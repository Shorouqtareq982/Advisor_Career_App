import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/utils/auth_validators.dart';

import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/custom_button.dart';

import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _currentPasswordError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (_currentPasswordError != null) {
      setState(() => _currentPasswordError = null);
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      _showSuccessDialog();
    } else {
      setState(() => _currentPasswordError = 'Current password is incorrect');
      _formKey.currentState!.validate();
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Success!',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.grey50 : AppColors.blue900,
          ),
        ),
        content: Text(
          'Your password has been changed successfully.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: isDark ? AppColors.grey200 : AppColors.grey800,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.r(16)),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: TextButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
              foregroundColor: AppColors.grey50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
              ),
            ),
            child: const Text('OK', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenH = MediaQuery.sizeOf(context).height;
    final maxCardHeight = screenH - context.whiteContainerTop;

    final screenW = MediaQuery.sizeOf(context).width;
    final horizontalPad = (screenW * 0.06).clamp(16.0, 60.0);

    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: BackgroundCurves()),

          Positioned(
            top: context.h(60),
            left: 0,
            right: 0,
            child: const Center(child: AppLogo()),
          ),

          // ✅ الكارد لازق تحت وقد المحتوى
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(context.r(50)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          context.h(30),
                          horizontalPad,
                          context.h(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => context.pop(),
                                  borderRadius:
                                      BorderRadius.circular(context.r(8)),
                                  child: Padding(
                                    padding: EdgeInsets.all(context.w(8)),
                                    child: Icon(
                                      Icons.arrow_back_ios_new,
                                      color: isDark
                                          ? AppColors.grey50
                                          : AppColors.blue900,
                                      size: context.icon(20),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: context.sp(20),
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.grey50
                                            : AppColors.blue900,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.w(40)),
                              ],
                            ),
                            SizedBox(height: context.h(28)),
                            Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomTextField(
                                    controller: _currentPasswordController,
                                    label: 'Current Password',
                                    hintText: 'Enter current password',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: _obscureCurrent,
                                    errorText: _currentPasswordError,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Current password is required';
                                      }
                                      if (_currentPasswordError != null) {
                                        return _currentPasswordError;
                                      }
                                      return null;
                                    },
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureCurrent
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : AppColors.grey700,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureCurrent = !_obscureCurrent),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    useTheme: true,
                                  ),
                                  SizedBox(height: context.h(16)),
                                  CustomTextField(
                                    controller: _newPasswordController,
                                    label: 'New Password',
                                    hintText: 'Enter new password',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: _obscureNew,
                                    validator: AuthValidators.validatePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureNew
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : AppColors.grey700,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscureNew = !_obscureNew),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    useTheme: true,
                                  ),
                                  SizedBox(height: context.h(16)),
                                  CustomTextField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm Password',
                                    hintText: 'Re-enter new password',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: _obscureConfirm,
                                    validator: (value) =>
                                        AuthValidators.validateConfirmPassword(
                                      value,
                                      _newPasswordController.text,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : AppColors.grey700,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) =>
                                        _handleChangePassword(),
                                    useTheme: true,
                                  ),
                                  SizedBox(height: context.h(8)),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.push(
                                        '/choose-verification',
                                        extra: {'useTheme': true},
                                      ),
                                      child: Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: context.sp(14),
                                          color: AppColors.lightBlue700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ✅ زرار ثابت تحت
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        0,
                        horizontalPad,
                        (context.h(16) + bottomSafe).clamp(16.0, 40.0),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          elevatedButtonTheme: ElevatedButtonThemeData(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.lightBlue500
                                  : AppColors.lightBlue700,
                            ),
                          ),
                        ),
                        child: CustomButton(
                          text: 'Change Password',
                          onPressed: _handleChangePassword,
                          isLoading: _isLoading,
                        ),
                      ),
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
