import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_randomization_interim_firewall.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  const verifier = CredibilityRandomizationInterimVerifier();

  CredibilityRandomizationInterimPackage current() {
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
    final replication = CredibilityBlindedReplicationPackage.syntheticCurrent(
      protocolLedger: ledger,
      protocolAssessment: const CredibilityProtocolTransparencyVerifier()
          .verify(ledger),
      executionAttestationSha256: execution.attestationSha256,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
    final statistics = CredibilityStatisticalAnalysisPackage.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      protocolLedgerSha256: ledger.ledgerSha256,
      replicationPackageSha256: replication.packageSha256,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
    return CredibilityRandomizationInterimPackage.syntheticCurrent(
      statisticalPackage: statistics,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
  }

  Set<RandomizationInterimFindingKind> kinds(
    CredibilityRandomizationInterimPackage package,
  ) => verifier.verify(package).findings.map((item) => item.kind).toSet();

  test('clean fixture exposes seven operational governance lanes', () {
    final package = current();
    final assessment = verifier.verify(package);

    expect(
      assessment.status,
      RandomizationInterimGovernanceStatus.mechanicallyObserved,
    );
    expect(assessment.integrityVerified, isTrue);
    expect(assessment.findings, isEmpty);
    expect(assessment.lanes.keys, {
      'randomizationIdentity',
      'concealment',
      'roleSeparation',
      'accessHistory',
      'interimBoundaries',
      'committeeRecommendation',
      'adjudication',
    });
    expect(assessment.counts, containsPair('assignments', 4));
    expect(assessment.counts, containsPair('plannedLooks', 2));
    expect(assessment.counts, containsPair('completedLooks', 1));
    expect(assessment.counts, containsPair('committeeMembers', 3));
    expect(assessment.counts, containsPair('emergencyUnblinding', 0));
    expect(assessment.canSupportGcpConformance, isFalse);
  });

  test('seed or future-assignment exposure fails closed', () {
    final base = current();
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            publicArtifactContainsSeed: true,
            publicArtifactContainsFutureAssignments: true,
          ),
        ),
      ),
      contains(RandomizationInterimFindingKind.seedOrFutureAssignmentExposed),
    );
  });

  test('schedule or seed custody forgery cannot open commitment', () {
    final base = current();
    expect(
      kinds(
        base.copyWith(
          custody: base.custody.copyWith(seedSecret: 'forged-short-seed'),
        ),
      ),
      contains(RandomizationInterimFindingKind.scheduleCommitmentMismatch),
    );
  });

  test('sequence generation and enrollment role collapse fails closed', () {
    final base = current();
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            enrollmentActorId: base.contract.generatorActorId,
          ),
        ),
      ),
      contains(RandomizationInterimFindingKind.roleCollapse),
    );
  });

  test('ineligible or replayed assignment is retained as violation', () {
    final base = current();
    final changed = base.assignments.first.copyWith(
      sequence: 2,
      eligibilityVerified: false,
    );
    expect(
      kinds(base.copyWith(assignments: [changed, ...base.assignments.skip(1)])),
      containsAll(const {
        RandomizationInterimFindingKind.assignmentChainBroken,
        RandomizationInterimFindingKind.ineligibleAssignment,
      }),
    );
  });

  test('sponsor access to comparative interim data breaks firewall', () {
    final base = current();
    final changed = base.accessEvents.last.copyWith(
      interimComparativeResultVisible: true,
    );
    expect(
      kinds(
        base.copyWith(
          accessEvents: [
            ...base.accessEvents.take(base.accessEvents.length - 1),
            changed,
          ],
        ),
      ),
      contains(RandomizationInterimFindingKind.sponsorInterimExposure),
    );
  });

  test('unauthorized emergency unblinding is rejected', () {
    final base = current();
    final prior = base.accessEvents.last;
    final emergency = RandomizationAccessEvent(
      sequence: base.accessEvents.length + 1,
      eventId: 'mutation-emergency-unblinding',
      predecessorSha256: prior.eventSha256,
      kind: RandomizationAccessKind.emergencyUnblinding,
      actorId: base.contract.sponsorActorId,
      role: RandomizationRole.sponsor,
      authorityId: 'mutation-authority',
      occurredAtUtc: '2026-08-18T09:10:00.000Z',
      treatmentIdentityVisible: false,
      interimComparativeResultVisible: false,
      purpose: 'short',
      scope: 'all assignments',
      acknowledged: true,
      accepted: true,
    );
    expect(
      kinds(base.copyWith(accessEvents: [...base.accessEvents, emergency])),
      containsAll(const {
        RandomizationInterimFindingKind.unauthorizedAccess,
        RandomizationInterimFindingKind.emergencyUnblindingInvalid,
      }),
    );
  });

  test('committee conflict and insufficient membership fail closed', () {
    final base = current();
    final conflicted = base.committeeMembers.first.copyWith(
      independentFromSponsor: false,
      conflictFree: false,
    );
    expect(
      kinds(base.copyWith(committeeMembers: [conflicted])),
      containsAll(const {
        RandomizationInterimFindingKind.committeeIncomplete,
        RandomizationInterimFindingKind.committeeConflict,
      }),
    );
  });

  test('interim alpha or boundary drift fails closed', () {
    final base = current();
    final changed = base.boundaryPlan.boundaries.first.copyWith(
      cumulativeAlpha: 0.20,
    );
    expect(
      kinds(
        base.copyWith(
          boundaryPlan: base.boundaryPlan.copyWith(
            boundaries: [changed, ...base.boundaryPlan.boundaries.skip(1)],
          ),
        ),
      ),
      containsAll(const {
        RandomizationInterimFindingKind.interimPlanMismatch,
        RandomizationInterimFindingKind.alphaSpendingDrift,
      }),
    );
  });

  test('duplicate interim look and inadequate quorum fail closed', () {
    final base = current();
    final changed = base.interimReviews.single.copyWith(
      votingMemberIds: [base.committeeMembers.first.memberId],
    );
    expect(
      kinds(base.copyWith(interimReviews: [changed, changed])),
      containsAll(const {
        RandomizationInterimFindingKind.interimLookReplay,
        RandomizationInterimFindingKind.insufficientQuorum,
        RandomizationInterimFindingKind.decisionChainBroken,
      }),
    );
  });

  test('sponsor override is a terminal integrity violation', () {
    final base = current();
    final changed = base.sponsorDecisions.single.copyWith(
      acceptedRecommendation: false,
      overrideAttempted: true,
    );
    expect(
      kinds(base.copyWith(sponsorDecisions: [changed])),
      contains(RandomizationInterimFindingKind.recommendationOverride),
    );
  });

  test('unaccepted access remains visible as held', () {
    final base = current();
    final changed = base.accessEvents.last.copyWith(accepted: false);
    final assessment = verifier.verify(
      base.copyWith(
        accessEvents: [
          ...base.accessEvents.take(base.accessEvents.length - 1),
          changed,
        ],
      ),
    );
    expect(assessment.status, RandomizationInterimGovernanceStatus.held);
    expect(assessment.lanes['adjudication'], 'held');
  });

  test('future schema is unknown and revocation is terminal', () {
    final base = current();
    expect(
      verifier.verify(base.copyWith(schemaVersion: 2)).status,
      RandomizationInterimGovernanceStatus.unknown,
    );
    expect(
      verifier.verify(base.copyWith(revoked: true)).status,
      RandomizationInterimGovernanceStatus.revoked,
    );
  });

  test('public JSON is deterministic, immutable, and secret-free', () {
    final package = current();
    final encoded = jsonEncode(package.toJson());
    expect(encoded, jsonEncode(current().toJson()));
    expect(encoded, isNot(contains(package.custody.seedSecret)));
    expect(encoded, isNot(contains(package.custody.commitmentSalt)));
    for (final code in package.custody.assignmentCodes) {
      expect(encoded, isNot(contains(code)));
    }
    expect(
      () => package.assignments.add(package.assignments.first),
      throwsUnsupportedError,
    );
  });
}
