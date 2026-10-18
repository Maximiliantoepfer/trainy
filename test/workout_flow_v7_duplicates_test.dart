import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/exercise_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'duplicate checks publish high-confidence suggestions once, retain decisions and remove stale rows',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'trainy-v7-duplicates-',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      final exercises = ExerciseDatabase.instance;
      const names = {
        'free:Pushups': ['Liegestütz', 'Push-Up', 'Pushups'],
      };
      try {
        final db = await AppDatabase.instance.database;
        Future<int> add(int id, String name) => exercises.addOrUpdateExercise(
          id: id,
          name: name,
          trackSets: true,
          trackReps: true,
          trackWeight: false,
          trackDuration: false,
        );
        await add(1, 'Liegestütz');
        await exercises.refreshDuplicateSuggestions(names);
        var suggestions = await exercises.getOpenDuplicateSuggestions();
        expect(suggestions, hasLength(1));
        expect(suggestions.single.confidence, 'high');
        final firstId = suggestions.single.id;
        await exercises.refreshDuplicateSuggestions(names);
        expect(
          (await exercises.getOpenDuplicateSuggestions()).single.id,
          firstId,
        );
        await exercises.setDuplicateSuggestionStatus(firstId, 'dismissed');
        await add(1, 'Liegestütz');
        await exercises.refreshDuplicateSuggestions(names);
        expect(await exercises.getOpenDuplicateSuggestions(), isEmpty);
        await add(2, 'Push-Up');
        await exercises.refreshDuplicateSuggestions(names);
        suggestions = await exercises.getOpenDuplicateSuggestions();
        expect(suggestions, hasLength(1));
        await exercises.setDuplicateSuggestionStatus(
          suggestions.single.id,
          'accepted',
        );
        await add(2, 'Push-Up');
        await exercises.refreshDuplicateSuggestions(names);
        expect(await exercises.getOpenDuplicateSuggestions(), isEmpty);
        await add(3, 'Pushups');
        await exercises.refreshDuplicateSuggestions(names);
        expect(await exercises.getOpenDuplicateSuggestions(), hasLength(1));
        await add(3, 'Unique custom name');
        await exercises.refreshDuplicateSuggestions(names);
        expect(await exercises.getOpenDuplicateSuggestions(), isEmpty);
        expect(
          (await db.query('duplicate_suggestions')).map((r) => r['status']),
          containsAll(['accepted', 'dismissed']),
        );
        expect(await exercises.getAllExercises(), hasLength(3));
        await AppDatabase.instance.assertIntegrity();
      } finally {
        await AppDatabase.instance.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
