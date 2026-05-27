import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';

void main() {
  test('seed catalog FoodItem → CandidateFood preserves sourceSystem', () {
    final item = FoodItem(
      id: 'food_oats',
      name: 'oats',
      category: FoodCategory.carbs,
      aliases: const [],
      description: '',
      sourceSystem: 'CIQUAL',
      sourceFoodCode: 'X',
      jurisdiction: 'FR',
      textureClass: 'solid',
      iddsiLevel: null,
      proteinG: 13,
      carbsG: 67,
      fatG: 7,
      fiberG: 10,
      sodiumMg: 2,
    );
    final c = foodItemToCandidateFood(item);
    expect(c.id, 'food_oats');
    expect(c.regionalFoodLibraryRef, 'CIQUAL');
    expect(c.declaredPhysicalForm, MealPhysicalForm.solid);
    expect(c.components.single.proteinSource, ProteinSourceType.grain);
  });

  test('unknown texture class maps to unknown physical form', () {
    final item = FoodItem(
      id: 'food_mystery',
      name: 'unidentified',
      category: FoodCategory.other,
      aliases: const [],
      description: '',
      sourceSystem: 'LOCAL_SEED',
      sourceFoodCode: null,
      jurisdiction: 'GLOBAL',
      textureClass: null,
      iddsiLevel: null,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
    );
    final c = foodItemToCandidateFood(item);
    expect(c.declaredPhysicalForm, MealPhysicalForm.unknown);
    expect(c.components.single.proteinSource, ProteinSourceType.unknown);
  });

  test('tofu maps to soy via name inference', () {
    final item = FoodItem(
      id: 'food_tofu',
      name: 'silken tofu',
      category: FoodCategory.protein,
      aliases: const [],
      description: '',
      sourceSystem: 'CIQUAL',
      sourceFoodCode: null,
      jurisdiction: 'FR',
      textureClass: 'soft',
      iddsiLevel: 5,
      proteinG: 8,
      carbsG: 2,
      fatG: 4,
      fiberG: 1,
      sodiumMg: 6,
    );
    final c = foodItemToCandidateFood(item);
    expect(c.components.single.proteinSource, ProteinSourceType.soy);
  });

  test('beef maps to meat via name inference', () {
    final item = FoodItem(
      id: 'food_beef',
      name: 'beef steak',
      category: FoodCategory.protein,
      aliases: const [],
      description: '',
      sourceSystem: 'CIQUAL',
      sourceFoodCode: null,
      jurisdiction: 'FR',
      textureClass: 'solid',
      iddsiLevel: null,
      proteinG: 26,
      carbsG: 0,
      fatG: 15,
      fiberG: 0,
      sodiumMg: 70,
    );
    final c = foodItemToCandidateFood(item);
    expect(c.components.single.proteinSource, ProteinSourceType.meat);
  });
}
