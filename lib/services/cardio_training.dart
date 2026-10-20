import 'dart:math' as math;
import 'profile_readiness.dart';
import 'running_assessment.dart';

import '../models/cardio.dart';
import '../utils/uuid_v4.dart';

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
            ? profile.fiveKmSpeed(now ?? DateTime.now())
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
      final easyPace = ((1000 / easy * 1.05) / 5).ceil() * 5.0;
      switch (intensity) {
        case CardioIntensity.easy:
        case CardioIntensity.recovery:
          high = 1000 / easyPace;
        case CardioIntensity.steady:
          low = 1000 / easyPace;
          high = easy;
        case CardioIntensity.threshold:
          low = easy;
          high = easy / .95;
        case CardioIntensity.interval:
          low = easy;
          high = easy / .95;
        case CardioIntensity.free:
          break;
      }
    }
    if (intensity == CardioIntensity.easy ||
        intensity == CardioIntensity.recovery) {
      low = null;
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
      minHeartRate: profile.pulse(fraction.$1),
      maxHeartRate: profile.pulse(fraction.$2),
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
          !profile.hasRecentBenchmark(now ?? DateTime.now()) &&
          profile.easySpeed != null) {
        target = target.copyWith(
          minSpeed: profile.easySpeed,
          maxSpeed: profile.easySpeed! / .95,
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
          ).copyWith(
            // NTNU's 4x4 target is %HRmax, not %heart-rate reserve.
            minHeartRate:
                p.maximumHeartRate == null
                    ? null
                    : (p.maximumHeartRate! * .85).round(),
            maxHeartRate:
                p.maximumHeartRate == null
                    ? null
                    : (p.maximumHeartRate! * .95).round(),
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
  });
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
      );
  Map<String, dynamic> toJson() => {
    'targetMeters': targetMeters,
    'startDate': startDate.toIso8601String(),
    'targetSeconds': targetSeconds,
    'targetDate': targetDate?.toIso8601String(),
    'rulesVersion': 3,
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
  ) {
    ProfileReadiness.requireRunning(p, now: request.startDate);
    if (![5000, 10000, 21097.5, 42195].contains(request.targetMeters) ||
        (request.targetSeconds != null &&
            (!request.targetSeconds!.isFinite ||
                request.targetSeconds! <= 0))) {
      throw const FormatException('Invalid plan goal');
    }
    final id = UuidV4.generate();
    final blockWeeks =
        request.targetMeters <= 5000
            ? 8
            : request.targetMeters <= 10000
            ? 12
            : request.targetMeters < 42000
            ? 16
            : 20;
    final assessed = RunningAssessment.level(p);
    final novice = assessed == RunningLevel.starting;
    // Graduating from the walk/run phase does not make someone advanced.
    final beginner = novice || assessed == RunningLevel.beginner;
    final marathon = request.targetMeters > 42000;
    final minimumBase =
        novice
            ? 9
            : (marathon && (p.weeklyMeters < 30000 || p.longestMeters < 10000))
            ? 8
            : 0;
    final requestedWeeks =
        request.targetDate == null
            ? 0
            : (request.targetDate!.difference(request.startDate).inDays / 7)
                .ceil();
    if (requestedWeeks > 104) {
      throw const FormatException('Goal must be within two years');
    }
    final baseWeeks = math.max(minimumBase, requestedWeeks - blockWeeks);
    final warnings = <String>[
      if (baseWeeks > 0) 'basePhase',
      if (p.weekdays.length < (marathon ? 4 : 2)) 'infeasible',
      if (p.weekdays.any((d) => p.weekdays.contains(d % 7 + 1))) 'restDays',
      if (request.targetSeconds != null) 'targetTimeInfo',
    ];
    final weeks = baseWeeks + blockWeeks;
    if (request.targetDate != null &&
        requestedWeeks < minimumBase + blockWeeks) {
      warnings.add('infeasible');
    }
    final days = [...p.weekdays]..sort();
    final start = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final monday = DateTime(
      start.year,
      start.month,
      start.day - start.weekday + 1,
    );
    final easySpeed =
        CardioTraining.prescribe(p, CardioIntensity.easy, now: start).maxSpeed;
    // Race speed is not evidence of volume tolerance. Unknown load stays time-based.
    // With no benchmark use reported continuous duration, never infer speed.
    var weeklySeconds =
        easySpeed == null
            ? math.max(15, math.min(p.continuousMinutes, 45)) *
                60.0 *
                days.length
            : math.max(
              p.weeklyMeters / easySpeed,
              math.max(
                    math.min(p.continuousMinutes, 45) * 60.0,
                    !p.isMaximal && p.referenceSeconds != null
                        ? math.min(p.referenceSeconds!, 2700.0)
                        : 0.0,
                  ) *
                  math.min(days.length, p.recentRunsPerWeek ?? days.length),
            );
    weeklySeconds = math.max(weeklySeconds, 900.0 * days.length);
    final initialLong =
        easySpeed != null && p.longestMeters > 0
            ? p.longestMeters / easySpeed
            : math.max(900, p.continuousMinutes * 60).toDouble();
    final occurrences = <ScheduledCardioWorkout>[];
    for (var week = 0; week < weeks; week++) {
      final taper =
          request.targetMeters <= 10000
              ? 1
              : marathon
              ? 3
              : 2;
      final isTaper = week >= weeks - taper;
      final recoveryWeek = (week + 1) % 4 == 0 && !isTaper;
      if (week > 0 && !recoveryWeek && !isTaper && week >= baseWeeks) {
        weeklySeconds *= 1.05;
      }
      weeklySeconds = math.min(
        weeklySeconds,
        days.length * (marathon ? 5400.0 : 3600.0),
      );
      final budget =
          weeklySeconds *
          (isTaper
              ? math.pow(.8, week - (weeks - taper) + 1)
              : recoveryWeek
              ? .8
              : 1);
      for (var index = 0; index < days.length; index++) {
        final date = DateTime(
          monday.year,
          monday.month,
          monday.day + week * 7 + days[index] - 1,
        );
        if (date.isBefore(start)) continue;
        CardioWorkout workout;
        if (novice && week < 9) {
          final run =
              [60, 90, 120, 180, 300, 480, 720, 1200, 1800][week].toDouble();
          final count = [8, 6, 6, 5, 4, 3, 2, 1, 1][week];
          workout = CardioWorkout(
            name: t('runWalk'),
            templateCode: 'runWalk',
            warmup: CardioTraining.routine('running'),
            cooldown: CardioTraining.routine('running', cooling: true),
            steps: [
              CardioStep(amount: 300, movement: 'walk'),
              CardioTraining.prescribe(
                p,
                CardioIntensity.easy,
                amount: run,
                repeat: count,
                recovery: 90,
              ),
              CardioStep(amount: 300, movement: 'walk'),
            ],
          );
        } else {
          final isLong = index == days.length - 1 && days.length > 1;
          var qualityIndex = days.lastIndexWhere((day) => days.last - day >= 2);
          if (qualityIndex < 0 && beginner && days.length >= 2) {
            qualityIndex = 0;
          }
          final quality =
              !isTaper &&
              !recoveryWeek &&
              week >= (beginner ? 0 : baseWeeks) &&
              days.length >= 2 &&
              index == qualityIndex;
          final advancedSecond =
              assessed == RunningLevel.experienced &&
              days.length >= 5 &&
              index == 0 &&
              qualityIndex > 0 &&
              days[qualityIndex] - days.first >= 2 &&
              7 - days.last + days.first >= 2 &&
              !isTaper &&
              !recoveryWeek &&
              week >= baseWeeks;
          final longSeconds = math
              .min(initialLong * math.pow(1.05, week), budget * .4)
              .clamp(
                600.0,
                marathon
                    ? 10800.0
                    : request.targetMeters > 10000
                    ? 9000.0
                    : 6000.0,
              );
          final seconds =
              days.length == 1
                  ? budget
                  : isLong
                  ? longSeconds
                  : (budget - longSeconds) / (days.length - 1);
          final intensity =
              quality || advancedSecond
                  ? (beginner || week.isEven
                      ? CardioIntensity.steady
                      : CardioIntensity.threshold)
                  : CardioIntensity.easy;
          final code =
              isLong
                  ? 'longRun'
                  : quality || advancedSecond
                  ? (beginner || week.isEven ? 'progression' : 'threshold')
                  : 'easySession';
          final capped =
              isLong && easySpeed != null && p.longestMeters > 0
                  ? math.min(
                    math.max(600.0, seconds),
                    p.longestMeters * math.pow(1.05, week) / easySpeed,
                  )
                  : math.max(600.0, seconds);
          workout = CardioWorkout(
            name: t(code),
            templateCode: code,
            warmup: CardioTraining.routine('running'),
            cooldown: CardioTraining.routine('running', cooling: true),
            steps:
                intensity == CardioIntensity.easy
                    ? [
                      CardioTraining.prescribe(
                        p,
                        intensity,
                        goal:
                            isLong && easySpeed == null && p.longestMeters > 0
                                ? StepGoal.distance
                                : StepGoal.time,
                        amount:
                            isLong && easySpeed == null && p.longestMeters > 0
                                ? p.longestMeters * math.pow(1.05, week)
                                : capped,
                        now: start,
                      ),
                    ]
                    : [
                      CardioTraining.prescribe(
                        p,
                        CardioIntensity.easy,
                        amount: math.min(600, capped * .4),
                        now: start,
                      ),
                      CardioTraining.prescribe(
                        p,
                        intensity,
                        amount: math.max(
                          60,
                          capped -
                              math.min(600, capped * .4) -
                              math.min(300, capped * .2),
                        ),
                        now: start,
                      ),
                      CardioTraining.prescribe(
                        p,
                        CardioIntensity.easy,
                        amount: math.min(300, capped * .2),
                        now: start,
                      ),
                    ],
          );
          if (beginner && quality && week % 4 == 0) {
            final easy = CardioTraining.prescribe(
              p,
              CardioIntensity.easy,
              now: start,
            );
            final normal = CardioTraining.prescribe(
              p,
              CardioIntensity.steady,
              now: start,
            );
            final slow = easy.maxSpeed, fast = normal.maxSpeed;
            workout = CardioWorkout(
              name: t('progression'),
              templateCode: 'progression',
              warmup: workout.warmup,
              cooldown: workout.cooldown,
              steps: [
                easy.copyWith(id: UuidV4.generate(), amount: capped * .4),
                normal.copyWith(
                  id: UuidV4.generate(),
                  targetVariant: 'progressionMid',
                  amount: capped * .2,
                  maxSpeed:
                      slow == null || fast == null ? null : (slow + fast) / 2,
                ),
                normal.copyWith(id: UuidV4.generate(), amount: capped * .2),
                easy.copyWith(id: UuidV4.generate(), amount: capped * .2),
              ],
            );
          }
          if (quality &&
              ((beginner && week % 4 != 0) ||
                  (!beginner && week % 3 == 2 && capped >= 1200))) {
            // Scale interval density to the budget, keeping warm-up and easy exit.
            final advanced = !beginner && p.continuousMinutes >= 45;
            final warmupSeconds = math.min(600.0, capped * .5);
            final cooldownSeconds = math.min(300.0, capped * .2);
            final available = capped - warmupSeconds - cooldownSeconds;
            final reps =
                advanced
                    ? math.min(4, (available / 420).floor() + 1).clamp(2, 4)
                    : (available / (week % 4 == 2 ? 180 : 150)).floor().clamp(
                      1,
                      4,
                    );
            final recovery = advanced ? 180.0 : (week % 4 == 2 ? 120.0 : 90.0);
            final work = ((available - recovery * (reps - 1)) / reps).clamp(
              30.0,
              advanced ? 240.0 : 90.0,
            );
            final intervalCode =
                advanced || week % 4 == 2 ? 'intervalSession' : 'fartlek';
            var workStep = CardioTraining.prescribe(
              p,
              advanced ? CardioIntensity.interval : CardioIntensity.steady,
              amount: work,
              repeat: reps,
              recovery: recovery,
              now: start,
            );
            if (!advanced) {
              workStep = CardioTraining.refreshTarget(
                workStep.copyWith(targetVariant: 'lightInterval'),
                p,
                now: start,
              );
            }
            workout = CardioWorkout(
              name: t(intervalCode),
              templateCode: intervalCode,
              warmup: workout.warmup,
              cooldown: workout.cooldown,
              steps: [
                CardioTraining.prescribe(
                  p,
                  CardioIntensity.easy,
                  amount: warmupSeconds,
                  now: start,
                ),
                workStep,
                CardioTraining.prescribe(
                  p,
                  CardioIntensity.easy,
                  amount: cooldownSeconds,
                  now: start,
                ),
              ],
            );
          }
        }
        occurrences.add(
          ScheduledCardioWorkout(
            id: UuidV4.generate(),
            planId: id,
            date: date,
            workout: workout,
          ),
        );
      }
    }
    return RunningPlanProposal(
      id: id,
      request: request,
      occurrences: occurrences,
      baseWeeks: baseWeeks,
      warnings: warnings.toSet().toList(),
    );
  }
}
