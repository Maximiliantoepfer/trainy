import 'plan_drag_target.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/planning_l10n.dart';
import '../l10n/plan_l10n.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../models/training_program.dart';
import '../utils/goal_utils.dart';
import 'plan_controls.dart';

class PlanWeekBlock extends StatelessWidget {
  const PlanWeekBlock({
    super.key,
    required this.monday,
    required this.entries,
    required this.entryBuilder,
    this.planStart,
    this.planEnd,
    this.onAdd,
    this.onMove,
  });
  final void Function(ProgramEntry, DateTime)? onMove;
  final DateTime monday;
  final DateTime? planStart;
  final DateTime? planEnd;
  final List<ProgramEntry> entries;
  final Widget Function(ProgramEntry) entryBuilder;
  final ValueChanged<DateTime>? onAdd;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final today = DateUtils.dateOnly(DateTime.now());
    final current =
        calendarDays(today, monday) >= 0 && calendarDays(today, monday) < 7;
    final start = planStart;
    final week =
        start == null
            ? null
            : calendarDays(
                      monday,
                      DateTime(
                        start.year,
                        start.month,
                        start.day - start.weekday + 1,
                      ),
                    ) ~/
                    7 +
                1;
    final scheme = Theme.of(context).colorScheme;
    final divider =
        Theme.of(context).brightness == Brightness.dark
            ? scheme.outlineVariant.withValues(alpha: .15)
            : scheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: current ? scheme.primary.withValues(alpha: .55) : divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat.MMMd(locale).format(monday)} – ${DateFormat.MMMd(locale).format(DateTime(monday.year, monday.month, monday.day + 6))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (current) context.planning('currentWeek'),
                    if (week != null && week > 0)
                      '${context.planning('weekTitle')} $week',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (c) {
                final day = DateTime(monday.year, monday.month, monday.day + i);
                final items =
                    entries
                        .where((e) => dateKey(e.date) == dateKey(day))
                        .toList();
                final isToday = dateKey(day) == dateKey(today);
                return PlanDayDropTarget(
                  day: day,
                  onMove: onMove,
                  enabled:
                      (planStart == null ||
                          !day.isBefore(DateUtils.dateOnly(planStart!))) &&
                      (planEnd == null ||
                          !day.isAfter(DateUtils.dateOnly(planEnd!))),
                  child: Column(
                    children: [
                      Divider(height: 1, color: divider),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 48,
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat.E(locale).format(day),
                                    style: Theme.of(c).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          isToday
                                              ? scheme.primary
                                              : Colors.transparent,
                                    ),
                                    child: Text(
                                      '${day.day}',
                                      style: Theme.of(
                                        c,
                                      ).textTheme.titleMedium?.copyWith(
                                        color:
                                            isToday
                                                ? scheme.onPrimary
                                                : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (items.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        context.planning('restDay'),
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  for (final e in items)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: PlanDraggable(
                                        entry: e,
                                        enabled: onMove != null,
                                        child: entryBuilder(e),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (onAdd != null &&
                                !day.isBefore(today) &&
                                (planEnd == null ||
                                    !day.isAfter(
                                      DateUtils.dateOnly(planEnd!),
                                    )) &&
                                (planStart == null ||
                                    !day.isBefore(
                                      DateUtils.dateOnly(planStart!),
                                    )))
                              IconButton(
                                tooltip: context.plan('add'),
                                onPressed: () => onAdd!(day),
                                icon: const Icon(Icons.add, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class PlanWorkoutTile extends StatelessWidget {
  const PlanWorkoutTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.units,
    this.onActions,
    this.detail,
  });
  final ProgramEntry entry;
  final String? detail;
  final VoidCallback onTap;
  final VoidCallback? onActions;
  final DistanceSystem units;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme, e = entry;
    final goal = e.kind == 'running' ? 'endurance' : e.kind;
    final steps = e.cardio?.workout.expandedSteps() ?? <CardioStep>[];
    final meters = steps
        .where((s) => s.goal == StepGoal.distance)
        .fold<double>(0, (v, s) => v + s.amount);
    final seconds = steps
        .where((s) => s.goal == StepGoal.time)
        .fold<double>(0, (v, s) => v + s.amount);
    int priority(CardioIntensity intensity) => switch (intensity) {
      CardioIntensity.interval => 4,
      CardioIntensity.threshold => 3,
      CardioIntensity.steady => 2,
      CardioIntensity.easy => 1,
      _ => 0,
    };
    final targets =
        steps.where((s) => s.movement != 'walk' && s.maxSpeed != null).toList()
          ..sort(
            (a, b) => priority(b.intensity).compareTo(priority(a.intensity)),
          );
    final target = targets.firstOrNull;
    final info = [
      if (detail != null) detail!,
      if (e.needsWorkout && !e.completed) context.plan('assignWorkout'),
      if (meters > 0)
        CardioUnits.distance(
          meters,
          units,
          locale: Localizations.localeOf(context).toString(),
        ),
      if (seconds > 0) CardioUnits.clock(seconds),
      if (target != null)
        target.minSpeed == null
            ? '${context.planning('paceLimit')} ${CardioUnits.pace(target.maxSpeed, units)}'
            : '${CardioUnits.pace(target.maxSpeed, units)} – ${CardioUnits.pace(target.minSpeed, units)}',
      if (steps.isNotEmpty && target == null)
        context.cardio(steps.first.intensity.name),
    ].join(' · ');
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                color: e.completed ? scheme.tertiary : scheme.primary,
              ),
              const SizedBox(width: 10),
              GoalIcon(goal, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planLabel(context, e.name),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          info,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (e.completed)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.check_circle,
                    color: scheme.tertiary,
                    size: 20,
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
