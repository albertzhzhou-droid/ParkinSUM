import 'package:flutter_test/flutter_test.dart';
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
  const verifier = CredibilityBayesianMultisourceModelCriticismVerifier();

  final base = BayesianMultisourceModelCriticismFixture.build(
    bayesianPackage: _currentBayesianPackage(),
  );

  Set<MultisourceFindingKind> kinds(
    CredibilityBayesianMultisourceModelCriticismPackage package,
  ) => verifier.verify(package).findings.map((item) => item.kind).toSet();

  test('clean fixture exposes ten distinct governance lanes', () {
    final assessment = verifier.verify(base);
    expect(
      assessment.status,
      MultisourceGovernanceStatus.mechanicallyObserved,
      reason:
          '${assessment.findings.map((item) => '${item.kind.name}: ${item.detail}').join('\n')}\n'
          '${base.operatingResults.map((item) => '${item.scenarioId}: decision=${item.decisionProbability} bias=${item.bias} coverage=${item.coverage} ess=${item.meanBorrowedEffectiveSampleSize}').join('\n')}',
    );
    expect(assessment.findings, isEmpty);
    expect(assessment.lanes.keys, {
      'sourceDiscovery',
      'dependency',
      'transportability',
      'exchangeability',
      'biasAdjustment',
      'priorPredictiveCriticism',
      'posteriorPredictiveCriticism',
      'sensitivityAndNegativeControls',
      'computation',
      'independentReplication',
    });
    expect(assessment.counts, containsPair('sources', 7));
    expect(assessment.counts, containsPair('includedSources', 3));
    expect(assessment.counts, containsPair('criticismChecks', 12));
    expect(assessment.counts, containsPair('scenarios', 6));
    expect(assessment.counts, containsPair('totalRepetitions', 120000));
    expect(assessment.counts, containsPair('independentCases', 4));
    expect(assessment.totalBorrowedEffectiveSampleSize, closeTo(40, 1e-9));
    expect(assessment.maximumMonteCarloStandardError, lessThan(0.004));
    expect(assessment.canEstablishTransportabilityOrClinicalValidity, isFalse);
  });

  test('ledger retains every disposition and excludes unsuitable sources', () {
    expect(
      base.sourceLedger.map((item) => item.disposition).toSet(),
      containsAll(MultisourceEvidenceDisposition.values),
    );
    expect(
      base.sourceLedger
          .where(
            (item) =>
                item.disposition == MultisourceEvidenceDisposition.duplicate,
          )
          .single
          .included,
      isFalse,
    );
    expect(
      base.sourceLedger
          .where(
            (item) =>
                item.disposition ==
                MultisourceEvidenceDisposition.contradictory,
          )
          .single
          .included,
      isFalse,
    );
  });

  test('incomplete or post-result source search fails closed', () {
    expect(
      kinds(base.copyWith(exhaustiveSearchRetained: false)),
      contains(MultisourceFindingKind.searchLedgerIncomplete),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(
            searchFrozenAtUtc: '2026-08-26T12:30:00Z',
          ),
        ),
      ),
      contains(MultisourceFindingKind.postResultSelection),
    );
  });

  test('duplicate inclusion and dependency laundering are detected', () {
    final duplicate = base.sourceLedger.firstWhere(
      (item) => item.disposition == MultisourceEvidenceDisposition.duplicate,
    );
    expect(
      kinds(
        base.copyWith(
          sourceLedger: [
            for (final source in base.sourceLedger)
              if (source.sourceId == duplicate.sourceId)
                source.copyWith(included: true)
              else
                source,
          ],
        ),
      ),
      contains(MultisourceFindingKind.sourceDuplicateIncluded),
    );
    expect(
      kinds(
        base.copyWith(
          borrowingResults: [
            for (final result in base.borrowingResults)
              if (result.sourceId == 'ext-registry-a-linked')
                result.copyWith(dependencyDiscount: 1)
              else
                result,
          ],
        ),
      ),
      contains(MultisourceFindingKind.sourceDependencyUnresolved),
    );
  });

  test('transportability and exchangeability overclaims are held', () {
    final included = base.sourceLedger.firstWhere(
      (item) => item.sourceId == 'ext-trial-b',
    );
    expect(
      kinds(
        base.copyWith(
          sourceLedger: [
            for (final source in base.sourceLedger)
              if (source.sourceId == included.sourceId)
                source.copyWith(overlapScore: 0.2)
              else
                source,
          ],
        ),
      ),
      contains(MultisourceFindingKind.transportabilityUnresolved),
    );
    expect(
      kinds(
        base.copyWith(
          sourceLedger: [
            for (final source in base.sourceLedger)
              if (source.sourceId == included.sourceId)
                source.copyWith(
                  exchangeability: MultisourceExchangeability.full,
                )
              else
                source,
          ],
        ),
      ),
      contains(MultisourceFindingKind.exchangeabilityOverclaimed),
    );
  });

  test('bias arithmetic and borrowing cap are independently enforced', () {
    expect(
      kinds(
        base.copyWith(
          borrowingResults: [
            base.borrowingResults.first.copyWith(biasAdjustedRate: 0.99),
            ...base.borrowingResults.skip(1),
          ],
        ),
      ),
      contains(MultisourceFindingKind.biasAdjustmentMissing),
    );
    expect(
      kinds(
        base.copyWith(
          contract: base.contract.copyWith(maximumTotalBorrowedEss: 80),
        ),
      ),
      contains(MultisourceFindingKind.borrowingUnbounded),
    );
  });

  test(
    'predictive criticism and sensitivities cannot be omitted or relabeled',
    () {
      expect(
        kinds(
          base.copyWith(
            criticismResults: base.criticismResults
                .where(
                  (item) =>
                      item.kind !=
                      MultisourceCriticismKind.simulationBasedCalibration,
                )
                .toList(),
          ),
        ),
        contains(MultisourceFindingKind.criticismIncomplete),
      );
      final negative = base.criticismResults.firstWhere(
        (item) => item.kind == MultisourceCriticismKind.negativeControl,
      );
      expect(
        kinds(
          base.copyWith(
            criticismResults: [
              for (final item in base.criticismResults)
                if (item.checkId == negative.checkId)
                  item.copyWith(passed: false, observedValue: 0.2)
                else
                  item,
            ],
          ),
        ),
        contains(MultisourceFindingKind.negativeControlFailure),
      );
      expect(
        kinds(base.copyWith(sourceOrderInvariant: false)),
        contains(MultisourceFindingKind.sourceOrderDrift),
      );
    },
  );

  test('scenario omission and operating-result arithmetic fail closed', () {
    expect(
      kinds(
        base.copyWith(operatingResults: base.operatingResults.skip(1).toList()),
      ),
      contains(MultisourceFindingKind.resultOmission),
    );
    expect(
      kinds(
        base.copyWith(
          operatingResults: [
            base.operatingResults.first.copyWith(decisionProbability: 0.99),
            ...base.operatingResults.skip(1),
          ],
        ),
      ),
      contains(MultisourceFindingKind.operatingResultMismatch),
    );
  });

  test(
    'independent Python identity and manufactured values are exact-bound',
    () {
      expect(
        kinds(
          base.copyWith(
            independentReplication: base.independentReplication.copyWith(
              scriptSha256: 'a' * 64,
            ),
          ),
        ),
        contains(MultisourceFindingKind.independentImplementationMismatch),
      );
      expect(
        kinds(
          base.copyWith(
            independentReplication: base.independentReplication.copyWith(
              casePosteriorMeans: {
                ...base.independentReplication.casePosteriorMeans,
                'aligned': 0.9,
              },
            ),
          ),
        ),
        contains(MultisourceFindingKind.independentImplementationMismatch),
      );
    },
  );

  test('schema, upstream identity, chronology, and revocation fail closed', () {
    expect(
      kinds(base.copyWith(schemaVersion: 2)),
      contains(MultisourceFindingKind.schemaUnsupported),
    );
    expect(
      kinds(base.copyWith(bayesianPackageSha256: 'b' * 64)),
      contains(MultisourceFindingKind.identityMismatch),
    );
    expect(
      kinds(base.copyWith(analysisCompletedAtUtc: '2026-08-26T12:04:00Z')),
      contains(MultisourceFindingKind.historyBroken),
    );
    expect(
      verifier.verify(base.copyWith(revoked: true)).status,
      MultisourceGovernanceStatus.revoked,
    );
  });
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
