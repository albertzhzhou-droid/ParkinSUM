import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_executable_contract_gate.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_model_verification_gate.dart';

void main() {
  const gate = AlgorithmExecutableContractGate();

  test('first-wave report passes eight production API contracts', () async {
    final report = await gate.run();

    expect(report.passed, isTrue, reason: _describe(report));
    expect(report.checks, hasLength(8));
    expect(
      report.coveredAlgorithmIds,
      AlgorithmExecutableContractGate.coveredAlgorithmIds.toSet(),
    );
    expect(report.passedCheckCount, 8);
    expect(report.specificationSha256, hasLength(64));
    expect(
      report.configurationSha256,
      AlgorithmConfigurationIdentity.defaults().sha256Digest,
    );
    expect(
      report.sourceBundleSha256,
      AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
    expect(
      report.toJson(AlgorithmRegistry.all.map((entry) => entry.id))['boundary'],
      contains('does not establish scientific truth'),
    );
  });

  test('combined executable and mathematical coverage is 30 of 65', () async {
    final executable = await gate.run();
    final mathematical = const MechanisticModelVerificationGate().run();
    final combined = <String>{
      ...executable.coveredAlgorithmIds,
      ...mathematical.coveredAlgorithmIds,
    };

    expect(AlgorithmRegistry.all, hasLength(65));
    expect(mathematical.checks, hasLength(23));
    expect(mathematical.coveredAlgorithmIds, hasLength(22));
    expect(
      AlgorithmRegistry.all.length - mathematical.coveredAlgorithmIds.length,
      43,
    );
    expect(executable.coveredAlgorithmIds, hasLength(8));
    expect(combined, hasLength(30));
    expect(AlgorithmRegistry.all.length - combined.length, 35);
  });

  test(
    'each deliberate observation mutation fails only its algorithm',
    () async {
      final baseline = await gate.run();
      expect(baseline.passed, isTrue, reason: _describe(baseline));

      for (final spec in AlgorithmExecutableContractGate.specifications) {
        final observations = _copyObservations(baseline.observationPayloads);
        observations[spec.id] = <String, Object?>{
          ...observations[spec.id]!,
          'deliberate_mutation': spec.id,
        };
        final mutated = gate.verifyObservations(observations);
        expect(mutated.passed, isFalse, reason: spec.id);
        expect(
          mutated.statusFor(spec.algorithmId),
          AlgorithmExecutableContractStatus.failed,
          reason: spec.id,
        );
        for (final other
            in AlgorithmExecutableContractGate.coveredAlgorithmIds) {
          if (other == spec.algorithmId) continue;
          expect(
            mutated.statusFor(other),
            AlgorithmExecutableContractStatus.passed,
            reason: '$other changed when only ${spec.algorithmId} was mutated',
          );
        }
      }
    },
  );

  test('missing extra non-finite and identity drift fail closed', () async {
    final baseline = await gate.run();
    final missing = _copyObservations(baseline.observationPayloads)
      ..remove(AlgorithmExecutableContractGate.specifications.first.id);
    expect(gate.verifyObservations(missing).passed, isFalse);

    final extra = _copyObservations(baseline.observationPayloads)
      ..['unexpected.contract'] = <String, Object?>{'passed': true};
    final extraReport = gate.verifyObservations(extra);
    expect(extraReport.passed, isFalse);
    expect(
      extraReport.integrityFailureCodes,
      contains('contract.extra_observation'),
    );

    final nonFinite = _copyObservations(baseline.observationPayloads);
    final firstId = AlgorithmExecutableContractGate.specifications.first.id;
    nonFinite[firstId] = <String, Object?>{'value': double.nan};
    expect(
      gate.verifyObservations(nonFinite).checks.first.failureCodes,
      contains('contract.observation_non_finite'),
    );

    final identityDrift = gate.verifyObservations(
      baseline.observationPayloads,
      configurationSha256: List<String>.filled(64, '0').join(),
      sourceBundleSha256: List<String>.filled(64, '1').join(),
    );
    expect(identityDrift.passed, isFalse);
    expect(
      identityDrift.integrityFailureCodes,
      containsAll(<String>[
        'contract.configuration_identity_drift',
        'contract.source_bundle_identity_drift',
      ]),
    );
  });

  test(
    'async execution blockage is distinct from a failed observation',
    () async {
      final baseline = await gate.run();
      final id = AlgorithmExecutableContractGate.specifications.last.id;
      final report = gate.verifyObservations(
        baseline.observationPayloads,
        blockedChecks: <String, String>{
          id: 'contract.fixture_transport_blocked',
        },
      );

      expect(
        report.statusFor('local_ai_adapter'),
        AlgorithmExecutableContractStatus.blocked,
      );
      expect(report.checks.last.failureCodes, <String>[
        'contract.fixture_transport_blocked',
      ]);
    },
  );

  test('same fixed run produces byte-stable contract evidence', () async {
    final first = await gate.run();
    final second = await gate.run();
    final ids = AlgorithmRegistry.all.map((entry) => entry.id);
    expect(jsonEncode(first.toJson(ids)), jsonEncode(second.toJson(ids)));
  });

  test('all applicable partitions execute paired production samples', () async {
    var invocationCount = 0;
    for (final specification
        in AlgorithmExecutableContractGate.specifications) {
      for (final partition in const <String>[
        'normal',
        'boundary',
        'adversarial',
      ]) {
        final execution = await gate.runProductionSample(
          relationId: specification.id,
          partition: partition,
          seed: 0x5eed1234,
        );
        expect(execution.relationId, specification.id);
        expect(execution.partition, partition);
        expect(execution.sourceInput, isNotEmpty);
        expect(execution.followUpInput, isNotEmpty);
        expect(execution.sourceOutput, isNotEmpty);
        expect(execution.followUpOutput, isNotEmpty);
        expect(execution.relationObservation, isNotEmpty);
        expect(execution.productionApiInvocationCount, greaterThan(0));
        invocationCount += execution.productionApiInvocationCount;
      }
    }
    expect(invocationCount, greaterThan(100));
  });

  test('non-applicable partitions are held before production execution', () {
    expect(
      () => gate.runProductionSample(
        relationId: AlgorithmExecutableContractGate.specifications.first.id,
        partition: 'missing',
        seed: 1,
      ),
      throwsArgumentError,
    );
  });
}

Map<String, Map<String, Object?>> _copyObservations(
  Map<String, Map<String, Object?>> source,
) => (jsonDecode(jsonEncode(source)) as Map<String, dynamic>).map(
  (key, value) => MapEntry(key, Map<String, Object?>.from(value as Map)),
);

String _describe(AlgorithmExecutableContractReport report) => report.checks
    .map(
      (check) =>
          '${check.spec.id}: ${check.status.name} ${check.failureCodes} ${check.observation}',
    )
    .join('\n');
