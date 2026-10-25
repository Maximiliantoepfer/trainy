import 'dart:math' as math;
import 'running_plan_engine.dart';
import 'running_fitness.dart';
import 'running_rules.dart';

import '../models/cardio.dart';

typedef CardioTranslate = String Function(String key);

abstract final class CardioTraining {
  static String targetDescription(
    CardioStep s,
    DistanceSystem units,
    CardioTranslate t, {
    bool cycling = false,
  }) {
    if (s.primaryTarget == 'heart_rate' && s.minHeartRate != null) {
      return '${s.minHeartRate}–${s.maxHeartRate} bpm';
    }
    if (s.primaryTarget != 'pace' ||
        (s.maxSpeed == null && s.minSpeed == null)) {
      return t(s.intensity.name);
    }
    String value(double? speed) =>
        cycling
            ? CardioUnits.speed(speed, units)
            : CardioUnits.pace(speed, units);
    if (s.minSpeed == null) return '${t('notFaster')} ${value(s.maxSpeed)}';
    if (s.maxSpeed == null) return '${t('notSlower')} ${value(s.minSpeed)}';
    return cycling
        ? '${value(s.minSpeed)} – ${value(s.maxSpeed)}'
        : '${value(s.maxSpeed)} – ${value(s.minSpeed)}';
  }

  static const templateCodes = [
    'easy5k',
    'longRun',
    'runWalk',
    'progression',
    'tempo',
    'threshold',
    'pyramid',
    'descending',
    'fourByFour',
    'fartlek',
    'strides',
  ];

  /// Manual alternatives remain available without silently increasing a new
  /// runner's distance. Automatic plan generation is deliberately unchanged.
  static CardioWorkout replacementTemplate(
    String code,
    AthleteRunningProfile profile,
    CardioTranslate t,
  ) {
    final base = template(code, profile, t);
    final beginner =
        profile.level == RunningLevel.beginner ||
        profile.continuousMinutes < 30 ||
        profile.returningAfterBreak;
    final minutes =
        profile.continuousMinutes > 0
            ? profile.continuousMinutes.clamp(10, 45)
            : 20;
    final steps =
        code == 'easy5k'
            ? [prescribe(profile, CardioIntensity.easy, amount: minutes * 60.0)]
            : [
              for (final s in base.steps)
                if (beginner && code == 'progression')
                  refreshTarget(
                    s.copyWith(
                      intensity:
                          s.intensity == CardioIntensity.threshold
                              ? CardioIntensity.steady
                              : s.intensity,
                    ),
                    profile,
                    force: true,
                  )
                else
                  s,
            ];
    return CardioWorkout(
      name: code == 'easy5k' ? t('easySession') : base.name,
      templateCode: base.templateCode,
      steps: steps,
      warmup: base.warmup,
      cooldown: base.cooldown,
    );
  }

  static const warmups = {
    'running': [
      'ankleRocks',
      'calfRaises',
      'legSwings',
      'lateralSwings',
      'reverseLunge',
      'march',
    ],
    'cycling': [
      'ankleRocks',
      'calfRaises',
      'hinge',
      'squat',
      'reverseLunge',
      'rotation',
    ],
    'lower': [
      'ankleRocks',
      'hinge',
      'squat',
      'lateralLunge',
      'gluteBridge',
      'birdDog',
    ],
    'upper': [
      'shoulderCircles',
      'armCircles',
      'rotation',
      'wallSlides',
      'scapularPushup',
      'birdDog',
    ],
    'drills': ['aMarch', 'ankling', 'aSkip', 'buttKicks', 'sideSteps', 'march'],
  };
  static const cooldowns = {
    'running': ['calfStretch', 'hipFlexor', 'hamstring'],
    'cycling': ['quadStretch', 'hipFlexor', 'gluteStretch'],
    'lower': ['quadStretch', 'gluteStretch', 'hamstring'],
    'upper': ['chestStretch', 'latStretch', 'shoulderStretch'],
  };
  static List<RoutineStep> routine(String key, {bool cooling = false}) =>
      (cooling
              ? cooldowns[key] ?? cooldowns['running']!
              : warmups[key] ?? warmups['running']!)
          .map((e) => RoutineStep(e, seconds: cooling ? 60 : 30))
          .toList();

