package com.fajrwakeup.app

import com.fajrwakeup.app.ai.FaucetVerifier
import com.fajrwakeup.app.ai.FaucetVerifier.LabelHit
import com.fajrwakeup.app.ai.FaucetVerifier.State
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pure unit tests for the label-classification logic (no ML Kit runtime, no
 * Robolectric). Live inference against the bundled model is a device concern
 * (see docs/TESTING.md). There is intentionally no path that returns success
 * without a confident "Sink".
 */
class FaucetVerifierTest {

    @Test
    fun sinkAboveThreshold_isDetected() {
        val result = FaucetVerifier.classify(
            listOf(LabelHit("Sink", 0.84f, 0), LabelHit("Bathroom", 0.90f, 1)),
            threshold = 0.70f,
        )
        assertEquals(State.SINK_DETECTED, result.state)
        assertEquals(0.84f, result.confidence, 1e-6f)
    }

    @Test
    fun sinkBelowThreshold_isLowConfidence() {
        val result = FaucetVerifier.classify(
            listOf(LabelHit("Sink", 0.55f, 0)),
            threshold = 0.70f,
        )
        assertEquals(State.LOW_CONFIDENCE, result.state)
    }

    @Test
    fun bathroomWithoutSink_isNotDetected() {
        // "Bathroom" alone must NOT pass.
        val result = FaucetVerifier.classify(
            listOf(LabelHit("Bathroom", 0.95f, 0), LabelHit("Tile", 0.80f, 1)),
            threshold = 0.70f,
        )
        assertEquals(State.SINK_NOT_DETECTED, result.state)
    }

    @Test
    fun emptyLabels_isNotDetected() {
        val result = FaucetVerifier.classify(emptyList(), threshold = 0.70f)
        assertEquals(State.SINK_NOT_DETECTED, result.state)
    }

    @Test
    fun matchIsCaseInsensitive() {
        val result = FaucetVerifier.classify(
            listOf(LabelHit("sink", 0.9f, 0)),
            threshold = 0.70f,
        )
        assertEquals(State.SINK_DETECTED, result.state)
    }
}
