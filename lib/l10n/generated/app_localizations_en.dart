// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get trainingProfile => 'Training profile';

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
  String get trainingProfileDescription => 'Choose the equipment available for your default training location.';

  @override
  String get addTrainingProfile => 'Add training profile';

  @override
  String get editTrainingProfile => 'Edit training profile';

  @override
  String get archiveProfile => 'Archive profile?';

  @override
  String archiveProfileDescription(String name) {
    return '\"$name\" will no longer be offered as a training profile. Existing sessions remain unchanged.';
  }

  @override
  String get profileLoadFailed => 'Training profiles could not be loaded.';

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
        'cardio': 'Cardio',
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
  String get workoutSetup => 'Setup';

  @override
  String get workoutExercises => 'Exercises';

  @override
  String get choosePrimaryGoal => 'Choose this workout\'s primary goal';

  @override
  String get primaryGoal => 'Primary goal';

  @override
  String get setupName => 'Setup name';

  @override
  String get withoutProfile => 'No training profile';

  @override
  String get createSetup => 'Add setup';

  @override
  String get selectSetup => 'Choose setup';

  @override
  String get setups => 'Setups';

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
  String get noSetups => 'No setup yet';

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
  String get defaultSetup => 'Default setup';

  @override
  String get chooseSetupProfile => 'Which training environment is this setup for?';

  @override
  String get profileSetup => 'Use this profile';

  @override
  String get makeDefaultSetup => 'Make default setup';

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
}
