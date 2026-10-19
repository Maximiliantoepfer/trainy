import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/cardio.dart';
import '../repositories/cardio_repository.dart';
import '../services/cardio_training.dart';
import '../services/generated/cardio_api.g.dart';
import '../services/cardio_health_service.dart';

class CardioProvider extends ChangeNotifier {
  CardioProvider({CardioRepository? repository, CardioHostApi? api})
    : repository = repository ?? CardioRepository(),
      api = api ?? CardioHostApi();
  final CardioRepository repository;
  final CardioHostApi api;
  AthleteRunningProfile profile = const AthleteRunningProfile();
  List<CardioWorkout> workouts = [];
  List<ScheduledCardioWorkout> occurrences = [];
  List<Map<String, Object?>> history = [];
  Map<String, dynamic>? runtime;
  Map<String, dynamic> capabilities = {};
  Object? error;
  bool loaded = false;
  bool _disposed = false, _polling = false;
  bool _starting = false;
  Timer? _timer;
  int _lastSequence = -1;
  String? _lastSessionId;
  bool get active => runtime != null && runtime!['status'] != 'completed';

  Future<void> load() async {
    try {
      profile = await repository.profile();
      workouts = await repository.workouts();
      occurrences = await repository.occurrences();
      history = await repository.history();
      error = null;
      loaded = true;
    } catch (e) {
      error = e;
    }
    _notify();
  }

  Future<void> initialize() async {
    await load();
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    try {
      capabilities =
          jsonDecode(await api.capabilities()) as Map<String, dynamic>;
      await poll();
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => poll());
    } catch (e) {
      error = e;
      _notify();
    }
    if (profile.healthEnabled) {
      // Optional post-workout discovery must not block local readiness.
      unawaited(
        CardioHealthService(repository).refresh().catchError((Object _) {}),
      );
    }
  }

  Future<void> poll() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final raw = await api.state();
      if (raw == null) {
        if (_starting) return;
        for (final row in await repository.recoverable()) {
          if (row['runtime_json'] == null) {
            // Interrupted before the native start was committed: no measured data exists.
            await repository.cancelStart(row['id'] as String);
          } else {
            await api.recover(row['runtime_json'] as String);
            break;
          }
        }
        return;
      }
      final state = jsonDecode(raw) as Map<String, dynamic>;
      final id = state['sessionId'] as String;
      if (id != _lastSessionId) {
        _lastSessionId = id;
        _lastSequence = -1;
      }
      runtime = state;
      await repository.saveRuntime(state);
      var more = true;
      while (more) {
        final values =
            (jsonDecode(await api.samples(_lastSequence)) as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList();
        if (values.isNotEmpty) {
          await repository.saveSamples(id, values);
          _lastSequence = (values.last['sequence'] as num).toInt();
        }
        more = state['status'] == 'completed' && values.length == 1000;
      }
      if (state['status'] == 'completed') {
        await api.acknowledge(id);
        await load();
        _lastSessionId = null;
        _lastSequence = -1;
      }
      error = null;
      _notify();
    } catch (e) {
      error = e;
      _notify();
    } finally {
      _polling = false;
    }
  }

  Future<String> prepare(CardioWorkout workout, String locale) =>
      api.prepare(!workout.indoor, locale);
  Future<void> start(
    CardioWorkout workout,
    CardioTranslate t,
    String locale, {
    String? occurrenceId,
  }) async {
    if (active || _starting) throw StateError('active_session');
    if (workout.indoor &&
        workout.steps.any((s) => s.goal == StepGoal.distance)) {
      throw StateError('indoor_distance');
    }
    await poll();
    if (active) throw StateError('active_session');
    _starting = true;
    late final String id;
    try {
      id = await repository.begin(workout, occurrenceId: occurrenceId);
    } catch (_) {
      _starting = false;
      rethrow;
    }
    String amount(CardioStep s, double fraction) =>
        s.goal == StepGoal.time
            ? '${CardioUnits.clock(s.amount * fraction)} ${t('minutes')}'
            : CardioUnits.distance(s.amount * fraction, profile.units);
    final steps =
        workout.expandedSteps().map((s) {
          final name = s.name.isNotEmpty ? s.name : t(s.intensity.name);
          final target =
              s.primaryTarget == 'heart_rate' && s.minHeartRate != null
                  ? '${s.minHeartRate}–${s.maxHeartRate} bpm'
                  : s.minSpeed == null
                  ? t('effort')
                  : workout.sport == CardioSport.cycling
                  ? '${CardioUnits.speed(s.minSpeed, profile.units)} – ${CardioUnits.speed(s.maxSpeed, profile.units)}'
                  : '${CardioUnits.pace(s.maxSpeed, profile.units)} – ${CardioUnits.pace(s.minSpeed, profile.units)}';
          return {
            ...s.toJson(),
            'displayName': name,
            'startCue': '$name. ${amount(s, 1)}. ${t('target')}: $target.',
            'halfCue': '${t('half')}. ${t('remaining')}: ${amount(s, .5)}.',
            'nearCue':
                '${t('remaining')}: ${s.goal == StepGoal.distance ? CardioUnits.distance(100, profile.units) : '15 ${t('seconds')}'}.',
            'endCue': '${t('completed')}. $name. ${t('target')}: $target.',
          };
        }).toList();
    for (var i = 0; i + 1 < steps.length; i++) {
      steps[i]['nearCue'] =
          '${steps[i]['nearCue']} ${t('next')}: ${steps[i + 1]['startCue']}';
    }
    try {
      await api.start(
        jsonEncode({
          'version': 1,
          'sessionId': id,
          'workoutId': workout.id,
          'name': workout.name,
          'sport': workout.sport.name,
          'indoor': workout.indoor,
          'autoPause': workout.autoPause,
          'locale': locale,
          'steps': steps,
          'startedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
          'messages': {
            for (final key in [
              'half',
              'nearEnd',
              'slower',
              'faster',
              'gpsLost',
              'paused',
              'resume',
              'completed',
              'average',
            ])
              key: t(key),
          },
          'unitMeters': CardioUnits.distanceUnit(profile.units),
          'cooldown': workout.cooldown.map((s) => s.toJson()).toList(),
        }),
      );
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => poll());
      await poll();
    } catch (_) {
      final saved = await api.state();
      if (saved == null) {
        await repository.cancelStart(id);
      } else {
        await poll();
      }
      rethrow;
    } finally {
      _starting = false;
    }
  }

  Future<void> pause() async {
    await api.pause();
    await poll();
  }

  Future<void> resume() async {
    await api.resume();
    await poll();
  }

  Future<void> finish() async {
    await api.finish();
    await poll();
  }

  void clearCompleted() {
    if (!active) {
      runtime = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
