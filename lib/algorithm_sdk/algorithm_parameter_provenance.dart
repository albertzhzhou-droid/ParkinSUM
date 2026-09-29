library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/analysis/nutrition_rules.dart';
import '../domain/entities/absorption_opportunity.dart';
import '../domain/entities/algorithm_descriptor.dart';
import '../domain/entities/gastric_emptying_parameters.dart';
import '../domain/entities/gastric_emptying_profile.dart';
import '../domain/entities/levodopa_absorption_opportunity_parameters.dart';
import '../domain/entities/protein_source.dart';
import '../domain/usecases/amino_acid_competition_model.dart';
import '../domain/usecases/dosage_note_parser.dart';
import '../domain/usecases/get_protein_trend_usecase.dart';
import '../domain/usecases/gastric_emptying_model.dart';
import '../domain/usecases/levodopa_absorption_opportunity_model.dart';
import '../domain/usecases/legacy_food_recommendation_parameters.dart';
import '../domain/usecases/mechanistic_next_meal_scorer.dart';
import '../domain/usecases/model_assumption_registry.dart';
import '../domain/usecases/next_meal_scoring_parameters.dart';
import '../domain/usecases/protein_distribution_model.dart';

enum AlgorithmParameterProvenanceStatus {
  measured,
  literatureDerived,
  fitted,
  prototypeHeuristic,
}

enum AlgorithmParameterSupportKind { numericRange, allowedValues, schema }

/// Declares the values that an implementation supports. This is an engineering
/// input contract, not a population reference interval or clinical range.
final class AlgorithmParameterSupport {
  final AlgorithmParameterSupportKind kind;
  final double? minimum;
  final double? maximum;
  final List<Object?> allowedValues;
  final String? schemaId;

  AlgorithmParameterSupport._({
    required this.kind,
    this.minimum,
    this.maximum,
    this.allowedValues = const [],
    this.schemaId,
  });

  factory AlgorithmParameterSupport.numericRange({
    required double minimum,
    required double maximum,
  }) {
    if (!minimum.isFinite || !maximum.isFinite || minimum > maximum) {
      throw ArgumentError(
        'Supported numeric range must be finite and ordered.',
      );
    }
    return AlgorithmParameterSupport._(
      kind: AlgorithmParameterSupportKind.numericRange,
      minimum: minimum,
      maximum: maximum,
    );
  }

  factory AlgorithmParameterSupport.allowedValues(List<Object?> values) {
    if (values.isEmpty) {
      throw ArgumentError('Supported allowed-values domain cannot be empty.');
    }
    final digests = <String>{};
    for (final value in values) {
      _validateJsonValue(value, field: 'allowedValues');
      final digest = _canonicalDigest(value);
      if (!digests.add(digest)) {
        throw ArgumentError('Supported allowed-values domain has duplicates.');
      }
    }
    return AlgorithmParameterSupport._(
      kind: AlgorithmParameterSupportKind.allowedValues,
      allowedValues: List<Object?>.unmodifiable(values.map(_deepFreeze)),
    );
  }

  factory AlgorithmParameterSupport.schema(String schemaId) {
    _requireIdentifier(schemaId, field: 'schemaId');
    return AlgorithmParameterSupport._(
      kind: AlgorithmParameterSupportKind.schema,
      schemaId: schemaId,
    );
  }

  void validateValue(Object? value) {
    switch (kind) {
      case AlgorithmParameterSupportKind.numericRange:
        if (value is! num || !value.isFinite) {
          throw ArgumentError('Numeric-range support requires a finite value.');
        }
        if (value < minimum! || value > maximum!) {
          throw ArgumentError.value(
            value,
            'canonicalValue',
            'must be between $minimum and $maximum',
          );
        }
        return;
      case AlgorithmParameterSupportKind.allowedValues:
        final digest = _canonicalDigest(value);
        if (!allowedValues.any(
          (candidate) => _canonicalDigest(candidate) == digest,
        )) {
          throw ArgumentError.value(
            value,
            'canonicalValue',
            'is outside the declared allowed-values domain',
          );
        }
        return;
      case AlgorithmParameterSupportKind.schema:
        _validateJsonValue(value, field: 'canonicalValue');
        return;
    }
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (allowedValues.isNotEmpty) 'allowed_values': allowedValues,
    if (schemaId != null) 'schema_id': schemaId,
  };
}

/// Parametric distribution identity for future calibrated or measured values.
/// Only distribution metadata is accepted; participant-level observations have
/// no field in this schema.
final class AlgorithmParameterDistribution {
  final String familyId;
  final Map<String, double> parameters;

  factory AlgorithmParameterDistribution({
    required String familyId,
    required Map<String, double> parameters,
  }) {
    _requireIdentifier(familyId, field: 'familyId');
    if (parameters.isEmpty) {
      throw ArgumentError(
        'A distribution must declare at least one parameter.',
      );
    }
    if (!parameters.containsKey('lower_bound') ||
        !parameters.containsKey('upper_bound')) {
      throw ArgumentError(
        'A distribution must declare finite lower_bound and upper_bound.',
      );
    }
    final sorted = <String, double>{};
    final keys = parameters.keys.toList()..sort();
    for (final key in keys) {
      _requireIdentifier(key, field: 'distribution parameter');
      final value = parameters[key]!;
      if (!value.isFinite) {
        throw ArgumentError.value(value, key, 'must be finite');
      }
      if ((key.contains('standard_deviation') ||
              key == 'scale' ||
              key == 'shape') &&
          value <= 0) {
        throw ArgumentError.value(value, key, 'must be greater than zero');
      }
      sorted[key] = value;
    }
    if (sorted['lower_bound']! > sorted['upper_bound']!) {
      throw ArgumentError('Distribution bounds must be ordered.');
    }
    for (final key in const ['mean', 'median', 'mode', 'location']) {
      final value = sorted[key];
      if (value != null &&
          (value < sorted['lower_bound']! || value > sorted['upper_bound']!)) {
        throw ArgumentError.value(
          value,
          key,
          'must lie within the declared distribution bounds',
        );
      }
    }
    return AlgorithmParameterDistribution._(
      familyId: familyId,
      parameters: Map<String, double>.unmodifiable(sorted),
    );
  }

  const AlgorithmParameterDistribution._({
    required this.familyId,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'family_id': familyId,
    'parameters': parameters,
  };
}

/// Required immutable-content identifiers for a fitted value. This record does
/// not itself prove that a governed calibration-dataset registry exists.
/// Hashes and aggregate diagnostics are accepted; raw participant rows,
/// subject IDs, and outcome arrays are not.
final class AlgorithmFittedParameterIdentity {
  static const String schema =
      'parkinsum.algorithm-fitted-parameter-identity/1';

  final String calibrationDatasetId;
  final String calibrationDatasetContentSha256;
  final String splitId;
  final String splitManifestSha256;
  final String estimatorId;
  final String estimatorCodeSha256;
  final String environmentLockSha256;
  final String rawToAnalysisLineageSha256;
  final Map<String, double> diagnostics;

