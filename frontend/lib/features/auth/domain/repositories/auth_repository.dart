import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract repository defining auth operations
abstract class AuthRepository {
  /// Get current user
  User? getCurrentUser();

  /// Sign up with email and password
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  });

  /// Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle();

  /// Sign in with phone OTP
  Future<Map<String, dynamic>> signInWithPhone(String phoneNumber);

  /// Verify phone OTP
  Future<Map<String, dynamic>> verifyPhoneOtp(String phone, String token);

  /// Verify email OTP
  Future<Map<String, dynamic>> verifyEmailOtp(String token);

  /// Reset password
  Future<Map<String, dynamic>> resetPassword(String email);

  /// Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail(String email);

  /// Sign out
  Future<void> signOut();

  // 🗑️ DELETE ACCOUNT METHODS

  /// Send OTP for account deletion
  Future<bool> sendDeleteAccountOTP(String method);

  /// Delete account with password
  Future<bool> deleteAccountWithPassword(String password);

  /// Delete account with email OTP
  Future<bool> deleteAccountWithEmailOTP(String email, String otp);

  /// Delete account with phone OTP
  Future<bool> deleteAccountWithPhoneOTP(String phone, String otp);
}
