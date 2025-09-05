import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;
  final bool autoStart; // ▶️ Neu: optionaler Auto-Start

  const WorkoutRunScreen({
    super.key,
    required this.workout,
    required this.exercises,
    this.autoStart = false,
  });

  @override
  State<WorkoutRunScreen> createState() => _WorkoutRunScreenState();
}

class _WorkoutRunScreenState extends State<WorkoutRunScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  /// sekündlicher Ticker -> UI
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);

  /// exerciseId → Liste von Sets (Map: reps/weight/sets/duration als String-Werte)
  final Map<int, List<Map<String, String>>> _setsByExercise = {};

  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      // Timer direkt starten, kein zweiter Start nötig
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  void _start() {
    if (_isRunning) return;
    _isRunning = true;
    _stopwatch.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds.value = _stopwatch.elapsed.inSeconds;
    });
    setState(() {});
  }

  Future<void> _stopAndFinish() async {
    if (!_isRunning) return;

    _stopwatch.stop();
    _ticker?.cancel();
    _isRunning = false;
    setState(() {});

    final hasAnySets = _setsByExercise.values.any((list) => list.isNotEmpty);

    if (!mounted) return;

    if (!hasAnySets) {
      final discard = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Workout beenden'),
              content: const Text(
                'Du hast keine Sätze erfasst. Workout ohne Speichern beenden?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Beenden'),
                ),
              ],
            ),
      );
      if (discard == true && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Speichern bestätigen
    final save = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout beenden und speichern?'),
            content: const Text(
              'Die erfassten Sätze werden gespeichert und der Fortschritt aktualisiert.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Speichern'),
              ),
            ],
          ),
    );

    if (save != true) return;

    final duration = _stopwatch.elapsed.inSeconds;

    // 1) Last Values pro Exercise aktualisieren
    final exerciseProvider = context.read<ExerciseProvider>();
    _setsByExercise.forEach((exerciseId, sets) {
      if (sets.isEmpty) return;
      final last = _deriveLastValues(sets);
      exerciseProvider.updateLastValues(exerciseId, last);
    });

    // 2) Session für Progress persistieren
    await context.read<ProgressProvider>().saveWorkoutEntries(
      workoutId: widget.workout.id,
      durationSeconds: duration,
      setsByExercise: _setsByExercise,
    );

    if (mounted) Navigator.of(context).pop();
  }

  Map<String, String> _deriveLastValues(List<Map<String, String>> sets) {
    String? lastReps;
    String? lastWeight;
    String? lastSets;
    String? lastDuration;

    for (final s in sets) {
      final reps = s['reps']?.trim();
      final weight = s['weight']?.trim();
      final setsVal = s['sets']?.trim();
      final dur = s['duration']?.trim();
      if (reps != null && reps.isNotEmpty) lastReps = reps;
      if (weight != null && weight.isNotEmpty) lastWeight = weight;
      if (setsVal != null && setsVal.isNotEmpty) lastSets = setsVal;
      if (dur != null && dur.isNotEmpty) lastDuration = dur;
    }

    final map = <String, String>{};
    if (lastSets != null) map['sets'] = lastSets!;
    if (lastReps != null) map['reps'] = lastReps!;
    if (lastWeight != null) map['weight'] = lastWeight!;
    if (lastDuration != null) map['duration'] = lastDuration!;
    return map;
  }

  String _formatTime(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _addSet(BuildContext context, Exercise e) async {
    // Prefill aus lastValues → defaultValues
    final last = e.lastValues;
    final defs = e.defaultValues;

    // Falls aus Versehen alle Felder deaktiviert sind, zeigen wir einen Hinweis
    final tracksAny =
        e.trackSets || e.trackReps || e.trackWeight || e.trackDuration;
    if (!tracksAny) {
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(e.name),
              content: const Text(
                'Für diese Übung sind keine Felder zum Tracken aktiviert. '
                'Aktiviere Sätze/Wdh./Gewicht/Dauer in der Übungsbearbeitung.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    final repsCtrl = TextEditingController(
      text: last['reps'] ?? defs['reps'] ?? '',
    );
    final weightCtrl = TextEditingController(
      text: last['weight'] ?? defs['weight'] ?? '',
    );
    final setsCtrl = TextEditingController(
      text: last['sets'] ?? defs['sets'] ?? '',
    );
    final durCtrl = TextEditingController(
      text: last['duration'] ?? defs['duration'] ?? '',
    );

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(e.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.trackSets)
                    TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sätze (Anzahl)',
                      ),
                    ),
                  if (e.trackReps)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: repsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Wiederholungen',
                        ),
                      ),
                    ),
                  if (e.trackWeight)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Gewicht (kg)',
                        ),
                      ),
                    ),
                  if (e.trackDuration)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: durCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dauer (Sekunden)',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  final entry = <String, String>{};
                  if (e.trackSets && setsCtrl.text.trim().isNotEmpty) {
                    entry['sets'] = setsCtrl.text.trim();
                  }
                  if (e.trackReps && repsCtrl.text.trim().isNotEmpty) {
                    entry['reps'] = repsCtrl.text.trim();
                  }
                  if (e.trackWeight && weightCtrl.text.trim().isNotEmpty) {
                    entry['weight'] = weightCtrl.text.trim();
                  }
                  if (e.trackDuration && durCtrl.text.trim().isNotEmpty) {
                    entry['duration'] = durCtrl.text.trim();
                  }

                  if (entry.isNotEmpty) {
                    _setsByExercise.putIfAbsent(e.id, () => []);
                    _setsByExercise[e.id]!.add(entry);
                    setState(() {}); // check-icon / progress
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Speichern'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final total = widget.exercises.length;
    final doneCount = _setsByExercise.values.where((v) => v.isNotEmpty).length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ValueListenableBuilder<int>(
                valueListenable: _elapsedSeconds,
                builder:
                    (_, sec, __) => Text(
                      _formatTime(sec),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
              ),
            ),
          ),
          if (_isRunning)
            IconButton(
              tooltip: 'Stoppen & speichern',
              onPressed: _stopAndFinish,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress, minHeight: 4),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: widget.exercises.length,
        itemBuilder: (_, i) {
          final e = widget.exercises[i];
          final hasSets = (_setsByExercise[e.id] ?? const []).isNotEmpty;
          return Card(
            child: ListTile(
              title: Text(
                e.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                [
                  if (e.trackSets) 'Sätze',
                  if (e.trackReps) 'Wdh.',
                  if (e.trackWeight) 'Gewicht',
                  if (e.trackDuration) 'Dauer',
                ].join(' · '),
              ),
              trailing:
                  hasSets
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                        tooltip: 'Satz hinzufügen',
                        onPressed: () => _addSet(context, e),
                        icon: Icon(Icons.add, color: accent),
                      ),
              onTap: () => _addSet(context, e),
            ),
          );
        },
      ),
      floatingActionButton:
          _isRunning
              ? FloatingActionButton.extended(
                onPressed: _stopAndFinish,
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
              )
              : FloatingActionButton.extended(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              ),
    );
  }
}
