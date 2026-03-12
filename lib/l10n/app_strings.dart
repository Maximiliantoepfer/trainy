import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

/// Lightweight localization: access via `S.of(context)`.
class S {
  final String locale; // 'de' or 'en'
  const S._(this.locale);

  static S of(BuildContext context) {
    final code = context.watch<LocaleProvider>().locale;
    return S._(code);
  }

  /// Helper for non-watch contexts (e.g. inside callbacks)
  static S read(BuildContext context) {
    final code = context.read<LocaleProvider>().locale;
    return S._(code);
  }

  bool get _de => locale == 'de';

  // ── Navigation & Screen Titles ──────────────────────────────
  String get workouts => 'Workouts';
  String get exercises => _de ? 'Übungen' : 'Exercises';
  String get progress => _de ? 'Fortschritt' : 'Progress';
  String get settings => _de ? 'Einstellungen' : 'Settings';
  String get insights => 'Insights';
  String get workoutDetails => _de ? 'Workout-Details' : 'Workout Details';

  // ── Buttons – Create / Add ──────────────────────────────────
  String get createAndAdd => _de ? 'Erstellen & hinzufügen' : 'Create & add';
  String get add => _de ? 'Hinzufügen' : 'Add';
  String get addMoreExercises => _de ? 'Weitere Übungen hinzufügen' : 'Add more exercises';
  String get addExercises => _de ? 'Übungen hinzufügen' : 'Add exercises';
  String get create => _de ? 'Erstellen' : 'Create';
  String get createExercise => _de ? 'Übung anlegen' : 'Create exercise';
  String get newLabel => _de ? 'Neu' : 'New';

  // ── Buttons – Save / Cancel / Delete ────────────────────────
  String get save => _de ? 'Speichern' : 'Save';
  String get cancel => _de ? 'Abbrechen' : 'Cancel';
  String get delete => _de ? 'Löschen' : 'Delete';
  String get apply => _de ? 'Übernehmen' : 'Apply';
  String get ok => 'OK';

  // ── Dialog Titles ───────────────────────────────────────────
  String get newWorkout => _de ? 'Neues Workout' : 'New Workout';
  String get deleteWorkout => _de ? 'Workout löschen?' : 'Delete Workout?';
  String get renameWorkout => _de ? 'Workout umbenennen' : 'Rename Workout';
  String get createExerciseTitle => _de ? 'Übung erstellen' : 'Create Exercise';
  String get editExerciseTitle => _de ? 'Übung bearbeiten' : 'Edit Exercise';
  String get nameMissing => _de ? 'Name fehlt' : 'Name missing';
  String get pleaseEnterName => _de ? 'Bitte einen Namen eingeben' : 'Please enter a name';
  String get endWorkout => _de ? 'Workout beenden' : 'End Workout';
  String get accentColorPicker => _de ? 'Akzentfarbe wählen' : 'Choose accent color';

  // ── Dialog Content ──────────────────────────────────────────
  String deleteWorkoutConfirm(String name) =>
      _de ? '„$name" wird endgültig gelöscht. Fortfahren?' : '"$name" will be permanently deleted. Continue?';
  String get setsWillBeSaved => _de ? 'Die erfassten Sätze werden gespeichert.' : 'Captured sets will be saved.';
  String get noSetsEndAnyway => _de ? 'Keine Sätze erfasst. Trotzdem beenden?' : 'No sets captured. End anyway?';
  String get noTrackingFields =>
      _de
          ? 'Für diese Übung sind keine Felder zum Tracken aktiviert. Aktiviere Sätze/Wdh./Gewicht/Dauer in der Übungsbearbeitung.'
          : 'No tracking fields enabled for this exercise. Enable sets/reps/weight/duration in exercise editing.';

