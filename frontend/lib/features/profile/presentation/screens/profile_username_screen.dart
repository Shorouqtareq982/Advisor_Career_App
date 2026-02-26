import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/utils/auth_validators.dart';

import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/custom_button.dart';

import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileUsernameScreen extends ConsumerStatefulWidget {
  const ProfileUsernameScreen({super.key});

  @override
  ConsumerState<ProfileUsernameScreen> createState() =>
      _ProfileUsernameScreenState();
}

class _ProfileUsernameScreenState extends ConsumerState<ProfileUsernameScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user?.username != null && user!.username!.isNotEmpty) {
        _usernameController.text = user.username!;
      }
    });

    _usernameController.addListener(() {
      if (_usernameError != null) setState(() => _usernameError = null);
    });

    _passwordController.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _usernameError = 'Username is required');
      return;
    }

    final usernameValidation =
        AuthValidators.validateUsername(_usernameController.text.trim());
    if (usernameValidation != null) {
      setState(() => _usernameError = usernameValidation);
      return;
    }

    if (_passwordController.text.isNotEmpty) {
      final passwordValidation =
          AuthValidators.validatePassword(_passwordController.text);
      if (passwordValidation != null) {
        setState(() => _passwordError = passwordValidation);
        return;
      }
    }

    setState(() => _isLoading = true);

    final usernameSuccess =
        await ref.read(authProvider.notifier).updateUsername(
              _usernameController.text.trim(),
            );

    if (!mounted) return;

    if (usernameSuccess) {
      if (_passwordController.text.isNotEmpty) {
        await ref.read(authProvider.notifier).updatePassword(
              _passwordController.text,
            );
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/profile-information');
    } else {
      setState(() {
        _usernameError =
            ref.read(authProvider).usernameError ?? 'Failed to update username';
        _isLoading = false;
      });
    }
  }

  void _handleSkip() => context.go('/profile-information');

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isGoogleUser = user?.provider == 'google';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            final horizontalPad = screenW >= 1024 ? 40.0 : 20.0;

            final panelTop = (screenH * 0.44).clamp(270.0, 360.0);

            final bottomSafe = MediaQuery.of(context).padding.bottom;
            final keyboard = MediaQuery.of(context).viewInsets.bottom;

            final maxCardHeight = screenH - panelTop;

            return Stack(
              children: [
                // Background
                Positioned.fill(child: Container(color: AppColors.blue500)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/top_curve.png',
                    width: screenW,
                    height: screenH * 0.38,
                    fit: BoxFit.fill,
                  ),
                ),

                // Back
                Positioned(
                  top: context.h(10),
                  left: context.w(8),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.grey50,
                      size: context.icon(20),
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),

                // Skip
                Positioned(
                  top: context.h(14),
                  right: context.w(16),
                  child: TextButton(
                    onPressed: _handleSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.grey50,
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Logo
                Positioned(
                  top: context.h(40),
                  left: 0,
                  right: 0,
                  child: const Center(child: AppLogo()),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: maxCardHeight),
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(44),
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
                                context.h(22),
                                horizontalPad,
                                context.h(12),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Choose Your Username',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize:
                                            (screenW * 0.055).clamp(20.0, 24.0),
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.grey50
                                            : AppColors.blue900,
                                      ),
                                    ),
                                    SizedBox(height: context.h(8)),
                                    Text(
                                      isGoogleUser
                                          ? 'Set a username to personalize your profile'
                                          : 'Set your username and password to secure your account',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize:
                                            (screenW * 0.038).clamp(14.0, 16.0),
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : AppColors.grey800,
                                      ),
                                    ),
                                    SizedBox(height: context.h(18)),
                                    CustomTextField(
                                      controller: _usernameController,
                                      label: 'Username',
                                      hintText: 'Enter Username',
                                      prefixIcon: Icons.person_outline,
                                      errorText: _usernameError,
                                      textInputAction: TextInputAction.next,
                                      useTheme: true,
                                    ),
                                    SizedBox(height: context.h(14)),
                                    CustomTextField(
                                      controller: _passwordController,
                                      label: 'Password (Optional)',
                                      hintText: 'Enter password',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: _obscurePassword,
                                      errorText: _passwordError,
                                      textInputAction: TextInputAction.done,
                                      useTheme: true,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : AppColors.grey700,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    SizedBox(
                                      height:
                                          (keyboard * 0.15).clamp(0.0, 80.0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
                                text: 'Continue',
                                onPressed: _handleContinue,
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
            );
          },
        ),
      ),
    );
  }
}
