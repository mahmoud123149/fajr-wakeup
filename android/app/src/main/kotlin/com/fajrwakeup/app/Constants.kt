package com.fajrwakeup.app

/**
 * Single source of truth for identifiers shared across the native alarm stack
 * and the Flutter bridge. Keep these in sync with the Dart side
 * (lib/core/platform/alarm_bridge.dart).
 */
object Constants {
    // MethodChannel name (must match AlarmBridge on the Dart side).
    const val METHOD_CHANNEL = "com.fajrwakeup.app/alarm"

    // SharedPreferences
    const val PREFS = "fajr_alarm_prefs"
    const val KEY_QUEUE = "schedule_queue"           // CSV of future trigger epoch-millis
    const val KEY_LABEL = "alarm_label"
    const val KEY_ACTIVE = "alarm_active"
    const val KEY_REPEAT_INTERVAL = "repeat_interval_seconds"
    const val KEY_ADHAN_PATH = "adhan_file_path"
    const val KEY_CONFIDENCE = "confidence_threshold"
    const val KEY_SAVE_DIAG = "save_diagnostic_images"

    // AlarmManager / PendingIntent request codes.
    const val ALARM_REQUEST_CODE = 7001
    const val SHOW_INTENT_REQUEST_CODE = 7101

    // Notification
    const val NOTIF_CHANNEL_ID = "fajr_alarm_channel"
    const val NOTIF_ID = 42

    // Recognition (ML Kit bundled default image-labeling model).
    // The default model exposes a generic "Sink" label; that is our target.
    const val TARGET_LABEL = "Sink"
    const val DEFAULT_CONFIDENCE = 0.70f                 // tune via the diagnostic view

    // Playback
    const val DEFAULT_REPEAT_INTERVAL_SECONDS = 20       // gap after a full Adhan before repeating

    // Native -> Flutter wake event hand-off file (JSON lines) in filesDir.
    const val WAKE_EVENTS_FILE = "pending_wake_events.jsonl"

    // Intent extras / actions
    const val EXTRA_SCHEDULED = "scheduled_time_millis"
    const val EXTRA_TRIGGERED = "triggered_time_millis"
    const val EXTRA_LABEL = "label"
    const val EXTRA_TEST_MODE = "test_mode"
    const val ACTION_START = "com.fajrwakeup.app.action.START_ADHAN"
    const val ACTION_STOP = "com.fajrwakeup.app.action.STOP_ADHAN"
}
