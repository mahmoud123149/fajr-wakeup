package com.fajrwakeup.app.bridge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.fajrwakeup.app.Constants
import com.fajrwakeup.app.activity.AlarmActivity
import com.fajrwakeup.app.ai.FaucetVerifier
import com.fajrwakeup.app.alarm.AlarmScheduler
import com.fajrwakeup.app.service.AdhanPlaybackService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles all MethodChannel calls from Dart (see lib/core/platform/alarm_bridge.dart).
 * Keeps native responsibilities (scheduling, playback, model status) behind one
 * well-defined, error-handled surface.
 */
class AlarmBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val context: Context get() = activity.applicationContext

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "scheduleFajrAlarms" -> {
                    val triggers = (call.argument<List<*>>("triggers") ?: emptyList<Any>())
                        .mapNotNull { (it as? Number)?.toLong() }
                    val label = call.argument<String>("label") ?: "Fajr"
                    AlarmScheduler.setSchedule(context, triggers, label)
                    result.success(true)
                }

                "cancelFajrAlarms" -> {
                    AlarmScheduler.clear(context)
                    result.success(true)
                }

                "canScheduleExactAlarms" -> result.success(AlarmScheduler.canScheduleExact(context))

                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:${context.packageName}"),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        runCatching { context.startActivity(intent) }
                            .onFailure { context.startActivity(appDetailsIntent()) }
                        result.success(true)
                    } else {
                        result.success(true) // not applicable < Android 12
                    }
                }

                "openAppSettings" -> {
                    context.startActivity(appDetailsIntent())
                    result.success(true)
                }

                "getScheduledInfo" -> {
                    result.success(
                        mapOf(
                            "nextTriggerMillis" to AlarmScheduler.nextTrigger(context),
                            "count" to AlarmScheduler.queueCount(context),
                            "active" to isAlarmActive(),
                            "label" to AlarmScheduler.label(context),
                        ),
                    )
                }

                "startTestAlarm" -> {
                    val delay = call.argument<Int>("delaySeconds") ?: 60
                    AlarmScheduler.scheduleTest(context, delay)
                    result.success(true)
                }

                "stopAlarm" -> {
                    AdhanPlaybackService.stop(context)
                    result.success(true)
                }

                "isAlarmActive" -> result.success(isAlarmActive())

                "setPlaybackConfig" -> {
                    val interval = call.argument<Int>("repeatIntervalSeconds")
                        ?: Constants.DEFAULT_REPEAT_INTERVAL_SECONDS
                    val path = call.argument<String>("adhanFilePath")
                    prefs().edit()
                        .putInt(Constants.KEY_REPEAT_INTERVAL, interval)
                        .apply {
                            if (path == null) remove(Constants.KEY_ADHAN_PATH)
                            else putString(Constants.KEY_ADHAN_PATH, path)
                        }
                        .apply()
                    result.success(true)
                }

                "setChallengeConfig" -> {
                    val threshold = (call.argument<Double>("confidenceThreshold")
                        ?: Constants.DEFAULT_CONFIDENCE.toDouble()).toFloat()
                    val saveDiag = call.argument<Boolean>("saveDiagnosticImages") ?: false
                    prefs().edit()
                        .putFloat(Constants.KEY_CONFIDENCE, threshold)
                        .putBoolean(Constants.KEY_SAVE_DIAG, saveDiag)
                        .apply()
                    result.success(true)
                }

                "getLabelerInfo" -> {
                    val info = FaucetVerifier(context).checkLabeler()
                    result.success(
                        mapOf(
                            "state" to info.state.name,
                            "detail" to info.detail,
                        ),
                    )
                }

                "testFaucetRecognition" -> {
                    val intent = Intent(activity, AlarmActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        putExtra(Constants.EXTRA_TEST_MODE, true)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            result.error("NATIVE_ERROR", t.message, null)
        }
    }

    private fun isAlarmActive(): Boolean =
        AdhanPlaybackService.isRunning || prefs().getBoolean(Constants.KEY_ACTIVE, false)

    private fun appDetailsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun prefs() = context.getSharedPreferences(Constants.PREFS, Context.MODE_PRIVATE)
}
