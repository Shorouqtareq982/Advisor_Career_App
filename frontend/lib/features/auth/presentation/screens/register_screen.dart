import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/social_auth_button.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/models/country_model.dart';
import '../../../../core/utils/auth_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneInputKey = GlobalKey<PhoneInputFieldState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _serverUsernameError;
  String? _serverEmailError;
  String? _serverPhoneError;
  String? _serverPasswordError;
  String? _serverGeneralError;
  Country _selectedCountry = Countries.defaultCountry;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    _usernameController.addListener(() {
      if (_serverUsernameError != null)
        setState(() => _serverUsernameError = null);
      if (_serverGeneralError != null)
        setState(() => _serverGeneralError = null);
    });
    _emailController.addListener(() {
      if (_serverEmailError != null) setState(() => _serverEmailError = null);
      if (_serverGeneralError != null)
        setState(() => _serverGeneralError = null);
    });
    _phoneController.addListener(() {
      if (_serverPhoneError != null) setState(() => _serverPhoneError = null);
      if (_serverGeneralError != null)
        setState(() => _serverGeneralError = null);
    });
    _passwordController.addListener(() {
      if (_serverPasswordError != null)
        setState(() => _serverPasswordError = null);
      if (_serverGeneralError != null)
        setState(() => _serverGeneralError = null);
    });
    _confirmPasswordController.addListener(() {
      if (_serverGeneralError != null)
        setState(() => _serverGeneralError = null);
    });
  }

  String? _validateUsername(String? value) {
    if (_serverUsernameError != null) return _serverUsernameError;
    if (value == null || value.trim().isEmpty) return 'Username is required';
    final u = value.trim();
    if (u.length < 3) return 'Username must be at least 3 characters';
    if (u.length > 20) return 'Username must be less than 20 characters';
    if (!RegExp(r'^[a-zA-Z]').hasMatch(u[0]))
      return 'Username must start with a letter';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(u))
      return 'Only letters, numbers, and underscores';
    if (u.contains('__')) return 'No consecutive underscores';
    if (u.endsWith('_')) return 'Username cannot end with underscore';
    return null;
  }

  String? _validateEmail(String? value) {
    if (_serverEmailError != null) return _serverEmailError;
    return AuthValidators.validateEmail(value);
  }

  String? _validatePassword(String? value) {
    if (_serverPasswordError != null) return _serverPasswordError;
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    if (!RegExp(r'[a-zA-Z]').hasMatch(value))
      return 'Password must contain at least one letter';
    if (!RegExp(r'\d').hasMatch(value))
      return 'Password must contain at least one number';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _handleEmailSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final fullPhone = _phoneInputKey.currentState!.getFullPhoneNumber();
      final success = await ref.read(authProvider.notifier).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
          phone: fullPhone);
      if (!mounted) return;
      if (success) {
        context.go('/profile-information');
      } else {
        final authState = ref.read(authProvider);
        setState(() {
          _serverUsernameError = authState.usernameError;
          _serverEmailError = authState.emailError;
          _serverPhoneError = authState.phoneError;
          _serverPasswordError = authState.passwordError;
          _serverGeneralError = authState.error;
        });
        _formKey.currentState!.validate();
      }
    } catch (e) {
      if (mounted) {
        final error = e.toString().replaceAll('Exception: ', '');
        if (error.toLowerCase().contains('email'))
          setState(() => _serverEmailError = error);
        else if (error.toLowerCase().contains('phone'))
          setState(() => _serverPhoneError = error);
        else if (error.toLowerCase().contains('username'))
          setState(() => _serverUsernameError = error);
        else if (error.toLowerCase().contains('password'))
          setState(() => _serverPasswordError = error);
        else
          setState(() => _serverGeneralError = error);
        _formKey.currentState!.validate();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signUpWithGoogle();
    } catch (e) {
      if (mounted) print('Google sign up failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePhoneSignUp() => context.push('/phone-sign-up');

  @override
  Widget build(BuildContext context) {
    final textTheme = context.appTextTheme;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const BackgroundCurves(),

          // Logo
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: context.h(40)),
                child: const AppLogo(),
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding:
                    EdgeInsets.only(top: context.h(48), left: context.w(8)),
                child: IconButton(
                  onPressed: () => context.go('/'),
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: AppColors.blue900,
                    size: context.icon(20),
                  ),
                ),
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.grey50,
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
                    children: [
                      // Title
                      context.text(
                        'Get Started',
                        style: textTheme.h5Bold.copyWith(
                          color: AppColors.blue900,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      context.veryHighSpace,

                      // Username field
                      CustomTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hintText: 'Enter Username',
                        prefixIcon: Icons.person_outline,
                        validator: _validateUsername,
                        onChanged: (_) {
                          if (_serverUsernameError != null)
                            setState(() => _serverUsernameError = null);
                        },
                        textInputAction: TextInputAction.next,
                        useTheme: false,
                      ),

                      context.highSpace,

                      // Email field
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        onChanged: (_) {
                          if (_serverEmailError != null)
                            setState(() => _serverEmailError = null);
                        },
                        textInputAction: TextInputAction.next,
                        useTheme: false,
                      ),

                      context.highSpace,

                      // Phone field
                      PhoneInputField(
                        key: _phoneInputKey,
                        controller: _phoneController,
                        selectedCountry: _selectedCountry,
                        onCountryChanged: (c) => setState(() {
                          _selectedCountry = c;
                          _serverPhoneError = null;
                        }),
                        label: 'Phone Number',
                        validator: (value) {
                          if (_serverPhoneError != null)
                            return _serverPhoneError;
                          if (value == null || value.trim().isEmpty)
                            return 'Phone number is required';
                          if (value.length != _selectedCountry.phoneLength)
                            return 'Must be exactly ${_selectedCountry.phoneLength} digits';
                          return null;
                        },
                        onChanged: (_) {
                          if (_serverPhoneError != null)
                            setState(() => _serverPhoneError = null);
                        },
                        textInputAction: TextInputAction.next,
                        useTheme: false,
                      ),

                      context.highSpace,

                      // Password field
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: _validatePassword,
                        onChanged: (_) {
                          if (_serverPasswordError != null)
                            setState(() => _serverPasswordError = null);
                        },
                        textInputAction: TextInputAction.next,
                        useTheme: false,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.grey700,
                            size: context.icon(20),
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),

                      context.highSpace,

                      // Confirm password field
                      CustomTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Re-enter password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        validator: _validateConfirmPassword,
                        textInputAction: TextInputAction.done,
                        useTheme: false,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.grey700,
                            size: context.icon(20),
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),

                      // Error message
                      if (_serverGeneralError != null) ...[
                        context.highSpace,
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.red600,
                              size: context.icon(14),
                            ),
                            SizedBox(width: context.w(6)),
                            Expanded(
                              child: context.text(
                                _serverGeneralError!,
                                style: textTheme.bodyRegular.copyWith(
                                  color: AppColors.red600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      context.highSpace,

                      // Sign Up button
                      SizedBox(
                        width: double.infinity,
                        height: context.h(48),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleEmailSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lightBlue700,
                            foregroundColor: AppColors.grey50,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(context.r(50)),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: context.h(24),
                                  height: context.h(24),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.grey50,
                                    ),
                                  ),
                                )
                              : context.text(
                                  'Sign Up',
                                  style: textTheme.title2Bold.copyWith(
                                    color: AppColors.grey50,
                                  ),
                                ),
                        ),
                      ),

                      context.highSpace,

                      // Divider with text
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.grey400,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.w(8),
                            ),
                            child: context.text(
                              'Sign up with',
                              style: textTheme.bodyMedium.copyWith(
                                color: AppColors.grey800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.grey400,
                            ),
                          ),
                        ],
                      ),

                      context.mediumSpace,

                      // Social buttons
                      Row(
                        children: [
                          Expanded(
                            child: GoogleSignInButton(
                              onPressed:
                                  _isLoading ? null : _handleGoogleSignUp,
                              isLoading: false,
                              useTheme: false,
                            ),
                          ),
                          SizedBox(width: context.w(16)),
                          Expanded(
                            child: PhoneSignInButton(
                              onPressed: _isLoading ? null : _handlePhoneSignUp,
                              isLoading: false,
                              useTheme: false,
                            ),
                          ),
                        ],
                      ),

                      context.highSpace,

                      // Sign in link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          context.text(
                            "Already have an account? ",
                            style: textTheme.bodyBold.copyWith(
                              color: AppColors.grey800,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/sign-in'),
                            child: context.text(
                              'Sign in',
                              style: textTheme.bodyBold.copyWith(
                                color: AppColors.purple800,
                              ),
                            ),
                          ),
                        ],
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
