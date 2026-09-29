import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  const verifier = CredibilityBlindedReplicationVerifier();

  CredibilityBlindedReplicationPackage current() {
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
    final ledger = CredibilityProtocolTransparencyLedger.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      executionAttestationSha256: execution.attestationSha256,
      manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
    final protocolAssessment = const CredibilityProtocolTransparencyVerifier()
        .verify(ledger);
    return CredibilityBlindedReplicationPackage.syntheticCurrent(
      protocolLedger: ledger,
      protocolAssessment: protocolAssessment,
      executionAttestationSha256: execution.attestationSha256,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
  }

  ReplicationAdjudicationEvent heldAdjudication(
    CredibilityBlindedReplicationPackage package,
    IndependentReplicationResponse response,
    List<ReplicationDiscrepancyClass> classes,
  ) => package.adjudicationEvents.single.copyWith(
    responseSha256: response.responseSha256,
    decision: ReplicationAdjudicationDecision.discrepancyHeld,
    discrepancyClasses: classes,
    reason: 'Synthetic discrepancy retained for independent adjudication.',
  );

  test('clean synthetic package exposes six bounded evidence lanes', () {
    final package = current();
    final assessment = verifier.verify(package);
    final capsuleJson = jsonEncode(package.capsule.toJson());

    expect(assessment.status, BlindedReplicationStatus.mechanicallyObserved);
    expect(assessment.integrityVerified, isTrue);
    expect(assessment.findings, isEmpty);
    expect(assessment.discrepancies, isEmpty);
    expect(assessment.lanes, {
      'capsule': 'contentAddressed',
      'blinding': 'sealedUntilFinalization',
      'independentResponse': 'roleSeparated',
      'environmentMatch': 'matched',
      'comparison': 'exactAgreement',
      'adjudication': 'acceptedSyntheticAgreement',
    });
    expect(assessment.canSupportScientificCredibility, isFalse);
    expect(capsuleJson, isNot(contains('expected_outcomes')));
    expect(capsuleJson, isNot(contains('result_sha256')));
    expect(capsuleJson, isNot(contains('patient_id')));
  });

  test('expected values and raw participant data in capsule fail closed', () {
    final base = current();
    final assessment = verifier.verify(
      base.copyWith(
        capsule: base.capsule.copyWith(
          containsExpectedResultValues: true,
          containsRawParticipantData: true,
        ),
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      containsAll(const [
        BlindedReplicationFindingKind.expectedValueInCapsule,
        BlindedReplicationFindingKind.rawParticipantDataIncluded,
      ]),
    );
  });

  test('same actor or missing independent authority fails closed', () {
    final base = current();
    final response = base.responses.single.copyWith(
      replicatorId: base.capsule.creatorId,
      independentlyAuthorized: false,
      replicatorAuthorityId: '',
    );
    final assessment = verifier.verify(
      base.copyWith(
        responses: [response],
        adjudicationEvents: [
          base.adjudicationEvents.single.copyWith(
            responseSha256: response.responseSha256,
          ),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      containsAll(const [
        BlindedReplicationFindingKind.actorNotIndependent,
        BlindedReplicationFindingKind.authorityMissing,
      ]),
    );
  });

  test('pre-finalization access and early custody release break blinding', () {
    final base = current();
    final response = base.responses.single.copyWith(
      expectedResultsAccessedBeforeFinalization: true,
    );
    final assessment = verifier.verify(
      base.copyWith(
        custody: base.custody.copyWith(
          releasedAtUtc: '2026-08-18T01:15:00.000Z',
        ),
        responses: [response],
        adjudicationEvents: [
          base.adjudicationEvents.single.copyWith(
            responseSha256: response.responseSha256,
          ),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      everyElement(BlindedReplicationFindingKind.blindingBreach),
    );
  });

  test('environment and dependency drift are classified and held', () {
    final base = current();
    final response = base.responses.single.copyWith(
      environmentSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      dependencyLockSha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    final assessment = verifier.verify(
      base.copyWith(
        responses: [response],
        adjudicationEvents: [
          heldAdjudication(base, response, const [
            ReplicationDiscrepancyClass.environment,
            ReplicationDiscrepancyClass.dependency,
          ]),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.held);
    expect(assessment.findings, isEmpty);
    expect(
      assessment.discrepancies.map((item) => item.classification).toSet(),
      {
        ReplicationDiscrepancyClass.environment,
        ReplicationDiscrepancyClass.dependency,
      },
    );
    expect(assessment.lanes['environmentMatch'], 'different');
  });

  test('missing null outcome remains visible as analysis discrepancy', () {
    final base = current();
    final retained = base.responses.single.outcomes
        .where((item) => item.status != ReplicationOutcomeStatus.nullResult)
        .toList();
    final response = base.responses.single.copyWith(outcomes: retained);
    final assessment = verifier.verify(
      base.copyWith(
        responses: [response],
        adjudicationEvents: [
          heldAdjudication(base, response, const [
            ReplicationDiscrepancyClass.analysis,
          ]),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.held);
    expect(
      assessment.discrepancies,
      contains(
        isA<ReplicationDiscrepancy>()
            .having(
              (item) => item.classification,
              'classification',
              ReplicationDiscrepancyClass.analysis,
            )
            .having((item) => item.observed, 'observed', 'missing'),
      ),
    );
  });

  test('post-publication tolerance policy change is a violation', () {
    final base = current();
    final assessment = verifier.verify(
      base.copyWith(
        comparisonTolerancePolicySha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      contains(BlindedReplicationFindingKind.tolerancePolicyChanged),
    );
  });

  test('response replay clock regression partial run and unsafe logs fail', () {
    final base = current();
    final first = base.responses.single.copyWith(
      finalizedAtUtc: '2026-08-18T01:05:00.000Z',
      monotonicEndMicros: 900000,
      privacyBoundedLogs: false,
      completeExecution: false,
    );
    final replay = first.copyWith(sequence: 2);
    final assessment = verifier.verify(
      base.copyWith(
        responses: [first, replay],
        adjudicationEvents: [
          base.adjudicationEvents.single.copyWith(
            responseSha256: replay.responseSha256,
          ),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      containsAll(const [
        BlindedReplicationFindingKind.responseChainBroken,
        BlindedReplicationFindingKind.responseReplay,
        BlindedReplicationFindingKind.invalidClock,
        BlindedReplicationFindingKind.partialExecution,
        BlindedReplicationFindingKind.privacyUnsafeLog,
      ]),
    );
  });

  test('custody salt drift cannot open the sealed commitment', () {
    final base = current();
    final assessment = verifier.verify(
      base.copyWith(
        custody: base.custody.copyWith(commitmentSalt: 'forged-salt'),
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      contains(BlindedReplicationFindingKind.custodyCommitmentMismatch),
    );
  });

  test('agreement cannot be accepted over an unresolved discrepancy', () {
    final base = current();
    final response = base.responses.single.copyWith(
      codeSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    final assessment = verifier.verify(
      base.copyWith(
        responses: [response],
        adjudicationEvents: [
          base.adjudicationEvents.single.copyWith(
            responseSha256: response.responseSha256,
          ),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.violated);
    expect(
      assessment.findings.map((item) => item.kind),
      contains(BlindedReplicationFindingKind.adjudicationMismatch),
    );
  });

  test('future schema and runtime identity drift remain unknown', () {
    final base = current();
    final capsule = base.capsule.copyWith(
      configurationSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    final response = base.responses.single.copyWith(
      capsuleSha256: capsule.capsuleSha256,
      configurationSha256: capsule.configurationSha256,
    );
    final assessment = verifier.verify(
      base.copyWith(
        schemaVersion: 2,
        capsule: capsule,
        custody: base.custody.copyWith(capsuleSha256: capsule.capsuleSha256),
        responses: [response],
        adjudicationEvents: [
          base.adjudicationEvents.single.copyWith(
            responseSha256: response.responseSha256,
          ),
        ],
      ),
    );

    expect(assessment.status, BlindedReplicationStatus.unknown);
    expect(
      assessment.findings.map((item) => item.kind),
      containsAll(const [
        BlindedReplicationFindingKind.schemaUnsupported,
        BlindedReplicationFindingKind.identityMismatch,
      ]),
    );
  });

  test('append-only revocation dominates the observed result', () {
    final base = current();
    final prior = base.adjudicationEvents.single;
    final revocation = ReplicationAdjudicationEvent(
      sequence: 2,
      eventId: 'synthetic-revocation-v1',
      predecessorSha256: prior.eventSha256,
      responseSha256: base.responses.single.responseSha256,
      actorId: 'synthetic-independent-adjudicator',
      authorityId: 'synthetic-adjudication-authority',
      decision: ReplicationAdjudicationDecision.revoked,
      discrepancyClasses: const [],
      reason: 'Synthetic explicit revocation fixture.',
      occurredAtUtc: '2026-08-18T01:30:00.000Z',
      accepted: true,
    );
    final assessment = verifier.verify(
      base.copyWith(adjudicationEvents: [prior, revocation]),
    );

    expect(assessment.status, BlindedReplicationStatus.revoked);
    expect(
      assessment.findings.map((item) => item.kind),
      contains(BlindedReplicationFindingKind.revocation),
    );
  });

  test('collections are immutable and output is deterministic and bounded', () {
    final package = current();
    final first = jsonEncode(verifier.verify(package).toJson());
    final second = jsonEncode(verifier.verify(current()).toJson());

    expect(() => package.responses.clear(), throwsUnsupportedError);
    expect(
      () => package.custody.expectedOutcomes.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => package.responses.single.outcomes.clear(),
      throwsUnsupportedError,
    );
    expect(first, second);
    expect(first, contains('nullResult'));
    expect(first, contains('failed'));
    expect(first, contains('adverse'));
    expect(first, isNot(contains('patient_id')));
  });
}
