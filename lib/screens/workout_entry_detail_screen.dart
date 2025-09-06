// lib/screens/workout_entry_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_entry.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';

class WorkoutEntryDetailScreen extends StatelessWidget {
  final WorkoutEntry entry;

  const WorkoutEntryDetailScreen({super.key, required this.entry});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDurationSeconds(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
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
              _formatDate(entry.date),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemBuilder: (ctx, index) {
          final exerciseId = entry.results.keys.elementAt(index);
          final data = entry.results[exerciseId] ?? const {};
          Exercise? ex;
          try {
            ex = exercises.firstWhere((e) => e.id == exerciseId);
          } catch (_) {
            ex = null;
          }

          return _ExerciseResultCard(
            exerciseName: ex?.name ?? 'Übung #$exerciseId',
            values: data,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: entry.results.length,
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  final String exerciseName;
  final Map<String, dynamic> values;

  const _ExerciseResultCard({required this.exerciseName, required this.values});

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
            // Titel
            Text(
              exerciseName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // Kennzahlen-Chips (zeigen nur, was vorhanden ist)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (sets != null)
                  _MetricChip(
                    icon: Icons.layers,
                    label: 'Sätze',
                    value: '$sets',
                    color: scheme.primary,
                  ),
                if (reps != null)
                  _MetricChip(
                    icon: Icons.repeat,
                    label: 'Wdh.',
                    value: '$reps',
                    color: scheme.primary,
                  ),
                if (weight != null)
                  _MetricChip(
                    icon: Icons.fitness_center,
                    label: 'Gewicht',
                    value: _formatWeight(weight),
                    color: scheme.primary,
                  ),
                if (duration != null)
                  _MetricChip(
                    icon: Icons.timer_outlined,
                    label: 'Dauer',
                    value: _formatDuration(duration),
                    color: scheme.primary,
                  ),
              ],
            ),
            // Fallback: Wenn nichts angezeigt werden konnte, zeige Rohwerte
            if (sets == null &&
                reps == null &&
                weight == null &&
                duration == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _RawValues(values: values),
              ),
          ],
        ),
      ),
    );
  }

  String _formatWeight(double w) {
    // Einfache Formatierung, keine Einheitserkennung
    final s = w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1);
    return '$s';
  }

  String _formatDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
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
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: onColor),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RawValues extends StatelessWidget {
  final Map<String, dynamic> values;

  const _RawValues({required this.values});

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
                Text(
                  '${e.value}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
