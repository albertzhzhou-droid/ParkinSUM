import 'dart:convert';

import 'package:crypto/crypto.dart';

const int gastricStructuralUncertaintySchemaVersion = 1;
const String gastricStructuralUncertaintySchema =
    'parkinsum.gastric-structural-uncertainty-report/1';

enum GastricMeasuredObservable {
  normalizedIntragastricRetention,
  absoluteGastricVolume,
  pelletRetention,
}

enum GastricMeasurementModality { scintigraphy, magneticResonanceImaging }

enum GastricStructureKind {
  productionComponentLagExponential,
  elashoffPowerExponential,
  siegelModifiedPowerExponential,
  explicitLagExponential,
  linearExponentialVolume,
  doubleWeibullPellet,
}

enum GastricParameterAuthority { productionBound, priorFixed, fitted }

enum GastricTrajectoryAvailability {
  available,
  observableMismatch,
  insufficientEvidence,
  blockedIntegrity,
}

enum GastricFitDisposition { priorFixedOnly, eligibleForResearchFit, blocked }

final class GastricStructureParameter {
  GastricStructureParameter({
    required this.id,
    required this.symbol,
    required this.value,
    required this.unit,
    required this.authority,
    required List<String> sourceIds,
    required this.limitation,
  }) : sourceIds = List<String>.unmodifiable(sourceIds) {
    if (!_safeId(id) || symbol.trim().isEmpty || unit.trim().isEmpty) {
      throw ArgumentError('Gastric parameter identity is invalid.');
    }
    if (!value.isFinite || value < 0) {
      throw ArgumentError(
        'Gastric parameter values must be finite and nonnegative.',
      );
    }
    if (sourceIds.isEmpty || sourceIds.any((source) => !_safeId(source))) {
      throw ArgumentError('Gastric parameters require governed source IDs.');
    }
    if (limitation.trim().isEmpty) {
      throw ArgumentError('Gastric parameter limitations are required.');
    }
  }

  final String id;
  final String symbol;
  final double value;
  final String unit;
  final GastricParameterAuthority authority;
  final List<String> sourceIds;
  final String limitation;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'symbol': symbol,
    'value': value,
    'unit': unit,
    'authority': authority.name,
    'source_ids': sourceIds,
    'limitation': limitation,
  };
}

final class GastricStructureContract {
  GastricStructureContract({
    required this.id,
    required this.kind,
    required this.name,
    required this.formula,
    required this.observable,
    required this.modality,
    required this.originalUnit,
    required this.canonicalUnit,
    required List<String> freeParameterIds,
    required List<GastricStructureParameter> parameters,
    required List<String> evidenceSourceIds,
    required this.supportedDomain,
    required this.limitation,
  }) : freeParameterIds = List<String>.unmodifiable(freeParameterIds),
       parameters = List<GastricStructureParameter>.unmodifiable(parameters),
       evidenceSourceIds = List<String>.unmodifiable(evidenceSourceIds) {
    if (!_safeId(id) || name.trim().isEmpty || formula.trim().isEmpty) {
      throw ArgumentError('Gastric structure identity is invalid.');
    }
    if (originalUnit.trim().isEmpty || canonicalUnit.trim().isEmpty) {
      throw ArgumentError('Gastric structure units are required.');
    }
    if (parameters.isEmpty ||
        parameters.map((parameter) => parameter.id).toSet().length !=
            parameters.length) {
      throw ArgumentError('Gastric structure parameters are invalid.');
    }
    final parameterIds = parameters.map((parameter) => parameter.id).toSet();
    if (freeParameterIds.toSet().length != freeParameterIds.length ||
        freeParameterIds.any((id) => !parameterIds.contains(id))) {
      throw ArgumentError(
        'Free parameters must reference declared parameters.',
      );
    }
    if (evidenceSourceIds.isEmpty ||
        evidenceSourceIds.any((source) => !_safeId(source))) {
      throw ArgumentError('Gastric structures require evidence source IDs.');
    }
    if (supportedDomain.trim().isEmpty || limitation.trim().isEmpty) {
      throw ArgumentError('Gastric structure boundaries are required.');
    }
  }

