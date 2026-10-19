import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import '../screens/cardio_session_screen.dart';
import 'cardio_route_view.dart';

class CardioHistoryCard extends StatefulWidget {
  const CardioHistoryCard({super.key, required this.row});
  final Map<String, Object?> row;
  @override
  State<CardioHistoryCard> createState() => _CardioHistoryCardState();
}

class _CardioHistoryCardState extends State<CardioHistoryCard> {
  late final _route = context.read<CardioProvider>().repository.route(
    widget.row['id'] as String,
  );
  @override
  Widget build(BuildContext context) {
    final runtime = cardioHistoryRuntime(widget.row),
        units = context.read<CardioProvider>().profile.units;
    final seconds = (runtime['activeSeconds'] as num? ?? 0).toDouble(),
        meters = (runtime['distanceMeters'] as num? ?? 0).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => CardioSummaryScreen(
                      runtime: runtime,
                      snapshot:
                          jsonDecode(widget.row['snapshot_json'] as String)
                              as Map<String, dynamic>,
                    ),
              ),
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.row['name_snapshot'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMEd(
                  Localizations.localeOf(context).toString(),
                ).format(
                  DateTime.fromMillisecondsSinceEpoch(
                    widget.row['started_at_utc'] as int,
                  ),
                ),
              ),
              Text(
                [
                  CardioUnits.clock(seconds),
                  if (meters > 0) CardioUnits.distance(meters, units),
                  if (meters > 0 && seconds > 0)
                    CardioUnits.pace(meters / seconds, units),
                ].join(' · '),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _route,
                builder:
                    (c, s) =>
                        !s.hasData || s.data!.length < 2
                            ? const SizedBox.shrink()
                            : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: CardioRouteView(
                                samples: s.data!,
                                thumbnail: true,
                              ),
                            ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
