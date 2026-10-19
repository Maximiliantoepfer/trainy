import 'dart:math' as math;
import 'package:intl/intl.dart';

import '../utils/uuid_v4.dart';

enum CardioSport {
  running,
  walking,
  cycling,
  stepper,
  elliptical,
  rowing,
  other,
}

enum StepGoal { time, distance }

enum CardioIntensity { easy, steady, threshold, interval, recovery, free }

enum DistanceSystem { metric, imperial }

enum RunningLevel { starting, beginner, intermediate, experienced }

abstract final class CardioUnits {
  static const metersPerMile = 1609.344;
  static double distanceUnit(DistanceSystem system) =>
      system == DistanceSystem.metric ? 1000 : metersPerMile;
  static String distance(
    double meters,
    DistanceSystem system, {
    String? locale,
  }) =>
      '${NumberFormat('0.##', locale).format(meters / distanceUnit(system))} ${system == DistanceSystem.metric ? 'km' : 'mi'}';
  static double? parseDuration(String text) {
    if (text.trim().isEmpty) return null;
    final parts = text.trim().split(':');
    if (parts.length == 1) {
      if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(parts.single)) return null;
      final minutes = double.tryParse(parts.single.replaceAll(',', '.'));
      return minutes != null && minutes.isFinite && minutes > 0
          ? minutes * 60
          : null;
    }
    if (parts.length < 2 ||
        parts.length > 3 ||
        parts.any((p) => !RegExp(r'^\d+$').hasMatch(p))) {
      return null;
    }
    final values = parts.map(int.parse).toList();
    if (values.skip(1).any((v) => v >= 60)) return null;
    final seconds = values.fold<int>(0, (a, b) => a * 60 + b);
    return seconds > 0 ? seconds.toDouble() : null;
  }

  static String clock(num seconds) {
    final value = seconds.round().clamp(0, 99999999);
    return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
  }

  static String pace(double? metersPerSecond, DistanceSystem system) =>
      metersPerSecond == null || metersPerSecond <= 0
          ? '—'
          : '${clock(distanceUnit(system) / metersPerSecond)} /${system == DistanceSystem.metric ? 'km' : 'mi'}';
  static String speed(double? metersPerSecond, DistanceSystem system) =>
      metersPerSecond == null
          ? '—'
          : '${(metersPerSecond * 3600 / distanceUnit(system)).toStringAsFixed(1)} ${system == DistanceSystem.metric ? 'km/h' : 'mph'}';
}

class AthleteRunningProfile {
  const AthleteRunningProfile({
    this.referenceMeters = 5000,
    this.referenceSeconds,
    this.referenceDate,
    this.isMaximal = false,
    this.weeklyMeters = 0,
    this.longestMeters = 0,
    this.continuousMinutes = 0,
    this.experienceMonths = 0,
    this.restingHeartRate,
    this.maximumHeartRate,
    this.weekdays = const [1, 3, 5],
    this.units = DistanceSystem.metric,
    this.backupSensorData = false,
    this.healthEnabled = false,
    this.interests = const ['strength'],
    this.level,
    this.canRunFiveKm,
    this.recentRunsPerWeek,
    this.bestMeters = 5000,
    this.bestSeconds,
    this.bestDate,
  });
  final double referenceMeters;
  final double? referenceSeconds;
  final DateTime? referenceDate;
  final bool isMaximal;

  /// A separate optional race/test result; legacy maximal references still work.
  final double bestMeters;
  final double? bestSeconds;
  final DateTime? bestDate;
  double get benchmarkMeters =>
      bestSeconds != null ? bestMeters : referenceMeters;
  double? get benchmarkSeconds =>
      bestSeconds ?? (isMaximal ? referenceSeconds : null);
  DateTime? get benchmarkDate => bestSeconds != null ? bestDate : referenceDate;
  double? get easySpeed =>
      !isMaximal && referenceSeconds != null
          ? referenceMeters / referenceSeconds!
          : null;
  final double weeklyMeters;
  final double longestMeters;
  final int continuousMinutes;
  final int experienceMonths;
  final RunningLevel? level;
  final bool? canRunFiveKm;
  final int? recentRunsPerWeek;
  final int? restingHeartRate;
  final int? maximumHeartRate;
  final List<int> weekdays;
  final DistanceSystem units;
  final bool backupSensorData;
  final bool healthEnabled;
  final List<String> interests;

