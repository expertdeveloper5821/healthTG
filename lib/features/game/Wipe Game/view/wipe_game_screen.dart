import 'package:demo_p/features/game/widgets/camera_preview_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wipe_game_provider.dart';
import '../widgets/wipe_cursor_widget.dart';
import '../widgets/wipe_grid_widget.dart';

class WipeGameScreen extends ConsumerStatefulWidget {
  const WipeGameScreen({super.key});

  @override
  ConsumerState<WipeGameScreen> createState() => _WipeGameScreenState();
}

class _WipeGameScreenState extends ConsumerState<WipeGameScreen> {
  final GlobalKey _gameStackKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(wipeGameProvider).initialize();
    });
  }

  @override
  void dispose() {
    ref.read(wipeGameProvider).disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(wipeGameProvider);
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

                  const SizedBox(height: 18),

                  Expanded(
                    child: WipeGridWidget(
                      key: _gridKey,
                      imagePath: 'assets/Images/schedule_1.png',
                      leftHand: provider.leftCursor,
                      rightHand: provider.rightCursor,
                      coordinateSpaceKey: _gameStackKey,
                    ),
                  ),

                  SizedBox(height: 10),
                ],
              ),
            ),

            WipeCursorWidget(
              position: provider.leftCursor,
              color: Colors.blueAccent,
              flipped: false,
            ),

            WipeCursorWidget(
              position: provider.rightCursor,
              color: Colors.greenAccent,
              flipped: true,
            ),
          ],
        ),
      ),
    );
  }

  void _updateTrackingArea(WipeGameProvider provider) {
    final stackBox = _gameStackKey.currentContext?.findRenderObject();
    final gridBox = _gridKey.currentContext?.findRenderObject();
    if (stackBox is! RenderBox || gridBox is! RenderBox) {
      provider.cameraServices.updateGameScreenWidth(
        MediaQuery.of(context).size.width,
      );
      return;
    }

    if (!stackBox.hasSize || !gridBox.hasSize) return;

    final gridTopLeft = stackBox.globalToLocal(
      gridBox.localToGlobal(Offset.zero),
    );
    final gridBottomRight = stackBox.globalToLocal(
      gridBox.localToGlobal(Offset(0, gridBox.size.height)),
    );

    provider.cameraServices.updateGameTrackingArea(
      screenWidth: stackBox.size.width,
      gridTop: gridTopLeft.dy,
      gridBottom: gridBottomRight.dy,
      horizontalPadding: gridTopLeft.dx,
    );
  }
}
