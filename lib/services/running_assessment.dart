import '../models/cardio.dart';
import 'running_rules.dart';

/// Conservative product categories, not a physiological diagnosis.
abstract final class RunningAssessment {
  static RunningLevel level(AthleteRunningProfile p) {
    final rules = RunningRules.bundled;
    if (p.continuousMinutes < rules.integer('continuousMinutes')) {
      return RunningLevel.starting;
    }
    if (p.level == RunningLevel.experienced &&
        p.experienceMonths >= rules.integer('experiencedMonths') &&
        p.planning.highLoadTolerated == true &&
        (p.weeklyMeters >= rules.number('experiencedWeeklyMeters') ||
            (p.planning.weeklyMinutes ?? 0) >=
                rules.number('experiencedWeeklyMinutes')) &&
        (p.recentRunsPerWeek ?? 0) >= rules.integer('experiencedRuns') &&
        (p.longestMeters >= rules.number('experiencedLongMeters') ||
            (p.planning.longestMinutes ?? 0) >=
                rules.number('experiencedLongMinutes'))) {
      return RunningLevel.experienced;
    }
    if ([
          RunningLevel.intermediate,
          RunningLevel.experienced,
        ].contains(p.level) &&
        p.experienceMonths >= rules.integer('advancedMonths') &&
        (p.weeklyMeters >= rules.number('advancedWeeklyMeters') ||
            (p.planning.weeklyMinutes ?? 0) >=
                rules.number('advancedWeeklyMinutes')) &&
        (p.recentRunsPerWeek ?? 0) >= rules.integer('advancedRuns') &&
        (p.longestMeters >= rules.number('advancedLongMeters') ||
            (p.planning.longestMinutes ?? 0) >=
                rules.number('advancedLongMinutes'))) {
      return RunningLevel.intermediate;
    }
    return RunningLevel.beginner;
  }
}
