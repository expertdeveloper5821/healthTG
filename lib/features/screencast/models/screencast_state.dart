import 'package:demo_p/features/screencast/models/cast_device.dart';

export 'package:demo_p/features/screencast/models/cast_device.dart'
    show CastDevice, CastConnectionType, CastStatus, CastMode;

class ScreenCastState {
  const ScreenCastState({
    this.status = CastStatus.idle,
    this.castMode,
    this.devices = const [],
    this.connectedDevice,
    this.errorMessage,
    this.permissionMessage,
    this.wiredDisplayName,
    this.systemCastLaunched = false,
  });

  final CastStatus status;
  final CastMode? castMode;
  final List<CastDevice> devices;
  final CastDevice? connectedDevice;
  final String? errorMessage;
  final String? permissionMessage;
  final String? wiredDisplayName;

  /// True when the native system cast picker was successfully opened.
  /// The sheet uses this to adjust its instructional copy.
  final bool systemCastLaunched;

  bool get isCasting => status == CastStatus.connected;
  bool get isSearching => status == CastStatus.searching;
  bool get isConnecting => status == CastStatus.connecting;
  bool get isBusy => isSearching || isConnecting;
  bool get isWiredCast => castMode == CastMode.wired && isCasting;
  bool get isWirelessCast => castMode == CastMode.wireless && isCasting;

  ScreenCastState copyWith({
    CastStatus? status,
    CastMode? castMode,
    bool clearCastMode = false,
    List<CastDevice>? devices,
    CastDevice? connectedDevice,
    bool clearConnectedDevice = false,
    String? errorMessage,
    bool clearError = false,
    String? permissionMessage,
    bool clearPermissionMessage = false,
    String? wiredDisplayName,
    bool clearWiredDisplayName = false,
    bool? systemCastLaunched,
  }) {
    return ScreenCastState(
      status: status ?? this.status,
      castMode: clearCastMode ? null : castMode ?? this.castMode,
      devices: devices ?? this.devices,
      connectedDevice: clearConnectedDevice
          ? null
          : connectedDevice ?? this.connectedDevice,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      permissionMessage: clearPermissionMessage
          ? null
          : permissionMessage ?? this.permissionMessage,
      wiredDisplayName: clearWiredDisplayName
          ? null
          : wiredDisplayName ?? this.wiredDisplayName,
      systemCastLaunched: systemCastLaunched ?? this.systemCastLaunched,
    );
  }
}
