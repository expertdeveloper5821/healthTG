import 'dart:math';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SleepCard extends StatelessWidget {
  const SleepCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 171.9,
      height: 242.8,
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.backgroundright,
        borderRadius: BorderRadius.circular(19.42),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            offset: const Offset(0, 3.88),
            blurRadius: 15.54,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                "assets/Images/sleep.svg",
                width: 18,
                height: 18,
               
              ),
           6.w,
            Text(
                "Sleep",
                style: const TextStyle(
                  fontFamily: "Mulish",
                  fontSize: 14.57,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                  color: Color(0xFF9B9B9B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 98.24,
              height: 98.24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(98.24, 98.24),
                    painter: _SleepPainter(progress: 0.78),
                  ),

                  /// CENTER TEXT
                  const Text(
                    "Good",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

     16.h,
          Center(
            child: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: "6",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 23.31,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: " hr ",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 14.57,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                    ),
                  ),
                  TextSpan(
                    text: "27",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 23.31,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: " min",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 14.57,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          /// ================= GOAL =================
          Center(
            child: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: "Your goal: ",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 10.68,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                      color: Color(0xFF5CD1AE),
                    ),
                  ),
                  TextSpan(
                    text: "7",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 10.68,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: Color(0xFF9DE3CE),
                    ),
                  ),
                  TextSpan(
                    text: " hr",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontSize: 10.68,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                      color: Color(0xFF9DE3CE),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepPainter extends CustomPainter {
  final double progress;
  const _SleepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    const stroke = 8.0;

    /// ❌ UNSELECTED (TRACK)
    final trackPaint = Paint()
      ..color = const Color(0xFF2E2E2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, trackPaint);

    /// ✅ SELECTED (GRADIENT ARC)
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = const SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: [
        Color(0xFF97DAFA),
        Color(0xFF43C3FF),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}