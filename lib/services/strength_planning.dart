import '../models/strength_equipment.dart';
import '../models/strength_plan.dart';
import '../models/training_profile.dart';
import '../models/training_program.dart';
import '../models/workout_planning.dart';
import 'profile_readiness.dart';

/// Reviewed recommendation metadata, deliberately separate from the broad
/// searchable catalogue. Unknown equipment is never treated as available.
class StrengthCandidate {
  const StrengthCandidate(
    this.id,
    this.role,
    this.equipment, {
    this.guided = false,
    this.beginner = true,
    this.unilateral = false,
    this.secondary = const {},
    this.isolation = false,
  });
  final String id, role;
  final Set<String> equipment, secondary;
  final bool guided, beginner, unilateral, isolation;
}

abstract final class StrengthPlanning {
  static const muscles = [
    'chest',
    'shoulders',
    'rearDelts',
    'back',
    'biceps',
    'triceps',
    'core',
    'quads',
    'hamstrings',
    'glutes',
    'calves',
  ];
  static Set<String> expand(Iterable<String> focus) =>
      focus
          .expand(
            (f) => switch (f) {
              'push' => ['chest', 'shoulders', 'triceps'],
              'pull' => ['back', 'rearDelts', 'biceps'],
              'legs' => ['quads', 'hamstrings', 'glutes', 'calves'],
              'arms' => ['biceps', 'triceps'],
              'abs' => ['core'],
              _ => [f],
            },
          )
          .toSet();

  static List<String> labels(int count, {String pair = 'mixedSplit'}) {
    final two =
        pair == 'upperLower'
            ? ['upper', 'lowerCore']
            : ['pushCore', 'pullLegs'];
    return switch (count) {
      1 => ['fullBody'],
      2 => ['fullBody', 'fullBody'],
      3 => [...two, 'fullBody'],
      4 => [...two, ...two],
      5 => ['pushCore', 'pull', 'legs', ...two],
      6 => ['pushCore', 'pull', 'legs', 'pushCore', 'pull', 'legs'],
      _ => throw ArgumentError.value(count, 'count'),
    };
  }

  static Set<String> focus(String label) =>
      label == 'lowerCore' ? {'legs', 'core'} : ProgramSplits.focusFor(label);

  /// Enumerates <= 35 ordered day combinations. The cyclic score includes
  /// next Monday; manual placements are never rewritten by this function.
  static List<int> suggestDays(List<int> available, List<Set<String>> focuses) {
    final days = available.toSet().toList()..sort();
    if (focuses.length > days.length) return [];
    List<int> best = [];
    var bestScore = 1 << 30;
    for (var mask = 1; mask < 1 << days.length; mask++) {
      final selected = [
        for (var i = 0; i < days.length; i++)
          if (mask & (1 << i) != 0) days[i],
      ];
      if (selected.length != focuses.length) continue;
      final conflicts = recoveryConflicts(selected, focuses);
      var gaps = 0;
      for (var i = 0; i < selected.length; i++) {
        final gap = (selected[(i + 1) % selected.length] - selected[i] + 7) % 7;
        gaps += gap * gap;
      }
      final score = conflicts * 1000 + gaps;
      if (score < bestScore) {
        bestScore = score;
        best = selected;
      }
    }
    return best;
  }

  static int recoveryConflicts(List<int> days, List<Set<String>> focuses) {
    var result = 0;
    for (var i = 0; i < days.length; i++) {
      for (var j = i + 1; j < days.length; j++) {
        final gap = (days[i] - days[j]).abs();
        if ((gap < 2 || gap > 5) &&
            expand(focuses[i]).intersection(expand(focuses[j])).isNotEmpty) {
          result++;
        }
      }
    }
    return result;
  }

