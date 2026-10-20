import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const confirmedAnswers = {
  'level',
  'experience',
  'continuous',
  'frequency',
  'volume',
  'reference',
  'referenceKind',
};

AthleteRunningProfile confirmedRunner([
  Map<String, dynamic> values = const {},
]) => AthleteRunningProfile.fromJson({
  ...const AthleteRunningProfile(
    referenceSeconds: 2700,
    continuousMinutes: 45,
    recentRunsPerWeek: 3,
    level: RunningLevel.beginner,
    experienceMonths: 2,
    referenceKind: 'normal',
    setupVersion: 1,
    confirmedAnswers: confirmedAnswers,
  ).toJson(),
  ...values,
});

Future<void> seedProfiles(Database db) async {
  await db.insert('training_profiles_v2', {
    'id': 'confirmed-home',
    'name': 'Home Gym',
    'created_at_utc': 1,
    'updated_at_utc': 1,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  final service = DatabaseService(database: db);
  await TrainingProgramRepository(database: service).saveUserProfile(
    const UserTrainingProfile(
      strengthLevel: 'beginner',
      strengthProfileId: 'confirmed-home',
      strengthSetupVersion: 1,
    ),
  );
  await CardioRepository(database: service).saveProfile(confirmedRunner());
}
