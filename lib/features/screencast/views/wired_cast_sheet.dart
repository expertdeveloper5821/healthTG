import 'package:demo_p/features/screencast/models/screencast_state.dart';
import 'package:demo_p/features/screencast/viewmodels/screencast_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet shown while wired (HDMI/USB-C) casting is active.
///
/// Only rendered after the user has confirmed casting via [_WiredConfirmDialog]
/// and [beginWiredCasting] succeeded. Auto-dismisses when the cable is
/// unplugged (DisplayManager fires → state reverts to idle) or when the user
/// taps Stop Casting.
class WiredCastSheet extends ConsumerWidget {
  const WiredCastSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(screenCastProvider);
    final notifier = ref.read(screenCastProvider.notifier);

    // Auto-dismiss when casting ends (cable unplugged or stopped by user).
    ref.listen<ScreenCastState>(screenCastProvider, (previous, next) {
      if (previous?.isWiredCast == true && !next.isWiredCast) {
        Navigator.of(context).maybePop();
      }
    });

    final device = state.connectedDevice;

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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.settings_input_hdmi,
                  color: Color(0xFF54F2F2),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Wired Casting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Live indicator
                const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.greenAccent,
                  size: 12,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, thickness: 1),

          // Connected device card
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cast_connected,
                    color: Colors.greenAccent, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device?.name ?? 'External Display',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Connected via HDMI / USB-C',
                        style:
                            TextStyle(color: Colors.greenAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 22),
              ],
            ),
          ),

          // Info row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white24, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unplug the cable to stop casting automatically.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stop button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  notifier.stopCasting();
                },
                icon: const Icon(Icons.stop_screen_share, size: 18),
                label: const Text('Stop Casting'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
