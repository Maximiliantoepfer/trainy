import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogDir = 'assets/catalog';
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

void main() {
  final essentials = _readJson('tool/catalog_essentials.json');
  final catalog = _readJson('$_catalogDir/catalog.json');
  final english = _readJson('$_catalogDir/catalog_en.json');
  final german = _readJson('$_catalogDir/catalog_de.json');

  final definitions = List<Map<String, dynamic>>.from(
    (catalog['exercises'] as List).map(
      (value) => Map<String, dynamic>.from(value as Map),
    ),
  );
  final byId = {for (final item in definitions) item['id'] as String: item};
  final enContent = Map<String, dynamic>.from(english['exercises'] as Map);
  final deContent = Map<String, dynamic>.from(german['exercises'] as Map);

  for (final raw in List<dynamic>.from(essentials['additions'] as List)) {
    final addition = Map<String, dynamic>.from(raw as Map);
    final id = addition['id'] as String;
    if (byId.containsKey(id)) continue;
    final definition = <String, dynamic>{
      'id': id,
      'activityTypeCode': addition['activityTypeCode'],
      'movementFamilyId': id.substring('trainy:'.length),
      'primaryMuscleIds': addition['primaryMuscleIds'],
      'secondaryMuscleIds': addition['secondaryMuscleIds'],
      'equipmentIds': addition['equipmentIds'],
      'goalCodes': addition['goalCodes'],
      'tracking': addition['tracking'],
      'imageAssetPath': '',
      'iconKey': addition['iconKey'],
      'aliases': <String>[],
    };
    definitions.add(definition);
    byId[id] = definition;
    enContent[id] = {
      ...Map<String, dynamic>.from(addition['en'] as Map),
      'reviewed': true,
      'translationMethod': 'manual',
      'sourceHash': _contentHash(addition['en'] as Map),
    };
    deContent[id] = {
      ...Map<String, dynamic>.from(addition['de'] as Map),
      'reviewed': true,
      'translationMethod': 'manual',
      'sourceHash': _contentHash(addition['en'] as Map),
    };
  }

  for (final raw in List<dynamic>.from(essentials['essentials'] as List)) {
    final essential = Map<String, dynamic>.from(raw as Map);
    final id = essential['id'] as String;
    final definition = byId[id];
    if (definition == null) {
      throw StateError('Essential catalog exercise is missing: $id');
    }
    definition['essentialRank'] = essential['rank'];
    definition['movementFamilyId'] = essential['movementFamilyId'];
    definition['aliases'] =
        {
          ...List<String>.from(definition['aliases'] as List? ?? const []),
          ...List<String>.from(essential['aliases'] as List? ?? const []),
        }.toList();
    final localized = Map<String, dynamic>.from(deContent[id] as Map);
    localized['name'] = essential['deName'];
    localized['searchTerms'] =
        {
          ...List<String>.from(localized['searchTerms'] as List? ?? const []),
          essential['deName'] as String,
          ...List<String>.from(essential['aliases'] as List? ?? const []),
        }.toList();
    deContent[id] = localized;
  }

  for (final definition in definitions) {
    final category = _coverCategory(definition);
    definition['mediaId'] = 'owned:category-$category';
    definition['imageAssetPath'] = 'assets/catalog/covers/$category.webp';
  }

  definitions.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  catalog['schemaVersion'] = 1;
  catalog['catalogVersion'] = 3;
  catalog['exerciseCount'] = definitions.length;
  catalog['exercises'] = definitions;
  final sources = List<Map<String, dynamic>>.from(
    (catalog['sources'] as List).map(
      (value) => Map<String, dynamic>.from(value as Map),
    ),
  );
  for (final source in sources) {
    if (source['id'] == 'trainy-core') {
      source['exerciseCount'] =
          definitions
              .where((item) => '${item['id']}'.startsWith('trainy:'))
              .length;
    }
  }
  catalog['sources'] = sources;

  for (final locale in [english, german]) {
    locale['schemaVersion'] = 1;
    locale['catalogVersion'] = 3;
    locale['exerciseCount'] = definitions.length;
  }
  english['exercises'] = _sortedMap(enContent);
  german['exercises'] = _sortedMap(deContent);
  german['reviewedExerciseCount'] =
      deContent.values.where((value) {
        final item = Map<String, dynamic>.from(value as Map);
        return item['reviewed'] == true && item['fallbackLocale'] != 'en';
      }).length;
  german['fallbackExerciseCount'] =
      deContent.values.where((value) {
        final item = Map<String, dynamic>.from(value as Map);
        return item['fallbackLocale'] == 'en';
      }).length;
  german['machineTranslatedExerciseCount'] =
      deContent.values.where((value) {
        final item = Map<String, dynamic>.from(value as Map);
        return item['translationMethod'] == 'deepl';
      }).length;

  final coverFiles = <String, File>{
    for (final category in _coverCategories)
      category: File('$_catalogDir/covers/$category.webp'),
  };
  for (final entry in coverFiles.entries) {
    if (!entry.value.existsSync()) {
      throw StateError('Missing owned cover ${entry.value.path}.');
    }
  }
  final media = <String, dynamic>{
    'schemaVersion': 1,
    'media': [
      for (final entry in coverFiles.entries)
        {
          'mediaId': 'owned:category-${entry.key}',
          'assetPath': 'assets/catalog/covers/${entry.key}.webp',
          'sha256': sha256.convert(entry.value.readAsBytesSync()).toString(),
          'author': 'Trainy project',
          'sourceUrl': null,
          'license': 'owned',
        },
    ],
  };

  final catalogText = _encode(catalog);
  final englishText = _encode(english);
  final germanText = _encode(german);
  final mediaText = _encode(media);
  final fallbackCount =
      deContent.values.where((value) {
        final item = Map<String, dynamic>.from(value as Map);
        return item['fallbackLocale'] == 'en';
      }).length;
  final manifest = <String, dynamic>{
    'schemaVersion': 1,
    'catalogVersion': 3,
    'sourceCommit': _pinnedCommit,
    'freeExerciseCount': 876,
    'totalCatalogCount': definitions.length,
    'exerciseCount': definitions.length,
    'germanReviewedExerciseCount':
        deContent.values.where((value) {
          final item = Map<String, dynamic>.from(value as Map);
          return item['reviewed'] == true && item['fallbackLocale'] != 'en';
        }).length,
    'germanFallbackExerciseCount': fallbackCount,
    'germanMachineTranslatedExerciseCount':
        deContent.values.where((value) {
          final item = Map<String, dynamic>.from(value as Map);
          return item['translationMethod'] == 'deepl';
        }).length,
    'mediaPolicy': 'owned-or-explicitly-licensed',
    'assetChecksums': {
      'catalog.json': sha256.convert(utf8.encode(catalogText)).toString(),
      'catalog_de.json': sha256.convert(utf8.encode(germanText)).toString(),
      'catalog_en.json': sha256.convert(utf8.encode(englishText)).toString(),
      'catalog_media.json': sha256.convert(utf8.encode(mediaText)).toString(),
      for (final entry in coverFiles.entries)
        'covers/${entry.key}.webp':
            sha256.convert(entry.value.readAsBytesSync()).toString(),
    },
  };

  _writeAtomic('$_catalogDir/catalog.json', catalogText);
  _writeAtomic('$_catalogDir/catalog_en.json', englishText);
  _writeAtomic('$_catalogDir/catalog_de.json', germanText);
  _writeAtomic('$_catalogDir/catalog_media.json', mediaText);
  _writeAtomic('$_catalogDir/manifest.json', _encode(manifest));
  stdout.writeln(
    'Prepared catalog v2: ${definitions.length} exercises, '
    '${coverFiles.length} owned covers, $fallbackCount German fallbacks.',
  );
}

Map<String, dynamic> _readJson(String filePath) => Map<String, dynamic>.from(
  jsonDecode(File(filePath).readAsStringSync()) as Map,
);

Map<String, dynamic> _sortedMap(Map<String, dynamic> input) => Map.fromEntries(
  input.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
);

String _encode(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

String _contentHash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

String _coverCategory(Map<String, dynamic> definition) {
  final goals = List<String>.from(definition['goalCodes'] as List? ?? const []);
  final key =
      '${definition['id']} ${definition['movementFamilyId']}'.toLowerCase();
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

void _writeAtomic(String filePath, String contents) {
  final target = File(filePath);
  final temporary = File('$filePath.tmp');
  temporary.writeAsStringSync(contents, flush: true);
  if (target.existsSync()) target.deleteSync();
  temporary.renameSync(target.path);
}
