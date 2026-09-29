import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_contract_independent_oracle_attestation.dart';

void main() {
  const verifier = AlgorithmContractIndependentOracleVerifier();

  test('committed cross-runtime attestation is current and explicit', () {
    final attestation = AlgorithmContractIndependentOracleAttestation.current();
    final assessment = verifier.verify(attestation);

    expect(assessment.passed, isTrue, reason: assessment.findings.join('\n'));
    expect(
      assessment.status,
      AlgorithmContractIndependentOracleStatus.verifiedOffline,
    );
    expect(attestation.relationCount, 8);
    expect(attestation.relationPassedCount, 8);
    expect(attestation.mutationCount, 16);
    expect(attestation.mutationKilledCount, 16);
    expect(attestation.mutationSurvivorCount, 0);
    expect(attestation.invalidRelationRejectedCount, 3);
    expect(attestation.schedulerPassedCount, 6);
    expect(
      attestation.toJson()['boundary'],
      contains('not a live in-app Node execution'),
    );
  });

  test(
    'identity drift, survivors, false relations and scheduler gaps fail',
    () {
      final baseline = AlgorithmContractIndependentOracleAttestation.current();
      final mutations = <AlgorithmContractIndependentOracleAttestation>[
        baseline.copyWith(relationRegistrySha256: _digest('0')),
        baseline.copyWith(independentOracleSha256: _digest('1')),
        baseline.copyWith(executableSpecificationSha256: _digest('2')),
        baseline.copyWith(configurationSha256: _digest('3')),
        baseline.copyWith(sourceBundleSha256: _digest('4')),
        baseline.copyWith(reportSha256: _digest('5')),
        baseline.copyWith(mutationKilledCount: 15, mutationSurvivorCount: 1),
        baseline.copyWith(invalidRelationRejectedCount: 2),
        baseline.copyWith(schedulerPassedCount: 5),
      ];

      for (final mutation in mutations) {
        final assessment = verifier.verify(mutation);
        expect(
          assessment.passed,
          isFalse,
          reason: mutation.toJson().toString(),
        );
        expect(assessment.findings, isNotEmpty);
      }
    },
  );

  test('malformed digest is invalid rather than merely stale', () {
    final assessment = verifier.verify(
      AlgorithmContractIndependentOracleAttestation.current().copyWith(
        reportSha256: 'not-a-digest',
      ),
    );

    expect(assessment.status, AlgorithmContractIndependentOracleStatus.invalid);
    expect(assessment.findings, contains('oracle.report_identity_invalid'));
  });
}

String _digest(String character) => List<String>.filled(64, character).join();
