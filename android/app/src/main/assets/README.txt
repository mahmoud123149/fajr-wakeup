No model file is required here anymore.

Fajr WakeUp now uses Google ML Kit's BUNDLED default Image Labeling model
(com.google.mlkit:image-labeling), which ships inside the APK and works offline
immediately. Recognition looks for the generic "Sink" label.

You do NOT need to train or install any .tflite file for normal operation.

(The optional MobileNetV2 training pipeline in ../../../../ml_training is kept only
as future work for a custom per-faucet model; the app does not depend on it.)
