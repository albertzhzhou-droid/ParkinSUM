import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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
  const verifier = CredibilityAdaptiveDesignSimulationVerifier();

  CredibilityAdaptiveDesignSimulationPackage current() {
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
    return AdaptiveDesignSyntheticFixture.build(
      randomizationPackage: randomization,
    );
  }

  final base = current();

  Set<AdaptiveSimulationFindingKind> kinds(
    CredibilityAdaptiveDesignSimulationPackage package,
  ) => verifier.verify(package).findings.map((item) => item.kind).toSet();

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

  test(
    'clean fixture exposes seven bounded operating-characteristic lanes',
    () {
      final assessment = verifier.verify(base);
      expect(
        assessment.status,
        AdaptiveSimulationGovernanceStatus.mechanicallyObserved,
        reason: assessment.findings
            .map((item) => '${item.kind.name}: ${item.detail}')
            .join('\n'),
      );
      expect(assessment.findings, isEmpty);
      expect(assessment.lanes.keys, {
        'designIdentity',
        'scenarioCoverage',
        'monteCarloPrecision',
        'errorControl',
        'powerAndBias',
        'sampleSizeAndSelection',
        'oracleAndAdjudication',
      });
      expect(assessment.counts, containsPair('scenarios', 12));
      expect(assessment.counts, containsPair('nullScenarios', 2));
      expect(assessment.counts, containsPair('alternativeScenarios', 10));
      expect(assessment.counts, containsPair('totalRepetitions', 700000));
      expect(assessment.counts, containsPair('oracleVectors', 5));
      expect(assessment.maximumMonteCarloStandardError, lessThan(0.0025));
      expect(assessment.canSupportClinicalOrRegulatoryClaim, isFalse);
    },
  );

  test('seed substitution fails the locked custody manifest', () {
    final custody = AdaptiveSimulationSeedCustody(
      masterSeed: base.custody.masterSeed + 1,
      commitmentSalt: base.custody.commitmentSalt,
      scenarioIds: base.custody.scenarioIds,
    );
    expect(
      kinds(base.copyWith(custody: custody)),
      contains(AdaptiveSimulationFindingKind.seedManifestMismatch),
    );
  });

  test('decision timing and adaptation-rule drift fail closed', () {
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            informationFractions: const [0.6, 1.0],
            adaptationIds: const ['early_efficacy'],
          ),
        ),
      ),
      containsAll({
        AdaptiveSimulationFindingKind.contractIncomplete,
        AdaptiveSimulationFindingKind.decisionTimingDrift,
      }),
    );
  });

  test('scenario omission and post-lock addition are detected', () {
    expect(
      kinds(base.copyWith(scenarios: base.scenarios.sublist(1))),
      contains(AdaptiveSimulationFindingKind.scenarioCoverageIncomplete),
    );
    final changed = base.scenarios.first.copyWith(
      prespecifiedAtUtc: '2026-08-26T12:06:00.000Z',
    );
    expect(
      kinds(base.copyWith(scenarios: [changed, ...base.scenarios.skip(1)])),
      contains(AdaptiveSimulationFindingKind.scenarioAddedAfterLock),
    );
  });

  test('under-repeated scenario is held even when a result is retained', () {
    final changed = base.scenarios.first.copyWith(repetitions: 1000);
    expect(
      kinds(base.copyWith(scenarios: [changed, ...base.scenarios.skip(1)])),
      containsAll({
        AdaptiveSimulationFindingKind.monteCarloUnderpowered,
        AdaptiveSimulationFindingKind.resultIdentityMismatch,
      }),
    );
  });

  test('missing and unprespecified results fail closed', () {
    expect(
      kinds(base.copyWith(results: base.results.sublist(1))),
      contains(AdaptiveSimulationFindingKind.resultMissingOrDuplicate),
    );
    final extra = base.results.first.copyWith(scenarioId: 'post-result-added');
    expect(
      kinds(base.copyWith(results: [...base.results, extra])),
      contains(AdaptiveSimulationFindingKind.resultSuppressed),
    );
  });

  test('false convergence arithmetic cannot be serialized as precision', () {
    final changed = base.results.first.copyWith(successProbability: 0.0001);
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      contains(AdaptiveSimulationFindingKind.resultArithmeticMismatch),
    );
  });

  test('type-I inflation is detected with internally reconciled counts', () {
    final changed = withSuccessCount(base.results.first, 4000);
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      contains(AdaptiveSimulationFindingKind.typeOneErrorInflated),
    );
  });

  test('insufficient power is detected with internally reconciled counts', () {
    final index = base.scenarios.indexWhere(
      (item) => item.family == AdaptiveScenarioFamily.alternativeNormal,
    );
    final changed = withSuccessCount(base.results[index], 20000);
    final results = [...base.results]..[index] = changed;
    expect(
      kinds(base.copyWith(results: results)),
      contains(AdaptiveSimulationFindingKind.powerInsufficient),
    );
  });

  test('bias and coverage mutations remain separately visible', () {
    final result = base.results[2];
    final changed = result.copyWith(
      meanEstimate: result.meanEstimate + 0.5,
      bias: result.bias + 0.5,
      coverageCount: 100,
      intervalCoverage: 100 / result.repetitions,
    );
    final results = [...base.results]..[2] = changed;
    expect(
      kinds(base.copyWith(results: results)),
      containsAll({
        AdaptiveSimulationFindingKind.biasExcessive,
        AdaptiveSimulationFindingKind.coverageInsufficient,
      }),
    );
  });

  test('oracle mismatch cannot redefine a decision boundary', () {
    final changed = base.oracleVectors.first.copyWith(
      expectedFirstAction: AdaptiveDecisionAction.futility,
    );
    expect(
      kinds(
        base.copyWith(oracleVectors: [changed, ...base.oracleVectors.skip(1)]),
      ),
      contains(AdaptiveSimulationFindingKind.oracleMismatch),
    );
  });

  test(
    'runtime identity drift, future schema, chronology, and revocation fail',
    () {
      expect(
        kinds(base.copyWith(configurationSha256: '0' * 64)),
        contains(AdaptiveSimulationFindingKind.identityMismatch),
      );
      expect(
        verifier.verify(base.copyWith(schemaVersion: 2)).status,
        AdaptiveSimulationGovernanceStatus.unknown,
      );
      expect(
        kinds(
          base.copyWith(simulationStartedAtUtc: '2026-08-26T12:04:00.000Z'),
        ),
        contains(AdaptiveSimulationFindingKind.prospectiveLockBroken),
      );
      expect(
        verifier.verify(base.copyWith(revoked: true)).status,
        AdaptiveSimulationGovernanceStatus.revoked,
      );
    },
  );

  test('public JSON is deterministic, immutable, and excludes raw seeds', () {
    final first = jsonEncode(base.toJson());
    expect(jsonEncode(base.toJson()), first);
    expect(first, isNot(contains('${base.custody.masterSeed}')));
    expect(first, isNot(contains(base.custody.commitmentSalt)));
    expect(first, contains('raw_seed_exposed'));
    expect(
      () => base.scenarios.add(base.scenarios.first),
      throwsUnsupportedError,
    );
    expect(() => base.results.clear(), throwsUnsupportedError);
    expect(() => base.oracleVectors.clear(), throwsUnsupportedError);
  });
}