  final String id;
  final GastricStructureKind kind;
  final String name;
  final String formula;
  final GastricMeasuredObservable observable;
  final GastricMeasurementModality modality;
  final String originalUnit;
  final String canonicalUnit;
  final List<String> freeParameterIds;
  final List<GastricStructureParameter> parameters;
  final List<String> evidenceSourceIds;
  final String supportedDomain;
  final String limitation;

  int get freeParameterCount => freeParameterIds.length;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'name': name,
    'formula': formula,
    'observable': observable.name,
    'modality': modality.name,
    'original_unit': originalUnit,
    'canonical_unit': canonicalUnit,
    'free_parameter_ids': freeParameterIds,
    'parameters': parameters.map((parameter) => parameter.toJson()).toList(),
    'evidence_source_ids': evidenceSourceIds,
    'supported_domain': supportedDomain,
    'limitation': limitation,
  };
}

final class GastricObservationPoint {
  GastricObservationPoint({required this.minute, required this.value}) {
    if (minute < 0 || !value.isFinite || value < 0) {
      throw ArgumentError(
        'Gastric observation points must be finite and nonnegative.',
      );
    }
  }

  final int minute;
  final double value;

  Map<String, Object?> toJson() => <String, Object?>{
    'minute': minute,
    'value': value,
  };
}

final class GastricObservationSeries {
  GastricObservationSeries({
    required this.id,
    required this.observable,
    required this.modality,
    required this.originalUnit,
    required this.canonicalUnit,
    required List<GastricObservationPoint> points,
    required this.synthetic,
    required this.derivedFromProduction,
    required List<String> sourceIds,
  }) : points = List<GastricObservationPoint>.unmodifiable(points),
       sourceIds = List<String>.unmodifiable(sourceIds) {
    if (!_safeId(id) ||
        originalUnit.trim().isEmpty ||
        canonicalUnit.trim().isEmpty) {
      throw ArgumentError('Gastric observation-series identity is invalid.');
    }
    if (points.isEmpty ||
        points.map((point) => point.minute).toSet().length != points.length) {
      throw ArgumentError(
        'Gastric observations must be nonempty and time-unique.',
      );
    }
    for (var index = 1; index < points.length; index++) {
      if (points[index].minute <= points[index - 1].minute) {
        throw ArgumentError('Gastric observations must be time ordered.');
      }
    }
    if (sourceIds.isEmpty || sourceIds.any((source) => !_safeId(source))) {
      throw ArgumentError('Gastric observations require source IDs.');
    }
  }

  final String id;
  final GastricMeasuredObservable observable;
  final GastricMeasurementModality modality;
  final String originalUnit;
  final String canonicalUnit;
  final List<GastricObservationPoint> points;
  final bool synthetic;
  final bool derivedFromProduction;
  final List<String> sourceIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'observable': observable.name,
    'modality': modality.name,
    'original_unit': originalUnit,
    'canonical_unit': canonicalUnit,
    'points': points.map((point) => point.toJson()).toList(),
    'synthetic': synthetic,
    'derived_from_production': derivedFromProduction,
    'source_ids': sourceIds,
  };
}

final class GastricFitEvidence {
  GastricFitEvidence({
    required this.datasetSha256,
    required this.multistartRuns,
    required this.distinctStableOptima,
    required this.profileLikelihoodBounded,
    required this.conditionNumber,
    required this.heldOutPointCount,
    required this.heldOutRmse,
    required this.heldOutRmseThreshold,
    required this.independentImplementation,
  }) {
    if (!_sha256(datasetSha256) ||
        multistartRuns < 1 ||
        distinctStableOptima < 1 ||
        !conditionNumber.isFinite ||
        conditionNumber <= 0 ||
        heldOutPointCount < 0 ||
        !heldOutRmse.isFinite ||
        heldOutRmse < 0 ||
        !heldOutRmseThreshold.isFinite ||
        heldOutRmseThreshold <= 0) {
      throw ArgumentError('Gastric fit evidence is malformed.');
    }
  }

