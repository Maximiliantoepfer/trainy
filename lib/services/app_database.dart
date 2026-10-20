import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_schema_v2.dart';
import 'data_operation.dart';

/// Owns the single SQLite connection for data epoch 2.
///
/// SQL is intentionally kept out of providers and widgets. Repositories and
/// the temporary compatibility data services obtain their connection here.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const databaseName = 'trainy_v2.db';

  Database? _database;
  Future<Database>? _opening;
  Future<void>? _closing;

  Future<String> get databasePath async =>
      path.join(await getDatabasesPath(), databaseName);

  Future<Database> get database async {
    if (DataOperation.instance.databaseUnavailable) {
      throw const DataOperationFailure('database', 'operation-in-progress');
    }
    await _closing;
    if (DataOperation.instance.databaseUnavailable) {
      throw const DataOperationFailure('database', 'operation-in-progress');
    }
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    return _opening ??= _openShared();
  }

  Future<Database> _openShared() async {
    try {
      return _database = await _open(await databasePath);
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open(String filePath) => openDatabase(
    filePath,
    version: DatabaseSchemaV2.schemaVersion,
    onConfigure: (db) async {
      // SQLite does not enable foreign keys per connection by default.
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (db, _) => DatabaseSchemaV2.create(db),
    onUpgrade: DatabaseSchemaV2.upgrade,
    onOpen: (db) async {
      final enabled = Sqflite.firstIntValue(
        await db.rawQuery('PRAGMA foreign_keys'),
      );
      if (enabled != 1) {
        throw StateError('SQLite foreign-key enforcement is disabled.');
      }
    },
  );

  /// Opens an isolated database with exactly the production schema. This is
  /// used by restore validation and tests; it never changes the active handle.
  Future<Database> openIsolated(String filePath) => _open(filePath);

  Future<List<Map<String, Object?>>> foreignKeyViolations({
    Database? database,
  }) async {
    final db = database ?? await this.database;
    return db.rawQuery('PRAGMA foreign_key_check');
  }

  Future<void> assertIntegrity({Database? database}) async {
    final db = database ?? await this.database;
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final value = integrity.isEmpty ? null : integrity.first.values.first;
    if (value != 'ok') {
      throw StateError('SQLite integrity check failed: $value');
    }
    final violations = await foreignKeyViolations(database: db);
    if (violations.isNotEmpty) {
      throw StateError('SQLite foreign-key check failed: $violations');
    }
    final requiredTables = {
      'app_meta',
      'exercise_items',
      'workout_templates',
      'activity_sessions',
      'health_record_links',
    };
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables =
        tableRows.map((row) => row['name']).whereType<String>().toSet();
    if (!tables.containsAll(requiredTables)) {
      throw StateError('The epoch-2 schema is incomplete.');
    }
    final metadataRows = await db.query(
      'app_meta',
      where: 'key IN (?, ?, ?)',
      whereArgs: const ['data_epoch', 'schema_version', 'schema_revision'],
    );
    final metadata = {
      for (final row in metadataRows) row['key'] as String: row['value'],
    };
    if (metadata['data_epoch'] != '${DatabaseSchemaV2.dataEpoch}' ||
        metadata['schema_version'] != '${DatabaseSchemaV2.schemaVersion}') {
      throw StateError('The database metadata does not match epoch 2.');
    }
  }

  Future<void> close() async {
    if (_closing != null) return _closing;
    final closing = _closeShared();
    _closing = closing;
    try {
      await closing;
    } finally {
      _closing = null;
    }
  }

  Future<void> _closeShared() async {
    await _opening;
    final db = _database;
    if (db != null && db.isOpen) await db.close();
    _database = null;
  }

  Future<void> setCatalogVersion(String version) async {
    final db = await database;
    await db.insert('app_meta', {
      'key': 'catalog_version',
      'value': version,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAndRecreate() async {
    final filePath = await databasePath;
    await close();
    await deleteDatabase(filePath);
    final db = await database;
    await assertIntegrity(database: db);
  }
}
