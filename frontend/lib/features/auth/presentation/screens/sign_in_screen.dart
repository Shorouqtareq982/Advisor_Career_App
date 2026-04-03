import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_auth_button.dart';
import '../providers/auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_usernameOrEmailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).clearError();
    final success = await ref.read(authProvider.notifier).signIn(
          usernameOrEmail: _usernameOrEmailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (success) {
      final redirectPath = ref.read(authProvider.notifier).getRedirectPath();
      context.go(redirectPath ?? '/home');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    ref.read(authProvider.notifier).clearError();
    final success = await ref.read(authProvider.notifier).signInWithGoogle();
    if (success) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && ref.read(authProvider).isAuthenticated) {
        context.go('/home');
      }
    }
  }

  void _handlePhoneSignUp() => context.push('/phone-sign-up');

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
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
                  onPressed: () => context.go('/'),
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.blue900, size: context.icon(20)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(context.r(50)),
                  topRight: Radius.circular(context.r(50)),
                ),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
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
                      context.text(
                        'Welcome Back!',
                        style: textTheme.h5Bold.copyWith(
                          color: AppColors.blue900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      context.veryHighSpace,
                      CustomTextField(
                        controller: _usernameOrEmailController,
                        label: 'Email',
                        hintText: 'Enter Email or Username',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.emailAddress,
                        errorText:
                            authState.usernameError ?? authState.emailError,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your username or email';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (authState.usernameError != null ||
                              authState.emailError != null) {
                            ref.read(authProvider.notifier).clearError();
                          }
                        },
                        textInputAction: TextInputAction.next,
                        useTheme: false,
                      ),
                      context.highSpace,
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        errorText: authState.passwordError,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (authState.passwordError != null) {
                            ref.read(authProvider.notifier).clearError();
                          }
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSignIn(),
                        useTheme: false,
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.grey700,
                              size: context.icon(20)),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      context.mediumSpace,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: context.w(20),
                                height: context.w(20),
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(
                                      () => _rememberMe = value ?? false),
                                  fillColor: WidgetStateProperty.all(
                                      AppColors.lightBlue700),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(context.r(4))),
                                  side: BorderSide.none,
                                ),
                              ),
                              SizedBox(width: context.w(8)),
                              context.text(
                                'Remember me',
                                style: textTheme.bodyMedium.copyWith(
                                  color: AppColors.grey800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/forgot-password',
                                extra: {'useTheme': false}),
                            child: context.text(
                              'Forgot password?',
                              style: textTheme.bodyBold.copyWith(
                                color: AppColors.purple800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      context.highSpace,
                      SizedBox(
                        width: double.infinity,
                        height: context.h(48),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lightBlue700,
                            foregroundColor: AppColors.grey50,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(context.r(50))),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: context.h(24),
                                  height: context.h(24),
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.grey50)))
                              : context.text(
                                  'Sign In',
                                  style: textTheme.title2Bold.copyWith(
                                    color: AppColors.grey50,
                                  ),
                                ),
                        ),
                      ),
                      context.highSpace,
                      Row(
                        children: [
                          Expanded(
                              child: Container(
                                  height: 1, color: AppColors.grey400)),
                          Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: context.w(8)),
                              child: context.text(
                                'Sign in with',
                                style: textTheme.bodyMedium.copyWith(
                                  color: AppColors.grey800,
                                ),
                              )),
                          Expanded(
                              child: Container(
                                  height: 1, color: AppColors.grey400)),
                        ],
                      ),
                      context.mediumSpace,
                      Row(
                        children: [
                          Expanded(
                              child: GoogleSignInButton(
                                  onPressed:
                                      isLoading ? null : _handleGoogleSignIn,
                                  isLoading: false,
                                  useTheme: false)),
                          SizedBox(width: context.w(16)),
                          Expanded(
                              child: PhoneSignInButton(
                                  onPressed:
                                      isLoading ? null : _handlePhoneSignUp,
                                  isLoading: false,
                                  useTheme: false)),
                        ],
                      ),
                      context.highSpace,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          context.text(
                            "Don't have an account? ",
                            style: textTheme.bodyBold.copyWith(
                              color: AppColors.grey800,
                            ),
                          ),
                          GestureDetector(
                              onTap: () => context.go('/sign-up'),
                              child: context.text(
                                'Sign up',
                                style: textTheme.bodyBold.copyWith(
                                  color: AppColors.purple800,
                                ),
                              )),
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
