package com.fajrwakeup.app.ai

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.fajrwakeup.app.Constants
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * On-device sink/faucet recognition using Google ML Kit's **bundled default**
 * Image Labeling model. The model ships inside the APK, so recognition works
 * offline immediately — no custom model, no training, no downloads, no Firebase.
 *
 * IMPORTANT honesty note: the default model is a *generic* classifier. It can
 * recognise a generic "Sink" (and related labels), but it does NOT recognise your
 * specific personal faucet. A positive result only means a sink-like object is in
 * frame. There is still no "always succeed" path — if the labeler fails to init or
 * inference errors, verification cannot report success.
 */
class FaucetVerifier(@Suppress("unused") private val appContext: Context) {

    enum class State {
        LABELER_READY,
        SINK_DETECTED,
        SINK_NOT_DETECTED,
        LOW_CONFIDENCE,
        LABELER_ERROR,
    }

    data class LabelHit(val text: String, val confidence: Float, val index: Int)

    data class Result(
        val state: State,
        val confidence: Float = 0f,
        val topLabel: String? = null,
        val detail: String? = null,
        /** All returned labels (sorted desc) for the diagnostic view. */
        val labels: List<LabelHit> = emptyList(),
    )

    data class LabelerInfo(val state: State, val detail: String? = null)

    /**
     * The bundled model always ships with the app, so this simply confirms the
     * labeler can be constructed (it never needs a download or a model file).
     */
    fun checkLabeler(): LabelerInfo = try {
        ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS).close()
        LabelerInfo(State.LABELER_READY)
    } catch (t: Throwable) {
        Log.e(TAG, "ML Kit labeler init failed", t)
        LabelerInfo(State.LABELER_ERROR, t.message)
    }

    /**
     * Run inference on a captured bitmap and classify against [threshold].
     * Suspends until ML Kit returns.
     */
    suspend fun verify(bitmap: Bitmap, threshold: Float): Result {
        val labeler = try {
            ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to build labeler", t)
            return Result(State.LABELER_ERROR, detail = t.message)
        }

        return try {
            val labels = suspendCancellableCoroutine<List<LabelHit>> { cont ->
                val image = InputImage.fromBitmap(bitmap, 0)
                labeler.process(image)
                    .addOnSuccessListener { result ->
                        cont.resume(result.map { LabelHit(it.text, it.confidence, it.index) })
                    }
                    .addOnFailureListener { e ->
                        if (cont.isActive) cont.resumeWith(kotlin.Result.failure(e))
                    }
                cont.invokeOnCancellation { runCatching { labeler.close() } }
            }
            classify(labels, threshold)
        } catch (t: Throwable) {
            Log.e(TAG, "Verification failed during inference", t)
            Result(State.LABELER_ERROR, detail = t.message)
        } finally {
            runCatching { labeler.close() }
        }
    }

    companion object {
        private const val TAG = "FaucetVerifier"

        /**
         * Pure classification of ML Kit labels against [threshold]. Extracted so it
         * can be unit-tested without the ML Kit runtime. Only the explicit "Sink"
         * label counts toward success — "Bathroom" (or anything else) alone is NOT
         * accepted.
         */
        fun classify(
            labels: List<LabelHit>,
            threshold: Float,
            targetLabel: String = Constants.TARGET_LABEL,
        ): Result {
            val sorted = labels.sortedByDescending { it.confidence }
            val top = sorted.firstOrNull()?.text
            val sink = sorted.firstOrNull { it.text.equals(targetLabel, ignoreCase = true) }
            val sinkConf = sink?.confidence ?: 0f

            return when {
                sink != null && sinkConf >= threshold ->
                    Result(State.SINK_DETECTED, sinkConf, top, labels = sorted)
                sink != null ->
                    Result(State.LOW_CONFIDENCE, sinkConf, top, "below threshold ($threshold)", sorted)
                else ->
                    Result(State.SINK_NOT_DETECTED, 0f, top, labels = sorted)
            }
        }
    }
}
