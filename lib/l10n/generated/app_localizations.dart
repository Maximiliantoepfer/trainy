import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @refinementText.
  ///
  /// In en, this message translates to:
  /// **'{key, select, k_durationHint{Minutes, e.g. 45 or 45:30} k_durationError{Enter a time above 0, e.g. 45 or 45:30.} k_notFaster{No faster than} k_notSlower{No slower than} k_estimated{Rough estimate} k_benchmark{From recent best time} k_manual{Custom} k_effort{By effort} k_resetTarget{Use suggestion} k_recoveryMovement{Recovery} k_run{Easy jog} k_walk{Walk} k_rest{Stand} k_bestTime{Add best time} k_bestDate{Best time date} k_profileWhy{Why these details?} k_profileExplanation{Your easy pace provides a rough pace guide. A recent best time enables additional estimates. Running frequency and longest run limit the starting load; faster does not automatically mean more volume. Heart-rate zones require resting and maximum heart rate.} k_availableDays{Available days} k_sessionsPerWeek{Sessions per week} k_custom{Custom} k_pushCore{Push + core} k_pullLegs{Pull + legs} k_mixedSplit{Push + core / Pull + legs / Full body} k_focus{Focus} k_core{Core} k_endDate{Plan end (optional)} k_indefinite{No end date} k_extraWorkout{Start another workout} k_splitSession{Split session} k_swap{Swap sessions} k_undoSplit{Undo split} k_templates{Templates} k_extras{More exercises} k_missingEquipment{Equipment missing} k_streetMap{Load street map} k_mapPrivacy{The map is loaded from OpenStreetMap. The provider receives your IP address and the displayed map area. Your route stays local.} k_noRoute{No GPS route data is available for this session.} k_runningBlocks{Running blocks} k_updateTargets{Apply new pace suggestions?} k_updateTargetsInfo{Only future automatic targets are updated. Custom targets and started sessions stay unchanged.} k_shortPlan{This plan ends before the suggested running build-up. Later sessions are omitted; progression is not accelerated.} k_splitHint{Selected exercises stay on day 1. All others move to day 2.} k_muscleFocus{Individual muscle groups} k_chest{Chest} k_back{Back} k_shoulders{Shoulders} k_arms{Arms} k_quads{Thighs} k_glutes{Glutes} k_calves{Calves} k_manualEntry{Manual log} other{{key}}}'**
  String refinementText(String key);

  /// No description provided for @planText.
  ///
  /// In en, this message translates to:
  /// **'{key, select, k_training{Training} k_workouts{Workouts} k_exercises{Exercises} k_start{Home} k_settings{Settings} k_createPlan{Create training plan} k_resumePlan{Continue plan} k_withoutPlan{Train without a plan} k_planIntro{Your week. Your training.} k_planHint{Strength and running, planned together.} k_myPlan{My training plan} k_savedPlans{Saved plans} k_choosePlan{Which plan would you like to use?} k_choosePlanHint{Your existing plans are kept.} k_today{Today} k_week{This week} k_restDay{A day to recover.} k_unitsDone{sessions completed} k_newWorkout{Create workout} k_ownWorkouts{Your workouts} k_templates{Templates} k_all{All} k_strength{Strength} k_running{Running} k_cardio{Other cardio} k_mobility{Mobility} k_emptyWorkouts{No workouts yet} k_typeQuestion{What would you like to train?} k_emptyWorkout{Start from scratch} k_assignWorkout{Assign workout} k_workoutUnavailable{This workout is no longer available.} k_profile{My profile} k_runningProfile{Your running profile} k_strengthProfile{Your strength profile} k_equipment{Training locations & equipment} k_interests{What do you train?} k_units{Units} k_metric{Kilometres} k_imperial{Miles} k_connections{Connections} k_sensorBackup{Back up GPS and sensor data} k_sensorHint{Optional in cloud backups. Your local data is kept.} k_look{Your look} k_lookHint{Make Trainy feel like yours.} k_backup{Your backup} k_backupHint{Optionally back up with Google. Trainy works without an account.} k_health{Connect activities} k_healthHint{Import completed workouts from Health, not a live watch connection.} k_connect{Connect} k_connected{Connected} k_later{Later} k_next{Continue} k_back{Back} k_done{Done} k_save{Save} k_retry{Retry} k_error{That didn\'t work. Your entries are kept.} k_savingError{Not saved. Please try again.} k_days{When would you like to train?} k_availableDays{Available days} k_strengthDays{Your strength days} k_runningDays{Your running days} k_mobilityDays{Your mobility days} k_dayRequired{Choose at least one training day.} k_chooseSport{Choose at least one activity.} k_name{Plan name} k_nameRequired{Give your plan a name.} k_goal{Your goal} k_strengthGoal{Strength goal} k_runningGoal{Running goal} k_generalFitness{Stay fit} k_buildMuscle{Build muscle} k_getStronger{Get stronger} k_runFaster{Run faster} k_runFurther{Run further} k_firstDistance{Complete the distance} k_targetDistance{Target distance} k_targetTime{Goal time (optional)} k_targetDate{Target date (optional)} k_startDate{Start date} k_optional{Optional} k_none{Not specified} k_preview{Your week} k_activate{Use this plan} k_edit{Edit} k_replace{Change} k_split{Your split} k_fullBody{Full body} k_upperLower{Upper/lower body} k_pushPullLegs{Push/pull/legs} k_upper{Upper body} k_lower{Lower body} k_push{Push} k_pull{Pull} k_legs{Legs} k_splitHint{A suggestion — tap to adjust.} k_missingWorkouts{Assign the remaining workouts} k_weeklyRepeat{Repeats weekly} k_alternating{Alternates every two weeks} k_weekNumber{Week} k_level{How would you describe your experience?} k_starting{Getting started} k_beginner{Beginner} k_intermediate{Intermediate} k_experienced{Experienced} k_startingHint{I\'m just starting to run.} k_beginnerHint{I already run and am building a base.} k_intermediateHint{I run regularly, including longer distances.} k_experiencedHint{I regularly train tempo and intervals.} k_canFive{Can you run 5 km without walking?} k_yes{Yes} k_notYet{Not yet} k_unknown{Not sure} k_performance{Your current pace} k_distance{Distance} k_time{Time} k_pace{Pace} k_timeQuestion{How long does this distance take you?} k_durationHint{Minutes:seconds, e.g. 32:30} k_durationError{Enter a time above 0 as mm:ss.} k_positiveError{Enter a number greater than 0.} k_numberError{Enter a valid number.} k_performanceKind{What does this time describe?} k_easyRun{Easy training run} k_bestRun{Best-effort run} k_testDate{When was this run?} k_dateRequired{Choose the date of your run.} k_testInfo{Only recent best efforts support race estimates. Training times are not maximal tests.} k_load{Your recent training} k_longest{Longest run in the last 4 weeks} k_continuous{How long can you run easily without walking?} k_minutes{Minutes} k_recentFrequency{How often have you run per week recently?} k_recentHint{Over the last 4 weeks, not your new training goal.} k_pulse{Heart-rate zones (optional)} k_restPulse{Resting heart rate} k_maxPulse{Maximum heart rate} k_pulseError{Enter a whole number between 25 and 250.} k_pulseOrder{Maximum heart rate must exceed resting heart rate.} k_pulseMissing{Both values are needed to calculate zones.} k_zoneInfo{Karvonen estimate, not a performance assessment. You can edit target zones.} k_move{Move} k_onlyThis{Only this session} k_future{Future sessions too} k_conflict{Check training load} k_conflictHint{Sessions are close together. Move a demanding run or leg day to another available day.} k_doubleDay{More than one session on a day} k_changeDays{Adjust days} k_planEstimate{A suggestion, not a performance promise.} k_editRunning{Edit running block} k_editStrength{Edit strength block} k_regenerate{Update running proposal} k_regenerateHint{Only unchanged future runs are replaced. History and manual edits are kept.} k_delete{Delete} k_cancel{Cancel} k_deleteWorkout{Delete workout?} k_add{Add} k_calendar{Calendar} k_continueWorkout{Resume workout} k_viewAll{Show all} k_runNeedsDays{Choose running days to generate a running plan.} k_restore{Restore backup} k_keepLocal{Continue locally} k_backupFound{Backup found} k_restoreHint{Restoring replaces local training data. Continuing without restoring leaves your cloud backup unchanged.} k_summary{Overview} k_planSaved{Plan saved} k_finishSetup{Continue setup} other{{key}}}'**
  String planText(String key);

  /// No description provided for @cardioText.
  ///
  /// In en, this message translates to:
  /// **'{key, select, k_cardio{Endurance} k_library{Workouts} k_plan{Training plan} k_history{History} k_profile{Running profile} k_settings{Endurance settings} k_newWorkout{Create workout} k_edit{Edit} k_save{Save} k_cancel{Cancel} k_delete{Delete} k_add{Add} k_start{Start} k_continueLabel{Continue} k_skip{Skip} k_warmup{Warm-up} k_cooldown{Cool-down} k_core{Main workout} k_name{Name} k_sport{Sport} k_indoor{Indoor} k_outdoor{Outdoor} k_running{Running} k_walking{Walking} k_cycling{Cycling} k_stepper{Stair stepper} k_elliptical{Elliptical} k_rowing{Rowing} k_other{Other} k_time{Duration} k_distance{Distance} k_seconds{Seconds} k_minutes{Minutes} k_meters{Meters} k_repeat{Repeats} k_recovery{Recovery} k_standing{Standing recovery} k_easy{Easy} k_steady{Steady} k_threshold{Threshold} k_interval{Interval} k_free{Free effort} k_intensity{Intensity} k_run{Run} k_walk{Walk} k_rest{Rest} k_movement{Movement} k_pace{Pace} k_speed{Speed} k_heartRate{Heart rate} k_target{Target} k_minSpeed{Min. speed (m/s)} k_maxSpeed{Max. speed (m/s)} k_minPulse{Lower target heart rate} k_maxPulse{Upper target heart rate} k_primary{Primary guidance} k_effort{Perceived effort} k_reference{Reference time} k_referenceDistance{Reference distance} k_referenceDate{Reference date} k_maximal{Maximal test / race} k_weekly{Weekly distance} k_longest{Longest run (last 4 weeks)} k_continuous{Continuous running (minutes)} k_experience{Regular running experience (months)} k_restPulse{Resting heart rate (optional)} k_maxHeartRate{Maximum heart rate (optional)} k_days{Training days} k_metric{Kilometers / meters} k_imperial{Miles} k_units{Units} k_zones{Estimated heart rate zones} k_zoneInfo{Karvonen: resting heart rate + fraction × (maximum − resting heart rate). Trainy uses five bands from 50–100% of heart rate reserve. Individual thresholds may differ; performance testing provides more accurate zones.} k_benchmarkInfo{Pace suggestions require a maximal test within the last 90 days. Ordinary training pace does not predict race performance.} k_invalid{Please check your entries.} k_error{That did not work. Your locally saved data is preserved.} k_retry{Retry} k_noData{No activities yet} k_finish{Hold for 2 seconds to finish} k_finishAccessible{Finish workout} k_confirmFinish{Finish and save this workout?} k_pause{Pause} k_resume{Resume} k_paused{Paused} k_active{Workout in progress} k_completed{Completed} k_elapsed{Elapsed time} k_activeTime{Active time} k_remaining{Remaining} k_next{Up next} k_average{Average} k_half{Halfway} k_nearEnd{Almost there} k_faster{Run a little faster} k_slower{Run a little slower} k_gpsLost{GPS unavailable – distance measurement interrupted} k_gpsReady{GPS active} k_gpsWaiting{Searching for GPS} k_locationDenied{Precise location permission is required for outdoor distance tracking.} k_openSettings{Open settings} k_audioUnavailable{No offline voice available. Set up audio in system settings.} k_indoorInfo{Without a sensor, indoor distance, live pace and auto-pause are unavailable. Distance targets can be converted to time using a target speed.} k_convert{Convert distance targets to time} k_backgroundLimited{Indoor on this iOS version: keep the app open.} k_pulseLater{Heart rate is added after training through Health. Live guidance uses pace or perceived effort.} k_autoPause{Auto-pause after 10 seconds standing still} k_mediaPending{Video not yet available – follow the movement instructions.} k_routineInfo{Move slowly and with control within a comfortable range. Split unilateral exercises between both sides.} k_easy5k{Easy 5K} k_longRun{Long run} k_runWalk{Run–walk} k_progression{Progression run} k_tempo{Tempo run} k_pyramid{Pyramid intervals} k_descending{Descending intervals} k_fourByFour{4 × 4 minutes} k_fartlek{Fartlek} k_strides{Strides} k_drills{Running drills} k_easySession{Easy run} k_intervalSession{Timed intervals} k_goalDistance{Target distance} k_goalTime{Desired target time (optional, minutes)} k_goalDate{Preferred date (optional)} k_generate{Suggest plan} k_accept{Accept} k_preview{Preview} k_planInfo{Conservative planning based on your previous training. Target times and time frames are not performance promises. Changes require confirmation.} k_basePhase{Build a base first} k_infeasible{The date or training base does not yet fit the goal. The proposal includes a longer base phase.} k_move{Move} k_onlyThis{Only this activity} k_futureToo{Also future occurrences on this weekday} k_locked{Manually fixed} k_skipped{Skipped} k_adapt{Suggest adjustment} k_adaptInfo{Following missed activities, upcoming training load is reduced; fixed and completed activities are preserved.} k_rpe{How hard was it? (1–10)} k_discomfort{Discomfort} k_health{Connect Health} k_import{Review activities} k_export{Save to Health} k_dismiss{Dismiss} k_link{Link to existing activity} k_backupSensors{Include routes and sensor history in cloud backups} k_backupInfo{By default, only profile, plans and summaries are backed up.} k_healthInfo{Trainy reads completed workouts and heart rate locally from Apple Health or Health Connect. Imports can be reviewed. This does not create a live connection to your watch.} k_healthUnavailable{Health is unavailable on this device.} k_healthExported{Saved to Health} k_healthPermission{Health access was not granted.} k_strengthActive{Please finish the active workout first.} k_saved{Saved locally} k_newPlan{New running plan} k_date{Date} k_week{Week} k_summary{Summary} k_estimated{Estimated} k_recovered{Recovered; check for possible measurement gaps} k_interests{What would you like to train?} k_strength{Strength} k_mobility{Mobility} k_focus{Training focus} k_power{Power} k_muscularEndurance{Muscular endurance} k_dynamic{Dynamic} k_staticStretch{Static / stretching} k_copy{Duplicate} k_deleteConfirm{Delete this entry?} k_localOnly{Everything is stored and calculated locally.} k_secondsPerKm{Seconds per kilometer} k_restDays{Check recovery: training on consecutive days.} k_sensorCoverage{Measurement coverage} k_privacy{Health data and privacy} k_privacyBody{Trainy processes training data locally on this device. Health access is optional and can be revoked in system settings. Cloud backup is separately optional; detailed routes require additional consent. Health data is not sold for advertising.} k_ankleRocks{Ankle rocks} k_calfRaises{Calf raises} k_legSwings{Forward/backward leg swings} k_lateralSwings{Sideways leg swings} k_reverseLunge{Reverse lunge with reach} k_march{March with arm swings} k_hinge{Hip hinge} k_squat{Easy squats} k_rotation{Thoracic rotation} k_lateralLunge{Lateral lunge} k_gluteBridge{Glute bridge} k_birdDog{Bird dog} k_shoulderCircles{Shoulder circles} k_armCircles{Arm circles} k_wallSlides{Wall slides} k_scapularPushup{Scapular push-up} k_calfStretch{Calf stretch} k_hipFlexor{Hip flexor stretch} k_hamstring{Hamstring stretch} k_quadStretch{Quadriceps stretch} k_gluteStretch{Glute stretch} k_chestStretch{Chest stretch} k_latStretch{Lat stretch} k_shoulderStretch{Posterior shoulder stretch} k_aMarch{A-march} k_ankling{Ankling} k_aSkip{A-skip} k_buttKicks{Heel flicks} k_sideSteps{Side steps} k_lower{Lower body} k_upper{Upper body} k_startError{Unable to start. Check permissions, targets, and whether another workout is active.} k_storageError{Recording is not fully saved. Please pause and check free storage.} k_holdFinish{Hold for 2 seconds to finish} k_templates{Templates} k_profileIntro{Add a benchmark, heart rates and available days for personalised suggestions.} k_cardioIntro{Running, cycling and more endurance sports} k_equivalent{Current estimated equivalent — not a future prediction} k_noAdjustment{No adjustment suggested right now. You can always edit individual workouts.} k_refresh{Find workouts from the last 29 days} k_disconnect{Disable automatic refresh} k_importConfirm{Import or link this workout?} k_healthError{Health is unavailable or access is restricted. Check system permissions. An export with an uncertain result is not retried automatically; check Health to avoid duplicates.} k_ankleRocksInstruction{In a short split stance, move the front knee gently over the toes while keeping the heel down. Switch sides halfway.} k_calfRaisesInstruction{Stand tall. Slowly lift both heels and lower with control. Use a wall for balance if needed.} k_legSwingsInstruction{Use a wall for balance. Swing one leg gently forward and back with a stable pelvis. Switch halfway.} k_lateralSwingsInstruction{Use a wall for balance. Gently swing one leg from side to side. Switch halfway.} k_reverseLungeInstruction{Alternate small backward steps and gently bend both knees. Push up through the whole front foot.} k_marchInstruction{March tall in place. Lift knees comfortably and swing opposite arms.} k_hingeInstruction{Keep knees soft, send hips back and lean forward with a long spine. Return with control.} k_squatInstruction{Stand with feet comfortably apart. Lower hips slowly back and down, then stand. Use a comfortable depth.} k_rotationInstruction{Stand tall and gently rotate the upper body left and right, keeping hips mostly still.} k_lateralLungeInstruction{Step sideways and gently bend the loaded knee. Return to centre and switch.} k_gluteBridgeInstruction{Lie on your back with knees bent. Lift hips without arching the lower back, then lower.} k_birdDogInstruction{On hands and knees, slowly extend the opposite arm and leg. Keep the back steady, then switch.} k_shoulderCirclesInstruction{Relax your arms and make small, slow shoulder circles backwards and forwards.} k_armCirclesInstruction{Raise arms comfortably to the sides and make small circles. Increase range only if pain-free.} k_wallSlidesInstruction{Stand with your back lightly against a wall. Slide arms up and down without arching your back.} k_scapularPushupInstruction{On hands and knees with straight arms, gently move the shoulder blades together and apart.} k_calfStretchInstruction{Place hands on a wall in a split stance. Keep the back leg straight and heel down. Hold gently without bouncing. Switch halfway.} k_hipFlexorInstruction{In a padded half-kneeling stance, gently tuck the pelvis and shift forward without arching. Switch halfway.} k_hamstringInstruction{Place one heel in front with a soft knee. Gently hinge at the hips with a long back. Switch halfway.} k_quadStretchInstruction{Hold a support and bring one foot behind you. Keep knees near each other and pelvis steady; do not pull hard. Switch halfway.} k_gluteStretchInstruction{Lie on your back with one ankle over the opposite knee. Gently draw the lower leg toward you. Switch halfway.} k_chestStretchInstruction{Place a forearm gently against a doorway and turn slightly away. Keep the shoulder relaxed. Switch halfway.} k_latStretchInstruction{Place hands on a stable surface. Send hips back and lengthen the back without forcing the shoulders.} k_shoulderStretchInstruction{Bring one arm across the body and gently support it with the other. Keep the shoulder down. Switch halfway.} k_aMarchInstruction{March slowly forward, lift one knee and place the foot under the body. Use opposite arm action.} k_anklingInstruction{Move forward in very small steps with relaxed, springy ankle action and an upright torso.} k_aSkipInstruction{If familiar: use small relaxed skips with alternating knee lifts. March instead if preferred. Land softly.} k_buttKicksInstruction{Jog gently in place and alternate lifting heels behind you without forcing the movement.} k_sideStepsInstruction{Take small controlled side steps without crossing your feet. Change direction halfway.} k_targetTimeInfo{The target time is an aspiration, not a promised improvement. Training pace stays based on your current test and is updated after a new test.} k_route{Locally recorded route without map tiles} k_audioSetup{Install an offline voice for the selected app language in system settings. You can continue without speech; cues will only be visible on the screen.} k_custom{Custom exercise} k_instructions{Instructions (optional)} other{{key}}}'**
  String cardioText(String key);

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Trainy'**
  String get appName;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get german;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @progressDescription.
  ///
  /// In en, this message translates to:
  /// **'Track your training progress. History shows your completed workouts; Insights contains the calendar and exercise charts.'**
  String get progressDescription;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Customize Trainy, set weekly goals, and back up your data to the cloud.'**
  String get settingsDescription;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @designMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get designMode;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @trainingDays.
  ///
  /// In en, this message translates to:
  /// **'Training days'**
  String get trainingDays;

  /// No description provided for @trainingDaysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Training days per week'**
  String get trainingDaysPerWeek;

  /// No description provided for @weeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly goal'**
  String get weeklyGoal;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @weekOverview.
  ///
  /// In en, this message translates to:
  /// **'Weekly overview'**
  String get weekOverview;

  /// No description provided for @todayWorkout.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout'**
  String get todayWorkout;

  /// No description provided for @trainingForDay.
  ///
  /// In en, this message translates to:
  /// **'{day} workout'**
  String trainingForDay(String day);

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDay;

  /// No description provided for @trainingPlan.
  ///
  /// In en, this message translates to:
  /// **'Training plan'**
  String get trainingPlan;

  /// No description provided for @workoutsInARow.
  ///
  /// In en, this message translates to:
  /// **'{count} workouts in a row'**
  String workoutsInARow(int count);

  /// No description provided for @workoutsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} workout(s)'**
  String workoutsCount(int count);

  /// No description provided for @exercisesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} exercise(s)'**
  String exercisesCount(int count);

  /// No description provided for @newWorkout.
  ///
  /// In en, this message translates to:
  /// **'New workout'**
  String get newWorkout;

  /// No description provided for @workoutName.
  ///
  /// In en, this message translates to:
  /// **'Workout name'**
  String get workoutName;

  /// No description provided for @enterWorkoutName.
  ///
  /// In en, this message translates to:
  /// **'Enter workout name'**
  String get enterWorkoutName;

  /// No description provided for @workoutDetails.
  ///
  /// In en, this message translates to:
  /// **'Workout details'**
  String get workoutDetails;

  /// No description provided for @workoutDuration.
  ///
  /// In en, this message translates to:
  /// **'Workout duration'**
  String get workoutDuration;

  /// No description provided for @editWorkoutDuration.
  ///
  /// In en, this message translates to:
  /// **'Edit workout duration'**
  String get editWorkoutDuration;

  /// No description provided for @editDuration.
  ///
  /// In en, this message translates to:
  /// **'Edit duration'**
  String get editDuration;

  /// No description provided for @editSets.
  ///
  /// In en, this message translates to:
  /// **'Edit sets'**
  String get editSets;

  /// No description provided for @editRepetitions.
  ///
  /// In en, this message translates to:
  /// **'Edit repetitions'**
  String get editRepetitions;

  /// No description provided for @editWeight.
  ///
  /// In en, this message translates to:
  /// **'Edit weight'**
  String get editWeight;

  /// No description provided for @editDistance.
  ///
  /// In en, this message translates to:
  /// **'Edit distance'**
  String get editDistance;

  /// No description provided for @editValue.
  ///
  /// In en, this message translates to:
  /// **'Edit value'**
  String get editValue;

  /// No description provided for @addValue.
  ///
  /// In en, this message translates to:
  /// **'Add {label}'**
  String addValue(String label);

  /// No description provided for @exampleInteger.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10'**
  String get exampleInteger;

  /// No description provided for @exampleDecimal.
  ///
  /// In en, this message translates to:
  /// **'e.g. 42.5'**
  String get exampleDecimal;

  /// No description provided for @deleteWorkout.
  ///
  /// In en, this message translates to:
  /// **'Delete workout?'**
  String get deleteWorkout;

  /// No description provided for @deleteWorkoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" permanently?'**
  String deleteWorkoutConfirmation(String name);

  /// No description provided for @renameWorkout.
  ///
  /// In en, this message translates to:
  /// **'Rename workout'**
  String get renameWorkout;

  /// No description provided for @noWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No workouts yet'**
  String get noWorkouts;

  /// No description provided for @createFirstWorkout.
  ///
  /// In en, this message translates to:
  /// **'Create workouts, add exercises, and track your progress.'**
  String get createFirstWorkout;

  /// No description provided for @createWorkout.
  ///
  /// In en, this message translates to:
  /// **'Create workout'**
  String get createWorkout;

  /// No description provided for @addExercises.
  ///
  /// In en, this message translates to:
  /// **'Add exercises'**
  String get addExercises;

  /// No description provided for @noExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get noExercises;

  /// No description provided for @createFirstExercise.
  ///
  /// In en, this message translates to:
  /// **'Create your first exercise to get started.'**
  String get createFirstExercise;

  /// No description provided for @newExercise.
  ///
  /// In en, this message translates to:
  /// **'New exercise'**
  String get newExercise;

  /// No description provided for @editExercise.
  ///
  /// In en, this message translates to:
  /// **'Edit exercise'**
  String get editExercise;

  /// No description provided for @exerciseName.
  ///
  /// In en, this message translates to:
  /// **'Exercise name'**
  String get exerciseName;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @optionalDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get optionalDescription;

  /// No description provided for @localSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save locally. Your input is kept for another attempt.'**
  String get localSaveFailed;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @exerciseGoal.
  ///
  /// In en, this message translates to:
  /// **'Training goal'**
  String get exerciseGoal;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @catalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalog;

  /// No description provided for @own.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get own;

  /// No description provided for @reviewDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Review duplicates'**
  String get reviewDuplicates;

  /// No description provided for @noDuplicateSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No duplicate suggestions'**
  String get noDuplicateSuggestions;

  /// No description provided for @adoptStandardExercise.
  ///
  /// In en, this message translates to:
  /// **'Use standard exercise'**
  String get adoptStandardExercise;

  /// No description provided for @keepOwnExercise.
  ///
  /// In en, this message translates to:
  /// **'Keep my exercise'**
  String get keepOwnExercise;

  /// No description provided for @catalogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The reviewed offline catalog is not bundled in this build yet.'**
  String get catalogUnavailable;

  /// No description provided for @catalogExerciseAdded.
  ///
  /// In en, this message translates to:
  /// **'Exercise added to your library'**
  String get catalogExerciseAdded;

  /// No description provided for @exerciseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exerciseLibrary;

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activities;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @matchesProfile.
  ///
  /// In en, this message translates to:
  /// **'Matches {name}'**
  String matchesProfile(String name);

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @exerciseArchived.
  ///
  /// In en, this message translates to:
  /// **'Exercise archived; workout history stays unchanged'**
  String get exerciseArchived;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @trainingProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get trainingProfile;

  /// No description provided for @workoutVariant.
  ///
  /// In en, this message translates to:
  /// **'Workout variant'**
  String get workoutVariant;

  /// No description provided for @standardVariant.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardVariant;

  /// No description provided for @createVariant.
  ///
  /// In en, this message translates to:
  /// **'Create variant'**
  String get createVariant;

  /// No description provided for @variantName.
  ///
  /// In en, this message translates to:
  /// **'Variant name'**
  String get variantName;

  /// No description provided for @editWorkoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get editWorkoutPlan;

  /// No description provided for @workoutGroup.
  ///
  /// In en, this message translates to:
  /// **'Workout group'**
  String get workoutGroup;

  /// No description provided for @groupVariant.
  ///
  /// In en, this message translates to:
  /// **'Group variation'**
  String get groupVariant;

  /// No description provided for @addGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get addGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @addGroupVariant.
  ///
  /// In en, this message translates to:
  /// **'Add group variation'**
  String get addGroupVariant;

  /// No description provided for @alternatives.
  ///
  /// In en, this message translates to:
  /// **'Alternatives'**
  String get alternatives;

  /// No description provided for @addAlternative.
  ///
  /// In en, this message translates to:
  /// **'Add alternative exercise'**
  String get addAlternative;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @planExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises in this variation'**
  String get planExercises;

  /// No description provided for @noGroupExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises in this group variation yet.'**
  String get noGroupExercises;

  /// No description provided for @noProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profile selected'**
  String get noProfiles;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @equipmentBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get equipmentBodyweight;

  /// No description provided for @equipmentDumbbell.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells'**
  String get equipmentDumbbell;

  /// No description provided for @equipmentBarbell.
  ///
  /// In en, this message translates to:
  /// **'Barbell'**
  String get equipmentBarbell;

  /// No description provided for @equipmentMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get equipmentMachine;

  /// No description provided for @equipmentCable.
  ///
  /// In en, this message translates to:
  /// **'Cable'**
  String get equipmentCable;

  /// No description provided for @equipmentKettlebell.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell'**
  String get equipmentKettlebell;

  /// No description provided for @equipmentBands.
  ///
  /// In en, this message translates to:
  /// **'Resistance bands'**
  String get equipmentBands;

  /// No description provided for @equipmentBench.
  ///
  /// In en, this message translates to:
  /// **'Bench'**
  String get equipmentBench;

  /// No description provided for @equipmentRack.
  ///
  /// In en, this message translates to:
  /// **'Rack'**
  String get equipmentRack;

  /// No description provided for @equipmentPullUpBar.
  ///
  /// In en, this message translates to:
  /// **'Pull-up bar'**
  String get equipmentPullUpBar;

  /// No description provided for @equipmentMedicineBall.
  ///
  /// In en, this message translates to:
  /// **'Medicine ball'**
  String get equipmentMedicineBall;

  /// No description provided for @equipmentExerciseBall.
  ///
  /// In en, this message translates to:
  /// **'Exercise ball'**
  String get equipmentExerciseBall;

  /// No description provided for @equipmentFoamRoller.
  ///
  /// In en, this message translates to:
  /// **'Foam roller'**
  String get equipmentFoamRoller;

  /// No description provided for @equipmentEzBar.
  ///
  /// In en, this message translates to:
  /// **'EZ bar'**
  String get equipmentEzBar;

  /// No description provided for @equipmentMat.
  ///
  /// In en, this message translates to:
  /// **'Mat'**
  String get equipmentMat;

  /// No description provided for @equipmentCardioMachine.
  ///
  /// In en, this message translates to:
  /// **'Cardio machine'**
  String get equipmentCardioMachine;

  /// No description provided for @equipmentOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get equipmentOther;

  /// No description provided for @noEquipmentSelected.
  ///
  /// In en, this message translates to:
  /// **'No equipment selected'**
  String get noEquipmentSelected;

  /// No description provided for @trainingProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your training locations and their equipment.'**
  String get trainingProfileDescription;

  /// No description provided for @addTrainingProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get addTrainingProfile;

  /// No description provided for @editTrainingProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editTrainingProfile;

  /// No description provided for @archiveProfile.
  ///
  /// In en, this message translates to:
  /// **'Archive profile?'**
  String get archiveProfile;

  /// No description provided for @archiveProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will no longer be offered as a profile. Existing sessions remain unchanged.'**
  String archiveProfileDescription(String name);

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Profiles could not be loaded.'**
  String get profileLoadFailed;

  /// No description provided for @profileOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile operation failed ({operation}). Please retry.'**
  String profileOperationFailed(String operation);

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyweight;

  /// No description provided for @setsAndDuration.
  ///
  /// In en, this message translates to:
  /// **'Sets + duration'**
  String get setsAndDuration;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get nameRequired;

  /// No description provided for @searchExercises.
  ///
  /// In en, this message translates to:
  /// **'Search exercises'**
  String get searchExercises;

  /// No description provided for @tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get tracking;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @setsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String setsCount(int count);

  /// No description provided for @repetitions.
  ///
  /// In en, this message translates to:
  /// **'Repetitions'**
  String get repetitions;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @estimatedDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Estimated duration (minutes)'**
  String get estimatedDurationMinutes;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get seconds;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @continueWorkout.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueWorkout;

  /// No description provided for @endWorkout.
  ///
  /// In en, this message translates to:
  /// **'End workout'**
  String get endWorkout;

  /// No description provided for @stopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop and save'**
  String get stopAndSave;

  /// No description provided for @workoutCompleted.
  ///
  /// In en, this message translates to:
  /// **'Workout completed!'**
  String get workoutCompleted;

  /// No description provided for @addSet.
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get addSet;

  /// No description provided for @saveSet.
  ///
  /// In en, this message translates to:
  /// **'Save set'**
  String get saveSet;

  /// No description provided for @noSetsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No sets recorded.'**
  String get noSetsRecorded;

  /// No description provided for @endAnyway.
  ///
  /// In en, this message translates to:
  /// **'End anyway'**
  String get endAnyway;

  /// No description provided for @backdateWorkout.
  ///
  /// In en, this message translates to:
  /// **'Add past workout'**
  String get backdateWorkout;

  /// No description provided for @workoutBackdated.
  ///
  /// In en, this message translates to:
  /// **'Workout added for {date}'**
  String workoutBackdated(String date);

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @workoutsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Workouts per day'**
  String get workoutsPerDay;

  /// No description provided for @noEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get noEntries;

  /// No description provided for @startWorkoutToSeeEntries.
  ///
  /// In en, this message translates to:
  /// **'Start a workout and record sets to see progress here.'**
  String get startWorkoutToSeeEntries;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @cloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get cloudBackup;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @automaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get automaticBackup;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @loadFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Load from cloud'**
  String get loadFromCloud;

  /// No description provided for @backupLoaded.
  ///
  /// In en, this message translates to:
  /// **'Backup loaded'**
  String get backupLoaded;

  /// No description provided for @backupUploaded.
  ///
  /// In en, this message translates to:
  /// **'Backup uploaded'**
  String get backupUploaded;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// No description provided for @backUp.
  ///
  /// In en, this message translates to:
  /// **'Back up'**
  String get backUp;

  /// No description provided for @load.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get load;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get restoreBackup;

  /// No description provided for @restoreBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Local data will be replaced by the cloud backup.'**
  String get restoreBackupDescription;

  /// No description provided for @signedInSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get signedInSuccessfully;

  /// No description provided for @merged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get merged;

  /// No description provided for @lowContrast.
  ///
  /// In en, this message translates to:
  /// **'Your accent color has low contrast in this mode.'**
  String get lowContrast;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get understood;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @minutesPerDay.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day'**
  String get minutesPerDay;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @workoutsRecordedOnDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No workouts} =1{1 workout recorded} other{{count} workouts recorded}}'**
  String workoutsRecordedOnDay(int count);

  /// No description provided for @activeWorkoutBanner.
  ///
  /// In en, this message translates to:
  /// **'Active workout: {name}. Tap to continue.'**
  String activeWorkoutBanner(String name);

  /// No description provided for @deleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get deleteEntry;

  /// No description provided for @deleteEntryDescription.
  ///
  /// In en, this message translates to:
  /// **'This workout entry will be permanently deleted.'**
  String get deleteEntryDescription;

  /// No description provided for @deletedExercise.
  ///
  /// In en, this message translates to:
  /// **'Deleted exercise ({id})'**
  String deletedExercise(int id);

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get notAvailable;

  /// No description provided for @formerName.
  ///
  /// In en, this message translates to:
  /// **'former: {name}'**
  String formerName(String name);

  /// No description provided for @greatWork.
  ///
  /// In en, this message translates to:
  /// **'Great work!'**
  String get greatWork;

  /// No description provided for @recommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get recommendation;

  /// No description provided for @exerciseProgress.
  ///
  /// In en, this message translates to:
  /// **'Exercise progress'**
  String get exerciseProgress;

  /// No description provided for @exerciseDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your exercises. Create new exercises, edit existing ones, and choose which metrics to track.'**
  String get exerciseDescription;

  /// No description provided for @editExerciseConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit exercise?'**
  String get editExerciseConfirmationTitle;

  /// No description provided for @editExerciseConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Changes affect every workout that uses this exercise.'**
  String get editExerciseConfirmation;

  /// No description provided for @mergeExercises.
  ///
  /// In en, this message translates to:
  /// **'Merge exercises{count, plural, =0{} other{ ({count})}}'**
  String mergeExercises(int count);

  /// No description provided for @removeEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove entry?'**
  String get removeEntry;

  /// No description provided for @removeMergeEntryDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from merge history?\n\nTransferred workout entries remain assigned to \"{target}\".'**
  String removeMergeEntryDescription(String name, String target);

  /// No description provided for @noOtherExercise.
  ///
  /// In en, this message translates to:
  /// **'No other exercise is available.'**
  String get noOtherExercise;

  /// No description provided for @mergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge into \"{name}\":'**
  String mergeInto(String name);

  /// No description provided for @confirmMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge?'**
  String get confirmMerge;

  /// No description provided for @mergeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use \"{target}\" for future workouts instead of \"{source}\"?\n\n{count, plural, =0{} =1{1 recorded entry remains unchanged.\n} other{{count} recorded entries remain unchanged.\n}}You can undo this later.'**
  String mergeDescription(String source, String target, int count);

  /// No description provided for @mergedResult.
  ///
  /// In en, this message translates to:
  /// **'\"{source}\" → \"{target}\" merged'**
  String mergedResult(String source, String target);

  /// No description provided for @mergeHistory.
  ///
  /// In en, this message translates to:
  /// **'Merge history'**
  String get mergeHistory;

  /// No description provided for @noMergedExercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises merged yet.'**
  String get noMergedExercises;

  /// No description provided for @mergedOn.
  ///
  /// In en, this message translates to:
  /// **'Merged on {date}'**
  String mergedOn(String date);

  /// No description provided for @newMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge another exercise'**
  String get newMerge;

  /// No description provided for @deleteExercise.
  ///
  /// In en, this message translates to:
  /// **'Delete exercise?'**
  String get deleteExercise;

  /// No description provided for @deleteExerciseConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" permanently? Existing workout data is retained.'**
  String deleteExerciseConfirmation(String name);

  /// No description provided for @deleteExerciseWithEntries.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"? {count, plural, =1{1 workout entry stays unchanged.} other{{count} workout entries stay unchanged.}}'**
  String deleteExerciseWithEntries(String name, int count);

  /// No description provided for @permanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get permanentlyDelete;

  /// No description provided for @exerciseDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" deleted'**
  String exerciseDeleted(String name);

  /// No description provided for @noExercisesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first exercise.'**
  String get noExercisesDescription;

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'Your dashboard at a glance. See your weekly overview, planned workouts, and start training directly.'**
  String get homeDescription;

  /// No description provided for @noExercisesInWorkout.
  ///
  /// In en, this message translates to:
  /// **'This workout has no exercises.'**
  String get noExercisesInWorkout;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get getStarted;

  /// No description provided for @firstWorkout.
  ///
  /// In en, this message translates to:
  /// **'Create your first workout'**
  String get firstWorkout;

  /// No description provided for @noWorkoutsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No workouts available'**
  String get noWorkoutsAvailable;

  /// No description provided for @selectWorkout.
  ///
  /// In en, this message translates to:
  /// **'Select workout'**
  String get selectWorkout;

  /// No description provided for @trained.
  ///
  /// In en, this message translates to:
  /// **'trained'**
  String get trained;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get planned;

  /// No description provided for @noTrackingFieldsActive.
  ///
  /// In en, this message translates to:
  /// **'No tracking fields are enabled.'**
  String get noTrackingFieldsActive;

  /// No description provided for @saveRecordedSets.
  ///
  /// In en, this message translates to:
  /// **'Recorded sets will be saved.'**
  String get saveRecordedSets;

  /// No description provided for @endWithoutSets.
  ///
  /// In en, this message translates to:
  /// **'No sets recorded. End anyway?'**
  String get endWithoutSets;

  /// No description provided for @weightKilograms.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKilograms;

  /// No description provided for @distanceKilometers.
  ///
  /// In en, this message translates to:
  /// **'Distance (km)'**
  String get distanceKilometers;

  /// No description provided for @allExercisesAlreadyInWorkout.
  ///
  /// In en, this message translates to:
  /// **'All exercises are already in this workout.'**
  String get allExercisesAlreadyInWorkout;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercise;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @recordedSets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set recorded} other{{count} sets recorded}}'**
  String recordedSets(int count);

  /// No description provided for @setNumber.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String setNumber(int number);

  /// No description provided for @workoutCreatedAndAdded.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" was created and added'**
  String workoutCreatedAndAdded(String name);

  /// No description provided for @nameMissing.
  ///
  /// In en, this message translates to:
  /// **'Name missing'**
  String get nameMissing;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get enterName;

  /// No description provided for @addExistingExercises.
  ///
  /// In en, this message translates to:
  /// **'Existing exercises'**
  String get addExistingExercises;

  /// No description provided for @createNewExercise.
  ///
  /// In en, this message translates to:
  /// **'Create new exercise'**
  String get createNewExercise;

  /// No description provided for @addSelected.
  ///
  /// In en, this message translates to:
  /// **'Add selected'**
  String get addSelected;

  /// No description provided for @exercisesAdded.
  ///
  /// In en, this message translates to:
  /// **'Exercises added'**
  String get exercisesAdded;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @additionalExercises.
  ///
  /// In en, this message translates to:
  /// **'Add more exercises'**
  String get additionalExercises;

  /// No description provided for @addExercisesToStart.
  ///
  /// In en, this message translates to:
  /// **'Add exercises to start your workout.'**
  String get addExercisesToStart;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @cloudBackupFound.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup found'**
  String get cloudBackupFound;

  /// No description provided for @cloudBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Back up your data to the cloud.'**
  String get cloudBackupDescription;

  /// No description provided for @setUpCloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Set up cloud backup?'**
  String get setUpCloudBackup;

  /// No description provided for @setUpCloudBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to securely back up your workout data to the cloud and sync it between devices. This is optional and the app remains local-first.'**
  String get setUpCloudBackupDescription;

  /// No description provided for @continueWithoutCloud.
  ///
  /// In en, this message translates to:
  /// **'Continue without cloud'**
  String get continueWithoutCloud;

  /// No description provided for @cloudBackupAccountFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'A cloud backup already exists for this account. How would you like to continue?'**
  String get cloudBackupAccountFoundDescription;

  /// No description provided for @doNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Don\'t load'**
  String get doNotLoad;

  /// No description provided for @loadAndReplace.
  ///
  /// In en, this message translates to:
  /// **'Load backup (replace)'**
  String get loadAndReplace;

  /// No description provided for @mergeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Merge (recommended)'**
  String get mergeRecommended;

  /// No description provided for @cloudOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud backup?'**
  String get cloudOverwrite;

  /// No description provided for @cloudOverwriteDescription.
  ///
  /// In en, this message translates to:
  /// **'All existing cloud-backup data will be lost. Continue?'**
  String get cloudOverwriteDescription;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @cloudBackupUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup updated'**
  String get cloudBackupUpdated;

  /// No description provided for @quoteOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Quote of the day'**
  String get quoteOfTheDay;

  /// No description provided for @motivationalQuote.
  ///
  /// In en, this message translates to:
  /// **'{key, select, start{You do not have to be perfect. You just have to start.} consistency{Consistency beats talent.} strength{You are stronger than you think.} progress{Progress, not perfection.} habit{Motivation gets you going. Habit gets you to the finish line.} challenge{If it does not challenge you, it does not change you.} smallSteps{Small steps are better than no steps.} effort{Every workout counts — even the one you did not feel like doing.} discipline{Discipline is the bridge between goals and results.} today{What you do today shapes who you are tomorrow.} routine{The best time to train is the time you can keep.} limits{Your only limit is you.} other{Keep going.}}'**
  String motivationalQuote(String key);

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String lastBackup(String date);

  /// No description provided for @cloudBackupFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'An existing backup was found.'**
  String get cloudBackupFoundDescription;

  /// No description provided for @loadBackup.
  ///
  /// In en, this message translates to:
  /// **'Load backup'**
  String get loadBackup;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// No description provided for @backupRestoredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestoredSuccess;

  /// No description provided for @workoutDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" deleted'**
  String workoutDeleted(String name);

  /// No description provided for @dayStatus.
  ///
  /// In en, this message translates to:
  /// **'{day}: {status}'**
  String dayStatus(String day, String status);

  /// No description provided for @addExercisesForProgress.
  ///
  /// In en, this message translates to:
  /// **'Create exercises first to see progress.'**
  String get addExercisesForProgress;

  /// No description provided for @completeWorkoutForProgress.
  ///
  /// In en, this message translates to:
  /// **'Complete a workout to see progress data.'**
  String get completeWorkoutForProgress;

  /// No description provided for @selectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select exercise'**
  String get selectExercise;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @searchExercise.
  ///
  /// In en, this message translates to:
  /// **'Search exercise'**
  String get searchExercise;

  /// No description provided for @noTrackingFields.
  ///
  /// In en, this message translates to:
  /// **'No fields to track'**
  String get noTrackingFields;

  /// No description provided for @noDataForExercise.
  ///
  /// In en, this message translates to:
  /// **'No data for this exercise yet.'**
  String get noDataForExercise;

  /// No description provided for @exerciseLabel.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exerciseLabel;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @minimum.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minimum;

  /// No description provided for @maximum.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maximum;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTime;

  /// No description provided for @month1.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get month1;

  /// No description provided for @month3.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get month3;

  /// No description provided for @month6.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get month6;

  /// No description provided for @year1.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get year1;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sunday;

  /// No description provided for @goalLabel.
  ///
  /// In en, this message translates to:
  /// **'{goal, select, strength{Strength} endurance{Endurance} cardio{Endurance} mobility{Mobility} other{Other}}'**
  String goalLabel(String goal);

  /// No description provided for @standardExerciseName.
  ///
  /// In en, this message translates to:
  /// **'{key, select, kraft_bankdruecken{Bench press} kraft_kniebeugen{Squats} kraft_kreuzheben{Deadlift} kraft_schulterdruecken{Shoulder press} kraft_langhantelrudern{Barbell row} kraft_bizeps_curls{Biceps curls} kraft_trizepsdruecken{Triceps press} kraft_beinpresse{Leg press} kraft_ausfallschritte{Lunges} kraft_wadenheben{Calf raises} kraft_russian_twist{Russian twist} kraft_latzug{Lat pulldown} kraft_butterfly{Butterfly} kraft_beinbeuger{Leg curl} kraft_beinstrecker{Leg extension} kraft_seitheben{Lateral raise} kraft_facepulls{Face pulls} kraft_brustpresse{Chest press} kraft_hip_thrusts{Hip thrusts} kraft_reverse_flys{Reverse flyes} kraft_bulgarian_split_squats{Bulgarian split squats} kraft_klimmzuege{Pull-ups} kraft_liegestuetze{Push-ups} kraft_dips{Dips} kraft_sit_ups{Sit-ups} kraft_push_ups{Push-ups} kraft_pull_ups{Pull-ups} cardio_joggen{Jogging} cardio_laufen{Running} cardio_radfahren{Cycling} cardio_intervallaeufe{Interval running} cardio_schwimmen{Swimming} ausdauer_plank{Plank} ausdauer_seilspringen{Jump rope} mobilitaet_dehnen{Stretching} mobilitaet_yoga{Yoga} other{Exercise}}'**
  String standardExerciseName(String key);

  /// No description provided for @dataAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & privacy'**
  String get dataAndPrivacy;

  /// No description provided for @resetLocalTrainingData.
  ///
  /// In en, this message translates to:
  /// **'Reset local training data'**
  String get resetLocalTrainingData;

  /// No description provided for @resetLocalTrainingDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes workouts, progress and personal exercise images on this device.'**
  String get resetLocalTrainingDataDescription;

  /// No description provided for @resetLocalTrainingDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Your local training data and personal exercise images will be deleted. Your login, language and appearance stay unchanged.'**
  String get resetLocalTrainingDataConfirm;

  /// No description provided for @confirmResetAgain.
  ///
  /// In en, this message translates to:
  /// **'Really reset local data?'**
  String get confirmResetAgain;

  /// No description provided for @confirmResetAgainDescription.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Automatic cloud backup will be disabled.'**
  String get confirmResetAgainDescription;

  /// No description provided for @resetNow.
  ///
  /// In en, this message translates to:
  /// **'Reset now'**
  String get resetNow;

  /// No description provided for @deleteCloudData.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud data'**
  String get deleteCloudData;

  /// No description provided for @deleteCloudDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes every Trainy backup stored for this account. Local data and the account remain.'**
  String get deleteCloudDataDescription;

  /// No description provided for @deleteCloudDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'All Trainy cloud objects for your account will be deleted.'**
  String get deleteCloudDataConfirm;

  /// No description provided for @confirmCloudDeleteAgain.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete cloud data?'**
  String get confirmCloudDeleteAgain;

  /// No description provided for @confirmCloudDeleteAgainDescription.
  ///
  /// In en, this message translates to:
  /// **'The operation can be retried if the connection is interrupted.'**
  String get confirmCloudDeleteAgainDescription;

  /// No description provided for @cloudDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cloud data deleted'**
  String get cloudDataDeleted;

  /// No description provided for @deleteAccountAndData.
  ///
  /// In en, this message translates to:
  /// **'Delete account and all data'**
  String get deleteAccountAndData;

  /// No description provided for @deleteAccountAndDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes cloud data, the Firebase account and all local app data.'**
  String get deleteAccountAndDataDescription;

  /// No description provided for @deleteAccountAndDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will be asked to sign in with Google again. Then the account and all Trainy data will be deleted.'**
  String get deleteAccountAndDataConfirm;

  /// No description provided for @confirmAccountDeleteAgain.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account?'**
  String get confirmAccountDeleteAgain;

  /// No description provided for @confirmAccountDeleteAgainDescription.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get confirmAccountDeleteAgainDescription;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// No description provided for @activeWorkoutMustEnd.
  ///
  /// In en, this message translates to:
  /// **'Active workout'**
  String get activeWorkoutMustEnd;

  /// No description provided for @activeWorkoutMustEndDescription.
  ///
  /// In en, this message translates to:
  /// **'The current workout must be completed or discarded before data can be deleted.'**
  String get activeWorkoutMustEndDescription;

  /// No description provided for @discardAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Discard & continue'**
  String get discardAndContinue;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @localDataRecovery.
  ///
  /// In en, this message translates to:
  /// **'Local data recovery'**
  String get localDataRecovery;

  /// No description provided for @localDataNeedsRecovery.
  ///
  /// In en, this message translates to:
  /// **'Your local training data needs attention'**
  String get localDataNeedsRecovery;

  /// No description provided for @localDataNeedsRecoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Trainy did not delete the database. You can retry opening it, save a raw recovery copy, or explicitly reset the local training data.'**
  String get localDataNeedsRecoveryDescription;

  /// No description provided for @saveRecoveryCopy.
  ///
  /// In en, this message translates to:
  /// **'Save recovery copy'**
  String get saveRecoveryCopy;

  /// No description provided for @recoverySaved.
  ///
  /// In en, this message translates to:
  /// **'Recovery copy saved to {path}'**
  String recoverySaved(String path);

  /// No description provided for @recoveryExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The recovery copy could not be saved.'**
  String get recoveryExportFailed;

  /// No description provided for @recoveryResetDescription.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the local training database and creates a fresh one. Save a recovery copy first if you may need the data.'**
  String get recoveryResetDescription;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @finishingLocally.
  ///
  /// In en, this message translates to:
  /// **'Finishing locally …'**
  String get finishingLocally;

  /// No description provided for @savedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get savedLocally;

  /// No description provided for @workoutSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The workout is still available as a local draft. Saving failed; please retry.'**
  String get workoutSaveFailed;

  /// No description provided for @workoutAutosaveFailed.
  ///
  /// In en, this message translates to:
  /// **'A change could not be saved locally. Your input remains here; retry before finishing.'**
  String get workoutAutosaveFailed;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetFilters;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @allProfiles.
  ///
  /// In en, this message translates to:
  /// **'All profiles'**
  String get allProfiles;

  /// No description provided for @noMatchingExercises.
  ///
  /// In en, this message translates to:
  /// **'No matching exercises'**
  String get noMatchingExercises;

  /// No description provided for @noMatchingExercisesDescription.
  ///
  /// In en, this message translates to:
  /// **'Change your search or reset the active filters.'**
  String get noMatchingExercisesDescription;

  /// No description provided for @englishSynonym.
  ///
  /// In en, this message translates to:
  /// **'English: {name}'**
  String englishSynonym(String name);

  /// No description provided for @selectImage.
  ///
  /// In en, this message translates to:
  /// **'Select image'**
  String get selectImage;

  /// No description provided for @replaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get replaceImage;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeImage;

  /// No description provided for @exerciseCover.
  ///
  /// In en, this message translates to:
  /// **'Exercise image'**
  String get exerciseCover;

  /// No description provided for @equipmentBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get equipmentBicycle;

  /// No description provided for @equipmentPool.
  ///
  /// In en, this message translates to:
  /// **'Swimming pool'**
  String get equipmentPool;

  /// No description provided for @workoutBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get workoutBasics;

  /// No description provided for @workoutSetup.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get workoutSetup;

  /// No description provided for @workoutExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get workoutExercises;

  /// No description provided for @choosePrimaryGoal.
  ///
  /// In en, this message translates to:
  /// **'Choose this workout\'s primary goal'**
  String get choosePrimaryGoal;

  /// No description provided for @primaryGoal.
  ///
  /// In en, this message translates to:
  /// **'Primary goal'**
  String get primaryGoal;

  /// No description provided for @setupName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get setupName;

  /// No description provided for @withoutProfile.
  ///
  /// In en, this message translates to:
  /// **'No profile'**
  String get withoutProfile;

  /// No description provided for @createSetup.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get createSetup;

  /// No description provided for @selectSetup.
  ///
  /// In en, this message translates to:
  /// **'Choose profile'**
  String get selectSetup;

  /// No description provided for @setups.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get setups;

  /// No description provided for @weeklyPlanner.
  ///
  /// In en, this message translates to:
  /// **'Weekly planner'**
  String get weeklyPlanner;

  /// No description provided for @editWeeklyPlanner.
  ///
  /// In en, this message translates to:
  /// **'Edit weekly planner'**
  String get editWeeklyPlanner;

  /// No description provided for @addToWeeklyPlanner.
  ///
  /// In en, this message translates to:
  /// **'Add to weekly planner'**
  String get addToWeeklyPlanner;

  /// No description provided for @addWorkoutToDay.
  ///
  /// In en, this message translates to:
  /// **'Add workout'**
  String get addWorkoutToDay;

  /// No description provided for @noWorkoutPlanned.
  ///
  /// In en, this message translates to:
  /// **'No workout planned'**
  String get noWorkoutPlanned;

  /// No description provided for @moveWorkout.
  ///
  /// In en, this message translates to:
  /// **'Move workout'**
  String get moveWorkout;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @coreExercise.
  ///
  /// In en, this message translates to:
  /// **'Required exercise'**
  String get coreExercise;

  /// No description provided for @optionalExercise.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalExercise;

  /// No description provided for @makeOptional.
  ///
  /// In en, this message translates to:
  /// **'Mark optional'**
  String get makeOptional;

  /// No description provided for @makeCore.
  ///
  /// In en, this message translates to:
  /// **'Mark core'**
  String get makeCore;

  /// No description provided for @moveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to another group'**
  String get moveToGroup;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(int current, int total);

  /// No description provided for @saveWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save workout'**
  String get saveWorkout;

  /// No description provided for @noSetups.
  ///
  /// In en, this message translates to:
  /// **'No profile yet'**
  String get noSetups;

  /// No description provided for @setupExercisesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No exercises} =1{1 exercise} other{{count} exercises}}'**
  String setupExercisesCount(int count);

  /// No description provided for @plannedWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Planned workouts'**
  String get plannedWorkouts;

  /// No description provided for @dayDetails.
  ///
  /// In en, this message translates to:
  /// **'Day overview'**
  String get dayDetails;

  /// No description provided for @workoutAlreadyPlanned.
  ///
  /// In en, this message translates to:
  /// **'This workout is already planned for this day.'**
  String get workoutAlreadyPlanned;

  /// No description provided for @defaultSetup.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultSetup;

  /// No description provided for @chooseSetupProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile for this training environment.'**
  String get chooseSetupProfile;

  /// No description provided for @profileSetup.
  ///
  /// In en, this message translates to:
  /// **'Use this profile'**
  String get profileSetup;

  /// No description provided for @makeDefaultSetup.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get makeDefaultSetup;

  /// No description provided for @warmupGroup.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get warmupGroup;

  /// No description provided for @coreExercisesGroup.
  ///
  /// In en, this message translates to:
  /// **'Main exercises'**
  String get coreExercisesGroup;

  /// No description provided for @cooldownGroup.
  ///
  /// In en, this message translates to:
  /// **'Cooldown'**
  String get cooldownGroup;

  /// No description provided for @dropExercisesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop exercises here'**
  String get dropExercisesHere;

  /// No description provided for @dragExercise.
  ///
  /// In en, this message translates to:
  /// **'Drag exercise'**
  String get dragExercise;

  /// No description provided for @selectedExercises.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise selected} other{{count} exercises selected}}'**
  String selectedExercises(int count);

  /// No description provided for @groupSelectedExercises.
  ///
  /// In en, this message translates to:
  /// **'Group selected exercises'**
  String get groupSelectedExercises;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @showAllExercises.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAllExercises;

  /// No description provided for @prioritizeProfileExercises.
  ///
  /// In en, this message translates to:
  /// **'Prioritize matching'**
  String get prioritizeProfileExercises;

  /// No description provided for @switchExerciseForSession.
  ///
  /// In en, this message translates to:
  /// **'Switch exercise for this session'**
  String get switchExerciseForSession;

  /// No description provided for @removeFromWeeklyPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove from weekly plan'**
  String get removeFromWeeklyPlan;

  /// No description provided for @weeklyPlacementRemoved.
  ///
  /// In en, this message translates to:
  /// **'Workout removed from weekly plan'**
  String get weeklyPlacementRemoved;

  /// No description provided for @dragGroup.
  ///
  /// In en, this message translates to:
  /// **'Drag group'**
  String get dragGroup;

  /// No description provided for @requiredExercise.
  ///
  /// In en, this message translates to:
  /// **'Required exercise'**
  String get requiredExercise;

  /// No description provided for @exerciseRequirement.
  ///
  /// In en, this message translates to:
  /// **'Required/Optional'**
  String get exerciseRequirement;

  /// No description provided for @workoutEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this change. Please try again.'**
  String get workoutEditFailed;

  /// No description provided for @alreadyInWorkout.
  ///
  /// In en, this message translates to:
  /// **'Already in this workout'**
  String get alreadyInWorkout;

  /// No description provided for @noExercisesFound.
  ///
  /// In en, this message translates to:
  /// **'No matching exercises. Change the search or label.'**
  String get noExercisesFound;

  /// No description provided for @swapLockedAfterSets.
  ///
  /// In en, this message translates to:
  /// **'Sets have already been recorded. This exercise can no longer be replaced.'**
  String get swapLockedAfterSets;

  /// No description provided for @finishActiveWorkoutFirst.
  ///
  /// In en, this message translates to:
  /// **'Please resume or finish the active session first.'**
  String get finishActiveWorkoutFirst;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Training locations & equipment'**
  String get profilesTitle;

  /// No description provided for @profileTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get profileTemplate;

  /// No description provided for @homeGym.
  ///
  /// In en, this message translates to:
  /// **'Home Gym'**
  String get homeGym;

  /// No description provided for @gym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gym;

  /// No description provided for @individualProfile.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get individualProfile;

  /// No description provided for @selectAllEquipment.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAllEquipment;

  /// No description provided for @clearEquipment.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearEquipment;

  /// No description provided for @profileRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile for this workout.'**
  String get profileRequired;

  /// No description provided for @profileSharedHint.
  ///
  /// In en, this message translates to:
  /// **'Equipment changes apply to all workouts using this profile.'**
  String get profileSharedHint;

  /// No description provided for @profileOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do you train?'**
  String get profileOnboardingTitle;

  /// No description provided for @profileOnboardingHint.
  ///
  /// In en, this message translates to:
  /// **'Choose your default for new workouts and check your equipment. You can add more profiles anytime.'**
  String get profileOnboardingHint;

  /// No description provided for @profileIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up profiles'**
  String get profileIntroTitle;

  /// No description provided for @profileIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Use Home Gym and Gym templates and choose your default.'**
  String get profileIntroBody;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get configure;

  /// No description provided for @preferredProfile.
  ///
  /// In en, this message translates to:
  /// **'Default for new workouts'**
  String get preferredProfile;

  /// No description provided for @useExistingProfile.
  ///
  /// In en, this message translates to:
  /// **'Use an existing profile'**
  String get useExistingProfile;

  /// No description provided for @moreWorkoutProfiles.
  ///
  /// In en, this message translates to:
  /// **'Use another profile'**
  String get moreWorkoutProfiles;

  /// No description provided for @copyWorkoutExercises.
  ///
  /// In en, this message translates to:
  /// **'Copy exercises'**
  String get copyWorkoutExercises;

  /// No description provided for @emptyWorkoutProfile.
  ///
  /// In en, this message translates to:
  /// **'Start empty'**
  String get emptyWorkoutProfile;

  /// No description provided for @configureWorkoutProfile.
  ///
  /// In en, this message translates to:
  /// **'How would you like to set up this profile?'**
  String get configureWorkoutProfile;

  /// No description provided for @linkWorkoutProfile.
  ///
  /// In en, this message translates to:
  /// **'Link existing exercises'**
  String get linkWorkoutProfile;

  /// No description provided for @discardWorkoutDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard workout draft?'**
  String get discardWorkoutDraft;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @noExercisesToStart.
  ///
  /// In en, this message translates to:
  /// **'Add exercises before starting.'**
  String get noExercisesToStart;

  /// No description provided for @duplicateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Duplicate check unavailable.'**
  String get duplicateCheckFailed;

  /// No description provided for @weeklyRecurrence.
  ///
  /// In en, this message translates to:
  /// **'This plan repeats every week.'**
  String get weeklyRecurrence;

  /// No description provided for @allWorkoutsPlanned.
  ///
  /// In en, this message translates to:
  /// **'All workouts are already planned for this day.'**
  String get allWorkoutsPlanned;

  /// No description provided for @noWorkoutsToPlan.
  ///
  /// In en, this message translates to:
  /// **'Create a workout first.'**
  String get noWorkoutsToPlan;

  /// No description provided for @profileArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get profileArchived;

  /// No description provided for @equipmentSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String equipmentSelectionCount(int count);

  /// No description provided for @startWithProfile.
  ///
  /// In en, this message translates to:
  /// **'Start with {name}'**
  String startWithProfile(String name);

  /// No description provided for @applyExerciseSelection.
  ///
  /// In en, this message translates to:
  /// **'Apply ({count})'**
  String applyExerciseSelection(int count);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
