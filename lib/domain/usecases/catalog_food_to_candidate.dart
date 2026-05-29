import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
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
  final physicalForm = textureClassToPhysicalForm(item.textureClass);
  final proteinSource = inferProteinSourceFromNameAndCategory(
    name: item.name,
    category: item.category.name,
  );

  // Missing ≠ zero: when a nutrient field has no source data (recorded in
  // `item.missingNutrientFields`), pass null to the component so the normalizer
  // records it as a missing field and lowers completeness — instead of letting
  // the FoodItem's non-nullable 0 default masquerade as a true measured 0 g.
  double? present(String field, double value) =>
      item.isNutrientMissing(field) ? null : value;

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
        proteinGrams: present('proteinG', item.proteinG),
        fatGrams: present('fatG', item.fatG),
        fiberGrams: present('fiberG', item.fiberG),
        carbohydrateGrams: present('carbsG', item.carbsG),
        // Carry energy only when the source provides it (never fabricated).
        // Portion grams are not captured by the local catalog → left null so
        // the normalizer records them as missing rather than inventing values.
        calories: item.energyKcal,
        portionGrams: null,
        sourceDocId: item.sourceSystem,
        proteinSource: proteinSource,
        // Prefer the actual amino-acid profile when present; null → the LNAA
        // layer falls back to the protein-source proxy.
        aminoAcidProfile: item.aminoAcidProfile,
      ),
    ],
  );
}

/// Map a single logged `MealItem` to a `FoodComponent` for mechanistic
/// meal-history composition. Macros + portion come from the user-logged item
/// (`quantityFactor × per-100g`); the optional [catalogMatch] enriches physical
/// form, energy (calories), protein source, and the amino-acid profile (scaled
/// to the logged serving). Nothing is fabricated: when the catalog lacks
/// energy/texture/amino-acid data those stay null/unknown, and the LNAA layer
/// falls back to the protein-source proxy.
FoodComponent mealItemToFoodComponent(
  MealItem item, {
  required String componentId,
  FoodItem? catalogMatch,
}) {
  final portionGrams = item.grams; // quantityFactor * 100 (user-entered)

  final physicalForm = catalogMatch == null
      ? MealPhysicalForm.unknown
      : textureClassToPhysicalForm(catalogMatch.textureClass);

  // Energy only when the catalog provides per-100g energy; scale to serving.
  final calories = (catalogMatch?.energyKcal != null)
      ? catalogMatch!.energyKcal! * (portionGrams / 100.0)
      : null;

  // Actual amino-acid profile (per_100g) scaled to the logged serving so
  // absolute competing LNAA grams reflect what was eaten. Null → proxy.
  final aminoAcidProfile =
      catalogMatch?.aminoAcidProfile?.scaledToGrams(portionGrams);

  final proteinSource = inferProteinSourceFromNameAndCategory(
    name: item.foodName,
    category: item.foodCategory.name,
  );

  return FoodComponent(
    id: componentId,
    name: item.foodName,
    physicalForm: physicalForm,
    proteinGrams: item.proteinG,
    fatGrams: item.fatG,
    fiberGrams: item.fiberG,
    carbohydrateGrams: item.carbsG,
    calories: calories,
    portionGrams: portionGrams,
    sourceDocId: catalogMatch?.sourceSystem ?? 'meal_history',
    proteinSource: proteinSource,
    aminoAcidProfile: aminoAcidProfile,
  );
}

/// Map a catalog `textureClass` string to a `MealPhysicalForm`. Public so the
/// meal-history componentizer can reuse the same mapping. Unknown/absent
/// texture → `unknown` (never guessed).
MealPhysicalForm textureClassToPhysicalForm(String? textureClass) {
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
