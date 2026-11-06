package com.fajrwakeup.app

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import com.fajrwakeup.app.alarm.AlarmScheduler
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAlarmManager

@RunWith(RobolectricTestRunner::class)
class AlarmSchedulerTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        AlarmScheduler.clear(context)
    }

    @Test
    fun setSchedule_dropsPast_andArmsSoonestFuture() {
        val now = System.currentTimeMillis()
        val triggers = listOf(now - 10_000, now + 60_000, now + 120_000)
        AlarmScheduler.setSchedule(context, triggers, "Fajr")

        assertEquals(2, AlarmScheduler.queueCount(context))
        assertEquals(now + 60_000, AlarmScheduler.nextTrigger(context))

        val am = context.getSystemService(AlarmManager::class.java)
        val next = Shadows.shadowOf(am).peekNextScheduledAlarm()
        assertNotNull("an alarm should be scheduled", next)
        assertEquals(now + 60_000, next.triggerAtTime)
    }

    @Test
    fun setSchedule_isIdempotentReplace_noDuplicates() {
        val now = System.currentTimeMillis()
        AlarmScheduler.setSchedule(context, listOf(now + 10_000, now + 20_000), "Fajr")
        AlarmScheduler.setSchedule(context, listOf(now + 30_000), "Fajr")

        // The second call replaces the first; only the new set remains.
        assertEquals(1, AlarmScheduler.queueCount(context))
        assertEquals(now + 30_000, AlarmScheduler.nextTrigger(context))
    }

    @Test
    fun clear_removesEverything() {
        val now = System.currentTimeMillis()
        AlarmScheduler.setSchedule(context, listOf(now + 10_000), "Fajr")
        AlarmScheduler.clear(context)

        assertEquals(0, AlarmScheduler.queueCount(context))
        assertNull(AlarmScheduler.nextTrigger(context))
    }

    /**
     * Below Android 12 (API 31) there is no exact-alarm permission, so
     * canScheduleExact() is unconditionally true. Pinned to a pre-S SDK, which is
     * exactly the regime this assertion describes.
     */
    @Test
    @Config(sdk = [Build.VERSION_CODES.O])
    fun canScheduleExact_defaultTrue() {
        assertTrue(AlarmScheduler.canScheduleExact(context))
    }

    /**
     * On Android 12+ (API 31+), canScheduleExact() must reflect the real
     * AlarmManager.canScheduleExactAlarms() permission state — true when granted,
     * false when not. (Robolectric defaults this to false at API 34, which is why
     * asserting an unconditional "true" there previously failed — the production
     * code was correct; the old test's assumption was not.)
     */
    @Test
    @Config(sdk = [Build.VERSION_CODES.TIRAMISU])
    fun canScheduleExact_android12Plus_reflectsPermission() {
        // Robolectric's backing field is static; set it on the class (Kotlin can't
        // call a Java static via an instance). @Resetter restores false per test.
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        assertTrue(AlarmScheduler.canScheduleExact(context))

        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        assertFalse(AlarmScheduler.canScheduleExact(context))
    }
}
