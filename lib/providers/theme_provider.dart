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

  void toggleTheme() async {
    bool isCurrentlyDark = _themeData.brightness == Brightness.dark;
    _themeData = isCurrentlyDark ? AppTheme.lightTheme : AppTheme.darkTheme;

    _themeData = _themeData.copyWith(
      colorScheme: _themeData.colorScheme.copyWith(primary: _accentColor),
      primaryColor: _accentColor,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, !isCurrentlyDark);

    notifyListeners();
  }

  void setAccentColor(MaterialColor color) async {
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
    _themeData = (isDark ? AppTheme.darkTheme : AppTheme.lightTheme).copyWith(
      colorScheme: (isDark ? AppTheme.darkTheme : AppTheme.lightTheme)
          .colorScheme
          .copyWith(primary: _accentColor),
      primaryColor: _accentColor,
    );

    notifyListeners();
  }

  /// Hilfsfunktionen zur Konvertierung von Farben zu Integer
  int _materialColorToIndex(MaterialColor color) {
    if (color == Colors.red) return 1;
    if (color == Colors.green) return 2;
    return 0; // Blau (default)
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
