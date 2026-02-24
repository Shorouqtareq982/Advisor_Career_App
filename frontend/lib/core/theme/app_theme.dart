import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.backgroundLight,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: 'Inter',
      textTheme: _textTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.backgroundDark,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      fontFamily: 'Inter',
      textTheme: _textTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
    );
  }

  // Typography
  static const TextTheme _textTheme = TextTheme(
    // "Welcome to Growza"
    headlineMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 23,
      fontWeight: FontWeight.w700, // Bold
      height: 1.2,
      letterSpacing: 0,
    ),

    // "Empower your career..."
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      fontWeight: FontWeight.w500, // Medium
      height: 1.2,
      letterSpacing: 0,
    ),

    //  "Sign In", "Sign Up"
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w700, // Bold
      height: 1.2,
      letterSpacing: 0,
    ),

    //Status bar - "8:20"
    labelSmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: 0,
    ),
  );

  // Button Themes

  /// Primary Button (Sign In)
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textDark,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      );

  /// Secondary Button (Sign Up)
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.textDark,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide.none,
        ),
      );
}
