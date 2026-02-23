import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

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

    if (kIsWeb) {
      bool isDark = themeString == 'dark';
      String color = isDark ? '#121212' : '#ffffff';
      js.context.callMethod('updateThemeColor', [color]);
      js.context['localStorage'].setItem('theme_mode', themeString);
    }

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
