import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import '../services/cardio_training.dart';
import '../l10n/cardio_l10n.dart';
import '../l10n/plan_l10n.dart';
import '../l10n/strength_l10n.dart';
import 'cardio_editor_screen.dart';

/// Returns a detached running workout. Picking never edits a saved template.
class RunningWorkoutPicker extends StatelessWidget {
  const RunningWorkoutPicker({super.key, this.sport = CardioSport.running});
  final CardioSport sport;

  Future<void> _pick(BuildContext context, CardioWorkout workout) async {
    final result = await Navigator.push<CardioWorkout>(
      context,
      MaterialPageRoute(
        builder:
            (_) => CardioEditorScreen(
              workout: workout,
              units: context.read<CardioProvider>().profile.units,
              lockSport: true,
            ),
      ),
    );
    if (result != null && context.mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardioProvider>();
    final profile = provider.profile;
    final recommended =
        profile.returningAfterBreak || profile.continuousMinutes < 30
            ? {'runWalk', 'easy5k'}
            : {'easy5k', 'progression', 'fartlek', 'longRun'};
    final codes = [
      if (sport == CardioSport.running) ...CardioTraining.templateCodes,
    ]..sort((a, b) {
      final order =
          (recommended.contains(b) ? 1 : 0) - (recommended.contains(a) ? 1 : 0);
      return order != 0
          ? order
          : CardioTraining.templateCodes
              .indexOf(a)
              .compareTo(CardioTraining.templateCodes.indexOf(b));
    });
    return Scaffold(
      appBar: AppBar(title: Text(context.strength('replaceWorkout'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.cardio('templates'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final code in codes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_run),
                  title: Text(
                    context.cardio(code == 'easy5k' ? 'easySession' : code),
                  ),
                  subtitle:
                      recommended.contains(code)
                          ? Text(context.strength('suggested'))
                          : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => _pick(
                        context,
                        CardioTraining.replacementTemplate(
                          code,
                          profile,
                          context.cardio,
                        ),
                      ),
                ),
              ),
            ),
          if (sport != CardioSport.running)
            OutlinedButton.icon(
              onPressed:
                  () => _pick(
                    context,
                    CardioWorkout(
                      name: context.cardio(sport.name),
                      sport: sport,
                      steps: [CardioStep(amount: 1200)],
                    ),
                  ),
              icon: const Icon(Icons.add),
              label: Text(context.strength('individualRoutine')),
            ),
          if (provider.workouts.any((w) => w.sport == sport)) ...[
            const SizedBox(height: 16),
            Text(
              context.plan('ownWorkouts'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final w in provider.workouts.where((w) => w.sport == sport))
              ListTile(
                title: Text(w.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pick(context, w),
              ),
          ],
        ],
      ),
    );
  }
}