  // ── Form Labels & Hints ─────────────────────────────────────
  String get enterWorkoutName => _de ? 'Workout-Namen eingeben' : 'Enter workout name';
  String get workoutName => _de ? 'Workout-Name' : 'Workout name';
  String get nameRequired => _de ? 'Name *' : 'Name *';
  String get egPlank => _de ? 'z. B. Plank' : 'e.g. Plank';
  String get description => _de ? 'Beschreibung' : 'Description';
  String get setsQuantity => _de ? 'Sätze (Anzahl)' : 'Sets (quantity)';
  String get repetitions => _de ? 'Wiederholungen' : 'Repetitions';
  String get weightKg => _de ? 'Gewicht (kg)' : 'Weight (kg)';
  String get hours => _de ? 'Std' : 'h';
  String get minutes => _de ? 'Min' : 'min';
  String get seconds => _de ? 'Sek' : 'sec';
  String get eg10 => _de ? 'z. B. 10' : 'e.g. 10';
  String get eg425 => _de ? 'z. B. 42.5' : 'e.g. 42.5';
  String get pleaseEnterNameValidator => _de ? 'Bitte Namen eingeben' : 'Please enter a name';
  String get searchExercises => _de ? 'Übungen durchsuchen' : 'Search exercises';
  String get clear => _de ? 'Leeren' : 'Clear';

  // ── Tracking Fields ─────────────────────────────────────────
  String get sets => _de ? 'Sätze' : 'Sets';
  String get reps => _de ? 'Wdh.' : 'Reps';
  String get weight => _de ? 'Gewicht' : 'Weight';
  String get duration => _de ? 'Dauer' : 'Duration';

  // ── Exercise Presets ────────────────────────────────────────
  String get standard => 'Standard';
  String get bodyweight => _de ? 'Körpergewicht' : 'Bodyweight';
  String get setsPlusDuration => _de ? 'Sätze + Dauer' : 'Sets + Duration';

  // ── Exercise Tracking Checklist ─────────────────────────────
  String get countSets => _de ? 'Sätze zählen' : 'Count sets';
  String get eg3Sets => _de ? 'z. B. 3 Sätze' : 'e.g. 3 sets';
  String get eg10PerSet => _de ? 'z. B. 10 pro Satz' : 'e.g. 10 per set';
  String get eg50kg => _de ? 'z. B. 50 kg' : 'e.g. 50 kg';
  String get eg60Seconds => _de ? 'z. B. 60 Sekunden' : 'e.g. 60 seconds';

  // ── Empty States ────────────────────────────────────────────
  String get noWorkoutsYet => _de ? 'Noch keine Workouts' : 'No workouts yet';
  String get createFirstWorkout =>
      _de ? 'Erstelle dein erstes Workout mit dem Plus-Button.' : 'Create your first workout with the plus button.';
  String get noExercisesYet => _de ? 'Noch keine Übungen' : 'No exercises yet';
  String get addExercisesToStart =>
      _de ? 'Füge Übungen hinzu, um dein Workout zu starten.' : 'Add exercises to start your workout.';
  String get createFirstExercise =>
      _de ? 'Lege deine erste Übung an, um zu starten.' : 'Create your first exercise to get started.';
  String get noEntriesYet => _de ? 'Noch keine Einträge' : 'No entries yet';
  String get startWorkoutToSeeEntries =>
      _de
          ? 'Starte ein Workout und erfasse Sätze, dann erscheinen sie hier.'
          : 'Start a workout and track sets, then they\'ll appear here.';

  // ── SnackBar Messages ───────────────────────────────────────
  String deletedSnackbar(String name) => _de ? '„$name" gelöscht' : '"$name" deleted';
  String createdAndAdded(String name) =>
      _de ? '„$name" wurde erstellt und hinzugefügt' : '"$name" was created and added';
  String get exercisesAdded => _de ? 'Übungen hinzugefügt' : 'Exercises added';
  String exerciseCreated(String name) => _de ? 'Übung "$name" angelegt' : 'Exercise "$name" created';
  String exerciseUpdated(String name) => _de ? 'Übung "$name" aktualisiert' : 'Exercise "$name" updated';
  String get valueUpdated => _de ? 'Wert aktualisiert' : 'Value updated';

  // ── Tooltips ────────────────────────────────────────────────
  String get rename => _de ? 'Umbenennen' : 'Rename';
  String get stopAndSave => _de ? 'Stoppen & speichern' : 'Stop & save';
  String get addSet => _de ? 'Satz hinzufügen' : 'Add set';
  String get edit => _de ? 'Bearbeiten' : 'Edit';

