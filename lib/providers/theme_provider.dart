import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_helper.dart'
    if (dart.library.js) '../utils/theme_helper_web.dart' as theme_helper;

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');

    if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
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

    // ✅ ОБНОВЛЯЕМ WEB
    theme_helper.saveThemeToLocalStorage(themeString);

    bool isDark;
    if (themeString == 'dark') {
      isDark = true;
    } else if (themeString == 'light') {
      isDark = false;
    } else {
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }

    String color = isDark ? '#121212' : '#ffffff';
    theme_helper.updateThemeColor(color);

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
