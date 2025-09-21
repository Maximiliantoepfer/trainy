import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _kAccentKey = 'accent_argb';
  static const _kThemeModeKey = 'theme_mode'; // system|light|dark

  Color _accent = const Color.fromARGB(
    255,
    71,
    118,
    248,
  ); // default accent (hellblau)
  ThemeMode _themeMode = ThemeMode.system;

  Color get accent => _accent;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> setAccent(Color color) async {
    _accent = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, color.value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final argb = prefs.getInt(_kAccentKey);
    final modeStr = prefs.getString(_kThemeModeKey);

    if (argb != null) _accent = Color(argb);
    if (modeStr != null) {
      _themeMode = switch (modeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }
    notifyListeners();
  }
}
