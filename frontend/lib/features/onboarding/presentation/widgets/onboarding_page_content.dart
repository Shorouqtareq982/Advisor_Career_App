import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OnboardingPageContent extends StatelessWidget {
  final String imagePath;
  final String title;
  final String body;

  const OnboardingPageContent({
    super.key,
    required this.imagePath,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final isShort = h < 520;

        // ✅ FIX: image size depends on BOTH width & height
        final imgFromW = w * 0.72;
        final imgFromH = h * (isShort ? 0.42 : 0.48);
        final imgSize = math.min(imgFromW, imgFromH).clamp(160.0, 320.0);

        final titleSize = (w * 0.055).clamp(18.0, 26.0);
        final bodySize = (w * 0.034).clamp(12.0, 15.0);
        final bodyMaxWidth = (w * 0.92).clamp(280.0, 520.0);

        final topSpace = (h * (isShort ? 0.02 : 0.04)).clamp(6.0, 18.0);
        final afterImg = (h * (isShort ? 0.02 : 0.035)).clamp(8.0, 20.0);
        final afterTitle = (h * (isShort ? 0.012 : 0.018)).clamp(6.0, 14.0);

        return Column(
          children: [
            SizedBox(height: topSpace),
            SizedBox(
              width: imgSize,
              height: imgSize,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: (imgSize * 0.35).clamp(56.0, 96.0),
                      color: AppColors.lightBlue500,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: afterImg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: AppColors.purple500,
                height: 1.2,
              ),
            ),
            SizedBox(height: afterTitle),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bodyMaxWidth),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: bodySize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey50.withOpacity(0.9),
                  height: 1.35,
                ),
              ),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}
