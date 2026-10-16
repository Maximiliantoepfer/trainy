import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Low-level database boundary. Repositories own domain SQL; UI code never
/// receives a [Database] instance.
class DatabaseService {
  DatabaseService({AppDatabase? appDatabase, Database? database})
    : _appDatabase = appDatabase ?? AppDatabase.instance,
      _databaseOverride = database;

  final AppDatabase _appDatabase;
  final Database? _databaseOverride;

  Future<Database> get _connection async =>
      _databaseOverride ?? await _appDatabase.database;

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await _connection;
    return db.transaction(action);
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
  }) async {
    final db = await _connection;
    return db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
    );
  }
}
