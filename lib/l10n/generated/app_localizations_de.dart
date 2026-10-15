// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Trainy';

  @override
  String get systemLanguage => 'System';

  @override
  String get german => 'Deutsch';

  @override
  String get english => 'English';

  @override
  String get language => 'Sprache';

  @override
  String get home => 'Start';

  @override
  String get exercises => 'Übungen';

  @override
  String get progress => 'Fortschritt';

  @override
  String get progressDescription => 'Verfolge deinen Trainingsfortschritt. Im Verlauf siehst du alle absolvierten Workouts, in Insights findest du Kalender und Übungsdiagramme.';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsDescription => 'Passe Trainy an deine Bedürfnisse an, setze Wochenziele und sichere deine Daten in der Cloud.';

  @override
  String get more => 'Mehr';

  @override
  String get workouts => 'Workouts';

  @override
  String get workout => 'Workout';

  @override
  String get exercise => 'Übung';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get create => 'Erstellen';

  @override
  String get close => 'Schließen';

  @override
  String get done => 'Fertig';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get info => 'Info';

  @override
  String get back => 'Zurück';

  @override
  String get next => 'Weiter';

  @override
  String get search => 'Suchen';

  @override
  String get clear => 'Leeren';

  @override
  String get change => 'Ändern';

  @override
  String get appearance => 'Darstellung';

  @override
  String get designMode => 'Design-Modus';

  @override
  String get system => 'System';

  @override
  String get light => 'Hell';

  @override
  String get dark => 'Dunkel';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get goals => 'Ziele';

  @override
  String get trainingDays => 'Trainingstage';

  @override
  String get trainingDaysPerWeek => 'Trainingstage pro Woche';

  @override
  String get weeklyGoal => 'Wochenziel';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get weekOverview => 'Wochenübersicht';

  @override
  String get todayWorkout => 'Heutiges Training';

  @override
  String trainingForDay(String day) {
    return '$day-Training';
  }

  @override
  String get restDay => 'Ruhetag';

  @override
  String get trainingPlan => 'Trainingsplan';

  @override
  String workoutsInARow(int count) {
    return '$count Trainings in Folge';
  }

  @override
  String workoutsCount(int count) {
    return '$count Workout(s)';
  }

  @override
  String exercisesCount(int count) {
    return '$count Übung(en)';
  }

  @override
  String get newWorkout => 'Neues Workout';

  @override
  String get workoutName => 'Workout-Name';

  @override
  String get enterWorkoutName => 'Workout-Namen eingeben';

  @override
  String get workoutDetails => 'Workout-Details';

  @override
  String get workoutDuration => 'Workout-Dauer';

  @override
  String get editWorkoutDuration => 'Workout-Dauer bearbeiten';

  @override
  String get editDuration => 'Dauer bearbeiten';

  @override
  String get editSets => 'Sätze bearbeiten';

  @override
  String get editRepetitions => 'Wiederholungen bearbeiten';

  @override
  String get editWeight => 'Gewicht bearbeiten';

  @override
  String get editDistance => 'Entfernung bearbeiten';

  @override
  String get editValue => 'Wert bearbeiten';

  @override
  String addValue(String label) {
    return '$label hinzufügen';
  }

  @override
  String get exampleInteger => 'z. B. 10';

  @override
  String get exampleDecimal => 'z. B. 42.5';

  @override
  String get deleteWorkout => 'Workout löschen?';

  @override
  String deleteWorkoutConfirmation(String name) {
    return '\"$name\" endgültig löschen?';
  }

  @override
  String get renameWorkout => 'Workout umbenennen';

  @override
  String get noWorkouts => 'Noch keine Workouts';

  @override
  String get createFirstWorkout => 'Erstelle Workouts, füge Übungen hinzu und tracke deinen Fortschritt.';

  @override
  String get createWorkout => 'Workout erstellen';

  @override
  String get addExercises => 'Übungen hinzufügen';

  @override
  String get noExercises => 'Noch keine Übungen';

  @override
  String get createFirstExercise => 'Lege deine erste Übung an, um zu starten.';

  @override
  String get newExercise => 'Neue Übung';

  @override
  String get editExercise => 'Übung bearbeiten';

  @override
  String get exerciseName => 'Übungsname';

  @override
  String get description => 'Beschreibung';

  @override
  String get optional => 'optional';

  @override
  String get exerciseGoal => 'Trainingsziel';

  @override
  String get standard => 'Standard';

  @override
  String get catalog => 'Katalog';

  @override
  String get own => 'Eigen';

  @override
  String get reviewDuplicates => 'Dubletten prüfen';

  @override
  String get noDuplicateSuggestions => 'Keine Dublettenvorschläge';

  @override
  String get adoptStandardExercise => 'Standardübung verwenden';

  @override
  String get keepOwnExercise => 'Eigene Übung behalten';

  @override
  String get catalogUnavailable => 'Der geprüfte Offline-Katalog ist in diesem Build noch nicht enthalten.';

  @override
  String get catalogExerciseAdded => 'Übung wurde zur Bibliothek hinzugefügt';

  @override
  String get exerciseArchived => 'Übung archiviert; der Trainingsverlauf bleibt unverändert';

  @override
  String get archive => 'Archivieren';

  @override
  String get undo => 'Rückgängig';

  @override
  String get trainingProfile => 'Trainingsprofil';

  @override
  String get workoutVariant => 'Workout-Variante';

  @override
  String get standardVariant => 'Standard';

  @override
  String get createVariant => 'Variante erstellen';

  @override
  String get variantName => 'Variantenname';

  @override
  String get editWorkoutPlan => 'Plan bearbeiten';

  @override
  String get workoutGroup => 'Workout-Gruppe';

  @override
  String get groupVariant => 'Gruppenvariante';

  @override
  String get addGroup => 'Gruppe hinzufügen';

  @override
  String get groupName => 'Gruppenname';

  @override
  String get addGroupVariant => 'Gruppenvariante hinzufügen';

  @override
  String get alternatives => 'Alternativen';

  @override
  String get addAlternative => 'Alternativen hinzufügen';

  @override
  String get core => 'Kern';

  @override
  String get planExercises => 'Übungen in dieser Variante';

  @override
  String get noGroupExercises => 'Diese Gruppenvariante enthält noch keine Übungen.';

  @override
  String get noProfiles => 'Kein Profil ausgewählt';

  @override
  String get profileName => 'Profilname';

  @override
  String get equipment => 'Equipment';

  @override
  String get equipmentBodyweight => 'Körpergewicht';

  @override
  String get equipmentDumbbell => 'Kurzhanteln';

  @override
  String get equipmentBarbell => 'Langhantel';

  @override
  String get equipmentMachine => 'Maschine';

  @override
  String get equipmentCable => 'Kabelzug';

  @override
  String get equipmentKettlebell => 'Kettlebell';

  @override
  String get equipmentBands => 'Widerstandsbänder';

  @override
  String get bodyweight => 'Körpergewicht';

  @override
  String get setsAndDuration => 'Sätze + Dauer';

  @override
  String get nameRequired => 'Bitte einen Namen eingeben';

  @override
  String get searchExercises => 'Übungen durchsuchen';

  @override
  String get tracking => 'Tracking';

  @override
  String get sets => 'Sätze';

  @override
  String setsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sätze',
      one: '1 Satz',
    );
    return '$_temp0';
  }

  @override
  String get repetitions => 'Wiederholungen';

  @override
  String get weight => 'Gewicht';

  @override
  String get duration => 'Dauer';

  @override
  String get estimatedDurationMinutes => 'Geschätzte Dauer (Minuten)';

  @override
  String get distance => 'Entfernung';

  @override
  String get hours => 'Std';

  @override
  String get minutes => 'Min';

  @override
  String get seconds => 'Sek';

  @override
  String get start => 'Start';

  @override
  String get continueWorkout => 'Fortsetzen';

  @override
  String get endWorkout => 'Workout beenden';

  @override
  String get stopAndSave => 'Stoppen & speichern';

  @override
  String get workoutCompleted => 'Workout abgeschlossen!';

  @override
  String get addSet => 'Satz hinzufügen';

  @override
  String get saveSet => 'Satz speichern';

  @override
  String get noSetsRecorded => 'Keine Sätze erfasst.';

  @override
  String get endAnyway => 'Trotzdem beenden';

  @override
  String get backdateWorkout => 'Workout nachtragen';

  @override
  String workoutBackdated(String date) {
    return 'Workout für $date nachgetragen';
  }

  @override
  String get activity => 'Aktivität';

  @override
  String get workoutsPerDay => 'Workouts pro Tag';

  @override
  String get noEntries => 'Noch keine Einträge';

  @override
  String get startWorkoutToSeeEntries => 'Starte ein Workout und erfasse Sätze, dann erscheinen sie hier.';

  @override
  String get calendar => 'Kalender';

  @override
  String get cloudBackup => 'Cloud-Backup';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get signOut => 'Abmelden';

  @override
  String get automaticBackup => 'Automatische Sicherung';

  @override
  String get backupNow => 'Jetzt sichern';

  @override
  String get loadFromCloud => 'Aus Cloud laden';

  @override
  String get backupLoaded => 'Backup geladen';

  @override
  String get backupUploaded => 'Backup hochgeladen';

  @override
  String get backupRestored => 'Backup wiederhergestellt';

  @override
  String get backUp => 'Sichern';

  @override
  String get load => 'Laden';

  @override
  String get merge => 'Zusammenführen';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get restoreBackup => 'Backup wiederherstellen?';

  @override
  String get restoreBackupDescription => 'Lokale Daten werden durch das Cloud-Backup ersetzt.';

  @override
  String get signedInSuccessfully => 'Anmeldung erfolgreich';

  @override
  String get merged => 'Zusammengeführt';

  @override
  String get lowContrast => 'Deine Akzentfarbe hat wenig Kontrast in diesem Modus.';

  @override
  String get error => 'Fehler';

  @override
  String get understood => 'Verstanden';

  @override
  String get history => 'Verlauf';

  @override
  String get insights => 'Insights';

  @override
  String get minutesPerDay => 'Minuten pro Tag';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String workoutsRecordedOnDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Workouts aufgezeichnet',
      one: '1 Workout aufgezeichnet',
      zero: 'Keine Workouts',
    );
    return '$_temp0';
  }

  @override
  String activeWorkoutBanner(String name) {
    return 'Aktives Workout: $name. Tippe zum Fortsetzen.';
  }

  @override
  String get deleteEntry => 'Eintrag löschen?';

  @override
  String get deleteEntryDescription => 'Dieser Trainingseintrag wird unwiderruflich gelöscht.';

  @override
  String deletedExercise(int id) {
    return 'Gelöschte Übung ($id)';
  }

  @override
  String get notAvailable => 'Nicht mehr vorhanden';

  @override
  String formerName(String name) {
    return 'ehem.: $name';
  }

  @override
  String get greatWork => 'Starke Leistung!';

  @override
  String get recommendation => 'Empfehlung';

  @override
  String get exerciseProgress => 'Übungsfortschritt';

  @override
  String get exerciseDescription => 'Verwalte deine Übungen. Erstelle neue Übungen, bearbeite bestehende und lege fest, welche Metriken du tracken möchtest.';

  @override
  String get editExerciseConfirmationTitle => 'Übung bearbeiten?';

  @override
  String get editExerciseConfirmation => 'Änderungen wirken sich auf alle Workouts aus, die diese Übung verwenden.';

  @override
  String mergeExercises(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' ($count)',
      zero: '',
    );
    return 'Übungen zusammenführen$_temp0';
  }

  @override
  String get removeEntry => 'Eintrag entfernen?';

  @override
  String removeMergeEntryDescription(String name, String target) {
    return '\"$name\" aus dem Zusammenführungsverlauf entfernen?\n\nDie übertragenen Trainingseinträge bleiben bei \"$target\" erhalten.';
  }

  @override
  String get noOtherExercise => 'Keine andere Übung vorhanden';

  @override
  String mergeInto(String name) {
    return 'In \"$name\" zusammenführen:';
  }

  @override
  String get confirmMerge => 'Zusammenführen?';

  @override
  String mergeDescription(String source, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Trainingseinträge bleiben unverändert.\n',
      one: '1 Trainingseintrag bleibt unverändert.\n',
      zero: '',
    );
    return '\"$target\" künftig statt \"$source\" verwenden?\n\n${_temp0}Du kannst dies später rückgängig machen.';
  }

  @override
  String mergedResult(String source, String target) {
    return '\"$source\" → \"$target\" zusammengeführt';
  }

  @override
  String get mergeHistory => 'Zusammenführungen';

  @override
  String get noMergedExercises => 'Noch keine Übungen zusammengeführt.';

  @override
  String mergedOn(String date) {
    return 'Zusammengeführt am $date';
  }

  @override
  String get newMerge => 'Neue Übung zusammenführen';

  @override
  String get deleteExercise => 'Übung löschen?';

  @override
  String deleteExerciseConfirmation(String name) {
    return '\"$name\" endgültig löschen? Bestehende Trainingsdaten bleiben erhalten.';
  }

  @override
  String deleteExerciseWithEntries(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Trainingseinträge bleiben unverändert.',
      one: '1 Trainingseintrag bleibt unverändert.',
    );
    return '\"$name\" archivieren? $_temp0';
  }

  @override
  String get permanentlyDelete => 'Endgültig löschen';

  @override
  String exerciseDeleted(String name) {
    return '\"$name\" gelöscht';
  }

  @override
  String get noExercisesDescription => 'Lege deine erste Übung an.';

  @override
  String get homeDescription => 'Dein Dashboard auf einen Blick. Hier siehst du deine Wochenübersicht, geplante Workouts und kannst direkt ein Training starten.';

  @override
  String get noExercisesInWorkout => 'Keine Übungen im Workout';

  @override
  String get getStarted => 'Los geht\'s';

  @override
  String get firstWorkout => 'Erstes Workout erstellen';

  @override
  String get noWorkoutsAvailable => 'Keine Workouts vorhanden';

  @override
  String get selectWorkout => 'Workout auswählen';

  @override
  String get trained => 'trainiert';

  @override
  String get planned => 'geplant';

  @override
  String get noTrackingFieldsActive => 'Keine Felder zum Tracken aktiviert.';

  @override
  String get saveRecordedSets => 'Die erfassten Sätze werden gespeichert.';

  @override
  String get endWithoutSets => 'Keine Sätze erfasst. Trotzdem beenden?';

  @override
  String get weightKilograms => 'Gewicht (kg)';

  @override
  String get distanceKilometers => 'Entfernung (km)';

  @override
  String get allExercisesAlreadyInWorkout => 'Alle Übungen sind bereits im Workout';

  @override
  String get addExercise => 'Übung hinzufügen';

  @override
  String get pause => 'Pausieren';

  @override
  String recordedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sätze erfasst',
      one: '1 Satz erfasst',
    );
    return '$_temp0';
  }

  @override
  String setNumber(int number) {
    return 'Satz $number';
  }

  @override
  String workoutCreatedAndAdded(String name) {
    return '\"$name\" wurde erstellt und hinzugefügt';
  }

  @override
  String get nameMissing => 'Name fehlt';

  @override
  String get enterName => 'Bitte einen Namen eingeben';

  @override
  String get addExistingExercises => 'Vorhandene';

  @override
  String get createNewExercise => 'Neu erstellen';

  @override
  String get addSelected => 'Ausgewählte hinzufügen';

  @override
  String get exercisesAdded => 'Übungen hinzugefügt';

  @override
  String get remove => 'Entfernen';

  @override
  String get additionalExercises => 'Weitere Übungen hinzufügen';

  @override
  String get addExercisesToStart => 'Füge Übungen hinzu, um dein Workout zu starten.';

  @override
  String get rename => 'Umbenennen';

  @override
  String get apply => 'Übernehmen';

  @override
  String get cloudBackupFound => 'Cloud-Backup gefunden';

  @override
  String get cloudBackupDescription => 'Sichere deine Daten in der Cloud.';

  @override
  String get setUpCloudBackup => 'Cloud-Backup einrichten?';

  @override
  String get setUpCloudBackupDescription => 'Du kannst dich anmelden, um deine Trainingsdaten sicher in der Cloud zu sichern und zwischen Geräten zu synchronisieren. Das ist optional; die App bleibt Local-First.';

  @override
  String get continueWithoutCloud => 'Ohne Cloud fortfahren';

  @override
  String get cloudBackupAccountFoundDescription => 'Es gibt bereits ein Cloud-Backup für diesen Account. Wie möchtest du fortfahren?';

  @override
  String get doNotLoad => 'Nicht laden';

  @override
  String get loadAndReplace => 'Backup laden (ersetzen)';

  @override
  String get mergeRecommended => 'Zusammenführen (empfohlen)';

  @override
  String get cloudOverwrite => 'Cloud überschreiben?';

  @override
  String get cloudOverwriteDescription => 'Alle alten Daten des Cloud-Backups gehen verloren. Fortfahren?';

  @override
  String get overwrite => 'Überschreiben';

  @override
  String get cloudBackupUpdated => 'Cloud-Backup aktualisiert';

  @override
  String get quoteOfTheDay => 'Spruch des Tages';

  @override
  String motivationalQuote(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'start': 'Du musst nicht perfekt sein. Du musst nur anfangen.',
        'consistency': 'Konsistenz schlägt Talent.',
        'strength': 'Du bist stärker als du denkst.',
        'progress': 'Fortschritt, nicht Perfektion.',
        'habit': 'Motivation bringt dich in Gang. Gewohnheit bringt dich ans Ziel.',
        'challenge': 'Wenn es dich nicht herausfordert, verändert es dich nicht.',
        'smallSteps': 'Kleine Schritte sind besser als keine Schritte.',
        'effort': 'Jedes Training zählt — auch das, auf das du keine Lust hattest.',
        'discipline': 'Disziplin ist die Brücke zwischen Zielen und Ergebnissen.',
        'today': 'Was du heute tust, entscheidet, wer du morgen bist.',
        'routine': 'Die beste Zeit zu trainieren ist die, die du einhältst.',
        'limits': 'Du bist dein einziges Limit.',
        'other': 'Weiter so.',
      },
    );
    return '$_temp0';
  }

  @override
  String get signedIn => 'angemeldet';

  @override
  String lastBackup(String date) {
    return 'Letzte Sicherung: $date';
  }

  @override
  String get cloudBackupFoundDescription => 'Ein vorhandenes Backup wurde gefunden.';

  @override
  String get loadBackup => 'Backup laden';

  @override
  String get genericError => 'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get backupRestoredSuccess => 'Wiederhergestellt';

  @override
  String workoutDeleted(String name) {
    return '\"$name\" gelöscht';
  }

  @override
  String dayStatus(String day, String status) {
    return '$day: $status';
  }

  @override
  String get addExercisesForProgress => 'Lege zuerst Übungen an, um Fortschritt zu sehen.';

  @override
  String get completeWorkoutForProgress => 'Absolviere ein Workout, um Fortschrittsdaten zu sehen.';

  @override
  String get selectExercise => 'Übung auswählen';

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String get searchExercise => 'Nach Übung suchen';

  @override
  String get noTrackingFields => 'Keine Felder zum Tracken';

  @override
  String get noDataForExercise => 'Noch keine Daten für diese Übung.';

  @override
  String get exerciseLabel => 'Übung';

  @override
  String get volume => 'Volumen';

  @override
  String get minimum => 'Min';

  @override
  String get maximum => 'Max';

  @override
  String get speed => 'Geschw.';

  @override
  String get allTime => 'Alle';

  @override
  String get month1 => '1M';

  @override
  String get month3 => '3M';

  @override
  String get month6 => '6M';

  @override
  String get year1 => '1J';

  @override
  String get monday => 'Mo';

  @override
  String get tuesday => 'Di';

  @override
  String get wednesday => 'Mi';

  @override
  String get thursday => 'Do';

  @override
  String get friday => 'Fr';

  @override
  String get saturday => 'Sa';

  @override
  String get sunday => 'So';

  @override
  String goalLabel(String goal) {
    String _temp0 = intl.Intl.selectLogic(
      goal,
      {
        'strength': 'Kraft',
        'endurance': 'Ausdauer',
        'cardio': 'Cardio',
        'mobility': 'Mobilität',
        'other': 'Sonstiges',
      },
    );
    return '$_temp0';
  }

  @override
  String standardExerciseName(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'kraft_bankdruecken': 'Bankdrücken',
        'kraft_kniebeugen': 'Kniebeugen',
        'kraft_kreuzheben': 'Kreuzheben',
        'kraft_schulterdruecken': 'Schulterdrücken',
        'kraft_langhantelrudern': 'Langhantelrudern',
        'kraft_bizeps_curls': 'Bizeps-Curls',
        'kraft_trizepsdruecken': 'Trizepsdrücken',
        'kraft_beinpresse': 'Beinpresse',
        'kraft_ausfallschritte': 'Ausfallschritte',
        'kraft_wadenheben': 'Wadenheben',
        'kraft_russian_twist': 'Russian Twist',
        'kraft_latzug': 'Latzug',
        'kraft_butterfly': 'Butterfly',
        'kraft_beinbeuger': 'Beinbeuger',
        'kraft_beinstrecker': 'Beinstrecker',
        'kraft_seitheben': 'Seitheben',
        'kraft_facepulls': 'Facepulls',
        'kraft_brustpresse': 'Brustpresse',
        'kraft_hip_thrusts': 'Hip Thrusts',
        'kraft_reverse_flys': 'Reverse Flys',
        'kraft_bulgarian_split_squats': 'Bulgarian Split Squats',
        'kraft_klimmzuege': 'Klimmzüge',
        'kraft_liegestuetze': 'Liegestütze',
        'kraft_dips': 'Dips',
        'kraft_sit_ups': 'Sit-ups',
        'kraft_push_ups': 'Push-ups',
        'kraft_pull_ups': 'Pull-ups',
        'cardio_joggen': 'Joggen',
        'cardio_laufen': 'Laufen',
        'cardio_radfahren': 'Radfahren',
        'cardio_intervallaeufe': 'Intervallläufe',
        'cardio_schwimmen': 'Schwimmen',
        'ausdauer_plank': 'Plank',
        'ausdauer_seilspringen': 'Seilspringen',
        'mobilitaet_dehnen': 'Dehnen',
        'mobilitaet_yoga': 'Yoga',
        'other': 'Übung',
      },
    );
    return '$_temp0';
  }
}
