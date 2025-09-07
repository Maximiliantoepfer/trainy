import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/settings_database.dart';
import '../services/local_backup_service.dart';

class CloudSyncProvider extends ChangeNotifier {
  final SettingsDatabase _settings = SettingsDatabase.instance;

  bool _syncEnabled = false;
  int _lastSyncMillis = 0;
  bool _isBusy = false;

  // Auto-Backup
  static const int _autoThresholdMillis = 24 * 60 * 60 * 1000; // 24h
  Timer? _periodicCheck;
  bool _disposed = false;

  CloudSyncProvider() {
    _init();
  }

  bool get syncEnabled => _syncEnabled;
  bool get isBusy => _isBusy;
  int get lastSyncMillis => _lastSyncMillis;

  User? get user => FirebaseAuth.instance.currentUser;
  bool get isSignedIn => user != null;

  Future<void> _init() async {
    _syncEnabled = await _settings.getSyncEnabled();
    _lastSyncMillis = await _settings.getLastSyncMillis();

    FirebaseAuth.instance.authStateChanges().listen((_) {
      _attachAutoChecks();
      notifyListeners();
    });

    _attachAutoChecks();
    notifyListeners();
  }

  Future<void> setSyncEnabled(bool value) async {
    _syncEnabled = value;
    await _settings.setSyncEnabled(value);
    _attachAutoChecks();
    if (value) {
      await maybeAutoBackup(reason: 'sync_enabled_toggle');
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _isBusy = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
        if (gUser == null) return;
        final gAuth = await gUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      await maybeAutoBackup(reason: 'login');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isBusy = true;
    notifyListeners();
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
      await FirebaseAuth.instance.signOut();
    } finally {
      _isBusy = false;
      _attachAutoChecks();
      notifyListeners();
    }
  }

  Future<void> backupNow() async {
    if (!isSignedIn) throw Exception('Nicht angemeldet');
    _isBusy = true;
    notifyListeners();
    try {
      final data = await LocalBackupService.instance.exportAll();
      final jsonStr = jsonEncode(data);

      final uid = user!.uid;
      final storage = FirebaseStorage.instance;

      final latestRef = storage.ref('users/$uid/backup/latest.json');
      await latestRef.putString(
        jsonStr,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'application/json'),
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final tsRef = storage.ref('users/$uid/backup/$ts.json');
      await tsRef.putString(
        jsonStr,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'application/json'),
      );

      _lastSyncMillis = ts;
      await _settings.setLastSyncMillis(ts);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> restoreNow() async {
    if (!isSignedIn) throw Exception('Nicht angemeldet');
    _isBusy = true;
    notifyListeners();
    try {
      final uid = user!.uid;
      final latestRef = FirebaseStorage.instance.ref(
        'users/$uid/backup/latest.json',
      );

      final bytes = await latestRef.getData(20 * 1024 * 1024);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Kein Backup gefunden.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Ungültiges Backup-Format.');
      }
      await LocalBackupService.instance.restoreAll(decoded, replace: true);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // ---------- Auto-Backup ----------
  Future<void> onAppResumed() async {
    await maybeAutoBackup(reason: 'app_resume');
  }

  Future<void> maybeAutoBackup({String reason = 'auto'}) async {
    if (!_syncEnabled || !isSignedIn || _isBusy) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSyncMillis < _autoThresholdMillis) return;

    try {
      await backupNow();
    } catch (_) {
      // bewusst still – manueller Button bleibt verfügbar
    }
  }

  void _attachAutoChecks() {
    _periodicCheck?.cancel();
    _periodicCheck = null;

    if (!_syncEnabled || !isSignedIn || _disposed) return;

    // alle 6h prüfen (sichert max. 1x/24h)
    _periodicCheck = Timer.periodic(const Duration(hours: 2), (_) {
      // ignore: discarded_futures
      maybeAutoBackup(reason: 'periodic_check');
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _periodicCheck?.cancel();
    super.dispose();
  }
}
