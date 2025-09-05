// lib/models/exercise_in_workout.dart

import 'dart:convert';

class ExerciseInWorkout {
  final int id;
  final int workoutId;
  final int exerciseId;
  final int position;
  final Map<String, String>
  customValues; // Zuletzt verwendete Werte für diese Übung

  ExerciseInWorkout({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.position,
    this.customValues = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'exerciseId': exerciseId,
      'position': position,
      'customValues': jsonEncode(customValues),
    };
  }

  static ExerciseInWorkout fromMap(Map<String, dynamic> map) {
    return ExerciseInWorkout(
      id: map['id'],
      workoutId: map['workoutId'],
      exerciseId: map['exerciseId'],
      position: map['position'],
      customValues: _safeDecodeMap(map['customValues']),
    );
  }

  static Map<String, String> _safeDecodeMap(String? input) {
    try {
      final decoded = jsonDecode(input ?? '{}');
      if (decoded is Map) {
        return Map<String, String>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  ExerciseInWorkout copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? position,
    Map<String, String>? customValues,
    Map<String, String>? defaultValues,
  }) {
    return ExerciseInWorkout(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      customValues: customValues ?? Map.from(this.customValues),
    );
  }
}
