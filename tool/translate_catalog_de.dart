import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _catalogPath = 'assets/catalog/catalog_en.json';
const _germanPath = 'assets/catalog/catalog_de.json';
const _manifestPath = 'assets/catalog/manifest.json';
const _cachePath = 'tool/.catalog_translation_cache.json';

Future<void> main() async {
  final authKey = Platform.environment['DEEPL_AUTH_KEY']?.trim();
  if (authKey == null || authKey.isEmpty) {
    stderr.writeln(
      'DEEPL_AUTH_KEY is missing. Set it only in the local environment; '
      'never add it to the repository.',
    );
    exitCode = 2;
    return;
  }
  final baseUrl =
      Platform.environment['DEEPL_API_URL']?.trim().replaceFirst(
        RegExp(r'/$'),
        '',
      ) ??
      'https://api-free.deepl.com';
  final client = _DeepLClient(baseUrl: baseUrl, authKey: authKey);
  final english = _readJson(_catalogPath);
  final existingGerman = _readJson(_germanPath);
  final cache =
      File(_cachePath).existsSync()
          ? Map<String, dynamic>.from(
            _readJson(_cachePath)['translations'] as Map,
          )
          : <String, dynamic>{};
  final records = Map<String, dynamic>.from(english['exercises'] as Map);
  final units = <_TranslationUnit>[];
  for (final entry in records.entries) {
    final content = Map<String, dynamic>.from(entry.value as Map);
    units.add(_TranslationUnit(content['name'] as String));
    final instructions = List<String>.from(content['instructions'] as List);
    for (var index = 0; index < instructions.length; index++) {
      units.add(_TranslationUnit(instructions[index]));
    }
  }
  final missing =
      units.where((unit) => !cache.containsKey(unit.textHash)).toList();
  final requiredCharacters = missing.fold<int>(
    0,
    (total, unit) => total + unit.text.runes.length,
  );
  final usage = await client.usage();
  final remaining = usage.limit - usage.used;
  stdout.writeln(
    'DeepL preflight: $requiredCharacters characters required, '
    '$remaining remaining (${missing.length} uncached text blocks).',
  );
  if (remaining < requiredCharacters) {
    throw StateError('DeepL quota is insufficient; no request was sent.');
  }

  final glossaryId = await client.createGlossary(
    File('tool/fitness_glossary_en_de.tsv').readAsStringSync(),
  );
  try {
    for (var offset = 0; offset < missing.length; offset += 40) {
      final batch = missing.skip(offset).take(40).toList();
      final translated = await client.translate(
        batch.map((unit) => unit.text).toList(),
        glossaryId: glossaryId,
      );
      if (translated.length != batch.length) {
        throw const FormatException('DeepL result count mismatch.');
      }
      for (var index = 0; index < batch.length; index++) {
        final value = translated[index].trim();
        if (value.isEmpty) throw const FormatException('Empty translation.');
        cache[batch[index].textHash] = value;
      }
      _writeAtomic(
        _cachePath,
        _encode({'schemaVersion': 1, 'translations': cache}),
      );
      stdout.writeln(
        'Translated ${offset + batch.length}/${missing.length} uncached blocks.',
      );
    }
  } finally {
    await client.deleteGlossary(glossaryId);
  }

  final germanRecords = <String, dynamic>{};
  for (final entry in records.entries) {
    final source = Map<String, dynamic>.from(entry.value as Map);
    final sourceInstructions = List<String>.from(
      source['instructions'] as List,
    );
    final translatedName = cache[_hash(source['name'] as String)] as String;
    final translatedInstructions = [
      for (final instruction in sourceInstructions)
        cache[_hash(instruction)] as String,
    ];
    _validateTranslation(
      id: entry.key,
      sourceName: source['name'] as String,
      translatedName: translatedName,
      instructions: translatedInstructions,
    );
    germanRecords[entry.key] = {
      'name': translatedName,
      'description': translatedInstructions.join(' '),
      'instructions': translatedInstructions,
      'searchTerms':
          {
            translatedName,
            source['name'] as String,
            ...List<String>.from(source['searchTerms'] as List? ?? const []),
          }.toList(),
      'reviewed': false,
      'translationMethod': 'deepl',
      'sourceHash': _hash(jsonEncode(source)),
    };
  }
  final german = <String, dynamic>{
    ...existingGerman,
    'schemaVersion': 1,
    'catalogVersion': english['catalogVersion'],
    'locale': 'de',
    'exerciseCount': germanRecords.length,
    'reviewedExerciseCount': 0,
    'machineTranslatedExerciseCount': germanRecords.length,
    'fallbackExerciseCount': 0,
    'exercises': Map.fromEntries(
      germanRecords.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
  final germanText = _encode(german);
  final manifest = _readJson(_manifestPath);
  final checksums = Map<String, dynamic>.from(
    manifest['assetChecksums'] as Map,
  );
  checksums['catalog_de.json'] =
      sha256.convert(utf8.encode(germanText)).toString();
  manifest['assetChecksums'] = checksums;
  manifest['germanReviewedExerciseCount'] = 0;
  manifest['germanFallbackExerciseCount'] = 0;
  manifest['germanMachineTranslatedExerciseCount'] = germanRecords.length;
  _writeAtomic(_germanPath, germanText);
  _writeAtomic(_manifestPath, _encode(manifest));
  stdout.writeln(
    'German catalog written atomically: ${germanRecords.length} records.',
  );
}

void _validateTranslation({
  required String id,
  required String sourceName,
  required String translatedName,
  required List<String> instructions,
}) {
  if (translatedName.trim().isEmpty ||
      instructions.any((value) => value.trim().isEmpty)) {
    throw FormatException('Structurally incomplete translation for $id.');
  }
  const allowedUnchanged = {
    'plank',
    'crunch',
    'burpee',
    'box jump',
    'muscle up',
    'push press',
  };
  if (sourceName.trim().toLowerCase() == translatedName.trim().toLowerCase() &&
      !allowedUnchanged.contains(sourceName.trim().toLowerCase())) {
    throw FormatException('Unchanged English exercise name for $id.');
  }
}

class _TranslationUnit {
  const _TranslationUnit(this.text);
  final String text;
  String get textHash => _hash(text);
}

class _Usage {
  const _Usage(this.used, this.limit);
  final int used;
  final int limit;
}

class _DeepLClient {
  const _DeepLClient({required this.baseUrl, required this.authKey});
  final String baseUrl;
  final String authKey;

  Future<_Usage> usage() async {
    final response = await _request('GET', '/v2/usage');
    return _Usage(
      (response['character_count'] as num).toInt(),
      (response['character_limit'] as num).toInt(),
    );
  }

  Future<String> createGlossary(String entries) async {
    final response = await _request(
      'POST',
      '/v2/glossaries',
      body: {
        'name': 'Trainy fitness terminology',
        'source_lang': 'EN',
        'target_lang': 'DE',
        'entries': entries,
        'entries_format': 'tsv',
      },
    );
    return response['glossary_id'] as String;
  }

  Future<void> deleteGlossary(String glossaryId) async {
    await _request('DELETE', '/v2/glossaries/$glossaryId', allowEmpty: true);
  }

  Future<List<String>> translate(
    List<String> texts, {
    required String glossaryId,
  }) async {
    final response = await _request(
      'POST',
      '/v2/translate',
      jsonBody: {
        'text': texts,
        'source_lang': 'EN',
        'target_lang': 'DE',
        'glossary_id': glossaryId,
        'preserve_formatting': true,
      },
    );
    return List<Map<String, dynamic>>.from(
      (response['translations'] as List).map(
        (value) => Map<String, dynamic>.from(value as Map),
      ),
    ).map((value) => value['text'] as String).toList();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? body,
    Map<String, dynamic>? jsonBody,
    bool allowEmpty = false,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.set('Authorization', 'DeepL-Auth-Key $authKey');
      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(jsonBody));
      } else if (body != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(Uri(queryParameters: body).query);
      }
      final response = await request.close();
      final raw = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('DeepL ${response.statusCode}: $raw');
      }
      if (allowEmpty && raw.trim().isEmpty) return const {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } finally {
      client.close(force: true);
    }
  }
}

Map<String, dynamic> _readJson(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
String _encode(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _writeAtomic(String path, String contents) {
  final target = File(path);
  final temporary = File('$path.tmp');
  temporary.writeAsStringSync(contents, flush: true);
  if (target.existsSync()) target.deleteSync();
  temporary.renameSync(target.path);
}
