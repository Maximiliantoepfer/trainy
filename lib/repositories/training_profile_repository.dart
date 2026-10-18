import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';

import '../models/training_profile.dart';
import '../services/database_schema_v2.dart';
import '../services/database_service.dart';

class TrainingProfileRepositoryException implements Exception {
  const TrainingProfileRepositoryException(this.operation, this.cause);

  final String operation;
  final Object cause;

  @override
  String toString() => 'Training profile $operation failed: $cause';
}

class TrainingProfileRepository implements TrainingProfilePreferencesStore {
  TrainingProfileRepository({DatabaseService? database})
    : _database = database ?? DatabaseService();

  final DatabaseService _database;

  static const equipmentCodes = <String>{
    'bodyweight',
    'dumbbell',
    'barbell',
    'bench',
    'rack',
    'pull_up_bar',
    'cable',
    'machine',
    'kettlebell',
    'bands',
    'medicine_ball',
    'exercise_ball',
    'foam_roller',
    'ez_bar',
    'mat',
    'cardio_machine',
    'bicycle',
    'pool',
    'other',
  };

  static const homeEquipment = <String>{'bodyweight'};
  static final gymEquipment = Set<String>.unmodifiable(
    equipmentCodes.difference({'bicycle', 'pool', 'other'}),
  );

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      developer.log(
        'Training profile $operation failed',
        name: 'trainy.training_profiles',
        error: error,
        stackTrace: stackTrace,
      );
      throw TrainingProfileRepositoryException(operation, error);
    }
  }

  @override
  Future<List<TrainingProfileRecord>> profiles({
    bool includeArchived = false,
  }) => _guard('load', () async {
    final rows = await _database.rawQuery('''
      SELECT profile.*, equipment.equipment_code
      FROM training_profiles_v2 profile
      LEFT JOIN training_profile_equipment equipment
        ON equipment.profile_id = profile.id
      ${includeArchived ? '' : 'WHERE profile.is_archived = 0'}
      ORDER BY profile.sort_order ASC, profile.name COLLATE NOCASE ASC,
               equipment.equipment_code ASC
      ''');
    final profiles = <String, TrainingProfileRecord>{};
    for (final row in rows) {
      final id = row['id'] as String;
      final current = profiles[id];
      final equipment = <String>{
        ...?current?.equipmentCodes,
        if (row['equipment_code'] case final String code) code,
      };
      profiles[id] = TrainingProfileRecord(
        id: id,
        name: row['name'] as String,
        equipmentCodes: Set.unmodifiable(equipment),
        isArchived: (row['is_archived'] as num).toInt() == 1,
        sortOrder: (row['sort_order'] as num).toInt(),
        createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at_utc'] as num).toInt(),
          isUtc: true,
        ),
        updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
          (row['updated_at_utc'] as num).toInt(),
          isUtc: true,
        ),
      );
    }
    return profiles.values.toList(growable: false);
  });

  @override
  Future<String?> selectedProfileId() => _guard('load selection', () async {
    final rows = await _database.query(
      'selected_training_profile',
      columns: const ['profile_id'],
      where: 'id = 0',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['profile_id'] as String?;
  });

  @override
  Future<void> save(TrainingProfileRecord profile) => _guard('save', () async {
    final name = profile.name.trim();
    if (name.isEmpty) throw ArgumentError.value(name, 'name');
    final invalid = profile.equipmentCodes.difference(equipmentCodes);
    if (invalid.isNotEmpty) {
      throw ArgumentError.value(invalid, 'equipmentCodes');
    }
    await _database.transaction((txn) async {
      final values = <String, Object?>{
        'id': profile.id,
        'name': name,
        'is_archived': profile.isArchived ? 1 : 0,
        'sort_order': profile.sortOrder,
        'created_at_utc': profile.createdAtUtc.toUtc().millisecondsSinceEpoch,
        'updated_at_utc': profile.updatedAtUtc.toUtc().millisecondsSinceEpoch,
      };
      final updated = await txn.update(
        'training_profiles_v2',
        {...values}..remove('created_at_utc'),
        where: 'id = ?',
        whereArgs: [profile.id],
      );
      if (updated == 0) await txn.insert('training_profiles_v2', values);
      await txn.delete(
        'training_profile_equipment',
        where: 'profile_id = ?',
        whereArgs: [profile.id],
      );
      for (final code in profile.equipmentCodes) {
        await txn.insert('training_profile_equipment', {
          'profile_id': profile.id,
          'equipment_code': code,
        });
      }
    });
  });

  @override
  Future<void> select(String? profileId) => _guard('select', () async {
    if (profileId != null) {
      final found = await _database.query(
        'training_profiles_v2',
        where: 'id = ? AND is_archived = 0',
        whereArgs: [profileId],
      );
      if (found.isEmpty) throw StateError('Profile is not active.');
    }
    await _database.insert('selected_training_profile', {
      'id': 0,
      'profile_id': profileId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  @override
  Future<void> archive(String profileId) => _guard('archive', () async {
    await _database.transaction((txn) async {
      final count = await txn.update(
        'training_profiles_v2',
        {
          'is_archived': 1,
          'updated_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [profileId],
      );
      if (count != 1) throw StateError('Profile no longer exists.');
      await txn.update(
        'selected_training_profile',
        {'profile_id': null},
        where: 'id = 0 AND profile_id = ?',
        whereArgs: [profileId],
      );
    });
  });

  Future<int> migrateLegacyProfiles() => _guard(
    'legacy migration',
    () => _database.transaction(DatabaseSchemaV2.migrateLegacyProfiles),
  );

  @override
  Future<ProfileSetupState> setupState() => _guard('load setup', () async {
    final rows = await _database.query(
      'user_settings',
      columns: ['profile_setup_state'],
      limit: 1,
    );
    final code = rows.firstOrNull?['profile_setup_state'];
    return ProfileSetupState.values.firstWhere(
      (s) => s.name == code,
      orElse: () => ProfileSetupState.required,
    );
  });

  @override
  Future<void> dismissSetupOffer() => _guard('dismiss setup', () async {
    await _database.update('user_settings', {
      'profile_setup_state': 'dismissed',
    }, where: "id = 0 AND profile_setup_state = 'offer'");
  });

  @override
  Future<void> completeSetup({
    required List<TrainingProfileRecord> profiles,
    required String preferredProfileId,
  }) => _guard('complete setup', () async {
    await _database.transaction((txn) async {
      for (final profile in profiles) {
        if (profile.name.trim().isEmpty ||
            profile.equipmentCodes.difference(equipmentCodes).isNotEmpty) {
          throw ArgumentError('Invalid profile draft.');
        }
        // Existing profiles are explicitly reused, never overwritten by a preset.
        final existing = await txn.query(
          'training_profiles_v2',
          where: 'id = ?',
          whereArgs: [profile.id],
        );
        if (existing.isNotEmpty) continue;
        await txn.insert('training_profiles_v2', {
          'id': profile.id,
          'name': profile.name.trim(),
          'is_archived': 0,
          'sort_order': profile.sortOrder,
          'created_at_utc': profile.createdAtUtc.millisecondsSinceEpoch,
          'updated_at_utc': profile.updatedAtUtc.millisecondsSinceEpoch,
        });
        for (final code in profile.equipmentCodes) {
          await txn.insert('training_profile_equipment', {
            'profile_id': profile.id,
            'equipment_code': code,
          });
        }
      }
      final active = await txn.query(
        'training_profiles_v2',
        where: 'id = ? AND is_archived = 0',
        whereArgs: [preferredProfileId],
      );
      if (active.isEmpty) throw StateError('Choose an active profile.');
      await txn.insert('selected_training_profile', {
        'id': 0,
        'profile_id': preferredProfileId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update('user_settings', {
        'profile_setup_state': 'completed',
      }, where: 'id = 0');
    });
  });
}
