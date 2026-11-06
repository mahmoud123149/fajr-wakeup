package com.fajrwakeup.app.service

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.fajrwakeup.app.Constants
import com.fajrwakeup.app.alarm.AlarmNotificationManager
import java.io.File

/**
 * Foreground (mediaPlayback) service that plays the complete Adhan and repeats it
 * after a configurable gap, until it is explicitly stopped (successful verification
 * or emergency stop). It never cuts the Adhan off mid-playback.
 *
 * Audio uses USAGE_ALARM so it respects the device's alarm volume and the user's DND
 * policy for alarms — the app never force-overrides volume or DND.
 */
class AdhanPlaybackService : Service() {

    private var player: ExoPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var repeatRunnable: Runnable? = null
    private var stopped = false
    private var usedFallback = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            Constants.ACTION_STOP -> {
                stopEverything()
                return START_NOT_STICKY
            }
            else -> start(intent)
        }
        // If the system kills us while the alarm is unresolved, come back.
        return START_STICKY
    }

    private fun start(intent: Intent?) {
        if (isRunning) {
            Log.i(TAG, "Already running; ignoring duplicate start")
            return
        }
        isRunning = true
        stopped = false
        usedFallback = false

        val scheduled = intent?.getLongExtra(Constants.EXTRA_SCHEDULED, 0L) ?: 0L

        AlarmNotificationManager.ensureChannel(this)
        val notification = AlarmNotificationManager.buildAlarmNotification(this, scheduled)
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        } else 0
        ServiceCompat.startForeground(this, Constants.NOTIF_ID, notification, type)

        prefs().edit().putBoolean(Constants.KEY_ACTIVE, true).apply()

        initPlayer()
        playOnce()
    }

    private fun initPlayer() {
        if (player != null) return
        val exo = ExoPlayer.Builder(this).build().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_ALARM)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SONIFICATION)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            setWakeMode(C.WAKE_MODE_LOCAL) // keep CPU awake while playing (needs WAKE_LOCK)
            repeatMode = Player.REPEAT_MODE_OFF
            addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_ENDED && !stopped) {
                        scheduleRepeat()
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    Log.e(TAG, "Playback error: ${error.errorCodeName}", error)
                    if (!usedFallback) {
                        // The imported Adhan file may be missing/corrupt: fall back to
                        // the device's alarm tone so the alarm is never silent.
                        usedFallback = true
                        loadAndPlay(fallbackUri())
                    } else if (!stopped) {
                        scheduleRepeat()
                    }
                }
            })
        }
        player = exo
    }

    private fun playOnce() {
        if (stopped) return
        loadAndPlay(resolveMediaUri())
    }

    private fun loadAndPlay(uri: Uri) {
        val p = player ?: return
        try {
            p.setMediaItem(MediaItem.fromUri(uri))
            p.prepare()
            p.playWhenReady = true
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to load media $uri", t)
            if (!usedFallback) {
                usedFallback = true
                loadAndPlay(fallbackUri())
            } else {
                scheduleRepeat()
            }
        }
    }

    private fun scheduleRepeat() {
        repeatRunnable?.let { handler.removeCallbacks(it) }
        val gapSeconds = prefs()
            .getInt(Constants.KEY_REPEAT_INTERVAL, Constants.DEFAULT_REPEAT_INTERVAL_SECONDS)
            .coerceIn(0, 600)
        val r = Runnable { if (!stopped) playOnce() }
        repeatRunnable = r
        handler.postDelayed(r, gapSeconds * 1000L)
    }

    private fun resolveMediaUri(): Uri {
        val path = prefs().getString(Constants.KEY_ADHAN_PATH, null)
        if (!path.isNullOrBlank()) {
            val f = File(path)
            if (f.exists() && f.length() > 0L) return Uri.fromFile(f)
        }
        return fallbackUri()
    }

    /** Device's default alarm tone (non-copyrighted, user-owned). */
    private fun fallbackUri(): Uri =
        RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_NOTIFICATION)
            ?: Settings.System.DEFAULT_ALARM_ALERT_URI

    private fun stopEverything() {
        stopped = true
        repeatRunnable?.let { handler.removeCallbacks(it) }
        repeatRunnable = null
        player?.let {
            runCatching { it.stop() }
            runCatching { it.release() }
        }
        player = null
        isRunning = false
        prefs().edit().putBoolean(Constants.KEY_ACTIVE, false).apply()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isRunning) {
            // Ensure resources are freed if the system tears us down.
            runCatching { player?.release() }
            player = null
            isRunning = false
            prefs().edit().putBoolean(Constants.KEY_ACTIVE, false).apply()
        }
    }

    private fun prefs() = getSharedPreferences(Constants.PREFS, Context.MODE_PRIVATE)

    companion object {
        private const val TAG = "AdhanPlaybackService"

        @Volatile
        var isRunning = false
            private set

        /** Stop playback from anywhere (AlarmActivity, Flutter emergency stop). */
        fun stop(context: Context) {
            val intent = Intent(context, AdhanPlaybackService::class.java).apply {
                action = Constants.ACTION_STOP
            }
            // startService (not foreground) is fine for delivering a stop command.
            runCatching { context.startService(intent) }
        }
    }
}
