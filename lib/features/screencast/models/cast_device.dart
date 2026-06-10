import 'package:demo_p/features/screencast/models/cast_enums.dart';

export 'package:demo_p/features/screencast/models/cast_enums.dart';

class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final CastConnectionType type;
  final String? description;
  final bool isAvailable;

  factory CastDevice.fromMap(Map<String, dynamic> map) {
    return CastDevice(
      id: map['deviceId'] as String? ?? '',
      name: map['deviceName'] as String? ?? 'Unknown Device',
      type: _parseType(map['deviceType'] as String?),
      description: map['description'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }

  static CastConnectionType _parseType(String? raw) {
    switch (raw) {
      case 'wired':
        return CastConnectionType.wired;
      case 'chromecast':
        return CastConnectionType.chromecast;
      case 'miracast':
        return CastConnectionType.miracast;
      default:
        return CastConnectionType.unknown;
    }
  }

  String get typeLabel {
    switch (type) {
      case CastConnectionType.wired:
        return 'HDMI / USB-C';
      case CastConnectionType.chromecast:
        return 'Chromecast';
      case CastConnectionType.miracast:
        return 'Wireless Display';
      case CastConnectionType.unknown:
        return 'Smart TV';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CastDevice && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
