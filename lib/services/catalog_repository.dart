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
  final Map<String, Map<String, _SearchDocument>> _searchIndex = {};
  final Map<String, CatalogMedia> _media = {};
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
  Iterable<CatalogMedia> get media => _media.values;
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
    _searchIndex.clear();
    _media.clear();
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
            (!german!.reviewed &&
                german.fallbackLocale != 'en' &&
                german.translation?.method != 'deepl')) {
          throw FormatException('Invalid German content or fallback for $id.');
        }
      }
      await _loadMedia();
      _buildSearchIndex();
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
      _searchIndex.clear();
      _media.clear();
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
      'catalog_media.json': await rootBundle.loadString(
        'assets/catalog/catalog_media.json',
      ),
    };
    for (final asset in assets.entries) {
      final expected = checksums[asset.key]?.toString().toLowerCase();
      final actual = sha256.convert(utf8.encode(asset.value)).toString();
      if (expected == null || expected != actual) {
        throw FormatException('Catalog checksum mismatch: ${asset.key}.');
      }
    }
    for (final media in _media.values) {
      final bytes = await rootBundle.load(media.assetPath);
      final actual = sha256.convert(bytes.buffer.asUint8List()).toString();
      final relative = media.assetPath.replaceFirst('assets/catalog/', '');
      final expected = checksums[relative]?.toString().toLowerCase();
      if (actual != media.sha256.toLowerCase() || expected != actual) {
        throw FormatException('Catalog media checksum mismatch: ${media.id}.');
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

  Future<void> _loadMedia() async {
    final decoded = Map<String, dynamic>.from(
      jsonDecode(
            await rootBundle.loadString('assets/catalog/catalog_media.json'),
          )
          as Map,
    );
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Invalid catalog media index.');
    }
    for (final raw in List<dynamic>.from(decoded['media'] ?? const [])) {
      final item = CatalogMedia.fromJson(Map<String, dynamic>.from(raw as Map));
      if (_media.putIfAbsent(item.id, () => item) != item) {
        throw FormatException('Duplicate catalog media ID ${item.id}.');
      }
      if (item.license == CatalogMediaLicense.ccBy &&
          ((item.author?.trim().isEmpty ?? true) ||
              (item.sourceUrl?.trim().isEmpty ?? true))) {
        throw FormatException('Incomplete CC-BY attribution for ${item.id}.');
      }
    }
    for (final definition in _definitions.values) {
      if (definition.mediaId == null ||
          !_media.containsKey(definition.mediaId)) {
        throw FormatException('Missing media for ${definition.id}.');
      }
    }
  }

  void _buildSearchIndex() {
    for (final locale in const ['de', 'en']) {
      final documents = <String, _SearchDocument>{};
      for (final definition in _definitions.values) {
        final local = _contentByLocale[locale]![definition.id]!;
        final english = _contentByLocale['en']![definition.id]!;
        documents[definition.id] = _SearchDocument.fromFields(
          names: [local.name, english.name],
          aliases: [
            ...definition.aliases,
            ...local.searchTerms,
            ...english.searchTerms,
          ],
          searchableText: [
            local.description,
            ...local.instructions,
            ...definition.primaryMuscleIds,
            ...definition.secondaryMuscleIds,
            ...definition.equipmentIds,
          ],
        );
      }
      _searchIndex[locale] = documents;
    }
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

  List<LocalizedCatalogExercise> search(String localeCode, CatalogQuery query) {
    if (query.source == ExerciseSourceFilter.custom) return const [];
    final locale = _contentByLocale.containsKey(localeCode) ? localeCode : 'en';
    final normalized = normalizeSearchText(query.text);
    final ranked =
        _definitions.values
            .map((definition) => localized(definition.id, localeCode))
            .whereType<LocalizedCatalogExercise>()
            .where((exercise) {
              if (query.goalCode != null &&
                  !exercise.definition.goalCodes.contains(query.goalCode)) {
                return false;
              }
              if (query.availableEquipment != null &&
                  !_matchesEquipment(
                    exercise.definition.equipmentIds,
                    query.availableEquipment!,
                  )) {
                return false;
              }
              if (normalized.isEmpty) return true;
              return _searchIndex[locale]![exercise.definition.id]!.score(
                    normalized,
                  ) <
                  _SearchDocument.noMatch;
            })
            .toList();
    ranked.sort((left, right) {
      if (normalized.isNotEmpty) {
        final leftScore = _searchIndex[locale]![left.definition.id]!.score(
          normalized,
        );
        final rightScore = _searchIndex[locale]![right.definition.id]!.score(
          normalized,
        );
        final byScore = leftScore.compareTo(rightScore);
        if (byScore != 0) return byScore;
      }
      final leftRank = left.definition.essentialRank ?? 1 << 20;
      final rightRank = right.definition.essentialRank ?? 1 << 20;
      final byEssential = leftRank.compareTo(rightRank);
      if (byEssential != 0) return byEssential;
      return left.content.name.toLowerCase().compareTo(
        right.content.name.toLowerCase(),
      );
    });
    return ranked;
  }

  static String normalizeSearchText(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = {
      'ä': 'a',
      'ae': 'a',
      'ö': 'o',
      'oe': 'o',
      'ü': 'u',
      'ue': 'u',
      'ß': 'ss',
    };
    for (final replacement in replacements.entries) {
      normalized = normalized.replaceAll(replacement.key, replacement.value);
    }
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _matchesEquipment(
    List<String> equipmentIds,
    Set<String> availableEquipment,
  ) {
    final required =
        equipmentIds
            .map(DatabaseSchemaV2.normalizeEquipmentCode)
            .where(
              (code) =>
                  code != 'bodyweight' && code != 'other' && code != 'unknown',
            )
            .toSet();
    if (required.isEmpty) return true;
    return availableEquipment.containsAll(required);
  }
}

class _SearchDocument {
  const _SearchDocument({
    required this.names,
    required this.aliases,
    required this.allText,
  });

  static const noMatch = 1 << 20;
  final Set<String> names;
  final Set<String> aliases;
  final String allText;

  factory _SearchDocument.fromFields({
    required Iterable<String> names,
    required Iterable<String> aliases,
    required Iterable<String> searchableText,
  }) {
    Set<String> normalizeAll(Iterable<String> values) =>
        values
            .map(CatalogRepository.normalizeSearchText)
            .where((value) => value.isNotEmpty)
            .expand((value) => _variants(value))
            .toSet();
    final normalizedNames = normalizeAll(names);
    final normalizedAliases = normalizeAll(aliases);
    final text = normalizeAll(searchableText).join(' ');
    return _SearchDocument(
      names: normalizedNames,
      aliases: normalizedAliases,
      allText:
          '${normalizedNames.join(' ')} ${normalizedAliases.join(' ')} $text',
    );
  }

  int score(String query) {
    final variants = _variants(query);
    if (variants.any(names.contains)) return 0;
    if (variants.any(aliases.contains)) return 2;
    if (variants.any((value) => names.any((name) => name.startsWith(value)))) {
      return 10;
    }
    if (variants.any(
      (value) => aliases.any((name) => name.startsWith(value)),
    )) {
      return 20;
    }
    if (variants.any(allText.contains)) return 50;
    return noMatch;
  }

  static Set<String> _variants(String value) {
    final compact = value.replaceAll(' ', '');
    final variants = <String>{value, compact};
    if (compact.endsWith('s') && compact.length > 3) {
      variants.add(compact.substring(0, compact.length - 1));
    } else if (compact.length > 3) {
      variants.add('${compact}s');
    }
    return variants;
  }
}