  factory AlgorithmFittedParameterIdentity({
    required String calibrationDatasetId,
    required String calibrationDatasetContentSha256,
    required String splitId,
    required String splitManifestSha256,
    required String estimatorId,
    required String estimatorCodeSha256,
    required String environmentLockSha256,
    required String rawToAnalysisLineageSha256,
    required Map<String, double> diagnostics,
  }) {
    for (final entry in <String, String>{
      'calibrationDatasetId': calibrationDatasetId,
      'splitId': splitId,
      'estimatorId': estimatorId,
    }.entries) {
      _requireIdentifier(entry.value, field: entry.key);
    }
    for (final entry in <String, String>{
      'calibrationDatasetContentSha256': calibrationDatasetContentSha256,
      'splitManifestSha256': splitManifestSha256,
      'estimatorCodeSha256': estimatorCodeSha256,
      'environmentLockSha256': environmentLockSha256,
      'rawToAnalysisLineageSha256': rawToAnalysisLineageSha256,
    }.entries) {
      if (!_sha256Pattern.hasMatch(entry.value)) {
        throw ArgumentError.value(entry.value, entry.key, 'must be SHA-256');
      }
    }
    if (diagnostics.isEmpty) {
      throw ArgumentError('Fitted identity requires aggregate diagnostics.');
    }
    if (diagnostics.length > 32) {
      throw ArgumentError(
        'Fitted identity accepts at most 32 aggregate diagnostics.',
      );
    }
    final sortedDiagnostics = <String, double>{};
    final keys = diagnostics.keys.toList()..sort();
    for (final key in keys) {
      _requireIdentifier(key, field: 'diagnostic');
      final normalizedKey = key.toLowerCase();
      if (_participantLevelDiagnosticTokens.any(normalizedKey.contains)) {
        throw ArgumentError.value(
          key,
          'diagnostic',
          'participant-level diagnostic keys are forbidden; use aggregate metrics',
        );
      }
      final value = diagnostics[key]!;
      if (!value.isFinite) {
        throw ArgumentError.value(value, key, 'diagnostic must be finite');
      }
      sortedDiagnostics[key] = value;
    }
    return AlgorithmFittedParameterIdentity._(
      calibrationDatasetId: calibrationDatasetId,
      calibrationDatasetContentSha256: calibrationDatasetContentSha256,
      splitId: splitId,
      splitManifestSha256: splitManifestSha256,
      estimatorId: estimatorId,
      estimatorCodeSha256: estimatorCodeSha256,
      environmentLockSha256: environmentLockSha256,
      rawToAnalysisLineageSha256: rawToAnalysisLineageSha256,
      diagnostics: Map<String, double>.unmodifiable(sortedDiagnostics),
    );
  }

  const AlgorithmFittedParameterIdentity._({
    required this.calibrationDatasetId,
    required this.calibrationDatasetContentSha256,
    required this.splitId,
    required this.splitManifestSha256,
    required this.estimatorId,
    required this.estimatorCodeSha256,
    required this.environmentLockSha256,
    required this.rawToAnalysisLineageSha256,
    required this.diagnostics,
  });

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'calibration_dataset_id': calibrationDatasetId,
    'calibration_dataset_content_sha256': calibrationDatasetContentSha256,
    'split_id': splitId,
    'split_manifest_sha256': splitManifestSha256,
    'estimator_id': estimatorId,
    'estimator_code_sha256': estimatorCodeSha256,
    'environment_lock_sha256': environmentLockSha256,
    'raw_to_analysis_lineage_sha256': rawToAnalysisLineageSha256,
    'diagnostics': diagnostics,
  };
}

final class AlgorithmParameterProvenanceRecord {
  static const String schema = 'parkinsum.algorithm-parameter-provenance/2';

  final String parameterId;
  final List<String> algorithmIds;
  final String displayName;
  final String semanticId;
  final String formulaId;
  final String originalUnit;
  final String canonicalUnit;
  final Object? originalValue;
  final Object? canonicalValue;
  final AlgorithmParameterDistribution? distribution;
  final AlgorithmParameterSupport supportedDomain;
  final String transformId;
  final AlgorithmParameterProvenanceStatus provenanceStatus;
  final List<String> sourceIds;
  final String reviewDate;
  final AlgorithmFittedParameterIdentity? fittedIdentity;
  final String limitation;

  factory AlgorithmParameterProvenanceRecord({
    required String parameterId,
    required List<String> algorithmIds,
    required String displayName,
    required String semanticId,
    required String formulaId,
    required String originalUnit,
    required String canonicalUnit,
    Object? originalValue,
    Object? canonicalValue,
    AlgorithmParameterDistribution? distribution,
    required AlgorithmParameterSupport supportedDomain,
    required String transformId,
    required AlgorithmParameterProvenanceStatus provenanceStatus,
    required List<String> sourceIds,
    required String reviewDate,
    AlgorithmFittedParameterIdentity? fittedIdentity,
    required String limitation,
  }) {
    for (final entry in <String, String>{
      'parameterId': parameterId,
      'semanticId': semanticId,
      'formulaId': formulaId,
      'originalUnit': originalUnit,
      'canonicalUnit': canonicalUnit,
      'transformId': transformId,
    }.entries) {
      _requireIdentifier(entry.value, field: entry.key);
    }
    if (algorithmIds.isEmpty) {
      throw ArgumentError('Every parameter record requires algorithm IDs.');
    }
    final algorithmIdSet = <String>{};
    for (final algorithmId in algorithmIds) {
      _requireIdentifier(algorithmId, field: 'algorithmId');
      if (!algorithmIdSet.add(algorithmId)) {
        throw ArgumentError.value(
          algorithmId,
          'algorithmIds',
          'duplicate algorithm ID',
        );
      }
    }
    if (displayName.trim().isEmpty || limitation.trim().isEmpty) {
      throw ArgumentError('Display name and limitation are required.');
    }
    final hasScalarValue = originalValue != null || canonicalValue != null;
    if (hasScalarValue == (distribution != null)) {
      throw ArgumentError(
        'Declare exactly one complete value pair or one distribution.',
      );
    }
    if (distribution == null &&
        (originalValue == null || canonicalValue == null)) {
      throw ArgumentError(
        'Original and canonical values must both be present.',
      );
    }
    if (distribution == null) {
      _validateJsonValue(originalValue, field: 'originalValue');
      _validateJsonValue(canonicalValue, field: 'canonicalValue');
      supportedDomain.validateValue(canonicalValue);
    } else {
      if (supportedDomain.kind != AlgorithmParameterSupportKind.numericRange) {
        throw ArgumentError(
          'Distribution records require a numeric supported range.',
        );
      }
      supportedDomain.validateValue(distribution.parameters['lower_bound']);
      supportedDomain.validateValue(distribution.parameters['upper_bound']);
    }
    if (sourceIds.isEmpty) {
      throw ArgumentError('Every parameter record requires source IDs.');
    }
    final sourceSet = <String>{};
    for (final sourceId in sourceIds) {
      _requireIdentifier(sourceId, field: 'sourceId');
      if (!sourceSet.add(sourceId)) {
        throw ArgumentError.value(sourceId, 'sourceIds', 'duplicate source ID');
      }
    }
    _requireIsoDate(reviewDate, field: 'reviewDate');
    if (provenanceStatus == AlgorithmParameterProvenanceStatus.fitted) {
      if (fittedIdentity == null) {
        throw ArgumentError(
          'Fitted parameters require complete fitted identity.',
        );
      }
    } else if (fittedIdentity != null) {
      throw ArgumentError(
        'Fitted identity is allowed only when provenanceStatus is fitted.',
      );
    }
    return AlgorithmParameterProvenanceRecord._(
      parameterId: parameterId,
      algorithmIds: List<String>.unmodifiable(algorithmIds),
      displayName: displayName.trim(),
      semanticId: semanticId,
      formulaId: formulaId,
      originalUnit: originalUnit,
      canonicalUnit: canonicalUnit,
      originalValue: _deepFreeze(originalValue),
      canonicalValue: _deepFreeze(canonicalValue),
      distribution: distribution,
      supportedDomain: supportedDomain,
      transformId: transformId,
      provenanceStatus: provenanceStatus,
      sourceIds: List<String>.unmodifiable(sourceIds),
      reviewDate: reviewDate,
      fittedIdentity: fittedIdentity,
      limitation: limitation.trim(),
    );
  }

  const AlgorithmParameterProvenanceRecord._({
    required this.parameterId,
    required this.algorithmIds,
    required this.displayName,
    required this.semanticId,
    required this.formulaId,
    required this.originalUnit,
    required this.canonicalUnit,
    required this.originalValue,
    required this.canonicalValue,
    required this.distribution,
    required this.supportedDomain,
    required this.transformId,
    required this.provenanceStatus,
    required this.sourceIds,
    required this.reviewDate,
    required this.fittedIdentity,
    required this.limitation,
  });

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'parameter_id': parameterId,
    'algorithm_ids': algorithmIds,
    'display_name': displayName,
    'semantic_id': semanticId,
    'formula_id': formulaId,
    'original_unit': originalUnit,
    'canonical_unit': canonicalUnit,
    if (distribution == null)
      'value': {'original': originalValue, 'canonical': canonicalValue}
    else
      'distribution': distribution!.toJson(),
    'supported_domain': supportedDomain.toJson(),
    'transform_id': transformId,
    'provenance_status': provenanceStatus.name,
    'source_ids': sourceIds,
    'review_date': reviewDate,
    if (fittedIdentity != null) 'fitted_identity': fittedIdentity!.toJson(),
    'limitation': limitation,
  };
}

