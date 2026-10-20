import 'package:flutter/foundation.dart';

import '../services/data_lifecycle_coordinator.dart';
import '../services/data_operation.dart';

/// Recreates all database-backed providers after a destructive lifecycle
/// operation. Locale and theme providers live above this boundary.
class DataLifecycleProvider extends ChangeNotifier {
  DataLifecycleProvider({
    DataLifecycleCoordinator? coordinator,
    DataStartupResult initialResult = const DataStartupResult.ready(),
  }) : _coordinator = coordinator ?? DataLifecycleCoordinator.instance,
       _startupResult = initialResult {
    DataOperation.instance.addListener(notifyListeners);
  }

  final DataLifecycleCoordinator _coordinator;
  int _generation = 0;
  bool _isBusy = false;
  DataStartupResult _startupResult;

  int get generation => _generation;
  bool get isBusy => _isBusy || DataOperation.instance.isBusy;
  DataStartupResult get startupResult => _startupResult;
  bool get needsRecovery =>
      _startupResult.state == DataStartupState.needsRecovery;

  Future<void> resetLocalTrainingData() async {
    await _run(() async {
      await _coordinator.resetLocalTrainingData();
      _startupResult = const DataStartupResult.ready();
    });
  }

  Future<void> deleteAllLocalData() async {
    await _run(() async {
      await _coordinator.deleteAllLocalData();
      _startupResult = const DataStartupResult.ready();
    });
  }

  Future<void> retryStartup() async {
    await _run(() async {
      _startupResult = await _coordinator.retryRecovery();
      if (_startupResult.isReady) _generation++;
    }, incrementGeneration: false);
  }

  Future<String> exportRecoveryCopy() => _coordinator.exportRecoveryCopy();

  void notifyDataWasReplaced() {
    _generation++;
    notifyListeners();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool incrementGeneration = true,
  }) async {
    if (_isBusy) {
      throw const DataOperationFailure('prepare', 'operation-in-progress');
    }
    _isBusy = true;
    notifyListeners();
    try {
      await action();
      if (incrementGeneration) _generation++;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    DataOperation.instance.removeListener(notifyListeners);
    super.dispose();
  }
}
