import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  final package = _currentPackage();
  const verifier = CredibilityStatisticalAnalysisVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final expectedStatuses = <String, StatisticalGovernanceStatus>{
    'estimand_incomplete': StatisticalGovernanceStatus.violated,
    'analysis_and_missing_drift': StatisticalGovernanceStatus.violated,
    'alpha_and_multiplicity_failure': StatisticalGovernanceStatus.violated,
    'interval_p_value_conflict': StatisticalGovernanceStatus.violated,
    'denominator_drift': StatisticalGovernanceStatus.violated,
    'result_suppression': StatisticalGovernanceStatus.violated,
    'sensitivity_estimand_switch': StatisticalGovernanceStatus.violated,
    'post_result_contract_change': StatisticalGovernanceStatus.violated,
    'deviation_chain_break': StatisticalGovernanceStatus.violated,
    'unaccepted_deviation': StatisticalGovernanceStatus.held,
    'future_schema': StatisticalGovernanceStatus.unknown,
    'explicit_revocation': StatisticalGovernanceStatus.revoked,
  };
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final retainedStatuses = package.results.map((item) => item.status).toSet();
  final retainedBoundary = {
    StatisticalResultStatus.reported,
    StatisticalResultStatus.nullResult,
    StatisticalResultStatus.inconclusive,
    StatisticalResultStatus.failed,
    StatisticalResultStatus.adverse,
  }.difference(retainedStatuses).isEmpty;
  final pass =
      assessment.integrityVerified &&
      assessment.status == StatisticalGovernanceStatus.mechanicallyObserved &&
      assessment.lanes.length == 7 &&
      retainedBoundary &&
      !assessment.canSupportClinicalInference &&
      mutationsDetected;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_statistical_analysis',
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
    'retains_null_inconclusive_failed_and_adverse_results': retainedBoundary,
    'synthetic_fixture_only': true,
    'not_statistical_or_clinical_validation': true,
    'not_regulatory_review': true,
    'not_clinical_or_patient_safety_evidence': true,
    'safety_boundary': package.boundary,
  };
  final markdown = <String>[
    '# Statistical analysis, error control, and uncertainty governance',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Status:** ${assessment.status.name}',
    '**Integrity:** ${assessment.integrityVerified ? 'verified' : 'FAILED'}',
    '**Clinical inference:** blocked',
    '**Package:** `${package.packageSha256}`',
    '',
    '## Evidence lanes',
    '',
    '| Lane | State |',
    '| --- | --- |',
    for (final entry in assessment.lanes.entries)
      '| ${entry.key} | ${entry.value} |',
    '',
    '## Retained outcome states',
    '',
    '| Status | Count |',
    '| --- | ---: |',
    for (final entry in assessment.outcomeStatusCounts.entries)
      '| ${entry.key.name} | ${entry.value} |',
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

  final output = Directory('build/credibility_statistical_analysis')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility statistical analysis: ${pass ? 'pass' : 'FAILED'}; '
    'status=${assessment.status.name}; lanes=${assessment.lanes.length}; '
    'results=${package.results.length}; mutations=${mutations.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

CredibilityStatisticalAnalysisPackage _currentPackage() {
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
  return CredibilityStatisticalAnalysisPackage.syntheticCurrent(
    prospectivePlanSha256: plan.planSha256,
    protocolLedgerSha256: ledger.ledgerSha256,
    replicationPackageSha256: replication.packageSha256,
    configurationSha256: configuration.sha256Digest,
    algorithmSourceBundleSha256:
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
  );
}

Map<String, StatisticalGovernanceAssessment> _mutations(
  CredibilityStatisticalAnalysisPackage base,
  CredibilityStatisticalAnalysisVerifier verifier,
) {
  final incompleteEstimand = base.estimands.single.copyWith(
    scientificQuestion: '',
    intercurrentEvents: const [],
  );
  final driftedResult = base.results.first.copyWith(
    analysisSetId: 'analysis_set.post_result_subset',
    missingDataMethodId: 'missing.post_result_complete_case',
  );
  final conflictingResult = base.results.first.copyWith(
    pValue: 0.20,
    multiplicityAdjustedPValue: 0.20,
  );
  final denominatorDrift = base.results.first.copyWith(denominator: 50);
  final sensitivitySwitch = base.sensitivityResults.first.copyWith(
    estimandId: 'estimand.changed_after_results',
    prospectivelyPlanned: false,
  );
  final postResultChange = base.deviationEvents.single.copyWith(
    resultsVisible: true,
    affectedContractFields: const ['estimand', 'alpha'],
  );
  final brokenDeviation = base.deviationEvents.single.copyWith(
    sequence: 2,
    predecessorSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    occurredAtUtc: 'not-a-clock',
  );
  return {
    'estimand_incomplete': verifier.verify(
      base.copyWith(estimands: [incompleteEstimand]),
    ),
    'analysis_and_missing_drift': verifier.verify(
      base.copyWith(results: [driftedResult, ...base.results.skip(1)]),
    ),
    'alpha_and_multiplicity_failure': verifier.verify(
      base.copyWith(
        errorControl: base.errorControl.copyWith(
          overallAlpha: 0.10,
          confidenceLevel: 0.90,
          multiplicityMethod: StatisticalMultiplicityMethod.noneSinglePrimary,
        ),
      ),
    ),
    'interval_p_value_conflict': verifier.verify(
      base.copyWith(results: [conflictingResult, ...base.results.skip(1)]),
    ),
    'denominator_drift': verifier.verify(
      base.copyWith(results: [denominatorDrift, ...base.results.skip(1)]),
    ),
    'result_suppression': verifier.verify(
      base.copyWith(results: base.results.skip(1).toList()),
    ),
    'sensitivity_estimand_switch': verifier.verify(
      base.copyWith(
        sensitivityResults: [
          sensitivitySwitch,
          ...base.sensitivityResults.skip(1),
        ],
      ),
    ),
    'post_result_contract_change': verifier.verify(
      base.copyWith(deviationEvents: [postResultChange]),
    ),
    'deviation_chain_break': verifier.verify(
      base.copyWith(deviationEvents: [brokenDeviation]),
    ),
    'unaccepted_deviation': verifier.verify(
      base.copyWith(
        deviationEvents: [
          base.deviationEvents.single.copyWith(accepted: false),
        ],
      ),
    ),
    'future_schema': verifier.verify(base.copyWith(schemaVersion: 2)),
    'explicit_revocation': verifier.verify(base.copyWith(revoked: true)),
  };
}
