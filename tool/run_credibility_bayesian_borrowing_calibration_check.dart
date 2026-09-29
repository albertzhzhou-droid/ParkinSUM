import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_bayesian_borrowing_calibration.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_randomization_interim_firewall.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';
import 'package:parkinsum_companion/domain/usecases/adaptive_design_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_borrowing_operating_characteristics_simulator.dart';

void main() {
  final package = _currentPackage();
  const verifier = CredibilityBayesianBorrowingCalibrationVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  const expectedStatuses = <String, BayesianGovernanceStatus>{
    'prior_cherry_picking': BayesianGovernanceStatus.held,
    'hyperparameter_switch': BayesianGovernanceStatus.held,
    'external_cohort_duplication': BayesianGovernanceStatus.held,
    'population_outcome_mismatch': BayesianGovernanceStatus.held,
    'overborrowing': BayesianGovernanceStatus.held,
    'discounting_disabled': BayesianGovernanceStatus.held,
    'prior_conflict_suppression': BayesianGovernanceStatus.held,
    'posterior_threshold_switch': BayesianGovernanceStatus.held,
    'selective_posterior_reporting': BayesianGovernanceStatus.held,
    'false_convergence': BayesianGovernanceStatus.held,
    'seed_substitution': BayesianGovernanceStatus.violated,
    'model_code_drift': BayesianGovernanceStatus.held,
    'post_result_scenario_calibration': BayesianGovernanceStatus.held,
    'false_positive_inflation': BayesianGovernanceStatus.held,
    'power_failure': BayesianGovernanceStatus.held,
    'oracle_redefinition': BayesianGovernanceStatus.held,
    'future_schema': BayesianGovernanceStatus.violated,
    'explicit_revocation': BayesianGovernanceStatus.revoked,
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
      assessment.status == BayesianGovernanceStatus.mechanicallyObserved &&
      assessment.lanes.length == 8 &&
      assessment.counts['externalEvidence'] == 2 &&
      assessment.counts['scenarios'] == 10 &&
      assessment.counts['totalRepetitions'] == 400000 &&
      assessment.counts['oracleVectors'] == 5 &&
      assessment.maximumMonteCarloStandardError < 0.0026 &&
      assessment.maximumBorrowedEffectiveSampleSize <= 40 &&
      secretsExcluded &&
      mutationsDetected &&
      !assessment.canSupportClinicalOrRegulatoryClaim;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_bayesian_borrowing_and_calibration',
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
    'fda_january_2026_draft_not_for_implementation': true,
    'not_bayesian_or_clinical_validation': true,
    'not_regulatory_review_or_acceptance': true,
    'not_clinical_or_patient_safety_evidence': true,
    'safety_boundary': package.boundary,
  };
  final markdown = <String>[
    '# Bayesian prior, borrowing conflict, and posterior calibration',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Status:** ${assessment.status.name}',
    '**Package:** `${package.packageSha256}`',
    '**Scenarios:** ${assessment.counts['scenarios']}',
    '**Total repetitions:** ${assessment.counts['totalRepetitions']}',
    '**Executable mutations:** ${mutations.length}',
    '',
    '## Lanes',
    '',
    for (final entry in assessment.lanes.entries)
      '- `${entry.key}`: `${entry.value}`',
    '',
    '## Mutation packages',
    '',
    for (final entry in mutations.entries)
      '- `${entry.key}`: `${entry.value.status.name}` — ${entry.value.findings.map((finding) => finding.kind.name).toSet().join(', ')}',
    '',
    '## Boundary',
    '',
    package.boundary,
    '',
  ].join('\n');
  final outputDirectory = Directory(
    'build/credibility_bayesian_borrowing_calibration',
  )..createSync(recursive: true);
  File(
    '${outputDirectory.path}/latest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  File('${outputDirectory.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility Bayesian borrowing/calibration: '
    '${pass ? 'pass' : 'FAILED'}; status=${assessment.status.name}; '
    'lanes=${assessment.lanes.length}; scenarios=${assessment.counts['scenarios']}; '
    'repetitions=${assessment.counts['totalRepetitions']}; '
    'mutations=${mutations.length}.',
  );
  stdout.writeln('Report: ${outputDirectory.path}/latest.json');
  stdout.writeln('Report: ${outputDirectory.path}/latest.md');
  if (!pass) exitCode = 1;
}

CredibilityBayesianBorrowingCalibrationPackage _currentPackage() {
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
  return BayesianBorrowingSyntheticFixture.build(adaptivePackage: adaptive);
}

Map<String, BayesianGovernanceAssessment> _mutations(
  CredibilityBayesianBorrowingCalibrationPackage base,
  CredibilityBayesianBorrowingCalibrationVerifier verifier,
) {
  BayesianOperatingCharacteristicsResult withDecisionCount(
    BayesianOperatingCharacteristicsResult result,
    int count,
  ) {
    final probability = count / result.repetitions;
    return result.copyWith(
      decisionCount: count,
      decisionProbability: probability,
      monteCarloStandardError: math.sqrt(
        probability * (1 - probability) / result.repetitions,
      ),
    );
  }

  final severeIndex = base.scenarios.indexWhere(
    (item) => item.family == BayesianBorrowingScenarioFamily.severeConflict,
  );
  final mildIndex = base.scenarios.indexWhere(
    (item) => item.family == BayesianBorrowingScenarioFamily.mildConflict,
  );
  final suppressedConflictResults = [...base.results];
  suppressedConflictResults[severeIndex] = base.results[severeIndex].copyWith(
    meanBorrowingWeight: base.results[mildIndex].meanBorrowingWeight + 0.05,
  );
  final underpoweredIndex = base.scenarios.indexWhere(
    (item) => !item.nullCompatible,
  );
  final lowPowerResults = [...base.results];
  lowPowerResults[underpoweredIndex] = withDecisionCount(
    base.results[underpoweredIndex],
    100,
  );
  final highFalsePositiveResults = [...base.results];
  highFalsePositiveResults[0] = withDecisionCount(base.results.first, 10000);
  final changedScenario = base.scenarios.first.copyWith(
    trueControlRate: 0.61,
    prespecifiedAtUtc: '2026-08-26T13:06:00.000Z',
  );
  final changedOracle = base.oracleVectors.last.copyWith(
    expectedDecisionState: BayesianDecisionState.success,
  );
  final changedEvidence = base.externalEvidence.last.copyWith(included: true);
  final mutations = <String, CredibilityBayesianBorrowingCalibrationPackage>{
    'prior_cherry_picking': base.copyWith(
      allRelevantExternalEvidenceRetained: false,
    ),
    'hyperparameter_switch': base.copyWith(
      contract: base.contract.copyWith(weakPriorAlpha: 2),
    ),
    'external_cohort_duplication': base.copyWith(
      externalEvidence: [...base.externalEvidence, base.externalEvidence.first],
    ),
    'population_outcome_mismatch': base.copyWith(
      externalEvidence: [base.externalEvidence.first, changedEvidence],
    ),
    'overborrowing': base.copyWith(
      contract: base.contract.copyWith(
        maximumBorrowingFraction: 1,
        maximumPriorEffectiveSampleSize: 100,
      ),
    ),
    'discounting_disabled': base.copyWith(
      contract: base.contract.copyWith(discountingRuleId: 'static/1'),
    ),
    'prior_conflict_suppression': base.copyWith(
      results: suppressedConflictResults,
    ),
    'posterior_threshold_switch': base.copyWith(
      contract: base.contract.copyWith(posteriorSuccessProbability: 0.90),
    ),
    'selective_posterior_reporting': base.copyWith(
      results: base.results.sublist(1),
      allPrespecifiedResultsRetained: false,
    ),
    'false_convergence': base.copyWith(
      results: [
        base.results.first.copyWith(computationConverged: false),
        ...base.results.skip(1),
      ],
    ),
    'seed_substitution': base.copyWith(
      custody: BayesianSeedCustody(
        masterSeed: base.custody.masterSeed + 1,
        commitmentSalt: base.custody.commitmentSalt,
        scenarioIds: base.custody.scenarioIds,
      ),
    ),
    'model_code_drift': base.copyWith(
      contract: base.contract.copyWith(
        modelCodeSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    ),
    'post_result_scenario_calibration': base.copyWith(
      scenarios: [changedScenario, ...base.scenarios.skip(1)],
    ),
    'false_positive_inflation': base.copyWith(
      results: highFalsePositiveResults,
    ),
    'power_failure': base.copyWith(results: lowPowerResults),
    'oracle_redefinition': base.copyWith(
      oracleVectors: [...base.oracleVectors.take(4), changedOracle],
    ),
    'future_schema': base.copyWith(schemaVersion: 2),
    'explicit_revocation': base.copyWith(revoked: true),
  };
  return {
    for (final entry in mutations.entries)
      entry.key: verifier.verify(entry.value),
  };
}
