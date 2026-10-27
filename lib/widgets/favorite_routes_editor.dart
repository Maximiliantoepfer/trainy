import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cardio.dart';
import '../models/running_preferences.dart';
import '../l10n/cardio_l10n.dart';
import '../utils/uuid_v4.dart';

class FavoriteRoutesEditor extends StatelessWidget {
  const FavoriteRoutesEditor({
    super.key,
    required this.routes,
    required this.units,
    required this.onChanged,
  });
  final List<FavoriteRunningRoute> routes;
  final DistanceSystem units;
  final ValueChanged<List<FavoriteRunningRoute>> onChanged;
  Future<void> _edit(
    BuildContext context, [
    FavoriteRunningRoute? route,
  ]) async {
    final name = TextEditingController(text: route?.name ?? '');
    final distance = TextEditingController(
      text:
          route == null
              ? ''
              : NumberFormat(
                '0.###',
                Localizations.localeOf(context).toString(),
              ).format(route.meters / CardioUnits.distanceUnit(units)),
    );
    final days = {...?route?.weekdays};
    final originalDistance = distance.text;
    final form = GlobalKey<FormState>();
    final result = await showDialog<FavoriteRunningRoute>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, update) => AlertDialog(
                  title: Text(c.recording('addRoute')),
                  content: SingleChildScrollView(
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: distance,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: c.recording('routeDistance'),
                              suffixText:
                                  units == DistanceSystem.metric ? 'km' : 'mi',
                            ),
                            validator: (v) {
                              final meters =
                                  (double.tryParse(
                                        (v ?? '').replaceAll(',', '.'),
                                      ) ??
                                      0) *
                                  CardioUnits.distanceUnit(units);
                              return meters.isFinite &&
                                      meters >= 100 &&
                                      meters <= 100000
                                  ? null
                                  : c.recording('answerRequired');
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: name,
                            maxLength: 80,
                            decoration: InputDecoration(
                              labelText: c.recording('routeName'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(c.recording('routeDays')),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (var d = 1; d <= 7; d++)
                                FilterChip(
                                  label: Text(
                                    DateFormat.E(
                                      Localizations.localeOf(c).toString(),
                                    ).format(DateTime(2026, 10, 18 + d)),
                                  ),
                                  selected: days.contains(d),
                                  onSelected:
                                      (v) => update(() {
                                        v ? days.add(d) : days.remove(d);
                                      }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(c.cardio('cancel')),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (!form.currentState!.validate()) return;
                        Navigator.pop(
                          c,
                          FavoriteRunningRoute(
                            id: route?.id ?? UuidV4.generate(),
                            name: name.text.trim(),
                            meters:
                                route != null &&
                                        distance.text == originalDistance
                                    ? route.meters
                                    : double.parse(
                                          distance.text.replaceAll(',', '.'),
                                        ) *
                                        CardioUnits.distanceUnit(units),
                            weekdays: days.toList()..sort(),
                          ),
                        );
                      },
                      child: Text(c.cardio('save')),
                    ),
                  ],
                ),
          ),
    );
    // Controllers outlive the dialog's closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    distance.dispose();
    if (result != null && context.mounted) {
      onChanged(
        route == null
            ? [...routes, result]
            : [for (final r in routes) r.id == route.id ? result : r],
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.recording('routeHint')),
      const SizedBox(height: 16),
      for (var i = 0; i < routes.length; i++)
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Text('${i + 1}'),
                onTap: () => _edit(context, routes[i]),
                title: Text(
                  routes[i].name.isEmpty
                      ? CardioUnits.distance(routes[i].meters, units)
                      : routes[i].name,
                ),
                subtitle: Text(
                  '${CardioUnits.distance(routes[i].meters, units)}${routes[i].weekdays.isEmpty ? '' : ' · ${routes[i].weekdays.map((d) => DateFormat.E(Localizations.localeOf(context).toString()).format(DateTime(2026, 10, 18 + d))).join(', ')}'}',
                ),
                trailing: IconButton(
                  tooltip: context.recording('remove'),
                  icon: const Icon(Icons.close),
                  onPressed:
                      () => onChanged(
                        routes.where((r) => r.id != routes[i].id).toList(),
                      ),
                ),
              ),
              if (routes.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: WidgetsLocalizations.of(context).reorderItemUp,
                      onPressed:
                          i == 0
                              ? null
                              : () {
                                final next = [...routes];
                                final r = next.removeAt(i);
                                next.insert(i - 1, r);
                                onChanged(next);
                              },
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: WidgetsLocalizations.of(context).reorderItemDown,
                      onPressed:
                          i == routes.length - 1
                              ? null
                              : () {
                                final next = [...routes];
                                final r = next.removeAt(i);
                                next.insert(i + 1, r);
                                onChanged(next);
                              },
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
            ],
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: Text(context.recording('addRoute')),
      ),
    ],
  );
}
