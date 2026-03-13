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

const Duration _kFastAnim = Duration(milliseconds: 200);
const Duration _kProgressAnim = Duration(milliseconds: 260);
const Duration _kFabAnim = Duration(milliseconds: 220);

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

    final hasAnySets = active.setsByExercise.values.any(
      (list) => list.isNotEmpty,
    );

    if (!mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          hasAnySets
              ? Icons.check_circle_outline_rounded
              : Icons.warning_amber_rounded,
          size: 32,
          color: hasAnySets
              ? const Color(0xFF4CAF50)
              : Theme.of(ctx).colorScheme.error,
        ),
        content: Text(
          hasAnySets
              ? 'Die erfassten Sätze werden gespeichert.'
              : 'Keine Sätze erfasst. Trotzdem beenden?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );

    if (save != true) return;

    final duration = active.elapsedTotalSeconds;

    final exerciseProvider = context.read<ExerciseProvider>();
    active.setsByExercise.forEach((exerciseId, sets) {
      if (sets.isEmpty) return;
      final last = _deriveLastValues(sets);
      exerciseProvider.updateLastValues(exerciseId, last);
    });

    if (hasAnySets) {
      await context.read<ProgressProvider>().saveWorkoutEntries(
        workoutId: widget.workout.id,
        durationSeconds: duration,
        setsByExercise: active.setsByExercise,
      );
    }

    final cloud = context.read<CloudSyncProvider>();
    if (cloud.syncEnabled && cloud.isSignedIn) {
      try {
        await cloud.backupNow();
      } catch (_) {}
    }

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

  String _formatTime(int seconds) => DurationFormatter.digital(seconds);

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
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              size: 32, color: Theme.of(ctx).colorScheme.error),
          content: const Text(
            'Für diese Übung sind keine Felder zum Tracken aktiviert. '
            'Aktiviere Sätze/Wdh./Gewicht/Dauer in der Übungsbearbeitung.',
          ),
          actions: [
            FilledButton(
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
    final durationParts = DurationFormatter.fromRaw(
      last['duration'] ?? defs['duration'],
    );
    final durHoursCtrl = TextEditingController(
      text: durationParts.hours > 0 ? '${durationParts.hours}' : '',
    );
    final durMinutesCtrl = TextEditingController(
      text: durationParts.minutes > 0 ? '${durationParts.minutes}' : '',
    );
    final durSecondsCtrl = TextEditingController(
      text: durationParts.seconds > 0 ? '${durationParts.seconds}' : '',
    );

    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 24, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.name,
                          style: Theme.of(ctx).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    children: [
                      if (e.trackSets)
                        _InputRow(
                          icon: Icons.layers_rounded,
                          controller: setsCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      if (e.trackReps)
                        _InputRow(
                          icon: Icons.repeat_rounded,
                          controller: repsCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      if (e.trackWeight)
                        _InputRow(
                          icon: Icons.fitness_center_rounded,
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          suffix: 'kg',
                        ),
                      if (e.trackDuration) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 20,
                                color: scheme.onSurfaceVariant
                                    .withOpacity(0.6)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: durHoursCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Std',
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: durMinutesCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Min',
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: durSecondsCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Sek',
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final entry = <String, String>{};
                      if (e.trackSets && setsCtrl.text.trim().isNotEmpty) {
                        entry['sets'] = setsCtrl.text.trim();
                      }
                      if (e.trackReps && repsCtrl.text.trim().isNotEmpty) {
                        entry['reps'] = repsCtrl.text.trim();
                      }
                      if (e.trackWeight &&
                          weightCtrl.text.trim().isNotEmpty) {
                        entry['weight'] = weightCtrl.text.trim();
                      }
                      if (e.trackDuration) {
                        final durationSeconds =
                            DurationFormatter.totalSecondsFromTexts(
                          durHoursCtrl.text,
                          durMinutesCtrl.text,
                          durSecondsCtrl.text,
                        );
                        if (durationSeconds > 0) {
                          entry['duration'] = '$durationSeconds';
                        }
                      }

                      if (entry.isNotEmpty) {
                        context.read<ActiveWorkoutProvider>().updateLastSet(
                          e.id,
                          entry,
                        );
                        setState(() {});
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Icon(Icons.check_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                builder: (_, sec, __) => Text(
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
              onPressed: _stopAndFinish,
              icon: Icon(Icons.stop_circle_outlined, color: scheme.error),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: _kProgressAnim,
            curve: Curves.easeOut,
            builder: (context, value, _) =>
                LinearProgressIndicator(value: value, minHeight: 4),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: widget.exercises.length,
        itemBuilder: (_, i) {
          final e = widget.exercises[i];
          final hasSets =
              (active.setsByExercise[e.id] ?? const []).isNotEmpty;
          final setCount =
              (active.setsByExercise[e.id] ?? const []).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              color: hasSets
                  ? const Color(0xFF4CAF50).withOpacity(0.06)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: hasSets
                    ? BorderSide(
                        color: const Color(0xFF4CAF50).withOpacity(0.25),
                        width: 1.5)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => _addSet(context, e),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasSets
                              ? const Color(0xFF4CAF50).withOpacity(0.12)
                              : scheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          hasSets
                              ? Icons.check_rounded
                              : Icons.fitness_center_rounded,
                          size: 20,
                          color: hasSets
                              ? const Color(0xFF4CAF50)
                              : scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (e.trackSets)
                                  _MiniIcon(Icons.layers_rounded, scheme),
                                if (e.trackReps)
                                  _MiniIcon(Icons.repeat_rounded, scheme),
                                if (e.trackWeight)
                                  _MiniIcon(
                                      Icons.fitness_center_rounded, scheme),
                                if (e.trackDuration)
                                  _MiniIcon(Icons.timer_outlined, scheme),
                                if (hasSets) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$setCount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color:
                                                const Color(0xFF4CAF50),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.add_rounded, color: scheme.primary),
                    ],
                  ),
                ),
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
          final scale =
              Tween<double>(begin: 0.9, end: 1).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        child: _isRunning
            ? FloatingActionButton(
                key: const ValueKey('fab_stop'),
                onPressed: _stopAndFinish,
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                child: const Icon(Icons.stop_rounded),
              )
            : FloatingActionButton(
                key: const ValueKey('fab_start'),
                onPressed: _start,
                child: const Icon(Icons.play_arrow_rounded),
              ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? suffix;

  const _InputRow({
    required this.icon,
    required this.controller,
    this.keyboardType = TextInputType.number,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon,
              size: 20, color: scheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                suffixText: suffix,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final ColorScheme scheme;
  const _MiniIcon(this.icon, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(icon,
          size: 14, color: scheme.onSurfaceVariant.withOpacity(0.45)),
    );
  }
}
