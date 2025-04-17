// lib/models/exercise_in_workout.dart

import 'package:flutter/material.dart';
import 'dart:convert';

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
      'defaultValues': jsonEncode(defaultValues),
      'units': jsonEncode(units),
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
      defaultValues: _safeDecodeMap(map['defaultValues']),
      units: _safeDecodeMap(map['units']),
      icon: IconData(map['icon'], fontFamily: 'MaterialIcons'),
      position: map['position'],
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
}