enum AlgorithmConfigurationCoverageMode {
  fieldAndSourceBound,
  sourceBundleOnly,
}

/// Reviewed, digest-bound evidence that one registered algorithm's declared
/// result-affecting configuration fields form an exact closed set.
///
/// This is an engineering configuration-closure witness. It does not prove
/// numerical correctness, scientific validity, clinical calibration, safety,
/// efficacy, or patient benefit.
final class AlgorithmConfigurationCompletenessWitness {
  static const String schema =
      'parkinsum.algorithm-configuration-completeness-witness/1';

  final String witnessId;
  final String algorithmId;
  final String reviewedAt;
  final List<String> fieldRecordIds;
  final Map<String, List<String>> affectedResultSinksByFieldId;
  final List<String> requiredResultSinks;
  final Map<String, String> ownedSourceSha256;
  final String configurationSectionSha256;
  final String registeredSourceBundleSha256;
  final Map<String, String> dependencyContractSha256;
  final List<String> reviewEvidenceIds;
  final String completionBoundary;
  final String limitation;

  factory AlgorithmConfigurationCompletenessWitness({
    required String witnessId,
    required String algorithmId,
    required String reviewedAt,
    required Iterable<String> fieldRecordIds,
    required Map<String, Iterable<String>> affectedResultSinksByFieldId,
    required Iterable<String> requiredResultSinks,
    required Map<String, String> ownedSourceSha256,
    required String configurationSectionSha256,
    required String registeredSourceBundleSha256,
    required Map<String, String> dependencyContractSha256,
    required Iterable<String> reviewEvidenceIds,
    required String completionBoundary,
    required String limitation,
  }) {
    _requireIdentifier(witnessId, field: 'witnessId');
    _requireIdentifier(algorithmId, field: 'algorithmId');
    _requireIsoDate(reviewedAt, field: 'reviewedAt');
    for (final digest in [
      configurationSectionSha256,
      registeredSourceBundleSha256,
      ...ownedSourceSha256.values,
      ...dependencyContractSha256.values,
    ]) {
      if (!_sha256Pattern.hasMatch(digest)) {
        throw ArgumentError.value(digest, 'digest', 'must be SHA-256');
      }
    }

    final fields = fieldRecordIds.toSet();
    if (fields.isEmpty || fields.length != fieldRecordIds.length) {
      throw ArgumentError(
        'Completeness witness field IDs must be non-empty and unique.',
      );
    }
    for (final fieldId in fields) {
      _requireIdentifier(fieldId, field: 'fieldRecordId');
    }
    if (affectedResultSinksByFieldId.keys
            .toSet()
            .difference(fields)
            .isNotEmpty ||
        fields
            .difference(affectedResultSinksByFieldId.keys.toSet())
            .isNotEmpty) {
      throw ArgumentError(
        'Affected-result sink ownership must exactly match field record IDs.',
      );
    }
    final sinksByField = <String, List<String>>{};
    for (final fieldId in fields.toList()..sort()) {
      final sinks = affectedResultSinksByFieldId[fieldId]!.toSet();
      if (sinks.isEmpty) {
        throw ArgumentError.value(fieldId, 'affectedResultSinksByFieldId');
      }
      for (final sink in sinks) {
        _requireIdentifier(sink, field: 'affectedResultSink');
      }
      sinksByField[fieldId] = List<String>.unmodifiable(sinks.toList()..sort());
    }
    final requiredSinks = requiredResultSinks.toSet();
    if (requiredSinks.isEmpty ||
        requiredSinks.length != requiredResultSinks.length) {
      throw ArgumentError(
        'Required result sinks must be non-empty and unique.',
      );
    }
    for (final sink in requiredSinks) {
      _requireIdentifier(sink, field: 'requiredResultSink');
    }
    final observedSinks = sinksByField.values
        .expand((values) => values)
        .toSet();
    if (!observedSinks.containsAll(requiredSinks)) {
      throw ArgumentError(
        'Completeness witness does not cover every required result sink.',
      );
    }

    if (ownedSourceSha256.isEmpty) {
      throw ArgumentError('Completeness witness requires owned source files.');
    }
    final sortedSources = <String, String>{};
    for (final path in ownedSourceSha256.keys.toList()..sort()) {
      if (!RegExp(r'^lib/[A-Za-z0-9_./-]+\.dart$').hasMatch(path)) {
        throw ArgumentError.value(path, 'ownedSourceSha256');
      }
      sortedSources[path] = ownedSourceSha256[path]!;
    }
    final sortedDependencies = <String, String>{};
    for (final dependencyId in dependencyContractSha256.keys.toList()..sort()) {
      _requireIdentifier(dependencyId, field: 'dependencyId');
      if (dependencyId == algorithmId) {
        throw ArgumentError('An algorithm cannot be its own dependency.');
      }
      sortedDependencies[dependencyId] =
          dependencyContractSha256[dependencyId]!;
    }
    if (sortedDependencies.isEmpty) {
      throw ArgumentError('Completeness witness requires dependency bindings.');
    }
    final evidence = reviewEvidenceIds.toSet();
    if (evidence.isEmpty || evidence.length != reviewEvidenceIds.length) {
      throw ArgumentError('Review evidence IDs must be non-empty and unique.');
    }
    for (final evidenceId in evidence) {
      _requireIdentifier(evidenceId, field: 'reviewEvidenceId');
    }
    if (completionBoundary.trim().isEmpty || limitation.trim().isEmpty) {
      throw ArgumentError('Completion boundary and limitation are required.');
    }

    return AlgorithmConfigurationCompletenessWitness._(
      witnessId: witnessId,
      algorithmId: algorithmId,
      reviewedAt: reviewedAt,
      fieldRecordIds: List<String>.unmodifiable(fields.toList()..sort()),
      affectedResultSinksByFieldId: Map.unmodifiable(sinksByField),
      requiredResultSinks: List<String>.unmodifiable(
        requiredSinks.toList()..sort(),
      ),
      ownedSourceSha256: Map.unmodifiable(sortedSources),
      configurationSectionSha256: configurationSectionSha256,
      registeredSourceBundleSha256: registeredSourceBundleSha256,
      dependencyContractSha256: Map.unmodifiable(sortedDependencies),
      reviewEvidenceIds: List<String>.unmodifiable(evidence.toList()..sort()),
      completionBoundary: completionBoundary.trim(),
      limitation: limitation.trim(),
    );
  }

  const AlgorithmConfigurationCompletenessWitness._({
    required this.witnessId,
    required this.algorithmId,
    required this.reviewedAt,
    required this.fieldRecordIds,
    required this.affectedResultSinksByFieldId,
    required this.requiredResultSinks,
    required this.ownedSourceSha256,
    required this.configurationSectionSha256,
    required this.registeredSourceBundleSha256,
    required this.dependencyContractSha256,
    required this.reviewEvidenceIds,
    required this.completionBoundary,
    required this.limitation,
  });

  Map<String, dynamic> get canonicalPayload => {
    r'$schema': schema,
    'witness_id': witnessId,
    'algorithm_id': algorithmId,
    'reviewed_at': reviewedAt,
    'field_record_ids': fieldRecordIds,
    'affected_result_sinks_by_field_id': affectedResultSinksByFieldId,
    'required_result_sinks': requiredResultSinks,
    'owned_source_sha256': ownedSourceSha256,
    'configuration_section_sha256': configurationSectionSha256,
    'registered_source_bundle_sha256': registeredSourceBundleSha256,
    'dependency_contract_sha256': dependencyContractSha256,
    'review_evidence_ids': reviewEvidenceIds,
    'completion_boundary': completionBoundary,
    'limitation': limitation,
  };

  String get sha256Digest => _canonicalDigest(canonicalPayload);

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'sha256': sha256Digest,
  };
}

