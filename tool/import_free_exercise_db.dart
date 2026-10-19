/// Builds Trainy's immutable, fully-offline exercise catalog.
///
/// This is a release gate: it only accepts the pinned Free Exercise DB source
/// and optional, editorially reviewed German content. Missing German fields
/// visibly fall back to the English source and are never marked reviewed.
/// Work happens in
/// a temporary sibling directory and replaces the catalog only after every
/// validation succeeds. The mobile app never executes this tool.
///
/// Usage:
///   dart run tool/import_free_exercise_db.dart C:\\src\\free-exercise-db \
///     tool/catalog_translations_de.json --replace
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogVersion = 3;
// Verified against the pinned source commit (2026-09-12).  The former plan
// stated 873, but the actual upstream JSON contains 876 records.
const _expectedExerciseCount = 876;
const _pinnedCommit = 'a859101d633a01c4a1a920d6a8ce41dabba0705f';
const _coverCategories = [
  'strength',
  'push',
  'pull',
  'squat',
  'hinge',
  'core',
  'cardio',
  'cycling',
  'swimming',
  'rowing',
  'mobility',
];

Future<void> main(List<String> args) async {
  if (args.isEmpty || !args.contains('--replace')) {
    stderr.writeln('Usage: <source> [reviewed German JSON] --replace');
    exitCode = 64;
    return;
  }
  final sourceRoot = Directory(args[0]);
  final translationPath = args.where((value) => value != '--replace').skip(1);
  final translationFile =
      translationPath.isEmpty ? null : File(translationPath.first);
  final sourceFile = File(_join(sourceRoot.path, 'dist', 'exercises.json'));
  if (!await sourceFile.exists()) {
    throw StateError('Source exercises.json is missing.');
  }
  final commit = await _gitCommit(sourceRoot);
  if (commit != _pinnedCommit) {
    throw StateError('Expected pinned commit $_pinnedCommit, got $commit.');
  }
  final source = List<dynamic>.from(
    jsonDecode(await sourceFile.readAsString()) as List,
  );
  if (source.length != _expectedExerciseCount) {
    throw StateError(
      'Expected $_expectedExerciseCount exercises, got ${source.length}.',
    );
  }
  final translations =
      translationFile != null && await translationFile.exists()
          ? _readTranslations(await translationFile.readAsString())
          : <String, Map<String, dynamic>>{};
  final expectedIds = source.map((raw) => 'free:${(raw as Map)['id']}').toSet();
  _validateTranslations(translations, expectedIds);

  final target = Directory(_join('assets', 'catalog'));
  final temporary = Directory(
    '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
  );
  await temporary.create(recursive: true);
  try {
    final coverDirectory = Directory(_join(temporary.path, 'covers'));
    await coverDirectory.create(recursive: true);
    for (final category in _coverCategories) {
      final sourceCover = File(_join(target.path, 'covers', '$category.webp'));
      if (!await sourceCover.exists()) {
        throw StateError('Missing Trainy-owned category cover: $category');
      }
      await sourceCover.copy(_join(coverDirectory.path, '$category.webp'));
    }
    final overrides = await _readOverrides();
    final definitions = <Map<String, dynamic>>[];
    final english = <String, dynamic>{};
    final german = <String, dynamic>{};
    var reviewedGermanCount = 0;
    var germanFallbackCount = 0;

    // Trainy core activities are curated in-repository and are retained when
    // the pinned Free Exercise DB release replaces the generated catalog.
    if (await target.exists()) {
      final existingCatalog = File(_join(target.path, 'catalog.json'));
      final existingEnglish = File(_join(target.path, 'catalog_en.json'));
      final existingGerman = File(_join(target.path, 'catalog_de.json'));
      if (await existingCatalog.exists() &&
          await existingEnglish.exists() &&
          await existingGerman.exists()) {
        final catalogRoot = Map<String, dynamic>.from(
          jsonDecode(await existingCatalog.readAsString()) as Map,
        );
        for (final raw in List<dynamic>.from(
          catalogRoot['exercises'] ?? const [],
        )) {
          final item = Map<String, dynamic>.from(raw as Map);
          if ((item['id'] as String).startsWith('trainy:') &&
              item['id'] != 'trainy:mobility_session') {
            definitions.add(item);
          }
        }
        final englishRoot = Map<String, dynamic>.from(
          jsonDecode(await existingEnglish.readAsString()) as Map,
        );
        final germanRoot = Map<String, dynamic>.from(
          jsonDecode(await existingGerman.readAsString()) as Map,
        );
        english.addAll(
          Map<String, dynamic>.from(englishRoot['exercises'] as Map),
        );
        german.addAll(
          Map<String, dynamic>.from(germanRoot['exercises'] as Map),
        );
        english.removeWhere((id, _) => !id.startsWith('trainy:'));
        german.removeWhere(
          (id, _) =>
              !id.startsWith('trainy:') || id == 'trainy:mobility_session',
        );
      }
    }

    for (final raw in source) {
      final item = Map<String, dynamic>.from(raw as Map);
      final upstreamId = item['id'] as String;
      final catalogId = 'free:$upstreamId';
      final name = item['name'] as String;
      final category = (item['category'] as String? ?? 'other').toLowerCase();
      final equipment =
          (item['equipment'] as String? ?? 'unknown').toLowerCase();
      final override = Map<String, dynamic>.from(
        overrides[upstreamId] ?? const {},
      );
      final goals = List<String>.from(
        override['goalCodes'] ?? _goals(category, name),
      );
      final coverCategory = _coverCategory(
        id: catalogId,
        movementFamilyId:
            override['movementFamilyId'] ??
            'free:${_safeFileName(upstreamId).toLowerCase()}',
        goals: goals,
      );
      definitions.add({
        'id': catalogId,
        'activityTypeCode': _activityType(category, name),
        'movementFamilyId':
            override['movementFamilyId'] ??
            'free:${_safeFileName(upstreamId).toLowerCase()}',
        'primaryMuscleIds': List<String>.from(
          item['primaryMuscles'] ?? const [],
        ),
        'secondaryMuscleIds': List<String>.from(
          item['secondaryMuscles'] ?? const [],
        ),
        'equipmentIds': [equipment],
        'goalCodes': goals,
        'tracking': _tracking(category, equipment, name),
        'imageAssetPath': 'assets/catalog/covers/$coverCategory.webp',
        'mediaId': 'owned:category-$coverCategory',
        'iconKey': _iconKey(category, name),
        'aliases': [name, upstreamId.replaceAll('_', ' ')],
      });
      final sourceInstructions = List<String>.from(
        item['instructions'] ?? const [],
      );
      final instructions =
          sourceInstructions.isNotEmpty
              ? sourceInstructions
              : List<String>.from(override['englishInstructions'] ?? const []);
      if (name.trim().isEmpty || instructions.isEmpty) {
        throw StateError('English catalog record $catalogId is incomplete.');
      }
      english[catalogId] = {
        'name': name,
        'description': instructions.join('\n'),
        'instructions': instructions,
        'searchTerms': [name, upstreamId.replaceAll('_', ' ')],
        'reviewed': true,
      };
      final reviewedGerman = translations[catalogId];
      if (reviewedGerman != null) {
        german[catalogId] = reviewedGerman;
        reviewedGermanCount++;
      } else {
        german[catalogId] = {
          ...Map<String, dynamic>.from(english[catalogId] as Map),
          'reviewed': false,
          'fallbackLocale': 'en',
        };
        germanFallbackCount++;
      }
    }
    definitions.sort(
      (a, b) => (a['id'] as String).compareTo(b['id'] as String),
    );
    await _writeJson(File(_join(temporary.path, 'catalog.json')), {
      'schemaVersion': 1,
      'catalogVersion': _catalogVersion,
      'exerciseCount': definitions.length,
      'releaseStatus': 'complete',
      'sources': [
        {
          'id': 'free-exercise-db',
          'name': 'Free Exercise DB',
          'repository': 'https://github.com/yuhonas/free-exercise-db',
          'commit': commit,
          'license': 'Unlicense',
          'exerciseCount': _expectedExerciseCount,
          'sourceSha256': await _sha256(sourceFile),
        },
        {
          'id': 'trainy-core',
          'license': 'Trainy project content',
          'exerciseCount': definitions.length - _expectedExerciseCount,
        },
      ],
      'exercises': definitions,
    });
    await _writeJson(File(_join(temporary.path, 'catalog_en.json')), {
      'schemaVersion': 1,
      'catalogVersion': _catalogVersion,
      'locale': 'en',
      'exercises': english,
    });
    await _writeJson(File(_join(temporary.path, 'catalog_de.json')), {
      'schemaVersion': 1,
      'catalogVersion': _catalogVersion,
      'locale': 'de',
      'reviewedExerciseCount': reviewedGermanCount,
      'fallbackExerciseCount': germanFallbackCount,
      'exercises': german,
    });
    await _writeJson(File(_join(temporary.path, 'catalog_media.json')), {
      'schemaVersion': 1,
      'media': [
        for (final category in _coverCategories)
          {
            'mediaId': 'owned:category-$category',
            'assetPath': 'assets/catalog/covers/$category.webp',
            'sha256': await _sha256(
              File(_join(coverDirectory.path, '$category.webp')),
            ),
            'author': 'Trainy project',
            'sourceUrl': null,
            'license': 'owned',
          },
      ],
    });
    await File(_join(temporary.path, 'NOTICE.md')).writeAsString('''
# Bundled exercise catalog

Source: Free Exercise DB, commit $commit
https://github.com/yuhonas/free-exercise-db

The upstream text catalog is public domain under the Unlicense. Upstream photos
are intentionally not shipped because their individual provenance is unclear.
Trainy uses project-owned, local category covers declared in catalog_media.json.
''');
    final checksums = <String, String>{};
    await for (final entity in temporary.list(recursive: true)) {
      if (entity is File) {
        final relative = entity.path
            .substring(temporary.path.length + 1)
            .replaceAll('\\', '/');
        checksums[relative] = await _sha256(entity);
      }
    }
    await _writeJson(File(_join(temporary.path, 'manifest.json')), {
      'schemaVersion': 1,
      'catalogVersion': _catalogVersion,
      'sourceCommit': commit,
      'freeExerciseCount': _expectedExerciseCount,
      'totalCatalogCount': definitions.length,
      'germanReviewedExerciseCount': reviewedGermanCount,
      'germanFallbackExerciseCount': germanFallbackCount,
      'assetChecksums': checksums,
    });
    await _replaceDirectory(temporary, target);
  } catch (_) {
    if (await temporary.exists()) await temporary.delete(recursive: true);
    rethrow;
  }
}

