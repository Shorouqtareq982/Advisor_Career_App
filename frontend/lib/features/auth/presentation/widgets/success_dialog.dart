import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onContinue;
  final String buttonText;
  final bool useTheme;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onContinue,
    this.buttonText = 'Sign In',
    this.useTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color getBackgroundColor() {
      if (!useTheme) return const Color(0xFFF8F8F8);
      return isDark ? const Color(0xFF1E1E2F) : const Color(0xFFF8F8F8);
    }

    Color getTitleColor() {
      if (!useTheme) return const Color(0xFF0F111D);
      return isDark ? AppColors.grey50 : const Color(0xFF0F111D);
    }

    Color getMessageColor() {
      if (!useTheme) return const Color(0xFF686868);
      return isDark ? Colors.grey.shade400 : const Color(0xFF686868);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(16),
      ),
      child: Center(
        child: Container(
          width: context.isMobile ? context.screenWidth * 0.9 : context.w(400),
          constraints: BoxConstraints(
            minHeight: context.h(358),
            maxHeight: context.screenHeight * 0.9,
          ),
          decoration: BoxDecoration(
            color: getBackgroundColor(),
            borderRadius: BorderRadius.circular(context.r(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: Offset(0, context.h(10)),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(context.h(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success Image
                  SizedBox(
                    width: double.infinity,
                    height: context.h(171),
                    child: Image.asset(
                      'assets/images/success_illustration.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: context.h(24)),

                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w700,
                      color: getTitleColor(),
                      fontFamily: 'Inter',
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.h(16)),

                  Text(
                    message,
                    style: TextStyle(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w400,
                      color: getMessageColor(),
                      fontFamily: 'Inter',
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.h(24)),

                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: context.h(48),
                    child: ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF268299),
                        foregroundColor: AppColors.grey50,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(50)),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey50,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onContinue,
    String buttonText = 'Sign In',
    bool useTheme = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        onContinue: onContinue,
        buttonText: buttonText,
        useTheme: useTheme,
      ),
    );
  }
}
