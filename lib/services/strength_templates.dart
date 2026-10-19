import '../models/workout_planning.dart';

class StrengthAlternative {
  const StrengthAlternative(this.catalogId, this.equipment);
  final String catalogId;
  final Set<String> equipment;
  bool available(Set<String> owned) => owned.containsAll(equipment);
}

class StrengthTemplateExercise {
  const StrengthTemplateExercise(
    this.key,
    this.focus,
    this.sets,
    this.alternatives, {
    this.extra = false,
    this.isolation = false,
  });
  final String key, focus;
  final int sets;
  final bool extra, isolation;
  final List<StrengthAlternative> alternatives;
  StrengthPrescription get prescription => StrengthPrescription(
    sets: sets,
    minReps: isolation ? 10 : 8,
    maxReps: isolation ? 15 : 12,
  );
  StrengthAlternative? forEquipment(Set<String> owned) =>
      alternatives.where((a) => a.available(owned)).firstOrNull;
}

/// Deliberate alternatives, never an arbitrary same-muscle replacement.
abstract final class StrengthTemplates {
  static const codes = [
    'fullBody',
    'upper',
    'lower',
    'push',
    'pull',
    'legs',
    'pushCore',
    'pullLegs',
  ];
  static const pushup = StrengthTemplateExercise('pushup', 'push', 3, [
    StrengthAlternative('free:Pushups', {'bodyweight'}),
  ]);
  static const dip = StrengthTemplateExercise('dip', 'push', 2, [
    StrengthAlternative('free:Dips_-_Chest_Version', {'bodyweight', 'other'}),
    StrengthAlternative('free:Dip_Machine', {'machine'}),
  ]);
  static const incline = StrengthTemplateExercise('incline', 'push', 2, [
    StrengthAlternative('free:Incline_Dumbbell_Press', {'dumbbell', 'bench'}),
  ]);
  static const lateral = StrengthTemplateExercise('lateral', 'push', 3, [
    StrengthAlternative('free:Side_Lateral_Raise', {'dumbbell'}),
  ], isolation: true);
  static const shoulder = StrengthTemplateExercise('shoulder', 'push', 2, [
    StrengthAlternative('free:Dumbbell_Shoulder_Press', {'dumbbell', 'bench'}),
  ], extra: true);
  static const triceps = StrengthTemplateExercise(
    'triceps',
    'push',
    2,
    [
      StrengthAlternative('free:Seated_Triceps_Press', {'dumbbell', 'bench'}),
      StrengthAlternative('free:Push-Ups_-_Close_Triceps_Position', {
        'bodyweight',
      }),
    ],
    extra: true,
    isolation: true,
  );
  static const core = StrengthTemplateExercise('core', 'core', 3, [
    StrengthAlternative('free:Hanging_Leg_Raise', {'pull_up_bar'}),
    StrengthAlternative('free:Crunches', {'bodyweight'}),
  ], isolation: true);
  static const pullup = StrengthTemplateExercise('pullup', 'pull', 3, [
    StrengthAlternative('free:Pullups', {'pull_up_bar'}),
  ]);
  static const row = StrengthTemplateExercise('row', 'pull', 1, [
    StrengthAlternative('free:Bent_Over_Two-Dumbbell_Row', {'dumbbell'}),
  ], extra: true);
  static const reverseFly = StrengthTemplateExercise('reverseFly', 'pull', 3, [
    StrengthAlternative('free:Reverse_Flyes', {'dumbbell', 'bench'}),
  ], isolation: true);
  static const wRaise = StrengthTemplateExercise(
    'wRaise',
    'pull',
    1,
    [
      StrengthAlternative('trainy:w_raises', {'bodyweight'}),
    ],
    extra: true,
    isolation: true,
  );
  static const back = StrengthTemplateExercise('back', 'pull', 1, [
    StrengthAlternative('free:Hyperextensions_Back_Extensions', {'other'}),
    StrengthAlternative('free:Superman', {'bodyweight'}),
  ]);
  static const curl = StrengthTemplateExercise(
    'curl',
    'pull',
    2,
    [
      StrengthAlternative('free:Dumbbell_Bicep_Curl', {'dumbbell'}),
    ],
    extra: true,
    isolation: true,
  );
  static const bulgarian = StrengthTemplateExercise('bulgarian', 'legs', 3, [
    StrengthAlternative('trainy:bulgarian_split_squat', {
      'bodyweight',
      'bench',
    }),
  ]);
  static const hip = StrengthTemplateExercise('hip', 'legs', 2, [
    StrengthAlternative('free:Barbell_Hip_Thrust', {'barbell', 'bench'}),
    StrengthAlternative('free:Butt_Lift_Bridge', {'bodyweight'}),
  ]);
  static const squat = StrengthTemplateExercise('squat', 'legs', 1, [
    StrengthAlternative('free:Wide_Stance_Barbell_Squat', {'barbell', 'rack'}),
  ], extra: true);
  static const side = StrengthTemplateExercise(
    'side',
    'core',
    1,
    [
      StrengthAlternative('trainy:side_plank_leg_raise', {'bodyweight'}),
    ],
    extra: true,
    isolation: true,
  );
  static const calf = StrengthTemplateExercise(
    'calf',
    'legs',
    1,
    [
      StrengthAlternative('trainy:standing_calf_raise', {'bodyweight'}),
    ],
    extra: true,
    isolation: true,
  );
  static const _push = [pushup, dip, incline, lateral, shoulder, triceps];
  static const _pull = [pullup, row, reverseFly, wRaise, back, curl];
  static const _legs = [bulgarian, hip, squat, side, calf];
  static List<StrengthTemplateExercise> exercises(String code) =>
      switch (code) {
        'push' => _push,
        'pull' => _pull,
        'legs' || 'lower' => _legs,
        'pushCore' => [..._push, core],
        'pullLegs' => [..._pull, ..._legs],
        'upper' =>
          _full.where((e) => e.focus == 'push' || e.focus == 'pull').toList(),
        _ => _full,
      };
  static final _full = <StrengthTemplateExercise>[
    StrengthTemplateExercise('pushup', 'push', 3, [
      StrengthAlternative('free:Pushups', {'bodyweight'}),
      StrengthAlternative('free:Dips_-_Chest_Version', {'bodyweight', 'other'}),
    ]),
    pullup,
    StrengthTemplateExercise('row', 'pull', 2, [
      StrengthAlternative('free:Bent_Over_Two-Dumbbell_Row', {'dumbbell'}),
    ], extra: true),
    lateral,
    shoulder,
    reverseFly,
    wRaise,
    StrengthTemplateExercise('back', 'pull', 1, back.alternatives, extra: true),
    bulgarian,
    StrengthTemplateExercise('hip', 'legs', 1, hip.alternatives, extra: true),
    side,
    core,
    curl,
    triceps,
  ];
}