  static const candidates = <StrengthCandidate>[
    StrengthCandidate(
      'free:Machine_Bench_Press',
      'chest',
      {'chest_press'},
      guided: true,
      secondary: {'shoulders', 'triceps'},
    ),
    StrengthCandidate(
      'free:Pushups',
      'chest',
      {'bodyweight'},
      beginner: false,
      secondary: {'shoulders', 'triceps'},
    ),
    StrengthCandidate('free:Push-Ups_-_Close_Triceps_Position', 'triceps', {
      'bodyweight',
    }, beginner: false),
    StrengthCandidate(
      'free:Incline_Push-Up',
      'chest',
      {'bodyweight', 'bench'},
      secondary: {'shoulders', 'triceps'},
    ),
    StrengthCandidate(
      'free:Incline_Dumbbell_Press',
      'chest',
      {'dumbbell', 'bench'},
      secondary: {'shoulders', 'triceps'},
    ),
    StrengthCandidate(
      'free:Dips_-_Chest_Version',
      'chest',
      {'dip_bars'},
      beginner: false,
      secondary: {'triceps'},
    ),
    StrengthCandidate('free:Side_Lateral_Raise', 'shoulders', {
      'dumbbell',
    }, isolation: true),
    StrengthCandidate('free:Cable_Seated_Lateral_Raise', 'shoulders', {
      'cable',
      'bench',
    }, isolation: true),
    StrengthCandidate(
      'free:Machine_Shoulder_Military_Press',
      'shoulderPress',
      {'shoulder_press'},
      guided: true,
      secondary: {'shoulders', 'triceps'},
    ),
    StrengthCandidate(
      'free:Dumbbell_Shoulder_Press',
      'shoulderPress',
      {'dumbbell', 'bench'},
      secondary: {'shoulders', 'triceps'},
    ),
    StrengthCandidate(
      'free:Wide-Grip_Lat_Pulldown',
      'back',
      {'lat_pulldown'},
      guided: true,
      secondary: {'biceps'},
    ),
    StrengthCandidate(
      'free:Pullups',
      'back',
      {'pull_up_bar'},
      beginner: false,
      secondary: {'biceps'},
    ),
    StrengthCandidate(
      'free:Band_Assisted_Pull-Up',
      'back',
      {'pull_up_bar', 'bands'},
      secondary: {'biceps'},
    ),
    StrengthCandidate(
      'free:Bent_Over_Two-Dumbbell_Row',
      'back',
      {'dumbbell'},
      secondary: {'biceps', 'rearDelts'},
    ),
    StrengthCandidate(
      'free:Seated_Cable_Rows',
      'row',
      {'row_machine'},
      guided: true,
      secondary: {'back', 'biceps', 'rearDelts'},
    ),
    StrengthCandidate(
      'free:Bent_Over_Two-Dumbbell_Row',
      'row',
      {'dumbbell'},
      secondary: {'back', 'biceps', 'rearDelts'},
    ),
    StrengthCandidate(
      'free:Reverse_Machine_Flyes',
      'rearDelts',
      {'rear_delt_machine'},
      guided: true,
      isolation: true,
    ),
    StrengthCandidate('free:Reverse_Flyes', 'rearDelts', {
      'dumbbell',
      'bench',
    }, isolation: true),
    StrengthCandidate('trainy:w_raises', 'rearDelts', {
      'bodyweight',
    }, isolation: true),
    StrengthCandidate(
      'free:Leg_Press',
      'quads',
      {'leg_press'},
      guided: true,
      secondary: {'glutes'},
    ),
    StrengthCandidate(
      'trainy:bulgarian_split_squat',
      'quads',
      {'bodyweight', 'bench'},
      beginner: false,
      unilateral: true,
      secondary: {'glutes'},
    ),
    StrengthCandidate(
      'free:Bodyweight_Squat',
      'quads',
      {'bodyweight'},
      secondary: {'glutes'},
    ),
    StrengthCandidate(
      'free:Dumbbell_Squat',
      'quads',
      {'dumbbell'},
      secondary: {'glutes'},
    ),
    StrengthCandidate(
      'free:Barbell_Squat',
      'quads',
      {'barbell', 'rack'},
      beginner: false,
      secondary: {'glutes'},
    ),
    StrengthCandidate(
      'free:Seated_Leg_Curl',
      'hamstrings',
      {'leg_curl'},
      guided: true,
      isolation: true,
    ),
    StrengthCandidate(
      'free:Butt_Lift_Bridge',
      'hamstrings',
      {'bodyweight'},
      secondary: {'glutes'},
    ),
    StrengthCandidate('free:Barbell_Hip_Thrust', 'glutes', {
      'barbell',
      'bench',
    }),
    StrengthCandidate(
      'free:Butt_Lift_Bridge',
      'glutes',
      {'bodyweight'},
      secondary: {'hamstrings'},
    ),
    StrengthCandidate(
      'free:Ab_Crunch_Machine',
      'core',
      {'ab_machine'},
      guided: true,
      isolation: true,
    ),
    StrengthCandidate(
      'free:Hanging_Leg_Raise',
      'core',
      {'pull_up_bar'},
      beginner: false,
      isolation: true,
    ),
    StrengthCandidate('free:Crunches', 'core', {'bodyweight'}, isolation: true),
    StrengthCandidate(
      'free:Machine_Bicep_Curl',
      'biceps',
      {'arm_curl_machine'},
      guided: true,
      isolation: true,
    ),
    StrengthCandidate('free:Dumbbell_Bicep_Curl', 'biceps', {
      'dumbbell',
    }, isolation: true),
    StrengthCandidate('free:Hammer_Curls', 'biceps', {
      'dumbbell',
    }, isolation: true),
    StrengthCandidate(
      'free:Machine_Triceps_Extension',
      'triceps',
      {'triceps_machine'},
      guided: true,
      isolation: true,
    ),
    StrengthCandidate('free:Triceps_Pushdown', 'triceps', {
      'cable',
    }, isolation: true),
    StrengthCandidate('free:Seated_Triceps_Press', 'triceps', {
      'dumbbell',
      'bench',
    }, isolation: true),
    StrengthCandidate('trainy:standing_calf_raise', 'calves', {
      'bodyweight',
    }, isolation: true),
    StrengthCandidate('free:Hyperextensions_Back_Extensions', 'lowerBack', {
      'back_extension',
    }, guided: true),
    StrengthCandidate('free:Superman', 'lowerBack', {'bodyweight'}),
  ];

