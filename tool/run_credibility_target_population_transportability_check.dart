import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_bayesian_multisource_model_criticism.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_randomization_interim_firewall.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/credibility_target_population_transportability.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';
import 'package:parkinsum_companion/domain/usecases/adaptive_design_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_borrowing_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_multisource_model_criticism_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/target_population_transportability_simulator.dart';

void main() {
  final package = TargetPopulationTransportabilityFixture.build(
    multisourcePackage: _currentMultisourcePackage(),
  );
  const verifier = CredibilityTargetPopulationTransportabilityVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final independent = _runIndependentOracle(package);
  final expectedStatuses = <String, TargetTransportabilityStatus>{
    for (final id in mutations.keys) id: TargetTransportabilityStatus.held,
  }..['explicit_revocation'] = TargetTransportabilityStatus.revoked;
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final pass =
      assessment.status == TargetTransportabilityStatus.mechanicallyObserved &&
      assessment.findings.isEmpty &&
      assessment.lanes.length == 9 &&
      assessment.counts['trialRecords'] == 260 &&
      assessment.counts['targetRecords'] == 360 &&
      assessment.counts['assumptions'] == 7 &&
      assessment.counts['manufacturedCases'] == 4 &&
      assessment.counts['scenarios'] == 7 &&
      assessment.counts['totalRepetitions'] == 70000 &&
      assessment.counts['independentCases'] == 4 &&
      mutationsDetected &&
      independent.pass;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_target_population_transportability',
    'pass': pass,
    'assessment': assessment.toJson(),
    'independent_oracle': independent.toJson(),
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
    'synthetic_fixture_only': true,
    'not_identification_or_transportability_proof': true,
    'not_clinical_validation_or_effect': true,
    'not_regulatory_review_or_acceptance': true,
  };
  final outputDirectory = Directory(
    'build/credibility_target_population_transportability',
  )..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  File(
    '${outputDirectory.path}/latest.json',
  ).writeAsStringSync('${encoder.convert(report)}\n');
  File('${outputDirectory.path}/latest.md').writeAsStringSync(
    _markdown(
      pass: pass,
      assessment: assessment,
      independent: independent,
      mutationCount: mutations.length,
    ),
  );
  stdout.writeln(
    'Credibility target-population transportability: '
    '${pass ? 'pass' : 'FAILED'}; status=${assessment.status.name}; '
    'lanes=${assessment.lanes.length}; trial=260; target=360; '
    'scenarios=7; repetitions=70000; mutations=${mutations.length}; '
    'independent=${independent.pass}.',
  );
  stdout.writeln('Report: ${outputDirectory.path}/latest.json');
  stdout.writeln('Report: ${outputDirectory.path}/latest.md');
  if (!pass) exitCode = 1;
}

