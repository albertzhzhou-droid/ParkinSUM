library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/analysis/nutrition_rules.dart';
import '../domain/entities/algorithm_descriptor.dart';
import '../domain/entities/gastric_emptying_parameters.dart';
import '../domain/entities/protein_source.dart';
import '../domain/usecases/amino_acid_competition_model.dart';
import '../domain/usecases/levodopa_absorption_opportunity_model.dart';
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
  static const String schema = 'parkinsum.algorithm-parameter-provenance/1';

  final String parameterId;
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

final class AlgorithmParameterProvenanceManifest {
  static const String schema = 'parkinsum.algorithm-parameter-manifest/1';

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
    required NextMealScoringParameterSet scoringParameters,
    required List<LnaaLoadFactor> lnaaFactors,
    required List<Map<String, dynamic>> runtimeRuleLogic,
    required List<AlgorithmDescriptor> algorithmDescriptors,
  }) {
    const reviewDate = '2026-08-17';
    const internalSource = 'src.internal.prototype.heuristic';
    final records = <AlgorithmParameterProvenanceRecord>[];

    for (final parameter in gastricParameters.all) {
      final spec = _gastricSpec(parameter.id);
      records.add(
        _valueRecord(
          id: parameter.id,
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

    final absorptionSources = <String>[
      'src.dailymed.sinemet.label',
      'src.nutt.onoff.1984',
      'src.doi.ge.levodopa.2012',
      internalSource,
    ];
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
            value: LevodopaAbsorptionOpportunityModel.referenceIrLagMinutes,
            unit: 'min',
            minimum: 0,
            maximum: 1440,
            formula: 'levodopa.absorption.ir-window/1',
          ),
          (
            id: 'absorption.ir.reference_duration_minutes',
            name: 'IR reference opportunity duration',
            value:
                LevodopaAbsorptionOpportunityModel.referenceIrDurationMinutes,
            unit: 'min',
            minimum: 1,
            maximum: 2880,
            formula: 'levodopa.absorption.ir-window/1',
          ),
          (
            id: 'absorption.meal.illustrative_delay_minutes',
            name: 'Illustrative meal-associated opportunity shift',
            value:
                LevodopaAbsorptionOpportunityModel.illustrativeMealDelayMinutes,
            unit: 'min',
            minimum: 0,
            maximum: 1440,
            formula: 'levodopa.absorption.residual-load-shift/2',
          ),
          (
            id: 'absorption.openness.sample_stride_minutes',
            name: 'Absorption-openness sampling stride',
            value:
                LevodopaAbsorptionOpportunityModel.opennessSampleStrideMinutes,
            unit: 'min',
            minimum: 1,
            maximum: 1440,
            formula: 'levodopa.absorption.ir-openness/1',
          ),
          (
            id: 'absorption.openness.ir_peak',
            name: 'IR peak openness weight',
            value: LevodopaAbsorptionOpportunityModel.irPeakOpenness,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
            formula: 'levodopa.absorption.ir-openness/1',
          ),
          (
            id: 'absorption.openness.ir_tail',
            name: 'IR terminal openness weight',
            value: LevodopaAbsorptionOpportunityModel.irTailOpenness,
            unit: 'ratio_0_1',
            minimum: 0,
            maximum: 1,
            formula: 'levodopa.absorption.ir-openness/1',
          ),
        ]) {
      records.add(
        _valueRecord(
          id: spec.id,
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
      _valueRecord(
        id: 'competition.reference_protein_g',
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
