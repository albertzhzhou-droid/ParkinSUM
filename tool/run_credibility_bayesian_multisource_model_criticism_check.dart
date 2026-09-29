import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_bayesian_borrowing_calibration.dart';
import 'package:parkinsum_companion/domain/entities/credibility_bayesian_multisource_model_criticism.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_randomization_interim_firewall.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';
import 'package:parkinsum_companion/domain/usecases/adaptive_design_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_borrowing_operating_characteristics_simulator.dart';
import 'package:parkinsum_companion/domain/usecases/bayesian_multisource_model_criticism_simulator.dart';

void main() {
  final package = BayesianMultisourceModelCriticismFixture.build(
    bayesianPackage: _currentBayesianPackage(),
  );
  const verifier = CredibilityBayesianMultisourceModelCriticismVerifier();
  final assessment = verifier.verify(package);
  final mutations = _mutations(package, verifier);
  final independent = _runIndependentOracle(package);
  final expectedStatuses = <String, MultisourceGovernanceStatus>{
    'search_omission': MultisourceGovernanceStatus.held,
    'post_result_selection': MultisourceGovernanceStatus.held,
    'duplicate_inclusion': MultisourceGovernanceStatus.held,
    'dependency_laundering': MultisourceGovernanceStatus.held,
    'contradictory_inclusion': MultisourceGovernanceStatus.held,
    'positivity_overclaim': MultisourceGovernanceStatus.held,
    'exchangeability_overclaim': MultisourceGovernanceStatus.held,
    'bias_adjustment_removed': MultisourceGovernanceStatus.held,
    'overborrowing': MultisourceGovernanceStatus.held,
    'prior_predictive_omission': MultisourceGovernanceStatus.held,
    'sbc_false_pass': MultisourceGovernanceStatus.held,
    'posterior_predictive_failure': MultisourceGovernanceStatus.held,
    'loo_omission': MultisourceGovernanceStatus.held,
    'source_order_drift': MultisourceGovernanceStatus.held,
    'negative_control_failure': MultisourceGovernanceStatus.held,
    'scenario_omission': MultisourceGovernanceStatus.held,
    'operating_arithmetic_drift': MultisourceGovernanceStatus.held,
    'false_positive_inflation': MultisourceGovernanceStatus.held,
    'independent_script_drift': MultisourceGovernanceStatus.held,
    'independent_result_drift': MultisourceGovernanceStatus.held,
    'future_schema': MultisourceGovernanceStatus.violated,
    'explicit_revocation': MultisourceGovernanceStatus.revoked,
  };
  final mutationsDetected = expectedStatuses.entries.every(
    (entry) => mutations[entry.key]?.status == entry.value,
  );
  final pass =
      assessment.integrityVerified &&
      assessment.status == MultisourceGovernanceStatus.mechanicallyObserved &&
      assessment.lanes.length == 10 &&
      assessment.counts['sources'] == 7 &&
      assessment.counts['includedSources'] == 3 &&
      assessment.counts['criticismChecks'] == 12 &&
      assessment.counts['scenarios'] == 6 &&
      assessment.counts['totalRepetitions'] == 120000 &&
      assessment.counts['independentCases'] == 4 &&
      assessment.totalBorrowedEffectiveSampleSize <= 40 &&
      assessment.maximumMonteCarloStandardError < 0.004 &&
      mutationsDetected &&
      independent.pass &&
      !assessment.canEstablishTransportabilityOrClinicalValidity;
  final report = <String, Object?>{
    'report_type': 'parkinsum_credibility_bayesian_multisource_model_criticism',
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
    'not_exchangeability_or_transportability_proof': true,
    'not_bayesian_or_clinical_validation': true,
    'not_regulatory_review_or_acceptance': true,
    'safety_boundary': package.boundary,
  };
  final markdown = <String>[
    '# Bayesian multi-source transportability and model criticism',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Status:** ${assessment.status.name}',
    '**Package:** `${package.packageSha256}`',
    '**Sources:** ${assessment.counts['sources']} (${assessment.counts['includedSources']} included)',
    '**Criticism checks:** ${assessment.counts['criticismChecks']}',
    '**Scenarios:** ${assessment.counts['scenarios']}',
    '**Total repetitions:** ${assessment.counts['totalRepetitions']}',
    '**Independent Python:** ${independent.pass ? 'agree' : 'FAILED'} (${independent.runtime})',
    '**Executable mutations:** ${mutations.length}',
    '',
    '## Lanes',
    '',
    for (final entry in assessment.lanes.entries)
      '- `${entry.key}`: `${entry.value}`',
    '',
    '## Boundary',
    '',
    package.boundary,
    '',
  ].join('\n');
  final outputDirectory = Directory(
    'build/credibility_bayesian_multisource_model_criticism',
  )..createSync(recursive: true);
  File(
    '${outputDirectory.path}/latest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  File('${outputDirectory.path}/latest.md').writeAsStringSync(markdown);
  stdout.writeln(
    'Credibility Bayesian multi-source/model criticism: '
    '${pass ? 'pass' : 'FAILED'}; status=${assessment.status.name}; '
    'lanes=${assessment.lanes.length}; sources=${assessment.counts['sources']}; '
    'checks=${assessment.counts['criticismChecks']}; '
    'repetitions=${assessment.counts['totalRepetitions']}; '
    'mutations=${mutations.length}; independent=${independent.pass}.',
  );
  stdout.writeln('Report: ${outputDirectory.path}/latest.json');
  stdout.writeln('Report: ${outputDirectory.path}/latest.md');
  if (!pass) exitCode = 1;
}

Map<String, MultisourceGovernanceAssessment> _mutations(
  CredibilityBayesianMultisourceModelCriticismPackage base,
  CredibilityBayesianMultisourceModelCriticismVerifier verifier,
) {
  MultisourceCriticismResult check(MultisourceCriticismKind kind) =>
      base.criticismResults.firstWhere((item) => item.kind == kind);
  final duplicate = base.sourceLedger.firstWhere(
    (item) => item.disposition == MultisourceEvidenceDisposition.duplicate,
  );
  final contradiction = base.sourceLedger.firstWhere(
    (item) => item.disposition == MultisourceEvidenceDisposition.contradictory,
  );
  final trialB = base.sourceLedger.firstWhere(
    (item) => item.sourceId == 'ext-trial-b',
  );
  List<MultisourceExternalEvidenceRecord> replaceSource(
    MultisourceExternalEvidenceRecord replacement,
  ) => [
    for (final source in base.sourceLedger)
      if (source.sourceId == replacement.sourceId) replacement else source,
  ];
  List<MultisourceCriticismResult> replaceCheck(
    MultisourceCriticismResult replacement,
  ) => [
    for (final item in base.criticismResults)
      if (item.checkId == replacement.checkId) replacement else item,
  ];
  final nullScenario = base.scenarios.firstWhere((item) => item.nullCompatible);
  final nullResult = base.operatingResults.firstWhere(
    (item) => item.scenarioId == nullScenario.scenarioId,
  );
  final mutated = <String, CredibilityBayesianMultisourceModelCriticismPackage>{
    'search_omission': base.copyWith(exhaustiveSearchRetained: false),
    'post_result_selection': base.copyWith(
      contract: base.contract.copyWith(
        searchFrozenAtUtc: '2026-08-26T12:30:00Z',
      ),
    ),
    'duplicate_inclusion': base.copyWith(
      sourceLedger: replaceSource(duplicate.copyWith(included: true)),
    ),
    'dependency_laundering': base.copyWith(
      borrowingResults: [
        for (final result in base.borrowingResults)
          if (result.sourceId == 'ext-registry-a-linked')
            result.copyWith(dependencyDiscount: 1)
          else
            result,
      ],
    ),
    'contradictory_inclusion': base.copyWith(
      sourceLedger: replaceSource(contradiction.copyWith(included: true)),
    ),
    'positivity_overclaim': base.copyWith(
      sourceLedger: replaceSource(trialB.copyWith(overlapScore: 0.2)),
    ),
    'exchangeability_overclaim': base.copyWith(
      sourceLedger: replaceSource(
        trialB.copyWith(exchangeability: MultisourceExchangeability.full),
      ),
    ),
    'bias_adjustment_removed': base.copyWith(
      borrowingResults: [
        base.borrowingResults.first.copyWith(biasAdjustedRate: 0.99),
        ...base.borrowingResults.skip(1),
      ],
    ),
    'overborrowing': base.copyWith(
      contract: base.contract.copyWith(maximumTotalBorrowedEss: 80),
    ),
    'prior_predictive_omission': base.copyWith(
      criticismResults: base.criticismResults
          .where(
            (item) => item.kind != MultisourceCriticismKind.priorPredictive,
          )
          .toList(),
    ),
    'sbc_false_pass': base.copyWith(
      criticismResults: replaceCheck(
        check(
          MultisourceCriticismKind.simulationBasedCalibration,
        ).copyWith(passed: false, observedValue: 1),
      ),
    ),
    'posterior_predictive_failure': base.copyWith(
      criticismResults: replaceCheck(
        check(
          MultisourceCriticismKind.posteriorPredictive,
        ).copyWith(passed: false, observedValue: 0.5),
      ),
    ),
    'loo_omission': base.copyWith(
      criticismResults: base.criticismResults
          .where(
            (item) => item.kind != MultisourceCriticismKind.leaveOneSourceOut,
          )
          .toList(),
    ),
    'source_order_drift': base.copyWith(sourceOrderInvariant: false),
    'negative_control_failure': base.copyWith(
      criticismResults: replaceCheck(
        check(
          MultisourceCriticismKind.negativeControl,
        ).copyWith(passed: false, observedValue: 0.2),
      ),
    ),
    'scenario_omission': base.copyWith(
      operatingResults: base.operatingResults.skip(1).toList(),
    ),
    'operating_arithmetic_drift': base.copyWith(
      operatingResults: [
        nullResult.copyWith(decisionProbability: 0.99),
        ...base.operatingResults.where(
          (item) => item.scenarioId != nullResult.scenarioId,
        ),
      ],
    ),
    'false_positive_inflation': base.copyWith(
      operatingResults: [
        nullResult.copyWith(
          decisionCount: 4000,
          decisionProbability: 0.2,
          monteCarloStandardError: 0.0028284271247461905,
        ),
        ...base.operatingResults.where(
          (item) => item.scenarioId != nullResult.scenarioId,
        ),
      ],
    ),
    'independent_script_drift': base.copyWith(
      independentReplication: base.independentReplication.copyWith(
        scriptSha256: 'a' * 64,
      ),
    ),
    'independent_result_drift': base.copyWith(
      independentReplication: base.independentReplication.copyWith(
        casePosteriorMeans: {
          ...base.independentReplication.casePosteriorMeans,
          'aligned': 0.9,
        },
      ),
    ),
    'future_schema': base.copyWith(schemaVersion: 2),
    'explicit_revocation': base.copyWith(revoked: true),
  };
  return {
    for (final entry in mutated.entries)
      entry.key: verifier.verify(entry.value),
  };
}

_IndependentOracleResult _runIndependentOracle(
  CredibilityBayesianMultisourceModelCriticismPackage package,
) {
  final script = File(package.independentReplication.scriptPath);
  if (!script.existsSync()) {
    return const _IndependentOracleResult(
      pass: false,
      runtime: 'missing',
      scriptSha256: '',
      detail: 'script_missing',
    );
  }
  final scriptSha256 = sha256.convert(script.readAsBytesSync()).toString();
  final process = Process.runSync('python3', [script.path]);
  if (process.exitCode != 0) {
    return _IndependentOracleResult(
      pass: false,
      runtime: 'failed',
      scriptSha256: scriptSha256,
      detail: process.stderr.toString(),
    );
  }
  try {
    final decoded =
        jsonDecode(process.stdout.toString()) as Map<String, Object?>;
    final cases = decoded['cases'] as Map<String, Object?>;
    final expected = package.independentReplication.casePosteriorMeans;
    final agree = expected.entries.every((entry) {
      final item = cases[entry.key] as Map<String, Object?>?;
      final actual = item?['posterior_mean'] as num?;
      return actual != null &&
          (actual.toDouble() - entry.value).abs() <=
              package.independentReplication.tolerance;
    });
    final reversed = cases['reversed_source_order'] as Map<String, Object?>;
    final aligned = cases['aligned'] as Map<String, Object?>;
    final orderInvariant =
        ((reversed['posterior_mean'] as num).toDouble() -
                (aligned['posterior_mean'] as num).toDouble())
            .abs() <=
        package.independentReplication.tolerance;
    return _IndependentOracleResult(
      pass:
          scriptSha256 == package.independentReplication.scriptSha256 &&
          decoded['language'] == 'Python' &&
          decoded['dependency_lock'] == 'python-stdlib-only' &&
          agree &&
          orderInvariant,
      runtime: decoded['runtime']?.toString() ?? 'unknown',
      scriptSha256: scriptSha256,
      detail: agree && orderInvariant
          ? 'manufactured_cases_agree'
          : 'case_mismatch',
    );
  } catch (error) {
    return _IndependentOracleResult(
      pass: false,
      runtime: 'parse_failed',
      scriptSha256: scriptSha256,
      detail: '$error',
    );
  }
}

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

CredibilityBayesianBorrowingCalibrationPackage _currentBayesianPackage() {
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
