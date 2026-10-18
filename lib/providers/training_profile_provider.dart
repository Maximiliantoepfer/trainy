import 'package:flutter/foundation.dart';

import '../models/training_profile.dart';
import '../repositories/training_profile_repository.dart';

/// Shared local profile state. Screens never keep independent profile caches.
class TrainingProfileProvider extends ChangeNotifier
    implements TrainingProfilePreferencesStore {
  TrainingProfileProvider({TrainingProfilePreferencesStore? store})
    : _store = store ?? TrainingProfileRepository();

  final TrainingProfilePreferencesStore _store;
  List<TrainingProfileRecord> _profiles = const [];
  List<TrainingProfileRecord> get activeProfiles =>
      List.unmodifiable(_profiles.where((p) => !p.isArchived));
  String? preferredProfileId;
  ProfileSetupState onboardingState = ProfileSetupState.required;
  bool loading = false;
  Object? error;
  int _revision = 0;
  bool _disposed = false;

  Future<void> reload() async {
    final revision = ++_revision;
    loading = true;
    error = null;
    _notify();
    try {
      final profiles = await _store.profiles(includeArchived: true);
      final preferred = await _store.selectedProfileId();
      final state = await _store.setupState();
      if (_disposed || revision != _revision) return;
      _profiles = List.unmodifiable(profiles);
      preferredProfileId =
          profiles.any((p) => p.id == preferred && !p.isArchived)
              ? preferred
              : null;
      onboardingState = state;
    } catch (e) {
      if (!_disposed && revision == _revision) error = e;
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<List<TrainingProfileRecord>> profiles({
    bool includeArchived = false,
  }) => _store.profiles(includeArchived: includeArchived);
  @override
  Future<String?> selectedProfileId() => _store.selectedProfileId();
  @override
  Future<ProfileSetupState> setupState() => _store.setupState();
  @override
  Future<void> save(TrainingProfileRecord profile) async {
    await _store.save(profile);
    await reload();
  }

  @override
  Future<void> select(String? profileId) async {
    await _store.select(profileId);
    await reload();
  }

  @override
  Future<void> archive(String profileId) async {
    await _store.archive(profileId);
    await reload();
  }

  @override
  Future<void> dismissSetupOffer() async {
    await _store.dismissSetupOffer();
    await reload();
  }

  @override
  Future<void> completeSetup({
    required List<TrainingProfileRecord> profiles,
    required String preferredProfileId,
  }) async {
    await _store.completeSetup(
      profiles: profiles,
      preferredProfileId: preferredProfileId,
    );
    await reload();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
