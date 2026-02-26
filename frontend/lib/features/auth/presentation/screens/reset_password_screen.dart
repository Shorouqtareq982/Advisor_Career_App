import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../shared/models/country_model.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/phone_input_field.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String method;
  final bool useTheme;
  const ResetPasswordScreen(
      {super.key, required this.method, this.useTheme = false});
  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  Country _selectedCountry = Countries.egypt;
  String? _emailError;
  String? _phoneError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => setState(() => _isLoading = false));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String?> _checkEmailExists(String email) async {
    try {
      final exists =
          await ref.read(authProvider.notifier).checkEmailExists(email);
      return exists ? null : 'No account found with this email address';
    } catch (e) {
      return 'Error checking email. Please try again.';
    }
  }

  Future<String?> _checkPhoneExists(String phone) async {
    try {
      final fullPhone =
          _selectedCountry.dialCode + phone.replaceFirst(RegExp(r'^0+'), '');
      final exists =
          await ref.read(authProvider.notifier).checkPhoneExists(fullPhone);
      return exists ? null : 'No account found with this phone number';
    } catch (e) {
      return 'Error checking phone. Please try again.';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _emailError = null;
      _phoneError = null;
    });
    bool success = false;
    String contact = '';
    try {
      if (widget.method == 'email') {
        contact = _emailController.text.trim();
        final check = await _checkEmailExists(contact);
        if (check != null) {
          setState(() {
            _emailError = check;
            _isLoading = false;
          });
          return;
        }
        success = await ref.read(authProvider.notifier).sendEmailOTP(contact);
      } else {
        final phone = _phoneController.text.trim();
        contact =
            '${_selectedCountry.dialCode}${phone.replaceFirst(RegExp(r'^0+'), '')}';
        final check = await _checkPhoneExists(phone);
        if (check != null) {
          setState(() {
            _phoneError = check;
            _isLoading = false;
          });
          return;
        }
        success = await ref.read(authProvider.notifier).sendPhoneOTP(contact);
      }
      if (success && mounted) {
        setState(() => _isLoading = false);
        context.push('/otp-verification', extra: {
          'method': widget.method,
          'contact': contact,
          'type': 'reset',
          'useTheme': widget.useTheme
        });
      } else if (mounted) {
        setState(() {
          if (widget.method == 'email')
            _emailError = 'Failed to send code. Please try again.';
          else
            _phoneError = 'Failed to send code. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        if (widget.method == 'email')
          _emailError = 'An error occurred. Please try again.';
        else
          _phoneError = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmail = widget.method == 'email';
    final textTheme = context.appTextTheme;
    final isDark =
        widget.useTheme && Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.blue700 : AppColors.blue500;
    final containerColor = widget.useTheme
        ? (isDark ? AppColors.blue700 : AppColors.grey50)
        : AppColors.grey50;
    final fieldBgColor = isDark ? const Color(0xFF1E2D4A) : null; // blue700-ish
    final textPrimary = widget.useTheme
        ? (isDark ? AppColors.grey50 : AppColors.blue900)
        : AppColors.blue900;
    final textSecondary = widget.useTheme
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
                  onPressed: () {
                    setState(() => _isLoading = false);
                    context.pop();
                  },
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
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom + context.h(40),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/reset_password.png',
                        width: context.w(268),
                        height: context.h(200),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: context.w(268),
                          height: context.h(200),
                          color: Colors.grey.withOpacity(0.1),
                          child: Icon(
                            isEmail ? Icons.email : Icons.phone,
                            size: context.icon(80),
                            color: AppColors.lightBlue500,
                          ),
                        ),
                      ),
                      SizedBox(height: context.h(24)),
                      context.text(
                        AppStrings.resetPassword,
                        style:
                            textTheme.title1Bold.copyWith(color: textPrimary),
                      ),
                      SizedBox(height: context.h(16)),
                      context.text(
                        isEmail
                            ? AppStrings.enterEmailForCode
                            : AppStrings.enterPhoneForCode,
                        style: textTheme.title2Medium
                            .copyWith(color: textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.h(32)),
                      if (isEmail) ...[
                        CustomTextField(
                          controller: _emailController,
                          label: AppStrings.email,
                          hintText: AppStrings.enterEmail,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              AuthValidators.validateEmail(value),
                          onChanged: (_) {
                            if (_emailError != null)
                              setState(() => _emailError = null);
                          },
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSubmit(),
                          errorText: _emailError,
                          useTheme: widget.useTheme,
                          overrideBgColor: fieldBgColor,
                        ),
                      ] else ...[
                        PhoneInputField(
                          controller: _phoneController,
                          selectedCountry: _selectedCountry,
                          onCountryChanged: (c) => setState(() {
                            _selectedCountry = c;
                            _phoneError = null;
                          }),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Phone number is required';
                            if (value.length != _selectedCountry.phoneLength)
                              return 'Must be exactly ${_selectedCountry.phoneLength} digits';
                            return null;
                          },
                          onChanged: (_) {
                            if (_phoneError != null)
                              setState(() => _phoneError = null);
                          },
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSubmit(),
                          errorText: _phoneError,
                          useTheme: widget.useTheme,
                          overrideBgColor: fieldBgColor,
                        ),
                      ],
                      SizedBox(height: context.h(40)),
                      CustomButton(
                        text: AppStrings.sendCode,
                        onPressed: _handleSubmit,
                        isLoading: _isLoading,
                        // dark: lightblue500 bg, blue700 text
                        backgroundColor: isDark ? AppColors.lightBlue500 : null,
                        textColor: isDark ? AppColors.blue700 : null,
                      ),
                      SizedBox(height: context.h(20)),
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
