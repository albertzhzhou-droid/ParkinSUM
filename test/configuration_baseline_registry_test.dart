import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_configuration_change_impact.dart';
import 'package:parkinsum_companion/domain/entities/configuration_baseline_registry.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_configuration_change_impact_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/configuration_baseline_registry_service.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';

void main() {
  const service = ConfigurationBaselineRegistryService();
  final anchor = DateTime.utc(2026, 8, 27, 12);

  test(
    'current candidate is retained and blocked on unresolved obligations',
    () async {
      final impact = _buildExecutableChangeImpactFixture();
      final result = await service.buildCurrentFixture(
        impact: impact,
        contextOfUseRecordSha256: _sha('c'),
      );

      expect(result.accepted, isFalse);
      expect(result.reason, 'verification_obligations_incomplete');
      expect(result.state.revision, 2);
      expect(
        result.state.events.last.kind,
        ConfigurationBaselineEventKind.promotionRejected,
      );
      expect(
        result.state.activeConfigurationSha256,
        impact.previousConfigurationSha256,
      );
      expect(result.state.integrityReasons, isEmpty);
      expect(result.state.toJson()['boundary'], contains('not scientific'));
    },
  );

  test(
    'seven independent Ed25519 authorities can promote and rollback',
    () async {
      final initial = service.initialState(
        activeConfigurationSha256: _sha('a'),
        environment: 'test',
        targetPopulationScope: 'synthetic',
        recordedAtUtc: anchor,
      );
      final signedPromotion = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('b'),
        rollbackTarget: null,
        anchor: anchor,
      );
      final promoted = await service.apply(
        state: initial,
        expectedRevision: 1,
        receipt: signedPromotion.receipt,
        trustedReviewerKeys: signedPromotion.keys,
        nowUtc: anchor.add(const Duration(minutes: 2)),
      );
      expect(promoted.accepted, isTrue);
      expect(promoted.state.activeConfigurationSha256, _sha('b'));
      expect(
        promoted.state.events.last.kind,
        ConfigurationBaselineEventKind.activated,
      );

      final signedRollback = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.rollback,
        expectedActive: _sha('b'),
        candidate: _sha('a'),
        rollbackTarget: _sha('a'),
        anchor: anchor.add(const Duration(minutes: 3)),
      );
      final rolledBack = await service.apply(
        state: promoted.state,
        expectedRevision: promoted.state.revision,
        receipt: signedRollback.receipt,
        trustedReviewerKeys: signedRollback.keys,
        nowUtc: anchor.add(const Duration(minutes: 5)),
      );
      expect(rolledBack.accepted, isTrue);
      expect(rolledBack.state.activeConfigurationSha256, _sha('a'));
      expect(
        rolledBack.state.events.last.kind,
        ConfigurationBaselineEventKind.rolledBack,
      );
      expect(rolledBack.state.integrityReasons, isEmpty);
    },
  );

  test('one public key cannot satisfy multiple reviewer authorities', () async {
    final initial = service.initialState(
      activeConfigurationSha256: _sha('a'),
      environment: 'test',
      targetPopulationScope: 'synthetic',
      recordedAtUtc: anchor,
    );
    final unsigned = _receipt(
      kind: ConfigurationBaselineTransitionKind.promote,
      expectedActive: _sha('a'),
      candidate: _sha('b'),
      rollbackTarget: null,
      anchor: anchor,
      signatures: const [],
    );
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPairFromSeed(
      List.generate(32, (position) => position + 1),
    );
    final publicKey = await pair.extractPublicKey();
    final sharedSignature = await algorithm.sign(
      utf8.encode(unsigned.signingPayloadJson),
      keyPair: pair,
    );
    final signatures = <ConfigurationBaselineReviewerSignature>[];
    final keys = <String, ConfigurationBaselineTrustedReviewerKey>{};
    var index = 1;
    for (final role
        in ConfigurationBaselineRegistryService.requiredPromotionRoles.toList()
          ..sort()) {
      final keyId = 'shared-key-alias-$index';
      final reviewerId = 'reviewer-$index';
      signatures.add(
        ConfigurationBaselineReviewerSignature(
          reviewerId: reviewerId,
          authorityRole: role,
          keyId: keyId,
          signatureBase64: base64Encode(sharedSignature.bytes),
        ),
      );
      keys[keyId] = ConfigurationBaselineTrustedReviewerKey(
        reviewerId: reviewerId,
        authorityRole: role,
        keyId: keyId,
        publicKey: publicKey,
      );
      index += 1;
    }

    final result = await service.apply(
      state: initial,
      expectedRevision: initial.revision,
      receipt: _copyReceipt(unsigned, signatures: signatures),
      trustedReviewerKeys: keys,
      nowUtc: anchor.add(const Duration(minutes: 2)),
    );

    expect(result.accepted, isFalse);
    expect(result.reason, 'reviewer_trust_binding_invalid');
    expect(result.state.integrityReasons, isEmpty);
  });

  test('receipt identities and authority labels match trusted keys', () async {
    final initial = service.initialState(
      activeConfigurationSha256: _sha('a'),
      environment: 'test',
      targetPopulationScope: 'synthetic',
      recordedAtUtc: anchor,
    );
    final signed = await _signedReceipt(
      kind: ConfigurationBaselineTransitionKind.promote,
      expectedActive: _sha('a'),
      candidate: _sha('b'),
      rollbackTarget: null,
      anchor: anchor,
    );
    final reviewer = signed.receipt.signatures.first;
    final original = signed.keys[reviewer.keyId]!;
    for (final mismatchedBinding in [
      ConfigurationBaselineTrustedReviewerKey(
        reviewerId: 'another-reviewer',
        authorityRole: original.authorityRole,
        keyId: original.keyId,
        publicKey: original.publicKey,
      ),
      ConfigurationBaselineTrustedReviewerKey(
        reviewerId: original.reviewerId,
        authorityRole: 'untrusted_relabel',
        keyId: original.keyId,
        publicKey: original.publicKey,
      ),
      ConfigurationBaselineTrustedReviewerKey(
        reviewerId: original.reviewerId,
        authorityRole: original.authorityRole,
        keyId: 'another-key-id',
        publicKey: original.publicKey,
      ),
    ]) {
      final result = await service.apply(
        state: initial,
        expectedRevision: initial.revision,
        receipt: signed.receipt,
        trustedReviewerKeys: {
          ...signed.keys,
          reviewer.keyId: mismatchedBinding,
        },
        nowUtc: anchor.add(const Duration(minutes: 2)),
      );

      expect(result.accepted, isFalse);
      expect(result.reason, 'reviewer_trust_binding_invalid');
      expect(result.state.integrityReasons, isEmpty);
    }
  });

  test(
    'replay, stale active identity and atomic revision conflicts are retained',
    () async {
      final initial = service.initialState(
        activeConfigurationSha256: _sha('a'),
        environment: 'test',
        targetPopulationScope: 'synthetic',
        recordedAtUtc: anchor,
      );
      final signed = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('b'),
        rollbackTarget: null,
        anchor: anchor,
      );
      final first = await service.apply(
        state: initial,
        expectedRevision: 1,
        receipt: signed.receipt,
        trustedReviewerKeys: signed.keys,
        nowUtc: anchor.add(const Duration(minutes: 2)),
      );
      final replay = await service.apply(
        state: first.state,
        expectedRevision: first.state.revision,
        receipt: signed.receipt,
        trustedReviewerKeys: signed.keys,
        nowUtc: anchor.add(const Duration(minutes: 3)),
      );
      expect(replay.accepted, isFalse);
      expect(replay.reason, 'receipt_replay_rejected');
      expect(
        replay.state.events.last.kind,
        ConfigurationBaselineEventKind.promotionRejected,
      );

      final conflict = await service.apply(
        state: replay.state,
        expectedRevision: 1,
        receipt: signed.receipt,
        trustedReviewerKeys: signed.keys,
        nowUtc: anchor.add(const Duration(minutes: 4)),
      );
      expect(conflict.accepted, isFalse);
      expect(conflict.reason, 'atomic_revision_conflict');
      expect(conflict.state.revision, replay.state.revision + 1);
    },
  );

  test(
    'registry and receipt clocks cannot move behind the current head',
    () async {
      final initial = service.initialState(
        activeConfigurationSha256: _sha('a'),
        environment: 'test',
        targetPopulationScope: 'synthetic',
        recordedAtUtc: anchor,
      );
      final futureIssued = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('b'),
        rollbackTarget: null,
        anchor: anchor,
      );
      final clockRegression = await service.apply(
        state: initial,
        expectedRevision: initial.revision,
        receipt: futureIssued.receipt,
        trustedReviewerKeys: futureIssued.keys,
        nowUtc: anchor.subtract(const Duration(minutes: 1)),
      );
      expect(clockRegression.accepted, isFalse);
      expect(clockRegression.reason, 'registry_clock_regression');
      expect(clockRegression.state.events.last.recordedAtUtc, anchor);
      expect(clockRegression.state.integrityReasons, isEmpty);

      final predating = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('c'),
        rollbackTarget: null,
        anchor: anchor.subtract(const Duration(minutes: 2)),
      );
      final predatingResult = await service.apply(
        state: initial,
        expectedRevision: initial.revision,
        receipt: predating.receipt,
        trustedReviewerKeys: predating.keys,
        nowUtc: anchor.add(const Duration(minutes: 1)),
      );
      expect(predatingResult.accepted, isFalse);
      expect(predatingResult.reason, 'receipt_predates_registry_head');
      expect(predatingResult.state.integrityReasons, isEmpty);
    },
  );

  test(
    'revocation retains identity but disables use until reviewed reactivation',
    () async {
      final initial = service.initialState(
        activeConfigurationSha256: _sha('a'),
        environment: 'test',
        targetPopulationScope: 'synthetic',
        recordedAtUtc: anchor,
      );
      final signedRevocation = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.revoke,
        expectedActive: _sha('a'),
        candidate: _sha('a'),
        rollbackTarget: null,
        anchor: anchor,
      );
      final revoked = await service.apply(
        state: initial,
        expectedRevision: initial.revision,
        receipt: signedRevocation.receipt,
        trustedReviewerKeys: signedRevocation.keys,
        nowUtc: anchor.add(const Duration(minutes: 2)),
      );
      expect(revoked.accepted, isTrue);
      expect(revoked.state.activeConfigurationSha256, _sha('a'));
      expect(revoked.state.activeConfigurationRevoked, isTrue);
      expect(revoked.state.hasUsableActiveConfiguration, isFalse);

      final signedReactivation = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('a'),
        rollbackTarget: null,
        anchor: anchor.add(const Duration(minutes: 3)),
      );
      final reactivated = await service.apply(
        state: revoked.state,
        expectedRevision: revoked.state.revision,
        receipt: signedReactivation.receipt,
        trustedReviewerKeys: signedReactivation.keys,
        nowUtc: anchor.add(const Duration(minutes: 5)),
      );
      expect(reactivated.accepted, isTrue);
      expect(reactivated.state.activeConfigurationRevoked, isFalse);
      expect(reactivated.state.hasUsableActiveConfiguration, isTrue);
      expect(reactivated.state.integrityReasons, isEmpty);
    },
  );

  test(
    'tampered signatures and unknown rollback targets fail closed',
    () async {
      final initial = service.initialState(
        activeConfigurationSha256: _sha('a'),
        environment: 'test',
        targetPopulationScope: 'synthetic',
        recordedAtUtc: anchor,
      );
      final signed = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('b'),
        rollbackTarget: null,
        anchor: anchor,
      );
      final signatures = [...signed.receipt.signatures];
      final first = signatures.first;
      signatures[0] = ConfigurationBaselineReviewerSignature(
        reviewerId: first.reviewerId,
        authorityRole: first.authorityRole,
        keyId: first.keyId,
        signatureBase64: base64Encode(List.filled(64, 0)),
      );
      final tampered = _copyReceipt(signed.receipt, signatures: signatures);
      final rejected = await service.apply(
        state: initial,
        expectedRevision: 1,
        receipt: tampered,
        trustedReviewerKeys: signed.keys,
        nowUtc: anchor.add(const Duration(minutes: 2)),
      );
      expect(rejected.accepted, isFalse);
      expect(rejected.reason, 'reviewer_signature_invalid');

      final rollback = await _signedReceipt(
        kind: ConfigurationBaselineTransitionKind.rollback,
        expectedActive: _sha('a'),
        candidate: _sha('f'),
        rollbackTarget: _sha('f'),
        anchor: anchor.add(const Duration(minutes: 3)),
      );
      final unknown = await service.apply(
        state: initial,
        expectedRevision: 1,
        receipt: rollback.receipt,
        trustedReviewerKeys: rollback.keys,
        nowUtc: anchor.add(const Duration(minutes: 5)),
      );
      expect(unknown.accepted, isFalse);
      expect(unknown.reason, 'rollback_target_not_in_verified_history');
    },
  );

  test('event-chain tampering and reviewer-role collapse are rejected', () {
    final state = service.initialState(
      activeConfigurationSha256: _sha('a'),
      environment: 'test',
      targetPopulationScope: 'synthetic',
      recordedAtUtc: anchor,
    );
    expect(
      () => ConfigurationBaselineRegistryState(
        revision: 2,
        activeConfigurationSha256: _sha('a'),
        environment: 'test',
        targetPopulationScope: 'synthetic',
        events: [state.events.single],
      ),
      throwsArgumentError,
    );
    expect(
      () => _receipt(
        kind: ConfigurationBaselineTransitionKind.promote,
        expectedActive: _sha('a'),
        candidate: _sha('b'),
        rollbackTarget: null,
        anchor: anchor,
        signatures: const [
          ConfigurationBaselineReviewerSignature(
            reviewerId: 'repository-maintainers',
            authorityRole: 'software_quality',
            keyId: 'key',
            signatureBase64: 'AA==',
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => _receipt(
        kind: ConfigurationBaselineTransitionKind.rollback,
        expectedActive: _sha('b'),
        candidate: _sha('c'),
        rollbackTarget: _sha('a'),
        anchor: anchor,
        signatures: const [],
      ),
      throwsArgumentError,
    );
    for (final collapsed in [
      const [
        ConfigurationBaselineReviewerSignature(
          reviewerId: 'same-reviewer',
          authorityRole: 'software_quality',
          keyId: 'key-1',
          signatureBase64: 'AA==',
        ),
        ConfigurationBaselineReviewerSignature(
          reviewerId: 'same-reviewer',
          authorityRole: 'code_verification',
          keyId: 'key-2',
          signatureBase64: 'AA==',
        ),
      ],
      const [
        ConfigurationBaselineReviewerSignature(
          reviewerId: 'reviewer-1',
          authorityRole: 'same-role',
          keyId: 'key-1',
          signatureBase64: 'AA==',
        ),
        ConfigurationBaselineReviewerSignature(
          reviewerId: 'reviewer-2',
          authorityRole: 'same-role',
          keyId: 'key-2',
          signatureBase64: 'AA==',
        ),
      ],
      const [
        ConfigurationBaselineReviewerSignature(
          reviewerId: 'reviewer-1',
          authorityRole: 'software_quality',
          keyId: 'same-key',
          signatureBase64: 'AA==',
        ),
        ConfigurationBaselineReviewerSignature(
          reviewerId: 'reviewer-2',
          authorityRole: 'code_verification',
          keyId: 'same-key',
          signatureBase64: 'AA==',
        ),
      ],
    ]) {
      expect(
        () => _receipt(
          kind: ConfigurationBaselineTransitionKind.promote,
          expectedActive: _sha('a'),
          candidate: _sha('b'),
          rollbackTarget: null,
          anchor: anchor,
          signatures: collapsed,
        ),
        throwsArgumentError,
      );
    }
  });

  test('registry state rejects event scope and UTC ordering drift', () {
    final initial = service.initialState(
      activeConfigurationSha256: _sha('a'),
      environment: 'test',
      targetPopulationScope: 'synthetic',
      recordedAtUtc: anchor,
    );
    ConfigurationBaselineRegistryEvent next({
      required DateTime recordedAtUtc,
      String environment = 'test',
      String targetPopulationScope = 'synthetic',
    }) => ConfigurationBaselineRegistryEvent(
      sequence: 2,
      kind: ConfigurationBaselineEventKind.promotionRejected,
      configurationSha256: _sha('b'),
      activeConfigurationBeforeSha256: _sha('a'),
      activeConfigurationAfterSha256: _sha('a'),
      receiptSha256: _sha('f'),
      previousEventSha256: initial.events.single.eventSha256,
      recordedAtUtc: recordedAtUtc,
      reason: 'synthetic_rejection',
      environment: environment,
      targetPopulationScope: targetPopulationScope,
    );

    for (final driftedEvent in [
      next(recordedAtUtc: anchor, environment: 'other'),
      next(recordedAtUtc: anchor, targetPopulationScope: 'other'),
      next(recordedAtUtc: anchor.subtract(const Duration(microseconds: 1))),
    ]) {
      expect(
        () => ConfigurationBaselineRegistryState(
          revision: 2,
          activeConfigurationSha256: _sha('a'),
          environment: 'test',
          targetPopulationScope: 'synthetic',
          events: [initial.events.single, driftedEvent],
        ),
        throwsArgumentError,
      );
    }
  });
}

Future<
  ({
    ConfigurationBaselinePromotionReceipt receipt,
    Map<String, ConfigurationBaselineTrustedReviewerKey> keys,
  })
>
_signedReceipt({
  required ConfigurationBaselineTransitionKind kind,
  required String expectedActive,
  required String candidate,
  required String? rollbackTarget,
  required DateTime anchor,
}) async {
  final unsigned = _receipt(
    kind: kind,
    expectedActive: expectedActive,
    candidate: candidate,
    rollbackTarget: rollbackTarget,
    anchor: anchor,
    signatures: const [],
  );
  final algorithm = Ed25519();
  final signatures = <ConfigurationBaselineReviewerSignature>[];
  final keys = <String, ConfigurationBaselineTrustedReviewerKey>{};
  var index = 1;
  for (final role
      in ConfigurationBaselineRegistryService.requiredPromotionRoles.toList()
        ..sort()) {
    final keyId = 'key-$index';
    final pair = await algorithm.newKeyPairFromSeed(
      List.generate(32, (position) => (position + index) % 256),
    );
    final publicKey = await pair.extractPublicKey();
    final signature = await algorithm.sign(
      utf8.encode(unsigned.signingPayloadJson),
      keyPair: pair,
    );
    keys[keyId] = ConfigurationBaselineTrustedReviewerKey(
      reviewerId: 'reviewer-$index',
      authorityRole: role,
      keyId: keyId,
      publicKey: publicKey,
    );
    signatures.add(
      ConfigurationBaselineReviewerSignature(
        reviewerId: 'reviewer-$index',
        authorityRole: role,
        keyId: keyId,
        signatureBase64: base64Encode(signature.bytes),
      ),
    );
    index += 1;
  }
  return (receipt: _copyReceipt(unsigned, signatures: signatures), keys: keys);
}

ConfigurationBaselinePromotionReceipt _receipt({
  required ConfigurationBaselineTransitionKind kind,
  required String expectedActive,
  required String candidate,
  required String? rollbackTarget,
  required DateTime anchor,
  required List<ConfigurationBaselineReviewerSignature> signatures,
}) => ConfigurationBaselinePromotionReceipt(
  receiptId: 'receipt-${kind.name}-${anchor.minute}',
  transitionKind: kind,
  proposerId: 'repository-maintainers',
  environment: 'test',
  targetPopulationScope: 'synthetic',
  expectedActiveConfigurationSha256: expectedActive,
  candidateConfigurationSha256: candidate,
  rollbackTargetConfigurationSha256: rollbackTarget,
  sourceBundleSha256: _sha('1'),
  buildArtifactSha256: _sha('2'),
  changeImpactPackageSha256: _sha('3'),
  replayArtifactSha256: _sha('4'),
  contextOfUseRecordSha256: _sha('5'),
  obligationMatrixSha256: _sha('6'),
  obligations: {
    for (final role
        in ConfigurationBaselineRegistryService.requiredPromotionRoles)
      role: ConfigurationBaselineObligationStatus.satisfied,
  },
  issuedAtUtc: anchor.add(const Duration(minutes: 1)),
  expiresAtUtc: anchor.add(const Duration(days: 1)),
  signatures: signatures,
  boundary: 'Synthetic signature and atomic-transition fixture only.',
);

ConfigurationBaselinePromotionReceipt _copyReceipt(
  ConfigurationBaselinePromotionReceipt source, {
  required List<ConfigurationBaselineReviewerSignature> signatures,
}) => ConfigurationBaselinePromotionReceipt(
  receiptId: source.receiptId,
  transitionKind: source.transitionKind,
  proposerId: source.proposerId,
  environment: source.environment,
  targetPopulationScope: source.targetPopulationScope,
  expectedActiveConfigurationSha256: source.expectedActiveConfigurationSha256,
  candidateConfigurationSha256: source.candidateConfigurationSha256,
  rollbackTargetConfigurationSha256: source.rollbackTargetConfigurationSha256,
  sourceBundleSha256: source.sourceBundleSha256,
  buildArtifactSha256: source.buildArtifactSha256,
  changeImpactPackageSha256: source.changeImpactPackageSha256,
  replayArtifactSha256: source.replayArtifactSha256,
  contextOfUseRecordSha256: source.contextOfUseRecordSha256,
  obligationMatrixSha256: source.obligationMatrixSha256,
  obligations: source.obligations,
  issuedAtUtc: source.issuedAtUtc,
  expiresAtUtc: source.expiresAtUtc,
  signatures: signatures,
  boundary: source.boundary,
);

String _sha(String character) => List.filled(64, character).join();

AlgorithmConfigurationChangeImpactPackage
_buildExecutableChangeImpactFixture() {
  final currentParameters =
      GastricEmptyingParameterSet.literatureInformedDefault();
  final previousParameters = GastricEmptyingParameterSet(
    id: currentParameters.id,
    version: currentParameters.version,
    lastReviewed: currentParameters.lastReviewed,
    solidLagMinutes: currentParameters.solidLagMinutes,
    solidHalfMinutes: GastricEmptyingParameter<double>(
      id: currentParameters.solidHalfMinutes.id,
      label: currentParameters.solidHalfMinutes.label,
      value: currentParameters.solidHalfMinutes.value - 5,
      sourceRefs: currentParameters.solidHalfMinutes.sourceRefs,
      confidence: currentParameters.solidHalfMinutes.confidence,
      limitation: currentParameters.solidHalfMinutes.limitation,
    ),
    liquidLagMinutes: currentParameters.liquidLagMinutes,
    liquidHalfMinutes: currentParameters.liquidHalfMinutes,
    referenceMealCalories: currentParameters.referenceMealCalories,
    fatSlowdownMultiplier: currentParameters.fatSlowdownMultiplier,
    fatFractionThreshold: currentParameters.fatFractionThreshold,
    fiberSlowdownMultiplier: currentParameters.fiberSlowdownMultiplier,
    mixedMealUncertaintyBoost: currentParameters.mixedMealUncertaintyBoost,
    overlapUncertaintyBoost: currentParameters.overlapUncertaintyBoost,
    fatUncertaintyBoost: currentParameters.fatUncertaintyBoost,
    highCalorieUncertaintyBoost: currentParameters.highCalorieUncertaintyBoost,
    highCalorieFractionThreshold:
        currentParameters.highCalorieFractionThreshold,
    timeScaleSensitivityFraction:
        currentParameters.timeScaleSensitivityFraction,
  );
  final previousIdentity = AlgorithmConfigurationIdentity.defaults(
    gastricParameters: previousParameters,
  );
  final currentIdentity = AlgorithmConfigurationIdentity.defaults(
    gastricParameters: currentParameters,
  );
  final previousEngine = MechanisticConflictEngine(
    gastricEmptyingParameters: previousParameters,
  );
  final currentEngine = MechanisticConflictEngine(
    gastricEmptyingParameters: currentParameters,
  );
  final previousObservatory = AlgorithmObservatoryService(
    conflictEngine: previousEngine,
    candidateScorer: MechanisticNextMealScorer(engine: previousEngine),
    configurationIdentity: previousIdentity,
  );
  final currentObservatory = AlgorithmObservatoryService(
    conflictEngine: currentEngine,
    candidateScorer: MechanisticNextMealScorer(engine: currentEngine),
    configurationIdentity: currentIdentity,
  );
  return const AlgorithmConfigurationChangeImpactService().assess(
    previousIdentity: previousIdentity,
    currentIdentity: currentIdentity,
    expectedPreviousSha256: previousIdentity.sha256Digest,
    expectedCurrentSha256: currentIdentity.sha256Digest,
    previousSnapshots: {
      for (final scenario in ObservatoryScenario.values)
        scenario: previousObservatory.build(scenario),
    },
    currentSnapshots: {
      for (final scenario in ObservatoryScenario.values)
        scenario: currentObservatory.build(scenario),
    },
  );
}
