import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_randomization_interim_firewall.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  final package = _currentPackage();
  const verifier = CredibilityRandomizationInterimVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final expectedStatuses = <String, RandomizationInterimGovernanceStatus>{
    'seed_future_assignment_exposure':
        RandomizationInterimGovernanceStatus.violated,
    'schedule_commitment_forgery':
        RandomizationInterimGovernanceStatus.violated,
    'generator_enrollment_role_collapse':
        RandomizationInterimGovernanceStatus.violated,
    'assignment_replay_and_ineligible':
        RandomizationInterimGovernanceStatus.violated,
    'sponsor_interim_exposure': RandomizationInterimGovernanceStatus.violated,
    'invalid_emergency_unblinding':
        RandomizationInterimGovernanceStatus.violated,
    'committee_conflict': RandomizationInterimGovernanceStatus.violated,
    'alpha_boundary_drift': RandomizationInterimGovernanceStatus.violated,
    'interim_replay_and_quorum_failure':
        RandomizationInterimGovernanceStatus.violated,
    'sponsor_override': RandomizationInterimGovernanceStatus.violated,
    'unaccepted_access_hold': RandomizationInterimGovernanceStatus.held,
    'future_schema': RandomizationInterimGovernanceStatus.unknown,
    'explicit_revocation': RandomizationInterimGovernanceStatus.revoked,
  };
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final publicJson = jsonEncode(package.toJson());
  final secretsExcluded =
      !publicJson.contains(package.custody.seedSecret) &&
      !publicJson.contains(package.custody.commitmentSalt) &&
      package.custody.assignmentCodes.every(
        (code) => !publicJson.contains(code),
      );
  final pass =
      assessment.integrityVerified &&
      assessment.status ==
          RandomizationInterimGovernanceStatus.mechanicallyObserved &&
      assessment.lanes.length == 7 &&
      assessment.counts['plannedLooks'] == 2 &&
      assessment.counts['completedLooks'] == 1 &&
      secretsExcluded &&
      !assessment.canSupportGcpConformance &&
      mutationsDetected;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_randomization_interim_firewall',
    'pass': pass,
    'assessment': assessment.toJson(),
    'mutation_results': {
      for (final entry in mutations.entries)
        entry.key: {
          'expected_status': expectedStatuses[entry.key]!.name,
          'status': entry.value.status.name,
          'finding_kinds':
              entry.value.findings
                  .map((finding) => finding.kind.name)
                  .toSet()
                  .toList()
                ..sort(),
        },
    },
    'seed_and_future_assignments_excluded': secretsExcluded,
    'synthetic_fixture_only': true,
    'not_allocation_concealment_proof': true,
    'not_committee_independence_proof': true,
    'not_gcp_conformance': true,
    'not_scientific_or_clinical_validation': true,
    'not_regulatory_review': true,
    'not_clinical_or_patient_safety_evidence': true,
    'safety_boundary': package.boundary,
  };
  final markdown = <String>[
    '# Randomization, allocation concealment, and interim-access firewall',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Status:** ${assessment.status.name}',
    '**Integrity:** ${assessment.integrityVerified ? 'verified' : 'FAILED'}',
    '**GCP conformance claim:** blocked',
    '**Package:** `${package.packageSha256}`',
    '**Schedule commitment:** `${package.contract.scheduleCommitmentSha256}`',
    '**Boundary plan:** `${package.boundaryPlan.planSha256}`',
    '',
    '## Operational governance lanes',
    '',
    '| Lane | State |',
    '| --- | --- |',
    for (final entry in assessment.lanes.entries)
      '| ${entry.key} | ${entry.value} |',
    '',
    '## Bounded counts',
    '',
    '| Counter | Value |',
    '| --- | ---: |',
    for (final entry in assessment.counts.entries)
      '| ${entry.key} | ${entry.value} |',
    '',
    '## Mutation detection',
    '',
    '| Fixture | Expected | Observed | Findings |',
    '| --- | --- | --- | --- |',
    for (final entry in mutations.entries)
      '| ${entry.key} | ${expectedStatuses[entry.key]!.name} | '
          '${entry.value.status.name} | '
          '${entry.value.findings.map((item) => item.kind.name).toSet().join(', ')} |',
    '',
    '## Boundary',
    '',
    package.boundary,
    '',
  ].join('\n');
  final output = Directory('build/credibility_randomization_interim')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility randomization/interim firewall: '
    '${pass ? 'pass' : 'FAILED'}; status=${assessment.status.name}; '
    'lanes=${assessment.lanes.length}; assignments=${package.assignments.length}; '
    'mutations=${mutations.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

