import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/auth_service.dart';

/// Auth repository implementation using Supabase
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;
  final AuthService _authService;

  AuthRepositoryImpl(this._supabase) : _authService = AuthService();

  @override
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  @override
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
        emailRedirectTo: 'io.supabase.growza://login-callback/',
      );

      if (response.user != null) {
        return {'success': true, 'user': response.user};
      } else {
        return {'success': false, 'message': 'Sign up failed'};
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return {'success': true, 'user': response.user};
      } else {
        return {'success': false, 'message': 'Sign in failed'};
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.growza://login-callback/',
      );

      if (response) {
        await Future.delayed(const Duration(seconds: 2));
        final user = _supabase.auth.currentUser;
        if (user != null) {
          return {'success': true, 'user': user};
        }
      }

      return {'success': false, 'message': 'Google sign in cancelled'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> signInWithPhone(String phoneNumber) async {
    try {
      await _supabase.auth.signInWithOtp(
        phone: phoneNumber,
      );
      return {'success': true};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> verifyPhoneOtp(
      String phone, String token) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      if (response.user != null) {
        return {'success': true, 'user': response.user};
      }

      return {'success': false, 'message': 'Invalid verification code'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> verifyEmailOtp(String token) async {
    try {
      final email = _supabase.auth.currentUser?.email;
      if (email == null) {
        return {'success': false, 'message': 'No email found'};
      }

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (response.user != null) {
        return {'success': true, 'user': response.user};
      }

      return {'success': false, 'message': 'Invalid verification code'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.growza://reset-password/',
      );
      return {'success': true};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.email,
        email: email,
      );
      return {'success': true};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // 🗑️ DELETE ACCOUNT METHODS

  @override
  Future<bool> sendDeleteAccountOTP(String method) async {
    return _authService.sendDeleteAccountOTP(method);
  }

  @override
  Future<bool> deleteAccountWithPassword(String password) async {
    try {
      await _authService.deleteAccountWithPassword(password);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteAccountWithEmailOTP(String email, String otp) async {
    return _authService.deleteAccountWithEmailOTP(email: email, otp: otp);
  }

  @override
  Future<bool> deleteAccountWithPhoneOTP(String phone, String otp) async {
    return _authService.deleteAccountWithPhoneOTP(phone: phone, otp: otp);
  }
}
