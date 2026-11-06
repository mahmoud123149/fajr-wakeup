package com.fajrwakeup.app.util

import android.content.Context
import android.util.Log
import com.fajrwakeup.app.Constants
import org.json.JSONObject
import java.io.File

/**
 * The native alarm stack and Flutter own different storage:
 *  - Flutter owns the SQLite history database.
 *  - Native code runs at alarm time, often when the Flutter engine is not alive.
 *
 * To avoid cross-process SQLite coupling, native code appends one JSON object per
 * line to a hand-off file in filesDir. On next launch/resume, Flutter drains this
 * file into SQLite and truncates it (see WakeEventImportService on the Dart side).
 */
object WakeEventStore {
    private const val TAG = "WakeEventStore"

    /** Outcome values mirrored by the Dart WakeOutcome enum. */
    const val OUTCOME_VERIFIED = "VERIFIED"
    const val OUTCOME_EMERGENCY = "EMERGENCY_STOP"
    const val OUTCOME_TRIGGERED = "TRIGGERED"   // alarm fired; not yet resolved

    @Synchronized
    fun append(
        context: Context,
        scheduledTimeMillis: Long,
        triggeredTimeMillis: Long,
        resolvedTimeMillis: Long?,
        outcome: String,
        confidence: Float?,
        attempts: Int,
    ) {
        try {
            val obj = JSONObject().apply {
                put("scheduledTimeMillis", scheduledTimeMillis)
                put("triggeredTimeMillis", triggeredTimeMillis)
                if (resolvedTimeMillis != null) put("resolvedTimeMillis", resolvedTimeMillis)
                put("outcome", outcome)
                if (confidence != null) put("confidence", confidence.toDouble())
                put("attempts", attempts)
                put("recordedAt", System.currentTimeMillis())
            }
            val file = File(context.filesDir, Constants.WAKE_EVENTS_FILE)
            file.appendText(obj.toString() + "\n")
        } catch (t: Throwable) {
            // Never let history bookkeeping crash the alarm flow.
            Log.e(TAG, "Failed to append wake event", t)
        }
    }
}
