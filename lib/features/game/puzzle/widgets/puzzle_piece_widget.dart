import 'dart:math' as math;

import 'package:demo_p/features/game/puzzle/controllers/puzzle_game_controller.dart';
import 'package:demo_p/features/game/puzzle/models/puzzle_piece_model.dart';
import 'package:demo_p/features/game/puzzle/services/puzzle_path_factory.dart';
import 'package:flutter/material.dart';

class PuzzlePieceWidget extends StatefulWidget {
  final PuzzlePieceModel piece;
  final Rect boardRect;
  final String imagePath;
  final bool isHovered;
  final double hoverProgress;

  const PuzzlePieceWidget({
    super.key,
    required this.piece,
    required this.boardRect,
    required this.imagePath,
    required this.isHovered,
    required this.hoverProgress,
  });

  @override
  State<PuzzlePieceWidget> createState() => _PuzzlePieceWidgetState();
}

class _PuzzlePieceWidgetState extends State<PuzzlePieceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    // Each piece has a unique duration offset to desync their float cycles.
    final durationMs = 3200 + (widget.piece.id % 4) * 200;
    _floatCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final piece = widget.piece;
    final margin =
        piece.cellSize.shortestSide * PuzzleGameController.pieceMarginRatio;
    final visualSize = Size(
      piece.cellSize.width + margin * 2,
      piece.cellSize.height + margin * 2,
    );

    final isScattered = piece.status == PuzzlePieceStatus.scattered;
    final isSettled = piece.status == PuzzlePieceStatus.placed;
    final target = isScattered ? piece.scatterPosition : piece.correctPosition;
    final topLeft = target - Offset(margin, margin);

    return AnimatedPositioned(
      duration: isScattered
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 640),
      curve: Curves.easeOutCubic,
      left: topLeft.dx,
      top: topLeft.dy,
      width: visualSize.width,
      height: visualSize.height,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _floatCtrl,
            builder: (context, child) {
              double floatDx = 0;
              double floatDy = 0;
              if (isScattered) {
                final t =
                    _floatCtrl.value * 2 * math.pi + piece.floatPhase;
                floatDx = math.sin(t) * 13.0;
                floatDy = math.sin(t * 1.37 + 0.83) * 9.0;
              }
              return Transform.translate(
                offset: Offset(floatDx, floatDy),
                child: child,
              );
            },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              scale: piece.status == PuzzlePieceStatus.placing
                  ? 1.06
                  : widget.isHovered
                  ? 1.04
                  : 1.0,
              child: CustomPaint(
                painter: _PuzzlePieceGlowPainter(
                  clipper: PuzzlePieceClipper(
                    cellSize: piece.cellSize,
                    margin: margin,
                    top: piece.top,
                    right: piece.right,
                    bottom: piece.bottom,
                    left: piece.left,
                  ),
                  color: widget.isHovered
                      ? const Color(0xFF6EE7FF)
                      : isSettled
                      ? const Color(0xFF7CFFB2)
                      : Colors.black,
                  progress: widget.isHovered ? widget.hoverProgress : 0,
                  placed: isSettled,
                ),
                child: ClipPath(
                  clipper: PuzzlePieceClipper(
                    cellSize: piece.cellSize,
                    margin: margin,
                    top: piece.top,
                    right: piece.right,
                    bottom: piece.bottom,
                    left: piece.left,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: margin - piece.column * piece.cellSize.width,
                        top: margin - piece.row * piece.cellSize.height,
                        width: widget.boardRect.width,
                        height: widget.boardRect.height,
                        child: Image.asset(widget.imagePath, fit: BoxFit.fill),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.14),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.10),
                            ],
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PuzzlePieceGlowPainter extends CustomPainter {
  final PuzzlePieceClipper clipper;
  final Color color;
  final double progress;
  final bool placed;

  const _PuzzlePieceGlowPainter({
    required this.clipper,
    required this.color,
    required this.progress,
    required this.placed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: placed ? 0.18 : 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);

    if (progress > 0 || placed) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = placed ? 2.1 : 3.0
        ..color = color.withValues(
          alpha: placed ? 0.48 : 0.30 + progress * 0.44,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, glowPaint);
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: placed ? 0.18 : 0.42);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PuzzlePieceGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.placed != placed ||
        oldDelegate.color != color ||
        oldDelegate.clipper != clipper;
  }
}