  // ── Workout Run ─────────────────────────────────────────────
  String get stop => 'Stop';
  String get start => 'Start';
  String get continueWorkout => _de ? 'Fortsetzen' : 'Continue';
  String get end => _de ? 'Beenden' : 'End';

  // ── Weekly Overview ─────────────────────────────────────────
  String get thisWeek => _de ? 'Diese Woche' : 'This week';
  List<String> get weekdayLabels =>
      _de ? const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ── Metric Detail Edit Dialogs ──────────────────────────────
  String get editSets => _de ? 'Sätze bearbeiten' : 'Edit sets';
  String get editReps => _de ? 'Wiederholungen bearbeiten' : 'Edit repetitions';
  String get editWeight => _de ? 'Gewicht bearbeiten' : 'Edit weight';
  String get editDurationSec => _de ? 'Dauer (Sek.) bearbeiten' : 'Edit duration (sec.)';
  String get editValue => _de ? 'Wert bearbeiten' : 'Edit value';
  String addMetric(String label) => _de ? '$label hinzufügen' : 'Add $label';

  // ── Progress Screen ─────────────────────────────────────────
  String get activity => _de ? 'Aktivität' : 'Activity';
  String get workoutsPerDay => _de ? 'Workouts pro Tag' : 'Workouts per day';
  String workoutDash(String name) => _de ? 'Workout – $name' : 'Workout — $name';
  String totalSetsLabel(int count) => _de ? '$count Sätze' : '$count sets';

  // ── Workout Card ────────────────────────────────────────────
  String exerciseCount(int count) => _de ? '$count Übung(en)' : '$count exercise(s)';
  String deletedExercise(int id) => _de ? 'Gelöschte Übung ($id)' : 'Deleted exercise ($id)';
  String get noLongerAvailable => _de ? 'Nicht mehr vorhanden' : 'No longer available';
  String exerciseLabel(int id) => _de ? 'Übung #$id' : 'Exercise #$id';

  // ── Settings ────────────────────────────────────────────────
  String get appearance => _de ? 'Darstellung' : 'Appearance';
  String get system => 'System';
  String get light => _de ? 'Hell' : 'Light';
  String get dark => _de ? 'Dunkel' : 'Dark';
  String get accentColor => _de ? 'Akzentfarbe' : 'Accent color';
  String get change => _de ? 'Ändern' : 'Change';
  String get goals => _de ? 'Ziele' : 'Goals';
  String get trainingDaysPerWeek => _de ? 'Trainingstage pro Woche' : 'Training days per week';
  String get language => _de ? 'Sprache' : 'Language';
  String get german => 'Deutsch';
  String get english => 'English';

