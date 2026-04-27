import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class SocialAuthButton extends StatelessWidget {
  final String text;
  final Widget iconWidget;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool useTheme;

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.iconWidget,
    this.onPressed,
    this.isLoading = false,
    this.useTheme = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    final borderColor = useTheme
        ? (isDark ? AppColors.blue400 : AppColors.lightBlue700)
        : AppColors.lightBlue700;

    final textColor = useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue500)
        : AppColors.blue500;

    return SizedBox(
      height: context.h(48),
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(50)),
          ),
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: context.w(20),
                height: context.w(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.lightBlue700,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  SizedBox(width: context.w(10)),
                  Flexible(
                    child: context.text(
                      text,
                      style: textTheme.title2Bold.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Google Button ───────────────────────────────────────────────────────────

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool useTheme;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.useTheme = true,
  });

  @override
  Widget build(BuildContext context) {
    return SocialAuthButton(
      text: 'Google',
      iconWidget: Image.asset(
        'assets/icons/google_icon.png',
        width: context.w(20),
        height: context.w(20),
      ),
      onPressed: onPressed,
      isLoading: isLoading,
      useTheme: useTheme,
    );
  }
}

// ── Phone Button ────────────────────────────────────────────────────────────

class PhoneSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;
  final bool useTheme;

  const PhoneSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Phone',
    this.useTheme = true,
  });

  @override
  Widget build(BuildContext context) {
    return SocialAuthButton(
      text: text,
      iconWidget: Image.asset(
        'assets/icons/phone_icon.png',
        width: context.w(20),
        height: context.w(20),
      ),
      onPressed: onPressed,
      isLoading: isLoading,
      useTheme: useTheme,
    );
  }
}
