import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/icon_data.dart';

class Exercise {
  final int id;
  final String name;
  final String description;
  final IconData icon;
  final List<String> trackedFields;
  final Map<String, String> defaultValues;
  final Map<String, String> units;

  Exercise({
    required this.id,
    required this.name,
    required this.trackedFields,
    required this.defaultValues,
    required this.units,
    required this.icon,
    this.description = '',
  });

  @override
  String toString() {
    return 'Exercise{id: $id, name: $name, description: $description, trackedFields: $trackedFields, defaultValues: $defaultValues, units: $units}';
  }

  // Datenbank-konvertierung
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trackedFields': trackedFields.join(','),
      'defaultValues': defaultValues.toString(),
      'units': units.toString(),
      'icon': icon.codePoint, // WICHTIG!
    };
  }

  static Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      trackedFields: (map['trackedFields'] as String).split(','),
      defaultValues: _parseMap(map['defaultValues']),
      units: _parseMap(map['units']),
      icon: IconData(
        map['icon'] ?? Icons.fitness_center.codePoint,
        fontFamily: 'MaterialIcons',
      ),
    );
  }

  static Map<String, String> _parseMap(String input) {
    input = input.replaceAll(RegExp(r'^\{|\}$'), '');
    if (input.trim().isEmpty) return {};
    return Map.fromEntries(
      input.split(', ').map((e) {
        final parts = e.split(': ');
        return MapEntry(parts[0], parts[1]);
      }),
    );
  }
}
