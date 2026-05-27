import 'package:flutter/material.dart';

class RepBounce extends StatelessWidget {
  final int tick;
  final Widget child;

  const RepBounce({super.key, required this.tick, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(tick),
      tween: Tween(begin: 1.08, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: child,
    );
  }
}

class PlusOneBurst extends StatelessWidget {
  final int tick;

  const PlusOneBurst({super.key, required this.tick});

  @override
  Widget build(BuildContext context) {
    if (tick == 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      key: ValueKey(tick),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final opacity = (1 - value).clamp(0.0, 1.0);
        final yOffset = -72 * value;
        final scaleBoost = (1 - (value - 0.35).abs())
            .clamp(0.0, 1.0)
            .toDouble();
        final scale = 0.85 + (0.35 * scaleBoost);

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF33D69F),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6633D69F),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Text(
          '+1',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
