// lib/widgets/trainings_calendar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../models/workout_entry.dart';
import '../l10n/l10n.dart';
import '../utils/goal_utils.dart';

/// Simpler Monatskalender mit Markierungen für Tage, an denen Workouts getrackt wurden.
/// Design-Update: Statt Zahl nun ein kräftiger, gefüllter grüner Haken.
/// Count bleibt für Semantics/Screenreader erhalten.
class TrainingsCalendar extends StatefulWidget {
  final List<WorkoutEntry> entries;
  final List<Workout> plannedWorkouts;
  final ValueChanged<CalendarDaySummary>? onDayTap;

  const TrainingsCalendar({
    super.key,
    required this.entries,
    this.plannedWorkouts = const [],
    this.onDayTap,
  });

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
      fontSize: 13,
      fontWeight: FontWeight.w600,
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
              tooltip: context.l10n.previousMonth,
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
              tooltip: context.l10n.nextMonth,
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
            _WeekdayHead(context.l10n.monday, style: bigMuted),
            _WeekdayHead(context.l10n.tuesday, style: bigMuted),
            _WeekdayHead(context.l10n.wednesday, style: bigMuted),
            _WeekdayHead(context.l10n.thursday, style: bigMuted),
            _WeekdayHead(context.l10n.friday, style: bigMuted),
            _WeekdayHead(context.l10n.saturday, style: bigMuted),
            _WeekdayHead(context.l10n.sunday, style: bigMuted),
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
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (ctx, i) {
            final d = days[i];
            final isCurrentMonth = d.month == _visibleMonthFirstDay.month;
            final cnt = activityMap[_key(d)] ?? 0;
            final planned = _plannedForWeekday(d.weekday);
            final goalCode = prioritizedGoal(
              planned.expand((workout) => workout.goalCodes),
            );
            final summary = CalendarDaySummary(
              date: d,
              plannedWorkoutIds: planned
                  .map((workout) => workout.canonicalId)
                  .toList(growable: false),
              primaryGoal: goalCode == null
                  ? null
                  : WorkoutPrimaryGoal.fromCode(goalCode),
              completedCount: cnt,
            );
            final semantics = <String>[
              '${d.day}',
              context.l10n.workoutsRecordedOnDay(cnt),
              if (planned.isNotEmpty) context.l10n.plannedWorkouts,
            ].join(': ');

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isCurrentMonth ? 1.0 : 0.4,
              child: Semantics(
                button: widget.onDayTap != null,
                label: semantics,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onDayTap == null
                        ? null
                        : () => widget.onDayTap!(summary),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 8,
                            top: 6,
                            child: Text('${d.day}', style: bigLabel),
                          ),
                          Positioned.fill(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: cnt > 0
                                  ? const Center(
                                      key: ValueKey('done'),
                                      child: _DoneCheck(),
                                    )
                                  : summary.primaryGoal == null
                                  ? const SizedBox.shrink(
                                      key: ValueKey('empty'),
                                    )
                                  : Center(
                                      key: ValueKey(
                                        'planned-${summary.primaryGoal!.code}',
                                      ),
                                      child: GoalIcon(
                                        summary.primaryGoal!.code,
                                        size: 25,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                            ),
                          ),
                          if (summary.additionalWorkoutCount > 0)
                            Positioned(
                              right: 5,
                              bottom: 4,
                              child: Text(
                                '+${summary.additionalWorkoutCount}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
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

  List<Workout> _plannedForWeekday(int weekday) {
    final result = widget.plannedWorkouts
        .where((workout) => workout.assignedDays.contains(weekday))
        .toList()
      ..sort(
        (a, b) =>
            (a.scheduleOrderByDay[weekday] ?? 0).compareTo(
              b.scheduleOrderByDay[weekday] ?? 0,
            ),
      );
    return result;
  }

  String _key(DateTime d) {
    final x = DateUtils.dateOnly(d);
    return '${x.year}-${x.month}-${x.day}';
  }

  String _monthName(DateTime d) {
    return DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(d);
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 180),
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: scheme.tertiary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.tertiary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check_rounded, size: 23, color: scheme.onTertiary),
      ),
    );
  }
}
