import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
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
  Future<List<HealthWorkout>> workouts(int start, int end) async => data;
  @override
  Future<HealthRoute> route(String id) async =>
      HealthRoute(state: 'denied', points: []);
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
}
