import '../../../core/constants/seed_food_composition_table.dart';
import '../../../core/models/food_item.dart';

/// Projects a built-in seed catalog food with nutrient values copied from
/// its USDA FoodData Central record ([seedFoodCompositions]).
///
/// A seed food with no authoritative record keeps its name, aliases and
/// texture for search and logging, but every nutrient is marked unknown in
/// [FoodItem.missingNutrientFields]; no value is estimated. Educational
/// prototype; values describe foods, not people.
FoodItem projectSeedCatalogFood({
  required String id,
  required String name,
  required FoodCategory category,
  required List<String> aliases,
  required String sourceSystem,
  required String jurisdiction,
  String? textureClass,
  int? iddsiLevel,
}) {
  final composition = seedFoodCompositions[id];
  if (composition == null) {
    final reason =
        seedFoodUnmatchedReasons[id] ??
        'No authoritative composition record is mapped.';
    return FoodItem(
      id: id,
      name: name,
      category: category,
      aliases: aliases,
      description:
          'Built-in catalog entry without an authoritative composition '
          'record ($reason) Nutrient values are unknown.',
      sourceSystem: sourceSystem,
      sourceFoodCode: id,
      jurisdiction: jurisdiction,
      textureClass: textureClass,
      iddsiLevel: iddsiLevel,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: const {
        'proteinG',
        'carbsG',
        'fatG',
        'fiberG',
        'sodiumMg',
        'energyKcal',
        'waterG',
      },
    );
  }
  final available = composition.availableCarbohydrateG;
  final proxyNote = composition.note == null ? '' : ' ${composition.note}';
  return FoodItem(
    id: id,
    name: name,
    category: category,
    aliases: aliases,
    description:
        'Per-100 g values copied from ${composition.sourceLabel} record '
        '${composition.fdcId} ("${composition.sourceDescription}"; '
        '${composition.match.name}).$proxyNote',
    sourceSystem: sourceSystem,
    sourceFoodCode: id,
    jurisdiction: jurisdiction,
    textureClass: textureClass,
    iddsiLevel: iddsiLevel,
    proteinG: composition.proteinG ?? 0,
    carbsG: available ?? 0,
    fatG: composition.fatG ?? 0,
    fiberG: composition.fiberG ?? 0,
    sodiumMg: composition.sodiumMg ?? 0,
    energyKcal: composition.energyKcal,
    waterG: composition.waterG,
    missingNutrientFields: {
      if (composition.proteinG == null) 'proteinG',
      if (available == null) 'carbsG',
      if (composition.fatG == null) 'fatG',
      if (composition.fiberG == null) 'fiberG',
      if (composition.sodiumMg == null) 'sodiumMg',
      if (composition.energyKcal == null) 'energyKcal',
      if (composition.waterG == null) 'waterG',
    },
  );
}
