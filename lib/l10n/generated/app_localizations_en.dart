// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String refinementText(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'k_durationHint': 'Minutes, e.g. 45 or 45:30',
        'k_durationError': 'Enter a time above 0, e.g. 45 or 45:30.',
        'k_notFaster': 'No faster than',
        'k_notSlower': 'No slower than',
        'k_estimated': 'Rough estimate',
        'k_benchmark': 'From recent best time',
        'k_manual': 'Custom',
        'k_effort': 'By effort',
        'k_resetTarget': 'Use suggestion',
        'k_recoveryMovement': 'Recovery',
        'k_run': 'Easy jog',
        'k_walk': 'Walk',
        'k_rest': 'Stand',
        'k_bestTime': 'Add best time',
        'k_bestDate': 'Best time date',
        'k_profileWhy': 'Why these details?',
        'k_profileExplanation': 'Your easy pace provides a rough pace guide. A recent best time enables additional estimates. Running frequency and longest run limit the starting load; faster does not automatically mean more volume. Heart-rate zones require resting and maximum heart rate.',
        'k_availableDays': 'Available days',
        'k_sessionsPerWeek': 'Sessions per week',
        'k_custom': 'Custom',
        'k_pushCore': 'Push + core',
        'k_pullLegs': 'Pull + legs',
        'k_mixedSplit': 'Push + core / Pull + legs / Full body',
        'k_focus': 'Focus',
        'k_core': 'Core',
        'k_endDate': 'Plan end (optional)',
        'k_indefinite': 'No end date',
        'k_extraWorkout': 'Start another workout',
        'k_splitSession': 'Split session',
        'k_swap': 'Swap sessions',
        'k_undoSplit': 'Undo split',
        'k_templates': 'Templates',
        'k_extras': 'More exercises',
        'k_missingEquipment': 'Equipment missing',
        'k_streetMap': 'Load street map',
        'k_mapPrivacy': 'The map is loaded from OpenStreetMap. The provider receives your IP address and the displayed map area. Your route stays local.',
        'k_noRoute': 'No GPS route data is available for this session.',
        'k_runningBlocks': 'Running blocks',
        'k_updateTargets': 'Apply new pace suggestions?',
        'k_updateTargetsInfo': 'Only future automatic targets are updated. Custom targets and started sessions stay unchanged.',
        'k_shortPlan': 'This plan ends before the suggested running build-up. Later sessions are omitted; progression is not accelerated.',
        'k_splitHint': 'Selected exercises stay on day 1. All others move to day 2.',
        'k_muscleFocus': 'Individual muscle groups',
        'k_chest': 'Chest',
        'k_back': 'Back',
        'k_shoulders': 'Shoulders',
        'k_arms': 'Arms',
        'k_quads': 'Thighs',
        'k_glutes': 'Glutes',
        'k_calves': 'Calves',
        'k_manualEntry': 'Manual log',
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
        'k_exercises': 'Exercises',
        'k_start': 'Home',
        'k_settings': 'Settings',
        'k_createPlan': 'Create training plan',
        'k_resumePlan': 'Continue plan',
        'k_withoutPlan': 'Train without a plan',
        'k_planIntro': 'Your week. Your training.',
        'k_planHint': 'Strength and running, planned together.',
        'k_myPlan': 'My training plan',
        'k_savedPlans': 'Saved plans',
        'k_choosePlan': 'Which plan would you like to use?',
        'k_choosePlanHint': 'Your existing plans are kept.',
        'k_today': 'Today',
        'k_week': 'This week',
        'k_restDay': 'A day to recover.',
        'k_unitsDone': 'sessions completed',
        'k_newWorkout': 'Create workout',
        'k_ownWorkouts': 'Your workouts',
        'k_templates': 'Templates',
        'k_all': 'All',
        'k_strength': 'Strength',
        'k_running': 'Running',
        'k_cardio': 'Other cardio',
        'k_mobility': 'Mobility',
        'k_emptyWorkouts': 'No workouts yet',
        'k_typeQuestion': 'What would you like to train?',
        'k_emptyWorkout': 'Start from scratch',
        'k_assignWorkout': 'Assign workout',
        'k_workoutUnavailable': 'This workout is no longer available.',
        'k_profile': 'My profile',
        'k_runningProfile': 'Your running profile',
        'k_strengthProfile': 'Your strength profile',
        'k_equipment': 'Training locations & equipment',
        'k_interests': 'What do you train?',
        'k_units': 'Units',
        'k_metric': 'Kilometres',
        'k_imperial': 'Miles',
        'k_connections': 'Connections',
        'k_sensorBackup': 'Back up GPS and sensor data',
        'k_sensorHint': 'Optional in cloud backups. Your local data is kept.',
        'k_look': 'Your look',
        'k_lookHint': 'Make Trainy feel like yours.',
        'k_backup': 'Your backup',
        'k_backupHint': 'Optionally back up with Google. Trainy works without an account.',
        'k_health': 'Connect activities',
        'k_healthHint': 'Import completed workouts from Health, not a live watch connection.',
        'k_connect': 'Connect',
        'k_connected': 'Connected',
        'k_later': 'Later',
        'k_next': 'Continue',
        'k_back': 'Back',
        'k_done': 'Done',
        'k_save': 'Save',
        'k_retry': 'Retry',
        'k_error': 'That didn\'t work. Your entries are kept.',
        'k_savingError': 'Not saved. Please try again.',
        'k_days': 'When would you like to train?',
        'k_availableDays': 'Available days',
        'k_strengthDays': 'Your strength days',
        'k_runningDays': 'Your running days',
        'k_mobilityDays': 'Your mobility days',
        'k_dayRequired': 'Choose at least one training day.',
        'k_chooseSport': 'Choose at least one activity.',
        'k_name': 'Plan name',
        'k_nameRequired': 'Give your plan a name.',
        'k_goal': 'Your goal',
        'k_strengthGoal': 'Strength goal',
        'k_runningGoal': 'Running goal',
        'k_generalFitness': 'Stay fit',
        'k_buildMuscle': 'Build muscle',
        'k_getStronger': 'Get stronger',
        'k_runFaster': 'Run faster',
        'k_runFurther': 'Run further',
        'k_firstDistance': 'Complete the distance',
        'k_targetDistance': 'Target distance',
        'k_targetTime': 'Goal time (optional)',
        'k_targetDate': 'Target date (optional)',
        'k_startDate': 'Start date',
        'k_optional': 'Optional',
        'k_none': 'Not specified',
        'k_preview': 'Your week',
        'k_activate': 'Use this plan',
        'k_edit': 'Edit',
        'k_replace': 'Change',
        'k_split': 'Your split',
        'k_fullBody': 'Full body',
        'k_upperLower': 'Upper/lower body',
        'k_pushPullLegs': 'Push/pull/legs',
        'k_upper': 'Upper body',
        'k_lower': 'Lower body',
        'k_push': 'Push',
        'k_pull': 'Pull',
        'k_legs': 'Legs',
        'k_splitHint': 'A suggestion — tap to adjust.',
        'k_missingWorkouts': 'Assign the remaining workouts',
        'k_weeklyRepeat': 'Repeats weekly',
        'k_alternating': 'Alternates every two weeks',
        'k_weekNumber': 'Week',
        'k_level': 'How would you describe your experience?',
        'k_starting': 'Getting started',
        'k_beginner': 'Beginner',
        'k_intermediate': 'Intermediate',
        'k_experienced': 'Experienced',
        'k_startingHint': 'I\'m just starting to run.',
        'k_beginnerHint': 'I already run and am building a base.',
        'k_intermediateHint': 'I run regularly, including longer distances.',
        'k_experiencedHint': 'I regularly train tempo and intervals.',
        'k_canFive': 'Can you run 5 km without walking?',
        'k_yes': 'Yes',
        'k_notYet': 'Not yet',
        'k_unknown': 'Not sure',
        'k_performance': 'Your current pace',
        'k_distance': 'Distance',
        'k_time': 'Time',
        'k_pace': 'Pace',
        'k_timeQuestion': 'How long does this distance take you?',
        'k_durationHint': 'Minutes:seconds, e.g. 32:30',
        'k_durationError': 'Enter a time above 0 as mm:ss.',
        'k_positiveError': 'Enter a number greater than 0.',
        'k_numberError': 'Enter a valid number.',
        'k_performanceKind': 'What does this time describe?',
        'k_easyRun': 'Easy training run',
        'k_bestRun': 'Best-effort run',
        'k_testDate': 'When was this run?',
        'k_dateRequired': 'Choose the date of your run.',
        'k_testInfo': 'Only recent best efforts support race estimates. Training times are not maximal tests.',
        'k_load': 'Your recent training',
        'k_longest': 'Longest run in the last 4 weeks',
        'k_continuous': 'How long can you run easily without walking?',
        'k_minutes': 'Minutes',
        'k_recentFrequency': 'How often have you run per week recently?',
        'k_recentHint': 'Over the last 4 weeks, not your new training goal.',
        'k_pulse': 'Heart-rate zones (optional)',
        'k_restPulse': 'Resting heart rate',
        'k_maxPulse': 'Maximum heart rate',
        'k_pulseError': 'Enter a whole number between 25 and 250.',
        'k_pulseOrder': 'Maximum heart rate must exceed resting heart rate.',
        'k_pulseMissing': 'Both values are needed to calculate zones.',
        'k_zoneInfo': 'Karvonen estimate, not a performance assessment. You can edit target zones.',
        'k_move': 'Move',
        'k_onlyThis': 'Only this session',
        'k_future': 'Future sessions too',
        'k_conflict': 'Check training load',
        'k_conflictHint': 'Sessions are close together. Move a demanding run or leg day to another available day.',
        'k_doubleDay': 'More than one session on a day',
        'k_changeDays': 'Adjust days',
        'k_planEstimate': 'A suggestion, not a performance promise.',
        'k_editRunning': 'Edit running block',
        'k_editStrength': 'Edit strength block',
        'k_regenerate': 'Update running proposal',
        'k_regenerateHint': 'Only unchanged future runs are replaced. History and manual edits are kept.',
        'k_delete': 'Delete',
        'k_cancel': 'Cancel',
        'k_deleteWorkout': 'Delete workout?',
        'k_add': 'Add',
        'k_calendar': 'Calendar',
        'k_continueWorkout': 'Resume workout',
        'k_viewAll': 'Show all',
        'k_runNeedsDays': 'Choose running days to generate a running plan.',
        'k_restore': 'Restore backup',
        'k_keepLocal': 'Continue locally',
        'k_backupFound': 'Backup found',
        'k_restoreHint': 'Restoring replaces local training data. Continuing without restoring leaves your cloud backup unchanged.',
        'k_summary': 'Overview',
        'k_planSaved': 'Plan saved',
        'k_finishSetup': 'Continue setup',
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
        'k_cardio': 'Endurance',
        'k_library': 'Workouts',
        'k_plan': 'Training plan',
        'k_history': 'History',
        'k_profile': 'Running profile',
        'k_settings': 'Endurance settings',
        'k_newWorkout': 'Create workout',
        'k_edit': 'Edit',
        'k_save': 'Save',
        'k_cancel': 'Cancel',
        'k_delete': 'Delete',
        'k_add': 'Add',
        'k_start': 'Start',
        'k_continueLabel': 'Continue',
        'k_skip': 'Skip',
        'k_warmup': 'Warm-up',
        'k_cooldown': 'Cool-down',
        'k_core': 'Main workout',
        'k_name': 'Name',
        'k_sport': 'Sport',
        'k_indoor': 'Indoor',
        'k_outdoor': 'Outdoor',
        'k_running': 'Running',
        'k_walking': 'Walking',
        'k_cycling': 'Cycling',
        'k_stepper': 'Stair stepper',
        'k_elliptical': 'Elliptical',
        'k_rowing': 'Rowing',
        'k_other': 'Other',
        'k_time': 'Duration',
        'k_distance': 'Distance',
        'k_seconds': 'Seconds',
        'k_minutes': 'Minutes',
        'k_meters': 'Meters',
        'k_repeat': 'Repeats',
        'k_recovery': 'Recovery',
        'k_standing': 'Standing recovery',
        'k_easy': 'Easy',
        'k_steady': 'Steady',
        'k_threshold': 'Threshold',
        'k_interval': 'Interval',
        'k_free': 'Free effort',
        'k_intensity': 'Intensity',
        'k_run': 'Run',
        'k_walk': 'Walk',
        'k_rest': 'Rest',
        'k_movement': 'Movement',
        'k_pace': 'Pace',
        'k_speed': 'Speed',
        'k_heartRate': 'Heart rate',
        'k_target': 'Target',
        'k_minSpeed': 'Min. speed (m/s)',
        'k_maxSpeed': 'Max. speed (m/s)',
        'k_minPulse': 'Lower target heart rate',
        'k_maxPulse': 'Upper target heart rate',
        'k_primary': 'Primary guidance',
        'k_effort': 'Perceived effort',
        'k_reference': 'Reference time',
        'k_referenceDistance': 'Reference distance',
        'k_referenceDate': 'Reference date',
        'k_maximal': 'Maximal test / race',
        'k_weekly': 'Weekly distance',
        'k_longest': 'Longest run (last 4 weeks)',
        'k_continuous': 'Continuous running (minutes)',
        'k_experience': 'Regular running experience (months)',
        'k_restPulse': 'Resting heart rate (optional)',
        'k_maxHeartRate': 'Maximum heart rate (optional)',
        'k_days': 'Training days',
        'k_metric': 'Kilometers / meters',
        'k_imperial': 'Miles',
        'k_units': 'Units',
        'k_zones': 'Estimated heart rate zones',
        'k_zoneInfo': 'Karvonen: resting heart rate + fraction × (maximum − resting heart rate). Trainy uses five bands from 50–100% of heart rate reserve. Individual thresholds may differ; performance testing provides more accurate zones.',
        'k_benchmarkInfo': 'Pace suggestions require a maximal test within the last 90 days. Ordinary training pace does not predict race performance.',
        'k_invalid': 'Please check your entries.',
        'k_error': 'That did not work. Your locally saved data is preserved.',
        'k_retry': 'Retry',
        'k_noData': 'No activities yet',
        'k_finish': 'Hold for 2 seconds to finish',
        'k_finishAccessible': 'Finish workout',
        'k_confirmFinish': 'Finish and save this workout?',
        'k_pause': 'Pause',
        'k_resume': 'Resume',
        'k_paused': 'Paused',
        'k_active': 'Workout in progress',
        'k_completed': 'Completed',
        'k_elapsed': 'Elapsed time',
        'k_activeTime': 'Active time',
        'k_remaining': 'Remaining',
        'k_next': 'Up next',
        'k_average': 'Average',
        'k_half': 'Halfway',
        'k_nearEnd': 'Almost there',
        'k_faster': 'Run a little faster',
        'k_slower': 'Run a little slower',
        'k_gpsLost': 'GPS unavailable – distance measurement interrupted',
        'k_gpsReady': 'GPS active',
        'k_gpsWaiting': 'Searching for GPS',
        'k_locationDenied': 'Precise location permission is required for outdoor distance tracking.',
        'k_openSettings': 'Open settings',
        'k_audioUnavailable': 'No offline voice available. Set up audio in system settings.',
        'k_indoorInfo': 'Without a sensor, indoor distance, live pace and auto-pause are unavailable. Distance targets can be converted to time using a target speed.',
        'k_convert': 'Convert distance targets to time',
        'k_backgroundLimited': 'Indoor on this iOS version: keep the app open.',
        'k_pulseLater': 'Heart rate is added after training through Health. Live guidance uses pace or perceived effort.',
        'k_autoPause': 'Auto-pause after 10 seconds standing still',
        'k_mediaPending': 'Video not yet available – follow the movement instructions.',
        'k_routineInfo': 'Move slowly and with control within a comfortable range. Split unilateral exercises between both sides.',
        'k_easy5k': 'Easy 5K',
        'k_longRun': 'Long run',
        'k_runWalk': 'Run–walk',
        'k_progression': 'Progression run',
        'k_tempo': 'Tempo run',
        'k_pyramid': 'Pyramid intervals',
        'k_descending': 'Descending intervals',
        'k_fourByFour': '4 × 4 minutes',
        'k_fartlek': 'Fartlek',
        'k_strides': 'Strides',
        'k_drills': 'Running drills',
        'k_easySession': 'Easy run',
        'k_intervalSession': 'Timed intervals',
        'k_goalDistance': 'Target distance',
        'k_goalTime': 'Desired target time (optional, minutes)',
        'k_goalDate': 'Preferred date (optional)',
        'k_generate': 'Suggest plan',
        'k_accept': 'Accept',
        'k_preview': 'Preview',
        'k_planInfo': 'Conservative planning based on your previous training. Target times and time frames are not performance promises. Changes require confirmation.',
        'k_basePhase': 'Build a base first',
        'k_infeasible': 'The date or training base does not yet fit the goal. The proposal includes a longer base phase.',
        'k_move': 'Move',
        'k_onlyThis': 'Only this activity',
        'k_futureToo': 'Also future occurrences on this weekday',
        'k_locked': 'Manually fixed',
        'k_skipped': 'Skipped',
        'k_adapt': 'Suggest adjustment',
        'k_adaptInfo': 'Following missed activities, upcoming training load is reduced; fixed and completed activities are preserved.',
        'k_rpe': 'How hard was it? (1–10)',
        'k_discomfort': 'Discomfort',
        'k_health': 'Connect Health',
        'k_import': 'Review activities',
        'k_export': 'Save to Health',
        'k_dismiss': 'Dismiss',
        'k_link': 'Link to existing activity',
        'k_backupSensors': 'Include routes and sensor history in cloud backups',
        'k_backupInfo': 'By default, only profile, plans and summaries are backed up.',
        'k_healthInfo': 'Trainy reads completed workouts and heart rate locally from Apple Health or Health Connect. Imports can be reviewed. This does not create a live connection to your watch.',
        'k_healthUnavailable': 'Health is unavailable on this device.',
        'k_healthExported': 'Saved to Health',
        'k_healthPermission': 'Health access was not granted.',
        'k_strengthActive': 'Please finish the active workout first.',
        'k_saved': 'Saved locally',
        'k_newPlan': 'New running plan',
        'k_date': 'Date',
        'k_week': 'Week',
        'k_summary': 'Summary',
        'k_estimated': 'Estimated',
        'k_recovered': 'Recovered; check for possible measurement gaps',
        'k_interests': 'What would you like to train?',
        'k_strength': 'Strength',
        'k_mobility': 'Mobility',
        'k_focus': 'Training focus',
        'k_power': 'Power',
        'k_muscularEndurance': 'Muscular endurance',
        'k_dynamic': 'Dynamic',
        'k_staticStretch': 'Static / stretching',
        'k_copy': 'Duplicate',
        'k_deleteConfirm': 'Delete this entry?',
        'k_localOnly': 'Everything is stored and calculated locally.',
        'k_secondsPerKm': 'Seconds per kilometer',
        'k_restDays': 'Check recovery: training on consecutive days.',
        'k_sensorCoverage': 'Measurement coverage',
        'k_privacy': 'Health data and privacy',
        'k_privacyBody': 'Trainy processes training data locally on this device. Health access is optional and can be revoked in system settings. Cloud backup is separately optional; detailed routes require additional consent. Health data is not sold for advertising.',
        'k_ankleRocks': 'Ankle rocks',
        'k_calfRaises': 'Calf raises',
        'k_legSwings': 'Forward/backward leg swings',
        'k_lateralSwings': 'Sideways leg swings',
        'k_reverseLunge': 'Reverse lunge with reach',
        'k_march': 'March with arm swings',
        'k_hinge': 'Hip hinge',
        'k_squat': 'Easy squats',
        'k_rotation': 'Thoracic rotation',
        'k_lateralLunge': 'Lateral lunge',
        'k_gluteBridge': 'Glute bridge',
        'k_birdDog': 'Bird dog',
        'k_shoulderCircles': 'Shoulder circles',
        'k_armCircles': 'Arm circles',
        'k_wallSlides': 'Wall slides',
        'k_scapularPushup': 'Scapular push-up',
        'k_calfStretch': 'Calf stretch',
        'k_hipFlexor': 'Hip flexor stretch',
        'k_hamstring': 'Hamstring stretch',
        'k_quadStretch': 'Quadriceps stretch',
        'k_gluteStretch': 'Glute stretch',
        'k_chestStretch': 'Chest stretch',
        'k_latStretch': 'Lat stretch',
        'k_shoulderStretch': 'Posterior shoulder stretch',
        'k_aMarch': 'A-march',
        'k_ankling': 'Ankling',
        'k_aSkip': 'A-skip',
        'k_buttKicks': 'Heel flicks',
        'k_sideSteps': 'Side steps',
        'k_lower': 'Lower body',
        'k_upper': 'Upper body',
        'k_startError': 'Unable to start. Check permissions, targets, and whether another workout is active.',
        'k_storageError': 'Recording is not fully saved. Please pause and check free storage.',
        'k_holdFinish': 'Hold for 2 seconds to finish',
        'k_templates': 'Templates',
        'k_profileIntro': 'Add a benchmark, heart rates and available days for personalised suggestions.',
        'k_cardioIntro': 'Running, cycling and more endurance sports',
        'k_equivalent': 'Current estimated equivalent — not a future prediction',
        'k_noAdjustment': 'No adjustment suggested right now. You can always edit individual workouts.',
        'k_refresh': 'Find workouts from the last 29 days',
        'k_disconnect': 'Disable automatic refresh',
        'k_importConfirm': 'Import or link this workout?',
        'k_healthError': 'Health is unavailable or access is restricted. Check system permissions. An export with an uncertain result is not retried automatically; check Health to avoid duplicates.',
        'k_ankleRocksInstruction': 'In a short split stance, move the front knee gently over the toes while keeping the heel down. Switch sides halfway.',
        'k_calfRaisesInstruction': 'Stand tall. Slowly lift both heels and lower with control. Use a wall for balance if needed.',
        'k_legSwingsInstruction': 'Use a wall for balance. Swing one leg gently forward and back with a stable pelvis. Switch halfway.',
        'k_lateralSwingsInstruction': 'Use a wall for balance. Gently swing one leg from side to side. Switch halfway.',
        'k_reverseLungeInstruction': 'Alternate small backward steps and gently bend both knees. Push up through the whole front foot.',
        'k_marchInstruction': 'March tall in place. Lift knees comfortably and swing opposite arms.',
        'k_hingeInstruction': 'Keep knees soft, send hips back and lean forward with a long spine. Return with control.',
        'k_squatInstruction': 'Stand with feet comfortably apart. Lower hips slowly back and down, then stand. Use a comfortable depth.',
        'k_rotationInstruction': 'Stand tall and gently rotate the upper body left and right, keeping hips mostly still.',
        'k_lateralLungeInstruction': 'Step sideways and gently bend the loaded knee. Return to centre and switch.',
        'k_gluteBridgeInstruction': 'Lie on your back with knees bent. Lift hips without arching the lower back, then lower.',
        'k_birdDogInstruction': 'On hands and knees, slowly extend the opposite arm and leg. Keep the back steady, then switch.',
        'k_shoulderCirclesInstruction': 'Relax your arms and make small, slow shoulder circles backwards and forwards.',
        'k_armCirclesInstruction': 'Raise arms comfortably to the sides and make small circles. Increase range only if pain-free.',
        'k_wallSlidesInstruction': 'Stand with your back lightly against a wall. Slide arms up and down without arching your back.',
        'k_scapularPushupInstruction': 'On hands and knees with straight arms, gently move the shoulder blades together and apart.',
        'k_calfStretchInstruction': 'Place hands on a wall in a split stance. Keep the back leg straight and heel down. Hold gently without bouncing. Switch halfway.',
        'k_hipFlexorInstruction': 'In a padded half-kneeling stance, gently tuck the pelvis and shift forward without arching. Switch halfway.',
        'k_hamstringInstruction': 'Place one heel in front with a soft knee. Gently hinge at the hips with a long back. Switch halfway.',
        'k_quadStretchInstruction': 'Hold a support and bring one foot behind you. Keep knees near each other and pelvis steady; do not pull hard. Switch halfway.',
        'k_gluteStretchInstruction': 'Lie on your back with one ankle over the opposite knee. Gently draw the lower leg toward you. Switch halfway.',
        'k_chestStretchInstruction': 'Place a forearm gently against a doorway and turn slightly away. Keep the shoulder relaxed. Switch halfway.',
        'k_latStretchInstruction': 'Place hands on a stable surface. Send hips back and lengthen the back without forcing the shoulders.',
        'k_shoulderStretchInstruction': 'Bring one arm across the body and gently support it with the other. Keep the shoulder down. Switch halfway.',
        'k_aMarchInstruction': 'March slowly forward, lift one knee and place the foot under the body. Use opposite arm action.',
        'k_anklingInstruction': 'Move forward in very small steps with relaxed, springy ankle action and an upright torso.',
        'k_aSkipInstruction': 'If familiar: use small relaxed skips with alternating knee lifts. March instead if preferred. Land softly.',
        'k_buttKicksInstruction': 'Jog gently in place and alternate lifting heels behind you without forcing the movement.',
        'k_sideStepsInstruction': 'Take small controlled side steps without crossing your feet. Change direction halfway.',
        'k_targetTimeInfo': 'The target time is an aspiration, not a promised improvement. Training pace stays based on your current test and is updated after a new test.',
        'k_route': 'Locally recorded route without map tiles',
        'k_audioSetup': 'Install an offline voice for the selected app language in system settings. You can continue without speech; cues will only be visible on the screen.',
        'k_custom': 'Custom exercise',
        'k_instructions': 'Instructions (optional)',
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
  String get language => 'Language';

  @override
  String get home => 'Home';

  @override
  String get exercises => 'Exercises';

  @override
  String get progress => 'Progress';

  @override
  String get progressDescription => 'Track your training progress. History shows your completed workouts; Insights contains the calendar and exercise charts.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsDescription => 'Customize Trainy, set weekly goals, and back up your data to the cloud.';

  @override
  String get more => 'More';

  @override
  String get workouts => 'Workouts';

  @override
  String get workout => 'Workout';

  @override
  String get exercise => 'Exercise';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get info => 'Info';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get search => 'Search';

  @override
  String get clear => 'Clear';

  @override
  String get change => 'Change';

  @override
  String get appearance => 'Appearance';

  @override
  String get designMode => 'Theme mode';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get accentColor => 'Accent color';

  @override
  String get goals => 'Goals';

  @override
  String get trainingDays => 'Training days';

  @override
  String get trainingDaysPerWeek => 'Training days per week';

  @override
  String get weeklyGoal => 'Weekly goal';

  @override
  String get thisWeek => 'This week';

  @override
  String get weekOverview => 'Weekly overview';

  @override
  String get todayWorkout => 'Today\'s workout';

  @override
  String trainingForDay(String day) {
    return '$day workout';
  }

  @override
  String get restDay => 'Rest day';

  @override
  String get trainingPlan => 'Training plan';

  @override
  String workoutsInARow(int count) {
    return '$count workouts in a row';
  }

  @override
  String workoutsCount(int count) {
    return '$count workout(s)';
  }

  @override
  String exercisesCount(int count) {
    return '$count exercise(s)';
  }

  @override
  String get newWorkout => 'New workout';

  @override
  String get workoutName => 'Workout name';

  @override
  String get enterWorkoutName => 'Enter workout name';

  @override
  String get workoutDetails => 'Workout details';

  @override
  String get workoutDuration => 'Workout duration';

  @override
  String get editWorkoutDuration => 'Edit workout duration';

  @override
  String get editDuration => 'Edit duration';

  @override
  String get editSets => 'Edit sets';

  @override
  String get editRepetitions => 'Edit repetitions';

  @override
  String get editWeight => 'Edit weight';

  @override
  String get editDistance => 'Edit distance';

  @override
  String get editValue => 'Edit value';

  @override
  String addValue(String label) {
    return 'Add $label';
  }

  @override
  String get exampleInteger => 'e.g. 10';

  @override
  String get exampleDecimal => 'e.g. 42.5';

  @override
  String get deleteWorkout => 'Delete workout?';

  @override
  String deleteWorkoutConfirmation(String name) {
    return 'Delete \"$name\" permanently?';
  }

  @override
  String get renameWorkout => 'Rename workout';

  @override
  String get noWorkouts => 'No workouts yet';

  @override
  String get createFirstWorkout => 'Create workouts, add exercises, and track your progress.';

  @override
  String get createWorkout => 'Create workout';

  @override
  String get addExercises => 'Add exercises';

  @override
  String get noExercises => 'No exercises yet';

  @override
  String get createFirstExercise => 'Create your first exercise to get started.';

  @override
  String get newExercise => 'New exercise';

  @override
  String get editExercise => 'Edit exercise';

  @override
  String get exerciseName => 'Exercise name';

  @override
  String get description => 'Description';

  @override
  String get optionalDescription => 'Description (optional)';

  @override
  String get localSaveFailed => 'Could not save locally. Your input is kept for another attempt.';

  @override
  String get optional => 'optional';

  @override
  String get exerciseGoal => 'Training goal';

  @override
  String get standard => 'Standard';

  @override
  String get catalog => 'Catalog';

  @override
  String get own => 'Custom';

  @override
  String get reviewDuplicates => 'Review duplicates';

  @override
  String get noDuplicateSuggestions => 'No duplicate suggestions';

  @override
  String get adoptStandardExercise => 'Use standard exercise';

  @override
  String get keepOwnExercise => 'Keep my exercise';

  @override
  String get catalogUnavailable => 'The reviewed offline catalog is not bundled in this build yet.';

  @override
  String get catalogExerciseAdded => 'Exercise added to your library';

  @override
  String get exerciseLibrary => 'Exercises';

  @override
  String get activities => 'Activities';

  @override
  String get all => 'All';

  @override
  String matchesProfile(String name) {
    return 'Matches $name';
  }

  @override
  String get instructions => 'Instructions';

  @override
  String get exerciseArchived => 'Exercise archived; workout history stays unchanged';

  @override
  String get archive => 'Archive';

  @override
  String get undo => 'Undo';

  @override
  String get trainingProfile => 'Profile';

  @override
  String get workoutVariant => 'Workout variant';

  @override
  String get standardVariant => 'Standard';

  @override
  String get createVariant => 'Create variant';

  @override
  String get variantName => 'Variant name';

  @override
  String get editWorkoutPlan => 'Edit plan';

  @override
  String get workoutGroup => 'Workout group';

  @override
  String get groupVariant => 'Group variation';

  @override
  String get addGroup => 'Add group';

  @override
  String get groupName => 'Group name';

  @override
  String get addGroupVariant => 'Add group variation';

  @override
  String get alternatives => 'Alternatives';

  @override
  String get addAlternative => 'Add alternative exercise';

  @override
  String get core => 'Core';

  @override
  String get planExercises => 'Exercises in this variation';

  @override
  String get noGroupExercises => 'No exercises in this group variation yet.';

  @override
  String get noProfiles => 'No profile selected';

  @override
  String get profileName => 'Profile name';

  @override
  String get equipment => 'Equipment';

  @override
  String get equipmentBodyweight => 'Bodyweight';

  @override
  String get equipmentDumbbell => 'Dumbbells';

  @override
  String get equipmentBarbell => 'Barbell';

  @override
  String get equipmentMachine => 'Machine';

  @override
  String get equipmentCable => 'Cable';

  @override
  String get equipmentKettlebell => 'Kettlebell';

  @override
  String get equipmentBands => 'Resistance bands';

  @override
  String get equipmentBench => 'Bench';

  @override
  String get equipmentRack => 'Rack';

  @override
  String get equipmentPullUpBar => 'Pull-up bar';

  @override
  String get equipmentMedicineBall => 'Medicine ball';

  @override
  String get equipmentExerciseBall => 'Exercise ball';

  @override
  String get equipmentFoamRoller => 'Foam roller';

  @override
  String get equipmentEzBar => 'EZ bar';

  @override
  String get equipmentMat => 'Mat';

  @override
  String get equipmentCardioMachine => 'Cardio machine';

  @override
  String get equipmentOther => 'Other';

  @override
  String get noEquipmentSelected => 'No equipment selected';

  @override
  String get trainingProfileDescription => 'Manage your training locations and their equipment.';

  @override
  String get addTrainingProfile => 'New profile';

  @override
  String get editTrainingProfile => 'Edit profile';

  @override
  String get archiveProfile => 'Archive profile?';

  @override
  String archiveProfileDescription(String name) {
    return '\"$name\" will no longer be offered as a profile. Existing sessions remain unchanged.';
  }

  @override
  String get profileLoadFailed => 'Profiles could not be loaded.';

  @override
  String profileOperationFailed(String operation) {
    return 'Profile operation failed ($operation). Please retry.';
  }

  @override
  String get bodyweight => 'Bodyweight';

  @override
  String get setsAndDuration => 'Sets + duration';

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get searchExercises => 'Search exercises';

  @override
  String get tracking => 'Tracking';

  @override
  String get sets => 'Sets';

  @override
  String setsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get repetitions => 'Repetitions';

  @override
  String get weight => 'Weight';

  @override
  String get duration => 'Duration';

  @override
  String get estimatedDurationMinutes => 'Estimated duration (minutes)';

  @override
  String get distance => 'Distance';

  @override
  String get hours => 'hr';

  @override
  String get minutes => 'min';

  @override
  String get seconds => 'sec';

  @override
  String get start => 'Start';

  @override
  String get continueWorkout => 'Continue';

  @override
  String get endWorkout => 'End workout';

  @override
  String get stopAndSave => 'Stop and save';

  @override
  String get workoutCompleted => 'Workout completed!';

  @override
  String get addSet => 'Add set';

  @override
  String get saveSet => 'Save set';

  @override
  String get noSetsRecorded => 'No sets recorded.';

  @override
  String get endAnyway => 'End anyway';

  @override
  String get backdateWorkout => 'Add past workout';

  @override
  String workoutBackdated(String date) {
    return 'Workout added for $date';
  }

  @override
  String get activity => 'Activity';

  @override
  String get workoutsPerDay => 'Workouts per day';

  @override
  String get noEntries => 'No entries yet';

  @override
  String get startWorkoutToSeeEntries => 'Start a workout and record sets to see progress here.';

  @override
  String get calendar => 'Calendar';

  @override
  String get cloudBackup => 'Cloud backup';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signOut => 'Sign out';

  @override
  String get automaticBackup => 'Automatic backup';

  @override
  String get backupNow => 'Back up now';

  @override
  String get loadFromCloud => 'Load from cloud';

  @override
  String get backupLoaded => 'Backup loaded';

  @override
  String get backupUploaded => 'Backup uploaded';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backUp => 'Back up';

  @override
  String get load => 'Load';

  @override
  String get merge => 'Merge';

  @override
  String get restore => 'Restore';

  @override
  String get restoreBackup => 'Restore backup?';

  @override
  String get restoreBackupDescription => 'Local data will be replaced by the cloud backup.';

  @override
  String get signedInSuccessfully => 'Signed in successfully';

  @override
  String get merged => 'Merged';

  @override
  String get lowContrast => 'Your accent color has low contrast in this mode.';

  @override
  String get error => 'Error';

  @override
  String get understood => 'Got it';

  @override
  String get history => 'History';

  @override
  String get insights => 'Insights';

  @override
  String get minutesPerDay => 'Minutes per day';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String workoutsRecordedOnDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts recorded',
      one: '1 workout recorded',
      zero: 'No workouts',
    );
    return '$_temp0';
  }

  @override
  String activeWorkoutBanner(String name) {
    return 'Active workout: $name. Tap to continue.';
  }

  @override
  String get deleteEntry => 'Delete entry?';

  @override
  String get deleteEntryDescription => 'This workout entry will be permanently deleted.';

  @override
  String deletedExercise(int id) {
    return 'Deleted exercise ($id)';
  }

  @override
  String get notAvailable => 'No longer available';

  @override
  String formerName(String name) {
    return 'former: $name';
  }

  @override
  String get greatWork => 'Great work!';

  @override
  String get recommendation => 'Recommendation';

  @override
  String get exerciseProgress => 'Exercise progress';

  @override
  String get exerciseDescription => 'Manage your exercises. Create new exercises, edit existing ones, and choose which metrics to track.';

  @override
  String get editExerciseConfirmationTitle => 'Edit exercise?';

  @override
  String get editExerciseConfirmation => 'Changes affect every workout that uses this exercise.';

  @override
  String mergeExercises(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' ($count)',
      zero: '',
    );
    return 'Merge exercises$_temp0';
  }

  @override
  String get removeEntry => 'Remove entry?';

  @override
  String removeMergeEntryDescription(String name, String target) {
    return 'Remove \"$name\" from merge history?\n\nTransferred workout entries remain assigned to \"$target\".';
  }

  @override
  String get noOtherExercise => 'No other exercise is available.';

  @override
  String mergeInto(String name) {
    return 'Merge into \"$name\":';
  }

  @override
  String get confirmMerge => 'Merge?';

  @override
  String mergeDescription(String source, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recorded entries remain unchanged.\n',
      one: '1 recorded entry remains unchanged.\n',
      zero: '',
    );
    return 'Use \"$target\" for future workouts instead of \"$source\"?\n\n${_temp0}You can undo this later.';
  }

  @override
  String mergedResult(String source, String target) {
    return '\"$source\" → \"$target\" merged';
  }

  @override
  String get mergeHistory => 'Merge history';

  @override
  String get noMergedExercises => 'No exercises merged yet.';

  @override
  String mergedOn(String date) {
    return 'Merged on $date';
  }

  @override
  String get newMerge => 'Merge another exercise';

  @override
  String get deleteExercise => 'Delete exercise?';

  @override
  String deleteExerciseConfirmation(String name) {
    return 'Delete \"$name\" permanently? Existing workout data is retained.';
  }

  @override
  String deleteExerciseWithEntries(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workout entries stay unchanged.',
      one: '1 workout entry stays unchanged.',
    );
    return 'Archive \"$name\"? $_temp0';
  }

  @override
  String get permanentlyDelete => 'Delete permanently';

  @override
  String exerciseDeleted(String name) {
    return '\"$name\" deleted';
  }

  @override
  String get noExercisesDescription => 'Create your first exercise.';

  @override
  String get homeDescription => 'Your dashboard at a glance. See your weekly overview, planned workouts, and start training directly.';

  @override
  String get noExercisesInWorkout => 'This workout has no exercises.';

  @override
  String get getStarted => 'Let\'s go';

  @override
  String get firstWorkout => 'Create your first workout';

  @override
  String get noWorkoutsAvailable => 'No workouts available';

  @override
  String get selectWorkout => 'Select workout';

  @override
  String get trained => 'trained';

  @override
  String get planned => 'planned';

  @override
  String get noTrackingFieldsActive => 'No tracking fields are enabled.';

  @override
  String get saveRecordedSets => 'Recorded sets will be saved.';

  @override
  String get endWithoutSets => 'No sets recorded. End anyway?';

  @override
  String get weightKilograms => 'Weight (kg)';

  @override
  String get distanceKilometers => 'Distance (km)';

  @override
  String get allExercisesAlreadyInWorkout => 'All exercises are already in this workout.';

  @override
  String get addExercise => 'Add exercise';

  @override
  String get pause => 'Pause';

  @override
  String recordedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets recorded',
      one: '1 set recorded',
    );
    return '$_temp0';
  }

  @override
  String setNumber(int number) {
    return 'Set $number';
  }

  @override
  String workoutCreatedAndAdded(String name) {
    return '\"$name\" was created and added';
  }

  @override
  String get nameMissing => 'Name missing';

  @override
  String get enterName => 'Please enter a name';

  @override
  String get addExistingExercises => 'Existing exercises';

  @override
  String get createNewExercise => 'Create new exercise';

  @override
  String get addSelected => 'Add selected';

  @override
  String get exercisesAdded => 'Exercises added';

  @override
  String get remove => 'Remove';

  @override
  String get additionalExercises => 'Add more exercises';

  @override
  String get addExercisesToStart => 'Add exercises to start your workout.';

  @override
  String get rename => 'Rename';

  @override
  String get apply => 'Apply';

  @override
  String get cloudBackupFound => 'Cloud backup found';

  @override
  String get cloudBackupDescription => 'Back up your data to the cloud.';

  @override
  String get setUpCloudBackup => 'Set up cloud backup?';

  @override
  String get setUpCloudBackupDescription => 'Sign in to securely back up your workout data to the cloud and sync it between devices. This is optional and the app remains local-first.';

  @override
  String get continueWithoutCloud => 'Continue without cloud';

  @override
  String get cloudBackupAccountFoundDescription => 'A cloud backup already exists for this account. How would you like to continue?';

  @override
  String get doNotLoad => 'Don\'t load';

  @override
  String get loadAndReplace => 'Load backup (replace)';

  @override
  String get mergeRecommended => 'Merge (recommended)';

  @override
  String get cloudOverwrite => 'Overwrite cloud backup?';

  @override
  String get cloudOverwriteDescription => 'All existing cloud-backup data will be lost. Continue?';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get cloudBackupUpdated => 'Cloud backup updated';

  @override
  String get quoteOfTheDay => 'Quote of the day';

  @override
  String motivationalQuote(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'start': 'You do not have to be perfect. You just have to start.',
        'consistency': 'Consistency beats talent.',
        'strength': 'You are stronger than you think.',
        'progress': 'Progress, not perfection.',
        'habit': 'Motivation gets you going. Habit gets you to the finish line.',
        'challenge': 'If it does not challenge you, it does not change you.',
        'smallSteps': 'Small steps are better than no steps.',
        'effort': 'Every workout counts — even the one you did not feel like doing.',
        'discipline': 'Discipline is the bridge between goals and results.',
        'today': 'What you do today shapes who you are tomorrow.',
        'routine': 'The best time to train is the time you can keep.',
        'limits': 'Your only limit is you.',
        'other': 'Keep going.',
      },
    );
    return '$_temp0';
  }

  @override
  String get signedIn => 'Signed in';

  @override
  String lastBackup(String date) {
    return 'Last backup: $date';
  }

  @override
  String get cloudBackupFoundDescription => 'An existing backup was found.';

  @override
  String get loadBackup => 'Load backup';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get backupRestoredSuccess => 'Backup restored';

  @override
  String workoutDeleted(String name) {
    return '\"$name\" deleted';
  }

  @override
  String dayStatus(String day, String status) {
    return '$day: $status';
  }

  @override
  String get addExercisesForProgress => 'Create exercises first to see progress.';

  @override
  String get completeWorkoutForProgress => 'Complete a workout to see progress data.';

  @override
  String get selectExercise => 'Select exercise';

  @override
  String get noMatches => 'No matches';

  @override
  String get searchExercise => 'Search exercise';

  @override
  String get noTrackingFields => 'No fields to track';

  @override
  String get noDataForExercise => 'No data for this exercise yet.';

  @override
  String get exerciseLabel => 'Exercise';

  @override
  String get volume => 'Volume';

  @override
  String get minimum => 'Min';

  @override
  String get maximum => 'Max';

  @override
  String get speed => 'Speed';

  @override
  String get allTime => 'All';

  @override
  String get month1 => '1M';

  @override
  String get month3 => '3M';

  @override
  String get month6 => '6M';

  @override
  String get year1 => '1Y';

  @override
  String get monday => 'Mon';

  @override
  String get tuesday => 'Tue';

  @override
  String get wednesday => 'Wed';

  @override
  String get thursday => 'Thu';

  @override
  String get friday => 'Fri';

  @override
  String get saturday => 'Sat';

  @override
  String get sunday => 'Sun';

  @override
  String goalLabel(String goal) {
    String _temp0 = intl.Intl.selectLogic(
      goal,
      {
        'strength': 'Strength',
        'endurance': 'Endurance',
        'cardio': 'Endurance',
        'mobility': 'Mobility',
        'other': 'Other',
      },
    );
    return '$_temp0';
  }

  @override
  String standardExerciseName(String key) {
    String _temp0 = intl.Intl.selectLogic(
      key,
      {
        'kraft_bankdruecken': 'Bench press',
        'kraft_kniebeugen': 'Squats',
        'kraft_kreuzheben': 'Deadlift',
        'kraft_schulterdruecken': 'Shoulder press',
        'kraft_langhantelrudern': 'Barbell row',
        'kraft_bizeps_curls': 'Biceps curls',
        'kraft_trizepsdruecken': 'Triceps press',
        'kraft_beinpresse': 'Leg press',
        'kraft_ausfallschritte': 'Lunges',
        'kraft_wadenheben': 'Calf raises',
        'kraft_russian_twist': 'Russian twist',
        'kraft_latzug': 'Lat pulldown',
        'kraft_butterfly': 'Butterfly',
        'kraft_beinbeuger': 'Leg curl',
        'kraft_beinstrecker': 'Leg extension',
        'kraft_seitheben': 'Lateral raise',
        'kraft_facepulls': 'Face pulls',
        'kraft_brustpresse': 'Chest press',
        'kraft_hip_thrusts': 'Hip thrusts',
        'kraft_reverse_flys': 'Reverse flyes',
        'kraft_bulgarian_split_squats': 'Bulgarian split squats',
        'kraft_klimmzuege': 'Pull-ups',
        'kraft_liegestuetze': 'Push-ups',
        'kraft_dips': 'Dips',
        'kraft_sit_ups': 'Sit-ups',
        'kraft_push_ups': 'Push-ups',
        'kraft_pull_ups': 'Pull-ups',
        'cardio_joggen': 'Jogging',
        'cardio_laufen': 'Running',
        'cardio_radfahren': 'Cycling',
        'cardio_intervallaeufe': 'Interval running',
        'cardio_schwimmen': 'Swimming',
        'ausdauer_plank': 'Plank',
        'ausdauer_seilspringen': 'Jump rope',
        'mobilitaet_dehnen': 'Stretching',
        'mobilitaet_yoga': 'Yoga',
        'other': 'Exercise',
      },
    );
    return '$_temp0';
  }

  @override
  String get dataAndPrivacy => 'Data & privacy';

  @override
  String get resetLocalTrainingData => 'Reset local training data';

  @override
  String get resetLocalTrainingDataDescription => 'Deletes workouts, progress and personal exercise images on this device.';

  @override
  String get resetLocalTrainingDataConfirm => 'Your local training data and personal exercise images will be deleted. Your login, language and appearance stay unchanged.';

  @override
  String get confirmResetAgain => 'Really reset local data?';

  @override
  String get confirmResetAgainDescription => 'This cannot be undone. Automatic cloud backup will be disabled.';

  @override
  String get resetNow => 'Reset now';

  @override
  String get deleteCloudData => 'Delete cloud data';

  @override
  String get deleteCloudDataDescription => 'Deletes every Trainy backup stored for this account. Local data and the account remain.';

  @override
  String get deleteCloudDataConfirm => 'All Trainy cloud objects for your account will be deleted.';

  @override
  String get confirmCloudDeleteAgain => 'Permanently delete cloud data?';

  @override
  String get confirmCloudDeleteAgainDescription => 'The operation can be retried if the connection is interrupted.';

  @override
  String get cloudDataDeleted => 'Cloud data deleted';

  @override
  String get deleteAccountAndData => 'Delete account and all data';

  @override
  String get deleteAccountAndDataDescription => 'Deletes cloud data, the Firebase account and all local app data.';

  @override
  String get deleteAccountAndDataConfirm => 'You will be asked to sign in with Google again. Then the account and all Trainy data will be deleted.';

  @override
  String get confirmAccountDeleteAgain => 'Permanently delete your account?';

  @override
  String get confirmAccountDeleteAgainDescription => 'This action cannot be undone.';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get activeWorkoutMustEnd => 'Active workout';

  @override
  String get activeWorkoutMustEndDescription => 'The current workout must be completed or discarded before data can be deleted.';

  @override
  String get discardAndContinue => 'Discard & continue';

  @override
  String get continueLabel => 'Continue';

  @override
  String get localDataRecovery => 'Local data recovery';

  @override
  String get localDataNeedsRecovery => 'Your local training data needs attention';

  @override
  String get localDataNeedsRecoveryDescription => 'Trainy did not delete the database. You can retry opening it, save a raw recovery copy, or explicitly reset the local training data.';

  @override
  String get saveRecoveryCopy => 'Save recovery copy';

  @override
  String recoverySaved(String path) {
    return 'Recovery copy saved to $path';
  }

  @override
  String get recoveryExportFailed => 'The recovery copy could not be saved.';

  @override
  String get recoveryResetDescription => 'This permanently deletes the local training database and creates a fresh one. Save a recovery copy first if you may need the data.';

  @override
  String get retry => 'Retry';

  @override
  String get finishingLocally => 'Finishing locally …';

  @override
  String get savedLocally => 'Saved locally';

  @override
  String get workoutSaveFailed => 'The workout is still available as a local draft. Saving failed; please retry.';

  @override
  String get workoutAutosaveFailed => 'A change could not be saved locally. Your input remains here; retry before finishing.';

  @override
  String get filters => 'Filters';

  @override
  String get resetFilters => 'Reset';

  @override
  String get label => 'Label';

  @override
  String get source => 'Source';

  @override
  String get allProfiles => 'All profiles';

  @override
  String get noMatchingExercises => 'No matching exercises';

  @override
  String get noMatchingExercisesDescription => 'Change your search or reset the active filters.';

  @override
  String englishSynonym(String name) {
    return 'English: $name';
  }

  @override
  String get selectImage => 'Select image';

  @override
  String get replaceImage => 'Replace image';

  @override
  String get removeImage => 'Remove image';

  @override
  String get exerciseCover => 'Exercise image';

  @override
  String get equipmentBicycle => 'Bicycle';

  @override
  String get equipmentPool => 'Swimming pool';

  @override
  String get workoutBasics => 'Basics';

  @override
  String get workoutSetup => 'Profile';

  @override
  String get workoutExercises => 'Exercises';

  @override
  String get choosePrimaryGoal => 'Choose this workout\'s primary goal';

  @override
  String get primaryGoal => 'Primary goal';

  @override
  String get setupName => 'Profile name';

  @override
  String get withoutProfile => 'No profile';

  @override
  String get createSetup => 'Add profile';

  @override
  String get selectSetup => 'Choose profile';

  @override
  String get setups => 'Profiles';

  @override
  String get weeklyPlanner => 'Weekly planner';

  @override
  String get editWeeklyPlanner => 'Edit weekly planner';

  @override
  String get addToWeeklyPlanner => 'Add to weekly planner';

  @override
  String get addWorkoutToDay => 'Add workout';

  @override
  String get noWorkoutPlanned => 'No workout planned';

  @override
  String get moveWorkout => 'Move workout';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get coreExercise => 'Required exercise';

  @override
  String get optionalExercise => 'Optional';

  @override
  String get makeOptional => 'Mark optional';

  @override
  String get makeCore => 'Mark core';

  @override
  String get moveToGroup => 'Move to another group';

  @override
  String stepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get saveWorkout => 'Save workout';

  @override
  String get noSetups => 'No profile yet';

  @override
  String setupExercisesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
      zero: 'No exercises',
    );
    return '$_temp0';
  }

  @override
  String get plannedWorkouts => 'Planned workouts';

  @override
  String get dayDetails => 'Day overview';

  @override
  String get workoutAlreadyPlanned => 'This workout is already planned for this day.';

  @override
  String get defaultSetup => 'Default';

  @override
  String get chooseSetupProfile => 'Choose a profile for this training environment.';

  @override
  String get profileSetup => 'Use this profile';

  @override
  String get makeDefaultSetup => 'Make default';

  @override
  String get warmupGroup => 'Warm-up';

  @override
  String get coreExercisesGroup => 'Main exercises';

  @override
  String get cooldownGroup => 'Cooldown';

  @override
  String get dropExercisesHere => 'Drop exercises here';

  @override
  String get dragExercise => 'Drag exercise';

  @override
  String selectedExercises(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises selected',
      one: '1 exercise selected',
    );
    return '$_temp0';
  }

  @override
  String get groupSelectedExercises => 'Group selected exercises';

  @override
  String get group => 'Group';

  @override
  String get showAllExercises => 'Show all';

  @override
  String get prioritizeProfileExercises => 'Prioritize matching';

  @override
  String get switchExerciseForSession => 'Switch exercise for this session';

  @override
  String get removeFromWeeklyPlan => 'Remove from weekly plan';

  @override
  String get weeklyPlacementRemoved => 'Workout removed from weekly plan';

  @override
  String get dragGroup => 'Drag group';

  @override
  String get requiredExercise => 'Required exercise';

  @override
  String get exerciseRequirement => 'Required/Optional';

  @override
  String get workoutEditFailed => 'Could not save this change. Please try again.';

  @override
  String get alreadyInWorkout => 'Already in this workout';

  @override
  String get noExercisesFound => 'No matching exercises. Change the search or label.';

  @override
  String get swapLockedAfterSets => 'Sets have already been recorded. This exercise can no longer be replaced.';

  @override
  String get finishActiveWorkoutFirst => 'Please resume or finish the active session first.';

  @override
  String get profilesTitle => 'Training locations & equipment';

  @override
  String get profileTemplate => 'Template';

  @override
  String get homeGym => 'Home Gym';

  @override
  String get gym => 'Gym';

  @override
  String get individualProfile => 'Custom';

  @override
  String get selectAllEquipment => 'Select all';

  @override
  String get clearEquipment => 'Clear selection';

  @override
  String get profileRequired => 'Choose a profile for this workout.';

  @override
  String get profileSharedHint => 'Equipment changes apply to all workouts using this profile.';

  @override
  String get profileOnboardingTitle => 'Where do you train?';

  @override
  String get profileOnboardingHint => 'Choose your default for new workouts and check your equipment. You can add more profiles anytime.';

  @override
  String get profileIntroTitle => 'Set up profiles';

  @override
  String get profileIntroBody => 'Use Home Gym and Gym templates and choose your default.';

  @override
  String get later => 'Later';

  @override
  String get configure => 'Set up';

  @override
  String get preferredProfile => 'Default for new workouts';

  @override
  String get useExistingProfile => 'Use an existing profile';

  @override
  String get moreWorkoutProfiles => 'Use another profile';

  @override
  String get copyWorkoutExercises => 'Copy exercises';

  @override
  String get emptyWorkoutProfile => 'Start empty';

  @override
  String get configureWorkoutProfile => 'How would you like to set up this profile?';

  @override
  String get linkWorkoutProfile => 'Link existing exercises';

  @override
  String get discardWorkoutDraft => 'Discard workout draft?';

  @override
  String get discard => 'Discard';

  @override
  String get noExercisesToStart => 'Add exercises before starting.';

  @override
  String get duplicateCheckFailed => 'Duplicate check unavailable.';

  @override
  String get weeklyRecurrence => 'This plan repeats every week.';

  @override
  String get allWorkoutsPlanned => 'All workouts are already planned for this day.';

  @override
  String get noWorkoutsToPlan => 'Create a workout first.';

  @override
  String get profileArchived => 'Archived';

  @override
  String equipmentSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String startWithProfile(String name) {
    return 'Start with $name';
  }

  @override
  String applyExerciseSelection(int count) {
    return 'Apply ($count)';
  }
}
