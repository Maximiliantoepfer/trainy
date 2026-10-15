/// Builds Trainy's immutable, fully-offline exercise catalog.
///
/// This is a release gate: it only accepts the pinned Free Exercise DB source
/// and a complete, editorially reviewed German content file. Work happens in
/// a temporary sibling directory and replaces the catalog only after every
/// validation succeeds. The mobile app never executes this tool.
///
/// Prerequisites: `cwebp` on PATH and a complete `catalog_de.json`.
/// Usage:
///   dart run tool/import_free_exercise_db.dart C:\\src\\free-exercise-db \
///     tool/catalog_translations_de.json --replace
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogVersion = 1;
// Verified against the pinned source commit (2026-09-12).  The former plan
// stated 873, but the actual upstream JSON contains 876 records.
const _expectedExerciseCount = 876;
const _pinnedCommit = 'a859101d633a01c4a1a920d6a8ce41dabba0705f';
const _fallbackIds = <String>{
  'Kettlebell_Halo',
  'Kettlebell_Halo_With_Overhead_Extension',
  'Kettlebell_Overhead_Triceps_Extension',
};

Future<void> main(List<String> args) async {
  if (args.length < 2 || !args.contains('--replace')) {
    stderr.writeln('Usage: <source> <reviewed German JSON> --replace');
    exitCode = 64;
    return;
  }
  await _requireCwebp();
  final sourceRoot = Directory(args[0]);
  final translationFile = File(args[1]);
  final sourceFile = File(_join(sourceRoot.path, 'dist', 'exercises.json'));
  if (!await sourceFile.exists() || !await translationFile.exists()) {
    throw StateError(
      'Source exercises.json or German translation file is missing.',
    );
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
  final translations = _readTranslations(await translationFile.readAsString());
  final expectedIds = source.map((raw) => 'free:${(raw as Map)['id']}').toSet();
  _validateTranslations(translations, expectedIds);

  final target = Directory(_join('assets', 'catalog'));
  final temporary = Directory(
    '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
  );
  await temporary.create(recursive: true);
  try {
    final imageDirectory = Directory(_join(temporary.path, 'images'));
    await imageDirectory.create(recursive: true);
    await _encodeWebP(
      File(_join('tool', 'catalog_fallback.png')),
      File(_join(imageDirectory.path, '_fallback.webp')),
    );
    final overrides = await _readOverrides();
    final definitions = <Map<String, dynamic>>[];
    final english = <String, dynamic>{};
    final german = <String, dynamic>{};

    for (final raw in source) {
      final item = Map<String, dynamic>.from(raw as Map);
      final upstreamId = item['id'] as String;
      final catalogId = 'free:$upstreamId';
      final imagePaths = List<String>.from(item['images'] ?? const []);
      final imageFile = '${_safeFileName(upstreamId)}.webp';
      if (imagePaths.isEmpty) {
        if (!_fallbackIds.contains(upstreamId)) {
          throw StateError(
            'Unexpected source exercise without image: $upstreamId',
          );
        }
      } else {
        final input = File(
          _join(sourceRoot.path, 'exercises', imagePaths.first),
        );
        if (!await input.exists())
          throw StateError('Missing source image for $upstreamId');
        await _encodeWebP(input, File(_join(imageDirectory.path, imageFile)));
      }
      final name = item['name'] as String;
      final category = (item['category'] as String? ?? 'other').toLowerCase();
      final equipment =
          (item['equipment'] as String? ?? 'unknown').toLowerCase();
      final override = Map<String, dynamic>.from(
        overrides[upstreamId] ?? const {},
      );
      definitions.add({
        'id': catalogId,
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
        'goalCodes': List<String>.from(
          override['goalCodes'] ?? _goals(category, name),
        ),
        'tracking': _tracking(category, equipment, name),
        'imageAssetPath':
            imagePaths.isEmpty
                ? 'assets/catalog/images/_fallback.webp'
                : 'assets/catalog/images/$imageFile',
        'aliases': [name, upstreamId.replaceAll('_', ' ')],
      });
      final instructions = List<String>.from(item['instructions'] ?? const []);
      english[catalogId] = {
        'name': name,
        'description': instructions.join('\n'),
        'instructions': instructions,
        'searchTerms': [name, upstreamId.replaceAll('_', ' ')],
        'reviewed': true,
      };
      german[catalogId] = translations[catalogId];
    }
    definitions.sort(
      (a, b) => (a['id'] as String).compareTo(b['id'] as String),
    );
    await _writeJson(File(_join(temporary.path, 'catalog.json')), {
      'schemaVersion': 1,
      'catalogVersion': _catalogVersion,
      'source': {
        'name': 'Free Exercise DB',
        'repository': 'https://github.com/yuhonas/free-exercise-db',
        'commit': commit,
        'license': 'Unlicense',
        'exerciseCount': definitions.length,
        'sourceSha256': await _sha256(sourceFile),
      },
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
      'exercises': german,
    });
    await File(_join(temporary.path, 'NOTICE.md')).writeAsString('''
# Bundled exercise catalog

Source: Free Exercise DB, commit $commit
https://github.com/yuhonas/free-exercise-db

The upstream catalog is public domain under the Unlicense. Trainy ships local
metadata and optimized WebP covers. Three source records without imagery use
Trainy's bundled neutral fallback image.
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
  if (root['locale'] != 'de')
    throw StateError('Translation file locale must be de.');
  return Map<String, dynamic>.from(
    root['exercises'] as Map? ?? const {},
  ).map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
}

void _validateTranslations(
  Map<String, Map<String, dynamic>> values,
  Set<String> ids,
) {
  if (values.length != ids.length || !values.keys.toSet().containsAll(ids)) {
    throw StateError('German file must contain exactly every catalog ID.');
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

Future<void> _requireCwebp() async {
  try {
    final result = await Process.run('cwebp', const ['-version']);
    if (result.exitCode == 0) return;
  } on ProcessException {}
  throw StateError(
    'cwebp is required to produce WebP covers. Install libwebp and retry.',
  );
}

Future<String> _gitCommit(Directory source) async {
  final result = await Process.run('git', const [
    'rev-parse',
    'HEAD',
  ], workingDirectory: source.path);
  if (result.exitCode != 0)
    throw StateError('Cannot resolve upstream source commit.');
  return (result.stdout as String).trim();
}

Future<void> _encodeWebP(File input, File output) async {
  final result = await Process.run('cwebp', [
    '-quiet',
    '-q',
    '82',
    '-resize',
    '512',
    '0',
    input.path,
    '-o',
    output.path,
  ]);
  if (result.exitCode != 0 || !await output.exists()) {
    throw StateError('cwebp failed for ${input.path}: ${result.stderr}');
  }
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

Map<String, bool> _tracking(String category, String equipment, String name) {
  final lower = name.toLowerCase();
  if (category == 'cardio')
    return const {
      'sets': false,
      'reps': false,
      'weight': false,
      'duration': true,
      'distance': true,
    };
  if (lower.contains('stretch') || lower.contains('yoga'))
    return const {
      'sets': false,
      'reps': false,
      'weight': false,
      'duration': true,
      'distance': false,
    };
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
  if (category == 'cardio') return const ['cardio'];
  if (lower.contains('stretch') || lower.contains('yoga'))
    return const ['mobility'];
  if (lower.contains('plank') || lower.contains('jump rope'))
    return const ['endurance'];
  return const ['strength'];
}
