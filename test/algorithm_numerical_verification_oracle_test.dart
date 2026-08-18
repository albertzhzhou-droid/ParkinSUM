import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_descriptor.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_numerical_verification_oracle.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

void main() {
  const oracle = AlgorithmNumericalVerificationOracle();

  test('independent reference vectors verify all six production providers', () {
    final report = oracle.run();

    expect(report.blockReasonCode, isNull);
    expect(report.failedCaseCount, 0);
    expect(report.passedCaseCount, 19);
    expect(
      report.coveredAlgorithmIds,
      AlgorithmNumericalVerificationOracle.requiredCoveredAlgorithmIds,
    );
    expect(
      report.coveredAlgorithmIds,
      AlgorithmObservatoryService.traceProviderContract.algorithmIds.toSet(),
    );
    for (final id in report.coveredAlgorithmIds) {
      expect(
        report.statusFor(id),
        AlgorithmNumericalOracleStatus.verified,
        reason: id,
      );
    }
    expect(
      report.statusFor('runtime_rule_engine'),
      AlgorithmNumericalOracleStatus.notCovered,
    );
  });

  test('truth manifest is stable, finite, unique, and method-bounded', () {
    expect(
      AlgorithmNumericalVerificationOracle.manifestDigest,
      '1fa29e4dfdf32882739b7372029591b1898850996154d221c5df858e050f65e3',
    );
    final vectors = AlgorithmNumericalVerificationOracle.truthVectors;
    expect(vectors.map((entry) => entry.id).toSet(), hasLength(vectors.length));
    for (final vector in vectors) {
      expect(vector.expectedValue.isFinite, isTrue, reason: vector.id);
      expect(vector.absoluteTolerance.isFinite, isTrue, reason: vector.id);
      expect(
        vector.absoluteTolerance,
        greaterThanOrEqualTo(0),
        reason: vector.id,
      );
      expect(vector.method.trim(), isNotEmpty, reason: vector.id);
      expect(vector.specification.trim(), isNotEmpty, reason: vector.id);
      expect(vector.unit.trim(), isNotEmpty, reason: vector.id);
    }
  });

  test('time-scale, weight, sign, and threshold mutations are rejected', () {
    final baseline = oracle.run();

    AlgorithmNumericalOracleReport mutate(String id, double value) {
      final observations = Map<String, double>.from(baseline.observations)
        ..[id] = value;
      return oracle.verifyObservations(
        observations,
        configurationDigest: baseline.configurationDigest,
      );
    }

    final hourScale = mutate(
      'gastric.remaining_fraction_minute_110',
      baseline.observations['gastric.remaining_fraction_minute_110']! * 60,
    );
    expect(
      hourScale.statusFor('gastric_emptying'),
      AlgorithmNumericalOracleStatus.mismatch,
    );

    final normalizedButWrongWeight = mutate(
      'candidate.oats_final_score',
      baseline.observations['candidate.oats_final_score']! + 0.01,
    );
    expect(
      normalizedButWrongWeight.statusFor('mechanistic_candidate_scorer'),
      AlgorithmNumericalOracleStatus.mismatch,
    );

    final signFlip = mutate(
      'conflict.interaction_score',
      -baseline.observations['conflict.interaction_score']!,
    );
    expect(
      signFlip.statusFor('mechanistic_conflict'),
      AlgorithmNumericalOracleStatus.mismatch,
    );

    final thresholdOffByOne = mutate('competition.band_index', 2);
    expect(
      thresholdOffByOne.statusFor('amino_acid_competition'),
      AlgorithmNumericalOracleStatus.mismatch,
    );
  });

  test('missing, extra, and non-finite observations fail closed', () {
    final baseline = oracle.run();
    final missing = Map<String, double>.from(baseline.observations)
      ..remove('absorption.relative_start_minutes');
    final missingReport = oracle.verifyObservations(missing);
    expect(missingReport.blockReasonCode, 'oracle.observation_shape_mismatch');
    expect(
      missingReport.statusFor('levodopa_absorption_opportunity'),
      AlgorithmNumericalOracleStatus.blocked,
    );

    final extra = Map<String, double>.from(baseline.observations)
      ..['unreviewed.metric'] = 1;
    expect(
      oracle.verifyObservations(extra).blockReasonCode,
      'oracle.observation_shape_mismatch',
    );

    final nonFinite = Map<String, double>.from(baseline.observations)
      ..['competition.overlap'] = double.nan;
    final nonFiniteReport = oracle.verifyObservations(nonFinite);
    expect(nonFiniteReport.blockReasonCode, isNull);
    expect(
      nonFiniteReport.statusFor('amino_acid_competition'),
      AlgorithmNumericalOracleStatus.mismatch,
    );
    expect(
      jsonEncode(
        nonFiniteReport.toJson(AlgorithmRegistry.all.map((entry) => entry.id)),
      ),
      isNot(contains('NaN')),
    );
  });

  test(
    'report exports every registry status and the non-clinical boundary',
    () {
      final report = oracle.run();
      final json = report.toJson(
        AlgorithmRegistry.all.map((entry) => entry.id),
      );
      final statuses = json['algorithm_status'] as Map<String, String>;

      expect(statuses, hasLength(AlgorithmRegistry.all.length));
      expect(json['schema_version'], algorithmNumericalOracleSchemaVersion);
      expect(json['oracle_id'], algorithmNumericalOracleId);
      expect(json['boundary'], contains('not biological validation'));
      expect(
        AlgorithmRegistry.all.where((entry) => entry.hasLiveTrace),
        everyElement(
          isA<AlgorithmDescriptor>().having(
            (entry) => statuses[entry.id],
            'oracle status',
            'verified',
          ),
        ),
      );
    },
  );
}
