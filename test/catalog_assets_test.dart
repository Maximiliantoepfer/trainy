import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/services/catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog has complete reviewed core activities', () async {
    final repository = CatalogRepository.instance;
    expect(await repository.load(), isTrue, reason: repository.loadError);

    const coreIds = {
      'trainy:running',
      'trainy:walking',
      'trainy:cycling',
      'trainy:swimming',
      'trainy:interval_running',
      'trainy:mobility_session',
    };
    final ids = repository.definitions.map((item) => item.id).toSet();
    expect(ids, containsAll(coreIds));
    for (final id in coreIds) {
      final definition = repository.byId(id)!;
      expect(definition.goalCodes, isNotEmpty);
      expect(definition.goalCodes.length, lessThanOrEqualTo(2));
      expect(
        definition.goalCodes.any(
          const {'strength', 'cardio', 'mobility'}.contains,
        ),
        isTrue,
      );
      for (final locale in const ['de', 'en']) {
        final content = repository.content(id, locale)!;
        expect(content.reviewed, isTrue);
        expect(content.name.trim(), isNotEmpty);
        expect(content.instructions, isNotEmpty);
        expect(content.searchTerms, isNotEmpty);
      }
      expect(await rootBundle.load(definition.imageAssetPath), isA<ByteData>());
    }
  });
}