CredibilityRandomizationInterimPackage _currentPackage() {
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
    protocolAssessment: const CredibilityProtocolTransparencyVerifier().verify(
      ledger,
    ),
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

Map<String, RandomizationInterimGovernanceAssessment> _mutations(
  CredibilityRandomizationInterimPackage base,
  CredibilityRandomizationInterimVerifier verifier,
) {
  final replayedAssignment = base.assignments.first.copyWith(
    sequence: 2,
    eligibilityVerified: false,
  );
  final sponsorExposure = base.accessEvents.last.copyWith(
    interimComparativeResultVisible: true,
  );
  final priorAccess = base.accessEvents.last;
  final emergency = RandomizationAccessEvent(
    sequence: base.accessEvents.length + 1,
    eventId: 'mutation-emergency-unblinding',
    predecessorSha256: priorAccess.eventSha256,
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
  final conflicted = base.committeeMembers.first.copyWith(
    independentFromSponsor: false,
    conflictFree: false,
  );
  final driftedBoundary = base.boundaryPlan.boundaries.first.copyWith(
    cumulativeAlpha: 0.20,
  );
  final insufficientReview = base.interimReviews.single.copyWith(
    votingMemberIds: [base.committeeMembers.first.memberId],
  );
  final override = base.sponsorDecisions.single.copyWith(
    acceptedRecommendation: false,
    overrideAttempted: true,
  );
  final unaccepted = base.accessEvents.last.copyWith(accepted: false);
  return {
    'seed_future_assignment_exposure': verifier.verify(
      base.copyWith(
        contract: base.contract.copyWith(
          publicArtifactContainsSeed: true,
          publicArtifactContainsFutureAssignments: true,
        ),
      ),
    ),
    'schedule_commitment_forgery': verifier.verify(
      base.copyWith(
        custody: base.custody.copyWith(seedSecret: 'synthetic-bad-seed'),
      ),
    ),
    'generator_enrollment_role_collapse': verifier.verify(
      base.copyWith(
        contract: base.contract.copyWith(
          enrollmentActorId: base.contract.generatorActorId,
        ),
      ),
    ),
    'assignment_replay_and_ineligible': verifier.verify(
      base.copyWith(
        assignments: [replayedAssignment, ...base.assignments.skip(1)],
      ),
    ),
    'sponsor_interim_exposure': verifier.verify(
      base.copyWith(
        accessEvents: [
          ...base.accessEvents.take(base.accessEvents.length - 1),
          sponsorExposure,
        ],
      ),
    ),
    'invalid_emergency_unblinding': verifier.verify(
      base.copyWith(accessEvents: [...base.accessEvents, emergency]),
    ),
    'committee_conflict': verifier.verify(
      base.copyWith(committeeMembers: [conflicted]),
    ),
    'alpha_boundary_drift': verifier.verify(
      base.copyWith(
        boundaryPlan: base.boundaryPlan.copyWith(
          boundaries: [
            driftedBoundary,
            ...base.boundaryPlan.boundaries.skip(1),
          ],
        ),
      ),
    ),
    'interim_replay_and_quorum_failure': verifier.verify(
      base.copyWith(interimReviews: [insufficientReview, insufficientReview]),
    ),
    'sponsor_override': verifier.verify(
      base.copyWith(sponsorDecisions: [override]),
    ),
    'unaccepted_access_hold': verifier.verify(
      base.copyWith(
        accessEvents: [
          ...base.accessEvents.take(base.accessEvents.length - 1),
          unaccepted,
        ],
      ),
    ),
    'future_schema': verifier.verify(base.copyWith(schemaVersion: 2)),
    'explicit_revocation': verifier.verify(base.copyWith(revoked: true)),
  };
}
