import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  final configuration = AlgorithmConfigurationIdentity.defaults();
  final plan = ProspectiveModelCredibilityPlan.current(
    manifest: MechanisticApplicabilityManifest.current,
    configurationSha256: configuration.sha256Digest,
  );
  final attestation = CredibilityEvidenceExecutionAttestation.syntheticCurrent(
    prospectivePlanSha256: plan.planSha256,
    manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
    configurationSha256: configuration.sha256Digest,
    algorithmSourceBundleSha256:
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
  );
  const verifier = CredibilityEvidenceIndependenceVerifier();
  final assessment = verifier.verify(attestation);
  final mutations = _mutationAssessments(attestation, verifier);
  final mutationsDetected = mutations.values.every(
    (assessment) =>
        assessment.status == EvidenceIndependenceStatus.violated &&
        assessment.findings.isNotEmpty,
  );
  final pass =
      assessment.integrityVerified &&
      assessment.findings.isEmpty &&
      assessment.status == EvidenceIndependenceStatus.mechanicallyObserved &&
      !assessment.canSupportScientificCredibility &&
      mutationsDetected;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_evidence_execution',
    'pass': pass,
    'assessment': assessment.toJson(),
    'mutation_results': {
      for (final entry in mutations.entries)
        entry.key: {
          'status': entry.value.status.name,
          'finding_kinds': entry.value.findings
              .map((finding) => finding.kind.name)
              .toList(),
        },
    },
    'not_representativeness_evidence': true,
    'not_scientific_validation': true,
    'not_model_qualification': true,
    'not_regulatory_review': true,
    'not_external_approval': true,
    'safety_boundary':
        'This gate verifies an offline synthetic execution and adversarial '
        'leakage fixtures. It does not validate a model, dataset, population, '
        'clinical outcome, or patient-specific decision.',
  };
  final markdown = <String>[
    '# Credibility-evidence execution and leakage gate',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Execution status:** ${assessment.status.name}',
    '**Integrity:** ${assessment.integrityVerified ? 'verified' : 'FAILED'}',
    '**Scientific credibility:** ${assessment.canSupportScientificCredibility ? 'eligible' : 'blocked'}',
    '**Attestation:** `${attestation.attestationSha256}`',
    '**Prospective plan:** `${attestation.prospectivePlanSha256}`',
    '**Configuration:** `${attestation.configurationSha256}`',
    '',
    '## Independence dimensions',
    '',
    '| Dimension | Status |',
    '| --- | --- |',
    for (final dimension in EvidenceIndependenceDimension.values)
      '| ${dimension.name} | ${assessment.dimensionStatuses[dimension]!.name} |',
    '',
    '## Mutation detection',
    '',
    '| Fixture | Status | Findings |',
    '| --- | --- | --- |',
    for (final entry in mutations.entries)
      '| ${entry.key} | ${entry.value.status.name} | '
          '${entry.value.findings.map((finding) => finding.kind.name).join(', ')} |',
    '',
    '## Boundary',
    '',
    report['safety_boundary']! as String,
    '',
  ].join('\n');

  final output = Directory('build/credibility_evidence_execution')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility evidence execution: ${pass ? 'pass' : 'FAILED'}; '
    'status=${assessment.status.name}; dimensions='
    '${assessment.dimensionStatuses.length}; mutations=${mutations.length}; '
    'findings=${assessment.findings.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

Map<String, EvidenceIndependenceAssessment> _mutationAssessments(
  CredibilityEvidenceExecutionAttestation base,
  CredibilityEvidenceIndependenceVerifier verifier,
) {
  final first = base.records.first;
  final last = base.records.last;
  final overlap = base.copyWith(
    records: [
      ...base.records.take(base.records.length - 1),
      last.copyWith(
        subjectGroupId: first.subjectGroupId,
        siteId: first.siteId,
        acquisitionId: first.acquisitionId,
      ),
    ],
  );
  final preprocessing = base.copyWith(
    transformations: [
      base.transformations.first.copyWith(
        fittedOnSplits: const [
          EvidenceSplitRole.fit,
          EvidenceSplitRole.lockedTest,
        ],
        usesTarget: true,
        usesFutureInformation: true,
      ),
    ],
  );
  final earlyHoldout = base.copyWith(
    accessEvents: base.accessEvents.map((event) {
      if (event.action == EvidenceAccessAction.lockedHoldoutRead) {
        return event.copyWith(occurredAtUtc: '2026-08-18T00:01:00.000Z');
      }
      return event;
    }).toList(),
  );
  final unauthorized = base.copyWith(
    accessEvents: base.accessEvents.map((event) {
      if (event.action == EvidenceAccessAction.rawRead) {
        return event.copyWith(authorized: false);
      }
      return event;
    }).toList(),
  );
  final omission = base.copyWith(
    reportedOutcomeIds: base.reportedOutcomeIds.take(1).toList(),
  );
  return {
    'cross_split_overlap': verifier.verify(overlap),
    'preprocessing_leakage': verifier.verify(preprocessing),
    'early_holdout_access': verifier.verify(earlyHoldout),
    'unauthorized_access': verifier.verify(unauthorized),
    'selective_outcome_omission': verifier.verify(omission),
  };
}
