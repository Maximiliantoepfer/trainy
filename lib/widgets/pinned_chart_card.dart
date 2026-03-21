import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pinned_chart.dart';
import '../models/exercise.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import 'chart_data_builder.dart';
import 'filtered_exercise_progress_chart.dart';
import 'tap_scale.dart';

/// Kompakter Mini-Chart für gepinnte oder empfohlene Übung+Metrik-Kombination.
class PinnedChartCard extends StatefulWidget {
  /// Gepinnter Chart (id vorhanden → Unpin möglich)
  final PinnedChart? pinnedChart;

  /// Empfehlungs-Modus (kein PinnedChart, automatisch ermittelt)
  final bool isRecommendation;
  final int? recommendedExerciseId;
  final String? recommendedMetric;

  const PinnedChartCard({
    super.key,
    this.pinnedChart,
    this.isRecommendation = false,
    this.recommendedExerciseId,
    this.recommendedMetric,
  });

  @override
  State<PinnedChartCard> createState() => _PinnedChartCardState();
}

class _PinnedChartCardState extends State<PinnedChartCard> {
  int? _highlightedIndex;

  int get _exerciseId =>
      widget.pinnedChart?.exerciseId ?? widget.recommendedExerciseId ?? 0;
  String get _metric =>
      widget.pinnedChart?.metric ?? widget.recommendedMetric ?? 'reps';

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ProgressProvider>().entries;
    final exercises = context.watch<ExerciseProvider>().exercises;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exercises.cast<Exercise?>().firstWhere(
      (ex) => ex!.id == _exerciseId,
      orElse: () => null,
    );
    if (exercise == null) return const SizedBox.shrink();

    final series = buildChartSeries(entries, _exerciseId, _metric, '6M');
    if (series.avg.isEmpty) return const SizedBox.shrink();

    final metricLabel = metricDisplayLabel(_metric);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.surfaceContainerHigh.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.isRecommendation) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: scheme.primary.withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  'Empfehlung',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                exercise.name,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metricLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Unpin / Pin button
                  if (widget.isRecommendation)
                    TapScale(
                      child: GestureDetector(
                        onTap: () {
                          context.read<ProgressProvider>().pinChart(
                            _exerciseId,
                            _metric,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: scheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.push_pin_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    TapScale(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.pinnedChart != null) {
                            context.read<ProgressProvider>().unpinChart(
                              widget.pinnedChart!.id,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Mini-Chart
              SizedBox(
                width: double.infinity,
                height: 120,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints.maxWidth;
                    const chartHeight = 120.0;

                    final safeHighlight = (_highlightedIndex != null &&
                            _highlightedIndex! < series.avg.length)
                        ? _highlightedIndex
                        : null;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GestureDetector(
                        onTapUp: (d) {
                          final idx = findNearestIndex(
                              d.localPosition, series.avg, chartWidth, chartHeight);
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
                              d.localPosition, series.avg, chartWidth, chartHeight);
                          setState(() => _highlightedIndex = idx);
                        },
                        onLongPressMoveUpdate: (d) {
                          final idx = findNearestIndex(
                              d.localPosition, series.avg, chartWidth, chartHeight);
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
