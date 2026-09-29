import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/legacy_food_recommendation_invariant_probe.dart';

void main() {
  test('black-box probe executes the production scorer for every vector', () {
    final scorer = _CountingRecommendationScorer();

    final probe = LegacyFoodRecommendationInvariantProbe.capture(
      recommender: scorer,
    );

    expect(scorer.invocationCount, 10);
    expect(probe.observations['probe.invocation_count'], 10);
    expect(probe.observations['baseline.score'], closeTo(95.25, 1e-12));
    expect(probe.observations['threshold.14_999.score'], closeTo(87.55, 1e-12));
    expect(probe.observations['threshold.15_0.score'], closeTo(74.15, 1e-12));
    expect(probe.observations['threshold.20_0.score'], closeTo(68.15, 1e-12));
    expect(probe.observations['threshold.25_0.score'], closeTo(58.15, 1e-12));
    expect(
      probe.observations['bounds.unbounded_score'],
      closeTo(101.09, 1e-12),
    );
    expect(probe.observations['bounds.score'], 100.0);
    expect(probe.observations['bounds.bound_applied'], isTrue);
    expect(probe.observations['ranking.count'], 5);
    expect(probe.observations['ranking.descending'], isTrue);
    expect(probe.observations['ranking.permutation_invariant'], isTrue);
    expect(probe.observations['scores.finite_and_bounded'], isTrue);
  });

  test('observation mutations do not execute or replace production code', () {
    final baseline = LegacyFoodRecommendationInvariantProbe.capture();

    final mutated = baseline.withObservation('bounds.score', 101.09);
    final missing = baseline.withoutObservation('ranking.descending');

    expect(baseline.observations['bounds.score'], 100.0);
    expect(mutated.observations['bounds.score'], 101.09);
    expect(missing.observations, isNot(contains('ranking.descending')));
    expect(
      LegacyFoodRecommendationInvariantProbe.probeId,
      'legacy-food-recommendations.black-box-production/1',
    );
  });
}

final class _CountingRecommendationScorer
    extends GetFoodRecommendationsUseCase {
  int invocationCount = 0;

  @override
  List<FoodRecommendation> call({
    required List<Meal> history,
    required List<DrugDefinition> drugs,
    required List<FoodItem> allFoods,
    required UserProfile userProfile,
  }) {
    invocationCount++;
    return super.call(
      history: history,
      drugs: drugs,
      allFoods: allFoods,
      userProfile: userProfile,
    );
  }
}
