import '../services/database_service.dart';
import '../utils/uuid_v4.dart';

class WorkoutRepository {
  WorkoutRepository({DatabaseService? databaseService})
    : _database = databaseService ?? DatabaseService();

  final DatabaseService _database;
  static const _domains = {'strength', 'cardio', 'mobility'};

  Future<String> createWorkout({
    required String name,
    String description = '',
    String? iconKey,
    String sourceType = 'custom',
    required List<String> tags,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name');
    final cleanTags = _validatedTags(tags);
    final id = UuidV4.generate();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      await txn.insert('workout_templates', {
        'id': id,
        'name': cleanName,
        'description': description.trim(),
        'icon_key': iconKey,
        'source_type': sourceType,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      for (var index = 0; index < cleanTags.length; index++) {
        await txn.insert('workout_tags', {
          'workout_id': id,
          'tag_code': cleanTags[index],
          'position': index,
        });
      }
    });
    return id;
  }

  Future<void> archiveWorkout(String workoutId) =>
      _database.transaction((txn) async {
        final changed = await txn.update(
          'workout_templates',
          {
            'is_archived': 1,
            'updated_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [workoutId],
        );
        if (changed != 1) throw StateError('Workout not found.');
      });

  Future<String> createVariant({
    required String workoutId,
    required String name,
    String? profileId,
    bool isDefault = false,
    int sortOrder = 0,
  }) async {
    final id = UuidV4.generate();
    await _database.transaction((txn) async {
      if (isDefault) {
        await txn.update(
          'workout_variants_v2',
          {'is_default': 0},
          where: 'workout_id = ?',
          whereArgs: [workoutId],
        );
      }
      await txn.insert('workout_variants_v2', {
        'id': id,
        'workout_id': workoutId,
        'profile_id': profileId,
        'name': name.trim(),
        'is_default': isDefault ? 1 : 0,
        'sort_order': sortOrder,
      });
    });
    return id;
  }

  static List<String> _validatedTags(Iterable<String> tags) {
    final result = tags.toSet().toList();
    if (result.isEmpty || result.length > 2 || !result.any(_domains.contains)) {
      throw ArgumentError('Workouts require one domain and at most two tags.');
    }
    result.sort((a, b) {
      final ad = _domains.contains(a);
      final bd = _domains.contains(b);
      return ad == bd ? 0 : (ad ? -1 : 1);
    });
    return result;
  }
}
