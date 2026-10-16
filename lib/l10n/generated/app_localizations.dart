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
  /// **'Own'**
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
  /// **'Training profile'**
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
  /// **'Add alternatives'**
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
  /// **'{goal, select, strength{Strength} endurance{Endurance} cardio{Cardio} mobility{Mobility} other{Other}}'**
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
