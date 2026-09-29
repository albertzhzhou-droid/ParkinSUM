import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  final package = _currentPackage();
  const verifier = CredibilityBlindedReplicationVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final expectedStatuses = <String, BlindedReplicationStatus>{
    'expected_and_raw_data_leak': BlindedReplicationStatus.violated,
    'actor_authority_collapse': BlindedReplicationStatus.violated,
    'early_unblinding': BlindedReplicationStatus.violated,
    'environment_dependency_drift': BlindedReplicationStatus.held,
    'null_outcome_suppression': BlindedReplicationStatus.held,
    'tolerance_policy_switch': BlindedReplicationStatus.violated,
    'response_chain_clock_log_failure': BlindedReplicationStatus.violated,
    'custody_commitment_forgery': BlindedReplicationStatus.violated,
    'false_agreement_adjudication': BlindedReplicationStatus.violated,
    'future_schema': BlindedReplicationStatus.unknown,
    'explicit_revocation': BlindedReplicationStatus.revoked,
  };
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final pass =
      assessment.integrityVerified &&
      assessment.status == BlindedReplicationStatus.mechanicallyObserved &&
      assessment.discrepancies.isEmpty &&
      !assessment.canSupportScientificCredibility &&
      mutationsDetected;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_blinded_replication',
    'pass': pass,
    'assessment': assessment.toJson(),
    'mutation_results': {
      for (final entry in mutations.entries)
        entry.key: {
          'expected_status': expectedStatuses[entry.key]!.name,
          'status': entry.value.status.name,
          'finding_kinds': entry.value.findings
              .map((finding) => finding.kind.name)
              .toList(),
          'discrepancy_classes':
              entry.value.discrepancies
                  .map((item) => item.classification.name)
                  .toSet()
                  .toList()
                ..sort(),
        },
    },
    'expected_results_absent_from_capsule': !jsonEncode(
      package.capsule.toJson(),
    ).contains('expected_outcomes'),
    'synthetic_fixture_only': true,
    'not_external_scientific_replication': true,
    'not_scientific_or_clinical_validation': true,
    'not_regulatory_review': true,
    'not_clinical_or_patient_safety_evidence': true,
    'safety_boundary': package.boundary,
  };
  final markdown = <String>[
    '# Blinded independent replication capsule and discrepancy adjudication',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Status:** ${assessment.status.name}',
    '**Integrity:** ${assessment.integrityVerified ? 'verified' : 'FAILED'}',
    '**External scientific replication claim:** blocked',
    '**Capsule:** `${package.capsule.capsuleSha256}`',
    '**Package:** `${package.packageSha256}`',
    '',
    '## Evidence lanes',
    '',
    '| Lane | State |',
    '| --- | --- |',
    for (final entry in assessment.lanes.entries)
      '| ${entry.key} | ${entry.value} |',
    '',
    '## Retained outcomes',
    '',
    '| Outcome | Status |',
    '| --- | --- |',
    for (final outcome in package.custody.expectedOutcomes)
      '| ${outcome.outcomeId} | ${outcome.status.name} |',
    '',
    '## Mutation detection',
    '',
    '| Fixture | Expected | Observed | Findings / discrepancies |',
    '| --- | --- | --- | --- |',
    for (final entry in mutations.entries)
      '| ${entry.key} | ${expectedStatuses[entry.key]!.name} | '
          '${entry.value.status.name} | '
          '${[...entry.value.findings.map((item) => item.kind.name), ...entry.value.discrepancies.map((item) => 'discrepancy:${item.classification.name}')].join(', ')} |',
    '',
    '## Boundary',
    '',
    package.boundary,
    '',
  ].join('\n');

  final output = Directory('build/credibility_blinded_replication')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility blinded replication: ${pass ? 'pass' : 'FAILED'}; '
    'status=${assessment.status.name}; lanes=${assessment.lanes.length}; '
    'outcomes=${package.custody.expectedOutcomes.length}; '
    'mutations=${mutations.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

CredibilityBlindedReplicationPackage _currentPackage() {
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
  return CredibilityBlindedReplicationPackage.syntheticCurrent(
    protocolLedger: ledger,
    protocolAssessment: const CredibilityProtocolTransparencyVerifier().verify(
      ledger,
    ),
    executionAttestationSha256: execution.attestationSha256,
    configurationSha256: configuration.sha256Digest,
    algorithmSourceBundleSha256:
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
  );
}

