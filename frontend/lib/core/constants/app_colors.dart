import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary Colors
  static const Color primary = Color(0xFF35B7D7);

  /// Purple Background
  static const Color secondary = Color(0xFF9C8ECB);

  // Background Colors

  /// Dark Background
  static const Color backgroundDark = Color(0xFF0F111D);

  /// Light Background
  static const Color backgroundLight = Color(0xFFF8F8F8);

  static const Color surfaceDark = Color(0xFF232946);

  // Accent Colors
  ///  Aqua Wave
  static const Color aqua = Color(0xFF268299);

  /// Error/Alert
  static const Color error = Color(0xFFD03430);

  // Text Colors

  /// نص على خلفية داكنة
  static const Color textLight = Color(0xFFFFFFFF);

  /// نص على خلفية فاتحة
  static const Color textDark = Color(0xFF232946);

  /// نص ثانوي/رمادي
  static const Color textSecondary = Color(0xFFE1E1E1);

  // Gradients

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, aqua],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [secondary, backgroundDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Primary Colors
  static const Color primaryLight = Color(0xFF35B7D7);
  static const Color primaryDark = Color(0xFF232946);

  // Purple/Lavender
  static const Color purple = Color(0xFF9C8ECB);
  static const Color purpleLight = Color(0xFFA8B8D6);
  static const Color lavender = Color(0xFFB8A9E8);

  // Navy/Dark
  static const Color navyDark = Color(0xFF2D3047);
  static const Color navy = Color(0xFF3E4168);
  static const Color darkBackground = Color(0xFF1A1B2E);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F9FA);
  static const Color grey = Color(0xFF9CA3AF);
  static const Color greyLight = Color(0xFFE5E7EB);
  static const Color greyDark = Color(0xFF4B5563);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Background Colors
  static const Color background = Color(0xFFFFFFFF);

  // Card & Surface
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF3F4F6);
}
