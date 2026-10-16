import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/models/catalog_exercise.dart';
import 'package:trainy/utils/goal_utils.dart';

void main() {
  test('catalog definition keeps stable identity and two goals at most', () {
    final exercise = CatalogExercise.fromJson({
      'id': 'free:Barbell_Squat',
      'movementFamilyId': 'squat',
      'primaryMuscleIds': ['quadriceps'],
      'secondaryMuscleIds': ['glutes'],
      'equipmentIds': ['barbell'],
      'goalCodes': ['strength'],
      'tracking': {
        'sets': true,
        'reps': true,
        'weight': true,
        'duration': false,
        'distance': false,
      },
      'imageAssetPath': 'assets/catalog/images/Barbell_Squat.webp',
      'aliases': ['Barbell Squat'],
    });

    expect(exercise.id, 'free:Barbell_Squat');
    expect(exercise.movementFamilyId, 'squat');
    expect(exercise.tracking.weight, isTrue);
  });

  test('weekly goal priority is strength, endurance, cardio, mobility', () {
    expect(prioritizedGoal(['mobility', 'endurance']), 'endurance');
    expect(prioritizedGoal(['cardio', 'strength']), 'strength');
    expect(prioritizedGoal(['cardio', 'endurance']), 'endurance');
    expect(prioritizedGoal(['mobility', 'cardio']), 'cardio');
    expect(prioritizedGoal(const []), isNull);
  });
}
