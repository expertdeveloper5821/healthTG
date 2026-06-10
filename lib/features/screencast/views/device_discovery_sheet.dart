import 'package:demo_p/features/screencast/models/screencast_state.dart';
import 'package:demo_p/features/screencast/viewmodels/screencast_viewmodel.dart';
import 'package:demo_p/features/screencast/widgets/device_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceDiscoverySheet extends ConsumerWidget {
  const DeviceDiscoverySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(screenCastProvider);
    final notifier = ref.read(screenCastProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16162A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.cast, color: Colors.white70, size: 22),
                const SizedBox(width: 10),
                Text(
                  _sheetTitle(state.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (state.isSearching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                if (state.isCasting)
                  const Icon(Icons.fiber_manual_record,
                      color: Colors.greenAccent, size: 14),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, thickness: 1),

          // Permission denied message
          if (state.status == CastStatus.permissionDenied &&
              state.permissionMessage != null)
            _PermissionBanner(message: state.permissionMessage!),

          // Error message
          if (state.errorMessage != null &&
              state.status == CastStatus.failed)
            _ErrorBanner(
              message: state.errorMessage!,
              onRetry: () => notifier.startWirelessCasting(),
            ),

          // Connected device card
          if (state.isCasting && state.connectedDevice != null)
            _ConnectedCard(
              device: state.connectedDevice!,
              onDisconnect: () {
                Navigator.pop(context);
                notifier.stopCasting();
              },
            ),

          // Device list (discovery results)
          if (!state.isCasting) ...[
            if (state.devices.isEmpty && state.isSearching)
              _SearchingPlaceholder(
                systemCastLaunched: state.systemCastLaunched,
              )
            else if (state.devices.isEmpty &&
                state.status != CastStatus.searching &&
                state.status != CastStatus.idle)
              const _EmptyPlaceholder()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.devices.length,
                itemBuilder: (_, i) {
                  final device = state.devices[i];
                  return DeviceTile(
                    device: device,
                    isConnecting: state.isConnecting,
                    onTap: () => notifier.connectTo(device),
                  );
                },
              ),
          ],

          // Action buttons
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (state.isSearching)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        notifier.cancelSearch();
                      },
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop Search'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else if (!state.isCasting)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.startWirelessCasting(),
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Search Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D3D6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sheetTitle(CastStatus status) {
    switch (status) {
      case CastStatus.idle:
        return 'Cast Screen';
      case CastStatus.searching:
        return 'Finding Displays…';
      case CastStatus.connecting:
        return 'Connecting…';
      case CastStatus.connected:
        return 'Now Casting';
      case CastStatus.disconnected:
        return 'Disconnected';
      case CastStatus.failed:
        return 'Connection Failed';
      case CastStatus.permissionDenied:
        return 'Permission Required';
    }
  }
}

// ── Internal sub-widgets ──────────────────────────────────────────────────────

class _SearchingPlaceholder extends StatelessWidget {
  const _SearchingPlaceholder({this.systemCastLaunched = false});

  final bool systemCastLaunched;

  @override
  Widget build(BuildContext context) {
    if (systemCastLaunched) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7CFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF8B7CFF).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cast, color: Color(0xFF8B7CFF), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System cast screen opened',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select a nearby device from the system panel '
                          'to begin casting automatically.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white38,
                    strokeWidth: 1.5,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Also scanning for nearby devices…',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Scanning for nearby displays…',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'Make sure your TV is on the same Wi-Fi network.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.tv_off, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            'No displays found',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          SizedBox(height: 6),
          Text(
            'Ensure your Smart TV is powered on and connected '
            'to the same Wi-Fi as this device.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({
    required this.device,
    required this.onDisconnect,
  });

  final CastDevice device;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cast_connected, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  device.typeLabel,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDisconnect,
            child: const Text(
              'Stop',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => openAppSettings(),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
