// lib/models/exercise_in_workout.dart

import 'package:flutter/material.dart';

class ExerciseInWorkout {
  final int id;
  final int workoutId;
  final int exerciseId;
  final String name;
  final String description;
  final List<String> trackedFields;
  final Map<String, String> defaultValues;
  final Map<String, String> units;
  final IconData icon;
  final int position;

  ExerciseInWorkout({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.name,
    required this.description,
    required this.trackedFields,
    required this.defaultValues,
    required this.units,
    required this.icon,
    required this.position,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'exerciseId': exerciseId,
      'name': name,
      'description': description,
      'trackedFields': trackedFields.join(','),
      'defaultValues': defaultValues.toString(),
      'units': units.toString(),
      'icon': icon.codePoint,
      'position': position,
    };
  }

  static ExerciseInWorkout fromMap(Map<String, dynamic> map) {
    return ExerciseInWorkout(
      id: map['id'],
      workoutId: map['workoutId'],
      exerciseId: map['exerciseId'],
      name: map['name'],
      description: map['description'] ?? '',
      trackedFields: (map['trackedFields'] as String).split(','),
      defaultValues: _parseMap(map['defaultValues']),
      units: _parseMap(map['units']),
      icon: IconData(map['icon'], fontFamily: 'MaterialIcons'),
      position: map['position'],
    );
  }

  static Map<String, String> _parseMap(String input) {
    input = input.replaceAll(RegExp(r'^{|}\$'), '');
    if (input.trim().isEmpty) return {};
    return Map.fromEntries(
      input.split(', ').map((e) {
        final parts = e.split(': ');
        return MapEntry(parts[0], parts[1]);
      }),
    );
  }
}
