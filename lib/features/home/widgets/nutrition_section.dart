import 'dart:math';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_sizes.dart';
import 'package:demo_p/core/constants/app_text_styles.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class NutritionSection extends StatelessWidget {
  const NutritionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: AppColors.blueCardGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          _NutritionHeader(),
          SizedBox(height: 14),
          _NutritionStatsRow(),
          SizedBox(height: 26),
          _MacroBarsSection(),
        ],
      ),
    );
  }
}

// ─────────────── Header ───────────────
class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // SVG-style nutrition icon
      SizedBox(
  width: 27.89,
  height: 27.66,
  child: SvgPicture.asset(
    'assets/Images/nutrition.svg',
    fit: BoxFit.contain,
  ),
),
        const SizedBox(width: 8),
        Text(
          'Nutrition',
          style: AppTextStyles.base.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15.54,
            letterSpacing: 0.5 * 15.54 / 100,
            height: 1.0,
            color: AppColors.black,
          ),
        ),
        const Spacer(),
        // Arrow button — 32.64 × 27.19
       
SvgPicture.asset(
  'assets/Images/arrow.svg',
  width: 10,
  height: 13,
  
),
      ],
    );
  }
}

// ─────────────── Stats Row ───────────────
class _NutritionStatsRow extends StatelessWidget {
  const _NutritionStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
      _StatBlock(
  iconPath: 'assets/Images/burn.svg',
  value: '435',
  label: 'burn',
),
        _KcalGauge(eaten: 1000, total: 1500),
      _StatBlock(
  iconPath: 'assets/Images/eaten.svg',
  value: '210',
  label: 'eaten',
),
      ],
    );
  }
}
class _StatBlock extends StatelessWidget {
  final String iconPath;  
  final String value;
  final String label;

  const _StatBlock({
    required this.iconPath,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(   
          iconPath,
          width: 17.49,
          height: 23.27,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.base.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.base.copyWith(
            fontSize: 12,
            color: AppColors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}


class _KcalGauge extends StatelessWidget {
  final int eaten;
  final int total;

  const _KcalGauge({required this.eaten, required this.total});

 @override
Widget build(BuildContext context) {
  return SizedBox(
    width: 110,
    height: 70,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(110, 64),
          painter: _GaugePainter(
            progress: eaten / total,
            trackColor: AppColors.deepOcean.withOpacity(0.3),
            fillColor: AppColors.deepOcean,
          ),
        ),
        Positioned(
          bottom: 6,  
          child: Column(
            children: [
              Text(
                '$eaten',
                style: AppTextStyles.base.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.black,
                ),
              ),
              Text(
                'of $total kcal',
                style: AppTextStyles.base.copyWith(
                  fontSize: 10,
                  color: AppColors.black.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  const _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

 @override
void paint(Canvas canvas, Size size) {
  final cx = size.width / 2;
  final cy = size.height - 4;
  final radius = size.width / 2 - 10;

  final rect = Rect.fromCircle(
    center: Offset(cx, cy),
    radius: radius,
  );
  canvas.drawArc(
    rect,
    pi,
    pi,
    false,
    Paint()
      ..color = trackColor
      ..strokeWidth = 6  
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawArc(
    rect,
    pi,
    pi * progress,
    false,
    Paint()
      ..color = fillColor
      ..strokeWidth = 12    
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );
}

  @override
  bool shouldRepaint(_GaugePainter old) => old.progress != progress;
}
class _MacroBarsSection extends StatelessWidget {
  const _MacroBarsSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MacroItem(
  label: 'Carb',
  value: 0.65,
  selectedColor: Color(0xFFB524FF),
  remaining: '106g left',
),
        ),
        SizedBox(width: 10),
        Expanded(
          child:const _MacroItem(
  label: 'Protein',
  value: 0.45,
  selectedColor: Color(0xFFFFC853),
  remaining: '92g left',
),
        ),
        SizedBox(width: 10),
        Expanded(
          child:const _MacroItem(
  label: 'Fat',
  value: 0.78,
  selectedColor: Color(0xFFEB426A),
  remaining: '122g left',
),
        ),
      ],
    );
  }
}
class _MacroItem extends StatelessWidget {
  final String label;
  final double value;
  final Color selectedColor;
  final String remaining;

  const _MacroItem({
    required this.label,
    required this.value,
    required this.selectedColor,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 7.18,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35.9),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor:
                  AppColors.deepOcean.withOpacity(0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(selectedColor),
              minHeight: 7.18,
            ),
          ),
        ),

        6.h,

    
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.base.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.black,
          ),
        ),
        2.h,
        Text(
          remaining,
          textAlign: TextAlign.center,
          style: AppTextStyles.base.copyWith(
            fontSize: 11,
            color: AppColors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
