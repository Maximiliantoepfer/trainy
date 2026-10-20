import '../models/cardio.dart';
import '../models/training_program.dart';
import '../models/training_profile.dart';

class ProfileIncomplete implements Exception {
  const ProfileIncomplete(this.sport, this.missing);
  final String sport;
  final List<String> missing;
}

/// One contract for wizard, resumed drafts, generators and persistence.
abstract final class ProfileReadiness {
  static List<String> strengthForGeneration(
    UserTrainingProfile p,
    Iterable<TrainingProfileRecord> places,
  ) => [
    ...strength(p, places),
    if (p.strengthSetupVersion < 2) 'confirmProfile',
    if (![
      'generalFitness',
      'buildMuscle',
      'getStronger',
    ].contains(p.strengthGoal))
      'goal',
    if (!['guided', 'freeWeights'].contains(p.strengthPreference)) 'preference',
    for (final key in ['level', 'goal', 'places', 'equipment', 'preference'])
      if (!p.strengthAnswers.contains(key)) key,
    if (p.strengthPlaces.isEmpty ||
        p.strengthPlaces.any(
          (id) => !places.any((e) => e.id == id && !e.isArchived),
        ))
      'trainingPlace',
  ];
  static List<String> running(AthleteRunningProfile p, {DateTime? now}) {
    final missing = <String>[
      for (final answer in [
        'level',
        'experience',
        'continuous',
        'frequency',
        'volume',
        'reference',
        'referenceKind',
      ])
        if (!p.confirmedAnswers.contains(answer)) answer,
      if (p.level == null) 'level',
      if (p.experienceMonths < 0) 'experience',
      if (p.continuousMinutes < 0) 'continuous',
      if (p.recentRunsPerWeek != null &&
          (p.recentRunsPerWeek! < 0 || p.recentRunsPerWeek! > 7))
        'frequency',
      if (!p.weeklyMeters.isFinite || p.weeklyMeters < 0) 'volume',
      if (!p.longestMeters.isFinite || p.longestMeters < 0) 'longest',
      if (p.restingHeartRate != null &&
          (p.restingHeartRate! < 25 || p.restingHeartRate! > 250))
        'restPulse',
      if (p.maximumHeartRate != null &&
          (p.maximumHeartRate! < 25 ||
              p.maximumHeartRate! > 250 ||
              (p.restingHeartRate != null &&
                  p.maximumHeartRate! <= p.restingHeartRate!)))
        'maxPulse',
      if (p.referenceSeconds == null ||
          !p.referenceSeconds!.isFinite ||
          p.referenceSeconds! <= 0 ||
          !p.referenceMeters.isFinite ||
          p.referenceMeters <= 0)
        'reference',
      if (!['normal', 'runWalk', 'maximal'].contains(p.referenceKind))
        'referenceKind',
      if (p.referenceKind == 'maximal' &&
          (p.referenceDate == null ||
              p.referenceDate!.isAfter(now ?? DateTime.now())))
        'testDate',
      if (p.setupVersion < 1) 'confirmProfile',
    ];
    return missing.toSet().toList();
  }

  static List<String> strength(
    UserTrainingProfile p,
    Iterable<TrainingProfileRecord> places,
  ) => strengthStatus(
    p,
    hasPlace: places.any((e) => e.id == p.strengthProfileId && !e.isArchived),
  );

  static List<String> strengthStatus(
    UserTrainingProfile p, {
    required bool hasPlace,
  }) => [
    if (p.strengthSetupVersion < 1) 'confirmProfile',
    if (![
      'starting',
      'beginner',
      'intermediate',
      'experienced',
    ].contains(p.strengthLevel))
      'level',
    if (!hasPlace) 'trainingPlace',
  ];

  static void requireRunning(AthleteRunningProfile p, {DateTime? now}) {
    final missing = running(p, now: now);
    if (missing.isNotEmpty) throw ProfileIncomplete('running', missing);
    p.validate();
  }
}
