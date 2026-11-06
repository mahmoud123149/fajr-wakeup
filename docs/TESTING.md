# Manual device test checklist

Automated unit tests cover pure logic (prayer math, scheduling, serialization,
alarm-queue bookkeeping). The items below **require a real Android phone** — they
depend on the OS alarm scheduler, Doze, lockscreen, real audio hardware and the
camera, none of which an emulator or JVM test reproduces faithfully. Be honest in
recording results; do not mark an item passed unless you actually observed it.

## Prerequisites
- Debug APK installed (`flutter run` or `flutter build apk --debug`).
- Exact-alarm + notification permissions granted (Home-screen banners).
- Battery optimization disabled for the app (see README, per-OEM).
- Either a trained `faucet_classifier.tflite` installed, OR plan to dismiss via
  **emergency stop** (the AI challenge cannot succeed without a valid model).

## Core alarm delivery
Use **Adhan settings → Test alarm (after 1 minute)** for each scenario.

| # | Scenario | Expected | Pass? |
|---|---|---|---|
| 1 | App in foreground | Full-screen alarm appears, Adhan plays | |
| 2 | App backgrounded (home button) | Alarm appears, Adhan plays | |
| 3 | App removed from recents | Alarm still fires (service `stopWithTask=false`) | |
| 4 | Screen off, device locked | Screen turns on, alarm shows over lockscreen | |
| 5 | Battery saver ON | Alarm still fires at time (verify delay is acceptable) | |
| 6 | Airplane mode / no internet | Alarm + Adhan + AI all work offline | |
| 7 | Let Adhan finish once | After the gap, the **complete** Adhan repeats (not cut off) | |
| 8 | Reboot device, then wait for next scheduled Fajr | Alarm fires (re-armed by BootReceiver) | |
| 9 | Change system time/zone | Schedule re-arms; next trigger correct | |
| 10 | Force-stop the app, then test | Alarm does **not** fire (expected OS limit) | |

## Adhan playback
| # | Scenario | Expected | Pass? |
|---|---|---|---|
| 11 | Import a custom MP3, test alarm | Imported Adhan plays | |
| 12 | No imported file | Device default alarm tone plays (no silence) | |
| 13 | Corrupt/renamed file | Falls back to device tone, keeps playing | |
| 14 | Alarm volume at 0 | Document behaviour; app does not force volume | |
| 15 | DND on (alarms allowed) | Adhan audible (USAGE_ALARM); app doesn't override DND | |

## AI recognition (bundled ML Kit model — no training)
Validate how well the **generic** model detects *your* sink. Use **AI Challenge →
Test recognition** and read the on-screen labels/confidences after each capture.

| # | Scenario | Expected | Pass? |
|---|---|---|---|
| 16 | Your actual bathroom sink + faucet, well lit, ~0.5–1 m | `Sink` with high confidence → SINK_DETECTED ≥ threshold → Adhan stops | |
| 17 | A kitchen sink | `Sink` label appears (expected); informs your threshold | |
| 18 | Unrelated bathroom scene (no sink in frame, e.g. mirror/wall) | `Sink` absent or low → SINK_NOT_DETECTED → Adhan continues | |
| 19 | An image with no sink at all (random object) | SINK_NOT_DETECTED | |
| 20 | Far away / dim / partial sink | `Sink` present but below threshold → LOW_CONFIDENCE ("move closer") | |
| 21 | Different lighting (night/lamp) and distances (0.3 m, 1 m, 2 m) | Record the `Sink` confidence at each to pick a robust threshold | |
| 22 | Camera permission denied | Clear message; emergency stop still available | |
| 23 | Diagnostics OFF (default) | No challenge images left in app storage | |

**If the generic model can't reliably detect your sink:** lower the threshold only
as far as the diagnostics justify. If `Sink` confidence is consistently low or the
label rarely appears, the generic model isn't sufficient for your bathroom — the
honest recommendation is to train the **optional** custom model in `ml_training/`
rather than forcing a low threshold that would accept almost anything.

## Challenge workflow & history
| # | Scenario | Expected | Pass? |
|---|---|---|---|
| 24 | Successful verification | Recorded as VERIFIED with confidence + duration | |
| 25 | Emergency stop | Recorded as EMERGENCY_STOP (not a success) | |
| 26 | Back button during alarm | Does not dismiss the alarm (Adhan keeps playing) | |
| 27 | History/stats after several wakes | Totals, success rate, avg challenge time correct | |

## Notes
- If an alarm is late only under battery saver / Doze on a specific OEM, record
  the OEM + Android version; this is usually an OEM power-management setting, not
  a code defect (see README per-OEM guidance).
- Full-screen intent may show as a heads-up notification instead of auto-launching
  on some Android 14+ configurations — tapping it opens the alarm screen.
