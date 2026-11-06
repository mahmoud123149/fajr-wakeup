package com.fajrwakeup.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.fajrwakeup.app.Constants
import com.fajrwakeup.app.service.AdhanPlaybackService

/**
 * Fires at the scheduled Fajr time. Acting on an exact-alarm broadcast grants a
 * short-lived exemption to start a foreground service from the background, which
 * is exactly what we use here.
 */
class FajrAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val scheduled = intent.getLongExtra(Constants.EXTRA_SCHEDULED, 0L)
        val triggered = System.currentTimeMillis()
        Log.i(TAG, "Fajr alarm fired (scheduled=$scheduled)")

        // Brief wakelock to bridge until the foreground service holds its own.
        val pm = context.getSystemService(PowerManager::class.java)
        val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "fajr:receiver")
        wl.acquire(10_000L)
        try {
            val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
                action = Constants.ACTION_START
                putExtra(Constants.EXTRA_SCHEDULED, scheduled)
                putExtra(Constants.EXTRA_TRIGGERED, triggered)
            }
            ContextCompat.startForegroundService(context, serviceIntent)

            // Immediately arm the next day's alarm so the schedule keeps rolling,
            // independent of what happens in the UI.
            AlarmScheduler.refreshArm(context)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to start Adhan service", t)
        } finally {
            if (wl.isHeld) wl.release()
        }
    }

    companion object {
        private const val TAG = "FajrAlarmReceiver"
    }
}
