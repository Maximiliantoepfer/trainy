import 'package:flutter/material.dart';
import '../models/workout_entry.dart';

/// Wochen-Aktivitätschart (Mo–So) für die **aktuelle Woche**.
/// - Woche ist horizontal **zentriert** (nutzt die komplette Breite gleichmäßig).
/// - Keine Overflows: Slotbreiten werden dynamisch aus der verfügbaren Breite berechnet.
/// - Beschriftungen größer & fett, Balken dicker.
/// API bleibt kompatibel.
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
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = _mondayOfWeek(now);

    // Tage der Woche (Mo–So)
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    );

    // Anzahl Workouts pro Tag bestimmen
    final counts = List<int>.filled(7, 0);
    for (final e in entries) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (d.isBefore(startOfWeek) || d.isAfter(days.last)) continue;
      final idx = d.difference(startOfWeek).inDays;
      if (idx >= 0 && idx < 7) counts[idx] += 1;
    }
    final maxValue =
        counts.isNotEmpty ? counts.reduce((a, b) => a > b ? a : b) : 0;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bg =
        theme.brightness == Brightness.dark
            ? const Color(0xFF151515)
            : Colors.white;

    // Layout-Konstanten (vertikal)
    const double topValueHeight = 28;
    const double bottomLabelHeight = 22;
    const double innerGap = 10;

    // Schriftgrößen/-gewichte (größer & fett)
    final valueStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: (textTheme.labelMedium?.fontSize ?? 12) + 2,
    );
    final dayStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: (textTheme.labelMedium?.fontSize ?? 12) + 1,
      color: textTheme.labelMedium?.color?.withOpacity(0.85),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          // Chartbereich
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Verfügbare Breite gleichmäßig auf 7 Slots verteilen.
                // => Kein Overflow, Reihe zentriert (nimmt die volle Breite symmetrisch ein).
                final slotWidth = constraints.maxWidth / 7.0;

                // Balkenbreite dynamisch & dicker, aber mit sinnvollen Grenzen
                final computedBarWidth = (slotWidth * 0.36).clamp(12.0, 22.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    return SizedBox(
                      width: slotWidth,
                      child: _DayColumn(
                        value: counts[i],
                        maxValue: maxValue,
                        label: _weekdayLabel(i),
                        barColor: scheme.primary,
                        valueStyle: valueStyle,
                        dayStyle: dayStyle,
                        barWidth: computedBarWidth,
                        topValueHeight: topValueHeight,
                        bottomLabelHeight: bottomLabelHeight,
                        innerGap: innerGap,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _mondayOfWeek(DateTime d) {
    // Monday = 1
    final int weekday = d.weekday;
    return DateTime(d.year, d.month, d.day - (weekday - 1));
  }

  static String _weekdayLabel(int index) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return labels[index.clamp(0, 6)];
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.barColor,
    required this.valueStyle,
    required this.dayStyle,
    required this.barWidth,
    required this.topValueHeight,
    required this.bottomLabelHeight,
    required this.innerGap,
  });

  final int value;
  final int maxValue;
  final String label;
  final Color barColor;
  final TextStyle? valueStyle;
  final TextStyle? dayStyle;
  final double barWidth;
  final double topValueHeight;
  final double bottomLabelHeight;
  final double innerGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableForBar =
            constraints.maxHeight -
            topValueHeight -
            bottomLabelHeight -
            innerGap * 2;

        final normalized =
            maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
        final barHeight = availableForBar * normalized;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: topValueHeight,
              child: Center(
                child: FittedBox(child: Text('$value', style: valueStyle)),
              ),
            ),
            SizedBox(height: innerGap),
            Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
            SizedBox(height: innerGap),
            SizedBox(
              height: bottomLabelHeight,
              child: Center(
                child: FittedBox(child: Text(label, style: dayStyle)),
              ),
            ),
          ],
        );
      },
    );
  }
}
