import 'dart:math';
import 'dart:ui';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_sizes.dart';
import 'package:demo_p/core/constants/app_text_styles.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class VitalSignsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const VitalSignsCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final steps = data['steps'] ?? 0;
final spo2 = data['bloodOxygen'] ?? 0.0;
final heart = data['heartRate'] ?? 0.0;
final calories = data['totalCalories'] ?? 0.0;
double stepsProgress = (steps / 10000).clamp(0.0, 1.0);
double oxygenProgress = (spo2 / 100).clamp(0.0, 1.0);
double heartProgress = (heart / 200).clamp(0.0, 1.0);
double caloriesProgress = (calories / 3000).clamp(0.0, 1.0);
    return Container(
      width: 364,
      height: 332,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          
Positioned(
  top: 100,
  bottom: 0,
  left: -265.72,
  right: -15,
  child: Transform.rotate(
    angle: 142.37 * pi / 2, 
    child: ClipRRect(
      borderRadius: BorderRadius.circular(40), 
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 50,
          sigmaY: 50,
        ),
        child: Container(
          width: 551.85,
          height: 305.02,
          decoration: BoxDecoration(
            color: const Color(0xFF050505).withOpacity(0.5), 
            borderRadius: BorderRadius.circular(40),

            /// 🔥 glass highlight (important)
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
      ),
    ),
  ),
),   // ── Concentric arc rings (right side) ──
          Positioned(
            top: 29.95,
            left: 62.41,
            child: SizedBox(
              width: 241.17,
              height: 241.17,
              child: CustomPaint(
  painter: _ConcentricArcsPainter(
    steps: stepsProgress,
    oxygen: oxygenProgress,
    heart: heartProgress,
    calories: caloriesProgress,
  ),
),
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 const Spacer(), 
Row(
  children: [
    Expanded(
      child: _VitalStatBlock(
        svgPath: 'assets/Images/steps.svg',
        lineColor: const Color(0xFFFFD93D),
        label: 'Steps Taken',
    value: steps.toString(),
        unit: '',
      ),
    ),
    Expanded(
      child: _VitalStatBlock(
        svgPath: 'assets/Images/oxygen.svg',
        lineColor: const Color(0xFFFF3366),
        label: 'Oxygen level',
      value: "${spo2.toStringAsFixed(0)}%",
        unit: '(SpO2)',
      ),
    ),
  ],
),
const SizedBox(height: 4),
Row(
  children: [
    Expanded(
      child: _VitalStatBlock(
        svgPath: 'assets/Images/heart.svg',
        lineColor: const Color(0xFF1E90FF),
        label: 'Heart rate',
      value: heart.toStringAsFixed(0),
        unit: 'bpm',
      ),
    ),
    Expanded(
      child: _VitalStatBlock(
        svgPath: 'assets/Images/burn.svg',
        lineColor: const Color(0xFF97DAFA),
        label: 'Calories burned',
      value: calories.toStringAsFixed(0),
        unit: 'kcal',
      ),
    ),
  ],
),
               8.h,
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _VitalStatBlock extends StatelessWidget {
  final String svgPath;
  final Color lineColor;
  final String label;
  final String value;
  final String unit;

  const _VitalStatBlock({
    required this.svgPath,
    required this.lineColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  bool get isNumber => double.tryParse(value.replaceAll('%', '').replaceAll(',', '')) != null;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5.39,
          height: 42.52,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),

        8.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: SVG + Title
              Row(
                children: [
                  SvgPicture.asset(
                    svgPath,
                    width: 13,
                    height: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTextStyles.base.copyWith(
                      fontSize: 9.8,
                      fontWeight: FontWeight.w400,
                      color: Colors.white60,
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
               4.h,
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.base.copyWith(
                      fontSize: 15.25,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                   4.w,
                    Text(
                      unit,
                      style: AppTextStyles.base.copyWith(
                        fontSize: 9.8,
                        fontWeight: FontWeight.w400,
                        color: Colors.white60,
                        letterSpacing: 0.5,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
class _ConcentricArcsPainter extends CustomPainter {
  final double steps;      // 0 → 1
  final double oxygen;     // 0 → 1
  final double heart;      // 0 → 1
  final double calories;   // 0 → 1

  const _ConcentricArcsPainter({
    required this.steps,
    required this.oxygen,
    required this.heart,
    required this.calories,
  });

  @override
  void paint(Canvas canvas, Size size) {

    final cx = size.width / 2;
    final cy = size.height / 2;

   final rings = [
  _Ring(241.17 / 2, const Color(0xFFFFD600), steps, 14),   // Steps
  _Ring(193.40 / 2, const Color(0xFFE91E63), oxygen, 14),  // Oxygen

  _Ring((147.61 / 2) - 3, const Color(0xFF1E88E5), heart, 20),   // 🔥 THICKER

  _Ring(86.95 / 2,  const Color(0xFF80DEEA), calories, 14),
];

    /// TRACK + ARC
    for (final ring in rings) {

      /// TRACK
      final trackPaint = Paint()
        ..color = Color(0XFF2E2E2E)
    ..strokeWidth = ring.stroke
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(cx, cy), ring.radius, trackPaint);

      /// PROGRESS ARC
      final arcPaint = Paint()
        ..color = ring.color
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(
        center: Offset(cx, cy),
        radius: ring.radius,
      );

      canvas.drawArc(
        rect,
        -pi / 2, // start top
        2 * pi * ring.progress, // dynamic
        false,
        arcPaint,
      );
    }


    final innerRadius = 40.28 / 2;

    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.97
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Ring {
  final double radius;
  final Color color;
  final double progress;
  final double stroke;

  const _Ring(this.radius, this.color, this.progress, this.stroke);
}


