// lib/screens/workout_entry_detail_screen.dart

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
  late Map<int, Map<String, dynamic>> _results; // lokale, editierbare Kopie

  @override
  void initState() {
    super.initState();
    // Deep copy der Map, damit wir lokal updaten können
    _results = {
      for (final e in widget.entry.results.entries)
        e.key: Map<String, dynamic>.from(e.value),
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editMetric({
    required int exerciseId,
    required String field, // 'sets' | 'reps' | 'weight' | 'duration'
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
                  final p = int.tryParse(txt);
                  if (p != null) parsed = p;
                } else {
                  final p = double.tryParse(txt);
                  if (p != null) parsed = p;
                }
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (newValue == null) return;

    // DB aktualisieren
    await WorkoutEntryDatabase.instance.updateMetric(
      workoutId: widget.entry.workoutId,
      exerciseId: exerciseId,
      timestamp: widget.entry.date.millisecondsSinceEpoch,
      field: field,
      value: newValue,
    );

    // Provider-List re-laden, damit Progress-Screen aktuell bleibt
    await context.read<ProgressProvider>().refreshEntries();

    // Lokalen Zustand updaten (UI direkt aktualisieren)
    setState(() {
      final m = _results[exerciseId] ?? <String, dynamic>{};
      m[field] = newValue;
      _results[exerciseId] = m;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wert aktualisiert')));
    }

    // Trigger a debounced cloud backup for this change
    try {
      if (mounted) context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  String _dialogTitleFor(String field) {
    switch (field) {
      case 'sets':
        return 'Sätze bearbeiten';
      case 'reps':
        return 'Wiederholungen bearbeiten';
      case 'weight':
        return 'Gewicht bearbeiten';
      case 'duration':
        return 'Dauer (Sek.) bearbeiten';
      default:
        return 'Wert bearbeiten';
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;

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
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
            exerciseName: ex?.name ?? 'Übung #$exerciseId',
            values: data,
            onEdit: _editMetric,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
  })
  onEdit;

  const _ExerciseResultCard({
    required this.exerciseId,
    required this.exerciseName,
    required this.values,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final sets = _asInt(values['sets']);
    final reps = _asInt(values['reps']);
    final weight = _asDouble(values['weight']);
    final duration = _asInt(values['duration']);

    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel with leading icon
            Row(children: [
              Container(
                width: 40,
                height: 40,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )),
            ]),
            const SizedBox(height: 10),
            // Kennzahlen-Chips (klickbar)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  icon: Icon(Icons.layers, size: 18, color: scheme.onSecondaryContainer),
                  label: 'Sätze',
                  value: sets?.toString(),
                  onTap:
                      () => onEdit(
                        exerciseId: exerciseId,
                        field: 'sets',
                        current: sets,
                      ),
                ),
                _MetricChip(
                  icon: Icon(Icons.repeat, size: 18, color: scheme.onSecondaryContainer),
                  label: 'Wdh.',
                  value: reps?.toString(),
                  onTap:
                      () => onEdit(
                        exerciseId: exerciseId,
                        field: 'reps',
                        current: reps,
                      ),
                ),
                _MetricChip(
                  icon: ImageIcon(const AssetImage('assets/icons/hantel.png'), size: 18, color: scheme.onSecondaryContainer),
                  label: 'Gewicht',
                  value: weight == null ? null : _formatWeight(weight),
                  onTap:
                      () => onEdit(
                        exerciseId: exerciseId,
                        field: 'weight',
                        current: weight,
                      ),
                ),
                _MetricChip(
                  icon: Icon(Icons.timer_outlined, size: 18, color: scheme.onSecondaryContainer),
                  label: 'Dauer',
                  value:
                      duration == null
                          ? null
                          : DurationFormatter.verbose(duration),
                  onTap:
                      () => onEdit(
                        exerciseId: exerciseId,
                        field: 'duration',
                        current: duration,
                      ),
                ),
              ],
            ),
            // Per-Set-Aufschlüsselung (nur bei neuem Format)
            if (values.containsKey('perSet') && values['perSet'] is List) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _PerSetBreakdown(perSet: List<Map<String, dynamic>>.from(
                (values['perSet'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
              )),
            ],
            // Fallback: Wenn keine bekannten Felder, zeige Rohwerte (auch editierbar)
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
    final s = w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1);
    return s;
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

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(
          hasValue ? '$label: $value' : '$label hinzufügen',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );

    // (Ausschnitt) â€“ in _ValuePill.build() den Material-Container anpassen:
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      ),
    );
  }
}

class _PerSetBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> perSet;
  const _PerSetBreakdown({required this.perSet});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Einzelne Sätze',
          style: textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...perSet.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final parts = <String>[];
          if (s['reps'] != null) parts.add('${s['reps']} Wdh.');
          if (s['weight'] != null) parts.add('${_formatWeight(s['weight'])} kg');
          if (s['duration'] != null) {
            parts.add(DurationFormatter.verbose((s['duration'] as num).toInt()));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(parts.join(' / '), style: textTheme.bodyMedium),
            ]),
          );
        }),
      ],
    );
  }

  static String _formatWeight(dynamic w) {
    if (w is int) return '$w';
    if (w is double) {
      return w.truncateToDouble() == w ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
    }
    return '$w';
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
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      '${e.value}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
