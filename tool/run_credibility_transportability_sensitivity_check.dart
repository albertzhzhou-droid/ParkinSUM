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
import 'package:parkinsum_companion/domain/entities/credibility_transportability_sensitivity.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';
import 'package:parkinsum_companion/domain/usecases/adaptive_design_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_borrowing_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_multisource_model_criticism_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/target_population_transportability_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/transportability_bias_function_sensitivity_simulator.dart';

void main() {
  final package = TransportabilityBiasFunctionSensitivityFixture.build(
    transportPackage: TargetPopulationTransportabilityFixture.build(
      multisourcePackage: _currentMultisourcePackage(),
    ),
  );
  const verifier = CredibilityTransportabilitySensitivityVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final independent = _runIndependentOracle(package);
  final expectedStatuses = <String, TransportSensitivityStatus>{
    for (final id in mutations.keys) id: TransportSensitivityStatus.held,
  }..['explicit_revocation'] = TransportSensitivityStatus.revoked;
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final pass =
      assessment.status == TransportSensitivityStatus.mechanicallyObserved &&
      assessment.findings.isEmpty &&
      assessment.lanes.length == 10 &&
      assessment.counts['axes'] == 5 &&
      assessment.counts['elicitationRecords'] == 3 &&
      assessment.counts['gridPoints'] == 2625 &&
      assessment.counts['admissiblePoints'] == 2375 &&
      assessment.counts['excludedPoints'] == 250 &&
      assessment.counts['localCases'] == 6 &&
      assessment.counts['globalIndices'] == 5 &&
      assessment.counts['scenarios'] == 8 &&
      assessment.counts['totalRepetitions'] == 80000 &&
      mutationsDetected &&
      independent.pass;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_transportability_sensitivity',
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
    'cannot_establish_conditional_transportability': true,
    'structural_positivity_not_repaired': true,
    'not_clinical_validation_or_effect': true,
    'not_regulatory_review_or_acceptance': true,
  };
  final outputDirectory = Directory(
    'build/credibility_transportability_sensitivity',
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
    'Credibility transportability sensitivity: '
    '${pass ? 'pass' : 'FAILED'}; status=${assessment.status.name}; '
    'lanes=${assessment.lanes.length}; grid=2625; admissible=2375; '
    'scenarios=8; repetitions=80000; mutations=${mutations.length}; '
    'independent=${independent.pass}.',
  );
  stdout.writeln('Report: ${outputDirectory.path}/latest.json');
  stdout.writeln('Report: ${outputDirectory.path}/latest.md');
  if (!pass) exitCode = 1;
}

