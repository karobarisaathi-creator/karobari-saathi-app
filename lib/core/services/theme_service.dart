import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:account_app/core/theme/app_theme.dart';

class ThemeService with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _currentTheme = 'light';

  ThemeMode get themeMode => _themeMode;
  String get currentTheme => _currentTheme;

  ThemeService() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString('theme') ?? 'light';
    _themeMode = _currentTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  ThemeData get currentThemeData {
    if (_themeMode == ThemeMode.dark) return AppTheme.darkTheme;
    return AppTheme.lightTheme;
  }

  Future<void> changeTheme(String theme) async {
    if (_currentTheme == theme) return;

    _currentTheme = theme;
    if (theme == 'system') {
      _themeMode = ThemeMode.system;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);

    notifyListeners();
  }
}
