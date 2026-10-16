import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../utils/uuid_v4.dart';

class ActivityRepository {
  ActivityRepository({DatabaseService? databaseService})
    : _database = databaseService ?? DatabaseService();

  final DatabaseService _database;
  static const _domains = {'strength', 'cardio', 'mobility'};

  Future<String> startSession({
    required String activityType,
    required String nameSnapshot,
    required List<String> tags,
    String source = 'manual',
    String? workoutId,
    String? trainingPlanId,
    String? workoutVariantId,
    String? profileId,
    DateTime? startedAt,
  }) async {
    final normalizedTags = _validateTags(tags);
    final start = (startedAt ?? DateTime.now()).toUtc();
    final localStart = startedAt ?? DateTime.now();
    final id = UuidV4.generate();
    await _database.transaction((txn) async {
      await txn.insert('activity_sessions', {
        'id': id,
        'workout_id': workoutId,
        'training_plan_id': trainingPlanId,
        'workout_variant_id': workoutVariantId,
        'profile_id': profileId,
        'activity_type': activityType,
        'status': 'active',
        'source': source,
        'name_snapshot': nameSnapshot,
        'started_at_utc': start.millisecondsSinceEpoch,
        'timezone_offset_minutes': localStart.timeZoneOffset.inMinutes,
        'created_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
      for (var index = 0; index < normalizedTags.length; index++) {
        await txn.insert('activity_session_tags', {
          'session_id': id,
          'tag_code': normalizedTags[index],
          'position': index,
        });
      }
    });
    return id;
  }

  Future<String> addActivityItem({
    required String sessionId,
    required String displayNameSnapshot,
    String? exerciseId,
    String? catalogIdSnapshot,
    String? movementFamilySnapshot,
    String? equipmentSnapshot,
    String? sessionGroupId,
    int sortOrder = 0,
  }) async {
    final id = UuidV4.generate();
    await _database.transaction((txn) async {
      await txn.insert('activity_items', {
        'id': id,
        'session_id': sessionId,
        'session_group_id': sessionGroupId,
        'exercise_id': exerciseId,
        'catalog_id_snapshot': catalogIdSnapshot,
        'display_name_snapshot': displayNameSnapshot,
        'movement_family_snapshot': movementFamilySnapshot,
        'equipment_snapshot': equipmentSnapshot,
        'sort_order': sortOrder,
      });
    });
    return id;
  }

  Future<String> recordEffort({
    required String sessionId,
    required String activityItemId,
    String effortType = 'set',
    int sortOrder = 0,
    DateTime? startedAt,
    DateTime? endedAt,
    required List<ActivityMetricInput> metrics,
  }) async {
    final effortId = UuidV4.generate();
    await _database.transaction((txn) async {
      await txn.insert('activity_efforts', {
        'id': effortId,
        'activity_item_id': activityItemId,
        'effort_type': effortType,
        'sort_order': sortOrder,
        'started_at_utc': startedAt?.toUtc().millisecondsSinceEpoch,
        'ended_at_utc': endedAt?.toUtc().millisecondsSinceEpoch,
      });
      await _insertMetrics(
        txn,
        sessionId: sessionId,
        itemId: activityItemId,
        effortId: effortId,
        metrics: metrics,
      );
    });
    return effortId;
  }

  Future<void> recordItemMetrics({
    required String sessionId,
    required String activityItemId,
    required List<ActivityMetricInput> metrics,
  }) => _database.transaction(
    (txn) => _insertMetrics(
      txn,
      sessionId: sessionId,
      itemId: activityItemId,
      metrics: metrics,
    ),
  );

  Future<void> completeSession(String sessionId, {DateTime? endedAt}) async {
    final ended = (endedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      final changed = await txn.update(
        'activity_sessions',
        {'status': 'completed', 'ended_at_utc': ended},
        where: "id = ? AND status = 'active'",
        whereArgs: [sessionId],
      );
      if (changed != 1) throw StateError('Active session not found.');
    });
  }

  static Future<void> _insertMetrics(
    DatabaseExecutor db, {
    required String sessionId,
    required String itemId,
    String? effortId,
    required List<ActivityMetricInput> metrics,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final metric in metrics) {
      await db.insert('activity_metric_values', {
        'id': UuidV4.generate(),
        'session_id': sessionId,
        'activity_item_id': itemId,
        'effort_id': effortId,
        'metric_code': metric.metricCode,
        'canonical_value': metric.canonicalValue,
        'entered_value': metric.enteredValue,
        'entered_unit_code': metric.enteredUnitCode,
        'source': metric.source,
        'recorded_at_utc': now,
      });
    }
  }

  static List<String> _validateTags(Iterable<String> tags) {
    final normalized = tags.toSet().toList();
    if (normalized.isEmpty ||
        normalized.length > 2 ||
        !normalized.any(_domains.contains)) {
      throw ArgumentError(
        'A session requires one domain and at most two tags.',
      );
    }
    normalized.sort((a, b) {
      final ad = _domains.contains(a);
      final bd = _domains.contains(b);
      return ad == bd ? 0 : (ad ? -1 : 1);
    });
    return normalized;
  }
}

class ActivityMetricInput {
  const ActivityMetricInput({
    required this.metricCode,
    required this.canonicalValue,
    required this.enteredValue,
    required this.enteredUnitCode,
    this.source = 'manual',
  });

  final String metricCode;
  final double canonicalValue;
  final double enteredValue;
  final String enteredUnitCode;
  final String source;
}
