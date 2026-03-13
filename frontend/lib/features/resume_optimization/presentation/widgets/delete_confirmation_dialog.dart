import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

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
              'Delete Resume Insights',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(12)),
            context.text(
              'Are you sure you want to delete this resume insight? You won\'t be able to recover it later.',
              style: textTheme.bodyRegular.copyWith(color: textMuted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(24)),
            Row(
              children: [
                // Cancel
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(
                          color: isDark ? AppColors.blue300 : AppColors.grey400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(50)),
                        ),
                      ),
                      child: context.text(
                        'Cancel',
                        style: textTheme.bodyBold.copyWith(color: textPrimary),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.w(12)),
                // Delete
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red500,
                        foregroundColor: AppColors.grey50,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(50)),
                        ),
                      ),
                      child: context.text(
                        'Delete',
                        style: textTheme.bodyBold
                            .copyWith(color: AppColors.grey50),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
