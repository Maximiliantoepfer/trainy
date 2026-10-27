import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/cardio_recording.dart';
import 'cardio_repository.dart';

extension CardioRecordings on CardioRepository {
  Future<void> removeRecording(String sessionId, String recordingId) async {
    await db.transaction((txn) async {
      final detail =
          (await txn.query(
            'cardio_session_details',
            where: 'session_id = ?',
            whereArgs: [sessionId],
          )).single;
      final snapshot =
          jsonDecode(detail['snapshot_json'] as String) as Map<String, dynamic>;
      final runtime =
          jsonDecode(detail['runtime_json'] as String) as Map<String, dynamic>;
      final sources = CardioRecording.all(snapshot, runtime);
      if (sources.length < 2) throw StateError('last_recording');
      final removed = sources.singleWhere((r) => r.id == recordingId);
      snapshot['removedRecordings'] =
          {
            ...List<String>.from(snapshot['removedRecordings'] as List? ?? []),
            recordingId,
          }.toList();
      snapshot['recordings'] =
          (snapshot['recordings'] as List? ?? [])
              .where((r) => (r as Map)['id'] != recordingId)
              .toList();
      if (snapshot['preferredRecordingId'] == recordingId) {
        snapshot.remove('preferredRecordingId');
      }
      final selected = CardioRecording.preferred(snapshot, runtime)!;
      snapshot['preferredRecordingId'] = selected.id;
      final oldHealthId =
          snapshot['health'] is Map
              ? CardioRecording.healthId(snapshot['health'] as Map)
              : null;
      final removeOriginal =
          removed.phone ||
          snapshot['originalRecordingId'] == removed.id ||
          (runtime['source'] != null &&
              snapshot['originalRecordingId'] == null &&
              CardioRecording.healthId(snapshot['health'] as Map) ==
                  removed.id);
      if (removeOriginal) snapshot['originalRecordingId'] = selected.id;
      if (oldHealthId == removed.id) {
        snapshot.remove('health');
        // Keep only the remaining source's identity, never the removed metrics.
        if (!selected.phone) {
          snapshot['health'] = {
            'provider': selected.id.split(':').first,
            'sourceId': selected.source,
            'externalId': selected.externalId,
          };
        }
      }
      await txn.update(
        'cardio_session_details',
        {
          'snapshot_json': jsonEncode(snapshot),
          // Removal must really remove the local copy, not merely hide it.
          if (removeOriginal) 'runtime_json': jsonEncode(selected.runtime),
        },
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      if (removed.phone) {
        await txn.delete(
          'activity_items',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
      }
      for (final row in await txn.query(
        'cardio_sensor_samples',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      )) {
        final point = jsonDecode(row['sample_json'] as String) as Map;
        final source =
            point['recordingId'] ??
            (point['source'] == null || point['source'] == 'phone_gps'
                ? 'phone'
                : oldHealthId);
        if (source == recordingId) {
          await txn.delete(
            'cardio_sensor_samples',
            where: 'session_id = ? AND sequence = ?',
            whereArgs: [sessionId, row['sequence']],
          );
        }
      }
      if (removed.externalId != null) {
        final links = await txn.query(
          'health_record_links',
          where: 'session_id = ? AND external_record_id = ?',
          whereArgs: [sessionId, removed.externalId],
        );
        for (final link in links) {
          await txn.update(
            'cardio_health_inbox',
            {
              'decision': 'dismissed',
              'record_json': jsonEncode({
                'provider': link['provider'],
                'externalId': removed.externalId,
                'locallyRemoved': true,
              }),
            },
            where: 'provider = ? AND external_id = ?',
            whereArgs: [link['provider'], removed.externalId],
          );
        }
      }
      for (final metric in [
        ('duration', 'activeSeconds', 'second'),
        ('distance', 'distanceMeters', 'meter'),
      ]) {
        final value = selected.runtime[metric.$2];
        await txn.delete(
          'activity_metric_values',
          where: 'id = ?',
          whereArgs: ['$sessionId:${metric.$1}'],
        );
        if (value != null) {
          await txn.insert('activity_metric_values', {
            'id': '$sessionId:${metric.$1}',
            'session_id': sessionId,
            'metric_code': metric.$1,
            'canonical_value': value,
            'entered_value': value,
            'entered_unit_code': metric.$3,
            'source':
                selected.phone
                    ? 'manual'
                    : selected.runtime['source'] ?? 'import',
            'recorded_at_utc': selected.runtime['endedAt'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
