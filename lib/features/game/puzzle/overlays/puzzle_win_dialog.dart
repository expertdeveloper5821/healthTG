import 'dart:math' as math;

import 'package:flutter/material.dart';

class PuzzleWinDialog extends StatefulWidget {
  final String imagePath;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const PuzzleWinDialog({
    super.key,
    required this.imagePath,
    required this.onPlayAgain,
    required this.onHome,
  });

  @override
  State<PuzzleWinDialog> createState() => _PuzzleWinDialogState();
}

class _PuzzleWinDialogState extends State<PuzzleWinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale:
                0.92 + Curves.easeOutBack.transform(_controller.value) * 0.08,
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF121827),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: CustomPaint(
                      painter: _SuccessBurstPainter(
                        progress: _controller.value,
                      ),
                      child: Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF33D69F),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Puzzle Completed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Great focus. Every piece is in place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(widget.imagePath, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onHome,
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Home'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onPlayAgain,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Play Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF33D69F),
                            foregroundColor: const Color(0xFF071118),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBurstPainter extends CustomPainter {
  final double progress;

  const _SuccessBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi * 2 / 12;
      final distance = 26 + 12 * progress;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 27;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      paint.color =
          (i.isEven ? const Color(0xFFFFD166) : const Color(0xFF6EE7FF))
              .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
