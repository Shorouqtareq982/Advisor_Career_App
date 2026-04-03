import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class AnalysisPendingDialog extends StatelessWidget {
  const AnalysisPendingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.r(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.w(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            context.text(
              'You\'ll receive an alert once your resume analysis is complete.',
              style: textTheme.bodyMedium.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(20)),
            SizedBox(
              width: double.infinity,
              height: context.h(44),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/resume-optimization');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                ),
                child: context.text(
                  'Got it',
                  style: textTheme.bodyBold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
