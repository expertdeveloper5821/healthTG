package com.example.demo_p

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.media.MediaRouter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

/**
 * Handles wireless display discovery and connection via MediaRouter (ROUTE_TYPE_LIVE_VIDEO).
 * Casts only app content — no system screen mirroring.
 * Events are pushed to Flutter via an EventChannel sink.
 */
class ScreenCastManager(
    private val context: Context,
) {
    companion object {
        private const val TAG = "ScreenCastManager"
    }

    @Suppress("DEPRECATION")
    private val mediaRouter =
        context.getSystemService(Context.MEDIA_ROUTER_SERVICE) as MediaRouter

    private val mainHandler = Handler(Looper.getMainLooper())

    var eventSink: EventChannel.EventSink? = null

    private val discoveredRoutes = mutableMapOf<String, MediaRouter.RouteInfo>()
    private var selectedRoute: MediaRouter.RouteInfo? = null
    private var isDiscovering = false

    private var wiredDisplayListener: DisplayManager.DisplayListener? = null
    private var displayManager: DisplayManager? = null
    // Tracks display IDs confirmed to be physical wired connections so that
    // onDisplayRemoved only fires events for cable disconnections, not
    // WiFi-display or virtual-display removals.
    private val monitoredWiredDisplayIds = mutableSetOf<Int>()

    @Suppress("DEPRECATION")
    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) {
            if (!isLiveVideoRoute(route)) return
            val id = routeId(route)
            discoveredRoutes[id] = route
            Log.d(TAG, "Route added: $id name=${route.name}")
            sendEvent(
                mapOf(
                    "type" to "deviceFound",
                    "deviceId" to id,
                    "deviceName" to route.name.toString(),
                    "deviceType" to routeType(route),
                    "description" to (route.description?.toString() ?: "Wireless Display"),
                    "isAvailable" to true,
                )
            )
        }

        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) {
            val id = routeId(route)
            discoveredRoutes.remove(id)
            Log.d(TAG, "Route removed: $id")
            sendEvent(mapOf("type" to "deviceLost", "deviceId" to id))
        }

        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) {
            val id = routeId(route)
            discoveredRoutes[id] = route
        }

        override fun onRouteGrouped(
            router: MediaRouter,
            route: MediaRouter.RouteInfo,
            group: MediaRouter.RouteGroup,
            index: Int,
        ) {
            if (!isLiveVideoRoute(route)) return
            discoveredRoutes[routeId(route)] = route
        }

        override fun onRouteUngrouped(
            router: MediaRouter,
            route: MediaRouter.RouteInfo,
            group: MediaRouter.RouteGroup,
        ) {
            if (!isLiveVideoRoute(route)) return
            discoveredRoutes[routeId(route)] = route
        }

        override fun onRouteVolumeChanged(router: MediaRouter, route: MediaRouter.RouteInfo) {
            if (!isLiveVideoRoute(route)) return
            discoveredRoutes[routeId(route)] = route
        }

        override fun onRouteSelected(
            router: MediaRouter,
            type: Int,
            route: MediaRouter.RouteInfo,
        ) {
            if (!isLiveVideoRoute(route)) return
            selectedRoute = route
            val id = routeId(route)
            Log.d(TAG, "Route selected: $id")
            sendEvent(
                mapOf(
                    "type" to "connectionChanged",
                    "isConnected" to true,
                    "deviceId" to id,
                    "deviceName" to route.name.toString(),
                    "deviceType" to routeType(route),
                    "description" to (route.description?.toString() ?: "Wireless Display"),
                    "isAvailable" to true,
                )
            )
        }

        override fun onRouteUnselected(
            router: MediaRouter,
            type: Int,
            route: MediaRouter.RouteInfo,
        ) {
            if (!isLiveVideoRoute(route)) return
            selectedRoute = null
            Log.d(TAG, "Route unselected: ${routeId(route)}")
            sendEvent(
                mapOf(
                    "type" to "connectionChanged",
                    "isConnected" to false,
                    "deviceId" to routeId(route),
                )
            )
        }
    }

    @Suppress("DEPRECATION")
    fun startDiscovery(): Boolean {
        return try {
            if (!isDiscovering) {
                mediaRouter.addCallback(
                    MediaRouter.ROUTE_TYPE_LIVE_VIDEO,
                    routerCallback,
                    MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN,
                )
                isDiscovering = true
            }
            // Emit routes the router already knows about before active scan finds new ones.
            val count = mediaRouter.routeCount
            for (i in 0 until count) {
                val route = mediaRouter.getRouteAt(i)
                if (isLiveVideoRoute(route)) routerCallback.onRouteAdded(mediaRouter, route)
            }
            Log.d(TAG, "Discovery started (existing routes: $count)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "startDiscovery failed", e)
            false
        }
    }

    @Suppress("DEPRECATION")
    fun stopDiscovery(): Boolean {
        return try {
            if (isDiscovering) {
                mediaRouter.removeCallback(routerCallback)
                isDiscovering = false
            }
            Log.d(TAG, "Discovery stopped")
            true
        } catch (e: Exception) {
            Log.e(TAG, "stopDiscovery failed", e)
            false
        }
    }

    @Suppress("DEPRECATION")
    fun connectDevice(deviceId: String): Boolean {
        val route = discoveredRoutes[deviceId] ?: run {
            Log.w(TAG, "connectDevice: route $deviceId not found in cache")
            return false
        }
        return try {
            mediaRouter.selectRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, route)
            true
        } catch (e: Exception) {
            Log.e(TAG, "connectDevice failed", e)
            sendEvent(
                mapOf(
                    "type" to "error",
                    "message" to (e.message ?: "Connection failed"),
                )
            )
            false
        }
    }

    @Suppress("DEPRECATION")
    fun disconnectDevice(): Boolean {
        return try {
            val routeBeforeDisconnect = selectedRoute
            if (routeBeforeDisconnect != null) {
                val default_ = mediaRouter.defaultRoute
                mediaRouter.selectRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, default_)
                selectedRoute = null
                sendEvent(
                    mapOf(
                        "type" to "connectionChanged",
                        "isConnected" to false,
                        "deviceId" to routeId(routeBeforeDisconnect),
                    )
                )
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "disconnectDevice failed", e)
            false
        }
    }

    fun checkWiredDisplay(): Map<String, Any?> {
        return try {
            val dm = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val wired = dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                .filter { isWiredPhysicalDisplay(it) }
            mapOf(
                "isConnected" to wired.isNotEmpty(),
                "displayName" to (wired.firstOrNull()?.name ?: null),
                "displayCount" to wired.size,
            )
        } catch (e: Exception) {
            Log.e(TAG, "checkWiredDisplay failed", e)
            mapOf("isConnected" to false)
        }
    }

    fun startWiredDisplayMonitoring(): Boolean {
        return try {
            val dm = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            displayManager = dm

            // Seed the tracked set with any wired displays already connected.
            dm.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                .filter { isWiredPhysicalDisplay(it) }
                .forEach { monitoredWiredDisplayIds.add(it.displayId) }

            val listener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) {
                    val display = dm.getDisplay(displayId) ?: return
                    if (!isWiredPhysicalDisplay(display)) return
                    monitoredWiredDisplayIds.add(displayId)
                    Log.d(TAG, "Wired display added: $displayId name=${display.name}")
                    sendEvent(
                        mapOf(
                            "type" to "wiredDisplayChanged",
                            "isConnected" to true,
                            "displayName" to (display.name ?: "External Display"),
                        )
                    )
                }

                override fun onDisplayRemoved(displayId: Int) {
                    // Only react if this was a tracked wired display.
                    if (!monitoredWiredDisplayIds.remove(displayId)) return
                    Log.d(TAG, "Wired display removed: $displayId")
                    // Only report disconnection when no physical wired displays remain.
                    if (monitoredWiredDisplayIds.isEmpty()) {
                        sendEvent(
                            mapOf(
                                "type" to "wiredDisplayChanged",
                                "isConnected" to false,
                                "displayId" to displayId,
                            )
                        )
                    }
                }

                override fun onDisplayChanged(displayId: Int) {}
            }
            wiredDisplayListener = listener
            dm.registerDisplayListener(listener, mainHandler)
            Log.d(TAG, "Wired display monitoring started (tracking ${monitoredWiredDisplayIds.size} wired display(s))")
            true
        } catch (e: Exception) {
            Log.e(TAG, "startWiredDisplayMonitoring failed", e)
            false
        }
    }

    fun stopWiredDisplayMonitoring(): Boolean {
        return try {
            wiredDisplayListener?.let { displayManager?.unregisterDisplayListener(it) }
            wiredDisplayListener = null
            displayManager = null
            monitoredWiredDisplayIds.clear()
            Log.d(TAG, "Wired display monitoring stopped")
            true
        } catch (e: Exception) {
            Log.e(TAG, "stopWiredDisplayMonitoring failed", e)
            false
        }
    }

    fun checkPermissions(): Map<String, Boolean> {
        val hasLocation = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

        val hasNearbyWifi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.NEARBY_WIFI_DEVICES,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            hasLocation
        }

        return mapOf(
            "hasLocation" to hasLocation,
            "hasNearbyWifi" to hasNearbyWifi,
        )
    }

    /**
     * Returns a connectionChanged-style map reflecting the currently selected route,
     * regardless of whether the callback is registered. Safe to call at any time.
     */
    @Suppress("DEPRECATION")
    fun checkCurrentCastStatus(): Map<String, Any?> {
        return try {
            val selected = mediaRouter.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
            val isDefault = selected == null || selected == mediaRouter.defaultRoute
            if (!isDefault && isLiveVideoRoute(selected)) {
                mapOf(
                    "type" to "connectionChanged",
                    "isConnected" to true,
                    "deviceId" to routeId(selected),
                    "deviceName" to selected.name.toString(),
                    "deviceType" to routeType(selected),
                    "description" to (selected.description?.toString() ?: "Wireless Display"),
                    "isAvailable" to true,
                )
            } else {
                mapOf("type" to "connectionChanged", "isConnected" to false, "deviceId" to "")
            }
        } catch (e: Exception) {
            Log.e(TAG, "checkCurrentCastStatus failed", e)
            mapOf("type" to "connectionChanged", "isConnected" to false, "deviceId" to "")
        }
    }

    /**
     * Switches from active scanning mode to passive monitoring mode.
     * The callback stays registered (so onRouteUnselected still fires on disconnect)
     * but the active Wi-Fi scan is stopped to save battery.
     */
    @Suppress("DEPRECATION")
    fun switchToMonitoringMode(): Boolean {
        return try {
            mediaRouter.removeCallback(routerCallback)
            // Re-register without CALLBACK_FLAG_PERFORM_ACTIVE_SCAN.
            // onRouteSelected / onRouteUnselected still fire from system events.
            mediaRouter.addCallback(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, routerCallback, 0)
            isDiscovering = false
            Log.d(TAG, "Switched to monitoring mode (passive)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "switchToMonitoringMode failed", e)
            false
        }
    }

    /**
     * Pushes the current route status through the event sink.
     * Called from MainActivity.onResume so Flutter can re-sync state after
     * returning from the system cast picker.
     */
    fun emitCurrentStatus() {
        sendEvent(checkCurrentCastStatus())
    }

    @Suppress("DEPRECATION")
    fun dispose() {
        try { mediaRouter.removeCallback(routerCallback) } catch (_: Exception) {}
        stopWiredDisplayMonitoring()
        discoveredRoutes.clear()
        selectedRoute = null
        isDiscovering = false
        eventSink = null
    }

    private fun sendEvent(payload: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(payload) }
    }

    /**
     * Returns true only for displays that represent a genuine physical wired
     * connection (HDMI, DisplayPort, USB-C Alt Mode, MHL).
     *
     * Display.getType() and the TYPE_* constants were removed from the public
     * Android SDK stubs at API 29+, so we cannot use them at compile time.
     * Instead we combine three checks that remain in the public API:
     *
     *  1. Skip the device's built-in screen (displayId == DEFAULT_DISPLAY).
     *  2. Skip displays whose state is STATE_OFF (powered off / suspended).
     *  3. Exclude displays whose name matches known wireless / virtual patterns
     *     (Miracast, WFD, Overlay, virtual display, etc.).
     *     Physical HDMI / USB-C screens report their EDID name (e.g. "LG ULTRAFINE")
     *     while programmatically created displays use recognisable prefixes.
     *  4. If a wireless cast route is currently active via MediaRouter any
     *     presentation display found is that wireless session, not a cable.
     */
    private fun isWiredPhysicalDisplay(display: Display): Boolean {
        if (display.displayId == Display.DEFAULT_DISPLAY) return false
        if (display.state == Display.STATE_OFF) return false

        val name = display.name?.lowercase() ?: return false

        val nonWiredKeywords = arrayOf(
            "virtual", "overlay", "wifi", "wfd", "widi",
            "miracast", "cast", "mirror", "wireless",
            "chromecast", "airplay", "surface", "screen share",
            "recording"
        )
        if (nonWiredKeywords.any { name.contains(it) }) return false

        // If the MediaRouter already has a non-default wireless route selected,
        // any presentation display is that wireless session — not a cable.
        @Suppress("DEPRECATION")
        val wirelessCastActive = try {
            val selected = mediaRouter.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
            selected != null && selected != mediaRouter.defaultRoute
        } catch (_: Exception) {
            false
        }
        if (wirelessCastActive) return false

        return true
    }

    @Suppress("DEPRECATION")
    private fun isLiveVideoRoute(route: MediaRouter.RouteInfo): Boolean {
        if (route == mediaRouter.defaultRoute) return false
        return (route.supportedTypes and MediaRouter.ROUTE_TYPE_LIVE_VIDEO) != 0
    }

    @Suppress("DEPRECATION")
    private fun routeId(route: MediaRouter.RouteInfo): String =
        route.tag?.toString() ?: route.name.toString().replace(" ", "_").lowercase()

    @Suppress("DEPRECATION")
    private fun routeType(route: MediaRouter.RouteInfo): String {
        val desc = route.description?.toString()?.lowercase() ?: ""
        return when {
            desc.contains("miracast") || desc.contains("wireless") -> "miracast"
            desc.contains("chromecast") || desc.contains("cast") -> "chromecast"
            else -> "miracast"
        }
    }
}
