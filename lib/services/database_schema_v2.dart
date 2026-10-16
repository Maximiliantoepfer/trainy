import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// The first schema in data epoch 2.
///
/// The canonical v2 tables use UUID text identifiers. A small set of legacy
/// facade tables remains while the existing screens are moved repository by
/// repository. They are created empty after the epoch reset and are included
/// here so the application remains usable during that transition.
abstract final class DatabaseSchemaV2 {
  static const int dataEpoch = 2;
  static const int schemaVersion = 5;
  static const String schemaRevision = '2026-10-16.5';

  static const userDataTables = <String>[
    'health_record_links',
    'activity_metric_values',
    'activity_efforts',
    'activity_items',
    'activity_session_groups',
    'activity_session_tags',
    'activity_sessions',
    'training_plan_workouts',
    'training_plans',
    'workout_slot_alternatives_v2',
    'workout_slots_v2',
    'workout_variant_group_selections_v2',
    'workout_group_variants_v2',
    'workout_groups_v2',
    'workout_variants_v2',
    'workout_weekly_schedule',
    'workout_tags',
    'workout_templates',
    'exercise_redirects_v2',
    'duplicate_suggestions_v2',
    'catalog_exercise_preferences',
    'exercise_images_v2',
    'exercise_metric_configs',
    'exercise_tags',
    'exercise_items',
    'selected_training_profile',
    'training_profile_equipment',
    'training_profiles_v2',
    // Temporary application facade tables.
    'workout_session_slot_selections',
    'workout_session_group_selections',
    'workout_entries',
    'workout_sessions',
    'workout_slot_alternatives',
    'workout_slots',
    'workout_variant_group_selections',
    'workout_group_variants',
    'workout_groups',
    'workout_variants',
    'training_profiles',
    'exercise_redirects',
    'duplicate_suggestions',
    'exercise_images',
    'exercise_goal_labels',
    'pinned_charts',
    'workout_day_assignments',
    'merge_history',
    'seeded_standards',
    'exercises_in_workouts',
    'workouts',
    'exercises',
    'user_settings',
  ];

  static Future<void> create(DatabaseExecutor db) async {
    // openDatabase already wraps onCreate in a transaction; nesting a second
    // sqflite transaction can deadlock on Android.
    for (final statement in _tableStatements) {
      await db.execute(statement);
    }
    for (final statement in _indexStatements) {
      await db.execute(statement);
    }
    for (final statement in _triggerStatements) {
      await db.execute(statement);
    }
    await _seedReferenceData(db);
  }

