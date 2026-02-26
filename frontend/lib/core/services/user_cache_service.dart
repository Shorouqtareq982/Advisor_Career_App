import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/domain/entities/user_entity.dart' as entities;

class UserCacheService {
  static const String _userKey = 'cached_user';

  Future<void> saveUser(entities.AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(user.toJson());
      await prefs.setString(_userKey, json);
      print('    [CACHE] User saved locally: ${user.username}');
    } catch (e) {
      print('   [CACHE] Error saving user: $e');
    }
  }

  Future<entities.AppUser?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_userKey);
      if (json == null) {
        print('  [CACHE] No cached user found');
        return null;
      }
      final user = entities.AppUser.fromJson(jsonDecode(json));
      print('    [CACHE] User loaded from cache: ${user.username}');
      return user;
    } catch (e) {
      print('   [CACHE] Error loading user: $e');
      return null;
    }
  }

  Future<void> clearUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      print('    [CACHE] User cache cleared');
    } catch (e) {
      print('   [CACHE] Error clearing user: $e');
    }
  }

  Future<bool> hasUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userKey);
    } catch (e) {
      return false;
    }
  }
}
