// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  static final ThemeData lightTheme = _base(
    ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
  );

  static final ThemeData darkTheme = _base(
    ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
  );
}
