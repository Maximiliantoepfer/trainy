// lib/models/exercise.dart

import 'package:flutter/material.dart';
import 'dart:convert';

class Exercise {
  final int id;
  final String name;
  final String description;
  final List<String> trackedFields;
  final Map<String, String> defaultValues;
  final Map<String, String> units;
  final IconData icon;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.trackedFields,
    required this.defaultValues,
    required this.units,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trackedFields': trackedFields.join(','),
      'defaultValues': jsonEncode(defaultValues),
      'units': jsonEncode(units),
      'icon': icon.codePoint,
    };
  }

  static Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      trackedFields: (map['trackedFields'] as String).split(','),
      defaultValues: _safeDecodeMap(map['defaultValues']),
      units: _safeDecodeMap(map['units']),
      icon: IconData(map['icon'], fontFamily: 'MaterialIcons'),
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
