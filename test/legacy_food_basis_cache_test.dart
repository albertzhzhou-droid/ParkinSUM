import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';

// Old cache shapes are independent of the current importer. Source identifiers,
// names and quantities are cropped from the original USDA records used in the
// pre-change counterexamples. This is synthetic cache data, not a user cache.
Map<String, dynamic> cache({
  String family = 'Branded',
  String code = '2385707',
  String name = 'WHOLE MILK',
  Map<String, Object?>? evidence,
}) => {
  'id': 'legacy_$code',
  'name': name,
  'category': 'other',
  'sourceSystem': family,
  'sourceFoodCode': code,
  'basisType': 'per_100g_edible_part',
  'proteinG': family == 'Foundation' ? 25.5 : 3.33,
  'missingNutrientFields': <String>[],
  'sourceBasisEvidence': ?evidence,
};

void expectUnavailable(FoodItem item) {
  expect(item.supportsEdibleMassPoint, isFalse);
  expect(
    item.missingNutrientFields,
    containsAll([
      'proteinG',
      'carbsG',
      'fatG',
      'fiberG',
      'sodiumMg',
      'energyKcal',
      'waterG',
    ]),
  );
  expect(foodItemToCandidateFood(item).components.single.proteinGrams, isNull);
}

void main() {
  test('old Foundation moisture label overrides a false edible-mass cache', () {
    for (final basis in ['0', '0.0', '12.5']) {
      final item = FoodItem.fromJson(
        cache(
          family: 'Foundation',
          code: '747430',
          name:
              'Beans, dry, pinto (includes foods for USDA\'s Food Distribution Program) ($basis% moisture)',
        ),
      );
      expect(item.proteinG, 25.5);
      expectUnavailable(item);
      expectUnavailable(FoodItem.fromJson(item.toJson()));
    }
  });

  test(
    'Branded cache without original source units never authorizes grams',
    () {
      final item = FoodItem.fromJson(cache());
      expect(item.proteinG, 3.33);
      expectUnavailable(item);
      expectUnavailable(FoodItem.fromJson(item.toJson()));
    },
  );

  test(
    'source-bound grams survive serialization without quantity conversion',
    () {
      final json = cache(
        evidence: {
          'fdcId': 2385707,
          'dataType': 'Branded',
          'servingSizeUnit': 'g',
        },
      );
      final item = FoodItem.fromJson(json);
      expect(item.supportsEdibleMassPoint, isTrue);
      expect(
        foodItemToCandidateFood(item).components.single.proteinGrams,
        3.33,
      );
      expect(FoodItem.fromJson(item.toJson()).supportsEdibleMassPoint, isTrue);
    },
  );

  test('volume, unknown, mismatched IDs and source families stay withheld', () {
    for (final evidence in <Map<String, Object?>>[
      {'fdcId': 2385707, 'dataType': 'Branded', 'servingSizeUnit': 'ml'},
      {'fdcId': 2385707, 'dataType': 'Branded', 'servingSizeUnit': 'MLT'},
      {'fdcId': 2385707, 'dataType': 'Branded'},
      {'fdcId': 1, 'dataType': 'Branded', 'servingSizeUnit': 'g'},
      {'fdcId': 2385707, 'dataType': 'Foundation', 'servingSizeUnit': 'g'},
    ]) {
      expectUnavailable(FoodItem.fromJson(cache(evidence: evidence)));
    }
    expectUnavailable(
      FoodItem.fromJson(
        cache(
          family: 'Foundation',
          evidence: {
            'fdcId': 2385707,
            'dataType': 'Branded',
            'servingSizeUnit': 'g',
          },
        ),
      ),
    );
  });

  test(
    'basis evidence is deeply frozen and old ordinary JSON stays additive',
    () {
      final fields = <String, Object?>{
        'fdcId': 2385707,
        'dataType': 'Branded',
        'servingSizeUnit': 'g',
        'labelNutrients': {
          'protein': {'value': 7.99},
        },
        'nested': [1],
      };
      final item = FoodItem.fromJson(cache(evidence: fields));
      fields['servingSizeUnit'] = 'ml';
      ((fields['labelNutrients'] as Map)['protein'] as Map)['value'] = 99.0;
      (fields['nested'] as List).add(2);
      expect(item.supportsEdibleMassPoint, isTrue);
      expect(
        ((item.sourceBasisEvidence!['labelNutrients'] as Map)['protein']
            as Map)['value'],
        7.99,
      );
      expect(item.sourceBasisEvidence!['nested'], [1]);
      expect(
        () => item.sourceBasisEvidence!['servingSizeUnit'] = 'ml',
        throwsUnsupportedError,
      );
      final ordinary = FoodItem.fromJson(
        cache(family: 'Foundation', name: 'Dry beans, raw'),
      );
      expect(ordinary.supportsEdibleMassPoint, isTrue);
      expect(ordinary.toJson().containsKey('sourceBasisEvidence'), isFalse);
    },
  );
}
