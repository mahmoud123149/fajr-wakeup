package com.fajrwakeup.app

import com.fajrwakeup.app.bridge.AlarmBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter host for the normal app UI. Registers the native alarm/AI MethodChannel.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.METHOD_CHANNEL)
            .setMethodCallHandler(AlarmBridge(this))
    }
}