Map<String, Map<String, dynamic>> _readTranslations(String raw) {
  final root = Map<String, dynamic>.from(jsonDecode(raw) as Map);
  if (root['locale'] != 'de') {
    throw StateError('Translation file locale must be de.');
  }
  return Map<String, dynamic>.from(
    root['exercises'] as Map? ?? const {},
  ).map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
}

void _validateTranslations(
  Map<String, Map<String, dynamic>> values,
  Set<String> ids,
) {
  final unknown = values.keys.toSet().difference(ids);
  if (unknown.isNotEmpty) {
    throw StateError('German file contains unknown catalog IDs: $unknown');
  }
  for (final entry in values.entries) {
    final content = entry.value;
    if (content['reviewed'] != true ||
        (content['name'] as String? ?? '').trim().isEmpty ||
        (content['description'] as String? ?? '').trim().isEmpty ||
        List<String>.from(content['instructions'] ?? const []).isEmpty ||
        List<String>.from(content['searchTerms'] ?? const []).isEmpty) {
      throw StateError(
        'German catalog record ${entry.key} is incomplete or unreviewed.',
      );
    }
  }
}

Future<Map<String, dynamic>> _readOverrides() async {
  final file = File(_join('tool', 'catalog_overrides.json'));
  return await file.exists()
      ? Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map)
      : const {};
}

