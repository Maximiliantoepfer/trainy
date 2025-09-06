// lib/widgets/filtered_exercise_progress_chart.dart
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
    final unit = _unitForMetric(_metric);

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
            // Breite sicherstellen + zusätzlicher Abstand nach unten
            Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ), // Mindestabstandshalter
              child: SizedBox(
                width: double.infinity,
                height: 210, // etwas höher für größere Labels
                child: CustomPaint(
                  painter: _LinePainter(
                    series: series,
                    lineColor: Theme.of(context).colorScheme.primary,
                    gridColor: Theme.of(context).colorScheme.outlineVariant,
                    textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    unit: unit,
                  ),
                ),
              ),
            ),
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

  String _unitForMetric(String metric) {
    switch (metric) {
      case 'reps':
        return 'Wdh.';
      case 'weight':
        return 'Gewicht';
      case 'duration':
        return 'Sek.';
      case 'sets':
        return 'Sätze';
      default:
        return '';
    }
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

// (Ausschnitt) – ersetze die Klasse _MetricButton durch folgende Implementierung:

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
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceVariant, // neutral – unabhängig vom Status
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: active ? scheme.primary : scheme.onSurface,
            ),
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
  final String unit;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const _LineChart({
    super.key,
    required this.series,
    required this.unit,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // nicht genutzt (wir zeichnen direkt über CustomPaint)
    return const SizedBox.shrink();
  }
}

class _LinePainter extends CustomPainter {
  final List<_Point> series;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final String unit;

