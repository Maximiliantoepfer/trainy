import 'package:flutter/material.dart';

import '../data/motivational_quotes.dart';
import '../l10n/l10n.dart';

class MotivationalQuoteCard extends StatelessWidget {
  const MotivationalQuoteCard({super.key});

  String get _todaysQuoteKey {
    final now = DateTime.now();
    final index = (now.day + now.month * 31) % motivationalQuoteKeys.length;
    return motivationalQuoteKeys[index];
  }

  @override
  Widget build(BuildContext context) {
    final quote = context.l10n.motivationalQuote(_todaysQuoteKey);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.quoteOfTheDay,
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '„$quote"',
                style: textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
