import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OnboardingTopBar extends StatelessWidget {
  final VoidCallback onSkip;
  final bool showSkip;

  const OnboardingTopBar({
    super.key,
    required this.onSkip,
    this.showSkip = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topSafe = MediaQuery.of(context).padding.top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        final blobW = (w * 0.24).clamp(86.0, 120.0);
        final blobH = (blobW * 1.32).clamp(110.0, 150.0);
        final logoSize = (blobW * 0.42).clamp(34.0, 48.0);

        return SizedBox(
          height: blobH,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: SizedBox(
                  width: blobW,
                  height: blobH,
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/images/onboarding/onboarding_blob.png',
                        width: blobW,
                        height: blobH,
                        fit: BoxFit.contain,
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: Offset(-(blobW * 0.18), blobH * 0.05),
                          child: Image.asset(
                            'assets/images/branding/logo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showSkip)
                Positioned(
                  right: (w * 0.04).clamp(12.0, 18.0),
                  top: topSafe + 10,
                  child: InkWell(
                    onTap: onSkip,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (w * 0.02).clamp(6.0, 10.0),
                        vertical: 6,
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: (w * 0.032).clamp(12.0, 14.0),
                          fontWeight: FontWeight.w500,
                          color: AppColors.grey50,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
