import 'package:flutter/foundation.dart';

import '../services/data_lifecycle_coordinator.dart';

/// Recreates all database-backed providers after a destructive lifecycle
/// operation. Locale and theme providers live above this boundary.
class DataLifecycleProvider extends ChangeNotifier {
  DataLifecycleProvider({DataLifecycleCoordinator? coordinator})
    : _coordinator = coordinator ?? DataLifecycleCoordinator.instance;

  final DataLifecycleCoordinator _coordinator;
  int _generation = 0;
  bool _isBusy = false;

  int get generation => _generation;
  bool get isBusy => _isBusy;

  Future<void> resetLocalTrainingData() async {
    await _run(_coordinator.resetLocalTrainingData);
  }

  Future<void> deleteAllLocalData() async {
    await _run(_coordinator.deleteAllLocalData);
  }

  void notifyDataWasReplaced() {
    _generation++;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await action();
      _generation++;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