  void validate() {
    if (referenceMeters <= 0 ||
        !referenceMeters.isFinite ||
        bestMeters <= 0 ||
        !bestMeters.isFinite ||
        (bestSeconds != null &&
            (!bestSeconds!.isFinite || bestSeconds! <= 0)) ||
        (referenceSeconds != null &&
            (referenceSeconds! <= 0 || !referenceSeconds!.isFinite)) ||
        weeklyMeters < 0 ||
        !weeklyMeters.isFinite ||
        longestMeters < 0 ||
        !longestMeters.isFinite ||
        continuousMinutes < 0 ||
        experienceMonths < 0 ||
        weekdays.isEmpty ||
        weekdays.toSet().length != weekdays.length ||
        weekdays.any((d) => d < 1 || d > 7)) {
      throw const FormatException('Invalid running profile');
    }
    if ((restingHeartRate != null &&
            (restingHeartRate! < 25 || restingHeartRate! > 250)) ||
        (maximumHeartRate != null &&
            (maximumHeartRate! < 25 || maximumHeartRate! > 250)) ||
        (restingHeartRate != null &&
            maximumHeartRate != null &&
            maximumHeartRate! <= restingHeartRate!) ||
        (recentRunsPerWeek != null &&
            (recentRunsPerWeek! < 0 || recentRunsPerWeek! > 7))) {
      throw const FormatException('Invalid heart rate reserve');
    }
  }

  bool hasRecentBenchmark(DateTime now) =>
      benchmarkSeconds != null &&
      benchmarkDate != null &&
      !benchmarkDate!.isAfter(now) &&
      now.difference(benchmarkDate!).inDays <= 90;
  double equivalentSeconds(double meters) =>
      benchmarkSeconds! * math.pow(meters / benchmarkMeters, 1.06);
  double? fiveKmSpeed(DateTime now) =>
      hasRecentBenchmark(now) ? 5000 / equivalentSeconds(5000) : null;
  int? pulse(double fraction) =>
      restingHeartRate == null || maximumHeartRate == null
          ? null
          : (restingHeartRate! +
                  fraction * (maximumHeartRate! - restingHeartRate!))
              .round();
  List<(int, int)> get zones =>
      restingHeartRate == null || maximumHeartRate == null
          ? []
          : List.generate(5, (i) => (pulse(.5 + i * .1)!, pulse(.6 + i * .1)!));

