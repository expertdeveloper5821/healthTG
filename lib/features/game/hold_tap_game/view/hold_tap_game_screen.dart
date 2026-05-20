import 'package:demo_p/features/game/hold_tap_game/provider/hold_tap_game_provider.dart';
import 'package:demo_p/features/game/hold_tap_game/widgets/click_effect_widget.dart';
import 'package:demo_p/features/game/hold_tap_game/widgets/game_background_widget.dart';
import 'package:demo_p/features/game/hold_tap_game/widgets/hold_cursor_widget.dart';
import 'package:demo_p/features/game/hold_tap_game/widgets/hold_target_widget.dart';
import 'package:demo_p/features/game/widgets/camera_preview_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HoldTapGameScreen extends ConsumerStatefulWidget {
  const HoldTapGameScreen({super.key});

  @override
  ConsumerState<HoldTapGameScreen> createState() => _HoldTapGameScreenState();
}

class _HoldTapGameScreenState extends ConsumerState<HoldTapGameScreen> {
  final GlobalKey _gameStackKey = GlobalKey();
  final GlobalKey _playAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(holdTapGameProvider).initialize();
    });
  }

  @override
  void dispose() {
    ref.read(holdTapGameProvider).disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(holdTapGameProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateTrackingArea(provider);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Stack(
          key: _gameStackKey,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  CameraPreviewBox(cameraServices: provider.cameraServices),
                  
                  const SizedBox(height: 14),
                  Expanded(
                    key: _playAreaKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: const GameBackgroundWidget(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            if (provider.activeTarget != null)
              HoldTargetWidget(
                key: ValueKey(provider.activeTarget!.id),
                target: provider.activeTarget!,
                isHolding: provider.isHolding,
              ),
            ClickEffectWidget(
              key: ValueKey(provider.clickEffectPosition),
              position: provider.clickEffectPosition,
            ),
            HoldCursorWidget(
              position: provider.leftCursor,
              color: const Color(0xFF54F2F2),
              flipped: false,
            ),
            HoldCursorWidget(
              position: provider.rightCursor,
              color: const Color(0xFFFF5CC8),
              flipped: true,
            ),
          ],
        ),
      ),
    );
  }

  void _updateTrackingArea(HoldTapGameProvider provider) {
    final stackBox = _gameStackKey.currentContext?.findRenderObject();
    final playBox = _playAreaKey.currentContext?.findRenderObject();
    if (stackBox is! RenderBox || playBox is! RenderBox) {
      provider.cameraServices.updateGameScreenWidth(
        MediaQuery.of(context).size.width,
      );
      return;
    }

    if (!stackBox.hasSize || !playBox.hasSize) return;

    final playTopLeft = stackBox.globalToLocal(
      playBox.localToGlobal(Offset.zero),
    );
    final playBottomRight = stackBox.globalToLocal(
      playBox.localToGlobal(Offset(playBox.size.width, playBox.size.height)),
    );

    provider.updateGameArea(Rect.fromPoints(playTopLeft, playBottomRight));
  }
}
