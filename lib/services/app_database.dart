import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'trainy.db');

    _database = await openDatabase(path, version: 1, onCreate: _createDB);
    return _database!;
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        trackedFields TEXT,
        defaultValues TEXT,
        units TEXT,
        icon INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE exercises_in_workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER,
        exerciseId INTEGER,
        name TEXT,
        description TEXT,
        trackedFields TEXT,
        defaultValues TEXT,
        units TEXT,
        icon INTEGER,
        position INTEGER
      );
    ''');
  }
}
