import 'package:flutter/material.dart';

@immutable
class AppCardTheme extends ThemeExtension<AppCardTheme> {
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double borderRadius;
  final double blurRadius;
  final Offset offset;
  final double spreadRadius;

  const AppCardTheme({
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.borderRadius,
    required this.blurRadius,
    required this.offset,
    required this.spreadRadius,
  });

  @override
  AppCardTheme copyWith({
    Color? backgroundColor,
    Color? borderColor,
    Color? shadowColor,
    double? borderRadius,
    double? blurRadius,
    Offset? offset,
    double? spreadRadius,
  }) {
    return AppCardTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      shadowColor: shadowColor ?? this.shadowColor,
      borderRadius: borderRadius ?? this.borderRadius,
      blurRadius: blurRadius ?? this.blurRadius,
      offset: offset ?? this.offset,
      spreadRadius: spreadRadius ?? this.spreadRadius,
    );
  }

  @override
  AppCardTheme lerp(ThemeExtension<AppCardTheme>? other, double t) {
    if (other is! AppCardTheme) return this;
    return AppCardTheme(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      borderRadius: borderRadius + (other.borderRadius - borderRadius) * t,
      blurRadius: blurRadius + (other.blurRadius - blurRadius) * t,
      offset: Offset.lerp(offset, other.offset, t)!,
      spreadRadius: spreadRadius + (other.spreadRadius - spreadRadius) * t,
    );
  }
}
