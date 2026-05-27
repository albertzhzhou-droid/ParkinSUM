import '../../core/models/food_item.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_source.dart';
import '../entities/time_axis_events.dart';
import 'mechanistic_next_meal_scorer.dart';

/// Pure adapter from a runtime `FoodItem` (seed catalog OR DB-projected) to
/// a `CandidateFood` that the mechanistic next-meal scorer consumes.
///
/// Preserves provenance (`sourceSystem` → `regionalFoodLibraryRef`),
/// physical form (from `textureClass`), and the nutrient fields the local
/// catalog actually populates. Inferred `ProteinSourceType` widens
/// uncertainty when unknown rather than guessing.
CandidateFood foodItemToCandidateFood(FoodItem item) {
  final physicalForm = _textureToPhysicalForm(item.textureClass);
  final proteinSource = inferProteinSourceFromNameAndCategory(
    name: item.name,
    category: item.category.name,
  );

  return CandidateFood(
    id: item.id,
    name: item.name,
    regionalFoodLibraryRef: item.sourceSystem,
    declaredPhysicalForm: physicalForm,
    components: [
      FoodComponent(
        id: item.id,
        name: item.name,
        physicalForm: physicalForm,
        proteinGrams: item.proteinG,
        fatGrams: item.fatG,
        fiberGrams: item.fiberG,
        carbohydrateGrams: item.carbsG,
        // Local catalog does not capture per-serving calories or portion
        // grams today; leave null so the normalizer records them as
        // missing fields rather than inventing values.
        calories: null,
        portionGrams: null,
        sourceDocId: item.sourceSystem,
        proteinSource: proteinSource,
      ),
    ],
  );
}

MealPhysicalForm _textureToPhysicalForm(String? textureClass) {
  switch ((textureClass ?? '').toLowerCase()) {
    case 'liquid':
      return MealPhysicalForm.liquid;
    case 'soft':
    case 'solid':
      return MealPhysicalForm.solid;
    default:
      return MealPhysicalForm.unknown;
  }
}
