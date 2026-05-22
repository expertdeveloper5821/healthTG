import 'package:flutter/material.dart';

class PuzzleCursorWidget extends StatelessWidget {
  final Offset position;
  final Color color;
  final bool flipped;

  const PuzzleCursorWidget({
    super.key,
    required this.position,
    required this.color,
    required this.flipped,
  });

  @override
  Widget build(BuildContext context) {
    if (position == Offset.zero) return const SizedBox.shrink();

    return Positioned(
      left: position.dx - 27,
      top: position.dy - 27,
      width: 54,
      height: 54,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Transform(
            alignment: Alignment.center,
            transform: flipped
                ? (Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0))
                : Matrix4.identity(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.36),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/Images/plam.png',
                color: color.withValues(alpha: 0.94),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
