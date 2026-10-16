import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/repositories/training_profile_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/exercise_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Unicode names survive SQLite close and reopen without rewriting',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'trainy-v6-unicode-',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      const name = 'ÄÖÜäöüß · O\u0308';
      final profiles = TrainingProfileRepository();
      final workouts = WorkoutPlanningRepository();
      final now = DateTime.now().toUtc();
      try {
        await profiles.save(
          TrainingProfileRecord(
            id: 'unicode-profile',
            name: name,
            equipmentCodes: const {'bodyweight'},
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
        final exerciseId = await ExerciseDatabase.instance.addOrUpdateExercise(
          name: name,
          trackSets: true,
          trackReps: true,
          trackWeight: false,
          trackDuration: false,
        );
        final workout = await workouts.createWorkout(
          WorkoutEditorDraft(
            name: name,
            description: name,
            primaryGoal: WorkoutPrimaryGoal.strength,
            setupName: name,
            profileId: 'unicode-profile',
            exerciseIds: [exerciseId],
          ),
        );

        await AppDatabase.instance.close();

        expect((await profiles.profiles()).single.name, name);
        final exercise =
            (await ExerciseDatabase.instance.getAllExercises()).single;
        expect(exercise.name, name);
        expect(exercise.id, exerciseId);
        final loaded = (await workouts.workouts()).single;
        expect(loaded.name, name);
        expect(loaded.description, name);
        expect(loaded.exerciseIds, [exerciseId]);
        final setup =
          (await workouts.setupsForWorkout(workout.canonicalId)).single;
        expect(setup.name, name);
        expect(setup.profile?.name, name);
        await AppDatabase.instance.assertIntegrity();
      } finally {
        await AppDatabase.instance.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
