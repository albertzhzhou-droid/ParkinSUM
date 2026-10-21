import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../entities/food_serving_reference.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_source.dart';
import '../entities/time_axis_events.dart';
import 'food_composition_interdependency_model.dart' show referenceRowsByFdcId;
import 'food_serving_reference_resolver.dart';
import 'mechanistic_next_meal_scorer.dart';

/// Protein source of a catalog food. A FoodData Central record that is in
/// the curated reference subset takes its curated group (the grouping the
/// LNAA calibration uses); any other food is inferred from its name, then
/// its aliases (which carry the English name of a Chinese-named entry), then
/// its category.
ProteinSourceType proteinSourceForFoodItem(FoodItem item) {
  final fdcId = item.sourceSystem.startsWith('USDA_FDC')
      ? int.tryParse(item.sourceFoodCode ?? '')
      : null;
  final reference = fdcId == null ? null : referenceRowsByFdcId[fdcId];
  if (reference != null) {
    return proteinSourceForReferenceGroup(
      reference.group,
      reference.sourceDescription,
    );
  }
  return inferProteinSourceFromNameAndCategory(
    name: item.name,
    category: item.category.name,
    aliases: item.aliases,
  );
}

/// Pure adapter from a runtime `FoodItem` (seed catalog OR DB-projected) to
/// a `CandidateFood` that the mechanistic next-meal scorer consumes.
///
/// Preserves provenance (`sourceSystem` → `regionalFoodLibraryRef`),
/// physical form (from `textureClass`), and the nutrient fields the local
/// catalog actually populates. Inferred `ProteinSourceType` widens
/// uncertainty when unknown rather than guessing.
///
/// The candidate is evaluated at the food's reference serving
/// ([foodServingReferenceFor]): per-100 g values are scaled to a source
/// portion or a category reference amount, and the component carries the
/// serving grams and their basis. Without a serving the values stay per
/// 100 g, the portion stays missing and the basis says so.
CandidateFood foodItemToCandidateFood(
  FoodItem item, {
  FoodServingReference? servingReference,
}) {
  final physicalForm = textureClassToPhysicalForm(item.textureClass);
  final proteinSource = proteinSourceForFoodItem(item);
  final serving = servingReference ?? foodServingReferenceFor(item);
  final servingGrams = serving.grams;

  // Missing ≠ zero: when a nutrient field has no source data (recorded in
  // `item.missingNutrientFields`), pass null to the component so the normalizer
  // records it as a missing field and lowers completeness — instead of letting
  // the FoodItem's non-nullable 0 default masquerade as a true measured 0 g.
  // A serving scales a present, finite, non-negative per-100 g value only.
  double? present(String field, double? value) {
    if (item.isNutrientMissing(field) || value == null) return null;
    if (servingGrams == null) return value;
    if (!value.isFinite || value < 0) return null;
    final scaled = value * servingGrams / 100.0;
    return scaled.isFinite ? scaled : null;
  }

  // The amino-acid profile follows the same serving through the existing
  // per-100 g `scaledToGrams` path; a profile on any other basis has no
  // proven relationship to this serving and is withheld.
  final sourceProfile = item.supportsEdibleMassPoint
      ? item.aminoAcidProfile
      : null;
  final aminoAcidProfile = servingGrams == null
      ? sourceProfile
      : sourceProfile?.basis == 'per_100g'
      ? sourceProfile!.scaledToGrams(servingGrams)
      : null;

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
        calories: present('energyKcal', item.energyKcal),
        portionGrams: servingGrams,
        sourceDocId: item.sourceSystem,
        proteinSource: proteinSource,
        // Prefer the actual amino-acid profile when present; null → the LNAA
        // layer falls back to the protein-source proxy.
        aminoAcidProfile: aminoAcidProfile,
        portionBasis: serving.basis.wireName,
      ),
    ],
  );
}

/// Map a single logged `MealItem` to a `FoodComponent` for mechanistic
/// meal-history composition. Macros + portion come from the user-logged item
/// (`quantityFactor × per-100g`); the optional [catalogMatch] enriches physical
/// form, energy (calories), protein source (see [proteinSourceForFoodItem]),
/// and the amino-acid profile (scaled to the logged serving). Nothing is
/// fabricated: when the catalog lacks energy/texture/amino-acid data those
/// stay null/unknown, and the LNAA layer falls back to the protein-source
/// proxy.
FoodComponent mealItemToFoodComponent(
  MealItem item, {
  required String componentId,
  FoodItem? catalogMatch,
}) {
  final portionGrams = item.grams; // quantityFactor * 100 (user-entered)

  final physicalForm = catalogMatch == null
      ? MealPhysicalForm.unknown
      : textureClassToPhysicalForm(catalogMatch.textureClass);

  // Energy only when the catalog explicitly provides a finite, non-negative
  // per-100g value and the logged mass is valid. A stale numeric field cannot
  // override the source's missing marker, and overflow remains missing.
  double? scaleEnergy() {
    final match = catalogMatch;
    final source = match?.energyKcal;
    if (match == null ||
        match.isNutrientMissing('energyKcal') ||
        source == null ||
        !source.isFinite ||
        source < 0 ||
        !portionGrams.isFinite ||
        portionGrams < 0) {
      return null;
    }
    final scaled = source * (portionGrams / 100.0);
    return scaled.isFinite ? scaled : null;
  }

  final calories = scaleEnergy();

  // Actual amino-acid profile may be projected only from an explicit per-100g
  // basis because MealItem quantityFactor is itself defined against 100 g.
  // A source `per_serving` profile has no proven relationship to the user's
  // logged quantity here and must not be relabelled as this serving. Invalid
  // portions and invalid profile values also fail closed. A true zero-gram
  // serving scales present fields to true zero rather than retaining 100 g.
  final sourceAminoAcidProfile = catalogMatch?.aminoAcidProfile;
  final aminoAcidProfile =
      catalogMatch?.supportsEdibleMassPoint != false &&
          sourceAminoAcidProfile?.basis == 'per_100g'
      ? sourceAminoAcidProfile?.scaledToGrams(portionGrams)
      : null;

  final proteinSource = catalogMatch != null
      ? proteinSourceForFoodItem(catalogMatch)
      : inferProteinSourceFromNameAndCategory(
          name: item.foodName,
          category: item.foodCategory.name,
        );

  double? presentLoggedNutrient(String field, double value) {
    if (item.missingNutrientFields.contains(field) ||
        catalogMatch?.isNutrientMissing(field) == true ||
        !value.isFinite ||
        value < 0) {
      return null;
    }
    return value;
  }

  return FoodComponent(
    id: componentId,
    name: item.foodName,
    physicalForm: physicalForm,
    proteinGrams: presentLoggedNutrient('proteinG', item.proteinG),
    fatGrams: presentLoggedNutrient('fatG', item.fatG),
    fiberGrams: presentLoggedNutrient('fiberG', item.fiberG),
    carbohydrateGrams: presentLoggedNutrient('carbsG', item.carbsG),
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
