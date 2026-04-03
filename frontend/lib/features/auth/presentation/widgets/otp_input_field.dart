import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class OtpInputField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onCompleted;
  final String? errorText;
  final bool useTheme;

  const OtpInputField({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.errorText,
    this.useTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = useTheme && Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    final boxWidth = context.w(40);
    final boxHeight = context.h(40);
    final fontSize = context.sp(20);
    final borderRadius = context.r(16);
    final cursorHeight = context.h(20);

    Color getBackgroundColor() {
      if (!useTheme) return AppColors.grey50;
      return isDark ? AppColors.blue700 : AppColors.grey50;
    }

    Color getTextColor() {
      if (!useTheme) return AppColors.blue900;
      return isDark ? AppColors.grey50 : AppColors.blue900;
    }

    Color getBorderColor() {
      if (errorText != null) return AppColors.red600;
      if (!useTheme) return AppColors.grey600;
      return isDark ? AppColors.blue400 : AppColors.grey600;
    }

    // Active/focused
    Color getActiveBorderColor() {
      if (errorText != null) return AppColors.red600;
      return isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    }

    final defaultPinTheme = PinTheme(
      width: boxWidth,
      height: boxHeight,
      textStyle: context.responsiveText(
        textTheme.title1Bold.copyWith(
          color: getTextColor(),
          fontSize: fontSize,
        ),
      ),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: getBorderColor(), width: 2),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: getActiveBorderColor(), width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: getActiveBorderColor(), width: 2),
      ),
    );

    return Column(
      children: [
        Pinput(
          controller: controller,
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: submittedPinTheme,
          showCursor: true,
          cursor: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 2,
                height: cursorHeight,
                color: isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
              ),
            ],
          ),
          onCompleted: onCompleted,
          keyboardType: TextInputType.number,
          hapticFeedbackType: HapticFeedbackType.lightImpact,
          autofocus: true,
        ),
        if (errorText != null) ...[
          SizedBox(height: context.h(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.red600, size: context.icon(16)),
              SizedBox(width: context.w(6)),
              Flexible(
                child: context.text(
                  errorText!,
                  style: textTheme.bodyMedium.copyWith(color: AppColors.red600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
