import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/data_lifecycle_coordinator.dart';
import '../services/data_operation.dart';
import '../services/account_deletion.dart';
import '../services/local_backup_service.dart';
import '../services/settings_database.dart';

class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider() {
    DataOperation.instance.addListener(_operationChanged);
    DataOperation.instance.register(this, suspendAutomaticBackup, () {});
    _init();
  }

  final SettingsDatabase _settings = SettingsDatabase.instance;
  bool _syncEnabled = false;
  int _lastSyncMillis = 0;
  bool _isBusy = false;
  bool _disposed = false;
  bool pendingLocalDeletion = false;
  String? _optionalCloudErrorCode;
  Timer? _periodicCheck;
  Timer? _immediateDebounce;
  StreamSubscription<User?>? _authSubscription;

  static const int _autoThresholdMillis = 24 * 60 * 60 * 1000;

  bool get syncEnabled => _syncEnabled;
  bool get isBusy => _isBusy || DataOperation.instance.isBusy;
  int get lastSyncMillis => _lastSyncMillis;
  User? get user => FirebaseAuth.instance.currentUser;
  bool get isSignedIn => user != null;
  String? get optionalCloudErrorCode => _optionalCloudErrorCode;

  void _operationChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> suspendAutomaticBackup() async {
    _syncEnabled = false;
    _periodicCheck?.cancel();
    _immediateDebounce?.cancel();
    await _settings.setSyncEnabled(false);
  }

  Future<void> _init() async {
    pendingLocalDeletion =
        await DataLifecycleCoordinator.instance.hasConfirmedLocalDeletion();
    final enabled = await _settings.getSyncEnabled();
    _syncEnabled = !DataOperation.instance.isBusy && enabled;
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
      final archive = await LocalBackupService.instance.exportZipFile();
      final uid = user!.uid;
      final root = FirebaseStorage.instance.ref('users/$uid/backups/v2');
      final metadata = SettableMetadata(
        contentType: 'application/zip',
        customMetadata: const {'dataEpoch': '2', 'formatVersion': '3'},
      );
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      try {
        await root.child('$timestamp.zip').putFile(archive, metadata);
        await root.child('latest.zip').putFile(archive, metadata);
      } finally {
        await archive.parent.delete(recursive: true);
      }
      _lastSyncMillis = timestamp;
      await _settings.setLastSyncMillis(timestamp);
    }, blocking: false);
  }

  Future<void> restoreNow() async {
    if (!isSignedIn) throw StateError('Not signed in.');
    await _withBusy(() async {
      final uid = user!.uid;
      final reference = FirebaseStorage.instance.ref(
        'users/$uid/backups/v2/latest.zip',
      );
      final metadata = await reference.getMetadata();
      if ((metadata.size ?? 0) >
          LocalBackupService.maximumStreamingArchiveBytes) {
        throw StateError('Backup exceeds size limit');
      }
      final directory = await (await getTemporaryDirectory()).createTemp(
        'trainy-cloud-',
      );
      final file = File('${directory.path}/backup.zip');
      try {
        await reference.writeToFile(file);
        await DataOperation.instance.mutateLocal(
          () => LocalBackupService.instance.restoreZipFile(file),
        );
      } finally {
        await directory.delete(recursive: true);
      }
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
    final current = user;
    if (current == null) {
      throw const DataOperationFailure('cloud-delete', 'unauthenticated');
    }
    await _withBusy(() async {
      await suspendAutomaticBackup();
      await DataOperation.step(
        'cloud-delete',
        () => _deleteStorageTree(
          FirebaseStorage.instance.ref('users/${current.uid}'),
        ),
      );
    });
  }

  /// Reauthenticates, deletes remote objects and Auth, then clears all local
  /// state. The pending marker makes the local half crash-resumable.
  Future<void> deleteAccountAndAllData() async {
    final current = user;
    if (current == null &&
        await DataLifecycleCoordinator.instance.hasConfirmedLocalDeletion()) {
      await _withBusy(DataLifecycleCoordinator.instance.deleteAllLocalData);
      return;
    }
    if (current == null) {
      throw const DataOperationFailure('account-delete', 'unauthenticated');
    }
    final coordinator = DataLifecycleCoordinator.instance;
    await _withBusy(() async {
      await AccountDeletion.run(
        reauthenticate: () => _reauthenticateWithGoogle(current),
        stopBackup: suspendAutomaticBackup,
        journal:
            (phase) => coordinator.markAccountDeletionPending(
              uid: current.uid,
              phase: phase,
            ),
        deleteCloud:
            () => _deleteStorageTree(
              FirebaseStorage.instance.ref('users/${current.uid}'),
            ),
        deleteAuth: current.delete,
        deleteLocal: coordinator.deleteAllLocalData,
      );
      if (!kIsWeb) {
        try {
          await GoogleSignIn().disconnect();
        } catch (_) {
          // Auth is already deleted. Optional Google cleanup cannot prevent
          // the confirmed local deletion or change its success result.
        }
      }
    });
  }

  Future<void> _reauthenticateWithGoogle(User current) async {
    if (kIsWeb) {
      await current.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw const DataOperationFailure('reauthenticate', 'cancelled');
    }
    if (googleUser.email.toLowerCase() != current.email?.toLowerCase()) {
      throw const DataOperationFailure('reauthenticate', 'user-mismatch');
    }
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
        try {
          await item.delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
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
      if (_disposed || !_syncEnabled || isBusy) return;
      try {
        await backupNow();
      } catch (_) {
        // Manual backup remains available with visible error reporting.
      }
    });
  }

  Future<void> onAppResumed() => maybeAutoBackup(reason: 'app_resume');

  Future<void> maybeAutoBackup({String reason = 'auto'}) async {
    if (!_syncEnabled || !isSignedIn || isBusy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSyncMillis < _autoThresholdMillis) return;
    try {
      await backupNow();
    } catch (_) {
      // Auto backup must never block app startup/resume.
    }
  }

  Future<void> _withBusy(
    Future<void> Function() action, {
    bool blocking = true,
  }) async {
    if (_isBusy) throw StateError('Another cloud operation is in progress.');
    _isBusy = true;
    if (!_disposed) notifyListeners();
    try {
      await DataOperation.instance.run('cloud', action, blocking: blocking);
    } finally {
      _isBusy = false;
      try {
        pendingLocalDeletion =
            await DataLifecycleCoordinator.instance.hasConfirmedLocalDeletion();
      } catch (_) {
        // Do not replace the original operation error with a preference read
        // failure. The persisted recovery journal will be retried on startup.
      }
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
    DataOperation.instance.removeListener(_operationChanged);
    DataOperation.instance.unregister(this);
    _disposed = true;
    _periodicCheck?.cancel();
    _immediateDebounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
