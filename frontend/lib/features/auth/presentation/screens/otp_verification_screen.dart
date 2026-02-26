import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/success_dialog.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String method;
  final String contact;
  final String type;
  final bool useTheme;
  final String? provider;

  const OtpVerificationScreen({
    super.key,
    required this.method,
    required this.contact,
    this.type = 'signup',
    this.useTheme = false,
    this.provider,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  String? _errorText;
  int _resendTimer = 30;
  Timer? _timer;
  bool _isResendActive = false;
  bool _isResending = false;
  int _resendAttempts = 0;
  static const int _maxResendAttempts = 3;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _resendTimer = 30;
      _isResendActive = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() {
          _isResendActive = true;
          _resendAttempts = 0;
          _isBlocked = false;
        });
        timer.cancel();
        _timer = null;
      }
    });
  }

  void _startBlockTimer() {
    setState(() {
      _isBlocked = true;
      _isResendActive = false;
      _resendTimer = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() {
          _isBlocked = false;
          _isResendActive = true;
          _resendAttempts = 0;
        });
        timer.cancel();
        _timer = null;
      }
    });
  }

  Future<void> _handleVerify(String otp) async {
    final error = AuthValidators.validateOTP(otp);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() => _errorText = null);

    bool success;
    if (widget.method == 'email') {
      success = await ref.read(authProvider.notifier).verifyEmailOTP(
            email: widget.contact,
            otp: otp,
            isResetPassword: widget.type == 'reset',
          );
    } else {
      success = await ref.read(authProvider.notifier).verifyPhoneOTP(
            phone: widget.contact,
            otp: otp,
            isResetPassword: widget.type == 'reset',
          );
    }

    if (success && mounted) {
      if (widget.type == 'signup') {
        if (widget.provider == 'phone') {
          SuccessDialog.show(
            context,
            title: 'Success!',
            message: 'Your ${widget.method} has been verified successfully.',
            onContinue: () {
              Navigator.pop(context);
              context.go('/profile-username');
            },
            useTheme: widget.useTheme,
          );
        } else {
          SuccessDialog.show(
            context,
            title: 'Success!',
            message: 'Your ${widget.method} has been verified successfully.',
            onContinue: () {
              Navigator.pop(context);
              context.go('/profile-information');
            },
            useTheme: widget.useTheme,
          );
        }
      } else {
        context.pushReplacement('/new-password', extra: {
          widget.method: widget.contact,
          'useTheme': widget.useTheme,
        });
      }
    } else if (mounted) {
      setState(() => _errorText = 'Invalid code. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.appTextTheme;
    final isDark =
        widget.useTheme && Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.blue700 : AppColors.blue500;
    final containerColor = widget.useTheme
        ? (isDark ? AppColors.blue700 : AppColors.grey50)
        : AppColors.grey50;
    final textPrimaryColor = widget.useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue900)
        : AppColors.blue900;
    final textSecondaryColor = widget.useTheme
        ? (isDark ? AppColors.blue200 : AppColors.grey800)
        : AppColors.grey800;
    final arrowColor = widget.useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue900)
        : AppColors.blue900;

    return Scaffold(
      backgroundColor: backgroundColor,
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

          // Container بيتحدد بالمحتوى من تحت
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(50),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: context.h(40),
                  left: context.w(16),
                  right: context.w(16),
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + context.h(40),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    context.text(
                      widget.type == 'signup'
                          ? 'Verification Code'
                          : AppStrings.verifyCode,
                      style: textTheme.h5Bold.copyWith(color: textPrimaryColor),
                    ),
                    SizedBox(height: context.h(16)),
                    RichText(
                      text: TextSpan(
                        text:
                            'Enter the 6-digit code sent to your ${widget.method}: ',
                        style: context.responsiveText(
                          textTheme.title2Medium.copyWith(
                            color: textSecondaryColor,
                          ),
                        ),
                        children: [
                          TextSpan(
                            text: _maskedContact,
                            style: context.responsiveText(
                              textTheme.title2Bold.copyWith(
                                color: isDark
                                    ? AppColors.lightBlue500
                                    : AppColors.blue900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.h(24)),
                    OtpInputField(
                      controller: _otpController,
                      onCompleted: _handleVerify,
                      errorText: _errorText,
                      useTheme: widget.useTheme,
                    ),
                    SizedBox(height: context.h(24)),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: context.h(48),
                      child: ElevatedButton(
                        onPressed: _isOtpComplete
                            ? () => _handleVerify(_otpController.text)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isOtpComplete
                              ? (isDark
                                  ? AppColors.lightBlue500
                                  : AppColors.lightBlue700)
                              : (isDark
                                  ? AppColors.blue700
                                  : AppColors.grey600),
                          foregroundColor:
                              isDark ? AppColors.blue700 : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.r(50)),
                          ),
                        ),
                        child: _isResending
                            ? SizedBox(
                                width: context.w(20),
                                height: context.h(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark ? AppColors.blue700 : Colors.white,
                                  ),
                                ),
                              )
                            : context.text(
                                widget.type == 'signup'
                                    ? 'Verify Code'
                                    : AppStrings.verifyCode,
                                style: textTheme.title2Bold.copyWith(
                                  color:
                                      isDark ? AppColors.blue700 : Colors.white,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(height: context.h(16)),

                    // Resend
                    InkWell(
                      onTap: (_isResendActive &&
                              !_isBlocked &&
                              _resendAttempts < _maxResendAttempts)
                          ? _handleResend
                          : null,
                      child: Text.rich(
                        TextSpan(
                          text: 'Didn\'t receive the code? ',
                          style: context.responsiveText(
                            textTheme.bodyMedium.copyWith(
                              color: textSecondaryColor,
                            ),
                          ),
                          children: [
                            TextSpan(
                              text: _resendStatusText,
                              style: context.responsiveText(
                                textTheme.bodyBold.copyWith(
                                  color: _getResendTextColor(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: context.h(8)),

                    // Change contact
                    InkWell(
                      onTap: _handleChangeContact,
                      child: Text.rich(
                        TextSpan(
                          text: 'Wrong ${widget.method}? ',
                          style: context.responsiveText(
                            textTheme.bodyMedium.copyWith(
                              color: _isResendActive
                                  ? textSecondaryColor
                                  : textSecondaryColor.withOpacity(0.5),
                            ),
                          ),
                          children: [
                            TextSpan(
                              text: 'Change it',
                              style: context.responsiveText(
                                textTheme.bodyBold.copyWith(
                                  color: _isResendActive
                                      ? (isDark
                                          ? AppColors.purple800
                                          : AppColors.purple800)
                                      : textSecondaryColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (widget.type == 'reset') ...[
                      SizedBox(height: context.h(16)),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: isDark
                                  ? AppColors.blue700
                                  : AppColors.grey400,
                            ),
                          ),
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: context.w(8)),
                            child: context.text(
                              'OR',
                              style: textTheme.bodyMedium.copyWith(
                                color: textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: isDark
                                  ? AppColors.blue700
                                  : AppColors.grey400,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.h(16)),
                      InkWell(
                        onTap: () {
                          _timer?.cancel();
                          final alternativeMethod =
                              widget.method == 'email' ? 'phone' : 'email';
                          context.push('/reset-password', extra: {
                            'method': alternativeMethod,
                            'useTheme': widget.useTheme,
                          });
                        },
                        child: Container(
                          height: context.h(48),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.w(16),
                            vertical: context.h(8),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(context.r(16)),
                            border: Border.all(
                              color: AppColors.lightBlue500,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: context.w(32),
                                height: context.h(32),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBlue500,
                                  borderRadius:
                                      BorderRadius.circular(context.r(8)),
                                ),
                                child: Icon(
                                  widget.method == 'email'
                                      ? Icons.phone_android_outlined
                                      : Icons.email_outlined,
                                  color: AppColors.blue700,
                                  size: context.icon(18),
                                ),
                              ),
                              SizedBox(width: context.w(16)),
                              context.text(
                                'Verify with ${widget.method == 'email' ? 'phone' : 'email'}',
                                style: textTheme.bodyMedium.copyWith(
                                  color: textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: context.h(48),
            left: context.w(16),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: arrowColor,
                size: context.icon(20),
              ),
              onPressed: () {
                _timer?.cancel();
                context.pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _isOtpComplete => _otpController.text.length == 6;

  String get _maskedContact {
    if (widget.method == 'email') {
      return AuthValidators.maskEmail(widget.contact);
    } else {
      return AuthValidators.maskPhone(widget.contact);
    }
  }

  String get _resendStatusText {
    if (_isBlocked) return 'Try again in $_resendTimer s';
    if (!_isResendActive) return 'Resend in $_resendTimer s';
    if (_resendAttempts >= _maxResendAttempts)
      return 'Maximum attempts reached';
    return 'Resend Code';
  }

  Color _getResendTextColor(bool isDark) {
    if (_isBlocked ||
        (!_isResendActive && _resendAttempts >= _maxResendAttempts)) {
      return (isDark ? AppColors.blue200 : AppColors.grey800).withOpacity(0.5);
    }
    if (_isResendActive) {
      return isDark ? AppColors.purple800 : AppColors.purple800;
    }
    return isDark ? AppColors.blue200 : AppColors.grey800;
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: isError ? AppColors.red600 : AppColors.green700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(context.w(16)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleChangeContact() {
    _timer?.cancel();
    final isDark =
        widget.useTheme && Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        final dialogTextTheme = context.appTextTheme;
        return AlertDialog(
          title: context.text(
            'Change ${widget.method}',
            style: dialogTextTheme.title2Bold,
          ),
          content: context.text(
            'Are you sure you want to change your ${widget.method}?',
            style: dialogTextTheme.bodyMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(16)),
          ),
          backgroundColor: widget.useTheme
              ? (isDark ? const Color(0xFF1A2035) : Colors.white)
              : Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: widget.useTheme
                    ? (isDark ? AppColors.blue200 : AppColors.grey800)
                    : AppColors.grey800,
              ),
              child:
                  const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
                foregroundColor: isDark ? AppColors.blue700 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r(50)),
                ),
              ),
              child:
                  const Text('Change', style: TextStyle(fontFamily: 'Inter')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleResend() async {
    if (!_isResendActive || _isResending || _isBlocked) {
      if (_isBlocked && mounted) {
        _showSnackBar(
          'Too many attempts. Please wait $_resendTimer seconds.',
          isError: true,
        );
      }
      return;
    }

    if (_resendAttempts >= _maxResendAttempts) {
      _startBlockTimer();
      if (mounted) {
        _showSnackBar('Too many attempts. Please wait 60 seconds.',
            isError: true);
      }
      return;
    }

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      bool success;
      if (widget.method == 'email') {
        success =
            await ref.read(authProvider.notifier).sendEmailOTP(widget.contact);
      } else {
        success =
            await ref.read(authProvider.notifier).sendPhoneOTP(widget.contact);
      }

      if (success && mounted) {
        setState(() => _resendAttempts++);
        _startTimer();
        _showSnackBar(
          'Code sent successfully! (Attempt $_resendAttempts/$_maxResendAttempts)',
          isError: false,
        );
      } else if (mounted) {
        setState(() {
          _resendAttempts++;
          _isResendActive = true;
        });
        String errorMessage = 'Failed to send code. ';
        if (_resendAttempts >= _maxResendAttempts) {
          _startBlockTimer();
          errorMessage = 'Too many failures. Please wait 60 seconds.';
        } else {
          errorMessage +=
              'Please try again. ($_resendAttempts/$_maxResendAttempts)';
        }
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resendAttempts++;
          _isResendActive = true;
        });
        String errorMessage = 'Network error. ';
        if (_resendAttempts >= _maxResendAttempts) {
          _startBlockTimer();
          errorMessage = 'Too many errors. Please wait 60 seconds.';
        } else {
          errorMessage +=
              'Please try again. ($_resendAttempts/$_maxResendAttempts)';
        }
        _showSnackBar(errorMessage, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }
}
