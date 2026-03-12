import 'package:flutter/material.dart';

class AppTextTheme {
  // H1  –  48px / 120%
  final TextStyle h1Regular;
  final TextStyle h1Medium;
  final TextStyle h1Bold;

  // H2  –  40px / 120%
  final TextStyle h2Regular;
  final TextStyle h2Medium;
  final TextStyle h2Bold;

  // H3  –  30px / 120%
  final TextStyle h3Regular;
  final TextStyle h3Medium;
  final TextStyle h3Bold;

  // H4  –  28px / 120%
  final TextStyle h4Regular;
  final TextStyle h4Medium;
  final TextStyle h4Bold;

  // H5  –  23px / 120%
  final TextStyle h5Regular;
  final TextStyle h5Medium;
  final TextStyle h5Bold;

  // Title1  –  19px / 120%
  final TextStyle title1Regular;
  final TextStyle title1Medium;
  final TextStyle title1Bold;

  // Title2  –  16px / 120%
  final TextStyle title2Regular;
  final TextStyle title2Medium;
  final TextStyle title2Bold;

  // body  –  13px / 120%
  final TextStyle bodyRegular;
  final TextStyle bodyMedium;
  final TextStyle bodyBold;

  // caption  –  11px / 120%
  final TextStyle captionRegular;
  final TextStyle captionMedium;
  final TextStyle captionBold;

  const AppTextTheme({
    required this.h1Regular,
    required this.h1Medium,
    required this.h1Bold,
    required this.h2Regular,
    required this.h2Medium,
    required this.h2Bold,
    required this.h3Regular,
    required this.h3Medium,
    required this.h3Bold,
    required this.h4Regular,
    required this.h4Medium,
    required this.h4Bold,
    required this.h5Regular,
    required this.h5Medium,
    required this.h5Bold,
    required this.title1Regular,
    required this.title1Medium,
    required this.title1Bold,
    required this.title2Regular,
    required this.title2Medium,
    required this.title2Bold,
    required this.bodyRegular,
    required this.bodyMedium,
    required this.bodyBold,
    required this.captionRegular,
    required this.captionMedium,
    required this.captionBold,
  });

  factory AppTextTheme.create() => AppTextTheme(
        h1Regular: _s(48, FontWeight.w400),
        h1Medium: _s(48, FontWeight.w500),
        h1Bold: _s(48, FontWeight.w700),
        h2Regular: _s(40, FontWeight.w400),
        h2Medium: _s(40, FontWeight.w500),
        h2Bold: _s(40, FontWeight.w700),
        h3Regular: _s(30, FontWeight.w400),
        h3Medium: _s(30, FontWeight.w500),
        h3Bold: _s(30, FontWeight.w700),
        h4Regular: _s(28, FontWeight.w400),
        h4Medium: _s(28, FontWeight.w500),
        h4Bold: _s(28, FontWeight.w700),
        h5Regular: _s(23, FontWeight.w400),
        h5Medium: _s(23, FontWeight.w500),
        h5Bold: _s(23, FontWeight.w700),
        title1Regular: _s(19, FontWeight.w400),
        title1Medium: _s(19, FontWeight.w500),
        title1Bold: _s(19, FontWeight.w700),
        title2Regular: _s(16, FontWeight.w400),
        title2Medium: _s(16, FontWeight.w500),
        title2Bold: _s(16, FontWeight.w700),
        bodyRegular: _s(13, FontWeight.w400),
        bodyMedium: _s(13, FontWeight.w500),
        bodyBold: _s(13, FontWeight.w700),
        captionRegular: _s(11, FontWeight.w400),
        captionMedium: _s(11, FontWeight.w500),
        captionBold: _s(11, FontWeight.w700),
      );

  static TextStyle _s(double size, FontWeight weight) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFamily: 'Inter',
        height: 1.2, // 120% line-height
      );
}

// ─────────────────────────────────────────────
//  ThemeExtension
// ─────────────────────────────────────────────

class AppTextThemeExtension extends ThemeExtension<AppTextThemeExtension> {
  final AppTextTheme appTextTheme;

  const AppTextThemeExtension(this.appTextTheme);

  @override
  AppTextThemeExtension copyWith({AppTextTheme? appTextTheme}) =>
      AppTextThemeExtension(appTextTheme ?? this.appTextTheme);

  @override
  AppTextThemeExtension lerp(
          ThemeExtension<AppTextThemeExtension>? other, double t) =>
      this;
}

extension AppTextThemeContext on BuildContext {
  AppTextTheme get appTextTheme =>
      Theme.of(this).extension<AppTextThemeExtension>()!.appTextTheme;
}

extension ResponsiveText on BuildContext {
  double _scaleFactor() {
    double width = MediaQuery.of(this).size.width;

    double scale = width / 375;

    return scale.clamp(0.8, 1.4); // مابين 80% و 140%
  }

  TextStyle responsiveText(TextStyle style, {double additionalScale = 1.0}) {
    return style.copyWith(
      fontSize: (style.fontSize! * _scaleFactor() * additionalScale),
    );
  }

  Widget text(
    String data, {
    required TextStyle style,
    double additionalScale = 1.0,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      data,
      style: responsiveText(style, additionalScale: additionalScale),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
