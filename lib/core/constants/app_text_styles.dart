import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_sizes.dart';

class AppTextStyles {

  static const String fontFamily = "Inter";

  static const TextStyle base = TextStyle(
    fontFamily: fontFamily,
    height: 1,
    letterSpacing: 0.5,
  );


  static final TextStyle heading = base.copyWith(
    fontSize: AppSizes.textXL,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static final TextStyle subHeading = base.copyWith(
    fontSize: AppSizes.textLg,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final TextStyle body = base.copyWith(
    fontSize: AppSizes.textMd,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static final TextStyle small = base.copyWith(
    fontSize: AppSizes.textSm,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static final TextStyle button = base.copyWith(
    fontSize: AppSizes.textMd,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static final TextStyle cardTitle = base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  static final TextStyle cardSubtitle = base.copyWith(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  static final TextStyle cardTime = base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  /// ================= SECTION HEADER =================
  static final TextStyle sectionTitle = base.copyWith(
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static final TextStyle sectionAction = base.copyWith(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF7CA9D8),
  );

static final TextStyle medicationTitle = base.copyWith(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: AppColors.black,
  letterSpacing: 0,
);

static final TextStyle medicationSubtitle = base.copyWith(
  fontSize: 10,
  fontWeight: FontWeight.w300,
  color: AppColors.black,
  letterSpacing: 0,
);


static final TextStyle medicationDose = base.copyWith(
  fontSize: 11,
  fontWeight: FontWeight.w300, 
  color: AppColors.background, 
  letterSpacing: 0,
);
static final TextStyle medicationHeader = base.copyWith(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.background,
);

static final TextStyle seeAll = const TextStyle(
 
  fontSize: 11,
  fontWeight: FontWeight.w700,

  color: Color(0xFF000206),
);

static final TextStyle medicationButton = base.copyWith(
  fontSize: 13.6,
  fontWeight: FontWeight.w500,
  color: AppColors.white,
);
}