Map<String, TargetTransportabilityAssessment> _mutations(
  CredibilityTargetPopulationTransportabilityPackage base,
  CredibilityTargetPopulationTransportabilityVerifier verifier,
) {
  final firstTarget = base.records.firstWhere(
    (record) => record.role == TargetSampleRole.targetPopulation,
  );
  final supportResult = base.operatingResults.firstWhere(
    (result) =>
        base.scenarios
            .singleWhere((scenario) => scenario.scenarioId == result.scenarioId)
            .family ==
        TransportScenarioFamily.supportViolation,
  );
  final independentCases = {
    for (final entry in base.independentReplication.cases.entries)
      entry.key: Map<String, double>.from(entry.value),
  };
  independentCases['both_models_correct']!['augmented_inverse_odds'] = 0.9;
  final mutations =
      <String, CredibilityTargetPopulationTransportabilityPackage>{
        'post_result_target_freeze': base.copyWith(
          contract: base.contract.copyWith(
            targetSampleFrozenAtUtc: '2026-08-26T16:30:00Z',
          ),
        ),
        'causal_contrast_omission': base.copyWith(
          contract: base.contract.copyWith(causalContrast: ''),
        ),
        'causal_graph_omission': base.copyWith(
          contract: base.contract.copyWith(graphEdges: const []),
        ),
        'identification_assumption_omission': base.copyWith(
          contract: base.contract.copyWith(
            assumptions: base.contract.assumptions.skip(1).toList(),
          ),
        ),
        'record_identity_collision': base.copyWith(
          records: [
            base.records.first,
            base.records[1].copyWith(recordId: base.records.first.recordId),
            ...base.records.skip(2),
          ],
        ),
        'target_outcome_leakage': base.copyWith(
          records: [
            for (final record in base.records)
              if (record.recordId == firstTarget.recordId)
                record.copyWith(outcome: 0.3)
              else
                record,
          ],
        ),
        'target_covariate_omission': base.copyWith(
          records: [
            base.records.first.copyWith(covariates: const {}),
            ...base.records.skip(1),
          ],
        ),
        'real_record_claim': base.copyWith(
          records: [
            base.records.first.copyWith(synthetic: false),
            ...base.records.skip(1),
          ],
        ),
        'support_violation_laundering': base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            supportViolationStrata: const ['stratum-6'],
          ),
        ),
        'unknown_covariate_laundering': base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            unknownTargetCovariates: const ['unmeasured-effect-modifier'],
          ),
        ),
        'weight_cap_breach': base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            maximumInverseOddsWeight: 8,
          ),
        ),
        'weighted_balance_drift': base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            maximumSmdAfterWeighting: 0.2,
          ),
        ),
        'estimator_omission': base.copyWith(
          estimatorEstimates: base.estimatorEstimates.skip(1).toList(),
        ),
        'estimator_arithmetic_drift': base.copyWith(
          estimatorEstimates: [
            base.estimatorEstimates.first.copyWith(estimate: 0.3),
            ...base.estimatorEstimates.skip(1),
          ],
        ),
        'dual_misspecification_overclaim': base.copyWith(
          estimatorEstimates: [
            for (final estimate in base.estimatorEstimates)
              if (estimate.caseId == 'both_models_misspecified' &&
                  estimate.estimator ==
                      TransportEstimatorKind.augmentedInverseOdds)
                estimate.copyWith(estimate: 0.18)
              else
                estimate,
          ],
        ),
        'truncation_sensitivity_omission': base.copyWith(
          truncationSensitivity: const [],
        ),
        'scenario_omission': base.copyWith(
          scenarios: base.scenarios.skip(1).toList(),
        ),
        'operating_bias_drift': base.copyWith(
          operatingResults: [
            base.operatingResults.first.copyWith(bias: 0.7),
            ...base.operatingResults.skip(1),
          ],
        ),
        'nonidentifiable_estimate': base.copyWith(
          operatingResults: [
            for (final result in base.operatingResults)
              if (identical(result, supportResult))
                result.copyWith(
                  status: TransportOperatingStatus.estimated,
                  meanEstimate: 0.18,
                  bias: 0,
                  coverage95: 0.95,
                )
              else
                result,
          ],
        ),
        'independent_script_drift': base.copyWith(
          independentReplication: base.independentReplication.copyWith(
            scriptSha256: '0' * 64,
          ),
        ),
        'independent_result_drift': base.copyWith(
          independentReplication: base.independentReplication.copyWith(
            cases: independentCases,
          ),
        ),
        'runtime_identity_drift': base.copyWith(configurationSha256: '0' * 64),
        'result_retention_disabled': base.copyWith(
          allPrespecifiedResultsRetained: false,
        ),
        'boundary_overclaim': base.copyWith(boundary: 'clinically valid'),
        'future_schema': base.copyWith(schemaVersion: 2),
        'explicit_revocation': base.copyWith(revoked: true),
      };
  return {
    for (final entry in mutations.entries)
      entry.key: verifier.verify(entry.value),
  };
}

