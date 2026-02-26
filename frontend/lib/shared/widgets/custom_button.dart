import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/responsive_extension.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.width,
    this.height,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? 48.0;
    final borderRadius = context.r(50);
    final loadingSize = 24.0;

    final bgColor = backgroundColor ??
        (isPrimary ? AppColors.lightBlue700 : AppColors.lightBlue500);
    final fgColor =
        textColor ?? (isPrimary ? AppColors.grey50 : AppColors.blue700);

    return SizedBox(
      width: width ?? double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? SizedBox(
                height: loadingSize,
                width: loadingSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: buttonHeight * 0.4,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                  fontFamily: 'Inter',
                  height: 1.2,
                ),
              ),
      ),
    );
  }
}