/// Truthful per-algorithm view of configuration identity coverage.
///
/// A field-bound entry proves only that at least one explicit parameter or
/// structural-provider record names the algorithm. It does not silently claim
/// that every branch and constant has been promoted out of the source-bundle
/// fallback. That stronger audit remains a separate completion criterion.
final class AlgorithmConfigurationCoverageEntry {
  const AlgorithmConfigurationCoverageEntry._({
    required this.algorithmId,
    required this.algorithmName,
    required this.mode,
    required this.fieldRecordIds,
    required this.sourcePaths,
    required this.structuralIdentitySha256,
    required this.registeredSourceBundleSha256,
    required this.completenessWitness,
  });

  final String algorithmId;
  final String algorithmName;
  final AlgorithmConfigurationCoverageMode mode;
  final List<String> fieldRecordIds;
  final List<String> sourcePaths;
  final String structuralIdentitySha256;
  final String registeredSourceBundleSha256;
  final AlgorithmConfigurationCompletenessWitness? completenessWitness;

  bool get hasExplicitFieldRecords => fieldRecordIds.isNotEmpty;
  bool get completePerFieldCoverageProven => completenessWitness != null;

  String get limitation => completePerFieldCoverageProven
      ? 'Reviewed complete per-field configuration closure within the exact '
            'witness boundary. Source, dependency, field, sink, and section '
            'digests match; this does not prove numerical, biological, '
            'clinical, safety, efficacy, or patient-benefit validity.'
      : hasExplicitFieldRecords
      ? 'At least one explicit field or provider binding is owned by this '
            'algorithm; unlisted branches may still rely on the registered '
            'source-bundle digest. This is not proof of complete per-field '
            'coverage or scientific validity.'
      : 'No explicit parameter or provider record currently names this '
            'algorithm. Source-bundle change detection is available, but field '
            'semantics, units, provenance, and impact remain unassessed.';

  Map<String, dynamic> toJson() => {
    'algorithm_id': algorithmId,
    'algorithm_name': algorithmName,
    'mode': mode.name,
    'field_record_count': fieldRecordIds.length,
    'field_record_ids': fieldRecordIds,
    'source_paths': sourcePaths,
    'structural_identity_sha256': structuralIdentitySha256,
    'registered_source_bundle_sha256': registeredSourceBundleSha256,
    'complete_per_field_coverage_proven': completePerFieldCoverageProven,
    if (completenessWitness != null)
      'completeness_witness': completenessWitness!.toJson(),
    'limitation': limitation,
  };
}

/// Exhaustive registry-to-configuration-identity partition.
///
/// Every registered result-affecting algorithm appears exactly once. Every
/// parameter/structure record must name a registered consumer. This makes the
/// remaining source-only fallback visible and machine-testable instead of
/// hiding it behind a single repository-wide digest.
final class AlgorithmConfigurationCoverageManifest {
  static const String schema = 'parkinsum.algorithm-configuration-coverage/2';
  static const String boundary =
      'Configuration identity and change-detection coverage only. A field '
      'record does not establish complete branch coverage. A validated '
      'completion witness closes only its declared configuration boundary; '
      'neither status establishes calculation correctness, biological '
      'validity, clinical accuracy, safety, efficacy, or patient benefit.';

  const AlgorithmConfigurationCoverageManifest._(this.entries);

  final List<AlgorithmConfigurationCoverageEntry> entries;

  factory AlgorithmConfigurationCoverageManifest.fromRegistry({
    required List<AlgorithmDescriptor> algorithmDescriptors,
    required AlgorithmParameterProvenanceManifest parameterManifest,
    required String registeredSourceBundleSha256,
    required Map<String, Map<String, String>>
    dependencyContractSha256ByAlgorithm,
    List<AlgorithmConfigurationCompletenessWitness> completionWitnesses =
        const [],
    Map<String, String> configurationSectionSha256ByAlgorithm = const {},
    Map<String, String> implementationSourceSha256 = const {},
  }) {
    if (!_sha256Pattern.hasMatch(registeredSourceBundleSha256)) {
      throw ArgumentError.value(
        registeredSourceBundleSha256,
        'registeredSourceBundleSha256',
        'must be lowercase SHA-256',
      );
    }
    if (algorithmDescriptors.isEmpty) {
      throw ArgumentError('Algorithm registry cannot be empty.');
    }
    final descriptorsById = <String, AlgorithmDescriptor>{};
    for (final descriptor in algorithmDescriptors) {
      if (descriptorsById.containsKey(descriptor.id)) {
        throw ArgumentError.value(
          descriptor.id,
          'algorithmDescriptors',
          'duplicate algorithm ID',
        );
      }
      descriptorsById[descriptor.id] = descriptor;
    }

    final recordsByAlgorithm =
        <String, List<AlgorithmParameterProvenanceRecord>>{
          for (final algorithmId in descriptorsById.keys)
            algorithmId: <AlgorithmParameterProvenanceRecord>[],
        };
    for (final record in parameterManifest.records) {
      for (final algorithmId in record.algorithmIds) {
        final records = recordsByAlgorithm[algorithmId];
        if (records == null) {
          throw ArgumentError.value(
            algorithmId,
            record.parameterId,
            'parameter record names an unregistered algorithm',
          );
        }
        records.add(record);
      }
    }

    final witnessesByAlgorithm =
        <String, AlgorithmConfigurationCompletenessWitness>{};
    for (final witness in completionWitnesses) {
      final descriptor = descriptorsById[witness.algorithmId];
      if (descriptor == null) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'names an unregistered algorithm',
        );
      }
      if (witnessesByAlgorithm.containsKey(witness.algorithmId)) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'duplicate completion witness',
        );
      }
      final actualFieldIds = recordsByAlgorithm[witness.algorithmId]!
          .map((record) => record.parameterId)
          .toSet();
      if (actualFieldIds.length != witness.fieldRecordIds.length ||
          !actualFieldIds.containsAll(witness.fieldRecordIds)) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'field record set is not exact',
        );
      }
      final descriptorPaths = descriptor.sourcePaths.toSet();
      if (descriptorPaths.length != witness.ownedSourceSha256.length ||
          !descriptorPaths.containsAll(witness.ownedSourceSha256.keys)) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'owned source set is not exact',
        );
      }
      for (final entry in witness.ownedSourceSha256.entries) {
        if (implementationSourceSha256[entry.key] != entry.value) {
          throw ArgumentError.value(
            entry.key,
            'completionWitnesses',
            'owned source digest does not match implementation identity',
          );
        }
      }
      if (witness.registeredSourceBundleSha256 !=
          registeredSourceBundleSha256) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'registered source-bundle digest mismatch',
        );
      }
      if (configurationSectionSha256ByAlgorithm[witness.algorithmId] !=
          witness.configurationSectionSha256) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'configuration-section digest mismatch',
        );
      }
      final currentDependencyContracts =
          dependencyContractSha256ByAlgorithm[witness.algorithmId];
      if (currentDependencyContracts == null ||
          currentDependencyContracts.length !=
              witness.dependencyContractSha256.length ||
          !currentDependencyContracts.keys.toSet().containsAll(
            witness.dependencyContractSha256.keys,
          )) {
        throw ArgumentError.value(
          witness.algorithmId,
          'completionWitnesses',
          'dependency contract set does not match current identity',
        );
      }
      for (final dependencyId in witness.dependencyContractSha256.keys) {
        if (!descriptorsById.containsKey(dependencyId)) {
          throw ArgumentError.value(
            dependencyId,
            'completionWitnesses',
            'dependency is not a registered algorithm',
          );
        }
        if (currentDependencyContracts[dependencyId] !=
            witness.dependencyContractSha256[dependencyId]) {
          throw ArgumentError.value(
            dependencyId,
            'completionWitnesses',
            'dependency contract digest does not match current identity',
          );
        }
      }
      witnessesByAlgorithm[witness.algorithmId] = witness;
    }
    if (dependencyContractSha256ByAlgorithm.length !=
            witnessesByAlgorithm.length ||
        !dependencyContractSha256ByAlgorithm.keys.toSet().containsAll(
          witnessesByAlgorithm.keys,
        )) {
      throw ArgumentError(
        'Dependency contract owners must exactly match completion witnesses.',
      );
    }

    final sortedDescriptors = algorithmDescriptors.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final entries = <AlgorithmConfigurationCoverageEntry>[
      for (final descriptor in sortedDescriptors)
        AlgorithmConfigurationCoverageEntry._(
          algorithmId: descriptor.id,
          algorithmName: descriptor.name,
          mode: recordsByAlgorithm[descriptor.id]!.isEmpty
              ? AlgorithmConfigurationCoverageMode.sourceBundleOnly
              : AlgorithmConfigurationCoverageMode.fieldAndSourceBound,
          fieldRecordIds: List<String>.unmodifiable(
            (recordsByAlgorithm[descriptor.id]!
                .map((record) => record.parameterId)
                .toList()
              ..sort()),
          ),
          sourcePaths: List<String>.unmodifiable(descriptor.sourcePaths),
          structuralIdentitySha256: _canonicalDigest(
            descriptor.toManifestJson(),
          ),
          registeredSourceBundleSha256: registeredSourceBundleSha256,
          completenessWitness: witnessesByAlgorithm[descriptor.id],
        ),
    ];
    return AlgorithmConfigurationCoverageManifest._(
      List<AlgorithmConfigurationCoverageEntry>.unmodifiable(entries),
    );
  }

  int get fieldAndSourceBoundCount => entries
      .where(
        (entry) =>
            entry.mode ==
            AlgorithmConfigurationCoverageMode.fieldAndSourceBound,
      )
      .length;

  int get sourceBundleOnlyCount => entries.length - fieldAndSourceBoundCount;

  int get completePerFieldCoverageCount =>
      entries.where((entry) => entry.completePerFieldCoverageProven).length;

  AlgorithmConfigurationCoverageEntry entryFor(String algorithmId) =>
      entries.singleWhere((entry) => entry.algorithmId == algorithmId);

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'algorithm_count': entries.length,
    'field_and_source_bound_count': fieldAndSourceBoundCount,
    'source_bundle_only_count': sourceBundleOnlyCount,
    'complete_per_field_coverage_count': completePerFieldCoverageCount,
    'boundary': boundary,
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };
}

