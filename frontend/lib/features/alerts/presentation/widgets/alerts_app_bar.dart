import 'package:flutter/material.dart';
import 'package:growza/core/constants/app_colors.dart';
import 'package:growza/core/extensions/responsive_extension.dart';

class AlertsAppBar extends StatelessWidget {
  final VoidCallback onBack;

  const AlertsAppBar({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.w(16),
        context.h(8),
        context.w(16),
        0,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(context.r(24)),
            child: Padding(
              padding: EdgeInsets.all(context.w(6)),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: context.icon(18),
                color: isDark ? AppColors.grey50 : AppColors.blue900,
              ),
            ),
          ),
          const Spacer(),
          Image.asset(
            'assets/images/branding/logo.png',
            height: context.logo(32),
            fit: BoxFit.contain,
          ),
          const Spacer(),
          SizedBox(width: context.w(30)),
        ],
      ),
    );
  }
}
