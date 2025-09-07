// lib/providers/cloud_sync_provider.dart
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
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> setSyncEnabled(bool value) async {
    _syncEnabled = value;
    await _settings.setSyncEnabled(value);
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
        if (gUser == null) {
          return; // user aborted
        }
        final gAuth = await gUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
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
      final storage = FirebaseStorage.instance;
      final latestRef = storage.ref('users/$uid/backup/latest.json');

      final bytes = await latestRef.getData(20 * 1024 * 1024); // max 20MB
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
}