  Map<String, dynamic> toJson() => {
    'referenceMeters': referenceMeters,
    'referenceSeconds': referenceSeconds,
    'referenceDate': referenceDate?.toIso8601String(),
    'isMaximal': isMaximal,
    'bestMeters': bestMeters,
    'bestSeconds': bestSeconds,
    'bestDate': bestDate?.toIso8601String(),
    'weeklyMeters': weeklyMeters == 0 ? null : weeklyMeters,
    'longestMeters': longestMeters == 0 ? null : longestMeters,
    'continuousMinutes': continuousMinutes == 0 ? null : continuousMinutes,
    'experienceMonths': experienceMonths,
    'level': level?.name,
    'canRunFiveKm': canRunFiveKm,
    'recentRunsPerWeek': recentRunsPerWeek,
    'restingHeartRate': restingHeartRate,
    'maximumHeartRate': maximumHeartRate,
    'weekdays': weekdays,
    'units': units.name,
    'backupSensorData': backupSensorData,
    'healthEnabled': healthEnabled,
    'interests': interests,
  };
  factory AthleteRunningProfile.fromJson(Map<String, dynamic> j) =>
      AthleteRunningProfile(
        referenceMeters: (j['referenceMeters'] as num?)?.toDouble() ?? 5000,
        referenceSeconds: (j['referenceSeconds'] as num?)?.toDouble(),
        referenceDate: DateTime.tryParse(j['referenceDate'] as String? ?? ''),
        isMaximal: j['isMaximal'] == true,
        bestMeters: (j['bestMeters'] as num?)?.toDouble() ?? 5000,
        bestSeconds: (j['bestSeconds'] as num?)?.toDouble(),
        bestDate: DateTime.tryParse(j['bestDate'] as String? ?? ''),
        weeklyMeters: (j['weeklyMeters'] as num?)?.toDouble() ?? 0,
        longestMeters: (j['longestMeters'] as num?)?.toDouble() ?? 0,
        continuousMinutes: j['continuousMinutes'] as int? ?? 0,
        experienceMonths: j['experienceMonths'] as int? ?? 0,
        level:
            j['level'] == null
                ? null
                : RunningLevel.values.byName(j['level'] as String),
        canRunFiveKm: j['canRunFiveKm'] as bool?,
        recentRunsPerWeek: j['recentRunsPerWeek'] as int?,
        restingHeartRate: j['restingHeartRate'] as int?,
        maximumHeartRate: j['maximumHeartRate'] as int?,
        weekdays: List<int>.from(j['weekdays'] as List? ?? [1, 3, 5]),
        units: DistanceSystem.values.byName(j['units'] as String? ?? 'metric'),
        backupSensorData: j['backupSensorData'] == true,
        healthEnabled: j['healthEnabled'] == true,
        interests: List<String>.from(j['interests'] as List? ?? ['strength']),
      );
}

class CardioStep {
  CardioStep({
    String? id,
    this.name = '',
    this.goal = StepGoal.time,
    this.amount = 300,
    this.intensity = CardioIntensity.easy,
    this.movement = 'run',
    this.minSpeed,
    this.maxSpeed,
    this.minHeartRate,
    this.maxHeartRate,
    this.primaryTarget = 'pace',
    this.repeat = 1,
    this.recoverySeconds = 0,
    this.standingRecovery = false,
    this.recoveryMovement = 'walk',
    this.targetSource = 'manual',
  }) : id = id ?? UuidV4.generate();
  final String id;
  final String name;
  final StepGoal goal;
  final double amount;
  final CardioIntensity intensity;
  final String movement;
  final double? minSpeed, maxSpeed;
  final int? minHeartRate, maxHeartRate;
  final String primaryTarget;
  final int repeat;
  final double recoverySeconds;
  final bool standingRecovery;
  final String recoveryMovement;

  /// manual, benchmark, estimated, or effort. Only automatic targets regenerate.
  final String targetSource;

  void validate() {
    if (!amount.isFinite ||
        amount <= 0 ||
        repeat < 1 ||
        repeat > 100 ||
        !recoverySeconds.isFinite ||
        recoverySeconds < 0 ||
        (minSpeed != null && (!minSpeed!.isFinite || minSpeed! <= 0)) ||
        (maxSpeed != null && (!maxSpeed!.isFinite || maxSpeed! <= 0)) ||
        (minSpeed != null && maxSpeed != null && maxSpeed! < minSpeed!) ||
        !['walk', 'run', 'rest'].contains(recoveryMovement) ||
        ![
          'manual',
          'benchmark',
          'estimated',
          'effort',
        ].contains(targetSource) ||
        ((minHeartRate == null) != (maxHeartRate == null)) ||
        (minHeartRate != null &&
            (minHeartRate! < 25 ||
                maxHeartRate! > 250 ||
                maxHeartRate! < minHeartRate!)) ||
        !['pace', 'heart_rate', 'effort'].contains(primaryTarget)) {
      throw const FormatException('Invalid cardio step');
    }
  }

