import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/cardio_l10n.dart';
import '../providers/cardio_provider.dart';
import 'cardio_health_screen.dart';
import 'cardio_session_screen.dart';

/// Completed activities only: plans and templates have their own shared homes.
class CardioHistoryScreen extends StatelessWidget {
  const CardioHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.cardio('history')),
        actions: [
          IconButton(
            tooltip: context.cardio('health'),
            icon: const Icon(Icons.favorite_border),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CardioHealthScreen()),
                ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: p.load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (p.history.isEmpty) Text(context.cardio('noData')),
            for (final r in p.history)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(
                      r['name_snapshot'] as String? ?? context.cardio('cardio'),
                    ),
                    subtitle: Text(
                      DateFormat.yMMMEd(
                        Localizations.localeOf(context).toString(),
                      ).add_Hm().format(
                        DateTime.fromMillisecondsSinceEpoch(
                          r['started_at_utc'] as int,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CardioSummaryScreen(
                                  runtime: cardioHistoryRuntime(r),
                                  snapshot:
                                      jsonDecode(r['snapshot_json'] as String)
                                          as Map<String, dynamic>,
                                ),
                          ),
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
