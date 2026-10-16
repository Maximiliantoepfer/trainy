import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/training_profile.dart';
import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../services/database_service.dart';
import '../utils/uuid_v4.dart';

/// The only writer for workout templates, setups and the recurring weekly
/// schedule.  The integer tables are maintained solely as a short-term
/// runtime facade for the already-shipped workout runner.
class WorkoutPlanningRepository {
  WorkoutPlanningRepository({DatabaseService? database})
    : _database = database ?? DatabaseService();

  final DatabaseService _database;

  Future<List<Workout>> workouts() async {
    final rows = await _database.rawQuery('''
      SELECT template.*
      FROM workout_templates template
      WHERE template.is_archived = 0
      ORDER BY template.name COLLATE NOCASE ASC
      ''');
    final schedules = await _database.query(
      'workout_weekly_schedule',
      orderBy: 'weekday ASC, sort_order ASC, id ASC',
    );
    final scheduleByWorkout = <String, List<Map<String, Object?>>>{};
    for (final schedule in schedules) {
      final id = schedule['workout_id'] as String;
      scheduleByWorkout.putIfAbsent(id, () => []).add(schedule);
    }
    final result = <Workout>[];
    for (final row in rows) {
      final canonicalId = row['id'] as String;
      final localId = row['legacy_local_id'] as int?;
      if (localId == null) continue;
      final schedule = scheduleByWorkout[canonicalId] ?? const [];
      final exerciseIds = await _defaultExerciseIds(canonicalId);
      result.add(
        Workout(
          id: localId,
          canonicalId: canonicalId,
          name: row['name'] as String,
          description: row['description'] as String? ?? '',
          exerciseIds: exerciseIds,
          assignedDays: schedule
              .map((value) => (value['weekday'] as num).toInt())
              .toSet(),
          primaryGoalCode: row['primary_goal_code'] as String? ?? 'strength',
          scheduleOrderByDay: {
            for (final value in schedule)
              (value['weekday'] as num).toInt():
                  (value['sort_order'] as num).toInt(),
          },
        ),
      );
    }
    return result;
  }

