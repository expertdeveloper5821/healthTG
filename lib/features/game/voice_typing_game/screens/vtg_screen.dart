import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vtg_enums.dart';
import '../providers/vtg_provider.dart';
import '../widgets/graph_card.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/monitoring_toggle.dart';
import '../widgets/settings_panel.dart';
import '../widgets/typing_input_panel.dart';

/// Live performance monitoring screen.
///
/// Design principles:
/// • No scores, no timers, no success/fail text — purely visual feedback.
/// • Graph scrolls continuously from init; monitoring toggle only switches
///   the data source (idle sine → real sensor).
/// • Settings are hidden behind the app-bar icon to keep the surface clean.
class VtgScreen extends ConsumerWidget {
  const VtgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vtgProvider);
    final notifier = ref.read(vtgProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(state.showSettings, notifier.toggleSettings),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Mode toggle ─────────────────────────────────────────────
                ModeToggle(
                  current: state.mode,
                  onChanged: (m) {
                    if (!state.isMonitoring) {
                      notifier.setMode(m);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Stop monitoring before switching modes',
                            style: TextStyle(color: Colors.white70),
                          ),
                          backgroundColor: const Color(0xFF16162A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 16),

                // ── Live graph — always scrolling ────────────────────────────
                GraphCard(
                  samples: state.samples,
                  graphYMin: state.graphYMin,
                  graphYMax: state.graphYMax,
                  zoneMin: state.zoneMin,
                  zoneMax: state.zoneMax,
                  zoneStatus: state.zoneStatus,
                  isMonitoring: state.isMonitoring,
                  modeLabel: state.modeLabel,
                ),

                const SizedBox(height: 20),

                // ── Monitoring toggle ────────────────────────────────────────
                MonitoringToggle(
                  isMonitoring: state.isMonitoring,
                  onToggle: notifier.toggleMonitoring,
                ),

                // ── Typing input (typing mode only) ──────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => SizeTransition(
                    sizeFactor: CurvedAnimation(
                        parent: anim, curve: Curves.easeInOut),
                    axisAlignment: -1,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: state.mode == GameMode.typing
                      ? Padding(
                          key: const ValueKey('typing'),
                          padding: const EdgeInsets.only(top: 18),
                          child: const TypingInputPanel(),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
                ),

                // ── Mic permission banner ─────────────────────────────────────
                if (state.mode == GameMode.voice && !state.hasMicPermission)
                  _MicBanner(onAllow: notifier.toggleMonitoring),

                // ── Settings panel (collapsible) ─────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => SizeTransition(
                    sizeFactor: CurvedAnimation(
                        parent: anim, curve: Curves.easeInOut),
                    axisAlignment: -1,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: state.showSettings
                      ? Padding(
                          key: const ValueKey('settings'),
                          padding: const EdgeInsets.only(top: 18),
                          child: SettingsPanel(
                            settings: state.settings,
                            mode: state.mode,
                            onVoiceRangeChanged: notifier.updateVoiceRange,
                            onTypingRangeChanged: notifier.updateTypingRange,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no_settings')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      bool settingsOpen, VoidCallback onSettingsTap) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white54, size: 18),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
      centerTitle: true,
      title: Text(
        'Live Monitor',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            settingsOpen ? Icons.tune_rounded : Icons.tune_outlined,
            color: settingsOpen
                ? const Color(0xFF26C6DA)
                : Colors.white.withValues(alpha: 0.35),
            size: 20,
          ),
          onPressed: onSettingsTap,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Permission banner ──────────────────────────────────────────────────────────

class _MicBanner extends StatelessWidget {
  final VoidCallback onAllow;
  const _MicBanner({required this.onAllow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0D00),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFFF7043).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_off_rounded,
                color: const Color(0xFFFF7043).withValues(alpha: 0.8), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Microphone access required for Voice mode.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: onAllow,
              child: const Text(
                'Allow',
                style: TextStyle(
                  color: Color(0xFFFF7043),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
