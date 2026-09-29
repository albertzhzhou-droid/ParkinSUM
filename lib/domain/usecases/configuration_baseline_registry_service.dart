import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../entities/algorithm_configuration_change_impact.dart';
import '../entities/configuration_baseline_registry.dart';

final class ConfigurationBaselineTransitionResult {
  const ConfigurationBaselineTransitionResult({
    required this.accepted,
    required this.reason,
    required this.state,
    required this.receipt,
  });

  final bool accepted;
  final String reason;
  final ConfigurationBaselineRegistryState state;
  final ConfigurationBaselinePromotionReceipt receipt;
}

/// One reviewer identity and authority role bound to one exact Ed25519 key.
///
/// Callers must obtain these bindings from a separately governed trust policy;
/// receipt-supplied role labels never grant authority by themselves.
final class ConfigurationBaselineTrustedReviewerKey {
  const ConfigurationBaselineTrustedReviewerKey({
    required this.reviewerId,
    required this.authorityRole,
    required this.keyId,
    required this.publicKey,
  });

  final String reviewerId;
  final String authorityRole;
  final String keyId;
  final SimplePublicKey publicKey;
}

/// Append-only, compare-and-swap-friendly configuration baseline transition
/// engine. Storage adapters must persist the returned [state] only when their
/// expected revision still matches; rejected attempts are events too.
final class ConfigurationBaselineRegistryService {
  static const requiredPromotionRoles = <String>{
    'software_quality',
    'code_verification',
    'calculation_verification',
    'scientific_validation',
    'human_factors',
    'transportability',
    'context_of_use',
  };

  const ConfigurationBaselineRegistryService();

  ConfigurationBaselineRegistryState initialState({
    required String activeConfigurationSha256,
    required String environment,
    required String targetPopulationScope,
    required DateTime recordedAtUtc,
  }) {
    final event = ConfigurationBaselineRegistryEvent(
      sequence: 1,
      kind: ConfigurationBaselineEventKind.activated,
      configurationSha256: activeConfigurationSha256,
      activeConfigurationBeforeSha256: activeConfigurationSha256,
      activeConfigurationAfterSha256: activeConfigurationSha256,
      receiptSha256: null,
      previousEventSha256: null,
      recordedAtUtc: recordedAtUtc.toUtc(),
      reason: 'manufactured_change_control_baseline',
      environment: environment,
      targetPopulationScope: targetPopulationScope,
    );
    return ConfigurationBaselineRegistryState(
      revision: 1,
      activeConfigurationSha256: activeConfigurationSha256,
      environment: environment,
      targetPopulationScope: targetPopulationScope,
      events: [event],
    );
  }

