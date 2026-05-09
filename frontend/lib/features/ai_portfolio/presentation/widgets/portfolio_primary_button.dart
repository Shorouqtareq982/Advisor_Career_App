import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class PortfolioPrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const PortfolioPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.h(32),
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.lightBlue700 : AppColors.grey200,
          foregroundColor: enabled ? Colors.white : AppColors.grey600,
          disabledBackgroundColor: AppColors.grey200,
          disabledForegroundColor: AppColors.grey600,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.w(120),
            vertical: context.h(8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: context.sp(13).clamp(12.0, 13.0),
          ),
        ),
      ),
    );
  }
}
