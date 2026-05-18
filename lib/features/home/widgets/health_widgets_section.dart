import 'dart:ui';

import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_sizes.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:demo_p/features/home/widgets/water_card.dart';
import 'package:demo_p/features/home/widgets/sleep_card.dart';
import 'package:demo_p/features/home/widgets/heart_rate_card.dart';
import 'package:demo_p/features/home/widgets/daily_notes_card.dart';

class HealthWidgetsSection extends StatelessWidget {
  const HealthWidgetsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Column(
        children: [


          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

            
              Expanded(
                child: Column(
                  children:  [
                    _AddNotesCard(),
                   9.h,
                    _AddWidgetCard(),
                   9.h,
                    SleepCard(), 
                  ],
                ),
              ),
             9.w,
             Expanded(
                child: Column(
                  children: const [
                    WaterCard(),
                    SizedBox(height: 9),
                    HeartRateCard(value: 72,),
                  ],
                ),
              ),
            ],
          ),
          9.h,
          const DailyNotesCard(),
        ],
      ),
    );
  }
}
class _AddNotesCard extends StatelessWidget {
  const _AddNotesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96, 
      padding: const EdgeInsets.fromLTRB(10.68, 7.77, 10, 7.77),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19.42), // 👈 match other cards
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 65.9,
            height: 81.58,
            child: Image.asset(
              "assets/Images/add_notes.png",
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: Text(
              'Add notes\nto yourself',
              style: const TextStyle(
                fontFamily: 'Mulish',
                fontSize: 13.6,
                fontWeight: FontWeight.w500,
                height: 1.25,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _AddWidgetCard extends StatelessWidget {
  const _AddWidgetCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58.27, 
      width: double.infinity,

      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.white.withOpacity(0.25),
          radius: 19.42, 
          dashWidth: 6,
          dashSpace: 4,
        ),
        child: Container(
          alignment: Alignment.center,
          child: Opacity(
            opacity: 0.6,
            child: const Text(
              '+ Add widget',
              style: TextStyle(
                fontFamily: 'Mulish',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────── Dashed Border Painter ───────────────
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}