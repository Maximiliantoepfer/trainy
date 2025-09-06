import 'package:flutter/material.dart';
import '../models/workout_entry.dart';

/// Simpler Monatskalender mit Markierungen für Tage, an denen Workouts getrackt wurden.
/// Keine Abhängigkeiten, stateful Navigation über Monate.
class TrainingsCalendar extends StatefulWidget {
  final List<WorkoutEntry> entries;
  const TrainingsCalendar({super.key, required this.entries});

  @override
  State<TrainingsCalendar> createState() => _TrainingsCalendarState();
}

class _TrainingsCalendarState extends State<TrainingsCalendar> {
  late DateTime _visibleMonthFirstDay; // jeweils der 1. des Monats

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonthFirstDay = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildMonthDays(_visibleMonthFirstDay);
    final activityMap = _activityByDay(widget.entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kopf mit Monat-Navigation
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _visibleMonthFirstDay = DateTime(
                    _visibleMonthFirstDay.year,
                    _visibleMonthFirstDay.month - 1,
                    1,
                  );
                });
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  _monthName(_visibleMonthFirstDay),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _visibleMonthFirstDay = DateTime(
                    _visibleMonthFirstDay.year,
                    _visibleMonthFirstDay.month + 1,
                    1,
                  );
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Wochentags-Header
        Row(
          children: const [
            _WeekdayHead('Mo'),
            _WeekdayHead('Di'),
            _WeekdayHead('Mi'),
            _WeekdayHead('Do'),
            _WeekdayHead('Fr'),
            _WeekdayHead('Sa'),
            _WeekdayHead('So'),
          ],
        ),
        const SizedBox(height: 8),
        // Grid
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (ctx, i) {
            final d = days[i];
            final isCurrentMonth = d.month == _visibleMonthFirstDay.month;
            final cnt = activityMap[_key(d)] ?? 0;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isCurrentMonth ? 1.0 : 0.4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 6,
                      child: Text(
                        '${d.day}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    if (cnt > 0)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$cnt',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<DateTime> _buildMonthDays(DateTime firstDay) {
    final firstWeekday =
        DateTime(firstDay.year, firstDay.month, 1).weekday; // 1=Mo..7=So
    final daysInMonth = DateUtils.getDaysInMonth(firstDay.year, firstDay.month);

    // Start am Montag der ersten Woche
    final start = DateTime(
      firstDay.year,
      firstDay.month,
      1,
    ).subtract(Duration(days: (firstWeekday - 1)));

    // Mindestens 42 Felder (6 Wochen) für sauberes Raster
    final totalCells = 42;
    return List.generate(totalCells, (i) => DateUtils.addDaysToDate(start, i));
  }

  Map<String, int> _activityByDay(List<WorkoutEntry> entries) {
    final map = <String, int>{};
    for (final e in entries) {
      final key = _key(e.date);
      map.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    return map;
  }

  String _key(DateTime d) {
    final x = DateUtils.dateOnly(d);
    return '${x.year}-${x.month}-${x.day}';
    // (einfacher String-Key für Map)
  }

  String _monthName(DateTime d) {
    const names = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }
}

class _WeekdayHead extends StatelessWidget {
  final String label;
  const _WeekdayHead(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
