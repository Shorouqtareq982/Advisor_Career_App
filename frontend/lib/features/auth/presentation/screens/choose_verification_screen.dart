import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';

class ChooseVerificationScreen extends StatelessWidget {
  final bool useTheme;
  const ChooseVerificationScreen({super.key, this.useTheme = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.appTextTheme;
    final isDark = useTheme && Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.blue700 : AppColors.blue500;
    final containerColor = useTheme
        ? (isDark ? AppColors.blue700 : AppColors.grey50) // blue800
        : AppColors.grey50;
    final textPrimary = useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue900)
        : AppColors.blue900;
    final textSecondary = useTheme
        ? (isDark ? AppColors.blue200 : AppColors.grey800)
        : AppColors.grey800;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const BackgroundCurves(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: context.h(35)),
                child: const AppLogo(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding:
                    EdgeInsets.only(top: context.h(48), left: context.w(8)),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: isDark ? AppColors.grey50 : AppColors.blue900,
                    size: context.icon(20),
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(context.r(50)),
                  topRight: Radius.circular(context.r(50)),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: context.h(40),
                  left: context.w(16),
                  right: context.w(16),
                  bottom: context.h(40),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/forgot_password.png',
                      width: context.w(268),
                      height: context.h(200),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: context.w(268),
                        height: context.h(200),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue500.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(context.r(20)),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: context.icon(80),
                          color: AppColors.lightBlue500,
                        ),
                      ),
                    ),
                    context.highSpace,
                    context.text(
                      AppStrings.forgotPassword,
                      style: textTheme.title1Bold.copyWith(color: textPrimary),
                    ),
                    context.mediumSpace,
                    context.text(
                      AppStrings.chooseVerificationMethod,
                      style:
                          textTheme.title2Medium.copyWith(color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    context.veryHighSpace,
                    _VerificationOption(
                      icon: Icons.email_outlined,
                      title: AppStrings.emailVerification,
                      subtitle: AppStrings.emailVerificationSubtitle,
                      onTap: () => context.push('/reset-password',
                          extra: {'method': 'email', 'useTheme': useTheme}),
                      useTheme: useTheme,
                      textTheme: textTheme,
                    ),
                    context.mediumSpace,
                    _VerificationOption(
                      icon: Icons.phone_android_outlined,
                      title: AppStrings.phoneVerification,
                      subtitle: AppStrings.phoneVerificationSubtitle,
                      onTap: () => context.push('/reset-password',
                          extra: {'method': 'phone', 'useTheme': useTheme}),
                      useTheme: useTheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool useTheme;
  final AppTextTheme textTheme;

  const _VerificationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.useTheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = useTheme && Theme.of(context).brightness == Brightness.dark;
    final textPrimary = useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue900)
        : AppColors.blue900;
    final textHint = useTheme
        ? (isDark ? AppColors.blue200 : AppColors.grey700)
        : AppColors.grey700;

    final accentColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    final iconFgColor = isDark ? AppColors.blue700 : AppColors.grey50;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.r(16)),
      child: Container(
        constraints: BoxConstraints(minHeight: context.h(59)),
        padding: EdgeInsets.symmetric(
          horizontal: context.w(16),
          vertical: context.h(12),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.r(16)),
          border: Border.all(color: accentColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: context.w(40),
              height: context.w(40),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(context.r(8)),
              ),
              child: Icon(icon, color: iconFgColor, size: context.icon(20)),
            ),
            SizedBox(width: context.w(16)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  context.text(
                    title,
                    style: textTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: context.h(2)),
                  context.text(
                    subtitle,
                    style: textTheme.captionMedium.copyWith(color: textHint),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
