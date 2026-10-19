import 'package:flutter/foundation.dart';
import '../models/training_program.dart';
import '../repositories/training_program_repository.dart';

class TrainingProgramProvider extends ChangeNotifier {
  TrainingProgramProvider({TrainingProgramRepository? repository})
    : repository = repository ?? TrainingProgramRepository();
  final TrainingProgramRepository repository;
  List<TrainingProgram> plans = [];
  TrainingProgram? active;
  bool loaded = false;
  Object? error;
  Map<String, dynamic>? pendingDraft;
  int _generation = 0;
  bool _disposed = false;
  Future<void> load() async {
    final generation = ++_generation;
    try {
      await repository.initialize();
      final next = await repository.plans(), id = await repository.activeId();
      final draft = await repository.draft('plan:new');
      if (_disposed || generation != _generation) return;
      plans = next;
      active = next.where((p) => p.id == id).firstOrNull;
      pendingDraft = draft;
      error = null;
      loaded = true;
    } catch (e) {
      if (!_disposed && generation == _generation) error = e;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> activate(String id) async {
    await repository.activate(id);
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