  static CardioStep prescribe(
    AthleteRunningProfile profile,
    CardioIntensity intensity, {
    StepGoal goal = StepGoal.time,
    double amount = 300,
    int repeat = 1,
    double recovery = 0,
    DateTime? now,
    CardioSport sport = CardioSport.running,
  }) {
    final v =
        sport == CardioSport.running && profile.referenceKind != 'runWalk'
            ? profile.fiveKmSpeed(
              now ?? DateTime.now(),
              maximumAgeDays: RunningRules.bundled.integer('benchmarkDays'),
            )
            : null;
    double? low, high;
    if (v != null) {
      final factors = switch (intensity) {
        CardioIntensity.easy || CardioIntensity.recovery => (.65, .8),
        CardioIntensity.steady => (.8, .85),
        CardioIntensity.interval => (.95, 1.0),
        _ => (.65, .8),
      };
      low = v * factors.$1;
      high = v * factors.$2;
      if (intensity == CardioIntensity.threshold) {
        final distance =
            profile.benchmarkMeters *
            math.pow(3600 / profile.benchmarkSeconds!, 1 / 1.06);
        low = distance / 3600 * .97;
        high = distance / 3600 * 1.03;
      }
    }
    if (sport == CardioSport.running &&
        v == null &&
        profile.easySpeed != null) {
      // Product heuristic in seconds per kilometre, not a performance prediction.
      final easy = profile.easySpeed!;
      final easyPace =
          ((1000 / easy * RunningRules.bundled.number('normalPaceFactor')) / 5)
              .ceil() *
          5.0;
      switch (intensity) {
        case CardioIntensity.easy:
        case CardioIntensity.recovery:
          high = 1000 / easyPace;
        case CardioIntensity.steady:
          low = 1000 / easyPace;
          high = easy;
        case CardioIntensity.threshold:
          low = easy;
          high = easy * RunningRules.bundled.number('lightSpeedFactor');
        case CardioIntensity.interval:
          low = easy;
          high = easy * RunningRules.bundled.number('lightSpeedFactor');
        case CardioIntensity.free:
          break;
      }
    }
    if (intensity == CardioIntensity.easy ||
        intensity == CardioIntensity.recovery) {
      low = null;
      if (sport == CardioSport.running && profile.planning.easySpeed != null) {
        high = profile.planning.easySpeed;
      }
    }
    if (intensity == CardioIntensity.free) {
      low = null;
      high = null;
    }
    final fraction = switch (intensity) {
      CardioIntensity.easy => (.6, .7),
      CardioIntensity.recovery => (.5, .6),
      CardioIntensity.steady => (.7, .8),
      CardioIntensity.threshold => (.8, .9),
      CardioIntensity.interval => (.8, .95),
      CardioIntensity.free => (.5, 1.0),
    };
    return CardioStep(
      goal: goal,
      amount: amount,
      intensity: intensity,
      minSpeed: low,
      maxSpeed: high,
      minHeartRate:
          profile.planning.zoneMethod == 'manual' && profile.zones.isNotEmpty
              ? profile
                  .zones[switch (intensity) {
                    CardioIntensity.recovery => 0,
                    CardioIntensity.easy => 1,
                    CardioIntensity.steady => 2,
                    _ => 3,
                  }]
                  .$1
              : profile.pulse(fraction.$1),
      maxHeartRate:
          profile.planning.zoneMethod == 'manual' && profile.zones.isNotEmpty
              ? profile
                  .zones[switch (intensity) {
                    CardioIntensity.recovery => 0,
                    CardioIntensity.easy => 1,
                    CardioIntensity.steady => 2,
                    CardioIntensity.interval => 4,
                    _ => 3,
                  }]
                  .$2
              : profile.pulse(fraction.$2),
      primaryTarget: high == null ? 'effort' : 'pace',
      targetSource:
          high == null
              ? 'effort'
              : v == null
              ? 'estimated'
              : 'benchmark',
      repeat: repeat,
      recoverySeconds: recovery,
      movement:
          sport == CardioSport.walking
              ? 'walk'
              : sport == CardioSport.running
              ? 'run'
              : sport.name,
    );
  }

