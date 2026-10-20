import '../models/cardio.dart';

/// Conservative product categories, not a physiological diagnosis.
abstract final class RunningAssessment {
  static RunningLevel level(AthleteRunningProfile p) {
    if (p.returningAfterBreak ||
        p.level == RunningLevel.starting ||
        p.continuousMinutes < 30) {
      return RunningLevel.starting;
    }
    if (p.level == RunningLevel.experienced &&
        p.experienceMonths >= 24 &&
        p.weeklyMeters >= 60000 &&
        (p.recentRunsPerWeek ?? 0) >= 5 &&
        p.longestMeters >= 10000) {
      return RunningLevel.experienced;
    }
    if ([
          RunningLevel.intermediate,
          RunningLevel.experienced,
        ].contains(p.level) &&
        p.experienceMonths >= 6 &&
        p.weeklyMeters >= 20000 &&
        (p.recentRunsPerWeek ?? 0) >= 3 &&
        p.longestMeters >= 8000) {
      return RunningLevel.intermediate;
    }
    return RunningLevel.beginner;
  }
}
