import 'package:flutter/material.dart';

/// AppTheme – Modern & Minimalistic
///
/// Design-Prinzipien:
/// - Konsistenter 16px Border-Radius überall
/// - Mehr Weißraum, subtilere Farben
/// - Kein `ColorScheme.fromSeed` – exakte Akzentfarbe
/// - Flache Oberflächen, keine Elevation-Overlays
/// - Sanfte Übergänge, reduzierte visuelle Noise
class AppTheme {
  // Einheitliche Design-Konstanten
  static const double kRadius = 16;
  static const double kRadiusLg = 20;
  static const double kRadiusSm = 12;
  static const double kRadiusPill = 999;

  static ThemeData light(Color accent) {
    final scheme = _schemeLight(accent);
    final scaffold = scheme.surfaceContainerLowest;
    final card = scheme.surfaceContainerLow;

    return _base(scheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: scaffold,
      appBarTheme: _appBarTheme(scheme, scaffold),
      cardTheme: _cardTheme(scheme, card, Brightness.light),
      dialogTheme: _dialogTheme(scheme, Colors.white),
      navigationBarTheme: _navBarTheme(scheme, scheme.surfaceContainer),
      snackBarTheme: _snackBarTheme(scheme),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.35),
        thickness: 0.5,
      ),
    );
  }

  static ThemeData dark(Color accent) {
    final scheme = _schemeDark(accent);
    final scaffold = scheme.surfaceContainerLowest;
    final card = scheme.surfaceContainerLow;

    return _base(scheme, Brightness.dark).copyWith(
      applyElevationOverlayColor: false,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: _appBarTheme(scheme, scaffold),
      cardTheme: _cardTheme(scheme, card, Brightness.dark),
      dialogTheme: _dialogTheme(scheme, const Color(0xFF1E1E22)),
      navigationBarTheme: _navBarTheme(scheme, scheme.surfaceContainer),
      snackBarTheme: _snackBarTheme(scheme),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.3),
        thickness: 0.5,
      ),
    );
  }

  // ---- Basis ----
  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    ).copyWith(applyElevationOverlayColor: false);

    final text = base.textTheme;
    final bumped = text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: text.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: text.bodySmall?.copyWith(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: text.labelMedium?.copyWith(fontSize: 12),
      labelSmall: text.labelSmall?.copyWith(fontSize: 11),
    );

    return base.copyWith(
      textTheme: bumped,

      // Icons: subtil, nicht alles in Akzentfarbe
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
        ),
      ),

      // FAB: Pill-Shape, kein übermäßiger Schatten
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 4,
        shape: const StadiumBorder(),
      ),

      // ElevatedButton: kräftige Akzentfarbe, Pill-Form
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.primary),
          foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chips: neutral, Pill-Form
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
        selectedColor: scheme.primary.withOpacity(0.12),
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
      ),

      // SegmentedButton
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary.withOpacity(0.12)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // Textfelder: sauber, minimalistisch
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withOpacity(0.5),
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),

      // SwitchListTile
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline.withOpacity(0.3),
        ),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        dense: false,
        visualDensity: VisualDensity.standard,
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withOpacity(0.4),
        dragHandleSize: const Size(32, 4),
      ),

      // TabBar
      tabBarTheme: TabBarTheme(
        dividerColor: Colors.transparent,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ProgressIndicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 3,
        linearTrackColor: scheme.primary.withOpacity(0.1),
      ),
    );
  }

  static AppBarTheme _appBarTheme(ColorScheme scheme, Color bg) => AppBarTheme(
    backgroundColor: bg,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
    titleTextStyle: TextStyle(
      color: scheme.onSurface,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
  );

  static CardTheme _cardTheme(ColorScheme scheme, Color bg, Brightness brightness) => CardTheme(
    color: bg,
    elevation: brightness == Brightness.light ? 0.5 : 0,
    shadowColor: brightness == Brightness.light
        ? const Color(0x12000000)
        : Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadius),
      side: brightness == Brightness.dark
          ? BorderSide(color: scheme.outlineVariant.withOpacity(0.15), width: 0.5)
          : BorderSide.none,
    ),
    margin: EdgeInsets.zero,
  );

  static DialogTheme _dialogTheme(ColorScheme scheme, Color bg) => DialogTheme(
    backgroundColor: bg,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    ),
    titleTextStyle: TextStyle(
      color: scheme.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
  );

  static const double kLgRadius = 20;

  static NavigationBarThemeData _navBarTheme(ColorScheme scheme, Color bg) {
    return NavigationBarThemeData(
      backgroundColor: bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant.withOpacity(0.45),
          size: states.contains(WidgetState.selected) ? 32 : 28,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant.withOpacity(0.45),
          letterSpacing: 0.1,
        ),
      ),
      height: 56,
    );
  }

  static SnackBarThemeData _snackBarTheme(ColorScheme scheme) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
        ),
        elevation: 2,
      );

  // ---------- ColorSchemes ----------
  static ColorScheme _schemeLight(Color accent) {
    final onAccent = _onColor(accent);
    final base = const ColorScheme.light();
    return base.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      primaryContainer: accent.withOpacity(0.08),
      onPrimaryContainer: accent,
      secondaryContainer: accent.withOpacity(0.08),
      onSecondaryContainer: accent,
      tertiary: const Color(0xFF4CAF50),
      onTertiary: Colors.white,
      surface: const Color(0xFFFCFBF9),
      surfaceContainerLowest: const Color(0xFFFAF9F6), // Scaffold — warmes Creme
      surfaceContainerLow: const Color(0xFFFFFEFC),     // Cards — subtil warmes Weiss
      surfaceContainer: const Color(0xFFFAF9F6),        // NavBar — nahtlos wie Scaffold
      surfaceContainerHighest: const Color(0xFFF0EEEB), // Chips, Fills — warm
      outlineVariant: const Color(0xFFDDD9D4),           // warm grey
      outline: const Color(0xFF9E9A94),                  // warm mid-grey
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
      primaryContainer: accent.withOpacity(0.15),
      onPrimaryContainer: accent,
      secondaryContainer: accent.withOpacity(0.15),
      onSecondaryContainer: accent,
      tertiary: const Color(0xFF4CAF50),
      onTertiary: Colors.white,
      surface: const Color(0xFF121214),
      surfaceContainerLowest: const Color(0xFF0E0E10),
      surfaceContainerLow: const Color(0xFF1A1A1E),
      surfaceContainer: const Color(0xFF1E1E22),
      surfaceContainerHigh: const Color(0xFF232326),
      surfaceContainerHighest: const Color(0xFF252528),
    );
  }

  static Color _onColor(Color bg) {
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
}
