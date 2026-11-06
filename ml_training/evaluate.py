#!/usr/bin/env python3
"""
evaluate.py
===========
Evaluate the trained Fajr WakeUp faucet classifier and RECOMMEND a confidence
threshold for the Android app's "AI Challenge" settings.

What it does:
  * Rebuilds the SAME validation split train.py used (same --seed / --val-split /
    --img-size / class order / preprocessing). This is why the split arguments
    must match those you trained with.
  * Runs predictions and reports MEANINGFUL metrics:
      - overall accuracy
      - per-class precision / recall / F1 (sklearn classification_report)
      - confusion matrix (printed + saved as PNG)
      - a threshold sweep (0.50 .. 0.95) for the 'target_faucet' class,
        recommending the smallest threshold reaching a target precision
        (default 0.95) to minimize false "you may stop the alarm" positives.
  * Writes everything to artifacts/evaluation_metrics.json.

IMPORTANT HONESTY NOTE: every number here is only as good as your dataset. A
high score on a tiny or non-diverse validation set does NOT mean the model is
reliable in your real bathroom. Treat the recommended threshold as a starting
point and validate in the app.

The normalization contract (input in [-1, 1] via mobilenet_v2.preprocess_input,
NO internal rescaling layer) is identical to train.py - see that file's header.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import numpy as np
import tensorflow as tf

# Must match train.py exactly (index 0 = other, 1 = target_faucet).
CLASS_NAMES = ["other", "target_faucet"]
TARGET_INDEX = CLASS_NAMES.index("target_faucet")  # positive class = 1


def parse_args():
    p = argparse.ArgumentParser(
        description="Evaluate the faucet classifier and recommend a confidence threshold.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("--model", default="./artifacts/model.keras",
                   help="Path to model.keras (preferred) or a SavedModel directory.")
    p.add_argument("--data-dir", default="./dataset")
    p.add_argument("--img-size", type=int, default=224)
    p.add_argument("--batch-size", type=int, default=16)
    p.add_argument("--output-dir", default="./artifacts")
    p.add_argument("--val-split", type=float, default=0.2,
                   help="MUST match the value used in train.py.")
    p.add_argument("--seed", type=int, default=1337,
                   help="MUST match the value used in train.py to reproduce the split.")
    p.add_argument("--target-precision", type=float, default=0.95,
                   help="Desired minimum precision for 'target_faucet' when picking the threshold.")
    return p.parse_args()


class LoadedModel:
    """Loads a Keras model (.keras/.h5) or a SavedModel directory and exposes a
    uniform ``predict_batch(x)`` returning a (N, 2) softmax-probability array."""

    def __init__(self, path, img_size):
        self.path = path
        self.kind = None
        if path.endswith((".keras", ".h5")):
            self.model = tf.keras.models.load_model(path)
            self.kind = "keras"
        elif os.path.isdir(path):
            try:
                self.model = tf.keras.models.load_model(path)
                self.kind = "keras"
            except Exception:
                # Keras 3 inference SavedModel, or a plain tf.saved_model.
                self.sm = tf.saved_model.load(path)
                self.infer = self.sm.signatures["serving_default"]
                self.kind = "savedmodel"
        else:
            raise FileNotFoundError(f"Model path not found: {path}")

    def predict_batch(self, x):
        if self.kind == "keras":
            return np.asarray(self.model(x, training=False))
        out = self.infer(x)
        # serving_default returns a dict with a single output tensor.
        tensor = list(out.values())[0]
        return np.asarray(tensor)


def build_val_dataset(data_dir, img_size, batch_size, val_split, seed):
    """Reproduce train.py's validation subset (NO augmentation, same preprocessing)."""
    val_raw = tf.keras.utils.image_dataset_from_directory(
        data_dir,
        labels="inferred",
        label_mode="int",
        class_names=CLASS_NAMES,
        validation_split=val_split,
        subset="validation",
        seed=seed,
        image_size=(img_size, img_size),
        batch_size=batch_size,
    )
    assert list(val_raw.class_names) == CLASS_NAMES, (
        f"Unexpected class order {val_raw.class_names}; expected {CLASS_NAMES}")

    preprocess = tf.keras.applications.mobilenet_v2.preprocess_input
    # NOTE: we keep the dataset's default behavior but gather predictions AND
    # labels in ONE pass (below) so shuffling cannot misalign them.
    return val_raw.map(lambda x, y: (preprocess(x), y),
                       num_parallel_calls=tf.data.AUTOTUNE)


