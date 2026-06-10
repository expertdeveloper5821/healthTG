import 'package:demo_p/features/screencast/models/screencast_state.dart';
import 'package:demo_p/features/screencast/viewmodels/screencast_viewmodel.dart';
import 'package:demo_p/features/screencast/views/cast_selection_dialog.dart';
import 'package:demo_p/features/screencast/views/wired_cast_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating Action Button that reflects the current casting state.
///
/// Wireless flow (system-picker driven):
///   idle → CastSelectionDialog → startWirelessCasting()
///     → system cast screen opens; OS drives the full connect/disconnect flow
///     → FAB transitions to "Casting" when OS reports connection
///   connected (wireless) → system cast screen opens directly so the user
///     can disconnect; FAB returns to "Cast Screen" when OS reports disconnect
///
/// Wired flow:
///   idle → CastSelectionDialog → _startWiredCastFlow()
///     → detectWiredDisplay() (fast, no state change)
///     → not found  → _WiredNotFoundDialog (try-again / cancel)
///     → found      → _WiredConfirmDialog  (allow / cancel)
///     → allowed    → beginWiredCasting() → WiredCastSheet
///   connected (wired) → WiredCastSheet (stop casting)
class CastFab extends ConsumerWidget {
  const CastFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(screenCastProvider);
    final notifier = ref.read(screenCastProvider.notifier);

    final config = _fabConfig(state);

    return FloatingActionButton.extended(
      onPressed: () => _handleTap(context, state, notifier),
      backgroundColor: config.backgroundColor,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: Icon(config.icon, size: 22),
      label: Text(
        config.label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    ScreenCastState state,
    ScreenCastNotifier notifier,
  ) {
    switch (state.status) {
      case CastStatus.connected:
        if (state.isWiredCast) {
          _showWiredCastSheet(context);
        } else {
          // Wireless active: open system picker directly — user disconnects there.
          notifier.openSystemCastSettings();
        }

      case CastStatus.searching:
        if (state.castMode == CastMode.wired) {
          _showWiredCastSheet(context);
        } else {
          // Wireless: system picker may have been dismissed — re-open it.
          notifier.openSystemCastSettings();
        }

      case CastStatus.connecting:
        return;

      case CastStatus.disconnected:
      case CastStatus.failed:
      case CastStatus.permissionDenied:
      case CastStatus.idle:
        _showCastSelectionDialog(context, notifier);
    }
  }

  // ── Selection dialog (Wireless vs Wired) ─────────────────────────────────

  void _showCastSelectionDialog(
      BuildContext context, ScreenCastNotifier notifier) {
    showDialog<CastMode>(
      context: context,
      builder: (_) => const CastSelectionDialog(),
    ).then((mode) {
      if (mode == null || !context.mounted) return;
      if (mode == CastMode.wireless) {
        notifier.startWirelessCasting();
      } else {
        _startWiredCastFlow(context, notifier);
      }
    });
  }

  // ── Wired cast detection flow ─────────────────────────────────────────────

  Future<void> _startWiredCastFlow(
      BuildContext context, ScreenCastNotifier notifier) async {
    final displayName = await notifier.detectWiredDisplay();
    if (!context.mounted) return;

    if (displayName == null) {
      _showWiredNotFoundDialog(context, notifier);
    } else {
      _showWiredConfirmDialog(context, notifier, displayName);
    }
  }

  void _showWiredNotFoundDialog(
      BuildContext context, ScreenCastNotifier notifier) {
    showDialog<bool>(
      context: context,
      builder: (_) => const _WiredNotFoundDialog(),
    ).then((tryAgain) {
      if (tryAgain != true || !context.mounted) return;
      _startWiredCastFlow(context, notifier);
    });
  }

  void _showWiredConfirmDialog(
    BuildContext context,
    ScreenCastNotifier notifier,
    String displayName,
  ) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WiredConfirmDialog(displayName: displayName),
    ).then((confirmed) async {
      if (confirmed != true || !context.mounted) return;
      final casting = await notifier.beginWiredCasting(displayName);
      if (casting && context.mounted) _showWiredCastSheet(context);
    });
  }

  // ── Wired sheet ───────────────────────────────────────────────────────────

  void _showWiredCastSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const WiredCastSheet(),
    );
  }

  // ── FAB appearance ────────────────────────────────────────────────────────

  _FabConfig _fabConfig(ScreenCastState state) {
    switch (state.status) {
      case CastStatus.connected:
        return _FabConfig(
          icon: state.isWiredCast
              ? Icons.settings_input_hdmi
              : Icons.cast_connected,
          label: state.isWiredCast ? 'Wired Cast' : 'Casting',
          backgroundColor: const Color(0xFF2E7D32),
        );

      // All non-casting states show a single "Cast Screen" button.
      case CastStatus.idle:
      case CastStatus.searching:
      case CastStatus.connecting:
      case CastStatus.disconnected:
      case CastStatus.failed:
      case CastStatus.permissionDenied:
        return const _FabConfig(
          icon: Icons.cast,
          label: 'Cast Screen',
          backgroundColor: Color(0xFF3D3D6B),
        );
    }
  }
}

// ── Wired not-found dialog ────────────────────────────────────────────────────

class _WiredNotFoundDialog extends StatelessWidget {
  const _WiredNotFoundDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.cable, color: Colors.orange, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No Wired Display Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No wired display was detected. Please connect a supported cable and try again.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          _cableHint(Icons.usb, 'USB-C to HDMI adapter or cable'),
          _cableHint(Icons.cable, 'DisplayPort Alt Mode adapter'),
          _cableHint(Icons.settings_input_hdmi, 'MHL (Micro USB to HDMI)'),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D3D6B),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _cableHint(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white30, size: 15),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Wired confirm dialog ──────────────────────────────────────────────────────

class _WiredConfirmDialog extends StatelessWidget {
  const _WiredConfirmDialog({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.cast_connected, color: Colors.greenAccent, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wired Display Detected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'A wired display connection is ready. Do you want to start screen sharing?',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            'Allow',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── FAB config ────────────────────────────────────────────────────────────────

class _FabConfig {
  const _FabConfig({
    required this.icon,
    required this.label,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
}
