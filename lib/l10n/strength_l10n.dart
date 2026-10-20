import 'package:flutter/widgets.dart';
import 'plan_l10n.dart';

extension StrengthL10n on BuildContext {
  String strength(String key) {
    final pair = _strengthText[key];
    if (pair != null) {
      return pair[Localizations.localeOf(this).languageCode == 'de' ? 0 : 1];
    }
    final value = plan(key);
    return value == 'k_$key' ? key : value;
  }
}

const _strengthText = <String, List<String>>{
  'minutes': ['Minuten', 'Minutes'],
  'splitHint': ['So verteilen wir dein Training', 'How training is distributed'],
  'pushPullLegs': ['Push / Pull / Legs', 'Push / Pull / Legs'],
  'myProfile': ['Mein Profil', 'My profile'],
  'custom': ['Eigene Aufteilung', 'Custom split'],
  'previewLabel': ['Vorschau', 'Preview'],
  'both': ['Home Gym und Gym', 'Home gym and gym'],
  'placesQuestion': [
    'Wo trainierst du hauptsächlich?',
    'Where do you usually train?',
  ],
  'goalQuestion': [
    'Was möchtest du mit Krafttraining erreichen?',
    'What is your strength training goal?',
  ],
  'preferenceQuestion': [
    'Wie trainierst du im Gym am liebsten?',
    'How do you prefer to train at the gym?',
  ],
  'guided': ['Maschinen bevorzugen', 'Prefer machines'],
  'freeWeights': [
    'Freihanteln und Kabel bevorzugen',
    'Prefer free weights and cables',
  ],
  'equipmentBasic': ['Grundausstattung', 'Basic equipment'],
  'equipmentMachines': ['Kraftmaschinen', 'Strength machines'],
  'equipmentLegacy': [
    'Bisherige weitere Ausstattung',
    'Other existing equipment',
  ],
  'equipmentHint': [
    'Bestätige nur Geräte, die dir wirklich zur Verfügung stehen.',
    'Confirm only equipment you actually have access to.',
  ],
  'weighted_vest': ['Gewichtsweste', 'Weighted vest'],
  'dip_bars': ['Dip-Barren', 'Dip bars'],
  'chest_press': ['Brustpresse', 'Chest press machine'],
  'shoulder_press': ['Schulterpresse', 'Shoulder press machine'],
  'lateral_raise_machine': ['Seithebemaschine', 'Lateral raise machine'],
  'lat_pulldown': ['Latzugstation', 'Lat pulldown station'],
  'row_machine': ['Ruderstation', 'Row station'],
  'rear_delt_machine': ['Reverse-Butterfly', 'Rear delt machine'],
  'assisted_pullup': [
    'Unterstützte Klimmzugmaschine',
    'Assisted pull-up machine',
  ],
  'leg_press': ['Beinpresse', 'Leg press'],
  'leg_extension': ['Beinstrecker', 'Leg extension machine'],
  'leg_curl': ['Beinbeuger', 'Leg curl machine'],
  'hip_thrust_machine': ['Hip-Thrust-Maschine', 'Hip thrust machine'],
  'calf_machine': ['Wadenmaschine', 'Calf raise machine'],
  'ab_machine': ['Bauchmaschine', 'Abdominal machine'],
  'back_extension': ['Rückenstreckerbank', 'Back extension bench'],
  'arm_curl_machine': ['Bizepsmaschine', 'Biceps curl machine'],
  'triceps_machine': ['Trizepsmaschine', 'Triceps extension machine'],
  'countQuestion': [
    'Wie oft möchtest du pro Woche Kraft trainieren?',
    'How often would you like to train strength each week?',
  ],
  'timeQuestion': [
    'Wie viel Zeit hast du pro Einheit?',
    'How much time do you have per session?',
  ],
  'timeHint': [
    'Gesamtzeit einschließlich Aufwärmen, Satzpausen und Gerätewechsel. Später je Workout anpassbar.',
    'Total time including warm-up, rest and equipment changes. Editable for each workout later.',
  ],
  'ownTime': ['Eigene Zeit', 'Custom duration'],
  'timeError': ['Gib 10 bis 240 Minuten ein.', 'Enter 10 to 240 minutes.'],
  'strengthWeek': ['Dein Kraft-Wochenplan', 'Your strength week'],
  'pairBlock': ['Zweier-Split', 'Two-way split'],
  'tripleBlock': ['Dreier-Split', 'Three-way split'],
  'mixedSplit': ['Push + Abs / Pull + Legs', 'Push + Abs / Pull + Legs'],
  'pushCore': ['Push + Abs', 'Push + Abs'],
  'pullLegs': ['Pull + Legs', 'Pull + Legs'],
  'lowerCore': ['Unterkörper + Abs', 'Lower body + Abs'],
  'legs': ['Legs', 'Legs'],
  'core': ['Abs', 'Abs'],
  'chest': ['Brust', 'Chest'],
  'shoulders': ['Vordere/seitliche Schulter', 'Front/side delts'],
  'rearDelts': ['Hintere Schulter', 'Rear delts'],
  'back': ['Rücken', 'Back'],
  'biceps': ['Bizeps', 'Biceps'],
  'triceps': ['Trizeps', 'Triceps'],
  'quads': ['Vordere Oberschenkel', 'Quadriceps'],
  'hamstrings': ['Hintere Oberschenkel', 'Hamstrings'],
  'glutes': ['Gesäß', 'Glutes'],
  'calves': ['Waden', 'Calves'],
  'customSplit': ['Eigene Aufteilung erstellen', 'Create your own split'],
  'workoutName': ['Workoutname', 'Workout name'],
  'focusQuestion': [
    'Welche Muskelgruppen trainierst du?',
    'Which muscle groups will you train?',
  ],
  'recoveryInfo': [
    'Vorschläge lassen ungefähr 48 Stunden zwischen denselben Muskelgruppen frei, auch über den Wochenwechsel. Ohne Uhrzeit verwenden wir zwei Kalendertage Abstand. Eigene Anordnungen bleiben möglich.',
    'Suggestions leave roughly 48 hours between the same muscle groups, including across weeks. Without times we use two calendar days. You can still choose your own arrangement.',
  ],
  'manualArrangement': ['Eigene Anordnung verwenden', 'Use my arrangement'],
  'arrangementHint': [
    'Für diese Verfügbarkeit gibt es keinen Vorschlag mit zwei Tagen Abstand. Passe Tage oder Häufigkeit an oder verwende deine eigene Anordnung.',
    'These available days do not allow a suggestion with two-day spacing. Adjust the days or frequency, or use your own arrangement.',
  ],
  'generate': ['Workouts vorschlagen', 'Suggest workouts'],
  'regenerate': ['Vorschläge neu erstellen', 'Regenerate suggestions'],
  'regenerateHint': [
    'Dies ersetzt die bearbeiteten Vorschläge in diesem Entwurf. Bereits gespeicherte Workouts bleiben erhalten.',
    'This replaces edited suggestions in this draft. Saved workouts are kept.',
  ],
  'reviewWorkouts': ['Workouts prüfen', 'Review workouts'],
  'estimated': ['Geschätzte Dauer', 'Estimated duration'],
  'warmupReserve': [
    'Aufwärmen und Vorbereitung: 5 min eingeplant',
    'Warm-up and preparation: 5 min included',
  ],
  'restSeconds': ['Satzpause (Sekunden)', 'Rest between sets (seconds)'],
  'restError': ['Gib 0 bis 600 Sekunden ein.', 'Enter 0 to 600 seconds.'],
  'missingEquipmentFor': [
    'Keine passende Übung mit deiner Ausstattung:',
    'No suitable exercise with your equipment:',
  ],
  'missingTimeFor': [
    'Passt noch nicht ins Zeitbudget:',
    'Does not fit the time budget yet:',
  ],
  'acceptReduced': [
    'Diese reduzierte Variante bewusst übernehmen',
    'Use this reduced version',
  ],
  'reviewRequired': [
    'Prüfe die offenen Punkte in den Workout-Vorschlägen.',
    'Review the open points in the workout suggestions.',
  ],
  'runningTransition': [
    'Möchtest du jetzt Laufen einrichten?',
    'Would you like to set up running now?',
  ],
  'strengthPrepared': [
    'Dein Kraftplan ist vorbereitet.',
    'Your strength plan is prepared.',
  ],
  'configureRunning': ['Laufen einrichten', 'Set up running'],
  'skipSport': ['Diesen Sport später einrichten', 'Set up this activity later'],
  'continueWithoutRunning': [
    'Jetzt ohne Laufen fortfahren',
    'Continue without running for now',
  ],
  'emptyPlanHint': [
    'Noch kein Sportteil ist fertig. Deine Antworten bleiben gespeichert.',
    'No activity is ready yet. Your answers are saved.',
  ],
  'dragHint': ['Gedrückt halten zum Verschieben', 'Hold to move'],
  'workoutPreview': ['Workout-Vorschau', 'Workout preview'],
  'replaceWorkout': ['Workout ersetzen', 'Replace workout'],
  'swapDates': ['Termine tauschen', 'Swap dates'],
  'changePlan': ['Planung bearbeiten', 'Edit scheduling'],
  'moved': ['Einheit verschoben', 'Session moved'],
  'undoMove': ['Rückgängig', 'Undo'],
};
