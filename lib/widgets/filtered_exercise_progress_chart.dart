// lib/widgets/filtered_exercise_progress_chart.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/workout_entry.dart';
import '../models/exercise.dart';
import '../utils/goal_utils.dart';
import 'tap_scale.dart';

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
    final allExercises = context.watch<ExerciseProvider>().exercises;

    // Nur Übungen anzeigen, die tatsächlich Daten haben
    final exerciseIdsWithData = <int>{};
    for (final entry in entries) {
      exerciseIdsWithData.addAll(entry.results.keys);
    }
    final exercises = allExercises
        .where((ex) => exerciseIdsWithData.contains(ex.id))
        .toList();

    if (allExercises.isEmpty) {
      return _section(
        context,
        title: 'Exercise-Progress',
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Lege zuerst Übungen an, um Fortschritt zu sehen.'),
        ),
      );
    }

    if (exercises.isEmpty) {
      return _section(
        context,
        title: 'Exercise-Progress',
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Absolviere ein Workout, um Fortschrittsdaten zu sehen.'),
        ),
      );
    }

    // Auswahl zurücksetzen falls gewählte Übung keine Daten mehr hat
    if (_selectedExerciseId != null &&
        !exerciseIdsWithData.contains(_selectedExerciseId)) {
      _selectedExerciseId = null;
    }
    _selectedExerciseId ??= exercises.first.id;

    final series = _buildSeries(entries, _selectedExerciseId!, _metric);

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
          TapScale(
            child: Material(
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
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                      child: ImageIcon(
                        const AssetImage('assets/icons/hantel.png'),
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
                            'Übung',
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
          ),
          const SizedBox(height: 18),
          Builder(
            builder: (context) {
              final availableMetrics = <({String key, String label})>[
                if (selectedExercise.trackReps) (key: 'reps', label: 'Wdh.'),
                if (selectedExercise.trackWeight) (key: 'weight', label: 'Gewicht'),
                if (selectedExercise.trackDistance) (key: 'distance', label: 'Entfernung'),
                if (selectedExercise.trackDuration) (key: 'duration', label: 'Dauer'),
                if (selectedExercise.trackSets) (key: 'sets', label: 'Sätze'),
              ];

              if (availableMetrics.isNotEmpty && !availableMetrics.any((m) => m.key == _metric)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _metric = availableMetrics.first.key);
                });
              }

              if (availableMetrics.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Keine Felder zum Tracken',
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < availableMetrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _MetricButton(
                      label: availableMetrics[i].label,
                      active: _metric == availableMetrics[i].key,
                      onTap: () => setState(() => _metric = availableMetrics[i].key),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          if (series.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Noch keine Daten für diese Übung.',
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
                          'Übung auswählen',
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
                            hintText: 'Nach Übung suchen',
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
                                      final tags = [
                                        if (exercise.trackReps) 'Wdh.',
                                        if (exercise.trackWeight) 'Gewicht',
                                        if (exercise.trackDistance) 'Entfernung',
                                        if (exercise.trackDuration) 'Dauer',
                                        if (exercise.trackSets) 'Sätze',
                                      ];
                                      return TapScale(
                                        child: InkWell(
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
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
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
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (exercise.goal != null) ...[
                                                          const SizedBox(width: 8),
                                                          goalBadge(exercise.goal!, theme.colorScheme),
                                                        ],
                                                      ],
                                                    ),
                                                    if (tags.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        tags.join(' · '),
                                                        style: textTheme.bodySmall?.copyWith(
                                                          color: isSelected
                                                              ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
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

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
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

    return TapScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      : Colors.transparent,
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

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.series,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<_Point> series;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  static const double _minLeftInset = 40;
  static const double _minRightInset = 20;
  static const double _topInset = 20;
  static const double _minBottomInset = 40;
  static const double _labelSpacing = 10;
  static const double _lineStrokeWidth = 3.2;
  static const double _pointRadius = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    double leftInset = _minLeftInset;
    const double rightInset = _minRightInset;
    double bottomInset = _minBottomInset;
    const double topInset = _topInset;

    final labelStyle = TextStyle(
      color: textColor.withValues(alpha: 0.5),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.1,
    );

    // --- X-Bereich ---
    final minX = series.first.t.millisecondsSinceEpoch.toDouble();
    final maxX = series.last.t.millisecondsSinceEpoch.toDouble();
    final dx = maxX - minX;
    final safeDx = dx <= 0 ? 1.0 : dx;

    // --- Y-Bereich ---
    double dataMinY = series.first.y;
    double dataMaxY = series.first.y;
    for (final p in series) {
      if (p.y < dataMinY) dataMinY = p.y;
      if (p.y > dataMaxY) dataMaxY = p.y;
    }

    double range = dataMaxY - dataMinY;
    if (range == 0) {
      range = dataMaxY.abs() > 1 ? dataMaxY.abs() : 1.0;
    }
    final double pad = range * 0.10;

    double yMin = 0;
    double yMax = dataMaxY + pad;

    if (yMax <= 0) yMax = 1;

    // --- Y-Ticks: gleichmäßig von 0 bis yMax ---
    final step = _niceStep(yMax, 5);
    final tickValues = <double>[];
    for (double v = 0; v <= yMax + step * 0.01; v += step) {
      tickValues.add(double.parse(v.toStringAsFixed(6)));
    }
    // yMax auf letzten Tick anpassen
    if (tickValues.isNotEmpty && tickValues.last > yMax) {
      yMax = tickValues.last;
    }

    final yRange = (yMax - yMin).abs() < 1e-9 ? 1.0 : yMax - yMin;

    final yTickPainters = <_AxisTick>[];
    double maxYLabelWidth = 0;

    for (final value in tickValues) {
      final painter = TextPainter(
        text: TextSpan(text: _formatNumber(value), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > maxYLabelWidth) {
        maxYLabelWidth = painter.width;
      }
      yTickPainters.add(_AxisTick(value: value, painter: painter));
    }

    final requiredLeft = maxYLabelWidth + _labelSpacing + 4;
    if (requiredLeft > leftInset) leftInset = requiredLeft;

    double width = size.width - leftInset - rightInset;
    double height = size.height - topInset - bottomInset;
    if (width <= 0 || height <= 0) return;

    // --- X-Labels ---
    final startLabel = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(minX.toInt()),
    );
    final endLabel = _formatDate(
      DateTime.fromMillisecondsSinceEpoch(maxX.toInt()),
    );

    final startTp = TextPainter(
      text: TextSpan(text: startLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width * 0.5);

    final endTp = TextPainter(
      text: TextSpan(text: endLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width * 0.5);

    final xLabelHeight =
        startTp.height > endTp.height ? startTp.height : endTp.height;
    final requiredBottom = xLabelHeight + _labelSpacing + 6;
    if (requiredBottom > bottomInset) {
      bottomInset = requiredBottom;
      height = size.height - topInset - bottomInset;
      if (height <= 0) return;
    }

    final chartRect = Rect.fromLTWH(leftInset, topInset, width, height);

    // --- Hintergrund ---
    final backgroundPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              lineColor.withValues(alpha: 0.04),
              gridColor.withValues(alpha: 0.01),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chartRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(18)),
      backgroundPaint,
    );

    // --- Y-Labels (nur an Datenpunktwerten, ohne Overlap) ---
    const minPixelGap = 28.0;
    double? lastLabelPixelY;
    for (final tick in yTickPainters) {
      final y = topInset + (1 - (tick.value - yMin) / yRange) * height;
      if (y < topInset || y > topInset + height) continue;
      if (lastLabelPixelY != null &&
          (lastLabelPixelY - y).abs() < minPixelGap) {
        continue;
      }
      lastLabelPixelY = y;

      // Subtile horizontale Hilfslinie
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(leftInset + width, y),
        Paint()
          ..color = gridColor.withValues(alpha: 0.08)
          ..strokeWidth = 0.5,
      );

      tick.painter.paint(
        canvas,
        Offset(
          leftInset - _labelSpacing - tick.painter.width,
          y - tick.painter.height / 2,
        ),
      );
    }

    // --- Datenlinie zeichnen ---
    final linePath = Path();
    final pixelPoints = <Offset>[];
    for (int i = 0; i < series.length; i++) {
      final p = series[i];
      final x =
          leftInset + ((p.t.millisecondsSinceEpoch - minX) / safeDx) * width;
      final y = topInset + (1 - ((p.y - yMin) / yRange)) * height;
      pixelPoints.add(Offset(x, y));
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    // --- Fläche mit Gradient relativ zur Datenlinie ---
    final lastPx = pixelPoints.last;
    final firstPx = pixelPoints.first;
    final areaPath =
        Path.from(linePath)
          ..lineTo(lastPx.dx, topInset + height)
          ..lineTo(firstPx.dx, topInset + height)
          ..close();

    // Gradient von höchstem Datenpunkt bis X-Achse
    double dataMinPixelY = topInset + height;
    for (final pt in pixelPoints) {
      if (pt.dy < dataMinPixelY) dataMinPixelY = pt.dy;
    }
    final dataRect = Rect.fromLTRB(
      leftInset,
      dataMinPixelY,
      leftInset + width,
      topInset + height,
    );

    final areaPaint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              lineColor.withValues(alpha: 0.30),
              lineColor.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(dataRect);
    canvas.drawPath(areaPath, areaPaint);

    // --- Linie ---
    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _lineStrokeWidth
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
    canvas.drawPath(linePath, linePaint);

    // --- Datenpunkte ---
    final haloPaint =
        Paint()
          ..color = lineColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
    final dotPaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;

    for (final pt in pixelPoints) {
      canvas.drawCircle(pt, _pointRadius + 2.5, haloPaint);
      canvas.drawCircle(pt, _pointRadius, dotPaint);
    }

    // --- X-Labels ---
    final xLabelDy = topInset + height + _labelSpacing;
    startTp.paint(canvas, Offset(leftInset, xLabelDy));
    endTp.paint(canvas, Offset(leftInset + width - endTp.width, xLabelDy));
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) {
    return old.series != series ||
        old.lineColor != lineColor ||
        old.gridColor != gridColor ||
        old.textColor != textColor;
  }

  double _niceStep(double maxVal, int desiredTicks) {
    if (maxVal <= 0) return 1;
    final rawStep = maxVal / (desiredTicks - 1);
    final magnitude = pow(10, (log(rawStep) / ln10).floor().toDouble());
    final residual = rawStep / magnitude;
    double niceRes;
    if (residual <= 1.5) {
      niceRes = 1;
    } else if (residual <= 3.5) {
      niceRes = 2;
    } else if (residual <= 7.5) {
      niceRes = 5;
    } else {
      niceRes = 10;
    }
    return niceRes * magnitude;
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
