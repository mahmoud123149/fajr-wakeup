#!/usr/bin/env python3
"""
export_tflite.py
================
Convert the trained Keras / SavedModel into a TensorFlow Lite model with
EMBEDDED metadata that is compatible with Google ML Kit Custom Image Labeling,
then verify the metadata.

ML KIT COMPATIBILITY CHECKLIST (all enforced / documented below):
  * Single image input tensor of shape [1, 224, 224, 3], dtype float32.
  * Float model (ML Kit custom image labeling supports float models). We keep
    input/output float32 even when --quantize (float16) is used.
  * Embedded TFLite metadata with input normalization mean=[127.5], std=[127.5]
    and an associated labels file (axis labels), written via tflite_support's
    image_classifier.MetadataWriter.create_for_inference(...).
  * Label order in labels.txt matches the model's output order EXACTLY:
    index 0 = other, index 1 = target_faucet.

NORMALIZATION CONTRACT (why mean/std = 127.5):
  The Keras model was trained on inputs already mapped to [-1, 1] via
  mobilenet_v2.preprocess_input and contains NO internal rescaling layer.
  Declaring mean=127.5 / std=127.5 tells ML Kit to compute
  (pixel[0..255] - 127.5) / 127.5 = [-1, 1] before feeding the model - exactly
  the range it was trained on. This avoids double-normalization.

Usage:
    python export_tflite.py --model ./artifacts/saved_model
    python export_tflite.py --model ./artifacts/model.keras --quantize
"""

import argparse
import os
import shutil
import sys
import tempfile

import tensorflow as tf


def parse_args():
    p = argparse.ArgumentParser(
        description="Export an ML Kit-compatible .tflite with embedded metadata.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("--model", default="./artifacts/saved_model",
                   help="SavedModel directory (preferred) or a .keras file.")
    p.add_argument("--labels", default="./artifacts/labels.txt",
                   help="Labels file: one label per line, index 0=other, 1=target_faucet.")
    p.add_argument("--output", default="./artifacts/faucet_classifier.tflite",
                   help="Output .tflite path (metadata + labels embedded).")
    p.add_argument("--img-size", type=int, default=224,
                   help="Expected square input size (224 for the ML Kit contract).")
    p.add_argument("--quantize", action="store_true",
                   help="Apply float16 weight quantization (smaller model; input/output stay "
                        "float32 so it remains ML Kit-compatible). Tradeoff: ~half the size, "
                        "negligible accuracy loss. Omit for a plain float32 model.")
    return p.parse_args()


def ensure_saved_model(model_path, img_size):
    """Return (saved_model_dir, cleanup_dir_or_None).

    If model_path is already a SavedModel directory, use it directly. If it is a
    .keras/.h5 file, load it and export a temporary SavedModel (works on both
    Keras 2 and Keras 3) so TFLiteConverter.from_saved_model can consume it.
    """
    if os.path.isdir(model_path):
        # Heuristic sanity check for a SavedModel.
        if not os.path.exists(os.path.join(model_path, "saved_model.pb")):
            print(f"WARNING: '{model_path}' has no saved_model.pb - is this really a SavedModel?")
        return model_path, None

    if not os.path.isfile(model_path):
        print(f"ERROR: model path not found: {model_path}", file=sys.stderr)
        sys.exit(2)

    print(f"Loading Keras model '{model_path}' and exporting a temporary SavedModel...")
    model = tf.keras.models.load_model(model_path)
    tmp_dir = tempfile.mkdtemp(prefix="fajr_saved_model_")
    try:
        model.export(tmp_dir)          # Keras 3 (TF 2.16+)
    except AttributeError:
        model.save(tmp_dir, save_format="tf")  # Keras 2 (TF 2.15)
    return tmp_dir, tmp_dir


def convert_to_tflite(saved_model_dir, quantize):
    """Convert a SavedModel to a float TFLite model (input/output stay float32)."""
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    if quantize:
        # float16 quantization: weights stored as float16, but the graph still
        # runs in float and input/output remain float32 -> ML Kit compatible.
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        print("Quantization: float16 (weights) - input/output kept float32.")
    else:
        print("Quantization: none (plain float32).")
    # NOTE: Full int8 quantization is possible (needs a representative dataset)
    # and yields the smallest/fastest model, but float is the simplest path for
    # ML Kit custom image labeling and avoids quantized-input handling, so we
    # deliberately keep float here.
    return converter.convert()


