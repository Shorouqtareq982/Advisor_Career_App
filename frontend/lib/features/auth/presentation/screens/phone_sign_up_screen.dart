import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../shared/models/country_model.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../widgets/phone_input_field.dart';
import '../providers/auth_provider.dart';
import '../../../../core/services/auth_service.dart';

class PhoneSignUpScreen extends ConsumerStatefulWidget {
  const PhoneSignUpScreen({super.key});
  @override
  ConsumerState<PhoneSignUpScreen> createState() => _PhoneSignUpScreenState();
}

class _PhoneSignUpScreenState extends ConsumerState<PhoneSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneInputKey = GlobalKey<PhoneInputFieldState>();
  Country _selectedCountry = Countries.defaultCountry;
  String? _phoneError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (_phoneError != null && mounted) setState(() => _phoneError = null);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handlePhoneSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _phoneError = null;
      _isLoading = true;
    });
    try {
      final fullPhone = _phoneInputKey.currentState!.getFullPhoneNumber();
      if (fullPhone.isEmpty) {
        setState(() {
          _phoneError = 'Please enter phone number';
          _isLoading = false;
        });
        _formKey.currentState!.validate();
        return;
      }
      final authService = AuthService();
      final phoneExists = await authService.checkPhoneExists(fullPhone);
      if (phoneExists) {
        setState(() {
          _phoneError =
              'This phone number is already registered. Please sign in.';
          _isLoading = false;
        });
        _formKey.currentState!.validate();
        return;
      }
      await ref.read(authProvider.notifier).sendPhoneOTP(fullPhone);
      if (!mounted) return;
      context.push('/otp-verification', extra: {
        'method': 'phone',
        'contact': fullPhone,
        'type': 'signup',
        'useTheme': false,
        'provider': 'phone'
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _phoneError = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        _formKey.currentState!.validate();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLoading || authState.isLoading;
    final textTheme = context.appTextTheme;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const BackgroundCurves(),
          SafeArea(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                      padding: EdgeInsets.only(top: context.h(35)),
                      child: const AppLogo()))),
          SafeArea(
              child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                      padding: EdgeInsets.only(
                          top: context.h(48), left: context.w(8)),
                      child: IconButton(
                          icon: Icon(Icons.arrow_back_ios,
                              color: AppColors.blue900, size: context.icon(20)),
                          onPressed: () => context.pop())))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(context.r(50)),
                      topRight: Radius.circular(context.r(50)))),
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                    top: context.h(40),
                    left: context.w(16),
                    right: context.w(16),
                    bottom: MediaQuery.of(context).viewInsets.bottom +
                        context.h(40)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      context.text(
                        'Sign Up with Phone',
                        style: textTheme.h5Bold.copyWith(
                          color: AppColors.blue900,
                        ),
                      ),
                      context.mediumSpace,
                      context.text(
                        'Enter your phone number to receive\na verification code',
                        style: textTheme.title2Medium.copyWith(
                          color: AppColors.grey800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: context.h(32)),
                      PhoneInputField(
                          key: _phoneInputKey,
                          controller: _phoneController,
                          selectedCountry: _selectedCountry,
                          onCountryChanged: (c) => setState(() {
                                _selectedCountry = c;
                                _phoneError = null;
                              }),
                          validator: (value) {
                            if (_phoneError != null) return _phoneError;
                            if (value == null || value.trim().isEmpty)
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
                          onFieldSubmitted: (_) => _handlePhoneSignUp(),
                          errorText: _phoneError,
                          useTheme: false),
                      SizedBox(height: context.h(40)),
                      CustomButton(
                          text: 'Send Code',
                          onPressed: isLoading ? null : _handlePhoneSignUp,
                          isLoading: isLoading),
                      SizedBox(height: context.h(20)),
                      context.text(
                        "We'll send a 6-digit verification code\nto your phone number",
                        style: textTheme.bodyMedium.copyWith(
                          color: AppColors.grey800.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
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
