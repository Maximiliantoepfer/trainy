import '../services/database_service.dart';
import '../utils/uuid_v4.dart';

class TrainingPlanRepository {
  TrainingPlanRepository({DatabaseService? databaseService})
    : _database = databaseService ?? DatabaseService();

  final DatabaseService _database;

  Future<String> createPlan({
    required String name,
    String sourceType = 'manual',
    String status = 'draft',
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final id = UuidV4.generate();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      await txn.insert('training_plans', {
        'id': id,
        'name': name.trim(),
        'source_type': sourceType,
        'status': status,
        'starts_at_utc': startsAt?.toUtc().millisecondsSinceEpoch,
        'ends_at_utc': endsAt?.toUtc().millisecondsSinceEpoch,
        'created_at_utc': now,
        'updated_at_utc': now,
      });
    });
    return id;
  }

  Future<String> addWorkout({
    required String planId,
    required String workoutId,
    required int weekNumber,
    int? weekday,
    int sortOrder = 0,
    bool isOptional = false,
  }) async {
    final id = UuidV4.generate();
    await _database.transaction((txn) async {
      await txn.insert('training_plan_workouts', {
        'id': id,
        'training_plan_id': planId,
        'workout_id': workoutId,
        'week_number': weekNumber,
        'weekday': weekday,
        'sort_order': sortOrder,
        'is_optional': isOptional ? 1 : 0,
      });
    });
    return id;
  }

  Future<void> setStatus(String planId, String status) =>
      _database.transaction((txn) async {
        final changed = await txn.update(
          'training_plans',
          {
            'status': status,
            'updated_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [planId],
        );
        if (changed != 1) throw StateError('Training plan not found.');
      });

  /// Plan ownership ends at the relation. Workouts remain independent.
  Future<void> deletePlan(String planId) => _database.transaction((txn) async {
    await txn.delete('training_plans', where: 'id = ?', whereArgs: [planId]);
  });
}
