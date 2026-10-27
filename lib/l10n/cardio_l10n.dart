import 'package:flutter/widgets.dart';
import 'l10n.dart';

extension CardioL10n on BuildContext {
  String forecast(String key) => l10n.forecastText('k_$key');
  String running(String key) => l10n.runningText('k_$key');
  String cardio(String key) =>
      key == 'qualityScheduleConflict'
          ? forecast(key)
          : [
            'restrictedTraining',
            'walkPreparation',
            'hills',
            'routeBudget',
          ].contains(key)
          ? running(
            key == 'walkPreparation'
                ? 'walkPreparationWorkout'
                : key == 'hills'
                ? 'hillsWorkout'
                : key,
          )
          : ['notFaster', 'notSlower'].contains(key)
          ? l10n.refinementText('k_$key')
          : l10n.cardioText('k_$key');
}
