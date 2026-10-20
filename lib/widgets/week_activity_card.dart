import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/plan_l10n.dart';
import '../models/training_program.dart';
import 'activity_day_badge.dart';
import 'animated_flame_icon.dart';
import '../l10n/planning_l10n.dart';

class WeekActivityCard extends StatelessWidget {
  const WeekActivityCard({
    super.key,
    required this.date,
    required this.entries,
    required this.onDateChanged,
    this.streak = 0,
    this.todayOverride,
  });
  final DateTime date;
  final List<ProgramEntry> entries;
  final ValueChanged<DateTime> onDateChanged;
  final int streak;
  final DateTime? todayOverride;
  @override
  Widget build(BuildContext context) {
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(todayOverride ?? DateTime.now());
    final thisMonday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final currentWeek = dateKey(monday) == dateKey(thisMonday);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.planning(currentWeek ? 'currentWeek' : 'weekTitle'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (dateKey(date) != dateKey(today))
                  TextButton(
                    onPressed: () => onDateChanged(today),
                    child: Text(context.plan('today')),
                  ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: context.planning('previousWeek'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      () => onDateChanged(
                        DateTime(date.year, date.month, date.day - 7),
                      ),
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.MMMd(locale).format(monday)} – ${DateFormat.MMMd(locale).format(DateTime(monday.year, monday.month, monday.day + 6))}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.planning('nextWeek'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      () => onDateChanged(
                        DateTime(date.year, date.month, date.day + 7),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder:
                  (c, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Builder(
                            builder: (c) {
                              final day = DateTime(
                                monday.year,
                                monday.month,
                                monday.day + i,
                              );
                              final selected = dateKey(day) == dateKey(date);
                              final dayEntries =
                                  entries
                                      .where(
                                        (e) => dateKey(e.date) == dateKey(day),
                                      )
                                      .toList();
                              final state = ActivityDayState.fromEntries(
                                dayEntries,
                              );
                              return SizedBox(
                                width: (constraints.maxWidth / 7).clamp(
                                  MediaQuery.textScalerOf(c).scale(14) > 21
                                      ? 58
                                      : 44,
                                  double.infinity,
                                ),
                                child: Semantics(
                                  button: true,
                                  selected: selected,
                                  label:
                                      '${DateFormat.yMMMEd(locale).format(day)}: ${state.completed}/${state.planned}',
                                  child: InkWell(
                                    onTap: () => onDateChanged(day),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Column(
                                        children: [
                                          ActivityDayBadge(
                                            state: state,
                                            selected:
                                                dateKey(day) == dateKey(today),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            DateFormat.E(locale).format(day),
                                            style: Theme.of(
                                              c,
                                            ).textTheme.labelLarge?.copyWith(
                                              color: scheme.onSurface,
                                              fontWeight:
                                                  selected
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: 18,
                                            height: 3,
                                            color:
                                                selected
                                                    ? scheme.primary
                                                    : Colors.transparent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${DateFormat.yMMMEd(locale).format(date)}${dateKey(date) == dateKey(today) ? ' · ${context.plan('today')}' : ''}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (streak > 0)
                  const AnimatedFlameIcon(size: 28)
                else
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 28,
                    color: scheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    streak > 0
                        ? '$streak ${context.planning('streakSuffix')}'
                        : context.planning('startStreak'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
