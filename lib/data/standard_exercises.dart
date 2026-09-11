/// Wartbare Registry aller Standardübungen.
///
/// Neue Übungen einfach ans Ende der Liste anhängen — beim nächsten
/// App-Start werden sie automatisch in die DB eingefügt (sofern der
/// Key noch nicht in `seeded_standards` eingetragen ist).
class StandardExercise {
  final String key;
  /// Legacy German catalog name. It is only a migration/fallback value; the
  /// user-facing name is resolved from local ARB resources.
  final String name;
  final String goal;
  final bool trackSets;
  final bool trackReps;
  final bool trackWeight;
  final bool trackDuration;
  final bool trackDistance;

  const StandardExercise({
    required this.key,
    required this.name,
    required this.goal,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
    this.trackDistance = false,
  });
}

const List<StandardExercise> standardExercises = [
  // ─── Kraft (Geräte / Hanteln) ───
  StandardExercise(key: 'kraft_bankdruecken',      name: 'Bankdrücken',       goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_kniebeugen',        name: 'Kniebeugen',        goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_kreuzheben',        name: 'Kreuzheben',        goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_schulterdruecken',  name: 'Schulterdrücken',   goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_langhantelrudern',  name: 'Langhantelrudern',  goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_bizeps_curls',      name: 'Bizeps-Curls',      goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_trizepsdruecken',   name: 'Trizepsdrücken',    goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_beinpresse',        name: 'Beinpresse',        goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_ausfallschritte',   name: 'Ausfallschritte',   goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_wadenheben',        name: 'Wadenheben',        goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_russian_twist',     name: 'Russian Twist',     goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_latzug',            name: 'Latzug',            goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_butterfly',         name: 'Butterfly',         goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_beinbeuger',        name: 'Beinbeuger',        goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_beinstrecker',      name: 'Beinstrecker',      goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_seitheben',         name: 'Seitheben',         goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_facepulls',         name: 'Facepulls',         goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_brustpresse',       name: 'Brustpresse',       goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_hip_thrusts',       name: 'Hip Thrusts',       goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_reverse_flys',      name: 'Reverse Flys',     goal: 'strength', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_bulgarian_split_squats', name: 'Bulgarian Split Squats', goal: 'strength', trackSets: true, trackReps: true, trackWeight: true, trackDuration: false),

  // ─── Kraft (Körpergewicht) ───
  StandardExercise(key: 'kraft_klimmzuege',    name: 'Klimmzüge',    goal: 'strength', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_liegestuetze',  name: 'Liegestütze',  goal: 'strength', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_dips',          name: 'Dips',         goal: 'strength', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_sit_ups',       name: 'Sit-ups',      goal: 'strength', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_push_ups',      name: 'Push-ups',     goal: 'strength', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_pull_ups',      name: 'Pull-ups',     goal: 'strength', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),

  // ─── Cardio ───
  StandardExercise(key: 'cardio_joggen',         name: 'Joggen',         goal: 'cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true, trackDistance: true),
  StandardExercise(key: 'cardio_laufen',         name: 'Laufen',         goal: 'cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true, trackDistance: true),
  StandardExercise(key: 'cardio_radfahren',      name: 'Radfahren',      goal: 'cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true, trackDistance: true),
  StandardExercise(key: 'cardio_intervallaeufe', name: 'Intervallläufe', goal: 'cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true, trackDistance: true),
  StandardExercise(key: 'cardio_schwimmen',      name: 'Schwimmen',      goal: 'cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true, trackDistance: true),

  // ─── Ausdauer ───
  StandardExercise(key: 'ausdauer_plank',        name: 'Plank',        goal: 'endurance', trackSets: true, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'ausdauer_seilspringen', name: 'Seilspringen', goal: 'endurance', trackSets: true, trackReps: false, trackWeight: false, trackDuration: true),

  // ─── Mobilität ───
  StandardExercise(key: 'mobilitaet_dehnen', name: 'Dehnen', goal: 'mobility', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'mobilitaet_yoga',   name: 'Yoga',   goal: 'mobility', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
];
