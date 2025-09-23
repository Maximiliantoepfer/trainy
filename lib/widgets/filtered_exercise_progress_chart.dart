// lib/widgets/filtered_exercise_progress_chart.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/workout_entry.dart';
import '../models/exercise.dart';

/// Zeigt den Verlauf (Reps/Gewicht/Dauer/Saetze) fuer eine ausgewaehlte Uebung.
/// Lightweight Line-Chart via CustomPainter (keine zusaetzlichen Packages).
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
          child: Text('Lege zuerst Uebungen an, um Fortschritt zu sehen.'),
        ),
      );
    }

    _selectedExerciseId ??= exercises.first.id;

    final series = _buildSeries(entries, _selectedExerciseId!, _metric);
    final unit = _unitForMetric(_metric);

    final selectedExercise = exercises.firstWhere(
      (ex) => ex.id == _selectedExerciseId,
      orElse: () => exercises.first,
    );
    final selectedExerciseName = selectedExercise.name;

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _section(
      context,
      title: 'Exercise-Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openExercisePicker(context, exercises),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Uebung',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedExerciseName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
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
                  label: 'Saetze',
                  active: _metric == 'sets',
                  onTap: () => setState(() => _metric = 'sets'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (series.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Noch keine Daten fuer diese Uebung.',
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.surfaceContainerHigh.withValues(alpha: 0.55),
                          scheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _LinePainter(
                        series: series,
                        lineColor: scheme.primary,
                        gridColor: scheme.outlineVariant,
                        textColor: scheme.onSurfaceVariant,
                        unit: unit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openExercisePicker(
    BuildContext context,
    List<Exercise> exercises,
  ) async {
    if (exercises.isEmpty) return;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    String query = '';

    if (!context.mounted) return;

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (stateContext, setModalState) {
            final media = MediaQuery.of(stateContext);
            final bottomInset = media.viewInsets.bottom;
            final heightFactor =
                bottomInset > 0
                    ? (1 - (bottomInset / media.size.height) - 0.08).clamp(
                      0.45,
                      0.88,
                    )
                    : 0.88;

            final search = query.trim().toLowerCase();
            final filtered =
                search.isEmpty
                    ? exercises
                    : exercises
                        .where((ex) => ex.name.toLowerCase().contains(search))
                        .toList();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uebung auswaehlen',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: 'Nach Uebung suchen',
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHigh
                                .withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged:
                              (value) => setModalState(() {
                                query = value;
                              }),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child:
                              filtered.isEmpty
                                  ? Center(
                                    child: Text(
                                      'Keine Treffer',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  )
                                  : ListView.separated(
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    itemCount: filtered.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (itemContext, index) {
                                      final exercise = filtered[index];
                                      final isSelected =
                                          exercise.id == _selectedExerciseId;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          FocusScope.of(stateContext).unfocus();
                                          Navigator.of(
                                            modalContext,
                                          ).pop(exercise.id);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            color:
                                                isSelected
                                                    ? theme.colorScheme.primary
                                                        .withValues(alpha: 0.14)
                                                    : theme
                                                        .colorScheme
                                                        .surfaceContainerHigh
                                                        .withValues(alpha: 0.5),
                                            border: Border.all(
                                              color:
                                                  isSelected
                                                      ? theme
                                                          .colorScheme
                                                          .primary
                                                      : theme
                                                          .colorScheme
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  exercise.name,
                                                  style: textTheme.titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            isSelected
                                                                ? FontWeight
                                                                    .w700
                                                                : FontWeight
                                                                    .w500,
                                                        color:
                                                            isSelected
                                                                ? theme
                                                                    .colorScheme
                                                                    .primary
                                                                : theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                      ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  Icons.check_rounded,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedId != null && selectedId != _selectedExerciseId) {
      if (!context.mounted) return;
      setState(() => _selectedExerciseId = selectedId);
    }
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
        return 'Saetze';
      default:
        return '';
    }
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.surfaceContainerHigh.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// --- UI: Metrik-Button mit modernem Look ---
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
    final baseStyle =
        Theme.of(context).textTheme.titleSmall ??
        Theme.of(context).textTheme.bodyMedium;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                active
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            border: Border.all(
              color:
                  active
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.7),
              width: active ? 1.4 : 1.0,
            ),
            boxShadow:
                active
                    ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
              Text(
                label,
                style: baseStyle?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Datenmodelle fuer den Painter ---
class _Point {
  final DateTime t;
  final double y;
  _Point(this.t, this.y);
}

class _AxisTick {
  _AxisTick({required this.value, required this.painter});

  final double value;
  final TextPainter painter;
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
    // nicht genutzt (wir zeichnen direkt ueber CustomPaint)
    return const SizedBox.shrink();
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.series,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.unit,
    this.tickCount = 6,
  });

  final List<_Point> series;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final String unit;
  final int tickCount;

  static const double _minLeftInset = 52;
  static const double _minRightInset = 20;
  static const double _topInset = 32;
  static const double _minBottomInset = 56;
  static const double _labelSpacing = 12;
  static const double _tickLength = 8;
  static const double _lineStrokeWidth = 2.6;
  static const double _pointRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) {
      return;
    }

    double leftInset = _minLeftInset;
    const double rightInset = _minRightInset;
    double bottomInset = _minBottomInset;
    const double topInset = _topInset;

    final baseLabelStyle = TextStyle(
      color: textColor,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.1,
    );

    final axisLabelStyle = baseLabelStyle;
    final axisSecondaryStyle = baseLabelStyle.copyWith(
      fontWeight: FontWeight.w500,
    );

    final minX = series.first.t.millisecondsSinceEpoch.toDouble();
    final maxX = series.last.t.millisecondsSinceEpoch.toDouble();
    final dx = maxX - minX;
    final safeDx = dx <= 0 ? 1.0 : dx;

    double minY = series.first.y;
    double maxY = series.first.y;
    for (final p in series) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    double range = maxY - minY;
    if (range == 0) {
      range = maxY.abs() > 1 ? maxY.abs() : 1.0;
    }
    final double padding = range * 0.08;
    minY -= padding;
    maxY += padding;
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    final ticks = _niceTicks(minY, maxY, tickCount);
    final yMin = ticks.first;
    final yMax = ticks.last;
    final yRange = (yMax - yMin).abs() < 1e-9 ? 1.0 : yMax - yMin;

    final yTickPainters = <_AxisTick>[];
    double maxYLabelWidth = 0;
    for (final value in ticks) {
      final painter = TextPainter(
        text: TextSpan(text: _formatNumber(value), style: axisLabelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > maxYLabelWidth) {
        maxYLabelWidth = painter.width;
      }
      yTickPainters.add(_AxisTick(value: value, painter: painter));
    }

    final requiredLeft = maxYLabelWidth + _tickLength + _labelSpacing + 4;
    if (requiredLeft > leftInset) {
      leftInset = requiredLeft;
    }

    double width = size.width - leftInset - rightInset;
    double height = size.height - topInset - bottomInset;
    if (width <= 0 || height <= 0) {
      return;
    }

    final startLabel = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(minX.toInt()),
    );
    final endLabel = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(maxX.toInt()),
    );

    final startTp = TextPainter(
      text: TextSpan(text: startLabel, style: axisSecondaryStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width * 0.5);

    final endTp = TextPainter(
      text: TextSpan(text: endLabel, style: axisSecondaryStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width * 0.5);

    final xLabelHeight =
        startTp.height > endTp.height ? startTp.height : endTp.height;
    final requiredBottom = xLabelHeight + _labelSpacing + _tickLength + 6;
    if (requiredBottom > bottomInset) {
      bottomInset = requiredBottom;
      height = size.height - topInset - bottomInset;
      if (height <= 0) {
        return;
      }
    }

    final chartRect = Rect.fromLTWH(leftInset, topInset, width, height);
    final chartRRect = RRect.fromRectAndRadius(
      chartRect,
      const Radius.circular(18),
    );

    final backgroundPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              lineColor.withValues(alpha: 0.06),
              gridColor.withValues(alpha: 0.02),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chartRect);
    canvas.drawRRect(chartRRect, backgroundPaint);

    final horizontalGridPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.25)
          ..strokeWidth = 1.0;

    final axisPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;

    for (final tick in yTickPainters) {
      final y = topInset + (1 - (tick.value - yMin) / yRange) * height;
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(leftInset + width, y),
        horizontalGridPaint,
      );
      canvas.drawLine(
        Offset(leftInset - _tickLength, y),
        Offset(leftInset, y),
        axisPaint,
      );
      tick.painter.paint(
        canvas,
        Offset(
          leftInset - _tickLength - _labelSpacing - tick.painter.width,
          y - tick.painter.height / 2,
        ),
      );
    }

    const verticalDivisions = 4;
    final verticalGridPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.18)
          ..strokeWidth = 1.0;

    for (int i = 1; i < verticalDivisions; i++) {
      final x = leftInset + width * i / verticalDivisions;
      canvas.drawLine(
        Offset(x, topInset),
        Offset(x, topInset + height),
        verticalGridPaint,
      );
    }

    canvas.drawLine(
      Offset(leftInset, topInset),
      Offset(leftInset, topInset + height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftInset, topInset + height),
      Offset(leftInset + width, topInset + height),
      axisPaint,
    );

    final linePath = Path();
    for (int i = 0; i < series.length; i++) {
      final p = series[i];
      final x =
          leftInset + ((p.t.millisecondsSinceEpoch - minX) / safeDx) * width;
      final y = topInset + (1 - ((p.y - yMin) / yRange)) * height;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final areaPath =
        Path.from(linePath)
          ..lineTo(leftInset + width, topInset + height)
          ..lineTo(leftInset, topInset + height)
          ..close();

    final areaPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              lineColor.withValues(alpha: 0.22),
              lineColor.withValues(alpha: 0.04),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chartRect);
    canvas.drawPath(areaPath, areaPaint);

    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _lineStrokeWidth
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
    canvas.drawPath(linePath, linePaint);

    final haloPaint =
        Paint()
          ..color = lineColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
    final dotPaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;

    for (final p in series) {
      final x =
          leftInset + ((p.t.millisecondsSinceEpoch - minX) / safeDx) * width;
      final y = topInset + (1 - ((p.y - yMin) / yRange)) * height;
      canvas.drawCircle(Offset(x, y), _pointRadius + 2, haloPaint);
      canvas.drawCircle(Offset(x, y), _pointRadius, dotPaint);
    }

    final xLabelDy = topInset + height + _labelSpacing;
    startTp.paint(canvas, Offset(leftInset - startTp.width * 0.1, xLabelDy));
    endTp.paint(canvas, Offset(leftInset + width - endTp.width, xLabelDy));

    if (unit.isNotEmpty) {
      final unitPainter = TextPainter(
        text: TextSpan(
          text: unit,
          style: axisLabelStyle.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      unitPainter.paint(
        canvas,
        Offset(leftInset, topInset - unitPainter.height - 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) {
    return old.series != series ||
        old.lineColor != lineColor ||
        old.gridColor != gridColor ||
        old.textColor != textColor ||
        old.unit != unit ||
        old.tickCount != tickCount;
  }

  List<double> _niceTicks(double min, double max, int desiredCount) {
    final targetCount = desiredCount < 2 ? 2 : desiredCount;
    double range = max - min;
    if (range == 0) {
      range = max.abs() > 1 ? max.abs() : 1.0;
    }
    final step = _niceNum(range / (targetCount - 1), true);
    final niceMin = (min / step).floor() * step;
    final niceMax = (max / step).ceil() * step;

    final ticks = <double>[];
    for (double v = niceMin; v <= niceMax + 0.5 * step; v += step) {
      ticks.add(double.parse(v.toStringAsFixed(6)));
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
      if (f < 1.5) {
        nf = 1;
      } else if (f < 3) {
        nf = 2;
      } else if (f < 7) {
        nf = 5;
      } else {
        nf = 10;
      }
    } else {
      if (f <= 1) {
        nf = 1;
      } else if (f <= 2) {
        nf = 2;
      } else if (f <= 5) {
        nf = 5;
      } else {
        nf = 10;
      }
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
    return _exp(e * ln10);
  }

  // Minimal-Implementierungen mit Approximation - ausreichend fuer Axis-Ticks
  static double _ln(double x) {
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
    double sum = 1.0, term = 1.0;
    for (int i = 1; i < 20; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }
}
