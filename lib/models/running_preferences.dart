class FavoriteRunningRoute {
  const FavoriteRunningRoute({
    required this.id,
    required this.meters,
    this.name = '',
    this.weekdays = const [],
  });
  final String id, name;
  final double meters;
  final List<int> weekdays;
  void validate() {
    if (id.isEmpty ||
        !meters.isFinite ||
        meters < 100 ||
        meters > 100000 ||
        name.length > 80 ||
        weekdays.any((d) => d < 1 || d > 7)) {
      throw const FormatException('Invalid favorite route');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'meters': meters,
    'weekdays': weekdays,
  };
  factory FavoriteRunningRoute.fromJson(Map<String, dynamic> j) =>
      FavoriteRunningRoute(
        id: j['id'] as String,
        meters: (j['meters'] as num).toDouble(),
        name: j['name'] as String? ?? '',
        weekdays: List<int>.from(j['weekdays'] as List? ?? []),
      );
}

/// Additive profile answers. Null means unknown, never implicitly confirmed.
class RunningPreferences {
  const RunningPreferences({
    this.goal,
    this.complaints,
    this.walkMinutes,
    this.walkPreparation,
    this.weeklyMinutes,
    this.longestMinutes,
    this.longestDate,
    this.longestEffort,
    this.desiredDays,
    this.minutesPerSession,
    this.dayMinutes = const {},
    this.hardTrainingDays = const [],
    this.highLoadTolerated,
    this.routePreference,
    this.routeMeters,
    this.walkBreaks,
    this.audio,
    this.zoneMethod = 'karvonen',
    this.zoneSource = 'estimate',
    this.zoneBounds = const [],
    this.pulseSource,
    this.easySpeed,
    this.paceUpdatedAt,
    this.runWalkStage = 0,
    this.adaptationHistory = const [],
    this.dismissedAdaptations = const [],
    this.healthRoutes = true,
    this.favoriteRoutes = const [],
    this.breakWeeks,
  });
  final String? goal, complaints, routePreference, pulseSource;
  final bool? walkPreparation, highLoadTolerated, walkBreaks, audio;
  final double? weeklyMinutes, longestMinutes, easySpeed, routeMeters;
  final int? walkMinutes, longestEffort, desiredDays, minutesPerSession;
  final DateTime? longestDate, paceUpdatedAt;
  final Map<int, int> dayMinutes;
  final List<int> hardTrainingDays, zoneBounds;
  final String zoneMethod, zoneSource;
  final int runWalkStage;
  final List<Map<String, dynamic>> adaptationHistory;
  final List<String> dismissedAdaptations;
  final bool healthRoutes;
  final List<FavoriteRunningRoute> favoriteRoutes;
  final int? breakWeeks;
  bool get restricted => complaints != null && complaints != 'none';
  void validate() {
    for (final route in favoriteRoutes) {
      route.validate();
    }
    if (favoriteRoutes.map((r) => r.id).toSet().length !=
            favoriteRoutes.length ||
        (breakWeeks != null && (breakWeeks! < 1 || breakWeeks! > 520))) {
      throw const FormatException('Invalid routes or training break');
    }
    if ((minutesPerSession != null &&
            (minutesPerSession! < 10 || minutesPerSession! > 300)) ||
        dayMinutes.entries.any(
          (e) => e.key < 1 || e.key > 7 || e.value < 10 || e.value > 300,
        ) ||
        hardTrainingDays.any((d) => d < 1 || d > 7) ||
        (desiredDays != null && (desiredDays! < 1 || desiredDays! > 6)) ||
        (walkMinutes != null && (walkMinutes! < 0 || walkMinutes! > 300)) ||
        (longestEffort != null &&
            (longestEffort! < 1 || longestEffort! > 10)) ||
        !['karvonen', 'manual'].contains(zoneMethod) ||
        (weeklyMinutes != null &&
            (!weeklyMinutes!.isFinite || weeklyMinutes! < 0)) ||
        (longestMinutes != null &&
            (!longestMinutes!.isFinite || longestMinutes! <= 0)) ||
        (easySpeed != null &&
            (!easySpeed!.isFinite || easySpeed! <= 0 || easySpeed! > 12)) ||
        (routeMeters != null &&
            (!routeMeters!.isFinite ||
                routeMeters! < 100 ||
                routeMeters! > 100000)) ||
        runWalkStage < 0 ||
        runWalkStage > 8) {
      throw const FormatException('Invalid running planning answers');
    }
    if (zoneBounds.isNotEmpty &&
        (zoneBounds.length != 6 ||
            zoneBounds.first < 25 ||
            zoneBounds.last > 250 ||
            List.generate(
              zoneBounds.length - 1,
              (i) => zoneBounds[i] >= zoneBounds[i + 1],
            ).any((e) => e))) {
      throw const FormatException(
        'Heart-rate zones must be ordered boundaries',
      );
    }
    if (zoneMethod == 'manual' && zoneBounds.length != 6) {
      throw const FormatException('Missing manual zones');
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 3,
    'favoriteRoutes': favoriteRoutes.map((r) => r.toJson()).toList(),
    'breakWeeks': breakWeeks,
    'goal': goal,
    'complaints': complaints,
    'walkMinutes': walkMinutes,
    'walkPreparation': walkPreparation,
    'weeklyMinutes': weeklyMinutes,
    'longestMinutes': longestMinutes,
    'longestDate': longestDate?.toIso8601String(),
    'longestEffort': longestEffort,
    'desiredDays': desiredDays,
    'minutesPerSession': minutesPerSession,
    'dayMinutes': {for (final e in dayMinutes.entries) '${e.key}': e.value},
    'hardTrainingDays': hardTrainingDays,
    'highLoadTolerated': highLoadTolerated,
    'routePreference': routePreference,
    'routeMeters': routeMeters,
    'walkBreaks': walkBreaks,
    'audio': audio,
    'zoneMethod': zoneMethod,
    'zoneSource': zoneSource,
    'zoneBounds': zoneBounds,
    'pulseSource': pulseSource,
    'easySpeed': easySpeed,
    'paceUpdatedAt': paceUpdatedAt?.toIso8601String(),
    'runWalkStage': runWalkStage,
    'adaptationHistory': adaptationHistory,
    'dismissedAdaptations': dismissedAdaptations,
    'healthRoutes': healthRoutes,
  };
  factory RunningPreferences.fromJson(Map<String, dynamic> j) =>
      RunningPreferences(
        goal: j['goal'] as String?,
        complaints: j['complaints'] as String?,
        walkMinutes: j['walkMinutes'] as int?,
        walkPreparation: j['walkPreparation'] as bool?,
        weeklyMinutes: (j['weeklyMinutes'] as num?)?.toDouble(),
        longestMinutes: (j['longestMinutes'] as num?)?.toDouble(),
        longestDate: DateTime.tryParse(j['longestDate'] as String? ?? ''),
        longestEffort: j['longestEffort'] as int?,
        desiredDays: j['desiredDays'] as int?,
        minutesPerSession: j['minutesPerSession'] as int?,
        dayMinutes: (j['dayMinutes'] as Map? ?? {}).map(
          (k, v) => MapEntry(int.parse('$k'), (v as num).toInt()),
        ),
        hardTrainingDays: List<int>.from(j['hardTrainingDays'] as List? ?? []),
        highLoadTolerated: j['highLoadTolerated'] as bool?,
        routePreference: j['routePreference'] as String?,
        routeMeters: (j['routeMeters'] as num?)?.toDouble(),
        walkBreaks: j['walkBreaks'] as bool?,
        audio: j['audio'] as bool?,
        zoneMethod: j['zoneMethod'] as String? ?? 'karvonen',
        zoneSource: j['zoneSource'] as String? ?? 'estimate',
        zoneBounds: List<int>.from(j['zoneBounds'] as List? ?? []),
        pulseSource: j['pulseSource'] as String?,
        easySpeed: (j['easySpeed'] as num?)?.toDouble(),
        paceUpdatedAt: DateTime.tryParse(j['paceUpdatedAt'] as String? ?? ''),
        runWalkStage: j['runWalkStage'] as int? ?? 0,
        adaptationHistory:
            (j['adaptationHistory'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
        dismissedAdaptations: List<String>.from(
          j['dismissedAdaptations'] as List? ?? [],
        ),
        healthRoutes: j['healthRoutes'] != false,
        breakWeeks: j['breakWeeks'] as int?,
        favoriteRoutes:
            j['favoriteRoutes'] is List
                ? (j['favoriteRoutes'] as List)
                    .map(
                      (r) => FavoriteRunningRoute.fromJson(
                        Map<String, dynamic>.from(r as Map),
                      ),
                    )
                    .toList()
                : j['routeMeters'] is num && (j['routeMeters'] as num) > 0
                ? [
                  FavoriteRunningRoute(
                    id: 'legacy-route',
                    meters: (j['routeMeters'] as num).toDouble(),
                  ),
                ]
                : const [],
      );
}
