import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_blinded_replication.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/credibility_protocol_transparency_ledger.dart';
import 'package:parkinsum_companion/domain/entities/credibility_statistical_analysis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  const verifier = CredibilityStatisticalAnalysisVerifier();

  CredibilityStatisticalAnalysisPackage current() {
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
    return CredibilityStatisticalAnalysisPackage.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      protocolLedgerSha256: ledger.ledgerSha256,
      replicationPackageSha256: replication.packageSha256,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
  }

  Set<StatisticalFindingKind> kinds(
    CredibilityStatisticalAnalysisPackage package,
  ) => verifier.verify(package).findings.map((item) => item.kind).toSet();

  test('clean package exposes seven bounded statistical evidence lanes', () {
    final package = current();
    final assessment = verifier.verify(package);

    expect(assessment.status, StatisticalGovernanceStatus.mechanicallyObserved);
    expect(assessment.integrityVerified, isTrue);
    expect(assessment.findings, isEmpty);
    expect(assessment.lanes.keys, {
      'design',
      'estimand',
      'estimate',
      'uncertainty',
      'errorControl',
      'sensitivity',
      'deviations',
    });
    expect(
      assessment.outcomeStatusCounts,
      containsPair(StatisticalResultStatus.reported, 1),
    );
    expect(
      assessment.outcomeStatusCounts,
      containsPair(StatisticalResultStatus.nullResult, 1),
    );
    expect(
      assessment.outcomeStatusCounts,
      containsPair(StatisticalResultStatus.inconclusive, 1),
    );
    expect(
      assessment.outcomeStatusCounts,
      containsPair(StatisticalResultStatus.failed, 1),
    );
    expect(
      assessment.outcomeStatusCounts,
      containsPair(StatisticalResultStatus.adverse, 1),
    );
    expect(assessment.canSupportClinicalInference, isFalse);
    expect(jsonEncode(package.toJson()), isNot(contains('patient_id')));
  });

  test('incomplete estimand and intercurrent-event handling fail closed', () {
    final base = current();
    final changed = base.estimands.single.copyWith(
      scientificQuestion: '',
      intercurrentEvents: const [],
    );
    expect(
      kinds(base.copyWith(estimands: [changed])),
      contains(StatisticalFindingKind.estimandMismatch),
    );
  });

  test('analysis-set and missing-data drift are retained', () {
    final base = current();
    final changed = base.results.first.copyWith(
      analysisSetId: 'analysis_set.post_result_subset',
      missingDataMethodId: 'missing.post_result_complete_case',
    );
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      containsAll(const {
        StatisticalFindingKind.analysisSetChanged,
        StatisticalFindingKind.missingDataMethodChanged,
      }),
    );
  });

  test('alpha inflation and absent multiplicity fail closed', () {
    final base = current();
    expect(
      kinds(
        base.copyWith(
          errorControl: base.errorControl.copyWith(
            overallAlpha: 0.10,
            confidenceLevel: 0.90,
            multiplicityMethod: StatisticalMultiplicityMethod.noneSinglePrimary,
          ),
        ),
      ),
      containsAll(const {
        StatisticalFindingKind.alphaInflation,
        StatisticalFindingKind.multiplicityMissing,
      }),
    );
  });

  test('interval and p-value disagreement fail closed', () {
    final base = current();
    final changed = base.results.first.copyWith(
      pValue: 0.20,
      multiplicityAdjustedPValue: 0.20,
    );
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      contains(StatisticalFindingKind.pValueIntervalMismatch),
    );
  });

  test('denominator and sample-size drift fail closed', () {
    final base = current();
    final changed = base.results.first.copyWith(denominator: 50);
    expect(
      kinds(base.copyWith(results: [changed, ...base.results.skip(1)])),
      contains(StatisticalFindingKind.denominatorMismatch),
    );
    expect(
      kinds(
        base.copyWith(
          errorControl: base.errorControl.copyWith(targetPower: 0.60),
        ),
      ),
      contains(StatisticalFindingKind.sampleSizeDrift),
    );
  });

  test('every planned endpoint must retain an explicit outcome', () {
    final base = current();
    expect(
      kinds(base.copyWith(results: base.results.skip(1).toList())),
      contains(StatisticalFindingKind.resultOmitted),
    );
  });

  test('sensitivity analysis stays planned and on the same estimand', () {
    final base = current();
    final changed = base.sensitivityResults.first.copyWith(
      estimandId: 'estimand.changed_after_results',
      prospectivelyPlanned: false,
    );
    expect(
      kinds(
        base.copyWith(
          sensitivityResults: [changed, ...base.sensitivityResults.skip(1)],
        ),
      ),
      containsAll(const {
        StatisticalFindingKind.sensitivityEstimandChanged,
        StatisticalFindingKind.unplannedSensitivity,
      }),
    );
  });

  test('post-result protected choice changes fail closed', () {
    final base = current();
    final changed = base.deviationEvents.single.copyWith(
      resultsVisible: true,
      affectedContractFields: const ['alpha', 'estimand'],
    );
    expect(
      kinds(base.copyWith(deviationEvents: [changed])),
      contains(StatisticalFindingKind.postResultChange),
    );
  });

  test('broken deviation chain and clock are rejected', () {
    final base = current();
    final changed = base.deviationEvents.single.copyWith(
      sequence: 2,
      predecessorSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      occurredAtUtc: 'not-a-clock',
    );
    expect(
      kinds(base.copyWith(deviationEvents: [changed])),
      contains(StatisticalFindingKind.deviationChainBroken),
    );
  });

  test('unaccepted deviation is held rather than silently accepted', () {
    final base = current();
    final assessment = verifier.verify(
      base.copyWith(
        deviationEvents: [
          base.deviationEvents.single.copyWith(accepted: false),
        ],
      ),
    );
    expect(assessment.status, StatisticalGovernanceStatus.held);
    expect(assessment.lanes['deviations'], 'held');
  });

  test('future schema is unknown and explicit revocation is terminal', () {
    final base = current();
    expect(
      verifier.verify(base.copyWith(schemaVersion: 2)).status,
      StatisticalGovernanceStatus.unknown,
    );
    expect(
      verifier.verify(base.copyWith(revoked: true)).status,
      StatisticalGovernanceStatus.revoked,
    );
  });

  test('payload is deterministic and collection views are immutable', () {
    final package = current();
    expect(package.packageSha256, package.packageSha256);
    expect(jsonEncode(package.toJson()), jsonEncode(current().toJson()));
    expect(
      () => package.results.add(package.results.first),
      throwsUnsupportedError,
    );
  });
}
