import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/cardio_recording.dart';
import 'package:trainy/repositories/cardio_recordings.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/services/cardio_health_service.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/generated/health_api.g.dart';

class FakeHealth extends HealthHostApi {
  String readState = 'limited';
  bool available = true, routeFails = false;
  final List<HealthWorkout> data = [];
  final Map<String, HealthWorkout> exports = {};
  int routes = 0;
  int reads = 0;
  final List<bool> prompts = [];
  HealthRoute routeResult = HealthRoute(state: 'denied', points: []);
  @override
  Future<HealthAccess> access(
    bool request,
    bool write,
    bool heartRate,
    bool route,
  ) async => HealthAccess(
    available: available,
    readState: readState,
    canWrite: true,
    ownSource: 'trainy.integration',
  );
  @override
  Future<List<HealthWorkout>> workouts(int start, int end) async {
    reads++;
    return data;
  }

  @override
  Future<HealthRoute> route(String id, bool allowPrompt) async {
    prompts.add(allowPrompt);
    return routeResult;
  }

  @override
  Future<String> saveWorkout(HealthWorkout w) async {
    exports[w.clientId!] = w;
    return w.clientId!;
  }

  @override
  Future<void> saveRoute(String id, List<HealthRoutePoint> points) async {
    if (routeFails) throw StateError('interrupted');
    routes++;
  }
}

