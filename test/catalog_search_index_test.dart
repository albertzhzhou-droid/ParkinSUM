import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/catalog_engine.dart';
import 'package:parkinsum_companion/core/analysis/catalog_search_index.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/interaction_engine.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/analysis/nutrition_classifier.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';

void main() {
  test('index supports substring, accent folding, and stable source order', () {
    final index = CatalogSearchIndex<String>(
      items: const ['first', 'second', 'third'],
      searchableText: (item) => switch (item) {
        'first' => 'Café au lait',
        'second' => 'Decaf cafe',
        _ => 'Green tea',
      },
    );

    expect(index.search('CAFE'), ['first', 'second']);
    expect(index.search('fé au'), ['first']);
    expect(index.search('een t'), ['third']);
  });

  test(
    'catalog engine rebuilds the index only when repository revision changes',
    () {
      final foods = FoodRepository.createDefault();
      final medications = MedicationRepository.createDefault();
      final engine = CatalogEngine(
        foodRepo: foods,
        medRepo: medications,
        interactionEngine: InteractionEngine(),
        nutritionClassifier: NutritionClassifier(),
      );
      final initialRevision = foods.revision;
      expect(engine.searchFoods('new indexed food'), isEmpty);

      foods.replaceAll([
        FoodItem(
          id: 'food_new_indexed',
          name: 'New Indexed Food',
          category: FoodCategory.other,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 0,
        ),
      ]);

      expect(foods.revision, initialRevision + 1);
      expect(engine.searchFoods('indexed').single.id, 'food_new_indexed');
    },
  );
}
