import 'package:flutter/material.dart';

class AppColors {
  // ─── Blue (Primary Colours) ───────────────────────────────────
  static const Color blue50 = Color(0xFFE9EAED);
  static const Color blue100 = Color(0xFFBBBDC6);
  static const Color blue200 = Color(0xFF9A9DAA);
  static const Color blue300 = Color(0xFF6C7083);
  static const Color blue400 = Color(0xFF4F546B);
  static const Color blue500 = Color(0xFF232946);
  static const Color blue600 = Color(0xFF202540);
  static const Color blue700 = Color(0xFF191D32);
  static const Color blue800 = Color(0xFF131727);
  static const Color blue900 = Color(0xFF0F111D);

  // ─── Light Blue (Secondary Colours) ──────────────────────────
  static const Color lightBlue50 = Color(0xFFEBF8FB);
  static const Color lightBlue100 = Color(0xFFC0E9F3);
  static const Color lightBlue200 = Color(0xFFA2DEED);
  static const Color lightBlue300 = Color(0xFF78CFE4);
  static const Color lightBlue400 = Color(0xFF5DC5DF);
  static const Color lightBlue500 = Color(0xFF35B7D7);
  static const Color lightBlue600 = Color(0xFF30A7C4);
  static const Color lightBlue700 = Color(0xFF268299);
  static const Color lightBlue800 = Color(0xFF1D6576);
  static const Color lightBlue900 = Color(0xFF164D5A);

// ─── Purple (Secondary Colours) ───────────────────────────────
  static const Color purple50 = Color(0xFFF5F4FA);
  static const Color purple100 = Color(0xFFE0DCEF);
  static const Color purple200 = Color(0xFFD1CBE7);
  static const Color purple300 = Color(0xFFBDB3DC);
  static const Color purple400 = Color(0xFFB0A5D5);
  static const Color purple500 = Color(0xFF9C8ECB);
  static const Color purple600 = Color(0xFF8E81B9);
  static const Color purple700 = Color(0xFF6F6590);
  static const Color purple800 = Color(0xFF564E70);
  static const Color purple900 = Color(0xFF423C55);

// ─── Grey (Natural Colours) ───────────────────────────────────
  static const Color grey50 = Color(0xFFF8F8F8);
  static const Color grey100 = Color(0xFFebebeb);
  static const Color grey200 = Color(0xFFE1E1E1);
  static const Color grey300 = Color(0xFFD3D3D3);
  static const Color grey400 = Color(0xFFCACACA);
  static const Color grey500 = Color(0xFFBDBDBD);
  static const Color grey600 = Color(0xFFACACAC);
  static const Color grey700 = Color(0xFF868686);
  static const Color grey800 = Color(0xFF686868);
  static const Color grey900 = Color(0xFF4F4F4F);

// ─── Green (Success Colours) ──────────────────────────────────
  static const Color green50 = Color(0xFFEDF7EE);
  static const Color green100 = Color(0xFFC8E6C9);
  static const Color green200 = Color(0xFFADDAAF);
  static const Color green300 = Color(0xFF87C98A);
  static const Color green400 = Color(0xFF70BF73);
  static const Color green500 = Color(0xFF4CAF50);
  static const Color green600 = Color(0xFF459F49);
  static const Color green700 = Color(0xFF367C39);
  static const Color green800 = Color(0xFF2A602C);
  static const Color green900 = Color(0xFF204A22);

// ─── Orange (Warning Colours) ─────────────────────────────────
  static const Color orange50 = Color(0xFFFFF5E6);
  static const Color orange100 = Color(0xFFFFDFB0);
  static const Color orange200 = Color(0xFFFFD08A);
  static const Color orange300 = Color(0xFFFFBA54);
  static const Color orange400 = Color(0xFFFFAD33);
  static const Color orange500 = Color(0xFFFF9800);
  static const Color orange600 = Color(0xFFE88A00);
  static const Color orange700 = Color(0xFFB56C00);
  static const Color orange800 = Color(0xFF8C5400);
  static const Color orange900 = Color(0xFF6B4000);

// ─── Red (Error Colours) ──────────────────────────────────────
  static const Color red50 = Color(0xFFFCEBEB);
  static const Color red100 = Color(0xFFF7C2C0);
  static const Color red200 = Color(0xFFF3A4A2);
  static const Color red300 = Color(0xFFEE7A78);
  static const Color red400 = Color(0xFFEA615D);
  static const Color red500 = Color(0xFFE53935);
  static const Color red600 = Color(0xFFD03430);
  static const Color red700 = Color(0xFFA32826);
  static const Color red800 = Color(0xFF7E1F1D);
  static const Color red900 = Color(0xFF601816);

  static const Color darkshadow = Color(0x28668686);
  static const Color lightshadow = Color(0x40000000);
  static const Color textDark = Color(0xFFEBEBEB);

  // ─── Gradient ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [lightBlue400, lightBlue700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Adaptive Helpers ─────────────────────────────────────────

  static Color backgroundAdaptive(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? blue500 : grey100;
  }

  static Color cardAdaptive(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? blue700 : AppColors.grey50;
  }

  static Color textPrimaryAdaptive(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.grey50 : blue900;
  }

  static Color textMutedAdaptive(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? grey400 : grey800;
  }

  AppColors._();
}
