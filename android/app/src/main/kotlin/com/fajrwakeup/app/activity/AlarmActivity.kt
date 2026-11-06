package com.fajrwakeup.app.activity

import android.Manifest
import android.app.KeyguardManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.fajrwakeup.app.Constants
import com.fajrwakeup.app.R
import com.fajrwakeup.app.ai.FaucetVerifier
import com.fajrwakeup.app.service.AdhanPlaybackService
import com.fajrwakeup.app.util.WakeEventStore
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The native, full-screen alarm experience shown over the lockscreen. It drives the
 * entire challenge workflow and is the ONLY place that can stop the Adhan (successful
 * AI verification or an explicit emergency stop).
 *
 * The camera is opened only from an explicit user tap — never from the background.
 */
class AlarmActivity : AppCompatActivity() {

    // Views
    private lateinit var alarmContainer: View
    private lateinit var cameraContainer: View
    private lateinit var clockText: TextView
    private lateinit var playbackStatusText: TextView
    private lateinit var resultText: TextView
    private lateinit var previewView: PreviewView
    private lateinit var cameraStatusText: TextView
    private lateinit var diagnosticsText: TextView
    private lateinit var cameraProgress: ProgressBar
    private lateinit var captureButton: Button

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var verifier: FaucetVerifier

    private var scheduledMillis = 0L
    private var triggeredMillis = 0L
    private var testMode = false
    private var attempts = 0
    private var resolved = false

    private var imageCapture: ImageCapture? = null
    private var cameraProvider: ProcessCameraProvider? = null

    // Force Arabic UI regardless of device locale.
    override fun attachBaseContext(newBase: Context) {
        val locale = Locale("ar")
        Locale.setDefault(locale)
        val config = Configuration(newBase.resources.configuration)
        config.setLocale(locale)
        config.setLayoutDirection(locale)
        super.attachBaseContext(newBase.createConfigurationContext(config))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockscreen()
        setContentView(R.layout.activity_alarm)

        verifier = FaucetVerifier(applicationContext)

        scheduledMillis = intent.getLongExtra(Constants.EXTRA_SCHEDULED, 0L)
        triggeredMillis = intent.getLongExtra(Constants.EXTRA_TRIGGERED, System.currentTimeMillis())
        testMode = intent.getBooleanExtra(Constants.EXTRA_TEST_MODE, false)

        bindViews()
        updateClock()

        if (testMode) {
            // Test-recognition flow from AI settings: no Adhan, open the camera straight away.
            playbackStatusText.visibility = View.GONE
            findViewById<Button>(R.id.emergencyStopButton).text = getString(R.string.alarm_cancel)
            openChallenge()
        }
    }

    private fun bindViews() {
        alarmContainer = findViewById(R.id.alarmContainer)
        cameraContainer = findViewById(R.id.cameraContainer)
        clockText = findViewById(R.id.clockText)
        playbackStatusText = findViewById(R.id.playbackStatusText)
        resultText = findViewById(R.id.resultText)
        previewView = findViewById(R.id.previewView)
        cameraStatusText = findViewById(R.id.cameraStatusText)
        diagnosticsText = findViewById(R.id.diagnosticsText)
        cameraProgress = findViewById(R.id.cameraProgress)
        captureButton = findViewById(R.id.captureButton)

        findViewById<Button>(R.id.openChallengeButton).setOnClickListener { openChallenge() }
        findViewById<Button>(R.id.emergencyStopButton).setOnClickListener {
            if (testMode) finish() else emergencyStop()
        }
        captureButton.setOnClickListener { capture() }
        findViewById<Button>(R.id.cancelCameraButton).setOnClickListener { showAlarmView() }

        // Keep the clock ticking.
        handler.post(object : Runnable {
            override fun run() {
                updateClock()
                handler.postDelayed(this, 1_000L)
            }
        })
    }

    private fun updateClock() {
        if (::clockText.isInitialized) {
            clockText.text = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        }
    }

    // ----------------------------- Challenge flow -----------------------------

