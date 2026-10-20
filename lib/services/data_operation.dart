import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Only codes and stages may be logged; exception messages can contain paths,
/// account identifiers, tokens or server response bodies.
class DataOperationFailure implements Exception {
  const DataOperationFailure(this.stage, this.code);
  final String stage;
  final String code;

  static DataOperationFailure from(String stage, Object error) {
    if (error is DataOperationFailure) return error;
    final code = switch (error) {
      FirebaseException e => e.code,
      PlatformException e => e.code,
      TimeoutException _ => 'timeout',
      _ => 'local-data-error',
    };
    return DataOperationFailure(stage, code);
  }

  @override
  String toString() => 'DataOperationFailure($stage, $code)';
}

/// One lock shared by cloud operations, resets and account deletion. Nested
/// steps in the owning async zone are allowed; unrelated operations fail fast.
class DataOperation extends ChangeNotifier {
  DataOperation();
  static final instance = DataOperation();
  final Object _zoneKey = Object();
  Object? _ownerToken;
  bool _busy = false;
  bool _blocking = false;
  bool _localMutation = false;
  final Map<Object, Future<void> Function()> _pause = {};
  final Map<Object, void Function()> _resume = {};

  bool get isBusy => _busy;
  bool get blocksInteraction => _busy && _blocking;
  bool get ownsOperation =>
      _busy && _ownerToken != null && Zone.current[_zoneKey] == _ownerToken;
  bool get databaseUnavailable => _localMutation && !ownsOperation;

  void register(
    Object owner,
    Future<void> Function() pause,
    void Function() resume,
  ) {
    _pause[owner] = pause;
    _resume[owner] = resume;
  }

  void unregister(Object owner) {
    _pause.remove(owner);
    _resume.remove(owner);
  }

  Future<T> run<T>(
    String stage,
    Future<T> Function() action, {
    bool blocking = true,
  }) async {
    if (ownsOperation) {
      final wasBlocking = _blocking;
      _blocking = _blocking || blocking;
      if (_blocking != wasBlocking) notifyListeners();
      try {
        return await action();
      } finally {
        final changed = _blocking != wasBlocking;
        _blocking = wasBlocking;
        if (changed) notifyListeners();
      }
    }
    if (_busy) {
      throw const DataOperationFailure('prepare', 'operation-in-progress');
    }
    _busy = true;
    _blocking = blocking;
    final token = _ownerToken = Object();
    notifyListeners();
    try {
      return await runZoned(action, zoneValues: {_zoneKey: token});
    } catch (error) {
      final failure = DataOperationFailure.from(stage, error);
      debugPrint('Data operation failed: ${failure.stage}/${failure.code}');
      throw failure;
    } finally {
      _busy = false;
      _blocking = false;
      _ownerToken = null;
      notifyListeners();
    }
  }

  Future<T> mutateLocal<T>(Future<T> Function() action) => run(
    'local',
    () async {
      // Finish existing native polls before closing SQLite. New readers cannot
      // reopen it until deletion/recreation and integrity validation finish.
      final resumes = List<void Function()>.of(_resume.values);
      try {
        for (final pause in List<Future<void> Function()>.of(_pause.values)) {
          await pause();
        }
        _localMutation = true;
        return await action();
      } finally {
        _localMutation = false;
        for (final resume in resumes) {
          resume();
        }
      }
    },
  );

  static Future<T> step<T>(String stage, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw DataOperationFailure.from(stage, error);
    }
  }
}
