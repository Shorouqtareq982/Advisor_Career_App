import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:growza/core/constants/app_colors.dart';

class HomeBackArrow extends StatelessWidget {
  const HomeBackArrow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => context.go('/home'),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: isDark ? AppColors.grey50 : AppColors.blue900,
        ),
      ),
    );
  }
}