  Future<ConfigurationBaselineTransitionResult> apply({
    required ConfigurationBaselineRegistryState state,
    required int expectedRevision,
    required ConfigurationBaselinePromotionReceipt receipt,
    required Map<String, ConfigurationBaselineTrustedReviewerKey>
    trustedReviewerKeys,
    required DateTime nowUtc,
  }) async {
    final now = nowUtc.toUtc();
    final previousRecordedAtUtc = state.events.last.recordedAtUtc;
    final clockRegressed = now.isBefore(previousRecordedAtUtc);
    String? rejection;
    if (expectedRevision != state.revision) {
      rejection = 'atomic_revision_conflict';
    } else if (state.usedReceiptSha256s.contains(receipt.receiptSha256)) {
      rejection = 'receipt_replay_rejected';
    } else if (receipt.expectedActiveConfigurationSha256 !=
        state.activeConfigurationSha256) {
      rejection = 'expected_active_identity_mismatch';
    } else if (receipt.environment != state.environment ||
        receipt.targetPopulationScope != state.targetPopulationScope) {
      rejection = 'approval_scope_mismatch';
    } else if (clockRegressed) {
      rejection = 'registry_clock_regression';
    } else if (now.isBefore(receipt.issuedAtUtc) ||
        !now.isBefore(receipt.expiresAtUtc)) {
      rejection = 'receipt_time_invalid';
    } else if (receipt.issuedAtUtc.isBefore(previousRecordedAtUtc)) {
      rejection = 'receipt_predates_registry_head';
    } else if (!_obligationsComplete(receipt)) {
      rejection = 'verification_obligations_incomplete';
    } else if (!_reviewerRolesComplete(receipt)) {
      rejection = 'independent_reviewer_roles_incomplete';
    } else if (!_trustedReviewerBindingsValid(receipt, trustedReviewerKeys)) {
      rejection = 'reviewer_trust_binding_invalid';
    } else if (!await _signaturesVerified(receipt, trustedReviewerKeys)) {
      rejection = 'reviewer_signature_invalid';
    } else if (receipt.transitionKind ==
            ConfigurationBaselineTransitionKind.promote &&
        receipt.candidateConfigurationSha256 ==
            state.activeConfigurationSha256 &&
        !state.activeConfigurationRevoked) {
      rejection = 'candidate_already_active';
    } else if (receipt.transitionKind ==
            ConfigurationBaselineTransitionKind.revoke &&
        receipt.candidateConfigurationSha256 !=
            state.activeConfigurationSha256) {
      rejection = 'revocation_target_not_active';
    } else if (receipt.transitionKind ==
            ConfigurationBaselineTransitionKind.rollback &&
        (!state.previouslyActiveConfigurationSha256s.contains(
              receipt.rollbackTargetConfigurationSha256,
            ) ||
            receipt.rollbackTargetConfigurationSha256 ==
                state.activeConfigurationSha256)) {
      rejection = 'rollback_target_not_in_verified_history';
    }

    final accepted = rejection == null;
    final nextActive = accepted
        ? switch (receipt.transitionKind) {
            ConfigurationBaselineTransitionKind.promote =>
              receipt.candidateConfigurationSha256,
            ConfigurationBaselineTransitionKind.rollback =>
              receipt.rollbackTargetConfigurationSha256!,
            ConfigurationBaselineTransitionKind.revoke =>
              state.activeConfigurationSha256,
          }
        : state.activeConfigurationSha256;
    final event = ConfigurationBaselineRegistryEvent(
      sequence: state.events.length + 1,
      kind: _eventKind(receipt.transitionKind, accepted),
      configurationSha256: receipt.candidateConfigurationSha256,
      activeConfigurationBeforeSha256: state.activeConfigurationSha256,
      activeConfigurationAfterSha256: nextActive,
      receiptSha256: receipt.receiptSha256,
      previousEventSha256: state.events.last.eventSha256,
      recordedAtUtc: clockRegressed ? previousRecordedAtUtc : now,
      reason: rejection ?? '${receipt.transitionKind.name}_accepted',
      environment: state.environment,
      targetPopulationScope: state.targetPopulationScope,
    );
    final next = ConfigurationBaselineRegistryState(
      revision: state.revision + 1,
      activeConfigurationSha256: nextActive,
      environment: state.environment,
      targetPopulationScope: state.targetPopulationScope,
      events: [...state.events, event],
    );
    return ConfigurationBaselineTransitionResult(
      accepted: accepted,
      reason: event.reason,
      state: next,
      receipt: receipt,
    );
  }

  Future<ConfigurationBaselineTransitionResult> buildCurrentFixture({
    required AlgorithmConfigurationChangeImpactPackage impact,
    required String contextOfUseRecordSha256,
  }) {
    final anchor = DateTime.utc(2026, 8, 27, 12);
    final state = initialState(
      activeConfigurationSha256: impact.previousConfigurationSha256,
      environment: 'local-research',
      targetPopulationScope: 'synthetic-observatory-only',
      recordedAtUtc: anchor,
    );
    final obligations = {
      for (final obligation in impact.obligations)
        obligation.kind.name: ConfigurationBaselineObligationStatus.unresolved,
    };
    final receipt = ConfigurationBaselinePromotionReceipt(
      receiptId: 'synthetic-current-candidate-v1',
      transitionKind: ConfigurationBaselineTransitionKind.promote,
      proposerId: 'repository-maintainers',
      environment: state.environment,
      targetPopulationScope: state.targetPopulationScope,
      expectedActiveConfigurationSha256: state.activeConfigurationSha256,
      candidateConfigurationSha256: impact.currentConfigurationSha256,
      rollbackTargetConfigurationSha256: null,
      sourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
      buildArtifactSha256: impact.currentConfigurationSha256,
      changeImpactPackageSha256: impact.packageSha256,
      replayArtifactSha256: _sha256Of(
        impact.replayDeltas.map((delta) => delta.toJson()).toList(),
      ),
      contextOfUseRecordSha256: contextOfUseRecordSha256,
      obligationMatrixSha256: _sha256Of(
        impact.obligations.map((obligation) => obligation.toJson()).toList(),
      ),
      obligations: obligations,
      issuedAtUtc: anchor.add(const Duration(minutes: 1)),
      expiresAtUtc: anchor.add(const Duration(days: 7)),
      signatures: const [],
      boundary:
          'Synthetic local change-control candidate only. Unresolved evidence '
          'and missing independent signatures block activation.',
    );
    return apply(
      state: state,
      expectedRevision: state.revision,
      receipt: receipt,
      trustedReviewerKeys: const {},
      nowUtc: anchor.add(const Duration(minutes: 2)),
    );
  }

