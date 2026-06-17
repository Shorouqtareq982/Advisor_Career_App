import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class DeletePlanDialog extends StatelessWidget {
  final VoidCallback onDelete;

  const DeletePlanDialog({super.key, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dialogBg = isDark ? const Color(0xFF111A38) : Colors.white;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;
    final cancelBg = isDark ? const Color(0xFF1C2647) : AppColors.grey200;
    final cancelText = isDark ? AppColors.grey50 : AppColors.grey800;
    final borderColor =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.35) : Colors.transparent;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(18)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.r(24)),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(18),
          vertical: context.h(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete Plan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(20).clamp(18.0, 22.0),
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: titleColor,
              ),
            ),
            SizedBox(height: context.h(10)),
            Text(
              "Are you sure you want to delete this plan?\nYou won’t be able to recover it later.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(14).clamp(12.0, 15.0),
                fontWeight: FontWeight.w500,
                height: 1.25,
                color: bodyColor,
              ),
            ),
            SizedBox(height: context.h(18)),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cancelBg,
                        foregroundColor: cancelText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(14).clamp(13.0, 15.0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.w(12)),
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: ElevatedButton(
                      onPressed: onDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD03430),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(14).clamp(13.0, 15.0),
                          fontWeight: FontWeight.w700,
                        ),
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
