import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../models/cardio_recording.dart';
import '../repositories/cardio_repository.dart';
import '../utils/uuid_v4.dart';
import 'generated/health_api.g.dart';

/// Health stores are post-workout inboxes, never a live watch connection.
class CardioHealthService {
  CardioHealthService(this.repository, {HealthHostApi? health})
    : health = health ?? HealthHostApi();
  final CardioRepository repository;
  final HealthHostApi health;
  HealthAccess? accessState;
  String syncState = 'idle';
  String? routeState;
  Future<void>? _refreshing;
  Object? error;
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
    accessState = await health.access(
      true,
      false,
      true,
      (await repository.profile()).planning.healthRoutes,
    );
    if (!accessState!.available) throw StateError('health_unavailable');
    if (accessState!.readState == 'denied') {
      throw StateError('health_permission');
    }
    final p = await repository.profile();
    await repository.saveProfile(
      AthleteRunningProfile.fromJson({...p.toJson(), 'healthEnabled': true}),
    );
  }

  Future<void> refresh({bool allowRoutePrompt = false}) =>
      _refreshing ??= _refresh(
        allowRoutePrompt,
      ).whenComplete(() => _refreshing = null);

  Future<void> _refresh(bool allowRoutePrompt) async {
    if (!(await repository.profile()).healthEnabled) return;
    syncState = 'syncing';
    error = null;
    try {
      accessState = await health.access(false, false, false, false);
      if (!accessState!.available) throw StateError('health_unavailable');
      if (accessState!.readState == 'denied') {
        throw StateError('health_permission');
      }
      final now = DateTime.now();
      final data = await health.workouts(
        now.subtract(const Duration(days: 29)).millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      var imported = 0;
      for (final point in data) {
        if (point.source == accessState!.ownSource) continue;
        final activity =
            CardioSport.values.where((s) => s.name == point.sport).firstOrNull;
        if (activity == null ||
            point.id.isEmpty ||
            point.source.isEmpty ||
            point.end <= point.start) {
          continue;
        }
        final rawDistance = point.distance;
        // Some providers encode a missing distance as zero. Do not present it as measured.
        final distance =
            rawDistance != null && rawDistance.isFinite && rawDistance > 0
                ? rawDistance
                : null;
        final record = {
          'provider': provider,
          'externalId': point.id,
          'sport': activity.name,
          'sourceId': point.source,
          'sourceName': point.source,
          'sourceDeviceId': point.device,
          'start': point.start,
          'end': point.end,
          'distance': distance,
          'activeSeconds': point.activeSeconds,
          'averageHeartRate': point.averageHeartRate,
          'indoor': point.indoor,
        };
        final prior = await repository.db.query(
          'cardio_health_inbox',
          where: 'provider = ? AND external_id = ?',
          whereArgs: [provider, point.id],
        );
        if (prior.firstOrNull?['decision'] == 'dismissed') continue;
        if (prior.isEmpty) {
          await repository.db.insert('cardio_health_inbox', {
            'provider': provider,
            'external_id': point.id,
            'record_json': jsonEncode(record),
          });
        } else {
          await repository.db.update(
            'cardio_health_inbox',
            {'record_json': jsonEncode(record)},
            where: 'provider = ? AND external_id = ?',
            whereArgs: [provider, point.id],
          );
        }
        final links = await repository.db.query(
          'health_record_links',
          where: 'provider = ? AND external_record_id = ?',
          whereArgs: [provider, point.id],
        );
        final candidates =
            links.isEmpty
                ? (await repository.history())
                    .where((s) => matches(s, record))
                    .toList()
                : <Map<String, Object?>>[];
        final session =
            links.firstOrNull?['session_id'] as String? ??
            (candidates.length == 1 ? candidates.single['id'] as String : null);
        if (session != null) {
          await accept(
            record,
            linkSessionId: session,
            name: point.name,
            includeRoute: (await repository.profile()).planning.healthRoutes,
            allowRoutePrompt: allowRoutePrompt,
          );
        }
        imported++;
      }
      syncState = imported == 0 ? 'empty' : 'synced';
    } catch (e) {
      error = e;
      syncState = 'failed';
      rethrow;
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
    final shorter = (b - a) < (d - c) ? b - a : d - c;
    final overlap = (b < d ? b : d) - (a > c ? a : c);
    return shorter >= 60000 &&
        (a - c).abs() <= 120000 &&
        overlap >= shorter * .85;
  }

  Future<void> accept(
    Map<String, dynamic> record, {
    String? linkSessionId,
    String? occurrenceId,
    required String name,
    bool includeRoute = true,
    bool allowRoutePrompt = true,
  }) async {
    final rawHeartRate = (record['averageHeartRate'] as num?)?.toDouble();
    final averageHeartRate =
        rawHeartRate != null &&
                rawHeartRate.isFinite &&
                rawHeartRate >= 25 &&
                rawHeartRate <= 250
            ? rawHeartRate
            : null;
    HealthRoute? route;
    if (includeRoute) {
      try {
        route = await health.route(
          record['externalId'] as String,
          allowRoutePrompt,
        );
        routeState = route.state;
      } catch (_) {
        routeState = 'failed';
      }
    }
    await repository.db.transaction((txn) async {
      final existing = await txn.query(
        'health_record_links',
        where: 'provider = ? AND external_record_id = ?',
        whereArgs: [record['provider'], record['externalId']],
      );
      final id =
          existing.firstOrNull?['session_id'] as String? ??
          linkSessionId ??
          UuidV4.generate();
      final recordingId = CardioRecording.healthId(record);
      final detail = await txn.query(
        'cardio_session_details',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      final oldSnapshot =
          detail.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(detail.single['snapshot_json'] as String)
                  as Map<String, dynamic>;
      if ((oldSnapshot['removedRecordings'] as List? ?? []).contains(
        recordingId,
      )) {
        return;
      }
      final start = record['start'] as int, end = record['end'] as int;
      final elapsed = (end - start) / 1000;
      final active = (record['activeSeconds'] as num?)?.toDouble();
      final knownActive =
          active != null && active.isFinite && active > 0 && active <= elapsed;
      final seconds = knownActive ? active : elapsed;
      final meters = (record['distance'] as num?)?.toDouble();
      final externalRuntime = <String, dynamic>{
        'sessionId': id,
        'name': name,
        'status': 'completed',
        'sport': record['sport'],
        'indoor': record['indoor'],
        'distanceMeasured': meters != null,
        'startedAt': start,
        'endedAt': end,
        'activeSeconds': seconds,
        'elapsedSeconds': elapsed,
        'distanceMeters': meters,
        'averageHeartRate': averageHeartRate,
        'results': <Object>[],
        'cooldown': <Object>[],
        'source': record['provider'],
        'sourceId': record['sourceId'],
        'durationBasis': knownActive ? 'active' : 'elapsed',
        if (knownActive) 'hadPause': elapsed - active > 5,
      };
      if (detail.isEmpty) {
        final start = record['start'] as int, end = record['end'] as int;
        final elapsed = (end - start) / 1000;
        final active = (record['activeSeconds'] as num?)?.toDouble();
        final knownActive =
            active != null &&
            active.isFinite &&
            active > 0 &&
            active <= elapsed;
        final seconds = knownActive ? active : elapsed;
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
          'elapsedSeconds': elapsed,
          'distanceMeters': meters ?? 0,
          'averageHeartRate': averageHeartRate,
          'results': <Object>[],
          'cooldown': <Object>[],
          'source': record['provider'],
          'durationBasis': knownActive ? 'active' : 'elapsed',
          // Missing duration is not zero. A later explicit continuous-running
          // confirmation can make elapsed duration usable, never silently here.
          if (knownActive) 'hadPause': elapsed - active > 5,
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
        await txn.update(
          'cardio_session_details',
          {'snapshot_json': jsonEncode(snapshot)},
          where: 'session_id = ?',
          whereArgs: [id],
        );
      }
      final saved =
          (await txn.query(
            'cardio_session_details',
            where: 'session_id = ?',
            whereArgs: [id],
          )).single;
      final snapshot =
          jsonDecode(saved['snapshot_json'] as String) as Map<String, dynamic>;
      if (detail.isEmpty) snapshot['originalRecordingId'] = recordingId;
      final recordings = List<Map<String, dynamic>>.from(
        (snapshot['recordings'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final previousRecording =
          recordings.where((r) => r['id'] == recordingId).firstOrNull;
      final previousRuntime = previousRecording?['runtime'] as Map?;
      if (!knownActive &&
          previousRuntime?['durationBasis'] == 'active' &&
          previousRuntime?['startedAt'] == start &&
          previousRuntime?['endedAt'] == end) {
        externalRuntime['activeSeconds'] = previousRuntime!['activeSeconds'];
        externalRuntime['durationBasis'] = 'active';
        externalRuntime['hadPause'] = previousRuntime['hadPause'];
      }
      for (final key in ['distanceMeters', 'averageHeartRate']) {
        if (externalRuntime[key] == null && previousRuntime?[key] != null) {
          externalRuntime[key] = previousRuntime![key];
        }
      }
      externalRuntime['distanceMeasured'] =
          externalRuntime['distanceMeters'] != null;
      recordings.removeWhere((r) => r['id'] == recordingId);
      recordings.add(
        CardioRecording(
          id: recordingId,
          source: record['sourceId'] as String,
          externalId: record['externalId'] as String,
          runtime: externalRuntime,
          routeState:
              route?.state == 'available'
                  ? 'available'
                  : previousRecording?['routeState'] as String? ?? route?.state,
        ).toJson(),
      );
      snapshot['recordings'] = recordings;
      snapshot['health'] = record;
      snapshot['preferredRecordingId'] ??= recordingId;
      await txn.update(
        'cardio_session_details',
        {'snapshot_json': jsonEncode(snapshot)},
        where: 'session_id = ?',
        whereArgs: [id],
      );
      // A refresh replaces only this source's route. Phone samples remain untouched.
      if (route?.state == 'available') {
        final sampleRows = await txn.query(
          'cardio_sensor_samples',
          where: 'session_id = ?',
          whereArgs: [id],
        );
        var sequence = 0;
        for (final row in sampleRows) {
          final value = jsonDecode(row['sample_json'] as String) as Map;
          final n = row['sequence'] as int;
          if (n >= sequence) sequence = n + 1;
          if (value['recordingId'] == recordingId ||
              (value['recordingId'] == null &&
                  value['source'] == record['provider'] &&
                  detail.isNotEmpty &&
                  (jsonDecode(detail.single['runtime_json'] as String)
                          as Map)['source'] !=
                      null)) {
            await txn.delete(
              'cardio_sensor_samples',
              where: 'session_id = ? AND sequence = ?',
              whereArgs: [id, n],
            );
          }
        }
        for (final point in route!.points) {
          if (!validRoutePoint(
            point,
            record['start'] as int,
            record['end'] as int,
          )) {
            continue;
          }
          await txn.insert('cardio_sensor_samples', {
            'session_id': id,
            'sequence': sequence++,
            'sample_json': jsonEncode({
              'timestamp': point.timestamp,
              'latitude': point.latitude,
              'longitude': point.longitude,
              'accuracy': point.accuracy,
              'altitude': point.altitude,
              'active': true,
              'source': record['provider'],
              'recordingId': recordingId,
            }),
          });
        }
      }
      if (existing.isEmpty) {
        await txn.insert('health_record_links', {
          'id': UuidV4.generate(),
          'session_id': id,
          'provider': record['provider'],
          'external_record_id': record['externalId'],
          'sync_status': 'linked',
          'updated_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
        });
      }
      // Progress metrics use one selected measurement, never sum two recordings.
      if (snapshot['preferredRecordingId'] == recordingId) {
        for (final metric in [
          ('duration', externalRuntime['activeSeconds'], 'second'),
          ('distance', externalRuntime['distanceMeters'], 'meter'),
        ]) {
          if (metric.$2 == null) continue;
          await txn.insert('activity_metric_values', {
            'id': '$id:${metric.$1}',
            'session_id': id,
            'metric_code': metric.$1,
            'canonical_value': metric.$2,
            'entered_value': metric.$2,
            'entered_unit_code': metric.$3,
            'source': record['provider'],
            'recorded_at_utc': end,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
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

  static bool validRoutePoint(HealthRoutePoint p, int start, int end) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180 &&
      p.timestamp >= start &&
      p.timestamp <= end &&
      (p.accuracy == null ||
          (p.accuracy!.isFinite && p.accuracy! >= 0 && p.accuracy! <= 100));

  Future<void> export(
    Map<String, Object?> session, {
    bool includeRoute = false,
  }) async {
    if (session['source'] != 'manual') {
      throw StateError('Do not re-export an import');
    }
    final runtime =
        jsonDecode(session['runtime_json'] as String) as Map<String, dynamic>;
    accessState = await health.access(true, true, false, includeRoute);
    if (!accessState!.available) throw StateError('health_unavailable');
    if (!accessState!.canWrite) throw StateError('health_permission');
    final snapshot =
        jsonDecode(session['snapshot_json'] as String) as Map<String, dynamic>;
    if ((snapshot['removedRecordings'] as List? ?? []).contains('phone')) {
      throw StateError('phone_recording_removed');
    }
    final start = session['started_at_utc'] as int;
    final end = session['ended_at_utc'] as int;
    // Native adapters reconcile legacy exports and use stable IDs for all retries.
    final externalId = await health.saveWorkout(
      HealthWorkout(
        id: '',
        source: accessState!.ownSource,
        clientId: session['id'] as String,
        name: session['name_snapshot'] as String,
        sport: runtime['sport'] as String,
        start: start,
        end: end,
        indoor: runtime['indoor'] == true,
        activeSeconds: (runtime['activeSeconds'] as num?)?.toDouble(),
        distance:
            runtime['distanceMeasured'] == false || runtime['indoor'] == true
                ? null
                : (runtime['distanceMeters'] as num?)?.toDouble(),
      ),
    );
    snapshot['healthExportId'] = externalId;
    snapshot['healthExport'] = 'done';
    snapshot['healthRouteExport'] =
        includeRoute ? 'pending' : snapshot['healthRouteExport'];
    await repository.db.update(
      'cardio_session_details',
      {'snapshot_json': jsonEncode(snapshot)},
      where: 'session_id = ?',
      whereArgs: [session['id']],
    );
    if (includeRoute) {
      final samples = await repository.db.query(
        'cardio_sensor_samples',
        where: 'session_id = ?',
        whereArgs: [session['id']],
        orderBy: 'sequence',
      );
      final points = <HealthRoutePoint>[];
      for (final row in samples) {
        final p =
            jsonDecode(row['sample_json'] as String) as Map<String, dynamic>;
        if (p['recordingId'] != null ||
            (p['source'] != null && p['source'] != 'phone_gps')) {
          continue;
        }
        if (p['active'] == false ||
            p['latitude'] is! num ||
            p['longitude'] is! num ||
            p['timestamp'] is! num) {
          continue;
        }
        final point = HealthRoutePoint(
          timestamp: (p['timestamp'] as num).toInt(),
          latitude: (p['latitude'] as num).toDouble(),
          longitude: (p['longitude'] as num).toDouble(),
          accuracy: (p['accuracy'] as num?)?.toDouble(),
          altitude: (p['altitude'] as num?)?.toDouble(),
        );
        if (validRoutePoint(point, start, end)) points.add(point);
      }
      if (points.isNotEmpty) await health.saveRoute(externalId, points);
      snapshot['healthRouteExport'] = points.isEmpty ? 'noData' : 'done';
      await repository.db.update(
        'cardio_session_details',
        {'snapshot_json': jsonEncode(snapshot)},
        where: 'session_id = ?',
        whereArgs: [session['id']],
      );
    }
  }
}