final class AlgorithmParameterProvenanceManifest {
  static const String schema = 'parkinsum.algorithm-parameter-manifest/2';

  final List<AlgorithmParameterProvenanceRecord> records;

  factory AlgorithmParameterProvenanceManifest(
    Iterable<AlgorithmParameterProvenanceRecord> records,
  ) {
    final sorted = records.toList()
      ..sort((left, right) => left.parameterId.compareTo(right.parameterId));
    if (sorted.isEmpty) {
      throw ArgumentError('Parameter provenance manifest cannot be empty.');
    }
    final ids = <String>{};
    final semanticIds = <String>{};
    for (final record in sorted) {
      if (!ids.add(record.parameterId)) {
        throw ArgumentError.value(
          record.parameterId,
          'records',
          'duplicate parameter ID',
        );
      }
      if (!semanticIds.add(record.semanticId)) {
        throw ArgumentError.value(
          record.semanticId,
          'records',
          'duplicate semantic ID',
        );
      }
    }
    return AlgorithmParameterProvenanceManifest._(
      List<AlgorithmParameterProvenanceRecord>.unmodifiable(sorted),
    );
  }

  const AlgorithmParameterProvenanceManifest._(this.records);

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'record_count': records.length,
    'records': records.map((record) => record.toJson()).toList(growable: false),
  };

  static AlgorithmParameterProvenanceManifest defaults({
    required GastricEmptyingParameterSet gastricParameters,
    required LevodopaAbsorptionOpportunityParameterSet absorptionParameters,
    required NextMealScoringParameterSet scoringParameters,
    required LegacyFoodRecommendationParameterSet
    legacyFoodRecommendationParameters,
    required List<LnaaLoadFactor> lnaaFactors,
    required List<Map<String, dynamic>> runtimeRuleLogic,
    required List<AlgorithmDescriptor> algorithmDescriptors,
  }) {
    const reviewDate = '2026-08-17';
    const internalSource = 'src.internal.prototype.heuristic';
    final records = <AlgorithmParameterProvenanceRecord>[];

    records.add(
      AlgorithmParameterProvenanceRecord(
        parameterId: 'medication_dose.grammar_identity',
        algorithmIds: const ['dosage_note_parser'],
        displayName: 'Administration dose-expression grammar',
        semanticId: 'medication_dose.expression.grammar_identity',
        formulaId: 'dose-expression-parser.grammar/4',
        originalUnit: 'schema_contract',
        canonicalUnit: 'schema_contract',
        originalValue: DosageNoteParser.configurationIdentity,
        canonicalValue: DosageNoteParser.configurationIdentity,
        supportedDomain: AlgorithmParameterSupport.schema(
          'parkinsum.administration-dose-expression/4',
        ),
        transformId: 'identity-json/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: const [internalSource],
        reviewDate: reviewDate,
        limitation:
            'Binds the local grammar and unit-map identity only; it does not '
            'establish prescription correctness, dose appropriateness, '
            'UCUM/FHIR semantics, or clinical validity.',
      ),
    );

    records.add(
      AlgorithmParameterProvenanceRecord(
        parameterId: 'protein_trend.aggregation_contract',
        algorithmIds: const ['protein_trend'],
        displayName: 'Protein-trend time, value, ordering and mean contract',
        semanticId: 'analytics.protein_trend.aggregation_contract',
        formulaId: 'protein-trend.effective-time-series-and-mean/1',
        originalUnit: 'canonical_json',
        canonicalUnit: 'canonical_json',
        originalValue: GetProteinTrendUseCase.configurationIdentity,
        canonicalValue: GetProteinTrendUseCase.configurationIdentity,
        supportedDomain: AlgorithmParameterSupport.schema(
          'parkinsum.protein-trend-aggregation/1',
        ),
        transformId: 'identity-json/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: const [internalSource],
        reviewDate: reviewDate,
        limitation:
            'Binds a descriptive per-meal aggregation only; it does not assess '
            'nutrient-source completeness, dietary adequacy, clinical meaning, '
            'benefit, or safety.',
      ),
    );

    for (final parameter in gastricParameters.all) {
      final spec = _gastricSpec(parameter.id);
      records.add(
        _valueRecord(
          id: parameter.id,
          algorithmIds: const ['gastric_emptying'],
          displayName: parameter.label,
          formulaId: spec.formulaId,
          unit: spec.unit,
          value: parameter.value,
          minimum: spec.minimum,
          maximum: spec.maximum,
          sources: parameter.sourceRefs,
          reviewDate: gastricParameters.lastReviewed,
          status: parameter.isPrototypeHeuristic
              ? AlgorithmParameterProvenanceStatus.prototypeHeuristic
              : AlgorithmParameterProvenanceStatus.literatureDerived,
          limitation: parameter.limitation,
        ),
      );
    }

    records.addAll([
      AlgorithmParameterProvenanceRecord(
        parameterId: GastricEmptyingParameterIds.generatorStructure,
        algorithmIds: const ['gastric_emptying'],
        displayName: 'Gastric generator branch and weighting policy',
        semanticId: GastricEmptyingParameterIds.generatorStructure,
        formulaId: 'gastric-emptying.generator-structure/1',
        originalUnit: 'canonical_json',
        canonicalUnit: 'canonical_json',
        originalValue: GastricEmptyingModel.generatorStructure,
        canonicalValue: GastricEmptyingModel.generatorStructure,
        supportedDomain: AlgorithmParameterSupport.schema(
          GastricEmptyingModel.generatorStructureSchema,
        ),
        transformId: 'identity-json/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: const [internalSource],
        reviewDate: gastricParameters.lastReviewed,
        limitation:
            'Reviewed deterministic branch declaration for an educational '
            'population-sensitivity model; it is not individual calibration or '
            'evidence of physiological accuracy.',
      ),
      AlgorithmParameterProvenanceRecord(
        parameterId: GastricEmptyingParameterIds.outputIntegrityContract,
        algorithmIds: const ['gastric_emptying'],
        displayName: 'Gastric output integrity and wire policy',
        semanticId: GastricEmptyingParameterIds.outputIntegrityContract,
        formulaId: 'gastric-emptying.output-integrity/1',
        originalUnit: 'canonical_json',
        canonicalUnit: 'canonical_json',
        originalValue: GastricEmptyingOutputContract.integrityConfiguration,
        canonicalValue: GastricEmptyingOutputContract.integrityConfiguration,
        supportedDomain: AlgorithmParameterSupport.schema(
          GastricEmptyingOutputContract.schema,
        ),
        transformId: 'identity-json/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: const [internalSource],
        reviewDate: gastricParameters.lastReviewed,
        limitation:
            'Engineering integrity and abstention encoding only; passing does '
            'not establish biological, clinical, safety, or efficacy truth.',
      ),
    ]);

    final absorptionSources = LevodopaAbsorptionOpportunityModel.baseSourceRefs;
    for (final spec
        in <
          ({
            String id,
            String name,
            num value,
            String unit,
            double minimum,
            double maximum,
            String formula,
          })
        >[
          (
            id: 'absorption.ir.reference_lag_minutes',
            name: 'IR reference opportunity lag',
            value: absorptionParameters.referenceIrLagMinutes,
            unit: 'min',
            minimum: 0,
            maximum: 1440,
            formula: 'levodopa.absorption.ir-window/1',
          ),
          (
            id: 'absorption.ir.reference_duration_minutes',
            name: 'IR reference opportunity duration',
            value: absorptionParameters.referenceIrDurationMinutes,
            unit: 'min',
            minimum: 1,
            maximum: 2880,
            formula: 'levodopa.absorption.ir-window/1',
          ),
          (
            id: 'absorption.meal.illustrative_delay_minutes',
            name: 'Illustrative meal-associated opportunity shift',
            value: absorptionParameters.illustrativeMealDelayMinutes,
            unit: 'min',
            minimum: 0,
            maximum: 1440,
            formula: 'levodopa.absorption.residual-load-shift/2',
          ),
          (
            id: LevodopaAbsorptionOpportunityParameterIds.highResidualThreshold,
            name: 'Strict high-residual meal-load threshold',
            value: absorptionParameters.highResidualThreshold,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
            formula: 'levodopa.absorption.residual-load-shift/2',
          ),
          (
            id: LevodopaAbsorptionOpportunityParameterIds
                .moderateResidualThreshold,
            name: 'Strict moderate-residual meal-load threshold',
            value: absorptionParameters.moderateResidualThreshold,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
            formula: 'levodopa.absorption.residual-load-shift/2',
          ),
          (
            id: LevodopaAbsorptionOpportunityParameterIds
                .highResidualEndDelayMultiplier,
            name: 'High-residual window-end delay multiplier',
            value: absorptionParameters.highResidualEndDelayMultiplier,
            unit: 'multiplier',
            minimum: 1,
            maximum: 100,
            formula: 'levodopa.absorption.residual-load-shift/2',
          ),
          (
            id: LevodopaAbsorptionOpportunityParameterIds
                .moderateResidualShiftDivisor,
            name: 'Moderate-residual integer shift divisor',
            value: absorptionParameters.moderateResidualShiftDivisor,
            unit: 'integer_divisor',
            minimum: 1,
            maximum: 100,
            formula: 'levodopa.absorption.residual-load-shift/2',
          ),
          (
            id: LevodopaAbsorptionOpportunityParameterIds
                .peakOffsetDurationDivisor,
            name: 'IR baseline peak-offset integer divisor',
            value: absorptionParameters.peakOffsetDurationDivisor,
            unit: 'integer_divisor',
            minimum: 1,
            maximum: 100,
            formula: 'levodopa.absorption.ir-window/1',
          ),
          (
            id: 'absorption.openness.sample_stride_minutes',
            name: 'Absorption-openness sampling stride',
            value: absorptionParameters.opennessSampleStrideMinutes,
            unit: 'min',
            minimum: 1,
            maximum: 1440,
            formula: 'levodopa.absorption.ir-openness/1',
          ),
          (
            id: 'absorption.openness.ir_peak',
            name: 'IR peak openness weight',
            value: absorptionParameters.irPeakOpenness,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
            formula: 'levodopa.absorption.ir-openness/1',
          ),
          (
            id: 'absorption.openness.ir_tail',
            name: 'IR terminal openness weight',
            value: absorptionParameters.irTailOpenness,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
            formula: 'levodopa.absorption.ir-openness/1',
          ),
        ]) {
      records.add(
        _valueRecord(
          id: spec.id,
          algorithmIds: const ['levodopa_absorption_opportunity'],
          displayName: spec.name,
          formulaId: spec.formula,
          unit: spec.unit,
          value: spec.value,
          minimum: spec.minimum,
          maximum: spec.maximum,
          sources: absorptionSources,
          reviewDate: reviewDate,
          limitation:
              'Population-informed educational shape parameter; not fitted to '
              'an individual, formulation, plasma concentration, or outcome.',
        ),
      );
    }

    records.addAll([
      AlgorithmParameterProvenanceRecord(
        parameterId:
            LevodopaAbsorptionOpportunityParameterIds.generatorStructure,
        algorithmIds: const ['levodopa_absorption_opportunity'],
        displayName: 'Absorption generator branch and output-code policy',
        semanticId:
            LevodopaAbsorptionOpportunityParameterIds.generatorStructure,
        formulaId: 'levodopa.absorption.generator-structure/1',
        originalUnit: 'canonical_json',
        canonicalUnit: 'canonical_json',
        originalValue: LevodopaAbsorptionOpportunityModel.generatorStructure,
        canonicalValue: LevodopaAbsorptionOpportunityModel.generatorStructure,
        supportedDomain: AlgorithmParameterSupport.schema(
          'parkinsum.levodopa-absorption-generator-structure/1',
        ),
        transformId: 'identity-json/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: absorptionSources,
        reviewDate: absorptionParameters.lastReviewed,
        limitation:
            'Reviewed deterministic branch declaration for an educational '
            'opportunity trace; it is not a PK/PD model or clinical policy.',
      ),
      AlgorithmParameterProvenanceRecord(
        parameterId:
            LevodopaAbsorptionOpportunityParameterIds.outputIntegrityContract,
        algorithmIds: const ['levodopa_absorption_opportunity'],
        displayName: 'Absorption output integrity and wire policy',
        semanticId:
            LevodopaAbsorptionOpportunityParameterIds.outputIntegrityContract,
        formulaId: 'levodopa.absorption.output-integrity/1',
        originalUnit: 'canonical_json',
        canonicalUnit: 'canonical_json',
        originalValue: AbsorptionOpportunityWindow.integrityConfiguration,
        canonicalValue: AbsorptionOpportunityWindow.integrityConfiguration,
        supportedDomain: AlgorithmParameterSupport.schema(
          'parkinsum.absorption-opportunity-output-contract/1',
        ),
        transformId: 'identity-json/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: const [internalSource],
        reviewDate: absorptionParameters.lastReviewed,
        limitation:
            'Engineering integrity and abstention encoding only; passing does '
            'not establish physiological, clinical, safety, or efficacy truth.',
      ),
    ]);

    records.addAll([
      _valueRecord(
        id: 'competition.reference_protein_g',
        algorithmIds: const ['amino_acid_competition'],
        displayName: 'Competition reference protein load',
        formulaId: 'lnaa.competition.peak-normalized-load/2',
        unit: 'g',
        value: AminoAcidCompetitionModel.referenceProteinG,
        minimum: 0.001,
        maximum: 1000,
        sources: const [
          'src.nutt.lnaa.1989',
          'src.nutt.onoff.1984',
          internalSource,
        ],
        reviewDate: reviewDate,
        limitation:
            'Reference magnitude is illustrative, not a dose-response fit.',
      ),
      _valueRecord(
        id: 'competition.sample_stride_minutes',
        algorithmIds: const ['amino_acid_competition'],
        displayName: 'Competition timeline sampling stride',
        formulaId: 'lnaa.competition.peak-normalized-load/2',
        unit: 'min',
        value: AminoAcidCompetitionModel.sampleStrideMinutes,
        minimum: 1,
        maximum: 1440,
        sources: const [internalSource],
        reviewDate: reviewDate,
        limitation: 'Numerical sampling interval is an engineering choice.',
      ),
    ]);
    for (final factor in lnaaFactors) {
      records.add(
        _valueRecord(
          id: 'competition.lnaa_factor.${factor.sourceType.name}',
          algorithmIds: const ['amino_acid_competition'],
          displayName: '${factor.sourceType.name} protein LNAA load factor',
          formulaId: 'lnaa.competition.source-factor/1',
          unit: 'multiplier',
          value: factor.loadFactor,
          minimum: 0,
          maximum: 3,
          sources: factor.sourceRefs,
          reviewDate: reviewDate,
          limitation: factor.limitation,
        ),
      );
    }

    for (final spec
        in <
          ({
            String id,
            String name,
            num value,
            String unit,
            double minimum,
            double maximum,
          })
        >[
          (
            id: 'protein_distribution.high_overlap_threshold',
            name: 'High-overlap threshold',
            value: ProteinDistributionModel.highOverlapThreshold,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
          ),
          (
            id: 'protein_distribution.low_overlap_threshold',
            name: 'Low-overlap threshold',
            value: ProteinDistributionModel.lowOverlapThreshold,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
          ),
          (
            id: 'protein_distribution.evening_hour_start',
            name: 'Local-hour evening label threshold',
            value: ProteinDistributionModel.eveningHourStart,
            unit: 'local_hour_0_23',
            minimum: 0,
            maximum: 23,
          ),
          (
            id: 'protein_distribution.adequacy_reference_protein_g',
            name: 'Single-meal adequacy-proxy reference protein',
            value: ProteinDistributionModel.adequacyReferenceProteinG,
            unit: 'g',
            minimum: 0.001,
            maximum: 1000,
          ),
        ]) {
      records.add(
        _valueRecord(
          id: spec.id,
          algorithmIds: const ['protein_distribution'],
          displayName: spec.name,
          formulaId: 'protein.redistribution.overlap-objective/1',
          unit: spec.unit,
          value: spec.value,
          minimum: spec.minimum,
          maximum: spec.maximum,
          sources: const [
            'src.cereda.protein.2017',
            'src.pare.protein.redistribution.1992',
            'src.virmani.protein.2023',
            internalSource,
          ],
          reviewDate: reviewDate,
          limitation: 'Educational objective parameter; not a dietary target.',
        ),
      );
    }

    for (final weight in scoringParameters.all) {
      records.add(
        _valueRecord(
          id: weight.id,
          algorithmIds: const ['mechanistic_candidate_scorer'],
          displayName: weight.label,
          formulaId: 'candidate-score.bounded-linear-composition/1',
          unit: 'weight_0_1',
          value: weight.value,
          minimum: 0,
          maximum: 1,
          sources: weight.sourceRefs,
          reviewDate: reviewDate,
          limitation:
              '${weight.limitation} The coefficient itself is not fitted.',
        ),
      );
    }
    for (final spec in <({String id, String name, int value})>[
      (
        id: 'candidate_score.min_sample_count',
        name: 'Minimum candidate-window samples',
        value: MechanisticNextMealScorer.minSampleCount,
      ),
      (
        id: 'candidate_score.max_sample_count',
        name: 'Maximum candidate-window samples',
        value: MechanisticNextMealScorer.maxSampleCount,
      ),
      (
        id: 'candidate_score.sample_stride_minutes',
        name: 'Candidate-window sample stride',
        value: MechanisticNextMealScorer.sampleStrideMinutes,
      ),
    ]) {
      records.add(
        _valueRecord(
          id: spec.id,
          algorithmIds: const ['mechanistic_candidate_scorer'],
          displayName: spec.name,
          formulaId: 'candidate-score.window-sampling/1',
          unit: spec.id.endsWith('minutes') ? 'min' : 'count',
          value: spec.value,
          minimum: 1,
          maximum: 10000,
          sources: const [internalSource],
          reviewDate: reviewDate,
          limitation: 'Deterministic engineering sampling choice.',
        ),
      );
    }

    for (final spec
        in <
          ({String id, String name, double value, String unit, double maximum})
        >[
          (
            id: 'legacy_nutrition.high_protein_per_100g_g',
            name: 'Legacy high-protein density threshold',
            value: NutritionRules.highProteinPer100gG,
            unit: 'g_per_100g',
            maximum: 100,
          ),
          (
            id: 'legacy_nutrition.high_protein_meal_threshold_g',
            name: 'Legacy high-protein meal threshold',
            value: NutritionRules.highProteinMealThresholdG,
            unit: 'g',
            maximum: 1000,
          ),
          (
            id: 'legacy_nutrition.protein_interference_threshold_g',
            name: 'Legacy protein-interference threshold',
            value: NutritionRules.proteinInterferenceThresholdG,
            unit: 'g',
            maximum: 1000,
          ),
          (
            id: 'legacy_nutrition.low_fiber_meal_threshold_g',
            name: 'Legacy low-fiber meal threshold',
            value: NutritionRules.lowFiberMealThresholdG,
            unit: 'g',
            maximum: 1000,
          ),
          (
            id: 'legacy_nutrition.high_sodium_meal_threshold_mg',
            name: 'Legacy high-sodium meal threshold',
            value: NutritionRules.highSodiumMealThresholdMg,
            unit: 'mg',
            maximum: 100000,
          ),
        ]) {
      records.add(
        _valueRecord(
          id: spec.id,
          algorithmIds: const ['legacy_nutrition_classifier'],
          displayName: spec.name,
          formulaId: 'legacy-nutrition.threshold-classifier/1',
          unit: spec.unit,
          value: spec.value,
          minimum: 0,
          maximum: spec.maximum,
          sources: const [internalSource],
          reviewDate: reviewDate,
          limitation:
              'Compatibility threshold retained for legacy paths; magnitude '
              'is an educational heuristic, not a clinical cutoff.',
        ),
      );
    }

    for (final parameter in legacyFoodRecommendationParameters.parameters) {
      records.add(
        _valueRecord(
          id: parameter.id,
          algorithmIds: const ['legacy_food_recommendations'],
          displayName: parameter.label,
          formulaId: parameter.formulaId,
          unit: parameter.unit,
          value: parameter.value,
          minimum: parameter.minimum,
          maximum: parameter.maximum,
          sources: parameter.sourceRefs,
          reviewDate: legacyFoodRecommendationParameters.lastReviewed,
          limitation: parameter.limitation,
        ),
      );
    }
    records.add(
      AlgorithmParameterProvenanceRecord(
        parameterId: LegacyFoodRecommendationParameterIds.tieBreakPolicy,
        algorithmIds: const ['legacy_food_recommendations'],
        displayName: LegacyFoodRecommendationParameterSet.tieBreakLabel,
        semanticId: LegacyFoodRecommendationParameterIds.tieBreakPolicy,
        formulaId: LegacyFoodRecommendationParameterSet.tieBreakFormulaId,
        originalUnit: LegacyFoodRecommendationParameterSet.tieBreakUnit,
        canonicalUnit: LegacyFoodRecommendationParameterSet.tieBreakUnit,
        originalValue: legacyFoodRecommendationParameters.tieBreakPolicy,
        canonicalValue: legacyFoodRecommendationParameters.tieBreakPolicy,
        supportedDomain: AlgorithmParameterSupport.allowedValues(
          LegacyFoodRecommendationParameterSet.supportedTieBreakPolicies,
        ),
        transformId: 'identity/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: LegacyFoodRecommendationParameterSet.tieBreakSourceRefs,
        reviewDate: legacyFoodRecommendationParameters.lastReviewed,
        limitation: LegacyFoodRecommendationParameterSet.tieBreakLimitation,
      ),
    );
    records.add(
      AlgorithmParameterProvenanceRecord(
        parameterId: LegacyFoodRecommendationProvenancePolicy.parameterId,
        algorithmIds: const ['legacy_food_recommendations'],
        displayName: 'Legacy source-system provenance score policy',
        semanticId: LegacyFoodRecommendationProvenancePolicy.parameterId,
        formulaId: LegacyFoodRecommendationProvenancePolicy.formulaId,
        originalUnit: LegacyFoodRecommendationProvenancePolicy.unit,
        canonicalUnit: LegacyFoodRecommendationProvenancePolicy.unit,
        originalValue: LegacyFoodRecommendationProvenancePolicy.canonicalValue,
        canonicalValue: LegacyFoodRecommendationProvenancePolicy.canonicalValue,
        supportedDomain: AlgorithmParameterSupport.schema(
          'legacy-food-source-provenance-policy/1',
        ),
        transformId: LegacyFoodRecommendationProvenancePolicy.transformId,
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: LegacyFoodRecommendationProvenancePolicy.sourceRefs,
        reviewDate: legacyFoodRecommendationParameters.lastReviewed,
        limitation: LegacyFoodRecommendationProvenancePolicy.limitation,
      ),
    );

    for (final rule in runtimeRuleLogic) {
      final ruleId = rule['rule_id'];
      if (ruleId is! String || ruleId.trim().isEmpty) {
        throw ArgumentError(
          'Every runtime-rule provenance record needs rule_id.',
        );
      }
      final provenance = rule['provenance'];
      final declaredSources = provenance is Map
          ? (provenance['source_refs'] as List?)?.whereType<String>().toList(
                  growable: false,
                ) ??
                const <String>[]
          : const <String>[];
      records.add(
        AlgorithmParameterProvenanceRecord(
          parameterId: 'runtime_rule.$ruleId.logic',
          algorithmIds: const ['runtime_rule_engine'],
          displayName: 'Runtime rule $ruleId',
          semanticId: 'runtime_rule.$ruleId.logic',
          formulaId: 'runtime-rule.canonical-logic/1',
          originalUnit: 'canonical_json',
          canonicalUnit: 'canonical_json',
          originalValue: rule,
          canonicalValue: rule,
          supportedDomain: AlgorithmParameterSupport.schema(
            'parkinsum.cdss-rule-logic/1',
          ),
          transformId: 'identity-json/1',
          provenanceStatus:
              AlgorithmParameterProvenanceStatus.prototypeHeuristic,
          sourceIds: declaredSources.isEmpty
              ? const [internalSource]
              : [...declaredSources, internalSource],
          reviewDate: reviewDate,
          limitation:
              'Canonical rule logic may mix source-derived conditions with '
              'prototype operational policy; identity is not validation.',
        ),
      );
    }

    for (final descriptor in algorithmDescriptors.where(
      (descriptor) => descriptor.traceProviderId != null,
    )) {
      records.add(
        AlgorithmParameterProvenanceRecord(
          parameterId: 'trace_provider.${descriptor.id}',
          algorithmIds: [descriptor.id],
          displayName: '${descriptor.name} trace-provider binding',
          semanticId: 'trace_provider.${descriptor.id}',
          formulaId: 'algorithm.trace-provider-binding/1',
          originalUnit: 'provider_id',
          canonicalUnit: 'provider_id',
          originalValue: descriptor.traceProviderId,
          canonicalValue: descriptor.traceProviderId,
          supportedDomain: AlgorithmParameterSupport.allowedValues([
            descriptor.traceProviderId,
          ]),
          transformId: 'identity/1',
          provenanceStatus:
              AlgorithmParameterProvenanceStatus.prototypeHeuristic,
          sourceIds: const [internalSource],
          reviewDate: reviewDate,
          limitation:
              'Provider binding attests trace origin, not scientific validity.',
        ),
      );
    }

    return AlgorithmParameterProvenanceManifest(records);
  }
}

