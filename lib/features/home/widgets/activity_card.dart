import 'dart:ui';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:demo_p/core/constants/app_sizes.dart';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/constants/app_strings.dart';
import 'package:demo_p/core/constants/app_text_styles.dart';

class ActivityCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final String time;

  const ActivityCard({
    super.key,
    required this.image,
    this.title = AppStrings.exercise,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 194,
      height: AppSizes.cardHeight,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        image: DecorationImage(
          image: AssetImage(image),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [

          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.30),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(
                      color: AppColors.white.withOpacity(0.25),
                    ),
                  ),

                 child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

   4.h,


    Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.cardTitle,
          ),
        ),
        Text(
          time,
          style: AppTextStyles.cardTime,
        ),
      ],
    ),

   2.h,

    /// SUBTITLE
    Text(
      subtitle,
      style: AppTextStyles.cardSubtitle,
    ),
  ],
),
                ),
              ),
            ),
          ),

       
        ],
      ),
    );
  }
}