  /// Applies non-destructive schema upgrades inside data epoch 2.
  ///
  /// An epoch mismatch is intentionally not migrated here. The lifecycle
  /// coordinator decides whether an older epoch may be replaced.
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    final epoch = await readEpoch(db);
    if (epoch != dataEpoch) {
      throw DatabaseEpochMismatch(epoch);
    }
    if (oldVersion < 2) {
      await db.execute('''CREATE TABLE IF NOT EXISTS selected_training_profile(
        id INTEGER PRIMARY KEY CHECK(id = 0),
        profile_id TEXT,
        FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE SET NULL
      )''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_selected_profile_profile ON selected_training_profile(profile_id)',
      );
      if (!await _columnExists(db, 'activity_items', 'source_local_id')) {
        await db.execute(
          'ALTER TABLE activity_items ADD COLUMN source_local_id TEXT',
        );
      }
      if (!await _columnExists(db, 'activity_sessions', 'source_local_id')) {
        await db.execute(
          'ALTER TABLE activity_sessions ADD COLUMN source_local_id TEXT',
        );
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_items_source_local ON activity_items(source_local_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_sessions_source_local ON activity_sessions(source_local_id)',
      );
      await db.execute('''DELETE FROM workout_entries
        WHERE sessionId IS NOT NULL AND id NOT IN (
          SELECT MAX(id) FROM workout_entries
          WHERE sessionId IS NOT NULL
          GROUP BY sessionId, exerciseId
        )''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_entries_session_exercise_unique ON workout_entries(sessionId, exerciseId) WHERE sessionId IS NOT NULL',
      );
      await migrateLegacyProfiles(db);
    }
    if (oldVersion < 3) {
      await _upgradeToWorkoutWorkflowV3(db);
    }
    if (oldVersion < 4) {
      await _upgradeToMobileWorkoutWorkflowV4(db);
    }
    if (oldVersion < 5) {
      if (!await _columnExists(
        db,
        'activity_session_groups',
        'plan_snapshot',
      )) {
        await db.execute(
          'ALTER TABLE activity_session_groups ADD COLUMN plan_snapshot TEXT',
        );
      }
      if (!await _columnExists(db, 'activity_sessions', 'selection_snapshot')) {
        await db.execute(
          'ALTER TABLE activity_sessions ADD COLUMN selection_snapshot TEXT',
        );
      }
      await normalizeWorkoutGroupOrder(db);
    }
    await _writeCurrentMetadata(db);
  }

  /// Also used after importing a schema-4 backup into a staging database.
  static Future<void> normalizeWorkoutGroupOrder(DatabaseExecutor db) async {
    final workouts = await db.query('workout_templates', columns: ['id']);
    for (final workout in workouts) {
      final groups = await db.query(
        'workout_groups_v2',
        where: 'workout_id = ?',
        whereArgs: [workout['id']],
        orderBy:
            "CASE group_kind WHEN 'warmup' THEN 0 WHEN 'cooldown' THEN 2 ELSE 1 END, sort_order, id",
      );
      for (var i = 0; i < groups.length; i++) {
        await db.update(
          'workout_groups_v2',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [groups[i]['id']],
        );
      }
    }
  }

  /// Separates setup contents that were formerly shared through a group
  /// variant.  A setup is now a concrete training environment: changing its
  /// exercise list can never change another profile's setup.
  static Future<void> _upgradeToMobileWorkoutWorkflowV4(Database db) async {
    if (!await _columnExists(db, 'workout_groups_v2', 'group_kind')) {
      await db.execute(
        "ALTER TABLE workout_groups_v2 ADD COLUMN group_kind TEXT NOT NULL DEFAULT 'custom' CHECK(group_kind IN ('warmup','core','cooldown','custom'))",
      );
    }
    if (!await _columnExists(
      db,
      'workout_group_variants_v2',
      'owner_setup_id',
    )) {
      await db.execute(
        'ALTER TABLE workout_group_variants_v2 ADD COLUMN owner_setup_id TEXT',
      );
    }

    // "Main" was an implementation detail and must never reach the UI.
    await db.update(
      'workout_groups_v2',
      {'group_kind': 'core', 'name': 'core'},
      where: 'lower(trim(name)) IN (?, ?)',
      whereArgs: const ['main', 'kernuebungen'],
    );

    // Retain every former duplicate setup.  Only one can stay linked to a
    // concrete profile; later rows become intentionally profile-free.
    final duplicateProfiles = await db.rawQuery('''
      SELECT workout_id, profile_id
      FROM workout_variants_v2
      WHERE profile_id IS NOT NULL
      GROUP BY workout_id, profile_id
      HAVING COUNT(*) > 1
      ''');
    for (final duplicate in duplicateProfiles) {
      final rows = await db.query(
        'workout_variants_v2',
        columns: const ['id'],
        where: 'workout_id = ? AND profile_id = ?',
        whereArgs: [duplicate['workout_id'], duplicate['profile_id']],
        orderBy: 'is_default DESC, sort_order ASC, id ASC',
      );
      for (final row in rows.skip(1)) {
        await db.update(
          'workout_variants_v2',
          {'profile_id': null},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }

    final workouts = await db.query('workout_templates', columns: const ['id']);
    for (final workout in workouts) {
      final workoutId = workout['id'] as String;
      final groups = await db.query(
        'workout_groups_v2',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
        orderBy: 'sort_order ASC, id ASC',
      );
      final byKind = <String, Map<String, Object?>>{};
      for (final group in groups) {
        byKind.putIfAbsent(
          group['group_kind'] as String? ?? 'custom',
          () => group,
        );
      }
      for (final entry in const [
        ('warmup', 0),
        ('core', 1),
        ('cooldown', 999999),
      ]) {
        if (byKind.containsKey(entry.$1)) {
          continue;
        }
        final id = '$workoutId:group:${entry.$1}';
        await db.insert('workout_groups_v2', {
          'id': id,
          'workout_id': workoutId,
          'name': entry.$1,
          'group_kind': entry.$1,
          'sort_order': entry.$2,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final allGroups = await db.query(
        'workout_groups_v2',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
        orderBy: 'sort_order ASC, id ASC',
      );
      final setups = await db.query(
        'workout_variants_v2',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
        orderBy: 'sort_order ASC, id ASC',
      );
      for (final setup in setups) {
        final setupId = setup['id'] as String;
        for (final group in allGroups) {
          final groupId = group['id'] as String;
          final selected = await db.query(
            'workout_variant_group_selections_v2',
            where: 'workout_variant_id = ? AND workout_group_id = ?',
            whereArgs: [setupId, groupId],
            limit: 1,
          );
          final sourceId =
              selected.isEmpty
                  ? null
                  : selected.single['group_variant_id'] as String;
          final ownedId = '$setupId:group:$groupId';
          final source =
              sourceId == null
                  ? const <Map<String, Object?>>[]
                  : await db.query(
                    'workout_group_variants_v2',
                    where: 'id = ?',
                    whereArgs: [sourceId],
                    limit: 1,
                  );
          await db.insert(
            'workout_group_variants_v2',
            {
              'id': ownedId,
              'workout_group_id': groupId,
              'profile_id': setup['profile_id'],
              'owner_setup_id': setupId,
              'name':
                  source.isEmpty
                      ? (group['name'] as String)
                      : source.single['name'] as String,
              'sort_order': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (sourceId != null) {
            final slots = await db.query(
              'workout_slots_v2',
              where: 'group_variant_id = ?',
              whereArgs: [sourceId],
              orderBy: 'sort_order ASC, id ASC',
            );
            for (final slot in slots) {
              final oldSlotId = slot['id'] as String;
              final newSlotId = '$ownedId:slot:$oldSlotId';
              await db.insert('workout_slots_v2', {
                'id': newSlotId,
                'group_variant_id': ownedId,
                'exercise_id': slot['exercise_id'],
                'movement_family_id': slot['movement_family_id'],
                'slot_kind': slot['slot_kind'],
                'sort_order': slot['sort_order'],
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
              final alternatives = await db.query(
                'workout_slot_alternatives_v2',
                where: 'workout_slot_id = ?',
                whereArgs: [oldSlotId],
              );
              for (final alternative in alternatives) {
                await db.insert(
                  'workout_slot_alternatives_v2',
                  {
                    'id': '$newSlotId:alternative:${alternative['id']}',
                    'workout_slot_id': newSlotId,
                    'exercise_id': alternative['exercise_id'],
                    'profile_id': alternative['profile_id'],
                    'sort_order': alternative['sort_order'],
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }
            }
          }
          await db.insert(
            'workout_variant_group_selections_v2',
            {
              'workout_variant_id': setupId,
              'workout_group_id': groupId,
              'group_variant_id': ownedId,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_variants_unique_profile_per_workout ON workout_variants_v2(workout_id, profile_id) WHERE profile_id IS NOT NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_group_variants_owner_group ON workout_group_variants_v2(owner_setup_id, workout_group_id) WHERE owner_setup_id IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_groups_kind ON workout_groups_v2(workout_id, group_kind, sort_order)',
    );
  }

  /// Brings the remaining integer facade rows into the canonical workout
  /// graph.  The facade is intentionally kept read-only for older releases,
  /// but every new workflow operation uses the UUID tables from here on.
  static Future<void> _upgradeToWorkoutWorkflowV3(Database db) async {
    if (!await _columnExists(db, 'exercise_items', 'legacy_local_id')) {
      await db.execute(
        'ALTER TABLE exercise_items ADD COLUMN legacy_local_id INTEGER',
      );
    }
    if (!await _columnExists(db, 'workout_templates', 'legacy_local_id')) {
      await db.execute(
        'ALTER TABLE workout_templates ADD COLUMN legacy_local_id INTEGER',
      );
    }
    if (!await _columnExists(db, 'workout_templates', 'primary_goal_code')) {
      await db.execute(
        "ALTER TABLE workout_templates ADD COLUMN primary_goal_code TEXT NOT NULL DEFAULT 'strength' CHECK(primary_goal_code IN ('strength','endurance','cardio','mobility'))",
      );
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercise_items_legacy_local ON exercise_items(legacy_local_id) WHERE legacy_local_id IS NOT NULL',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_templates_legacy_local ON workout_templates(legacy_local_id) WHERE legacy_local_id IS NOT NULL',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS workout_weekly_schedule(
      id TEXT PRIMARY KEY,
      workout_id TEXT NOT NULL,
      weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7),
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(workout_id, weekday),
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE CASCADE
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_weekly_schedule_workout ON workout_weekly_schedule(workout_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_weekly_schedule_day_order ON workout_weekly_schedule(weekday, sort_order, id)',
    );
    await migrateLegacyProfiles(db);
    await _migrateLegacyWorkoutPlanning(db);
  }

  static Future<void> _migrateLegacyWorkoutPlanning(Database db) async {
    if (!await _tableExists(db, 'exercises') ||
        !await _tableExists(db, 'workouts')) {
      return;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final exerciseRows = await db.query('exercises');
    final exerciseIds = <int, String>{};
    for (final row in exerciseRows) {
      final localId = (row['id'] as num).toInt();
      final catalogId = row['catalogId'] as String?;
      final existingByLocal = await db.query(
        'exercise_items',
        columns: const ['id'],
        where: 'legacy_local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      final existingByCatalog =
          catalogId == null
              ? const <Map<String, Object?>>[]
              : await db.query(
                'exercise_items',
                columns: const ['id'],
                where: 'catalog_id = ?',
                whereArgs: [catalogId],
                limit: 1,
              );
      final canonicalId =
          existingByLocal.isNotEmpty
              ? existingByLocal.single['id']! as String
              : existingByCatalog.isNotEmpty
              ? existingByCatalog.single['id']! as String
              : 'legacy-exercise:$localId';
      final goalCodes = _legacyGoalCodes(row['goalCodes'], row['goal']);
      if (existingByLocal.isEmpty && existingByCatalog.isEmpty) {
        final isCatalog = catalogId != null && catalogId.isNotEmpty;
        await db.insert('exercise_items', {
          'id': canonicalId,
          'legacy_local_id': localId,
          'source_type': isCatalog ? 'catalog' : 'custom',
          'catalog_id': isCatalog ? catalogId : null,
          'custom_name': isCatalog ? null : (row['name'] as String),
          'custom_description':
              isCatalog ? null : (row['description'] as String? ?? ''),
          'personal_alias': row['alias'] as String?,
          'notes': row['notes'] as String? ?? '',
          'tracking_mode': _trackingModeForGoals(goalCodes),
          'is_archived': (row['isArchived'] as num?)?.toInt() ?? 0,
          'created_at_utc': now,
          'updated_at_utc': now,
        });
      } else {
        await db.update(
          'exercise_items',
          {'legacy_local_id': localId, 'updated_at_utc': now},
          where: 'id = ?',
          whereArgs: [canonicalId],
        );
      }
      await _replaceCanonicalTags(
        db,
        table: 'exercise_tags',
        idColumn: 'exercise_id',
        entityId: canonicalId,
        goals: _statisticsGoals(_primaryGoal(goalCodes)),
      );
      exerciseIds[localId] = canonicalId;
    }

    final workoutRows = await db.query('workouts');
    final workoutIds = <int, String>{};
    for (final row in workoutRows) {
      final localId = (row['id'] as num).toInt();
      final existing = await db.query(
        'workout_templates',
        columns: const ['id'],
        where: 'legacy_local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      final workoutId =
          existing.isEmpty
              ? 'legacy-workout:$localId'
              : existing.single['id']! as String;
      final goals = _legacyGoalCodes(row['goalCodes'], null);
      final primary = _primaryGoal(goals);
      if (existing.isEmpty) {
        await db.insert('workout_templates', {
          'id': workoutId,
          'legacy_local_id': localId,
          'name': row['name'] as String,
          'description': row['description'] as String? ?? '',
          'primary_goal_code': primary,
          'source_type': 'custom',
          'is_archived': (row['isArchived'] as num?)?.toInt() ?? 0,
          'created_at_utc': now,
          'updated_at_utc': now,
        });
      } else {
        await db.update(
          'workout_templates',
          {
            'legacy_local_id': localId,
            'primary_goal_code': primary,
            'updated_at_utc': now,
          },
          where: 'id = ?',
          whereArgs: [workoutId],
        );
      }
      await _replaceCanonicalTags(
        db,
        table: 'workout_tags',
        idColumn: 'workout_id',
        entityId: workoutId,
        goals: _statisticsGoals(primary),
      );
      workoutIds[localId] = workoutId;
    }

    if (workoutIds.isEmpty) return;
    final variantRows = await db.query('workout_variants');
    final groupRows = await db.query('workout_groups');
    final groupVariantRows = await db.query('workout_group_variants');
    final selectionRows = await db.query('workout_variant_group_selections');
    final slotRows = await db.query('workout_slots');
    final alternativeRows = await db.query('workout_slot_alternatives');
    final variantIds = <int, String>{};
    final groupIds = <int, String>{};
    final groupVariantIds = <int, String>{};
    final slotIds = <int, String>{};

    for (final row in groupRows) {
      final localWorkoutId = (row['workoutId'] as num).toInt();
      final workoutId = workoutIds[localWorkoutId];
      if (workoutId == null) continue;
      final legacyId = (row['id'] as num).toInt();
      final id = 'legacy-workout-group:$legacyId';
      await db.insert('workout_groups_v2', {
        'id': id,
        'workout_id': workoutId,
        'name': row['name'] as String,
        'muscle_group_code': row['muscleGroupCode'] as String?,
        'sort_order': (row['sort'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      groupIds[legacyId] = id;
    }
    for (final row in groupVariantRows) {
      final legacyGroupId = (row['workoutGroupId'] as num).toInt();
      final groupId = groupIds[legacyGroupId];
      if (groupId == null) continue;
      final legacyId = (row['id'] as num).toInt();
      final id = 'legacy-group-variant:$legacyId';
      final profile = row['profileId'] as int?;
      await db.insert('workout_group_variants_v2', {
        'id': id,
        'workout_group_id': groupId,
        'profile_id': profile == null ? null : 'legacy-profile:$profile',
        'name': row['name'] as String,
        'sort_order': (row['sort'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      groupVariantIds[legacyId] = id;
    }
    for (final row in variantRows) {
      final localWorkoutId = (row['workoutId'] as num).toInt();
      final workoutId = workoutIds[localWorkoutId];
      if (workoutId == null) continue;
      final legacyId = (row['id'] as num).toInt();
      final id = 'legacy-setup:$legacyId';
      final profile = row['profileId'] as int?;
      await db.insert('workout_variants_v2', {
        'id': id,
        'workout_id': workoutId,
        'profile_id': profile == null ? null : 'legacy-profile:$profile',
        'name': row['name'] as String,
        'is_default': (row['isDefault'] as num?)?.toInt() ?? 0,
        'sort_order': (row['sort'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      variantIds[legacyId] = id;
    }
    for (final row in slotRows) {
      final legacyGroupVariantId = (row['groupVariantId'] as num).toInt();
      final groupVariantId = groupVariantIds[legacyGroupVariantId];
      final exerciseId = exerciseIds[(row['exerciseId'] as num).toInt()];
      if (groupVariantId == null || exerciseId == null) continue;
      final legacyId = (row['id'] as num).toInt();
      final id = 'legacy-slot:$legacyId';
      await db.insert('workout_slots_v2', {
        'id': id,
        'group_variant_id': groupVariantId,
        'exercise_id': exerciseId,
        'movement_family_id': row['movementFamilyId'] as String?,
        'slot_kind': row['slotKind'] as String? ?? 'core',
        'sort_order': (row['sort'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      slotIds[legacyId] = id;
    }
    for (final row in alternativeRows) {
      final slotId = slotIds[(row['workoutSlotId'] as num).toInt()];
      final exerciseId = exerciseIds[(row['exerciseId'] as num).toInt()];
      if (slotId == null || exerciseId == null) continue;
      final legacyId = (row['id'] as num).toInt();
      final profile = row['profileId'] as int?;
      await db.insert(
        'workout_slot_alternatives_v2',
        {
          'id': 'legacy-slot-alternative:$legacyId',
          'workout_slot_id': slotId,
          'exercise_id': exerciseId,
          'profile_id': profile == null ? null : 'legacy-profile:$profile',
          'sort_order': (row['sort'] as num?)?.toInt() ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final row in selectionRows) {
      final variantId = variantIds[(row['workoutVariantId'] as num).toInt()];
      final groupId = groupIds[(row['workoutGroupId'] as num).toInt()];
      final groupVariantId =
          groupVariantIds[(row['groupVariantId'] as num).toInt()];
      if (variantId == null || groupId == null || groupVariantId == null) {
        continue;
      }
      await db.insert(
        'workout_variant_group_selections_v2',
        {
          'workout_variant_id': variantId,
          'workout_group_id': groupId,
          'group_variant_id': groupVariantId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final entry in workoutIds.entries) {
      final localWorkoutId = entry.key;
      final workoutId = entry.value;
      final hasSetup = await db.query(
        'workout_variants_v2',
        columns: const ['id'],
        where: 'workout_id = ?',
        whereArgs: [workoutId],
        limit: 1,
      );
      if (hasSetup.isEmpty) {
        await _createCanonicalDefaultSetup(
          db,
          workoutId: workoutId,
          localWorkoutId: localWorkoutId,
          exerciseIds: exerciseIds,
        );
      }
    }

    final assignments = await db.query(
      'workout_day_assignments',
      orderBy: 'dayOfWeek ASC, workoutId ASC',
    );
    final nextOrder = <int, int>{};
    for (final row in assignments) {
      final workoutId = workoutIds[(row['workoutId'] as num).toInt()];
      if (workoutId == null) continue;
      final weekday = (row['dayOfWeek'] as num).toInt();
      final order = nextOrder.update(
        weekday,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      await db.insert('workout_weekly_schedule', {
        'id': 'legacy-weekly:$workoutId:$weekday',
        'workout_id': workoutId,
        'weekday': weekday,
        'sort_order': order,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _createCanonicalDefaultSetup(
    Database db, {
    required String workoutId,
    required int localWorkoutId,
    required Map<int, String> exerciseIds,
  }) async {
    final setupId = '$workoutId:setup:default';
    final groupId = '$workoutId:group:main';
    final groupVariantId = '$workoutId:group-variant:default';
    await db.insert('workout_variants_v2', {
      'id': setupId,
      'workout_id': workoutId,
      'name': 'Standard',
      'is_default': 1,
      'sort_order': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('workout_groups_v2', {
      'id': groupId,
      'workout_id': workoutId,
      'name': 'Main',
      'sort_order': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('workout_group_variants_v2', {
      'id': groupVariantId,
      'workout_group_id': groupId,
      'name': 'Standard',
      'sort_order': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(
      'workout_variant_group_selections_v2',
      {
        'workout_variant_id': setupId,
        'workout_group_id': groupId,
        'group_variant_id': groupVariantId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final mappings = await db.query(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [localWorkoutId],
      orderBy: 'sort ASC',
    );
    for (var index = 0; index < mappings.length; index++) {
      final localExerciseId = (mappings[index]['exerciseId'] as num).toInt();
      final exerciseId = exerciseIds[localExerciseId];
      if (exerciseId == null) continue;
      await db.insert('workout_slots_v2', {
        'id': '$workoutId:slot:$index',
        'group_variant_id': groupVariantId,
        'exercise_id': exerciseId,
        'slot_kind': 'core',
        'sort_order': index,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static List<String> _legacyGoalCodes(Object? raw, Object? fallback) {
    final values = <String>[];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) values.addAll(decoded.map((value) => '$value'));
      } catch (_) {}
    }
    if (fallback is String && fallback.isNotEmpty) values.add(fallback);
    final normalized = <String>[];
    for (final value in values) {
      final code = switch (value) {
        'Kraft' || 'strength' => 'strength',
        'Ausdauer' || 'endurance' => 'endurance',
        'Cardio' || 'cardio' => 'cardio',
        'Mobilität' || 'mobility' => 'mobility',
        _ => null,
      };
      if (code != null && !normalized.contains(code)) normalized.add(code);
    }
    return normalized.isEmpty ? const ['strength'] : normalized;
  }

  static String _primaryGoal(Iterable<String> goals) {
    for (final candidate in const [
      'strength',
      'endurance',
      'cardio',
      'mobility',
    ]) {
      if (goals.contains(candidate)) return candidate;
    }
    return 'strength';
  }

  static List<String> _statisticsGoals(String primary) =>
      primary == 'endurance' ? const ['cardio', 'endurance'] : [primary];

  static String _trackingModeForGoals(Iterable<String> goals) {
    if (goals.contains('strength')) {
      return 'strength';
    }
    if (goals.contains('cardio') || goals.contains('endurance')) {
      return 'cardio';
    }
    if (goals.contains('mobility')) {
      return 'mobility';
    }
    return 'mixed';
  }

  static Future<void> _replaceCanonicalTags(
    DatabaseExecutor db, {
    required String table,
    required String idColumn,
    required String entityId,
    required Iterable<String> goals,
  }) async {
    await db.delete(table, where: '$idColumn = ?', whereArgs: [entityId]);
    final normalized = goals.toSet().toList(growable: false);
    for (var index = 0; index < normalized.length && index < 2; index++) {
      await db.insert(table, {
        idColumn: entityId,
        'tag_code': normalized[index],
        'position': index,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Copies the transitional integer profile rows once into the UUID model.
  /// The operation is idempotent and never mutates or deletes the legacy row.
  static Future<int> migrateLegacyProfiles(DatabaseExecutor db) async {
    if (!await _tableExists(db, 'training_profiles')) return 0;
    final rows = await db.query('training_profiles');
    var inserted = 0;
    for (final row in rows) {
      final legacyId = (row['id'] as num).toInt();
      final profileId = 'legacy-profile:$legacyId';
      final existing = await db.query(
        'training_profiles_v2',
        columns: const ['id'],
        where: 'id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      if (existing.isEmpty) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await db.insert('training_profiles_v2', {
          'id': profileId,
          'name': (row['name'] as String).trim(),
          'is_archived': (row['isArchived'] as num?)?.toInt() ?? 0,
          'sort_order': (row['sort'] as num?)?.toInt() ?? 0,
          'created_at_utc': now,
          'updated_at_utc': now,
        });
        inserted++;
      }

      final decoded = jsonDecode(row['equipmentCodesJson'] as String? ?? '[]');
      for (final raw in decoded is List ? decoded : const <Object?>[]) {
        final normalized = normalizeEquipmentCode('$raw');
        await db.insert(
          'training_profile_equipment',
          {'profile_id': profileId, 'equipment_code': normalized},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    final selected = await db.query(
      'selected_training_profile',
      where: 'id = 0',
      limit: 1,
    );
    if (selected.isEmpty) {
      final first = await db.query(
        'training_profiles_v2',
        columns: const ['id'],
        where: 'is_archived = 0',
        orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
        limit: 1,
      );
      await db.insert('selected_training_profile', {
        'id': 0,
        'profile_id': first.isEmpty ? null : first.single['id'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return inserted;
  }

  static String normalizeEquipmentCode(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[ -]+'),
      '_',
    );
    return switch (normalized) {
      'body_only' || 'body_weight' || 'bodyweight' => 'bodyweight',
      'dumbbells' || 'dumbbell' => 'dumbbell',
      'barbells' || 'barbell' => 'barbell',
      'bench' => 'bench',
      'power_rack' || 'squat_rack' || 'rack' => 'rack',
      'pull_up_bar' || 'pullup_bar' => 'pull_up_bar',
      'cable' || 'cable_machine' => 'cable',
      'machines' || 'machine' => 'machine',
      'kettlebells' || 'kettlebell' => 'kettlebell',
      'band' || 'bands' || 'resistance_bands' => 'bands',
      'medicine_ball' => 'medicine_ball',
      'exercise_ball' || 'stability_ball' => 'exercise_ball',
      'foam_roll' || 'foam_roller' => 'foam_roller',
      'e_z_curl_bar' || 'ez_bar' => 'ez_bar',
      'mat' || 'yoga_mat' => 'mat',
      'cardio_machine' || 'cardio_equipment' => 'cardio_machine',
      'bicycle' || 'bike' || 'stationary_bike' => 'bicycle',
      'pool' || 'swimming_pool' => 'pool',
      'none' || 'unknown' => 'unknown',
      _ => 'other',
    };
  }

  static Future<int?> readEpoch(DatabaseExecutor db) async {
    if (!await _tableExists(db, 'app_meta')) return null;
    final rows = await db.query(
      'app_meta',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const ['data_epoch'],
      limit: 1,
    );
    return rows.isEmpty ? null : int.tryParse('${rows.single['value']}');
  }

  static Future<void> _writeCurrentMetadata(DatabaseExecutor db) async {
    for (final entry
        in {
          'data_epoch': '$dataEpoch',
          'schema_version': '$schemaVersion',
          'schema_revision': schemaRevision,
        }.entries) {
      await db.insert('app_meta', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  static Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async => (await db.rawQuery(
    'PRAGMA table_info($table)',
  )).any((row) => row['name'] == column);

  static Future<void> _seedReferenceData(DatabaseExecutor db) async {
    await db.insert('app_meta', {
      'key': 'data_epoch',
      'value': '$dataEpoch',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_meta', {
      'key': 'schema_version',
      'value': '$schemaVersion',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_meta', {
      'key': 'schema_revision',
      'value': schemaRevision,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('app_meta', {
      'key': 'catalog_version',
      'value': 'core-1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    const tags = [
      ('strength', 'domain', 'muscle_arm', 400),
      ('cardio', 'domain', 'heart', 300),
      ('mobility', 'domain', 'mobility', 100),
      ('endurance', 'focus', 'running', 0),
    ];
    for (final tag in tags) {
      await db.insert('tag_definitions', {
        'code': tag.$1,
        'kind': tag.$2,
        'icon_key': tag.$3,
        'priority': tag.$4,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    const metrics = [
      ('repetitions', 'integer', 'count'),
      ('weight', 'decimal', 'kg'),
      ('duration', 'duration', 'second'),
      ('distance', 'decimal', 'meter'),
      ('pace', 'decimal', 'second_per_kilometer'),
      ('heart_rate', 'integer', 'beats_per_minute'),
      ('heart_rate_zone_duration', 'duration', 'second'),
    ];
    for (final metric in metrics) {
      await db.insert('metric_definitions', {
        'code': metric.$1,
        'value_type': metric.$2,
        'base_unit_code': metric.$3,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await db.insert('user_settings', {
      'id': 0,
      'weekly_goal': 2,
      'sync_enabled': 0,
      'last_sync_millis': 0,
      'training_days': '',
      'insights_order': '',
      'onboarding_done': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static const _tableStatements = <String>[
    '''CREATE TABLE app_meta(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )''',
    '''CREATE TABLE tag_definitions(
      code TEXT PRIMARY KEY,
      kind TEXT NOT NULL CHECK(kind IN ('domain','focus')),
      icon_key TEXT NOT NULL,
      priority INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE metric_definitions(
      code TEXT PRIMARY KEY,
      value_type TEXT NOT NULL CHECK(value_type IN ('integer','decimal','duration')),
      base_unit_code TEXT NOT NULL
    )''',

    // The existing settings API deliberately remains row based. Visual and
    // locale preferences continue to live in SharedPreferences.
    '''CREATE TABLE user_settings(
      id INTEGER PRIMARY KEY CHECK(id = 0),
      weekly_goal INTEGER NOT NULL DEFAULT 2 CHECK(weekly_goal BETWEEN 1 AND 7),
      sync_enabled INTEGER NOT NULL DEFAULT 0 CHECK(sync_enabled IN (0,1)),
      last_sync_millis INTEGER NOT NULL DEFAULT 0 CHECK(last_sync_millis >= 0),
      training_days TEXT NOT NULL DEFAULT '',
      insights_order TEXT NOT NULL DEFAULT '',
      onboarding_done INTEGER NOT NULL DEFAULT 0 CHECK(onboarding_done IN (0,1))
    )''',

    // Canonical profile and exercise model.
    '''CREATE TABLE training_profiles_v2(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at_utc INTEGER NOT NULL,
      updated_at_utc INTEGER NOT NULL
    )''',
    '''CREATE TABLE training_profile_equipment(
      profile_id TEXT NOT NULL,
      equipment_code TEXT NOT NULL,
      PRIMARY KEY(profile_id, equipment_code),
      FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE selected_training_profile(
      id INTEGER PRIMARY KEY CHECK(id = 0),
      profile_id TEXT,
      FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE exercise_items(
      id TEXT PRIMARY KEY,
      legacy_local_id INTEGER,
      source_type TEXT NOT NULL CHECK(source_type IN ('catalog','custom')),
      catalog_id TEXT UNIQUE,
      custom_name TEXT,
      custom_description TEXT,
      personal_alias TEXT,
      notes TEXT NOT NULL DEFAULT '',
      icon_key TEXT,
      tracking_mode TEXT NOT NULL CHECK(tracking_mode IN ('strength','cardio','mobility','mixed')),
      is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)),
      created_at_utc INTEGER NOT NULL,
      updated_at_utc INTEGER NOT NULL,
      CHECK(
        (source_type = 'catalog' AND catalog_id IS NOT NULL AND custom_name IS NULL)
        OR
        (source_type = 'custom' AND catalog_id IS NULL AND length(trim(custom_name)) > 0)
      )
    )''',
    '''CREATE TABLE exercise_tags(
      exercise_id TEXT NOT NULL,
      tag_code TEXT NOT NULL,
      position INTEGER NOT NULL CHECK(position IN (0,1)),
      PRIMARY KEY(exercise_id, tag_code),
      UNIQUE(exercise_id, position),
      FOREIGN KEY(exercise_id) REFERENCES exercise_items(id) ON DELETE CASCADE,
      FOREIGN KEY(tag_code) REFERENCES tag_definitions(code) ON DELETE RESTRICT,
      CHECK(position = 1 OR tag_code IN ('strength','cardio','mobility'))
    )''',
    '''CREATE TABLE exercise_metric_configs(
      id TEXT PRIMARY KEY,
      exercise_id TEXT NOT NULL,
      metric_code TEXT NOT NULL,
      unit_code TEXT NOT NULL,
      input_level TEXT NOT NULL CHECK(input_level IN ('activity','exercise','effort')),
      is_required INTEGER NOT NULL DEFAULT 0 CHECK(is_required IN (0,1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      default_numeric_value REAL,
      UNIQUE(exercise_id, metric_code, input_level),
      FOREIGN KEY(exercise_id) REFERENCES exercise_items(id) ON DELETE CASCADE,
      FOREIGN KEY(metric_code) REFERENCES metric_definitions(code) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE exercise_images_v2(
      id TEXT PRIMARY KEY,
      exercise_id TEXT NOT NULL,
      relative_path TEXT NOT NULL UNIQUE,
      is_cover INTEGER NOT NULL DEFAULT 0 CHECK(is_cover IN (0,1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(exercise_id) REFERENCES exercise_items(id) ON DELETE CASCADE,
      CHECK(relative_path NOT LIKE '/%' AND relative_path NOT LIKE '%..%')
    )''',
    '''CREATE TABLE catalog_exercise_preferences(
      catalog_id TEXT PRIMARY KEY,
      is_hidden INTEGER NOT NULL DEFAULT 0 CHECK(is_hidden IN (0,1)),
      personal_alias TEXT,
      icon_key TEXT,
      updated_at_utc INTEGER NOT NULL
    )''',
    '''CREATE TABLE duplicate_suggestions_v2(
      id TEXT PRIMARY KEY,
      source_exercise_id TEXT NOT NULL,
      target_exercise_id TEXT,
      target_catalog_id TEXT,
      confidence TEXT NOT NULL CHECK(confidence IN ('high','medium','low')),
      status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','accepted','dismissed')),
      created_at_utc INTEGER NOT NULL,
      updated_at_utc INTEGER NOT NULL,
      FOREIGN KEY(source_exercise_id) REFERENCES exercise_items(id) ON DELETE CASCADE,
      FOREIGN KEY(target_exercise_id) REFERENCES exercise_items(id) ON DELETE CASCADE,
      CHECK((target_exercise_id IS NULL) <> (target_catalog_id IS NULL))
    )''',
    '''CREATE TABLE exercise_redirects_v2(
      id TEXT PRIMARY KEY,
      source_exercise_id TEXT NOT NULL,
      target_exercise_id TEXT NOT NULL,
      created_at_utc INTEGER NOT NULL,
      undone_at_utc INTEGER,
      FOREIGN KEY(source_exercise_id) REFERENCES exercise_items(id) ON DELETE RESTRICT,
      FOREIGN KEY(target_exercise_id) REFERENCES exercise_items(id) ON DELETE RESTRICT,
      CHECK(source_exercise_id <> target_exercise_id),
      CHECK(undone_at_utc IS NULL OR undone_at_utc >= created_at_utc)
    )''',

    // Canonical workout/plan graph.
    '''CREATE TABLE workout_templates(
      id TEXT PRIMARY KEY,
      legacy_local_id INTEGER,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      description TEXT NOT NULL DEFAULT '',
      icon_key TEXT,
      primary_goal_code TEXT NOT NULL DEFAULT 'strength'
        CHECK(primary_goal_code IN ('strength','endurance','cardio','mobility')),
      source_type TEXT NOT NULL DEFAULT 'custom' CHECK(source_type IN ('custom','generated')),
      is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0,1)),
      created_at_utc INTEGER NOT NULL,
      updated_at_utc INTEGER NOT NULL
    )''',
    '''CREATE TABLE workout_tags(
      workout_id TEXT NOT NULL,
      tag_code TEXT NOT NULL,
      position INTEGER NOT NULL CHECK(position IN (0,1)),
      PRIMARY KEY(workout_id, tag_code),
      UNIQUE(workout_id, position),
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE CASCADE,
      FOREIGN KEY(tag_code) REFERENCES tag_definitions(code) ON DELETE RESTRICT,
      CHECK(position = 1 OR tag_code IN ('strength','cardio','mobility'))
    )''',
    '''CREATE TABLE workout_weekly_schedule(
      id TEXT PRIMARY KEY,
      workout_id TEXT NOT NULL,
      weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7),
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(workout_id, weekday),
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_variants_v2(
      id TEXT PRIMARY KEY,
      workout_id TEXT NOT NULL,
      profile_id TEXT,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      is_default INTEGER NOT NULL DEFAULT 0 CHECK(is_default IN (0,1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE CASCADE,
      FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE workout_groups_v2(
      id TEXT PRIMARY KEY,
      workout_id TEXT NOT NULL,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      group_kind TEXT NOT NULL DEFAULT 'custom' CHECK(group_kind IN ('warmup','core','cooldown','custom')),
      muscle_group_code TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_group_variants_v2(
      id TEXT PRIMARY KEY,
      workout_group_id TEXT NOT NULL,
      profile_id TEXT,
      owner_setup_id TEXT,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(id, workout_group_id),
      FOREIGN KEY(workout_group_id) REFERENCES workout_groups_v2(id) ON DELETE CASCADE,
      FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE workout_variant_group_selections_v2(
      workout_variant_id TEXT NOT NULL,
      workout_group_id TEXT NOT NULL,
      group_variant_id TEXT NOT NULL,
      PRIMARY KEY(workout_variant_id, workout_group_id),
      FOREIGN KEY(workout_variant_id) REFERENCES workout_variants_v2(id) ON DELETE CASCADE,
      FOREIGN KEY(workout_group_id) REFERENCES workout_groups_v2(id) ON DELETE CASCADE,
      FOREIGN KEY(group_variant_id, workout_group_id) REFERENCES workout_group_variants_v2(id, workout_group_id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_slots_v2(
      id TEXT PRIMARY KEY,
      group_variant_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      movement_family_id TEXT,
      slot_kind TEXT NOT NULL DEFAULT 'core' CHECK(slot_kind IN ('core','optional')),
      sort_order INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(group_variant_id) REFERENCES workout_group_variants_v2(id) ON DELETE CASCADE,
      FOREIGN KEY(exercise_id) REFERENCES exercise_items(id) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE workout_slot_alternatives_v2(
      id TEXT PRIMARY KEY,
      workout_slot_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      profile_id TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(workout_slot_id, exercise_id),
      FOREIGN KEY(workout_slot_id) REFERENCES workout_slots_v2(id) ON DELETE CASCADE,
      FOREIGN KEY(exercise_id) REFERENCES exercise_items(id) ON DELETE RESTRICT,
      FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE training_plans(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      source_type TEXT NOT NULL DEFAULT 'manual' CHECK(source_type IN ('manual','generated')),
      status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','completed','archived')),
      starts_at_utc INTEGER,
      ends_at_utc INTEGER,
      created_at_utc INTEGER NOT NULL,
      updated_at_utc INTEGER NOT NULL,
      CHECK(ends_at_utc IS NULL OR starts_at_utc IS NULL OR ends_at_utc >= starts_at_utc)
    )''',
    '''CREATE TABLE training_plan_workouts(
      id TEXT PRIMARY KEY,
      training_plan_id TEXT NOT NULL,
      workout_id TEXT NOT NULL,
      week_number INTEGER NOT NULL CHECK(week_number >= 1),
      weekday INTEGER CHECK(weekday BETWEEN 1 AND 7),
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_optional INTEGER NOT NULL DEFAULT 0 CHECK(is_optional IN (0,1)),
      FOREIGN KEY(training_plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE RESTRICT
    )''',

    // Canonical executed activity snapshot.
    '''CREATE TABLE activity_sessions(
      id TEXT PRIMARY KEY,
      selection_snapshot TEXT,
      source_local_id TEXT,
      workout_id TEXT,
      training_plan_id TEXT,
      workout_variant_id TEXT,
      profile_id TEXT,
      activity_type TEXT NOT NULL CHECK(activity_type IN ('strength','cardio','running','walking','cycling','swimming','mobility','mixed')),
      status TEXT NOT NULL CHECK(status IN ('active','completed','discarded')),
      source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','health_connect','healthkit','import')),
      name_snapshot TEXT NOT NULL,
      started_at_utc INTEGER NOT NULL,
      ended_at_utc INTEGER,
      timezone_offset_minutes INTEGER NOT NULL CHECK(timezone_offset_minutes BETWEEN -840 AND 840),
      created_at_utc INTEGER NOT NULL,
      FOREIGN KEY(workout_id) REFERENCES workout_templates(id) ON DELETE SET NULL,
      FOREIGN KEY(training_plan_id) REFERENCES training_plans(id) ON DELETE SET NULL,
      FOREIGN KEY(workout_variant_id) REFERENCES workout_variants_v2(id) ON DELETE SET NULL,
      FOREIGN KEY(profile_id) REFERENCES training_profiles_v2(id) ON DELETE SET NULL,
      CHECK(ended_at_utc IS NULL OR ended_at_utc >= started_at_utc)
    )''',
    '''CREATE TABLE activity_session_tags(
      session_id TEXT NOT NULL,
      tag_code TEXT NOT NULL,
      position INTEGER NOT NULL CHECK(position IN (0,1)),
      PRIMARY KEY(session_id, tag_code),
      UNIQUE(session_id, position),
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(tag_code) REFERENCES tag_definitions(code) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE activity_session_groups(
      id TEXT PRIMARY KEY,
      plan_snapshot TEXT,
      session_id TEXT NOT NULL,
      workout_group_id TEXT,
      group_variant_id TEXT,
      name_snapshot TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(id, session_id),
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(workout_group_id) REFERENCES workout_groups_v2(id) ON DELETE SET NULL,
      FOREIGN KEY(group_variant_id) REFERENCES workout_group_variants_v2(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE activity_items(
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      session_group_id TEXT,
      exercise_id TEXT,
      source_local_id TEXT,
      catalog_id_snapshot TEXT,
      display_name_snapshot TEXT NOT NULL,
      movement_family_snapshot TEXT,
      equipment_snapshot TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      UNIQUE(id, session_id),
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(session_group_id) REFERENCES activity_session_groups(id) ON DELETE SET NULL,
      FOREIGN KEY(exercise_id) REFERENCES exercise_items(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE activity_efforts(
      id TEXT PRIMARY KEY,
      activity_item_id TEXT NOT NULL,
      effort_type TEXT NOT NULL CHECK(effort_type IN ('set','interval','round','segment')),
      sort_order INTEGER NOT NULL DEFAULT 0,
      started_at_utc INTEGER,
      ended_at_utc INTEGER,
      UNIQUE(id, activity_item_id),
      FOREIGN KEY(activity_item_id) REFERENCES activity_items(id) ON DELETE CASCADE,
      CHECK(ended_at_utc IS NULL OR started_at_utc IS NULL OR ended_at_utc >= started_at_utc)
    )''',
    '''CREATE TABLE activity_metric_values(
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      activity_item_id TEXT,
      effort_id TEXT,
      metric_code TEXT NOT NULL,
      canonical_value REAL NOT NULL,
      entered_value REAL NOT NULL,
      entered_unit_code TEXT NOT NULL,
      source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','health_connect','healthkit','import')),
      recorded_at_utc INTEGER NOT NULL,
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(activity_item_id, session_id) REFERENCES activity_items(id, session_id) ON DELETE CASCADE,
      FOREIGN KEY(effort_id, activity_item_id) REFERENCES activity_efforts(id, activity_item_id) ON DELETE CASCADE,
      FOREIGN KEY(metric_code) REFERENCES metric_definitions(code) ON DELETE RESTRICT,
      CHECK(activity_item_id IS NOT NULL OR effort_id IS NULL)
    )''',
    '''CREATE TABLE health_record_links(
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      provider TEXT NOT NULL CHECK(provider IN ('health_connect','healthkit')),
      external_record_id TEXT NOT NULL,
      sync_status TEXT NOT NULL CHECK(sync_status IN ('linked','pending','failed','deleted')),
      updated_at_utc INTEGER NOT NULL,
      UNIQUE(provider, external_record_id),
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE
    )''',

    // Transitional facade used by current screens. All data starts empty in
    // epoch 2 and is eligible for removal once the last screen uses v2 repos.
    '''CREATE TABLE exercises(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      trackedFields TEXT NOT NULL,
      defaultValues TEXT NOT NULL,
      lastValues TEXT NOT NULL,
      units TEXT NOT NULL,
      icon INTEGER,
      goal TEXT,
      standardKey TEXT,
      isNameCustom INTEGER NOT NULL DEFAULT 1 CHECK(isNameCustom IN (0,1)),
      catalogId TEXT UNIQUE,
      origin TEXT NOT NULL DEFAULT 'custom' CHECK(origin IN ('catalog','custom')),
      alias TEXT,
      notes TEXT NOT NULL DEFAULT '',
      isArchived INTEGER NOT NULL DEFAULT 0 CHECK(isArchived IN (0,1))
    )''',
    '''CREATE TABLE workouts(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      isArchived INTEGER NOT NULL DEFAULT 0 CHECK(isArchived IN (0,1)),
      goalCodes TEXT NOT NULL DEFAULT '[]'
    )''',
    '''CREATE TABLE exercises_in_workouts(
      id INTEGER PRIMARY KEY,
      workoutId INTEGER NOT NULL,
      exerciseId INTEGER NOT NULL,
      sort INTEGER NOT NULL,
      UNIQUE(workoutId, exerciseId),
      FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE,
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE seeded_standards(key TEXT PRIMARY KEY)''',
    '''CREATE TABLE merge_history(
      id INTEGER PRIMARY KEY,
      sourceName TEXT NOT NULL,
      sourceKey TEXT,
      targetId INTEGER NOT NULL,
      mergedAt TEXT NOT NULL,
      FOREIGN KEY(targetId) REFERENCES exercises(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_day_assignments(
      workoutId INTEGER NOT NULL,
      dayOfWeek INTEGER NOT NULL CHECK(dayOfWeek BETWEEN 1 AND 7),
      PRIMARY KEY(workoutId, dayOfWeek),
      FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE pinned_charts(
      id INTEGER PRIMARY KEY,
      exerciseId INTEGER NOT NULL,
      metric TEXT NOT NULL,
      sort INTEGER NOT NULL DEFAULT 0,
      UNIQUE(exerciseId, metric),
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE exercise_goal_labels(
      exerciseId INTEGER NOT NULL,
      goalCode TEXT NOT NULL CHECK(goalCode IN ('strength','cardio','mobility','endurance')),
      position INTEGER NOT NULL DEFAULT 0 CHECK(position IN (0,1)),
      PRIMARY KEY(exerciseId, goalCode),
      UNIQUE(exerciseId, position),
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE CASCADE,
      CHECK(position = 1 OR goalCode IN ('strength','cardio','mobility'))
    )''',
    '''CREATE TABLE exercise_images(
      id INTEGER PRIMARY KEY,
      exerciseId INTEGER NOT NULL,
      relativePath TEXT NOT NULL,
      isCover INTEGER NOT NULL DEFAULT 0 CHECK(isCover IN (0,1)),
      sort INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE CASCADE,
      CHECK(relativePath NOT LIKE '/%' AND relativePath NOT LIKE '%..%')
    )''',
    '''CREATE TABLE duplicate_suggestions(
      id INTEGER PRIMARY KEY,
      sourceExerciseId INTEGER NOT NULL,
      targetExerciseId INTEGER,
      targetCatalogId TEXT,
      confidence TEXT NOT NULL CHECK(confidence IN ('high','medium','low')),
      status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','accepted','dismissed')),
      createdAt INTEGER NOT NULL,
      FOREIGN KEY(sourceExerciseId) REFERENCES exercises(id) ON DELETE CASCADE,
      FOREIGN KEY(targetExerciseId) REFERENCES exercises(id) ON DELETE CASCADE,
      CHECK((targetExerciseId IS NULL) <> (targetCatalogId IS NULL))
    )''',
    '''CREATE TABLE exercise_redirects(
      id INTEGER PRIMARY KEY,
      sourceExerciseId INTEGER NOT NULL,
      targetExerciseId INTEGER NOT NULL,
      sourceSnapshotJson TEXT NOT NULL,
      changedWorkoutMappingsJson TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      undoneAt INTEGER,
      FOREIGN KEY(sourceExerciseId) REFERENCES exercises(id) ON DELETE RESTRICT,
      FOREIGN KEY(targetExerciseId) REFERENCES exercises(id) ON DELETE RESTRICT,
      CHECK(sourceExerciseId <> targetExerciseId)
    )''',
    '''CREATE TABLE training_profiles(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      equipmentCodesJson TEXT NOT NULL DEFAULT '[]',
      isArchived INTEGER NOT NULL DEFAULT 0 CHECK(isArchived IN (0,1)),
      sort INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE workout_variants(
      id INTEGER PRIMARY KEY,
      workoutId INTEGER NOT NULL,
      name TEXT NOT NULL,
      profileId INTEGER,
      sort INTEGER NOT NULL DEFAULT 0,
      isDefault INTEGER NOT NULL DEFAULT 0 CHECK(isDefault IN (0,1)),
      FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE,
      FOREIGN KEY(profileId) REFERENCES training_profiles(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE workout_groups(
      id INTEGER PRIMARY KEY,
      workoutId INTEGER NOT NULL,
      name TEXT NOT NULL,
      muscleGroupCode TEXT,
      sort INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_group_variants(
      id INTEGER PRIMARY KEY,
      workoutGroupId INTEGER NOT NULL,
      name TEXT NOT NULL,
      profileId INTEGER,
      sort INTEGER NOT NULL DEFAULT 0,
      UNIQUE(id, workoutGroupId),
      FOREIGN KEY(workoutGroupId) REFERENCES workout_groups(id) ON DELETE CASCADE,
      FOREIGN KEY(profileId) REFERENCES training_profiles(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE workout_variant_group_selections(
      workoutVariantId INTEGER NOT NULL,
      workoutGroupId INTEGER NOT NULL,
      groupVariantId INTEGER NOT NULL,
      PRIMARY KEY(workoutVariantId, workoutGroupId),
      FOREIGN KEY(workoutVariantId) REFERENCES workout_variants(id) ON DELETE CASCADE,
      FOREIGN KEY(workoutGroupId) REFERENCES workout_groups(id) ON DELETE CASCADE,
      FOREIGN KEY(groupVariantId, workoutGroupId) REFERENCES workout_group_variants(id, workoutGroupId) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_slots(
      id INTEGER PRIMARY KEY,
      groupVariantId INTEGER NOT NULL,
      exerciseId INTEGER NOT NULL,
      movementFamilyId TEXT,
      slotKind TEXT NOT NULL DEFAULT 'core' CHECK(slotKind IN ('core','optional')),
      sort INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(groupVariantId) REFERENCES workout_group_variants(id) ON DELETE CASCADE,
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE workout_slot_alternatives(
      id INTEGER PRIMARY KEY,
      workoutSlotId INTEGER NOT NULL,
      exerciseId INTEGER NOT NULL,
      profileId INTEGER,
      sort INTEGER NOT NULL DEFAULT 0,
      UNIQUE(workoutSlotId, exerciseId),
      FOREIGN KEY(workoutSlotId) REFERENCES workout_slots(id) ON DELETE CASCADE,
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE RESTRICT,
      FOREIGN KEY(profileId) REFERENCES training_profiles(id) ON DELETE SET NULL
    )''',
    '''CREATE TABLE workout_sessions(
      id INTEGER PRIMARY KEY,
      workoutId INTEGER NOT NULL,
      workoutVariantId INTEGER,
      profileId INTEGER,
      startedAt INTEGER NOT NULL,
      completedAt INTEGER,
      snapshotJson TEXT NOT NULL,
      FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE RESTRICT,
      FOREIGN KEY(workoutVariantId) REFERENCES workout_variants(id) ON DELETE SET NULL,
      FOREIGN KEY(profileId) REFERENCES training_profiles(id) ON DELETE SET NULL,
      CHECK(completedAt IS NULL OR completedAt >= startedAt)
    )''',
    '''CREATE TABLE workout_session_group_selections(
      sessionId INTEGER NOT NULL,
      workoutGroupId INTEGER NOT NULL,
      groupVariantId INTEGER NOT NULL,
      PRIMARY KEY(sessionId, workoutGroupId),
      FOREIGN KEY(sessionId) REFERENCES workout_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(workoutGroupId) REFERENCES workout_groups(id) ON DELETE RESTRICT,
      FOREIGN KEY(groupVariantId) REFERENCES workout_group_variants(id) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE workout_session_slot_selections(
      sessionId INTEGER NOT NULL,
      workoutSlotId INTEGER NOT NULL,
      exerciseId INTEGER NOT NULL,
      PRIMARY KEY(sessionId, workoutSlotId),
      FOREIGN KEY(sessionId) REFERENCES workout_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(workoutSlotId) REFERENCES workout_slots(id) ON DELETE RESTRICT,
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE RESTRICT
    )''',
    '''CREATE TABLE workout_entries(
      id INTEGER PRIMARY KEY,
      workoutId INTEGER NOT NULL,
      exerciseId INTEGER NOT NULL,
      timestamp INTEGER NOT NULL,
      valuesJson TEXT NOT NULL,
      durationSeconds INTEGER NOT NULL CHECK(durationSeconds >= 0),
      sessionId INTEGER,
      FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE RESTRICT,
      FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE RESTRICT,
      FOREIGN KEY(sessionId) REFERENCES workout_sessions(id) ON DELETE SET NULL
    )''',
  ];

  static const _indexStatements = <String>[
    'CREATE INDEX idx_profile_equipment_profile ON training_profile_equipment(profile_id)',
    'CREATE INDEX idx_selected_profile_profile ON selected_training_profile(profile_id)',
    'CREATE INDEX idx_exercise_tags_exercise ON exercise_tags(exercise_id)',
    'CREATE UNIQUE INDEX idx_exercise_items_legacy_local ON exercise_items(legacy_local_id) WHERE legacy_local_id IS NOT NULL',
    'CREATE INDEX idx_exercise_tags_tag ON exercise_tags(tag_code)',
    'CREATE INDEX idx_metric_configs_exercise ON exercise_metric_configs(exercise_id)',
    'CREATE INDEX idx_metric_configs_metric ON exercise_metric_configs(metric_code)',
    'CREATE INDEX idx_exercise_images_exercise ON exercise_images_v2(exercise_id)',
    'CREATE INDEX idx_duplicates_source ON duplicate_suggestions_v2(source_exercise_id)',
    'CREATE INDEX idx_duplicates_target ON duplicate_suggestions_v2(target_exercise_id)',
    'CREATE INDEX idx_redirects_source ON exercise_redirects_v2(source_exercise_id)',
    'CREATE INDEX idx_redirects_target ON exercise_redirects_v2(target_exercise_id)',
    'CREATE UNIQUE INDEX idx_redirects_active_source ON exercise_redirects_v2(source_exercise_id) WHERE undone_at_utc IS NULL',
    'CREATE INDEX idx_workout_tags_workout ON workout_tags(workout_id)',
    'CREATE UNIQUE INDEX idx_workout_templates_legacy_local ON workout_templates(legacy_local_id) WHERE legacy_local_id IS NOT NULL',
    'CREATE INDEX idx_weekly_schedule_workout ON workout_weekly_schedule(workout_id)',
    'CREATE INDEX idx_weekly_schedule_day_order ON workout_weekly_schedule(weekday, sort_order, id)',
    'CREATE INDEX idx_workout_tags_tag ON workout_tags(tag_code)',
    'CREATE INDEX idx_variants_workout ON workout_variants_v2(workout_id)',
    'CREATE INDEX idx_variants_profile ON workout_variants_v2(profile_id)',
    'CREATE UNIQUE INDEX idx_variants_unique_profile_per_workout ON workout_variants_v2(workout_id, profile_id) WHERE profile_id IS NOT NULL',
    'CREATE INDEX idx_groups_workout ON workout_groups_v2(workout_id)',
    'CREATE INDEX idx_groups_kind ON workout_groups_v2(workout_id, group_kind, sort_order)',
    'CREATE INDEX idx_group_variants_group ON workout_group_variants_v2(workout_group_id)',
    'CREATE INDEX idx_group_variants_profile ON workout_group_variants_v2(profile_id)',
    'CREATE UNIQUE INDEX idx_group_variants_owner_group ON workout_group_variants_v2(owner_setup_id, workout_group_id) WHERE owner_setup_id IS NOT NULL',
    'CREATE INDEX idx_vgs_variant ON workout_variant_group_selections_v2(workout_variant_id)',
    'CREATE INDEX idx_vgs_group ON workout_variant_group_selections_v2(workout_group_id)',
    'CREATE INDEX idx_vgs_group_variant ON workout_variant_group_selections_v2(group_variant_id)',
    'CREATE INDEX idx_slots_group_variant ON workout_slots_v2(group_variant_id)',
    'CREATE INDEX idx_slots_exercise ON workout_slots_v2(exercise_id)',
    'CREATE INDEX idx_alternatives_slot ON workout_slot_alternatives_v2(workout_slot_id)',
    'CREATE INDEX idx_alternatives_exercise ON workout_slot_alternatives_v2(exercise_id)',
    'CREATE INDEX idx_alternatives_profile ON workout_slot_alternatives_v2(profile_id)',
    'CREATE INDEX idx_plan_workouts_plan ON training_plan_workouts(training_plan_id)',
    'CREATE INDEX idx_plan_workouts_workout ON training_plan_workouts(workout_id)',
    'CREATE INDEX idx_sessions_workout ON activity_sessions(workout_id)',
    'CREATE INDEX idx_sessions_plan ON activity_sessions(training_plan_id)',
    'CREATE INDEX idx_sessions_variant ON activity_sessions(workout_variant_id)',
    'CREATE INDEX idx_sessions_profile ON activity_sessions(profile_id)',
    'CREATE INDEX idx_activity_sessions_source_local ON activity_sessions(source_local_id)',
    'CREATE INDEX idx_session_tags_session ON activity_session_tags(session_id)',
    'CREATE INDEX idx_session_tags_tag ON activity_session_tags(tag_code)',
    'CREATE INDEX idx_session_groups_session ON activity_session_groups(session_id)',
    'CREATE INDEX idx_session_groups_group ON activity_session_groups(workout_group_id)',
    'CREATE INDEX idx_session_groups_variant ON activity_session_groups(group_variant_id)',
    'CREATE INDEX idx_activity_items_session ON activity_items(session_id)',
    'CREATE INDEX idx_activity_items_group ON activity_items(session_group_id)',
    'CREATE INDEX idx_activity_items_exercise ON activity_items(exercise_id)',
    'CREATE INDEX idx_activity_items_source_local ON activity_items(source_local_id)',
    'CREATE INDEX idx_efforts_item ON activity_efforts(activity_item_id)',
    'CREATE INDEX idx_metric_values_session ON activity_metric_values(session_id)',
    'CREATE INDEX idx_metric_values_item ON activity_metric_values(activity_item_id)',
    'CREATE INDEX idx_metric_values_effort ON activity_metric_values(effort_id)',
    'CREATE INDEX idx_metric_values_metric ON activity_metric_values(metric_code)',
    'CREATE UNIQUE INDEX idx_metric_value_effort_unique ON activity_metric_values(effort_id, metric_code) WHERE effort_id IS NOT NULL',
    'CREATE UNIQUE INDEX idx_metric_value_item_unique ON activity_metric_values(activity_item_id, metric_code) WHERE effort_id IS NULL AND activity_item_id IS NOT NULL',
    'CREATE INDEX idx_health_links_session ON health_record_links(session_id)',
    'CREATE INDEX idx_eiw_workout ON exercises_in_workouts(workoutId)',
    'CREATE INDEX idx_eiw_exercise ON exercises_in_workouts(exerciseId)',
    'CREATE INDEX idx_merge_target ON merge_history(targetId)',
    'CREATE INDEX idx_pinned_exercise ON pinned_charts(exerciseId)',
    'CREATE INDEX idx_goal_labels_exercise ON exercise_goal_labels(exerciseId)',
    'CREATE INDEX idx_images_exercise ON exercise_images(exerciseId)',
    'CREATE INDEX idx_dup_source ON duplicate_suggestions(sourceExerciseId)',
    'CREATE INDEX idx_dup_target ON duplicate_suggestions(targetExerciseId)',
    'CREATE INDEX idx_redirect_source ON exercise_redirects(sourceExerciseId)',
    'CREATE INDEX idx_redirect_target ON exercise_redirects(targetExerciseId)',
    'CREATE UNIQUE INDEX idx_redirect_active_source ON exercise_redirects(sourceExerciseId) WHERE undoneAt IS NULL',
    'CREATE INDEX idx_workout_variants_workout ON workout_variants(workoutId)',
    'CREATE INDEX idx_workout_variants_profile ON workout_variants(profileId)',
    'CREATE INDEX idx_workout_groups_workout ON workout_groups(workoutId)',
    'CREATE INDEX idx_workout_group_variants_group ON workout_group_variants(workoutGroupId)',
    'CREATE INDEX idx_workout_group_variants_profile ON workout_group_variants(profileId)',
    'CREATE INDEX idx_legacy_vgs_group ON workout_variant_group_selections(workoutGroupId)',
    'CREATE INDEX idx_legacy_vgs_variant_choice ON workout_variant_group_selections(groupVariantId)',
    'CREATE INDEX idx_legacy_slots_group ON workout_slots(groupVariantId)',
    'CREATE INDEX idx_legacy_slots_exercise ON workout_slots(exerciseId)',
    'CREATE INDEX idx_legacy_alt_slot ON workout_slot_alternatives(workoutSlotId)',
    'CREATE INDEX idx_legacy_alt_exercise ON workout_slot_alternatives(exerciseId)',
    'CREATE INDEX idx_legacy_alt_profile ON workout_slot_alternatives(profileId)',
    'CREATE INDEX idx_legacy_sessions_workout ON workout_sessions(workoutId)',
    'CREATE INDEX idx_legacy_sessions_variant ON workout_sessions(workoutVariantId)',
    'CREATE INDEX idx_legacy_sessions_profile ON workout_sessions(profileId)',
    'CREATE INDEX idx_legacy_session_groups_group ON workout_session_group_selections(workoutGroupId)',
    'CREATE INDEX idx_legacy_session_groups_variant ON workout_session_group_selections(groupVariantId)',
    'CREATE INDEX idx_legacy_session_slots_slot ON workout_session_slot_selections(workoutSlotId)',
    'CREATE INDEX idx_legacy_session_slots_exercise ON workout_session_slot_selections(exerciseId)',
    'CREATE INDEX idx_entries_workout ON workout_entries(workoutId)',
    'CREATE INDEX idx_entries_exercise ON workout_entries(exerciseId)',
    'CREATE INDEX idx_entries_session ON workout_entries(sessionId)',
    'CREATE UNIQUE INDEX idx_entries_session_exercise_unique ON workout_entries(sessionId, exerciseId) WHERE sessionId IS NOT NULL',
  ];

  static const _triggerStatements = <String>[
    '''CREATE TRIGGER exercise_tags_require_domain_insert
      BEFORE INSERT ON exercise_tags
      WHEN NEW.position = 1 AND NOT EXISTS(
        SELECT 1 FROM exercise_tags et
        JOIN tag_definitions td ON td.code = et.tag_code
        WHERE et.exercise_id = NEW.exercise_id AND td.kind = 'domain'
      ) AND (SELECT kind FROM tag_definitions WHERE code = NEW.tag_code) <> 'domain'
      BEGIN SELECT RAISE(ABORT, 'exercise requires a domain tag'); END''',
    '''CREATE TRIGGER workout_tags_require_domain_insert
      BEFORE INSERT ON workout_tags
      WHEN NEW.position = 1 AND NOT EXISTS(
        SELECT 1 FROM workout_tags wt
        JOIN tag_definitions td ON td.code = wt.tag_code
        WHERE wt.workout_id = NEW.workout_id AND td.kind = 'domain'
      ) AND (SELECT kind FROM tag_definitions WHERE code = NEW.tag_code) <> 'domain'
      BEGIN SELECT RAISE(ABORT, 'workout requires a domain tag'); END''',
    '''CREATE TRIGGER redirect_cycle_insert
      BEFORE INSERT ON exercise_redirects_v2
      WHEN EXISTS(
        WITH RECURSIVE chain(id) AS (
          SELECT NEW.target_exercise_id
          UNION ALL
          SELECT r.target_exercise_id FROM exercise_redirects_v2 r
          JOIN chain c ON r.source_exercise_id = c.id
          WHERE r.undone_at_utc IS NULL
        ) SELECT 1 FROM chain WHERE id = NEW.source_exercise_id
      )
      BEGIN SELECT RAISE(ABORT, 'exercise redirect cycle'); END''',
    '''CREATE TRIGGER activity_item_group_session_insert
      BEFORE INSERT ON activity_items
      WHEN NEW.session_group_id IS NOT NULL AND NOT EXISTS(
        SELECT 1 FROM activity_session_groups g
        WHERE g.id = NEW.session_group_id AND g.session_id = NEW.session_id
      )
      BEGIN SELECT RAISE(ABORT, 'activity group belongs to another session'); END''',
    '''CREATE TRIGGER activity_item_group_session_update
      BEFORE UPDATE OF session_group_id, session_id ON activity_items
      WHEN NEW.session_group_id IS NOT NULL AND NOT EXISTS(
        SELECT 1 FROM activity_session_groups g
        WHERE g.id = NEW.session_group_id AND g.session_id = NEW.session_id
      )
      BEGIN SELECT RAISE(ABORT, 'activity group belongs to another session'); END''',
    '''CREATE TRIGGER legacy_redirect_cycle_insert
      BEFORE INSERT ON exercise_redirects
      WHEN EXISTS(
        WITH RECURSIVE chain(id) AS (
          SELECT NEW.targetExerciseId
          UNION ALL
          SELECT r.targetExerciseId FROM exercise_redirects r
          JOIN chain c ON r.sourceExerciseId = c.id
          WHERE r.undoneAt IS NULL
        ) SELECT 1 FROM chain WHERE id = NEW.sourceExerciseId
      )
      BEGIN SELECT RAISE(ABORT, 'exercise redirect cycle'); END''',
  ];
}

class DatabaseEpochMismatch implements Exception {
  const DatabaseEpochMismatch(this.actualEpoch);

  final int? actualEpoch;

  @override
  String toString() =>
      'DatabaseEpochMismatch(expected: ${DatabaseSchemaV2.dataEpoch}, actual: $actualEpoch)';
}