AlgorithmParameterProvenanceRecord _valueRecord({
  required String id,
  required List<String> algorithmIds,
  required String displayName,
  required String formulaId,
  required String unit,
  required num value,
  required double minimum,
  required double maximum,
  required List<String> sources,
  required String reviewDate,
  required String limitation,
  AlgorithmParameterProvenanceStatus status =
      AlgorithmParameterProvenanceStatus.prototypeHeuristic,
}) => AlgorithmParameterProvenanceRecord(
  parameterId: id,
  algorithmIds: algorithmIds,
  displayName: displayName,
  semanticId: id,
  formulaId: formulaId,
  originalUnit: unit,
  canonicalUnit: unit,
  originalValue: value,
  canonicalValue: value,
  supportedDomain: AlgorithmParameterSupport.numericRange(
    minimum: minimum,
    maximum: maximum,
  ),
  transformId: 'identity/1',
  provenanceStatus: status,
  sourceIds: sources,
  reviewDate: reviewDate,
  limitation: limitation,
);

({String formulaId, String unit, double minimum, double maximum}) _gastricSpec(
  String id,
) {
  if (id.endsWith('lag_minutes')) {
    return (
      formulaId: 'gastric-emptying.explicit-lag-linear-exponential/2',
      unit: 'min',
      minimum: 0,
      maximum: 1440,
    );
  }
  if (id.endsWith('half_minutes')) {
    return (
      formulaId: 'gastric-emptying.explicit-lag-linear-exponential/2',
      unit: 'min',
      minimum: 0.001,
      maximum: 2880,
    );
  }
  if (id.endsWith('reference_kcal')) {
    return (
      formulaId: 'gastric-emptying.meal-size-scale/1',
      unit: 'kcal',
      minimum: 0.001,
      maximum: 10000,
    );
  }
  if (id.endsWith('uncertainty_boost')) {
    return (
      formulaId: 'gastric-emptying.ordinal-uncertainty/2',
      unit: 'ordinal_step',
      minimum: 0,
      maximum: 4,
    );
  }
  if (id == 'ge.highcal.fraction_threshold') {
    return (
      formulaId: 'gastric-emptying.meal-size-scale/1',
      unit: 'multiplier',
      minimum: 0,
      maximum: 10,
    );
  }
  if (id.endsWith('fraction_threshold') ||
      id.endsWith('sensitivity_fraction')) {
    return (
      formulaId: 'gastric-emptying.bounded-sensitivity/2',
      unit: 'ratio_0_1',
      minimum: 0,
      maximum: 1,
    );
  }
  if (id.endsWith('multiplier')) {
    return (
      formulaId: 'gastric-emptying.component-time-scale/2',
      unit: 'multiplier',
      minimum: 0,
      maximum: 10,
    );
  }
  throw StateError('Missing gastric provenance specification for $id.');
}

