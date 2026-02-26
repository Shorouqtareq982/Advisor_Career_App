import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../auth/presentation/widgets/otp_input_field.dart';

enum DeleteMethod { password, emailOtp, phoneOtp }

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _passwordError;
  String? _otpError;

  DeleteMethod? _selectedMethod;

  bool _otpSent = false;
  bool _showOtpField = false;
  int _otpTimer = 30;
  Timer? _timer;

  Type _keepDartIoUsed() => File;

  @override
  void initState() {
    super.initState();

    _keepDartIoUsed();

    _passwordController.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });

    _otpController.addListener(() {
      if (_otpError != null) setState(() => _otpError = null);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _otpTimer = 30;
      _otpSent = true;
      _showOtpField = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpTimer > 0) {
        setState(() => _otpTimer--);
      } else {
        setState(() => _otpTimer = 0);
        timer.cancel();
        _timer = null;
      }
    });
  }

  List<DeleteMethod> _getAvailableMethods() {
    final user = ref.read(authProvider).user;
    if (user == null) return [];

    final methods = <DeleteMethod>[];

    if (user.provider == 'email') {
      methods.add(DeleteMethod.password);
    }
    if (user.email != null && user.email!.isNotEmpty) {
      methods.add(DeleteMethod.emailOtp);
    }
    if (user.phone != null && user.phone!.isNotEmpty) {
      methods.add(DeleteMethod.phoneOtp);
    }

    return methods;
  }

  String _getMethodTitle(DeleteMethod method) {
    switch (method) {
      case DeleteMethod.password:
        return 'Verify with Password';
      case DeleteMethod.emailOtp:
        return 'Verify with Email OTP';
      case DeleteMethod.phoneOtp:
        return 'Verify with Phone OTP';
    }
  }

  String _getMethodSubtitle(DeleteMethod method) {
    final user = ref.read(authProvider).user;
    switch (method) {
      case DeleteMethod.password:
        return 'Use your account password';
      case DeleteMethod.emailOtp:
        return 'Send code to ${user?.email ?? 'your email'}';
      case DeleteMethod.phoneOtp:
        return 'Send code to ${user?.phone ?? 'your phone'}';
    }
  }

  Future<void> _handleSendOtp() async {
    if (_selectedMethod == null) return;

    setState(() {
      _otpError = null;
      _isLoading = true;
      _showOtpField = true;
    });

    try {
      final method =
          _selectedMethod == DeleteMethod.emailOtp ? 'email' : 'phone';
      final success =
          await ref.read(authProvider.notifier).sendDeleteAccountOTP(method);

      if (!mounted) return;

      if (success) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });

        _startTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Verification code sent successfully!',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: AppColors.green700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(context.w(16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.r(12)),
            ),
          ),
        );
      } else {
        setState(() {
          _otpError = 'Failed to send verification code';
          _isLoading = false;
          _showOtpField = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _otpError = 'Error: ${e.toString()}';
        _isLoading = false;
        _showOtpField = false;
      });
    }
  }

  Future<void> _handleVerifyAndDelete() async {
    if (_selectedMethod == null) return;

    setState(() {
      _passwordError = null;
      _otpError = null;
      _isLoading = true;
    });

    try {
      bool success = false;

      if (_selectedMethod == DeleteMethod.password) {
        if (_passwordController.text.isEmpty) {
          setState(() {
            _passwordError = 'Password is required';
            _isLoading = false;
          });
          return;
        }

        success = await ref
            .read(authProvider.notifier)
            .deleteAccountWithPassword(_passwordController.text);
      } else if (_selectedMethod == DeleteMethod.emailOtp) {
        if (_otpController.text.length != 6) {
          setState(() {
            _otpError = 'Please enter 6-digit code';
            _isLoading = false;
          });
          return;
        }

        success = await ref
            .read(authProvider.notifier)
            .deleteAccountWithEmailOTP(_otpController.text);
      } else if (_selectedMethod == DeleteMethod.phoneOtp) {
        if (_otpController.text.length != 6) {
          setState(() {
            _otpError = 'Please enter 6-digit code';
            _isLoading = false;
          });
          return;
        }

        success = await ref
            .read(authProvider.notifier)
            .deleteAccountWithPhoneOTP(_otpController.text);
      }

      if (!mounted) return;

      if (success) {
        _showSuccessDialog();
      } else {
        setState(() {
          if (_selectedMethod == DeleteMethod.password) {
            _passwordError = 'Incorrect password';
          } else {
            _otpError = 'Invalid or expired verification code';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_selectedMethod == DeleteMethod.password) {
          _passwordError = 'Error: ${e.toString()}';
        } else {
          _otpError = 'Error: ${e.toString()}';
        }
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Account Deleted',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: context.icon(60),
              color: AppColors.green700,
            ),
            SizedBox(height: context.h(16)),
            const Text(
              'Your account has been permanently deleted.',
              style: TextStyle(fontFamily: 'Inter'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.r(16)),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/');
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
                foregroundColor: AppColors.grey50,
                minimumSize: Size(context.w(200), context.h(48)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r(50)),
                ),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVerificationUI(BuildContext context, bool isDark) {
    if (_selectedMethod == DeleteMethod.password) {
      return [
        CustomTextField(
          controller: _passwordController,
          label: 'Enter your password',
          hintText: 'Password',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscurePassword,
          errorText: _passwordError,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: isDark ? Colors.grey.shade400 : AppColors.grey700,
              size: context.icon(20),
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleVerifyAndDelete(),
          useTheme: true,
        ),
      ];
    }

    // OTP methods
    return [
      if (_showOtpField) ...[
        OtpInputField(
          controller: _otpController,
          onCompleted: (code) => _handleVerifyAndDelete(),
          errorText: _otpError,
          useTheme: true,
        ),
        if (_otpSent)
          Padding(
            padding: EdgeInsets.only(top: context.h(6)),
            child: Text(
              'Code sent',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12),
                color: isDark ? Colors.grey.shade500 : AppColors.grey800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: context.h(8)),
        Center(
          child: TextButton(
            onPressed: _otpTimer == 0 ? _handleSendOtp : null,
            child: Text(
              _otpTimer > 0 ? 'Resend code in $_otpTimer s' : 'Resend Code',
              style: TextStyle(
                fontFamily: 'Inter',
                color: _otpTimer == 0
                    ? (isDark ? AppColors.lightBlue500 : AppColors.lightBlue700)
                    : (isDark ? Colors.grey.shade600 : AppColors.grey800),
              ),
            ),
          ),
        ),
      ] else ...[
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: 'Send Verification Code',
            onPressed: _handleSendOtp,
            isLoading: _isLoading,
            backgroundColor:
                isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
            textColor: isDark ? AppColors.blue700 : AppColors.grey50,
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final availableMethods = _getAvailableMethods();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      body: Stack(
        children: [
          const BackgroundCurves(),

          Positioned(
            top: context.h(60),
            child: SizedBox(
              width: context.screenWidth,
              child: const Center(child: AppLogo()),
            ),
          ),

          // Responsive white container
          Positioned(
            top: context.whiteContainerTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(context.r(50)),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(24),
                    vertical: context.h(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────
                      Row(
                        children: [
                          InkWell(
                            onTap: () => context.pop(),
                            borderRadius: BorderRadius.circular(context.r(8)),
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
                                'Delete Account',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(20),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.red600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: context.w(40)),
                        ],
                      ),

                      SizedBox(height: context.h(24)),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              'This action cannot be undone!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w700,
                                color: AppColors.red600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.h(8)),
                            Text(
                              'All your data will be permanently deleted.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(14),
                                color: isDark
                                    ? Colors.grey.shade400
                                    : AppColors.grey800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: context.h(24)),

                      // ── Account card ─────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.w(16)),
                        decoration: BoxDecoration(
                          color: AppColors.red600.withValues(alpha: 13),
                          borderRadius: BorderRadius.circular(context.r(12)),
                          border: Border.all(
                            color: AppColors.red600.withValues(alpha: 77),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Account to delete:',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(13),
                                color: isDark
                                    ? Colors.grey.shade400
                                    : AppColors.grey800,
                              ),
                            ),
                            SizedBox(height: context.h(4)),
                            Text(
                              user?.email ?? user?.phone ?? 'Unknown',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.grey50
                                    : AppColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: context.h(24)),

                      // ── Verification method label ─────────────────────
                      Text(
                        'Choose verification method:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.grey50 : AppColors.blue900,
                        ),
                      ),
                      SizedBox(height: context.h(12)),

                      // ── Method options ───────────────────────────────
                      ...availableMethods.map(
                        (method) => InkWell(
                          onTap: () => setState(() => _selectedMethod = method),
                          child: Container(
                            margin: EdgeInsets.only(bottom: context.h(8)),
                            padding: EdgeInsets.all(context.w(16)),
                            decoration: BoxDecoration(
                              color: _selectedMethod == method
                                  ? (isDark
                                          ? AppColors.lightBlue500
                                          : AppColors.lightBlue700)
                                      .withValues(alpha: 26)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(context.r(12)),
                              border: Border.all(
                                color: _selectedMethod == method
                                    ? (isDark
                                        ? AppColors.lightBlue500
                                        : AppColors.lightBlue700)
                                    : (isDark
                                        ? Colors.grey.shade700
                                        : AppColors.grey600),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  method == DeleteMethod.password
                                      ? Icons.lock_outline
                                      : method == DeleteMethod.emailOtp
                                          ? Icons.email_outlined
                                          : Icons.phone_outlined,
                                  color: _selectedMethod == method
                                      ? (isDark
                                          ? AppColors.lightBlue500
                                          : AppColors.lightBlue700)
                                      : (isDark
                                          ? Colors.grey.shade400
                                          : AppColors.grey800),
                                  size: context.icon(20),
                                ),
                                SizedBox(width: context.w(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getMethodTitle(method),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: context.sp(14),
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.grey50
                                              : AppColors.blue900,
                                        ),
                                      ),
                                      Text(
                                        _getMethodSubtitle(method),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: context.sp(12),
                                          color: isDark
                                              ? AppColors.grey100
                                              : AppColors.grey800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedMethod == method)
                                  Icon(
                                    Icons.check_circle,
                                    color: isDark
                                        ? AppColors.lightBlue500
                                        : AppColors.lightBlue700,
                                    size: context.icon(20),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Verification UI + Delete button ───────────────
                      if (_selectedMethod != null) ...[
                        SizedBox(height: context.h(24)),
                        ..._buildVerificationUI(context, isDark),
                        SizedBox(height: context.h(24)),
                        CustomButton(
                          text: 'Delete Account',
                          onPressed: _selectedMethod == DeleteMethod.password
                              ? _handleVerifyAndDelete
                              : (_showOtpField ? _handleVerifyAndDelete : null),
                          isLoading: _isLoading,
                          isPrimary: false,
                        ),
                      ],

                      SizedBox(height: context.h(24)),
                    ], // Column children
                  ), // Column
                ), // Padding
              ), // SingleChildScrollView
            ), // Container
          ), // Positioned
        ],
      ),
    );
  }
}
