library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'algorithm_parameter_provenance.dart';
import '../core/analysis/nutrition_rules.dart';
import '../core/constants/baseline_cdss_rules.dart';
import '../domain/entities/gastric_emptying_parameters.dart';
import '../domain/entities/levodopa_absorption_opportunity_parameters.dart';
import '../domain/entities/mechanistic_medication_applicability.dart';
import '../domain/entities/protein_source.dart';
import '../domain/usecases/amino_acid_competition_model.dart';
import '../domain/usecases/levodopa_absorption_opportunity_model.dart';
import '../domain/usecases/legacy_food_recommendation_parameters.dart';
import '../domain/usecases/mechanistic_next_meal_scorer.dart';
import '../domain/usecases/next_meal_scoring_parameters.dart';
import '../domain/usecases/protein_distribution_model.dart';
import '../domain/usecases/algorithm_registry.dart';
import '../domain/usecases/dosage_note_parser.dart';
import '../domain/usecases/gastric_emptying_model.dart';

/// Canonical identity for every default configuration family that can change
/// a deterministic ParkinSUM result.
///
/// Public parameter objects and constants are serialized directly. Some older
/// algorithms still keep thresholds private or inline; their exact source
/// fingerprints are therefore part of this identity as a fail-closed bridge.
/// A contract test recomputes every fingerprint from the production source, so
/// such a threshold cannot change silently: the checked-in identity and the
/// SDK digest must be updated together.
final class AlgorithmConfigurationIdentity {
  static const String schema = 'parkinsum.algorithm-configuration/6';
  static const String defaultId = 'parkinsum-default-algorithm-stack';
  // v46 additionally binds the local food-projection query, returned row IDs,
  // content digests, and selection/last-wins policy. This is engineering
  // provenance; it does not establish an atomic catalog snapshot or rank stability.
  // v47 changes only the digest encoding: integral doubles hash as integers so
  // VM and web builds derive the same identity. Payload values are unchanged.
  // v49 binds the protein-trend production trace provider in the algorithm
  // manifest. This changes configuration provenance, not calculation behavior.
  // v50 adds the trend's explicit time/value/mean contract and direct model
  // source bindings; it does not add a dietary-adequacy interpretation.
  // v51 adds the standalone synthetic dose-parser trace to the observatory.
  // v52 gates mechanistic traces on an exact evidence-currency assessment and
  // binds each result to the reviewed snapshot, as-of time, and provider set.
  // v53 adds the food-composition interdependency layer to the mechanistic
  // conflict engine (food-borne L-dopa presence, dry/cooked ambiguity and
  // energy-identity findings). It can add drivers and uncertainty and cap
  // confidence; it never changes the interaction score.
  // v54 binds the composition identity audit (food-specific energy factors,
  // proximate closure and part-within-whole checks) and the expanded FDC
  // importer sources. Engine scores and severities are unchanged.
  static const String defaultVersion = '2026.10.08-v54';

  /// SHA-256 over `path:file_sha256\n` for every source path owned by the
  /// algorithm registry, sorted lexicographically. The identity source itself
  /// is the sole exclusion to avoid a recursive self-hash; its emitted manifest
  /// and configuration are already the payload being hashed. This closes the
  /// gap between individually modeled parameters and remaining inline logic.
  static const String registeredAlgorithmSourceBundleSha256 =
      'a4dfcae4d9bb7e47a0d9a6a3451835847c79850af947f0dca0415e4cd5a75bd0';

