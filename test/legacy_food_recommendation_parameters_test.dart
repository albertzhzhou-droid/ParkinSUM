import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/legacy_food_recommendation_parameters.dart';

void main() {
  test('default legacy parameter contract is complete and deterministic', () {
    final parameters = LegacyFoodRecommendationParameterSet.prototypeDefault();

    expect(parameters.validationErrors, isEmpty);
    expect(parameters.parameters, hasLength(33));
    expect(parameters.allParameterIds, hasLength(34));
    expect(
      parameters.parameters.map((parameter) => parameter.id),
      orderedEquals(
        parameters.parameters.map((parameter) => parameter.id).toList()..sort(),
      ),
    );
    expect(
      parameters.parameters.map((parameter) => parameter.id).toSet(),
      LegacyFoodRecommendationParameterIds.numeric,
    );
    expect(
      parameters.tieBreakPolicy,
      LegacyFoodRecommendationParameterSet.scoreDescendingFoodIdAscending,
    );
    expect(parameters.maximumCandidateCount, 5);
    expect(parameters.minimumScore, 0);
    expect(parameters.maximumScore, 100);
    expect(
      parameters.toJson(),
      LegacyFoodRecommendationParameterSet.prototypeDefault().toJson(),
    );
    expect(
      () => parameters.parameters.add(parameters.parameters.first),
      throwsUnsupportedError,
    );
  });

  test('malformed values and policy fail before scorer execution', () {
    final defaults = LegacyFoodRecommendationParameterSet.prototypeDefault();
    final malformed = <LegacyFoodRecommendationParameterSet>[
      defaults.withValue(
        LegacyFoodRecommendationParameterIds.safetyWeight,
        double.nan,
      ),
      defaults.withValue(LegacyFoodRecommendationParameterIds.safetyWeight, 2),
      defaults.withValue(LegacyFoodRecommendationParameterIds.maximumScore, -1),
      defaults.withValue(
        LegacyFoodRecommendationParameterIds.safetyCautionProteinG,
        25,
      ),
      defaults.withValue(
        LegacyFoodRecommendationParameterIds.maximumCandidates,
        2.5,
      ),
      defaults.withTieBreakPolicy('unregistered_policy'),
    ];

    for (final parameters in malformed) {
      expect(parameters.validationErrors, isNotEmpty);
      expect(
        () => GetFoodRecommendationsUseCase(parameters: parameters),
        throwsArgumentError,
      );
      expect(
        () => AlgorithmConfigurationIdentity.defaults(
          legacyFoodRecommendationParameters: parameters,
        ),
        throwsArgumentError,
      );
    }
  });

  test('a valid weight mutation changes production output and identity', () {
    final defaults = LegacyFoodRecommendationParameterSet.prototypeDefault();
    final changed = defaults.withValue(
      LegacyFoodRecommendationParameterIds.safetyWeight,
      0.30,
    );
    expect(changed.validationErrors, isEmpty);

    final defaultResult = _score(defaults);
    final changedResult = _score(changed);
    expect(defaultResult, closeTo(95.25, 1e-12));
    expect(changedResult, closeTo(85.75, 1e-12));
    expect(changedResult, isNot(defaultResult));

    final defaultIdentity = AlgorithmConfigurationIdentity.defaults(
      legacyFoodRecommendationParameters: defaults,
    );
    final changedIdentity = AlgorithmConfigurationIdentity.defaults(
      legacyFoodRecommendationParameters: changed,
    );
    expect(changedIdentity.sha256Digest, isNot(defaultIdentity.sha256Digest));
    final changedRecord = changedIdentity.parameterProvenanceManifest.records
        .singleWhere(
          (record) =>
              record.parameterId ==
              LegacyFoodRecommendationParameterIds.safetyWeight,
        );
    expect(changedRecord.canonicalValue, 0.30);
    expect(changedRecord.algorithmIds, ['legacy_food_recommendations']);
  });

  test(
    'source provenance score policy is explicit and drives score features',
    () {
      final defaults = LegacyFoodRecommendationParameterSet.prototypeDefault();
      final identity = AlgorithmConfigurationIdentity.defaults(
        legacyFoodRecommendationParameters: defaults,
      );
      final policy = identity.parameterProvenanceManifest.records.singleWhere(
        (record) =>
            record.parameterId ==
            LegacyFoodRecommendationProvenancePolicy.parameterId,
      );
      expect(policy.canonicalValue, {
        'normalization': 'uppercase_without_trimming',
        'known_source_system_scores': {
          'CIQUAL': 0.95,
          'DAILYMED': 0.95,
          'DPD': 0.95,
          'FDC': 0.95,
          'HEALTH_CANADA_DPD': 0.95,
          'LOCAL_SEED': 0.55,
          'USDA_FDC': 0.95,
        },
        'unknown_with_source_food_code': 0.85,
        'unknown_without_source_food_code': 0.6,
      });
      expect(
        defaults.toJson()['provenance_policy'],
        LegacyFoodRecommendationProvenancePolicy.toJson(
          reviewDate: defaults.lastReviewed,
        ),
      );

      for (final entry
          in LegacyFoodRecommendationProvenancePolicy
              .knownSourceSystemScores
              .entries) {
        expect(
          _recommendation(
            defaults,
            sourceSystem: entry.key.toLowerCase(),
          ).scoreBreakdown['provenance_score'],
          entry.value,
          reason: 'score must use the digest-bound ${entry.key} policy',
        );
      }
      expect(
        _recommendation(
          defaults,
          sourceSystem: 'unlisted',
          sourceFoodCode: 'x',
        ).scoreBreakdown['provenance_score'],
        0.85,
      );
      expect(
        _recommendation(
          defaults,
          sourceSystem: 'unlisted',
          sourceFoodCode: null,
        ).scoreBreakdown['provenance_score'],
        0.6,
      );
    },
  );
}

double _score(LegacyFoodRecommendationParameterSet parameters) {
  return _recommendation(parameters, sourceSystem: 'FDC').score;
}

FoodRecommendation _recommendation(
  LegacyFoodRecommendationParameterSet parameters, {
  required String sourceSystem,
  String? sourceFoodCode = 'synthetic:baseline',
}) {
  final food = FoodItem(
    id: 'synthetic_baseline',
    name: 'Synthetic baseline',
    category: FoodCategory.fruit,
    sourceSystem: sourceSystem,
    sourceFoodCode: sourceFoodCode,
    jurisdiction: 'US',
    proteinG: 1,
    carbsG: 10,
    fatG: 1,
    fiberG: 2,
    sodiumMg: 1,
  );
  return GetFoodRecommendationsUseCase(parameters: parameters)
      .call(
        history: const [],
        drugs: const [],
        allFoods: [food],
        userProfile: UserProfile.defaults(),
      )
      .single;
}