  static CardioStep refreshTarget(
    CardioStep step,
    AthleteRunningProfile profile, {
    DateTime? now,
    CardioSport sport = CardioSport.running,
    bool force = false,
  }) {
    if (!force && step.targetSource == 'manual') return step;
    var target = prescribe(profile, step.intensity, now: now, sport: sport);
    if (sport == CardioSport.running &&
        step.intensity == CardioIntensity.steady) {
      if (step.targetVariant == 'lightInterval' &&
          !profile.hasRecentBenchmark(
            now ?? DateTime.now(),
            maximumAgeDays: RunningRules.bundled.integer('benchmarkDays'),
          ) &&
          profile.easySpeed != null) {
        target = target.copyWith(
          minSpeed: profile.easySpeed,
          maxSpeed:
              profile.easySpeed! *
              RunningRules.bundled.number('lightSpeedFactor'),
        );
      } else if (step.targetVariant == 'progressionMid') {
        final slow =
            prescribe(profile, CardioIntensity.easy, now: now).maxSpeed;
        if (slow != null && target.maxSpeed != null) {
          target = target.copyWith(maxSpeed: (slow + target.maxSpeed!) / 2);
        }
      }
    }
    return step.copyWith(
      clearTargets: true,
      minSpeed: target.minSpeed,
      maxSpeed: target.maxSpeed,
      minHeartRate: target.minHeartRate,
      maxHeartRate: target.maxHeartRate,
      primaryTarget: target.primaryTarget,
      targetSource: target.targetSource,
    );
  }

  static CardioWorkout template(
    String code,
    AthleteRunningProfile p,
    CardioTranslate t, {
    CardioSport sport = CardioSport.running,
    bool indoor = false,
    DateTime? now,
  }) {
    CardioStep step(
      double amount, {
      CardioIntensity intensity = CardioIntensity.easy,
      StepGoal goal = StepGoal.time,
      int repeat = 1,
      double recovery = 0,
    }) => prescribe(
      p,
      intensity,
      amount: amount,
      goal: goal,
      repeat: repeat,
      recovery: recovery,
      now: now,
      sport: sport,
    );
    final easyStart = step(600), easyEnd = step(300);
    final List<CardioStep> steps;
    if (sport != CardioSport.running) {
      steps =
          code == 'intervalSession'
              ? [
                easyStart,
                step(
                  180,
                  intensity: CardioIntensity.interval,
                  repeat: 4,
                  recovery: 180,
                ),
                easyEnd,
              ]
              : [step(code == 'longRun' ? 3600 : 1800)];
    } else {
      steps = switch (code) {
        'easy5k' => [step(5000, goal: StepGoal.distance)],
        'longRun' => [
          p.longestMeters > 0
              ? step(p.longestMeters, goal: StepGoal.distance)
              : step(1800),
        ],
        'runWalk' => [
          step(300).copyWith(movement: 'walk'),
          step(60, repeat: 8, recovery: 90),
          step(300).copyWith(movement: 'walk'),
        ],
        'progression' => [
          easyStart,
          step(600, intensity: CardioIntensity.steady),
          step(300, intensity: CardioIntensity.threshold),
          easyEnd,
        ],
        'tempo' => [
          easyStart,
          step(900, intensity: CardioIntensity.steady),
          easyEnd,
        ],
        'threshold' => [
          easyStart,
          step(
            360,
            intensity: CardioIntensity.threshold,
            repeat: 3,
            recovery: 120,
          ),
          easyEnd,
        ],
        'fourByFour' => [
          easyStart,
          step(
            240,
            intensity: CardioIntensity.interval,
            repeat: 4,
            recovery: 180,
          ),
          easyEnd,
        ],
        'pyramid' => [
          easyStart,
          for (final d in [400, 600, 800, 600, 400]) ...[
            step(
              d.toDouble(),
              goal: StepGoal.distance,
              intensity: CardioIntensity.interval,
            ),
            step(
              120,
              intensity: CardioIntensity.recovery,
            ).copyWith(movement: 'walk'),
          ],
          easyEnd,
        ],
        'descending' => [
          easyStart,
          for (final d in [800, 600, 400, 200]) ...[
            step(
              d.toDouble(),
              goal: StepGoal.distance,
              intensity: CardioIntensity.interval,
            ),
            step(120, intensity: CardioIntensity.recovery),
          ],
          easyEnd,
        ],
        'fartlek' => [
          easyStart,
          step(60, intensity: CardioIntensity.steady, repeat: 6, recovery: 120),
          easyEnd,
        ],
        'strides' => [
          easyStart,
          step(
            20,
            intensity: CardioIntensity.interval,
            repeat: 4,
            recovery: 90,
          ),
          easyEnd,
        ],
        _ => [step(1800)],
      };
    }
    return CardioWorkout(
      name: t(code),
      sport: sport,
      indoor: indoor,
      steps: steps,
      templateCode: code,
      warmup: routine(sport == CardioSport.cycling ? 'cycling' : 'running'),
      cooldown: routine(
        sport == CardioSport.cycling ? 'cycling' : 'running',
        cooling: true,
      ),
    );
  }
}

