# Flutter assets/models/

This directory only exists so `pubspec.yaml` has a valid `assets/models/` entry.

**No model file is needed here.** Fajr WakeUp uses Google ML Kit's **bundled
default Image Labeling model** (`com.google.mlkit:image-labeling`), which ships
inside the APK and runs offline. The challenge looks for the generic **`Sink`**
label — no custom model, no training, no `.tflite` install required.

The MobileNetV2 pipeline in [`ml_training/`](../../ml_training/) is retained as
**optional** future work (a custom per-faucet model) and is not a prerequisite
for the app.
