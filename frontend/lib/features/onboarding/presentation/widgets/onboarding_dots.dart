import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OnboardingDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const OnboardingDots({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        final gap = (w * 0.015).clamp(3.0, 8.0);
        final active = (w * 0.03).clamp(8.0, 12.0);
        final inactive = (w * 0.022).clamp(7.0, 10.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final isActive = i == activeIndex;
            final size = isActive ? active : inactive;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: EdgeInsets.symmetric(horizontal: gap),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.lightBlue500
                    : AppColors.grey800.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
