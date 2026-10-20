import 'cardio.dart';
import '../utils/uuid_v4.dart';

class UserTrainingProfile {
  const UserTrainingProfile({
    this.interests = const ['strength'],
    this.units = DistanceSystem.metric,
    this.strengthLevel = 'beginner',
    this.backupSensorData = false,
    this.healthEnabled = false,
    this.strengthSetupVersion = 0,
    this.strengthProfileId,
  });
  final int strengthSetupVersion;
  final String? strengthProfileId;
  final List<String> interests;
  final DistanceSystem units;
  final String strengthLevel;
  final bool backupSensorData, healthEnabled;
  Map<String, dynamic> toJson() => {
    'interests': interests,
    'units': units.name,
    'strengthLevel': strengthLevel,
    'backupSensorData': backupSensorData,
    'healthEnabled': healthEnabled,
    'strengthSetupVersion': strengthSetupVersion,
    'strengthProfileId': strengthProfileId,
  };
  factory UserTrainingProfile.fromJson(Map<String, dynamic> j) =>
      UserTrainingProfile(
        interests: List<String>.from(j['interests'] as List? ?? ['strength']),
        units: DistanceSystem.values.byName(j['units'] as String? ?? 'metric'),
        strengthLevel: j['strengthLevel'] as String? ?? 'beginner',
        backupSensorData: j['backupSensorData'] == true,
        healthEnabled: j['healthEnabled'] == true,
        strengthSetupVersion: j['strengthSetupVersion'] as int? ?? 0,
        strengthProfileId: j['strengthProfileId'] as String?,
      );
}

class ProgramSlot {
  ProgramSlot({
    String? id,
    required this.weekday,
    required this.label,
    this.workoutId,
    this.kind = 'strength',
    this.cycleWeek = 0,
    this.from,
    this.until,
    this.focus = const [],
  }) : id = id ?? UuidV4.generate();
  final String id, label, kind;
  final String? workoutId;
  final int weekday;

  /// 0 = every week, 1/2 = alternating weeks, anchored to the plan's Monday.
  final int cycleWeek;
  final DateTime? from, until;
  final List<String> focus;
  Set<String> get effectiveFocus =>
      focus.isEmpty ? ProgramSplits.focusFor(label) : focus.toSet();
  bool get legHeavy =>
      effectiveFocus.any({'legs', 'quads', 'glutes', 'calves'}.contains);
  ProgramSlot copyWith({
    int? weekday,
    int? cycleWeek,
    String? label,
    String? workoutId,
    bool clearWorkout = false,
    DateTime? until,
    List<String>? focus,
  }) => ProgramSlot(
    id: id,
    weekday: weekday ?? this.weekday,
    label: label ?? this.label,
    workoutId: clearWorkout ? null : workoutId ?? this.workoutId,
    kind: kind,
    cycleWeek: cycleWeek ?? this.cycleWeek,
    from: from,
    until: until ?? this.until,
    focus: focus ?? this.focus,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'weekday': weekday,
    'label': label,
    'workoutId': workoutId,
    'kind': kind,
    'cycleWeek': cycleWeek,
    'from': from?.toIso8601String(),
    'until': until?.toIso8601String(),
    'focus': focus,
  };
  factory ProgramSlot.fromJson(Map<String, dynamic> j) => ProgramSlot(
    id: j['id'] as String,
    weekday: j['weekday'] as int,
    label: j['label'] as String,
    workoutId: j['workoutId'] as String?,
    kind: j['kind'] as String? ?? 'strength',
    cycleWeek: j['cycleWeek'] as int? ?? 0,
    from: DateTime.tryParse(j['from'] as String? ?? ''),
    until: DateTime.tryParse(j['until'] as String? ?? ''),
    focus: List<String>.from(j['focus'] as List? ?? []),
  );
}