  /// Exact production files that currently contain result-affecting constants
  /// or formula branches which are not all represented by injectable objects.
  /// Values are verified mechanically in `parkinsum_algorithm_sdk_test.dart`.
  static const Map<String, String> defaultImplementationSourceDigests = {
    'lib/domain/entities/gastric_emptying_parameters.dart':
        'c6f3f29de193e403cd2cab5b6d113fd6ea52f220e875092492179b5d93baac5f',
    'lib/domain/entities/gastric_emptying_profile.dart':
        '907c6ed035001f35eee062df4c24fdf3d0f435a1f9739851944fb1670fcc558e',
    'lib/domain/usecases/gastric_emptying_model.dart':
        '4463c1c8de88b7f5e12a8ff87b0edef96aaf1d71b72cd2eaa38ab2b4978fca7b',
    'lib/domain/usecases/meal_composition_normalizer.dart':
        'c9e902d8c5f37b37ad73be5d598319730d1b7d6afb5eafb63f4ba787598c9c7f',
    'lib/domain/entities/absorption_opportunity.dart':
        'b069f21f51e7a7a3730d602160fcc3355b6dfe2953567b34f3084f6d599e1628',
    'lib/domain/entities/levodopa_absorption_opportunity_parameters.dart':
        '96685c8267f263f8c69bce627a43f116f3a6d93edb30dd2a5218e2ec68339d2b',
    'lib/domain/usecases/levodopa_absorption_opportunity_model.dart':
        'c0c2500bd33df75f18499b6bfaef8f4dacab413ab923a098cd26b101c4cfd2cd',
    'lib/domain/entities/amino_acid_competition.dart':
        'db04c321607e84dda10511e40158b575e7788408f3ff0ac5a3257fe4ac47f1b9',
    'lib/domain/entities/amino_acid_profile.dart':
        'b19f1b235adeab1b2592507b2f3e81cf9edcba72c267751e44006f042692b5dd',
    'lib/domain/entities/nutrient_derivation.dart':
        '013684f5865c2d957a0ce27fed47b93e8f0ca27852be2b6a6330d0f377fabd99',
    'lib/domain/entities/protein_source.dart':
        'd04048adf3a7d4d44f4de9d4293b59b8aa28ac627fa24fd6b524894167c14d86',
    'lib/domain/usecases/amino_acid_competition_model.dart':
        '499cb3a8939f135c01ffa630202fa8c9abf57dae5cd5868ca4f3b0012bbf5f70',
    'lib/domain/usecases/mechanistic_conflict_engine.dart':
        '79c01e3d8de22b7660ba16d917682f28a1447d7e867af09f84651cfd878c05cf',
    'lib/domain/usecases/food_composition_interdependency_model.dart':
        '5efcccb9b2e9fff12082609fea62ca23f2b6d5f4f1cdc3120c64430e54c7d614',
    'lib/domain/usecases/protein_distribution_model.dart':
        '9ab6035545b0dc2d6d462112a7c2d42f900bb24a9b6ecd7b9a42b7fbcfa2f881',
    'lib/domain/usecases/next_meal_scoring_parameters.dart':
        '6d02d9c819e99bc1ba075c4aa331eb1c5c0dfe51746ba868e2ca1a5647881b77',
    'lib/domain/usecases/mechanistic_next_meal_scorer.dart':
        'c71097ba45f8c7f02804fe657a36db9348e3e8524634b5447cf178707cb91b0a',
    'lib/domain/entities/rule_registry_models.dart':
        'dbecb0bbef2dd2e6baa64262b07df6fef3be07b2d6765e2898560ff432769b5b',
    'lib/domain/usecases/runtime_rule_engine.dart':
        'ca01e345e525cb8f6a83172d1b1b2d4855baaddbdded73bca10596156086ebcc',
    'lib/domain/usecases/runtime_rule_support.dart':
        '704566d904c9ab2bbfe01d841a84486d16d5eb89e80cd4a2411312a80a3de504',
    'lib/core/constants/baseline_cdss_rules.dart':
        'b2af81ac45371e8186fc073a2fc2d91fa2615a7fb08cdfc9c7ccad0409ac1fba',
    'lib/core/analysis/nutrition_rules.dart':
        '658a20a20000e7ff6ca1af0d8392ffd7582f8129771f4879f749089d8ac11a75',
    'lib/core/analysis/interaction_engine.dart':
        '81c8bf548ee028042aaea712934f409b296aa25cbe7596f49b3c13fb870979c7',
  };

  final String id;
  final String version;
  final AlgorithmParameterProvenanceManifest parameterProvenanceManifest;
  final AlgorithmConfigurationCoverageManifest configurationCoverageManifest;
  final Map<String, dynamic> canonicalConfiguration;

  AlgorithmConfigurationIdentity._({
    required this.id,
    required this.version,
    required this.parameterProvenanceManifest,
    required this.configurationCoverageManifest,
    required Map<String, dynamic> configuration,
  }) : canonicalConfiguration =
           _deepFreeze(_canonicalize(configuration)) as Map<String, dynamic>;

