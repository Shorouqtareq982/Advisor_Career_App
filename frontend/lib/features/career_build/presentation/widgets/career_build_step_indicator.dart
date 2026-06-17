// lib/features/career_build/presentation/widgets/career_build_step_indicator.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class CareerBuildStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const CareerBuildStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final active = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final inactive =
        isDark ? AppColors.blue200.withOpacity(0.35) : AppColors.grey300;
    final lineInactive =
        isDark ? AppColors.blue200.withOpacity(0.25) : AppColors.grey300;

    return SizedBox(
      height: context.h(24),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            final leftStep = (i ~/ 2) + 1;
            final isDone = leftStep < currentStep;

            return Expanded(
              child: Container(
                height: context.h(2),
                color: isDone ? active : lineInactive,
              ),
            );
          }

          final stepIndex = (i ~/ 2) + 1;
          final isActive = stepIndex <= currentStep;

          return Container(
            width: context.w(22),
            height: context.w(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? active : inactive,
            ),
            child: Center(
              child: Text(
                '$stepIndex',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(12).clamp(10.0, 13.0),
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey50,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
