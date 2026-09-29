import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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
  const verifier = CredibilityBayesianBorrowingCalibrationVerifier();

  CredibilityBayesianBorrowingCalibrationPackage current() {
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
      protocolAssessment: const CredibilityProtocolTransparencyVerifier()
          .verify(ledger),
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
    final randomization =
        CredibilityRandomizationInterimPackage.syntheticCurrent(
          statisticalPackage: statistics,
          configurationSha256: configuration.sha256Digest,
          algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
        );
    final adaptive = AdaptiveDesignSyntheticFixture.build(
      randomizationPackage: randomization,
    );
    return BayesianBorrowingSyntheticFixture.build(adaptivePackage: adaptive);
  }

  final base = current();

  Set<BayesianFindingKind> kinds(
    CredibilityBayesianBorrowingCalibrationPackage package,
  ) => verifier.verify(package).findings.map((item) => item.kind).toSet();

  test('clean fixture exposes eight separate Bayesian governance lanes', () {
    final assessment = verifier.verify(base);
    expect(
      assessment.status,
      BayesianGovernanceStatus.mechanicallyObserved,
      reason: assessment.findings
          .map((item) => '${item.kind.name}: ${item.detail}')
          .join('\n'),
    );
    expect(assessment.findings, isEmpty);
    expect(assessment.lanes.keys, {
      'priorProvenance',
      'externalDataSuitability',
      'borrowing',
      'priorDataConflict',
      'computation',
      'posteriorDecision',
      'frequentistCalibration',
      'oracleAndAdjudication',
    });
    expect(assessment.counts, containsPair('externalEvidence', 2));
    expect(assessment.counts, containsPair('scenarios', 10));
    expect(assessment.counts, containsPair('nullScenarios', 3));
    expect(assessment.counts, containsPair('totalRepetitions', 400000));
    expect(assessment.counts, containsPair('oracleVectors', 5));
    expect(assessment.maximumMonteCarloStandardError, lessThan(0.0026));
    expect(
      assessment.maximumBorrowedEffectiveSampleSize,
      lessThanOrEqualTo(40),
    );
    expect(assessment.canSupportClinicalOrRegulatoryClaim, isFalse);
  });

  test('public package excludes raw seed and salt', () {
    final publicJson = jsonEncode(base.toJson());
    expect(publicJson, isNot(contains('${base.custody.masterSeed}')));
    expect(publicJson, isNot(contains(base.custody.commitmentSalt)));
    expect(publicJson, contains('raw_seed_exposed'));
  });

  test('borrowing falls monotonically as conflict increases', () {
    BayesianOperatingCharacteristicsResult resultFor(
      BayesianBorrowingScenarioFamily family,
    ) {
      final scenario = base.scenarios.firstWhere(
        (item) => item.family == family,
      );
      return base.results.firstWhere(
        (item) => item.scenarioId == scenario.scenarioId,
      );
    }

    final none = resultFor(BayesianBorrowingScenarioFamily.noConflict);
    final mild = resultFor(BayesianBorrowingScenarioFamily.mildConflict);
    final severe = resultFor(BayesianBorrowingScenarioFamily.severeConflict);
    expect(none.meanBorrowingWeight, greaterThan(mild.meanBorrowingWeight));
    expect(mild.meanBorrowingWeight, greaterThan(severe.meanBorrowingWeight));
    expect(none.meanConflictScore, lessThan(mild.meanConflictScore));
    expect(mild.meanConflictScore, lessThan(severe.meanConflictScore));
  });

  test('prior cherry-picking and duplicate cohorts are held', () {
    expect(
      kinds(base.copyWith(allRelevantExternalEvidenceRetained: false)),
      contains(BayesianFindingKind.priorCherryPicking),
    );
    expect(
      kinds(
        base.copyWith(
          externalEvidence: [
            ...base.externalEvidence,
            base.externalEvidence.first,
          ],
        ),
      ),
      contains(BayesianFindingKind.externalEvidenceDuplicate),
    );
  });

  test('population, outcome, and quality mismatch cannot be included', () {
    final changed = base.externalEvidence.last.copyWith(included: true);
    expect(
      kinds(
        base.copyWith(externalEvidence: [base.externalEvidence.first, changed]),
      ),
      contains(BayesianFindingKind.externalEvidenceMismatch),
    );
  });

  test('overborrowing and disabled dynamic discounting fail closed', () {
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            maximumBorrowingFraction: 1,
            maximumPriorEffectiveSampleSize: 100,
          ),
        ),
      ),
      contains(BayesianFindingKind.borrowingUnbounded),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(discountingRuleId: 'static/1'),
        ),
      ),
      contains(BayesianFindingKind.discountingDisabled),
    );
  });

  test('scenario omission and Monte Carlo underpower are detected', () {
    expect(
      kinds(base.copyWith(scenarios: base.scenarios.sublist(1))),
      contains(BayesianFindingKind.scenarioCoverageIncomplete),
    );
    final changed = base.scenarios.first.copyWith(repetitions: 1000);
    expect(
      kinds(base.copyWith(scenarios: [changed, ...base.scenarios.skip(1)])),
      contains(BayesianFindingKind.monteCarloUnderpowered),
    );
  });

  test('posterior result omission and false convergence are visible', () {
    expect(
      kinds(base.copyWith(results: base.results.sublist(1))),
      containsAll({
        BayesianFindingKind.resultMissingOrDuplicate,
        BayesianFindingKind.selectivePosteriorReporting,
      }),
    );
    final changed = base.results.first.copyWith(computationConverged: false);
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      contains(BayesianFindingKind.computationUnreliable),
    );
  });

  test('reconciled false-positive inflation is detected', () {
    final result = base.results.first;
    final count = 10000;
    final probability = count / result.repetitions;
    final changed = result.copyWith(
      decisionCount: count,
      decisionProbability: probability,
      monteCarloStandardError: math.sqrt(
        probability * (1 - probability) / result.repetitions,
      ),
    );
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      contains(BayesianFindingKind.falsePositiveInflated),
    );
  });

  test('posterior threshold and oracle redefinition are detected', () {
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(posteriorSuccessProbability: 0.90),
        ),
      ),
      contains(BayesianFindingKind.oracleMismatch),
    );
    final changed = base.oracleVectors.last.copyWith(
      expectedDecisionState: BayesianDecisionState.success,
    );
    expect(
      kinds(
        base.copyWith(oracleVectors: [...base.oracleVectors.take(4), changed]),
      ),
      contains(BayesianFindingKind.oracleMismatch),
    );
  });

  test(
    'future schema, upstream drift, chronology break, and revocation fail',
    () {
      expect(
        verifier.verify(base.copyWith(schemaVersion: 2)).status,
        BayesianGovernanceStatus.violated,
      );
      expect(
        verifier
            .verify(
              base.copyWith(
                adaptivePackageSha256:
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              ),
            )
            .status,
        BayesianGovernanceStatus.violated,
      );
      expect(
        kinds(
          base.copyWith(
            contract: base.contract.copyWith(
              firstResultVisibleAtUtc: '2026-08-26T13:04:00.000Z',
            ),
          ),
        ),
        contains(BayesianFindingKind.prospectiveLockBroken),
      );
      expect(
        verifier.verify(base.copyWith(revoked: true)).status,
        BayesianGovernanceStatus.revoked,
      );
    },
  );
}
