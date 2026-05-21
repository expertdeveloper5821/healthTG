import 'package:demo_p/features/game/widgets/camera_preview_box.dart';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wipe_game_provider.dart';
import '../widgets/wipe_cursor_widget.dart';
import '../widgets/wipe_grid_widget.dart';

class WipeGameScreen extends ConsumerStatefulWidget {
  final bool isPaused;
  final GameCalibrationService? safetyMonitor;

  const WipeGameScreen({super.key, this.isPaused = false, this.safetyMonitor});

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
      ref.read(wipeGameProvider)
        ..attachSafetyMonitor(widget.safetyMonitor)
        ..initialize();
    });
  }

  @override
  void didUpdateWidget(covariant WipeGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      ref.read(wipeGameProvider).setPaused(widget.isPaused);
    }
    if (oldWidget.safetyMonitor != widget.safetyMonitor) {
      ref.read(wipeGameProvider).attachSafetyMonitor(widget.safetyMonitor);
    }
  }

  @override
  void dispose() {
    ref.read(wipeGameProvider).disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(wipeGameProvider);
    if (provider.isPaused != widget.isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(wipeGameProvider).setPaused(widget.isPaused);
      });
    }
    ref.listen<bool>(
      wipeGameProvider.select((provider) => provider.isCompleted),
      (previous, next) {
        if (previous == true || !next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showCompletionDialog();
        });
      },
    );

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
                      imagePath: provider.currentImagePath,
                      resetToken: provider.boardVersion,
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

  void _showCompletionDialog() {
    final provider = ref.read(wipeGameProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Great job!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          'You completed the wipe game.\nScore : ${provider.score}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(wipeGameProvider).restartGame();
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(wipeGameProvider).startNextImage();
            },
            child: const Text('Next Image'),
          ),
        ],
      ),
    );
  }
}