  factory AlgorithmConfigurationIdentity.defaults({
    GastricEmptyingParameterSet? gastricParameters,
    LevodopaAbsorptionOpportunityParameterSet? absorptionParameters,
    NextMealScoringParameterSet? scoringParameters,
    LegacyFoodRecommendationParameterSet? legacyFoodRecommendationParameters,
    List<Map<String, dynamic>>? runtimeRules,
  }) {
    _validateImplementationSourceDigests(defaultImplementationSourceDigests);
    final reviewedGastric =
        GastricEmptyingParameterSet.literatureInformedDefault();
    final gastric = gastricParameters ?? reviewedGastric;
    final gastricConfiguration = GastricEmptyingModel(
      parameters: gastric,
    ).configuration;
    final hasReviewedGastricConfiguration =
        digestConfiguration(gastricConfiguration) ==
        digestConfiguration(
          GastricEmptyingModel(parameters: reviewedGastric).configuration,
        );
    final scoring =
        scoringParameters ??
        NextMealScoringParameterSet.literatureInformedDefault();
    final reviewedAbsorption =
        LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();
    final absorption = absorptionParameters ?? reviewedAbsorption;
    final absorptionConfiguration = LevodopaAbsorptionOpportunityModel(
      parameters: absorption,
    ).configuration;
    final hasReviewedAbsorptionConfiguration =
        digestConfiguration(absorption.toJson()) ==
        digestConfiguration(reviewedAbsorption.toJson());
    final legacyFoodRecommendations =
        legacyFoodRecommendationParameters ??
        LegacyFoodRecommendationParameterSet.prototypeDefault();
    final legacyValidationErrors = legacyFoodRecommendations.validationErrors;
    if (legacyValidationErrors.isNotEmpty) {
      throw ArgumentError.value(
        legacyValidationErrors,
        'legacyFoodRecommendationParameters',
        'Legacy recommendation parameters must pass the execution contract.',
      );
    }
    final lnaaFactors = ProteinSourceLnaaRegistry.all()
      ..sort(
        (left, right) => left.sourceType.name.compareTo(right.sourceType.name),
      );
    final rules =
        (runtimeRules ?? baselineCdssRules)
            .map(_ruleLogicIdentity)
            .toList(growable: false)
          ..sort(
            (left, right) => (left['rule_id'] as String).compareTo(
              right['rule_id'] as String,
            ),
          );
    final algorithmManifest =
        AlgorithmRegistry.all
            .map((descriptor) => descriptor.toManifestJson())
            .toList(growable: false)
          ..sort(
            (left, right) =>
                (left['id'] as String).compareTo(right['id'] as String),
          );
    final parameterProvenanceManifest =
        AlgorithmParameterProvenanceManifest.defaults(
          gastricParameters: gastric,
          absorptionParameters: absorption,
          scoringParameters: scoring,
          legacyFoodRecommendationParameters: legacyFoodRecommendations,
          lnaaFactors: lnaaFactors,
          runtimeRuleLogic: rules,
          algorithmDescriptors: AlgorithmRegistry.all,
        );
    validateRegisteredParameterSources(parameterProvenanceManifest);
    const gastricAlgorithmId = 'gastric_emptying';
    const gastricSourcePaths = <String>[
      'lib/domain/usecases/gastric_emptying_model.dart',
      'lib/domain/entities/gastric_emptying_parameters.dart',
      'lib/domain/entities/gastric_emptying_profile.dart',
    ];
    final gastricFieldIds =
        GastricEmptyingParameterIds.completeCoverage.toList()..sort();
    final gastricSinksByField = <String, Iterable<String>>{
      for (final fieldId in gastricFieldIds)
        fieldId: switch (fieldId) {
          GastricEmptyingParameterIds.solidLagMinutes ||
          GastricEmptyingParameterIds.liquidLagMinutes => const [
            'component_profiles',
            'aggregate_lag_minutes',
            'peak_emptying_window',
            'mostly_emptied_window',
            'remaining_fraction_curve',
            'emptied_fraction_curve',
            'intestinal_arrival_rate_curve',
            'sensitivity_envelope',
            'source_refs',
          ],
          GastricEmptyingParameterIds.solidHalfMinutes ||
          GastricEmptyingParameterIds.liquidHalfMinutes ||
          GastricEmptyingParameterIds.fatSlowdownMultiplier ||
          GastricEmptyingParameterIds.fiberSlowdownMultiplier => const [
            'component_profiles',
            'peak_emptying_window',
            'mostly_emptied_window',
            'remaining_fraction_curve',
            'emptied_fraction_curve',
            'intestinal_arrival_rate_curve',
            'sensitivity_envelope',
            'assumptions',
            'source_refs',
          ],
          GastricEmptyingParameterIds.referenceMealCalories => const [
            'component_profiles',
            'aggregate_lag_minutes',
            'peak_emptying_window',
            'mostly_emptied_window',
            'remaining_fraction_curve',
            'emptied_fraction_curve',
            'intestinal_arrival_rate_curve',
            'sensitivity_envelope',
            'uncertainty_band',
            'assumptions',
            'source_refs',
          ],
          GastricEmptyingParameterIds.fatFractionThreshold => const [
            'component_profiles',
            'peak_emptying_window',
            'mostly_emptied_window',
            'remaining_fraction_curve',
            'emptied_fraction_curve',
            'intestinal_arrival_rate_curve',
            'sensitivity_envelope',
            'uncertainty_band',
            'assumptions',
            'source_refs',
          ],
          GastricEmptyingParameterIds.mixedMealUncertaintyBoost ||
          GastricEmptyingParameterIds.overlapUncertaintyBoost ||
          GastricEmptyingParameterIds.fatUncertaintyBoost ||
          GastricEmptyingParameterIds.highCalorieUncertaintyBoost ||
          GastricEmptyingParameterIds.highCalorieFractionThreshold => const [
            'uncertainty_band',
            'assumptions',
            'source_refs',
          ],
          GastricEmptyingParameterIds.timeScaleSensitivityFraction => const [
            'time_scale_sensitivity_fraction',
            'sensitivity_envelope',
            'source_refs',
          ],
          GastricEmptyingParameterIds.generatorStructure => const [
            'availability',
            'applicability_reasons',
            'component_profiles',
            'uncertainty_band',
            'assumptions',
            'missing_inputs',
            'source_refs',
            'aggregate_lag_minutes',
            'peak_emptying_window',
            'mostly_emptied_window',
            'time_scale_sensitivity_fraction',
            'remaining_fraction_curve',
            'emptied_fraction_curve',
            'intestinal_arrival_rate_curve',
            'sensitivity_envelope',
          ],
          GastricEmptyingParameterIds.outputIntegrityContract => const [
            'availability',
            'applicability_reasons',
            'component_profiles',
            'aggregate_lag_minutes',
            'peak_emptying_window',
            'mostly_emptied_window',
            'remaining_fraction_curve',
            'emptied_fraction_curve',
            'intestinal_arrival_rate_curve',
            'sensitivity_envelope',
            'wire_representation',
          ],
          GastricEmptyingParameterIds.traceProvider => const [
            'trace_provider_binding',
          ],
          _ => throw StateError('Unreviewed gastric field $fieldId'),
        },
    };
    final gastricDependencyContractSha256 = <String, String>{
      'meal_composition_normalizer': digestConfiguration({
        'algorithm_id': 'meal_composition_normalizer',
        'source_sha256':
            defaultImplementationSourceDigests['lib/domain/usecases/meal_composition_normalizer.dart'],
      }),
      'runtime_model_applicability_abstention_gate':
          MechanisticApplicabilityManifest.current.sha256Digest,
    };
    final gastricCompletenessWitness = hasReviewedGastricConfiguration
        ? AlgorithmConfigurationCompletenessWitness(
            witnessId: 'gastric_emptying.complete_fields.v1',
            algorithmId: gastricAlgorithmId,
            reviewedAt: gastric.lastReviewed,
            fieldRecordIds: gastricFieldIds,
            affectedResultSinksByFieldId: gastricSinksByField,
            requiredResultSinks: const [
              'availability',
              'applicability_reasons',
              'component_profiles',
              'uncertainty_band',
              'assumptions',
              'missing_inputs',
              'source_refs',
              'aggregate_lag_minutes',
              'peak_emptying_window',
              'mostly_emptied_window',
              'time_scale_sensitivity_fraction',
              'remaining_fraction_curve',
              'emptied_fraction_curve',
              'intestinal_arrival_rate_curve',
              'sensitivity_envelope',
              'wire_representation',
              'trace_provider_binding',
            ],
            ownedSourceSha256: {
              for (final path in gastricSourcePaths)
                path: defaultImplementationSourceDigests[path]!,
            },
            configurationSectionSha256: digestConfiguration(
              gastricConfiguration,
            ),
            registeredSourceBundleSha256: registeredAlgorithmSourceBundleSha256,
            dependencyContractSha256: gastricDependencyContractSha256,
            reviewEvidenceIds: const [
              'test.gastric_emptying_model',
              'test.mechanistic_model_invariant_gate',
              'oracle.gastric_high_precision_reference',
              'test.algorithm_configuration_completeness',
            ],
            completionBoundary:
                'Exact numeric parameters, meal-evidence gate, branch '
                'comparators, component weighting, ordinal uncertainty, curve '
                'and window construction, output-integrity and wire policy, '
                'normalizer dependency, trace provider, and owned sources.',
            limitation:
                'This checked-in witness proves only deterministic reviewed '
                'configuration closure for the default educational model. It '
                'does not establish gastric physiology, individual calibration, '
                'clinical safety, efficacy, or patient benefit.',
          )
        : null;
    const absorptionAlgorithmId = 'levodopa_absorption_opportunity';
    const absorptionSourcePaths = <String>[
      'lib/domain/usecases/levodopa_absorption_opportunity_model.dart',
      'lib/domain/entities/absorption_opportunity.dart',
      'lib/domain/entities/levodopa_absorption_opportunity_parameters.dart',
    ];
    final absorptionFieldIds =
        LevodopaAbsorptionOpportunityParameterIds.completeCoverage.toList()
          ..sort();
    final absorptionSinksByField = <String, Iterable<String>>{
      for (final fieldId in absorptionFieldIds)
        fieldId: switch (fieldId) {
          LevodopaAbsorptionOpportunityParameterIds.referenceIrLagMinutes =>
            const ['window', 'peak_minute', 'openness_profile'],
          LevodopaAbsorptionOpportunityParameterIds
              .referenceIrDurationMinutes =>
            const ['window', 'peak_minute', 'openness_profile'],
          LevodopaAbsorptionOpportunityParameterIds
              .illustrativeMealDelayMinutes =>
            const [
              'window',
              'peak_minute',
              'delay_likelihood',
              'assumptions',
              'openness_profile',
            ],
          LevodopaAbsorptionOpportunityParameterIds.highResidualThreshold ||
          LevodopaAbsorptionOpportunityParameterIds.moderateResidualThreshold =>
            const [
              'window',
              'peak_minute',
              'delay_likelihood',
              'assumptions',
              'openness_profile',
            ],
          LevodopaAbsorptionOpportunityParameterIds
              .highResidualEndDelayMultiplier =>
            const ['window', 'openness_profile'],
          LevodopaAbsorptionOpportunityParameterIds
              .moderateResidualShiftDivisor =>
            const ['window', 'peak_minute', 'openness_profile'],
          LevodopaAbsorptionOpportunityParameterIds.peakOffsetDurationDivisor =>
            const ['peak_minute', 'openness_profile'],
          LevodopaAbsorptionOpportunityParameterIds
              .opennessSampleStrideMinutes ||
          LevodopaAbsorptionOpportunityParameterIds.irPeakOpenness ||
          LevodopaAbsorptionOpportunityParameterIds.irTailOpenness => const [
            'openness_profile',
            'peak_openness',
          ],
          LevodopaAbsorptionOpportunityParameterIds.generatorStructure =>
            const [
              'window',
              'peak_minute',
              'delay_likelihood',
              'uncertainty_band',
              'assumptions',
              'missing_inputs',
              'source_refs',
              'availability',
              'openness_profile',
              'peak_openness',
            ],
          LevodopaAbsorptionOpportunityParameterIds.outputIntegrityContract =>
            const [
              'availability',
              'applicability_reasons',
              'openness_profile',
              'peak_openness',
              'wire_representation',
            ],
          'trace_provider.levodopa_absorption_opportunity' => const [
            'trace_provider_binding',
          ],
          _ => throw StateError('Unreviewed absorption field $fieldId'),
        },
    };
    final absorptionDependencyContractSha256 = <String, String>{
      'gastric_emptying': digestConfiguration(gastricConfiguration),
      'runtime_model_applicability_abstention_gate':
          MechanisticApplicabilityManifest.current.sha256Digest,
    };
    final absorptionCompletenessWitness = hasReviewedAbsorptionConfiguration
        ? AlgorithmConfigurationCompletenessWitness(
            witnessId: 'levodopa_absorption_opportunity.complete_fields.v1',
            algorithmId: absorptionAlgorithmId,
            reviewedAt: absorption.lastReviewed,
            fieldRecordIds: absorptionFieldIds,
            affectedResultSinksByFieldId: absorptionSinksByField,
            requiredResultSinks: const [
              'window',
              'peak_minute',
              'delay_likelihood',
              'uncertainty_band',
              'assumptions',
              'missing_inputs',
              'source_refs',
              'availability',
              'applicability_reasons',
              'openness_profile',
              'peak_openness',
              'wire_representation',
              'trace_provider_binding',
            ],
            ownedSourceSha256: {
              for (final path in absorptionSourcePaths)
                path: defaultImplementationSourceDigests[path]!,
            },
            configurationSectionSha256: digestConfiguration(
              absorptionConfiguration,
            ),
            registeredSourceBundleSha256: registeredAlgorithmSourceBundleSha256,
            dependencyContractSha256: absorptionDependencyContractSha256,
            reviewEvidenceIds: const [
              'test.absorption_openness_profile',
              'test.mechanistic_model_invariant_gate',
              'oracle.stack_independent_truth_vectors',
              'test.algorithm_configuration_completeness',
            ],
            completionBoundary:
                'Exact generator parameters, branch structure, applicability '
                'binding, openness construction, output-integrity contract, '
                'wire abstention, provider binding, and owned source files.',
            limitation:
                'Transitive gastric-emptying and applicability behavior remains '
                'separately owned and digest-bound. This witness proves only '
                'reviewed configuration closure, never PK/PD accuracy, clinical '
                'calibration, safety, efficacy, or patient benefit.',
          )
        : null;
    final configurationCoverageManifest =
        AlgorithmConfigurationCoverageManifest.fromRegistry(
          algorithmDescriptors: AlgorithmRegistry.all,
          parameterManifest: parameterProvenanceManifest,
          registeredSourceBundleSha256: registeredAlgorithmSourceBundleSha256,
          dependencyContractSha256ByAlgorithm: {
            if (gastricCompletenessWitness != null)
              gastricAlgorithmId: gastricDependencyContractSha256,
            if (absorptionCompletenessWitness != null)
              absorptionAlgorithmId: absorptionDependencyContractSha256,
          },
          completionWitnesses: [
            ?gastricCompletenessWitness,
            ?absorptionCompletenessWitness,
          ],
          configurationSectionSha256ByAlgorithm: {
            gastricAlgorithmId: digestConfiguration(gastricConfiguration),
            absorptionAlgorithmId: digestConfiguration(absorptionConfiguration),
          },
          implementationSourceSha256: defaultImplementationSourceDigests,
        );

    return AlgorithmConfigurationIdentity._(
      id: defaultId,
      version: defaultVersion,
      parameterProvenanceManifest: parameterProvenanceManifest,
      configurationCoverageManifest: configurationCoverageManifest,
      configuration: {
        'mechanistic_applicability_manifest': MechanisticApplicabilityManifest
            .current
            .toJson(),
        'dose_expression_grammar': DosageNoteParser.configurationIdentity,
        'gastric_emptying': gastricConfiguration,
        'levodopa_absorption_opportunity': absorptionConfiguration,
        'amino_acid_competition': {
          'reference_protein_g': AminoAcidCompetitionModel.referenceProteinG,
          'sample_stride_minutes':
              AminoAcidCompetitionModel.sampleStrideMinutes,
          'protein_source_lnaa_factors': [
            for (final factor in lnaaFactors) factor.toJson(),
          ],
        },
        'protein_distribution': {
          'high_overlap_threshold':
              ProteinDistributionModel.highOverlapThreshold,
          'low_overlap_threshold': ProteinDistributionModel.lowOverlapThreshold,
          'evening_hour_start': ProteinDistributionModel.eveningHourStart,
          'adequacy_reference_protein_g':
              ProteinDistributionModel.adequacyReferenceProteinG,
        },
        'candidate_scoring': {
          'weights': scoring.toJson(),
          'min_sample_count': MechanisticNextMealScorer.minSampleCount,
          'max_sample_count': MechanisticNextMealScorer.maxSampleCount,
          'sample_stride_minutes':
              MechanisticNextMealScorer.sampleStrideMinutes,
        },
        'legacy_food_recommendations': legacyFoodRecommendations.toJson(),
        'runtime_rule_logic': rules,
        'legacy_nutrition_thresholds': {
          'high_protein_per_100g_g': NutritionRules.highProteinPer100gG,
          'high_protein_meal_threshold_g':
              NutritionRules.highProteinMealThresholdG,
          'protein_interference_threshold_g':
              NutritionRules.proteinInterferenceThresholdG,
          'low_fiber_meal_threshold_g': NutritionRules.lowFiberMealThresholdG,
          'high_sodium_meal_threshold_mg':
              NutritionRules.highSodiumMealThresholdMg,
        },
        'algorithm_manifest': algorithmManifest,
        'parameter_provenance_manifest': parameterProvenanceManifest.toJson(),
        'algorithm_configuration_coverage_manifest':
            configurationCoverageManifest.toJson(),
        'registered_algorithm_source_bundle_sha256':
            registeredAlgorithmSourceBundleSha256,
        'implementation_source_sha256': defaultImplementationSourceDigests,
      },
    );
  }

