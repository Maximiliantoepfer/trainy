import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData _base({
    required Color seed,
    required Brightness brightness,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0E0F12) : const Color(0xFFF7F8FA),

      // Typografie – große, satte Überschriften für Screens
      textTheme: Typography.material2021(platform: TargetPlatform.android).black
          .apply(
            bodyColor: isDark ? scheme.onSurface : const Color(0xFF111418),
            displayColor: isDark ? scheme.onSurface : const Color(0xFF111418),
          )
          .copyWith(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? scheme.onSurface : const Color(0xFF101317),
            ),
            headlineMedium: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isDark ? scheme.onSurface : const Color(0xFF101317),
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? scheme.onSurface : const Color(0xFF101317),
            ),
          ),

      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF111316) : const Color(0xFFF7F8FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: isDark ? scheme.onSurface : const Color(0xFF101317),
        ),
        toolbarHeight: 72,
      ),

      // NavigationBar: keine Indikator-Fläche, ausgewähltes Icon groß + primary, andere Icons weiß
      navigationBarTheme: NavigationBarThemeData(
        height: 84,
        backgroundColor:
            isDark ? const Color(0xFF0E0F12) : const Color(0xFF111316),
        indicatorColor:
            Colors.transparent, // <— entfernt die Hintergrundmarkierung
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 34 : 28,
            color: selected ? scheme.primary : Colors.white,
            weight: selected ? 850 : 650,
          );
        }),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 0, height: 0), // Labels unsichtbar
        ),
      ),

      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF14171B) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF191C21) : const Color(0xFFF2F4F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),

      chipTheme: ChipThemeData(
        color: WidgetStatePropertyAll(
          isDark ? const Color(0xFF191C21) : const Color(0xFFF2F4F7),
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  static ThemeData light(Color seed) =>
      _base(seed: seed, brightness: Brightness.light);
  static ThemeData dark(Color seed) =>
      _base(seed: seed, brightness: Brightness.dark);
}
