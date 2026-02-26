import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_cache_service.dart';
import '../../domain/entities/user_entity.dart' as entities;

class AuthProviderState {
  final entities.AppUser? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  // Field-specific errors
  final String? usernameError;
  final String? emailError;
  final String? phoneError;
  final String? passwordError;

  const AuthProviderState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.usernameError,
    this.emailError,
    this.phoneError,
    this.passwordError,
  });

  AuthProviderState copyWith({
    entities.AppUser? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    String? usernameError,
    String? emailError,
    String? phoneError,
    String? passwordError,
  }) {
    return AuthProviderState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      usernameError: usernameError,
      emailError: emailError,
      phoneError: phoneError,
      passwordError: passwordError,
    );
  }

  /// Clear all field errors
  AuthProviderState clearFieldErrors() {
    return AuthProviderState(
      user: user,
      isLoading: isLoading,
      error: error,
      isAuthenticated: isAuthenticated,
      usernameError: null,
      emailError: null,
      phoneError: null,
      passwordError: null,
    );
  }
}

/// Auth provider notifier
class AuthNotifier extends StateNotifier<AuthProviderState> {
  final AuthService _authService;
  final UserCacheService _cache = UserCacheService();

  bool _isResettingPassword = false;
  void Function()? _onAuthStateChanged;
  String? _lastSignInInput;

  AuthNotifier(this._authService) : super(const AuthProviderState()) {
    _init();
    _listenToAuthChanges();
  }

  void setOnAuthStateChanged(void Function() callback) {
    _onAuthStateChanged = callback;
  }

