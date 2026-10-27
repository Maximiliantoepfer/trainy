import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';

/// Compact navigation across every generated week. Full cards remain in the
/// shared calendar; tapping a week reveals its individual workout targets.
class RunningForecastView extends StatelessWidget {
  const RunningForecastView({
    super.key,
    required this.occurrences,
    this.onWeek,
  });
  final List<ScheduledCardioWorkout> occurrences;
  final ValueChanged<DateTime>? onWeek;
  @override
  Widget build(BuildContext context) {
    final weeks = <DateTime, List<ScheduledCardioWorkout>>{};
    final today = DateUtils.dateOnly(DateTime.now());
    for (final o in occurrences.where((o) => !o.date.isBefore(today))) {
      final monday = DateTime(
        o.date.year,
        o.date.month,
        o.date.day - o.date.weekday + 1,
      );
      weeks.putIfAbsent(monday, () => []).add(o);
    }
    if (weeks.isEmpty) return const SizedBox.shrink();
    final dates = weeks.keys.toList()..sort();
    final locale = Localizations.localeOf(context).toString();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ExpansionTile(
        title: Text(context.forecast('title')),
        subtitle: Text(
          occurrences.any(
                (o) => o.workout.steps.any(
                  (s) => s.maxSpeed != null && s.targetSource != 'manual',
                ),
              )
              ? context.forecast('provisional')
              : context.running('noReference'),
        ),
        leading: const Icon(Icons.view_timeline_outlined),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(context.forecast('hint')),
          const SizedBox(height: 8),
          for (final date in dates)
            ListTile(
              key: ValueKey(date),
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${DateFormat.MMMd(locale).format(date)} – ${DateFormat.MMMd(locale).format(DateTime(date.year, date.month, date.day + 6))}',
              ),
              subtitle: Text(
                weeks[date]!.map((o) => o.workout.name).toSet().join(' · '),
              ),
              trailing: onWeek == null ? null : const Icon(Icons.chevron_right),
              onTap:
                  onWeek == null
                      ? null
                      : () {
                        // Return to the overview before collapsing it, so selecting a
                        // distant week never leaves the user halfway down its calendar.
                        Scrollable.ensureVisible(context);
                        onWeek!(date);
                      },
            ),
        ],
      ),
    );
  }
}
