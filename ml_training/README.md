# Fajr WakeUp — On-Device Faucet Classifier (ML Training)

> **⚠️ OPTIONAL — not required to run the app.** Fajr WakeUp now performs its AI
> challenge with Google ML Kit's **bundled default** image-labeling model (the
> generic `Sink` label), which ships in the APK and needs no training. This
> pipeline is retained only as **future work** for a *custom per-faucet* model if
> the generic model proves insufficient for your bathroom (see the app's
> `docs/TESTING.md`). The standard app does **not** depend on anything here, and
> the runtime no longer loads a custom `.tflite` by default.
>
> If you do build a custom model, note the app's current `FaucetVerifier` uses the
> bundled labeler; wiring a custom `LocalModel` back in would be a code change.

This directory trains a small transfer-learning image classifier that
distinguishes **your personal bathroom faucet** (`target_faucet`) from
**everything else** (`other`), and exports it to a **TensorFlow Lite** model
that is compatible with **Google ML Kit Custom Image Labeling**. The Android app
loads the resulting `.tflite` via ML Kit's `LocalModel` /
`CustomImageLabelerOptions` so the "AI Challenge" can check whether the faucet is
in the camera frame.

> **Honesty up front.** Recognizing the faucet proves only that the faucet
> *appears in the camera frame* — it does **not** prove that Wudu (ablution) was
> actually performed. The model's reliability depends **entirely** on the quality
> and diversity of the images you collect. Validate it in real conditions before
> trusting it to dismiss your Fajr alarm.

---

## 1. The ML Kit compatibility contract

The exported model is built to satisfy ML Kit Custom Image Labeling exactly:

| Requirement | Value in this pipeline |
|---|---|
| Input tensor | single image, shape `[1, 224, 224, 3]`, dtype `float32` |
| Model type | **float** (ML Kit custom labeling supports float; input/output stay float32) |
| Embedded metadata | yes — written with `tflite_support` metadata writers |
| Input normalization (metadata) | `input_norm_mean = [127.5]`, `input_norm_std = [127.5]` |
| Associated labels file | `labels.txt` embedded as axis labels |
| Label / output order | **index 0 = `other`, index 1 = `target_faucet`** (alphabetical, fixed) |

### Why mean = std = 127.5 (the normalization contract — important)

The metadata tells ML Kit to normalize each pixel as
`(pixel[0..255] - 127.5) / 127.5`, which maps raw pixels into **[-1, 1]**.

Therefore the trained Keras model **must expect input already in [-1, 1]** and
must **not** contain any internal `Rescaling` / normalization layer. We honor
this by applying `tf.keras.applications.mobilenet_v2.preprocess_input`
(which maps `[0, 255] → [-1, 1]`) **inside the data pipeline** during both
training and evaluation. On device, ML Kit does the equivalent via the metadata.

If you were to *also* put a rescaling layer in the model, you'd get
**double normalization** and the model would silently perform badly. Don't.

### Why the fixed class order matters

ML Kit maps each output index to a line in the embedded labels file. If the
label order and the model's output order disagree, every prediction is
mislabeled. The scripts pin `class_names=['other', 'target_faucet']` explicitly
and `assert` it, and `labels.txt` is written in that exact index order.

---

## 2. Python environment (READ THIS — version matters)

TensorFlow does **not** support Python 3.12+ for this stack, and this machine's
system Python 3.14 is **far too new** (no TF wheels exist for it). You must use
**Python 3.10 or 3.11**.

```bash
# from inside this ml_training/ directory
python3.10 -m venv .venv          # or python3.11 -m venv .venv
source .venv/bin/activate         # Windows: .venv\Scripts\activate
pip install --upgrade pip
pip install -r requirements.txt
```

The pinned versions in `requirements.txt` (TensorFlow 2.15.1 + tflite-support
0.4.4 + numpy < 2) are a known-good baseline for producing ML Kit metadata.

---

## 3. Collecting your dataset

Put images here (they are git-ignored on purpose; only the folder structure is
tracked):

```
dataset/
├── target_faucet/    <- photos of YOUR faucet ONLY
└── other/            <- everything else (negatives / hard negatives)
```

### `target_faucet/` (positives)
Photograph **your** faucet across as much variation as possible, because that is
exactly what the camera will see at 5 a.m.:
- **Angles:** front, side, above, low, tilted.
- **Distances:** close-up and from across the sink.
- **Lighting:** bright daylight, dim night light, bathroom light on/off, with
  glare/reflections.
- **State:** water running vs. off, wet vs. dry, with/without soap/toothbrush
  nearby.
- **Backgrounds:** the real wall/counter behind it, slightly different framings.

### `other/` (negatives — include *hard* negatives)
Teach the model what is *not* your faucet so it doesn't fire on anything shiny:
- **Hard negatives:** *other* faucets and taps, similar metal fixtures, shower
  heads, door handles, kettles, chrome objects, sinks without the faucet.
