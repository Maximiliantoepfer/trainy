import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/services/catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled catalog is pinned, complete, local and fallback-aware',
    () async {
      final repository = CatalogRepository.instance;
      expect(await repository.load(), isTrue, reason: repository.loadError);

      const activityIds = {
        'trainy:running',
        'trainy:walking',
        'trainy:cycling',
        'trainy:swimming',
        'trainy:interval_running',
        'trainy:hip_90_90',
        'trainy:thoracic_rotation',
      };
      final definitions = repository.definitions.toList();
      final ids = definitions.map((item) => item.id).toSet();
      expect(definitions, hasLength(883));
      expect(ids.where((id) => id.startsWith('free:')), hasLength(876));
      expect(ids.where((id) => id.startsWith('trainy:')).toSet(), activityIds);
      expect(ids, isNot(contains('trainy:mobility_session')));
      expect(
        repository.byId('free:90_90_Hamstring')!.goalCodes,
        contains('mobility'),
      );

      for (final definition in definitions) {
        expect(definition.goalCodes, isNotEmpty);
        expect(definition.goalCodes.length, lessThanOrEqualTo(2));
        expect(
          definition.goalCodes.any(
            const {'strength', 'cardio', 'mobility'}.contains,
          ),
          isTrue,
        );
        final english = repository.content(definition.id, 'en')!;
        final german = repository.content(definition.id, 'de')!;
        expect(english.reviewed, isTrue);
        expect(english.name.trim(), isNotEmpty);
        expect(english.instructions, isNotEmpty);
        expect(english.searchTerms, isNotEmpty);
        expect(german.name.trim(), isNotEmpty);
        expect(german.instructions, isNotEmpty);
        expect(
          german.reviewed || german.fallbackLocale == 'en',
          isTrue,
          reason: definition.id,
        );
        expect(File(definition.imageAssetPath).existsSync(), isTrue);
        expect(definition.imageAssetPath, startsWith('assets/catalog/covers/'));
        expect(definition.mediaId, isNotNull);
      }

      final media = Map<String, dynamic>.from(
        jsonDecode(File('assets/catalog/catalog_media.json').readAsStringSync())
            as Map,
      );
      final mediaItems = List<Map<String, dynamic>>.from(
        (media['media'] as List).map(
          (value) => Map<String, dynamic>.from(value as Map),
        ),
      );
      expect(mediaItems, hasLength(11));
      expect(mediaItems.map((value) => value['license']).toSet(), {'owned'});

      final manifest = Map<String, dynamic>.from(
        jsonDecode(File('assets/catalog/manifest.json').readAsStringSync())
            as Map,
      );
      expect(
        manifest['sourceCommit'],
        'a859101d633a01c4a1a920d6a8ce41dabba0705f',
      );
      expect(manifest['freeExerciseCount'], 876);
      expect(manifest['totalCatalogCount'], 883);
      expect(manifest['germanReviewedExerciseCount'], 7);
      expect(manifest['germanFallbackExerciseCount'], 876);
      final checksums = Map<String, dynamic>.from(
        manifest['assetChecksums'] as Map,
      );
      expect(checksums, hasLength(15));
      for (final entry in checksums.entries) {
        final file = File('assets/catalog/${entry.key}');
        expect(file.existsSync(), isTrue, reason: entry.key);
        expect(
          sha256.convert(file.readAsBytesSync()).toString(),
          entry.value,
          reason: entry.key,
        );
      }
    },
  );
}
