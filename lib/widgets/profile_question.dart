import 'package:flutter/material.dart';
import '../l10n/planning_l10n.dart';

/// Shared serial form shell; back does not discard the locally saved draft.
class ProfileQuestion extends StatelessWidget {
  const ProfileQuestion({
    super.key,
    required this.title,
    required this.question,
    required this.step,
    required this.count,
    required this.formKey,
    required this.children,
    required this.onNext,
    required this.onBack,
    required this.onLater,
    this.busy = false,
    this.error,
  });
  final String title, question;
  final int step, count;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onNext, onBack, onLater;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: step == 0 && !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !busy) onBack();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: busy ? null : onBack),
        actions: [
          TextButton(
            onPressed: busy ? null : onLater,
            child: Text(context.planning('later')),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: busy ? null : onNext,
          child: Text(
            context.planning(step == count - 1 ? 'confirmProfile' : 'next'),
          ),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          key: ValueKey('profile-question-$step'),
          padding: const EdgeInsets.all(20),
          children: [
            LinearProgressIndicator(value: (step + 1) / count),
            const SizedBox(height: 24),
            Text(question, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ...children,
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.planning(error!),
                  semanticsLabel: context.planning(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
