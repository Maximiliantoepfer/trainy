import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language setting is deliberately device-local. Translation resources are
/// compiled into the application and are never fetched from a backend.
enum AppLanguagePreference { system, german, english }

/// Resolves unsupported device languages predictably without relying on a
/// platform-specific fallback order.
Locale resolveAppLocale(Locale? requested, Iterable<Locale> supportedLocales) {
  final locales = supportedLocales.toList(growable: false);
  for (final candidate in locales) {
    if (candidate.languageCode == requested?.languageCode) return candidate;
  }
  return locales.firstWhere(
    (locale) => locale.languageCode == 'de',
    orElse: () => locales.first,
  );
}

class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';
  AppLanguagePreference _preference = AppLanguagePreference.system;

  AppLanguagePreference get preference => _preference;

  /// `null` tells [MaterialApp] to resolve the device locale.
  Locale? get localeOverride => switch (_preference) {
    AppLanguagePreference.system => null,
    AppLanguagePreference.german => const Locale('de'),
    AppLanguagePreference.english => const Locale('en'),
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _preference = switch (prefs.getString(_key)) {
      'de' => AppLanguagePreference.german,
      'en' => AppLanguagePreference.english,
      _ => AppLanguagePreference.system,
    };
    notifyListeners();
  }

  Future<void> setPreference(AppLanguagePreference value) async {
    if (value == _preference) return;
    _preference = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (value) {
      AppLanguagePreference.system => 'system',
      AppLanguagePreference.german => 'de',
      AppLanguagePreference.english => 'en',
    });
  }
}
