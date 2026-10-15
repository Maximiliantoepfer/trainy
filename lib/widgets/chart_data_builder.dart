import 'dart:math';
import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../l10n/l10n.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

class ChartPoint {
  final DateTime t;
  final double y;
  final double? yMin; // nur bei avg-Points mit Varianz
  final double? yMax;

  const ChartPoint(this.t, this.y, {this.yMin, this.yMax});
}

class AxisTick {
  AxisTick({required this.value, required this.painter});

  final double value;
  final TextPainter painter;
}

// ── Chart Series Result ──────────────────────────────────────────────────────

typedef ChartSeries =
    ({List<ChartPoint> avg, List<ChartPoint> min, List<ChartPoint> max});

// ── Metric Detection Helpers ─────────────────────────────────────────────────

bool isCardioExercise({
  required bool trackDistance,
  required bool trackDuration,
}) => trackDistance && trackDuration;

bool isStrengthExercise({
  required bool trackSets,
  required bool trackReps,
  required bool trackWeight,
}) => trackSets && trackReps && trackWeight;

/// Returns the best default metric key for an exercise.
String defaultMetricForExercise({
  required bool trackSets,
  required bool trackReps,
  required bool trackWeight,
  required bool trackDuration,
  required bool trackDistance,
}) {
  if (isCardioExercise(
    trackDistance: trackDistance,
    trackDuration: trackDuration,
  )) {
    return 'speed';
  }
  if (isStrengthExercise(
    trackSets: trackSets,
    trackReps: trackReps,
    trackWeight: trackWeight,
  )) {
    return 'volume';
  }
  if (trackReps) return 'reps';
  if (trackWeight) return 'weight';
  if (trackDistance) return 'distance';
  if (trackDuration) return 'duration';
  if (trackSets) return 'sets';
  return 'reps';
}

// ── Series Builder ───────────────────────────────────────────────────────────

/// Builds avg/min/max chart series for a given exercise and metric.
ChartSeries buildChartSeries(
  List<WorkoutEntry> entries,
  int exerciseId,
  String metric,
  String timeRange,
) {
  final now = DateTime.now();
  final cutoff = switch (timeRange) {
    '1M' => DateTime(now.year, now.month - 1, now.day),
    '3M' => DateTime(now.year, now.month - 3, now.day),
    '6M' => DateTime(now.year, now.month - 6, now.day),
    '1Y' => DateTime(now.year - 1, now.month, now.day),
    _ => null,
  };

  final avgPoints = <ChartPoint>[];
  final minPoints = <ChartPoint>[];
  final maxPoints = <ChartPoint>[];

  for (final e in entries) {
    if (cutoff != null && e.date.isBefore(cutoff)) continue;

    final m = e.results[exerciseId];
    if (m == null) continue;

    if (metric == 'volume') {
      final v = _computeVolume(m);
      if (v != null && v > 0) {
        avgPoints.add(ChartPoint(e.date, v));
      }
    } else if (metric == 'speed') {
      final v = _computeSpeed(m);
      if (v != null && v > 0) {
        avgPoints.add(ChartPoint(e.date, v));
      }
    } else {
      // Individual metric: extract per-set values for min/max/avg
      _addMetricPoints(m, metric, e.date, avgPoints, minPoints, maxPoints);
    }
  }

  avgPoints.sort((a, b) => a.t.compareTo(b.t));
  minPoints.sort((a, b) => a.t.compareTo(b.t));
  maxPoints.sort((a, b) => a.t.compareTo(b.t));

  return (avg: avgPoints, min: minPoints, max: maxPoints);
}

// ── Computed Metrics ─────────────────────────────────────────────────────────

/// Volumen = Σ(reps × weight) pro Set
double? _computeVolume(Map<String, dynamic> m) {
  final perSet = m['perSet'];
  if (perSet is List && perSet.isNotEmpty) {
    double total = 0;
    for (final setMap in perSet) {
      if (setMap is! Map) continue;
      final reps = _toDouble(setMap['reps']);
      final weight = _toDouble(setMap['weight']);
      if (reps != null && weight != null) {
        total += reps * weight;
      }
    }
    return total > 0 ? total : null;
  }
  // Fallback: top-level aggregate
  final sets = _toDouble(m['sets']);
  final reps = _toDouble(m['reps']);
  final weight = _toDouble(m['weight']);
  if (sets != null && reps != null && weight != null) {
    return sets * reps * weight;
  }
  return null;
}

/// Geschwindigkeit = distance / (duration / 3600) → km/h
double? _computeSpeed(Map<String, dynamic> m) {
  final distance = _toDouble(m['distance']);
  final duration = _toDouble(m['duration']);
  if (distance != null && duration != null && duration > 0) {
    return distance / (duration / 3600);
  }
  return null;
}

// ── Per-Metric Point Extraction ──────────────────────────────────────────────

void _addMetricPoints(
  Map<String, dynamic> m,
  String metric,
  DateTime date,
  List<ChartPoint> avgOut,
  List<ChartPoint> minOut,
  List<ChartPoint> maxOut,
) {
  final perSet = m['perSet'];

  if (metric != 'sets' && perSet is List && perSet.isNotEmpty) {
    final values = <double>[];
    for (final setMap in perSet) {
      if (setMap is! Map) continue;
      final v = _toDouble(setMap[metric]);
      if (v != null) values.add(v);
    }

    if (values.isNotEmpty) {
      final avg = values.reduce((a, b) => a + b) / values.length;
      final vMin = values.reduce(min);
      final vMax = values.reduce(max);

      avgOut.add(ChartPoint(date, avg, yMin: vMin, yMax: vMax));

      // Only add min/max points if there's variance
      if ((vMin - avg).abs() > 0.01 || (vMax - avg).abs() > 0.01) {
        minOut.add(ChartPoint(date, vMin));
        maxOut.add(ChartPoint(date, vMax));
      }
      return;
    }
  }

  // Fallback: top-level value
  final v = _toDouble(m[metric]);
  if (v != null) {
    avgOut.add(ChartPoint(date, v));
  }
}

/// Returns a human-readable label for metric keys.
String metricDisplayLabel(BuildContext context, String metric) {
  return switch (metric) {
    'reps' => context.l10n.repetitions,
    'weight' => context.l10n.weight,
    'distance' => context.l10n.distance,
    'duration' => context.l10n.duration,
    'sets' => context.l10n.sets,
    'volume' => context.l10n.volume,
    'speed' => context.l10n.speed,
    _ => metric,
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
