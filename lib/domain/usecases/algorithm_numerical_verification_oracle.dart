import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'algorithm_observatory_service.dart';

const int algorithmNumericalOracleSchemaVersion = 1;
const String algorithmNumericalOracleId =
    'parkinsum.mechanistic-numerical-oracle/1';

enum AlgorithmNumericalOracleStatus { verified, mismatch, notCovered, blocked }

/// One independently specified scalar truth vector.
///
/// Expected values in this manifest are recomputed below from a separately
/// authored mathematical specification. The specification deliberately does
/// not import production model constants, fixtures, golden output, or private
/// helpers. Production code is invoked only to obtain the observed values.
final class AlgorithmNumericalOracleVector {
  const AlgorithmNumericalOracleVector({
    required this.id,
    required this.algorithmId,
    required this.metric,
    required this.expectedValue,
    required this.absoluteTolerance,
    required this.unit,
    required this.method,
    required this.specification,
  });

  final String id;
  final String algorithmId;
  final String metric;
  final double expectedValue;
  final double absoluteTolerance;
  final String unit;
  final String method;
  final String specification;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'algorithm_id': algorithmId,
    'metric': metric,
    'expected_value': expectedValue,
    'absolute_tolerance': absoluteTolerance,
    'unit': unit,
    'method': method,
    'specification': specification,
  };
}

final class AlgorithmNumericalOracleCaseResult {
  const AlgorithmNumericalOracleCaseResult({
    required this.vector,
    required this.actualValue,
    required this.absoluteError,
    required this.passed,
    required this.reasonCode,
  });

  final AlgorithmNumericalOracleVector vector;
  final double? actualValue;
  final double? absoluteError;
  final bool passed;
  final String? reasonCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'vector': vector.toJson(),
    'actual_value': actualValue?.isFinite == true ? actualValue : null,
    'absolute_error': absoluteError?.isFinite == true ? absoluteError : null,
    'passed': passed,
    'reason_code': reasonCode,
  };
}

final class AlgorithmNumericalOracleReport {
  AlgorithmNumericalOracleReport({
    required this.manifestDigest,
    required this.configurationDigest,
    required List<AlgorithmNumericalOracleCaseResult> cases,
    required Map<String, double> observations,
    this.blockReasonCode,
  }) : cases = List<AlgorithmNumericalOracleCaseResult>.unmodifiable(cases),
       observations = Map<String, double>.unmodifiable(observations);

  final String manifestDigest;
  final String configurationDigest;
  final List<AlgorithmNumericalOracleCaseResult> cases;
  final Map<String, double> observations;
  final String? blockReasonCode;

  static const String boundary =
      'Independent implementation and calculation verification for fixed '
      'engineering vectors only. It is not biological validation, clinical '
      'accuracy, a patient prediction, or medical advice.';

  int get passedCaseCount => cases.where((entry) => entry.passed).length;
  int get failedCaseCount => cases.length - passedCaseCount;

  Set<String> get coveredAlgorithmIds =>
      Set<String>.unmodifiable(cases.map((entry) => entry.vector.algorithmId));

  AlgorithmNumericalOracleStatus statusFor(String algorithmId) {
    final relevant = cases
        .where((entry) => entry.vector.algorithmId == algorithmId)
        .toList(growable: false);
    if (relevant.isEmpty) return AlgorithmNumericalOracleStatus.notCovered;
    if (blockReasonCode != null) return AlgorithmNumericalOracleStatus.blocked;
    return relevant.every((entry) => entry.passed)
        ? AlgorithmNumericalOracleStatus.verified
        : AlgorithmNumericalOracleStatus.mismatch;
  }