  Future<Workout> createWorkout(WorkoutEditorDraft draft) async {
    final cleanName = draft.name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(draft.name, 'name');
    final cleanSetupName = draft.setupName.trim();
    if (cleanSetupName.isEmpty) {
      throw ArgumentError.value(draft.setupName, 'setupName');
    }
    final canonicalId = UuidV4.generate();
    final setupId = UuidV4.generate();
    final groupId = UuidV4.generate();
    final groupVariantId = UuidV4.generate();
    final localId = DateTime.now().microsecondsSinceEpoch;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      await txn.insert('workout_templates', {
        'id': canonicalId,
        'legacy_local_id': localId,
        'name': cleanName,
        'description': draft.description.trim(),
        'primary_goal_code': draft.primaryGoal.code,
        'source_type': 'custom',
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _replaceWorkoutTags(txn, canonicalId, draft.primaryGoal);
      await txn.insert('workouts', {
        'id': localId,
        'name': cleanName,
        'description': draft.description.trim(),
        'goalCodes': jsonEncode(draft.primaryGoal.statisticTags),
      });
      await txn.insert('workout_variants_v2', {
        'id': setupId,
        'workout_id': canonicalId,
        'profile_id': draft.profileId,
        'name': cleanSetupName,
        'is_default': 1,
        'sort_order': 0,
      });
      await txn.insert('workout_groups_v2', {
        'id': groupId,
        'workout_id': canonicalId,
        'name': 'Main',
        'sort_order': 0,
      });
      await txn.insert('workout_group_variants_v2', {
        'id': groupVariantId,
        'workout_group_id': groupId,
        'profile_id': draft.profileId,
        'name': cleanSetupName,
        'sort_order': 0,
      });
      await txn.insert('workout_variant_group_selections_v2', {
        'workout_variant_id': setupId,
        'workout_group_id': groupId,
        'group_variant_id': groupVariantId,
      });
      for (var index = 0; index < draft.exerciseIds.length; index++) {
        final canonicalExerciseId = await _ensureCanonicalExercise(
          txn,
          draft.exerciseIds[index],
          now,
        );
        if (canonicalExerciseId == null) continue;
        await txn.insert('workout_slots_v2', {
          'id': UuidV4.generate(),
          'group_variant_id': groupVariantId,
          'exercise_id': canonicalExerciseId,
          'slot_kind': 'core',
          'sort_order': index,
        });
        await txn.insert('exercises_in_workouts', {
          'id': localId + index + 1,
          'workoutId': localId,
          'exerciseId': draft.exerciseIds[index],
          'sort': index,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return Workout(
      id: localId,
      canonicalId: canonicalId,
      name: cleanName,
      description: draft.description.trim(),
      exerciseIds: List<int>.from(draft.exerciseIds),
      primaryGoalCode: draft.primaryGoal.code,
    );
  }

  Future<void> updateBasics({
    required Workout workout,
    required String name,
    String? description,
    WorkoutPrimaryGoal? primaryGoal,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      final nextGoal = primaryGoal ?? WorkoutPrimaryGoal.fromCode(workout.primaryGoalCode);
      await txn.update(
        'workout_templates',
        {
          'name': cleanName,
          if (description != null) 'description': description.trim(),
          'primary_goal_code': nextGoal.code,
          'updated_at_utc': now,
        },
        where: 'id = ?',
        whereArgs: [workout.canonicalId],
      );
      await _replaceWorkoutTags(txn, workout.canonicalId, nextGoal);
      await txn.update(
        'workouts',
        {
          'name': cleanName,
          if (description != null) 'description': description.trim(),
          'goalCodes': jsonEncode(nextGoal.statisticTags),
        },
        where: 'id = ?',
        whereArgs: [workout.id],
      );
    });
  }

  Future<void> archiveWorkout(Workout workout) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      await txn.update(
        'workout_templates',
        {'is_archived': 1, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [workout.canonicalId],
      );
      await txn.update(
        'workouts',
        {'isArchived': 1},
        where: 'id = ?',
        whereArgs: [workout.id],
      );
    });
  }

  Future<List<WorkoutSetup>> setupsForWorkout(String workoutId) async {
    final setupRows = await _database.rawQuery('''
      SELECT setup.*, profile.name AS profile_name, profile.is_archived AS profile_archived,
             profile.sort_order AS profile_sort, profile.created_at_utc AS profile_created,
             profile.updated_at_utc AS profile_updated
      FROM workout_variants_v2 setup
      LEFT JOIN training_profiles_v2 profile ON profile.id = setup.profile_id
      WHERE setup.workout_id = ?
      ORDER BY setup.is_default DESC, setup.sort_order ASC, setup.name COLLATE NOCASE ASC
      ''', [workoutId]);
    final profiles = <String, TrainingProfileRecord>{};
    final profileEquipment = await _database.query('training_profile_equipment');
    final equipmentByProfile = <String, Set<String>>{};
    for (final row in profileEquipment) {
      equipmentByProfile
          .putIfAbsent(row['profile_id'] as String, () => <String>{})
          .add(row['equipment_code'] as String);
    }
    final result = <WorkoutSetup>[];
    for (final setup in setupRows) {
      final profileId = setup['profile_id'] as String?;
      TrainingProfileRecord? profile;
      if (profileId != null && setup['profile_name'] is String) {
        profile = profiles.putIfAbsent(
          profileId,
          () => TrainingProfileRecord(
            id: profileId,
            name: setup['profile_name'] as String,
            equipmentCodes: Set.unmodifiable(equipmentByProfile[profileId] ?? const <String>{}),
            isArchived: (setup['profile_archived'] as num?)?.toInt() == 1,
            sortOrder: (setup['profile_sort'] as num?)?.toInt() ?? 0,
            createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
              (setup['profile_created'] as num?)?.toInt() ?? 0,
              isUtc: true,
            ),
            updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
              (setup['profile_updated'] as num?)?.toInt() ?? 0,
              isUtc: true,
            ),
          ),
        );
      }
      result.add(
        WorkoutSetup(
          id: setup['id'] as String,
          workoutId: workoutId,
          name: setup['name'] as String,
          profile: profile,
          sortOrder: (setup['sort_order'] as num).toInt(),
          isDefault: (setup['is_default'] as num).toInt() == 1,
          groups: await _groupsForSetup(setup['id'] as String, workoutId),
        ),
      );
    }
    return result;
  }

