import 'package:flutter/material.dart';

/// Neutrale (akzent-unabhängige) Flächenfarben:
class _Neutral {
  static const lightBackground = Color(0xFFFFFFFF); // reines Weiß
  static const lightSurface = Color(
    0xFFF6F7F9,
  ); // sehr helles Grau für Karten/Leisten

  static const darkBackground = Color(
    0xFF0E0F12,
  ); // tiefer, neutraler Schwarzton
  static const darkSurface = Color(
    0xFF15171C,
  ); // dunkles Grau für Karten/Leisten
}

class AppTheme {
  const AppTheme._();

  static ThemeData _base({
    required Color seed,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    // Farbwelt aus Akzent erzeugen ...
    final schemeSeeded = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    // ... aber Flächen explizit FIX setzen (keine Abhängigkeit von Akzent!)
    final scheme = schemeSeeded.copyWith(
      background: isDark ? _Neutral.darkBackground : _Neutral.lightBackground,
      surface: isDark ? _Neutral.darkSurface : _Neutral.lightSurface,
    );

    final fixedTextColor = isDark ? Colors.white : Colors.black;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      // Hintergrund NICHT vom Seed beeinflussen
      scaffoldBackgroundColor: scheme.background,

      // Ripple/Highlights global deaktivieren (kompatibel, ohne InkWellThemeData)
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
    );

    // Größeneffekt & Farben für Nav-Icons
    IconThemeData _navIconFor(Set<MaterialState> states) {
      final selected = states.contains(MaterialState.selected);
      return IconThemeData(
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
        size: selected ? 30 : 26, // ausgewählt leicht größer
      );
    }

    // Etwas größere & kräftigere Typografie
    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
      ),

      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
      ),

      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),

      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 17,
        height: 1.35,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 15.5,
        height: 1.35,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.35,
      ),

      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w800,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w800,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        color: fixedTextColor,
        fontWeight: FontWeight.w800,
      ),
    );

    return base.copyWith(
      // Text immer Schwarz/Weiß – unabhängig von Akzent
      textTheme: textTheme,

      // Icons global größer + in Akzentfarbe
      iconTheme: IconThemeData(color: scheme.primary, size: 26),

      // AppBar auf neutralen Surface-Ton, Text kontrastreich
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: fixedTextColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),

      // Material-3 NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 1,
        height: 76,
        surfaceTintColor: Colors.transparent,

        // KEIN Indicator/Highlight
        indicatorColor: Colors.transparent,

        // State-abhängige Icon-Farbe & -Größe
        iconTheme: MaterialStateProperty.resolveWith(_navIconFor),

        // Falls Labels doch irgendwo sichtbar werden: groß & kräftig
        labelTextStyle: MaterialStateProperty.all(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      // Fallback/Legacy (BottomNavigationBar)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedIconTheme: const IconThemeData(size: 30),
        unselectedIconTheme: const IconThemeData(size: 26),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 1,
      ),

      // Buttons akzentgeführt
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all<Color>(scheme.primary),
          foregroundColor: MaterialStateProperty.all<Color>(scheme.onPrimary),
          shape: MaterialStateProperty.all(const StadiumBorder()),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all<Color>(scheme.primary),
          foregroundColor: MaterialStateProperty.all<Color>(scheme.onPrimary),
          shape: MaterialStateProperty.all(const StadiumBorder()),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          elevation: MaterialStateProperty.all(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(scheme.primary),
          side: MaterialStateProperty.all(
            BorderSide(color: scheme.primary, width: 1.2),
          ),
          shape: MaterialStateProperty.all(const StadiumBorder()),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  static ThemeData light(Color seed) =>
      _base(seed: seed, brightness: Brightness.light);

  static ThemeData dark(Color seed) =>
      _base(seed: seed, brightness: Brightness.dark);
}