void main() {
  late Database db;
  late CardioRepository repo;
  late FakeHealth api;
  late CardioHealthService service;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchemaV2.schemaVersion,
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
      ),
    );
    repo = CardioRepository(database: DatabaseService(database: db));
    api = FakeHealth();
    service = CardioHealthService(repo, health: api);
    await repo.saveProfile(const AthleteRunningProfile(healthEnabled: true));
  });
  tearDown(() async => db.close());
  HealthWorkout record(String id, String origin) => HealthWorkout(
    id: id,
    source: origin,
    name: 'Run',
    sport: 'running',
    start: 1000000,
    end: 2800000,
    indoor: false,
  );

  test(
    'partial permissions import workouts without invented distance or active time',
    () async {
      api.data.addAll([
        record('watch', 'watch.vendor'),
        record('own', 'trainy.integration'),
      ]);
      await service.refresh();
      await service.refresh();
      final pending = await service.pending();
      expect(pending.length, 1);
      expect(pending.single['sourceId'], 'watch.vendor');
      expect(pending.single['distance'], isNull);
      await service.accept(pending.single, name: 'Run', includeRoute: true);
      await service.accept(pending.single, name: 'Run', includeRoute: true);
      final history = await repo.history();
      expect(history.length, 1);
      final runtime = jsonDecode(history.single['runtime_json'] as String);
      expect(runtime['distanceMeasured'], false);
      expect(runtime['durationBasis'], 'elapsed');
      expect(service.routeState, 'denied');
      expect(await db.query('cardio_sensor_samples'), isEmpty);
    },
  );
  test(
    'overlapping providers stay separate until user explicitly links them',
    () async {
      api.data.addAll([record('a', 'vendor.a'), record('b', 'vendor.b')]);
      await service.refresh();
      expect((await service.pending()).length, 2);
    },
  );
  test('denied and unavailable are not confused with an empty inbox', () async {
    api.readState = 'denied';
    await expectLater(service.refresh(), throwsStateError);
    api.available = false;
    await expectLater(service.connect(), throwsStateError);
    expect(await service.pending(), isEmpty);
  });
  test('route coordinates and timestamps are validated', () {
    HealthRoutePoint p(double lat, int timestamp) => HealthRoutePoint(
      timestamp: timestamp,
      latitude: lat,
      longitude: 13,
      accuracy: 5,
    );
    expect(CardioHealthService.validRoutePoint(p(52, 100), 0, 200), true);
    expect(
      CardioHealthService.validRoutePoint(p(double.nan, 100), 0, 200),
      false,
    );
    expect(CardioHealthService.validRoutePoint(p(52, 201), 0, 200), false);
  });
  test(
    'interrupted route export retries separately with the same workout identity',
    () async {
      final id = await repo.begin(
        CardioWorkout(name: 'Run', steps: [CardioStep()]),
      );
      final start = DateTime.now().millisecondsSinceEpoch;
      await repo.saveRuntime({
        'sessionId': id,
        'status': 'completed',
        'sport': 'running',
        'startedAt': start,
        'endedAt': start + 60000,
        'activeSeconds': 60,
        'distanceMeters': 100,
        'indoor': false,
      });
      await db.insert('cardio_sensor_samples', {
        'session_id': id,
        'sequence': 0,
        'sample_json': jsonEncode({
          'timestamp': start + 1000,
          'latitude': 52,
          'longitude': 13,
          'accuracy': 5,
          'active': true,
        }),
      });
      api.routeFails = true;
      await expectLater(
        service.export((await repo.history()).single, includeRoute: true),
        throwsStateError,
      );
      expect(api.exports.length, 1);
      var snapshot = jsonDecode(
        (await repo.history()).single['snapshot_json'] as String,
      );
      expect(snapshot['healthExport'], 'done');
      expect(snapshot['healthRouteExport'], 'pending');
      api.routeFails = false;
      await service.export((await repo.history()).single, includeRoute: true);
      expect(api.exports.keys, [id]);
      expect(api.routes, 1);
      snapshot = jsonDecode(
        (await repo.history()).single['snapshot_json'] as String,
      );
      expect(snapshot['healthRouteExport'], 'done');
    },
  );
  for (final removePhone in [false, true]) {
    test(
      'matched sources keep independent routes, update late values and remove locally: phone=$removePhone',
      () async {
        final id = await repo.begin(
          CardioWorkout(name: 'Dauerlauf', steps: [CardioStep()]),
        );
        final start =
            DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch;
        await db.update(
          'activity_sessions',
          {'started_at_utc': start},
          where: 'id = ?',
          whereArgs: [id],
        );
        await repo.saveRuntime({
          'sessionId': id,
          'status': 'completed',
          'sport': 'running',
          'startedAt': start,
          'endedAt': start + 1800000,
          'activeSeconds': 1800,
          'distanceMeters': 3000,
          'distanceMeasured': true,
          'results': [],
        });
        for (var i = 0; i < 3; i++) {
          await db.insert('cardio_sensor_samples', {
            'session_id': id,
            'sequence': i,
            'sample_json': jsonEncode({
              'timestamp': start + 1000 * i,
              'latitude': 52 + i * .0001,
              'longitude': 13,
              'active': true,
              'source': 'phone_gps',
            }),
          });
        }
        api.data.add(
          HealthWorkout(
            id: 'watch-1',
            source: 'watch.vendor',
            name: 'Watch run',
            sport: 'running',
            start: start + 5000,
            end: start + 1805000,
            indoor: false,
            activeSeconds: 1800,
            distance: 2900,
          ),
        );
        api.routeResult = HealthRoute(state: 'consentRequired', points: []);
        await Future.wait([service.refresh(), service.refresh()]);
        expect(api.reads, 1);
        expect(api.prompts, everyElement(false));
        expect(await service.pending(), isEmpty);
        expect((await repo.history()).length, 1);
        var row = (await repo.history()).single;
        var snapshot =
            jsonDecode(row['snapshot_json'] as String) as Map<String, dynamic>;
        var runtime =
            jsonDecode(row['runtime_json'] as String) as Map<String, dynamic>;
        var sources = CardioRecording.all(snapshot, runtime);
        expect(sources.length, 2);
        final watch = sources.singleWhere((s) => !s.phone).id;
        expect(runtime['distanceMeters'], 3000);
        expect(
          CardioRecording.preferred(
            snapshot,
            runtime,
          )!.runtime['distanceMeters'],
          2900,
        );
        expect((await repo.route(id, recordingId: 'phone')).length, 3);
        expect(await repo.route(id, recordingId: watch), isEmpty);
        api.data.single.averageHeartRate = 145;
        api.routeResult = HealthRoute(
          state: 'available',
          points: [
            for (var i = 0; i < 3; i++)
              HealthRoutePoint(
                timestamp: start + 6000 + 1000 * i,
                latitude: 52 + i * .0002,
                longitude: 13,
                accuracy: 3,
              ),
          ],
        );
        await service.refresh(allowRoutePrompt: true);
        await service.refresh();
        expect((await db.query('cardio_sensor_samples')).length, 6);
        expect((await repo.route(id, recordingId: watch)).length, 3);
        expect(
          await repo.route(id),
          await repo.route(id, recordingId: watch),
          reason: 'A default map must not join the phone and watch traces',
        );
        row = (await repo.history()).single;
        expect(CardioRecording.display(row)['averageHeartRate'], 145);
        api.data.single.activeSeconds = null;
        api.data.single.distance = null;
        api.data.single.averageHeartRate = null;
        await service.refresh();
        row = (await repo.history()).single;
        expect(CardioRecording.display(row)['averageHeartRate'], 145);
        expect(CardioRecording.display(row)['distanceMeters'], 2900);
        expect(CardioRecording.display(row)['activeSeconds'], 1800);
        expect(CardioRecording.display(row)['durationBasis'], 'active');
        await repo.removeRecording(id, removePhone ? 'phone' : watch);
        await service.refresh();
        row = (await repo.history()).single;
        snapshot =
            jsonDecode(row['snapshot_json'] as String) as Map<String, dynamic>;
        runtime =
            jsonDecode(row['runtime_json'] as String) as Map<String, dynamic>;
        sources = CardioRecording.all(snapshot, runtime);
        expect(sources.length, 1);
        expect(sources.single.phone, !removePhone);
        expect((await db.query('cardio_sensor_samples')).length, 3);
        expect(
          CardioRecording.display(row)['distanceMeters'],
          removePhone ? 2900 : 3000,
        );
        expect((await repo.history()).single['id'], id);
        expect(
          () => repo.removeRecording(id, sources.single.id),
          throwsStateError,
        );
      },
    );
  }
}
