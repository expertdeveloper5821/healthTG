import 'package:demo_p/features/screencast/models/cast_device.dart';
import 'package:demo_p/features/screencast/platform/screencast_channel.dart';
import 'package:demo_p/features/screencast/services/screencast_platform_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Public event types ────────────────────────────────────────────────────────

enum CastEventKind {
  deviceFound,
  deviceLost,
  connectionChanged,
  error,
  wiredDisplayChanged,
  unknown,
}

class CastEvent {
  const CastEvent._({
    required this.kind,
    this.device,
    this.deviceId,
    this.connected,
    this.errorMessage,
  });

  factory CastEvent.deviceFound(CastDevice device) =>
      CastEvent._(kind: CastEventKind.deviceFound, device: device);

  factory CastEvent.deviceLost(String deviceId) =>
      CastEvent._(kind: CastEventKind.deviceLost, deviceId: deviceId);

  factory CastEvent.connectionChanged({
    required bool connected,
    CastDevice? device,
  }) =>
      CastEvent._(
        kind: CastEventKind.connectionChanged,
        connected: connected,
        device: device,
      );

  factory CastEvent.error(String message) =>
      CastEvent._(kind: CastEventKind.error, errorMessage: message);

  factory CastEvent.wiredDisplayChanged({
    required bool connected,
    String? displayName,
  }) =>
      CastEvent._(
        kind: CastEventKind.wiredDisplayChanged,
        connected: connected,
        device: connected
            ? CastDevice(
                id: 'wired',
                name: displayName ?? 'External Display',
                type: CastConnectionType.wired,
                description: 'HDMI / USB-C Connection',
              )
            : null,
      );

  factory CastEvent.unknown() => CastEvent._(kind: CastEventKind.unknown);

  final CastEventKind kind;
  final CastDevice? device;
  final String? deviceId;
  final bool? connected;
  final String? errorMessage;
}

// ── Permission result ─────────────────────────────────────────────────────────

enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

// ── Repository ────────────────────────────────────────────────────────────────

/// Sits between the platform service and the ViewModel.
/// Owns permission logic and translates raw platform events into typed objects.
class ScreenCastRepository {
  ScreenCastRepository({ScreenCastPlatformService? platformService})
      : _platform = platformService ?? ScreenCastPlatformService();

  final ScreenCastPlatformService _platform;

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<PermissionResult> requestRequiredPermissions() async {
    final permissions = [
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();

    final locationStatus = statuses[Permission.location];
    final nearbyStatus = statuses[Permission.nearbyWifiDevices];

    if (locationStatus == PermissionStatus.permanentlyDenied ||
        nearbyStatus == PermissionStatus.permanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    final locationGranted = locationStatus == PermissionStatus.granted ||
        locationStatus == PermissionStatus.limited;
    final nearbyGranted = nearbyStatus == PermissionStatus.granted ||
        nearbyStatus == PermissionStatus.limited;

    if (locationGranted || nearbyGranted) return PermissionResult.granted;
    return PermissionResult.denied;
  }

  Future<bool> hasRequiredPermissions() async {
    final perms = await _platform.checkPermissions();
    return (perms['hasLocation'] ?? false) || (perms['hasNearbyWifi'] ?? false);
  }

  // ── Wireless discovery ────────────────────────────────────────────────────

  Future<bool> startDiscovery() => _platform.startDiscovery();

  Future<bool> stopDiscovery() => _platform.stopDiscovery();

  /// Polls the native side for the actual current cast route and returns it
  /// as a typed [CastEvent]. Used to re-sync state after returning from the
  /// system cast picker (which may have connected/disconnected while our app
  /// was in the background and the event was not delivered).
  Future<CastEvent> checkConnectionStatus() async {
    final raw = await _platform.checkConnectionStatus();
    final connected = raw['isConnected'] as bool? ?? false;
    return CastEvent.connectionChanged(
      connected: connected,
      device: connected ? CastDevice.fromMap(raw) : null,
    );
  }

  /// Switches native discovery from active-scan to passive-monitor mode so
  /// that route-unselected callbacks still fire after a device connects.
  Future<bool> switchToMonitoringMode() => _platform.switchToMonitoringMode();

  // ── Connection ────────────────────────────────────────────────────────────

  Future<bool> connect(String deviceId) => _platform.connectDevice(deviceId);

  Future<bool> disconnect() => _platform.disconnectDevice();

  // ── Wired display ─────────────────────────────────────────────────────────

  Future<bool> launchSystemCastPicker() => _platform.launchSystemCastPicker();

  Future<Map<String, dynamic>> checkWiredDisplay() =>
      _platform.checkWiredDisplay();

  Future<bool> startWiredDisplayMonitoring() =>
      _platform.startWiredDisplayMonitoring();

  Future<bool> stopWiredDisplayMonitoring() =>
      _platform.stopWiredDisplayMonitoring();

  // ── Event stream ──────────────────────────────────────────────────────────

  Stream<CastEvent> get events {
    return _platform.deviceEvents.map((raw) {
      final type = raw[ScreenCastChannel.eventType] as String? ?? '';
      switch (type) {
        case ScreenCastChannel.eventTypeDeviceFound:
          return CastEvent.deviceFound(CastDevice.fromMap(raw));
        case ScreenCastChannel.eventTypeDeviceLost:
          return CastEvent.deviceLost(raw['deviceId'] as String? ?? '');
        case ScreenCastChannel.eventTypeConnectionChanged:
          final connected = raw['isConnected'] as bool? ?? false;
          return CastEvent.connectionChanged(
            connected: connected,
            device: connected ? CastDevice.fromMap(raw) : null,
          );
        case ScreenCastChannel.eventTypeError:
          return CastEvent.error(raw['message'] as String? ?? 'Unknown error');
        case ScreenCastChannel.eventTypeWiredDisplayChanged:
          final connected = raw['isConnected'] as bool? ?? false;
          return CastEvent.wiredDisplayChanged(
            connected: connected,
            displayName: raw['displayName'] as String?,
          );
        default:
          debugPrint('[ScreenCastRepo] unknown event type: $type');
          return CastEvent.unknown();
      }
    });
  }
}
