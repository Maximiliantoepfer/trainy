import 'dart:convert';
import 'dart:io';
import 'package:health/health.dart';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../repositories/cardio_repository.dart';
import '../utils/uuid_v4.dart';

/// Health stores are post-workout inboxes, never a live watch connection.
class CardioHealthService {
  CardioHealthService(this.repository, {Health? health})
    : health = health ?? Health();
  final CardioRepository repository;
  final Health health;
  String get provider => Platform.isIOS ? 'healthkit' : 'health_connect';
  static CardioSport? sport(String type) => switch (type) {
    'RUNNING' || 'RUNNING_TREADMILL' => CardioSport.running,
    'WALKING' => CardioSport.walking,
    'BIKING' || 'BIKING_STATIONARY' => CardioSport.cycling,
    'STAIR_CLIMBING' || 'STAIR_CLIMBING_MACHINE' => CardioSport.stepper,
    'ELLIPTICAL' => CardioSport.elliptical,
    'ROWING' || 'ROWING_MACHINE' => CardioSport.rowing,
    _ => null,
  };
  Future<void> connect() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('health_unavailable');
    }
    await health.configure();
    if (Platform.isAndroid && !await health.isHealthConnectAvailable()) {
      throw StateError('health_unavailable');
    }
    final ok = await health.requestAuthorization(
      [HealthDataType.WORKOUT, HealthDataType.HEART_RATE],
      permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
    );
    if (!ok) throw StateError('health_permission');
    final p = await repository.profile();
    await repository.saveProfile(
      AthleteRunningProfile.fromJson({...p.toJson(), 'healthEnabled': true}),
    );
  }

  Future<void> refresh() async {
    if (!(await repository.profile()).healthEnabled) return;
    await health.configure();
    final now = DateTime.now();
    final data = await health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: now.subtract(const Duration(days: 29)),
      endTime: now,
    );
    for (final point in data) {
      if (point.value is! WorkoutHealthValue ||
          point.sourceId == 'com.example.trainy') {
        continue;
      }
      final value = point.value as WorkoutHealthValue;
      final activity = sport(value.workoutActivityType.name);
      if (activity == null ||
          point.uuid.isEmpty ||
          !point.dateTo.isAfter(point.dateFrom)) {
        continue;
      }
      // Distances from the plugin's workout summary are canonical meters.
      final rawDistance =
          point.workoutSummary?.totalDistance.toDouble() ??
          (value.totalDistanceUnit == HealthDataUnit.METER
              ? value.totalDistance?.toDouble()
              : null);
      // Some providers encode a missing distance as zero. Do not present it as measured.
      final distance =
          rawDistance != null && rawDistance.isFinite && rawDistance > 0
              ? rawDistance
              : null;
      final record = {
        'provider': provider,
        'externalId': point.uuid,
        'sport': activity.name,
        'sourceId': point.sourceId,
        'sourceName': point.sourceName,
        'sourceDeviceId': point.sourceDeviceId,
        'start': point.dateFrom.millisecondsSinceEpoch,
        'end': point.dateTo.millisecondsSinceEpoch,
        'distance': distance,
        'indoor':
            value.workoutActivityType.name.contains('STATIONARY') ||
            value.workoutActivityType.name.contains('TREADMILL'),
      };
      await repository.db.insert('cardio_health_inbox', {
        'provider': provider,
        'external_id': point.uuid,
        'record_json': jsonEncode(record),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Map<String, dynamic>>> pending() async =>
      (await repository.db.query(
            'cardio_health_inbox',
            where: "decision = 'pending'",
          ))
          .map(
            (r) =>
                jsonDecode(r['record_json'] as String) as Map<String, dynamic>,
          )
          .toList();
  Future<void> dismiss(Map<String, dynamic> record) async =>
      repository.db.update(
        'cardio_health_inbox',
        {'decision': 'dismissed'},
        where: 'provider = ? AND external_id = ?',
        whereArgs: [record['provider'], record['externalId']],
      );

  static bool matches(
    Map<String, Object?> session,
    Map<String, dynamic> record,
  ) {
    if (session['activity_type'] !=
        CardioRepository.activityType(
          CardioSport.values.byName(record['sport'] as String),
        )) {
      return false;
    }
    final a = session['started_at_utc'] as int,
        b = session['ended_at_utc'] as int? ?? a;
    final c = record['start'] as int, d = record['end'] as int;
    return (a - c).abs() <= 120000 &&
        ((b - a) - (d - c)).abs() <= ((d - c) * .1).clamp(120000, 600000);
  }

  Future<void> accept(
    Map<String, dynamic> record, {
    String? linkSessionId,
    String? occurrenceId,
    required String name,
  }) async {
    double? averageHeartRate;
    // Same source and device only. An overlapping record is not proof of association.
    try {
      final points = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: DateTime.fromMillisecondsSinceEpoch(record['start'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(record['end'] as int),
      );
      final rates =
          points
              .where(
                (p) =>
                    p.sourceId == record['sourceId'] &&
                    p.sourceDeviceId == record['sourceDeviceId'] &&
                    p.value is NumericHealthValue,
              )
              .map(
                (p) => (p.value as NumericHealthValue).numericValue.toDouble(),
              )
              .where((v) => v.isFinite && v >= 25 && v <= 250)
              .toList();
      if (rates.isNotEmpty) {
        averageHeartRate = rates.reduce((a, b) => a + b) / rates.length;
      }
    } catch (_) {
      /* Partial health permissions do not block workout import. */
    }
    await repository.db.transaction((txn) async {
      final existing = await txn.query(
        'health_record_links',
        where: 'provider = ? AND external_record_id = ?',
        whereArgs: [record['provider'], record['externalId']],
      );
      if (existing.isNotEmpty) return;
      final id = linkSessionId ?? UuidV4.generate();
      if (linkSessionId == null) {
        final start = record['start'] as int, end = record['end'] as int;
        final seconds = (end - start) / 1000;
        final meters = (record['distance'] as num?)?.toDouble();
        final runtime = {
          'sessionId': id,
          'name': name,
          'status': 'completed',
          'sport': record['sport'],
          'indoor': record['indoor'],
          'distanceMeasured': meters != null,
          'startedAt': start,
          'endedAt': end,
          'activeSeconds': seconds,
          'elapsedSeconds': seconds,
          'distanceMeters': meters ?? 0,
          'averageHeartRate': averageHeartRate,
          'results': <Object>[],
          'cooldown': <Object>[],
          'source': record['provider'],
          'durationBasis': 'elapsed',
        };
        await txn.insert('activity_sessions', {
          'id': id,
          'activity_type': CardioRepository.activityType(
            CardioSport.values.byName(record['sport'] as String),
          ),
          'status': 'completed',
          'source': record['provider'],
          'name_snapshot': name,
          'started_at_utc': start,
          'ended_at_utc': end,
          'timezone_offset_minutes':
              DateTime.fromMillisecondsSinceEpoch(
                start,
              ).timeZoneOffset.inMinutes,
          'created_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
        });
        await txn.insert('activity_session_tags', {
          'session_id': id,
          'tag_code': 'cardio',
          'position': 0,
        });
        await txn.insert('cardio_session_details', {
          'session_id': id,
          'snapshot_json': jsonEncode({
            'health': record,
            'occurrenceId': occurrenceId,
          }),
          'runtime_json': jsonEncode(runtime),
        });
        for (final metric in [
          ('duration', seconds, 'second'),
          if (meters != null) ('distance', meters, 'meter'),
        ]) {
          await txn.insert('activity_metric_values', {
            'id': '$id:${metric.$1}',
            'session_id': id,
            'metric_code': metric.$1,
            'canonical_value': metric.$2,
            'entered_value': metric.$2,
            'entered_unit_code': metric.$3,
            'source': record['provider'],
            'recorded_at_utc': end,
          });
        }
      } else {
        final rows = await txn.query(
          'cardio_session_details',
          where: 'session_id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) throw StateError('missing_session');
        final snapshot =
            jsonDecode(rows.single['snapshot_json'] as String)
                as Map<String, dynamic>;
        snapshot['health'] = record;
        final runtime =
            jsonDecode(rows.single['runtime_json'] as String)
                as Map<String, dynamic>;
        if (averageHeartRate != null) {
          runtime['averageHeartRate'] = averageHeartRate;
        }
        await txn.update(
          'cardio_session_details',
          {
            'snapshot_json': jsonEncode(snapshot),
            'runtime_json': jsonEncode(runtime),
          },
          where: 'session_id = ?',
          whereArgs: [id],
        );
      }
      await txn.insert('health_record_links', {
        'id': UuidV4.generate(),
        'session_id': id,
        'provider': record['provider'],
        'external_record_id': record['externalId'],
        'sync_status': 'linked',
        'updated_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
      if (occurrenceId != null) {
        await txn.update(
          'cardio_occurrences',
          {'status': 'completed', 'session_id': id},
          where: "id = ? AND status = 'planned'",
          whereArgs: [occurrenceId],
        );
      }
      await txn.update(
        'cardio_health_inbox',
        {'decision': 'accepted'},
        where: 'provider = ? AND external_id = ?',
        whereArgs: [record['provider'], record['externalId']],
      );
    });
  }

  Future<void> export(Map<String, Object?> session) async {
    if (session['source'] != 'manual') {
      throw StateError('Do not re-export an import');
    }
    await health.configure();
    final runtime =
        jsonDecode(session['runtime_json'] as String) as Map<String, dynamic>;
    final distanceType =
        Platform.isAndroid
            ? HealthDataType.DISTANCE_DELTA
            : runtime['sport'] == 'cycling'
            ? HealthDataType.DISTANCE_CYCLING
            : HealthDataType.DISTANCE_WALKING_RUNNING;
    final granted = await health.requestAuthorization(
      [HealthDataType.WORKOUT, distanceType],
      permissions: [HealthDataAccess.READ_WRITE, HealthDataAccess.READ_WRITE],
    );
    if (!granted) throw StateError('health_permission');
    final snapshot =
        jsonDecode(session['snapshot_json'] as String) as Map<String, dynamic>;
    if (snapshot['healthExport'] == 'done') return;
    // Plugin has no external idempotency key. Never automatically retry uncertain writes.
    final start = DateTime.fromMillisecondsSinceEpoch(
      session['started_at_utc'] as int,
    );
    final end = DateTime.fromMillisecondsSinceEpoch(
      session['ended_at_utc'] as int,
    );
    final existing = await health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start.subtract(const Duration(seconds: 1)),
      endTime: end.add(const Duration(seconds: 1)),
    );
    if (existing.any(
      (p) =>
          p.sourceId == 'com.example.trainy' &&
          (p.dateFrom.millisecondsSinceEpoch - start.millisecondsSinceEpoch)
                  .abs() <
              1000,
    )) {
      snapshot['healthExport'] = 'done';
    } else {
      if (snapshot['healthExport'] == 'pending') {
        throw StateError('health_export_uncertain');
      }
      snapshot['healthExport'] = 'pending';
      await repository.db.update(
        'cardio_session_details',
        {'snapshot_json': jsonEncode(snapshot)},
        where: 'session_id = ?',
        whereArgs: [session['id']],
      );
      final type = switch (runtime['sport']) {
        'running' => HealthWorkoutActivityType.RUNNING,
        'walking' => HealthWorkoutActivityType.WALKING,
        'cycling' => HealthWorkoutActivityType.BIKING,
        'elliptical' => HealthWorkoutActivityType.ELLIPTICAL,
        'rowing' => HealthWorkoutActivityType.ROWING,
        'stepper' => HealthWorkoutActivityType.STAIR_CLIMBING,
        _ => HealthWorkoutActivityType.OTHER,
      };
      final ok = await health.writeWorkoutData(
        activityType: type,
        start: start,
        end: end,
        title: session['name_snapshot'] as String,
        totalDistance:
            runtime['indoor'] == true
                ? null
                : (runtime['distanceMeters'] as num?)?.round(),
      );
      if (!ok) throw StateError('health_export_uncertain');
      snapshot['healthExport'] = 'done';
    }
    await repository.db.update(
      'cardio_session_details',
      {'snapshot_json': jsonEncode(snapshot)},
      where: 'session_id = ?',
      whereArgs: [session['id']],
    );
  }
}