Future<String> _gitCommit(Directory source) async {
  final result = await Process.run('git', const [
    'rev-parse',
    'HEAD',
  ], workingDirectory: source.path);
  if (result.exitCode != 0) {
    throw StateError('Cannot resolve upstream source commit.');
  }
  return (result.stdout as String).trim();
}

Future<void> _replaceDirectory(Directory temporary, Directory target) async {
  final backup = Directory(
    '${target.path}.previous-${DateTime.now().microsecondsSinceEpoch}',
  );
  if (await target.exists()) await target.rename(backup.path);
  try {
    await temporary.rename(target.path);
    if (await backup.exists()) await backup.delete(recursive: true);
  } catch (_) {
    if (await target.exists()) await target.delete(recursive: true);
    if (await backup.exists()) await backup.rename(target.path);
    rethrow;
  }
}

Future<void> _writeJson(File file, Object data) =>
    file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

Future<String> _sha256(File file) async =>
    sha256.convert(await file.readAsBytes()).toString();

String _join(String first, [String? second, String? third]) => [
  first,
  if (second != null) second,
  if (third != null) third,
].join(Platform.pathSeparator);

String _safeFileName(String id) =>
    id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_').replaceAll(RegExp('_+'), '_');

String _coverCategory({
  required String id,
  required String movementFamilyId,
  required List<String> goals,
}) {
  final key = '$id $movementFamilyId'.toLowerCase();
  if (goals.contains('mobility')) return 'mobility';
  if (goals.contains('cardio') ||
      (goals.contains('endurance') && !goals.contains('strength'))) {
    if (key.contains('cycl') || key.contains('bicycl')) return 'cycling';
    if (key.contains('swim')) return 'swimming';
    if (key.contains('row')) return 'rowing';
    return 'cardio';
  }
  if (RegExp(r'push|press|dip|chest|fly').hasMatch(key)) return 'push';
  if (RegExp(r'pull|row|chin|curl|pulldown').hasMatch(key)) return 'pull';
  if (RegExp(r'deadlift|hinge|good_morning|hip_thrust|swing').hasMatch(key)) {
    return 'hinge';
  }
  if (RegExp(
    r'ab_|abdominal|crunch|sit-up|sit_up|plank|core|twist',
  ).hasMatch(key)) {
    return 'core';
  }
  if (RegExp(r'squat|lunge|leg_|calf|quadricep|hamstring').hasMatch(key)) {
    return 'squat';
  }
  return 'strength';
}

