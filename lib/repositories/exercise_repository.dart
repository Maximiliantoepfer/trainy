import 'package:sqflite/sqflite.dart';

import '../models/catalog_exercise.dart';
import '../services/catalog_repository.dart';
import '../services/database_service.dart';
import '../utils/uuid_v4.dart';

class ExerciseRepository {
  ExerciseRepository({
    DatabaseService? databaseService,
    CatalogRepository? catalogRepository,
  }) : _database = databaseService ?? DatabaseService(),
       _catalog = catalogRepository ?? CatalogRepository.instance;

  final DatabaseService _database;
  final CatalogRepository _catalog;

  static const _domains = {'strength', 'cardio', 'mobility'};

  Future<String> materializeCatalogExercise(String catalogId) async {
    final definition = _catalog.byId(catalogId);
    if (definition == null) {
      throw ArgumentError.value(catalogId, 'catalogId', 'Unknown catalog ID');
    }
    final existing = await _database.query(
      'exercise_items',
      columns: ['id'],
      where: 'catalog_id = ?',
      whereArgs: [catalogId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id']! as String;

    final id = UuidV4.generate();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final tags = _validatedTags(definition.goalCodes);
    await _database.transaction((txn) async {
      await txn.insert('exercise_items', {
        'id': id,
        'source_type': 'catalog',
        'catalog_id': catalogId,
        'tracking_mode': _trackingMode(tags),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _insertTags(txn, id, tags);
      await _insertMetricConfigurations(txn, id, definition.tracking);
    });
    return id;
  }

  Future<String> createCustomExercise({
    required String name,
    String description = '',
    String? alias,
    String notes = '',
    String? iconKey,
    required List<String> tags,
    required List<ExerciseMetricConfiguration> metrics,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name');
    final cleanTags = _validatedTags(tags);
    final id = UuidV4.generate();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      await txn.insert('exercise_items', {
        'id': id,
        'source_type': 'custom',
        'custom_name': cleanName,
        'custom_description': description.trim(),
        'personal_alias': alias?.trim(),
        'notes': notes.trim(),
        'icon_key': iconKey,
        'tracking_mode': _trackingMode(cleanTags),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      await _insertTags(txn, id, cleanTags);
      for (var index = 0; index < metrics.length; index++) {
        final metric = metrics[index];
        await txn.insert('exercise_metric_configs', {
          'id': UuidV4.generate(),
          'exercise_id': id,
          'metric_code': metric.metricCode,
          'unit_code': metric.unitCode,
          'input_level': metric.inputLevel,
          'is_required': metric.isRequired ? 1 : 0,
          'sort_order': index,
          'default_numeric_value': metric.defaultValue,
        });
      }
    });
    return id;
  }

  Future<String> mergeExercises(String sourceId, String targetId) async {
    if (sourceId == targetId) {
      throw ArgumentError('Cannot merge an exercise into itself.');
    }
    final redirectId = UuidV4.generate();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      final source = await txn.query(
        'exercise_items',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [sourceId],
        limit: 1,
      );
      final target = await txn.query(
        'exercise_items',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [targetId],
        limit: 1,
      );
      if (source.isEmpty || target.isEmpty) {
        throw StateError('Both exercises must exist before merging.');
      }
      await txn.insert('exercise_redirects_v2', {
        'id': redirectId,
        'source_exercise_id': sourceId,
        'target_exercise_id': targetId,
        'created_at_utc': now,
      });
      await txn.update(
        'exercise_items',
        {'is_archived': 1, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [sourceId],
      );
    });
    return redirectId;
  }

  Future<void> undoMerge(String redirectId) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'exercise_redirects_v2',
        columns: ['source_exercise_id'],
        where: 'id = ? AND undone_at_utc IS NULL',
        whereArgs: [redirectId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Active exercise redirect not found.');
      final sourceId = rows.single['source_exercise_id']! as String;
      await txn.update(
        'exercise_redirects_v2',
        {'undone_at_utc': now},
        where: 'id = ?',
        whereArgs: [redirectId],
      );
      await txn.update(
        'exercise_items',
        {'is_archived': 0, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [sourceId],
      );
    });
  }

  Future<String> resolveActiveExerciseId(String exerciseId) async {
    var current = exerciseId;
    final visited = <String>{};
    while (visited.add(current)) {
      final redirect = await _database.query(
        'exercise_redirects_v2',
        columns: ['target_exercise_id'],
        where: 'source_exercise_id = ? AND undone_at_utc IS NULL',
        whereArgs: [current],
        limit: 1,
      );
      if (redirect.isEmpty) return current;
      current = redirect.single['target_exercise_id']! as String;
    }
    throw StateError('Exercise redirect cycle detected.');
  }

  static List<String> _validatedTags(Iterable<String> tags) {
    final result = <String>[];
    for (final tag in tags) {
      if (!result.contains(tag)) result.add(tag);
    }
    if (result.isEmpty || result.length > 2 || !result.any(_domains.contains)) {
      throw ArgumentError('Exercises require one domain and at most two tags.');
    }
    result.sort((a, b) {
      final aDomain = _domains.contains(a);
      final bDomain = _domains.contains(b);
      return aDomain == bDomain ? 0 : (aDomain ? -1 : 1);
    });
    return result;
  }

  static String _trackingMode(List<String> tags) {
    if (tags.contains('strength')) return 'strength';
    if (tags.contains('cardio')) return 'cardio';
    if (tags.contains('mobility')) return 'mobility';
    return 'mixed';
  }

  static Future<void> _insertTags(
    DatabaseExecutor db,
    String exerciseId,
    List<String> tags,
  ) async {
    for (var index = 0; index < tags.length; index++) {
      await db.insert('exercise_tags', {
        'exercise_id': exerciseId,
        'tag_code': tags[index],
        'position': index,
      });
    }
  }

  static Future<void> _insertMetricConfigurations(
    DatabaseExecutor db,
    String exerciseId,
    CatalogTrackingProfile tracking,
  ) async {
    final metrics = <ExerciseMetricConfiguration>[
      if (tracking.reps)
        const ExerciseMetricConfiguration(
          metricCode: 'repetitions',
          unitCode: 'count',
          inputLevel: 'effort',
          isRequired: true,
        ),
      if (tracking.weight)
        const ExerciseMetricConfiguration(
          metricCode: 'weight',
          unitCode: 'kg',
          inputLevel: 'effort',
        ),
      if (tracking.duration)
        const ExerciseMetricConfiguration(
          metricCode: 'duration',
          unitCode: 'second',
          inputLevel: 'exercise',
        ),
      if (tracking.distance)
        const ExerciseMetricConfiguration(
          metricCode: 'distance',
          unitCode: 'meter',
          inputLevel: 'exercise',
        ),
    ];
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      await db.insert('exercise_metric_configs', {
        'id': UuidV4.generate(),
        'exercise_id': exerciseId,
        'metric_code': metric.metricCode,
        'unit_code': metric.unitCode,
        'input_level': metric.inputLevel,
        'is_required': metric.isRequired ? 1 : 0,
        'sort_order': index,
      });
    }
  }
}

class ExerciseMetricConfiguration {
  const ExerciseMetricConfiguration({
    required this.metricCode,
    required this.unitCode,
    required this.inputLevel,
    this.isRequired = false,
    this.defaultValue,
  });

  final String metricCode;
  final String unitCode;
  final String inputLevel;
  final bool isRequired;
  final double? defaultValue;
}
