// lib/widgets/trainings_calendar.dart
import 'package:flutter/material.dart';
import '../models/workout_entry.dart';

/// Simpler Monatskalender mit Markierungen für Tage, an denen Workouts getrackt wurden.
/// Design-Update: Statt Zahl nun ein kräftiger, gefüllter grüner Haken.
/// Count bleibt für Semantics/Screenreader erhalten.
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

    final bigLabel = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final bigMuted = bigLabel.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

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
          children: [
            _WeekdayHead('Mo', style: bigMuted),
            _WeekdayHead('Di', style: bigMuted),
            _WeekdayHead('Mi', style: bigMuted),
            _WeekdayHead('Do', style: bigMuted),
            _WeekdayHead('Fr', style: bigMuted),
            _WeekdayHead('Sa', style: bigMuted),
            _WeekdayHead('So', style: bigMuted),
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
              child: Semantics(
                label:
                    cnt > 0
                        ? '${d.day}.: $cnt Workouts aufgezeichnet'
                        : '${d.day}.: keine Workouts',
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
                        child: Text('${d.day}', style: bigLabel),
                      ),
                      // Kräftiger, gefüllter Haken statt Zahl
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child:
                              cnt > 0
                                  ? const Center(
                                    key: ValueKey('done'),
                                    child: _DoneCheck(),
                                  )
                                  : const SizedBox.shrink(
                                    key: ValueKey('empty'),
                                  ),
                        ),
                      ),
                    ],
                  ),
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

    // Start am Montag der ersten Woche
    final start = DateTime(
      firstDay.year,
      firstDay.month,
      1,
    ).subtract(Duration(days: (firstWeekday - 1)));

    // Mindestens 42 Felder (6 Wochen) für sauberes Raster
    const totalCells = 42;
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
  final TextStyle style;
  const _WeekdayHead(this.label, {required this.style});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Center(child: Text(label, style: style)));
  }
}

/// Kräftiger „Done“-Badge: sattes Grün (vollflächig), weißer Haken, subtile Shadow.
/// Kein Durchscheinen mehr.
class _DoneCheck extends StatelessWidget {
  const _DoneCheck();

  @override
  Widget build(BuildContext context) {
    const Color fill = Color(0xFF2E7D32); // sattes Grün (Material Green 800)
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 180),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: fill, // vollflächig, nicht transparent
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x402E7D32), // 25% Alpha für sanfte Tiefe
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.check_rounded,
          size: 20,
          color: Colors.white, // maximaler Kontrast
        ),
      ),
    );
  }
}