  CardioStep copyWith({
    String? id,
    String? name,
    StepGoal? goal,
    double? amount,
    CardioIntensity? intensity,
    String? movement,
    double? minSpeed,
    double? maxSpeed,
    int? minHeartRate,
    int? maxHeartRate,
    String? primaryTarget,
    int? repeat,
    double? recoverySeconds,
    bool? standingRecovery,
    String? recoveryMovement,
    String? targetSource,
    bool clearTargets = false,
  }) => CardioStep(
    id: id ?? this.id,
    name: name ?? this.name,
    goal: goal ?? this.goal,
    amount: amount ?? this.amount,
    intensity: intensity ?? this.intensity,
    movement: movement ?? this.movement,
    minSpeed: clearTargets ? minSpeed : minSpeed ?? this.minSpeed,
    maxSpeed: clearTargets ? maxSpeed : maxSpeed ?? this.maxSpeed,
    minHeartRate:
        clearTargets ? minHeartRate : minHeartRate ?? this.minHeartRate,
    maxHeartRate:
        clearTargets ? maxHeartRate : maxHeartRate ?? this.maxHeartRate,
    primaryTarget: primaryTarget ?? this.primaryTarget,
    repeat: repeat ?? this.repeat,
    recoverySeconds: recoverySeconds ?? this.recoverySeconds,
    standingRecovery: standingRecovery ?? this.standingRecovery,
    recoveryMovement: recoveryMovement ?? this.recoveryMovement,
    targetSource: targetSource ?? this.targetSource,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'goal': goal.name,
    'amount': amount,
    'intensity': intensity.name,
    'movement': movement,
    'minSpeed': minSpeed,
    'maxSpeed': maxSpeed,
    'minHeartRate': minHeartRate,
    'maxHeartRate': maxHeartRate,
    'primaryTarget': primaryTarget,
    'repeat': repeat,
    'recoverySeconds': recoverySeconds,
    'standingRecovery': standingRecovery,
    'recoveryMovement': recoveryMovement,
    'targetSource': targetSource,
  };
  factory CardioStep.fromJson(Map<String, dynamic> j) => CardioStep(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    goal: StepGoal.values.byName(j['goal'] as String),
    amount: (j['amount'] as num).toDouble(),
    intensity: CardioIntensity.values.byName(
      j['intensity'] as String? ?? 'easy',
    ),
    movement: j['movement'] as String? ?? 'run',
    minSpeed: (j['minSpeed'] as num?)?.toDouble(),
    maxSpeed: (j['maxSpeed'] as num?)?.toDouble(),
    minHeartRate: j['minHeartRate'] as int?,
    maxHeartRate: j['maxHeartRate'] as int?,
    primaryTarget: j['primaryTarget'] as String? ?? 'pace',
    repeat: j['repeat'] as int? ?? 1,
    recoverySeconds: (j['recoverySeconds'] as num?)?.toDouble() ?? 0,
    standingRecovery: j['standingRecovery'] == true,
    recoveryMovement:
        j['recoveryMovement'] as String? ??
        (j['standingRecovery'] == true ? 'rest' : 'walk'),
    targetSource: j['targetSource'] as String? ?? 'manual',
  );
}

class RoutineStep {
  const RoutineStep(
    this.exercise, {
    this.seconds = 30,
    this.customName = '',
    this.instructions = '',
  });
  final String exercise;
  final int seconds;
  final String customName, instructions;
  Map<String, dynamic> toJson() => {
    'exercise': exercise,
    'seconds': seconds,
    'customName': customName,
    'instructions': instructions,
  };
  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
    j['exercise'] as String,
    seconds: j['seconds'] as int,
    customName: j['customName'] as String? ?? '',
    instructions: j['instructions'] as String? ?? '',
  );
}

