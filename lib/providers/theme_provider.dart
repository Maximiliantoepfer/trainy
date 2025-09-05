// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = AppTheme.darkTheme;
  MaterialColor _accentColor = Colors.blue;

  static const _darkModeKey = 'darkMode';
  static const _accentColorKey = 'accentColor';

  ThemeProvider() {
    _loadThemePreferences();
  }

  ThemeData getTheme() => _themeData;
  Color getAccentColor() => _accentColor;
  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  Future<void> toggleTheme() async {
    final isCurrentlyDark = _themeData.brightness == Brightness.dark;
    final nextBase = isCurrentlyDark ? AppTheme.lightTheme : AppTheme.darkTheme;

    _themeData = nextBase.copyWith(
      colorScheme: nextBase.colorScheme.copyWith(primary: _accentColor),
      primaryColor: _accentColor,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, !isCurrentlyDark);

    notifyListeners();
  }

  Future<void> setAccentColor(MaterialColor color) async {
    _accentColor = color;
    _themeData = _themeData.copyWith(
      colorScheme: _themeData.colorScheme.copyWith(primary: color),
      primaryColor: color,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, _materialColorToIndex(color));

    notifyListeners();
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final isDark = prefs.getBool(_darkModeKey) ?? true;
    final accentIndex = prefs.getInt(_accentColorKey) ?? 0;

    _accentColor = _indexToMaterialColor(accentIndex);

    final base = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
    _themeData = base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: _accentColor),
      primaryColor: _accentColor,
    );

    notifyListeners();
  }

  int _materialColorToIndex(MaterialColor color) {
    if (color == Colors.red) return 1;
    if (color == Colors.green) return 2;
    return 0; // blue default
  }

  MaterialColor _indexToMaterialColor(int index) {
    switch (index) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
