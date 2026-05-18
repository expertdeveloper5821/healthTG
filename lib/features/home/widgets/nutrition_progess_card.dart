import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_sizes.dart';
import 'package:demo_p/core/constants/app_text_styles.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NutritionProgressCard extends StatelessWidget {
  const NutritionProgressCard({super.key});

  static const double _totalWidth = 366;
  static const double _totalHeight = 92.62;

  static const double _topHeight = 59.16;

  static const double _bottomHeight = 54;
  static const double _bottomTop = 543.62 - 505;
  static const double _bottomRadius = 11.65;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      width: double.infinity,
      height: _totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _bottomTop,
            left: 0,
            right: 0,
            child: const _BottomProgressCard(),
          ),
          const _TopCard(),
        ],
      ),
    );
  }
}
class _TopCard extends StatelessWidget {
  const _TopCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: NutritionProgressCard._topHeight,
      decoration: BoxDecoration(
        gradient: AppColors.blueCardGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 27.89,
            height: 27.66,
            child: SvgPicture.asset(
              'assets/Images/nutrition.svg',
              fit: BoxFit.contain,
            ),
          ),

          10.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Nutrition',
                  style: AppTextStyles.base.copyWith(
                    fontSize: 15.54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5 * 15.54 / 100,
                    height: 1.0,
                    color: AppColors.black,
                  ),
                ),

                const SizedBox(height: 8),

                /// SUBTEXT
                Text(
                  '1000 Kcal/1500 kcal',
                  style: AppTextStyles.base.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),

SvgPicture.asset(
  'assets/Images/arrow.svg',
  width: 10,
  height: 13,
  
),
        ],
      ),
    );
  }
}


class _BottomProgressCard extends StatelessWidget {
  const _BottomProgressCard();

  static const double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: NutritionProgressCard._bottomHeight,
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.20),
        borderRadius: const BorderRadius.only(
          bottomLeft:
              Radius.circular(NutritionProgressCard._bottomRadius),
          bottomRight:
              Radius.circular(NutritionProgressCard._bottomRadius),
        ),
        border: Border.all(
          color: AppColors.white.withOpacity(0.15),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nutrition progress',
                style: AppTextStyles.base.copyWith(
                  fontSize: 8,
                  color: AppColors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.base.copyWith(
                  fontSize: 8,
                  color:AppColors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF4FC3F7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
