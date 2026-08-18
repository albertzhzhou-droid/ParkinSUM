library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'algorithm_parameter_provenance.dart';
import '../core/analysis/nutrition_rules.dart';
import '../core/constants/baseline_cdss_rules.dart';
import '../domain/entities/gastric_emptying_parameters.dart';
import '../domain/entities/protein_source.dart';
import '../domain/usecases/amino_acid_competition_model.dart';
import '../domain/usecases/levodopa_absorption_opportunity_model.dart';
import '../domain/usecases/mechanistic_next_meal_scorer.dart';
import '../domain/usecases/next_meal_scoring_parameters.dart';
import '../domain/usecases/protein_distribution_model.dart';
import '../domain/usecases/algorithm_registry.dart';

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
  static const String schema = 'parkinsum.algorithm-configuration/2';
  static const String defaultId = 'parkinsum-default-algorithm-stack';
  static const String defaultVersion = '2026.08.17-v2';

  /// SHA-256 over `path:file_sha256\n` for every source path owned by the
  /// algorithm registry, sorted lexicographically. The identity source itself
  /// is the sole exclusion to avoid a recursive self-hash; its emitted manifest
  /// and configuration are already the payload being hashed. This closes the
  /// gap between individually modeled parameters and remaining inline logic.
  static const String registeredAlgorithmSourceBundleSha256 =
      '45748605d58de42010614aeabf2f536853dfaca9fd44aa05617668eb90a0b9fa';

  /// Exact production files that currently contain result-affecting constants
  /// or formula branches which are not all represented by injectable objects.
  /// Values are verified mechanically in `parkinsum_algorithm_sdk_test.dart`.
  static const Map<String, String> defaultImplementationSourceDigests = {
    'lib/domain/entities/gastric_emptying_parameters.dart':
        'ba500963bd5596d66b99d7072425c597b0ef24e59bfe4e8b97ef814b7bf7207b',
    'lib/domain/entities/gastric_emptying_profile.dart':
        '20c1249462f4fb4b6b91880599fb0ef93468f9949c6778c8aa4d52dfef851505',
    'lib/domain/usecases/gastric_emptying_model.dart':
        '66df72fb38c40502fc278dc93a4574068a5594d35257f3aa3599d142ac8b6297',
    'lib/domain/usecases/meal_composition_normalizer.dart':
        'c9e902d8c5f37b37ad73be5d598319730d1b7d6afb5eafb63f4ba787598c9c7f',
    'lib/domain/entities/absorption_opportunity.dart':
        '0fcaa8031f4eb206bdec1f99f31d1ccd62a6bcabd1f60a827f560ea0f46b6450',
    'lib/domain/usecases/levodopa_absorption_opportunity_model.dart':
        'acb42bc575422bbbaa99c035e0751caf09a1d3319a3276138222d16d4f69c8b8',
    'lib/domain/entities/amino_acid_competition.dart':
        'db04c321607e84dda10511e40158b575e7788408f3ff0ac5a3257fe4ac47f1b9',
    'lib/domain/entities/amino_acid_profile.dart':
        '19339d51bbadc135c16c5aa383a3a7b37e2f4201bb49b9f3577ec22c268f9cad',
    'lib/domain/entities/nutrient_derivation.dart':
        '013684f5865c2d957a0ce27fed47b93e8f0ca27852be2b6a6330d0f377fabd99',
    'lib/domain/entities/protein_source.dart':
        'd04048adf3a7d4d44f4de9d4293b59b8aa28ac627fa24fd6b524894167c14d86',
    'lib/domain/usecases/amino_acid_competition_model.dart':
        'afd75e0cbffc2ef56d5673ea6823db632553e41eec45bd500c6d99746e495d5b',
    'lib/domain/usecases/mechanistic_conflict_engine.dart':
        '63e41e3932f641942fae0e842dc7036109b8d6e68789bdcd1e061f7d442a8d0b',
    'lib/domain/usecases/protein_distribution_model.dart':
        '9ab6035545b0dc2d6d462112a7c2d42f900bb24a9b6ecd7b9a42b7fbcfa2f881',
    'lib/domain/usecases/next_meal_scoring_parameters.dart':
        '6d02d9c819e99bc1ba075c4aa331eb1c5c0dfe51746ba868e2ca1a5647881b77',
    'lib/domain/usecases/mechanistic_next_meal_scorer.dart':
        '7781f657974d9b9063f3884c272f305afd0f450f1262ce04c4c3a3c62063e0f9',
    'lib/domain/entities/rule_registry_models.dart':
        'dbecb0bbef2dd2e6baa64262b07df6fef3be07b2d6765e2898560ff432769b5b',
    'lib/domain/usecases/runtime_rule_engine.dart':
        'ca01e345e525cb8f6a83172d1b1b2d4855baaddbdded73bca10596156086ebcc',
    'lib/domain/usecases/runtime_rule_support.dart':
        '3cc1a9f8e4902f901698d847a99ae3dc98d15eb2bb4f6e94215dac5e21b43ad3',
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
  final Map<String, dynamic> canonicalConfiguration;

  AlgorithmConfigurationIdentity._({
    required this.id,
    required this.version,
    required this.parameterProvenanceManifest,
    required Map<String, dynamic> configuration,
  }) : canonicalConfiguration =
           _deepFreeze(_canonicalize(configuration)) as Map<String, dynamic>;

  factory AlgorithmConfigurationIdentity.defaults({
    GastricEmptyingParameterSet? gastricParameters,
    NextMealScoringParameterSet? scoringParameters,
    List<Map<String, dynamic>>? runtimeRules,
  }) {
    _validateImplementationSourceDigests(defaultImplementationSourceDigests);
    final gastric =
        gastricParameters ??
        GastricEmptyingParameterSet.literatureInformedDefault();
    final scoring =
        scoringParameters ??
        NextMealScoringParameterSet.literatureInformedDefault();
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
          scoringParameters: scoring,
          lnaaFactors: lnaaFactors,
          runtimeRuleLogic: rules,
          algorithmDescriptors: AlgorithmRegistry.all,
        );
    validateRegisteredParameterSources(parameterProvenanceManifest);

    return AlgorithmConfigurationIdentity._(
      id: defaultId,
      version: defaultVersion,
      parameterProvenanceManifest: parameterProvenanceManifest,
      configuration: {
        'gastric_emptying': gastric.toJson(),
        'levodopa_absorption_opportunity': {
          'reference_ir_lag_minutes':
              LevodopaAbsorptionOpportunityModel.referenceIrLagMinutes,
          'reference_ir_duration_minutes':
              LevodopaAbsorptionOpportunityModel.referenceIrDurationMinutes,
          'illustrative_meal_delay_minutes':
              LevodopaAbsorptionOpportunityModel.illustrativeMealDelayMinutes,
          'openness_sample_stride_minutes':
              LevodopaAbsorptionOpportunityModel.opennessSampleStrideMinutes,
          'ir_peak_openness': LevodopaAbsorptionOpportunityModel.irPeakOpenness,
          'ir_tail_openness': LevodopaAbsorptionOpportunityModel.irTailOpenness,
        },
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
  static String digestConfiguration(Object? configuration) => sha256
      .convert(utf8.encode(jsonEncode(_canonicalize(configuration))))
      .toString();

  static Object? _canonicalize(Object? value) {
    if (value is num) {
      if (!value.isFinite) {
        throw ArgumentError.value(
          value,
          'configuration',
          'numeric values must be finite',
        );
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
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
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