class CardioWorkout {
  CardioWorkout({
    String? id,
    required this.name,
    this.sport = CardioSport.running,
    this.indoor = false,
    required this.steps,
    this.warmup = const [],
    this.cooldown = const [],
    this.templateCode,
    this.autoPause = true,
  }) : id = id ?? UuidV4.generate();
  final String id;
  final String name;
  final CardioSport sport;
  final bool indoor;
  final List<CardioStep> steps;
  final List<RoutineStep> warmup, cooldown;
  final String? templateCode;
  final bool autoPause;
  void validate() {
    if (name.trim().isEmpty ||
        steps.isEmpty ||
        warmup.length > 200 ||
        cooldown.length > 200 ||
        steps.length > 200 ||
        steps.map((s) => s.id).toSet().length != steps.length ||
        [...warmup, ...cooldown].any(
          (s) =>
              s.seconds <= 0 ||
              s.seconds > 3600 ||
              s.exercise.trim().isEmpty ||
              (s.exercise == 'custom' && s.customName.trim().isEmpty),
        )) {
      throw const FormatException('Invalid cardio workout');
    }
    for (final step in steps) {
      step.validate();
    }
    if (expandedSteps().length > 1000) {
      throw const FormatException('Too many intervals');
    }
  }

  List<CardioStep> expandedSteps() => [
    for (final s in steps)
      for (var i = 0; i < s.repeat; i++) ...[
        s.copyWith(
          id: '${s.id}:$i',
          repeat: 1,
          recoverySeconds: 0,
          standingRecovery: s.movement == 'rest',
        ),
        if (i < s.repeat - 1 && s.recoverySeconds > 0)
          CardioStep(
            id: '${s.id}:$i:recovery',
            amount: s.recoverySeconds,
            intensity: CardioIntensity.recovery,
            movement: s.standingRecovery ? 'rest' : s.recoveryMovement,
            standingRecovery:
                s.standingRecovery || s.recoveryMovement == 'rest',
            primaryTarget: 'effort',
          ),
      ],
  ];
  CardioWorkout timeReplacement() => CardioWorkout(
    id: id,
    name: name,
    sport: sport,
    indoor: indoor,
    warmup: warmup,
    cooldown: cooldown,
    templateCode: templateCode,
    autoPause: false,
    steps:
        steps.map((s) {
          if (s.goal == StepGoal.time) return s;
          if (s.minSpeed == null && s.maxSpeed == null) {
            throw const FormatException(
              'A target speed is needed for time conversion',
            );
          }
          return s.copyWith(
            goal: StepGoal.time,
            amount:
                s.amount /
                ((s.minSpeed ?? s.maxSpeed!) + (s.maxSpeed ?? s.minSpeed!)) *
                2,
          );
        }).toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sport': sport.name,
    'indoor': indoor,
    'steps': steps.map((s) => s.toJson()).toList(),
    'warmup': warmup.map((s) => s.toJson()).toList(),
    'cooldown': cooldown.map((s) => s.toJson()).toList(),
    'templateCode': templateCode,
    'autoPause': autoPause,
  };
  factory CardioWorkout.fromJson(Map<String, dynamic> j) => CardioWorkout(
    id: j['id'] as String,
    name: j['name'] as String,
    sport: CardioSport.values.byName(j['sport'] as String),
    indoor: j['indoor'] == true,
    steps:
        (j['steps'] as List)
            .map(
              (v) => CardioStep.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
    warmup:
        (j['warmup'] as List? ?? [])
            .map(
              (v) => RoutineStep.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
    cooldown:
        (j['cooldown'] as List? ?? [])
            .map(
              (v) => RoutineStep.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
    templateCode: j['templateCode'] as String?,
    autoPause: j['autoPause'] != false,
  );
}

class ScheduledCardioWorkout {
  const ScheduledCardioWorkout({
    required this.id,
    required this.planId,
    required this.date,
    required this.workout,
    this.status = 'planned',
    this.locked = false,
    this.sessionId,
  });
  final String id, planId, status;
  final DateTime date;
  final CardioWorkout workout;
  final bool locked;
  final String? sessionId;
}
