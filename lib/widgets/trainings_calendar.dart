// lib/widgets/trainings_calendar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../models/workout_entry.dart';
import '../l10n/l10n.dart';
import '../utils/goal_utils.dart';
import '../models/cardio.dart';
import 'package:provider/provider.dart';
import '../providers/training_program_provider.dart';
import '../models/training_program.dart';

/// Simpler Monatskalender mit Markierungen für Tage, an denen Workouts getrackt wurden.
/// Design-Update: Statt Zahl nun ein kräftiger, gefüllter grüner Haken.
/// Count bleibt für Semantics/Screenreader erhalten.
class TrainingsCalendar extends StatefulWidget {
  final List<WorkoutEntry> entries;
  final List<Workout> plannedWorkouts;
  final ValueChanged<CalendarDaySummary>? onDayTap;
  final List<DateTime> additionalCompleted;
  final List<ScheduledCardioWorkout> cardioOccurrences;

  const TrainingsCalendar({
    super.key,
    required this.entries,
    this.plannedWorkouts = const [],
    this.onDayTap,
    this.additionalCompleted = const [],
    this.cardioOccurrences = const [],
  });

  @override
  State<TrainingsCalendar> createState() => _TrainingsCalendarState();
}

class _TrainingsCalendarState extends State<TrainingsCalendar> {
  late DateTime _visibleMonthFirstDay; // jeweils der 1. des Monats
  Object? _planKey;
  DateTime? _loadedMonth;
  Future<List<ProgramEntry>>? _planned;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonthFirstDay = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TrainingProgramProvider?>();
    if (store == null) return _calendar(context, null);
    final p = store.active;
    if (p == null) return _calendar(context, const []);
    if (_planKey != p || _loadedMonth != _visibleMonthFirstDay) {
      _planKey = p;
      _loadedMonth = _visibleMonthFirstDay;
      final from = DateTime(
        _visibleMonthFirstDay.year,
        _visibleMonthFirstDay.month,
        1 - _visibleMonthFirstDay.weekday + 1,
      );
      _planned = store.repository.entries(
        p,
        from,
        DateTime(
          _visibleMonthFirstDay.year,
          _visibleMonthFirstDay.month + 1,
          8,
        ),
      );
    }
    return FutureBuilder<List<ProgramEntry>>(
      future: _planned,
      builder:
          (context, snapshot) => _calendar(context, snapshot.data ?? const []),
    );
  }

  Widget _calendar(BuildContext context, List<ProgramEntry>? scheduled) {
    final days = _buildMonthDays(_visibleMonthFirstDay);
    final activityMap = _activityByDay(widget.entries);
    for (final d in widget.additionalCompleted) {
      activityMap.update(_key(d), (n) => n + 1, ifAbsent: () => 1);
    }

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
            final unified =
                scheduled?.where((e) => dateKey(e.date) == dateKey(d)).toList();
            final planned =
                scheduled == null ? _plannedForWeekday(d.weekday) : <Workout>[];
            final cardioPlanned =
                (scheduled == null
                        ? widget.cardioOccurrences
                        : <ScheduledCardioWorkout>[])
                    .where(
                      (o) =>
                          o.status == 'planned' &&
                          o.date.year == d.year &&
                          o.date.month == d.month &&
                          o.date.day == d.day,
                    )
                    .toList();
            final goalCode =
                prioritizedGoal(
                  planned.expand((workout) => workout.goalCodes),
                ) ??
                (cardioPlanned.isNotEmpty ? 'cardio' : null) ??
                (unified?.isNotEmpty == true
                    ? (unified!.any((e) => e.kind == 'running')
                        ? 'cardio'
                        : unified.first.kind)
                    : null);
            final summary = CalendarDaySummary(
              date: d,
              plannedWorkoutIds: [
                ...cardioPlanned.map((o) => o.id),
                ...planned.map((workout) => workout.canonicalId),
                ...?unified?.map((e) => e.workoutId ?? e.id),
              ],
              primaryGoal:
                  goalCode == null
                      ? null
                      : WorkoutPrimaryGoal.fromCode(goalCode),
              completedCount: cnt,
            );
            final semantics = <String>[
              '${d.day}',
              context.l10n.workoutsRecordedOnDay(cnt),
              if (planned.isNotEmpty ||
                  cardioPlanned.isNotEmpty ||
                  unified?.isNotEmpty == true)
                context.l10n.plannedWorkouts,
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
                    onTap:
                        widget.onDayTap == null
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
                              child:
                                  cnt > 0
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
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
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
    final result =
        widget.plannedWorkouts
            .where((workout) => workout.assignedDays.contains(weekday))
            .toList()
          ..sort(
            (a, b) => (a.scheduleOrderByDay[weekday] ?? 0).compareTo(
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
