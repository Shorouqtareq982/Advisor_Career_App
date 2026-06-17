import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

// ─── Job Search Started Dialog ────────────────────────────────────────────────
/// Shown immediately when user taps "Find Matching Jobs".
/// Tells them the search runs in background and they'll get a notification.
class JobSearchStartedDialog extends StatelessWidget {
  const JobSearchStartedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Container(
        padding: EdgeInsets.all(context.w(24)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: context.w(64),
              height: context.w(64),
              decoration: BoxDecoration(
                color: btnColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                color: btnColor,
                size: context.icon(32),
              ),
            ),

            SizedBox(height: context.h(16)),

            Text(
              'Searching for Your Best Matches',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.h(10)),

            Text(
              'Our AI is analyzing your CV and finding the best job matches. '
              'This may take up to 5 minutes.\n\n'
              "We'll send you a notification as soon as your results are ready!",
              style:
                  textTheme.bodyRegular.copyWith(color: textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.h(8)),

            // Animated dots hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: btnColor, size: context.icon(16)),
                SizedBox(width: context.w(6)),
                Text(
                  "You'll get notified when done",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w500,
                    color: btnColor,
                  ),
                ),
              ],
            ),

            SizedBox(height: context.h(24)),

            SizedBox(
              width: double.infinity,
              height: context.h(48),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Got it!',
                  style: textTheme.title2Bold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Job Results Ready Dialog ─────────────────────────────────────────────────
/// Shown if user is still in the app when results come back.
class JobResultsReadyDialog extends StatelessWidget {
  final VoidCallback onViewResults;

  const JobResultsReadyDialog({super.key, required this.onViewResults});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Container(
        padding: EdgeInsets.all(context.w(24)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.w(64),
              height: context.w(64),
              decoration: BoxDecoration(
                color: AppColors.green700.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.green700,
                size: context.icon(32),
              ),
            ),
            SizedBox(height: context.h(16)),
            Text(
              'Your Results Are Ready! 🎉',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(8)),
            Text(
              "We found the best job matches for you. Tap below to see your results.",
              style: textTheme.bodyRegular.copyWith(color: textMuted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(24)),
            SizedBox(
              width: double.infinity,
              height: context.h(48),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onViewResults();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'View Results',
                  style: textTheme.title2Bold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
