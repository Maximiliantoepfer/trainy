import 'dart:math' as math;
import '../models/cardio.dart';
import '../utils/uuid_v4.dart';
import 'cardio_training.dart';
import 'profile_readiness.dart';
import 'running_assessment.dart';
import 'running_rules.dart';
import 'running_week_schedule.dart';
import 'running_routes.dart';
import '../models/running_preferences.dart';

/// Original, deterministic time-based templates. Calendar dates never graduate
/// a run/walk stage; only a confirmed adaptation can do that.
class AdaptiveRunningPlanEngine {
  AdaptiveRunningPlanEngine({RunningRules? rules})
    : rules = rules ?? RunningRules.bundled;
  final RunningRules rules;
  RunningPlanProposal generate(
    AthleteRunningProfile p,
    RunningPlanRequest request,
    CardioTranslate t,
  ) {
    ProfileReadiness.requireRunning(p, now: request.startDate);
    if (![5000, 10000, 21097.5, 42195].contains(request.targetMeters) ||
        request.dayMinutes.entries.any(
          (e) => e.key < 1 || e.key > 7 || e.value < 10 || e.value > 300,
        ) ||
        request.hardTrainingDays.any((d) => d < 1 || d > 7) ||
        (request.targetSeconds != null &&
            (!request.targetSeconds!.isFinite ||
                request.targetSeconds! <= 0))) {
      throw const FormatException('Invalid plan goal');
    }
    final config = rules.distance(request.targetMeters), planning = p.planning;
    final level = RunningAssessment.level(p);
    final novice = level == RunningLevel.starting;
    if (novice && (planning.walkMinutes ?? 0) <= 0) {
      throw const ProfileIncomplete('running', ['walkMinutes']);
    }
    final beginner = novice || level == RunningLevel.beginner;
    final goal = request.goal ?? planning.goal ?? 'runFaster';
    final days = _days(
      p.weekdays,
      math.min(planning.desiredDays ?? p.weekdays.length, 6),
      {...planning.hardTrainingDays, ...request.hardTrainingDays}.toList(),
    );
    final id = UuidV4.generate(), start = request.startDate;
    final monday = DateTime(
      start.year,
      start.month,
      start.day - start.weekday + 1,
    );
    final fitness = request.fitness;
    final restricted = planning.restricted || fitness?.difficult == true;
    final returningBase =
        p.returningAfterBreak &&
        (fitness?.toleratedRuns ?? 0) <
            rules.integer('returningSuccessfulSessions');
    final strenuousLong =
        (planning.longestEffort ?? 0) >= rules.number('strenuousLongEffort');
    final returningEasyOnly =
        returningBase &&
        (planning.breakWeeks ?? 0) >= rules.integer('returningLongBreakWeeks');
    final easy =
        CardioTraining.prescribe(p, CardioIntensity.easy, now: start).maxSpeed;
    final reported =
        planning.weeklyMinutes != null
            ? planning.weeklyMinutes! * 60
            : p.weeklyMeters > 0 && easy != null
            ? p.weeklyMeters / easy
            : 0.0;
    final measured = fitness?.weeklySeconds ?? 0;
    final base =
        measured > 0
            ? measured
            : reported > 0
            ? reported
            : math.max(10, math.min(p.continuousMinutes, 45)) *
                60.0 *
                math.min(
                  days.length,
                  math.max(1, p.recentRunsPerWeek ?? days.length),
                );
    final insufficient =
        !novice && base / 60 < (config['minimumMinutes'] as num);
    final baseWeeks =
        novice
            ? 9
            : insufficient
            ? 8
            : 0;
    final requestedWeeks =
        request.targetDate == null
            ? 0
            : (request.targetDate!.difference(start).inDays / 7).ceil();
    if (requestedWeeks > 104) {
      throw const FormatException('Goal must be within two years');
    }
    final block = config['weeks'] as int;
    // Insufficient foundations receive a base block, not a disguised race plan.
    final weeks =
        novice || insufficient ? baseWeeks : math.max(block, requestedWeeks);
    final warnings = <String>[
      if (novice || insufficient) 'basePhase',
      if (days.length == 1 || (request.targetMeters > 42000 && days.length < 4))
        'infeasible',
      if (request.targetDate != null && requestedWeeks < baseWeeks + block)
        'infeasible',
      if (request.targetSeconds != null) 'targetTimeInfo',
      if (restricted) 'restrictedTraining',
    ];
    final recentLong =
        (fitness?.longestSeconds ?? 0) > 0
            ? fitness!.longestSeconds
            : !strenuousLong &&
                planning.longestMinutes != null &&
                planning.longestDate != null &&
                !planning.longestDate!.isAfter(start) &&
                start.difference(planning.longestDate!).inDays <=
                    rules.integer('longRunDays')
            ? planning.longestMinutes! * 60
            : !strenuousLong &&
                p.longestMeters > 0 &&
                easy != null &&
                planning.longestDate != null &&
                !planning.longestDate!.isAfter(start) &&
                start.difference(planning.longestDate!).inDays <=
                    rules.integer('longRunDays')
            ? p.longestMeters / easy
            : math.min(
              p.continuousMinutes * 60.0,
              !strenuousLong && p.longestMeters > 0 && easy != null
                  ? p.longestMeters / easy
                  : double.infinity,
            );
    final initialLong = math.max(600.0, recentLong);
    final rotation = rules.rotation(beginner);
    final occurrences = <ScheduledCardioWorkout>[];
    final hard = {...planning.hardTrainingDays, ...request.hardTrainingDays};
    bool separated(int a, int b) =>
        math.min((a - b).abs(), 7 - (a - b).abs()) >= 2;
    double budget(int day) => ((request.dayMinutes[day] ??
                    planning.dayMinutes[day] ??
                    planning.minutesPerSession ??
                    60) *
                60.0 -
            360)
        .clamp(240, 17640);
    final schedule = RunningWeekSchedule.assign(days, hard, budget: budget);
    if (!novice && !restricted && schedule.qualityIndex < 0) {
      warnings.add('qualityScheduleConflict');
    }
    for (var week = 0; week < weeks; week++) {
      final recovery = (week + 1) % 4 == 0;
      final taper =
          !novice && !insufficient && week >= weeks - (config['taper'] as int);
      final loadFactor =
          recovery
              ? rules.number('recoveryFactor')
              : taper
              ? math
                  .pow(.8, week - weeks + (config['taper'] as int) + 1)
                  .toDouble()
              : 1.0;
      // If pace was just updated, this generation does not also increase volume.
      final paceRecentlyChanged =
          planning.paceUpdatedAt != null &&
          start.difference(planning.paceUpdatedAt!).inDays < 7;
      final growth =
          paceRecentlyChanged ||
                  novice ||
                  restricted ||
                  strenuousLong ||
                  returningBase
              ? 1.0
              : math
                  .pow(1 + rules.number('loadIncrease'), week ~/ 2)
                  .toDouble();
      final total =
          base *
          growth *
          loadFactor *
          (restricted ? rules.number('recoveryFactor') : 1);
      final longIndex = schedule.longIndex;
      final longDay = days[longIndex];
      final qualityIndex = schedule.qualityIndex;
      for (var index = 0; index < days.length; index++) {
        final date = DateTime(
          monday.year,
          monday.month,
          monday.day + week * 7 + days[index] - 1,
        );
        if (date.isBefore(DateTime(start.year, start.month, start.day))) {
          continue;
        }
        final cap = budget(days[index]);
        final qualityWeek =
            goal == 'runFaster' || goal == 'speed' || week.isEven;
        final quality =
            !novice &&
            !restricted &&
            !returningEasyOnly &&
            !recovery &&
            !taper &&
            qualityWeek &&
            (days.length > 1 || week % 3 == 1) &&
            index == qualityIndex &&
            hard.every((d) => separated(days[index], d));
        final secondQuality =
            !quality &&
            !returningBase &&
            !restricted &&
            level == RunningLevel.experienced &&
            planning.highLoadTolerated == true &&
            days.length >= 5 &&
            index == 0 &&
            qualityIndex > 0 &&
            separated(days.first, days[qualityIndex]) &&
            separated(days.first, longDay) &&
            hard.every((d) => separated(days.first, d)) &&
            !recovery &&
            !taper;
        final isLong =
            !quality &&
            index == longIndex &&
            (days.length > 1 || week % 3 == 2);
        final longSeconds = math.min(
          initialLong * growth * loadFactor,
          (config['longCapMinutes'] as num) * 60.0,
        );
        final regular =
            days.length > 2
                ? math.max(
                  240.0,
                  (total - math.min(budget(longDay), longSeconds)) /
                      (days.length - 1),
                )
                : total / days.length;
        final duration =
            math
                .min(
                  cap,
                  math.max(
                    240,
                    isLong ? longSeconds : math.min(regular, longSeconds),
                  ),
                )
                .toDouble();
        CardioWorkout workout;
        if (novice) {
          final stage = planning.runWalkStage.clamp(
            0,
            rules.runWalk.length - 1,
          );
          final template = rules.runWalk[stage];
          final walking = planning.walkPreparation == true;
          final work = (template['run'] as num).toDouble(),
              rest = (template['walk'] as num).toDouble();
          final count = math.max(
            1,
            math.min(
              template['repeat'] as int,
              ((cap - 60 + rest) / (work + rest)).floor(),
            ),
          );
          workout = CardioWorkout(
            name: t(walking ? 'walkPreparation' : 'runWalk'),
            templateCode: walking ? 'walkPreparation' : 'runWalk',
            ruleVersion: rules.version,
            runWalkStage: stage,
            targetsUpdatedAt: start,
            trainingPhase: 'base',
            steps:
                walking
                    ? [
                      CardioStep(
                        amount: math.min(
                          cap,
                          (planning.walkMinutes ?? 15) * 60.0,
                        ),
                        movement: 'walk',
                        primaryTarget: 'effort',
                      ),
                    ]
                    : [
                      CardioStep(
                        amount: math.min(work, cap - 60),
                        repeat: count,
                        recoverySeconds: rest,
                        primaryTarget: 'effort',
                        targetSource: 'effort',
                      ),
                      CardioStep(
                        amount: 60,
                        movement: 'walk',
                        primaryTarget: 'effort',
                        targetSource: 'effort',
                      ),
                    ],
            warmup: CardioTraining.routine('running'),
            cooldown: CardioTraining.routine('running', cooling: true),
          );
        } else {
          final code =
              quality || secondQuality
                  ? returningBase
                      ? 'progression'
                      : rotation[(week - week ~/ 4 + (secondQuality ? 2 : 0)) %
                          rotation.length]
                  : isLong
                  ? 'longRun'
                  : 'easySession';
          final steps = <CardioStep>[];
          CardioStep prescribe(double amount, CardioIntensity intensity) =>
              CardioTraining.prescribe(
                p,
                intensity,
                amount: amount,
                now: start,
              );
          if (!quality && !secondQuality) {
            steps.add(prescribe(duration, CardioIntensity.easy));
          } else if (code == 'progression') {
            final easyTarget = prescribe(duration * .5, CardioIntensity.easy);
            final normal = prescribe(duration * .2, CardioIntensity.steady);
            steps.addAll([
              easyTarget,
              normal.copyWith(
                id: UuidV4.generate(),
                amount: duration * .15,
                targetVariant: 'progressionMid',
                maxSpeed:
                    easyTarget.maxSpeed == null || normal.maxSpeed == null
                        ? null
                        : (easyTarget.maxSpeed! + normal.maxSpeed!) / 2,
              ),
              normal,
              prescribe(duration * .15, CardioIntensity.easy),
            ]);
          } else {
            final warm = duration * .35,
                cool = duration * .2,
                available = duration - warm - cool;
            final repetitions =
                code == 'tempo'
                    ? 1
                    : math.min(
                      beginner ? 4 : 6,
                      math.max(1, (available / (beginner ? 150 : 240)).floor()),
                    );
            final rest =
                repetitions > 1
                    ? math.min(
                      beginner ? 90.0 : 120.0,
                      available / (repetitions * 2),
                    )
                    : 0.0;
            final work = math.min(
              beginner ? 90.0 : double.infinity,
              (available - rest * (repetitions - 1)) / repetitions,
            );
            final remainder =
                available - work * repetitions - rest * (repetitions - 1);
            var stimulus = prescribe(
              work,
              beginner
                  ? CardioIntensity.steady
                  : ['tempo', 'threshold'].contains(code)
                  ? CardioIntensity.threshold
                  : CardioIntensity.interval,
            ).copyWith(repeat: repetitions, recoverySeconds: rest);
            if (beginner) {
              stimulus = CardioTraining.refreshTarget(
                stimulus.copyWith(targetVariant: 'lightInterval'),
                p,
                now: start,
              );
            }
            if (code == 'hills') {
              stimulus = stimulus.copyWith(
                clearTargets: true,
                primaryTarget: 'effort',
                targetSource: 'effort',
              );
            }
            steps.addAll([
              prescribe(warm + remainder, CardioIntensity.easy),
              stimulus,
              prescribe(cool, CardioIntensity.easy),
            ]);
          }
          FavoriteRunningRoute? route;
          double? estimated;
          if (easy != null && !restricted) {
            // Legacy distances migrate on read. An explicitly empty list means
            // that the user removed them; never resurrect the old preference.
            final preferences = planning.favoriteRoutes;
            // Fixed quality/recovery repetitions remain unchanged. Only the last easy
            // portion fills the chosen total, using live total distance at runtime.
            double estimateMeters(CardioStep s) =>
                s.goal == StepGoal.distance
                    ? s.amount
                    : s.amount * s.repeat * (s.maxSpeed ?? easy) +
                        s.recoverySeconds *
                            (s.repeat - 1) *
                            easy *
                            rules.number('recoverySpeedFactor');
            final priorMeters = steps
                .take(steps.length - 1)
                .fold<double>(0, (sum, s) => sum + estimateMeters(s));
            final priorSeconds = steps
                .take(steps.length - 1)
                .fold<double>(
                  0,
                  (sum, s) =>
                      sum +
                      (s.goal == StepGoal.time
                          ? s.amount * s.repeat +
                              s.recoverySeconds * (s.repeat - 1)
                          : s.amount / easy),
                );
            // 10% time reserve: an easy ceiling is not a promised speed.
            final maximum =
                math.min(duration, cap) *
                easy /
                rules.number('routeTimeReserveFactor');
            route = RunningRoutes.select(
              preferences,
              weekday: days[index],
              maximumMeters: maximum,
              minimumMeters:
                  (quality || secondQuality)
                      ? priorMeters + easy * 60
                      : isLong
                      ? maximum * .8
                      : 0,
              defaultMeters: rules.number('defaultRouteMeters'),
            );
            if (route != null) {
              final last = steps.removeLast();
              steps.add(
                last.copyWith(
                  goal: StepGoal.distance,
                  amount: route.meters - priorMeters,
                  routeTotalMeters: route.meters,
                ),
              );
              estimated =
                  priorSeconds + (route.meters - priorMeters) / easy + 360;
            }
          }
          workout = CardioWorkout(
            routeName: route?.name,
            routeMeters: route?.meters,
            estimatedSeconds: estimated ?? duration + 360,
            name: t(code),
            templateCode: code,
            ruleVersion: rules.version,
            steps: steps,
            targetsUpdatedAt: start,
            trainingPhase:
                taper
                    ? 'taper'
                    : recovery
                    ? 'recovery'
                    : insufficient
                    ? 'base'
                    : 'build',
            warmup: CardioTraining.routine('running'),
            cooldown: CardioTraining.routine('running', cooling: true),
          );
        }
        workout.validate();
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

  List<int> _days(List<int> available, int desired, List<int> hard) {
    final sorted = [...available]..sort();
    if (desired >= sorted.length) return sorted;
    List<int> best = sorted.take(desired).toList();
    var bestScore = double.negativeInfinity;
    for (var mask = 1; mask < (1 << sorted.length); mask++) {
      final choice = [
        for (var i = 0; i < sorted.length; i++)
          if (mask & (1 << i) != 0) sorted[i],
      ];
      if (choice.length != desired) continue;
      final gaps = [
        for (var i = 0; i < choice.length; i++)
          (choice[(i + 1) % choice.length] - choice[i] + 7) % 7,
      ];
      final score =
          gaps.fold<double>(0, (n, g) => n + math.min(g, 2)) -
          choice.where(hard.contains).length * .5;
      if (score > bestScore) {
        best = choice;
        bestScore = score;
      }
    }
    return best;
  }
}
