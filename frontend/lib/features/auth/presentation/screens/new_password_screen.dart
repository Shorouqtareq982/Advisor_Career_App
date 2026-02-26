import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/success_dialog.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  final String? email;
  final String? phone;
  final bool useTheme;
  const NewPasswordScreen(
      {super.key, this.email, this.phone, this.useTheme = false});
  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(authProvider);
      if (s.isAuthenticated) ref.read(authProvider.notifier).signOut();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.email == null && widget.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Error: Missing contact information',
            style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.red600,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(context.w(16)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(12))),
      ));
      return;
    }
    final success = await ref.read(authProvider.notifier).resetPassword(
        newPassword: _passwordController.text,
        email: widget.email,
        phone: widget.phone);
    if (success && mounted) {
      await ref.read(authProvider.notifier).signOut();
      SuccessDialog.show(
        context,
        title: 'Success!',
        message:
            'Your password has been reset. You can now sign in to your account.',
        buttonText: 'Sign In',
        onContinue: () {
          Navigator.pop(context);
          context.go('/sign-in');
        },
        useTheme: widget.useTheme,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Failed to update password',
            style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.red600,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(context.w(16)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(12))),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final textTheme = context.appTextTheme;
    final isDark =
        widget.useTheme && Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.blue700 : AppColors.blue500;
    final containerColor = widget.useTheme
        ? (isDark ? AppColors.blue700 : AppColors.grey50)
        : AppColors.grey50;
    final fieldBgColor = isDark ? const Color(0xFF1E2D4A) : null;
    final textPrimary = widget.useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue900)
        : AppColors.blue900;
    final textSecondary = widget.useTheme
        ? (isDark ? AppColors.blue200 : AppColors.grey800)
        : AppColors.grey800;
    final iconColor = widget.useTheme
        ? (isDark ? AppColors.blue200 : AppColors.grey700)
        : AppColors.grey700;

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
          // Bottom sheet
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
                child: Form(
                  // ← أضف Form هنا
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/new_password.png',
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
                          child: Icon(Icons.lock_reset,
                              size: context.icon(80),
                              color: AppColors.lightBlue500),
                        ),
                      ),
                      context.highSpace,
                      context.text(
                        'New Password',
                        style:
                            textTheme.title1Bold.copyWith(color: textPrimary),
                      ),
                      context.mediumSpace,
                      context.text(
                        'Please enter your new password',
                        style: textTheme.title2Medium
                            .copyWith(color: textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      context.veryHighSpace,
                      CustomTextField(
                        controller: _passwordController,
                        label: 'New Password',
                        hintText: 'Enter new password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: AuthValidators.validatePassword,
                        textInputAction: TextInputAction.next,
                        useTheme: widget.useTheme,
                        overrideBgColor: fieldBgColor,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: iconColor,
                            size: context.icon(20),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      context.highSpace,
                      CustomTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Re-enter new password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        validator: (value) =>
                            AuthValidators.validateConfirmPassword(
                                value, _passwordController.text),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSave(),
                        useTheme: widget.useTheme,
                        overrideBgColor: fieldBgColor,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: iconColor,
                            size: context.icon(20),
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                      ),
                      context.veryHighSpace,
                      CustomButton(
                        text: 'Save',
                        onPressed: _handleSave,
                        isLoading: isLoading,
                        backgroundColor: isDark ? AppColors.lightBlue500 : null,
                        textColor: isDark ? AppColors.blue700 : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
