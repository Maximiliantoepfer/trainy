// lib/screens/workout_entry_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout_entry.dart';
import '../providers/exercise_provider.dart';
import '../providers/progress_provider.dart';
import '../services/workout_entry_database.dart';
import '../providers/cloud_sync_provider.dart';
import '../models/exercise.dart';
import '../utils/duration_utils.dart';

class WorkoutEntryDetailScreen extends StatefulWidget {
  final WorkoutEntry entry;

  const WorkoutEntryDetailScreen({super.key, required this.entry});

  @override
  State<WorkoutEntryDetailScreen> createState() =>
      _WorkoutEntryDetailScreenState();
}

class _WorkoutEntryDetailScreenState extends State<WorkoutEntryDetailScreen> {
  late Map<int, Map<String, dynamic>> _results;
  late int? _durationSeconds;

  @override
  void initState() {
    super.initState();
    _durationSeconds = widget.entry.durationSeconds;
    // Deep copy inkl. perSet-Listen
    _results = {};
    for (final e in widget.entry.results.entries) {
      final map = Map<String, dynamic>.from(e.value);
      if (map['perSet'] is List) {
        map['perSet'] = (map['perSet'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
      _results[e.key] = map;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ---- Workout-Dauer bearbeiten ----

  Future<void> _editWorkoutDuration() async {
    final current = _durationSeconds ?? 0;
    final parts = DurationFormatter.split(current);
    final hCtrl = TextEditingController(
        text: parts.hours > 0 ? '${parts.hours}' : '');
    final mCtrl = TextEditingController(
        text: parts.minutes > 0 ? '${parts.minutes}' : '');
    final sCtrl = TextEditingController(
        text: parts.seconds > 0 ? '${parts.seconds}' : '');

    final newDuration = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workout-Dauer bearbeiten'),
        content: Row(children: [
          Expanded(child: TextField(
            controller: hCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Std'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: mCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Min'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: sCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Sek'),
          )),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final secs = DurationFormatter.totalSecondsFromTexts(
                  hCtrl.text, mCtrl.text, sCtrl.text);
              Navigator.of(ctx).pop(secs);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (newDuration == null) return;

    await WorkoutEntryDatabase.instance.updateSessionDuration(
      workoutId: widget.entry.workoutId,
      timestamp: widget.entry.date.millisecondsSinceEpoch,
      durationSeconds: newDuration,
    );
    if (!mounted) return;
    await context.read<ProgressProvider>().refreshEntries();
    setState(() => _durationSeconds = newDuration);
    _scheduleBackup();
  }

  // ---- Single-Modus: Einzelmetrik bearbeiten ----

  Future<void> _editMetric({
    required int exerciseId,
    required String field,
    required num? current,
  }) async {
    final isWeight = field == 'weight';
    final isDistance = field == 'distance';
    final isDuration = field == 'duration';
    final isInt = !isWeight && !isDistance;

    // Dauer: Std/Min/Sek-Dialog
    if (isDuration) {
      final newSecs = await _showDurationEditDialog(current?.toInt() ?? 0);
      if (newSecs == null) return;

      await WorkoutEntryDatabase.instance.updateMetric(
        workoutId: widget.entry.workoutId,
        exerciseId: exerciseId,
        timestamp: widget.entry.date.millisecondsSinceEpoch,
        field: field,
        value: newSecs,
      );
      if (!mounted) return;
      await context.read<ProgressProvider>().refreshEntries();
      setState(() {
        final m = _results[exerciseId] ?? <String, dynamic>{};
        m[field] = newSecs;
        _results[exerciseId] = m;
      });
      _scheduleBackup();
      return;
    }

    final controller = TextEditingController(
      text: current == null ? '' : '$current',
    );

    final newValue = await showDialog<num?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_dialogTitleFor(field)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            hintText: isInt ? 'z. B. 10' : 'z. B. 42.5',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final txt = controller.text.trim().replaceAll(',', '.');
              if (txt.isEmpty) {
                Navigator.of(ctx).pop(null);
                return;
              }
              num? parsed;
              if (isInt) {
                parsed = int.tryParse(txt);
              } else {
                parsed = double.tryParse(txt);
              }
              Navigator.of(ctx).pop(parsed);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (newValue == null) return;

    await WorkoutEntryDatabase.instance.updateMetric(
      workoutId: widget.entry.workoutId,
      exerciseId: exerciseId,
      timestamp: widget.entry.date.millisecondsSinceEpoch,
      field: field,
      value: newValue,
    );
    if (!mounted) return;
    await context.read<ProgressProvider>().refreshEntries();
    setState(() {
      final m = _results[exerciseId] ?? <String, dynamic>{};
      m[field] = newValue;
      _results[exerciseId] = m;
    });
    _scheduleBackup();
  }

  // ---- Per-Set Bearbeitung ----

  Future<void> _editPerSetValue({
    required int exerciseId,
    required int setIndex,
    required String field,
    required num? current,
  }) async {
    num? newValue;

    if (field == 'duration') {
      newValue = await _showDurationEditDialog(current?.toInt() ?? 0);
    } else {
      final isWeight = field == 'weight' || field == 'distance';
      final controller = TextEditingController(
        text: current == null ? '' : '$current',
      );

      newValue = await showDialog<num?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_dialogTitleFor(field)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: isWeight ? 'z. B. 42.5' : 'z. B. 10',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final txt = controller.text.trim().replaceAll(',', '.');
                if (txt.isEmpty) {
                  Navigator.of(ctx).pop(null);
                  return;
                }
                num? parsed;
                if (isWeight) {
                  parsed = double.tryParse(txt);
                } else {
                  parsed = int.tryParse(txt);
                }
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
    }

    if (newValue == null) return;

    setState(() {
      final data = _results[exerciseId]!;
      final perSet = data['perSet'] as List<Map<String, dynamic>>;
      perSet[setIndex][field] = newValue;
      _recalcAggregates(data, perSet);
    });
    await _persistExerciseValues(exerciseId);
  }

  void _removeSet(int exerciseId, int setIndex) {
    setState(() {
      final data = _results[exerciseId]!;
      final perSet = data['perSet'] as List<Map<String, dynamic>>;
      perSet.removeAt(setIndex);
      _recalcAggregates(data, perSet);
    });
    _persistExerciseValues(exerciseId);
  }

  void _addSet(int exerciseId, Exercise exercise) {
    setState(() {
      final data = _results[exerciseId]!;
      final perSet = data['perSet'] as List<Map<String, dynamic>>;

      // Letzten Satz kopieren oder leeren erzeugen
      final newSet = <String, dynamic>{};
      if (perSet.isNotEmpty) {
        final last = perSet.last;
        if (exercise.trackReps && last['reps'] != null) newSet['reps'] = last['reps'];
        if (exercise.trackWeight && last['weight'] != null) newSet['weight'] = last['weight'];
        if (exercise.trackDistance && last['distance'] != null) newSet['distance'] = last['distance'];
        if (exercise.trackDuration && last['duration'] != null) newSet['duration'] = last['duration'];
      }
      perSet.add(newSet);
      _recalcAggregates(data, perSet);
    });
    _persistExerciseValues(exerciseId);
  }

  /// Berechnet Top-Level-Aggregate aus perSet-Array neu.
  void _recalcAggregates(Map<String, dynamic> data, List<Map<String, dynamic>> perSet) {
    data['sets'] = perSet.length;

    int? lastReps;
    double? maxWeight;
    int totalDuration = 0;
    double totalDistance = 0;

    for (final s in perSet) {
      final r = _asInt(s['reps']);
      if (r != null) lastReps = r;
      final w = _asDouble(s['weight']);
      if (w != null && (maxWeight == null || w > maxWeight)) maxWeight = w;
      final d = _asInt(s['duration']);
      if (d != null) totalDuration += d;
      final dist = _asDouble(s['distance']);
      if (dist != null) totalDistance += dist;
    }

    if (lastReps != null) {
      data['reps'] = lastReps;
    } else {
      data.remove('reps');
    }
    if (maxWeight != null) {
      data['weight'] = maxWeight;
    } else {
      data.remove('weight');
    }
    if (totalDistance > 0) {
      data['distance'] = totalDistance;
    } else {
      data.remove('distance');
    }
    if (totalDuration > 0) {
      data['duration'] = totalDuration;
    } else {
      data.remove('duration');
    }
  }

  Future<void> _persistExerciseValues(int exerciseId) async {
    await WorkoutEntryDatabase.instance.updateExerciseValues(
      workoutId: widget.entry.workoutId,
      exerciseId: exerciseId,
      timestamp: widget.entry.date.millisecondsSinceEpoch,
      values: _results[exerciseId]!,
    );
    if (!mounted) return;
    await context.read<ProgressProvider>().refreshEntries();
    _scheduleBackup();
  }

  // ---- Hilfsmethoden ----

  Future<int?> _showDurationEditDialog(int currentSeconds) async {
    final parts = DurationFormatter.split(currentSeconds);
    final hCtrl = TextEditingController(
        text: parts.hours > 0 ? '${parts.hours}' : '');
    final mCtrl = TextEditingController(
        text: parts.minutes > 0 ? '${parts.minutes}' : '');
    final sCtrl = TextEditingController(
        text: parts.seconds > 0 ? '${parts.seconds}' : '');

    return showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dauer bearbeiten'),
        content: Row(children: [
          Expanded(child: TextField(
            controller: hCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Std'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: mCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Min'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: sCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Sek'),
          )),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final secs = DurationFormatter.totalSecondsFromTexts(
                  hCtrl.text, mCtrl.text, sCtrl.text);
              Navigator.of(ctx).pop(secs);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  String _dialogTitleFor(String field) {
    switch (field) {
      case 'sets':
        return 'Sätze bearbeiten';
      case 'reps':
        return 'Wiederholungen bearbeiten';
      case 'weight':
        return 'Gewicht bearbeiten';
      case 'distance':
        return 'Entfernung bearbeiten';
      case 'duration':
        return 'Dauer bearbeiten';
      default:
        return 'Wert bearbeiten';
    }
  }

  void _scheduleBackup() {
    try {
      if (mounted) context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout-Details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _formatDate(widget.entry.date),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Workout-Dauer Header
          if (_durationSeconds != null && _durationSeconds! > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _editWorkoutDuration,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.timer_outlined, size: 20, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text('Workout-Dauer',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                      const Spacer(),
                      Text(
                        DurationFormatter.verbose(_durationSeconds!),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    ]),
                  ),
                ),
              ),
            ),

          // Übungskarten
          ...List.generate(_results.length, (index) {
            final exerciseId = _results.keys.elementAt(index);
            final data = _results[exerciseId] ?? const {};
            Exercise? ex;
            try {
              ex = exercises.firstWhere((e) => e.id == exerciseId);
            } catch (_) {
              ex = null;
            }

            final usePerSetMode = ex != null &&
                ex.trackSets &&
                data.containsKey('perSet') &&
                data['perSet'] is List;

            return Padding(
              padding: EdgeInsets.only(bottom: index < _results.length - 1 ? 12 : 0),
              child: usePerSetMode
                  ? _PerSetExerciseCard(
                      exerciseId: exerciseId,
                      exercise: ex,
                      data: data,
                      onEditValue: _editPerSetValue,
                      onRemoveSet: _removeSet,
                      onAddSet: _addSet,
                    )
                  : _SingleExerciseCard(
                      exerciseId: exerciseId,
                      exercise: ex,
                      exerciseName: ex?.name ?? 'Übung #$exerciseId',
                      values: data,
                      onEdit: _editMetric,
                    ),
            );
          }),
        ],
      ),
    );
  }

  // ---- Statische Hilfsfunktionen ----

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Per-Set-Modus: Übungskarte mit editierbaren Einzelsätzen
// ---------------------------------------------------------------------------

class _PerSetExerciseCard extends StatelessWidget {
  final int exerciseId;
  final Exercise exercise;
  final Map<String, dynamic> data;
  final Future<void> Function({
    required int exerciseId,
    required int setIndex,
    required String field,
    required num? current,
  }) onEditValue;
  final void Function(int exerciseId, int setIndex) onRemoveSet;
  final void Function(int exerciseId, Exercise exercise) onAddSet;

  const _PerSetExerciseCard({
    required this.exerciseId,
    required this.exercise,
    required this.data,
    required this.onEditValue,
    required this.onRemoveSet,
    required this.onAddSet,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final perSet = (data['perSet'] as List)
        .map((s) => s as Map<String, dynamic>)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel
            Row(children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ImageIcon(const AssetImage('assets/icons/hantel.png'),
                    color: scheme.onPrimaryContainer, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${perSet.length} Satz${perSet.length == 1 ? "" : "e"}',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              )),
            ]),

            if (perSet.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Einzelne Sätze
              ...perSet.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return _EditableSetRow(
                  index: i,
                  setData: s,
                  exercise: exercise,
                  onEditValue: (field, current) => onEditValue(
                    exerciseId: exerciseId,
                    setIndex: i,
                    field: field,
                    current: current,
                  ),
                  onRemove: () => onRemoveSet(exerciseId, i),
                );
              }),
            ],

            // Satz hinzufügen
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => onAddSet(exerciseId, exercise),
                icon: Icon(Icons.add_rounded, size: 18, color: scheme.primary),
                label: Text('Satz hinzufügen',
                  style: textTheme.labelMedium?.copyWith(color: scheme.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editierbare Satz-Zeile (pro Satz im Per-Set-Modus)
// ---------------------------------------------------------------------------

class _EditableSetRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> setData;
  final Exercise exercise;
  final void Function(String field, num? current) onEditValue;
  final VoidCallback onRemove;

  const _EditableSetRow({
    required this.index,
    required this.setData,
    required this.exercise,
    required this.onEditValue,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Satznummer
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                )),
            ),
          ),
          const SizedBox(width: 10),

          // Tappbare Werte (nur getrackte Felder)
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (exercise.trackReps)
                  _TappableValue(
                    label: 'Wdh.',
                    value: _asInt(setData['reps'])?.toString(),
                    onTap: () => onEditValue('reps', _asInt(setData['reps'])),
                  ),
                if (exercise.trackWeight)
                  _TappableValue(
                    label: 'kg',
                    value: _formatWeight(_asDouble(setData['weight'])),
                    onTap: () => onEditValue('weight', _asDouble(setData['weight'])),
                  ),
                if (exercise.trackDistance)
                  _TappableValue(
                    label: 'km',
                    value: _formatWeight(_asDouble(setData['distance'])),
                    onTap: () => onEditValue('distance', _asDouble(setData['distance'])),
                  ),
                if (exercise.trackDuration)
                  _TappableValue(
                    label: '',
                    value: _asInt(setData['duration']) != null
                        ? DurationFormatter.verbose(_asInt(setData['duration'])!)
                        : null,
                    onTap: () => onEditValue('duration', _asInt(setData['duration'])),
                  ),
              ],
            ),
          ),

          // Löschen
          SizedBox(
            width: 32, height: 32,
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: scheme.error),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String? _formatWeight(double? w) {
    if (w == null) return null;
    return w.truncateToDouble() == w ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
  }
}

// ---------------------------------------------------------------------------
// Tappbarer Einzelwert innerhalb einer Satzzeile
// ---------------------------------------------------------------------------

class _TappableValue extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _TappableValue({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.isNotEmpty;
    final displayText = hasValue
        ? (label.isNotEmpty ? '$value $label' : value!)
        : (label.isNotEmpty ? '$label?' : '—');

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(displayText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: hasValue ? null : scheme.onSurfaceVariant.withValues(alpha: 0.5),
            )),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single-Modus: Nur getrackte Felder als Chips (kein trackSets / kein perSet)
// ---------------------------------------------------------------------------

class _SingleExerciseCard extends StatelessWidget {
  final int exerciseId;
  final Exercise? exercise;
  final String exerciseName;
  final Map<String, dynamic> values;
  final Future<void> Function({
    required int exerciseId,
    required String field,
    required num? current,
  }) onEdit;

  const _SingleExerciseCard({
    required this.exerciseId,
    required this.exercise,
    required this.exerciseName,
    required this.values,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = exercise;

    // Nur getrackte Felder anzeigen
    final chips = <Widget>[];

    if (ex == null || ex.trackSets) {
      final sets = _asInt(values['sets']);
      chips.add(_MetricChip(
        icon: Icon(Icons.layers, size: 18, color: scheme.onSecondaryContainer),
        label: 'Sätze',
        value: sets?.toString(),
        onTap: () => onEdit(exerciseId: exerciseId, field: 'sets', current: sets),
      ));
    }
    if (ex == null || ex.trackReps) {
      final reps = _asInt(values['reps']);
      chips.add(_MetricChip(
        icon: Icon(Icons.repeat, size: 18, color: scheme.onSecondaryContainer),
        label: 'Wdh.',
        value: reps?.toString(),
        onTap: () => onEdit(exerciseId: exerciseId, field: 'reps', current: reps),
      ));
    }
    if (ex == null || ex.trackWeight) {
      final weight = _asDouble(values['weight']);
      chips.add(_MetricChip(
        icon: ImageIcon(const AssetImage('assets/icons/hantel.png'),
            size: 18, color: scheme.onSecondaryContainer),
        label: 'Gewicht',
        value: weight == null ? null : _formatWeight(weight),
        onTap: () => onEdit(exerciseId: exerciseId, field: 'weight', current: weight),
      ));
    }
    if (ex == null || ex.trackDistance) {
      final distance = _asDouble(values['distance']);
      chips.add(_MetricChip(
        icon: Icon(Icons.straighten, size: 18, color: scheme.onSecondaryContainer),
        label: 'Entfernung',
        value: distance == null ? null : '${_formatWeight(distance)} km',
        onTap: () => onEdit(exerciseId: exerciseId, field: 'distance', current: distance),
      ));
    }
    if (ex == null || ex.trackDuration) {
      final duration = _asInt(values['duration']);
      chips.add(_MetricChip(
        icon: Icon(Icons.timer_outlined, size: 18, color: scheme.onSecondaryContainer),
        label: 'Dauer',
        value: duration == null ? null : DurationFormatter.verbose(duration),
        onTap: () => onEdit(exerciseId: exerciseId, field: 'duration', current: duration),
      ));
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel
            Row(children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ImageIcon(const AssetImage('assets/icons/hantel.png'),
                    color: scheme.onPrimaryContainer, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                exerciseName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              )),
            ]),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: chips),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatWeight(double w) =>
      w.truncateToDouble() == w ? w.toStringAsFixed(0) : w.toStringAsFixed(1);

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.toInt();
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Metric-Chip (wiederverwendbar für Single-Modus)
// ---------------------------------------------------------------------------

class _MetricChip extends StatelessWidget {
  final Widget icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                hasValue ? '$label: $value' : '$label hinzufügen',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
