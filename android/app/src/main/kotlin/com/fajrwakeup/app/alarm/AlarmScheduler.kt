package com.fajrwakeup.app.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.fajrwakeup.app.Constants
import com.fajrwakeup.app.MainActivity

/**
 * Rolling, idempotent alarm scheduling.
 *
 * Flutter computes a buffer of future Fajr trigger times (epoch millis) and hands
 * the whole list to [setSchedule]. We persist the list and arm only the SOONEST
 * one with [AlarmManager.setAlarmClock] (one-shot, exact, exempt from the
 * SCHEDULE_EXACT_ALARM gate, and shows the system alarm icon).
 *
 * When that alarm fires (FajrAlarmReceiver) or the device reboots (BootReceiver),
 * [refreshArm] drops past entries and arms the next soonest one. Re-running
 * [setSchedule] cancels and replaces, so settings changes never create duplicates.
 *
 * This gives an accurate day-by-day schedule for the length of the buffer even if
 * the app is never reopened, while reopening the app refreshes it (handling DST,
 * location and method changes).
 */
object AlarmScheduler {
    private const val TAG = "AlarmScheduler"
    private const val KEY_NEXT = "next_trigger"
    private const val TEST_REQUEST_CODE = 7002

    fun setSchedule(context: Context, triggers: List<Long>, label: String) {
        val now = System.currentTimeMillis()
        val future = triggers.filter { it > now + 1_000 }.distinct().sorted()
        prefs(context).edit()
            .putString(Constants.KEY_QUEUE, future.joinToString(","))
            .putString(Constants.KEY_LABEL, label)
            .apply()
        cancel(context)
        future.firstOrNull()?.let { scheduleExact(context, it) }
        Log.i(TAG, "setSchedule: ${future.size} future triggers, next=${future.firstOrNull()}")
    }

    /** Drop past triggers, persist, and arm the soonest remaining one. */
    fun refreshArm(context: Context) {
        val now = System.currentTimeMillis()
        val remaining = readQueue(context).filter { it > now + 60_000 }.sorted()
        prefs(context).edit().putString(Constants.KEY_QUEUE, remaining.joinToString(",")).apply()
        cancel(context)
        remaining.firstOrNull()?.let { scheduleExact(context, it) }
        Log.i(TAG, "refreshArm: ${remaining.size} remaining, next=${remaining.firstOrNull()}")
    }

    fun clear(context: Context) {
        cancel(context)
        prefs(context).edit()
            .remove(Constants.KEY_QUEUE)
            .remove(KEY_NEXT)
            .apply()
    }

    /**
     * Development/test helper: fire a one-off alarm after [delaySeconds] WITHOUT
     * touching the real rolling schedule (separate PendingIntent request code).
     */
    fun scheduleTest(context: Context, delaySeconds: Int) {
        val triggerAt = System.currentTimeMillis() + delaySeconds.coerceAtLeast(1) * 1000L
        val am = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, FajrAlarmReceiver::class.java).apply {
            action = Constants.ACTION_START
            putExtra(Constants.EXTRA_SCHEDULED, triggerAt)
            putExtra(Constants.EXTRA_LABEL, "TEST")
        }
        val fire = PendingIntent.getBroadcast(
            context,
            TEST_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        runCatching {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, showPendingIntent(context)), fire)
        }.onFailure {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, fire)
        }
        Log.i(TAG, "scheduleTest in ${delaySeconds}s at $triggerAt")
    }

    fun nextTrigger(context: Context): Long? =
        readQueue(context).filter { it > System.currentTimeMillis() }.minOrNull()

    fun queueCount(context: Context): Int =
        readQueue(context).count { it > System.currentTimeMillis() }

    fun label(context: Context): String =
        prefs(context).getString(Constants.KEY_LABEL, "") ?: ""

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(AlarmManager::class.java)
        return am.canScheduleExactAlarms()
    }

    // ----------------------------------------------------------------------

    private fun scheduleExact(context: Context, triggerAtMillis: Long) {
        val am = context.getSystemService(AlarmManager::class.java)
        val fire = firePendingIntent(context, triggerAtMillis)
        val show = showPendingIntent(context)
        try {
            // setAlarmClock is exact and is NOT gated by SCHEDULE_EXACT_ALARM.
            am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, show), fire)
        } catch (se: SecurityException) {
            Log.w(TAG, "setAlarmClock denied; falling back", se)
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, fire)
            } catch (e: Exception) {
                Log.w(TAG, "setExactAndAllowWhileIdle failed; using inexact", e)
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, fire)
            }
        }
        prefs(context).edit().putLong(KEY_NEXT, triggerAtMillis).apply()
    }

    private fun cancel(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java)
        val fire = firePendingIntent(context, 0L)
        am.cancel(fire)
    }

    private fun firePendingIntent(context: Context, triggerAtMillis: Long): PendingIntent {
        val intent = Intent(context, FajrAlarmReceiver::class.java).apply {
            action = Constants.ACTION_START
            putExtra(Constants.EXTRA_SCHEDULED, triggerAtMillis)
            putExtra(Constants.EXTRA_LABEL, label(context))
        }
        // Same request code + FLAG_UPDATE_CURRENT => scheduling is idempotent.
        return PendingIntent.getBroadcast(
            context,
            Constants.ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        return PendingIntent.getActivity(
            context,
            Constants.ALARM_REQUEST_CODE + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun readQueue(context: Context): List<Long> =
        prefs(context).getString(Constants.KEY_QUEUE, "")
            ?.split(",")
            ?.mapNotNull { it.trim().toLongOrNull() }
            ?: emptyList()

    private fun prefs(context: Context) =
        context.getSharedPreferences(Constants.PREFS, Context.MODE_PRIVATE)
}