- **Scene negatives:** general bathroom shots, walls, mirrors, towels.
- **Random objects:** everyday things the phone might point at.

### Rough minimums (more + more diverse = more reliable)
- `target_faucet`: **≥ ~40** images (aim for 100+).
- `other`: **≥ ~80** images (aim for 200+, heavy on hard negatives).
- Keep the classes from being wildly imbalanced, and make sure the variety above
  is actually represented — 100 near-identical shots are worth little.

`train.py` will **error out** if a class folder is empty and **warn** if a class
is below the recommended minimum.

Supported image types: `.jpg`, `.jpeg`, `.png`, `.bmp`, `.gif`.

---

## 4. Run the pipeline

All commands assume the venv is active and you are in `ml_training/`.

```bash
# 1) Train (feature extraction). Add --fine-tune for an extra low-LR phase.
python train.py
python train.py --fine-tune            # optional: unfreeze top base layers

# 2) Evaluate and get a recommended confidence threshold.
python evaluate.py --model ./artifacts/model.keras

# 3) Export the ML Kit-compatible .tflite (with embedded metadata).
python export_tflite.py --model ./artifacts/saved_model
python export_tflite.py --model ./artifacts/saved_model --quantize   # float16, smaller
```

Everything is written to `artifacts/` (git-ignored):

| File | What it is |
|---|---|
| `artifacts/model.keras` | trained Keras model (for evaluation/re-export) |
| `artifacts/saved_model/` | SavedModel (preferred input for TFLite export) |
| `artifacts/best.keras` | best checkpoint during training |
| `artifacts/labels.txt` | `other` / `target_faucet`, one per line, in index order |
| `artifacts/training_metadata.json` | training summary (sizes, versions, val accuracy) |
| `artifacts/evaluation_metrics.json` | metrics + recommended threshold |
| `artifacts/confusion_matrix.png` | confusion matrix plot |
| `artifacts/threshold_sweep.png` | precision/recall vs threshold plot |
| `artifacts/faucet_classifier.tflite` | **the model you ship to the app** |

> **Keep the split consistent.** `evaluate.py` reproduces the *same* validation
> set as `train.py` by reusing `--seed`, `--val-split`, `--img-size` and the
> fixed class order. If you change any of these in `train.py`, pass the same
> values to `evaluate.py`.

---

## 5. Reading the evaluation output & picking the threshold

`evaluate.py` reports overall accuracy, per-class precision/recall/F1, a
confusion matrix, and a **threshold sweep (0.50 → 0.95)** for `target_faucet`.

- **Higher threshold** → the faucet must be recognized with high confidence to
  pass. This **raises precision** (fewer false "you may stop the alarm"
  positives) but usually **lowers recall** (you may have to frame the faucet more
  clearly).
- The script recommends the **smallest threshold that reaches precision ≥ 0.95**
  (configurable with `--target-precision`) while keeping recall > 0, because for
  an alarm-dismissal gate you care most about **not being fooled**.

Take `recommended_confidence_threshold` from
`artifacts/evaluation_metrics.json` and **copy it into the app's AI Challenge
Settings** (ML Kit `CustomImageLabelerOptions.setConfidenceThreshold(...)`).

> If **no** threshold reaches the precision goal, that's a signal your dataset is
> too small or lacks hard negatives — collect more and retrain, rather than
> trusting a weak model.

---

## 6. Installing the model in the Android app

Copy the exported model into the app's assets:

```bash
cp artifacts/faucet_classifier.tflite \
   android/app/src/main/assets/faucet_classifier.tflite
```

Then load it with ML Kit (Kotlin sketch):

```kotlin
val localModel = LocalModel.Builder()
    .setAssetFilePath("faucet_classifier.tflite")
    .build()

val options = CustomImageLabelerOptions.Builder(localModel)
    .setConfidenceThreshold(0.90f)   // use evaluate.py's recommended value
    .setMaxResultCount(2)
    .build()

val labeler = ImageLabeling.getClient(options)
```

Because normalization is embedded in the metadata, you feed ML Kit the raw image
— do **not** normalize pixels yourself in the app.

---

## 7. Honesty & reliability notes

- **In-frame ≠ Wudu performed.** The model only detects that the faucet is
  visible. It cannot verify ablution. Treat it as a "point your camera at the
  sink" nudge, not proof.
- **Garbage in, garbage out.** Metrics and the recommended threshold are only as
  good as your dataset. A high score on a tiny/non-diverse validation set will
  over-estimate real reliability.
- **Validate before you rely on it.** Try it at the actual time and lighting
  you'll use it, including failure cases (other faucets, dark room), before
  letting it dismiss the alarm.
- **Privacy.** Your images stay local (git-ignored) and the model runs fully
  on-device via ML Kit; nothing is uploaded by this pipeline.
