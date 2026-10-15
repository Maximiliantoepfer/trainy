import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/catalog_exercise.dart';

/// Read-only local catalog. It has no network dependency and is loaded once
/// during app startup so display lookups stay synchronous in widgets.
class CatalogRepository {
  CatalogRepository._();

  static final CatalogRepository instance = CatalogRepository._();

  final Map<String, CatalogExercise> _definitions = {};
  final Map<String, Map<String, CatalogLocalizedContent>> _contentByLocale = {};
  bool _isLoaded = false;
  String? _loadError;

  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;
  Iterable<CatalogExercise> get definitions => _definitions.values;
  CatalogExercise? byId(String? id) => id == null ? null : _definitions[id];

  /// Returns false when a release does not bundle a complete, reviewed
  /// catalog yet. Existing personal exercises keep working in that state.
  Future<bool> load() async {
    if (_isLoaded) return true;
    _definitions.clear();
    _contentByLocale.clear();
    _loadError = null;
    try {
      final catalogJson =
          jsonDecode(await rootBundle.loadString('assets/catalog/catalog.json'))
              as Map<String, dynamic>;
      final source = Map<String, dynamic>.from(
        catalogJson['source'] ?? const {},
      );
      if (catalogJson['schemaVersion'] != 1 ||
          source['license'] != 'Unlicense' ||
          (source['exerciseCount'] as num? ?? 0).toInt() <= 0) {
        throw const FormatException('Invalid catalog manifest.');
      }
      for (final raw in List<dynamic>.from(
        catalogJson['exercises'] ?? const [],
      )) {
        final definition = CatalogExercise.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (_definitions.containsKey(definition.id)) {
          throw FormatException('Duplicate catalog ID ${definition.id}.');
        }
        _definitions[definition.id] = definition;
      }
      await Future.wait(['de', 'en'].map(_loadLocale));
      for (final id in _definitions.keys) {
        for (final locale in const ['de', 'en']) {
          final content = _contentByLocale[locale]?[id];
          if (content == null ||
              !content.reviewed ||
              content.name.trim().isEmpty ||
              content.instructions.isEmpty ||
              content.searchTerms.isEmpty) {
            throw FormatException(
              'Incomplete reviewed $locale content for $id.',
            );
          }
        }
      }
      _isLoaded = true;
      return true;
    } catch (error) {
      _definitions.clear();
      _contentByLocale.clear();
      _loadError = error.toString();
      return false;
    }
  }

  Future<void> _loadLocale(String locale) async {
    final decoded =
        jsonDecode(
              await rootBundle.loadString(
                'assets/catalog/catalog_$locale.json',
              ),
            )
            as Map<String, dynamic>;
    if (decoded['locale'] != locale || decoded['schemaVersion'] != 1) {
      throw const FormatException('Invalid localized catalog.');
    }
    final records = Map<String, CatalogLocalizedContent>.fromEntries(
      (decoded['exercises'] as Map<String, dynamic>? ?? const {}).entries.map(
        (entry) => MapEntry(
          entry.key,
          CatalogLocalizedContent.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
        ),
      ),
    );
    _contentByLocale[locale] = records;
  }

  CatalogLocalizedContent? content(String? id, String localeCode) {
    if (id == null) return null;
    return _contentByLocale[localeCode]?[id] ?? _contentByLocale['en']?[id];
  }

  LocalizedCatalogExercise? localized(String? id, String localeCode) {
    final definition = byId(id);
    final localizedContent = content(id, localeCode);
    if (definition == null || localizedContent == null) return null;
    return LocalizedCatalogExercise(
      definition: definition,
      content: localizedContent,
    );
  }

  List<LocalizedCatalogExercise> search(String localeCode, String query) {
    final normalized = query.trim().toLowerCase();
    return _definitions.values
        .map((definition) => localized(definition.id, localeCode))
        .whereType<LocalizedCatalogExercise>()
        .where((exercise) {
          if (normalized.isEmpty) return true;
          final haystack =
              [
                exercise.content.name,
                exercise.content.description,
                ...exercise.content.searchTerms,
                ...exercise.definition.aliases,
              ].join(' ').toLowerCase();
          return haystack.contains(normalized);
        })
        .toList();
  }
}
