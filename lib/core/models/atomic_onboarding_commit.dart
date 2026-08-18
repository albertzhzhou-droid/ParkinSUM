import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'intake.dart';
import 'user_profile.dart';

const int atomicOnboardingCommitSchemaVersion = 1;
const String atomicOnboardingCommitStageCommitted = 'committed';

/// Immutable first-day user state committed as one backend operation.
///
/// The operation id is a stable digest of the complete payload. Retrying the
/// same request after a timeout or process restart is therefore idempotent.
class AtomicOnboardingCommit {
  AtomicOnboardingCommit._({
    required this.operationId,
    required this.profile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
  }) : activeDrugIds = List<String>.unmodifiable(activeDrugIds),
       intakes = List<Intake>.unmodifiable(intakes);

  final String operationId;
  final UserProfile profile;
  final List<String> activeDrugIds;
  final List<Intake> intakes;

  factory AtomicOnboardingCommit.create({
    required UserProfile profile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
  }) {
    if (profile.patientId.trim().isEmpty) {
      throw ArgumentError.value(
        profile.patientId,
        'profile.patientId',
        'An account scope is required.',
      );
    }
    final normalizedDrugIds = List<String>.unmodifiable(activeDrugIds);
    if (normalizedDrugIds.any((id) => id.trim().isEmpty) ||
        normalizedDrugIds.toSet().length != normalizedDrugIds.length) {
      throw ArgumentError.value(
        activeDrugIds,
        'activeDrugIds',
        'Drug ids must be non-empty and unique.',
      );
    }
    final normalizedIntakes = List<Intake>.unmodifiable(intakes);
    if (normalizedIntakes.any(
          (intake) => intake.id.trim().isEmpty || intake.drugId.trim().isEmpty,
        ) ||
        normalizedIntakes.map((intake) => intake.id).toSet().length !=
            normalizedIntakes.length) {
      throw ArgumentError.value(
        intakes,
        'intakes',
        'Intake ids must be non-empty and unique.',
      );
    }

    final canonicalPayload = <String, Object?>{
      'schemaVersion': atomicOnboardingCommitSchemaVersion,
      'profile': profile.toJson(),
      'activeDrugIds': normalizedDrugIds,
      'intakes': normalizedIntakes
          .map((intake) => intake.toJson())
          .toList(growable: false),
    };
    final digest = sha256
        .convert(utf8.encode(jsonEncode(canonicalPayload)))
        .toString();
    return AtomicOnboardingCommit._(
      operationId: 'onboarding_v1_$digest',
      profile: profile,
      activeDrugIds: normalizedDrugIds,
      intakes: normalizedIntakes,
    );
  }

  Map<String, Object?> toCommittedJson() => <String, Object?>{
    'schemaVersion': atomicOnboardingCommitSchemaVersion,
    'operationId': operationId,
    'stage': atomicOnboardingCommitStageCommitted,
    'onboarded': true,
    'profile': profile.toJson(),
    'activeDrugIds': activeDrugIds,
    'intakes': intakes.map((intake) => intake.toJson()).toList(growable: false),
  };

  factory AtomicOnboardingCommit.fromCommittedJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != atomicOnboardingCommitSchemaVersion ||
        json['stage'] != atomicOnboardingCommitStageCommitted ||
        json['onboarded'] != true ||
        json['operationId'] is! String ||
        json['profile'] is! Map ||
        json['activeDrugIds'] is! List ||
        json['intakes'] is! List) {
      throw const FormatException('Onboarding commit envelope is invalid.');
    }
    final profile = UserProfile.fromJson(
      Map<String, dynamic>.from(json['profile'] as Map),
    );
    final activeDrugIds = (json['activeDrugIds'] as List<dynamic>)
        .map((value) => value.toString())
        .toList(growable: false);
    final intakes = (json['intakes'] as List<dynamic>)
        .map(
          (value) => Intake.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
    final reconstructed = AtomicOnboardingCommit.create(
      profile: profile,
      activeDrugIds: activeDrugIds,
      intakes: intakes,
    );
    if (reconstructed.operationId != json['operationId']) {
      throw const FormatException('Onboarding commit digest does not match.');
    }
    return reconstructed;
  }
}
