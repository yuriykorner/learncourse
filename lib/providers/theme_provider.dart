import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString('theme_mode');

      if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }

      _saveToLocalStorage(themeString ?? 'system');

      notifyListeners();
    } catch (e) {
      _themeMode = ThemeMode.system;
      _saveToLocalStorage('system');
      notifyListeners();
    }
  }

  void _saveToLocalStorage(String theme) {
    try {
      web.window.localStorage.setItem('theme_mode', theme);
    } catch (e) {
      // Игнорируем ошибки на мобильных
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();

      String themeString;
      if (mode == ThemeMode.dark) {
        themeString = 'dark';
      } else if (mode == ThemeMode.light) {
        themeString = 'light';
      } else {
        themeString = 'system';
      }

      await prefs.setString('theme_mode', themeString);

      _saveToLocalStorage(themeString);

      notifyListeners();
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
