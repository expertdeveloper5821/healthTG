import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
 fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,


    appBarTheme:  AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.white),
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

  
    cardColor: AppColors.background,

  
    textTheme:  TextTheme(
      bodyLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // 🎯 Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cardGradientEnd,
      secondary: AppColors.cardGradientStart,
    ),

    // 🔘 Icon Theme
    iconTheme: const IconThemeData(
      color: AppColors.white,
    ),
  );
}