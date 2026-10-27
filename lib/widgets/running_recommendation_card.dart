import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/cardio_l10n.dart';
import '../providers/cardio_provider.dart';
import '../screens/cardio_screen.dart';
import '../screens/cardio_session_screen.dart';

class RunningRecommendationCard extends StatelessWidget {
  const RunningRecommendationCard({super.key, this.showFeedback = false});
  final bool showFeedback;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    final recommendation = p.recommendation;
    Map<String, Object?>? feedbackRun;
    if (showFeedback && recommendation == null) {
      for (final row in p.history) {
        final r = cardioHistoryRuntime(row);
        final s = jsonDecode(row['snapshot_json'] as String) as Map;
        final date = DateTime.fromMillisecondsSinceEpoch(
          row['started_at_utc'] as int,
        );
        final feedback = s['feedback'] as Map?;
        if (r['sport'] == 'running' &&
            DateTime.now().difference(date).inDays <= 28 &&
            (feedback == null ||
                feedback['recovery'] == null ||
                (s['health'] != null && feedback['continuous'] == null))) {
          feedbackRun = row;
          break;
        }
      }
    }
    if (recommendation == null &&
        feedbackRun == null &&
        p.recommendationError == null) {
      return const SizedBox.shrink();
    }
    final row = feedbackRun;
    final isError = p.recommendationError != null && recommendation == null;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_graph_outlined, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.forecast(
                        recommendation != null
                            ? 'recommendation'
                            : isError
                            ? 'unavailable'
                            : 'feedback',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recommendation != null)
                Text(
                  recommendation.reason == 'structure'
                      ? context.forecast('structure')
                      : context.running(recommendation.reason),
                )
              else if (!isError)
                Text(context.forecast('feedbackHint')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      if (recommendation != null) {
                        await CardioScreen.showAdaptation(context, p);
                      } else if (isError) {
                        await p.refreshRecommendations();
                      } else if (row != null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CardioSummaryScreen(
                                  runtime: cardioHistoryRuntime(row),
                                  snapshot:
                                      jsonDecode(row['snapshot_json'] as String)
                                          as Map<String, dynamic>,
                                ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      context.forecast(
                        recommendation != null
                            ? 'review'
                            : isError
                            ? 'retry'
                            : 'feedback',
                      ),
                    ),
                  ),
                  if (recommendation != null)
                    TextButton(
                      onPressed: () async {
                        try {
                          await p.repository.dismissAdaptation(recommendation);
                          await p.load();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.cardio('error'))),
                            );
                          }
                        }
                      },
                      child: Text(context.forecast('later')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