Map<String, TransportSensitivityAssessment> _mutations(
  CredibilityTransportabilitySensitivityPackage base,
  CredibilityTransportabilitySensitivityVerifier verifier,
) {
  final excluded = base.gridPoints.firstWhere((point) => !point.admissible);
  final positivity = base.operatingResults.singleWhere(
    (result) => result.scenarioId == 'structural-positivity-failure',
  );
  final noConsensus = base.operatingResults.singleWhere(
    (result) => result.scenarioId == 'incompatible-elicitation',
  );
  final dual = base.operatingResults.singleWhere(
    (result) => result.scenarioId == 'dual-model-misspecification',
  );
  TransportSensitivityOperatingResult launder(
    TransportSensitivityOperatingResult result,
  ) => TransportSensitivityOperatingResult(
    scenarioId: result.scenarioId,
    status: SensitivityOperatingStatus.estimated,
    repetitions: result.repetitions,
    meanAdjustedEstimate: 0.18,
    bias: 0,
    coverage95: 0.95,
    decisionTippingProbability: 0,
    nullCrossingProbability: 0,
    monteCarloStandardError: 0.0004,
    disposition: 'laundered',
  );
  final changedCases = Map<String, double>.from(
    base.independentReplication.cases,
  )..['no_violation'] = 0.9;
  final mutations = <String, CredibilityTransportabilitySensitivityPackage>{
    'post_result_elicitation_freeze': base.copyWith(
      contract: base.contract.copyWith(
        elicitationFrozenAtUtc: '2026-08-27T12:30:00Z',
      ),
    ),
    'target_estimand_omission': base.copyWith(
      contract: base.contract.copyWith(targetEstimand: ''),
    ),
    'sign_convention_drift': base.copyWith(
      contract: base.contract.copyWith(biasFunctionDefinition: 'unknown'),
    ),
    'reference_control_drift': base.copyWith(
      contract: base.contract.copyWith(referenceControlMean: 0.5),
    ),
    'axis_omission': base.copyWith(
      contract: base.contract.copyWith(
        axes: base.contract.axes.skip(1).toList(),
      ),
    ),
    'axis_range_drift': base.copyWith(
      contract: base.contract.copyWith(
        axes: [
          base.contract.axes.first.copyWith(values: const [-0.08, 0.08]),
          ...base.contract.axes.skip(1),
        ],
      ),
    ),
    'axis_not_result_blind': base.copyWith(
      contract: base.contract.copyWith(
        axes: [
          base.contract.axes.first.copyWith(resultBlind: false),
          ...base.contract.axes.skip(1),
        ],
      ),
    ),
    'elicitation_omission': base.copyWith(
      contract: base.contract.copyWith(
        elicitationRecords: base.contract.elicitationRecords.take(2).toList(),
      ),
    ),
    'elicitation_post_result': base.copyWith(
      contract: base.contract.copyWith(
        elicitationRecords: [
          base.contract.elicitationRecords.first.copyWith(
            observedAtUtc: '2026-08-27T12:10:00Z',
          ),
          ...base.contract.elicitationRecords.skip(1),
        ],
      ),
    ),
    'duplicate_elicitation': base.copyWith(
      contract: base.contract.copyWith(
        elicitationRecords: [
          base.contract.elicitationRecords.first,
          base.contract.elicitationRecords[1].copyWith(
            recordId: base.contract.elicitationRecords.first.recordId,
          ),
          base.contract.elicitationRecords.last,
        ],
      ),
    ),
    'grid_omission': base.copyWith(
      gridPoints: base.gridPoints.skip(1).toList(),
    ),
    'grid_duplicate': base.copyWith(
      gridPoints: [base.gridPoints.first, ...base.gridPoints],
    ),
    'grid_arithmetic_drift': base.copyWith(
      gridPoints: [
        base.gridPoints.first.copyWith(adjustedEffect: 9),
        ...base.gridPoints.skip(1),
      ],
    ),
    'exclusion_laundering': base.copyWith(
      gridPoints: [
        for (final point in base.gridPoints)
          if (point.pointId == excluded.pointId)
            point.copyWith(admissible: true)
          else
            point,
      ],
    ),
    'local_case_drift': base.copyWith(
      localCases: [
        base.localCases.first.copyWith(adjustedEffect: 0.9),
        ...base.localCases.skip(1),
      ],
    ),
    'global_index_drift': base.copyWith(
      globalIndices: [
        base.globalIndices.first.copyWith(firstOrderIndex: 0.5),
        ...base.globalIndices.skip(1),
      ],
    ),
    'partial_bounds_drift': base.copyWith(
      partialIdentification: base.partialIdentification.copyWith(
        lowerEffect: -0.5,
      ),
    ),
    'tipping_region_drift': base.copyWith(
      partialIdentification: base.partialIdentification.copyWith(
        decisionTippingPoints: 1,
      ),
    ),
    'scenario_omission': base.copyWith(
      scenarios: base.scenarios.skip(1).toList(),
    ),
    'operating_calibration_laundering': base.copyWith(
      operatingResults: [
        for (final result in base.operatingResults)
          if (result.scenarioId == dual.scenarioId)
            result.copyWith(bias: 0, coverage95: 0.95)
          else
            result,
      ],
    ),
    'nonidentifiable_estimate': base.copyWith(
      operatingResults: [
        for (final result in base.operatingResults)
          if (result.scenarioId == positivity.scenarioId)
            launder(positivity)
          else
            result,
      ],
    ),
    'no_consensus_estimate': base.copyWith(
      operatingResults: [
        for (final result in base.operatingResults)
          if (result.scenarioId == noConsensus.scenarioId)
            launder(noConsensus)
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
        cases: changedCases,
      ),
    ),
    'runtime_identity_drift': base.copyWith(configurationSha256: '0' * 64),
    'upstream_identity_drift': base.copyWith(transportPackageSha256: '0' * 64),
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
  CredibilityTransportabilitySensitivityPackage package,
) {
  final script = File(package.independentReplication.scriptPath);
  if (!script.existsSync()) {
    return const _IndependentOracleResult(
      pass: false,
      runtime: 'missing',
      scriptSha256: 'missing',
      output: {},
      detail: 'Independent script is missing.',
    );
  }
  final scriptSha256 = sha256.convert(script.readAsBytesSync()).toString();
  final result = Process.runSync('python3', [script.path]);
  if (result.exitCode != 0) {
    return _IndependentOracleResult(
      pass: false,
      runtime: 'python3',
      scriptSha256: scriptSha256,
      output: const {},
      detail: '${result.stderr}'.trim(),
    );
  }
  try {
    final output = Map<String, Object?>.from(
      jsonDecode('${result.stdout}'.trim()) as Map,
    );
    final cases = Map<String, Object?>.from(output['cases']! as Map);
    final grid = Map<String, Object?>.from(output['grid']! as Map);
    bool near(num? left, num right) =>
        left != null && (left.toDouble() - right.toDouble()).abs() <= 1e-12;
    final pass =
        scriptSha256 == package.independentReplication.scriptSha256 &&
        output['imports_production_code'] == false &&
        output['imports_golden_outputs'] == false &&
        package.independentReplication.cases.entries.every(
          (entry) => near(cases[entry.key] as num?, entry.value),
        ) &&
        package.independentReplication.gridSummary.entries.every(
          (entry) => near(grid[entry.key] as num?, entry.value),
        );
    return _IndependentOracleResult(
      pass: pass,
      runtime: 'python3',
      scriptSha256: scriptSha256,
      output: output,
      detail: pass ? 'Independent oracle matched.' : 'Oracle output drifted.',
    );
  } on Object catch (error) {
    return _IndependentOracleResult(
      pass: false,
      runtime: 'python3',
      scriptSha256: scriptSha256,
      output: const {},
      detail: 'Oracle output was invalid: $error',
    );
  }
}

String _markdown({
  required bool pass,
  required TransportSensitivityAssessment assessment,
  required _IndependentOracleResult independent,
  required int mutationCount,
}) =>
    '# Transportability bias-function sensitivity verification\n\n'
    '**Result:** ${pass ? 'pass' : 'FAILED'}\n\n'
    '- Status: `${assessment.status.name}`\n'
    '- Lanes: ${assessment.lanes.length}\n'
    '- Grid: ${assessment.counts['gridPoints']} total, '
    '${assessment.counts['admissiblePoints']} admissible, '
    '${assessment.counts['excludedPoints']} excluded\n'
    '- Scenarios: ${assessment.counts['scenarios']} / '
    '${assessment.counts['totalRepetitions']} repetitions\n'
    '- Mutations: $mutationCount\n'
    '- Independent oracle: ${independent.pass ? 'pass' : 'FAILED'}\n\n'
    'Passing is synthetic methodology-governance evidence only. It cannot '
    'establish conditional transportability, identify a clinical effect, or '
    'repair structural positivity failure.\n';

final class _IndependentOracleResult {
  final bool pass;
  final String runtime;
  final String scriptSha256;
  final Map<String, Object?> output;
  final String detail;

  const _IndependentOracleResult({
    required this.pass,
    required this.runtime,
    required this.scriptSha256,
    required this.output,
    required this.detail,
  });

  Map<String, Object?> toJson() => {
    'pass': pass,
    'runtime': runtime,
    'script_sha256': scriptSha256,
    'output': output,
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
