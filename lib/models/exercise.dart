import 'dart:convert';

class Exercise {
  final int id;
  final String name;
  final String description;

  /// keys: 'sets', 'reps', 'weight', 'duration'
  final List<String> trackedFields;

  final Map<String, String> defaultValues;
  final Map<String, String> lastValues;
  final Map<String, String> units;
  final int? icon;

  const Exercise({
    required this.id,
    required this.name,
    this.description = '',
    this.trackedFields = const ['sets', 'reps', 'weight'],
    this.defaultValues = const {},
    this.lastValues = const {},
    this.units = const {},
    this.icon,
  });

  bool get trackSets => trackedFields.contains('sets');
  bool get trackReps => trackedFields.contains('reps');
  bool get trackWeight => trackedFields.contains('weight');
  bool get trackDuration => trackedFields.contains('duration');

  Exercise copyWith({
    int? id,
    String? name,
    String? description,
    List<String>? trackedFields,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
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
      'icon': icon,
    };
  }

  factory Exercise.fromMap(Map<String, Object?> map) {
    return Exercise(
      id: (map['id'] as num).toInt(),
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      trackedFields: _safeDecodeList(map['trackedFields'] as String?),
      defaultValues: _safeDecodeMap(map['defaultValues'] as String?),
      lastValues: _safeDecodeMap(map['lastValues'] as String?),
      units: _safeDecodeMap(map['units'] as String?),
      icon: map['icon'] != null ? (map['icon'] as num).toInt() : null,
    );
  }

  static List<String> _safeDecodeList(String? input) {
    try {
      final decoded = jsonDecode(input ?? '[]');
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
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
