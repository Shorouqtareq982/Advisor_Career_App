import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class MarketInsightsHeader extends StatelessWidget {
  final VoidCallback onBack;

  const MarketInsightsHeader({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? AppColors.grey100 : AppColors.blue900;
    final logoSize = context.icon(44);

    return SizedBox(
      height: context.h(50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(context.r(24)),
            child: SizedBox(
              width: context.w(32),
              height: context.h(32),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: iconColor,
                size: context.icon(18),
              ),
            ),
          ),
          Image.asset(
            'assets/images/branding/logo.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
          SizedBox(
            width: context.w(32),
            height: context.h(32),
          ),
        ],
      ),
    );
  }
}
