import 'dart:math' as math;

import '../models/cardio.dart';
import '../utils/uuid_v4.dart';

typedef CardioTranslate = String Function(String key);

abstract final class CardioTraining {
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
        sport == CardioSport.running
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
            profile.referenceMeters *
            math.pow(3600 / profile.referenceSeconds!, 1 / 1.06);
        low = distance / 3600 * .97;
        high = distance / 3600 * 1.03;
      }
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
      primaryTarget: v == null ? 'effort' : 'pace',
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
    'rulesVersion': 2,
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
    p.validate();
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
    final novice =
        p.canRunFiveKm == false ||
        (p.canRunFiveKm != true &&
            (p.level == RunningLevel.starting ||
                (p.level == null &&
                    p.continuousMinutes > 0 &&
                    p.continuousMinutes < 30)));
    final unknown =
        p.canRunFiveKm == null &&
        p.continuousMinutes == 0 &&
        p.weeklyMeters == 0;
    final establishedBeginner =
        p.canRunFiveKm == true && (p.recentRunsPerWeek ?? 0) >= 2;
    final marathon = request.targetMeters > 42000;
    final minimumBase =
        novice
            ? 9
            : !establishedBeginner && p.experienceMonths < 2
            ? 2
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
      if (p.weekdays.length < (marathon ? 4 : 3)) 'infeasible',
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
    final benchmarkSpeed = p.fiveKmSpeed(start);
    final easySpeed = benchmarkSpeed == null ? null : benchmarkSpeed * .725;
    // Race speed is not evidence of volume tolerance. Unknown load stays time-based.
    // With no benchmark use reported continuous duration, never infer speed.
    var weeklySeconds =
        easySpeed == null
            ? math.max(15, math.min(p.continuousMinutes, 45)) *
                60.0 *
                days.length
            : math.max(
              p.weeklyMeters / easySpeed,
              math.min(p.continuousMinutes, 30) * 60.0 * days.length,
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
          final qualityIndex = days.lastIndexWhere(
            (day) => days.last - day >= 2,
          );
          final quality =
              !isTaper &&
              !recoveryWeek &&
              !unknown &&
              week >= (establishedBeginner ? 1 : math.max(baseWeeks, 2)) &&
              days.length >= 3 &&
              index == qualityIndex;
          final advancedSecond =
              (p.level == RunningLevel.experienced ||
                  p.experienceMonths >= 12) &&
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
                  ? (week.isEven
                      ? CardioIntensity.steady
                      : CardioIntensity.threshold)
                  : CardioIntensity.easy;
          final code =
              isLong
                  ? 'longRun'
                  : quality || advancedSecond
                  ? (week.isEven ? 'progression' : 'threshold')
                  : 'easySession';
          final capped = math.max(600.0, seconds);
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
                        amount: capped,
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
          if (quality &&
              ((establishedBeginner && week <= 2) ||
                  (week % 3 == 2 && capped >= 1200))) {
            // Scale interval density to the budget, keeping warm-up and easy exit.
            final advanced =
                !(establishedBeginner && week <= 2) &&
                (p.level == RunningLevel.intermediate ||
                    p.level == RunningLevel.experienced ||
                    p.experienceMonths >= 6) &&
                p.continuousMinutes >= 45;
            final warmupSeconds = math.min(600.0, capped * .5);
            final cooldownSeconds = math.min(300.0, capped * .2);
            final available = capped - warmupSeconds - cooldownSeconds;
            final reps =
                advanced
                    ? math.min(4, (available / 420).floor() + 1).clamp(2, 4)
                    : (available / 120).floor().clamp(1, 4);
            final recovery = advanced ? 180.0 : 90.0;
            final work = ((available - recovery * (reps - 1)) / reps).clamp(
              30.0,
              advanced ? 240.0 : 90.0,
            );
            final intervalCode = advanced ? 'intervalSession' : 'fartlek';
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
                CardioTraining.prescribe(
                  p,
                  advanced ? CardioIntensity.interval : CardioIntensity.steady,
                  amount: work,
                  repeat: reps,
                  recovery: recovery,
                  now: start,
                ),
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
