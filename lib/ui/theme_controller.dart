import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static const String _themeKey = 'user_theme_mode';

  // Global ValueNotifier for theme state
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_themeKey);

    if (savedIndex != null) {
      themeNotifier.value = ThemeMode.values[savedIndex];
    } else {
      themeNotifier.value = ThemeMode.light;
    }
  }

  // Update theme and save preference to disk
  static Future<void> updateTheme(ThemeMode newMode) async {
    themeNotifier.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, newMode.index);
  }
}
