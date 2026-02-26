import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_card_theme.dart';
import 'app_text_theme.dart';

class AppTheme {
  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.lightBlue500,
    scaffoldBackgroundColor: AppColors.blue900,
    extensions: [
      const AppCardTheme(
        backgroundColor: AppColors.blue700,
        borderColor: AppColors.grey300,
        shadowColor: AppColors.darkshadow,
        borderRadius: 8,
        blurRadius: 4,
        offset: Offset(4, 4),
        spreadRadius: 0,
      ),
      AppTextThemeExtension(AppTextTheme.create()),
    ],
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lightBlue500,
      secondary: AppColors.grey200,
      error: AppColors.red600,
      surface: AppColors.blue500,
      onPrimary: AppColors.blue700,
      onSecondary: AppColors.grey300,
      onSurface: AppColors.textDark,
    ),
    elevatedButtonTheme: _darkElevatedButtonTheme,
    appBarTheme: _darkAppBarTheme,
    inputDecorationTheme: _darkInputDecorationTheme,
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.textDark,
    scaffoldBackgroundColor: AppColors.textDark,
    extensions: [
      const AppCardTheme(
        backgroundColor: AppColors.grey50,
        borderColor: AppColors.grey900,
        shadowColor: AppColors.lightshadow,
        borderRadius: 8,
        blurRadius: 4,
        offset: Offset(4, 4),
        spreadRadius: 0,
      ),
      AppTextThemeExtension(AppTextTheme.create()),
    ],
    colorScheme: const ColorScheme.light(
      primary: AppColors.textDark,
      secondary: AppColors.grey800,
      error: AppColors.red600,
      surface: AppColors.grey50,
      onPrimary: AppColors.blue900,
      onSecondary: AppColors.blue900,
      onSurface: AppColors.blue900,
    ),
    elevatedButtonTheme: _lightElevatedButtonTheme,
    appBarTheme: _lightAppBarTheme,
    inputDecorationTheme: _lightInputDecorationTheme,
  );

  // ── Button Themes ──────────────────────────

  static final ElevatedButtonThemeData _lightElevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.lightBlue700,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    ),
  );

  static final ElevatedButtonThemeData _darkElevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.lightBlue500,
      foregroundColor: AppColors.blue700,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
    ),
  );

  // ── Input Decoration Themes ────────────────

  static final InputDecorationTheme _darkInputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.blue700,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.blue400),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.blue400),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.lightBlue500),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.red600),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.red600),
    ),
    labelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.grey200,
      fontFamily: 'Inter',
    ),
    hintStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.grey700,
      fontFamily: 'Inter',
    ),
  );

  static final InputDecorationTheme _lightInputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.grey50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.grey600),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.grey600),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.lightBlue700),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.red600),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: AppColors.red600),
    ),
    labelStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.blue900,
      fontFamily: 'Inter',
    ),
    hintStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.grey700,
      fontFamily: 'Inter',
    ),
  );

  // ── AppBar Themes ──────────────────────────

  static const AppBarTheme _darkAppBarTheme = AppBarTheme(
    backgroundColor: AppColors.blue500,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.grey50,
      fontFamily: 'Inter',
    ),
    iconTheme: IconThemeData(color: AppColors.grey50),
  );

  static const AppBarTheme _lightAppBarTheme = AppBarTheme(
    backgroundColor: AppColors.grey200,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.blue900,
      fontFamily: 'Inter',
    ),
    iconTheme: IconThemeData(color: AppColors.blue900),
  );

  AppTheme._();
}
