import '../models/strength_plan.dart';
import '../models/workout_planning.dart';
import 'cardio_training.dart';

abstract final class StrengthRoutines {
  static List<StrengthExerciseDraft> preset(
    String focus, {
    required bool cooling,
  }) {
    final codes =
        focus == 'fullBody'
            ? (cooling
                ? ['chestStretch', 'gluteStretch', 'hamstring']
                : [
                  'shoulderCircles',
                  'armCircles',
                  'rotation',
                  'hinge',
                  'squat',
                  'birdDog',
                ])
            : (cooling
                ? CardioTraining.cooldowns[focus]!
                : CardioTraining.warmups[focus]!);
    return [
      for (final code in codes)
        StrengthExerciseDraft(
          catalogId: 'trainy:routine_$code',
          prescription: StrengthPrescription(
            sets: 1,
            durationSeconds: cooling ? 60 : 30,
            restSeconds: 0,
            source: 'routine',
          ),
        ),
    ];
  }
}
