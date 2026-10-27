import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import '../models/cardio.dart';
import 'cardio_training.dart';
import 'running_rules.dart';

class RunFeedback {
  const RunFeedback({
    required this.effort,
    required this.discomfort,
    this.talkComfort,
    this.recovery,
    this.environment = 'unknown',
    this.runType,
    this.continuous,
  });
  final int effort;
  final bool discomfort;
  final bool? talkComfort;
  final bool? continuous;
  final String? recovery, runType;
  final String environment;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'rpe': effort,
    'discomfort': discomfort,
    'talkComfort': talkComfort,
    'recovery': recovery,
    'environment': environment,
    'runType': runType,
    'continuous': continuous,
  };
  factory RunFeedback.fromJson(Map<String, dynamic> j) => RunFeedback(
    effort: (j['rpe'] as num?)?.toInt() ?? 0,
    discomfort: j['discomfort'] == true,
    talkComfort: j['talkComfort'] as bool?,
    recovery: j['recovery'] as String?,
    environment: j['environment'] as String? ?? 'unknown',
    runType: j['runType'] as String?,
    continuous: j['continuous'] as bool?,
  );
}

class RunningFitnessSnapshot {
  const RunningFitnessSnapshot({
    required this.asOf,
    this.sourceIds = const [],
    this.easySourceIds = const [],
    this.concernSourceIds = const [],
    this.excluded = const {},
    this.weeklySeconds = 0,
    this.longestSeconds = 0,
    this.easySpeed,
    this.difficult = false,
    this.successfulRunWalk = 0,
    this.toleratedRuns = 0,
    this.comparableEnvironment,
  });
  final DateTime asOf;
  final List<String> sourceIds, easySourceIds, concernSourceIds;
  final Map<String, String> excluded;
  final double weeklySeconds, longestSeconds;
  final double? easySpeed;
  final bool difficult;
  final int successfulRunWalk, toleratedRuns;
  final String? comparableEnvironment;
  factory RunningFitnessSnapshot.fromJson(Map<String, dynamic> j) =>
      RunningFitnessSnapshot(
        asOf: DateTime.parse(j['asOf'] as String),
        sourceIds: List<String>.from(j['sourceIds'] as List? ?? []),
        easySourceIds: List<String>.from(j['easySourceIds'] as List? ?? []),
        concernSourceIds: List<String>.from(
          j['concernSourceIds'] as List? ?? [],
        ),
        excluded: Map<String, String>.from(j['excluded'] as Map? ?? {}),
        weeklySeconds: (j['weeklySeconds'] as num?)?.toDouble() ?? 0,
        longestSeconds: (j['longestSeconds'] as num?)?.toDouble() ?? 0,
        easySpeed: (j['easySpeed'] as num?)?.toDouble(),
        difficult: j['difficult'] == true,
        successfulRunWalk: j['successfulRunWalk'] as int? ?? 0,
        toleratedRuns: j['toleratedRuns'] as int? ?? 0,
        comparableEnvironment: j['environment'] as String?,
      );
  Map<String, dynamic> toJson() => {
    'asOf': asOf.toIso8601String(),
    'sourceIds': sourceIds,
    'easySourceIds': easySourceIds,
    'concernSourceIds': concernSourceIds,
    'excluded': excluded,
    'weeklySeconds': weeklySeconds,
    'longestSeconds': longestSeconds,
    'easySpeed': easySpeed,
    'difficult': difficult,
    'successfulRunWalk': successfulRunWalk,
    'toleratedRuns': toleratedRuns,
    'environment': comparableEnvironment,
  };
}

