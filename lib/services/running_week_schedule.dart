import 'dart:math' as math;

/// Assign roles together. A conversational long run is not a second quality
/// session: proximity to leg training is a preference for it, a gate for speed.
class RunningWeekSchedule {
  const RunningWeekSchedule(this.qualityIndex, this.longIndex);
  final int qualityIndex, longIndex;

  static int gap(int a, int b) => math.min((a - b).abs(), 7 - (a - b).abs());

  static RunningWeekSchedule assign(
    List<int> days,
    Set<int> hardDays, {
    required double Function(int) budget,
  }) {
    if (days.isEmpty) throw const FormatException('No running days');
    var best = const RunningWeekSchedule(-1, 0);
    var bestScore = double.negativeInfinity;
    // Include a no-quality option only when no compatible placement exists.
    for (var q = -1; q < days.length; q++) {
      if (q >= 0 && hardDays.any((d) => gap(days[q], d) < 2)) continue;
      for (var l = 0; l < days.length; l++) {
        if (q >= 0 && days.length > 2 && gap(days[q], days[l]) < 2) continue;
        // With one/two runs, the second role rotates by week/goal.
        if (q >= 0 && days.length <= 2 && q != l) continue;
        final score =
            (q >= 0 ? 10000 : 0) +
            hardDays.fold<double>(0, (s, d) => s + gap(days[l], d) * 10) +
            math.min(budget(days[l]), 7200) / 7200 +
            days[l] / 100 +
            (q < 0 ? 0 : days[q] / 1000);
        if (score > bestScore) {
          bestScore = score;
          best = RunningWeekSchedule(q, l);
        }
      }
    }
    return best;
  }
}
