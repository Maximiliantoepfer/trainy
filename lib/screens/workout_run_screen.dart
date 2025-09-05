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
  late Stopwatch _stopwatch;
  Timer? _ticker;

  // pro Übung: completed + erfasste Sets
  final Map<int, bool> _completed = {};
  final Map<int, List<Map<String, String>>> _setsByExercise = {};

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stop() {
    _stopwatch.stop();
    _ticker?.cancel();
    setState(() {});
  }

  String _timeText() {
    final s = _stopwatch.elapsed.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
    // (Optional: h:mm:ss, hier reicht mm:ss für Workouts)
  }

  Future<void> _addSet(BuildContext context, Exercise e) async {
    final repsCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '1');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Satz für ${e.name}',
                  style: Theme.of(ctx).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
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
                        labelText: 'Gewicht (kg, optional)',
                      ),
                    ),
                  ),
                if (e.trackDuration)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dauer (Sekunden)',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Abbrechen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final entry = <String, String>{};
                          if (e.trackSets) entry['sets'] = setsCtrl.text.trim();
                          if (e.trackReps) entry['reps'] = repsCtrl.text.trim();
                          if (e.trackWeight)
                            entry['weight'] = weightCtrl.text.trim();
                          if (e.trackDuration)
                            entry['duration'] = durationCtrl.text.trim();

                          final list =
                              _setsByExercise[e.id] ?? <Map<String, String>>[];
                          list.add(entry);
                          _setsByExercise[e.id] = list;
                          _completed[e.id] = true;

                          Navigator.of(ctx).pop();
                          setState(() {});
                        },
                        child: const Text('Speichern'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finish(BuildContext context) async {
    _stop();

    final provider = context.read<ProgressProvider>();
    await provider.saveWorkoutEntries(
      workoutId: widget.workout.id,
      durationSeconds: _stopwatch.elapsed.inSeconds,
      setsByExercise: _setsByExercise,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

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
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: widget.exercises.length,
        itemBuilder: (_, i) {
          final e = widget.exercises[i];
          final done = _completed[e.id] ?? false;
          final sets = _setsByExercise[e.id] ?? const [];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: done ? Border.all(color: accent, width: 1.4) : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color:
                    done
                        ? Colors.greenAccent
                        : Theme.of(context).colorScheme.outline,
              ),
              title: Text(
                e.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle:
                  sets.isEmpty
                      ? Text(
                        [
                          if (e.trackSets) 'Sätze',
                          if (e.trackReps) 'Wdh.',
                          if (e.trackWeight) 'Gewicht',
                          if (e.trackDuration) 'Dauer',
                        ].join(' · '),
                      )
                      : Text('${sets.length} Satz/Sätze erfasst'),
              trailing: FilledButton.tonalIcon(
                onPressed: () => _addSet(context, e),
                icon: const Icon(Icons.add),
                label: const Text('Satz'),
              ),
              onTap:
                  () => setState(
                    () => _completed[e.id] = !(_completed[e.id] ?? false),
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