  Future<WorkoutSetup> createSetup({
    required String workoutId,
    required String name,
    String? profileId,
    String? copyFromSetupId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name');
    final setupId = UuidV4.generate();
    await _database.transaction((txn) async {
      final countRows = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM workout_variants_v2 WHERE workout_id = ?',
        [workoutId],
      );
      final sort = (countRows.single['count'] as num).toInt();
      await txn.insert('workout_variants_v2', {
        'id': setupId,
        'workout_id': workoutId,
        'profile_id': profileId,
        'name': cleanName,
        'sort_order': sort,
        'is_default': 0,
      });
      final groups = await txn.query(
        'workout_groups_v2',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );
      for (final group in groups) {
        final groupId = group['id'] as String;
        String? sourceVariantId;
        if (copyFromSetupId != null) {
          final selected = await txn.query(
            'workout_variant_group_selections_v2',
            columns: const ['group_variant_id'],
            where: 'workout_variant_id = ? AND workout_group_id = ?',
            whereArgs: [copyFromSetupId, groupId],
            limit: 1,
          );
          sourceVariantId = selected.isEmpty
              ? null
              : selected.single['group_variant_id'] as String;
        }
        sourceVariantId ??= await _firstGroupVariantId(txn, groupId);
        if (sourceVariantId != null) {
          await txn.insert('workout_variant_group_selections_v2', {
            'workout_variant_id': setupId,
            'workout_group_id': groupId,
            'group_variant_id': sourceVariantId,
          });
        }
      }
    });
    return (await setupsForWorkout(workoutId)).firstWhere(
      (setup) => setup.id == setupId,
    );
  }