  _LinePainter({
    required this.series,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paddings für Achsen und Labels (links/bottom etwas größer für gut lesbare Labels)
    const left = 56.0, right = 12.0, top = 14.0, bottom = 40.0;

    // Early exit, falls Breite/Höhe zu klein sind
    if (size.width <= left + right + 1 || size.height <= top + bottom + 1) {
      return;
    }

    final w = size.width - left - right;
    final h = size.height - top - bottom;

    // Achsenrahmen
    final axisPaint =
        Paint()
          ..color = gridColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Datenbereich bestimmen
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

    // "schöne" Y-Ticks berechnen
    final ticks = _niceTicks(minY, maxY, 5);
    final yMin = ticks.first;
    final yMax = ticks.last;

    // **größere, fettere** Label-Styles
    final yLabelStyle = TextStyle(
      color: textColor,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    final xLabelStyle = yLabelStyle;

    // Grid + Y-Labels
    for (final t in ticks) {
      final y = top + (1 - (t - yMin) / (yMax - yMin)) * h;

      // horizontale Linie
      final gridPaint =
          Paint()
            ..color = gridColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);

      // Label
      final tp = TextPainter(
        text: TextSpan(text: _formatNumber(t), style: yLabelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: left - 8 > 0 ? left - 8 : 0);
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }

    // X-Achse: Start/Ende-Datum
    final dx = (maxX - minX);
    final safeDx = dx <= 0 ? 1.0 : dx;

    final startStr = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(minX.toInt()),
    );
    final endStr = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(maxX.toInt()),
    );

    final startTp = TextPainter(
      text: TextSpan(text: startStr, style: xLabelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: w / 2 > 0 ? w / 2 : 0);

    final endTp = TextPainter(
      text: TextSpan(text: endStr, style: xLabelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: w / 2 > 0 ? w / 2 : 0);

    // Achsenlinien
    canvas.drawLine(Offset(left, top), Offset(left, top + h), axisPaint); // Y
    canvas.drawLine(
      Offset(left, top + h),
      Offset(left + w, top + h),
      axisPaint,
    ); // X

    // X-Labels (etwas weiter nach unten für "Luft")
    startTp.paint(canvas, Offset(left, top + h + 6));
    endTp.paint(canvas, Offset(left + w - endTp.width, top + h + 6));

    // Unit oben links
    if (unit.isNotEmpty) {
      final unitTp = TextPainter(
        text: TextSpan(
          text: unit,
          style: yLabelStyle.copyWith(fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: w > 0 ? w : 0);
      unitTp.paint(canvas, Offset(left, 2));
    }

    // Datenpfad
    final path = Path();
    for (int i = 0; i < series.length; i++) {
      final s = series[i];
      final x =
          left + ((s.t.millisecondsSinceEpoch - minX) / safeDx) * w; // safeDiv
      final y = top + (1 - ((s.y - yMin) / (yMax - yMin))) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..isAntiAlias = true;

    canvas.drawPath(path, linePaint);

    // Punkte
    final dot = Paint()..color = lineColor;
    for (final s in series) {
      final x =
          left + ((s.t.millisecondsSinceEpoch - minX) / safeDx) * w; // safeDiv
      final y = top + (1 - ((s.y - yMin) / (yMax - yMin))) * h;
      canvas.drawCircle(Offset(x, y), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) {
    return old.series != series ||
        old.lineColor != lineColor ||
        old.gridColor != gridColor ||
        old.textColor != textColor ||
        old.unit != unit;
  }

  // --- Helpers ---

  List<double> _niceTicks(double min, double max, int targetCount) {
    // "nice numbers" scaling (1, 2, 5 * 10^n)
    final range = _niceNum(max - min, false);
    final step = _niceNum(range / (targetCount - 1), true);
    final niceMin = (min / step).floor() * step;
    final niceMax = (max / step).ceil() * step;

    final ticks = <double>[];
    for (double v = niceMin; v <= niceMax + 0.5 * step; v += step) {
      ticks.add(double.parse(v.toStringAsFixed(6))); // stabilisieren
    }
    if (ticks.length < 2) {
      return [min, max];
    }
    return ticks;
  }

  double _niceNum(double x, bool round) {
    final expv = (x == 0) ? 0 : (x.abs()).log10().floor();
    final f = x / MathPow.pow10(expv);
    double nf;
    if (round) {
      if (f < 1.5)
        nf = 1;
      else if (f < 3)
        nf = 2;
      else if (f < 7)
        nf = 5;
      else
        nf = 10;
    } else {
      if (f <= 1)
        nf = 1;
      else if (f <= 2)
        nf = 2;
      else if (f <= 5)
        nf = 5;
      else
        nf = 10;
    }
    return nf * MathPow.pow10(expv);
  }

  String _formatNumber(double v) {
    final iv = v.roundToDouble();
    if ((v - iv).abs() < 1e-6) return iv.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.';
  }
}

/// Nur log10 als Extension (keine eigene floor-Implementierung nötig!)
extension _DoubleLog on double {
  double log10() {
    // Fallback: ln(x)/ln(10)
    return (this <= 0) ? 0 : (MathPow.ln(this) / MathPow.ln10);
  }
}

class MathPow {
  static const double ln10 = 2.302585092994046;
  static double ln(double x) => _ln(x);

  static double pow10(int e) {
    // explizit List<double>, sonst wird es List<num> und bricht die Typen
    const List<double> pows = <double>[
      1e-12,
      1e-11,
      1e-10,
      1e-9,
      1e-8,
      1e-7,
      1e-6,
      1e-5,
      1e-4,
      1e-3,
      1e-2,
      1e-1,
      1.0,
      1e1,
      1e2,
      1e3,
      1e4,
      1e5,
      1e6,
      1e7,
      1e8,
      1e9,
      1e10,
      1e11,
      1e12,
    ];
    final idx = e + 12;
    if (idx >= 0 && idx < pows.length) return pows[idx];
    // Fallback für sehr große/kleine Exponenten
    return _exp(e * ln10);
  }

  // Minimal-Implementierungen mit Approximation – ausreichend für Axis-Ticks
  static double _ln(double x) {
    // einfache Approx via log identities
    int k = 0;
    while (x > 1.5) {
      x /= 2;
      k++;
    }
    while (x < 0.75 && x > 0) {
      x *= 2;
      k--;
    }
    final y = (x - 1) / (x + 1);
    final y2 = y * y;
    double s = 0;
    double term = y;
    for (int n = 1; n < 15; n += 2) {
      s += term / n;
      term *= y2;
    }
    return 2 * s + k * ln2;
  }

  static const double ln2 = 0.6931471805599453;

  static double _exp(double x) {
    // kurzer exp-Taylor
    double sum = 1.0, term = 1.0;
    for (int i = 1; i < 20; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }
}