class TrainingProgram {
  TrainingProgram({
    String? id,
    required this.name,
    required this.start,
    this.strengthGoal = '',
    this.runningGoal = '',
    this.runningDays = const [],
    this.targetMeters = 5000,
    this.targetSeconds,
    this.targetDate,
    this.slots = const [],
    this.split = 'fullBody',
    this.status = 'draft',
    this.endDate,
    this.availableDays = const [1, 2, 3, 4, 5, 6, 7],
  }) : id = id ?? UuidV4.generate();
  final String id, name, strengthGoal, runningGoal, split, status;
  final DateTime start;
  final DateTime? targetDate;
  final DateTime? endDate;
  final List<int> availableDays;
  final double targetMeters;
  final double? targetSeconds;
  final List<int> runningDays;
  final List<ProgramSlot> slots;
  bool get hasRunning => runningDays.isNotEmpty;
  Set<int> get days => {...runningDays, ...currentSlots.map((s) => s.weekday)};
  Iterable<ProgramSlot> get currentSlots => slots.where(
    (s) =>
        s.until == null ||
        dateKey(s.until!).compareTo(dateKey(DateTime.now())) >= 0,
  );
  TrainingProgram copyWith({
    String? name,
    DateTime? start,
    String? strengthGoal,
    String? runningGoal,
    List<int>? runningDays,
    List<ProgramSlot>? slots,
    String? split,
    double? targetMeters,
    double? targetSeconds,
    DateTime? targetDate,
    bool clearTargetTime = false,
    bool clearTargetDate = false,
    String? status,
    DateTime? endDate,
    bool clearEndDate = false,
    List<int>? availableDays,
  }) => TrainingProgram(
    id: id,
    name: name ?? this.name,
    start: start ?? this.start,
    strengthGoal: strengthGoal ?? this.strengthGoal,
    runningGoal: runningGoal ?? this.runningGoal,
    runningDays: runningDays ?? this.runningDays,
    slots: slots ?? this.slots,
    split: split ?? this.split,
    targetMeters: targetMeters ?? this.targetMeters,
    targetSeconds: clearTargetTime ? null : targetSeconds ?? this.targetSeconds,
    targetDate: clearTargetDate ? null : targetDate ?? this.targetDate,
    status: status ?? this.status,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    availableDays: availableDays ?? this.availableDays,
  );
  void validate() {
    if (name.trim().isEmpty ||
        (endDate != null && dateKey(endDate!).compareTo(dateKey(start)) < 0) ||
        availableDays.any((d) => d < 1 || d > 7) ||
        days.isEmpty ||
        days.any((d) => d < 1 || d > 7) ||
        runningDays.toSet().length != runningDays.length ||
        slots.map((s) => s.id).toSet().length != slots.length ||
        slots.any(
          (s) =>
              !['strength', 'mobility'].contains(s.kind) ||
              s.cycleWeek < 0 ||
              s.cycleWeek > 2,
        ) ||
        ![5000, 10000, 21097.5, 42195].contains(targetMeters) ||
        (targetSeconds != null &&
            (!targetSeconds!.isFinite || targetSeconds! <= 0))) {
      throw const FormatException('Invalid training plan');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': dateKey(start),
    'strengthGoal': strengthGoal,
    'runningGoal': runningGoal,
    'runningDays': runningDays,
    'targetMeters': targetMeters,
    'targetSeconds': targetSeconds,
    'targetDate': targetDate == null ? null : dateKey(targetDate!),
    'slots': slots.map((s) => s.toJson()).toList(),
    'split': split,
    'status': status,
    'endDate': endDate == null ? null : dateKey(endDate!),
    'availableDays': availableDays,
  };
  factory TrainingProgram.fromJson(Map<String, dynamic> j) => TrainingProgram(
    id: j['id'] as String,
    name: j['name'] as String,
    start: DateTime.parse(j['start'] as String),
    strengthGoal: j['strengthGoal'] as String? ?? '',
    runningGoal: j['runningGoal'] as String? ?? '',
    runningDays: List<int>.from(j['runningDays'] as List? ?? []),
    targetMeters: (j['targetMeters'] as num?)?.toDouble() ?? 5000,
    targetSeconds: (j['targetSeconds'] as num?)?.toDouble(),
    targetDate: DateTime.tryParse(j['targetDate'] as String? ?? ''),
    slots: [
      for (final s in j['slots'] as List? ?? [])
        ProgramSlot.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    split: j['split'] as String? ?? 'fullBody',
    status: j['status'] as String? ?? 'draft',
    endDate: DateTime.tryParse(j['endDate'] as String? ?? ''),
    availableDays: List<int>.from(
      j['availableDays'] as List? ?? [1, 2, 3, 4, 5, 6, 7],
    ),
  );
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int datedPlanStreak(List<ProgramEntry> entries, DateTime now) {
  final days = <String, List<ProgramEntry>>{};
  final today = dateKey(now);
  for (final entry in entries) {
    final day = dateKey(entry.date);
    if (day.compareTo(today) <= 0) days.putIfAbsent(day, () => []).add(entry);
  }
  final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
  var streak = 0;
  for (final key in keys) {
    if (days[key]!.every((e) => e.completed)) {
      streak++;
    } else if (key != today) {
      break;
    }
  }
  return streak;
}

int calendarDays(DateTime a, DateTime b) =>
    DateTime.utc(
      a.year,
      a.month,
      a.day,
    ).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

class ProgramEntry {
  const ProgramEntry({
    required this.id,
    required this.planId,
    required this.date,
    required this.name,
    required this.kind,
    this.workoutId,
    this.slotId,
    this.originalDate,
    this.cardio,
    this.completed = false,
    this.sessionId,
    this.splitSourceId,
  });
  final String id, planId, name, kind;
  final String? workoutId, slotId;
  final String? sessionId, splitSourceId;
  final DateTime date;
  final DateTime? originalDate;
  final ScheduledCardioWorkout? cardio;
  final bool completed;
  bool get needsWorkout => cardio == null && workoutId == null;
}

/// Checks placements without silently changing the user's chosen dates.
String? planPlacementWarning(
  TrainingProgram plan,
  ProgramEntry entry,
  DateTime date,
  Iterable<ProgramEntry> neighbors, {
  Set<String> excluded = const {},
}) {
  final others = neighbors.where(
    (e) => e.id != entry.id && !excluded.contains(e.id),
  );
  Set<String> focus(ProgramEntry e) {
    final declared =
        plan.slots.where((s) => s.id == e.slotId).firstOrNull?.effectiveFocus ??
        <String>{};
    return declared
        .expand(
          (f) => switch (f) {
            'push' => {'chest', 'shoulders', 'triceps'},
            'pull' => {'back', 'biceps'},
            'legs' => {'quads', 'glutes', 'hamstrings', 'calves'},
            'arms' => {'biceps', 'triceps'},
            _ => {f},
          },
        )
        .toSet();
  }

  if (entry.kind != 'strength') return null;
  if (others.any(
    (e) =>
        e.kind == 'strength' &&
        dateKey(e.date) == dateKey(date) &&
        ((entry.workoutId != null && entry.workoutId == e.workoutId) ||
            focus(entry).intersection(focus(e)).isNotEmpty),
  )) {
    return 'strengthOverlap';
  }
  return null;
}

abstract final class ProgramSplits {
  static Set<String> focusFor(String label) => switch (label) {
    'fullBody' => {'push', 'pull', 'legs', 'core'},
    'upper' => {'push', 'pull'},
    'lower' || 'legs' => {'legs'},
    'pushCore' => {'push', 'core'},
    'pullLegs' => {'pull', 'legs'},
    'push' || 'pull' || 'core' => {label},
    _ => {},
  };
  static List<int> suggestedDays(
    Iterable<int> available,
    int count, {
    Set<int> avoid = const {},
  }) {
    final days = available.toSet().toList()..sort();
    count = count.clamp(0, days.length);
    var best = <int>[], bestScore = double.infinity;
    for (var mask = 0; mask < 1 << days.length; mask++) {
      final selected = [
        for (var i = 0; i < days.length; i++)
          if (mask & (1 << i) != 0) days[i],
      ];
      if (selected.length != count) continue;
      var score = selected.where(avoid.contains).length * 100.0;
      for (var i = 0; i < selected.length; i++) {
        for (var j = i + 1; j < selected.length; j++) {
          final d = (selected[i] - selected[j]).abs();
          if (d == 1 || d == 6) score += 10;
        }
      }
      if (score < bestScore) {
        best = selected;
        bestScore = score;
      }
    }
    return best;
  }

  /// Small deterministic search for the initial mixed-week suggestion. It never
  /// moves a user's existing choices. Hard runs/long runs get priority for rest.
  static List<int> suggestedRunningDays(List<int> available) {
    final days = [...available]..sort();
    final count = (days.length / 2).ceil();
    var best = <int>[];
    var bestScore = double.infinity;
    int distance(int a, int b) {
      final d = (a - b).abs();
      return d < 7 - d ? d : 7 - d;
    }

    for (var mask = 1; mask < (1 << days.length); mask++) {
      final run = [
        for (var i = 0; i < days.length; i++)
          if (mask & (1 << i) != 0) days[i],
      ];
      if (run.length != count) continue;
      final strength = days.where((d) => !run.contains(d)).toList();
      final quality =
          run.length < 3 ? -1 : run.lastIndexWhere((d) => run.last - d >= 2);
      final hard = {run.last, if (quality >= 0) run[quality]};
      var score = 0.0;
      for (final s in strength) {
        for (final r in hard) {
          if (distance(s, r) < 2) score += 10;
        }
      }
      for (var i = 0; i < run.length; i++) {
        for (var j = i + 1; j < run.length; j++) {
          if (distance(run[i], run[j]) < 2) score += 3;
        }
      }
      for (var i = 0; i < strength.length; i++) {
        for (var j = i + 1; j < strength.length; j++) {
          if (distance(strength[i], strength[j]) < 2) score += 2;
        }
      }
      if (score < bestScore) {
        bestScore = score;
        best = run;
      }
    }
    return best;
  }

  static String recommended(int days) =>
      days <= 3
          ? 'fullBody'
          : days <= 5
          ? 'upperLower'
          : 'pushPullLegs';
  static List<ProgramSlot> slots(List<int> days, String split) {
    final sorted = [...days]..sort();
    final labels = switch (split) {
      'upperLower' => ['upper', 'lower'],
      'pushPullLegs' => ['push', 'pull', 'legs'],
      'mixedSplit' => ['pushCore', 'pullLegs', 'fullBody'],
      'custom' => ['custom'],
      _ => ['fullBody'],
    };
    final alternating = sorted.length == 5 && split == 'upperLower';
    return [
      for (var week = 0; week < (alternating ? 2 : 1); week++)
        for (var i = 0; i < sorted.length; i++)
          ProgramSlot(
            weekday: sorted[i],
            label: labels[(week * sorted.length + i) % labels.length],
            cycleWeek: alternating ? week + 1 : 0,
            focus:
                focusFor(
                  labels[(week * sorted.length + i) % labels.length],
                ).toList(),
          ),
    ];
  }

  static bool legHeavy(String label) => focusFor(label).contains('legs');
}