class RunningPlanRequest {
  const RunningPlanRequest({
    required this.targetMeters,
    required this.startDate,
    this.targetSeconds,
    this.targetDate,
    this.goal,
    this.dayMinutes = const {},
    this.hardTrainingDays = const [],
    this.fitness,
  });
  final String? goal;
  final Map<int, int> dayMinutes;
  final List<int> hardTrainingDays;
  final RunningFitnessSnapshot? fitness;
  final double targetMeters;
  final DateTime startDate;
  final double? targetSeconds;
  final DateTime? targetDate;
  factory RunningPlanRequest.fromJson(Map<String, dynamic> j) =>
      RunningPlanRequest(
        targetMeters: (j['targetMeters'] as num).toDouble(),
        startDate: DateTime.parse(j['startDate'] as String),
        targetSeconds: (j['targetSeconds'] as num?)?.toDouble(),
        targetDate: DateTime.tryParse(j['targetDate'] as String? ?? ''),
        goal: j['goal'] as String?,
        dayMinutes: (j['dayMinutes'] as Map? ?? {}).map(
          (k, v) => MapEntry(int.parse('$k'), (v as num).toInt()),
        ),
        hardTrainingDays: List<int>.from(j['hardTrainingDays'] as List? ?? []),
        fitness:
            j['fitness'] is Map
                ? RunningFitnessSnapshot.fromJson(
                  Map<String, dynamic>.from(j['fitness'] as Map),
                )
                : null,
      );
  Map<String, dynamic> toJson() => {
    'targetMeters': targetMeters,
    'startDate': startDate.toIso8601String(),
    'targetSeconds': targetSeconds,
    'targetDate': targetDate?.toIso8601String(),
    'rulesVersion': RunningRules.bundled.version,
    'goal': goal,
    'dayMinutes': {for (final e in dayMinutes.entries) '${e.key}': e.value},
    'hardTrainingDays': hardTrainingDays,
    'fitness': fitness?.toJson(),
  };
}

class RunningPlanProposal {
  const RunningPlanProposal({
    required this.id,
    required this.request,
    required this.occurrences,
    required this.baseWeeks,
    required this.warnings,
  });
  final String id;
  final RunningPlanRequest request;
  final List<ScheduledCardioWorkout> occurrences;
  final int baseWeeks;
  final List<String> warnings;
}

class RunningPlanGenerator {
  RunningPlanProposal generate(
    AthleteRunningProfile p,
    RunningPlanRequest request,
    CardioTranslate t,
  ) => AdaptiveRunningPlanEngine().generate(p, request, t);
}
