import 'package:flutter_test/flutter_test.dart';
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
  const verifier = CredibilityTransportabilitySensitivityVerifier();
  final base = TransportabilityBiasFunctionSensitivityFixture.build(
    transportPackage: TargetPopulationTransportabilityFixture.build(
      multisourcePackage: _currentMultisourcePackage(),
    ),
  );

  Set<TransportSensitivityFindingKind> kinds(
    CredibilityTransportabilitySensitivityPackage package,
  ) => verifier.verify(package).findings.map((finding) => finding.kind).toSet();

  test('clean fixture exposes ten sensitivity lanes and complete counts', () {
    final assessment = verifier.verify(base);
    expect(
      assessment.status,
      TransportSensitivityStatus.mechanicallyObserved,
      reason: assessment.findings
          .map((finding) => '${finding.kind.name}: ${finding.detail}')
          .join('\n'),
    );
    expect(assessment.findings, isEmpty);
    expect(assessment.lanes.keys, {
      'assumptions',
      'elicitation',
      'parameterSpace',
      'localSensitivity',
      'globalSensitivity',
      'partialIdentification',
      'tippingRegion',
      'operatingCharacteristics',
      'independentReplication',
      'unresolvedLimitations',
    });
    expect(assessment.counts, containsPair('axes', 5));
    expect(assessment.counts, containsPair('elicitationRecords', 3));
    expect(assessment.counts, containsPair('gridPoints', 2625));
    expect(assessment.counts, containsPair('admissiblePoints', 2375));
    expect(assessment.counts, containsPair('excludedPoints', 250));
    expect(assessment.counts, containsPair('localCases', 6));
    expect(assessment.counts, containsPair('globalIndices', 5));
    expect(assessment.counts, containsPair('scenarios', 8));
    expect(assessment.counts, containsPair('totalRepetitions', 80000));
    expect(base.packageSha256, hasLength(64));
  });

  test('complete Cartesian grid retains arithmetic and exclusion reasons', () {
    expect(base.gridPoints, hasLength(3 * 7 * 5 * 5 * 5));
    expect(
      base.gridPoints.map((point) => point.pointId).toSet(),
      hasLength(2625),
    );
    expect(base.gridPoints.where((point) => point.admissible), hasLength(2375));
    expect(
      base.gridPoints
          .where((point) => !point.admissible)
          .every((point) => point.exclusionReason?.isNotEmpty ?? false),
      isTrue,
    );
    for (final point in base.gridPoints) {
      final expectedBias = transportSensitivityWeightedBias(
        point.delta,
        point.modifierSlope,
        point.measurementShift,
        point.modifierCorrelation,
      );
      expect(point.weightedBias, closeTo(expectedBias, 1e-12));
      expect(point.adjustedEffect, closeTo(0.18 - expectedBias, 1e-12));
      expect(
        point.adjustedTreatmentMean - point.adjustedControlMean,
        closeTo(point.adjustedEffect, 1e-12),
      );
    }
  });

  test(
    'local cases and independent oracle freeze sign and tipping behavior',
    () {
      final expected =
          CredibilityTransportabilitySensitivityVerifier.expectedCases;
      expect(
        base.localCases.map((item) => item.caseId).toSet(),
        expected.keys.toSet(),
      );
      for (final item in base.localCases) {
        expect(item.adjustedEffect, closeTo(expected[item.caseId]!, 1e-12));
        expect(
          base.independentReplication.cases[item.caseId],
          closeTo(item.adjustedEffect, 1e-12),
        );
      }
      expect(base.independentReplication.importsProductionCode, isFalse);
      expect(base.independentReplication.importsGoldenOutputs, isFalse);
    },
  );

  test('global indices and partial-identification region are reproducible', () {
    final recomputed = transportGlobalSensitivityIndices(base.gridPoints);
    expect(
      base.globalIndices.map((item) => item.toJson()).toList(),
      recomputed.map((item) => item.toJson()).toList(),
    );
    expect(
      base.globalIndices.fold<double>(
        0,
        (sum, item) => sum + item.firstOrderIndex,
      ),
      lessThanOrEqualTo(1.01),
    );
    expect(base.partialIdentification.lowerEffect, closeTo(-0.0175, 1e-12));
    expect(base.partialIdentification.upperEffect, closeTo(0.3775, 1e-12));
    expect(base.partialIdentification.decisionTippingPoints, 465);
    expect(base.partialIdentification.nullCrossingPoints, 12);
    expect(
      base.partialIdentification.lowerConfidenceEnvelope,
      closeTo(-0.0175 - 1.96 * 0.04, 1e-12),
    );
  });

  test('operating characteristics retain calibration and two held states', () {
    final results = {
      for (final result in base.operatingResults) result.scenarioId: result,
    };
    final reference = results['reference-no-violation']!;
    final dual = results['dual-model-misspecification']!;
    expect(reference.status, SensitivityOperatingStatus.estimated);
    expect(reference.bias!.abs(), lessThan(0.005));
    expect(reference.coverage95, greaterThanOrEqualTo(0.94));
    expect(dual.bias!.abs(), greaterThanOrEqualTo(0.02));
    expect(dual.coverage95, lessThanOrEqualTo(0.90));
    expect(
      results['structural-positivity-failure']!.status,
      SensitivityOperatingStatus.heldNonidentifiable,
    );
    expect(
      results['incompatible-elicitation']!.status,
      SensitivityOperatingStatus.heldNoConsensus,
    );
    expect(
      results.values.every((result) => result.repetitions == 10000),
      isTrue,
    );
  });

  test('contract sign, reference values and chronology fail closed', () {
    expect(
      kinds(
        base.copyWith(contract: base.contract.copyWith(targetEstimand: '')),
      ),
      contains(TransportSensitivityFindingKind.contractIncomplete),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(biasFunctionDefinition: 'unknown'),
        ),
      ),
      contains(TransportSensitivityFindingKind.signConventionDrift),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(referenceControlMean: 0.5),
        ),
      ),
      contains(TransportSensitivityFindingKind.contractIncomplete),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            elicitationFrozenAtUtc: '2026-08-27T12:30:00Z',
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.chronology),
    );
  });

  test('axis and elicitation catalog mutations fail closed', () {
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            axes: [
              base.contract.axes.first.copyWith(values: const [-0.08, 0.08]),
              ...base.contract.axes.skip(1),
            ],
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.axisCatalog),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            elicitationRecords: base.contract.elicitationRecords
                .take(2)
                .toList(),
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.elicitationIncomplete),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            elicitationRecords: [
              base.contract.elicitationRecords.first.copyWith(
                observedAtUtc: '2026-08-27T12:10:00Z',
              ),
              ...base.contract.elicitationRecords.skip(1),
            ],
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.postResultElicitation),
    );
  });

  test('grid omissions, arithmetic drift and exclusion laundering fail', () {
    expect(
      kinds(base.copyWith(gridPoints: base.gridPoints.skip(1).toList())),
      contains(TransportSensitivityFindingKind.gridIncomplete),
    );
    expect(
      kinds(
        base.copyWith(
          gridPoints: [
            base.gridPoints.first.copyWith(adjustedEffect: 9),
            ...base.gridPoints.skip(1),
          ],
        ),
      ),
      contains(TransportSensitivityFindingKind.gridArithmetic),
    );
    final excluded = base.gridPoints.firstWhere((point) => !point.admissible);
    expect(
      kinds(
        base.copyWith(
          gridPoints: [
            for (final point in base.gridPoints)
              if (point.pointId == excluded.pointId)
                point.copyWith(admissible: true)
              else
                point,
          ],
        ),
      ),
      contains(TransportSensitivityFindingKind.exclusionLaundered),
    );
  });

  test('local, global, bounds and tipping mutations are detected', () {
    expect(
      kinds(
        base.copyWith(
          localCases: [
            base.localCases.first.copyWith(adjustedEffect: 0.9),
            ...base.localCases.skip(1),
          ],
        ),
      ),
      contains(TransportSensitivityFindingKind.localCaseDrift),
    );
    expect(
      kinds(
        base.copyWith(
          globalIndices: [
            base.globalIndices.first.copyWith(firstOrderIndex: 0.5),
            ...base.globalIndices.skip(1),
          ],
        ),
      ),
      contains(TransportSensitivityFindingKind.globalIndexDrift),
    );
    expect(
      kinds(
        base.copyWith(
          partialIdentification: base.partialIdentification.copyWith(
            lowerEffect: -0.5,
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.partialBoundsDrift),
    );
    expect(
      kinds(
        base.copyWith(
          partialIdentification: base.partialIdentification.copyWith(
            decisionTippingPoints: 1,
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.tippingRegionDrift),
    );
  });

  test('scenario, calibration and held-state laundering fail closed', () {
    expect(
      kinds(base.copyWith(scenarios: base.scenarios.skip(1).toList())),
      contains(TransportSensitivityFindingKind.scenarioCatalog),
    );
    final positivity = base.operatingResults.singleWhere(
      (result) => result.scenarioId == 'structural-positivity-failure',
    );
    final estimatedPositivity = TransportSensitivityOperatingResult(
      scenarioId: positivity.scenarioId,
      status: SensitivityOperatingStatus.estimated,
      repetitions: positivity.repetitions,
      meanAdjustedEstimate: 0.18,
      bias: 0,
      coverage95: 0.95,
      decisionTippingProbability: 0,
      nullCrossingProbability: 0,
      monteCarloStandardError: 0.0004,
      disposition: 'laundered',
    );
    expect(
      kinds(
        base.copyWith(
          operatingResults: [
            for (final result in base.operatingResults)
              if (result.scenarioId == positivity.scenarioId)
                estimatedPositivity
              else
                result,
          ],
        ),
      ),
      contains(TransportSensitivityFindingKind.nonidentifiableEstimated),
    );
    final dual = base.operatingResults.singleWhere(
      (result) => result.scenarioId == 'dual-model-misspecification',
    );
    expect(
      kinds(
        base.copyWith(
          operatingResults: [
            for (final result in base.operatingResults)
              if (result.scenarioId == dual.scenarioId)
                result.copyWith(bias: 0, coverage95: 0.95)
              else
                result,
          ],
        ),
      ),
      contains(TransportSensitivityFindingKind.operatingCalibration),
    );
  });

  test('independent, upstream and runtime identity drift are detected', () {
    expect(
      kinds(
        base.copyWith(
          independentReplication: base.independentReplication.copyWith(
            scriptSha256: '0' * 64,
          ),
        ),
      ),
      contains(TransportSensitivityFindingKind.independentReplication),
    );
    expect(
      kinds(base.copyWith(transportPackageSha256: '0' * 64)),
      contains(TransportSensitivityFindingKind.upstreamIdentity),
    );
    expect(
      kinds(base.copyWith(configurationSha256: '0' * 64)),
      contains(TransportSensitivityFindingKind.runtimeIdentity),
    );
  });

  test(
    'retention, boundary, future schema and revocation remain fail closed',
    () {
      expect(
        kinds(base.copyWith(allPrespecifiedResultsRetained: false)),
        contains(TransportSensitivityFindingKind.resultRetention),
      );
      expect(
        kinds(base.copyWith(boundary: 'validated clinical effect')),
        contains(TransportSensitivityFindingKind.boundaryOverclaim),
      );
      expect(
        kinds(base.copyWith(schemaVersion: 2)),
        contains(TransportSensitivityFindingKind.futureSchema),
      );
      expect(
        verifier.verify(base.copyWith(revoked: true)).status,
        TransportSensitivityStatus.revoked,
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
