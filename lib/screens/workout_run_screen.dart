import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/progress_provider.dart';

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;

  const WorkoutRunScreen({
    super.key,
    required this.workout,
    required this.exercises,
  });

  @override
  State<WorkoutRunScreen> createState() => _WorkoutRunScreenState();
}

class _WorkoutRunScreenState extends State<WorkoutRunScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  /// exerciseId → Liste von Sets (Map: reps/weight/sets/duration als String-Werte)
  final Map<int, List<Map<String, String>>> _setsByExercise = {};

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _finish(BuildContext context) async {
    _stopwatch.stop();
    _ticker?.cancel();

    await context.read<ProgressProvider>().saveWorkoutEntries(
      workoutId: widget.workout.id,
      durationSeconds: _stopwatch.elapsed.inSeconds,
      setsByExercise: _setsByExercise,
    );

    if (mounted) Navigator.of(context).pop();
  }

  String _timeText() {
    final s = _stopwatch.elapsed.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _addSet(BuildContext context, Exercise e) async {
    // Prefill aus lastValues → defaultValues
    final last = e.lastValues;
    final defs = e.defaultValues;

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
            content: Column(
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
                    setState(() {}); // Done-Icon/Progress aktualisieren
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
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _timeText(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
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
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  if (e.trackSets) 'Sätze',
                  if (e.trackReps) 'Wdh.',
                  if (e.trackWeight) 'Gewicht',
                  if (e.trackDuration) 'Dauer',
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSets)
                    const Icon(Icons.check_circle, color: Colors.green),
                  IconButton(
                    tooltip: 'Satz hinzufügen',
                    onPressed: () => _addSet(context, e),
                    icon: Icon(Icons.add, color: accent),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _stopwatch.isRunning ? () => _finish(context) : _start,
        icon: Icon(
          _stopwatch.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
        ),
        label: Text(_stopwatch.isRunning ? 'Beenden' : 'Start'),
      ),
    );
  }
}
