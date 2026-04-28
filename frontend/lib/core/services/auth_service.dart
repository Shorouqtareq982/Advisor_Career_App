import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/entities/user_entity.dart' as entities;
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  entities.AppUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    return entities.AppUser(
      id: user.id,
      email: user.email,
      username:
          user.userMetadata?['username'] ?? 'user_${user.id.substring(0, 8)}',
      phone: user.phone,
      avatarUrl:
          user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
      provider: user.appMetadata['provider'] as String? ?? 'email',
    );
  }

  bool get isAuthenticated => _client.auth.currentUser != null;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<String?> validateSignUpFields({
    required String email,
    required String username,
    required String phone,
  }) async {
    print(' [VALIDATION] Starting field validation...');

    if (!_isValidEmail(email)) {
      print(' [VALIDATION] Invalid email format: $email');
      return 'Please enter a valid email address';
    }

    final usernameError = _validateUsername(username);
    if (usernameError != null) {
      print('   [VALIDATION] Invalid username: $usernameError');
      return usernameError;
    }

    final phoneError = _validatePhoneNumber(phone);
    if (phoneError != null) {
      print('   [VALIDATION] Invalid phone: $phoneError');
      return phoneError;
    }

    try {
      List<String> errors = [];

      print('     [VALIDATION] Checking username availability...');
      final usernameExists = await _checkUsernameExists(username);
      if (usernameExists) {
        errors.add('USERNAME_EXISTS');
        print('   [VALIDATION] Username already exists: $username');
      } else {
        print('    [VALIDATION] Username is available');
      }

      print('  [VALIDATION] Checking email availability...');
      final emailExists = await checkEmailExists(email);
      if (emailExists) {
        errors.add('EMAIL_EXISTS');
        print('   [VALIDATION] Email already exists: $email');
      } else {
        print('    [VALIDATION] Email is available');
      }

      print('  [VALIDATION] Checking phone availability...');
      final phoneExists = await checkPhoneExists(phone);
      if (phoneExists) {
        errors.add('PHONE_EXISTS');
        print('   [VALIDATION] Phone already exists: $phone');
      } else {
        print('    [VALIDATION] Phone is available');
      }

      if (errors.isNotEmpty) {
        final errorMessage = errors.join(', ');
        print('   [VALIDATION] Errors found: $errorMessage');
        return errorMessage;
      }

      print('  [VALIDATION] All fields are valid!');
      return null;
    } catch (e) {
      print('  [VALIDATION] Error during availability check: $e');
      return 'Error checking data. Please try again';
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  String? _validateUsername(String username) {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 50) return 'Username cannot exceed 50 characters';
    if (!RegExp(r'^[\u0600-\u06FFa-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain Arabic/English letters, numbers and (_)';
    }
    return null;
  }

  String? _validatePhoneNumber(String phone) {
    if (phone.isEmpty) return 'Phone number is required';
    if (!phone.startsWith('+')) {
      return 'Phone number must start with country code (e.g., +20)';
    }
    final phoneDigits = phone.substring(1);
    if (!RegExp(r'^[0-9]+$').hasMatch(phoneDigits)) {
      return 'Phone number must contain digits only';
    }
    if (phoneDigits.length < 8 || phoneDigits.length > 15) {
      return 'Invalid phone number length';
    }
    return null;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String phone,
  }) async {
    try {
      print('  [EMAIL FORM SIGNUP] Starting...');

      print('     Username: $username');
      print('  Email: $email');
      print('  Phone: $phone');

      if (!phone.startsWith('+')) {
        throw Exception(
            'Phone number must start with country code (e.g., +20)');
      }

      final validationError = await validateSignUpFields(
        email: email,
        username: username,
        phone: phone,
      );

      if (validationError != null) {
        throw Exception(validationError);
      }

      print('  Creating user in auth...');
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'phone': phone,
        },
      );

      if (response.user != null) {
        print('    User created successfully: ${response.user!.id}');

        await Future.delayed(const Duration(milliseconds: 1500));

        final profile = await getUserProfile(response.user!.id);
        if (profile == null) {
          print('  Profile not created by trigger, creating manually...');
          await _ensureProfileExists(
            userId: response.user!.id,
            email: email,
            username: username,
            phone: phone,
            provider: 'email',
          );
        } else {
          print('    Profile created successfully by trigger');
          print('   Phone in profile: ${profile.phone}');
        }
      }

      print('    [EMAIL FORM SIGNUP] Completed!');

      return response;
    } on AuthException catch (e) {
      print('   Supabase auth error: ${e.message}');

      String errorMessage;
      if (e.message.contains('already registered') ||
          e.message.contains('User already registered')) {
        errorMessage = 'EMAIL_EXISTS: This email is already registered';
      } else if (e.message.contains('invalid email')) {
        errorMessage = 'Invalid email format';
      } else if (e.message.contains('weak password')) {
        errorMessage = 'Password is too weak';
      } else if (e.message.contains('phone')) {
        errorMessage = 'PHONE_EXISTS: This phone number is already registered';
      } else {
        errorMessage = 'Registration failed: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      print('   Email form signup error: $e');
      rethrow;
    }
  }

  Future<bool> signUpWithGoogle() async {
    try {
      print(' [GOOGLE SIGNUP] Starting...');

      final currentUser = _client.auth.currentUser;
      if (currentUser != null) {
        print(
            '    [GOOGLE SIGNUP] User already signed in: ${currentUser.email}');
        return true;
      }

      print('  [GOOGLE SIGNUP] Initiating OAuth flow...');

      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.growza://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      print('    [GOOGLE SIGNUP] OAuth initiated: $result');
      return result;
    } catch (e) {
      print('   [GOOGLE SIGNUP] Error: $e');
      rethrow;
    }
  }

  Future<void> signUpWithPhone({
    required String phone,
  }) async {
    try {
      print('  [PHONE ONLY SIGNUP] Starting...');

      print('  Phone: $phone');

      if (!phone.startsWith('+')) {
        throw Exception(
            'Phone number must start with country code (e.g., +20)');
      }

      print(' Checking phone availability...');
      final phoneExists = await checkPhoneExists(phone);
      if (phoneExists) {
        print('   Phone number already exists: $phone');
        throw Exception(
            'PHONE_EXISTS: This phone number is already registered');
      }
      print('    Phone is available');

      print('  Sending OTP...');
      await _client.auth.signInWithOtp(
        phone: phone,
        data: {'phone': phone},
      );

      print('    OTP sent to phone: $phone');

      print('    [PHONE ONLY SIGNUP] OTP Sent!');
    } catch (e) {
      print('   [PHONE SIGNUP] Error: $e');
      rethrow;
    }
  }

  // SIGN IN METHODS

  Future<AuthResponse> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      print(' [SIGN IN] Attempting sign in for: $usernameOrEmail');

      String email = usernameOrEmail;

      if (usernameOrEmail.contains('@')) {
        print('  Looking up email: $usernameOrEmail');
        final emailExists = await checkEmailExists(usernameOrEmail);
        if (!emailExists) {
          print('   Email not found: $usernameOrEmail');
          throw Exception('EMAIL_NOT_FOUND: No account found with this email');
        }
      } else {
        print('     Looking up email for username: $usernameOrEmail');

        final response = await _client
            .from('profiles')
            .select('email')
            .ilike('username', usernameOrEmail)
            .maybeSingle();

        if (response == null) {
          print('   Username not found: $usernameOrEmail');
          throw Exception(
              'USERNAME_NOT_FOUND: No account found with this username');
        }

        email = response['email'] as String;
        print('    Found email for username: $email');

        if (!email.contains('@') || !email.contains('.')) {
          print('   Invalid email format in database: $email');
          throw Exception(
              'INVALID_CREDENTIALS: Account issue. Please contact support.');
        }
      }

      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        print('    Sign in successful: ${authResponse.user!.id}');

        final userEmail = authResponse.user!.email;
        if (userEmail != email) {
          print('  Email mismatch: Auth has $userEmail, Profile has $email');
        }

        await markOnboardingCompleted(authResponse.user!.id);
        print('    Onboarding marked as completed for sign in user');
      }

      return authResponse;
    } on AuthException catch (e) {
      print('   Supabase auth error: ${e.message}');

      if (e.message.contains('Invalid login credentials')) {
        throw Exception('INVALID_PASSWORD: Incorrect password');
      } else if (e.message.contains('Email not confirmed')) {
        throw Exception('Please confirm your email before signing in');
      }

      throw Exception(e.message);
    } catch (e) {
      print('   Sign in error: $e');
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      print(' [GOOGLE SIGNIN] Starting...');

      final currentUser = _client.auth.currentUser;
      if (currentUser != null) {
        print(
            '    [GOOGLE SIGNIN] User already signed in: ${currentUser.email}');
        return true;
      }

      print('  [GOOGLE SIGNIN] Initiating OAuth flow...');

      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.growza://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      print('    [GOOGLE SIGNIN] OAuth initiated: $result');
      return result;
    } catch (e) {
      print('   [GOOGLE SIGNIN] Error: $e');
      rethrow;
    }
  }

  // OTP VERIFICATION

  Future<void> sendEmailOTP(String email) async {
    try {
      print('  Sending OTP to email: $email');

      final exists = await checkEmailExists(email);
      if (!exists) {
        print('   Email not found: $email');
        throw Exception('EMAIL_NOT_FOUND: No account found with this email');
      }

      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      print('    Email OTP sent successfully');
    } on AuthException catch (e) {
      print('   Supabase error sending email OTP: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('   Error sending email OTP: $e');
      rethrow;
    }
  }

  Future<void> sendPhoneOTP(String phone) async {
    try {
      print('  Sending OTP to phone: $phone');

      if (!phone.startsWith('+')) {
        throw Exception(
            'Phone number must start with country code (e.g., +20)');
      }

      final exists = await checkPhoneExists(phone);
      if (!exists) {
        print('   Phone not found: $phone');
        throw Exception(
            'PHONE_NOT_FOUND: No account found with this phone number');
      }

      await _client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: false,
      );

      print('    Phone OTP sent successfully');
    } on AuthException catch (e) {
      print('   Supabase error sending phone OTP: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('   Error sending phone OTP: $e');
      rethrow;
    }
  }

  Future<AuthResponse> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    try {
      print('  Verifying email OTP for: $email');

      final response = await _client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: otp,
      );

      print('    Email OTP verified: ${response.user?.id}');

      return response;
    } on AuthException catch (e) {
      print('   Error verifying email OTP: ${e.message}');

      if (e.message.contains('invalid') || e.message.contains('expired')) {
        throw Exception('Invalid or expired verification code');
      }

      throw Exception(e.message);
    } catch (e) {
      print('   Error verifying email OTP: $e');
      rethrow;
    }
  }

  Future<AuthResponse> verifyPhoneOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      print('  Verifying phone OTP for: $phone');

      final response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: otp,
      );

      print('    Phone OTP verified: ${response.user?.id}');

      if (response.user != null) {
        await Future.delayed(const Duration(milliseconds: 1500));

        final profile = await getUserProfile(response.user!.id);
        if (profile == null) {
          print('  Profile not created by trigger, creating manually...');

          final username = 'user_${response.user!.id.substring(0, 8)}';

          await _ensureProfileExists(
            userId: response.user!.id,
            email: '$phone@phone.user',
            username: username,
            phone: phone,
            provider: 'phone',
          );

          print('    Profile created for phone user');
        }
      }

      return response;
    } on AuthException catch (e) {
      print('   Error verifying phone OTP: ${e.message}');

      if (e.message.contains('invalid') || e.message.contains('expired')) {
        throw Exception('Invalid or expired verification code');
      }

      throw Exception(e.message);
    } catch (e) {
      print('   Error verifying phone OTP: $e');
      rethrow;
    }
  }

  // PROFILE MANAGEMENT

  Future<entities.AppUser?> getUserProfile(String userId) async {
    try {
      print('     Fetching profile for: $userId');

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('  Profile not found: $userId');
        return null;
      }

      print('    Profile fetched successfully');
      return entities.AppUser.fromJson(response);
    } catch (e) {
      print('  Error fetching profile: $e');
      return null;
    }
  }

  Future<void> _ensureProfileExists({
    required String userId,
    required String email,
    required String username,
    String? phone,
    String? avatarUrl,
    String? provider = 'email',
  }) async {
    try {
      print('     Ensuring profile exists for: $userId');

      final existing = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        print('  Creating new profile...');
        await _client.from('profiles').insert({
          'id': userId,
          'email': email.toLowerCase(),
          'username': username,
          'phone': phone,
          'avatar_url': avatarUrl,
          'provider': provider,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('    Profile created');
      } else {
        print('  Updating existing profile...');
        final updates = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (phone != null) updates['phone'] = phone;
        if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
        if (provider != null) updates['provider'] = provider;

        await _client.from('profiles').update(updates).eq('id', userId);
        print('    Profile updated');
      }
    } catch (e) {
      print('   Error ensuring profile: $e');
    }
  }

  // HELPER METHODS

  Future<bool> _checkUsernameExists(String username) async {
    try {
      print(' Checking username: $username');

      final response = await _client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      final exists = response != null;
      print('  Username exists: $exists');
      return exists;
    } catch (e) {
      print('  Error checking username: $e');
      return false;
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      print(' Checking email: $email');

      final response = await _client
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();

      final exists = response != null;
      print('  Email exists: $exists');
      return exists;
    } catch (e) {
      print('  Error checking email: $e');
      return false;
    }
  }

  Future<bool> checkPhoneExists(String phone) async {
    try {
      print(' Checking phone: $phone');

      if (phone.isEmpty) return false;

      final response = await _client
          .from('profiles')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('  Error checking phone: $e');
      return false;
    }
  }

  // OTHER METHODS

  Future<void> sendPasswordResetEmail(String email) async {
    return sendEmailOTP(email);
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      print(' Updating password...');

      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('    Password updated successfully');
      return response;
    } on AuthException catch (e) {
      print('   Error updating password: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('   Error updating password: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      print('  Signing out...');
      await _client.auth.signOut();
      print('    Signed out successfully');
    } catch (e) {
      print('   Error signing out: $e');
      rethrow;
    }
  }

  // PASSWORD RESET METHODS

  Future<UserResponse> resetPasswordWithToken({
    required String newPassword,
    String? email,
    String? phone,
  }) async {
    try {
      print(' Resetting password for: ${email ?? phone}');

      final session = _client.auth.currentSession;
      if (session == null) {
        print('   No active session found');
        throw Exception('No active session. Please verify your code again.');
      }

      print('    Active session found for user: ${session.user.id}');

      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('    Password reset successfully');

      return response;
    } on AuthException catch (e) {
      print('   Error resetting password: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('   Error resetting password: $e');
      rethrow;
    }
  }

  // PROFILE MANAGEMENT - UPDATED WITH EMAIL

  /// Update profile with all fields - MODIFIED WITH EMAIL and improved error handling
  Future<void> updateProfile({
    required String userId,
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
    try {
      print('  Updating profile for: $userId');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (username != null) updates['username'] = username;
      if (email != null) updates['email'] = email.toLowerCase();
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (topSkills != null) updates['top_skills'] = topSkills;
      if (domain != null) updates['domain'] = domain;
      if (linkedinUrl != null) updates['linkedin_url'] = linkedinUrl;
      if (cvUrl != null) updates['cv_url'] = cvUrl;
      if (preferredLocation != null) {
        updates['preferred_location'] = preferredLocation;
      }
      if (interestedTracks != null) {
        updates['interested_tracks'] = interestedTracks;
      }
      if (jobTitle != null) updates['job_title'] = jobTitle;
      if (joinTime != null) updates['join_time'] = joinTime;
      if (workType != null) updates['work_type'] = workType;
      if (workLocation != null) updates['work_location'] = workLocation;
      if (jobPlatforms != null) updates['job_platforms'] = jobPlatforms;
      if (jobAlertsFrequency != null) {
        updates['job_alerts_frequency'] = jobAlertsFrequency;
      }

      await _client.from('profiles').update(updates).eq('id', userId);

      print('    Profile updated successfully');
      print('   Fields updated: ${updates.keys.join(', ')}');
    } on PostgrestException catch (e) {
      print(
        '   Postgrest error updating profile: ${e.message}, code: ${e.code}, details: ${e.details}',
      );

      // Handle unique constraint violations
      if (e.code == '23505') {
        //     FIX: message is non-nullable -> remove null-aware operator (?.)
        if (e.message.contains('username')) {
          throw Exception('USERNAME_EXISTS: This username is already taken');
        } else if (e.message.contains('email')) {
          throw Exception('EMAIL_EXISTS: This email is already registered');
        } else if (e.message.contains('phone')) {
          throw Exception(
              'PHONE_EXISTS: This phone number is already registered');
        }
      }
      rethrow;
    } catch (e) {
      print('   Error updating profile: $e');
      rethrow;
    }
  }

  /// Upload CV file
  Future<String?> uploadCV(String userId, String filePath) async {
    try {
      print(' Uploading CV for: $userId');

      final file = File(filePath);
      if (!await file.exists()) {
        print('   File does not exist: $filePath');
        return null;
      }

      // ← الحل: نحتفظ بالاسم الأصلي للملف
      final originalName = filePath.split('/').last.split('\\').last;
      // نضيف timestamp عشان مينفعش يتكرر في الـ storage لكن نحتفظ بالاسم الأصلي
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = originalName.contains('.')
          ? originalName.split('.').last.toLowerCase()
          : 'pdf';
      // اسم الفايل في الـ storage: timestamp.ext (عشان unique)
      // لكن بنحفظ الاسم الأصلي بطريقة تانية (شوف تحت)
      final storageName = '${timestamp}.$ext';

      final fileBytes = await file.readAsBytes();

      try {
        await _client.storage.createBucket('cvs');
      } catch (e) {}

      await _client.storage.from('cvs').uploadBinary(
            '$userId/$storageName',
            fileBytes,
          );

      final publicUrl =
          _client.storage.from('cvs').getPublicUrl('$userId/$storageName');

      print('    CV uploaded successfully: $publicUrl');

      // ← نضيف query parameter بالاسم الأصلي عشان نقدر نسترجعه
      // مثلاً: ...1776291038558.pdf?original=Ranim_Moustafa_CV.pdf
      final urlWithName =
          '$publicUrl?original=${Uri.encodeComponent(originalName)}';

      await updateProfile(
        userId: userId,
        cvUrl: urlWithName,
      );
      print('    CV URL saved to profile: $urlWithName');

      return urlWithName;
    } catch (e) {
      print('   Error uploading CV: $e');
      return null;
    }
  }

  /// Upload avatar
  Future<String?> uploadAvatar(String userId, File imageFile) async {
    try {
      print(' Uploading avatar for: $userId');

      final fileName =
          'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await imageFile.readAsBytes();

      try {
        await _client.storage.createBucket('avatars');
        print('    Avatars bucket created');
      } catch (e) {
        print('  Avatars bucket already exists or error: $e');
      }

      await _client.storage.from('avatars').uploadBinary(
            '$userId/$fileName',
            fileBytes,
          );

      final publicUrl =
          _client.storage.from('avatars').getPublicUrl('$userId/$fileName');

      print('    Avatar uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('   Error uploading avatar: $e');
      return null;
    }
  }

  /// Get profile completion status
  Future<Map<String, bool>> getProfileCompletionStatus(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) {
        return {'hasUsername': false, 'hasSkills': false, 'isComplete': false};
      }

      final hasUsername =
          profile.username != null && profile.username!.isNotEmpty;
      final hasSkills =
          profile.topSkills != null && profile.topSkills!.isNotEmpty;

      return {
        'hasUsername': hasUsername,
        'hasSkills': hasSkills,
        'isComplete': profile.isProfileComplete,
      };
    } catch (e) {
      print('   Error checking profile status: $e');
      return {'hasUsername': false, 'hasSkills': false, 'isComplete': false};
    }
  }

  /// Delete user account
  Future<void> deleteAccount(String password) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      await _client.rpc('delete_user', params: {'user_id': user.id});

      await signOut();

      print('    Account deleted successfully');
    } catch (e) {
      print('   Error deleting account: $e');
      rethrow;
    }
  }

  // PASSWORD MANAGEMENT

  Future<bool> verifyCurrentPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      final isValid = await verifyCurrentPassword(currentPassword);
      if (!isValid) {
        throw Exception('Current password is incorrect');
      }

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('    Password changed successfully');
      return true;
    } on AuthException catch (e) {
      print('   Error changing password: ${e.message}');
      return false;
    } catch (e) {
      print('   Error changing password: $e');
      return false;
    }
  }

  Future<bool> sendPasswordResetOTP({
    required String method,
    required String contact,
  }) async {
    try {
      if (method == 'email') {
        await sendEmailOTP(contact);
      } else {
        await sendPhoneOTP(contact);
      }
      return true;
    } catch (e) {
      print('   Error sending password reset OTP: $e');
      return false;
    }
  }

  Future<bool> resetPasswordWithOTP({
    required String method,
    required String contact,
    required String otp,
    required String newPassword,
  }) async {
    try {
      AuthResponse response;

      if (method == 'email') {
        response = await verifyEmailOTP(email: contact, otp: otp);
      } else {
        response = await verifyPhoneOTP(phone: contact, otp: otp);
      }

      if (response.user == null) {
        throw Exception('Invalid OTP');
      }

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      await signOut();

      print('    Password reset successfully');
      return true;
    } catch (e) {
      print('   Error resetting password: $e');
      return false;
    }
  }

  // DELETE ACCOUNT METHODS

  Future<void> deleteAccountWithPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      await _client.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      await _client.rpc('delete_user', params: {'user_id': user.id});

      await signOut();

      print('    Account deleted successfully with password');
    } catch (e) {
      print('   Error deleting account with password: $e');
      rethrow;
    }
  }

  Future<bool> deleteAccountWithEmailOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      final response = await _client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: otp,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP');
      }

      await _client.rpc('delete_user', params: {'user_id': user.id});

      await signOut();

      print('    Account deleted successfully with email OTP');
      return true;
    } catch (e) {
      print('   Error deleting account with email OTP: $e');
      return false;
    }
  }

  Future<bool> deleteAccountWithPhoneOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      final response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: otp,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP');
      }

      await _client.rpc('delete_user', params: {'user_id': user.id});

      await signOut();

      print('    Account deleted successfully with phone OTP');
      return true;
    } catch (e) {
      print('   Error deleting account with phone OTP: $e');
      return false;
    }
  }

  Future<bool> sendDeleteAccountOTP(String method) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      if (method == 'email' && user.email != null) {
        await _client.auth.signInWithOtp(
          email: user.email!,
          shouldCreateUser: false,
        );
      } else if (method == 'phone' && user.phone != null) {
        await _client.auth.signInWithOtp(
          phone: user.phone!,
          shouldCreateUser: false,
        );
      } else {
        throw Exception('Invalid verification method');
      }

      print('    Delete account OTP sent successfully');
      return true;
    } catch (e) {
      print('   Error sending delete account OTP: $e');
      return false;
    }
  }

  // ONBOARDING STATUS MANAGEMENT

  Future<void> markOnboardingCompleted(String userId) async {
    try {
      print('  Marking onboarding as completed for: $userId');

      await _client.from('profiles').update({
        'has_completed_onboarding': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      print('    Onboarding marked as completed');
    } catch (e) {
      print('   Error marking onboarding completed: $e');
    }
  }

  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('has_completed_onboarding')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return false;

      return response['has_completed_onboarding'] == true;
    } catch (e) {
      print('  Error checking onboarding status: $e');
      return false;
    }
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
