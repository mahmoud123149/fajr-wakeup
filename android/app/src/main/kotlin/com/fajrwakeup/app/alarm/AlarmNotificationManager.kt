package com.fajrwakeup.app.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.fajrwakeup.app.Constants
import com.fajrwakeup.app.R
import com.fajrwakeup.app.activity.AlarmActivity

/**
 * Owns the alarm notification channel and builds the high-priority alarm
 * notification that carries the full-screen intent to [AlarmActivity].
 */
object AlarmNotificationManager {

    fun ensureChannel(context: Context) {
        // minSdk is 26, so a channel is always required and always available.
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(Constants.NOTIF_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            Constants.NOTIF_CHANNEL_ID,
            context.getString(R.string.alarm_notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.alarm_notification_channel_desc)
            setBypassDnd(false)          // honour the user's Do Not Disturb choice
            enableLights(true)
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            // We drive audio through ExoPlayer (USAGE_ALARM), so the channel itself
            // is silent to avoid a double sound.
            setSound(null, null)
        }
        nm.createNotificationChannel(channel)
    }

    /** True if the OS will honour our full-screen intent (Android 14+ gates this). */
    fun canUseFullScreen(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val nm = context.getSystemService(NotificationManager::class.java)
        return nm.canUseFullScreenIntent()
    }

    fun buildAlarmNotification(context: Context, scheduledMillis: Long): Notification {
        ensureChannel(context)

        val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra(Constants.EXTRA_SCHEDULED, scheduledMillis)
            putExtra(Constants.EXTRA_TRIGGERED, System.currentTimeMillis())
        }
        val pi = PendingIntent.getActivity(
            context,
            Constants.SHOW_INTENT_REQUEST_CODE,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(context, Constants.NOTIF_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(context.getString(R.string.alarm_title))
            .setContentText(context.getString(R.string.alarm_message))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(pi)
            // Heads-up fallback uses the same intent as content; full-screen is
            // attempted when the OS permits it.
            .setFullScreenIntent(pi, true)

        return builder.build()
    }
}
