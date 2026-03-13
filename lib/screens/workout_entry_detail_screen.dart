import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _results = {
      for (final e in widget.entry.results.entries)
        e.key: Map<String, dynamic>.from(e.value),
    };
  }

  Future<void> _editMetric({
    required int exerciseId,
    required String field,
    required num? current,
  }) async {
    final isInt = field == 'sets' || field == 'reps' || field == 'duration';
    final controller = TextEditingController(
      text: current == null ? '' : '$current',
    );

    final newValue = await showDialog<num?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: Icon(_iconForField(field),
              size: 28, color: Theme.of(ctx).colorScheme.primary),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          actions: [
            OutlinedButton(
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
                  final p = int.tryParse(txt);
                  if (p != null) parsed = p;
                } else {
                  final p = double.tryParse(txt);
                  if (p != null) parsed = p;
                }
                Navigator.of(ctx).pop(parsed);
              },
              child: const Icon(Icons.check_rounded),
            ),
          ],
        );
      },
    );

    if (newValue == null) return;

    await WorkoutEntryDatabase.instance.updateMetric(
      workoutId: widget.entry.workoutId,
      exerciseId: exerciseId,
      timestamp: widget.entry.date.millisecondsSinceEpoch,
      field: field,
      value: newValue,
    );

    await context.read<ProgressProvider>().refreshEntries();

    setState(() {
      final m = _results[exerciseId] ?? <String, dynamic>{};
      m[field] = newValue;
      _results[exerciseId] = m;
    });

    try {
      if (mounted) context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  IconData _iconForField(String field) {
    switch (field) {
      case 'sets':
        return Icons.layers_rounded;
      case 'reps':
        return Icons.repeat_rounded;
      case 'weight':
        return Icons.fitness_center_rounded;
      case 'duration':
        return Icons.timer_outlined;
      default:
        return Icons.edit_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final scheme = Theme.of(context).colorScheme;
    final date = widget.entry.date;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: scheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(
              '${date.day.toString().padLeft(2, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.year}',
            ),
            const SizedBox(width: 10),
            Icon(Icons.access_time_rounded,
                size: 16, color: scheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(
              '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemBuilder: (ctx, index) {
          final exerciseId = _results.keys.elementAt(index);
          final data = _results[exerciseId] ?? const {};
          Exercise? ex;
          try {
            ex = exercises.firstWhere((e) => e.id == exerciseId);
          } catch (_) {
            ex = null;
          }

          return _ExerciseResultCard(
            exerciseId: exerciseId,
            exerciseName: ex?.name ?? '#$exerciseId',
            values: data,
            onEdit: _editMetric,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: _results.length,
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  final int exerciseId;
  final String exerciseName;
  final Map<String, dynamic> values;
  final Future<void> Function({
    required int exerciseId,
    required String field,
    required num? current,
  }) onEdit;

  const _ExerciseResultCard({
    required this.exerciseId,
    required this.exerciseName,
    required this.values,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sets = _asInt(values['sets']);
    final reps = _asInt(values['reps']);
    final weight = _asDouble(values['weight']);
    final duration = _asInt(values['duration']);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exerciseName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (sets != null)
                  _MetricPill(
                    icon: Icons.layers_rounded,
                    value: '$sets',
                    scheme: scheme,
                    onTap: () => onEdit(
                        exerciseId: exerciseId,
                        field: 'sets',
                        current: sets),
                  ),
                if (reps != null)
                  _MetricPill(
                    icon: Icons.repeat_rounded,
                    value: '$reps',
                    scheme: scheme,
                    onTap: () => onEdit(
                        exerciseId: exerciseId,
                        field: 'reps',
                        current: reps),
                  ),
                if (weight != null)
                  _MetricPill(
                    icon: Icons.fitness_center_rounded,
                    value: _formatWeight(weight),
                    scheme: scheme,
                    onTap: () => onEdit(
                        exerciseId: exerciseId,
                        field: 'weight',
                        current: weight),
                  ),
                if (duration != null)
                  _MetricPill(
                    icon: Icons.timer_outlined,
                    value: DurationFormatter.verbose(duration),
                    scheme: scheme,
                    onTap: () => onEdit(
                        exerciseId: exerciseId,
                        field: 'duration',
                        current: duration),
                  ),
              ],
            ),
            if (sets == null &&
                reps == null &&
                weight == null &&
                duration == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _RawValues(
                  values: values,
                  onEdit: (key, current) {
                    onEdit(
                      exerciseId: exerciseId,
                      field: key,
                      current: current,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatWeight(double w) {
    return w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1);
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
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _MetricPill({
    required this.icon,
    required this.value,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RawValues extends StatelessWidget {
  final Map<String, dynamic> values;
  final void Function(String field, num? current) onEdit;

  const _RawValues({required this.values, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final entries =
        values.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    final v = e.value;
                    num? current;
                    if (v is int) current = v;
                    if (v is double) current = v;
                    if (v is String) current = num.tryParse(v);
                    onEdit(e.key, current);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Text(
                      '${e.value}',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
