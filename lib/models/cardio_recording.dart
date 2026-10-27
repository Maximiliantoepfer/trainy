import 'dart:convert';

/// One activity can have several independent measurements. Never average them.
class CardioRecording {
  const CardioRecording({
    required this.id,
    required this.source,
    required this.runtime,
    this.externalId,
    this.routeState,
  });
  final String id, source;
  final String? externalId, routeState;
  final Map<String, dynamic> runtime;
  bool get phone => id == 'phone';
  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'externalId': externalId,
    'runtime': runtime,
    'routeState': routeState,
  };
  factory CardioRecording.fromJson(Map<String, dynamic> j) => CardioRecording(
    id: j['id'] as String,
    source: j['source'] as String,
    externalId: j['externalId'] as String?,
    routeState: j['routeState'] as String?,
    runtime: Map<String, dynamic>.from(j['runtime'] as Map),
  );

  static String healthId(Map record) =>
      '${record['provider']}:${record['sourceId']}:${record['externalId']}';

  static List<CardioRecording> all(
    Map<String, dynamic> snapshot,
    Map<String, dynamic> original,
  ) {
    final removed = List<String>.from(
      snapshot['removedRecordings'] as List? ?? [],
    );
    final stored =
        (snapshot['recordings'] as List? ?? [])
            .map(
              (e) =>
                  CardioRecording.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .where((e) => !removed.contains(e.id))
            .toList();
    final externalOnly =
        original['source'] != null ||
        (snapshot['health'] != null &&
            snapshot['workout'] == null &&
            snapshot['steps'] == null);
    if (!externalOnly && !removed.contains('phone')) {
      stored.insert(
        0,
        CardioRecording(id: 'phone', source: 'phone', runtime: original),
      );
    } else if (stored.isEmpty && externalOnly && snapshot['health'] is Map) {
      final h = snapshot['health'] as Map;
      final id = healthId(h);
      if (!removed.contains(id)) {
        stored.add(
          CardioRecording(
            id: id,
            source: h['sourceId'] as String? ?? '${original['source']}',
            externalId: h['externalId'] as String?,
            runtime: original,
          ),
        );
      }
    }
    return stored;
  }

  static CardioRecording? preferred(
    Map<String, dynamic> snapshot,
    Map<String, dynamic> original,
  ) {
    final recordings = all(snapshot, original);
    return recordings
            .where((r) => r.id == snapshot['preferredRecordingId'])
            .firstOrNull ??
        recordings.where((r) => !r.phone).firstOrNull ??
        recordings.firstOrNull;
  }

  static Map<String, dynamic> display(Map<String, Object?> row) {
    final snapshot =
        jsonDecode(row['snapshot_json'] as String? ?? '{}')
            as Map<String, dynamic>;
    final original =
        jsonDecode(row['runtime_json'] as String? ?? '{}')
            as Map<String, dynamic>;
    return preferred(snapshot, original)?.runtime ?? original;
  }
}