class RunningAdaptationProposal {
  const RunningAdaptationProposal({
    required this.createdAt,
    required this.ruleVersion,
    required this.fitness,
    required this.changes,
    required this.reason,
    this.easySpeed,
    this.runWalkStage,
    this.walkPreparation,
    this.originals = const {},
    this.expectedDates = const {},
    this.inputFingerprint,
  });
  final DateTime createdAt;
  final int ruleVersion;
  final RunningFitnessSnapshot fitness;
  final Map<String, CardioWorkout> changes;
  final String reason;
  final double? easySpeed;
  final int? runWalkStage;
  final bool? walkPreparation;
  final Map<String, String> originals, expectedDates;
  final String? inputFingerprint;
  String get evidenceKey =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode([
                ruleVersion,
                reason,
                (reason == 'easyPaceEvidence'
                        ? fitness.easySourceIds
                        : reason == 'reduceLoad'
                        ? fitness.concernSourceIds
                        : fitness.sourceIds)
                    .toList()
                  ..sort(),
                if (reason == 'structure') changes.keys.toList()..sort(),
                if (reason == 'runWalkProgress') runWalkStage,
              ]),
            ),
          )
          .toString();
  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toIso8601String(),
    'ruleVersion': ruleVersion,
    'fitness': fitness.toJson(),
    'reason': reason,
    'easySpeed': easySpeed,
    'runWalkStage': runWalkStage,
    'walkPreparation': walkPreparation,
    'changes': {for (final e in changes.entries) e.key: e.value.toJson()},
    'evidenceKey': evidenceKey,
  };
}

