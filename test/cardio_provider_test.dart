import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/generated/cardio_api.g.dart';

class Recorder extends CardioHostApi {
  Map<String, dynamic>? value;
  bool failStart = false, failAcknowledgement = false;
  int acknowledgements = 0;
  final points = <Map<String, dynamic>>[];
  @override
  Future<String?> state() async => value == null ? null : jsonEncode(value);
  @override
  Future<void> start(String snapshotJson) async {
    if (failStart) throw StateError('native_start_failed');
    value = {
      ...jsonDecode(snapshotJson) as Map<String, dynamic>,
      'status': 'active',
    };
  }

  @override
  Future<void> recover(String runtimeJson) async {
    value = {
      ...jsonDecode(runtimeJson) as Map<String, dynamic>,
      'status': 'paused',
      'recovered': true,
    };
  }

  @override
  Future<String> samples(int afterSequence) async => jsonEncode(
    points
        .where((p) => (p['sequence'] as int) > afterSequence)
        .take(1000)
        .toList(),
  );
  @override
  Future<void> acknowledge(String sessionId) async {
    if (failAcknowledgement) {
      failAcknowledgement = false;
      throw StateError('interrupted_acknowledgement');
    }
    expect(value!['sessionId'], sessionId);
    acknowledgements++;
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late CardioRepository repository;
  late Recorder recorder;
  late CardioProvider provider;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        version: DatabaseSchemaV2.schemaVersion,
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
      ),
    );
    repository = CardioRepository(database: DatabaseService(database: db));
    recorder = Recorder();
    provider = CardioProvider(repository: repository, api: recorder);
  });
  tearDown(() async {
    provider.dispose();
    await db.close();
  });
  final workout = CardioWorkout(
    name: 'Recovery test',
    steps: [CardioStep(amount: 300)],
  );
  test('failed native launch leaves no stuck active session', () async {
    recorder.failStart = true;
    await expectLater(
      provider.start(workout, (s) => s, 'en'),
      throwsStateError,
    );
    expect(await repository.recoverable(), isEmpty);
    expect((await db.query('activity_sessions')).single['status'], 'discarded');
  });
  test('lost native process restores the SQL checkpoint paused', () async {
    final id = await repository.begin(workout);
    await repository.saveRuntime({
      'version': 1,
      'sessionId': id,
      'status': 'active',
      'activeSeconds': 42,
      'steps': [CardioStep().toJson()],
    });
    await provider.poll();
    await provider.poll();
    expect(provider.runtime!['status'], 'paused');
    expect(provider.runtime!['activeSeconds'], 42);
    expect(provider.runtime!['recovered'], isTrue);
    expect(recorder.acknowledgements, 0);
  });
  test(
    'completed journal drains every page before ack and retries idempotently',
    () async {
      final id = await repository.begin(workout);
      recorder.value = {
        'sessionId': id,
        'status': 'completed',
        'activeSeconds': 300,
        'distanceMeters': 900,
      };
      recorder.points.addAll(
        List.generate(2001, (i) => {'sequence': i, 'latitude': 52.0}),
      );
      recorder.failAcknowledgement = true;
      await provider.poll();
      expect(provider.error, isNotNull);
      expect((await db.query('cardio_sensor_samples')).length, 2001);
      expect(recorder.value, isNotNull);
      await provider.poll();
      expect(provider.error, isNull);
      expect(recorder.acknowledgements, 1);
      expect((await repository.history()).length, 1);
      expect((await db.query('activity_metric_values')).length, 2);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
