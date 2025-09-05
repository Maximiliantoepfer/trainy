// lib/models/exercise.dart

import 'package:flutter/material.dart';
import 'dart:convert';

class Exercise {
  final int id;
  final String name;
  final String description;

  /// Welche Felder werden für diese Übung getrackt? (z. B. Gewicht, Wiederholungen)
  final List<String> trackedFields;

  /// Feste Vorgabewerte – werden als Startwerte in Formularen angeboten
  final Map<String, String> defaultValues;

  /// Zuletzt geloggte Werte – überschreiben die Defaults als Prefill
  final Map<String, String> lastValues;

  /// Einheiten je Feld (z. B. kg, reps, s)
  final Map<String, String> units;

  /// Material Icon zur Anzeige
  final IconData icon;

  const Exercise({
    required this.id,
    required this.name,
    this.description = '',
    this.trackedFields = const [],
    this.defaultValues = const {},
    this.lastValues = const {},
    this.units = const {},
    this.icon = Icons.fitness_center,
  });

  Exercise copyWith({
    int? id,
    String? name,
    String? description,
    List<String>? trackedFields,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    IconData? icon,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackedFields: trackedFields ?? List<String>.from(this.trackedFields),
      defaultValues:
          defaultValues ?? Map<String, String>.from(this.defaultValues),
      lastValues: lastValues ?? Map<String, String>.from(this.lastValues),
      units: units ?? Map<String, String>.from(this.units),
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trackedFields': jsonEncode(trackedFields),
      'defaultValues': jsonEncode(defaultValues),
      'lastValues': jsonEncode(lastValues),
      'units': jsonEncode(units),
      'icon': icon.codePoint,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int,
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      trackedFields: _safeDecodeList(map['trackedFields'] as String?),
      defaultValues: _safeDecodeMap(map['defaultValues'] as String?),
      lastValues: _safeDecodeMap(map['lastValues'] as String?),
      units: _safeDecodeMap(map['units'] as String?),
      icon: IconData(
        (map['icon'] ?? Icons.fitness_center.codePoint) as int,
        fontFamily: 'MaterialIcons',
      ),
    );
  }

  static List<String> _safeDecodeList(String? input) {
    try {
      final decoded = jsonDecode(input ?? '[]');
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return <String>[];
  }

  static Map<String, String> _safeDecodeMap(String? input) {
    try {
      final decoded = jsonDecode(input ?? '{}');
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return <String, String>{};
  }
}
