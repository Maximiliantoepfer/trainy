import 'package:flutter/foundation.dart';

@immutable
class TrainingProfileRecord {
  const TrainingProfileRecord({
    required this.id,
    required this.name,
    required this.equipmentCodes,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.isArchived = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final Set<String> equipmentCodes;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  TrainingProfileRecord copyWith({
    String? name,
    Set<String>? equipmentCodes,
    bool? isArchived,
    int? sortOrder,
    DateTime? updatedAtUtc,
  }) => TrainingProfileRecord(
    id: id,
    name: name ?? this.name,
    equipmentCodes: equipmentCodes ?? this.equipmentCodes,
    isArchived: isArchived ?? this.isArchived,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
}

abstract interface class TrainingProfileStore {
  Future<List<TrainingProfileRecord>> profiles({bool includeArchived = false});
  Future<String?> selectedProfileId();
  Future<void> save(TrainingProfileRecord profile);
  Future<void> select(String? profileId);
  Future<void> archive(String profileId);
}

enum ProfileSetupState { required, offer, dismissed, completed }

/// Optional preference contract keeps small injected stores usable in forms.
abstract interface class TrainingProfilePreferencesStore
    implements TrainingProfileStore {
  Future<ProfileSetupState> setupState();
  Future<void> dismissSetupOffer();
  Future<void> completeSetup({
    required List<TrainingProfileRecord> profiles,
    required String preferredProfileId,
  });
}
