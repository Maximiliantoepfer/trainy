import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/data_lifecycle_coordinator.dart';
import '../services/local_backup_service.dart';
import '../services/settings_database.dart';

class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider() {
    _init();
  }

  final SettingsDatabase _settings = SettingsDatabase.instance;
  bool _syncEnabled = false;
  int _lastSyncMillis = 0;
  bool _isBusy = false;
  bool _disposed = false;
  String? _optionalCloudErrorCode;
  Timer? _periodicCheck;
  Timer? _immediateDebounce;
  StreamSubscription<User?>? _authSubscription;

  static const int _autoThresholdMillis = 24 * 60 * 60 * 1000;
  static const int _maximumBackupBytes = 96 * 1024 * 1024;

  bool get syncEnabled => _syncEnabled;
  bool get isBusy => _isBusy;
  int get lastSyncMillis => _lastSyncMillis;
  User? get user => FirebaseAuth.instance.currentUser;
  bool get isSignedIn => user != null;
  String? get optionalCloudErrorCode => _optionalCloudErrorCode;

  Future<void> _init() async {
    _syncEnabled = await _settings.getSyncEnabled();
    _lastSyncMillis = await _settings.getLastSyncMillis();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      _attachAutoChecks();
      if (!_disposed) notifyListeners();
    });
    _attachAutoChecks();
    if (!_disposed) notifyListeners();
  }

  Future<void> setSyncEnabled(bool value) async {
    _syncEnabled = value;
    await _settings.setSyncEnabled(value);
    _attachAutoChecks();
    if (value) await maybeAutoBackup(reason: 'sync_enabled_toggle');
    if (!_disposed) notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    await _withBusy(() async {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final authentication = await googleUser.authentication;
        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: authentication.accessToken,
            idToken: authentication.idToken,
          ),
        );
      }
      // Never upload immediately after login: an existing cloud backup may be
      // the only remaining copy of the user's data.
      _syncEnabled = false;
      await _settings.setSyncEnabled(false);
      _attachAutoChecks();
    });
  }

  Future<void> signOut() async {
    await _withBusy(() async {
      _syncEnabled = false;
      await _settings.setSyncEnabled(false);
      if (!kIsWeb) await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      _attachAutoChecks();
    });
  }

  Future<void> backupNow() async {
    if (!isSignedIn) throw StateError('Not signed in.');
    await _withBusy(() async {
      final archive = await LocalBackupService.instance.exportZip();
      final uid = user!.uid;
      final root = FirebaseStorage.instance.ref('users/$uid/backups/v2');
      final metadata = SettableMetadata(
        contentType: 'application/zip',
        customMetadata: const {'dataEpoch': '2', 'formatVersion': '2'},
      );
      await root.child('latest.zip').putData(archive, metadata);
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      await root.child('$timestamp.zip').putData(archive, metadata);
      _lastSyncMillis = timestamp;
      await _settings.setLastSyncMillis(timestamp);
    });
  }

  Future<void> restoreNow() async {
    if (!isSignedIn) throw StateError('Not signed in.');
    await _withBusy(() async {
      final uid = user!.uid;
      final bytes = await FirebaseStorage.instance
          .ref('users/$uid/backups/v2/latest.zip')
          .getData(_maximumBackupBytes);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('No compatible backup found.');
      }
      await LocalBackupService.instance.restoreZip(bytes);
      _syncEnabled = false;
      await _settings.setSyncEnabled(false);
    });
  }

  Future<bool> remoteBackupExists() async {
    if (!isSignedIn) return false;
    try {
      await FirebaseStorage.instance
          .ref('users/${user!.uid}/backups/v2/latest.zip')
          .getMetadata();
      _optionalCloudErrorCode = null;
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return false;
      // Cloud is optional. Missing permissions or connectivity must never
      // block onboarding or local training data.
      _optionalCloudErrorCode = error.code;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  /// Deletes all objects below users/{uid}. Local data and Auth remain intact.
  Future<void> deleteCloudData() async {
    if (!isSignedIn) throw StateError('Not signed in.');
    await _withBusy(() async {
      _syncEnabled = false;
      await _settings.setSyncEnabled(false);
      await _deleteStorageTree(
        FirebaseStorage.instance.ref('users/${user!.uid}'),
      );
      _attachAutoChecks();
    });
  }

  /// Reauthenticates, deletes remote objects and Auth, then clears all local
  /// state. The pending marker makes the local half crash-resumable.
  Future<void> deleteAccountAndAllData() async {
    final current = user;
    if (current == null) throw StateError('Not signed in.');
    var authDeleted = false;
    await DataLifecycleCoordinator.instance.markAccountDeletionPending();
    try {
      await _withBusy(() async {
        _syncEnabled = false;
        await _settings.setSyncEnabled(false);
        await _reauthenticateWithGoogle(current);
        await _deleteStorageTree(
          FirebaseStorage.instance.ref('users/${current.uid}'),
        );
        await current.delete();
        authDeleted = true;
        if (!kIsWeb) {
          try {
            await GoogleSignIn().disconnect();
          } catch (_) {
            await GoogleSignIn().signOut();
          }
        }
        await DataLifecycleCoordinator.instance.deleteAllLocalData();
      });
    } catch (_) {
      if (!authDeleted) {
        await DataLifecycleCoordinator.instance.clearAccountDeletionPending();
      }
      rethrow;
    }
  }

  Future<void> _reauthenticateWithGoogle(User current) async {
    if (kIsWeb) {
      await current.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw StateError('Reauthentication cancelled.');
    final authentication = await googleUser.authentication;
    await current.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      ),
    );
  }

  Future<void> _deleteStorageTree(Reference root) async {
    String? pageToken;
    do {
      final page = await root.list(
        ListOptions(maxResults: 100, pageToken: pageToken),
      );
      for (final item in page.items) {
        await item.delete();
      }
      for (final prefix in page.prefixes) {
        await _deleteStorageTree(prefix);
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null);
  }

  void scheduleBackupSoon({Duration delay = const Duration(seconds: 2)}) {
    if (!_syncEnabled || !isSignedIn || _disposed) return;
    _immediateDebounce?.cancel();
    _immediateDebounce = Timer(delay, () async {
      if (_disposed) return;
      try {
        await backupNow();
      } catch (_) {
        // Manual backup remains available with visible error reporting.
      }
    });
  }

  Future<void> onAppResumed() => maybeAutoBackup(reason: 'app_resume');

  Future<void> maybeAutoBackup({String reason = 'auto'}) async {
    if (!_syncEnabled || !isSignedIn || _isBusy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSyncMillis < _autoThresholdMillis) return;
    try {
      await backupNow();
    } catch (_) {
      // Auto backup must never block app startup/resume.
    }
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    if (_isBusy) throw StateError('Another cloud operation is in progress.');
    _isBusy = true;
    if (!_disposed) notifyListeners();
    try {
      await action();
    } finally {
      _isBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _attachAutoChecks() {
    _periodicCheck?.cancel();
    _periodicCheck = null;
    if (!_syncEnabled || !isSignedIn || _disposed) return;
    _periodicCheck = Timer.periodic(const Duration(hours: 2), (_) {
      maybeAutoBackup(reason: 'periodic_check');
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _periodicCheck?.cancel();
    _immediateDebounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
