/// Stable codes. Legacy broad equipment remains readable, never an automatic
/// assertion that every particular machine is available.
abstract final class StrengthEquipment {
  static const basic = <String>{
    'bodyweight',
    'pull_up_bar',
    'dumbbell',
    'barbell',
    'bench',
    'mat',
    'weighted_vest',
    'dip_bars',
    'back_extension',
    'rack',
    'cable',
    'kettlebell',
    'bands',
    'ez_bar',
    'medicine_ball',
    'exercise_ball',
    'foam_roller',
  };
  static const machines = <String>{
    'chest_press',
    'shoulder_press',
    'lateral_raise_machine',
    'lat_pulldown',
    'row_machine',
    'rear_delt_machine',
    'assisted_pullup',
    'leg_press',
    'leg_extension',
    'leg_curl',
    'hip_thrust_machine',
    'calf_machine',
    'ab_machine',
    'arm_curl_machine',
    'triceps_machine',
  };
  static const all = <String>{...basic, ...machines};
  static const gym = <String>{...all};
}
