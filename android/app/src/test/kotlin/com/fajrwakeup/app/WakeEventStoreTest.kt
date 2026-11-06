package com.fajrwakeup.app

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fajrwakeup.app.util.WakeEventStore
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File

@RunWith(RobolectricTestRunner::class)
class WakeEventStoreTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Before
    fun clean() {
        File(context.filesDir, Constants.WAKE_EVENTS_FILE).delete()
    }

    @Test
    fun append_writesOneJsonLinePerEvent() {
        WakeEventStore.append(
            context = context,
            scheduledTimeMillis = 1000L,
            triggeredTimeMillis = 1002L,
            resolvedTimeMillis = 1122L,
            outcome = WakeEventStore.OUTCOME_VERIFIED,
            confidence = 0.91f,
            attempts = 2,
        )
        WakeEventStore.append(
            context = context,
            scheduledTimeMillis = 2000L,
            triggeredTimeMillis = 2002L,
            resolvedTimeMillis = 2050L,
            outcome = WakeEventStore.OUTCOME_EMERGENCY,
            confidence = null,
            attempts = 0,
        )

        val lines = File(context.filesDir, Constants.WAKE_EVENTS_FILE).readLines()
            .filter { it.isNotBlank() }
        assertEquals(2, lines.size)

        val first = JSONObject(lines[0])
        assertEquals(1000L, first.getLong("scheduledTimeMillis"))
        assertEquals("VERIFIED", first.getString("outcome"))
        assertEquals(2, first.getInt("attempts"))
        assertTrue(first.getDouble("confidence") > 0.9)

        val second = JSONObject(lines[1])
        assertEquals("EMERGENCY_STOP", second.getString("outcome"))
        assertTrue(!second.has("confidence") || second.isNull("confidence"))
    }
}