void validateRegisteredParameterSources(
  AlgorithmParameterProvenanceManifest manifest,
) {
  final unknown = <String>{};
  for (final record in manifest.records) {
    for (final sourceId in record.sourceIds) {
      if (sourceId.startsWith('src.') &&
          ModelAssumptionRegistry.byId(sourceId) == null) {
        unknown.add(sourceId);
      }
    }
  }
  if (unknown.isNotEmpty) {
    throw StateError('Unknown model source IDs: ${unknown.toList()..sort()}');
  }
}

void _validateJsonValue(Object? value, {required String field}) {
  if (value == null || value is String || value is bool) return;
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, field, 'must be finite');
    }
    return;
  }
  if (value is List) {
    for (final child in value) {
      _validateJsonValue(child, field: field);
    }
    return;
  }
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw ArgumentError.value(value, field, 'map keys must be strings');
    }
    for (final child in value.values) {
      _validateJsonValue(child, field: field);
    }
    return;
  }
  throw ArgumentError.value(value, field, 'must be JSON-compatible');
}

Object? _deepFreeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _deepFreeze(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_deepFreeze));
  }
  return value;
}

String _canonicalDigest(Object? value) {
  Object? canonicalize(Object? node) {
    if (node is Map) {
      final keys = node.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: canonicalize(node[key]),
      };
    }
    if (node is List) return node.map(canonicalize).toList(growable: false);
    return node;
  }

  return sha256
      .convert(utf8.encode(jsonEncode(canonicalize(value))))
      .toString();
}

void _requireIdentifier(String value, {required String field}) {
  if (!_identifierPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'must be a safe stable identifier');
  }
}

void _requireIsoDate(String value, {required String field}) {
  if (!_datePattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'must use YYYY-MM-DD');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw ArgumentError.value(value, field, 'must be a real calendar date');
  }
}

final RegExp _identifierPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,239}$',
);
final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
const List<String> _participantLevelDiagnosticTokens = [
  'participant',
  'patient',
  'subject',
  'individual',
  'observation_row',
  'record_id',
];
