import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/workout_entry.dart';
import '../models/exercise.dart';

/// Zeigt den Verlauf (Reps/Gewicht/Dauer/Sätze) für eine ausgewählte Übung.
/// Lightweight Line-Chart via CustomPainter (keine zusätzlichen Packages).
class FilteredExerciseProgressChart extends StatefulWidget {
  const FilteredExerciseProgressChart({super.key});

  @override
  State<FilteredExerciseProgressChart> createState() =>
      _FilteredExerciseProgressChartState();
}

class _FilteredExerciseProgressChartState
    extends State<FilteredExerciseProgressChart> {
  int? _selectedExerciseId;
  String _metric = 'reps'; // 'reps' | 'weight' | 'duration' | 'sets'

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ProgressProvider>().entries;
    final exercises = context.watch<ExerciseProvider>().exercises;

    if (exercises.isEmpty) {
      return _section(
        context,
        title: 'Exercise-Progress',
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Lege zuerst Übungen an, um Fortschritt zu sehen.'),
        ),
      );
    }

    _selectedExerciseId ??= exercises.first.id;

    final series = _buildSeries(entries, _selectedExerciseId!, _metric);

    return _section(
      context,
      title: 'Exercise-Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auswahlzeile
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Übungsauswahl (Dropdown)
              DropdownButton<int>(
                value: _selectedExerciseId,
                onChanged: (v) => setState(() => _selectedExerciseId = v),
                items: [
                  for (final ex in exercises)
                    DropdownMenuItem(
                      value: ex.id,
                      child: Text(ex.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              // Metrik-Buttons
              _MetricButton(
                label: 'Wdh.',
                active: _metric == 'reps',
                onTap: () => setState(() => _metric = 'reps'),
              ),
              _MetricButton(
                label: 'Gewicht',
                active: _metric == 'weight',
                onTap: () => setState(() => _metric = 'weight'),
              ),
              _MetricButton(
                label: 'Dauer',
                active: _metric == 'duration',
                onTap: () => setState(() => _metric = 'duration'),
              ),
              _MetricButton(
                label: 'Sätze',
                active: _metric == 'sets',
                onTap: () => setState(() => _metric = 'sets'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Chart / Fallback
          if (series.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Noch keine Daten für diese Übung.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            _LineChart(series: series),
        ],
      ),
    );
  }

  List<_Point> _buildSeries(
    List<WorkoutEntry> entries,
    int exerciseId,
    String metric,
  ) {
    final points = <_Point>[];
    for (final e in entries) {
      final m = e.results[exerciseId];
      if (m == null) continue;
      final v = m[metric];
      if (v == null) continue;
      double? d;
      if (v is num) d = v.toDouble();
      if (v is String) d = double.tryParse(v);
      if (d == null) continue;
      points.add(_Point(e.date, d));
    }
    points.sort((a, b) => a.t.compareTo(b.t));
    return points;
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MetricButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          active
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _Point {
  final DateTime t;
  final double y;
  _Point(this.t, this.y);
}

class _LineChart extends StatelessWidget {
  final List<_Point> series;
  const _LineChart({required this.series});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _LinePainter(series, Theme.of(context).colorScheme.primary),
        child: Container(),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<_Point> series;
  final Color color;
  _LinePainter(this.series, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) {
      // Punkt anzeigen
      final p =
          Paint()
            ..color = color
            ..style = PaintingStyle.fill;
      final dx = size.width / 2;
      final dy = size.height / 2;
      canvas.drawCircle(Offset(dx, dy), 3, p);
      return;
    }

    // X/Y-Ranges
    final minX = series.first.t.millisecondsSinceEpoch.toDouble();
    final maxX = series.last.t.millisecondsSinceEpoch.toDouble();
    double minY = series.first.y, maxY = series.first.y;
    for (final p in series) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    // Paddings
    const left = 8.0, right = 8.0, top = 10.0, bottom = 18.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final path = Path();
    for (int i = 0; i < series.length; i++) {
      final s = series[i];
      final x =
          left + ((s.t.millisecondsSinceEpoch - minX) / (maxX - minX)) * w;
      final y = top + (1 - ((s.y - minY) / (maxY - minY))) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..isAntiAlias = true;

    // Linie
    canvas.drawPath(path, paint);

    // Punkte
    final dot = Paint()..color = color;
    for (final s in series) {
      final x =
          left + ((s.t.millisecondsSinceEpoch - minX) / (maxX - minX)) * w;
      final y = top + (1 - ((s.y - minY) / (maxY - minY))) * h;
      canvas.drawCircle(Offset(x, y), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.color != color;
  }
}
