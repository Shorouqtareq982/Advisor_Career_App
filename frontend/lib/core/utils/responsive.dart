import 'package:flutter/material.dart';

class Responsive {
  //   Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  //   Base Figma design (iPhone 13 mini)
  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  //  Maximum effective dimensions (prevents extreme scaling)
  static const double maxEffectiveWidth = 600.0;
  static const double maxEffectiveHeight = 900.0;

  //   Device type
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  //   Width scale factor
  static double _widthScaleFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveWidth =
        screenWidth > maxEffectiveWidth ? maxEffectiveWidth : screenWidth;
    return effectiveWidth / designWidth;
  }

  //   Height scale factor (independent from width)
  static double _heightScaleFactor(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveHeight =
        screenHeight > maxEffectiveHeight ? maxEffectiveHeight : screenHeight;
    return effectiveHeight / designHeight;
  }

  //   Combined scale factor (uses minimum of width/height for safety)
  static double _combinedScaleFactor(BuildContext context) {
    final widthScale = _widthScaleFactor(context);
    final heightScale = _heightScaleFactor(context);
    return widthScale < heightScale ? widthScale : heightScale;
  }

  //   Width scaling (width-based)
  static double width(BuildContext context, double designSize) {
    return designSize * _widthScaleFactor(context);
  }

  static double height(BuildContext context, double designSize) {
    return designSize * _heightScaleFactor(context);
  }

  static double fontSize(BuildContext context, double designFontSize) {
    final scaled = designFontSize * _combinedScaleFactor(context);

    return scaled.clamp(
      designFontSize * 0.85,
      designFontSize * 1.3,
    );
  }

  static double radius(BuildContext context, double designRadius) {
    return designRadius * _widthScaleFactor(context);
  }

  static double icon(BuildContext context, double designIconSize) {
    final scaled = designIconSize * _widthScaleFactor(context);

    if (isDesktop(context)) {
      return scaled.clamp(designIconSize * 0.9, designIconSize * 1.1);
    } else if (isTablet(context)) {
      return scaled.clamp(designIconSize * 0.9, designIconSize * 1.3);
    } else {
      return scaled.clamp(designIconSize * 0.9, designIconSize * 1.8);
    }
  }

  static double logo(BuildContext context, double designLogoSize) {
    final scaled = designLogoSize * _widthScaleFactor(context);

    if (isDesktop(context)) {
      return scaled.clamp(designLogoSize * 0.95, designLogoSize * 1.1);
    } else if (isTablet(context)) {
      return scaled.clamp(designLogoSize * 0.95, designLogoSize * 1.4);
    } else {
      return scaled.clamp(designLogoSize * 0.95, designLogoSize * 1.6);
    }
  }

  //  Responsive clamp with device-aware limits
  static double responsiveClamp(
    BuildContext context,
    double value, {
    double? mobileMin,
    double? mobileMax,
    double? tabletMin,
    double? tabletMax,
    double? desktopMin,
    double? desktopMax,
  }) {
    if (isDesktop(context)) {
      return value.clamp(
        desktopMin ?? mobileMin ?? 0,
        desktopMax ?? mobileMax ?? double.infinity,
      );
    } else if (isTablet(context)) {
      return value.clamp(
        tabletMin ?? mobileMin ?? 0,
        tabletMax ?? mobileMax ?? double.infinity,
      );
    } else {
      return value.clamp(
        mobileMin ?? 0,
        mobileMax ?? double.infinity,
      );
    }
  }

  //  Simple clamp helper
  static double clampSize(
    double value, {
    double min = 0,
    double max = double.infinity,
  }) {
    return value.clamp(min, max);
  }

  //   Get current scale factors (for debugging)
  static Map<String, double> getScaleFactors(BuildContext context) {
    return {
      'widthScale': _widthScaleFactor(context),
      'heightScale': _heightScaleFactor(context),
      'combinedScale': _combinedScaleFactor(context),
      'screenWidth': MediaQuery.of(context).size.width,
      'screenHeight': MediaQuery.of(context).size.height,
    };
  }
}
