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

    MaterialStateProperty<T> ms<T>(T v) => MaterialStateProperty.all(v);
    T sel<T>(Set<MaterialState> s, T a, T b) =>
        s.contains(MaterialState.selected) ? a : b;

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),

      // Icons
      iconTheme: IconThemeData(color: scheme.onSurface),

      // FAB (Start-Button etc.)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
        elevation: 0,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: ms(buttonShape),
          elevation: ms(0.0),
          padding: ms(const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          backgroundColor: ms(scheme.primary),
          foregroundColor: ms(scheme.onPrimary),
          overlayColor: ms(scheme.primaryContainer.withOpacity(.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: ms(buttonShape),
          elevation: ms(0.0),
          padding: ms(const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          backgroundColor: ms(scheme.primaryContainer),
          foregroundColor: ms(scheme.onPrimaryContainer),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: ms(buttonShape),
          foregroundColor: ms(scheme.primary),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surface,
      ),

      // Cards
      cardTheme: CardTheme(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(0),
      ),

      // Slider/Switch
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceVariant,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withOpacity(.1),
      ),
      switchTheme: SwitchThemeData(
        trackColor: MaterialStateProperty.resolveWith((states) {
          final on = states.contains(MaterialState.selected);
          return on ? scheme.primary.withOpacity(.5) : scheme.surfaceVariant;
        }),
        thumbColor: MaterialStateProperty.resolveWith((states) {
          final on = states.contains(MaterialState.selected);
          return on ? scheme.primary : scheme.outline;
        }),
      ),

      // NavigationBar (M3)
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent, // kein „Pill“-Indicator
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final color = sel(
            states,
            scheme.primary,
            isDark ? scheme.onSurface : scheme.onSurfaceVariant,
          );
          return IconThemeData(color: color);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final color = sel(
            states,
            scheme.primary,
            isDark ? scheme.onSurface : scheme.onSurfaceVariant,
          );
          return TextStyle(fontWeight: FontWeight.w600, color: color);
        }),
      ),
    );
  }

  static ThemeData light(Color seed) =>
      _base(seed: seed, brightness: Brightness.light);

  static ThemeData dark(Color seed) =>
      _base(seed: seed, brightness: Brightness.dark);
}
