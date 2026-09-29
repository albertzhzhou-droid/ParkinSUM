import 'package:flutter_test/flutter_test.dart';
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
  const verifier = CredibilityTargetPopulationTransportabilityVerifier();
  final base = TargetPopulationTransportabilityFixture.build(
    multisourcePackage: _currentMultisourcePackage(),
  );

  Set<TargetTransportabilityFindingKind> kinds(
    CredibilityTargetPopulationTransportabilityPackage package,
  ) => verifier.verify(package).findings.map((finding) => finding.kind).toSet();

  test('clean fixture exposes nine target-transportability lanes', () {
    final assessment = verifier.verify(base);
    expect(
      assessment.status,
      TargetTransportabilityStatus.mechanicallyObserved,
      reason: assessment.findings
          .map((finding) => '${finding.kind.name}: ${finding.detail}')
          .join('\n'),
    );
    expect(assessment.findings, isEmpty);
    expect(assessment.lanes.keys, {
      'identification',
      'overlap',
      'weighting',
      'outcomeModeling',
      'estimatorAgreement',
      'sensitivity',
      'operatingCharacteristics',
      'independentReplication',
      'unresolvedLimitations',
    });
    expect(assessment.counts, containsPair('trialRecords', 260));
    expect(assessment.counts, containsPair('targetRecords', 360));
    expect(assessment.counts, containsPair('assumptions', 7));
    expect(assessment.counts, containsPair('manufacturedCases', 4));
    expect(assessment.counts, containsPair('scenarios', 7));
    expect(assessment.counts, containsPair('totalRepetitions', 70000));
    expect(assessment.counts, containsPair('independentCases', 4));
  });

  test('reference target sample is disjoint and outcome-free', () {
    final trial = base.records
        .where((record) => record.role == TargetSampleRole.randomizedTrial)
        .toList();
    final target = base.records
        .where((record) => record.role == TargetSampleRole.targetPopulation)
        .toList();
    expect(trial, hasLength(260));
    expect(target, hasLength(360));
    expect(trial.every((record) => record.outcome != null), isTrue);
    expect(target.every((record) => record.outcome == null), isTrue);
    expect(
      trial
          .map((record) => record.recordId)
          .toSet()
          .intersection(target.map((record) => record.recordId).toSet()),
      isEmpty,
    );
  });

  test(
    'overlap, balance, effective sample size and weight tail stay visible',
    () {
      final diagnostic = base.overlapDiagnostic;
      expect(diagnostic.supportViolationStrata, isEmpty);
      expect(diagnostic.unknownTargetCovariates, isEmpty);
      expect(diagnostic.maximumInverseOddsWeight, closeTo(6, 1e-12));
      expect(diagnostic.influentialRecordCount, 10);
      expect(diagnostic.maximumSmdBeforeWeighting, greaterThan(0.5));
      expect(diagnostic.maximumSmdAfterWeighting, lessThan(1e-12));
      expect(diagnostic.effectiveTargetSampleSize, inInclusiveRange(100, 260));
      expect(base.truncationSensitivity, hasLength(4));
      expect(base.truncationSensitivity.last.truncationCap, isNull);
    },
  );

  test('manufactured cases demonstrate the exact double-robust boundary', () {
    double estimate(String caseId, TransportEstimatorKind estimator) => base
        .estimatorEstimates
        .singleWhere(
          (item) => item.caseId == caseId && item.estimator == estimator,
        )
        .estimate;
    expect(
      estimate(
        'sampling_model_misspecified',
        TransportEstimatorKind.augmentedInverseOdds,
      ),
      closeTo(0.18, 1e-12),
    );
    expect(
      estimate(
        'outcome_model_misspecified',
        TransportEstimatorKind.augmentedInverseOdds,
      ),
      closeTo(0.18, 1e-12),
    );
    expect(
      estimate(
        'both_models_misspecified',
        TransportEstimatorKind.augmentedInverseOdds,
      ),
      closeTo(0.14, 1e-12),
    );
    expect(
      estimate('both_models_correct', TransportEstimatorKind.trialOnly),
      closeTo(0.14, 1e-12),
    );
  });

  test(
    'target contract, causal graph, assumptions and chronology fail closed',
    () {
      expect(
        kinds(
          base.copyWith(contract: base.contract.copyWith(causalContrast: '')),
        ),
        contains(TargetTransportabilityFindingKind.contractIncomplete),
      );
      expect(
        kinds(
          base.copyWith(contract: base.contract.copyWith(graphEdges: const [])),
        ),
        contains(TargetTransportabilityFindingKind.causalGraphIncomplete),
      );
      expect(
        kinds(
          base.copyWith(
            contract: base.contract.copyWith(
              assumptions: base.contract.assumptions.skip(1).toList(),
            ),
          ),
        ),
        contains(TargetTransportabilityFindingKind.assumptionIncomplete),
      );
      expect(
        kinds(
          base.copyWith(
            contract: base.contract.copyWith(
              targetSampleFrozenAtUtc: '2026-08-26T16:30:00Z',
            ),
          ),
        ),
        contains(TargetTransportabilityFindingKind.chronology),
      );
    },
  );

  test('target outcome leakage, missing covariates and duplicate ids fail', () {
    final target = base.records.firstWhere(
      (record) => record.role == TargetSampleRole.targetPopulation,
    );
    expect(
      kinds(
        base.copyWith(
          records: [
            for (final record in base.records)
              if (record.recordId == target.recordId)
                record.copyWith(outcome: 0.3)
              else
                record,
          ],
        ),
      ),
      contains(TargetTransportabilityFindingKind.targetOutcomeLeakage),
    );
    expect(
      kinds(
        base.copyWith(
          records: [
            base.records.first.copyWith(covariates: const {}),
            ...base.records.skip(1),
          ],
        ),
      ),
      contains(TargetTransportabilityFindingKind.covariateIncomplete),
    );
    expect(
      kinds(
        base.copyWith(
          records: [
            base.records.first,
            base.records[1].copyWith(recordId: base.records.first.recordId),
            ...base.records.skip(2),
          ],
        ),
      ),
      contains(TargetTransportabilityFindingKind.recordIdentity),
    );
  });

  test('support, unknown covariate, weight and balance laundering fail', () {
    expect(
      kinds(
        base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            supportViolationStrata: const ['stratum-6'],
          ),
        ),
      ),
      contains(TargetTransportabilityFindingKind.supportViolationLaundered),
    );
    expect(
      kinds(
        base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            unknownTargetCovariates: const ['unmeasured-effect-modifier'],
          ),
        ),
      ),
      contains(TargetTransportabilityFindingKind.unknownCovariateLaundered),
    );
    expect(
      kinds(
        base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            maximumInverseOddsWeight: 8,
          ),
        ),
      ),
      contains(TargetTransportabilityFindingKind.weightMismatch),
    );
    expect(
      kinds(
        base.copyWith(
          overlapDiagnostic: base.overlapDiagnostic.copyWith(
            maximumSmdAfterWeighting: 0.2,
          ),
        ),
      ),
      contains(TargetTransportabilityFindingKind.balanceMismatch),
    );
  });

  test('estimator, sensitivity and scenario drift are detected', () {
    expect(
      kinds(
        base.copyWith(
          estimatorEstimates: [
            base.estimatorEstimates.first.copyWith(estimate: 0.30),
            ...base.estimatorEstimates.skip(1),
          ],
        ),
      ),
      contains(TargetTransportabilityFindingKind.estimatorArithmetic),
    );
    expect(
      kinds(base.copyWith(truncationSensitivity: const [])),
      contains(TargetTransportabilityFindingKind.sensitivityIncomplete),
    );
    expect(
      kinds(base.copyWith(scenarios: base.scenarios.skip(1).toList())),
      contains(TargetTransportabilityFindingKind.scenarioCatalog),
    );
  });

  test('structural non-overlap is held without laundering an estimate', () {
    final scenario = base.scenarios.singleWhere(
      (item) => item.family == TransportScenarioFamily.supportViolation,
    );
    final results = base.operatingResults.where(
      (result) => result.scenarioId == scenario.scenarioId,
    );
    expect(results, hasLength(4));
    expect(
      results.every(
        (result) =>
            result.status == TransportOperatingStatus.heldNonidentifiable &&
            result.meanEstimate == null &&
            result.bias == null,
      ),
      isTrue,
    );
    final held = results.first;
    expect(
      kinds(
        base.copyWith(
          operatingResults: [
            for (final result in base.operatingResults)
              if (identical(result, held))
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
      ),
      contains(TargetTransportabilityFindingKind.nonidentifiableEstimated),
    );
  });

  test('independent Python identity and manufactured values fail closed', () {
    expect(
      kinds(
        base.copyWith(
          independentReplication: base.independentReplication.copyWith(
            scriptSha256: '0' * 64,
          ),
        ),
      ),
      contains(TargetTransportabilityFindingKind.independentReplication),
    );
    final cases = {
      for (final entry in base.independentReplication.cases.entries)
        entry.key: Map<String, double>.from(entry.value),
    };
    cases['both_models_correct']!['augmented_inverse_odds'] = 0.99;
    expect(
      kinds(
        base.copyWith(
          independentReplication: base.independentReplication.copyWith(
            cases: cases,
          ),
        ),
      ),
      contains(TargetTransportabilityFindingKind.independentReplication),
    );
  });

  test(
    'runtime identity, future schema, retention, boundary and revoke fail',
    () {
      expect(
        kinds(base.copyWith(configurationSha256: '0' * 64)),
        contains(TargetTransportabilityFindingKind.runtimeIdentity),
      );
      expect(
        kinds(base.copyWith(schemaVersion: 2)),
        contains(TargetTransportabilityFindingKind.futureSchema),
      );
      expect(
        kinds(base.copyWith(allPrespecifiedResultsRetained: false)),
        contains(TargetTransportabilityFindingKind.resultRetention),
      );
      expect(
        kinds(base.copyWith(boundary: 'validated')),
        contains(TargetTransportabilityFindingKind.boundaryOverclaim),
      );
      expect(
        verifier.verify(base.copyWith(revoked: true)).status,
        TargetTransportabilityStatus.revoked,
      );
    },
  );
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