/// Pure, deterministic interpretation. No history is rewritten and no plan is applied here.
class RunningFitness {
  RunningFitness({RunningRules? rules}) : rules = rules ?? RunningRules.bundled;
  final RunningRules rules;
  RunningFitnessSnapshot evaluate(
    List<Map<String, Object?>> history,
    DateTime now, {
    int runWalkStage = 0,
    DateTime? stageSince,
  }) {
    final included = <String>[],
        excluded = <String, String>{},
        seen = <String>{};
    final groups = <String, List<({String id, double speed, DateTime date})>>{};
    final intervals = <({String id, int start, int end})>[];
    double total = 0, longest = 0;
    var difficult = false, successes = 0, tolerated = 0;
    final concerns = <String>[];
    final sorted = [...history]..sort(
      (a, b) => ((b['started_at_utc'] as num?) ?? 0).compareTo(
        (a['started_at_utc'] as num?) ?? 0,
      ),
    );
    for (final row in sorted) {
      final id = row['id'] as String? ?? '';
      try {
        final runtime =
            jsonDecode(row['runtime_json'] as String) as Map<String, dynamic>;
        final snapshot =
            jsonDecode(row['snapshot_json'] as String) as Map<String, dynamic>;
        final date = DateTime.fromMillisecondsSinceEpoch(
          row['started_at_utc'] as int,
        );
        final age = now.difference(date).inSeconds / 86400;
        if (age < 0 ||
            age > rules.number('longRunDays') ||
            runtime['status'] != 'completed' ||
            runtime['sport'] != 'running') {
          continue;
        }
        final source = row['source'] as String?;
        if (source != 'manual' && snapshot['health'] == null) {
          excluded[id] = 'unaccepted';
          continue;
        }
        final health = snapshot['health'] as Map?;
        final identity =
            health == null
                ? id
                : '${health['provider']}:${health['sourceId']}:${health['externalId']}';
        if (!seen.add(identity)) {
          excluded[id] = 'duplicate';
          continue;
        }
        final seconds = (runtime['activeSeconds'] as num?)?.toDouble() ?? 0;
        final meters = (runtime['distanceMeters'] as num?)?.toDouble() ?? 0;
        if (!seconds.isFinite ||
            seconds <= 0 ||
            !meters.isFinite ||
            meters < 0) {
          excluded[id] = 'invalid';
          continue;
        }
        final feedbackJson = snapshot['feedback'] as Map?;
        final feedback =
            feedbackJson == null
                ? null
                : RunFeedback.fromJson(Map<String, dynamic>.from(feedbackJson));
        final bad =
            feedback != null &&
            (feedback.discomfort ||
                feedback.effort >= 8 ||
                feedback.recovery == 'poor');
        if (age <= 14 && bad) {
          difficult = true;
          concerns.add(id);
        }
        // Providers can export the same run under different IDs. Do not add
        // overlapping recordings to load or let them count as three easy runs.
        final begin = date.millisecondsSinceEpoch;
        final end =
            (runtime['endedAt'] as num?)?.toInt() ??
            begin + (seconds * 1000).round();
        final overlaps = intervals.any(
          (i) =>
              math.min(end, i.end) - math.max(begin, i.start) >
              math.min(end - begin, i.end - i.start) * .8,
        );
        if (overlaps) {
          excluded[id] = 'overlappingRecording';
          continue;
        }
        intervals.add((id: id, start: begin, end: end));
        final healthContinuous =
            health != null &&
            feedback?.continuous == true &&
            runtime['hadPause'] != true;
        final knownDuration =
            runtime['durationBasis'] != 'elapsed' || healthContinuous;
        // A stopped/partially recorded session may still report symptoms, but
        // cannot prove a tolerated long run or justify a load/pace increase.
        if (runtime['finishedEarly'] == true ||
            runtime['recovered'] == true ||
            (runtime['results'] as List? ?? []).any(
              (r) => (r as Map)['partial'] == true,
            )) {
          excluded[id] = 'incomplete';
          continue;
        }
        if (age <= 14 &&
            feedback != null &&
            !bad &&
            feedback.effort > 0 &&
            feedback.effort <= 5 &&
            feedback.recovery == 'ready' &&
            runtime['finishedEarly'] != true &&
            ((runtime['results'] as List? ?? []).isNotEmpty ||
                healthContinuous) &&
            (runtime['results'] as List? ?? []).every(
              (r) => (r as Map)['partial'] != true,
            )) {
          tolerated++;
        }
        if (!bad && knownDuration) {
          longest = math.max(longest, seconds);
        }
        if (age <= rules.number('historyDays') && knownDuration) {
          total += seconds;
          included.add(id);
        }
        final workout = snapshot['workout'] as Map? ?? snapshot;
        final template = workout['templateCode'] as String?;
        if (['runWalk', 'walkPreparation'].contains(template) &&
            age <= rules.number('historyDays') &&
            (stageSince == null || date.isAfter(stageSince)) &&
            workout['runWalkStage'] == runWalkStage &&
            feedback != null &&
            feedback.effort > 0 &&
            feedback.effort <= 5 &&
            !feedback.discomfort &&
            feedback.talkComfort == true &&
            feedback.recovery == 'ready' &&
            runtime['finishedEarly'] != true &&
            (runtime['results'] as List? ?? []).isNotEmpty &&
            (runtime['results'] as List? ?? []).every(
              (r) => (r as Map)['partial'] != true,
            )) {
          successes++;
        }
        final steps = workout['steps'] as List? ?? [];
        final easy =
            ['easy5k', 'easySession', 'longRun'].contains(template) ||
            (steps.isNotEmpty &&
                steps.every(
                  (s) =>
                      (s as Map)['intensity'] == 'easy' &&
                      s['movement'] != 'walk' &&
                      ((s['repeat'] as num?) ?? 1) == 1,
                )) ||
            (health != null && feedback?.runType == 'easy');
        final coverage = (runtime['gpsCoveredSeconds'] as num?)?.toDouble();
        final quality =
            healthContinuous &&
                    runtime['distanceMeasured'] == true &&
                    (health['sourceId'] as String? ?? '').isNotEmpty
                ? true
                : runtime['indoor'] == true
                ? runtime['distanceMeasured'] == true
                : coverage != null &&
                    coverage / seconds >= rules.number('minimumGpsCoverage');
        if (age > rules.number('historyDays') ||
            !easy ||
            !quality ||
            runtime['distanceMeasured'] == false ||
            seconds < rules.number('minimumEasySeconds') ||
            meters <= 0 ||
            meters / seconds > 8 ||
            runtime['hadPause'] == true ||
            runtime['finishedEarly'] == true ||
            (runtime['results'] as List? ?? []).any(
              (r) => (r as Map)['partial'] == true,
            ) ||
            !knownDuration ||
            runtime['recovered'] == true ||
            feedback?.talkComfort != true ||
            feedback == null ||
            feedback.discomfort ||
            feedback.effort < 1 ||
            feedback.effort > 5 ||
            feedback.recovery != 'ready') {
          excluded[id] = 'notComparableEasy';
          continue;
        }
        final environment =
            '${runtime['indoor'] == true ? 'indoor' : 'outdoor'}:${feedback.environment}'
            '${source != 'manual' && health != null ? ':health:${health['sourceId']}' : ''}';
        groups.putIfAbsent(environment, () => []).add((
          id: id,
          speed: meters / seconds,
          date: date,
        ));
      } catch (_) {
        excluded[id] = 'malformed';
      }
    }
    final candidates =
        groups.entries
            .where((g) => g.value.length >= rules.integer('minimumEasyRuns'))
            .toList()
          ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date));
    double? estimate;
    final easyIds = <String>[];
    if (candidates.isNotEmpty) {
      final sample =
          candidates.first.value.take(rules.integer('maximumEasyRuns')).toList()
            ..sort((a, b) => a.speed.compareTo(b.speed));
      // Robust outlier screening precedes weighting: recency alone must not
      // give an unusually fast latest recording the deciding vote.
      final median = sample[sample.length ~/ 2].speed;
      final deviations =
          sample.map((s) => (s.speed - median).abs()).toList()..sort();
      final tolerance = math.max(
        median * .15,
        deviations[deviations.length ~/ 2] * 3,
      );
      sample.removeWhere((s) {
        if ((s.speed - median).abs() <= tolerance) return false;
        excluded[s.id] = 'paceOutlier';
        return true;
      });
      double weight(DateTime date) => 1 / (1 + now.difference(date).inDays / 7);
      final totalWeight = sample.fold<double>(0, (n, s) => n + weight(s.date));
      var cumulative = 0.0;
      for (final item
          in sample.length >= rules.integer('minimumEasyRuns')
              ? sample
              : <({String id, double speed, DateTime date})>[]) {
        cumulative += weight(item.date);
        if (cumulative >= totalWeight / 2) {
          estimate = item.speed;
          break;
        }
      }
      if (estimate != null) easyIds.addAll(sample.map((s) => s.id));
    }
    return RunningFitnessSnapshot(
      asOf: now,
      sourceIds: included,
      easySourceIds: easyIds,
      concernSourceIds: concerns,
      excluded: excluded,
      weeklySeconds: total / 4,
      longestSeconds: longest,
      easySpeed: estimate,
      difficult: difficult,
      successfulRunWalk: successes,
      toleratedRuns: tolerated,
      comparableEnvironment: candidates.firstOrNull?.key,
    );
  }

  RunningAdaptationProposal propose(
    AthleteRunningProfile profile,
    RunningFitnessSnapshot fitness,
    List<ScheduledCardioWorkout> occurrences,
    CardioTranslate t,
  ) {
    final now = fitness.asOf, planning = profile.planning;
    final previous =
        planning.easySpeed ??
        CardioTraining.prescribe(
          profile,
          CardioIntensity.easy,
          now: now,
        ).maxSpeed;
    final last = planning.paceUpdatedAt;
    double? speed;
    var reason = 'insufficientEvidence';
    int? stage;
    bool? walking;
    if (fitness.difficult || planning.restricted) {
      reason = 'reduceLoad';
    } else if (fitness.successfulRunWalk >=
            rules.integer('successfulRunWalkSessions') &&
        (planning.runWalkStage < 8 || planning.walkPreparation == true)) {
      stage = planning.walkPreparation == true ? 0 : planning.runWalkStage + 1;
      if (planning.walkPreparation == true) walking = false;
      reason = 'runWalkProgress';
    } else if (fitness.easySpeed != null &&
        (last == null ||
            now.difference(last).inDays >= rules.integer('paceChangeDays'))) {
      speed =
          previous == null
              ? fitness.easySpeed
              : math.min(
                fitness.easySpeed!,
                previous * (1 + rules.number('maximumSpeedIncrease')),
              );
      // An easy update does not silently turn an old normal reference into
      // a faster performance test or invert progression targets.
      if (profile.easySpeed != null) {
        speed = math.min(speed!, profile.easySpeed!);
      }
      if (previous == null || (speed! - previous).abs() / previous > .005) {
        reason = 'easyPaceEvidence';
      } else {
        speed = null;
      }
    }
    final priorChanges =
        planning.adaptationHistory
            .map((e) => DateTime.tryParse(e['createdAt'] as String? ?? ''))
            .whereType<DateTime>();
    if (reason == 'insufficientEvidence' &&
        fitness.toleratedRuns >= 3 &&
        profile.continuousMinutes >= 30 &&
        (last == null ||
            now.difference(last).inDays >= rules.integer('paceChangeDays')) &&
        priorChanges.every((date) => now.difference(date).inDays >= 7)) {
      reason = 'buildLoad';
    }
    final changes = <String, CardioWorkout>{};
    for (final o in occurrences) {
      final date = DateTime(o.date.year, o.date.month, o.date.day);
      final today = DateTime(now.year, now.month, now.day);
      if (o.status != 'planned' ||
          o.sessionId != null ||
          o.locked ||
          date.isBefore(today) ||
          (reason != 'easyPaceEvidence' &&
              date.difference(today).inDays >
                  rules.integer('adaptationDays')) ||
          o.workout.sport != CardioSport.running) {
        continue;
      }
      final w = o.workout;
      // A planned recovery/taper must not be undone by a positive adaptation.
      // Legacy plans have no reliable phase metadata; never guess their load.
      if (!['reduceLoad', 'easyPaceEvidence'].contains(reason) &&
          !['base', 'build'].contains(w.trainingPhase)) {
        continue;
      }
      if (reason == 'buildLoad' &&
          w.steps.every(
            (s) =>
                s.goal == StepGoal.time &&
                s.intensity == CardioIntensity.easy &&
                s.repeat == 1,
          )) {
        final duration = w.steps.fold<double>(0, (n, s) => n + s.amount);
        final routines = [
          ...w.warmup,
          ...w.cooldown,
        ].fold<int>(0, (n, s) => n + s.seconds);
        final cap =
            (planning.dayMinutes[o.date.weekday] ??
                    planning.minutesPerSession ??
                    60) *
                60 -
            routines;
        final loadCap =
            fitness.weeklySeconds / math.max(1, planning.desiredDays ?? 3);
        // Never catch up missing volume or make a long run exceed recent
        // demonstrated tolerance. Phase protection is checked above.
        final ceiling =
            w.templateCode == 'longRun' ? fitness.longestSeconds : loadCap;
        final next = math.min(
          duration * (1 + rules.number('loadIncrease')),
          math.min(cap.toDouble(), ceiling),
        );
        if (duration > 0 && next > duration + 15) {
          changes[o.id] = CardioWorkout.fromJson({
            ...w.toJson(),
            'steps': [
              for (final s in w.steps)
                (s.targetSource == 'manual'
                        ? s
                        : s.copyWith(amount: s.amount * next / duration))
                    .toJson(),
            ],
          });
        }
      } else if (reason == 'reduceLoad') {
        changes[o.id] = CardioWorkout.fromJson({
          ...w.toJson(),
          'steps': [
            for (final s in w.steps)
              if (s.targetSource == 'manual')
                s.toJson()
              else
                CardioTraining.prescribe(
                  profile,
                  CardioIntensity.easy,
                  goal: s.goal,
                  amount: s.amount * rules.number('recoveryFactor'),
                  repeat: s.repeat,
                  recovery: s.recoverySeconds,
                  now: now,
                ).copyWith(id: s.id, movement: s.movement).toJson(),
          ],
        });
      } else if (speed != null &&
          w.steps.any(
            (s) =>
                s.targetSource != 'manual' &&
                s.intensity == CardioIntensity.easy,
          )) {
        changes[o.id] = CardioWorkout.fromJson({
          ...w.toJson(),
          'targetsUpdatedAt': now.toIso8601String(),
          'targetEvidenceIds': fitness.easySourceIds,
          'steps': [
            for (final s in w.steps)
              _paceTarget(s, profile, speed, now).toJson(),
          ],
        });
      } else if (stage != null &&
          ['runWalk', 'walkPreparation'].contains(w.templateCode) &&
          w.steps.every((s) => s.targetSource != 'manual')) {
        final template = rules.runWalk[stage];
        final budget =
            (planning.dayMinutes[o.date.weekday] ??
                    planning.minutesPerSession ??
                    60) *
                60.0 -
            360;
        final work = (template['run'] as num).toDouble();
        final rest = (template['walk'] as num).toDouble();
        if (work > budget) continue;
        final repetitions = math.max(
          1,
          math.min(
            template['repeat'] as int,
            ((budget + rest) / (work + rest)).floor(),
          ),
        );
        final planned = CardioTraining.prescribe(
          profile,
          CardioIntensity.easy,
          amount: work,
          repeat: repetitions,
          recovery: rest,
          now: now,
        ).copyWith(primaryTarget: 'effort', clearTargets: true);
        changes[o.id] = CardioWorkout.fromJson({
          ...w.toJson(),
          if (walking == false) 'name': t('runWalk'),
          'templateCode': 'runWalk',
          'runWalkStage': stage,
          'steps': [planned.toJson()],
        });
      }
    }
    final proposal = RunningAdaptationProposal(
      createdAt: now,
      ruleVersion: rules.version,
      fitness: fitness,
      changes: changes,
      reason: reason,
      easySpeed: speed,
      runWalkStage: stage,
      walkPreparation: walking,
    );
    if (planning.adaptationHistory.any(
      (h) => h['evidenceKey'] == proposal.evidenceKey,
    )) {
      return RunningAdaptationProposal(
        createdAt: now,
        ruleVersion: rules.version,
        fitness: fitness,
        changes: const {},
        reason: 'insufficientEvidence',
      );
    }
    return proposal;
  }

  /// Easy evidence changes easy guidance and the ramp into an existing normal
  /// pace. It cannot manufacture a faster threshold/interval performance.
  static CardioStep _paceTarget(
    CardioStep s,
    AthleteRunningProfile p,
    double speed,
    DateTime now,
  ) {
    if (s.targetSource == 'manual' ||
        s.movement == 'walk' ||
        s.movement == 'rest') {
      return s;
    }
    if ([
      CardioIntensity.easy,
      CardioIntensity.recovery,
    ].contains(s.intensity)) {
      return s.copyWith(
        clearTargets: true,
        maxSpeed: speed,
        minHeartRate: s.minHeartRate,
        maxHeartRate: s.maxHeartRate,
        primaryTarget: 'pace',
        targetSource: 'estimated',
      );
    }
    if (s.intensity == CardioIntensity.steady &&
        s.targetVariant != 'lightInterval' &&
        s.maxSpeed != null) {
      final normal =
          CardioTraining.prescribe(
            p,
            CardioIntensity.steady,
            now: now,
          ).maxSpeed;
      if (normal == null) return s;
      final start = math.min(speed, normal);
      return s.copyWith(
        minSpeed: start,
        maxSpeed:
            s.targetVariant == 'progressionMid' ? (start + normal) / 2 : normal,
      );
    }
    return s;
  }
}
