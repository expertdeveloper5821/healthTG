import 'package:flutter/material.dart';

class HoldCursorWidget extends StatelessWidget {
  final Offset position;
  final Color color;
  final bool flipped;

  const HoldCursorWidget({
    super.key,
    required this.position,
    required this.color,
    required this.flipped,
  });

  @override
  Widget build(BuildContext context) {
    if (position == Offset.zero) return const SizedBox();

    return Positioned(
      left: position.dx - 26,
      top: position.dy - 26,
      width: 52,
      height: 52,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Transform(
            alignment: Alignment.center,
            transform: flipped
                ? (Matrix4.identity()..scale(-1.0, 1.0))
                : Matrix4.identity(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.42),
                    blurRadius: 18,
                    spreadRadius: 2,
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
