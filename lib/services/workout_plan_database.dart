import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/workout_plan.dart';
import 'app_database.dart';

/// Local persistence for profiles and non-destructive workout variations.
class WorkoutPlanDatabase {
  WorkoutPlanDatabase._();
  static final instance = WorkoutPlanDatabase._();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<TrainingProfile>> profiles() async {
    final rows = await (await _db).query(
      'training_profiles',
      where: 'isArchived = 0',
      orderBy: 'sort ASC, name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => TrainingProfile(
            id: (row['id'] as num).toInt(),
            name: row['name'] as String,
            equipmentCodes: List<String>.from(
              jsonDecode(row['equipmentCodesJson'] as String) as List,
            ),
            isArchived: (row['isArchived'] as num).toInt() == 1,
            sort: (row['sort'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<void> saveProfile(TrainingProfile profile) async {
    await (await _db).insert('training_profiles', {
      'id': profile.id,
      'name': profile.name.trim(),
      'equipmentCodesJson': jsonEncode(profile.equipmentCodes),
      'isArchived': profile.isArchived ? 1 : 0,
      'sort': profile.sort,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorkoutVariant>> variantsForWorkout(int workoutId) async {
    final rows = await (await _db).query(
      'workout_variants',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'sort ASC, name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => WorkoutVariant(
            id: (row['id'] as num).toInt(),
            workoutId: workoutId,
            name: row['name'] as String,
            profileId: row['profileId'] as int?,
            sort: (row['sort'] as num).toInt(),
            isDefault: (row['isDefault'] as num).toInt() == 1,
          ),
        )
        .toList();
  }

  Future<void> saveVariant(WorkoutVariant value) async {
    final db = await _db;
    await db.transaction((txn) async {
      if (value.isDefault) {
        await txn.update(
          'workout_variants',
          {'isDefault': 0},
          where: 'workoutId = ?',
          whereArgs: [value.workoutId],
        );
      }
      await txn.insert('workout_variants', {
        'id': value.id,
        'workoutId': value.workoutId,
        'name': value.name.trim(),
        'profileId': value.profileId,
        'sort': value.sort,
        'isDefault': value.isDefault ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Creates a new workout preset from the current default preset.  A preset
  /// is deliberately a selection of group variants, not a copy of the
  /// exercises themselves; editing a reusable group therefore remains
  /// consistent wherever that group is selected.
  Future<WorkoutVariant> createVariantFromDefault({
    required int workoutId,
    required String name,
    int? profileId,
  }) async {
    final db = await _db;
    final variants = await variantsForWorkout(workoutId);
    final source = variants.firstWhere(
      (value) => value.isDefault,
      orElse: () => variants.first,
    );
    final id = DateTime.now().microsecondsSinceEpoch;
    final selections = await db.query(
      'workout_variant_group_selections',
      where: 'workoutVariantId = ?',
      whereArgs: [source.id],
    );
    await db.transaction((txn) async {
      await txn.insert('workout_variants', {
        'id': id,
        'workoutId': workoutId,
        'name': name.trim(),
        'profileId': profileId,
        'sort': variants.length,
        'isDefault': 0,
      });
      for (final selection in selections) {
        await txn.insert('workout_variant_group_selections', {
          'workoutVariantId': id,
          'workoutGroupId': selection['workoutGroupId'],
          'groupVariantId': selection['groupVariantId'],
        });
      }
    });
    return WorkoutVariant(
      id: id,
      workoutId: workoutId,
      name: name.trim(),
      profileId: profileId,
      sort: variants.length,
    );
  }

  /// Converts a legacy flat workout into one default group/variant lazily.
  /// No historical data is touched and existing workout order is retained.
  Future<void> bootstrapLegacyPlan({
    required int workoutId,
    required List<int> exerciseIds,
  }) async {
    final db = await _db;
    final existing = await db.query(
      'workout_variants',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await _syncLegacyDefaultSlots(db, workoutId, exerciseIds);
      return;
    }
    final base = DateTime.now().microsecondsSinceEpoch;
    final variantId = base;
    final groupId = base + 1;
    final groupVariantId = base + 2;
    await db.transaction((txn) async {
      await txn.insert('workout_variants', {
        'id': variantId,
        'workoutId': workoutId,
        'name': 'Standard',
        'sort': 0,
        'isDefault': 1,
      });
      await txn.insert('workout_groups', {
        'id': groupId,
        'workoutId': workoutId,
        'name': 'Main',
        'sort': 0,
      });
      await txn.insert('workout_group_variants', {
        'id': groupVariantId,
        'workoutGroupId': groupId,
        'name': 'Standard',
        'sort': 0,
      });
      await txn.insert('workout_variant_group_selections', {
        'workoutVariantId': variantId,
        'workoutGroupId': groupId,
        'groupVariantId': groupVariantId,
      });
      for (var index = 0; index < exerciseIds.length; index++) {
        await txn.insert('workout_slots', {
          'id': base + 100 + index,
          'groupVariantId': groupVariantId,
          'exerciseId': exerciseIds[index],
          'slotKind': 'core',
          'sort': index,
        });
      }
    });
  }

  /// The old editor still owns the flat exercise list.  Until a user creates
  /// dedicated group variants, new entries in that list must also appear in
  /// the lazy default plan.  We only add missing entries: removing one from
  /// the old flat list must never silently delete a slot from a curated plan.
  Future<void> _syncLegacyDefaultSlots(
    Database db,
    int workoutId,
    List<int> exerciseIds,
  ) async {
    final selected = await db.rawQuery(
      '''
      SELECT selection.groupVariantId
      FROM workout_variant_group_selections selection
      INNER JOIN workout_variants variant
        ON variant.id = selection.workoutVariantId
      WHERE variant.workoutId = ?
      ORDER BY variant.isDefault DESC, variant.sort ASC
      LIMIT 1
      ''',
      [workoutId],
    );
    if (selected.isEmpty) {
      // Builds created during the first, interrupted rollout could contain a
      // named variant without any group selection.  Recover it locally by
      // attaching every such legacy preset to one shared default group rather
      // than launching an empty workout.
      final variants = await db.query(
        'workout_variants',
        columns: ['id'],
        where: 'workoutId = ?',
        whereArgs: [workoutId],
      );
      if (variants.isEmpty) return;
      final base = DateTime.now().microsecondsSinceEpoch;
      final groupId = base;
      final groupVariantId = base + 1;
      await db.transaction((txn) async {
        await txn.insert('workout_groups', {
          'id': groupId,
          'workoutId': workoutId,
          'name': 'Main',
          'sort': 0,
        });
        await txn.insert('workout_group_variants', {
          'id': groupVariantId,
          'workoutGroupId': groupId,
          'name': 'Standard',
          'sort': 0,
        });
        for (final variant in variants) {
          await txn.insert('workout_variant_group_selections', {
            'workoutVariantId': variant['id'],
            'workoutGroupId': groupId,
            'groupVariantId': groupVariantId,
          });
        }
        for (var index = 0; index < exerciseIds.length; index++) {
          await txn.insert('workout_slots', {
            'id': base + 100 + index,
            'groupVariantId': groupVariantId,
            'exerciseId': exerciseIds[index],
            'slotKind': 'core',
            'sort': index,
          });
        }
      });
      return;
    }
    final groupVariantId = (selected.single['groupVariantId'] as num).toInt();
    final rows = await db.query(
      'workout_slots',
      columns: ['exerciseId', 'sort'],
      where: 'groupVariantId = ?',
      whereArgs: [groupVariantId],
      orderBy: 'sort ASC',
    );
    final existingIds =
        rows.map((row) => (row['exerciseId'] as num).toInt()).toSet();
    var sort = rows.isEmpty ? 0 : (rows.last['sort'] as num).toInt() + 1;
    final base = DateTime.now().microsecondsSinceEpoch;
    await db.transaction((txn) async {
      var offset = 0;
      for (final exerciseId in exerciseIds) {
        if (!existingIds.add(exerciseId)) continue;
        await txn.insert('workout_slots', {
          'id': base + offset++,
          'groupVariantId': groupVariantId,
          'exerciseId': exerciseId,
          'slotKind': 'core',
          'sort': sort++,
        });
      }
    });
  }

  Future<List<WorkoutSlot>> slotsForVariant(
    int workoutVariantId, {
    bool includeOptional = true,
  }) async {
    final rows = await (await _db).rawQuery(
      '''
      SELECT slots.* FROM workout_slots slots
      INNER JOIN workout_variant_group_selections selected
        ON selected.groupVariantId = slots.groupVariantId
      WHERE selected.workoutVariantId = ?
      ${includeOptional ? '' : "AND slots.slotKind = 'core'"}
      ORDER BY selected.workoutGroupId ASC, slots.sort ASC
    ''',
      [workoutVariantId],
    );
    return rows
        .map(
          (row) => WorkoutSlot(
            id: (row['id'] as num).toInt(),
            groupVariantId: (row['groupVariantId'] as num).toInt(),
            exerciseId: (row['exerciseId'] as num).toInt(),
            movementFamilyId: row['movementFamilyId'] as String?,
            isOptional: row['slotKind'] == 'optional',
            sort: (row['sort'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<WorkoutSlotAlternative>> alternativesForSlot(int slotId) async {
    final rows = await (await _db).query(
      'workout_slot_alternatives',
      where: 'workoutSlotId = ?',
      whereArgs: [slotId],
      orderBy: 'sort ASC',
    );
    return rows
        .map(
          (row) => WorkoutSlotAlternative(
            id: (row['id'] as num).toInt(),
            workoutSlotId: slotId,
            exerciseId: (row['exerciseId'] as num).toInt(),
            profileId: row['profileId'] as int?,
            sort: (row['sort'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<Map<int, int>> groupSelectionsForVariant(int workoutVariantId) async {
    final rows = await (await _db).query(
      'workout_variant_group_selections',
      where: 'workoutVariantId = ?',
      whereArgs: [workoutVariantId],
    );
    return {
      for (final row in rows)
        (row['workoutGroupId'] as num).toInt():
            (row['groupVariantId'] as num).toInt(),
    };
  }

  Future<List<WorkoutGroup>> groupsForWorkout(int workoutId) async {
    final rows = await (await _db).query(
      'workout_groups',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'sort ASC, name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => WorkoutGroup(
            id: (row['id'] as num).toInt(),
            workoutId: workoutId,
            name: row['name'] as String,
            muscleGroupCode: row['muscleGroupCode'] as String?,
            sort: (row['sort'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<WorkoutGroupVariant>> groupVariantsForGroup(int groupId) async {
    final rows = await (await _db).query(
      'workout_group_variants',
      where: 'workoutGroupId = ?',
      whereArgs: [groupId],
      orderBy: 'sort ASC, name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => WorkoutGroupVariant(
            id: (row['id'] as num).toInt(),
            workoutGroupId: groupId,
            name: row['name'] as String,
            profileId: row['profileId'] as int?,
            sort: (row['sort'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<WorkoutSlot>> slotsForGroupVariant(int groupVariantId) async {
    final rows = await (await _db).query(
      'workout_slots',
      where: 'groupVariantId = ?',
      whereArgs: [groupVariantId],
      orderBy: 'sort ASC',
    );
    return rows
        .map(
          (row) => WorkoutSlot(
            id: (row['id'] as num).toInt(),
            groupVariantId: groupVariantId,
            exerciseId: (row['exerciseId'] as num).toInt(),
            movementFamilyId: row['movementFamilyId'] as String?,
            isOptional: row['slotKind'] == 'optional',
            sort: (row['sort'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<WorkoutGroup> createGroup({
    required int workoutId,
    required String name,
  }) async {
    final db = await _db;
    final id = DateTime.now().microsecondsSinceEpoch;
    final variantId = id + 1;
    final existingGroups = await groupsForWorkout(workoutId);
    final variants = await variantsForWorkout(workoutId);
    await db.transaction((txn) async {
      await txn.insert('workout_groups', {
        'id': id,
        'workoutId': workoutId,
        'name': name.trim(),
        'sort': existingGroups.length,
      });
      await txn.insert('workout_group_variants', {
        'id': variantId,
        'workoutGroupId': id,
        'name': 'Standard',
        'sort': 0,
      });
      for (final variant in variants) {
        await txn.insert('workout_variant_group_selections', {
          'workoutVariantId': variant.id,
          'workoutGroupId': id,
          'groupVariantId': variantId,
        });
      }
    });
    return WorkoutGroup(
      id: id,
      workoutId: workoutId,
      name: name.trim(),
      sort: existingGroups.length,
    );
  }

  Future<WorkoutGroupVariant> createGroupVariant({
    required int groupId,
    required String name,
    int? profileId,
    int? copyFromGroupVariantId,
  }) async {
    final db = await _db;
    final existing = await groupVariantsForGroup(groupId);
    final id = DateTime.now().microsecondsSinceEpoch;
    final sourceId = copyFromGroupVariantId;
    await db.transaction((txn) async {
      await txn.insert('workout_group_variants', {
        'id': id,
        'workoutGroupId': groupId,
        'name': name.trim(),
        'profileId': profileId,
        'sort': existing.length,
      });
      if (sourceId == null) return;
      final sourceSlots = await txn.query(
        'workout_slots',
        where: 'groupVariantId = ?',
        whereArgs: [sourceId],
        orderBy: 'sort ASC',
      );
      for (var index = 0; index < sourceSlots.length; index++) {
        final slot = sourceSlots[index];
        // Reserve a small ID range per copied slot for its alternatives.
        // This avoids a primary-slot ID colliding with the next alternative.
        final slotId = id + 100000 + index * 100;
        await txn.insert('workout_slots', {
          'id': slotId,
          'groupVariantId': id,
          'exerciseId': slot['exerciseId'],
          'movementFamilyId': slot['movementFamilyId'],
          'slotKind': slot['slotKind'],
          'sort': slot['sort'],
        });
        final alternatives = await txn.query(
          'workout_slot_alternatives',
          where: 'workoutSlotId = ?',
          whereArgs: [slot['id']],
          orderBy: 'sort ASC',
        );
        for (
          var alternativeIndex = 0;
          alternativeIndex < alternatives.length;
          alternativeIndex++
        ) {
          final alternative = alternatives[alternativeIndex];
          await txn.insert('workout_slot_alternatives', {
            'id': slotId + alternativeIndex + 1,
            'workoutSlotId': slotId,
            'exerciseId': alternative['exerciseId'],
            'profileId': alternative['profileId'],
            'sort': alternative['sort'],
          });
        }
      }
    });
    return WorkoutGroupVariant(
      id: id,
      workoutGroupId: groupId,
      name: name.trim(),
      profileId: profileId,
      sort: existing.length,
    );
  }

  Future<void> selectGroupVariantForWorkoutVariant({
    required int workoutVariantId,
    required int workoutGroupId,
    required int groupVariantId,
  }) async {
    await (await _db).insert(
      'workout_variant_group_selections',
      {
        'workoutVariantId': workoutVariantId,
        'workoutGroupId': workoutGroupId,
        'groupVariantId': groupVariantId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Replaces editable plan slots only. Past sessions remain intact because
  /// they store executed exercise IDs and a separate session snapshot.
  Future<void> replaceGroupVariantSlots({
    required int groupVariantId,
    required List<WorkoutSlot> slots,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final current = await txn.query(
        'workout_slots',
        where: 'groupVariantId = ?',
        whereArgs: [groupVariantId],
      );
      final retainedIds = slots.map((slot) => slot.id).toSet();
      for (final currentSlot in current) {
        final id = (currentSlot['id'] as num).toInt();
        if (retainedIds.contains(id)) continue;
        await txn.delete(
          'workout_slot_alternatives',
          where: 'workoutSlotId = ?',
          whereArgs: [id],
        );
        await txn.delete('workout_slots', where: 'id = ?', whereArgs: [id]);
      }
      for (final slot in slots) {
        await txn.insert('workout_slots', {
          'id': slot.id,
          'groupVariantId': groupVariantId,
          'exerciseId': slot.exerciseId,
          'movementFamilyId': slot.movementFamilyId,
          'slotKind': slot.isOptional ? 'optional' : 'core',
          'sort': slot.sort,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> replaceSlotAlternatives({
    required int workoutSlotId,
    required List<int> exerciseIds,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'workout_slot_alternatives',
        where: 'workoutSlotId = ?',
        whereArgs: [workoutSlotId],
      );
      final base = DateTime.now().microsecondsSinceEpoch;
      for (var index = 0; index < exerciseIds.length; index++) {
        await txn.insert('workout_slot_alternatives', {
          'id': base + index,
          'workoutSlotId': workoutSlotId,
          'exerciseId': exerciseIds[index],
          'sort': index,
        });
      }
    });
  }

  Future<void> saveSlot(WorkoutSlot slot) async =>
      (await _db).insert('workout_slots', {
        'id': slot.id,
        'groupVariantId': slot.groupVariantId,
        'exerciseId': slot.exerciseId,
        'movementFamilyId': slot.movementFamilyId,
        'slotKind': slot.isOptional ? 'optional' : 'core',
        'sort': slot.sort,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveSlotAlternative(WorkoutSlotAlternative value) async =>
      (await _db).insert('workout_slot_alternatives', {
        'id': value.id,
        'workoutSlotId': value.workoutSlotId,
        'exerciseId': value.exerciseId,
        'profileId': value.profileId,
        'sort': value.sort,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> selectSessionSlotExercise({
    required int sessionId,
    required int workoutSlotId,
    required int exerciseId,
  }) async {
    await (await _db).insert(
      'workout_session_slot_selections',
      {
        'sessionId': sessionId,
        'workoutSlotId': workoutSlotId,
        'exerciseId': exerciseId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> selectSessionGroupVariant({
    required int sessionId,
    required int workoutGroupId,
    required int groupVariantId,
  }) async {
    await (await _db).insert(
      'workout_session_group_selections',
      {
        'sessionId': sessionId,
        'workoutGroupId': workoutGroupId,
        'groupVariantId': groupVariantId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WorkoutSessionSnapshot> createSession({
    required int workoutId,
    required List<int> executedExerciseIds,
    int? workoutVariantId,
    int? profileId,
    Map<int, int> groupSelections = const {},
    Map<int, int> slotSelections = const {},
  }) async {
    final db = await _db;
    final id = DateTime.now().microsecondsSinceEpoch;
    final startedAt = DateTime.now();
    final snapshot = jsonEncode({
      'exerciseIds': executedExerciseIds,
      'groupSelections': groupSelections.map(
        (key, value) => MapEntry('$key', value),
      ),
      'slotSelections': slotSelections.map(
        (key, value) => MapEntry('$key', value),
      ),
    });
    await db.transaction((txn) async {
      await txn.insert('workout_sessions', {
        'id': id,
        'workoutId': workoutId,
        'workoutVariantId': workoutVariantId,
        'profileId': profileId,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'snapshotJson': snapshot,
      });
      for (final entry in groupSelections.entries) {
        await txn.insert('workout_session_group_selections', {
          'sessionId': id,
          'workoutGroupId': entry.key,
          'groupVariantId': entry.value,
        });
      }
      for (final entry in slotSelections.entries) {
        await txn.insert('workout_session_slot_selections', {
          'sessionId': id,
          'workoutSlotId': entry.key,
          'exerciseId': entry.value,
        });
      }
    });
    return WorkoutSessionSnapshot(
      id: id,
      workoutId: workoutId,
      workoutVariantId: workoutVariantId,
      profileId: profileId,
      startedAt: startedAt,
      snapshotJson: snapshot,
    );
  }

  Future<void> completeSession(int sessionId) async => (await _db).update(
    'workout_sessions',
    {'completedAt': DateTime.now().millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [sessionId],
  );
}
