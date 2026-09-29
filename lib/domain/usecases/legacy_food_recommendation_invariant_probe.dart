import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../entities/food_recommendation.dart';
import 'get_food_recommendations_usecase.dart';

/// Black-box observations from the production legacy recommendation scorer.
///
/// Expected values deliberately live in the independent verification gate,
/// not here. This probe only executes manufactured inputs through the real
/// scorer and records primitive outputs. It performs no I/O or network work.
final class LegacyFoodRecommendationInvariantProbe {
  static const int probeVersion = 1;
  static const String probeId =
      'legacy-food-recommendations.black-box-production/1';

  LegacyFoodRecommendationInvariantProbe._({
    required Map<String, Object?> observations,
  }) : observations = Map<String, Object?>.unmodifiable(observations);

  factory LegacyFoodRecommendationInvariantProbe.capture({
    GetFoodRecommendationsUseCase? recommender,
  }) {
    final scorer = recommender ?? GetFoodRecommendationsUseCase();
    final profile = UserProfile.defaults();
    var invocationCount = 0;

    List<FoodRecommendation> run({
      required List<Meal> history,
      required List<DrugDefinition> drugs,
      required List<FoodItem> foods,
      UserProfile? userProfile,
    }) {
      invocationCount++;
      return scorer.call(
        history: history,
        drugs: drugs,
        allFoods: foods,
        userProfile: userProfile ?? profile,
      );
    }

    FoodItem food({
      required String id,
      required double protein,
      FoodCategory category = FoodCategory.protein,
      double fiber = 0,
      String jurisdiction = 'US',
    }) => FoodItem(
      id: id,
      name: 'Synthetic $id',
      category: category,
      sourceSystem: 'FDC',
      sourceFoodCode: 'synthetic:$id',
      jurisdiction: jurisdiction,
      proteinG: protein,
      carbsG: 10,
      fatG: 1,
      fiberG: fiber,
      sodiumMg: 1,
    );

    final baseline = run(
      history: const <Meal>[],
      drugs: const <DrugDefinition>[],
      foods: <FoodItem>[
        food(
          id: 'baseline',
          protein: 1,
          category: FoodCategory.fruit,
          fiber: 2,
        ),
      ],
    ).single;

    final levodopa = DrugDefinition(
      id: 'synthetic-levodopa',
      genericName: 'synthetic levodopa',
      brandNames: const <String>[],
      tags: const <DrugTag>[DrugTag.levodopaLike],
      notes: 'Manufactured invariant fixture only.',
    );
    final thresholdProteins = <double>[14.999, 15, 19.999, 20, 24.999, 25];
    final thresholdRecommendations = <String, FoodRecommendation>{};
    for (final protein in thresholdProteins) {
      final key = protein.toString().replaceAll('.', '_');
      thresholdRecommendations[key] = run(
        history: const <Meal>[],
        drugs: <DrugDefinition>[levodopa],
        foods: <FoodItem>[food(id: 'protein_$key', protein: protein)],
      ).single;
    }

    final boundedCandidate = food(
      id: 'bounded_candidate',
      protein: 1,
      category: FoodCategory.vegetable,
      fiber: 4,
      jurisdiction: 'JP',
    );
    final boundedHistory = Meal(
      id: 'bounded_history',
      eatenAt: DateTime.utc(2026, 9, 1, 8),
      timeSource: 'explicit_user_entry',
      nextMealWindowStart: DateTime.utc(2026, 9, 1, 10),
      nextMealWindowEnd: DateTime.utc(2026, 9, 1, 11),
      title: 'Manufactured high-protein history',
      items: <MealItem>[
        MealItem(
          foodId: boundedCandidate.id,
          foodName: boundedCandidate.name,
          foodCategory: boundedCandidate.category,
          quantityFactor: 1,
          foodTags: const <String>[],
          proteinPer100g: boundedCandidate.proteinG,
          carbsPer100g: boundedCandidate.carbsG,
          fatPer100g: boundedCandidate.fatG,
          fiberPer100g: boundedCandidate.fiberG,
          sodiumPer100g: boundedCandidate.sodiumMg,
        ),
        MealItem(
          foodId: 'history_protein',
          foodName: 'Synthetic history protein',
          foodCategory: FoodCategory.protein,
          quantityFactor: 1,
          foodTags: const <String>[],
          proteinPer100g: 30,
          carbsPer100g: 0,
          fatPer100g: 0,
          fiberPer100g: 0,
          sodiumPer100g: 0,
        ),
      ],
    );
    final bounded = run(
      history: <Meal>[boundedHistory],
      drugs: const <DrugDefinition>[],
      foods: <FoodItem>[boundedCandidate],
      userProfile: profile.copyWith(
        registrationRegion: 'JP',
        dietProfileRegion: 'JP',
      ),
    ).single;

    final rankingFoods = <FoodItem>[
      food(
        id: 'rank_fruit',
        protein: 1,
        category: FoodCategory.fruit,
        fiber: 4,
      ),
      food(
        id: 'rank_vegetable',
        protein: 3,
        category: FoodCategory.vegetable,
        fiber: 3,
      ),
      food(
        id: 'rank_carbs',
        protein: 6,
        category: FoodCategory.carbs,
        fiber: 2,
      ),
      food(id: 'rank_protein_1', protein: 12),
      food(id: 'rank_protein_2', protein: 18),
      food(id: 'rank_protein_3', protein: 26),
    ];
    final ranked = run(
      history: const <Meal>[],
      drugs: <DrugDefinition>[levodopa],
      foods: rankingFoods,
    );
    final permuted = run(
      history: const <Meal>[],
      drugs: <DrugDefinition>[levodopa],
      foods: rankingFoods.reversed.toList(growable: false),
    );
    final rankedIds = ranked
        .map((entry) => entry.food.id)
        .toList(growable: false);
    final permutedIds = permuted
        .map((entry) => entry.food.id)
        .toList(growable: false);
    var descending = true;
    for (var index = 1; index < ranked.length; index++) {
      if (ranked[index - 1].score < ranked[index].score) {
        descending = false;
      }
    }
    final allObservedScores = <double>[
      baseline.score,
      for (final recommendation in thresholdRecommendations.values)
        recommendation.score,
      bounded.score,
      for (final recommendation in ranked) recommendation.score,
      for (final recommendation in permuted) recommendation.score,
    ];

    return LegacyFoodRecommendationInvariantProbe._(
      observations: <String, Object?>{
        'probe.version': probeVersion,
        'probe.invocation_count': invocationCount,
        'baseline.score': baseline.score,
        'baseline.unbounded_score':
            baseline.scoreBreakdown['unbounded_score_points'],
        'baseline.bound_applied':
            baseline.scoreBreakdown['score_bound_applied'] == 1,
        'baseline.decision': baseline.decision,
        for (final entry
            in thresholdRecommendations.entries) ...<String, Object?>{
          'threshold.${entry.key}.score': entry.value.score,
          'threshold.${entry.key}.safety':
              entry.value.scoreBreakdown['safety_score'],
          'threshold.${entry.key}.schedule':
              entry.value.scoreBreakdown['medication_schedule_fit'],
          'threshold.${entry.key}.timing_sensitivity':
              entry.value.scoreBreakdown['drug_timing_sensitivity'],
          'threshold.${entry.key}.decision': entry.value.decision,
        },
        'bounds.unbounded_score':
            bounded.scoreBreakdown['unbounded_score_points'],
        'bounds.score': bounded.score,
        'bounds.bound_applied':
            bounded.scoreBreakdown['score_bound_applied'] == 1,
        'ranking.count': ranked.length,
        'ranking.ids': rankedIds,
        'ranking.descending': descending,
        'ranking.permutation_invariant':
            rankedIds.join('|') == permutedIds.join('|'),
        'ranking.unique': rankedIds.toSet().length == rankedIds.length,
        'scores.finite_and_bounded': allObservedScores.every(
          (score) =>
              score.isFinite &&
              score >= scorer.parameters.minimumScore &&
              score <= scorer.parameters.maximumScore,
        ),
      },
    );
  }

  final Map<String, Object?> observations;

  LegacyFoodRecommendationInvariantProbe withObservation(
    String key,
    Object? value,
  ) => LegacyFoodRecommendationInvariantProbe._(
    observations: <String, Object?>{...observations, key: value},
  );

  LegacyFoodRecommendationInvariantProbe withoutObservation(String key) =>
      LegacyFoodRecommendationInvariantProbe._(
        observations: <String, Object?>{...observations}..remove(key),
      );
}
