import 'dart:math' as math;
import '../models/cardio.dart';
import 'cardio_training.dart';
import 'running_fitness.dart';
import 'running_rules.dart';

/// Repairs a missing quality role in generated plans without moving dates,
/// adding sessions, increasing duration, or replacing personal edits.
class RunningForecast {
  Map<String, CardioWorkout> suggestStructure(
    AthleteRunningProfile profile,
    RunningFitnessSnapshot fitness,
    List<ScheduledCardioWorkout> occurrences,
    Map<String, RunningPlanRequest> requests,
    CardioTranslate t,
  ) {
    final changes = <String, CardioWorkout>{};
    if (profile.planning.restricted ||
        fitness.difficult ||
        profile.continuousMinutes < 30) {
      return changes;
    }
    final today = DateTime(
      fitness.asOf.year,
      fitness.asOf.month,
      fitness.asOf.day,
    );
    for (final entry in requests.entries) {
      final existing = occurrences.where((o) => o.planId == entry.key).toList();
      final days = existing.map((o) => o.date.weekday).toSet().toList()..sort();
      if (days.isEmpty || days.length > 6) continue;
      final p = AthleteRunningProfile.fromJson({
        ...profile.toJson(),
        'weekdays': days,
        'planning': {...profile.planning.toJson(), 'desiredDays': days.length},
      });
      final proposed = RunningPlanGenerator().generate(p, entry.value, t);
      final weeks = <String, List<ScheduledCardioWorkout>>{};
      for (final o in existing) {
        final monday = DateTime(
          o.date.year,
          o.date.month,
          o.date.day - o.date.weekday + 1,
        );
        weeks.putIfAbsent(monday.toIso8601String(), () => []).add(o);
      }
      for (final week in weeks.values) {
        if (week.any(
          (o) =>
              o.date.isBefore(today) ||
              o.status != 'planned' ||
              o.locked ||
              o.sessionId != null ||
              !['base', 'build'].contains(o.workout.trainingPhase) ||
              o.workout.steps.any((s) => s.targetSource == 'manual') ||
              ![
                'easySession',
                'easy5k',
                'longRun',
              ].contains(o.workout.templateCode),
        )) {
          continue;
        }
        final candidates =
            proposed.occurrences
                .where((n) => week.any((o) => o.date == n.date))
                .toList();
        if (candidates.length != week.length ||
            !candidates.any(
              (o) =>
                  !['easySession', 'longRun'].contains(o.workout.templateCode),
            )) {
          continue;
        }
        for (final old in week) {
          final candidate =
              candidates.singleWhere((o) => o.date == old.date).workout;
          if (candidate.templateCode == old.workout.templateCode) continue;
          final oldSeconds = duration(old.workout);
          final newSeconds = duration(candidate);
          if (oldSeconds == null || newSeconds == null || newSeconds <= 0) {
            continue;
          }
          final factor = math.min(1.0, oldSeconds / newSeconds);
          final steps =
              candidate.steps
                  .map(
                    (s) => s.copyWith(
                      amount: s.amount * factor,
                      recoverySeconds: s.recoverySeconds * factor,
                    ),
                  )
                  .toList();
          changes[old.id] = CardioWorkout.fromJson({
            ...candidate.toJson(),
            'id': old.workout.id,
            'steps': steps.map((s) => s.toJson()).toList(),
            'warmup': old.workout.warmup.map((s) => s.toJson()).toList(),
            'cooldown': old.workout.cooldown.map((s) => s.toJson()).toList(),
            'indoor': old.workout.indoor,
            'autoPause': old.workout.autoPause,
            'trainingPhase': old.workout.trainingPhase,
            'ruleVersion': RunningRules.bundled.version,
            'targetsUpdatedAt': fitness.asOf.toIso8601String(),
          });
        }
      }
    }
    return changes;
  }

  static double? duration(CardioWorkout w) {
    var seconds = 0.0;
    for (final s in w.expandedSteps()) {
      if (s.goal == StepGoal.distance && s.maxSpeed == null) return null;
      seconds += s.goal == StepGoal.time ? s.amount : s.amount / s.maxSpeed!;
    }
    return seconds;
  }
}
