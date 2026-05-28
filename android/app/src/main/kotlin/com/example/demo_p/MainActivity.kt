package com.example.demo_p

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenShareChannel = "com.example.demo_p/screen_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenShareChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        val intent = Intent(this, ScreenShareForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (error: Exception) {
                        Log.e("MainActivity", "Unable to start screen-share service", error)
                        result.error(
                            "SCREEN_SHARE_SERVICE_START_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                "stop" -> {
                    try {
                        stopService(Intent(this, ScreenShareForegroundService::class.java))
                        result.success(true)
                    } catch (error: Exception) {
                        Log.e("MainActivity", "Unable to stop screen-share service", error)
                        result.error(
                            "SCREEN_SHARE_SERVICE_STOP_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
