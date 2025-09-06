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
    this.height = 180, // leicht erhöht für größere Labels
  });

  @override
  Widget build(BuildContext context) {
    final days = _currentWeekDays();
    final counts = List<int>.generate(7, (i) {
      final d = days[i];
      return entries.where((e) => DateUtils.isSameDay(e.date, d)).length;
    });
    final maxVal = counts.fold<int>(0, (m, v) => v > m ? v : m);

    final labelStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final subLabelStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

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
              // Horizontaler Abstand zwischen Tagen
              const hSpacing = 10.0;
              final dayWidth = (constraints.maxWidth - hSpacing * 6) / 7;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(7, (i) {
                  final value = counts[i];
                  final label = _weekdayShort(i); // 0..6 -> Mo..So

                  return SizedBox(
                    width: dayWidth,
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 6 ? 0 : hSpacing),
                      child: _DayBar(
                        value: value,
                        maxValue: maxVal,
                        label: label,
                        valueStyle: labelStyle,
                        dayStyle: subLabelStyle,
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

class _DayBar extends StatelessWidget {
  final int value;
  final int maxValue;
  final String label;
  final TextStyle valueStyle;
  final TextStyle dayStyle;

  const _DayBar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.valueStyle,
    required this.dayStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Fixe Höhen für Labels -> kein Overflow
    const topValueHeight = 26.0; // mehr Platz für größere Schrift
    const bottomLabelHeight = 22.0; // mehr Platz für größere Schrift
    const middleGap = 8.0;

    final barColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Wert über dem Balken
        SizedBox(
          height: topValueHeight,
          child: Center(
            child: FittedBox(child: Text(value.toString(), style: valueStyle)),
          ),
        ),
        // Flexibler Balkenbereich
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: (maxValue <= 0) ? 0.0 : (value / maxValue),
              child: Container(
                width: 18, // leicht breiter für bessere Lesbarkeit
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: middleGap),
        // Wochentags-Label
        SizedBox(
          height: bottomLabelHeight,
          child: Center(child: FittedBox(child: Text(label, style: dayStyle))),
        ),
      ],
    );
  }
}
