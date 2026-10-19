import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/plan_l10n.dart';
import '../models/training_program.dart';
import 'activity_day_badge.dart';
import 'animated_flame_icon.dart';

class WeekActivityCard extends StatelessWidget {
  const WeekActivityCard({
    super.key,
    required this.date,
    required this.entries,
    required this.onDateChanged,
    this.streak = 0,
  });
  final DateTime date;
  final List<ProgramEntry> entries;
  final ValueChanged<DateTime> onDateChanged;
  final int streak;
  @override
  Widget build(BuildContext context) {
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.plan('back'),
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
                if (streak > 0) ...[
                  const SizedBox(width: 4),
                  const AnimatedFlameIcon(size: 20),
                  Text('$streak'),
                ],
                IconButton(
                  tooltip: context.plan('next'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      () => onDateChanged(
                        DateTime(date.year, date.month, date.day + 7),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                                            selected: selected,
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
          ],
        ),
      ),
    );
  }
}