_IndependentOracleResult _runIndependentOracle(
  CredibilityTargetPopulationTransportabilityPackage package,
) {
  final script = File(package.independentReplication.scriptPath);
  if (!script.existsSync()) {
    return const _IndependentOracleResult(
      pass: false,
      runtime: 'missing',
      scriptSha256: 'missing',
      detail: 'independent script missing',
    );
  }
  final scriptSha256 = sha256.convert(script.readAsBytesSync()).toString();
  final result = Process.runSync('python3', [script.path]);
  if (result.exitCode != 0) {
    return _IndependentOracleResult(
      pass: false,
      runtime: 'python3',
      scriptSha256: scriptSha256,
      detail: 'exit=${result.exitCode}: ${result.stderr}',
    );
  }
  try {
    final decoded =
        jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    final cases = decoded['cases'] as Map<String, dynamic>;
    final expected = package.independentReplication.cases;
    final casePass = expected.entries.every((caseEntry) {
      final observed = cases[caseEntry.key] as Map<String, dynamic>?;
      return observed != null &&
          caseEntry.value.entries.every(
            (entry) =>
                observed[entry.key] is num &&
                ((observed[entry.key] as num).toDouble() - entry.value).abs() <=
                    package.independentReplication.tolerance,
          );
    });
    final pass =
        scriptSha256 == package.independentReplication.scriptSha256 &&
        decoded['language'] == 'python-stdlib-only' &&
        decoded['imports_production_code'] == false &&
        decoded['imports_golden_outputs'] == false &&
        casePass;
    return _IndependentOracleResult(
      pass: pass,
      runtime: 'python3',
      scriptSha256: scriptSha256,
      detail: pass
          ? 'four manufactured cases reproduced independently'
          : 'identity, boundary, or manufactured values differed',
    );
  } catch (error) {
    return _IndependentOracleResult(
      pass: false,
      runtime: 'python3',
      scriptSha256: scriptSha256,
      detail: 'invalid output: $error',
    );
  }
}

String _markdown({
  required bool pass,
  required TargetTransportabilityAssessment assessment,
  required _IndependentOracleResult independent,
  required int mutationCount,
}) =>
    '''# Target-population transportability, positivity, and doubly robust estimation

**Result:** ${pass ? 'PASS' : 'FAILED'}
**Status:** `${assessment.status.name}`
**Package:** `${assessment.package.packageSha256}`
**Trial records:** ${assessment.counts['trialRecords']}
**Target records:** ${assessment.counts['targetRecords']}
**Identification assumptions:** ${assessment.counts['assumptions']}
**Manufactured cases:** ${assessment.counts['manufacturedCases']}
**Scenarios:** ${assessment.counts['scenarios']}
**Total repetitions:** ${assessment.counts['totalRepetitions']}
**Mutation packages:** $mutationCount
**Independent Python:** ${independent.pass ? 'PASS' : 'FAILED'}

## Boundary

${assessment.package.boundary}
''';

final class _IndependentOracleResult {
  final bool pass;
  final String runtime;
  final String scriptSha256;
  final String detail;

  const _IndependentOracleResult({
    required this.pass,
    required this.runtime,
    required this.scriptSha256,
    required this.detail,
  });

  Map<String, Object?> toJson() => {
    'pass': pass,
    'runtime': runtime,
    'script_sha256': scriptSha256,
    'detail': detail,
  };
}

CredibilityBayesianMultisourceModelCriticismPackage
_currentMultisourcePackage() {
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
  final randomization = CredibilityRandomizationInterimPackage.syntheticCurrent(
    statisticalPackage: statistics,
    configurationSha256: configuration.sha256Digest,
    algorithmSourceBundleSha256:
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
  );
  final adaptive = AdaptiveDesignSyntheticFixture.build(
    randomizationPackage: randomization,
  );
  final bayesian = BayesianBorrowingSyntheticFixture.build(
    adaptivePackage: adaptive,
  );
  return BayesianMultisourceModelCriticismFixture.build(
    bayesianPackage: bayesian,
  );
}
