# Fajr WakeUp

A **personal, fully-offline Android Fajr alarm** that plays the Adhan and keeps
repeating it until you pass an **on-device AI challenge**: taking a live photo of
your bathroom **sink/faucet** (where you perform Wudu), recognised on-device by
Google ML Kit's **bundled** image-labeling model. No backend, no cloud AI, no
Firebase, no account, no uploads, **no custom model to train** — everything runs
on the device and works immediately after install.

> Built with Flutter (UI, prayer-time math, storage) + native Kotlin (alarms,
> foreground Adhan playback, full-screen alarm UI, CameraX, ML Kit inference).

---

## ⚠️ Honest build status (read this first)

This repository was authored in an environment that had **no Flutter / Dart /
Android SDK / JDK / Gradle installed**, so the following were **NOT executed
here** and are explicitly not claimed as "passing":

| Item | Status |
|---|---|
| `flutter pub get` | **Not run** — resolve on your machine. Version constraints are known-good ranges; run `flutter pub upgrade --major-versions` if a pin conflicts. |
| `flutter analyze` / `flutter test` | **Not run here.** Dart unit tests are written (`test/`) and designed to be timezone-independent. |
| Gradle build / `flutter build apk` | **Not run here.** |
| Kotlin unit tests (Robolectric) | **Written** (`android/app/src/test/`), **not run here.** |
| On-device alarm reliability | **Cannot be verified without a physical device.** See [`docs/TESTING.md`](docs/TESTING.md). |
| The AI recognition | **Works out of the box** via ML Kit's bundled default model (generic `Sink` label) — no training, no model file. Live inference still needs a real device to validate (see below). **There is no fake AI success path.** |

Everything is real, compilable source — but you must run the toolchain to build,
test, and validate on a device. Where something genuinely needs a phone, this is
said plainly rather than glossed over.

---

## What works vs. what needs you

**Implemented and wired end-to-end:**
- Offline Fajr calculation (`adhan` package) with method, madhab, manual minute
  adjustment, device-location or manual lat/long.
- Rolling, idempotent exact-alarm scheduling via `AlarmManager.setAlarmClock()`.
- Native foreground (`mediaPlayback`) Adhan service that plays the **complete**
  Adhan and repeats after a configurable gap until stopped.
- Native full-screen alarm UI over the lockscreen (Arabic), with the exact
  workflow from the spec, emergency stop, and reboot re-arming.
- CameraX live capture + ML Kit **bundled** default Image Labeling inference
  (generic `Sink` label) with explicit result states and an on-screen
  labels/confidence diagnostic view; success stops the Adhan and records history.
- SQLite history + statistics; Arabic RTL UI across 5 screens.

**You must do:**
1. Install the toolchain and run the app (below).
2. Grant permissions and configure battery settings (per-OEM notes below).
3. In AI Challenge settings, run **Test recognition** on your actual sink and
   tune the confidence threshold using the diagnostic labels. (No model to train
   or install.) Emergency stop is always available.
4. Test alarm delivery on a real device.

---

## Architecture

```
┌──────────────────────────── Flutter (Dart) ────────────────────────────┐
│ UI (Arabic/RTL): Home, Prayer, Adhan, AI Challenge, History             │
│ PrayerTimeService (adhan)  SchedulingService  SQLite (sqflite)          │
│ AppState (provider)        WakeEventImportService                        │
└───────────────┬─────────────────────────────────────────────┬──────────┘
                │ MethodChannel: com.fajrwakeup.app/alarm       │ reads JSONL
                ▼                                               ▲ hand-off file
┌──────────────────────────── Native (Kotlin) ───────────────────────────┐
│ AlarmScheduler → AlarmManager.setAlarmClock (rolling 14-day queue)       │
│ FajrAlarmReceiver → starts AdhanPlaybackService + arms next day          │
│ AdhanPlaybackService (Media3/ExoPlayer, FGS mediaPlayback, loop)         │
│ AlarmNotificationManager (full-screen intent / heads-up fallback)        │
│ AlarmActivity (full-screen, lockscreen) → CameraX → FaucetVerifier       │
│ FaucetVerifier (ML Kit bundled default Image Labeling; looks for "Sink")  │
│ BootReceiver → re-arms alarms after reboot (never starts playback)       │
│ WakeEventStore → appends wake/verification events to a JSONL file        │
└─────────────────────────────────────────────────────────────────────────┘
```

**Why the critical path is native:** alarms fire from a `BroadcastReceiver`,
often with the screen off and the app not running. Spinning up the Flutter engine
at that moment is slow and unreliable, so scheduling, playback and the alarm
screen are pure Kotlin. Flutter owns configuration, prayer math, UI and history.

**Why a native→Flutter JSONL hand-off:** the alarm runs when Flutter is usually
dead. Instead of sharing one SQLite file across two layers (concurrency + schema
coupling), native appends events to `<filesDir>/pending_wake_events.jsonl`;
Flutter drains them into SQLite on next launch/resume. One owner per store.

### Rolling alarm scheduling (so it doesn't stop after the first alarm)

