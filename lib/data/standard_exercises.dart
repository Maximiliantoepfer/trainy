/// Wartbare Registry aller Standardübungen.
///
/// Neue Übungen einfach ans Ende der Liste anhängen — beim nächsten
/// App-Start werden sie automatisch in die DB eingefügt (sofern der
/// Key noch nicht in `seeded_standards` eingetragen ist).
class StandardExercise {
  final String key;
  final String name;
  final String goal;
  final bool trackSets;
  final bool trackReps;
  final bool trackWeight;
  final bool trackDuration;

  const StandardExercise({
    required this.key,
    required this.name,
    required this.goal,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
  });
}

const List<StandardExercise> standardExercises = [
  // ─── Kraft (Geräte / Hanteln) ───
  StandardExercise(key: 'kraft_bankdruecken',      name: 'Bankdrücken',       goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_kniebeugen',        name: 'Kniebeugen',        goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_kreuzheben',        name: 'Kreuzheben',        goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_schulterdruecken',  name: 'Schulterdrücken',   goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_langhantelrudern',  name: 'Langhantelrudern',  goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_bizeps_curls',      name: 'Bizeps-Curls',      goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_trizepsdruecken',   name: 'Trizepsdrücken',    goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_beinpresse',        name: 'Beinpresse',        goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_ausfallschritte',   name: 'Ausfallschritte',   goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_wadenheben',        name: 'Wadenheben',        goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_russian_twist',     name: 'Russian Twist',     goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_latzug',            name: 'Latzug',            goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_butterfly',         name: 'Butterfly',         goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_beinbeuger',        name: 'Beinbeuger',        goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_beinstrecker',      name: 'Beinstrecker',      goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_seitheben',         name: 'Seitheben',         goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_facepulls',         name: 'Facepulls',         goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_brustpresse',       name: 'Brustpresse',       goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_hip_thrusts',       name: 'Hip Thrusts',       goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_reverse_flys',      name: 'Reverse Flys',     goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true,  trackDuration: false),
  StandardExercise(key: 'kraft_bulgarian_split_squats', name: 'Bulgarian Split Squats', goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: true, trackDuration: false),

  // ─── Kraft (Körpergewicht) ───
  StandardExercise(key: 'kraft_klimmzuege',    name: 'Klimmzüge',    goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_liegestuetze',  name: 'Liegestütze',  goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_dips',          name: 'Dips',         goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_sit_ups',       name: 'Sit-ups',      goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_push_ups',      name: 'Push-ups',     goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),
  StandardExercise(key: 'kraft_pull_ups',      name: 'Pull-ups',     goal: 'Kraft', trackSets: true, trackReps: true, trackWeight: false, trackDuration: false),

  // ─── Cardio ───
  StandardExercise(key: 'cardio_joggen',         name: 'Joggen',         goal: 'Cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'cardio_laufen',         name: 'Laufen',         goal: 'Cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'cardio_radfahren',      name: 'Radfahren',      goal: 'Cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'cardio_intervallaeufe', name: 'Intervallläufe', goal: 'Cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'cardio_schwimmen',      name: 'Schwimmen',      goal: 'Cardio', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),

  // ─── Ausdauer ───
  StandardExercise(key: 'ausdauer_plank',        name: 'Plank',        goal: 'Ausdauer', trackSets: true, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'ausdauer_seilspringen', name: 'Seilspringen', goal: 'Ausdauer', trackSets: true, trackReps: false, trackWeight: false, trackDuration: true),

  // ─── Mobilität ───
  StandardExercise(key: 'mobilitaet_dehnen', name: 'Dehnen', goal: 'Mobilität', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
  StandardExercise(key: 'mobilitaet_yoga',   name: 'Yoga',   goal: 'Mobilität', trackSets: false, trackReps: false, trackWeight: false, trackDuration: true),
];
