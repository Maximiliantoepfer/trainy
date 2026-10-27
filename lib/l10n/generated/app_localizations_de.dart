// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String forecastText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'k_title': 'Deine nächsten Wochen',
        'k_hint': 'Der Aufbau steht bereits fest. Pace-Ziele sind vorläufig und werden anhand geeigneter Trainings neu berechnet. Änderungen übernimmst du mit einer Bestätigung.',
        'k_provisional': 'Pace vorläufig',
        'k_recommendation': 'Dein Plan kann sich anpassen',
        'k_review': 'Vorschlag ansehen',
        'k_later': 'Später',
        'k_week': 'Woche',
        'k_applied': 'Plan aktualisiert',
        'k_before': 'Bisher',
        'k_after': 'Vorschlag',
        'k_stale': 'Der Plan oder deine Trainingsdaten haben sich geändert. Bitte prüfe den aktualisierten Vorschlag.',
        'k_structure': 'Die Belastungen lassen sich besser verteilen. Ein passender Qualitätsschwerpunkt ergänzt deine lockeren Läufe; Die Trainingszeit steigt nicht; Termine bleiben erhalten.',
        'k_qualityScheduleConflict': 'An diesen Tagen bleibt kein passender Platz für einen Qualitätsschwerpunkt. Wähle andere Lauftage, wenn du mehr Abwechslung möchtest.',
        'k_continuous': 'Bist du ohne Geh- oder Stehpausen durchgelaufen?',
        'k_healthEvidence': 'Bestätigte Health-Trainings fließen ein. Für Pace-Vorschläge brauchen wir zusätzlich deine Rückmeldung und eine verlässliche Distanz und Laufdauer.',
        'k_noRecommendation': 'Dein Plan bleibt aktuell passend. Neue Trainings werden automatisch geprüft.',
        'k_feedback': 'Lauf kurz bewerten',
        'k_feedbackHint': 'Deine Rückmeldung hilft, die nächsten Pace-Ziele passend vorzuschlagen.',
        'k_recovery': 'Entlastung',
        'k_taper': 'Wettkampfvorbereitung',
        'k_base': 'Aufbau',
        'k_build': 'Training',
        'k_retry': 'Erneut prüfen',
        'k_unavailable': 'Empfehlungen konnten nicht aktualisiert werden. Dein gespeicherter Plan bleibt verfügbar.',
        'other': '$key',
      },
    );
    return '$_temp0';
  }

  @override
  String runningText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'k_goal': 'Was möchtest du beim Laufen erreichen?',
        'k_runFaster': 'Tempo verbessern',
        'k_runFurther': 'Grundlagenausdauer verbessern',
        'k_firstDistance': 'Eine Distanz schaffen',
        'k_complaints': 'Hast du aktuell Beschwerden oder ärztliche Einschränkungen?',
        'k_none': 'Keine',
        'k_pain': 'Beschwerden beim Training',
        'k_medical': 'Ärztliche Einschränkung',
        'k_restrictedTraining': 'Bei Beschwerden oder ärztlichen Einschränkungen stellen wir fordernde Vorschläge zurück. Bitte kläre, welche Belastung für dich geeignet ist. Dies ist keine Diagnose.',
        'k_walkMinutes': 'Wie viele Minuten kannst du beschwerdefrei gehen?',
        'k_walkPreparation': 'Möchtest du zunächst mit Gehen beginnen?',
        'k_yes': 'Ja',
        'k_no': 'Nein',
        'k_weeklyMinutes': 'Wie viele Minuten bist du zuletzt pro Woche gelaufen?',
        'k_unknown': 'Weiß ich nicht',
        'k_longestMinutes': 'Wie lange war dein längster Lauf der letzten 30 Tage?',
        'k_longestDate': 'Wann war dieser Lauf?',
        'k_longestEffort': 'Wie anstrengend war dieser Lauf (1–10)?',
        'k_desiredDays': 'Wie oft möchtest du pro Woche laufen?',
        'k_availableDays': 'An welchen Tagen kannst du laufen?',
        'k_minutesPerSession': 'Wie viele Minuten hast du insgesamt pro Einheit?',
        'k_timeBudgetHint': 'Einschließlich Aufwärmen und Auslaufen. Einzelne Tage kannst du anschließend anpassen.',
        'k_hardTrainingDays': 'An welchen Tagen trainierst du zusätzlich anstrengend, besonders Beine?',
        'k_highLoadTolerated': 'Verträgst du bereits regelmäßig mindestens fünf Lauftage gut?',
        'k_pulseSource': 'Wie misst du deinen Puls?',
        'k_watch': 'Optische Uhr',
        'k_chest': 'Brustgurt-Aufzeichnung',
        'k_diagnostic': 'Leistungsdiagnostik',
        'k_zoneMethod': 'Wie möchtest du deine Pulszonen festlegen?',
        'k_karvonen': 'Karvonen-Schätzung',
        'k_manual': 'Eigene Grenzen',
        'k_zoneBoundary': 'Pulsgrenze',
        'k_manualZoneHint': 'Sechs aufsteigende Grenzen bilden fünf Zonen. Deine eigenen Grenzen haben Vorrang. Keine Live-Pulsmessung.',
        'k_routePreference': 'Wie möchtest du deine Läufe planen?',
        'k_time': 'Nach Zeit',
        'k_distance': 'Bevorzugte Strecke; Dauer bleibt begrenzt',
        'k_walkBreaks': 'Möchtest du Gehpausen nach Bedarf nutzen?',
        'k_audio': 'Möchtest du Abschnitts- und Pace-Ansagen?',
        'k_skipReference': 'Ohne Referenzzeit fortfahren',
        'k_noReference': 'Anstrengung statt Pace: noch keine belastbare Referenz',
        'k_talkComfort': 'Konntest du entspannt ganze Sätze sprechen?',
        'k_recovery': 'Wie fühlst du dich nach der Erholung?',
        'k_ready': 'Gut erholt',
        'k_tired': 'Noch müde',
        'k_poor': 'Schlecht erholt',
        'k_environment': 'Wie waren die Streckenbedingungen?',
        'k_flat': 'Flach und üblich',
        'k_hills': 'Hügelig',
        'k_heat': 'Ungewöhnliche Hitze',
        'k_easy': 'Lockerer Dauerlauf',
        'k_runType': 'Welche Art Lauf war das?',
        'k_otherRun': 'Andere oder gemischte Einheit',
        'k_insufficientEvidence': 'Noch keine ausreichenden vergleichbaren Daten. Deine bisherige Orientierung bleibt bestehen.',
        'k_easyPaceEvidence': 'Mehrere bestätigte lockere Läufe erlauben eine neue Easy-Orientierung. Umfang bleibt unverändert.',
        'k_reduceLoad': 'Die letzten Rückmeldungen sprechen für weniger Belastung. Automatische Abschnitte werden zunächst um 20 % reduziert.',
        'k_runWalkProgress': 'Drei gut verträgliche Einheiten: nächste Geh-/Laufstufe vorschlagen.',
        'k_consideredRuns': 'Berücksichtigte Trainings',
        'k_changes': 'Was ändert sich?',
        'k_reason': 'Warum?',
        'k_ruleVersion': 'Regelversion',
        'k_walkPreparationWorkout': 'Gehvorbereitung',
        'k_hillsWorkout': 'Kontrollierte Bergintervalle',
        'k_profileRequired': 'Bitte ergänze zuerst die neuen Angaben im Laufprofil.',
        'k_singleDayHint': 'Ein Lauftag ist besser als keiner. Mit zwei Tagen lässt sich ein gleichmäßigerer Aufbau planen.',
        'k_customDayBudgets': 'Möchtest du für einzelne Tage andere Zeitbudgets?',
        'k_routeMeters': 'Wie lang ist deine bevorzugte Strecke?',
        'k_routeBudget': 'Deine bevorzugte Strecke wurde an Belastbarkeit und Zeitbudget angepasst. Langsameres Tempo kann mehr Zeit benötigen.',
        'k_buildLoad': 'Mehrere gut verträgliche Einheiten erlauben etwas mehr lockere Laufzeit innerhalb deiner jüngsten Belastung und Zeitbudgets. Pace bleibt unverändert.',
        'other': '$key',
      },
    );
    return '$_temp0';
  }

  @override
  String healthStatus(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'unavailable': 'Health ist auf diesem Gerät nicht verfügbar.',
        'denied': 'Trainingszugriff fehlt. Bitte prüfe die Freigaben.',
        'limited': 'Zugriff eingeschränkt. Fehlende Zusatzdaten bleiben unbekannt.',
        'unknown': 'Apple Health zeigt den Lesezugriff nicht an. Fehlende Daten können auch an Freigaben liegen.',
        'empty': 'Keine neuen Trainings gefunden.',
        'synced': 'Synchronisiert.',
        'failed': 'Synchronisierung fehlgeschlagen. Du kannst sie erneut versuchen.',
        'route': 'Route einschließen (separate Freigabe)',
        'routeFailed': 'Training übernommen. Die Route konnte nicht übernommen werden.',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String refinementText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'k_durationHint': 'Minuten, z. B. 45 oder 45:30',
        'k_durationError': 'Gib eine Zeit über 0 ein, z. B. 45 oder 45:30.',
        'k_notFaster': 'Nicht schneller als',
        'k_notSlower': 'Nicht langsamer als',
        'k_estimated': 'Grobe Orientierung',
        'k_benchmark': 'Aus aktueller Bestzeit',
        'k_manual': 'Individuell',
        'k_effort': 'Nach Gefühl',
        'k_resetTarget': 'Vorschlag übernehmen',
        'k_recoveryMovement': 'Erholung',
        'k_run': 'Locker traben',
        'k_walk': 'Gehen',
        'k_rest': 'Stehen',
        'k_bestTime': 'Bestzeit ergänzen',
        'k_bestDate': 'Datum der Bestzeit',
        'k_profileWhy': 'Wozu diese Angaben?',
        'k_profileExplanation': 'Dein lockeres Tempo liefert eine grobe Pace-Orientierung. Eine aktuelle Bestzeit erlaubt zusätzliche Schätzungen. Laufhäufigkeit und längster Lauf begrenzen den Einstieg; schneller bedeutet nicht automatisch mehr Umfang. Pulszonen benötigen Ruhe- und Maximalpuls.',
        'k_availableDays': 'Verfügbare Tage',
        'k_sessionsPerWeek': 'Einheiten pro Woche',
        'k_custom': 'Individuell',
        'k_pushCore': 'Push + Bauch',
        'k_pullLegs': 'Pull + Beine',
        'k_mixedSplit': 'Push + Bauch / Pull + Beine / Ganzkörper',
        'k_focus': 'Schwerpunkte',
        'k_core': 'Bauch',
        'k_endDate': 'Planende (optional)',
        'k_indefinite': 'Unbefristet',
        'k_extraWorkout': 'Weiteres Workout starten',
        'k_splitSession': 'Einheit aufteilen',
        'k_swap': 'Einheiten tauschen',
        'k_undoSplit': 'Aufteilung rückgängig',
        'k_templates': 'Vorlagen',
        'k_extras': 'Weitere Übungen',
        'k_missingEquipment': 'Benötigte Geräte fehlen',
        'k_streetMap': 'Straßenkarte laden',
        'k_mapPrivacy': 'Die Karte wird von OpenStreetMap geladen. Dabei erhält der Anbieter deine IP-Adresse und den angezeigten Kartenausschnitt. Deine Route bleibt lokal.',
        'k_noRoute': 'Für diese Einheit sind keine GPS-Routendaten vorhanden.',
        'k_runningBlocks': 'Laufbausteine',
        'k_updateTargets': 'Neue Pace-Vorschläge übernehmen?',
        'k_updateTargetsInfo': 'Nur zukünftige, automatisch berechnete Ziele werden aktualisiert. Individuelle Ziele und begonnene Einheiten bleiben unverändert.',
        'k_shortPlan': 'Der Plan endet vor dem vorgeschlagenen Laufaufbau. Spätere Einheiten entfallen; die Steigerung wird nicht beschleunigt.',
        'k_splitHint': 'Ausgewählte Übungen bleiben an Tag 1. Alle anderen wechseln zu Tag 2.',
        'k_muscleFocus': 'Einzelne Muskelgruppen',
        'k_chest': 'Brust',
        'k_back': 'Rücken',
        'k_shoulders': 'Schultern',
        'k_arms': 'Arme',
        'k_quads': 'Oberschenkel',
        'k_glutes': 'Gesäß',
        'k_calves': 'Waden',
        'k_manualEntry': 'Manuelles Protokoll',
        'other': '$key',
      },
    );
    return '$_temp0';
  }

  @override
  String planText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'k_training': 'Training',
        'k_workouts': 'Workouts',
        'k_exercises': 'Übungen',
        'k_start': 'Start',
        'k_settings': 'Einstellungen',
        'k_createPlan': 'Trainingsplan erstellen',
        'k_resumePlan': 'Plan fortsetzen',
        'k_withoutPlan': 'Ohne Plan trainieren',
        'k_planIntro': 'Deine Woche. Dein Training.',
        'k_planHint': 'Kraft und Laufen, gemeinsam geplant.',
        'k_myPlan': 'Mein Trainingsplan',
        'k_savedPlans': 'Gespeicherte Pläne',
        'k_choosePlan': 'Welchen Plan möchtest du verwenden?',
        'k_choosePlanHint': 'Deine bisherigen Pläne bleiben erhalten.',
        'k_today': 'Heute',
        'k_week': 'Diese Woche',
        'k_restDay': 'Heute ist Erholung dran.',
        'k_unitsDone': 'Einheiten abgeschlossen',
        'k_newWorkout': 'Workout erstellen',
        'k_ownWorkouts': 'Deine Workouts',
        'k_templates': 'Vorlagen',
        'k_all': 'Alle',
        'k_strength': 'Kraft',
        'k_running': 'Laufen',
        'k_cardio': 'Weitere Ausdauer',
        'k_mobility': 'Mobility',
        'k_emptyWorkouts': 'Noch keine eigenen Workouts',
        'k_typeQuestion': 'Was möchtest du trainieren?',
        'k_emptyWorkout': 'Ohne Vorlage starten',
        'k_assignWorkout': 'Workout zuordnen',
        'k_workoutUnavailable': 'Dieses Workout ist nicht mehr verfügbar.',
        'k_profile': 'Mein Profil',
        'k_runningProfile': 'Dein Laufprofil',
        'k_strengthProfile': 'Dein Kraftprofil',
        'k_equipment': 'Trainingsorte & Geräte',
        'k_interests': 'Was trainierst du?',
        'k_units': 'Einheiten',
        'k_metric': 'Kilometer',
        'k_imperial': 'Meilen',
        'k_connections': 'Verbindungen',
        'k_sensorBackup': 'GPS- und Sensordaten sichern',
        'k_sensorHint': 'Optional im Cloud-Backup. Lokal bleiben deine Daten erhalten.',
        'k_look': 'Dein Look',
        'k_lookHint': 'Wähle, wie sich Trainy für dich anfühlt.',
        'k_backup': 'Dein Backup',
        'k_backupHint': 'Optional mit Google sichern. Trainy funktioniert auch ohne Konto.',
        'k_health': 'Aktivitäten verbinden',
        'k_healthHint': 'Abgeschlossene Trainings aus Health übernehmen, keine Live-Uhrverbindung.',
        'k_connect': 'Verbinden',
        'k_connected': 'Verbunden',
        'k_later': 'Später',
        'k_next': 'Weiter',
        'k_back': 'Zurück',
        'k_done': 'Fertig',
        'k_save': 'Speichern',
        'k_retry': 'Erneut versuchen',
        'k_error': 'Das hat nicht geklappt. Deine Eingaben bleiben erhalten.',
        'k_savingError': 'Nicht gespeichert. Bitte erneut versuchen.',
        'k_days': 'Wann möchtest du trainieren?',
        'k_availableDays': 'Verfügbare Tage',
        'k_strengthDays': 'Deine Krafttage',
        'k_runningDays': 'Deine Lauftage',
        'k_mobilityDays': 'Deine Mobility-Tage',
        'k_dayRequired': 'Wähle mindestens einen Trainingstag.',
        'k_chooseSport': 'Wähle mindestens eine Sportart.',
        'k_name': 'Planname',
        'k_nameRequired': 'Gib deinem Plan einen Namen.',
        'k_goal': 'Dein Ziel',
        'k_strengthGoal': 'Kraftziel',
        'k_runningGoal': 'Laufziel',
        'k_generalFitness': 'Fit bleiben',
        'k_buildMuscle': 'Muskeln aufbauen',
        'k_getStronger': 'Stärker werden',
        'k_runFaster': 'Schneller laufen',
        'k_runFurther': 'Weiter laufen',
        'k_firstDistance': 'Distanz schaffen',
        'k_targetDistance': 'Zieldistanz',
        'k_targetTime': 'Zielzeit (optional)',
        'k_targetDate': 'Wunschtermin (optional)',
        'k_startDate': 'Startdatum',
        'k_optional': 'Optional',
        'k_none': 'Nicht angegeben',
        'k_preview': 'Deine Woche',
        'k_activate': 'Plan verwenden',
        'k_edit': 'Bearbeiten',
        'k_replace': 'Ändern',
        'k_split': 'Dein Split',
        'k_fullBody': 'Ganzkörper',
        'k_upperLower': 'Ober-/Unterkörper',
        'k_pushPullLegs': 'Push/Pull/Beine',
        'k_upper': 'Oberkörper',
        'k_lower': 'Unterkörper',
        'k_push': 'Push',
        'k_pull': 'Pull',
        'k_legs': 'Beine',
        'k_splitHint': 'Vorschlag – antippen und anpassen.',
        'k_missingWorkouts': 'Noch Workouts zuordnen',
        'k_weeklyRepeat': 'Wiederholt sich wöchentlich',
        'k_alternating': 'Wechselt alle zwei Wochen',
        'k_weekNumber': 'Woche',
        'k_level': 'Wie würdest du dich einordnen?',
        'k_starting': 'Einstieg',
        'k_beginner': 'Anfänger',
        'k_intermediate': 'Fortgeschritten',
        'k_experienced': 'Sehr erfahren',
        'k_startingHint': 'Ich beginne gerade mit Laufen.',
        'k_beginnerHint': 'Ich laufe schon, baue aber noch auf.',
        'k_intermediateHint': 'Ich laufe regelmäßig, auch längere Strecken.',
        'k_experiencedHint': 'Ich trainiere regelmäßig auch Tempo und Intervalle.',
        'k_canFive': 'Schaffst du 5 km ohne Gehpause?',
        'k_yes': 'Ja',
        'k_notYet': 'Noch nicht',
        'k_unknown': 'Weiß ich nicht',
        'k_performance': 'Dein aktuelles Tempo',
        'k_distance': 'Distanz',
        'k_time': 'Zeit',
        'k_pace': 'Pace',
        'k_timeQuestion': 'Wie lange brauchst du für diese Distanz?',
        'k_durationHint': 'Minuten:Sekunden, z. B. 32:30',
        'k_durationError': 'Gib eine Zeit über 0 als mm:ss ein.',
        'k_positiveError': 'Gib eine Zahl größer als 0 ein.',
        'k_numberError': 'Gib eine gültige Zahl ein.',
        'k_performanceKind': 'Was beschreibt diese Zeit?',
        'k_easyRun': 'Lockerer Trainingslauf',
        'k_bestRun': 'Schnellstmöglicher Lauf',
        'k_testDate': 'Wann war dieser Lauf?',
        'k_dateRequired': 'Wähle das Datum deines Laufs.',
        'k_testInfo': 'Nur aktuelle Bestleistungen dienen als Grundlage für Wettkampfprognosen. Trainingszeiten sind keine Maximaltests.',
        'k_load': 'Deine bisherige Belastung',
        'k_longest': 'Längster Lauf der letzten 4 Wochen',
        'k_continuous': 'Wie lange läufst du locker ohne Gehpause?',
        'k_minutes': 'Minuten',
        'k_recentFrequency': 'Wie oft bist du zuletzt pro Woche gelaufen?',
        'k_recentHint': 'In den letzten 4 Wochen, nicht dein neues Trainingsziel.',
        'k_pulse': 'Pulszonen (optional)',
        'k_restPulse': 'Ruhepuls',
        'k_maxPulse': 'Maximalpuls',
        'k_pulseError': 'Gib einen ganzen Wert zwischen 25 und 250 ein.',
        'k_pulseOrder': 'Der Maximalpuls muss über dem Ruhepuls liegen.',
        'k_pulseMissing': 'Für Zonen werden beide Werte benötigt.',
        'k_zoneInfo': 'Karvonen-Schätzung, keine Leistungsdiagnostik. Du kannst Zielbereiche selbst ändern.',
        'k_move': 'Verschieben',
        'k_onlyThis': 'Nur diese Einheit',
        'k_future': 'Auch künftig',
        'k_conflict': 'Belastung prüfen',
        'k_conflictHint': 'Einheiten liegen dicht zusammen. Lege einen anspruchsvollen Lauf oder Beintag auf einen anderen verfügbaren Tag.',
        'k_doubleDay': 'Mehrere Einheiten an einem Tag',
        'k_changeDays': 'Tage anpassen',
        'k_planEstimate': 'Vorschlag, kein Leistungsversprechen.',
        'k_editRunning': 'Laufbaustein bearbeiten',
        'k_editStrength': 'Kraftbaustein bearbeiten',
        'k_regenerate': 'Laufvorschlag aktualisieren',
        'k_regenerateHint': 'Nur ungeänderte zukünftige Läufe werden ersetzt. Verlauf und manuelle Änderungen bleiben erhalten.',
        'k_delete': 'Löschen',
        'k_cancel': 'Abbrechen',
        'k_deleteWorkout': 'Workout löschen?',
        'k_add': 'Hinzufügen',
        'k_calendar': 'Kalender',
        'k_continueWorkout': 'Workout fortsetzen',
        'k_viewAll': 'Alle anzeigen',
        'k_runNeedsDays': 'Wähle Lauftage, um den Laufplan vorzuschlagen.',
        'k_restore': 'Backup laden',
        'k_keepLocal': 'Lokal fortfahren',
        'k_backupFound': 'Backup gefunden',
        'k_restoreHint': 'Laden ersetzt die lokalen Trainingsdaten. Ohne Laden bleibt dein Cloud-Backup unverändert.',
        'k_summary': 'Übersicht',
        'k_planSaved': 'Plan gespeichert',
        'k_finishSetup': 'Einrichtung fortsetzen',
        'other': '$key',
      },
    );
    return '$_temp0';
  }

  @override
  String cardioText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'k_cardio': 'Ausdauer',
        'k_library': 'Workouts',
        'k_plan': 'Trainingsplan',
        'k_history': 'Verlauf',
        'k_profile': 'Laufprofil',
        'k_settings': 'Ausdauer-Einstellungen',
        'k_newWorkout': 'Workout erstellen',
        'k_edit': 'Bearbeiten',
        'k_save': 'Speichern',
        'k_cancel': 'Abbrechen',
        'k_delete': 'Löschen',
        'k_add': 'Hinzufügen',
        'k_start': 'Starten',
        'k_continueLabel': 'Weiter',
        'k_skip': 'Überspringen',
        'k_warmup': 'Warm-up',
        'k_cooldown': 'Cool-down',
        'k_core': 'Hauptteil',
        'k_name': 'Name',
        'k_sport': 'Sportart',
        'k_indoor': 'Indoor',
        'k_outdoor': 'Outdoor',
        'k_running': 'Laufen',
        'k_walking': 'Gehen',
        'k_cycling': 'Radfahren',
        'k_stepper': 'Stepper',
        'k_elliptical': 'Crosstrainer',
        'k_rowing': 'Rudern',
        'k_other': 'Sonstiges',
        'k_time': 'Dauer',
        'k_distance': 'Distanz',
        'k_seconds': 'Sekunden',
        'k_minutes': 'Minuten',
        'k_meters': 'Meter',
        'k_repeat': 'Wiederholungen',
        'k_recovery': 'Erholung',
        'k_standing': 'Stehende Erholung',
        'k_easy': 'Locker',
        'k_steady': 'Zügig',
        'k_threshold': 'Schwelle',
        'k_interval': 'Intervall',
        'k_free': 'Freie Intensität',
        'k_intensity': 'Intensität',
        'k_run': 'Laufen',
        'k_walk': 'Gehen',
        'k_rest': 'Ruhe',
        'k_movement': 'Bewegung',
        'k_pace': 'Pace',
        'k_speed': 'Geschwindigkeit',
        'k_heartRate': 'Puls',
        'k_target': 'Ziel',
        'k_minSpeed': 'Min. Geschwindigkeit (m/s)',
        'k_maxSpeed': 'Max. Geschwindigkeit (m/s)',
        'k_minPulse': 'Unterer Zielpuls',
        'k_maxPulse': 'Oberer Zielpuls',
        'k_primary': 'Primäre Führung',
        'k_effort': 'Belastungsempfinden',
        'k_reference': 'Referenzzeit',
        'k_referenceDistance': 'Referenzdistanz',
        'k_referenceDate': 'Datum der Referenz',
        'k_maximal': 'Maximaler Test / Wettkampf',
        'k_weekly': 'Wochenumfang',
        'k_longest': 'Längster Lauf (letzte 4 Wochen)',
        'k_continuous': 'Durchgängig laufbar (Minuten)',
        'k_experience': 'Regelmäßige Lauferfahrung (Monate)',
        'k_restPulse': 'Ruhepuls (optional)',
        'k_maxHeartRate': 'Maximalpuls (optional)',
        'k_days': 'Trainingstage',
        'k_metric': 'Kilometer / Meter',
        'k_imperial': 'Meilen',
        'k_units': 'Einheiten',
        'k_zones': 'Geschätzte Pulszonen',
        'k_zoneInfo': 'Karvonen: Ruhepuls + Anteil × (Maximalpuls − Ruhepuls). Trainy nutzt fünf Bereiche von 50–100 % der Herzfrequenzreserve. Individuelle Schwellen können abweichen; eine Leistungsdiagnostik ermöglicht genauere Bereiche.',
        'k_benchmarkInfo': 'Pace-Vorschläge benötigen einen maximalen Test der letzten 90 Tage. Normale Trainingspace ergibt keine Wettkampfprognose.',
        'k_invalid': 'Bitte prüfe die Eingaben.',
        'k_error': 'Das hat nicht geklappt. Deine lokal gespeicherten Daten bleiben erhalten.',
        'k_retry': 'Erneut versuchen',
        'k_noData': 'Noch keine Einheiten',
        'k_finish': 'Zum Beenden 2 Sekunden halten',
        'k_finishAccessible': 'Training beenden',
        'k_confirmFinish': 'Training jetzt beenden und speichern?',
        'k_pause': 'Pause',
        'k_resume': 'Fortsetzen',
        'k_paused': 'Pausiert',
        'k_active': 'Training läuft',
        'k_completed': 'Abgeschlossen',
        'k_elapsed': 'Gesamtzeit',
        'k_activeTime': 'Aktive Zeit',
        'k_remaining': 'Verbleibend',
        'k_next': 'Als Nächstes',
        'k_average': 'Durchschnitt',
        'k_half': 'Halbzeit',
        'k_nearEnd': 'Kurz vor dem Ziel',
        'k_faster': 'Etwas schneller laufen',
        'k_slower': 'Etwas langsamer laufen',
        'k_gpsLost': 'GPS fehlt – Distanzmessung unterbrochen',
        'k_gpsReady': 'GPS aktiv',
        'k_gpsWaiting': 'GPS wird gesucht',
        'k_locationDenied': 'Für Outdoor-Distanzmessung ist genauer Standortzugriff erforderlich.',
        'k_openSettings': 'Einstellungen öffnen',
        'k_audioUnavailable': 'Keine Offline-Stimme verfügbar. Audio in den Systemeinstellungen einrichten.',
        'k_indoorInfo': 'Ohne Sensor gibt es Indoor keine gemessene Distanz, Live-Pace oder Auto-Pause. Distanzziele lassen sich mit vorhandenem Zieltempo in Zeitziele umwandeln.',
        'k_convert': 'Distanzziele in Zeit umwandeln',
        'k_backgroundLimited': 'Indoor auf dieser iOS-Version: App geöffnet lassen.',
        'k_pulseLater': 'Puls wird nach dem Training über Health ergänzt. Live-Führung erfolgt per Pace oder Belastungsempfinden.',
        'k_autoPause': 'Auto-Pause nach 10 Sekunden Stillstand',
        'k_mediaPending': 'Video noch nicht verfügbar – folge der Bewegungsanleitung.',
        'k_routineInfo': 'Langsam und kontrolliert bewegen. Nur im angenehmen Bewegungsumfang. Einseitige Übungen auf beide Seiten aufteilen.',
        'k_easy5k': 'Lockerer 5-km-Lauf',
        'k_longRun': 'Long Run',
        'k_runWalk': 'Laufen und Gehen',
        'k_progression': 'Progressionslauf',
        'k_tempo': 'Tempolauf',
        'k_pyramid': 'Pyramidenintervalle',
        'k_descending': 'Absteigende Intervalle',
        'k_fourByFour': '4 × 4 Minuten',
        'k_fartlek': 'Fahrtspiel',
        'k_strides': 'Steigerungsläufe',
        'k_drills': 'Lauf-ABC',
        'k_easySession': 'Dauerlauf',
        'k_intervalSession': 'Zeitintervalle',
        'k_goalDistance': 'Zieldistanz',
        'k_goalTime': 'Gewünschte Zielzeit (optional, Minuten)',
        'k_goalDate': 'Wunschtermin (optional)',
        'k_generate': 'Plan vorschlagen',
        'k_accept': 'Übernehmen',
        'k_preview': 'Vorschau',
        'k_planInfo': 'Vorsichtige Planung anhand deiner bisherigen Belastung. Zielzeiten und Zeiträume sind keine Leistungsversprechen. Änderungen werden erst nach Bestätigung übernommen.',
        'k_basePhase': 'Zunächst Grundlagen aufbauen',
        'k_infeasible': 'Der Termin oder die Trainingsbasis passt noch nicht zum Ziel. Der Vorschlag enthält eine längere Aufbauphase.',
        'k_move': 'Verschieben',
        'k_onlyThis': 'Nur diese Einheit',
        'k_futureToo': 'Auch künftig diesen Wochentag',
        'k_locked': 'Manuell fixiert',
        'k_skipped': 'Ausgelassen',
        'k_adapt': 'Anpassung vorschlagen',
        'k_adaptInfo': 'Nach Ausfällen wird die kommende Belastung reduziert; fixierte und abgeschlossene Einheiten bleiben erhalten.',
        'k_rpe': 'Wie anstrengend war es? (1–10)',
        'k_discomfort': 'Beschwerden',
        'k_health': 'Health verbinden',
        'k_import': 'Aktivitäten prüfen',
        'k_export': 'In Health speichern',
        'k_dismiss': 'Nicht übernehmen',
        'k_link': 'Vorhandener Einheit zuordnen',
        'k_backupSensors': 'Strecken und Sensorverläufe im Cloud-Backup',
        'k_backupInfo': 'Standardmäßig werden nur Profil, Pläne und Zusammenfassungen gesichert.',
        'k_healthInfo': 'Trainy liest abgeschlossene Workouts und Pulsdaten lokal aus Apple Health bzw. Health Connect. Übernahmen sind prüfbar. Es gibt keine Live-Verbindung zu deiner Uhr.',
        'k_healthUnavailable': 'Health ist auf diesem Gerät nicht verfügbar.',
        'k_healthExported': 'In Health gespeichert',
        'k_healthPermission': 'Health-Zugriff wurde nicht freigegeben.',
        'k_strengthActive': 'Bitte beende zuerst die laufende Trainingseinheit.',
        'k_saved': 'Lokal gespeichert',
        'k_newPlan': 'Neuer Laufplan',
        'k_date': 'Datum',
        'k_week': 'Woche',
        'k_summary': 'Zusammenfassung',
        'k_estimated': 'Geschätzt',
        'k_recovered': 'Wiederhergestellt; mögliche Messlücken beachten',
        'k_interests': 'Was möchtest du trainieren?',
        'k_strength': 'Kraft',
        'k_mobility': 'Beweglichkeit',
        'k_focus': 'Trainingsfokus',
        'k_power': 'Schnellkraft',
        'k_muscularEndurance': 'Kraftausdauer',
        'k_dynamic': 'Dynamisch',
        'k_staticStretch': 'Statisch / Dehnen',
        'k_copy': 'Duplizieren',
        'k_deleteConfirm': 'Diesen Eintrag löschen?',
        'k_localOnly': 'Alles wird lokal gespeichert und berechnet.',
        'k_secondsPerKm': 'Sekunden pro Kilometer',
        'k_restDays': 'Trainingsabstände prüfen: aufeinanderfolgende Tage.',
        'k_sensorCoverage': 'Messabdeckung',
        'k_privacy': 'Gesundheitsdaten und Datenschutz',
        'k_privacyBody': 'Trainy verarbeitet Trainingsdaten lokal auf diesem Gerät. Health-Zugriff ist freiwillig und in den Systemeinstellungen widerrufbar. Cloud-Backup ist separat optional; detaillierte Strecken werden nur mit zusätzlicher Zustimmung gesichert. Es werden keine Gesundheitsdaten für Werbung verkauft.',
        'k_ankleRocks': 'Sprunggelenk-Wippen',
        'k_calfRaises': 'Wadenheben',
        'k_legSwings': 'Beinschwingen vor/zurück',
        'k_lateralSwings': 'Seitliches Beinschwingen',
        'k_reverseLunge': 'Rückwärtiger Ausfallschritt',
        'k_march': 'Marschieren mit Armbewegung',
        'k_hinge': 'Hüftbeuge',
        'k_squat': 'Lockere Kniebeugen',
        'k_rotation': 'Brustwirbelsäulenrotation',
        'k_lateralLunge': 'Seitlicher Ausfallschritt',
        'k_gluteBridge': 'Glute Bridge',
        'k_birdDog': 'Bird Dog',
        'k_shoulderCircles': 'Schulterkreisen',
        'k_armCircles': 'Armkreisen',
        'k_wallSlides': 'Wall Slides',
        'k_scapularPushup': 'Schulterblatt-Liegestütz',
        'k_calfStretch': 'Wadendehnung',
        'k_hipFlexor': 'Hüftbeugerdehnung',
        'k_hamstring': 'Hinterer Oberschenkel',
        'k_quadStretch': 'Vorderer Oberschenkel',
        'k_gluteStretch': 'Gesäßdehnung',
        'k_chestStretch': 'Brustdehnung',
        'k_latStretch': 'Latissimusdehnung',
        'k_shoulderStretch': 'Hintere Schulter',
        'k_aMarch': 'A-March',
        'k_ankling': 'Fußgelenksarbeit',
        'k_aSkip': 'A-Skip',
        'k_buttKicks': 'Anfersen',
        'k_sideSteps': 'Seitwärtsschritte',
        'k_lower': 'Unterkörper',
        'k_upper': 'Oberkörper',
        'k_startError': 'Start nicht möglich. Prüfe Berechtigungen, Ziele und ob bereits ein anderes Training aktiv ist.',
        'k_storageError': 'Aufzeichnung nicht vollständig gesichert. Bitte Training pausieren und freien Speicher prüfen.',
        'k_holdFinish': 'Zum Beenden 2 Sekunden gedrückt halten',
        'k_templates': 'Vorlagen',
        'k_profileIntro': 'Tempo, Pulswerte und verfügbare Tage für passende Vorschläge ergänzen.',
        'k_cardioIntro': 'Laufen, Radfahren und weitere Ausdauersportarten',
        'k_equivalent': 'Heutige rechnerische Äquivalenz – keine Zielzeitprognose',
        'k_noAdjustment': 'Aktuell keine automatische Anpassung empfohlen. Einzelne Einheiten kannst du jederzeit bearbeiten.',
        'k_refresh': 'Einheiten der letzten 29 Tage suchen',
        'k_disconnect': 'Automatischen Abruf deaktivieren',
        'k_importConfirm': 'Einheit nachtragen oder zuordnen?',
        'k_healthError': 'Health nicht verfügbar oder Zugriff eingeschränkt. Prüfe die Systemberechtigungen. Ein Export mit unklarem Ergebnis wird nicht automatisch wiederholt; prüfe ihn in Health, um Duplikate zu vermeiden.',
        'k_ankleRocksInstruction': 'Im Ausfallschritt das vordere Knie sanft über die Zehen schieben, Ferse am Boden. Nach der Hälfte Seite wechseln.',
        'k_calfRaisesInstruction': 'Aufrecht stehen. Beide Fersen langsam anheben und kontrolliert senken. Bei Bedarf an einer Wand abstützen.',
        'k_legSwingsInstruction': 'Seitlich an einer Wand abstützen. Ein Bein locker vor und zurück schwingen, Becken ruhig halten. Nach der Hälfte wechseln.',
        'k_lateralSwingsInstruction': 'An einer Wand abstützen. Ein Bein kontrolliert seitlich hin und her schwingen. Nach der Hälfte wechseln.',
        'k_reverseLungeInstruction': 'Abwechselnd einen kleinen Schritt zurück machen und beide Knie leicht beugen. Vorn über den ganzen Fuß hochdrücken.',
        'k_marchInstruction': 'Aufrecht auf der Stelle marschieren. Knie bequem anheben, Arme gegengleich mitschwingen.',
        'k_hingeInstruction': 'Knie locker, Hüfte nach hinten schieben und Oberkörper mit langem Rücken neigen. Kontrolliert aufrichten.',
        'k_squatInstruction': 'Füße bequem auseinander. Hüfte langsam nach hinten und unten führen, dann wieder aufrichten. Nur so tief wie angenehm.',
        'k_rotationInstruction': 'Aufrecht stehen und den Oberkörper sanft nach links und rechts drehen. Hüfte weitgehend ruhig halten.',
        'k_lateralLungeInstruction': 'Seitlich aussteigen und das Knie des belasteten Beins leicht beugen. Zur Mitte zurück und wechseln.',
        'k_gluteBridgeInstruction': 'Auf dem Rücken, Füße aufgestellt. Hüfte kontrolliert anheben, ohne ins Hohlkreuz zu gehen, dann senken.',
        'k_birdDogInstruction': 'Im Vierfüßlerstand gegenüberliegenden Arm und Bein langsam strecken. Rücken ruhig halten, dann wechseln.',
        'k_shoulderCirclesInstruction': 'Arme locker hängen lassen. Kleine, langsame Schulterkreise nach hinten und vorne ausführen.',
        'k_armCirclesInstruction': 'Arme seitlich bequem anheben und kleine Kreise machen. Bewegungsradius nur schmerzfrei vergrößern.',
        'k_wallSlidesInstruction': 'Mit dem Rücken locker an die Wand lehnen. Arme langsam nach oben und unten gleiten lassen, ohne auszuweichen.',
        'k_scapularPushupInstruction': 'Im Vierfüßlerstand mit gestreckten Armen die Schulterblätter sanft zusammen und auseinander bewegen.',
        'k_calfStretchInstruction': 'Im Schrittstand Hände an eine Wand, hinteres Bein gestreckt und Ferse unten. Sanft halten, nicht wippen. Nach der Hälfte wechseln.',
        'k_hipFlexorInstruction': 'Im halben Kniestand mit Polster das Becken leicht aufrichten. Hüfte sanft nach vorn verlagern, kein Hohlkreuz. Nach der Hälfte wechseln.',
        'k_hamstringInstruction': 'Ein Bein nach vorn, Ferse am Boden, Knie locker. Hüfte leicht nach hinten schieben und Rücken lang halten. Nach der Hälfte wechseln.',
        'k_quadStretchInstruction': 'Im Stand abstützen, einen Fuß hinter dem Körper halten. Knie nebeneinander, Becken ruhig. Nicht ziehen. Nach der Hälfte wechseln.',
        'k_gluteStretchInstruction': 'Auf dem Rücken einen Knöchel über das andere Knie legen. Unteres Bein sanft heranziehen. Nach der Hälfte wechseln.',
        'k_chestStretchInstruction': 'Unterarm sanft an einen Türrahmen legen und Oberkörper wenig wegdrehen. Schulter nicht hochziehen. Nach der Hälfte wechseln.',
        'k_latStretchInstruction': 'Hände auf eine stabile Fläche legen. Hüfte nach hinten schieben und Rücken lang lassen, ohne Druck in der Schulter.',
        'k_shoulderStretchInstruction': 'Einen Arm locker vor den Körper führen und mit dem anderen sanft unterstützen. Schulter unten lassen. Nach der Hälfte wechseln.',
        'k_aMarchInstruction': 'Langsam vorwärts marschieren, jeweils ein Knie anheben und den Fuß unter dem Körper absetzen. Gegengleicher Armschwung.',
        'k_anklingInstruction': 'Mit sehr kleinen Schritten vorwärts bewegen. Sprunggelenke federnd und locker bewegen, Oberkörper aufrecht.',
        'k_aSkipInstruction': 'Nur wenn vertraut: kleine lockere Hopser mit abwechselndem Kniehub. Alternativ marschieren. Leise landen.',
        'k_buttKicksInstruction': 'Locker auf der Stelle traben und Fersen abwechselnd nach hinten führen, ohne sie zu erzwingen.',
        'k_sideStepsInstruction': 'Kleine kontrollierte Seitwärtsschritte, Füße nicht kreuzen. Nach der Hälfte Richtung wechseln.',
        'k_targetTimeInfo': 'Die Zielzeit dient als Orientierung, nicht als zugesagte Verbesserung. Trainingspace bleibt an deinem aktuellen Test ausgerichtet und wird erst nach einem neuen Test angepasst.',
        'k_route': 'Lokal aufgezeichnete Route ohne Kartenhintergrund',
        'k_audioSetup': 'Installiere in den Systemeinstellungen eine Offline-Stimme für die gewählte App-Sprache. Du kannst ohne Ansagen fortfahren; währenddessen sind die Hinweise nur auf dem Bildschirm sichtbar.',
        'k_custom': 'Eigene Übung',
        'k_instructions': 'Anleitung (optional)',
        'other': '$key',
      },
    );
    return '$_temp0';
  }

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
  String get optionalDescription => 'Beschreibung (optional)';

  @override
  String get localSaveFailed => 'Lokal speichern fehlgeschlagen. Deine Eingaben bleiben für einen erneuten Versuch erhalten.';

  @override
  String get optional => 'optional';

  @override
  String get exerciseGoal => 'Trainingsziel';

  @override
  String get standard => 'Standard';

  @override
  String get catalog => 'Katalog';

  @override
  String get own => 'Eigene';

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
  String get exerciseLibrary => 'Übungen';

  @override
  String get activities => 'Aktivitäten';

  @override
  String get all => 'Alle';

  @override
  String matchesProfile(String name) {
    return 'Passend für $name';
  }

  @override
  String get instructions => 'Anleitung';

  @override
  String get exerciseArchived => 'Übung archiviert; der Trainingsverlauf bleibt unverändert';

  @override
  String get archive => 'Archivieren';

  @override
  String get undo => 'Rückgängig';

  @override
  String get trainingProfile => 'Profil';

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
  String get addAlternative => 'Alternativübung hinzufügen';

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
  String get equipmentBench => 'Bank';

  @override
  String get equipmentRack => 'Rack';

  @override
  String get equipmentPullUpBar => 'Klimmzugstange';

  @override
  String get equipmentMedicineBall => 'Medizinball';

  @override
  String get equipmentExerciseBall => 'Gymnastikball';

  @override
  String get equipmentFoamRoller => 'Foam Roller';

  @override
  String get equipmentEzBar => 'EZ-Stange';

  @override
  String get equipmentMat => 'Matte';

  @override
  String get equipmentCardioMachine => 'Cardiogerät';

  @override
  String get equipmentOther => 'Sonstiges';

  @override
  String get noEquipmentSelected => 'Kein Equipment ausgewählt';

  @override
  String get trainingProfileDescription => 'Verwalte deine Trainingsorte und ihr Equipment.';

  @override
  String get addTrainingProfile => 'Neues Profil';

  @override
  String get editTrainingProfile => 'Profil bearbeiten';

  @override
  String get archiveProfile => 'Profil archivieren?';

  @override
  String archiveProfileDescription(String name) {
    return '\"$name\" wird nicht mehr als Profil angeboten. Bestehende Einheiten bleiben unverändert.';
  }

  @override
  String get profileLoadFailed => 'Die Profile konnten nicht geladen werden.';

  @override
  String profileOperationFailed(String operation) {
    return 'Profilaktion fehlgeschlagen ($operation). Bitte erneut versuchen.';
  }

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
        'cardio': 'Ausdauer',
        'mobility': 'Beweglichkeit',
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

  @override
  String get dataAndPrivacy => 'Daten & Datenschutz';

  @override
  String get resetLocalTrainingData => 'Lokale Trainingsdaten zurücksetzen';

  @override
  String get resetLocalTrainingDataDescription => 'Löscht Workouts, Fortschritt und persönliche Übungsbilder auf diesem Gerät.';

  @override
  String get resetLocalTrainingDataConfirm => 'Deine lokalen Trainingsdaten und persönlichen Übungsbilder werden gelöscht. Anmeldung, Sprache und Design bleiben erhalten.';

  @override
  String get confirmResetAgain => 'Lokale Daten wirklich zurücksetzen?';

  @override
  String get confirmResetAgainDescription => 'Das kann nicht rückgängig gemacht werden. Das automatische Cloud-Backup wird deaktiviert.';

  @override
  String get resetNow => 'Jetzt zurücksetzen';

  @override
  String get deleteCloudData => 'Cloud-Daten löschen';

  @override
  String get deleteCloudDataDescription => 'Löscht alle Trainy-Backups dieses Kontos. Lokale Daten und das Konto bleiben erhalten.';

  @override
  String get deleteCloudDataConfirm => 'Alle Trainy-Cloudobjekte deines Kontos werden gelöscht.';

  @override
  String get confirmCloudDeleteAgain => 'Cloud-Daten endgültig löschen?';

  @override
  String get confirmCloudDeleteAgainDescription => 'Bei einer unterbrochenen Verbindung kann der Vorgang sicher wiederholt werden.';

  @override
  String get cloudDataDeleted => 'Cloud-Daten gelöscht';

  @override
  String get deleteAccountAndData => 'Konto und alle Daten löschen';

  @override
  String get deleteAccountAndDataDescription => 'Löscht Cloud-Daten, das Firebase-Konto und alle lokalen App-Daten.';

  @override
  String get deleteAccountAndDataConfirm => 'Du meldest dich erneut mit Google an. Danach werden das Konto und alle Trainy-Daten gelöscht.';

  @override
  String get confirmAccountDeleteAgain => 'Konto endgültig löschen?';

  @override
  String get confirmAccountDeleteAgainDescription => 'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deletePermanently => 'Endgültig löschen';

  @override
  String get activeWorkoutMustEnd => 'Aktives Workout';

  @override
  String get activeWorkoutMustEndDescription => 'Das aktuelle Workout muss beendet oder verworfen werden, bevor Daten gelöscht werden können.';

  @override
  String get discardAndContinue => 'Verwerfen & fortfahren';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get localDataRecovery => 'Lokale Datenwiederherstellung';

  @override
  String get localDataNeedsRecovery => 'Deine lokalen Trainingsdaten benötigen Aufmerksamkeit';

  @override
  String get localDataNeedsRecoveryDescription => 'Trainy hat die Datenbank nicht gelöscht. Du kannst das Öffnen erneut versuchen, eine rohe Recovery-Kopie sichern oder die lokalen Trainingsdaten ausdrücklich zurücksetzen.';

  @override
  String get saveRecoveryCopy => 'Recovery-Kopie sichern';

  @override
  String recoverySaved(String path) {
    return 'Recovery-Kopie gespeichert unter $path';
  }

  @override
  String get recoveryExportFailed => 'Die Recovery-Kopie konnte nicht gespeichert werden.';

  @override
  String get recoveryResetDescription => 'Dadurch wird die lokale Trainingsdatenbank endgültig gelöscht und neu erstellt. Sichere vorher eine Recovery-Kopie, falls du die Daten noch benötigst.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get finishingLocally => 'Wird lokal abgeschlossen …';

  @override
  String get savedLocally => 'Lokal gespeichert';

  @override
  String get workoutSaveFailed => 'Das Workout ist weiterhin als lokaler Entwurf vorhanden. Speichern fehlgeschlagen; bitte erneut versuchen.';

  @override
  String get workoutAutosaveFailed => 'Eine Änderung konnte nicht lokal gespeichert werden. Deine Eingabe bleibt erhalten; versuche es vor dem Beenden erneut.';

  @override
  String get filters => 'Filter';

  @override
  String get resetFilters => 'Zurücksetzen';

  @override
  String get label => 'Label';

  @override
  String get source => 'Quelle';

  @override
  String get allProfiles => 'Alle Profile';

  @override
  String get noMatchingExercises => 'Keine passenden Übungen';

  @override
  String get noMatchingExercisesDescription => 'Ändere deine Suche oder setze die aktiven Filter zurück.';

  @override
  String englishSynonym(String name) {
    return 'Englisch: $name';
  }

  @override
  String get selectImage => 'Bild auswählen';

  @override
  String get replaceImage => 'Bild ersetzen';

  @override
  String get removeImage => 'Bild entfernen';

  @override
  String get exerciseCover => 'Übungsbild';

  @override
  String get equipmentBicycle => 'Fahrrad';

  @override
  String get equipmentPool => 'Schwimmbecken';

  @override
  String get workoutBasics => 'Grundlagen';

  @override
  String get workoutSetup => 'Profil';

  @override
  String get workoutExercises => 'Übungen';

  @override
  String get choosePrimaryGoal => 'Wähle das Hauptziel dieses Workouts';

  @override
  String get primaryGoal => 'Hauptziel';

  @override
  String get setupName => 'Profilname';

  @override
  String get withoutProfile => 'Ohne Profil';

  @override
  String get createSetup => 'Profil hinzufügen';

  @override
  String get selectSetup => 'Profil auswählen';

  @override
  String get setups => 'Profile';

  @override
  String get weeklyPlanner => 'Wochenplan';

  @override
  String get editWeeklyPlanner => 'Wochenplan bearbeiten';

  @override
  String get addToWeeklyPlanner => 'In Wochenplan eintragen';

  @override
  String get addWorkoutToDay => 'Workout hinzufügen';

  @override
  String get noWorkoutPlanned => 'Kein Workout geplant';

  @override
  String get moveWorkout => 'Workout verschieben';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get coreExercise => 'Pflichtübung';

  @override
  String get optionalExercise => 'Optional';

  @override
  String get makeOptional => 'Als optional markieren';

  @override
  String get makeCore => 'Als Kernübung markieren';

  @override
  String get moveToGroup => 'In andere Gruppe verschieben';

  @override
  String stepOf(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get saveWorkout => 'Workout speichern';

  @override
  String get noSetups => 'Noch kein Profil angelegt';

  @override
  String setupExercisesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Übungen',
      one: '1 Übung',
      zero: 'Keine Übungen',
    );
    return '$_temp0';
  }

  @override
  String get plannedWorkouts => 'Geplante Workouts';

  @override
  String get dayDetails => 'Tagesübersicht';

  @override
  String get workoutAlreadyPlanned => 'Dieses Workout ist an diesem Tag bereits geplant.';

  @override
  String get defaultSetup => 'Standard';

  @override
  String get chooseSetupProfile => 'Wähle ein Profil für diese Trainingsumgebung.';

  @override
  String get profileSetup => 'Dieses Profil verwenden';

  @override
  String get makeDefaultSetup => 'Als Standard festlegen';

  @override
  String get warmupGroup => 'Aufwärmen';

  @override
  String get coreExercisesGroup => 'Kernübungen';

  @override
  String get cooldownGroup => 'Cooldown';

  @override
  String get dropExercisesHere => 'Übungen hierher ziehen';

  @override
  String get dragExercise => 'Übung ziehen';

  @override
  String selectedExercises(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Übungen ausgewählt',
      one: '1 Übung ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get groupSelectedExercises => 'Ausgewählte Übungen gruppieren';

  @override
  String get group => 'Gruppieren';

  @override
  String get showAllExercises => 'Alle anzeigen';

  @override
  String get prioritizeProfileExercises => 'Passende zuerst';

  @override
  String get switchExerciseForSession => 'Übung für diese Einheit wechseln';

  @override
  String get removeFromWeeklyPlan => 'Aus Wochenplan entfernen';

  @override
  String get weeklyPlacementRemoved => 'Workout aus Wochenplan entfernt';

  @override
  String get dragGroup => 'Gruppe ziehen';

  @override
  String get requiredExercise => 'Pflichtübung';

  @override
  String get exerciseRequirement => 'Pflicht/Optional';

  @override
  String get workoutEditFailed => 'Die Änderung konnte nicht gespeichert werden. Bitte erneut versuchen.';

  @override
  String get alreadyInWorkout => 'Bereits im Workout';

  @override
  String get noExercisesFound => 'Keine passenden Übungen gefunden. Suche oder Label ändern.';

  @override
  String get swapLockedAfterSets => 'Bereits Sätze erfasst. Diese Übung kann nicht mehr ausgetauscht werden.';

  @override
  String get finishActiveWorkoutFirst => 'Bitte zuerst die laufende Einheit fortsetzen oder beenden.';

  @override
  String get profilesTitle => 'Trainingsorte & Geräte';

  @override
  String get profileTemplate => 'Vorlage';

  @override
  String get homeGym => 'Home Gym';

  @override
  String get gym => 'Gym';

  @override
  String get individualProfile => 'Individuell';

  @override
  String get selectAllEquipment => 'Alle auswählen';

  @override
  String get clearEquipment => 'Auswahl aufheben';

  @override
  String get profileRequired => 'Wähle ein Profil für dieses Workout.';

  @override
  String get profileSharedHint => 'Änderungen am Equipment gelten für alle Workouts mit diesem Profil.';

  @override
  String get profileOnboardingTitle => 'Wo trainierst du?';

  @override
  String get profileOnboardingHint => 'Wähle deinen Standard für neue Workouts und prüfe dein Equipment. Weitere Profile kannst du jederzeit anlegen.';

  @override
  String get profileIntroTitle => 'Profile einrichten';

  @override
  String get profileIntroBody => 'Home Gym und Gym als Vorlagen nutzen und deinen Standard wählen.';

  @override
  String get later => 'Später';

  @override
  String get configure => 'Einrichten';

  @override
  String get preferredProfile => 'Standard für neue Workouts';

  @override
  String get useExistingProfile => 'Vorhandenes Profil verwenden';

  @override
  String get moreWorkoutProfiles => 'Weiteres Profil verwenden';

  @override
  String get copyWorkoutExercises => 'Übungen übernehmen';

  @override
  String get emptyWorkoutProfile => 'Leer beginnen';

  @override
  String get configureWorkoutProfile => 'Wie möchtest du dieses Profil einrichten?';

  @override
  String get linkWorkoutProfile => 'Mit vorhandenen Übungen verbinden';

  @override
  String get discardWorkoutDraft => 'Workout-Entwurf verwerfen?';

  @override
  String get discard => 'Verwerfen';

  @override
  String get noExercisesToStart => 'Füge zuerst Übungen hinzu.';

  @override
  String get duplicateCheckFailed => 'Dublettenprüfung nicht verfügbar.';

  @override
  String get weeklyRecurrence => 'Dieser Plan wiederholt sich jede Woche.';

  @override
  String get allWorkoutsPlanned => 'Alle Workouts sind für diesen Tag eingeplant.';

  @override
  String get noWorkoutsToPlan => 'Erstelle zuerst ein Workout.';

  @override
  String get profileArchived => 'Archiviert';

  @override
  String equipmentSelectionCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String startWithProfile(String name) {
    return 'Mit $name starten';
  }

  @override
  String applyExerciseSelection(int count) {
    return 'Übernehmen ($count)';
  }
}