  String get sha256Digest => digestConfiguration(canonicalConfiguration);

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'id': id,
    'version': version,
    'sha256': sha256Digest,
    'configuration': canonicalConfiguration,
  };

  /// Hashes a JSON-compatible value after recursively sorting every map key.
  /// List order is preserved because some ordered rule/action sequences are
  /// semantically meaningful; map insertion order is never meaningful.
  ///
  /// Integral doubles are hashed as integers so the digest is identical on the
  /// Dart VM (`90.0`) and on the web, where `int` and `double` share one
  /// JavaScript number representation and encode as `90`.
  static String digestConfiguration(Object? configuration) => sha256
      .convert(
        utf8.encode(jsonEncode(_canonicalize(configuration, forDigest: true))),
      )
      .toString();

  static Object? _canonicalize(Object? value, {bool forDigest = false}) {
    if (value is num) {
      if (!value.isFinite) {
        throw ArgumentError.value(
          value,
          'configuration',
          'numeric values must be finite',
        );
      }
      if (forDigest &&
          value is double &&
          value == value.truncateToDouble() &&
          value.abs() < 1e21) {
        return value.toInt();
      }
      return value;
    }
    if (value == null || value is String || value is bool) {
      return value;
    }
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw ArgumentError.value(
          value,
          'configuration',
          'JSON object keys must be strings',
        );
      }
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, dynamic>{
        for (final key in keys)
          key: _canonicalize(value[key], forDigest: forDigest),
      };
    }
    if (value is List) {
      return value
          .map((item) => _canonicalize(item, forDigest: forDigest))
          .toList(growable: false);
    }
    throw ArgumentError.value(
      value,
      'configuration',
      'must contain only JSON-compatible values',
    );
  }

  static Object? _deepFreeze(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: _deepFreeze(entry.value),
      });
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_deepFreeze));
    }
    return value;
  }

  static Map<String, dynamic> _ruleLogicIdentity(Map<String, dynamic> rule) {
    final canonical = _canonicalize(rule) as Map<String, dynamic>;
    final then = canonical['then'];
    if (then is Map<String, dynamic>) {
      // Localized prose can change independently without changing the rule's
      // decision thresholds, actions, severity, or ordering identity.
      then.remove('messages');
    }
    return canonical;
  }

  static void _validateImplementationSourceDigests(
    Map<String, String> digests,
  ) {
    if (digests.isEmpty) {
      throw ArgumentError('Implementation-source digest map cannot be empty.');
    }
    final shaPattern = RegExp(r'^[a-f0-9]{64}$');
    final pathPattern = RegExp(r'^lib/[A-Za-z0-9_./-]+\.dart$');
    for (final entry in digests.entries) {
      if (!pathPattern.hasMatch(entry.key) ||
          !shaPattern.hasMatch(entry.value)) {
        throw ArgumentError.value(
          entry,
          'implementationSourceDigests',
          'requires a safe lib/*.dart path and lowercase SHA-256',
        );
      }
    }
  }
}
