import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = AppTheme.darkTheme;
  MaterialColor _accentColor = Colors.blue; // Verwende MaterialColor

  ThemeData getTheme() => _themeData;
  Color getAccentColor() => _accentColor; // Gib Color zurück

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  void setTheme(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }

  void toggleTheme() {
    bool isCurrentlyDark = _themeData.brightness == Brightness.dark;

    _themeData = isCurrentlyDark ? AppTheme.lightTheme : AppTheme.darkTheme;

    // Accent-Farbe beibehalten
    _themeData = _themeData.copyWith(
      colorScheme: _themeData.colorScheme.copyWith(primary: _accentColor),
      primaryColor: _accentColor,
    );

    notifyListeners();
  }

  void setAccentColor(MaterialColor color) {
    // Verwende MaterialColor
    _accentColor = color;
    _themeData = _themeData.copyWith(
      colorScheme: _themeData.colorScheme.copyWith(primary: color),
      primaryColor: color, // Setze primaryColor
    );
    notifyListeners();
  }
}
