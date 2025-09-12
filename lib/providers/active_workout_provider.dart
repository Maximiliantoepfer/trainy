import 'dart:async';
import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/exercise.dart';

/// Hält eine aktuell laufende Workout-Session unabhängig vom Screen am Leben.
///
/// - Zeit läuft durch, auch bei Screen-Wechseln (Berechnung über Startzeit)
/// - Sets werden im Speicher gehalten und können laufend ergänzt werden
/// - Ein sekündlicher Ticker aktualisiert Listener im Vordergrund
class ActiveWorkoutProvider extends ChangeNotifier {
  Workout? _workout;
  List<Exercise> _exercises = const [];
  DateTime? _startedAt;
  int _extraElapsed = 0; // Reserve, falls später Pausen etc. hinzukommen

  final Map<int, List<Map<String, String>>> _setsByExercise = {};

  Timer? _ticker;
  final ValueNotifier<int> elapsedSeconds = ValueNotifier<int>(0);

  bool get isActive => _workout != null && _startedAt != null;
  Workout? get workout => _workout;
  List<Exercise> get exercises => _exercises;
  Map<int, List<Map<String, String>>> get setsByExercise => _setsByExercise;

  /// Startet eine neue Session (überschreibt ggf. die alte nach Rückfrage durch UI).
  void start({required Workout workout, required List<Exercise> exercises}) {
    _workout = workout;
    _exercises = List<Exercise>.from(exercises);
    _startedAt = DateTime.now();
    _extraElapsed = 0;
    _setsByExercise.clear();

    _startTicker();
    _notifyElapsed();
    notifyListeners();
  }

  /// Fügt (oder ersetzt) während einer aktiven Session eine Übungs-Liste hinzu.
  void updateExercises(List<Exercise> exercises) {
    _exercises = List<Exercise>.from(exercises);
    notifyListeners();
  }

  void addSet(int exerciseId, Map<String, String> entry) {
    _setsByExercise.putIfAbsent(exerciseId, () => []);
    _setsByExercise[exerciseId]!.add(entry);
    notifyListeners();
  }

  /// Aktualisiert den zuletzt erfassten Satz für eine Übung,
  /// oder fügt einen neuen hinzu, falls noch keiner existiert.
  void updateLastSet(int exerciseId, Map<String, String> entry) {
    final list = _setsByExercise[exerciseId];
    if (list != null && list.isNotEmpty) {
      list[list.length - 1] = entry;
    } else {
      _setsByExercise.putIfAbsent(exerciseId, () => []);
      _setsByExercise[exerciseId]!.add(entry);
    }
    notifyListeners();
  }

  void removeLastSet(int exerciseId) {
    final list = _setsByExercise[exerciseId];
    if (list != null && list.isNotEmpty) {
      list.removeLast();
      notifyListeners();
    }
  }

  int get elapsedTotalSeconds {
    if (_startedAt == null) return 0;
    final base = DateTime.now().difference(_startedAt!).inSeconds;
    return base + _extraElapsed;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _notifyElapsed(),
    );
  }

  void _notifyElapsed() {
    elapsedSeconds.value = elapsedTotalSeconds;
  }

  /// Beendet die Session im Speicher, ohne zu persistieren (UI entscheidet was kommt).
  void clear() {
    _ticker?.cancel();
    _ticker = null;
    _workout = null;
    _exercises = const [];
    _startedAt = null;
    _extraElapsed = 0;
    _setsByExercise.clear();
    elapsedSeconds.value = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    elapsedSeconds.dispose();
    super.dispose();
  }
}
