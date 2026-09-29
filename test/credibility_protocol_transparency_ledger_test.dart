import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  const verifier = CredibilityProtocolTransparencyVerifier();

  CredibilityProtocolTransparencyLedger current() {
    final configuration = AlgorithmConfigurationIdentity.defaults();
    final plan = ProspectiveModelCredibilityPlan.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256: configuration.sha256Digest,
    );
    final execution = CredibilityEvidenceExecutionAttestation.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
    return CredibilityProtocolTransparencyLedger.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      executionAttestationSha256: execution.attestationSha256,
      manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
  }

  test('clean synthetic ledger is observed without creating a GCP claim', () {
    final assessment = verifier.verify(current());

    expect(assessment.status, ProtocolTransparencyStatus.mechanicallyObserved);
    expect(assessment.integrityVerified, isTrue);
    expect(assessment.findings, isEmpty);
    expect(assessment.lastAcceptedSequence, 5);
    expect(assessment.canClaimGcpConformance, isFalse);
    expect(assessment.outcomeStatusCounts[ProtocolOutcomeStatus.reported], 2);
    expect(assessment.outcomeStatusCounts[ProtocolOutcomeStatus.postHoc], 1);
    expect(assessment.outcomeStatusCounts[ProtocolOutcomeStatus.omitted], 0);
  });

  test('broken predecessor and clock replay fail closed', () {
    final base = current();
    final events = [...base.events];
    events[2] = events[2].copyWith(
      predecessorSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      occurredAtUtc: '2026-08-18T00:01:00.000Z',
      observedAtUtc: '2026-08-18T00:01:00.000Z',
    );

    final assessment = verifier.verify(base.copyWith(events: events));
    expect(assessment.status, ProtocolTransparencyStatus.violated);
    expect(
      assessment.findings.map((finding) => finding.kind),
      containsAll(const [
        ProtocolTransparencyFindingKind.brokenPredecessor,
        ProtocolTransparencyFindingKind.clockRegression,
      ]),
    );
  });

  test('post-result amendment cannot be relabelled prospective', () {
    final base = current();
    final prior = base.events.last;
    final event = ProtocolTransparencyEvent(
      sequence: base.events.length + 1,
      eventId: 'forged-prospective-amendment',
      predecessorSha256: prior.eventSha256,
      type: ProtocolTransparencyEventType.amendment,
      authorId: 'synthetic-protocolOwner',
      authorRole: ProtocolActorRole.protocolOwner,
      authorityId: 'synthetic-governance-authority',
      reviewerId: 'synthetic-independent-reviewer',
      reviewDecision: ProtocolReviewDecision.accepted,
      reason: 'Mutation fixture attempts to relabel a result-aware change.',
      occurredAtUtc: '2026-08-18T00:40:00.000Z',
      observedAtUtc: '2026-08-18T00:40:00.000Z',
      accessedSplits: const [EvidenceSplitRole.lockedTest],
      visibleResults: const [ProtocolResultVisibility.aggregate],
      assertedProspective: true,
      affectedFactorIds: const ['comparatorOrValidationData'],
      affectedOutcomeIds: const ['outcome.mutation_suite_detected'],
      analysisPlanSha256: base.expectedAnalysisPlanSha256,
      datasetSha256: base.expectedDatasetSha256,
      codeSha256: base.expectedCodeSha256,
      supersededValueSha256: null,
      replacementValueSha256: null,
      sourceRecordSha256: null,
      affectsScientificSoundness: true,
      affectsDataValidity: false,
      affectsParticipantRights: false,
      affectsContextOfUse: false,
      acknowledged: true,
      accepted: true,
    );

    final assessment = verifier.verify(
      base.copyWith(events: [...base.events, event]),
    );
    expect(
      assessment.findings.map((finding) => finding.kind),
      contains(ProtocolTransparencyFindingKind.postResultProspectiveClaim),
    );
  });

  test(
    'correction must preserve superseded, replacement and source values',
    () {
      final base = current();
      final events = [...base.events];
      events[4] = events[4].copyWith(
        supersededValueSha256: 'missing',
        replacementValueSha256: 'missing',
        sourceRecordSha256: 'missing',
      );

      final assessment = verifier.verify(base.copyWith(events: events));
      expect(
        assessment.findings.map((finding) => finding.kind),
        contains(ProtocolTransparencyFindingKind.correctionHistoryMissing),
      );
    },
  );

  test('planned outcome omission remains explicit and blocks integrity', () {
    final base = current();
    final outcomes = [...base.outcomes];
    outcomes[0] = outcomes[0].copyWith(status: ProtocolOutcomeStatus.omitted);

    final assessment = verifier.verify(base.copyWith(outcomes: outcomes));
    expect(assessment.status, ProtocolTransparencyStatus.violated);
    expect(
      assessment.findings.map((finding) => finding.kind),
      contains(ProtocolTransparencyFindingKind.omittedPlannedOutcome),
    );
    expect(assessment.outcomeStatusCounts[ProtocolOutcomeStatus.omitted], 1);
  });

  test('missing review, disagreement and role escalation fail closed', () {
    final base = current();
    final events = [...base.events];
    events[1] = events[1].copyWith(
      reviewerId: '',
      reviewDecision: ProtocolReviewDecision.disputed,
      authorRole: ProtocolActorRole.observer,
    );

    final kinds = verifier
        .verify(base.copyWith(events: events))
        .findings
        .map((finding) => finding.kind);
    expect(
      kinds,
      containsAll(const [
        ProtocolTransparencyFindingKind.missingIndependentReview,
        ProtocolTransparencyFindingKind.reviewerDisagreement,
        ProtocolTransparencyFindingKind.roleEscalation,
      ]),
    );
  });

  test('rejected event is retained as held with last accepted state', () {
    final base = current();
    final events = [...base.events];
    events[4] = events[4].copyWith(
      reviewDecision: ProtocolReviewDecision.rejected,
      accepted: false,
    );

    final assessment = verifier.verify(base.copyWith(events: events));
    expect(assessment.status, ProtocolTransparencyStatus.held);
    expect(assessment.findings, isEmpty);
    expect(assessment.lastAcceptedSequence, 4);
    expect(assessment.lastAcceptedEventSha256, events[3].eventSha256);
  });

  test('explicit revocation is append-only and fails closed', () {
    final base = current();
    final prior = base.events.last;
    final revocation = ProtocolTransparencyEvent(
      sequence: base.events.length + 1,
      eventId: 'explicit-revocation-v1',
      predecessorSha256: prior.eventSha256,
      type: ProtocolTransparencyEventType.revocation,
      authorId: 'synthetic-independent-reviewer',
      authorRole: ProtocolActorRole.independentReviewer,
      authorityId: 'synthetic-governance-authority',
      reviewerId: 'synthetic-independent-reviewer',
      reviewDecision: ProtocolReviewDecision.accepted,
      reason: 'Synthetic revocation mutation.',
      occurredAtUtc: '2026-08-18T00:45:00.000Z',
      observedAtUtc: '2026-08-18T00:45:00.000Z',
      accessedSplits: const [EvidenceSplitRole.lockedTest],
      visibleResults: const [ProtocolResultVisibility.adverse],
      assertedProspective: false,
      affectedFactorIds: const ['comparatorOrValidationData'],
      affectedOutcomeIds: base.plannedOutcomeIds,
      analysisPlanSha256: base.expectedAnalysisPlanSha256,
      datasetSha256: base.expectedDatasetSha256,
      codeSha256: base.expectedCodeSha256,
      supersededValueSha256: null,
      replacementValueSha256: null,
      sourceRecordSha256: null,
      affectsScientificSoundness: true,
      affectsDataValidity: true,
      affectsParticipantRights: false,
      affectsContextOfUse: true,
      acknowledged: true,
      accepted: true,
    );

    final assessment = verifier.verify(
      base.copyWith(events: [...base.events, revocation]),
    );
    expect(assessment.status, ProtocolTransparencyStatus.revoked);
    expect(
      assessment.findings.map((finding) => finding.kind),
      contains(ProtocolTransparencyFindingKind.revoked),
    );
  });

  test('future schema and runtime identity drift remain unknown', () {
    final base = current();
    final drifted = base.copyWith(
      schemaVersion: 2,
      configurationSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    final assessment = verifier.verify(drifted);

    expect(assessment.status, ProtocolTransparencyStatus.unknown);
    expect(
      assessment.findings.map((finding) => finding.kind),
      containsAll(const [
        ProtocolTransparencyFindingKind.schemaUnsupported,
        ProtocolTransparencyFindingKind.identityMismatch,
      ]),
    );
  });

  test('collections are immutable and JSON is deterministic and bounded', () {
    final ledger = current();
    final first = jsonEncode(verifier.verify(ledger).toJson());
    final second = jsonEncode(verifier.verify(current()).toJson());

    expect(() => ledger.events.clear(), throwsUnsupportedError);
    expect(() => ledger.outcomes.clear(), throwsUnsupportedError);
    expect(
      () => ledger.events.first.visibleResults.clear(),
      throwsUnsupportedError,
    );
    expect(first, second);
    expect(first, contains('postHoc'));
    expect(first, contains('last_accepted_event_sha256'));
    expect(first, isNot(contains('patient_id')));
  });
}