def collect_predictions(model, val_ds):
    """Single pass: gather y_true and softmax probs together (shuffle-safe)."""
    y_true, y_prob = [], []
    for x, y in val_ds:
        probs = model.predict_batch(x)
        y_prob.append(probs)
        y_true.append(y.numpy())
    if not y_true:
        print("ERROR: validation set is empty - cannot evaluate.", file=sys.stderr)
        sys.exit(2)
    return np.concatenate(y_true), np.concatenate(y_prob)


def save_confusion_png(cm, out_path):
    """Render the confusion matrix to a PNG (matplotlib)."""
    import matplotlib
    matplotlib.use("Agg")  # headless
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(4.5, 4))
    im = ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(len(CLASS_NAMES)), labels=CLASS_NAMES)
    ax.set_yticks(range(len(CLASS_NAMES)), labels=CLASS_NAMES)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("True")
    ax.set_title("Confusion matrix (validation)")
    thresh = cm.max() / 2.0 if cm.max() > 0 else 0.5
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(j, i, str(cm[i, j]), ha="center", va="center",
                    color="white" if cm[i, j] > thresh else "black")
    fig.colorbar(im, ax=ax)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def save_threshold_png(sweep, recommended, out_path):
    """Plot precision/recall vs threshold for the target_faucet class."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    ts = [s["threshold"] for s in sweep]
    prec = [s["precision"] for s in sweep]
    rec = [s["recall"] for s in sweep]
    fig, ax = plt.subplots(figsize=(5.5, 4))
    ax.plot(ts, prec, marker="o", label="precision (target_faucet)")
    ax.plot(ts, rec, marker="s", label="recall (target_faucet)")
    if recommended is not None:
        ax.axvline(recommended, color="red", linestyle="--",
                   label=f"recommended = {recommended:.2f}")
    ax.set_xlabel("Confidence threshold")
    ax.set_ylabel("Score")
    ax.set_ylim(-0.02, 1.02)
    ax.set_title("target_faucet precision/recall vs threshold")
    ax.legend(loc="lower left")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def main():
    args = parse_args()

    from sklearn.metrics import (
        accuracy_score, classification_report, confusion_matrix,
        precision_score, recall_score, f1_score,
    )

    model_path = os.path.abspath(args.model)
    data_dir = os.path.abspath(args.data_dir)
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    print("=" * 70)
    print("Fajr WakeUp - faucet classifier evaluation")
    print("=" * 70)
    print(f"TensorFlow : {tf.__version__}")
    print(f"Model      : {model_path}")
    print(f"Data dir   : {data_dir}")
    print(f"Split      : val_split={args.val_split} seed={args.seed} (must match train.py)")
    print("-" * 70)

    model = LoadedModel(model_path, args.img_size)
    val_ds = build_val_dataset(data_dir, args.img_size, args.batch_size,
                               args.val_split, args.seed)

    y_true, y_prob = collect_predictions(model, val_ds)
    y_pred = np.argmax(y_prob, axis=1)
    target_scores = y_prob[:, TARGET_INDEX]          # P(target_faucet)
    y_true_bin = (y_true == TARGET_INDEX).astype(int)

    n_val = int(len(y_true))
    n_pos = int(y_true_bin.sum())
    n_neg = n_val - n_pos
    print(f"Validation samples: {n_val}  (target_faucet={n_pos}, other={n_neg})")
    if n_pos == 0 or n_neg == 0:
        print("WARNING: validation set has only one class present - precision/recall "
              "and the recommended threshold are meaningless. Add more varied data.")

    # --- Core metrics --------------------------------------------------------
    overall_acc = float(accuracy_score(y_true, y_pred))
    report_text = classification_report(
        y_true, y_pred, labels=[0, 1], target_names=CLASS_NAMES, zero_division=0)
    report_dict = classification_report(
        y_true, y_pred, labels=[0, 1], target_names=CLASS_NAMES, zero_division=0,
        output_dict=True)
    cm = confusion_matrix(y_true, y_pred, labels=[0, 1])

    print(f"\nOverall accuracy: {overall_acc:.4f}")
    print("\nPer-class report:")
    print(report_text)
    print("Confusion matrix (rows=true, cols=pred), order", CLASS_NAMES)
    print(cm)

    cm_png = os.path.join(output_dir, "confusion_matrix.png")
    save_confusion_png(cm, cm_png)

    # --- Threshold sweep for target_faucet ----------------------------------
    # For each threshold t: predict 'target_faucet' iff P(target_faucet) >= t.
    # Higher threshold -> higher precision (fewer false alarms dismissed),
    # usually lower recall (the faucet must be seen very clearly to pass).
    thresholds = [round(t, 2) for t in np.arange(0.50, 0.96, 0.05)]
    sweep = []
    for t in thresholds:
        pred_bin = (target_scores >= t).astype(int)
        prec = float(precision_score(y_true_bin, pred_bin, zero_division=0))
        rec = float(recall_score(y_true_bin, pred_bin, zero_division=0))
        f1 = float(f1_score(y_true_bin, pred_bin, zero_division=0))
        n_flagged = int(pred_bin.sum())
        sweep.append({"threshold": t, "precision": prec, "recall": rec,
                      "f1": f1, "num_flagged_target": n_flagged})

    # Recommend the SMALLEST threshold meeting the precision target with recall > 0.
    recommended = None
    for s in sweep:
        if s["precision"] >= args.target_precision and s["recall"] > 0:
            recommended = s["threshold"]
            break
    rationale = ""
    if recommended is None:
        # Fall back to the threshold with the best precision (ties -> higher recall).
        best = max(sweep, key=lambda s: (s["precision"], s["recall"]))
        recommended = best["threshold"]
        rationale = (f"No threshold reached precision >= {args.target_precision} with recall>0. "
                     f"Falling back to the best-precision threshold ({recommended}). "
                     "This strongly indicates you need more/better data - especially hard "
                     "negatives in 'other/'.")
    else:
        rationale = (f"Smallest threshold achieving precision >= {args.target_precision} "
                     "for target_faucet, which minimizes false 'you may stop the alarm' positives.")

    thr_png = os.path.join(output_dir, "threshold_sweep.png")
    save_threshold_png(sweep, recommended, thr_png)

    print("\nThreshold sweep (target_faucet):")
    print(f"{'thr':>5} {'precision':>10} {'recall':>8} {'f1':>6} {'flagged':>8}")
    for s in sweep:
        print(f"{s['threshold']:>5.2f} {s['precision']:>10.3f} {s['recall']:>8.3f} "
              f"{s['f1']:>6.3f} {s['num_flagged_target']:>8d}")
    print(f"\n>>> RECOMMENDED confidence_threshold = {recommended:.2f}")
    print(f"    {rationale}")

    # --- Write JSON ----------------------------------------------------------
    metrics = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "tensorflow_version": tf.__version__,
        "model_path": model_path,
        "class_names": CLASS_NAMES,
        "val_split": args.val_split,
        "seed": args.seed,
        "num_val": n_val,
        "num_val_target_faucet": n_pos,
        "num_val_other": n_neg,
        "overall_accuracy": overall_acc,
        "per_class_report": report_dict,
        "confusion_matrix": {
            "order": CLASS_NAMES,
            "rows_true_cols_pred": cm.tolist(),
        },
        "threshold_sweep": sweep,
        "target_precision_goal": args.target_precision,
        "recommended_confidence_threshold": float(recommended),
        "recommended_threshold_rationale": rationale,
        "artifacts": {
            "confusion_matrix_png": cm_png,
            "threshold_sweep_png": thr_png,
        },
        "honesty_notes": [
            "These numbers are only as good as your dataset; a small or non-diverse "
            "validation set will over-estimate real-world reliability.",
            "Recognizing the faucet proves only that it appears in the camera frame - "
            "NOT that Wudu was actually performed.",
            "Copy 'recommended_confidence_threshold' into the app's AI Challenge "
            "Settings, then validate it in real conditions before trusting it to "
            "dismiss the alarm.",
        ],
    }
    out_json = os.path.join(output_dir, "evaluation_metrics.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    print("\n" + "=" * 70)
    print("Wrote:")
    print(f"  Metrics JSON : {out_json}")
    print(f"  Confusion PNG: {cm_png}")
    print(f"  Threshold PNG: {thr_png}")
    print("=" * 70)
    print("\nHONESTY: these results reflect your dataset only. Recognizing the faucet "
          "proves it is in frame, not that Wudu was performed. Copy the recommended "
          "threshold into the app's AI Challenge Settings and validate before relying on it.")
    print("\nNext step: export the ML Kit model:")
    print("  python export_tflite.py --model ./artifacts/saved_model")


if __name__ == "__main__":
    main()
