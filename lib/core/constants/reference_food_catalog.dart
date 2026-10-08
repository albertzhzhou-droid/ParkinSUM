import '../../domain/entities/reference_food_composition.dart';
import '../../domain/usecases/food_composition_interdependency_model.dart';
import '../models/food_item.dart';
import '../utils/texture_support.dart';
import 'reference_food_composition_table.dart';

/// Catalog projection of the USDA SR Legacy reference subset.
///
/// - Values are per 100 g edible portion, copied from the verbatim table.
/// - `carbsG` is harmonised to available carbohydrate (by difference −
///   total fibre) so it matches the CIQUAL convention used by the P0 seed;
///   when fibre is unreported the carbohydrate stays unknown.
/// - Every unreported field is listed in `missingNutrientFields`; the
///   non-nullable getters keep 0 only for legacy display.
List<FoodItem> buildReferenceFoodCatalog() => referenceFoodCompositionRows
    .map(referenceRowToFoodItem)
    .toList(growable: false);

FoodItem referenceRowToFoodItem(ReferenceFoodCompositionRow row) {
  final availableCarbohydrate = availableCarbohydrateOf(row);
  return FoodItem(
    id: row.appFoodId,
    name: row.nameZh,
    category: _categoryFor(row.group),
    aliases: [row.nameEn, row.nameZh, row.sourceDescription],
    description:
        '${row.nameZh} / ${row.nameEn} · USDA FDC SR Legacy · FDC ${row.fdcId}'
        ' · per 100 g edible portion · carbohydrate = by difference − fibre',
    sourceSystem: 'USDA_FDC',
    sourceFoodCode: '${row.fdcId}',
    jurisdiction: 'US',
    textureClass: row.textureClass,
    iddsiLevel: inferIddsiLevelFromTextureClass(row.textureClass),
    proteinG: row.proteinG ?? 0,
    carbsG: availableCarbohydrate ?? 0,
    fatG: row.fatG ?? 0,
    fiberG: row.fiberG ?? 0,
    sodiumMg: row.sodiumMg ?? 0,
    energyKcal: row.energyKcal,
    missingNutrientFields: {
      if (row.proteinG == null) 'proteinG',
      if (availableCarbohydrate == null) 'carbsG',
      if (row.fatG == null) 'fatG',
      if (row.fiberG == null) 'fiberG',
      if (row.sodiumMg == null) 'sodiumMg',
      if (row.energyKcal == null) 'energyKcal',
      'waterG',
    },
    basisType: 'per_100g',
    preparationState: row.preparationState,
  );
}

FoodCategory _categoryFor(ReferenceFoodGroup group) {
  switch (group) {
    case ReferenceFoodGroup.fruit:
      return FoodCategory.fruit;
    case ReferenceFoodGroup.vegetable:
      return FoodCategory.vegetable;
    case ReferenceFoodGroup.legume:
    case ReferenceFoodGroup.egg:
    case ReferenceFoodGroup.meat:
    case ReferenceFoodGroup.poultry:
    case ReferenceFoodGroup.fishSeafood:
    case ReferenceFoodGroup.proteinSupplement:
      return FoodCategory.protein;
    case ReferenceFoodGroup.grain:
      return FoodCategory.carbs;
    case ReferenceFoodGroup.dairy:
      return FoodCategory.dairy;
    case ReferenceFoodGroup.nutSeed:
    case ReferenceFoodGroup.fatOil:
      return FoodCategory.fat;
    case ReferenceFoodGroup.beverage:
    case ReferenceFoodGroup.alcoholicBeverage:
      return FoodCategory.beverage;
    case ReferenceFoodGroup.sweetenerConfection:
    case ReferenceFoodGroup.condiment:
      return FoodCategory.other;
  }
}
