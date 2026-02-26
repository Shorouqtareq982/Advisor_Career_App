import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OnboardingNavButtons extends StatelessWidget {
  final int index;
  final String primaryText;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

  const OnboardingNavButtons({
    super.key,
    required this.index,
    required this.primaryText,
    required this.onBack,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = MediaQuery.of(context).size.height;

        final btnH = (h * 0.06).clamp(44.0, 56.0);
        final singleW = (w * 0.92).clamp(280.0, 420.0);
        final halfW = ((w - 16) / 2).clamp(120.0, 220.0);
        final font = (w * 0.035).clamp(12.0, 14.0);

        // ✅ الصفحة الأولى: نفس زرار Next القديم (#35B7D7) من غير CustomButton
        if (index == 0) {
          return Center(
            child: SizedBox(
              width: singleW,
              height: btnH,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue500, // ✅ ثابت
                  foregroundColor: AppColors.grey50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Text(
                  primaryText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: font,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey50,
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            SizedBox(
              width: halfW,
              height: btnH,
              child: ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.lightBlue500.withOpacity(0.1), // ✨ Light bg
                  foregroundColor: AppColors.lightBlue500, // ✨
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: font,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightBlue500, // ✨
                  ),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: halfW,
              height: btnH,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue500, // ✨ #35B7D7
                  foregroundColor: AppColors.grey50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Text(
                  primaryText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: font,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey50,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