  static StrengthPlanProposal generate({
    required String planId,
    required UserTrainingProfile user,
    required List<TrainingProfileRecord> places,
    required List<ProgramSlot> slots,
    required String goal,
    required int minutes,
    required String Function(String) label,
  }) {
    final missing = ProfileReadiness.strengthForGeneration(user, places);
    if (missing.isNotEmpty) throw ProfileIncomplete('strength', missing);
    if (minutes < 10 || minutes > 240) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    return StrengthPlanProposal(
      workouts: [
        for (final slot in slots.where(
          (s) => s.kind == 'strength' && s.workoutId == null,
        ))
          StrengthWorkoutDraft(
            id: 'generated:$planId:${slot.id}',
            slotId: slot.id,
            name: label(slot.label),
            variants: [
              for (final id in user.strengthPlaces)
                _variant(
                  places.firstWhere((p) => p.id == id),
                  user,
                  expand(slot.effectiveFocus),
                  goal,
                  minutes,
                ),
            ],
          ),
      ],
    );
  }

  static StrengthVariantDraft _variant(
    TrainingProfileRecord place,
    UserTrainingProfile user,
    Set<String> focus,
    String goal,
    int minutes,
  ) {
    final novice = ['starting', 'beginner'].contains(user.strengthLevel);
    final guided = novice || user.strengthPreference != 'freeWeights';
    final chosen = <StrengthExerciseDraft>[];
    final used = <String>{}, covered = <String>{}, missing = <String>[];
    final required = <String>[
      for (final role in [
        'chest',
        'back',
        'quads',
        'core',
        'shoulders',
        'rearDelts',
        'hamstrings',
        'glutes',
      ])
        if (focus.contains(role)) role,
      for (final role in ['biceps', 'triceps', 'calves'])
        if (focus.contains(role) && focus.length == 1) role,
    ];
    final extras = <String>[
      if (focus.contains('shoulders')) 'shoulderPress',
      if (focus.contains('back')) 'row',
      for (final role in ['glutes', 'biceps', 'triceps', 'calves'])
        if (focus.contains(role)) role,
      if (focus.contains('back')) 'lowerBack',
    ];
    var seconds = 300;
    for (final item in [...required, ...extras].indexed) {
      final role = item.$2, extra = item.$1 >= required.length;
      if (!extra && covered.contains(role)) continue;
      final pool =
          candidates
              .where(
                (c) =>
                    c.role == role &&
                    !used.contains(c.id) &&
                    place.equipmentCodes.containsAll(c.equipment) &&
                    (!novice || c.beginner),
              )
              .toList();
      // Stable ordering is important for draft resumption and reproducibility.
      pool.sort((a, b) {
        final pa = a.guided == guided ? 0 : 1, pb = b.guided == guided ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        if (!guided &&
            place.equipmentCodes.any(StrengthEquipment.machines.contains)) {
          int freeWeightRank(StrengthCandidate c) =>
              c.equipment.any(
                    {'dumbbell', 'barbell', 'cable', 'kettlebell'}.contains,
                  )
                  ? 0
                  : 1;
          final rank = freeWeightRank(a).compareTo(freeWeightRank(b));
          if (rank != 0) return rank;
        }
        return candidates.indexOf(a).compareTo(candidates.indexOf(b));
      });
      if (pool.isEmpty) {
        if (!extra) missing.add('equipment:$role');
        continue;
      }
      final c = pool.first;
      final strength = goal == 'getStronger';
      final prescription = StrengthPrescription(
        sets:
            novice || goal == 'generalFitness' || c.isolation || extra ? 2 : 3,
        minReps:
            c.isolation
                ? 10
                : strength
                ? 5
                : 8,
        maxReps:
            c.isolation
                ? 15
                : strength
                ? 8
                : 12,
        restSeconds:
            c.isolation
                ? 60
                : strength
                ? 150
                : 90,
        source: 'generated:v1',
      );
      final exercise = StrengthExerciseDraft(
        catalogId: c.id,
        prescription: prescription,
        unilateral: c.unilateral,
        optional: extra,
      );
      if (seconds + exercise.estimatedSeconds > minutes * 60) {
        if (!extra) missing.add('time:$role');
        continue;
      }
      seconds += exercise.estimatedSeconds;
      chosen.add(exercise);
      used.add(c.id);
      covered.add(role);
      // Compound glute/arm work satisfies coverage, not a second mandatory isolation.
      covered.addAll(
        c.secondary.where({'glutes', 'biceps', 'triceps'}.contains),
      );
    }
    return StrengthVariantDraft(
      profileId: place.id,
      name: place.name,
      exercises: chosen,
      missing: missing,
    );
  }
}
