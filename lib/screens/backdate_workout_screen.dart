import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../utils/duration_utils.dart';
import '../utils/goal_utils.dart';

class BackdateWorkoutScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;
  final DateTime backdateDate;

  const BackdateWorkoutScreen({
    super.key,
    required this.workout,
    required this.exercises,
    required this.backdateDate,
  });

  @override
  State<BackdateWorkoutScreen> createState() => _BackdateWorkoutScreenState();
}

class _BackdateWorkoutScreenState extends State<BackdateWorkoutScreen> {
  final Map<int, List<Map<String, String>>> _setsByExercise = {};
  final TextEditingController _durationCtrl = TextEditingController();
  late DateTime _backdateDate;

  bool get _hasAnySets =>
      _setsByExercise.values.any((list) => list.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _backdateDate = widget.backdateDate;
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _backdateDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('de', 'DE'),
    );
    if (picked != null && picked != _backdateDate) {
      setState(() => _backdateDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_hasAnySets) return;

    final durationMinutes = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    final durationSeconds = durationMinutes * 60;

    // Set backdate to noon to avoid timestamp collisions
    final date = DateTime(
      _backdateDate.year,
      _backdateDate.month,
      _backdateDate.day,
      12,
    );

    // Update lastValues
    final exerciseProvider = context.read<ExerciseProvider>();
    _setsByExercise.forEach((exerciseId, sets) {
      if (sets.isEmpty) return;
      exerciseProvider.updateLastValues(exerciseId, _deriveLastValues(sets));
    });

    // Save
    final progressProvider = context.read<ProgressProvider>();
    final cloudProvider = context.read<CloudSyncProvider>();

    await progressProvider.saveWorkoutEntries(
      workoutId: widget.workout.id,
      durationSeconds: durationSeconds,
      setsByExercise: _setsByExercise,
      when: date,
    );

    if (cloudProvider.syncEnabled && cloudProvider.isSignedIn) {
      cloudProvider.backupNow().catchError((_) {});
    }

    if (!mounted) return;
    final dateStr = DateFormat('dd.MM.yyyy', 'de_DE').format(_backdateDate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Workout für $dateStr nachgetragen'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Map<String, String> _deriveLastValues(List<Map<String, String>> sets) {
    String? lastReps, lastWeight, lastSets, lastDuration, lastDistance;
    for (final s in sets) {
      final reps = s['reps']?.trim();
      final weight = s['weight']?.trim();
      final setsVal = s['sets']?.trim();
      final dur = s['duration']?.trim();
      final dist = s['distance']?.trim();
      if (reps != null && reps.isNotEmpty) lastReps = reps;
      if (weight != null && weight.isNotEmpty) lastWeight = weight;
      if (setsVal != null && setsVal.isNotEmpty) lastSets = setsVal;
      if (dur != null && dur.isNotEmpty) lastDuration = dur;
      if (dist != null && dist.isNotEmpty) lastDistance = dist;
    }
    final map = <String, String>{};
    if (lastSets != null) map['sets'] = lastSets;
    if (lastReps != null) map['reps'] = lastReps;
    if (lastWeight != null) map['weight'] = lastWeight;
    if (lastDistance != null) map['distance'] = lastDistance;
    if (lastDuration != null) map['duration'] = lastDuration;
    return map;
  }

  Future<void> _addSet(BuildContext context, Exercise e) async {
    final tracksAny =
        e.trackSets || e.trackReps || e.trackWeight || e.trackDuration || e.trackDistance;
    if (!tracksAny) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(e.name),
          content: const Text('Keine Felder zum Tracken aktiviert.'),
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

    if (e.trackSets) {
      await _addSetPerSet(context, e);
    } else {
      await _addSetSingle(context, e);
    }
  }

  Future<void> _addSetSingle(BuildContext context, Exercise e) async {
    final existing = List<Map<String, String>>.from(
      _setsByExercise[e.id] ?? const <Map<String, String>>[],
    );
    final sessionLast = existing.isNotEmpty ? existing.last : null;
    final last = sessionLast ?? e.lastValues;
    final defs = e.defaultValues;

    final repsCtrl =
        TextEditingController(text: last['reps'] ?? defs['reps'] ?? '');
    final weightCtrl =
        TextEditingController(text: last['weight'] ?? defs['weight'] ?? '');
    final distanceCtrl =
        TextEditingController(text: last['distance'] ?? defs['distance'] ?? '');
    final durationParts =
        DurationFormatter.fromRaw(last['duration'] ?? defs['duration']);
    final durHoursCtrl = TextEditingController(
        text: durationParts.hours > 0 ? '${durationParts.hours}' : '');
    final durMinutesCtrl = TextEditingController(
        text: durationParts.minutes > 0 ? '${durationParts.minutes}' : '');
    final durSecondsCtrl = TextEditingController(
        text: durationParts.seconds > 0 ? '${durationParts.seconds}' : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.name),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (e.trackReps)
              TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Wiederholungen'),
              ),
            if (e.trackWeight)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Gewicht (kg)'),
                ),
              ),
            if (e.trackDistance)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: distanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Entfernung (km)'),
                ),
              ),
            if (e.trackDuration)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dauer',
                        style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: durHoursCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Std'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: durMinutesCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Min'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: durSecondsCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Sek'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final entry = <String, String>{};
              if (e.trackReps && repsCtrl.text.trim().isNotEmpty) {
                entry['reps'] = repsCtrl.text.trim();
              }
              if (e.trackWeight && weightCtrl.text.trim().isNotEmpty) {
                entry['weight'] = weightCtrl.text.trim();
              }
              if (e.trackDistance && distanceCtrl.text.trim().isNotEmpty) {
                entry['distance'] = distanceCtrl.text.trim();
              }
              if (e.trackDuration) {
                final secs = DurationFormatter.totalSecondsFromTexts(
                    durHoursCtrl.text,
                    durMinutesCtrl.text,
                    durSecondsCtrl.text);
                if (secs > 0) entry['duration'] = '$secs';
              }
              if (entry.isNotEmpty) {
                _setsByExercise.putIfAbsent(e.id, () => []);
                // Single mode: replace last entry
                if (_setsByExercise[e.id]!.isNotEmpty) {
                  _setsByExercise[e.id]!.last = entry;
                } else {
                  _setsByExercise[e.id]!.add(entry);
                }
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSetPerSet(BuildContext context, Exercise e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return _PerSetSheet(
          exercise: e,
          setsByExercise: _setsByExercise,
          onChanged: () {
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exercises = widget.exercises;
    final doneCount =
        _setsByExercise.values.where((v) => v.isNotEmpty).length;
    final progress =
        exercises.isEmpty ? 0.0 : doneCount / exercises.length;
    final dateStr = DateFormat('EE, dd.MM.yyyy', 'de_DE')
        .format(_backdateDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_calendar_rounded,
                          size: 16, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        itemCount: exercises.length + 1, // +1 for duration card
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          // Duration card at the end
          if (i >= exercises.length) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Geschätzte Dauer (Minuten)',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final e = exercises[i];
          final sets = _setsByExercise[e.id] ?? const [];
          final hasSets = sets.isNotEmpty;
          return Card(
            color: hasSets
                ? scheme.primary.withValues(alpha: 0.08)
                : null,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _addSet(context, e),
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    if (e.goal != null)
                      Container(
                        width: 4,
                        color: goalColor(e.goal!, scheme),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(e.name,
                                          style: textTheme.titleMedium),
                                    ),
                                    if (e.goal != null) ...[
                                      const SizedBox(width: 8),
                                      goalBadge(e.goal!, scheme),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (hasSets)
                                  Text(
                                    '${sets.length} Satz${sets.length == 1 ? "" : "e"} erfasst',
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: scheme.primary),
                                  )
                                else
                                  Text(
                                    [
                                      if (e.trackSets) 'Sätze',
                                      if (e.trackReps) 'Wdh.',
                                      if (e.trackWeight) 'Gewicht',
                                      if (e.trackDistance) 'Entfernung',
                                      if (e.trackDuration) 'Dauer',
                                    ].join(' · '),
                                    style: textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: hasSets
                                ? Icon(Icons.check_circle_rounded,
                                    key: ValueKey('done_${e.id}'),
                                    color: scheme.primary)
                                : Icon(Icons.add_circle_outline_rounded,
                                    key: ValueKey('add_${e.id}'),
                                    color: scheme.primary),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hasAnySets ? _save : null,
        backgroundColor:
            _hasAnySets ? scheme.primary : scheme.surfaceContainerHighest,
        foregroundColor:
            _hasAnySets ? scheme.onPrimary : scheme.onSurfaceVariant,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Speichern'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-Set Bottom Sheet (local state, no ActiveWorkoutProvider)
// ---------------------------------------------------------------------------

class _PerSetSheet extends StatefulWidget {
  final Exercise exercise;
  final Map<int, List<Map<String, String>>> setsByExercise;
  final VoidCallback onChanged;

  const _PerSetSheet({
    required this.exercise,
    required this.setsByExercise,
    required this.onChanged,
  });

  @override
  State<_PerSetSheet> createState() => _PerSetSheetState();
}

class _PerSetSheetState extends State<_PerSetSheet> {
  late TextEditingController _repsCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _durHoursCtrl;
  late TextEditingController _durMinutesCtrl;
  late TextEditingController _durSecondsCtrl;

  List<Map<String, String>> get _sets =>
      widget.setsByExercise[widget.exercise.id] ?? [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final e = widget.exercise;
    final sets = _sets;
    final Map<String, String> last;
    if (sets.isNotEmpty) {
      last = sets.last;
    } else if (e.lastValues.isNotEmpty) {
      last = e.lastValues;
    } else {
      last = e.defaultValues;
    }

    _repsCtrl = TextEditingController(text: last['reps'] ?? '');
    _weightCtrl = TextEditingController(text: last['weight'] ?? '');
    _distanceCtrl = TextEditingController(text: last['distance'] ?? '');
    final durParts = DurationFormatter.fromRaw(last['duration']);
    _durHoursCtrl = TextEditingController(
        text: durParts.hours > 0 ? '${durParts.hours}' : '');
    _durMinutesCtrl = TextEditingController(
        text: durParts.minutes > 0 ? '${durParts.minutes}' : '');
    _durSecondsCtrl = TextEditingController(
        text: durParts.seconds > 0 ? '${durParts.seconds}' : '');
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _distanceCtrl.dispose();
    _durHoursCtrl.dispose();
    _durMinutesCtrl.dispose();
    _durSecondsCtrl.dispose();
    super.dispose();
  }

  void _saveCurrentSet() {
    final e = widget.exercise;
    final entry = <String, String>{};
    if (e.trackReps && _repsCtrl.text.trim().isNotEmpty) {
      entry['reps'] = _repsCtrl.text.trim();
    }
    if (e.trackWeight && _weightCtrl.text.trim().isNotEmpty) {
      entry['weight'] = _weightCtrl.text.trim();
    }
    if (e.trackDistance && _distanceCtrl.text.trim().isNotEmpty) {
      entry['distance'] = _distanceCtrl.text.trim();
    }
    if (e.trackDuration) {
      final secs = DurationFormatter.totalSecondsFromTexts(
        _durHoursCtrl.text,
        _durMinutesCtrl.text,
        _durSecondsCtrl.text,
      );
      if (secs > 0) entry['duration'] = '$secs';
    }

    if (entry.isNotEmpty) {
      widget.setsByExercise.putIfAbsent(widget.exercise.id, () => []);
      widget.setsByExercise[widget.exercise.id]!.add(entry);
      widget.onChanged();
      setState(() {});
    }
  }

  void _removeSet(int index) {
    final sets = widget.setsByExercise[widget.exercise.id];
    if (sets != null && index < sets.length) {
      sets.removeAt(index);
      widget.onChanged();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final e = widget.exercise;
    final sets = _sets;

    return SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(e.name, style: textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                '${sets.length} Satz${sets.length == 1 ? "" : "e"} erfasst',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),

            // Completed sets
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sets.length,
                  itemBuilder: (_, i) => _CompletedSetRow(
                    index: i,
                    data: sets[i],
                    exercise: e,
                    onRemove: () => _removeSet(i),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 24),
              ),
            ] else
              const SizedBox(height: 16),

            // Input for next set
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Satz ${sets.length + 1}',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (e.trackReps)
                    TextField(
                      controller: _repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Wiederholungen'),
                    ),
                  if (e.trackWeight)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Gewicht (kg)'),
                      ),
                    ),
                  if (e.trackDistance)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _distanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Entfernung (km)'),
                      ),
                    ),
                  if (e.trackDuration)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _durHoursCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(labelText: 'Std'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _durMinutesCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(labelText: 'Min'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _durSecondsCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(labelText: 'Sek'),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fertig'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saveCurrentSet,
                      child: const Text('Satz speichern'),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedSetRow extends StatelessWidget {
  final int index;
  final Map<String, String> data;
  final Exercise exercise;
  final VoidCallback onRemove;

  const _CompletedSetRow({
    required this.index,
    required this.data,
    required this.exercise,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final parts = <String>[];
    if (exercise.trackReps && data['reps'] != null) {
      parts.add('${data['reps']} Wdh.');
    }
    if (exercise.trackWeight && data['weight'] != null) {
      parts.add('${data['weight']} kg');
    }
    if (exercise.trackDistance && data['distance'] != null) {
      parts.add('${data['distance']} km');
    }
    if (exercise.trackDuration && data['duration'] != null) {
      parts.add(
          DurationFormatter.verbose(int.tryParse(data['duration']!) ?? 0));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              parts.join(' / '),
              style: textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: scheme.error),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
