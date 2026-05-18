import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../utils/extensions.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText = "View all",
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /// TITLE
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Mulish",
            fontWeight: FontWeight.w400,
            fontSize: 15.5,
            height: 1,
            letterSpacing: 0.5,
            color: AppColors.textPrimary,
          ),
        ),

        /// ACTION
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: const TextStyle(
              fontFamily: "Mulish",
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              height: 1,
              color: Color(0xFF7CA9D8),
            ),
          ),
        ),
      ],
    ).paddingSymmetric(h: AppSizes.md, v: AppSizes.sm);
  }
}