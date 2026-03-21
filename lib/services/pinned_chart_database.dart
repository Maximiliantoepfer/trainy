import '../models/pinned_chart.dart';
import 'app_database.dart';

class PinnedChartDatabase {
  static final PinnedChartDatabase instance = PinnedChartDatabase._();
  PinnedChartDatabase._();

  Future<List<PinnedChart>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('pinned_charts', orderBy: 'sort ASC');
    return rows.map(PinnedChart.fromMap).toList();
  }

  Future<PinnedChart> add(int exerciseId, String metric) async {
    final db = await AppDatabase.instance.database;
    // Next sort index
    final maxSort = await db.rawQuery(
      'SELECT COALESCE(MAX(sort), -1) + 1 AS next FROM pinned_charts',
    );
    final nextSort = (maxSort.first['next'] as int?) ?? 0;

    final id = DateTime.now().millisecondsSinceEpoch;
    final chart = PinnedChart(
      id: id,
      exerciseId: exerciseId,
      metric: metric,
      sort: nextSort,
    );
    await db.insert('pinned_charts', chart.toMap());
    return chart;
  }

  Future<void> remove(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('pinned_charts', where: 'id = ?', whereArgs: [id]);
  }

  /// Aktualisiert die Sortierreihenfolge. [orderedIds] enthält alle IDs in der gewünschten Reihenfolge.
  Future<void> reorder(List<int> orderedIds) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'pinned_charts',
          {'sort': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }
}
