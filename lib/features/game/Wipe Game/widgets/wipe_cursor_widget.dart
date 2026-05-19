import 'package:flutter/material.dart';

class WipeCursorWidget extends StatelessWidget {
  final Offset position;
  final Color color;
  final bool flipped;

  const WipeCursorWidget({
    super.key,
    required this.position,
    required this.color,
    required this.flipped,
  });

  @override
  Widget build(BuildContext context) {
    if (position == Offset.zero) {
      return const SizedBox();
    }

    return Positioned(
      left: position.dx - 28,
      top: position.dy - 28,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.center,
          transform: flipped
              ? (Matrix4.identity()..scale(-1.0, 1.0))
              : Matrix4.identity(),
          child: Image.asset(
            'assets/Images/plam.png',
            width: 56,
            height: 56,
            color: color.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}