def verify_tflite_io(tflite_bytes, img_size):
    """Print input/output tensor details so the user can confirm the contract."""
    interpreter = tf.lite.Interpreter(model_content=tflite_bytes)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    print("\nTFLite I/O tensors:")
    print(f"  input : shape={list(inp['shape'])} dtype={inp['dtype'].__name__}")
    print(f"  output: shape={list(out['shape'])} dtype={out['dtype'].__name__}")
    exp_in = [1, img_size, img_size, 3]
    if list(inp["shape"]) != exp_in:
        print(f"  WARNING: expected input shape {exp_in} for ML Kit - got {list(inp['shape'])}.")
    if inp["dtype"].__name__ != "float32":
        print("  WARNING: input dtype is not float32; ML Kit custom labeling expects a float model.")


def write_metadata(temp_tflite_path, labels_path, output_path):
    """Embed ML Kit metadata (normalization + labels) using tflite_support."""
    try:
        from tflite_support.metadata_writers import image_classifier, writer_utils
        from tflite_support import metadata as _metadata
    except ImportError as e:
        print("\nERROR: 'tflite_support' is required to embed ML Kit metadata but is not "
              "installed.\n  Install it with:  pip install tflite-support==0.4.4\n"
              f"  (import error: {e})", file=sys.stderr)
        sys.exit(1)

    # mean/std = 127.5 -> ML Kit maps [0,255] pixels to [-1,1] (see header note).
    writer = image_classifier.MetadataWriter.create_for_inference(
        writer_utils.load_file(temp_tflite_path),
        input_norm_mean=[127.5],
        input_norm_std=[127.5],
        label_file_paths=[labels_path],
    )
    writer_utils.save_file(writer.populate(), output_path)

    # Verify: read metadata back and show it + the embedded label file.
    displayer = _metadata.MetadataDisplayer.with_model_file(output_path)
    print("\nEmbedded metadata JSON:")
    print(displayer.get_metadata_json())
    print("Embedded associated files:", displayer.get_packed_associated_file_list())


def main():
    args = parse_args()

    model_path = os.path.abspath(args.model)
    labels_path = os.path.abspath(args.labels)
    output_path = os.path.abspath(args.output)

    print("=" * 70)
    print("Fajr WakeUp - export ML Kit-compatible TFLite")
    print("=" * 70)
    print(f"TensorFlow : {tf.__version__}")
    print(f"Model      : {model_path}")
    print(f"Labels     : {labels_path}")
    print(f"Output     : {output_path}")
    print("-" * 70)

    if not os.path.isfile(labels_path):
        print(f"ERROR: labels file not found: {labels_path}\n"
              "Run train.py first (it writes artifacts/labels.txt).", file=sys.stderr)
        sys.exit(2)
    with open(labels_path, "r", encoding="utf-8") as f:
        labels = [ln.strip() for ln in f if ln.strip()]
    print(f"Labels (index order): {labels}")
    if labels != ["other", "target_faucet"]:
        print("WARNING: labels.txt is not exactly ['other', 'target_faucet']. The label "
              "order MUST match the model's output order or predictions will be mislabeled.")

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    saved_model_dir, cleanup = ensure_saved_model(model_path, args.img_size)
    try:
        tflite_bytes = convert_to_tflite(saved_model_dir, args.quantize)
    finally:
        if cleanup and os.path.isdir(cleanup):
            shutil.rmtree(cleanup, ignore_errors=True)

    verify_tflite_io(tflite_bytes, args.img_size)

    # Write the raw (metadata-less) model to a temp file, then embed metadata.
    with tempfile.NamedTemporaryFile(suffix=".tflite", delete=False) as tmp:
        tmp.write(tflite_bytes)
        temp_tflite_path = tmp.name
    try:
        write_metadata(temp_tflite_path, labels_path, output_path)
    finally:
        try:
            os.remove(temp_tflite_path)
        except OSError:
            pass

    size_kb = os.path.getsize(output_path) / 1024.0
    print("\n" + "=" * 70)
    print(f"SUCCESS: wrote {output_path} ({size_kb:.1f} KB)")
    print("=" * 70)
    print("\nINSTALL INTO THE ANDROID APP:")
    print("  Copy the model to the app's assets directory:")
    print(f"    cp {output_path} \\")
    print("       android/app/src/main/assets/faucet_classifier.tflite")
    print("\n  Then load it via ML Kit, e.g.:")
    print("    val localModel = LocalModel.Builder()")
    print("        .setAssetFilePath(\"faucet_classifier.tflite\").build()")
    print("    val options = CustomImageLabelerOptions.Builder(localModel)")
    print("        .setConfidenceThreshold(<value from evaluate.py>)  // see evaluation_metrics.json")
    print("        .setMaxResultCount(2).build()")
    print("\nReminder: set the confidence threshold from evaluate.py's "
          "recommended_confidence_threshold, and remember recognition only proves the "
          "faucet is in frame - not that Wudu was performed.")


if __name__ == "__main__":
    main()
