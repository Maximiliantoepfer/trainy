import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/workout_plan.dart';

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
    String? sourceLocalId,
    DateTime? startedAt,
  }) async {
    final normalizedTags = _validateTags(tags);
    final start = (startedAt ?? DateTime.now()).toUtc();
    final localStart = startedAt ?? DateTime.now();
    final id = UuidV4.generate();
    await _database.transaction((txn) async {
      await txn.insert('activity_sessions', {
        'id': id,
        'source_local_id': sourceLocalId,
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
    String? sourceLocalId,
    int sortOrder = 0,
  }) async {
    final id = UuidV4.generate();
    await _database.transaction((txn) async {
      await txn.insert('activity_items', {
        'id': id,
        'session_id': sessionId,
        'source_local_id': sourceLocalId,
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

  Future<void> putEffort({
    required String effortId,
    required String sessionId,
    required String activityItemId,
    String effortType = 'set',
    int sortOrder = 0,
    required List<ActivityMetricInput> metrics,
  }) async {
    await _database.transaction((txn) async {
      await txn.insert('activity_efforts', {
        'id': effortId,
        'activity_item_id': activityItemId,
        'effort_type': effortType,
        'sort_order': sortOrder,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'activity_metric_values',
        where: 'effort_id = ?',
        whereArgs: [effortId],
      );
      await _insertMetrics(
        txn,
        sessionId: sessionId,
        itemId: activityItemId,
        effortId: effortId,
        metrics: metrics,
      );
    });
  }

  Future<void> removeEffort(String effortId) => _database.transaction(
    (txn) =>
        txn.delete('activity_efforts', where: 'id = ?', whereArgs: [effortId]),
  );

  Future<StartedWorkoutActivity> startWorkoutActivity({
    required int localWorkoutId,
    required String nameSnapshot,
    required String activityType,
    required List<String> tags,
    required List<ActivityItemSnapshotInput> items,
    String? workoutId,
    String? workoutVariantId,
    String? profileId,
    DateTime? startedAt,
    List<WorkoutSessionPlanGroup> groups = const [],
    Map<String, Object?>? selectionSnapshot,
  }) async {
    final normalizedTags = _validateTags(tags);
    final localStart = startedAt ?? DateTime.now();
    final sessionId = UuidV4.generate();
    final itemIds = <int, String>{};
    await _database.transaction((txn) async {
      await txn.insert('activity_sessions', {
        'id': sessionId,
        'source_local_id': '$localWorkoutId',
        'workout_id': workoutId,
        'workout_variant_id': workoutVariantId,
        'profile_id': profileId,
        'activity_type': activityType,
        'status': 'active',
        'source': 'manual',
        'name_snapshot': nameSnapshot,
        'started_at_utc': localStart.toUtc().millisecondsSinceEpoch,
        'timezone_offset_minutes': localStart.timeZoneOffset.inMinutes,
        'created_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
      for (var index = 0; index < normalizedTags.length; index++) {
        await txn.insert('activity_session_tags', {
          'session_id': sessionId,
          'tag_code': normalizedTags[index],
          'position': index,
        });
      }
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final id = UuidV4.generate();
        itemIds[item.localExerciseId] = id;
        await txn.insert('activity_items', {
          'id': id,
          'session_id': sessionId,
          'source_local_id': '${item.localExerciseId}',
          'catalog_id_snapshot': item.catalogId,
          'display_name_snapshot': item.displayName,
          'movement_family_snapshot': item.movementFamily,
          'equipment_snapshot': item.equipment,
          'sort_order': index,
        });
      }
      if (selectionSnapshot != null) {
        await _writePlanSnapshot(txn, sessionId, groups, selectionSnapshot);
      }
    });
    return StartedWorkoutActivity(
      sessionId: sessionId,
      activityItemIds: Map.unmodifiable(itemIds),
    );
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

  Future<void> savePlanSnapshot({
    required String sessionId,
    required List<WorkoutSessionPlanGroup> groups,
    required Map<String, Object?> selection,
  }) => _database.transaction((txn) async {
    final session = await txn.query(
      'activity_sessions',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (session.isEmpty || session.single['status'] != 'active') {
      throw StateError('Session is not active.');
    }
    await _writePlanSnapshot(txn, sessionId, groups, selection);
  });

  static Future<void> _writePlanSnapshot(
    DatabaseExecutor txn,
    String sessionId,
    List<WorkoutSessionPlanGroup> groups,
    Map<String, Object?> selection,
  ) async {
    await txn.update(
      'activity_sessions',
      {'selection_snapshot': jsonEncode(selection)},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    final slotSelections = Map<String, dynamic>.from(
      selection['slots'] as Map? ?? {},
    );
    final groupSelections = Map<String, dynamic>.from(
      selection['groups'] as Map? ?? {},
    );
    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      final id = '$sessionId:group:${group.workoutGroupId}';
      final values = <String, Object?>{
        'session_id': sessionId,
        'name_snapshot': group.name,
        'sort_order': index,
        'plan_snapshot': jsonEncode(group.toJson()),
      };
      final changed = await txn.update(
        'activity_session_groups',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) {
        await txn.insert('activity_session_groups', {'id': id, ...values});
      }
      final selected =
          groupSelections['${group.workoutGroupId}'] ??
          group.selectedGroupVariantId;
      for (final variant in group.variants.where((v) => v.id == selected)) {
        for (final slot in variant.slots) {
          final exerciseId = slotSelections['${slot.id}'] ?? slot.exerciseId;
          await txn.update(
            'activity_items',
            {'session_group_id': id},
            where: 'session_id = ? AND source_local_id = ?',
            whereArgs: [sessionId, '$exerciseId'],
          );
        }
      }
    }
  }

  Future<void> completeSession(String sessionId, {DateTime? endedAt}) async {
    final ended = (endedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      final changed = await txn.update(
        'activity_sessions',
        {'status': 'completed', 'ended_at_utc': ended},
        where: "id = ? AND status IN ('active','completed')",
        whereArgs: [sessionId],
      );
      if (changed != 1) throw StateError('Session not found.');
    });
  }

  Future<void> discardSession(String sessionId) async {
    await _database.update(
      'activity_sessions',
      {
        'status': 'discarded',
        'ended_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: "id = ? AND status = 'active'",
      whereArgs: [sessionId],
    );
  }

  Future<RestorableActivitySession?> latestActiveWorkout() async {
    final sessions = await _database.query(
      'activity_sessions',
      where:
          "status = 'active' AND source = 'manual' AND source_local_id IS NOT NULL",
      orderBy: 'started_at_utc DESC',
      limit: 1,
    );
    if (sessions.isEmpty) return null;
    final session = sessions.single;
    final sessionId = session['id'] as String;
    final groupRows = await _database.query(
      'activity_session_groups',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC, id ASC',
    );
    final items = await _database.query(
      'activity_items',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC',
    );
    final efforts = await _database.rawQuery(
      '''SELECT effort.*, metric.metric_code, metric.entered_value,
                metric.entered_unit_code
         FROM activity_efforts effort
         LEFT JOIN activity_metric_values metric ON metric.effort_id = effort.id
         INNER JOIN activity_items item ON item.id = effort.activity_item_id
         WHERE item.session_id = ?
         ORDER BY item.sort_order, effort.sort_order, metric.metric_code''',
      [sessionId],
    );
    return RestorableActivitySession(
      sessionId: sessionId,
      localWorkoutId: int.parse(session['source_local_id'] as String),
      profileId: session['profile_id'] as String?,
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(
            (session['started_at_utc'] as num).toInt(),
            isUtc: true,
          ).toLocal(),
      items: items,
      efforts: efforts,
      groups: [
        for (final row in groupRows)
          if (row['plan_snapshot'] != null)
            WorkoutSessionPlanGroup.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(row['plan_snapshot'] as String) as Map,
              ),
            ),
      ],
      selection:
          session['selection_snapshot'] == null
              ? const {}
              : Map<String, dynamic>.from(
                jsonDecode(session['selection_snapshot'] as String) as Map,
              ),
      setupId: session['workout_variant_id'] as String?,
      nameSnapshot: session['name_snapshot'] as String,
    );
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

class ActivityItemSnapshotInput {
  const ActivityItemSnapshotInput({
    required this.localExerciseId,
    required this.displayName,
    this.catalogId,
    this.movementFamily,
    this.equipment,
  });

  final int localExerciseId;
  final String displayName;
  final String? catalogId;
  final String? movementFamily;
  final String? equipment;
}

class StartedWorkoutActivity {
  const StartedWorkoutActivity({
    required this.sessionId,
    required this.activityItemIds,
  });

  final String sessionId;
  final Map<int, String> activityItemIds;
}

class RestorableActivitySession {
  const RestorableActivitySession({
    required this.sessionId,
    required this.localWorkoutId,
    required this.startedAt,
    required this.items,
    required this.efforts,
    this.profileId,
    this.setupId,
    this.groups = const [],
    this.selection = const {},
    this.nameSnapshot,
  });

  final String sessionId;
  final int localWorkoutId;
  final String? profileId;
  final String? setupId;
  final String? nameSnapshot;
  final List<WorkoutSessionPlanGroup> groups;
  final Map<String, dynamic> selection;
  final DateTime startedAt;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> efforts;
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
