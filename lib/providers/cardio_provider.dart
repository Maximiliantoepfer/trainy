import 'dart:async';
import 'dart:convert';
import '../services/cardio_speech.dart';
import 'package:flutter/foundation.dart';
import '../models/cardio.dart';
import '../repositories/cardio_repository.dart';
import '../services/cardio_training.dart';
import '../services/generated/cardio_api.g.dart';
import '../services/cardio_health_service.dart';
import '../services/data_operation.dart';
import '../services/running_fitness.dart';
import '../services/profile_readiness.dart';
import '../services/running_rules.dart';

class CardioProvider extends ChangeNotifier {
  CardioProvider({CardioRepository? repository, CardioHostApi? api})
    : repository = repository ?? CardioRepository(),
      api = api ?? CardioHostApi() {
    DataOperation.instance.register(this, _suspendPolling, _resumePolling);
  }
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
  int revision = 0;
  RunningAdaptationProposal? recommendation;
  Object? recommendationError;
  int _recommendationEpoch = 0;
  int _loadEpoch = 0;
  bool _disposed = false, _polling = false;
  bool _starting = false;
  bool _suspended = false;
  Completer<void>? _pollDone;
  final _reads = <Completer<void>>{};
  Timer? _timer;
  int _lastSequence = -1;
  String? _lastSessionId;
  bool get active => runtime != null && runtime!['status'] != 'completed';

  Future<void> load() => _read(_load);

  Future<void> _read(Future<void> Function() action) async {
    if (_disposed ||
        DataOperation.instance.databaseUnavailable ||
        (_suspended && !DataOperation.instance.ownsOperation)) {
      return;
    }
    final done = Completer<void>();
    _reads.add(done);
    try {
      await action();
    } finally {
      _reads.remove(done);
      done.complete();
    }
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    ++_recommendationEpoch;
    try {
      final nextProfile = await repository.profile();
      final nextWorkouts = await repository.workouts();
      final nextOccurrences = await repository.occurrences();
      final nextHistory = await repository.history();
      if (epoch != _loadEpoch || _disposed) return;
      profile = nextProfile;
      workouts = nextWorkouts;
      occurrences = nextOccurrences;
      history = nextHistory;
      error = null;
      loaded = true;
      revision++;
      await _refreshRecommendations(notify: false);
    } catch (e) {
      if (epoch != _loadEpoch || _disposed) return;
      error = e;
    }
    if (epoch != _loadEpoch || _disposed) return;
    _notify();
  }

  /// Completion, feedback, accepted imports and profile edits all call load().
  /// Calculations are local; no modal or plan mutation happens during refresh.
  Future<void> refreshRecommendations({bool notify = true}) =>
      _read(() => _refreshRecommendations(notify: notify));

  Future<void> _refreshRecommendations({bool notify = true}) async {
    final epoch = ++_recommendationEpoch;
    if (occurrences.isEmpty) {
      recommendation = null;
      recommendationError = null;
      if (notify) _notify();
      return;
    }
    try {
      final next = await repository.adaptation((key) => key);
      if (epoch != _recommendationEpoch || _disposed) return;
      recommendation =
          next.changes.isNotEmpty &&
                  !profile.planning.dismissedAdaptations.contains(
                    next.evidenceKey,
                  )
              ? next
              : null;
      recommendationError = null;
    } on ProfileIncomplete {
      if (epoch != _recommendationEpoch || _disposed) return;
      recommendation = null;
      recommendationError = null;
    } catch (e) {
      if (epoch != _recommendationEpoch || _disposed) return;
      recommendation = null;
      recommendationError = e;
    }
    if (notify) _notify();
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
      if (!_suspended && !_disposed) {
        _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => poll());
      }
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
    if (_polling || _disposed || _suspended) return;
    _polling = true;
    final done = _pollDone = Completer<void>();
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
      done.complete();
    }
  }

  Future<void> _suspendPolling() async {
    _suspended = true;
    _timer?.cancel();
    _timer = null;
    await _pollDone?.future;
    await Future.wait(_reads.map((r) => r.future).toList());
  }

  void _resumePolling() {
    _suspended = false;
    if (_disposed ||
        kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => poll());
  }

  Future<void> discard() async {
    await _suspendPolling();
    try {
      await api.discard();
      if (_lastSessionId != null) await repository.cancelStart(_lastSessionId!);
      runtime = null;
      _lastSessionId = null;
      _lastSequence = -1;
      await _load();
    } finally {
      _resumePolling();
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
            ? CardioSpeech.duration(s.amount * fraction, locale)
            : CardioUnits.distance(s.amount * fraction, profile.units);
    final steps =
        workout.expandedSteps().map((s) {
          final name = s.name.isNotEmpty ? s.name : t(s.intensity.name);
          var target = CardioTraining.targetDescription(
            s,
            profile.units,
            t,
            cycling: workout.sport == CardioSport.cycling,
          );
          if (workout.sport == CardioSport.running &&
              s.primaryTarget == 'pace') {
            if (s.maxSpeed != null && s.minSpeed == null) {
              target =
                  '${t('notFaster')} ${CardioSpeech.pace(s.maxSpeed!, profile.units, locale)}';
            } else if (s.minSpeed != null && s.maxSpeed != null) {
              target =
                  '${CardioSpeech.pace(s.maxSpeed!, profile.units, locale)} – ${CardioSpeech.pace(s.minSpeed!, profile.units, locale)}';
            }
          }
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
          'measurementVersion': 2,
          'trackingRules': {
            for (final key in [
              'paceWindowSeconds',
              'positionWindowSeconds',
              'paceToleranceSecondsPerKm',
              'paceSustainedSeconds',
              'paceGraceSeconds',
              'paceCooldownSeconds',
            ])
              key: RunningRules.bundled.number(key),
          },
          'sessionId': id,
          'workoutId': workout.id,
          'name': workout.name,
          'sport': workout.sport.name,
          'indoor': workout.indoor,
          'autoPause': workout.autoPause,
          'audioEnabled': profile.planning.audio ?? true,
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
              'goalReached',
              'continueEasy',
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

  Future<void> setAudioEnabled(bool enabled) async {
    if (active) {
      await api.setAudioEnabled(enabled);
      await poll();
    }
    await repository.saveProfile(
      AthleteRunningProfile.fromJson({
        ...profile.toJson(),
        'planning': {...profile.planning.toJson(), 'audio': enabled},
      }),
    );
    await load();
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
    DataOperation.instance.unregister(this);
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
