import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class AIPortfolioHeader extends StatelessWidget {
  final VoidCallback onBack;
  final ValueChanged<TapDownDetails> onMenuTap;

  const AIPortfolioHeader({
    super.key,
    required this.onBack,
    required this.onMenuTap,
  });

  static const _basePath = 'assets/images/ai_protifilo';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textSecondary = isDark ? AppColors.grey400 : AppColors.grey800;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: context.w(24),
                height: context.w(24),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: context.w(18),
                  color: textPrimary,
                ),
              ),
            ),
            Image.asset(
              '$_basePath/logo.png',
              height: context.h(50),
              fit: BoxFit.contain,
            ),
            GestureDetector(
              onTapDown: onMenuTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                '$_basePath/options.png',
                width: context.w(24),
                height: context.w(24),
                color: textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(6)),
        Text(
          'Portfolio Builder',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(19).clamp(17.0, 20.0),
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        SizedBox(height: context.h(6)),
        Text(
          'Create a professional portfolio that tells your\nstory and showcases your experience',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(16).clamp(14.0, 16.0),
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}