Map<String, BlindedReplicationAssessment> _mutations(
  CredibilityBlindedReplicationPackage base,
  CredibilityBlindedReplicationVerifier verifier,
) {
  CredibilityBlindedReplicationPackage withResponse(
    IndependentReplicationResponse response, {
    ReplicationAdjudicationDecision decision =
        ReplicationAdjudicationDecision.agreementAccepted,
    List<ReplicationDiscrepancyClass> classes = const [],
  }) => base.copyWith(
    responses: [response],
    adjudicationEvents: [
      base.adjudicationEvents.single.copyWith(
        responseSha256: response.responseSha256,
        decision: decision,
        discrepancyClasses: classes,
        reason: decision == ReplicationAdjudicationDecision.agreementAccepted
            ? base.adjudicationEvents.single.reason
            : 'Synthetic discrepancy retained for adjudication.',
      ),
    ],
  );

  final actor = base.responses.single.copyWith(
    replicatorId: base.capsule.creatorId,
    independentlyAuthorized: false,
    replicatorAuthorityId: '',
  );
  final early = base.responses.single.copyWith(
    expectedResultsAccessedBeforeFinalization: true,
  );
  final environment = base.responses.single.copyWith(
    environmentSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    dependencyLockSha256:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  );
  final retained = base.responses.single.outcomes
      .where((item) => item.status != ReplicationOutcomeStatus.nullResult)
      .toList();
  final suppressed = base.responses.single.copyWith(outcomes: retained);
  final broken = base.responses.single.copyWith(
    predecessorResponseSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    finalizedAtUtc: '2026-08-18T01:05:00.000Z',
    monotonicEndMicros: 900000,
    privacyBoundedLogs: false,
    completeExecution: false,
  );
  final codeDrift = base.responses.single.copyWith(
    codeSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );
  final prior = base.adjudicationEvents.single;
  final revocation = ReplicationAdjudicationEvent(
    sequence: 2,
    eventId: 'mutation-explicit-revocation',
    predecessorSha256: prior.eventSha256,
    responseSha256: base.responses.single.responseSha256,
    actorId: 'synthetic-independent-adjudicator',
    authorityId: 'synthetic-adjudication-authority',
    decision: ReplicationAdjudicationDecision.revoked,
    discrepancyClasses: const [],
    reason: 'Synthetic explicit revocation.',
    occurredAtUtc: '2026-08-18T01:30:00.000Z',
    accepted: true,
  );

  return {
    'expected_and_raw_data_leak': verifier.verify(
      base.copyWith(
        capsule: base.capsule.copyWith(
          containsExpectedResultValues: true,
          containsRawParticipantData: true,
        ),
      ),
    ),
    'actor_authority_collapse': verifier.verify(withResponse(actor)),
    'early_unblinding': verifier.verify(
      withResponse(early).copyWith(
        custody: base.custody.copyWith(
          releasedAtUtc: '2026-08-18T01:15:00.000Z',
        ),
      ),
    ),
    'environment_dependency_drift': verifier.verify(
      withResponse(
        environment,
        decision: ReplicationAdjudicationDecision.discrepancyHeld,
        classes: const [
          ReplicationDiscrepancyClass.environment,
          ReplicationDiscrepancyClass.dependency,
        ],
      ),
    ),
    'null_outcome_suppression': verifier.verify(
      withResponse(
        suppressed,
        decision: ReplicationAdjudicationDecision.discrepancyHeld,
        classes: const [ReplicationDiscrepancyClass.analysis],
      ),
    ),
    'tolerance_policy_switch': verifier.verify(
      base.copyWith(
        comparisonTolerancePolicySha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    ),
    'response_chain_clock_log_failure': verifier.verify(withResponse(broken)),
    'custody_commitment_forgery': verifier.verify(
      base.copyWith(
        custody: base.custody.copyWith(commitmentSalt: 'forged-salt'),
      ),
    ),
    'false_agreement_adjudication': verifier.verify(withResponse(codeDrift)),
    'future_schema': verifier.verify(base.copyWith(schemaVersion: 2)),
    'explicit_revocation': verifier.verify(
      base.copyWith(adjudicationEvents: [prior, revocation]),
    ),
  };
}
