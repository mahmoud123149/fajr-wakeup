#!/usr/bin/env python3
"""
train.py
========
Transfer-learning trainer for the Fajr WakeUp personal faucet classifier.

GOAL
----
Train a lightweight MobileNetV2-based image classifier that distinguishes the
user's *personal bathroom faucet* (``target_faucet``) from *everything else*
(``other``), then save a Keras model + labels that ``export_tflite.py`` turns
into a Google ML Kit-compatible ``.tflite``.

================================  ML KIT CONTRACT  ============================
The exported ``.tflite`` will carry TFLite metadata declaring:

    input_norm_mean = [127.5]
    input_norm_std  = [127.5]

which means ML Kit (and any metadata-aware runtime) feeds the model pixels
normalized as:   (pixel[0..255] - 127.5) / 127.5   ->   range [-1, 1].

Therefore THIS MODEL MUST EXPECT INPUT ALREADY IN [-1, 1] and must NOT contain
an internal Rescaling / Normalization layer. To honor that contract during
training AND evaluation we apply
``tf.keras.applications.mobilenet_v2.preprocess_input`` (which maps
[0, 255] -> [-1, 1]) *inside the data pipeline*. This keeps the training-time
and the on-device inference-time normalization identical and avoids the classic
"double normalization" bug (normalizing once in the graph and again via
metadata), which silently wrecks accuracy.

================================  CLASS ORDER  ===============================
The label order is FIXED, alphabetical, and MUST match the model's softmax
output order exactly:

    index 0 = other
    index 1 = target_faucet

We pass ``class_names=['other', 'target_faucet']`` explicitly and assert it, so
we never rely on the OS-dependent directory-scan order.
=============================================================================

Run ``python train.py --help`` for options. Typical use:

    python train.py                       # feature-extraction only
    python train.py --fine-tune           # + a low-LR fine-tune phase
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import tensorflow as tf

# ---------------------------------------------------------------------------
# Fixed contract constants (DO NOT reorder - index 0 = other, 1 = target_faucet)
# ---------------------------------------------------------------------------
CLASS_NAMES = ["other", "target_faucet"]
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp")

# Dataset-size sanity thresholds (per class) used only for warnings.
MIN_POSITIVES_RECOMMENDED = 40   # target_faucet
MIN_NEGATIVES_RECOMMENDED = 80   # other


def parse_args():
    p = argparse.ArgumentParser(
        description="Train the Fajr WakeUp faucet classifier (MobileNetV2 transfer learning).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("--data-dir", default="./dataset",
                   help="Dataset root containing 'other/' and 'target_faucet/' subdirs.")
    p.add_argument("--epochs", type=int, default=25,
                   help="Max epochs for the feature-extraction phase (EarlyStopping may stop sooner).")
    p.add_argument("--batch-size", type=int, default=16)
    p.add_argument("--img-size", type=int, default=224,
                   help="Square input size. MUST stay 224 for the ML Kit model contract.")
    p.add_argument("--output-dir", default="./artifacts",
                   help="Where to write the model, labels and metadata.")
    p.add_argument("--fine-tune", action="store_true",
                   help="After feature extraction, unfreeze top base layers and fine-tune at a low LR.")
    p.add_argument("--fine-tune-epochs", type=int, default=10,
                   help="Additional epochs for the fine-tune phase (only if --fine-tune).")
    p.add_argument("--fine-tune-at", type=int, default=100,
                   help="Freeze base layers with index < this; unfreeze the rest during fine-tuning.")
    p.add_argument("--val-split", type=float, default=0.2,
                   help="Fraction of data used for validation. Must match evaluate.py.")
    p.add_argument("--seed", type=int, default=1337,
                   help="Random seed driving the train/val split. Must match evaluate.py.")
    p.add_argument("--dropout", type=float, default=0.2)
    p.add_argument("--learning-rate", type=float, default=1e-3,
                   help="LR for the feature-extraction phase.")
    p.add_argument("--fine-tune-lr", type=float, default=1e-5,
                   help="LR for the fine-tune phase (kept small to avoid wrecking pretrained weights).")
    p.add_argument("--patience", type=int, default=6,
                   help="EarlyStopping patience (epochs without val_loss improvement).")
    return p.parse_args()


def count_images(class_dir):
    """Count image files (recursively) under a class directory."""
    if not os.path.isdir(class_dir):
        return 0
    total = 0
    for root, _dirs, files in os.walk(class_dir):
        for name in files:
            if name.lower().endswith(IMAGE_EXTENSIONS):
                total += 1
    return total


def validate_dataset(data_dir):
    """Guard rails. Returns a dict of per-class counts, or exits non-zero on fatal problems."""
    counts = {}
    missing = []
    for cls in CLASS_NAMES:
        cls_dir = os.path.join(data_dir, cls)
        if not os.path.isdir(cls_dir):
            missing.append(cls_dir)
        counts[cls] = count_images(cls_dir)

    if missing:
        print("ERROR: Required class directories are missing:", file=sys.stderr)
        for m in missing:
            print(f"  - {m}", file=sys.stderr)
        print("Create them and add images before training.", file=sys.stderr)
        sys.exit(2)

    empty = [cls for cls in CLASS_NAMES if counts[cls] == 0]
    if empty:
        print("ERROR: The following class directories contain NO images:", file=sys.stderr)
        for cls in empty:
            print(f"  - {os.path.join(data_dir, cls)}", file=sys.stderr)
        print("\nAdd images and retry. For a personal faucet classifier you want at least\n"
              f"  ~{MIN_POSITIVES_RECOMMENDED} photos in 'target_faucet/' and ~{MIN_NEGATIVES_RECOMMENDED} in 'other/'.",
              file=sys.stderr)
        sys.exit(2)

    # Non-fatal warnings about small / imbalanced datasets.
    if counts["target_faucet"] < MIN_POSITIVES_RECOMMENDED:
        print(f"WARNING: only {counts['target_faucet']} 'target_faucet' images - "
              f"recommend at least ~{MIN_POSITIVES_RECOMMENDED} for a reliable model.")
    if counts["other"] < MIN_NEGATIVES_RECOMMENDED:
        print(f"WARNING: only {counts['other']} 'other' images - "
              f"recommend at least ~{MIN_NEGATIVES_RECOMMENDED} (include hard negatives).")

    total = sum(counts.values())
    if total < 20:
        print("WARNING: very small dataset - results will be noisy and the recommended "
              "confidence threshold unreliable. Collect more, diverse images.")
    return counts


def build_datasets(data_dir, img_size, batch_size, val_split, seed):
    """Build raw (un-preprocessed) train/val datasets with a DETERMINISTIC class order."""
    common = dict(
        labels="inferred",
        label_mode="int",                 # integer labels -> sparse_categorical_crossentropy
        class_names=CLASS_NAMES,          # <-- fixes the class order explicitly
        validation_split=val_split,
        seed=seed,                        # same seed -> same split in evaluate.py
        image_size=(img_size, img_size),
        batch_size=batch_size,
    )
    train_ds = tf.keras.utils.image_dataset_from_directory(
        data_dir, subset="training", **common)
    val_ds = tf.keras.utils.image_dataset_from_directory(
        data_dir, subset="validation", **common)

    # Hard assertion: Keras must have honored our explicit order.
    assert list(train_ds.class_names) == CLASS_NAMES, (
        f"Unexpected class order {train_ds.class_names}; expected {CLASS_NAMES}")
    assert list(val_ds.class_names) == CLASS_NAMES, (
        f"Unexpected class order {val_ds.class_names}; expected {CLASS_NAMES}")
    return train_ds, val_ds


def count_samples(ds):
    """Exact sample count by iterating once (datasets are small and re-iterable)."""
    total = 0
    for _x, y in ds:
        total += int(y.shape[0])
    return total


def make_augmentation():
    """Augmentation layers - applied to the TRAINING set only.

    These make the model robust to the angle / lighting / distance / background
    variation the prompt asks for. Note RandomBrightness is configured for the
    [0, 255] value range because augmentation runs BEFORE preprocess_input.
    """
    return tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.15),
            tf.keras.layers.RandomZoom(0.2),
            tf.keras.layers.RandomContrast(0.2),
            tf.keras.layers.RandomBrightness(0.2, value_range=(0, 255)),
        ],
        name="data_augmentation",
    )


def prepare(ds, augmentation=None):
    """Attach augmentation (train only) then MobileNetV2 preprocessing.

    CRITICAL: mobilenet_v2.preprocess_input maps [0, 255] -> [-1, 1]. The model
    has NO internal rescaling layer, so this is the single place normalization
    happens at training time - matching the mean=127.5 / std=127.5 metadata the
    exported .tflite declares for on-device inference.
    """
    autotune = tf.data.AUTOTUNE
    preprocess = tf.keras.applications.mobilenet_v2.preprocess_input
    if augmentation is not None:
        ds = ds.map(lambda x, y: (augmentation(x, training=True), y),
                    num_parallel_calls=autotune)
    ds = ds.map(lambda x, y: (preprocess(x), y), num_parallel_calls=autotune)
    return ds.prefetch(autotune)


def build_model(img_size, dropout):
    """MobileNetV2 (frozen) -> GAP -> Dropout -> Dense(2, softmax).

    base is returned too so the caller can unfreeze it for fine-tuning.
    The base is called with training=False so its BatchNorm layers stay in
    inference mode - the recommended setup for transfer learning AND fine-tuning.
    """
    base = tf.keras.applications.MobileNetV2(
        include_top=False,
        weights="imagenet",
        input_shape=(img_size, img_size, 3),
    )
    base.trainable = False

    inputs = tf.keras.Input(shape=(img_size, img_size, 3), name="input_image")
    x = base(inputs, training=False)                         # expects [-1, 1] input
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(len(CLASS_NAMES), activation="softmax",
                                    name="predictions")(x)
    model = tf.keras.Model(inputs, outputs, name="fajr_faucet_classifier")
    return model, base


def save_saved_model(model, path):
    """Save an inference SavedModel, working on both Keras 2 (TF 2.15) and Keras 3 (TF 2.16+)."""
    if os.path.isdir(path):
        # Overwrite cleanly.
        import shutil
        shutil.rmtree(path)
    try:
        # Keras 3 (TF 2.16+): produces an inference-only SavedModel.
        model.export(path)
        return "model.export"
    except AttributeError:
        # Keras 2 (TF 2.15): classic SavedModel directory.
        model.save(path, save_format="tf")
        return "model.save(save_format='tf')"


def main():
    args = parse_args()

    if args.img_size != 224:
        print(f"WARNING: --img-size={args.img_size} but the ML Kit model contract expects 224. "
              "The exported model will not match CustomImageLabelerOptions defaults.")

    tf.keras.utils.set_random_seed(args.seed)

    data_dir = os.path.abspath(args.data_dir)
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    print("=" * 70)
    print("Fajr WakeUp - faucet classifier training")
    print("=" * 70)
    print(f"TensorFlow : {tf.__version__}")
    print(f"Data dir   : {data_dir}")
    print(f"Output dir : {output_dir}")
    print(f"Classes    : {CLASS_NAMES}  (index 0=other, 1=target_faucet)")
    print("-" * 70)

    counts = validate_dataset(data_dir)
    print(f"Image counts: {counts}")

    # --- Build data pipeline -------------------------------------------------
    train_raw, val_raw = build_datasets(
        data_dir, args.img_size, args.batch_size, args.val_split, args.seed)

    num_train = count_samples(train_raw)
    num_val = count_samples(val_raw)
    print(f"Train samples: {num_train} | Val samples: {num_val}")
    if num_val == 0:
        print("ERROR: validation split produced 0 samples. Add more images or lower --val-split.",
              file=sys.stderr)
        sys.exit(2)

    augmentation = make_augmentation()
    train_ds = prepare(train_raw, augmentation=augmentation)
    val_ds = prepare(val_raw, augmentation=None)

    # --- Build + compile model ----------------------------------------------
    model, base = build_model(args.img_size, args.dropout)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.summary()

    best_ckpt = os.path.join(output_dir, "best.keras")
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=args.patience, restore_best_weights=True),
        tf.keras.callbacks.ModelCheckpoint(
            best_ckpt, monitor="val_loss", save_best_only=True),
    ]

    # --- Phase 1: feature extraction (frozen base) ---------------------------
    print("\n[Phase 1] Feature extraction (frozen MobileNetV2 base)")
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=callbacks,
    )
    last_epoch = history.epoch[-1] if history.epoch else 0

    # --- Phase 2 (optional): fine-tuning -------------------------------------
    did_fine_tune = False
    if args.fine_tune:
        print("\n[Phase 2] Fine-tuning top base layers (low LR)")
        base.trainable = True
        # Keep lower layers frozen; only fine-tune the top of the base.
        for layer in base.layers[:args.fine_tune_at]:
            layer.trainable = False
        trainable = sum(1 for l in base.layers if l.trainable)
        print(f"Unfroze {trainable}/{len(base.layers)} base layers "
              f"(from index {args.fine_tune_at}).")

        # Must recompile after changing trainability. Use a much smaller LR.
        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=args.fine_tune_lr),
            loss="sparse_categorical_crossentropy",
            metrics=["accuracy"],
        )
        total_epochs = last_epoch + 1 + args.fine_tune_epochs
        history_ft = model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=total_epochs,
            initial_epoch=last_epoch + 1,
            callbacks=callbacks,
        )
        did_fine_tune = True

    # --- Final validation metrics (best weights restored by EarlyStopping) ---
    print("\nEvaluating best model on the validation set...")
    val_loss, val_acc = model.evaluate(val_ds, verbose=0)
    print(f"Final validation accuracy: {val_acc:.4f} | loss: {val_loss:.4f}")

    # --- Save artifacts ------------------------------------------------------
    saved_model_dir = os.path.join(output_dir, "saved_model")
    keras_path = os.path.join(output_dir, "model.keras")
    labels_path = os.path.join(output_dir, "labels.txt")
    meta_path = os.path.join(output_dir, "training_metadata.json")

    how = save_saved_model(model, saved_model_dir)
    model.save(keras_path)  # portable single-file format (both Keras 2 and 3)

    # labels.txt - ONE label per line in the FIXED index order (other=0, target_faucet=1).
    with open(labels_path, "w", encoding="utf-8") as f:
        f.write("\n".join(CLASS_NAMES) + "\n")

    metadata = {
        "app": "Fajr WakeUp - faucet classifier",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "tensorflow_version": tf.__version__,
        "img_size": args.img_size,
        "class_names": CLASS_NAMES,
        "class_index_map": {name: i for i, name in enumerate(CLASS_NAMES)},
        "image_counts_per_class": counts,
        "num_train": num_train,
        "num_val": num_val,
        "val_split": args.val_split,
        "seed": args.seed,
        "epochs_requested": args.epochs,
        "fine_tuned": did_fine_tune,
        "final_val_accuracy": float(val_acc),
        "final_val_loss": float(val_loss),
        "normalization_contract": {
            "note": "Model expects input already in [-1, 1]; no internal Rescaling layer. "
                    "mobilenet_v2.preprocess_input is applied in the data pipeline. "
                    "The exported .tflite declares mean=127.5/std=127.5 so ML Kit maps "
                    "[0,255] pixels -> [-1,1] to match.",
            "input_norm_mean": 127.5,
            "input_norm_std": 127.5,
        },
        "saved_model_method": how,
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print("\n" + "=" * 70)
    print("Saved artifacts:")
    print(f"  SavedModel : {saved_model_dir}  (via {how})")
    print(f"  Keras model: {keras_path}")
    print(f"  Best ckpt  : {best_ckpt}")
    print(f"  Labels     : {labels_path}")
    print(f"  Metadata   : {meta_path}")
    print("=" * 70)
    print("\nNEXT STEPS:")
    print(f"  1) Evaluate & pick a confidence threshold:")
    print(f"       python evaluate.py --model {keras_path}")
    print(f"  2) Export the ML Kit-compatible TFLite model:")
    print(f"       python export_tflite.py --model {saved_model_dir}")
    print("\nReminder: recognizing the faucet proves only that it is in frame - "
          "not that Wudu was performed. Validate before trusting it to dismiss the alarm.")


if __name__ == "__main__":
    main()
