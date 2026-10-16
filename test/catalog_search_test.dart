import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/models/catalog_exercise.dart';
import 'package:trainy/services/catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository repository;

  setUpAll(() async {
    repository = CatalogRepository.instance;
    expect(await repository.load(), isTrue, reason: repository.loadError);
  });

  for (final query in const [
    'Push-Up',
    'push up',
    'pushup',
    'Pushups',
    'Liegestütz',
  ]) {
    test('$query ranks the classic push-up first', () {
      final results = repository.search('de', CatalogQuery(text: query));
      expect(results, isNotEmpty);
      expect(results.first.definition.id, 'free:Pushups');
    });
  }

  for (final query in const ['Pull-Up', 'pull up', 'Klimmzug']) {
    test('$query ranks the classic pull-up first', () {
      final results = repository.search('de', CatalogQuery(text: query));
      expect(results, isNotEmpty);
      expect(results.first.definition.id, 'free:Pullups');
    });
  }

  test('label, source and profile equipment are independent filters', () {
    final noEquipment = repository.search(
      'de',
      const CatalogQuery(
        goalCode: 'strength',
        profileId: 'home',
        availableEquipment: {},
        source: ExerciseSourceFilter.standard,
      ),
    );
    expect(noEquipment, isNotEmpty);
    expect(
      noEquipment.every(
        (item) => item.definition.goalCodes.contains('strength'),
      ),
      isTrue,
    );
    expect(
      noEquipment.any((item) => item.definition.id == 'free:Pushups'),
      isTrue,
    );
    expect(
      noEquipment.any((item) => item.definition.id == 'free:Barbell_Deadlift'),
      isFalse,
    );
    expect(
      repository.search(
        'de',
        const CatalogQuery(source: ExerciseSourceFilter.custom),
      ),
      isEmpty,
    );
  });
}