  /// Initialize auth state
  Future<void> _init() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    final cachedUser = await _cache.getUser();
    if (cachedUser != null && cachedUser.id == userId) {
      print('    [INIT] Loaded user from cache: ${cachedUser.username}');
      state = state.copyWith(
        user: cachedUser,
        isAuthenticated: true,
      );
    }
    try {
      final freshUser = await _authService.getUserProfile(userId);
      if (freshUser != null) {
        print('    [INIT] Refreshed user from Supabase: ${freshUser.username}');
        await _cache.saveUser(freshUser);
        state = state.copyWith(
          user: freshUser,
          isAuthenticated: true,
        );
      }
    } catch (e) {
      print('  [INIT] Could not refresh from Supabase (offline?): $e');
    }
  }

  /// Listen to auth state changes
  void _listenToAuthChanges() {
    _authService.authStateChanges.listen((AuthState authState) async {
      print('  [AUTH STATE] Changed: ${authState.event}');

      if (authState.session?.user != null) {
        print('   User ID: ${authState.session!.user.id}');
        print('   Email: ${authState.session!.user.email}');
        print(
            '   Provider: ${authState.session!.user.appMetadata['provider']}');
      } else {
        print('   No session');
      }

      if (authState.event == AuthChangeEvent.signedIn) {
        print('    [AUTH STATE] User signed in!');

        if (_isResettingPassword) {
          print(
              '  [AUTH STATE] Ignoring signedIn event - in reset password mode');
          return;
        }

        print('  [AUTH STATE] Processing user profile...');

        if (authState.session?.user != null) {
          final userId = authState.session!.user.id;

          await Future.delayed(const Duration(milliseconds: 1000));

          final user = await _authService.getUserProfile(userId);
          if (user != null) {
            print('    Profile loaded successfully');
            await _cache.saveUser(user);

            state = AuthProviderState(
              user: user,
              isAuthenticated: true,
              isLoading: false,
            );

            print('    State updated with user: ${user.username}');
            print('    isAuthenticated: true');

            if (_onAuthStateChanged != null) {
              print(' Calling auth state changed callback');
              _onAuthStateChanged!();
            }
          } else {
            print('  Profile not found after sign in');
            state = const AuthProviderState(
              isAuthenticated: true,
              isLoading: false,
            );
          }
        }
      } else if (authState.event == AuthChangeEvent.signedOut) {
        print('  [AUTH STATE] User signed out');

        if (_isResettingPassword) {
          print('  [AUTH STATE] In reset password mode - keeping state');
          return;
        }

        await _cache.clearUser();
        state = const AuthProviderState();
      }
    });
  }

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      return await _authService.checkEmailExists(email);
    } catch (e) {
      print('   Error checking email: $e');
      return false;
    }
  }

  // Check if phone exists
  Future<bool> checkPhoneExists(String phone) async {
    try {
      return await _authService.checkPhoneExists(phone);
    } catch (e) {
      print('   Error checking phone: $e');
      return false;
    }
  }

  /// Parse error messages
  Map<String, String?> _parseError(dynamic error) {
    final errorStr = error.toString();

    final Map<String, String?> errors = {
      'general': null,
      'username': null,
      'email': null,
      'phone': null,
      'password': null,
    };

    print(' Parsing error: $errorStr');

    if (errorStr.contains('USERNAME_NOT_FOUND')) {
      errors['username'] = 'No account found with this username';
    }
    if (errorStr.contains('USERNAME_EXISTS') ||
        (errorStr.contains('duplicate key') && errorStr.contains('username')) ||
        (errorStr.contains('23505') && errorStr.contains('username'))) {
      errors['username'] = 'This username is already taken';
    }

    if (errorStr.contains('EMAIL_NOT_FOUND')) {
      errors['email'] = 'No account found with this email';
    }
    if (errorStr.contains('EMAIL_EXISTS') ||
        (errorStr.contains('duplicate key') && errorStr.contains('email')) ||
        (errorStr.contains('23505') && errorStr.contains('email'))) {
      errors['email'] = 'This email is already registered';
    }

    if (errorStr.contains('PHONE_NOT_FOUND')) {
      errors['phone'] = 'No account found with this phone number';
    }
    if (errorStr.contains('PHONE_EXISTS') ||
        (errorStr.contains('duplicate key') && errorStr.contains('phone')) ||
        (errorStr.contains('23505') && errorStr.contains('phone'))) {
      errors['phone'] = 'This phone number is already registered';
    }

    if (errorStr.contains('INVALID_PASSWORD')) {
      errors['password'] = 'Incorrect password';
    }

    if (errorStr.contains('INVALID_CREDENTIALS') ||
        errorStr.contains('Invalid login credentials')) {
      errors['general'] = 'Invalid username/email or password';
    }

    if (errorStr.contains('Email not confirmed')) {
      errors['email'] = 'Please confirm your email before signing in';
    }

    if (errorStr.contains('User already registered')) {
      errors['email'] = 'This email is already registered';
    }

    if (errorStr.contains('rate limit')) {
      errors['general'] = 'Too many attempts. Please try again later';
    }

    if (errorStr.contains('HandshakeException')) {
      errors['general'] = 'Network error. Please check your connection';
    }

    if (errorStr.contains('Database error')) {
      errors['general'] = 'Service error. Please try again';
    }

    if (errors['general'] == null &&
        errors['username'] == null &&
        errors['email'] == null &&
        errors['phone'] == null &&
        errors['password'] == null) {
      errors['general'] = errorStr.replaceAll('Exception: ', '');
    }

    print('    Parsed errors: $errors');
    return errors;
  }

  /// Sign up with email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String phone,
  }) async {
    if (!_isValidEmail(email)) {
      state = state.clearFieldErrors().copyWith(
            emailError: 'Please enter a valid email address',
          );
      return false;
    }

    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);

      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        username: username,
        phone: phone,
      );

      if (response.user != null) {
        final user = await _authService.getUserProfile(response.user!.id);
        if (user != null) await _cache.saveUser(user);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      }

      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        usernameError: errors['username'],
        emailError: errors['email'],
        phoneError: errors['phone'],
        passwordError: errors['password'],
      );
      return false;
    }
  }

  /// Sign up with Google
  Future<bool> signUpWithGoogle() async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);
      final success = await _authService.signUpWithGoogle();
      if (success) return true;
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Sign in
  Future<bool> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      _lastSignInInput = usernameOrEmail;
      state = state.clearFieldErrors().copyWith(isLoading: true);

      final response = await _authService.signIn(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      if (response.user != null) {
        final user = await _authService.getUserProfile(response.user!.id);
        final updatedUser = user?.copyWith(hasCompletedOnboarding: true);
        if (updatedUser != null) await _cache.saveUser(updatedUser);

        state = state.copyWith(
          user: updatedUser,
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      }

      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        usernameError: errors['username'],
        emailError: errors['email'],
        passwordError: errors['password'],
      );
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);
      final success = await _authService.signInWithGoogle();
      if (success) return true;
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Sign out — امسح الـ cache
  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true);
      await _authService.signOut();
      await _cache.clearUser(); // ← امسح
      state = const AuthProviderState();
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
    }
  }

  /// Send email OTP
  Future<bool> sendEmailOTP(String email) async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);
      await _authService.sendEmailOTP(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        emailError: errors['email'],
      );
      return false;
    }
  }

  /// Send phone OTP
  Future<bool> sendPhoneOTP(String phone) async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);
      await _authService.sendPhoneOTP(phone);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        phoneError: errors['phone'],
      );
      return false;
    }
  }

  /// Verify email OTP
  Future<bool> verifyEmailOTP({
    required String email,
    required String otp,
    bool isResetPassword = false,
  }) async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);

      if (isResetPassword) _isResettingPassword = true;

      final response = await _authService.verifyEmailOTP(
        email: email,
        otp: otp,
      );

      if (response.user != null) {
        if (isResetPassword) {
          state = state.copyWith(isLoading: false, isAuthenticated: false);
        } else {
          final user = await _authService.getUserProfile(response.user!.id);
          if (user != null) await _cache.saveUser(user);
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );
        }
        return true;
      }

      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      _isResettingPassword = false;
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Verify phone OTP
  Future<bool> verifyPhoneOTP({
    required String phone,
    required String otp,
    bool isResetPassword = false,
    bool isSignIn = false,
  }) async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);

      final response = await _authService.verifyPhoneOTP(
        phone: phone,
        otp: otp,
      );

      if (response.user != null) {
        if (isResetPassword) {
          await _authService.signOut();
          await _cache.clearUser();
          state = state.copyWith(
            user: null,
            isAuthenticated: false,
            isLoading: false,
          );
        } else {
          final user = await _authService.getUserProfile(response.user!.id);
          if (user != null) await _cache.saveUser(user);
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );

          if (isSignIn && user?.hasCompletedOnboarding != true) {
            await _authService.markOnboardingCompleted(response.user!.id);
            final updatedUser = user!.copyWith(hasCompletedOnboarding: true);
            await _cache.saveUser(updatedUser);
            state = state.copyWith(user: updatedUser);
          }
        }
        return true;
      }

      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      state = state.clearFieldErrors().copyWith(isLoading: true);
      await _authService.sendEmailOTP(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        emailError: errors['email'],
      );
      return false;
    }
  }

  // PROFILE COMPLETION METHODS

  /// Update username
  Future<bool> updateUsername(String username) async {
    if (state.user == null) {
      state = state.copyWith(error: 'No user logged in');
      return false;
    }

    try {
      state = state.copyWith(isLoading: true);

      await _authService.updateProfile(
        userId: state.user!.id,
        username: username,
      );

      final updatedUser = state.user!.copyWith(username: username);
      await _cache.saveUser(updatedUser);

      state = state.copyWith(user: updatedUser, isLoading: false);
      print('    Username updated successfully: $username');
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        usernameError: errors['username'],
      );
      return false;
    }
  }

  /// Update top skills
  Future<bool> updateTopSkills(String topSkills) async {
    if (state.user == null) return false;

    try {
      state = state.copyWith(isLoading: true);

      await _authService.updateProfile(
        userId: state.user!.id,
        topSkills: topSkills,
      );

      final updatedUser = state.user!.copyWith(topSkills: topSkills);
      await _cache.saveUser(updatedUser);

      state = state.copyWith(user: updatedUser, isLoading: false);
      print('    Top skills updated: $topSkills');
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Upload avatar image
  Future<String?> uploadAvatar(File imageFile) async {
    if (state.user == null) return null;

    try {
      state = state.copyWith(isLoading: true);

      final avatarUrl =
          await _authService.uploadAvatar(state.user!.id, imageFile);

      if (avatarUrl != null) {
        final updatedUser = state.user!.copyWith(avatarUrl: avatarUrl);
        await _cache.saveUser(updatedUser);
        state = state.copyWith(user: updatedUser, isLoading: false);
        print('    Avatar uploaded: $avatarUrl');
      } else {
        state = state.copyWith(isLoading: false);
      }

      return avatarUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Upload CV
  Future<String?> uploadCV(File file) async {
    if (state.user == null) return null;

    try {
      state = state.copyWith(isLoading: true);

      final cvUrl = await _authService.uploadCV(state.user!.id, file.path);

      if (cvUrl != null) {
        final updatedUser = state.user!.copyWith(cvUrl: cvUrl);
        await _cache.saveUser(updatedUser);
        state = state.copyWith(user: updatedUser, isLoading: false);
        print('    CV uploaded: $cvUrl');
      } else {
        state = state.copyWith(isLoading: false);
      }

      return cvUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      state = state.copyWith(isLoading: true);
      await _authService.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Reset password
  Future<bool> resetPassword({
    required String newPassword,
    String? email,
    String? phone,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      await _authService.resetPasswordWithToken(
        newPassword: newPassword,
        email: email,
        phone: phone,
      );

      await _authService.signOut();
      await _cache.clearUser();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  Future<bool> updateUserProfile({
    String? fullName,
    String? username,
    String? email,
    String? phone,
    String? avatarUrl,
    String? topSkills,
    String? domain,
    String? linkedinUrl,
    String? cvUrl,
    String? preferredLocation,
    String? interestedTracks,
    String? jobTitle,
    String? joinTime,
    List<String>? workType,
    List<String>? workLocation,
    List<String>? jobPlatforms,
    String? jobAlertsFrequency,
  }) async {
    if (state.user == null) {
      state = state.copyWith(error: 'No user logged in');
      return false;
    }

    if (email != null && email.isNotEmpty && !_isValidEmail(email)) {
      state = state.clearFieldErrors().copyWith(
            emailError: 'Please enter a valid email address',
          );
      return false;
    }

    try {
      state = state.copyWith(isLoading: true);

      await _authService.updateProfile(
        userId: state.user!.id,
        fullName: fullName,
        username: username,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        topSkills: topSkills,
        domain: domain,
        linkedinUrl: linkedinUrl,
        cvUrl: cvUrl,
        preferredLocation: preferredLocation,
        interestedTracks: interestedTracks,
        jobTitle: jobTitle,
        joinTime: joinTime,
        workType: workType,
        workLocation: workLocation,
        jobPlatforms: jobPlatforms,
        jobAlertsFrequency: jobAlertsFrequency,
      );

      // Refresh user data
      final updatedUser = await _authService.getUserProfile(state.user!.id);
      if (updatedUser != null) await _cache.saveUser(updatedUser);

      state = state.copyWith(user: updatedUser, isLoading: false);
      print('    Profile updated successfully in provider');
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        usernameError: errors['username'],
        emailError: errors['email'],
        phoneError: errors['phone'],
      );
      return false;
    }
  }

  /// Delete user account
  Future<bool> deleteAccount(String password) async {
    try {
      state = state.copyWith(isLoading: true);
      await _authService.deleteAccount(password);
      await _cache.clearUser();
      state = const AuthProviderState();
      print('    Account deleted successfully from provider');
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        passwordError: errors['password'],
      );
      return false;
    }
  }

  // PASSWORD METHODS
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final success = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      state = state.copyWith(isLoading: false);
      if (success) await refreshUser();
      return success;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Send password reset OTP
  Future<bool> sendPasswordResetOTP({
    required String method,
    required String contact,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final success = await _authService.sendPasswordResetOTP(
        method: method,
        contact: contact,
      );

      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Reset password with OTP
  Future<bool> resetPasswordWithOTP({
    required String method,
    required String contact,
    required String otp,
    required String newPassword,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      final success = await _authService.resetPasswordWithOTP(
        method: method,
        contact: contact,
        otp: otp,
        newPassword: newPassword,
      );

      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Get next profile screen
  String? get nextProfileScreen {
    if (state.user == null) return null;
    final user = state.user!;
    if ((user.provider == 'phone' || user.provider == 'google') &&
        (user.username == null || user.username!.isEmpty)) {
      return '/profile-username';
    }
    return '/profile-information';
  }

  /// Get redirect path after authentication
  String? getRedirectPath() {
    if (state.user == null) return null;
    final user = state.user!;

    print('  [REDIRECT] Checking redirect for user: ${user.id}');
    print('   Provider: ${user.provider}');
    print('   Has completed onboarding: ${user.hasCompletedOnboarding}');

    if (user.hasCompletedOnboarding == true) {
      print(' User completed onboarding - redirecting to /home');
      return '/home';
    }

    if (user.provider == 'google' || user.provider == 'phone') {
      return '/profile-username';
    }

    if (user.provider == 'email') {
      return '/profile-information';
    }

    return '/home';
  }

  /// Check if user needs to complete profile
  bool get needsProfileCompletion {
    if (state.user == null) return false;
    final user = state.user!;

    if (user.provider == 'phone') {
      return user.topSkills == null || user.topSkills!.isEmpty;
    }
    if (user.provider == 'google') {
      return (user.username == null || user.username!.isEmpty) ||
          (user.topSkills == null || user.topSkills!.isEmpty);
    }
    return user.topSkills == null || user.topSkills!.isEmpty;
  }

  /// Refresh user data من Supabase وحفظ في الـ cache
  Future<void> refreshUser() async {
    if (state.user == null) return;

    try {
      final updatedUser = await _authService.getUserProfile(state.user!.id);
      if (updatedUser != null) {
        await _cache.saveUser(updatedUser);
        state = state.copyWith(user: updatedUser);
        print('    User data refreshed');
      }
    } catch (e) {
      print('   Error refreshing user (offline?): $e');
      // مشكلة، الـ cache موجود
    }
  }

  // DELETE ACCOUNT METHODS

  Future<bool> deleteAccountWithPassword(String password) async {
    try {
      state = state.copyWith(isLoading: true);
      await _authService.deleteAccountWithPassword(password);
      await _cache.clearUser(); // ← امسح
      state = const AuthProviderState();
      return true;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(
        isLoading: false,
        error: errors['general'],
        passwordError: errors['password'],
      );
      return false;
    }
  }

  Future<bool> deleteAccountWithEmailOTP(String otp) async {
    try {
      state = state.copyWith(isLoading: true);
      final user = state.user;
      if (user?.email == null) throw Exception('No email found');

      final success = await _authService.deleteAccountWithEmailOTP(
        email: user!.email!,
        otp: otp,
      );

      if (success) {
        await _cache.clearUser(); // ← امسح
        state = const AuthProviderState();
      } else {
        state = state.copyWith(isLoading: false);
      }
      return success;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  Future<bool> deleteAccountWithPhoneOTP(String otp) async {
    try {
      state = state.copyWith(isLoading: true);
      final user = state.user;
      if (user?.phone == null) throw Exception('No phone found');

      final success = await _authService.deleteAccountWithPhoneOTP(
        phone: user!.phone!,
        otp: otp,
      );

      if (success) {
        await _cache.clearUser(); // ← امسح
        state = const AuthProviderState();
      } else {
        state = state.copyWith(isLoading: false);
      }
      return success;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  Future<bool> sendDeleteAccountOTP(String method) async {
    try {
      state = state.copyWith(isLoading: true);
      final success = await _authService.sendDeleteAccountOTP(method);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      final errors = _parseError(e);
      state = state.copyWith(isLoading: false, error: errors['general']);
      return false;
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    if (state.user == null) return;

    try {
      await _authService.markOnboardingCompleted(state.user!.id);
      final updatedUser = state.user!.copyWith(hasCompletedOnboarding: true);
      await _cache.saveUser(updatedUser);
      state = state.copyWith(user: updatedUser);
      print('    Onboarding completed for user: ${state.user!.id}');
    } catch (e) {
      print('   Error completing onboarding: $e');
    }
  }

  /// Clear error
  void clearError() {
    state = state.clearFieldErrors();
  }
}

/// Auth provider instance
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthProviderState>((ref) {
  return AuthNotifier(AuthService());
});
