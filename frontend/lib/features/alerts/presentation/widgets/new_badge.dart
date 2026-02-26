import 'package:flutter/material.dart';
import 'package:growza/core/constants/app_colors.dart';
import 'package:growza/core/extensions/responsive_extension.dart';

class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(8),
        vertical: context.h(4),
      ),
      decoration: BoxDecoration(
        color: AppColors.lightBlue700,
        borderRadius: BorderRadius.circular(context.r(8)),
      ),
      child: Text(
        'New',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(10),
          fontWeight: FontWeight.w700,
          color: AppColors.grey50,
          height: 1.0,
        ),
      ),
    );
  }
}
