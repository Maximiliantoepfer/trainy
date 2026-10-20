import '../l10n/strength_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/plan_l10n.dart';

class PlanDayPicker extends StatelessWidget {
  const PlanDayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.available,
  });
  final Set<int> selected;
  final Set<int>? available;
  final ValueChanged<Set<int>> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var d = 1; d <= 7; d++)
        FilterChip(
          label: Text(
            DateFormat.E(
              Localizations.localeOf(context).toString(),
            ).format(DateTime(2024, 1, d)),
          ),
          selected: selected.contains(d),
          onSelected:
              available != null &&
                      !available!.contains(d) &&
                      !selected.contains(d)
                  ? null
                  : (v) => onChanged(
                    v ? {...selected, d} : ({...selected}..remove(d)),
                  ),
        ),
    ],
  );
}

Future<String?> choosePlanValue(
  BuildContext context,
  String title,
  List<String> values,
  String selected,
) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder:
      (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.plan(title),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final v in values)
                  ListTile(
                    title: Text(ctx.plan(v)),
                    trailing: v == selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(ctx, v),
                  ),
              ],
            ),
          ),
        ),
      ),
);

String planLabel(BuildContext context, String value) {
  final text = context.strength(value);
  return text == 'k_$value' ? value : text;
}

class PlanError extends StatelessWidget {
  const PlanError(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.plan(message),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(context.plan('retry'))),
      ],
    ),
  );
}
