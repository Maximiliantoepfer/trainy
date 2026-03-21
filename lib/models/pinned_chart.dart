class PinnedChart {
  final int id;
  final int exerciseId;
  final String metric; // 'volume', 'speed', 'reps', 'weight', 'duration', 'distance', 'sets'
  final int sort;

  const PinnedChart({
    required this.id,
    required this.exerciseId,
    required this.metric,
    this.sort = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'exerciseId': exerciseId,
        'metric': metric,
        'sort': sort,
      };

  factory PinnedChart.fromMap(Map<String, dynamic> map) => PinnedChart(
        id: map['id'] as int,
        exerciseId: map['exerciseId'] as int,
        metric: map['metric'] as String,
        sort: (map['sort'] as int?) ?? 0,
      );
}