  final String datasetSha256;
  final int multistartRuns;
  final int distinctStableOptima;
  final bool profileLikelihoodBounded;
  final double conditionNumber;
  final int heldOutPointCount;
  final double heldOutRmse;
  final double heldOutRmseThreshold;
  final bool independentImplementation;

  Map<String, Object?> toJson() => <String, Object?>{
    'dataset_sha256': datasetSha256,
    'multistart_runs': multistartRuns,
    'distinct_stable_optima': distinctStableOptima,
    'profile_likelihood_bounded': profileLikelihoodBounded,
    'condition_number': conditionNumber,
    'held_out_point_count': heldOutPointCount,
    'held_out_rmse': heldOutRmse,
    'held_out_rmse_threshold': heldOutRmseThreshold,
    'independent_implementation': independentImplementation,
  };
}

final class GastricFitAuthorization {
  GastricFitAuthorization({
    required this.structureId,
    required this.seriesId,
    required this.disposition,
    required List<String> reasons,
  }) : reasons = List<String>.unmodifiable(reasons) {
    if (!_safeId(structureId) || !_safeId(seriesId) || reasons.isEmpty) {
      throw ArgumentError('Gastric fit authorization is incomplete.');
    }
  }

  final String structureId;
  final String seriesId;
  final GastricFitDisposition disposition;
  final List<String> reasons;

  Map<String, Object?> toJson() => <String, Object?>{
    'structure_id': structureId,
    'series_id': seriesId,
    'disposition': disposition.name,
    'reasons': reasons,
  };
}

final class GastricTrajectoryPoint {
  GastricTrajectoryPoint({required this.minute, required this.value}) {
    if (minute < 0 || !value.isFinite || value < 0) {
      throw ArgumentError(
        'Gastric trajectory points must be finite and nonnegative.',
      );
    }
  }

  final int minute;
  final double value;

  Map<String, Object?> toJson() => <String, Object?>{
    'minute': minute,
    'value': value,
  };
}

final class GastricShadowTrajectory {
  GastricShadowTrajectory({
    required this.structure,
    required this.availability,
    required List<String> reasons,
    required List<GastricTrajectoryPoint> points,
    required this.fitAuthorization,
  }) : reasons = List<String>.unmodifiable(reasons),
       points = List<GastricTrajectoryPoint>.unmodifiable(points) {
    if (reasons.isEmpty ||
        (availability == GastricTrajectoryAvailability.available &&
            points.isEmpty) ||
        (availability != GastricTrajectoryAvailability.available &&
            points.isNotEmpty)) {
      throw ArgumentError('Gastric trajectory availability is inconsistent.');
    }
  }

  final GastricStructureContract structure;
  final GastricTrajectoryAvailability availability;
  final List<String> reasons;
  final List<GastricTrajectoryPoint> points;
  final GastricFitAuthorization fitAuthorization;

  Map<String, Object?> toJson() => <String, Object?>{
    'structure': structure.toJson(),
    'availability': availability.name,
    'reasons': reasons,
    'points': points.map((point) => point.toJson()).toList(),
    'fit_authorization': fitAuthorization.toJson(),
  };
}

final class GastricStructuralDisagreement {
  GastricStructuralDisagreement({
    required this.leftStructureId,
    required this.rightStructureId,
    required this.observable,
    required this.meanAbsoluteDifference,
    required this.maximumAbsoluteDifference,
    required this.maximumDifferenceMinute,
  }) {
    if (!_safeId(leftStructureId) ||
        !_safeId(rightStructureId) ||
        leftStructureId == rightStructureId ||
        !meanAbsoluteDifference.isFinite ||
        meanAbsoluteDifference < 0 ||
        !maximumAbsoluteDifference.isFinite ||
        maximumAbsoluteDifference < meanAbsoluteDifference ||
        maximumDifferenceMinute < 0) {
      throw ArgumentError('Gastric structural disagreement is invalid.');
    }
  }

  final String leftStructureId;
  final String rightStructureId;
  final GastricMeasuredObservable observable;
  final double meanAbsoluteDifference;
  final double maximumAbsoluteDifference;
  final int maximumDifferenceMinute;

