import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  final ledger = _currentLedger();
  const verifier = CredibilityProtocolTransparencyVerifier();
  final assessment = verifier.verify(ledger);
  final mutations = _mutations(ledger, verifier);
  final expectedStatuses = <String, ProtocolTransparencyStatus>{
    'broken_chain_and_clock_replay': ProtocolTransparencyStatus.violated,
    'post_result_prospective_claim': ProtocolTransparencyStatus.violated,
    'correction_history_erasure': ProtocolTransparencyStatus.violated,
    'planned_outcome_omission': ProtocolTransparencyStatus.violated,
    'review_and_role_escalation': ProtocolTransparencyStatus.violated,
    'rejected_event_hold': ProtocolTransparencyStatus.held,
    'future_schema': ProtocolTransparencyStatus.unknown,
    'explicit_revocation': ProtocolTransparencyStatus.revoked,
  };
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final pass =
      assessment.integrityVerified &&
      assessment.status == ProtocolTransparencyStatus.mechanicallyObserved &&
      !assessment.canClaimGcpConformance &&
      assessment.lastAcceptedSequence == ledger.events.length &&
      mutationsDetected;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_protocol_transparency',
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
          'last_accepted_sequence': entry.value.lastAcceptedSequence,
        },
    },
    'not_a_clinical_trial_registry': true,
    'not_gcp_conformance': true,
    'not_scientific_validation': true,
    'not_regulatory_review': true,
    'not_clinical_or_patient_safety_evidence': true,
    'safety_boundary': ledger.boundary,
  };
  final markdown = <String>[
    '# Protocol amendment, deviation and result-transparency ledger',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Ledger status:** ${assessment.status.name}',
    '**Integrity:** ${assessment.integrityVerified ? 'verified' : 'FAILED'}',
    '**GCP conformance claim:** blocked',
    '**Ledger:** `${ledger.ledgerSha256}`',
    '**Execution attestation:** `${ledger.executionAttestationSha256}`',
    '**Last accepted sequence:** ${assessment.lastAcceptedSequence}',
    '',
    '## Event timeline',
    '',
    '| Seq | Type | Prospective | Result visibility | Review |',
    '| ---: | --- | --- | --- | --- |',
    for (final event in ledger.events)
      '| ${event.sequence} | ${event.type.name} | '
          '${event.assertedProspective} | '
          '${event.visibleResults.map((item) => item.name).join(', ')} | '
          '${event.reviewDecision.name} |',
    '',
    '## Outcome transparency',
    '',
    '| Outcome | Planned | Status |',
    '| --- | --- | --- |',
    for (final outcome in ledger.outcomes)
      '| ${outcome.outcomeId} | ${outcome.originallyPlanned} | '
          '${outcome.status.name} |',
    '',
    '## Mutation detection',
    '',
    '| Fixture | Expected | Observed | Findings |',
    '| --- | --- | --- | --- |',
    for (final entry in mutations.entries)
      '| ${entry.key} | ${expectedStatuses[entry.key]!.name} | '
          '${entry.value.status.name} | '
          '${entry.value.findings.map((finding) => finding.kind.name).join(', ')} |',
    '',
    '## Boundary',
    '',
    ledger.boundary,
    '',
  ].join('\n');

  final output = Directory('build/credibility_protocol_transparency')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility protocol transparency: ${pass ? 'pass' : 'FAILED'}; '
    'status=${assessment.status.name}; events=${ledger.events.length}; '
    'outcomes=${ledger.outcomes.length}; mutations=${mutations.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

CredibilityProtocolTransparencyLedger _currentLedger() {
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

Map<String, ProtocolTransparencyAssessment> _mutations(
  CredibilityProtocolTransparencyLedger base,
  CredibilityProtocolTransparencyVerifier verifier,
) {
  final chain = [...base.events];
  chain[2] = chain[2].copyWith(
    predecessorSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    occurredAtUtc: '2026-08-18T00:01:00.000Z',
    observedAtUtc: '2026-08-18T00:01:00.000Z',
  );

  final correction = [...base.events];
  correction[4] = correction[4].copyWith(
    supersededValueSha256: 'missing',
    replacementValueSha256: 'missing',
    sourceRecordSha256: 'missing',
  );

  final omitted = [...base.outcomes];
  omitted[0] = omitted[0].copyWith(status: ProtocolOutcomeStatus.omitted);

  final review = [...base.events];
  review[1] = review[1].copyWith(
    reviewerId: '',
    reviewDecision: ProtocolReviewDecision.disputed,
    authorRole: ProtocolActorRole.observer,
  );

  final rejected = [...base.events];
  rejected[4] = rejected[4].copyWith(
    reviewDecision: ProtocolReviewDecision.rejected,
    accepted: false,
  );

  return {
    'broken_chain_and_clock_replay': verifier.verify(
      base.copyWith(events: chain),
    ),
    'post_result_prospective_claim': verifier.verify(
      base.copyWith(events: [...base.events, _postResultAmendment(base)]),
    ),
    'correction_history_erasure': verifier.verify(
      base.copyWith(events: correction),
    ),
    'planned_outcome_omission': verifier.verify(
      base.copyWith(outcomes: omitted),
    ),
    'review_and_role_escalation': verifier.verify(
      base.copyWith(events: review),
    ),
    'rejected_event_hold': verifier.verify(base.copyWith(events: rejected)),
    'future_schema': verifier.verify(base.copyWith(schemaVersion: 2)),
    'explicit_revocation': verifier.verify(
      base.copyWith(events: [...base.events, _revocation(base)]),
    ),
  };
}

ProtocolTransparencyEvent _postResultAmendment(
  CredibilityProtocolTransparencyLedger base,
) => ProtocolTransparencyEvent(
  sequence: base.events.length + 1,
  eventId: 'mutation-post-result-amendment',
  predecessorSha256: base.events.last.eventSha256,
  type: ProtocolTransparencyEventType.amendment,
  authorId: 'synthetic-protocolOwner',
  authorRole: ProtocolActorRole.protocolOwner,
  authorityId: 'synthetic-governance-authority',
  reviewerId: 'synthetic-independent-reviewer',
  reviewDecision: ProtocolReviewDecision.accepted,
  reason: 'Mutation attempts to create false prospective status.',
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

ProtocolTransparencyEvent _revocation(
  CredibilityProtocolTransparencyLedger base,
) => ProtocolTransparencyEvent(
  sequence: base.events.length + 1,
  eventId: 'mutation-explicit-revocation',
  predecessorSha256: base.events.last.eventSha256,
  type: ProtocolTransparencyEventType.revocation,
  authorId: 'synthetic-independent-reviewer',
  authorRole: ProtocolActorRole.independentReviewer,
  authorityId: 'synthetic-governance-authority',
  reviewerId: 'synthetic-independent-reviewer',
  reviewDecision: ProtocolReviewDecision.accepted,
  reason: 'Synthetic explicit revocation.',
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
