// lib/widgets/filtered_exercise_progress_chart.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';
import '../models/workout_entry.dart';
import '../utils/goal_utils.dart';
import '../utils/utils.dart';
import 'chart_data_builder.dart';
import 'tap_scale.dart';

/// Zeigt den Verlauf (Reps/Gewicht/Dauer/Sätze/Volumen/Geschwindigkeit)
/// für eine ausgewählte Übung als Line-Chart mit Min/Max/Avg.
class FilteredExerciseProgressChart extends StatefulWidget {
  const FilteredExerciseProgressChart({super.key});

  @override
  State<FilteredExerciseProgressChart> createState() =>
      _FilteredExerciseProgressChartState();
}

class _FilteredExerciseProgressChartState
    extends State<FilteredExerciseProgressChart> {
  int? _selectedExerciseId;
  String _metric = 'reps';
  String _timeRange = 'Alle';
  int? _highlightedIndex;
  bool _didPickDefault = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProgressProvider>();
    final entries = provider.entries;
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
      _didPickDefault = false;
    }

    // Smart default: zuletzt trainierte Übung
    if (_selectedExerciseId == null || !_didPickDefault) {
      _selectedExerciseId = _pickDefaultExerciseId(exercises, entries);
      final ex = exercises.firstWhere((e) => e.id == _selectedExerciseId);
      _metric = defaultMetricForExercise(
        trackSets: ex.trackSets,
        trackReps: ex.trackReps,
        trackWeight: ex.trackWeight,
        trackDuration: ex.trackDuration,
        trackDistance: ex.trackDistance,
      );
      _didPickDefault = true;
    }

    final chartSeries = buildChartSeries(entries, _selectedExerciseId!, _metric, _timeRange);

    final selectedExercise = exercises.firstWhere(
      (ex) => ex.id == _selectedExerciseId,
      orElse: () => exercises.first,
    );

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Pin state
    final isPinned = provider.isPinned(_selectedExerciseId!, _metric);

    return _section(
      context,
      title: 'Exercise-Progress',
      trailing: TapScale(
        child: GestureDetector(
          onTap: () {
            if (isPinned) {
              final pc = provider.pinnedCharts.firstWhere(
                (p) => p.exerciseId == _selectedExerciseId && p.metric == _metric,
              );
              provider.unpinChart(pc.id);
            } else {
              provider.pinChart(_selectedExerciseId!, _metric);
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              key: ValueKey(isPinned),
              size: 20,
              color: isPinned ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Exercise Picker ---
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
                            selectedExercise.name,
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
          // --- Metric Selector (Kombimetriken zuerst) ---
          Builder(
            builder: (context) {
              final isCardio = isCardioExercise(
                trackDistance: selectedExercise.trackDistance,
                trackDuration: selectedExercise.trackDuration,
              );
              final isStrength = isStrengthExercise(
                trackSets: selectedExercise.trackSets,
                trackReps: selectedExercise.trackReps,
                trackWeight: selectedExercise.trackWeight,
              );

              final availableMetrics = <({String key, String label})>[
                // Kombimetriken zuerst
                if (isCardio) (key: 'speed', label: 'Geschw.'),
                if (isStrength) (key: 'volume', label: 'Volumen'),
                // Einzelmetriken
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

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in availableMetrics)
                    _MetricButton(
                      label: m.label,
                      active: _metric == m.key,
                      onTap: () => setState(() {
                        _metric = m.key;
                        _highlightedIndex = null;
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // --- Zeitbereich-Filter ---
          Row(
            children: [
              for (final range in const ['1M', '3M', '6M', '1J', 'Alle']) ...[
                if (range != '1M') const SizedBox(width: 6),
                _RangeButton(
                  label: range,
                  active: _timeRange == range,
                  onTap: () => setState(() {
                    _timeRange = range;
                    _highlightedIndex = null;
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // --- Chart ---
          if (chartSeries.avg.isEmpty)
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
                child: _buildChart(chartSeries, scheme),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(ChartSeries series, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;

        // Clamp highlighted index
        final safeHighlight = (_highlightedIndex != null &&
                _highlightedIndex! < series.avg.length)
            ? _highlightedIndex
            : null;

        return ClipRRect(
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
            child: GestureDetector(
              onTapUp: (d) {
                final idx = findNearestIndex(
                    d.localPosition, series.avg, chartWidth, 260);
                setState(() {
                  if (idx == _highlightedIndex) {
                    _highlightedIndex = null;
                  } else {
                    _highlightedIndex = idx;
                  }
                });
              },
              onLongPressStart: (d) {
                final idx = findNearestIndex(
                    d.localPosition, series.avg, chartWidth, 260);
                setState(() => _highlightedIndex = idx);
              },
              onLongPressMoveUpdate: (d) {
                final idx = findNearestIndex(
                    d.localPosition, series.avg, chartWidth, 260);
                setState(() => _highlightedIndex = idx);
              },
              onLongPressEnd: (_) {
                setState(() => _highlightedIndex = null);
              },
              child: CustomPaint(
                painter: ProgressLinePainter(
                  series: series.avg,
                  minPoints: series.min,
                  maxPoints: series.max,
                  highlightedIndex: safeHighlight,
                  metric: _metric,
                  lineColor: scheme.primary,
                  gridColor: scheme.outlineVariant,
                  textColor: scheme.onSurfaceVariant,
                  tooltipBgColor: scheme.surfaceContainerHighest,
                  tooltipTextColor: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _pickDefaultExerciseId(List<Exercise> exercises, List<WorkoutEntry> entries) {
    // Zuletzt trainierte Übung bevorzugen
    DateTime? latestDate;
    int? latestExId;
    for (final entry in entries) {
      for (final exId in entry.results.keys) {
        if (latestDate == null || entry.date.isAfter(latestDate)) {
          latestDate = entry.date;
          latestExId = exId;
        }
      }
    }
    if (latestExId != null && exercises.any((e) => e.id == latestExId)) {
      return latestExId;
    }
    return exercises.first.id;
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
                        .where((ex) => ex.name.toLowerCase().contains(search)
                            || ex.mergedAliases.any((a) => a.toLowerCase().contains(search)))
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
                                      final alias = matchingAlias(exercise, query);
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
                                                    if (alias != null) ...[
                                                      const SizedBox(height: 2),
                                                      Text('ehem. $alias',
                                                        style: textTheme.bodySmall?.copyWith(
                                                          fontStyle: FontStyle.italic,
                                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
      final ex = exercises.firstWhere((e) => e.id == selectedId);
      setState(() {
        _selectedExerciseId = selectedId;
        _metric = defaultMetricForExercise(
          trackSets: ex.trackSets,
          trackReps: ex.trackReps,
          trackWeight: ex.trackWeight,
          trackDuration: ex.trackDuration,
          trackDistance: ex.trackDistance,
        );
        _highlightedIndex = null;
      });
    }
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
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

// ── Touch Hit-Test (shared) ──────────────────────────────────────────────────

int? findNearestIndex(
    Offset touch, List<ChartPoint> points, double totalWidth, double totalHeight) {
  if (points.isEmpty) return null;

  const double minLeftInset = 40;
  const double rightInset = 20;
  const double topInset = 20;
  const double bottomInset = 40;
  final leftInset = max(minLeftInset, 50.0);
  final chartW = totalWidth - leftInset - rightInset;
  final chartH = totalHeight - topInset - bottomInset;
  if (chartW <= 0 || chartH <= 0) return null;

  final minX = points.first.t.millisecondsSinceEpoch.toDouble();
  final maxX = points.last.t.millisecondsSinceEpoch.toDouble();
  final dx = maxX - minX;
  final safeDx = dx <= 0 ? 1.0 : dx;

  double dataMaxY = 0;
  for (final p in points) {
    if (p.y > dataMaxY) dataMaxY = p.y;
  }
  final pad = dataMaxY * 0.10;
  final yMax = (dataMaxY + pad) <= 0 ? 1.0 : dataMaxY + pad;

  int? bestIdx;
  double bestDist = double.infinity;
  for (int i = 0; i < points.length; i++) {
    final p = points[i];
    final px =
        leftInset + ((p.t.millisecondsSinceEpoch - minX) / safeDx) * chartW;
    final py = topInset + (1 - (p.y / yMax)) * chartH;
    final distX = (px - touch.dx).abs();
    final distY = (py - touch.dy).abs();
    final dist = distX * 2.0 + distY;
    if (dist < bestDist) {
      bestDist = dist;
      bestIdx = i;
    }
  }
  return bestIdx;
}

// ── UI: Metrik-Button ────────────────────────────────────────────────────────

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

// ── UI: Zeitbereich-Button ───────────────────────────────────────────────────

class _RangeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RangeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.4),
          border: Border.all(
            color: active ? scheme.primary : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Line Painter (with Min/Max support) ──────────────────────────────────────

class ProgressLinePainter extends CustomPainter {
  ProgressLinePainter({
    required this.series,
    required this.highlightedIndex,
    required this.metric,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.tooltipBgColor,
    required this.tooltipTextColor,
    this.minPoints = const [],
    this.maxPoints = const [],
  });

  final List<ChartPoint> series; // avg points
  final List<ChartPoint>? minPoints;
  final List<ChartPoint>? maxPoints;
  final int? highlightedIndex;
  final String metric;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color tooltipBgColor;
  final Color tooltipTextColor;

  static const double _minLeftInset = 40;
  static const double _minRightInset = 20;
  static const double _topInset = 20;
  static const double _minBottomInset = 40;
  static const double _labelSpacing = 10;

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

    // --- Y-Bereich (including min/max points) ---
    double dataMaxY = 0;
    double dataMinY = double.infinity;
    for (final p in series) {
      if (p.y > dataMaxY) dataMaxY = p.y;
      if (p.y < dataMinY) dataMinY = p.y;
    }
    for (final p in (minPoints ?? <ChartPoint>[])) {
      if (p.y < dataMinY) dataMinY = p.y;
    }
    for (final p in (maxPoints ?? <ChartPoint>[])) {
      if (p.y > dataMaxY) dataMaxY = p.y;
    }

    double range = dataMaxY;
    if (range == 0) range = 1.0;
    final double pad = range * 0.10;

    const double yMin = 0;
    double yMax = dataMaxY + pad;
    if (yMax <= 0) yMax = 1;

    // --- Y-Ticks ---
    final step = _niceStep(yMax, 5);
    final tickValues = <double>[];
    for (double v = 0; v <= yMax + step * 0.01; v += step) {
      tickValues.add(double.parse(v.toStringAsFixed(6)));
    }
    if (tickValues.isNotEmpty && tickValues.last > yMax) {
      yMax = tickValues.last;
    }

    final yRange = (yMax - yMin).abs() < 1e-9 ? 1.0 : yMax - yMin;

    final yTickPainters = <AxisTick>[];
    double maxYLabelWidth = 0;

    for (final value in tickValues) {
      final painter = TextPainter(
        text: TextSpan(text: _formatYLabel(value), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (painter.width > maxYLabelWidth) {
        maxYLabelWidth = painter.width;
      }
      yTickPainters.add(AxisTick(value: value, painter: painter));
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

    // --- Y-Labels + Grid ---
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

    // --- Helper: map data point to pixel ---
    Offset toPixel(ChartPoint p) {
      final x =
          leftInset + ((p.t.millisecondsSinceEpoch - minX) / safeDx) * width;
      final y = topInset + (1 - ((p.y - yMin) / yRange)) * height;
      return Offset(x, y);
    }

    // --- Line + Area through avg points ---
    final pixelPoints = series.map(toPixel).toList();
    final linePath = Path();
    for (int i = 0; i < pixelPoints.length; i++) {
      final pt = pixelPoints[i];
      if (i == 0) {
        linePath.moveTo(pt.dx, pt.dy);
      } else {
        linePath.lineTo(pt.dx, pt.dy);
      }
    }

    // Gradient fill under the line
    final lastPx = pixelPoints.last;
    final firstPx = pixelPoints.first;
    final areaPath =
        Path.from(linePath)
          ..lineTo(lastPx.dx, topInset + height)
          ..lineTo(firstPx.dx, topInset + height)
          ..close();

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

    // Line stroke
    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
    canvas.drawPath(linePath, linePaint);

    // --- Min/Max dots (gray, smaller, behind avg dots) ---
    final minMaxDotPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill;
    final minMaxHaloPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;

    for (final p in (minPoints ?? <ChartPoint>[])) {
      final pt = toPixel(p);
      canvas.drawCircle(pt, 3.0 + 2.0, minMaxHaloPaint);
      canvas.drawCircle(pt, 3.0, minMaxDotPaint);
    }
    for (final p in (maxPoints ?? <ChartPoint>[])) {
      final pt = toPixel(p);
      canvas.drawCircle(pt, 3.0 + 2.0, minMaxHaloPaint);
      canvas.drawCircle(pt, 3.0, minMaxDotPaint);
    }

    // --- Avg dots ---
    final haloPaint =
        Paint()
          ..color = lineColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
    final dotPaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;

    for (int i = 0; i < pixelPoints.length; i++) {
      if (i == highlightedIndex) continue;
      final pt = pixelPoints[i];
      canvas.drawCircle(pt, 5.0 + 2.5, haloPaint);
      canvas.drawCircle(pt, 5.0, dotPaint);
    }

    // --- Highlight + Tooltip ---
    if (highlightedIndex != null && highlightedIndex! < pixelPoints.length) {
      final hp = pixelPoints[highlightedIndex!];
      final hPoint = series[highlightedIndex!];

      // Vertical indicator line
      canvas.drawLine(
        Offset(hp.dx, topInset),
        Offset(hp.dx, topInset + height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.25)
          ..strokeWidth = 1.0,
      );

      // Highlighted dot (larger, with glow)
      canvas.drawCircle(
        hp,
        10,
        Paint()
          ..color = lineColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(hp, 6, dotPaint);

      // Tooltip
      _drawTooltip(canvas, hp, hPoint, chartRect);
    }

    // --- X-Labels ---
    final xLabelDy = topInset + height + _labelSpacing;
    startTp.paint(canvas, Offset(leftInset, xLabelDy));
    endTp.paint(canvas, Offset(leftInset + width - endTp.width, xLabelDy));
  }

  void _drawTooltip(
      Canvas canvas, Offset pixelPos, ChartPoint point, Rect chartRect) {
    final lines = <String>[
      _formatDateFull(point.t),
      point.label ?? _formatYLabel(point.y),
    ];
    // Show min/max info if available
    if (point.yMin != null && point.yMax != null &&
        ((point.yMin! - point.y).abs() > 0.01 || (point.yMax! - point.y).abs() > 0.01)) {
      lines.add('Min ${formatLabel(point.yMin!, metric)} · Max ${formatLabel(point.yMax!, metric)}');
    }

    final tooltipStyle = TextStyle(
      color: tooltipTextColor,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    final painters = lines.map((line) {
      return TextPainter(
        text: TextSpan(text: line, style: tooltipStyle),
        textDirection: TextDirection.ltr,
      )..layout();
    }).toList();

    double maxW = 0;
    double totalH = 0;
    for (final tp in painters) {
      if (tp.width > maxW) maxW = tp.width;
      totalH += tp.height;
    }
    totalH += (painters.length - 1) * 2;

    const hPad = 12.0;
    const vPad = 8.0;
    final bubbleW = maxW + hPad * 2;
    final bubbleH = totalH + vPad * 2;

    double bx = pixelPos.dx - bubbleW / 2;
    double by = pixelPos.dy - bubbleH - 14;

    if (bx < chartRect.left + 4) bx = chartRect.left + 4;
    if (bx + bubbleW > chartRect.right - 4) {
      bx = chartRect.right - 4 - bubbleW;
    }
    if (by < chartRect.top + 4) {
      by = pixelPos.dy + 14;
    }

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bubbleW, bubbleH),
      const Radius.circular(10),
    );

    // Shadow
    canvas.drawRRect(
      bubbleRect.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x1A000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Background
    canvas.drawRRect(bubbleRect, Paint()..color = tooltipBgColor);

    // Border
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Text
    double textY = by + vPad;
    for (final tp in painters) {
      tp.paint(canvas, Offset(bx + hPad, textY));
      textY += tp.height + 2;
    }
  }

  @override
  bool shouldRepaint(covariant ProgressLinePainter old) {
    return old.series != series ||
        old.highlightedIndex != highlightedIndex ||
        old.lineColor != lineColor ||
        old.gridColor != gridColor ||
        old.textColor != textColor ||
        old.metric != metric ||
        old.minPoints != minPoints ||
        old.maxPoints != maxPoints;
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

  String _formatYLabel(double v) {
    // Metric-aware Y-axis labels with units
    switch (metric) {
      case 'weight':
        return v >= 1000
            ? '${(v / 1000).toStringAsFixed(1)}t'
            : '${_fmtNum(v)} kg';
      case 'volume':
        return v >= 1000
            ? '${(v / 1000).toStringAsFixed(1)}t'
            : '${_fmtNum(v)} kg';
      case 'speed':
        return '${_fmtNum(v)} km/h';
      case 'distance':
        return '${_fmtNum(v)} km';
      case 'duration':
        final total = v.round();
        if (total >= 3600) return '${total ~/ 3600}h';
        if (total >= 60) return '${total ~/ 60}m';
        return '${total}s';
      default:
        return _fmtNum(v);
    }
  }

  String _fmtNum(double v) {
    final iv = v.roundToDouble();
    if ((v - iv).abs() < 1e-6) return iv.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.';
  }

  String _formatDateFull(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }
}