  // ── Cloud Backup ────────────────────────────────────────────
  String get cloudBackup => 'Cloud-Backup';
  String get cloudSignInDescription =>
      _de
          ? 'Melde dich mit Google an, um deine Trainingsdaten sicher in der Cloud zu sichern oder wiederherzustellen.'
          : 'Sign in with Google to securely back up or restore your training data in the cloud.';
  String get signInWithGoogle => _de ? 'Mit Google anmelden' : 'Sign in with Google';
  String signedInAs(String email) => _de ? 'Angemeldet: $email' : 'Signed in: $email';
  String lastBackup(String time) => _de ? 'Letzte Sicherung: $time' : 'Last backup: $time';
  String get automaticBackup => _de ? 'Automatische Sicherung' : 'Automatic backup';
  String get autoBackupDescription =>
      _de
          ? 'Sichert spätestens alle 2 Stunden automatisch – beim App-Start, nach Pause/Fortsetzen und in Intervallen.'
          : 'Backs up automatically every 2 hours at latest — on app start, after pause/resume, and at intervals.';
  String get backupNow => _de ? 'Jetzt sichern' : 'Backup now';
  String get loadFromCloud => _de ? 'Aus Cloud laden' : 'Load from cloud';
  String get signOut => _de ? 'Abmelden' : 'Sign out';
  String get cloudBackupFound => _de ? 'Cloud-Backup gefunden' : 'Cloud backup found';
  String get cloudBackupFoundDescription =>
      _de
          ? 'Ein vorhandenes Cloud-Backup wurde gefunden. Wie möchtest du fortfahren?'
          : 'An existing cloud backup was found. How would you like to proceed?';
  String get mergeRecommended => _de ? 'Zusammenführen (empfohlen)' : 'Merge (recommended)';
  String get loadBackup => _de ? 'Backup laden' : 'Load backup';
  String get overwriteCloud => _de ? 'Cloud überschreiben?' : 'Overwrite cloud?';
  String get overwriteCloudDescription =>
      _de
          ? 'Alle alten Daten des Cloud-Backups gehen verloren. Fortfahren?'
          : 'All old cloud backup data will be lost. Continue?';
  String get yesOverwrite => _de ? 'Ja, überschreiben' : 'Yes, overwrite';
  String get restoreFromCloud => _de ? 'Aus Cloud wiederherstellen?' : 'Restore from cloud?';
  String get restoreFromCloudDescription =>
      _de
          ? 'Dies ersetzt deine lokalen Daten mit dem Cloud-Backup. Fortfahren?'
          : 'This will replace your local data with the cloud backup. Continue?';
  String get yesRestore => _de ? 'Ja, wiederherstellen' : 'Yes, restore';
  String get backupLoaded => _de ? 'Backup geladen' : 'Backup loaded';
  String errorMsg(String e) => _de ? 'Fehler: $e' : 'Error: $e';
  String get mergedWithCloud => _de ? 'Mit Cloud zusammengeführt' : 'Merged with cloud';
  String get signInSuccessful => _de ? 'Anmeldung erfolgreich' : 'Sign-in successful';
  String signInFailed(String e) => _de ? 'Anmeldung fehlgeschlagen: $e' : 'Sign-in failed: $e';
  String get autoBackupEnabled => _de ? 'Automatische Sicherung aktiviert' : 'Automatic backup enabled';
  String get backupUploaded => _de ? 'Backup hochgeladen' : 'Backup uploaded';
  String get backupRestored => _de ? 'Backup wiederhergestellt' : 'Backup restored';
  String get cloudBackupUpdated => _de ? 'Cloud-Backup aktualisiert' : 'Cloud backup updated';

  // ── Onboarding ──────────────────────────────────────────────
  String get setupCloudBackup => _de ? 'Cloud-Backup einrichten?' : 'Set up cloud backup?';
  String get onboardingCloudDescription =>
      _de
          ? 'Du kannst dich anmelden, um deine Trainingsdaten sicher in der Cloud zu sichern und zwischen Geräten zu synchronisieren. Das ist optional (Local-First).'
          : 'You can sign in to securely back up your training data in the cloud and sync between devices. This is optional (local-first).';
  String get continueWithoutCloud => _de ? 'Ohne Cloud fortfahren' : 'Continue without cloud';
  String get dontLoad => _de ? 'Nicht laden' : 'Don\'t load';
  String get loadBackupReplace => _de ? 'Backup laden (ersetzen)' : 'Load backup (replace)';
  String get onboardingBackupFound =>
      _de
          ? 'Es gibt bereits ein Cloud-Backup für diesen Account. Wie möchtest du fortfahren?'
          : 'There is already a cloud backup for this account. How would you like to proceed?';

  // ── Progress Chart ──────────────────────────────────────────
  String get exerciseProgress => 'Exercise-Progress';
  String get createExercisesToSeeProgress =>
      _de ? 'Lege zuerst Übungen an, um Fortschritt zu sehen.' : 'Create exercises first to see progress.';
  String get exercise => _de ? 'Übung' : 'Exercise';
  String get noDataForExercise =>
      _de ? 'Noch keine Daten für diese Übung.' : 'No data for this exercise yet.';
  String get selectExercise => _de ? 'Übung auswählen' : 'Select exercise';
  String get searchForExercise => _de ? 'Nach Übung suchen' : 'Search for exercise';
  String get noMatches => _de ? 'Keine Treffer' : 'No matches';

  // ── Calendar ────────────────────────────────────────────────
  List<String> get monthNames =>
      _de
          ? const ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']
          : const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  // ── Existing tab labels ─────────────────────────────────────
  String get existing => _de ? 'Vorhandene' : 'Existing';
  String get createNew => _de ? 'Neu erstellen' : 'Create new';
}