  Future<void> replaceSetupExercises({
    required String setupId,
    required List<int> exerciseIds,
  }) async {
    await _database.transaction((txn) async {
      final selected = await txn.query(
        'workout_variant_group_selections_v2',
        columns: const ['workout_group_id', 'group_variant_id'],
        where: 'workout_variant_id = ?',
        whereArgs: [setupId],
        orderBy: 'workout_group_id ASC',
        limit: 1,
      );
      if (selected.isEmpty) throw StateError('Setup has no exercise group.');
      final groupVariantId = selected.single['group_variant_id'] as String;
      await txn.delete(
        'workout_slots_v2',
        where: 'group_variant_id = ?',
        whereArgs: [groupVariantId],
      );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (var index = 0; index < exerciseIds.length; index++) {
        final canonicalId = await _ensureCanonicalExercise(txn, exerciseIds[index], now);
        if (canonicalId == null) continue;
        await txn.insert('workout_slots_v2', {
          'id': UuidV4.generate(),
          'group_variant_id': groupVariantId,
          'exercise_id': canonicalId,
          'slot_kind': 'core',
          'sort_order': index,
        });
      }
      final workoutRows = await txn.query(
        'workout_variants_v2',
        columns: const ['workout_id'],
        where: 'id = ?',
        whereArgs: [setupId],
        limit: 1,
      );
      final workoutId = workoutRows.single['workout_id'] as String;
      final localRows = await txn.query(
        'workout_templates',
        columns: const ['legacy_local_id'],
        where: 'id = ?',
        whereArgs: [workoutId],
        limit: 1,
      );
      final localWorkoutId = localRows.single['legacy_local_id'] as int?;
      if (localWorkoutId != null) {
        await txn.delete('exercises_in_workouts', where: 'workoutId = ?', whereArgs: [localWorkoutId]);
        for (var index = 0; index < exerciseIds.length; index++) {
          await txn.insert('exercises_in_workouts', {
            'id': localWorkoutId + index + 1,
            'workoutId': localWorkoutId,
            'exerciseId': exerciseIds[index],
            'sort': index,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> replaceDefaultExercises({
    required String workoutId,
    required List<int> exerciseIds,
  }) async {
    final setups = await setupsForWorkout(workoutId);
    if (setups.isEmpty) throw StateError('Workout has no setup.');
    await replaceSetupExercises(setupId: setups.first.id, exerciseIds: exerciseIds);
  }

  Future<void> replaceWorkoutDays({
    required String workoutId,
    required Set<int> weekdays,
  }) async {
    if (weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    await _database.transaction((txn) async {
      final existing = await txn.query(
        'workout_weekly_schedule',
        columns: const ['id', 'weekday'],
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );
      for (final row in existing) {
        final day = (row['weekday'] as num).toInt();
        if (!weekdays.contains(day)) {
          await txn.delete(
            'workout_weekly_schedule',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      for (final day in weekdays) {
        final exists = existing.any(
          (row) => (row['weekday'] as num).toInt() == day,
        );
        if (exists) continue;
        final rows = await _dayRows(txn, day);
        await txn.insert('workout_weekly_schedule', {
          'id': UuidV4.generate(),
          'workout_id': workoutId,
          'weekday': day,
          'sort_order': rows.length,
        });
      }
    });
  }

  Future<void> setSlotOptional(String slotId, bool optional) =>
      _database.update(
        'workout_slots_v2',
        {'slot_kind': optional ? 'optional' : 'core'},
        where: 'id = ?',
        whereArgs: [slotId],
      );

  Future<void> createGroup({
    required String workoutId,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name');
    await _database.transaction((txn) async {
      final count = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM workout_groups_v2 WHERE workout_id = ?',
        [workoutId],
      );
      final groupId = UuidV4.generate();
      final groupVariantId = UuidV4.generate();
      await txn.insert('workout_groups_v2', {
        'id': groupId,
        'workout_id': workoutId,
        'name': cleanName,
        'sort_order': (count.single['count'] as num).toInt(),
      });
      await txn.insert('workout_group_variants_v2', {
        'id': groupVariantId,
        'workout_group_id': groupId,
        'name': cleanName,
        'sort_order': 0,
      });
      final setups = await txn.query(
        'workout_variants_v2',
        columns: const ['id'],
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );
      for (final setup in setups) {
        await txn.insert('workout_variant_group_selections_v2', {
          'workout_variant_id': setup['id'],
          'workout_group_id': groupId,
          'group_variant_id': groupVariantId,
        });
      }
    });
  }

  Future<void> moveSlotToGroup({
    required String slotId,
    required String setupId,
    required String targetGroupId,
  }) async {
    await _database.transaction((txn) async {
      final selection = await txn.query(
        'workout_variant_group_selections_v2',
        columns: const ['group_variant_id'],
        where: 'workout_variant_id = ? AND workout_group_id = ?',
        whereArgs: [setupId, targetGroupId],
        limit: 1,
      );
      if (selection.isEmpty) throw StateError('Target group is unavailable.');
      await txn.update(
        'workout_slots_v2',
        {'group_variant_id': selection.single['group_variant_id']},
        where: 'id = ?',
        whereArgs: [slotId],
      );
    });
  }

  Future<void> removeSlot(String slotId) => _database.delete(
    'workout_slots_v2',
    where: 'id = ?',
    whereArgs: [slotId],
  );

  Future<void> addSlotAlternative({
    required String slotId,
    required int localExerciseId,
    String? profileId,
  }) async {
    await _database.transaction((txn) async {
      final exerciseId = await _ensureCanonicalExercise(
        txn,
        localExerciseId,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      if (exerciseId == null) throw StateError('Exercise no longer exists.');
      final count = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM workout_slot_alternatives_v2 WHERE workout_slot_id = ?',
        [slotId],
      );
      await txn.insert('workout_slot_alternatives_v2', {
        'id': UuidV4.generate(),
        'workout_slot_id': slotId,
        'exercise_id': exerciseId,
        'profile_id': profileId,
        'sort_order': (count.single['count'] as num).toInt(),
      });
    });
  }

  Future<List<WeeklyWorkoutPlacement>> weeklyPlacements() async {
    final rows = await _database.query(
      'workout_weekly_schedule',
      orderBy: 'weekday ASC, sort_order ASC, id ASC',
    );
    return rows
        .map(
          (row) => WeeklyWorkoutPlacement(
            id: row['id'] as String,
            workoutId: row['workout_id'] as String,
            weekday: (row['weekday'] as num).toInt(),
            sortOrder: (row['sort_order'] as num).toInt(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> assignToDay({
    required String workoutId,
    required int weekday,
    int? index,
  }) async {
    _assertWeekday(weekday);
    await _database.transaction((txn) async {
      final existing = await txn.query(
        'workout_weekly_schedule',
        columns: const ['id'],
        where: 'workout_id = ? AND weekday = ?',
        whereArgs: [workoutId, weekday],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError('A workout may occur only once per weekday.');
      }
      final rows = List<Map<String, Object?>>.from(
        await _dayRows(txn, weekday),
      );
      final insertion = (index ?? rows.length).clamp(0, rows.length);
      rows.insert(insertion, {'id': UuidV4.generate(), 'workout_id': workoutId});
      await _writeDayRows(txn, weekday, rows);
    });
  }

  Future<void> removePlacement(String placementId) async {
    await _database.transaction((txn) async {
      final current = await txn.query(
        'workout_weekly_schedule',
        where: 'id = ?',
        whereArgs: [placementId],
        limit: 1,
      );
      if (current.isEmpty) return;
      final weekday = (current.single['weekday'] as num).toInt();
      await txn.delete('workout_weekly_schedule', where: 'id = ?', whereArgs: [placementId]);
      await _writeDayRows(txn, weekday, await _dayRows(txn, weekday));
    });
  }

  Future<void> movePlacement({
    required String placementId,
    required int targetWeekday,
    required int targetIndex,
  }) async {
    _assertWeekday(targetWeekday);
    await _database.transaction((txn) async {
      final current = await txn.query(
        'workout_weekly_schedule',
        where: 'id = ?',
        whereArgs: [placementId],
        limit: 1,
      );
      if (current.isEmpty) throw StateError('Weekly placement no longer exists.');
      final sourceWeekday = (current.single['weekday'] as num).toInt();
      final workoutId = current.single['workout_id'] as String;
      final alreadyAtTarget = await txn.query(
        'workout_weekly_schedule',
        columns: const ['id'],
        where: 'workout_id = ? AND weekday = ? AND id != ?',
        whereArgs: [workoutId, targetWeekday, placementId],
        limit: 1,
      );
      if (alreadyAtTarget.isNotEmpty) {
        throw StateError('A workout may occur only once per weekday.');
      }
      final source = List<Map<String, Object?>>.from(
        await _dayRows(txn, sourceWeekday),
      );
      source.removeWhere((value) => value['id'] == placementId);
      if (sourceWeekday == targetWeekday) {
        final index = targetIndex.clamp(0, source.length);
        source.insert(index, {'id': placementId, 'workout_id': workoutId});
        await _writeDayRows(txn, sourceWeekday, source);
        return;
      }
      final target = List<Map<String, Object?>>.from(
        await _dayRows(txn, targetWeekday),
      );
      target.insert(targetIndex.clamp(0, target.length), {
        'id': placementId,
        'workout_id': workoutId,
      });
      await _writeDayRows(txn, sourceWeekday, source);
      await _writeDayRows(txn, targetWeekday, target);
    });
  }

  Future<WorkoutLaunchPlan> launchPlanForSetup(String setupId) async {
    final setupRows = await _database.query(
      'workout_variants_v2',
      columns: const ['workout_id'],
      where: 'id = ?',
      whereArgs: [setupId],
      limit: 1,
    );
    if (setupRows.isEmpty) throw StateError('Workout setup no longer exists.');
    final setup = (await setupsForWorkout(
      setupRows.single['workout_id'] as String,
    )).firstWhere((value) => value.id == setupId);
    final exercises = <int>[];
    final optional = <String>{};
    for (final group in setup.groups) {
      for (final slot in group.selectedVariant.slots) {
        if (slot.isOptional) optional.add(slot.id);
        exercises.add(slot.localExerciseId);
      }
    }
    return WorkoutLaunchPlan(
      setup: setup,
      exerciseIds: exercises,
      optionalSlotIds: optional,
    );
  }

  Future<List<int>> _defaultExerciseIds(String workoutId) async {
    final setups = await setupsForWorkout(workoutId);
    if (setups.isEmpty) return const [];
    return setups.first.groups
        .expand((group) => group.selectedVariant.slots)
        .map((slot) => slot.localExerciseId)
        .toList(growable: false);
  }

  Future<List<WorkoutSetupGroup>> _groupsForSetup(
    String setupId,
    String workoutId,
  ) async {
    final groups = await _database.query(
      'workout_groups_v2',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    final selectedRows = await _database.query(
      'workout_variant_group_selections_v2',
      where: 'workout_variant_id = ?',
      whereArgs: [setupId],
    );
    final selectedByGroup = {
      for (final row in selectedRows)
        row['workout_group_id'] as String: row['group_variant_id'] as String,
    };
    final result = <WorkoutSetupGroup>[];
    for (final group in groups) {
      final groupId = group['id'] as String;
      final variantRows = await _database.query(
        'workout_group_variants_v2',
        where: 'workout_group_id = ?',
        whereArgs: [groupId],
        orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
      );
      final variants = <WorkoutSetupGroupVariant>[];
      for (final variant in variantRows) {
        final variantId = variant['id'] as String;
        final slots = await _slotsForGroupVariant(variantId);
        variants.add(
          WorkoutSetupGroupVariant(
            id: variantId,
            name: variant['name'] as String,
            profileId: variant['profile_id'] as String?,
            sortOrder: (variant['sort_order'] as num).toInt(),
            slots: slots,
          ),
        );
      }
      if (variants.isEmpty) continue;
      result.add(
        WorkoutSetupGroup(
          id: groupId,
          name: group['name'] as String,
          muscleGroupCode: group['muscle_group_code'] as String?,
          sortOrder: (group['sort_order'] as num).toInt(),
          selectedVariantId: selectedByGroup[groupId] ?? variants.first.id,
          variants: variants,
        ),
      );
    }
    return result;
  }

  Future<List<WorkoutSetupSlot>> _slotsForGroupVariant(String groupVariantId) async {
    final slots = await _database.rawQuery('''
      SELECT slot.*, item.legacy_local_id
      FROM workout_slots_v2 slot
      INNER JOIN exercise_items item ON item.id = slot.exercise_id
      WHERE slot.group_variant_id = ?
      ORDER BY slot.sort_order ASC, slot.id ASC
      ''', [groupVariantId]);
    final alternatives = await _database.rawQuery('''
      SELECT alternative.workout_slot_id, item.legacy_local_id
      FROM workout_slot_alternatives_v2 alternative
      INNER JOIN exercise_items item ON item.id = alternative.exercise_id
      WHERE alternative.workout_slot_id IN (
        SELECT id FROM workout_slots_v2 WHERE group_variant_id = ?
      )
      ORDER BY alternative.sort_order ASC, alternative.id ASC
      ''', [groupVariantId]);
    final alternativesBySlot = <String, List<int>>{};
    for (final alternative in alternatives) {
      final localId = alternative['legacy_local_id'] as int?;
      if (localId != null) {
        alternativesBySlot
            .putIfAbsent(alternative['workout_slot_id'] as String, () => <int>[])
            .add(localId);
      }
    }
    return slots
        .where((slot) => slot['legacy_local_id'] is int)
        .map(
          (slot) => WorkoutSetupSlot(
            id: slot['id'] as String,
            exerciseId: slot['exercise_id'] as String,
            localExerciseId: slot['legacy_local_id'] as int,
            isOptional: slot['slot_kind'] == 'optional',
            sortOrder: (slot['sort_order'] as num).toInt(),
            movementFamilyId: slot['movement_family_id'] as String?,
            alternativeLocalExerciseIds:
                alternativesBySlot[slot['id'] as String] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  static Future<String?> _firstGroupVariantId(
    DatabaseExecutor db,
    String groupId,
  ) async {
    final rows = await db.query(
      'workout_group_variants_v2',
      columns: const ['id'],
      where: 'workout_group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sort_order ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id'] as String;
  }

  static Future<void> _replaceWorkoutTags(
    DatabaseExecutor db,
    String workoutId,
    WorkoutPrimaryGoal goal,
  ) async {
    await db.delete('workout_tags', where: 'workout_id = ?', whereArgs: [workoutId]);
    for (var index = 0; index < goal.statisticTags.length; index++) {
      await db.insert('workout_tags', {
        'workout_id': workoutId,
        'tag_code': goal.statisticTags[index],
        'position': index,
      });
    }
  }

  static Future<String?> _ensureCanonicalExercise(
    DatabaseExecutor db,
    int legacyExerciseId,
    int now,
  ) async {
    final current = await db.query(
      'exercise_items',
      columns: const ['id'],
      where: 'legacy_local_id = ?',
      whereArgs: [legacyExerciseId],
      limit: 1,
    );
    if (current.isNotEmpty) return current.single['id'] as String;
    final legacy = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [legacyExerciseId],
      limit: 1,
    );
    if (legacy.isEmpty) return null;
    final row = legacy.single;
    final catalogId = row['catalogId'] as String?;
    final byCatalog = catalogId == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'exercise_items',
            columns: const ['id'],
            where: 'catalog_id = ?',
            whereArgs: [catalogId],
            limit: 1,
          );
    final id = byCatalog.isEmpty ? 'legacy-exercise:$legacyExerciseId' : byCatalog.single['id'] as String;
    final goal = _legacyGoal(row['goalCodes'], row['goal']);
    if (byCatalog.isEmpty) {
      final isCatalog = catalogId != null && catalogId.isNotEmpty;
      await db.insert('exercise_items', {
        'id': id,
        'legacy_local_id': legacyExerciseId,
        'source_type': isCatalog ? 'catalog' : 'custom',
        'catalog_id': isCatalog ? catalogId : null,
        'custom_name': isCatalog ? null : row['name'] as String,
        'custom_description': isCatalog ? null : row['description'] as String? ?? '',
        'personal_alias': row['alias'] as String?,
        'notes': row['notes'] as String? ?? '',
        'tracking_mode': goal == WorkoutPrimaryGoal.mobility ? 'mobility' : goal == WorkoutPrimaryGoal.strength ? 'strength' : 'cardio',
        'is_archived': (row['isArchived'] as num?)?.toInt() ?? 0,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
    } else {
      await db.update('exercise_items', {'legacy_local_id': legacyExerciseId}, where: 'id = ?', whereArgs: [id]);
    }
    await db.delete('exercise_tags', where: 'exercise_id = ?', whereArgs: [id]);
    for (var index = 0; index < goal.statisticTags.length; index++) {
      await db.insert('exercise_tags', {
        'exercise_id': id,
        'tag_code': goal.statisticTags[index],
        'position': index,
      });
    }
    return id;
  }

  static WorkoutPrimaryGoal _legacyGoal(Object? raw, Object? fallback) {
    final values = <String>[];
    if (raw is String) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) values.addAll(parsed.map((value) => '$value'));
      } catch (_) {}
    }
    if (fallback is String) values.add(fallback);
    for (final goal in const [
      WorkoutPrimaryGoal.strength,
      WorkoutPrimaryGoal.endurance,
      WorkoutPrimaryGoal.cardio,
      WorkoutPrimaryGoal.mobility,
    ]) {
      if (values.contains(goal.code) ||
          (goal == WorkoutPrimaryGoal.strength && values.contains('Kraft')) ||
          (goal == WorkoutPrimaryGoal.endurance && values.contains('Ausdauer')) ||
          (goal == WorkoutPrimaryGoal.cardio && values.contains('Cardio')) ||
          (goal == WorkoutPrimaryGoal.mobility && values.contains('Mobilität'))) {
        return goal;
      }
    }
    return WorkoutPrimaryGoal.strength;
  }

  static void _assertWeekday(int value) {
    if (value < 1 || value > 7) throw ArgumentError.value(value, 'weekday');
  }

  static Future<List<Map<String, Object?>>> _dayRows(
    DatabaseExecutor db,
    int weekday,
  ) => db.query(
    'workout_weekly_schedule',
    columns: const ['id', 'workout_id'],
    where: 'weekday = ?',
    whereArgs: [weekday],
    orderBy: 'sort_order ASC, id ASC',
  );

  static Future<void> _writeDayRows(
    DatabaseExecutor db,
    int weekday,
    List<Map<String, Object?>> values,
  ) async {
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      await db.insert('workout_weekly_schedule', {
        'id': value['id'],
        'workout_id': value['workout_id'],
        'weekday': weekday,
        'sort_order': index,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
