import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../models/catalog_exercise.dart';
import 'database_schema_v2.dart';

/// Read-only local catalog. It has no network dependency and is loaded once
/// in the background with the exercise provider so first paint is not blocked.
class CatalogRepository {
  CatalogRepository._();

  static final CatalogRepository instance = CatalogRepository._();

  final Map<String, CatalogExercise> _definitions = {};
  final Map<String, Map<String, CatalogLocalizedContent>> _contentByLocale = {};
  bool _isLoaded = false;
  Future<bool>? _loadInFlight;
  String? _loadError;
  String? _catalogVersion;

  static const _freeExerciseDbCommit =
      'a859101d633a01c4a1a920d6a8ce41dabba0705f';

  bool get isLoaded => _isLoaded;
  String? get loadError => _loadError;
  String? get catalogVersion => _catalogVersion;
  Iterable<CatalogExercise> get definitions => _definitions.values;
  CatalogExercise? byId(String? id) => id == null ? null : _definitions[id];

  /// Returns false when a release does not bundle a complete, reviewed
  /// catalog yet. Existing personal exercises keep working in that state.
  Future<bool> load() {
    if (_isLoaded) return Future<bool>.value(true);
    return _loadInFlight ??= _loadOnce().whenComplete(() {
      _loadInFlight = null;
    });
  }

  Future<bool> _loadOnce() async {
    _definitions.clear();
    _contentByLocale.clear();
    _loadError = null;
    _catalogVersion = null;
    try {
      final catalogRaw = await rootBundle.loadString(
        'assets/catalog/catalog.json',
      );
      final catalogJson = jsonDecode(catalogRaw) as Map<String, dynamic>;
      final exerciseCount = (catalogJson['exerciseCount'] as num? ?? 0).toInt();
      final sources = List<dynamic>.from(
        catalogJson['sources'] ??
            (catalogJson['source'] == null
                ? const []
                : [catalogJson['source']]),
      );
      if (catalogJson['schemaVersion'] != 1 ||
          exerciseCount <= 0 ||
          sources.isEmpty) {
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
      if (_definitions.length != exerciseCount) {
        throw const FormatException('Catalog exercise count mismatch.');
      }
      final freeDefinitions =
          _definitions.keys.where((id) => id.startsWith('free:')).length;
      final freeSource =
          sources
              .map((value) => Map<String, dynamic>.from(value as Map))
              .where((value) => value['id'] == 'free-exercise-db')
              .firstOrNull;
      if (freeDefinitions > 0 &&
          (freeSource == null ||
              freeSource['license'] != 'Unlicense' ||
              freeSource['commit'] != _freeExerciseDbCommit ||
              freeSource['exerciseCount'] != 876 ||
              freeDefinitions != 876)) {
        throw const FormatException('Invalid Free Exercise DB source pin.');
      }
      await Future.wait(['de', 'en'].map(_loadLocale));
      for (final id in _definitions.keys) {
        final english = _contentByLocale['en']?[id];
        final german = _contentByLocale['de']?[id];
        if (!_isComplete(english) || english!.reviewed != true) {
          throw FormatException('Incomplete reviewed English content for $id.');
        }
        if (!_isComplete(german) ||
            (!german!.reviewed && german.fallbackLocale != 'en')) {
          throw FormatException('Invalid German content or fallback for $id.');
        }
      }
      await _validateManifest(
        catalogRaw: catalogRaw,
        catalogVersion: catalogJson['catalogVersion']?.toString(),
        exerciseCount: exerciseCount,
      );
      _isLoaded = true;
      _catalogVersion = catalogJson['catalogVersion']?.toString();
      return true;
    } catch (error) {
      _definitions.clear();
      _contentByLocale.clear();
      _loadError = error.toString();
      _catalogVersion = null;
      return false;
    }
  }

  static bool _isComplete(CatalogLocalizedContent? content) =>
      content != null &&
      content.name.trim().isNotEmpty &&
      content.description.trim().isNotEmpty &&
      content.instructions.isNotEmpty &&
      content.searchTerms.isNotEmpty;

  Future<void> _validateManifest({
    required String catalogRaw,
    required String? catalogVersion,
    required int exerciseCount,
  }) async {
    final raw = await rootBundle.loadString('assets/catalog/manifest.json');
    final manifest = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (manifest['schemaVersion'] != 1 ||
        manifest['catalogVersion']?.toString() != catalogVersion ||
        (manifest['exerciseCount'] != null &&
            manifest['exerciseCount'] != exerciseCount) ||
        (manifest['sourceCommit'] != null &&
            manifest['sourceCommit'] != _freeExerciseDbCommit)) {
      throw const FormatException('Invalid catalog release manifest.');
    }
    final checksums = Map<String, dynamic>.from(
      manifest['assetChecksums'] as Map? ?? const {},
    );
    if (checksums.isEmpty) {
      throw const FormatException('Catalog checksums are missing.');
    }
    final assets = <String, String>{
      'catalog.json': catalogRaw,
      'catalog_de.json': await rootBundle.loadString(
        'assets/catalog/catalog_de.json',
      ),
      'catalog_en.json': await rootBundle.loadString(
        'assets/catalog/catalog_en.json',
      ),
    };
    for (final asset in assets.entries) {
      final expected = checksums[asset.key]?.toString().toLowerCase();
      final actual = sha256.convert(utf8.encode(asset.value)).toString();
      if (expected == null || expected != actual) {
        throw FormatException('Catalog checksum mismatch: ${asset.key}.');
      }
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

  List<LocalizedCatalogExercise> search(
    String localeCode,
    String query, {
    String? goalCode,
    bool? activitiesOnly,
    Set<String>? availableEquipment,
  }) {
    final normalized = query.trim().toLowerCase();
    return _definitions.values
        .map((definition) => localized(definition.id, localeCode))
        .whereType<LocalizedCatalogExercise>()
        .where((exercise) {
          final isActivity = exercise.definition.id.startsWith('trainy:');
          if (activitiesOnly != null && isActivity != activitiesOnly) {
            return false;
          }
          if (goalCode != null &&
              !exercise.definition.goalCodes.contains(goalCode)) {
            return false;
          }
          if (availableEquipment != null && availableEquipment.isNotEmpty) {
            final needed = exercise.definition.equipmentIds;
            final bodyOnly =
                needed.isEmpty ||
                needed.every(
                  (code) =>
                      code == 'body only' ||
                      code == 'bodyweight' ||
                      code == 'none',
                );
            if (!bodyOnly &&
                !needed.any(
                  (code) => availableEquipment.contains(
                    DatabaseSchemaV2.normalizeEquipmentCode(code),
                  ),
                )) {
              return false;
            }
          }
          if (normalized.isEmpty) return true;
          final english = _contentByLocale['en']?[exercise.definition.id];
          final haystack =
              [
                exercise.content.name,
                exercise.content.description,
                ...exercise.content.instructions,
                ...exercise.content.searchTerms,
                if (english != null) english.name,
                ...exercise.definition.aliases,
                ...exercise.definition.primaryMuscleIds,
                ...exercise.definition.secondaryMuscleIds,
                ...exercise.definition.equipmentIds,
              ].join(' ').toLowerCase();
          return haystack.contains(normalized);
        })
        .toList();
  }
}
