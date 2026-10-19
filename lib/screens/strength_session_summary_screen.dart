import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/activity_repository.dart';
import '../l10n/l10n.dart';
import '../l10n/plan_l10n.dart';

/// Reads the immutable canonical snapshot, including workouts deleted later.
class StrengthSessionSummaryScreen extends StatelessWidget {
  const StrengthSessionSummaryScreen({super.key, required this.sessionId});
  final String sessionId;
  Future<List<Map<String, Object?>>> _items() =>
      ActivityRepository().sessionItemsWithMetrics(sessionId);
  String _value(BuildContext c, Map<String, Object?> row) {
    final label = switch (row['metric_key']) {
      'reps' => c.l10n.repetitions,
      'sets' => c.l10n.sets,
      'weight' || 'added_weight' => c.l10n.weight,
      'duration' => c.l10n.duration,
      'distance' => c.l10n.distance,
      _ => row['metric_key'] as String? ?? '',
    };
    final unit = row['unit_code'] as String? ?? '';
    final value = NumberFormat.decimalPattern(
      Localizations.localeOf(c).toString(),
    ).format(row['numeric_value']);
    final index = row['effort_index'] as int?;
    return '${index == null ? '' : '${index + 1} · '}$label: $value${['count', 'rep', 'reps', 'set', 'sets', ''].contains(unit) ? '' : ' $unit'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.plan('strength'))),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: _items(),
      builder: (c, s) {
        if (s.hasError) return Center(child: Text(c.plan('error')));
        if (!s.hasData) return const SizedBox.shrink();
        final groups = <String, List<Map<String, Object?>>>{};
        for (final r in s.data!) {
          groups.putIfAbsent(r['id'] as String, () => []).add(r);
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final rows in groups.values)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows.first['display_name_snapshot'] as String,
                        style: Theme.of(c).textTheme.titleMedium,
                      ),
                      for (final row in rows.where(
                        (r) => r['numeric_value'] != null,
                      ))
                        Text(_value(c, row)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