  static bool _obligationsComplete(
    ConfigurationBaselinePromotionReceipt receipt,
  ) =>
      receipt.obligations.isNotEmpty &&
      receipt.obligations.values.every(
        (status) =>
            status == ConfigurationBaselineObligationStatus.satisfied ||
            status == ConfigurationBaselineObligationStatus.notApplicable,
      );

  static bool _reviewerRolesComplete(
    ConfigurationBaselinePromotionReceipt receipt,
  ) => receipt.signatures
      .map((signature) => signature.authorityRole)
      .toSet()
      .containsAll(requiredPromotionRoles);

  static Future<bool> _signaturesVerified(
    ConfigurationBaselinePromotionReceipt receipt,
    Map<String, ConfigurationBaselineTrustedReviewerKey> trustedReviewerKeys,
  ) async {
    final algorithm = Ed25519();
    final message = Uint8List.fromList(utf8.encode(receipt.signingPayloadJson));
    for (final reviewer in receipt.signatures) {
      final binding = trustedReviewerKeys[reviewer.keyId];
      if (binding == null) return false;
      List<int> signatureBytes;
      try {
        signatureBytes = base64Decode(reviewer.signatureBase64);
      } on FormatException {
        return false;
      }
      bool verified;
      try {
        verified = await algorithm.verify(
          message,
          signature: Signature(signatureBytes, publicKey: binding.publicKey),
        );
      } on Object {
        return false;
      }
      if (!verified) return false;
    }
    return true;
  }

  static bool _trustedReviewerBindingsValid(
    ConfigurationBaselinePromotionReceipt receipt,
    Map<String, ConfigurationBaselineTrustedReviewerKey> trustedReviewerKeys,
  ) {
    final publicKeyFingerprints = <String>{};
    for (final reviewer in receipt.signatures) {
      final binding = trustedReviewerKeys[reviewer.keyId];
      if (binding == null ||
          binding.keyId != reviewer.keyId ||
          binding.reviewerId != reviewer.reviewerId ||
          binding.authorityRole != reviewer.authorityRole ||
          binding.publicKey.type != KeyPairType.ed25519 ||
          binding.publicKey.bytes.length != 32 ||
          !publicKeyFingerprints.add(base64Encode(binding.publicKey.bytes))) {
        return false;
      }
    }
    return true;
  }

  static ConfigurationBaselineEventKind _eventKind(
    ConfigurationBaselineTransitionKind kind,
    bool accepted,
  ) => switch ((kind, accepted)) {
    (ConfigurationBaselineTransitionKind.promote, true) =>
      ConfigurationBaselineEventKind.activated,
    (ConfigurationBaselineTransitionKind.promote, false) =>
      ConfigurationBaselineEventKind.promotionRejected,
    (ConfigurationBaselineTransitionKind.rollback, true) =>
      ConfigurationBaselineEventKind.rolledBack,
    (ConfigurationBaselineTransitionKind.rollback, false) =>
      ConfigurationBaselineEventKind.rollbackRejected,
    (ConfigurationBaselineTransitionKind.revoke, true) =>
      ConfigurationBaselineEventKind.revoked,
    (ConfigurationBaselineTransitionKind.revoke, false) =>
      ConfigurationBaselineEventKind.revocationRejected,
  };
}

String _sha256Of(Object? value) =>
    AlgorithmConfigurationIdentity.digestConfiguration(value);
