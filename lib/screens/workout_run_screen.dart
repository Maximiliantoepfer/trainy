import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../utils/duration_utils.dart';

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;
  final bool autoStart;

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
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    } else {
      final active = context.read<ActiveWorkoutProvider>();
      if (active.isActive) {
        active.updateExercises(widget.exercises);
        _isRunning = true;
      }
    }
  }

  void _start() {
    if (_isRunning) return;
    final active = context.read<ActiveWorkoutProvider>();
    if (!active.isActive) {
      active.start(workout: widget.workout, exercises: widget.exercises);
    } else {
      active.updateExercises(widget.exercises);
    }
    setState(() => _isRunning = true);
  }

  Future<void> _stopAndFinish() async {
    if (!_isRunning) return;
    final active = context.read<ActiveWorkoutProvider>();
    _isRunning = false;
    setState(() {});

    final hasAnySets = active.setsByExercise.values.any((list) => list.isNotEmpty);
    if (!mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workout beenden'),
        content: Text(hasAnySets
            ? 'Die erfassten Sätze werden gespeichert.'
            : 'Keine Sätze erfasst. Trotzdem beenden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Beenden')),
        ],
      ),
    );

    if (save != true) return;

    final duration = active.elapsedTotalSeconds;
    final exerciseProvider = context.read<ExerciseProvider>();
    active.setsByExercise.forEach((exerciseId, sets) {
      if (sets.isEmpty) return;
      exerciseProvider.updateLastValues(exerciseId, _deriveLastValues(sets));
    });

    if (hasAnySets) {
      await context.read<ProgressProvider>().saveWorkoutEntries(
        workoutId: widget.workout.id, durationSeconds: duration,
        setsByExercise: active.setsByExercise,
      );
    }

    final cloud = context.read<CloudSyncProvider>();
    if (cloud.syncEnabled && cloud.isSignedIn) {
      try { await cloud.backupNow(); } catch (_) {}
    }

    active.clear();
    if (mounted) Navigator.of(context).pop();
  }

  Map<String, String> _deriveLastValues(List<Map<String, String>> sets) {
    String? lastReps, lastWeight, lastSets, lastDuration;
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
    if (lastSets != null) map['sets'] = lastSets;
    if (lastReps != null) map['reps'] = lastReps;
    if (lastWeight != null) map['weight'] = lastWeight;
    if (lastDuration != null) map['duration'] = lastDuration;
    return map;
  }

  Future<void> _addSet(BuildContext context, Exercise e) async {
    final active = context.read<ActiveWorkoutProvider>();
    final existing = List<Map<String, String>>.from(
      active.setsByExercise[e.id] ?? const <Map<String, String>>[],
    );
    final sessionLast = existing.isNotEmpty ? existing.last : null;
    final last = sessionLast ?? e.lastValues;
    final defs = e.defaultValues;
    final tracksAny = e.trackSets || e.trackReps || e.trackWeight || e.trackDuration;

    if (!tracksAny) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(e.name),
        content: const Text('Keine Felder zum Tracken aktiviert.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ));
      return;
    }

    final repsCtrl = TextEditingController(text: last['reps'] ?? defs['reps'] ?? '');
    final weightCtrl = TextEditingController(text: last['weight'] ?? defs['weight'] ?? '');
    final setsCtrl = TextEditingController(text: last['sets'] ?? defs['sets'] ?? '');
    final durationParts = DurationFormatter.fromRaw(last['duration'] ?? defs['duration']);
    final durHoursCtrl = TextEditingController(text: durationParts.hours > 0 ? '${durationParts.hours}' : '');
    final durMinutesCtrl = TextEditingController(text: durationParts.minutes > 0 ? '${durationParts.minutes}' : '');
    final durSecondsCtrl = TextEditingController(text: durationParts.seconds > 0 ? '${durationParts.seconds}' : '');

    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(e.name),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (e.trackSets)
          TextField(controller: setsCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sätze')),
        if (e.trackReps)
          Padding(padding: const EdgeInsets.only(top: 12),
            child: TextField(controller: repsCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Wiederholungen'))),
        if (e.trackWeight)
          Padding(padding: const EdgeInsets.only(top: 12),
            child: TextField(controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Gewicht (kg)'))),
        if (e.trackDuration)
          Padding(padding: const EdgeInsets.only(top: 12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dauer', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: durHoursCtrl,
                  keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Std'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: durMinutesCtrl,
                  keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Min'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: durSecondsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Sek'))),
              ]),
            ],
          )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
        FilledButton(onPressed: () {
          final entry = <String, String>{};
          if (e.trackSets && setsCtrl.text.trim().isNotEmpty) entry['sets'] = setsCtrl.text.trim();
          if (e.trackReps && repsCtrl.text.trim().isNotEmpty) entry['reps'] = repsCtrl.text.trim();
          if (e.trackWeight && weightCtrl.text.trim().isNotEmpty) entry['weight'] = weightCtrl.text.trim();
          if (e.trackDuration) {
            final secs = DurationFormatter.totalSecondsFromTexts(
              durHoursCtrl.text, durMinutesCtrl.text, durSecondsCtrl.text);
            if (secs > 0) entry['duration'] = '$secs';
          }
          if (entry.isNotEmpty) {
            context.read<ActiveWorkoutProvider>().updateLastSet(e.id, entry);
            setState(() {});
          }
          Navigator.pop(ctx);
        }, child: const Text('Speichern')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = context.watch<ActiveWorkoutProvider>();
    final total = widget.exercises.length;
    final doneCount = active.setsByExercise.values.where((v) => v.isNotEmpty).length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ValueListenableBuilder<int>(
                valueListenable: active.elapsedSeconds,
                builder: (_, sec, __) => Text(
                  DurationFormatter.digital(sec),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          if (_isRunning)
            IconButton(tooltip: 'Beenden', onPressed: _stopAndFinish,
              icon: Icon(Icons.stop_circle_outlined, color: scheme.error)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(value: value),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: widget.exercises.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = widget.exercises[i];
          final hasSets = (active.setsByExercise[e.id] ?? const []).isNotEmpty;
          return Card(
            color: hasSets ? scheme.primary.withOpacity(0.06) : null,
            child: InkWell(
              onTap: () => _addSet(context, e),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text([
                        if (e.trackSets) 'Sätze', if (e.trackReps) 'Wdh.',
                        if (e.trackWeight) 'Gewicht', if (e.trackDuration) 'Dauer',
                      ].join(' · '), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  )),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: hasSets
                        ? Icon(Icons.check_circle_rounded, key: ValueKey('done_${e.id}'), color: const Color(0xFF4CAF50))
                        : Icon(Icons.add_circle_outline_rounded, key: ValueKey('add_${e.id}'), color: scheme.primary),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isRunning
            ? FloatingActionButton.extended(key: const ValueKey('fab_stop'),
                onPressed: _stopAndFinish, backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                icon: const Icon(Icons.stop_rounded), label: const Text('Beenden'))
            : FloatingActionButton.extended(key: const ValueKey('fab_start'),
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start')),
      ),
    );
  }
}