  Map<String, Object?> toJson() => <String, Object?>{
    'left_structure_id': leftStructureId,
    'right_structure_id': rightStructureId,
    'observable': observable.name,
    'mean_absolute_difference': meanAbsoluteDifference,
    'maximum_absolute_difference': maximumAbsoluteDifference,
    'maximum_difference_minute': maximumDifferenceMinute,
  };
}

final class GastricStructuralUncertaintyReport {
  GastricStructuralUncertaintyReport({
    required this.reportId,
    required this.generatedAtUtc,
    required this.eventLedgerDigest,
    required this.eventLedgerReplayDigest,
    required this.configurationDigest,
    required this.productionOutputDigestBefore,
    required this.productionOutputDigestAfter,
    required this.observationSeries,
    required List<GastricShadowTrajectory> trajectories,
    required List<GastricStructuralDisagreement> disagreements,
    required this.boundary,
  }) : trajectories = List<GastricShadowTrajectory>.unmodifiable(trajectories),
       disagreements = List<GastricStructuralDisagreement>.unmodifiable(
         disagreements,
       ) {
    final reasons = integrityReasons;
    if (reasons.isNotEmpty) {
      throw ArgumentError(
        'Invalid gastric structural report: ${reasons.join(', ')}',
      );
    }
  }

  final String reportId;
  final DateTime generatedAtUtc;
  final String eventLedgerDigest;
  final String eventLedgerReplayDigest;
  final String configurationDigest;
  final String productionOutputDigestBefore;
  final String productionOutputDigestAfter;
  final GastricObservationSeries observationSeries;
  final List<GastricShadowTrajectory> trajectories;
  final List<GastricStructuralDisagreement> disagreements;
  final String boundary;

  List<String> get integrityReasons {
    final reasons = <String>[];
    if (!_safeId(reportId)) reasons.add('report_id_invalid');
    if (!generatedAtUtc.isUtc) reasons.add('generated_at_not_utc');
    for (final digest in <String>[
      eventLedgerDigest,
      eventLedgerReplayDigest,
      configurationDigest,
      productionOutputDigestBefore,
      productionOutputDigestAfter,
    ]) {
      if (!_sha256(digest)) reasons.add('digest_invalid');
    }
    if (productionOutputDigestBefore != productionOutputDigestAfter) {
      reasons.add('production_output_changed');
    }
    if (trajectories.length != GastricStructureKind.values.length ||
        trajectories.map((item) => item.structure.kind).toSet().length !=
            trajectories.length) {
      reasons.add('structure_coverage_invalid');
    }
    final available = trajectories
        .where(
          (item) =>
              item.availability == GastricTrajectoryAvailability.available,
        )
        .toList(growable: false);
    for (final item in available) {
      if (item.structure.observable != observationSeries.observable ||
          item.structure.modality != observationSeries.modality) {
        reasons.add('available_observable_mismatch');
      }
    }
    if (boundary.trim().isEmpty) reasons.add('boundary_missing');
    return List<String>.unmodifiable(reasons);
  }

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema': gastricStructuralUncertaintySchema,
    'schema_version': gastricStructuralUncertaintySchemaVersion,
    'report_id': reportId,
    'generated_at_utc': generatedAtUtc.toIso8601String(),
    'event_ledger_digest': eventLedgerDigest,
    'event_ledger_replay_digest': eventLedgerReplayDigest,
    'configuration_digest': configurationDigest,
    'production_output_digest_before': productionOutputDigestBefore,
    'production_output_digest_after': productionOutputDigestAfter,
    'observation_series': observationSeries.toJson(),
    'trajectories': trajectories.map((item) => item.toJson()).toList(),
    'disagreements': disagreements.map((item) => item.toJson()).toList(),
    'boundary': boundary,
  };

  late final String sha256Digest = _digest(_bodyJson());

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'sha256_digest': sha256Digest,
  };
}

bool _safeId(String value) =>
    RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._:-]{0,159}$').hasMatch(value);

bool _sha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is Iterable) return '[${value.map(_canonicalJson).join(',')}]';
  return jsonEncode(value);
}
