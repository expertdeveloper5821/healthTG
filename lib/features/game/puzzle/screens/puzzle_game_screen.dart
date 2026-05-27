import 'dart:math' as math;

import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/widgets/camera_preview_box.dart';
import 'package:demo_p/features/game/puzzle/controllers/puzzle_game_controller.dart';
import 'package:demo_p/features/game/puzzle/overlays/puzzle_win_dialog.dart';
import 'package:demo_p/features/game/puzzle/widgets/puzzle_board_widget.dart';
import 'package:demo_p/features/game/puzzle/widgets/puzzle_cursor_widget.dart';
import 'package:demo_p/features/game/puzzle/widgets/puzzle_piece_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PuzzleGameScreen extends ConsumerStatefulWidget {
  final bool isPaused;
  final GameCalibrationService? safetyMonitor;

  const PuzzleGameScreen({
    super.key,
    this.isPaused = false,
    this.safetyMonitor,
  });

  @override
  ConsumerState<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends ConsumerState<PuzzleGameScreen> {
  final GlobalKey _gameStackKey = GlobalKey();
  final GlobalKey _playAreaKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ref.read(puzzleGameProvider)
      ..attachSafetyMonitor(widget.safetyMonitor)
      ..initialize();
  }

  @override
  void didUpdateWidget(covariant PuzzleGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      ref.read(puzzleGameProvider).setPaused(widget.isPaused);
    }
    if (oldWidget.safetyMonitor != widget.safetyMonitor) {
      ref.read(puzzleGameProvider).attachSafetyMonitor(widget.safetyMonitor);
    }
  }

  @override
  void dispose() {
    ref.read(puzzleGameProvider).disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(puzzleGameProvider);

    if (controller.isPaused != widget.isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(puzzleGameProvider).setPaused(widget.isPaused);
      });
    }

    ref.listen<bool>(
      puzzleGameProvider.select((value) => value.isCompleted),
      (previous, next) {
        if (previous == true || !next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWinDialog();
        });
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTrackingArea(controller);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Stack(
          key: _gameStackKey,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  CameraPreviewBox(cameraServices: controller.cameraServices),
                  const SizedBox(height: 12),
                  Expanded(
                    key: _playAreaKey,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardWidth = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight * 0.60 / 0.75,
                        );
                        final boardHeight = boardWidth * 0.75;
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF111B2D),
                                      Color(0xFF0E1424),
                                      Color(0xFF101E25),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 14,
                              width: boardWidth,
                              height: boardHeight,
                              child: PuzzleBoardWidget(
                                key: _boardKey,
                                imagePath: PuzzleGameController.imagePath,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            for (final piece in controller.pieces)
              if (piece.isVisible)
                PuzzlePieceWidget(
                  key: ValueKey('${controller.boardVersion}-${piece.id}'),
                  piece: piece,
                  boardRect: controller.boardRect,
                  imagePath: PuzzleGameController.imagePath,
                  isHovered: controller.hoveredPieceId == piece.id,
                  hoverProgress: controller.hoveredPieceId == piece.id
                      ? controller.hoverProgress
                      : 0,
                ),
            PuzzleCursorWidget(
              position: controller.leftCursor,
              color: const Color(0xFF6EE7FF),
              flipped: false,
            ),
            PuzzleCursorWidget(
              position: controller.rightCursor,
              color: const Color(0xFFFFC857),
              flipped: true,
            ),
          ],
        ),
      ),
    );
  }

  void _updateTrackingArea(PuzzleGameController controller) {
    final stackBox = _gameStackKey.currentContext?.findRenderObject();
    final playBox = _playAreaKey.currentContext?.findRenderObject();
    final boardBox = _boardKey.currentContext?.findRenderObject();
    if (stackBox is! RenderBox ||
        playBox is! RenderBox ||
        boardBox is! RenderBox) {
      controller.cameraServices.updateGameScreenWidth(
        MediaQuery.of(context).size.width,
      );
      return;
    }
    if (!stackBox.hasSize || !playBox.hasSize || !boardBox.hasSize) return;

    final playTopLeft = stackBox.globalToLocal(
      playBox.localToGlobal(Offset.zero),
    );
    final playBottomRight = stackBox.globalToLocal(
      playBox.localToGlobal(Offset(playBox.size.width, playBox.size.height)),
    );
    final boardTopLeft = stackBox.globalToLocal(
      boardBox.localToGlobal(Offset.zero),
    );
    final boardBottomRight = stackBox.globalToLocal(
      boardBox.localToGlobal(Offset(boardBox.size.width, boardBox.size.height)),
    );

    controller.updateGameArea(
      playArea: Rect.fromPoints(playTopLeft, playBottomRight),
      boardRect: Rect.fromPoints(boardTopLeft, boardBottomRight),
    );
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PuzzleWinDialog(
        imagePath: PuzzleGameController.imagePath,
        onPlayAgain: () {
          Navigator.of(context).pop();
          ref.read(puzzleGameProvider).restartGame();
        },
        onHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}
