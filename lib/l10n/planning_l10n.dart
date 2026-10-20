import 'package:flutter/widgets.dart';
import 'plan_l10n.dart';

/// Copy for the serial profile flow and shared training calendar.
extension PlanningL10n on BuildContext {
  String planning(String key) {
    final values = _copy[key];
    return values == null
        ? plan(key)
        : values[Localizations.localeOf(this).languageCode == 'de' ? 0 : 1];
  }
}

const _copy = <String, List<String>>{
  'restDay': ['Ruhetag', 'Rest day'],
  'runningProfile': ['Laufprofil', 'Running profile'],
  'strengthProfile': ['Kraftprofil', 'Strength profile'],
  'paceLimit': ['Nicht schneller als', 'No faster than'],
  'referenceOtherQuestion': [
    'Wie lange brauchst du für diese Strecke?',
    'How long does this distance take you?',
  ],
  'advancedReason': [
    'Deine bestätigte Laufpraxis erlaubt gezielte Reize mit überwiegend lockeren Einheiten.',
    'Your established training supports targeted sessions alongside mostly easy running.',
  ],
  'chooseTraining': [
    'Was möchtest du in deinen Trainingsplan aufnehmen?',
    'What would you like in your training plan?',
  ],
  'answerRequired': ['Bitte wähle eine Antwort.', 'Please choose an answer.'],
  'profileRequired': [
    'Vervollständige zuerst dein Sportprofil.',
    'Complete your sport profile first.',
  ],
  'confirmProfile': ['Profil bestätigen', 'Confirm profile'],
  'experienceQuestion': [
    'Seit wann läufst du regelmäßig?',
    'How long have you been running regularly?',
  ],
  'newRunner': ['Ich fange gerade an', 'I am just starting'],
  'twoMonths': ['Weniger als 6 Monate', 'Less than 6 months'],
  'sixMonths': ['6 Monate bis 2 Jahre', '6 months to 2 years'],
  'twoYears': ['Mindestens 2 Jahre', 'At least 2 years'],
  'returning': [
    'Wiedereinstieg nach langer Pause',
    'Returning after a long break',
  ],
  'continuousQuestion': [
    'Wie lange kannst du locker am Stück laufen?',
    'How long can you run comfortably without stopping?',
  ],
  'continuousHelp': [
    'Ohne Gehpausen, in einem Tempo, in dem du dich unterhalten kannst. Auch 0 ist möglich.',
    'Without walking, at a pace where you can hold a conversation. Zero is fine.',
  ],
  'frequencyQuestion': [
    'Wie oft bist du zuletzt pro Woche gelaufen?',
    'How often have you been running each week?',
  ],
  'volumeQuestion': [
    'Wie viel bist du zuletzt pro Woche gelaufen?',
    'How far have you been running each week?',
  ],
  'volumeHelp': [
    'Grob geschätzt genügt. Gemeint ist dein bisheriger Umfang, nicht dein Ziel.',
    'An estimate is enough. This is your recent training, not your goal.',
  ],
  'volume0': ['Noch nicht regelmäßig', 'Not regularly yet'],
  'volume5': ['Unter 10 km', 'Under 10 km'],
  'volume15': ['10–19 km', '10–19 km'],
  'volume30': ['20–39 km', '20–39 km'],
  'volume50': ['40–59 km', '40–59 km'],
  'volume70': ['60 km oder mehr', '60 km or more'],
  'referenceQuestion': [
    'Wie lange brauchst du für 5 km?',
    'How long does 5 km take you?',
  ],
  'referenceHelp': [
    'Minuten reichen, z. B. 45 oder 45:30. Gehpausen zählen mit.',
    'Enter minutes, e.g. 45 or 45:30. Include walking breaks.',
  ],
  'otherDistance': ['Andere Strecke', 'Different distance'],
  'referenceKindQuestion': [
    'Was beschreibt diese Zeit?',
    'What kind of effort was this?',
  ],
  'normalReference': ['Normaler Trainingslauf', 'Normal training run'],
  'walkReference': ['Lauf mit Gehpausen', 'Run with walking breaks'],
  'maximalReference': ['Schnellstmöglicher Lauf', 'Best possible effort'],
  'estimatedHelp': [
    'Tempo-Orientierung, keine Wettkampfprognose. Locker bedeutet: entspannt sprechen können.',
    'Pace guidance, not a race prediction. Easy means you can talk comfortably.',
  ],
  'longestQuestion': [
    'Dein längster Lauf in den letzten vier Wochen?',
    'Your longest run in the last four weeks?',
  ],
  'longestHelp': [
    'Optional. Damit steigern wir den längeren Lauf nicht allein anhand deiner Geschwindigkeit.',
    'Optional. This keeps long runs based on recent training, not just speed.',
  ],
  'restPulseQuestion': [
    'Kennst du deinen Ruhepuls?',
    'Do you know your resting heart rate?',
  ],
  'maxPulseQuestion': [
    'Kennst du deinen Maximalpuls?',
    'Do you know your maximum heart rate?',
  ],
  'pulseOptional': [
    'Optional · leer lassen, wenn unbekannt.',
    'Optional · leave empty if unknown.',
  ],
  'profileReview': ['Dein Laufprofil', 'Your running profile'],
  'baseReason': [
    'Wir beginnen locker, damit sich auch Sehnen und Gelenke schrittweise an die Belastung gewöhnen können.',
    'We start gently so tendons and joints can gradually adapt to running.',
  ],
  'beginnerReason': [
    'Du kannst bereits durchlaufen. Dein Plan enthält von Anfang an leichte Abwechslung.',
    'You can already run continuously. Your plan includes gentle variety from the start.',
  ],
  'levelMismatch': [
    'Deine Angaben passen noch nicht zum gewählten Level. Prüfe Erfahrung, durchlaufbare Zeit und bisherigen Umfang.',
    'Your answers do not yet match the selected level. Check experience, continuous running time and recent training.',
  ],
  'useSuggestedLevel': ['Passendes Level verwenden', 'Use suggested level'],
  'trainingPlace': ['Wo trainierst du?', 'Where do you train?'],
  'equipmentQuestion': [
    'Welche Geräte stehen dir zur Verfügung?',
    'What equipment is available?',
  ],
  'homeSuggestion': [
    'Vorschlag · bitte bestätigen',
    'Suggested · please confirm',
  ],
  'equipmentConfirm': ['Geräte bestätigen', 'Confirm equipment'],
  'strengthOverlap': [
    'Ähnlicher Kraftfokus am selben Tag. Prüfe, ob du beide Einheiten möchtest.',
    'Similar strength focus on the same day. Check whether you want both sessions.',
  ],
  'weekTitle': ['Woche', 'Week'],
  'currentWeek': ['Diese Woche', 'This week'],
  'startStreak': ['Starte deine Serie', 'Start your streak'],
  'streakSuffix': ['Trainingstage in Folge', 'training days in a row'],
  'previousWeek': ['Vorherige Woche', 'Previous week'],
  'nextWeek': ['Nächste Woche', 'Next week'],
  'moreWeeks': ['Weitere Wochen', 'More weeks'],
  'earlierWeeks': ['Frühere Wochen', 'Earlier weeks'],
  'profiles': ['Sportprofile', 'Sport profiles'],
  'historySuggestion': [
    'Aus deinem Verlauf vorgeschlagen',
    'Suggested from your history',
  ],
  'normalDurationError': [
    'Gib eine Zeit über 0 ein, z. B. 45 oder 45:30.',
    'Enter a time above 0, e.g. 45 or 45:30.',
  ],
  'nonNegativeError': [
    'Gib eine ganze Zahl ab 0 ein.',
    'Enter a whole number of 0 or more.',
  ],
  'bestOptional': ['Zusätzliche Bestzeit', 'Additional best effort'],
};
