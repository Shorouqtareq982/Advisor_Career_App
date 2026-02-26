import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  static const String _themeKey = 'app_theme_mode';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey);

      if (themeIndex == null) {
        print('  No theme saved - using default light theme');
        state = ThemeMode.light;
        return;
      }

      switch (themeIndex) {
        case 0:
          state = ThemeMode.light;
          break;
        case 1:
          state = ThemeMode.dark;
          break;
        case 2:
          state = ThemeMode.system;
          break;
        default:
          state = ThemeMode.light;
      }

      print('  Theme loaded: ${state.toString()}');
    } catch (e) {
      print('  Error loading theme: $e');
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _saveTheme(newMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _saveTheme(mode);
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    try {
      state = mode;

      final prefs = await SharedPreferences.getInstance();

      int themeIndex = 0;
      if (mode == ThemeMode.light) {
        themeIndex = 0;
      } else if (mode == ThemeMode.dark) {
        themeIndex = 1;
      } else if (mode == ThemeMode.system) {
        themeIndex = 2;
      }

      await prefs.setInt(_themeKey, themeIndex);
      print('  Theme saved: $mode (index: $themeIndex)');
    } catch (e) {
      print('  Error saving theme: $e');
    }
  }

  bool get isDark => state == ThemeMode.dark;
  bool get isLight => state == ThemeMode.light;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

extension ThemeModeX on ThemeMode {
  bool get isDark => this == ThemeMode.dark;
  bool get isLight => this == ThemeMode.light;
}