    private fun openChallenge() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), REQ_CAMERA)
            return
        }
        showCameraView()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                showCameraView()
            } else {
                resultText.visibility = View.VISIBLE
                resultText.text = getString(R.string.alarm_camera_denied)
            }
        }
    }

    private fun showAlarmView() {
        cameraContainer.visibility = View.GONE
        alarmContainer.visibility = View.VISIBLE
        runCatching { cameraProvider?.unbindAll() }
    }

    private fun showCameraView() {
        alarmContainer.visibility = View.GONE
        cameraContainer.visibility = View.VISIBLE
        cameraStatusText.text = getString(R.string.alarm_camera_instruction)
        diagnosticsText.text = ""
        cameraProgress.visibility = View.GONE
        captureButton.isEnabled = true
        startCamera()
    }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .build()
                provider.unbindAll()
                provider.bindToLifecycle(
                    this, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageCapture,
                )
            } catch (t: Throwable) {
                cameraStatusText.text = getString(R.string.alarm_error)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun capture() {
        val capture = imageCapture ?: return
        captureButton.isEnabled = false
        cameraProgress.visibility = View.VISIBLE
        cameraStatusText.text = getString(R.string.alarm_verifying)
        attempts++

        capture.takePicture(
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(image: ImageProxy) {
                    val bitmap = try {
                        imageProxyToBitmap(image)
                    } catch (t: Throwable) {
                        null
                    } finally {
                        image.close()
                    }
                    if (bitmap == null) {
                        onVerifyFinished(getString(R.string.alarm_error), success = false)
                        return
                    }
                    maybeSaveDiagnostic(bitmap)
                    runVerification(bitmap)
                }

                override fun onError(exception: ImageCaptureException) {
                    onVerifyFinished(getString(R.string.alarm_error), success = false)
                }
            },
        )
    }

    private fun runVerification(bitmap: Bitmap) {
        val threshold = prefs().getFloat(Constants.KEY_CONFIDENCE, Constants.DEFAULT_CONFIDENCE)
        lifecycleScope.launch {
            val result = verifier.verify(bitmap, threshold)
            diagnosticsText.text = formatDiagnostics(result.labels)
            when (result.state) {
                FaucetVerifier.State.SINK_DETECTED ->
                    onVerificationSuccess(result.confidence)
                FaucetVerifier.State.LOW_CONFIDENCE ->
                    onVerifyFinished(getString(R.string.alarm_low_confidence), success = false)
                FaucetVerifier.State.SINK_NOT_DETECTED ->
                    onVerifyFinished(getString(R.string.alarm_rejected), success = false)
                else -> // LABELER_ERROR / unexpected
                    onVerifyFinished(getString(R.string.alarm_error), success = false)
            }
        }
    }

    /** Top labels + confidences for the diagnostic/debug view. */
    private fun formatDiagnostics(labels: List<FaucetVerifier.LabelHit>): String {
        if (labels.isEmpty()) return getString(R.string.alarm_no_labels)
        return labels.take(6).joinToString("\n") {
            "${it.text}: ${(it.confidence * 100).toInt()}%"
        }
    }

    private fun onVerifyFinished(message: String, success: Boolean) {
        cameraProgress.visibility = View.GONE
        captureButton.isEnabled = true
        cameraStatusText.text = message
        if (!success) {
            // Keep the Adhan running; let the user retake.
            captureButton.text = getString(R.string.alarm_retake)
        }
    }

    private fun onVerificationSuccess(confidence: Float) {
        if (resolved) return
        resolved = true
        cameraProgress.visibility = View.GONE
        cameraStatusText.text = getString(R.string.alarm_success)

        if (!testMode) {
            AdhanPlaybackService.stop(this)
            WakeEventStore.append(
                context = applicationContext,
                scheduledTimeMillis = scheduledMillis,
                triggeredTimeMillis = triggeredMillis,
                resolvedTimeMillis = System.currentTimeMillis(),
                outcome = WakeEventStore.OUTCOME_VERIFIED,
                confidence = confidence,
                attempts = attempts,
            )
        }
        // Let the success message linger briefly, then close.
        handler.postDelayed({ finish() }, 4_000L)
    }

    private fun emergencyStop() {
        if (resolved) return
        resolved = true
        AdhanPlaybackService.stop(this)
        WakeEventStore.append(
            context = applicationContext,
            scheduledTimeMillis = scheduledMillis,
            triggeredTimeMillis = triggeredMillis,
            resolvedTimeMillis = System.currentTimeMillis(),
            outcome = WakeEventStore.OUTCOME_EMERGENCY,
            confidence = null,
            attempts = attempts,
        )
        finish()
    }

    // ----------------------------- Camera helpers -----------------------------

    private fun imageProxyToBitmap(image: ImageProxy): Bitmap {
        // ImageCapture (JPEG) packs the full image into plane 0.
        val buffer = image.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalStateException("decode failed")
        val rotation = image.imageInfo.rotationDegrees
        if (rotation == 0) return decoded
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        return Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
    }

    private fun maybeSaveDiagnostic(bitmap: Bitmap) {
        // Temporary challenge images are NOT persisted unless the user opts in.
        if (!prefs().getBoolean(Constants.KEY_SAVE_DIAG, false)) return
        runCatching {
            val dir = File(filesDir, "diagnostics").apply { mkdirs() }
            val out = File(dir, "challenge_${System.currentTimeMillis()}.jpg")
            out.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        }
    }

    // ----------------------------- Window / lifecycle -----------------------------

    private fun showOverLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(KeyguardManager::class.java)
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Do not let Back silently dismiss the alarm. Back only steps out of the
        // camera; the emergency-stop button is the sanctioned way to stop.
        if (cameraContainer.visibility == View.VISIBLE && !testMode) {
            showAlarmView()
        } else if (testMode) {
            super.onBackPressed()
        }
        // else: consume (ignore) while the alarm is active.
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        runCatching { cameraProvider?.unbindAll() }
    }

    private fun prefs() = getSharedPreferences(Constants.PREFS, Context.MODE_PRIVATE)

    companion object {
        private const val REQ_CAMERA = 9001
    }
}
