import 'package:flutter/material.dart';

/// AppTheme
/// - FIX: Verwendet **kein** `ColorScheme.fromSeed` mehr.
///   Das M3-Seed erzeugt eine Tonal-Palette (Primary-Tone ~40/80),
///   wodurch Buttons/Icons sichtbar **heller** als der eingestellte Akzent wirken.
///   Stattdessen nehmen wir ColorScheme.light/dark und überschreiben `primary`
///   (und `secondary`) exakt mit dem Akzent.
/// - Zusätzlich: Elevation-Overlay im Dark-Mode deaktiviert.
class AppTheme {
  static ThemeData light(Color accent) {
    final scheme = _schemeLight(accent);

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: _appBarTheme(scheme, Colors.white),
      cardTheme: _cardTheme(
        scheme,
        const Color(0xFFF7F7F8), // neutrales helles Card-White
      ),
      dialogTheme: _dialogTheme(scheme, Colors.white),
      navigationBarTheme: _navBarTheme(scheme, Colors.white),
    );
  }

  static ThemeData dark(Color accent) {
    final scheme = _schemeDark(accent);

    // Feste, akzentunabhängige Dark-Hintergründe
    const scaffold = Color(0xFF0B0B0D);
    const card = Color(0xFF121316);

    return _base(scheme).copyWith(
      applyElevationOverlayColor: false,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: _appBarTheme(scheme, scaffold),
      cardTheme: _cardTheme(scheme, card),
      dialogTheme: _dialogTheme(scheme, card),
      navigationBarTheme: _navBarTheme(scheme, scaffold),
    );
  }

  // ---- Basis: gemeinsame Einstellungen ----
  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    ).copyWith(applyElevationOverlayColor: false);

    // Schrift insgesamt leicht größer, Titel deutlicher
    final text = base.textTheme;
    final bumped = text.copyWith(
      // Große Titel (z. B. AppBar) – groß & fett
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 22,
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

      // Icons sollen kräftig in Akzentfarbe erscheinen
      iconTheme: IconThemeData(color: scheme.primary),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(scheme.primary),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 8,
        // shape: StadiumBorder(), // optional, wenn du die Pill-Optik forcieren willst
      ),

      // Buttons: kräftige Akzentfarbe, keine Tonal-Variante
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

      // Chips/”Pills”: immer neutrale Fläche
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceVariant,
        selectedColor: scheme.surfaceVariant,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(color: scheme.onSurface),
        secondarySelectedColor: scheme.surfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      // SegmentedButton neutral, bei Auswahl nur Border/Text in Akzentfarbe
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(scheme.surfaceVariant),
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) =>
                states.contains(MaterialState.selected)
                    ? scheme.primary
                    : scheme.onSurface,
          ),
          side: MaterialStateProperty.resolveWith(
            (states) => BorderSide(
              color:
                  states.contains(MaterialState.selected)
                      ? scheme.primary
                      : scheme.outlineVariant,
            ),
          ),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // Textfelder: neutrale Füllung, keine Tints
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
      // Labels werden in der MainNavigation verborgen; Stil hier nur fallback
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

  // ---------- ColorSchemes ohne Seed ----------
  static ColorScheme _schemeLight(Color accent) {
    final onAccent = _onColor(accent);
    final base = const ColorScheme.light();
    return base.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      // optionale Annäherung – Container nutzen wir als Hintergründe kaum
      primaryContainer: accent.withOpacity(0.12),
      onPrimaryContainer: _onColor(accent.withOpacity(0.12)),
      secondaryContainer: accent.withOpacity(0.12),
      onSecondaryContainer: _onColor(accent.withOpacity(0.12)),
    );
  }

  static ColorScheme _schemeDark(Color accent) {
    final onAccent = _onColor(accent);
    final base = const ColorScheme.dark();
    return base.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      primaryContainer: accent.withOpacity(0.20),
      onPrimaryContainer: _onColor(accent.withOpacity(0.20)),
      secondaryContainer: accent.withOpacity(0.20),
      onSecondaryContainer: _onColor(accent.withOpacity(0.20)),
    );
  }

  static Color _onColor(Color bg) {
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
}