Map<String, bool> _tracking(String category, String equipment, String name) {
  final lower = name.toLowerCase();
  if (category == 'cardio') {
    return const {
      'sets': false,
      'reps': false,
      'weight': false,
      'duration': true,
      'distance': true,
    };
  }
  if (lower.contains('stretch') || lower.contains('yoga')) {
    return const {
      'sets': false,
      'reps': false,
      'weight': false,
      'duration': true,
      'distance': false,
    };
  }
  return {
    'sets': true,
    'reps': true,
    'weight': equipment != 'body only',
    'duration': false,
    'distance': false,
  };
}

List<String> _goals(String category, String name) {
  final lower = name.toLowerCase();
  if (category == 'cardio') return const ['cardio', 'endurance'];
  if (category == 'plyometrics') return const ['strength', 'cardio'];
  if (category == 'stretching' ||
      lower.contains('stretch') ||
      lower.contains('yoga')) {
    return const ['mobility'];
  }
  if (lower.contains('jump rope')) return const ['cardio', 'endurance'];
  if (lower.contains('plank')) return const ['strength', 'endurance'];
  return const ['strength'];
}

String _activityType(String category, String name) {
  final lower = name.toLowerCase();
  if (category == 'cardio' || lower.contains('jump rope')) return 'cardio';
  if (category == 'stretching' ||
      lower.contains('stretch') ||
      lower.contains('yoga')) {
    return 'mobility';
  }
  return 'strength';
}

String _iconKey(String category, String name) {
  return switch (_activityType(category, name)) {
    'cardio' => 'heart',
    'mobility' => 'mobility',
    _ => 'muscle_arm',
  };
}
