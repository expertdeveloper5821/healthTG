import 'package:demo_p/features/screencast/platform/screencast_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Low-level bridge to the Android platform channel.
/// All platform calls are funnelled through here so the rest of the
/// Dart code never touches MethodChannel directly.
class ScreenCastPlatformService {
  static const _method = MethodChannel(ScreenCastChannel.methodChannel);
  static const _event = EventChannel(ScreenCastChannel.eventChannel);

  // ── Method calls ──────────────────────────────────────────────────────────

  /// Starts Wi-Fi display / MediaRouter discovery on the native side.
  Future<bool> startDiscovery() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.startDiscovery,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] startDiscovery error: ${e.message}');
      return false;
    }
  }

  /// Stops ongoing discovery to save battery.
  Future<bool> stopDiscovery() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.stopDiscovery,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] stopDiscovery error: ${e.message}');
      return false;
    }
  }

  /// Asks Android to connect to [deviceId] via MediaRouter.
  Future<bool> connectDevice(String deviceId) async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.connectDevice,
        {'deviceId': deviceId},
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] connectDevice error: ${e.message}');
      return false;
    }
  }

  /// Disconnects any active screen cast route.
  Future<bool> disconnectDevice() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.disconnectDevice,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] disconnectDevice error: ${e.message}');
      return false;
    }
  }

  /// Returns a map with permission statuses: {hasLocation, hasNearbyWifi}.
  Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _method.invokeMethod<Map>(
        ScreenCastChannel.checkPermissions,
      );
      if (result == null) return {'hasLocation': false, 'hasNearbyWifi': false};
      return {
        'hasLocation': result['hasLocation'] as bool? ?? false,
        'hasNearbyWifi': result['hasNearbyWifi'] as bool? ?? false,
      };
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] checkPermissions error: ${e.message}');
      return {'hasLocation': false, 'hasNearbyWifi': false};
    }
  }

  Future<Map<String, dynamic>> checkWiredDisplay() async {
    try {
      final result = await _method.invokeMethod<Map>(
        ScreenCastChannel.checkWiredDisplay,
      );
      if (result == null) return {'isConnected': false};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] checkWiredDisplay error: ${e.message}');
      return {'isConnected': false};
    }
  }

  Future<bool> startWiredDisplayMonitoring() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.startWiredDisplayMonitoring,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] startWiredDisplayMonitoring error: ${e.message}');
      return false;
    }
  }

  /// Queries the native side for the currently selected cast route.
  /// Returns a connectionChanged-style map regardless of event stream state.
  Future<Map<String, dynamic>> checkConnectionStatus() async {
    try {
      final result = await _method.invokeMethod<Map>(
        ScreenCastChannel.checkConnectionStatus,
      );
      if (result == null) {
        return {'type': 'connectionChanged', 'isConnected': false, 'deviceId': ''};
      }
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] checkConnectionStatus error: ${e.message}');
      return {'type': 'connectionChanged', 'isConnected': false, 'deviceId': ''};
    }
  }

  /// Switches native MediaRouter from active-scan to passive-monitor mode.
  /// The callback stays registered so onRouteUnselected fires on disconnect.
  Future<bool> switchToMonitoringMode() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.switchToMonitoringMode,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] switchToMonitoringMode error: ${e.message}');
      return false;
    }
  }

  /// Launches the device's native system cast/screen-mirroring picker.
  /// Returns true if a system UI was successfully opened, false if no
  /// compatible intent was found (caller should fall back to custom discovery).
  Future<bool> launchSystemCastPicker() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.launchSystemCastPicker,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] launchSystemCastPicker error: ${e.message}');
      return false;
    }
  }

  Future<bool> stopWiredDisplayMonitoring() async {
    try {
      final ok = await _method.invokeMethod<bool>(
        ScreenCastChannel.stopWiredDisplayMonitoring,
      );
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ScreenCast] stopWiredDisplayMonitoring error: ${e.message}');
      return false;
    }
  }

  // ── Event stream ──────────────────────────────────────────────────────────

  /// Broadcasts device-found, device-lost, connection-state, and wired-display events
  /// from the native MediaRouter and DisplayManager listeners.
  Stream<Map<String, dynamic>> get deviceEvents {
    return _event.receiveBroadcastStream().map((raw) {
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{};
    });
  }
}
