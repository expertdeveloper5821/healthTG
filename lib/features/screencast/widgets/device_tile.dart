import 'package:demo_p/features/screencast/models/screencast_state.dart';
import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.isConnecting = false,
  });

  final CastDevice device;
  final VoidCallback onTap;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isConnecting ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: _iconColor(device.type).withValues(alpha: 0.18),
        child: Icon(_icon(device.type), color: _iconColor(device.type), size: 22),
      ),
      title: Text(
        device.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        device.description ?? device.typeLabel,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            )
          : const Icon(Icons.chevron_right, color: Colors.white38),
    );
  }

  IconData _icon(CastConnectionType type) {
    switch (type) {
      case CastConnectionType.wired:
        return Icons.settings_input_hdmi;
      case CastConnectionType.chromecast:
        return Icons.cast;
      case CastConnectionType.miracast:
        return Icons.screen_share;
      case CastConnectionType.unknown:
        return Icons.tv;
    }
  }

  Color _iconColor(CastConnectionType type) {
    switch (type) {
      case CastConnectionType.wired:
        return const Color(0xFF54F2F2);
      case CastConnectionType.chromecast:
        return const Color(0xFF4CAF50);
      case CastConnectionType.miracast:
        return const Color(0xFF8B7CFF);
      case CastConnectionType.unknown:
        return const Color(0xFFFFD166);
    }
  }
}
