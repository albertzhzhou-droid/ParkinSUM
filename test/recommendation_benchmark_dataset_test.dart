import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/recommendation_benchmark_models.dart';

void main() {
  test('default recommendation benchmark dataset covers key safety scenarios',
      () {
    const dataset = defaultRecommendationBenchmarkDataset;

    expect(dataset.version, isNotEmpty);
    expect(dataset.cases, isNotEmpty);
    expect(
      dataset.cases.any(
        (item) => item.focusTags.contains('levodopa'),
      ),
      isTrue,
    );
    expect(
      dataset.cases.any(
        (item) => item.focusTags.contains('china_common_foods'),
      ),
      isTrue,
    );
    expect(
      dataset.cases.any(
        (item) => item.focusTags.contains('missing_data'),
      ),
      isTrue,
    );
  });

  test('benchmark food ids stay grounded in current real catalog ids', () {
    final allFoodIds = defaultRecommendationBenchmarkDataset.cases
        .expand((item) => item.candidateFoodIds)
        .toSet();

    expect(allFoodIds.contains('food_banana'), isTrue);
    expect(allFoodIds.contains('food_tofu'), isTrue);
    expect(allFoodIds.contains('food_apple'), isTrue);
  });
}
