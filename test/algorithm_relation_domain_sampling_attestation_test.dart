import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_relation_domain_sampling_attestation.dart';

void main() {
  const verifier = AlgorithmRelationDomainSamplingVerifier();

  test('committed sampled-domain attestation is current and bounded', () {
    final attestation = AlgorithmRelationDomainSamplingAttestation.current();
    final assessment = verifier.verify(attestation);

    expect(assessment.passed, isTrue, reason: assessment.findings.join('\n'));
    expect(attestation.relationCount, 8);
    expect(attestation.caseCount, 160);
    expect(attestation.preconditionHoldCount, 64);
    expect(attestation.mutationKilledCount, 32);
    expect(attestation.mutationSurvivorCount, 0);
    expect(attestation.falseRelationRejectedCount, 3);
    expect(attestation.falseAlarmRate, 0.75);
    expect(attestation.falseAlarmCalibrationPassed, isTrue);
    expect(attestation.productionApiCaseCount, 96);
    expect(attestation.productionApiInvocationCount, 624);
    expect(attestation.productionIndependentEvaluationCount, 96);
    expect(attestation.productionRelationPassedCount, 96);
    expect(attestation.productionPreconditionHoldCount, 64);
    expect(
      attestation.toJson()['boundary'],
      contains('executes paired Dart production APIs'),
    );
    expect(
      attestation.toJson()['schema'],
      algorithmRelationDomainSamplingReportSchema,
    );
    expect(
      attestation.toJson()['schema_version'],
      algorithmRelationDomainSamplingReportSchemaVersion,
    );
    expect(attestation.toJson()['false_alarm_calibration_passed'], isTrue);
    expect(
      attestation.toJson()['defective_relation_calibration_policy'],
      containsPair(
        'scope',
        AlgorithmRelationDomainSamplingAttestation.falseAlarmCalibrationScope,
      ),
    );
    expect(
      attestation.toJson()['defective_relation_calibration_policy'],
      containsPair('production_false_positive_rate_status', 'not_estimated'),
    );
  });

  test('identity, survivor, hold, and false-alarm drift fails closed', () {
    final baseline = AlgorithmRelationDomainSamplingAttestation.current();
    final mutations = <AlgorithmRelationDomainSamplingAttestation>[
      baseline.copyWith(planSha256: _digest('0')),
      baseline.copyWith(relationRegistrySha256: _digest('1')),
      baseline.copyWith(samplerSha256: _digest('2')),
      baseline.copyWith(productionAnchorReportSha256: _digest('3')),
      baseline.copyWith(productionExecutionReportSha256: _digest('4')),
      baseline.copyWith(productionExecutionRunnerSha256: _digest('5')),
      baseline.copyWith(productionExecutorSha256: _digest('6')),
      baseline.copyWith(executableSpecificationSha256: _digest('7')),
      baseline.copyWith(configurationSha256: _digest('8')),
      baseline.copyWith(sourceBundleSha256: _digest('9')),
      baseline.copyWith(reportSha256: _digest('a')),
      baseline.copyWith(relationPassedCount: 7),
      baseline.copyWith(productionApiCaseCount: 95),
      baseline.copyWith(productionApiInvocationCount: 623),
      baseline.copyWith(productionIndependentEvaluationCount: 95),
      baseline.copyWith(productionRelationPassedCount: 95),
      baseline.copyWith(productionPreconditionHoldCount: 63),
      baseline.copyWith(preconditionHoldCount: 63),
      baseline.copyWith(mutationKilledCount: 31, mutationSurvivorCount: 1),
      baseline.copyWith(falseAlarmCount: 95),
      baseline.copyWith(falseAlarmDenominator: 127),
    ];
    for (final mutation in mutations) {
      final assessment = verifier.verify(mutation);
      expect(assessment.passed, isFalse, reason: mutation.toJson().toString());
      expect(assessment.findings, isNotEmpty);
    }
  });

  test('malformed digest is invalid rather than merely stale', () {
    final assessment = verifier.verify(
      AlgorithmRelationDomainSamplingAttestation.current().copyWith(
        reportSha256: 'not-a-digest',
      ),
    );
    expect(assessment.status, AlgorithmRelationDomainSamplingStatus.invalid);
    expect(assessment.findings, contains('sampling.report_identity_invalid'));
  });
}

String _digest(String character) => List<String>.filled(64, character).join();
