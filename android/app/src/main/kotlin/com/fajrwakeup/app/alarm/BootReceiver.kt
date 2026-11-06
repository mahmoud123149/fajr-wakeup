package com.fajrwakeup.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * AlarmManager alarms are cleared on reboot and can shift on time/zone changes.
 * This receiver only RE-ARMS the next future alarm from the persisted queue.
 *
 * It deliberately does NOT start the playback foreground service: launching a
 * mediaPlayback FGS from BOOT_COMPLETED is disallowed on modern Android, and there
 * is nothing to play at boot time anyway.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.i(TAG, "Re-arming alarms after ${intent.action}")
                AlarmScheduler.refreshArm(context)
            }
        }
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