`setAlarmClock()` is one-shot. Flutter precomputes the next **14 days** of Fajr
instants and hands the whole list to native. Native arms only the soonest with
`setAlarmClock()` and keeps the rest. When an alarm fires (or the device reboots,
or time/zone changes), native drops past entries and arms the next soonest one.
Reopening the app recomputes and replaces the buffer (handling DST, location and
method changes). Rescheduling is idempotent — the same `PendingIntent` request
code + `FLAG_UPDATE_CURRENT` means settings changes replace, never duplicate.

Fajr is an astronomical instant; its absolute value (epoch millis) is
timezone-independent, which is what native schedules on — so DST changes inside
the buffer do not shift the trigger instant.

---

## Requirements

- **Flutter** 3.19+ (Dart 3.3+). Developed against stable channel.
- **Android SDK** with `compileSdk`/`targetSdk` 34 (bump to 35 if your AGP
  supports it), **minSdk 26** (Android 8.0).
- **JDK 17**, **Android Gradle Plugin 8.5.2**, **Gradle 8.7**, **Kotlin 1.9.24**.
- The app needs **no Python** — recognition is the bundled ML Kit model. The
  *optional* custom-model pipeline (future work) needs **Python 3.10/3.11**; see
  [`ml_training/README.md`](ml_training/README.md).

Key dependency versions (verified current as of 2026-01; see inline notes):
`adhan ^2.0.0`, `sqflite ^2.3.3`, `geolocator ^13`, `permission_handler ^11.3`,
`file_picker ^8.1`, `just_audio ^0.9.40`; native `media3 1.3.1`, `CameraX 1.3.4`,
`mlkit image-labeling-custom 17.0.3`.

---

## Setup & run

```bash
# 1. Install Flutter (https://docs.flutter.dev/get-started/install) and an
#    Android SDK. Connect a device or start an emulator.

cd fajr_wakeup

# 2. Let Flutter generate android/local.properties (flutter.sdk + sdk.dir) and
#    fetch packages:
flutter pub get

# 2b. Provide the Gradle wrapper (gradlew + gradle-wrapper.jar). These are NOT in
#     this repo because the jar is a binary that couldn't be generated in the
#     authoring environment. Copy them from a throwaway Flutter project WITHOUT
#     overwriting this project's custom Gradle files:
flutter create /tmp/_wrap --platforms=android >/dev/null
cp /tmp/_wrap/android/gradlew /tmp/_wrap/android/gradlew.bat android/
cp /tmp/_wrap/android/gradle/wrapper/gradle-wrapper.jar android/gradle/wrapper/
chmod +x android/gradlew && rm -rf /tmp/_wrap
#     (Alternatively, with a system Gradle: cd android && gradle wrapper --gradle-version 8.7)
#     Do NOT run `flutter create .` in this directory — it would overwrite the
#     customised build.gradle / manifest / MainActivity.

# 3. Static analysis + unit tests:
flutter analyze
flutter test

# 4. Run on a connected device:
flutter run
```

If `android/local.properties` is missing, create it:
```
flutter.sdk=/absolute/path/to/flutter
sdk.dir=/absolute/path/to/Android/Sdk
```

### Build the debug APK

```bash
flutter build apk --debug
# output: build/app/outputs/flutter-apk/app-debug.apk
```
A release APK (`flutter build apk`) is signed with the debug key out of the box
for personal sideloading — replace with a real signing config before wider use.

> No APK is bundled in this repo because the build toolchain was unavailable in
> the authoring environment.

---

## Permissions & device setup

