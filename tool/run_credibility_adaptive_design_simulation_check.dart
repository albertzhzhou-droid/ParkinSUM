import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_adaptive_design_simulation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_randomization_interim_firewall.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';
import 'package:parkinsum_companion/domain/usecases/adaptive_design_operating_characteristics_simulator.dart';

void main() {
  final package = _currentPackage();
  const verifier = CredibilityAdaptiveDesignSimulationVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final expectedStatuses = <String, AdaptiveSimulationGovernanceStatus>{
    'seed_substitution': AdaptiveSimulationGovernanceStatus.violated,
    'decision_timing_and_adaptation_switch':
        AdaptiveSimulationGovernanceStatus.violated,
    'decision_threshold_drift': AdaptiveSimulationGovernanceStatus.violated,
    'scenario_omission': AdaptiveSimulationGovernanceStatus.violated,
    'post_lock_scenario': AdaptiveSimulationGovernanceStatus.violated,
    'monte_carlo_underpower': AdaptiveSimulationGovernanceStatus.violated,
    'result_suppression': AdaptiveSimulationGovernanceStatus.violated,
    'unprespecified_result': AdaptiveSimulationGovernanceStatus.violated,
    'false_convergence': AdaptiveSimulationGovernanceStatus.violated,
    'type_one_error_inflation': AdaptiveSimulationGovernanceStatus.violated,
    'power_failure': AdaptiveSimulationGovernanceStatus.violated,
    'bias_and_coverage_failure': AdaptiveSimulationGovernanceStatus.violated,
    'oracle_redefinition': AdaptiveSimulationGovernanceStatus.violated,
    'runtime_identity_drift': AdaptiveSimulationGovernanceStatus.unknown,
    'prospective_chronology_break': AdaptiveSimulationGovernanceStatus.violated,
    'future_schema': AdaptiveSimulationGovernanceStatus.unknown,
    'explicit_revocation': AdaptiveSimulationGovernanceStatus.revoked,
  };
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final publicJson = jsonEncode(package.toJson());
  final secretsExcluded =
      !publicJson.contains('${package.custody.masterSeed}') &&
      !publicJson.contains(package.custody.commitmentSalt);
  final pass =
      assessment.integrityVerified &&
      assessment.status ==
          AdaptiveSimulationGovernanceStatus.mechanicallyObserved &&
      assessment.lanes.length == 7 &&
      assessment.counts['scenarios'] == 12 &&
      assessment.counts['totalRepetitions'] == 700000 &&
      assessment.counts['oracleVectors'] == 5 &&
      assessment.maximumMonteCarloStandardError < 0.0025 &&
      secretsExcluded &&
      !assessment.canSupportClinicalOrRegulatoryClaim &&
      mutationsDetected;
  final report = <String, Object?>{
    'report_type':
        'parkinsum_credibility_adaptive_design_operating_characteristics',
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
    'raw_seed_and_salt_excluded': secretsExcluded,
    'synthetic_fixture_only': true,
    'ich_e20_draft_not_for_implementation': true,
    'not_statistical_or_clinical_validation': true,
    'not_regulatory_review_or_acceptance': true,
    'not_clinical_or_patient_safety_evidence': true,
    'safety_boundary': package.boundary,
  };
  final markdown = <String>[
    '# Adaptive-design operating characteristics and decision calibration',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Status:** ${assessment.status.name}',
    '**Integrity:** ${assessment.integrityVerified ? 'verified' : 'FAILED'}',
    '**Clinical or regulatory claim:** blocked',
    '**Package:** `${package.packageSha256}`',
    '**Decision contract:** `${package.contract.contractSha256}`',
    '**Scenario catalog:** `${package.contract.scenarioCatalogSha256}`',
    '**Seed manifest:** `${package.contract.seedManifestSha256}`',
    '',
    '## Operating-characteristic lanes',
    '',
    '| Lane | State |',
    '| --- | --- |',
    for (final entry in assessment.lanes.entries)
      '| ${entry.key} | ${entry.value} |',
    '',
    '## Prespecified scenario results',
    '',
    '| Scenario | Repetitions | Success | MCSE | Bias | Coverage | Mean N |',
    '| --- | ---: | ---: | ---: | ---: | ---: | ---: |',
    for (var index = 0; index < package.scenarios.length; index += 1)
      '| ${package.scenarios[index].scenarioId} | '
          '${package.results[index].repetitions} | '
          '${package.results[index].successProbability.toStringAsFixed(5)} | '
          '${package.results[index].monteCarloStandardError.toStringAsFixed(6)} | '
          '${package.results[index].bias.toStringAsFixed(5)} | '
          '${package.results[index].intervalCoverage.toStringAsFixed(5)} | '
          '${package.results[index].meanSampleSize.toStringAsFixed(2)} |',
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
  final output = Directory('build/credibility_adaptive_design')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility adaptive-design simulation: '
    '${pass ? 'pass' : 'FAILED'}; status=${assessment.status.name}; '
    'lanes=${assessment.lanes.length}; scenarios=${package.scenarios.length}; '
    'repetitions=${assessment.counts['totalRepetitions']}; '
    'mutations=${mutations.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

CredibilityAdaptiveDesignSimulationPackage _currentPackage() {
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
  return AdaptiveDesignSyntheticFixture.build(
    randomizationPackage: randomization,
  );
}

Map<String, AdaptiveSimulationGovernanceAssessment> _mutations(
  CredibilityAdaptiveDesignSimulationPackage base,
  CredibilityAdaptiveDesignSimulationVerifier verifier,
) {
  AdaptiveOperatingCharacteristicsResult withSuccessCount(
    AdaptiveOperatingCharacteristicsResult result,
    int count,
  ) {
    final probability = count / result.repetitions;
    return result.copyWith(
      successCount: count,
      successProbability: probability,
      monteCarloStandardError: math.sqrt(
        probability * (1 - probability) / result.repetitions,
      ),
    );
  }

  final changedCustody = AdaptiveSimulationSeedCustody(
    masterSeed: base.custody.masterSeed + 1,
    commitmentSalt: base.custody.commitmentSalt,
    scenarioIds: base.custody.scenarioIds,
  );
  final postLockScenario = base.scenarios.first.copyWith(
    prespecifiedAtUtc: '2026-08-26T12:06:00.000Z',
  );
  final underRepeated = base.scenarios.first.copyWith(repetitions: 1000);
  final extraResult = base.results.first.copyWith(
    scenarioId: 'post-result-added',
  );
  final falseConvergence = base.results.first.copyWith(
    successProbability: 0.0001,
  );
  final inflatedTypeOne = withSuccessCount(base.results.first, 4000);
  final alternativeIndex = base.scenarios.indexWhere(
    (item) => item.family == AdaptiveScenarioFamily.alternativeNormal,
  );
  final insufficientPower = withSuccessCount(
    base.results[alternativeIndex],
    20000,
  );
  final powerResults = [...base.results]
    ..[alternativeIndex] = insufficientPower;
  final biasCoverage = base.results[2].copyWith(
    meanEstimate: base.results[2].meanEstimate + 0.5,
    bias: base.results[2].bias + 0.5,
    coverageCount: 100,
    intervalCoverage: 100 / base.results[2].repetitions,
  );
  final biasCoverageResults = [...base.results]..[2] = biasCoverage;
  final redefinedOracle = base.oracleVectors.first.copyWith(
    expectedFirstAction: AdaptiveDecisionAction.futility,
  );
  return {
    'seed_substitution': verifier.verify(
      base.copyWith(custody: changedCustody),
    ),
    'decision_timing_and_adaptation_switch': verifier.verify(
      base.copyWith(
        contract: base.contract.copyWith(
          informationFractions: const [0.6, 1.0],
          adaptationIds: const ['early_efficacy'],
        ),
      ),
    ),
    'decision_threshold_drift': verifier.verify(
      base.copyWith(
        contract: base.contract.copyWith(
          efficacyZBoundaries: const [2.5, 1.98],
        ),
      ),
    ),
    'scenario_omission': verifier.verify(
      base.copyWith(scenarios: base.scenarios.sublist(1)),
    ),
    'post_lock_scenario': verifier.verify(
      base.copyWith(scenarios: [postLockScenario, ...base.scenarios.skip(1)]),
    ),
    'monte_carlo_underpower': verifier.verify(
      base.copyWith(scenarios: [underRepeated, ...base.scenarios.skip(1)]),
    ),
    'result_suppression': verifier.verify(
      base.copyWith(
        results: base.results.sublist(1),
        allPrespecifiedResultsRetained: false,
      ),
    ),
    'unprespecified_result': verifier.verify(
      base.copyWith(results: [...base.results, extraResult]),
    ),
    'false_convergence': verifier.verify(
      base.copyWith(results: [falseConvergence, ...base.results.skip(1)]),
    ),
    'type_one_error_inflation': verifier.verify(
      base.copyWith(results: [inflatedTypeOne, ...base.results.skip(1)]),
    ),
    'power_failure': verifier.verify(base.copyWith(results: powerResults)),
    'bias_and_coverage_failure': verifier.verify(
      base.copyWith(results: biasCoverageResults),
    ),
    'oracle_redefinition': verifier.verify(
      base.copyWith(
        oracleVectors: [redefinedOracle, ...base.oracleVectors.skip(1)],
      ),
    ),
    'runtime_identity_drift': verifier.verify(
      base.copyWith(configurationSha256: '0' * 64),
    ),
    'prospective_chronology_break': verifier.verify(
      base.copyWith(simulationStartedAtUtc: '2026-08-26T12:04:00.000Z'),
    ),
    'future_schema': verifier.verify(base.copyWith(schemaVersion: 2)),
    'explicit_revocation': verifier.verify(base.copyWith(revoked: true)),
  };
}
