import 'package:flutter_test/flutter_test.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/running_week_schedule.dart';
import 'support/confirmed_profiles.dart';

void main() {
  test('quality gets the only suitable day beside Friday leg training', () {
    final days = [2, 4, 6];
    final assignment = RunningWeekSchedule.assign(days, {
      5,
    }, budget: (_) => 3000);
    expect(days[assignment.qualityIndex], 2);
    expect(days[assignment.longIndex], 6);
    final p = confirmedRunner({'weekdays': days});
    final result = RunningPlanGenerator().generate(
      p,
      RunningPlanRequest(
        targetMeters: 5000,
        startDate: DateTime(2030, 1, 7),
        hardTrainingDays: [5],
      ),
      (key) => key,
    );
    for (var week = 0; week < 3; week++) {
      final workouts = result.occurrences.skip(week * 3).take(3).toList();
      expect(
        workouts.first.workout.templateCode,
        ['progression', 'fartlek', 'intervalSession'][week],
      );
      expect(workouts.last.workout.templateCode, 'longRun');
    }
    expect(result.warnings, isNot(contains('qualityScheduleConflict')));
  });
  test('cyclic spacing and impossible availability are explicit', () {
    expect(RunningWeekSchedule.gap(7, 1), 1);
    final result = RunningPlanGenerator().generate(
      confirmedRunner({
        'weekdays': [1, 3, 5],
      }),
      RunningPlanRequest(
        targetMeters: 5000,
        startDate: DateTime(2030, 1, 7),
        hardTrainingDays: [2, 4, 6],
      ),
      (key) => key,
    );
    expect(result.warnings, contains('qualityScheduleConflict'));
    expect(
      result.occurrences.every((o) => [1, 3, 5].contains(o.date.weekday)),
      isTrue,
    );
  });
  test('all day subsets: never consume a feasible quality/long pairing', () {
    for (var mask = 1; mask < 128; mask++) {
      final days = [
        for (var d = 1; d <= 7; d++)
          if (mask & (1 << (d - 1)) != 0) d,
      ];
      for (var hard = 1; hard <= 7; hard++) {
        final feasible = days.any(
          (q) =>
              RunningWeekSchedule.gap(q, hard) >= 2 &&
              (days.length <= 2 ||
                  days.any((l) => RunningWeekSchedule.gap(q, l) >= 2)),
        );
        final result = RunningWeekSchedule.assign(days, {
          hard,
        }, budget: (_) => 3000);
        expect(result.qualityIndex >= 0, feasible, reason: '$days, hard=$hard');
      }
    }
  });
}
