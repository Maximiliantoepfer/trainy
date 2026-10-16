import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:trainy/models/training_profile.dart';
import 'package:trainy/repositories/training_profile_repository.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';

void main() {
  late Database database;
  late TrainingProfileRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchemaV2.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
      ),
    );
    repository = TrainingProfileRepository(
      database: DatabaseService(database: database),
    );
  });

  tearDown(() => database.close());

  test('creates, selects, edits and archives a normalized profile', () async {
    final now = DateTime.utc(2026, 10, 16);
    const id = '00000000-0000-4000-8000-000000000001';
    await repository.save(
      TrainingProfileRecord(
        id: id,
        name: 'Homegym',
        equipmentCodes: const {'bodyweight', 'dumbbell', 'bench'},
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    await repository.select(id);

    var profile = (await repository.profiles()).single;
    expect(profile.equipmentCodes, {'bodyweight', 'dumbbell', 'bench'});
    expect(await repository.selectedProfileId(), id);

    await repository.save(
      profile.copyWith(
        name: 'Studio',
        equipmentCodes: const {'machine', 'cable'},
        updatedAtUtc: now.add(const Duration(hours: 1)),
      ),
    );
    profile = (await repository.profiles()).single;
    expect(profile.name, 'Studio');
    expect(profile.equipmentCodes, {'machine', 'cable'});

    await repository.archive(id);
    expect(await repository.profiles(), isEmpty);
    expect(await repository.selectedProfileId(), isNull);
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('legacy profile migration is idempotent and keeps stable IDs', () async {
    await database.insert('training_profiles', {
      'id': 42,
      'name': 'My old profile',
      'equipmentCodesJson': '["bodyweight","dumbbells"]',
      'isArchived': 0,
      'sort': 0,
    });
    expect(await repository.migrateLegacyProfiles(), 1);
    expect(await repository.migrateLegacyProfiles(), 0);

    final profile = (await repository.profiles()).single;
    expect(profile.id, 'legacy-profile:42');
    expect(profile.equipmentCodes, {'bodyweight', 'dumbbell'});
    expect(await repository.selectedProfileId(), profile.id);
  });

  test('rejects unknown equipment without partial writes', () async {
    final now = DateTime.utc(2026, 10, 16);
    await expectLater(
      repository.save(
        TrainingProfileRecord(
          id: '00000000-0000-4000-8000-000000000002',
          name: 'Invalid',
          equipmentCodes: const {'teleporter'},
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      ),
      throwsA(isA<TrainingProfileRepositoryException>()),
    );
    expect(await database.query('training_profiles_v2'), isEmpty);
  });
}
