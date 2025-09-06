import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: _appBarTheme(scheme, Colors.white),
      cardTheme: _cardTheme(
        scheme,
        const Color(0xFFF7F7F8), // neutral hell
      ),
      dialogTheme: _dialogTheme(scheme, Colors.white),
      navigationBarTheme: _navBarTheme(scheme, Colors.white),
    );
  }

  static ThemeData dark(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );

    const scaffold = Color(0xFF0B0B0D);
    const card = Color(0xFF121316);

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: scaffold,
      appBarTheme: _appBarTheme(scheme, scaffold),
      cardTheme: _cardTheme(scheme, card),
      dialogTheme: _dialogTheme(scheme, card),
      navigationBarTheme: _navBarTheme(scheme, scaffold),
    );
  }

  // ---- Basis: gemeinsame Einstellungen ----
  static ThemeData _base(ColorScheme scheme) {
    // Basis-Theme holen, damit wir auf dessen TextTheme aufbauen können
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    // Schrift insgesamt leicht größer, Titel deutlicher
    final text = base.textTheme;
    final bumped = text.copyWith(
      // Große Titel (z. B. AppBar) – wieder groß & fett
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 22, // vorher ~20
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      // Fließtext leicht angehoben
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15),
      labelMedium: text.labelMedium?.copyWith(fontSize: 13),
    );

    return base.copyWith(
      textTheme: bumped,

      // Kräftige Akzentfarbe für Icons
      iconTheme: IconThemeData(color: scheme.primary),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(scheme.primary),
        ),
      ),

      // Buttons: kräftig, keine Tonal-Variante
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(scheme.primary),
          foregroundColor: MaterialStatePropertyAll(scheme.onPrimary),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          elevation: const MaterialStatePropertyAll(0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // Chips/Segmente: neutrale Flächen
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        selectedColor: scheme.surfaceVariant,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(color: scheme.onSurface),
        secondarySelectedColor: scheme.surfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(scheme.surfaceVariant),
          foregroundColor: MaterialStateProperty.resolveWith(
            (s) =>
                s.contains(MaterialState.selected)
                    ? scheme.primary
                    : scheme.onSurface,
          ),
          side: MaterialStateProperty.resolveWith(
            (s) => BorderSide(
              color:
                  s.contains(MaterialState.selected)
                      ? scheme.primary
                      : scheme.outlineVariant,
            ),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // Textfelder: neutral
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
    );
  }

  static AppBarTheme _appBarTheme(ColorScheme scheme, Color bg) => AppBarTheme(
    backgroundColor: bg,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: scheme.primary),
    titleTextStyle: TextStyle(
      // wichtig: groß & fett
      color: scheme.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
  );

  static CardTheme _cardTheme(ColorScheme scheme, Color bg) => CardTheme(
    color: bg,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  static DialogTheme _dialogTheme(ColorScheme scheme, Color bg) => DialogTheme(
    backgroundColor: bg,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  static NavigationBarThemeData _navBarTheme(ColorScheme scheme, Color bg) {
    // Un-/Ausgewählt unterschiedlich groß
    const double unselectedSize = 26;
    const double selectedSize = 32;

    return NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: Colors.transparent, // kein Glow/Indicator
      // Icon-Größe & -Farbe nach Status
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color:
              states.contains(MaterialState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
          size:
              states.contains(MaterialState.selected)
                  ? selectedSize
                  : unselectedSize,
        ),
      ),
      // Label-Größe & -Gewicht nach Status
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: states.contains(MaterialState.selected) ? 13 : 12,
          fontWeight:
              states.contains(MaterialState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
          color:
              states.contains(MaterialState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
          letterSpacing: -0.1,
        ),
      ),
      height: 76, // etwas höher für größere Icons/Labels
    );
  }
}
