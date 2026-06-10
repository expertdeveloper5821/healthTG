package com.example.demo_p

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // ── Existing screen-share channel (video call feature) ────────────────────
    private val screenShareChannel = "com.example.demo_p/screen_share"

    // ── New screen-cast channels (Smart TV / external display feature) ─────────
    private val screenCastMethodChannel = "com.example.demo_p/screen_cast"
    private val screenCastEventChannel = "com.example.demo_p/screen_cast_events"

    private lateinit var castManager: ScreenCastManager
    private var castEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        castManager = ScreenCastManager(applicationContext)

        // ── 1. Original screen-share MethodChannel (unchanged) ────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenShareChannel,
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
                            null,
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
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── 2. Screen-cast EventChannel (device discovery events → Flutter) ───
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenCastEventChannel,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                castEventSink = sink
                castManager.eventSink = sink
            }

            override fun onCancel(arguments: Any?) {
                castEventSink = null
                castManager.eventSink = null
            }
        })

        // ── 3. Screen-cast MethodChannel (Flutter → native commands) ──────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenCastMethodChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDiscovery" -> {
                    try {
                        result.success(castManager.startDiscovery())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "startDiscovery error", e)
                        result.error("DISCOVERY_START_FAILED", e.message, null)
                    }
                }
                "stopDiscovery" -> {
                    try {
                        result.success(castManager.stopDiscovery())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "stopDiscovery error", e)
                        result.error("DISCOVERY_STOP_FAILED", e.message, null)
                    }
                }
                "connectDevice" -> {
                    try {
                        val deviceId = call.argument<String>("deviceId")
                        if (deviceId == null) {
                            result.error("MISSING_DEVICE_ID", "deviceId is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(castManager.connectDevice(deviceId))
                    } catch (e: Exception) {
                        Log.e("MainActivity", "connectDevice error", e)
                        result.error("CONNECT_FAILED", e.message, null)
                    }
                }
                "disconnectDevice" -> {
                    try {
                        result.success(castManager.disconnectDevice())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "disconnectDevice error", e)
                        result.error("DISCONNECT_FAILED", e.message, null)
                    }
                }
                "checkPermissions" -> {
                    try {
                        result.success(castManager.checkPermissions())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "checkPermissions error", e)
                        result.error("PERMISSION_CHECK_FAILED", e.message, null)
                    }
                }
                "checkWiredDisplay" -> {
                    try {
                        result.success(castManager.checkWiredDisplay())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "checkWiredDisplay error", e)
                        result.error("WIRED_CHECK_FAILED", e.message, null)
                    }
                }
                "startWiredDisplayMonitoring" -> {
                    try {
                        result.success(castManager.startWiredDisplayMonitoring())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "startWiredDisplayMonitoring error", e)
                        result.error("WIRED_MONITOR_START_FAILED", e.message, null)
                    }
                }
                "stopWiredDisplayMonitoring" -> {
                    try {
                        result.success(castManager.stopWiredDisplayMonitoring())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "stopWiredDisplayMonitoring error", e)
                        result.error("WIRED_MONITOR_STOP_FAILED", e.message, null)
                    }
                }
                "launchSystemCastPicker" -> {
                    try {
                        result.success(launchSystemCastPicker())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "launchSystemCastPicker error", e)
                        result.success(false)
                    }
                }
                "checkConnectionStatus" -> {
                    try {
                        result.success(castManager.checkCurrentCastStatus())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "checkConnectionStatus error", e)
                        result.error("STATUS_CHECK_FAILED", e.message, null)
                    }
                }
                "switchToMonitoringMode" -> {
                    try {
                        result.success(castManager.switchToMonitoringMode())
                    } catch (e: Exception) {
                        Log.e("MainActivity", "switchToMonitoringMode error", e)
                        result.error("MONITOR_MODE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-emit the current cast route status every time the app comes to the
        // foreground. This ensures Flutter syncs correctly after the user selects
        // (or disconnects) a device in the system cast picker without our app being
        // in the foreground to receive the original event.
        castManager.emitCurrentStatus()
    }

    override fun onDestroy() {
        super.onDestroy()
        castManager.dispose()
    }

    /**
     * Tries to open the device's native cast / screen-mirroring picker.
     *
     * Intent priority order:
     *  1. android.settings.CAST_SETTINGS          — Stock Android (API 21+), Pixel, Android One, most AOSP ROMs
     *  2. android.settings.WIFI_DISPLAY_SETTINGS  — Samsung One UI, older AOSP Miracast
     *  3. Samsung Smart View (component)           — Samsung Galaxy (SmartMirroring app)
     *  4. MIUI Wireless Display                   — Xiaomi / Redmi / POCO (MIUI)
     *  5. Oppo / Realme / Vivo Screen Cast        — ColorOS / FuntouchOS / RealmeUI
     *  6. Settings.ACTION_DISPLAY_SETTINGS        — Universal last-resort fallback
     *
     * Each intent is resolved against the package manager before launching so
     * we never crash with ActivityNotFoundException.
     *
     * Returns true when a UI was successfully opened, false when every candidate
     * failed (caller should show its own discovery sheet instead).
     */
    private fun launchSystemCastPicker(): Boolean {
        // Build the ordered candidate list.
        val candidates = mutableListOf<Intent>()

        // ── 1. Standard Android Cast Settings (Pixel, AOSP, Android One) ────────
        candidates += Intent("android.settings.CAST_SETTINGS")

        // ── 2. Wi-Fi Display / Miracast Settings (Samsung, many OEMs) ────────────
        candidates += Intent("android.settings.WIFI_DISPLAY_SETTINGS")

        // ── 3. Samsung Smart View / Smart Mirroring ───────────────────────────────
        candidates += Intent().apply {
            component = ComponentName(
                "com.samsung.android.smartmirroring",
                "com.samsung.android.smartmirroring.castview.CastViewActivity"
            )
        }
        // Older Samsung SmartView package name
        candidates += Intent().apply {
            component = ComponentName(
                "com.samsung.android.allshare.cast.fileshare",
                "com.samsung.android.allshare.cast.fileshare.ui.castview.CastViewActivity"
            )
        }

        // ── 4. Xiaomi / MIUI Media Router ─────────────────────────────────────────
        candidates += Intent().apply {
            component = ComponentName(
                "com.miui.mediarouter",
                "com.miui.mediarouter.ui.MediaControlActivity"
            )
        }
        // MIUI Wireless display settings (fallback for MIUI)
        candidates += Intent("miui.settings.action.WIFI_DISPLAY_SETTINGS")

        // ── 5. Oppo / Realme / OnePlus (ColorOS / OxygenOS / RealmeUI) ──────────
        candidates += Intent().apply {
            component = ComponentName(
                "com.oppo.screenmirroring",
                "com.oppo.screenmirroring.MainActivity"
            )
        }
        candidates += Intent("oneplus.settings.action.CAST_SETTINGS")

        // ── 6. Vivo (FuntouchOS / OriginOS) ──────────────────────────────────────
        candidates += Intent().apply {
            component = ComponentName(
                "com.vivo.smartshot",
                "com.vivo.smartshot.ui.activity.SmartShotActivity"
            )
        }

        // ── 7. Universal display settings fallback ────────────────────────────────
        candidates += Intent(Settings.ACTION_DISPLAY_SETTINGS)

        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.resolveActivity(
                        intent,
                        PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
                }

                if (resolved != null) {
                    startActivity(intent)
                    Log.d(
                        "MainActivity",
                        "Cast picker launched via: ${intent.action ?: intent.component}"
                    )
                    return true
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "Skipping intent (${intent.action ?: intent.component}): $e")
            }
        }

        Log.w("MainActivity", "No system cast picker available on this device — using custom discovery.")
        return false
    }
}
