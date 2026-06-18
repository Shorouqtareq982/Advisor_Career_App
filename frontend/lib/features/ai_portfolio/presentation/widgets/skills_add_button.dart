import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class SkillsAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const SkillsAddButton({
    super.key,
    required this.onTap,
  });

  static const _basePath = 'assets/images/ai_protifilo';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.r(8)),
      child: Container(
        width: double.infinity,
        height: context.h(43),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(context.r(8)),
          border: Border.all(color: AppColors.lightBlue700, width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                '$_basePath/add.png',
                width: context.w(16),
                height: context.w(16),
                color: AppColors.lightBlue700,
              ),
              SizedBox(width: context.w(8)),
              Text(
                'Add Skill',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
                  color: AppColors.lightBlue700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