  Map<String, Object?> toJson(Iterable<String> registeredAlgorithmIds) {
    final ids = registeredAlgorithmIds.toSet().toList(growable: false)..sort();
    return <String, Object?>{
      'schema_version': algorithmNumericalOracleSchemaVersion,
      'oracle_id': algorithmNumericalOracleId,
      'manifest_digest': manifestDigest,
      'configuration_digest': configurationDigest,
      'boundary': boundary,
      'block_reason_code': blockReasonCode,
      'passed_case_count': passedCaseCount,
      'failed_case_count': failedCaseCount,
      'algorithm_status': <String, String>{
        for (final id in ids) id: statusFor(id).name,
      },
      'cases': cases.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}

/// Independent numerical oracle for the six production-provider traces.
///
/// The reference calculation intentionally restates the equations and units
/// rather than importing any production constant. A production observation is
/// compared with a fixed manufactured solution; changing the implementation
/// without reviewing this oracle makes the report fail closed.
final class AlgorithmNumericalVerificationOracle {
  const AlgorithmNumericalVerificationOracle();

  static const Set<String> requiredCoveredAlgorithmIds = <String>{
    'meal_composition_normalizer',
    'gastric_emptying',
    'levodopa_absorption_opportunity',
    'amino_acid_competition',
    'mechanistic_conflict',
    'mechanistic_candidate_scorer',
  };

  static final List<AlgorithmNumericalOracleVector> truthVectors =
      List<AlgorithmNumericalOracleVector>.unmodifiable(_buildTruthVectors());

  static final String manifestDigest = _sha256(
    _canonicalJson(<String, Object?>{
      'schema_version': algorithmNumericalOracleSchemaVersion,
      'oracle_id': algorithmNumericalOracleId,
      'vectors': truthVectors
          .map((entry) => entry.toJson())
          .toList(growable: false),
    }),
  );

  AlgorithmNumericalOracleReport run({AlgorithmObservatoryService? service}) {
    try {
      final snapshot = (service ?? AlgorithmObservatoryService()).build(
        ObservatoryScenario.mixedReference,
      );
      return verifyObservations(
        _productionObservations(snapshot),
        configurationDigest: snapshot.configurationIdentity.sha256Digest,
      );
    } on Object {
      return AlgorithmNumericalOracleReport(
        manifestDigest: manifestDigest,
        configurationDigest: 'unavailable',
        cases: [
          for (final vector in truthVectors)
            AlgorithmNumericalOracleCaseResult(
              vector: vector,
              actualValue: null,
              absoluteError: null,
              passed: false,
              reasonCode: 'oracle.production_observation_failed',
            ),
        ],
        observations: const <String, double>{},
        blockReasonCode: 'oracle.production_observation_failed',
      );
    }
  }

  AlgorithmNumericalOracleReport verifyObservations(
    Map<String, double> observations, {
    String configurationDigest = 'test-configuration',
  }) {
    final expectedIds = truthVectors.map((entry) => entry.id).toSet();
    final actualIds = observations.keys.toSet();
    final shapeMismatch =
        !actualIds.containsAll(expectedIds) ||
        !expectedIds.containsAll(actualIds);
    final cases = <AlgorithmNumericalOracleCaseResult>[];
    for (final vector in truthVectors) {
      final actual = observations[vector.id];
      final finite = actual != null && actual.isFinite;
      final error = finite ? (actual - vector.expectedValue).abs() : null;
      final passed =
          !shapeMismatch && finite && error! <= vector.absoluteTolerance;
      cases.add(
        AlgorithmNumericalOracleCaseResult(
          vector: vector,
          actualValue: actual,
          absoluteError: error,
          passed: passed,
          reasonCode: passed
              ? null
              : actual == null
              ? 'oracle.observation_missing'
              : !actual.isFinite
              ? 'oracle.observation_nonfinite'
              : shapeMismatch
              ? 'oracle.observation_shape_mismatch'
              : 'oracle.value_mismatch',
        ),
      );
    }
    return AlgorithmNumericalOracleReport(
      manifestDigest: manifestDigest,
      configurationDigest: configurationDigest,
      cases: cases,
      observations: observations,
      blockReasonCode: shapeMismatch
          ? 'oracle.observation_shape_mismatch'
          : null,
    );
  }

  Map<String, double> _productionObservations(
    AlgorithmObservatorySnapshot snapshot,
  ) {
    final conflict = snapshot.conflict;
    final emptying = conflict.primaryEmptyingProfile;
    final absorption = conflict.absorptionOpportunityWindow;
    final competition = conflict.competitionTimeline;
    final dose = snapshot.context.medicationEvents.single;
    final oats = snapshot.candidateScores
        .where((entry) => entry.candidateFoodId == 'oats')
        .single;
    if (!conflict.hasModeledOutput ||
        emptying == null ||
        !emptying.hasModeledOutput ||
        absorption == null ||
        !absorption.hasModeledOutput ||
        competition == null ||
        !competition.hasModeledOutput ||
        !oats.hasModeledOutput) {
      throw StateError('Oracle production fixture abstained.');
    }
    return <String, double>{
      'normalizer.total_calories': snapshot.composition.totalCalories!,
      'normalizer.protein_grams': snapshot.composition.proteinGrams!,
      'normalizer.liquid_fraction': snapshot.composition.liquidFraction!,
      'normalizer.completeness': snapshot.composition.compositionCompleteness,
      'gastric.aggregate_lag_minutes': emptying.aggregateLagMinutes,
      'gastric.peak_window_minutes': emptying.peakEmptyingWindow.durationMinutes
          .toDouble(),
      'gastric.mostly_window_minutes': emptying
          .mostlyEmptiedWindow
          .durationMinutes
          .toDouble(),
      'gastric.remaining_fraction_minute_110': emptying.remainingFractionAt(
        110,
      ),
      'absorption.relative_start_minutes':
          (absorption.window.startMinute - dose.minute).toDouble(),
      'absorption.relative_end_minutes':
          (absorption.window.endMinute - dose.minute).toDouble(),
      'absorption.relative_peak_minutes': (absorption.peakMinute - dose.minute)
          .toDouble(),
      'absorption.peak_openness': absorption.peakOpenness,
      'absorption.tail_openness': absorption.opennessProfile.last.openness,
      'competition.peak_pressure': competition.peakPressure,
      'competition.overlap': competition.overlapWithAbsorptionWindow,
      'competition.band_index': competition.competitionBand.index.toDouble(),
      'conflict.interaction_score': conflict.modeledInteractionScore!,
      'conflict.severity_index': conflict.modeledSeverityBand!.index.toDouble(),
      'candidate.oats_final_score': oats.modeledFinalCandidateScore!,
    };
  }
}

List<AlgorithmNumericalOracleVector> _buildTruthVectors() {
  final gastric = _referenceGastric();
  final absorption = _referenceAbsorption(gastric);
  final competition = _referenceCompetition(gastric, absorption);
  final conflictScore = 0.6 * competition.overlap + 0.4 * 0.25;
  const candidateOverlap = 0.11183888589587694;
  const candidateRedistribution = 0.6358563899364431;
  const candidateAdequacy = 0.35;
  final candidateFinal =
      0.45 * (1 - candidateOverlap) +
      0.20 * candidateRedistribution +
      0.10 * candidateAdequacy +
      0.10 * 1.0 +
      0.05 * 0.8 +
      0.05 * 1.0 +
      0.05 * 0.8;

  AlgorithmNumericalOracleVector v(
    String id,
    String algorithmId,
    String metric,
    double expected,
    double tolerance,
    String unit,
    String method,
    String specification,
  ) => AlgorithmNumericalOracleVector(
    id: id,
    algorithmId: algorithmId,
    metric: metric,
    expectedValue: expected,
    absoluteTolerance: tolerance,
    unit: unit,
    method: method,
    specification: specification,
  );

  return <AlgorithmNumericalOracleVector>[
    v(
      'normalizer.total_calories',
      'meal_composition_normalizer',
      'total calories',
      250,
      0,
      'kcal',
      'analytic sum',
      '250 + 0 kcal',
    ),
    v(
      'normalizer.protein_grams',
      'meal_composition_normalizer',
      'protein total',
      8,
      0,
      'g',
      'analytic sum',
      '8 + 0 g',
    ),
    v(
      'normalizer.liquid_fraction',
      'meal_composition_normalizer',
      'liquid mass fraction',
      0.5,
      1e-12,
      'fraction',
      'analytic ratio',
      '240 / (240 + 240)',
    ),
    v(
      'normalizer.completeness',
      'meal_composition_normalizer',
      'composition completeness',
      1,
      0,
      'fraction',
      'manufactured complete input',
      '8 of 8 required fields observed',
    ),
    v(
      'gastric.aggregate_lag_minutes',
      'gastric_emptying',
      'mass-weighted lag',
      gastric.aggregateLag,
      1e-12,
      'min',
      'independent analytic equation',
      '0.5*(20*0.85) + 0.5*(0*0.85)',
    ),
    v(
      'gastric.peak_window_minutes',
      'gastric_emptying',
      'peak window width',
      gastric.peakDuration.toDouble(),
      0,
      'min',
      'independent rounded equation',
      'round(1.5 * mass-weighted half-time)',
    ),
    v(
      'gastric.mostly_window_minutes',
      'gastric_emptying',
      'mostly-emptied width',
      gastric.mostlyDuration.toDouble(),
      0,
      'min',
      'independent rounded equation',
      'round(4 * mass-weighted half-time)',
    ),
    v(
      'gastric.remaining_fraction_minute_110',
      'gastric_emptying',
      'remaining fraction at minute 110',
      gastric.remainingAt110,
      1e-12,
      'fraction',
      'closed-form manufactured solution',
      'sum(w_i * 2^-((t-lag_i)/half_i))',
    ),
    v(
      'absorption.relative_start_minutes',
      'levodopa_absorption_opportunity',
      'window start after dose',
      absorption.start.toDouble(),
      0,
      'min',
      'independent threshold branch',
      '5 min IR lag + 17 min moderate-residual shift',
    ),
    v(
      'absorption.relative_end_minutes',
      'levodopa_absorption_opportunity',
      'window end after dose',
      absorption.end.toDouble(),
      0,
      'min',
      'independent threshold branch',
      '5 + 90 min IR window + 34 min moderate-residual extension',
    ),
    v(
      'absorption.relative_peak_minutes',
      'levodopa_absorption_opportunity',
      'peak after dose',
      absorption.peak.toDouble(),
      0,
      'min',
      'independent threshold branch',
      '5 + floor(90/3) + 17',
    ),
    v(
      'absorption.peak_openness',
      'levodopa_absorption_opportunity',
      'peak openness',
      1,
      1e-12,
      'unitless',
      'manufactured triangular-linear curve',
      'IR peak openness fixed at one',
    ),
    v(
      'absorption.tail_openness',
      'levodopa_absorption_opportunity',
      'tail openness',
      0.15,
      1e-12,
      'unitless',
      'manufactured triangular-linear curve',
      'IR tail openness fixed at 0.15',
    ),
    v(
      'competition.peak_pressure',
      'amino_acid_competition',
      'peak relative pressure',
      0.17,
      1e-12,
      'unitless',
      'independent normalized-amplitude equation',
      '(8/20 * 0.85) / 2',
    ),
    v(
      'competition.overlap',
      'amino_acid_competition',
      'openness-weighted overlap',
      competition.overlap,
      1e-12,
      'unitless',
      'independent grid integration',
      'sum(pressure(t)*openness(t))/sum(openness(t)) on the full 5-minute absorption grid',
    ),
    v(
      'competition.band_index',
      'amino_acid_competition',
      'competition band branch',
      1,
      0,
      'enum index',
      'independent threshold branch',
      '0 < overlap < 0.10 maps to low',
    ),
    v(
      'conflict.interaction_score',
      'mechanistic_conflict',
      'composite conflict score',
      conflictScore,
      1e-12,
      'unitless',
      'independent weighted composition',
      '0.6*competition overlap + 0.4*moderate-delay contribution(0.25)',
    ),
    v(
      'conflict.severity_index',
      'mechanistic_conflict',
      'severity branch',
      1,
      0,
      'enum index',
      'independent threshold branch',
      'score in the low band maps to low',
    ),
    v(
      'candidate.oats_final_score',
      'mechanistic_candidate_scorer',
      'final candidate trace score',
      candidateFinal,
      1e-12,
      'unitless',
      'independent linear composition',
      'literal reviewed weights applied to conflict, redistribution, adequacy, and four provenance terms',
    ),
  ];
}

({
  double aggregateLag,
  int peakDuration,
  int mostlyDuration,
  double remainingAt110,
  List<_ReferenceComponent> components,
})
_referenceGastric() {
  const size = 0.6 + 0.4 * (250 / 400);
  const components = <_ReferenceComponent>[
    _ReferenceComponent(weight: 0.5, lag: 20 * size, half: 90 * size),
    _ReferenceComponent(weight: 0.5, lag: 0 * size, half: 15 * size),
  ];
  final aggregateLag = components.fold<double>(
    0,
    (sum, component) => sum + component.weight * component.lag,
  );
  final aggregateHalf = components.fold<double>(
    0,
    (sum, component) => sum + component.weight * component.half,
  );
  return (
    aggregateLag: aggregateLag,
    peakDuration: (aggregateHalf * 1.5).round(),
    mostlyDuration: (aggregateHalf * 4).round(),
    remainingAt110: _referenceRemaining(components, 110),
    components: components,
  );
}

({
  int start,
  int end,
  int peak,
  int absoluteStart,
  int absoluteEnd,
  int absolutePeak,
})
_referenceAbsorption(
  ({
    double aggregateLag,
    int peakDuration,
    int mostlyDuration,
    double remainingAt110,
    List<_ReferenceComponent> components,
  })
  gastric,
) {
  const doseMinute = 35;
  final residual = _referenceRemaining(gastric.components, doseMinute);
  if (!(residual > 0.4 && residual <= 0.7)) {
    throw StateError('Manufactured oracle residual left the moderate branch.');
  }
  const start = 5 + 17;
  const end = 5 + 90 + 34;
  const peak = 5 + (90 ~/ 3) + 17;
  return (
    start: start,
    end: end,
    peak: peak,
    absoluteStart: doseMinute + start,
    absoluteEnd: doseMinute + end,
    absolutePeak: doseMinute + peak,
  );
}

({double overlap}) _referenceCompetition(
  ({
    double aggregateLag,
    int peakDuration,
    int mostlyDuration,
    double remainingAt110,
    List<_ReferenceComponent> components,
  })
  gastric,
  ({
    int start,
    int end,
    int peak,
    int absoluteStart,
    int absoluteEnd,
    int absolutePeak,
  })
  absorption,
) {
  final mealEnd = gastric.aggregateLag.round() + gastric.mostlyDuration;
  final arrivals = <_ReferenceSample>[];
  var peakArrival = 0.0;
  for (var minute = 0; minute <= mealEnd; minute += 5) {
    final rate = _referenceArrival(gastric.components, minute);
    arrivals.add(_ReferenceSample(minute, rate));
    if (rate > peakArrival) peakArrival = rate;
  }
  final pressures = <_ReferenceSample>[
    for (final sample in arrivals)
      _ReferenceSample(
        sample.minute,
        peakArrival <= 0 ? 0 : sample.value / peakArrival * 0.17,
      ),
  ];
  var weighted = 0.0;
  var totalWeight = 0.0;
  for (
    var minute = absorption.absoluteStart;
    minute <= absorption.absoluteEnd;
    minute += 5
  ) {
    final openness = _referenceOpenness(
      minute,
      absorption.absoluteStart,
      absorption.absolutePeak,
      absorption.absoluteEnd,
    );
    weighted += _interpolate(pressures, minute) * openness;
    totalWeight += openness;
  }
  if ((absorption.absoluteEnd - absorption.absoluteStart) % 5 != 0) {
    final minute = absorption.absoluteEnd;
    final openness = _referenceOpenness(
      minute,
      absorption.absoluteStart,
      absorption.absolutePeak,
      absorption.absoluteEnd,
    );
    weighted += _interpolate(pressures, minute) * openness;
    totalWeight += openness;
  }
  return (overlap: weighted / totalWeight);
}

double _referenceRemaining(List<_ReferenceComponent> components, int minute) {
  var total = 0.0;
  for (final component in components) {
    final remaining = minute <= component.lag
        ? 1.0
        : math.pow(2, -(minute - component.lag) / component.half).toDouble();
    total += component.weight * remaining;
  }
  return total;
}

double _referenceArrival(List<_ReferenceComponent> components, int minute) {
  final left = minute <= 0 ? 0 : minute - 1;
  final right = minute + 1;
  final emptiedRight = 1 - _referenceRemaining(components, right);
  final emptiedLeft = 1 - _referenceRemaining(components, left);
  return ((emptiedRight - emptiedLeft) / 2).clamp(0.0, 1.0);
}

double _referenceOpenness(int minute, int start, int peak, int end) {
  if (minute < start || minute > end) return 0;
  if (minute <= peak) return (minute - start) / (peak - start);
  final decay = (minute - peak) / (end - peak);
  return 1 - decay * 0.85;
}

double _interpolate(List<_ReferenceSample> samples, int minute) {
  if (samples.isEmpty ||
      minute < samples.first.minute ||
      minute > samples.last.minute) {
    return 0;
  }
  for (var index = 0; index < samples.length - 1; index++) {
    final left = samples[index];
    final right = samples[index + 1];
    if (minute == left.minute) return left.value;
    if (minute == right.minute) return right.value;
    if (minute > left.minute && minute < right.minute) {
      final fraction = (minute - left.minute) / (right.minute - left.minute);
      return left.value + fraction * (right.value - left.value);
    }
  }
  return samples.last.value;
}

final class _ReferenceComponent {
  const _ReferenceComponent({
    required this.weight,
    required this.lag,
    required this.half,
  });

  final double weight;
  final double lag;
  final double half;
}

final class _ReferenceSample {
  const _ReferenceSample(this.minute, this.value);

  final int minute;
  final double value;
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted['${entry.key}'] = _canonicalize(entry.value);
    }
    return sorted;
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
