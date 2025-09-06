import 'package:flutter/material.dart';
import '../models/workout_entry.dart';

/// Ein leichter, dependency-freier Wochenbalken-Chart.
/// Zeigt Workouts je Tag der **aktuellen Woche** (Mo–So).
class WeeklyActivityChart extends StatelessWidget {
  final List<WorkoutEntry> entries;
  final String? title;
  final String? subtitle;
  final double height;

  const WeeklyActivityChart({
    super.key,
    required this.entries,
    this.title,
    this.subtitle,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final days = _currentWeekDays();
    final counts = List<int>.generate(7, (i) {
      final d = days[i];
      return entries.where((e) => DateUtils.isSameDay(e.date, d)).length;
    });
    final maxVal = (counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b))
        .clamp(0, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
          ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final barWidth =
                  (constraints.maxWidth - 6 * 10) / 7; // 10px spacing
              final maxBarHeight =
                  constraints.maxHeight - 28; // Platz für Labels

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final value = counts[i];
                  final h = maxVal == 0 ? 0.0 : (value / maxVal) * maxBarHeight;
                  final dowLabel = _weekdayShort(i); // 0..6 -> Mo..So

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 6 ? 0 : 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Wert (über dem Balken)
                          SizedBox(
                            height: 18,
                            child: FittedBox(
                              child: Text(
                                value.toString(),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                          // Balken
                          Container(
                            height: h,
                            width: barWidth,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Label (unter dem Balken)
                          Text(
                            dowLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Liefert die 7 Tage der aktuellen Woche (Mo..So) als DateOnly (Mitternacht).
  List<DateTime> _currentWeekDays() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final start = today.subtract(Duration(days: today.weekday - 1)); // Montag
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _weekdayShort(int indexFromMonday) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return labels[indexFromMonday];
  }
}
