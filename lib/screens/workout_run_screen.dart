import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/cloud_sync_provider.dart';

const Duration _kFastAnim = Duration(milliseconds: 200);
const Duration _kProgressAnim = Duration(milliseconds: 260);
const Duration _kFabAnim = Duration(milliseconds: 220);

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;
  final bool autoStart; // optionaler Auto-Start

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

    final hasAnySets = active.setsByExercise.values.any(
      (list) => list.isNotEmpty,
    );

    if (!mounted) return;

    // Speichern bestÃÂ¤tigen (auch wenn leer, damit klarer Flow)
    final save = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout beenden'),
            content: Text(
              hasAnySets
                  ? 'Die erfassten SÃÂ¤tze werden gespeichert.'
                  : 'Keine SÃÂ¤tze erfasst. Trotzdem beenden?',
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

    if (save != true) return;

    final duration = active.elapsedTotalSeconds;

    // 1) Last Values pro Exercise aktualisieren
    final exerciseProvider = context.read<ExerciseProvider>();
    active.setsByExercise.forEach((exerciseId, sets) {
      if (sets.isEmpty) return;
      final last = _deriveLastValues(sets);
      exerciseProvider.updateLastValues(exerciseId, last);
    });

    // 2) Session fÃÂ¼r Progress persistieren (nur wenn Sets vorhanden)
    if (hasAnySets) {
      await context.read<ProgressProvider>().saveWorkoutEntries(
        workoutId: widget.workout.id,
        durationSeconds: duration,
        setsByExercise: active.setsByExercise,
      );
    }

    // 3) Optional Cloud-Backup direkt nach Abschluss
    final cloud = context.read<CloudSyncProvider>();
    if (cloud.syncEnabled && cloud.isSignedIn) {
      try {
        await cloud.backupNow();
      } catch (_) {
        // stiller Fehler
      }
    }

    // 4) Aktive Session beenden
    active.clear();

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
    final active = context.read<ActiveWorkoutProvider>();
    final existing = List<Map<String, String>>.from(
      active.setsByExercise[e.id] ?? const <Map<String, String>>[],
    );
    final sessionLast = existing.isNotEmpty ? existing.last : null;
    final last = sessionLast ?? e.lastValues;
    final defs = e.defaultValues;
    final tracksAny =
        e.trackSets || e.trackReps || e.trackWeight || e.trackDuration;
    if (!tracksAny) {
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(e.name),
              content: const Text(
                'FÃÂ¼r diese ÃÅbung sind keine Felder zum Tracken aktiviert. '
                'Aktiviere SÃÂ¤tze/Wdh./Gewicht/Dauer in der ÃÅbungsbearbeitung.',
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
                        labelText: 'SÃÂ¤tze (Anzahl)',
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
                    context.read<ActiveWorkoutProvider>().updateLastSet(
                      e.id,
                      entry,
                    );
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
    final active = context.watch<ActiveWorkoutProvider>();
    final total = widget.exercises.length;
    final doneCount =
        active.setsByExercise.values.where((v) => v.isNotEmpty).length;
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
                builder:
                    (_, sec, __) => AnimatedSwitcher(
                      duration: _kFastAnim,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder:
                          (currentChild, previousChildren) => Stack(
                            alignment: Alignment.center,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          ),
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                          reverseCurve: Curves.easeIn,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _formatTime(sec),
                        key: ValueKey(sec),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: _kProgressAnim,
            curve: Curves.easeOut,
            builder:
                (context, value, _) =>
                    LinearProgressIndicator(value: value, minHeight: 4),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: widget.exercises.length,
        itemBuilder: (_, i) {
          final e = widget.exercises[i];
          final hasSets = (active.setsByExercise[e.id] ?? const []).isNotEmpty;
          return AnimatedContainer(
            duration: _kFastAnim,
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  hasSets
                      ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : const [],
            ),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  hasSets
                      ? Theme.of(context).colorScheme.surfaceVariant
                      : Theme.of(context).cardColor,
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
                  ].join(' / '),
                ),
                trailing: SizedBox(
                  width: 48,
                  height: 48,
                  child: AnimatedSwitcher(
                    duration: _kFastAnim,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final scale = Tween<double>(
                        begin: 0.85,
                        end: 1,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: scale, child: child),
                      );
                    },
                    child:
                        hasSets
                            ? Center(
                              key: ValueKey('done_${e.id}'),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            )
                            : IconButton(
                              key: ValueKey('add_${e.id}'),
                              tooltip: 'Satz hinzufügen',
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tight(
                                const Size(48, 48),
                              ),
                              onPressed: () => _addSet(context, e),
                              icon: Icon(Icons.add, color: accent),
                            ),
                  ),
                ),
                onTap: () => _addSet(context, e),
              ),
            ),
          );
        },
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: _kFabAnim,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(begin: 0.9, end: 1).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        child:
            _isRunning
                ? FloatingActionButton.extended(
                  key: const ValueKey('fab_stop'),
                  onPressed: _stopAndFinish,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                )
                : FloatingActionButton.extended(
                  key: const ValueKey('fab_start'),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                ),
      ),
    );
  }
}