The app requests, at the right moments:
- **Exact alarms** (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`) — the Home screen
  shows a banner + button to the system settings if not granted.
- **Notifications** (`POST_NOTIFICATIONS`, Android 13+) — needed for the alarm
  notification / full-screen intent.
- **Camera** — requested on the alarm screen when you tap the challenge button.
- **Location** (optional) — only if you use auto-detect; manual lat/long always
  works offline.
- **Full-screen intent** (`USE_FULL_SCREEN_INTENT`, Android 14+) — granted by
  default for genuine alarm apps; otherwise a high-priority heads-up notification
  is the documented fallback.

**Battery optimization / OEM restrictions (important for reliability):**
Aggressive power managers can delay or kill alarms. After install:
- **Stock Android / Pixel:** Settings → Apps → Fajr WakeUp → Battery →
  *Unrestricted*.
- **Samsung:** Settings → Battery → Background usage limits → remove app from
  "Sleeping/Deep sleeping apps"; disable "Put unused apps to sleep".
- **Xiaomi/MIUI:** Settings → Apps → Fajr WakeUp → Battery saver → *No
  restrictions*; enable Autostart.
- **Huawei:** App launch → manage manually → allow Auto-launch + Run in
  background.
- **OnePlus/Oppo/Realme/Vivo:** allow Auto-start and set battery to *Don't
  optimize*.

The app does **not** override your volume or Do-Not-Disturb. Audio uses the
**alarm** stream (`USAGE_ALARM`); make sure the alarm volume is up and alarms are
allowed in your DND schedule.

**Honest limits (not worked around):**
- An alarm **cannot** survive a **Force Stop** or a **powered-off** device — the
  OS removes scheduled alarms; they are re-armed on next boot by `BootReceiver`.
- These are platform guarantees, not app bugs.

---

## Using the app

1. **Prayer settings:** detect or enter location, pick calculation method and
   madhab, apply a manual Fajr adjustment, preview today/tomorrow's Fajr, Save.
   Saving re-arms the rolling schedule automatically.
2. **Adhan settings:** import your own Adhan MP3 (copied into app-private
   storage), preview it, set the repeat gap, and fire a **test alarm after 1
   minute**. If you don't import a file, the device's default alarm tone is used
   (no copyrighted audio ships with the app).
3. **AI Challenge settings:** see labeler status, set the acceptance confidence
   **threshold** (tune it from the on-screen diagnostic labels — don't trust a
   random number), toggle diagnostic image saving (off by default; images are
   deleted otherwise), and launch a camera **test recognition** to see exactly
   which labels/scores your sink produces.
4. **At Fajr:** the screen turns on over the lockscreen showing
   *«حان وقت صلاة الفجر، قم للوضوء»*. Tap *«التحقق من مكان الوضوء»*, point the
   camera at the sink/faucet; on a confident `Sink` match the Adhan stops and
   *«تبارك الله، أعانك الله على صلاة الفجر»* is shown. Otherwise the Adhan keeps
   going and you can retake. **Emergency stop** is always available (and is
   recorded as a manual stop, not a success).
5. **History:** date, scheduled Fajr, wake/verification time, challenge
   duration, attempts, outcome, confidence; with daily/weekly stats.

---

## AI recognition (bundled ML Kit model)

Recognition uses Google ML Kit's **bundled default Image Labeling model**
(`com.google.mlkit:image-labeling:17.0.9`) — it ships inside the APK, runs fully
offline, and needs **no training and no model file**. The challenge looks for the
generic **`Sink`** label and accepts only when its confidence exceeds your
configurable threshold. `Bathroom` (or any other label) alone is never accepted.

**Tune it to your bathroom:** open **AI Challenge settings → Test recognition**,
photograph your sink, and read the diagnostic labels + confidences shown on
screen. Set the threshold just below the `Sink` confidence you reliably get.

**Honesty / limits (important):**
- The default model is **generic**. It recognises *a sink*, not *your specific
  faucet*. A match only means a sink-like object is in frame — it does **not**
  prove you performed Wudu. This is a personal motivation tool, not a security
  system.
- If the default model does **not** reliably detect your particular sink (test it
  with the scenarios in [`docs/TESTING.md`](docs/TESTING.md)), the simplest next
  step is to train a custom per-faucet model with the **optional** pipeline in
  [`ml_training/`](ml_training/) — it is retained as future work and the app does
  not depend on it.

---

## Testing

- **Dart unit tests** (`test/`): prayer-time math (adjustment, ordering, method
  differences, rolling buffer), scheduling service (idempotent reschedule via a
  mocked MethodChannel), model/stats serialization. Run with `flutter test`.
- **Kotlin unit tests** (`android/app/src/test/`, Robolectric): alarm queue
  filtering/idempotency/clear, `Sink` classification logic, JSONL event store. Run
  with `cd android && ./gradlew testDebugUnitTest`.
- **Manual device checklist** (locked screen, screen off, background, battery
  saver, reboot, real audio, camera, exact-alarm permission):
  [`docs/TESTING.md`](docs/TESTING.md). These genuinely require a physical phone.

---

## Project structure

```
fajr_wakeup/
├── lib/                      # Flutter: UI, prayer math, storage, state
│   ├── core/ (services, storage, platform bridge, theme, l10n, widgets)
│   ├── data/ (models, repositories)
│   └── features/ (home, prayer_times, alarm→native, challenge, settings, history)
├── android/app/src/main/kotlin/com/fajrwakeup/app/
│   ├── alarm/   (AlarmScheduler, FajrAlarmReceiver, BootReceiver, Notification)
│   ├── service/ (AdhanPlaybackService)
│   ├── activity/(AlarmActivity)
│   ├── ai/      (FaucetVerifier)
│   └── bridge/  (AlarmBridge MethodChannel)
├── assets/models/            # placeholder dir (recognition uses bundled ML Kit, no file)
├── ml_training/              # OPTIONAL MobileNetV2 pipeline → TFLite (future work)
├── test/                     # Dart unit tests
└── docs/TESTING.md           # manual, device-dependent test checklist
```

---

## Engineering constraints honored

No backend · no cloud AI · no Firebase · no photo uploads · no authentication ·
on-device only · Kotlin (not Flutter) owns the alarm · no fake AI success path ·
no copyrighted Adhan bundled · DND/volume never silently overridden · honest
about Force-Stop / power-off / real-device limits · errors handled explicitly.

## Known limitations

- No iOS target (Android-only by request).
- The bundled model is generic: it detects *a sink*, not *your specific faucet*,
  and its reliability on your bathroom must be validated on-device.
- Full-screen-intent behaviour varies by OEM/Android version (fallback provided).
- Alarms don't survive Force Stop or power-off (re-armed on boot).
