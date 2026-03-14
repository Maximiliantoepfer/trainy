import 'package:flutter/material.dart';

import '../data/motivational_quotes.dart';

class MotivationalQuoteCard extends StatelessWidget {
  const MotivationalQuoteCard({super.key});

  MotivationalQuote get _todaysQuote {
    final now = DateTime.now();
    final index = (now.day + now.month * 31) % motivationalQuotes.length;
    return motivationalQuotes[index];
  }

  @override
  Widget build(BuildContext context) {
    final quote = _todaysQuote;
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
                  Icon(Icons.format_quote_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('Spruch des Tages',
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '„${quote.text}"',
                style: textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (quote.author != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '— ${quote.author}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
