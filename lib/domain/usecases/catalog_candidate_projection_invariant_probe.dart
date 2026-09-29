import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../entities/amino_acid_profile.dart';
import '../entities/meal_composition.dart';
import 'catalog_food_to_candidate.dart';
import 'mechanistic_next_meal_scorer.dart';

/// Black-box observations from the production catalog-to-candidate adapters.
///
/// Expected values live in the independent verification gate. This probe only
/// executes manufactured catalog and meal records through the production
/// projection functions and records primitive outputs. It performs no I/O.
final class CatalogCandidateProjectionInvariantProbe {
  static const int probeVersion = 1;
  static const String probeId =
      'catalog-candidate-projection.black-box-production/1';

  CatalogCandidateProjectionInvariantProbe._({
    required Map<String, Object?> observations,
  }) : observations = Map<String, Object?>.unmodifiable(observations);

  factory CatalogCandidateProjectionInvariantProbe.capture() {
    var invocationCount = 0;

    CandidateFood projectCatalog(FoodItem item) {
      invocationCount++;
      return foodItemToCandidateFood(item);
    }

    FoodComponent projectMeal(
      MealItem item,
      AminoAcidProfile profile, {
      double? energyKcal,
      Set<String> missingNutrients = const <String>{},
    }) {
      invocationCount++;
      return mealItemToFoodComponent(
        item,
        componentId: 'component-${invocationCount.toString()}',
        catalogMatch: FoodItem(
          id: item.foodId,
          name: item.foodName,
          category: item.foodCategory,
          sourceSystem: 'USDA_FDC',
          sourceFoodCode: 'synthetic:${item.foodId}',
          jurisdiction: 'US',
          textureClass: 'solid',
          proteinG: item.proteinPer100g,
          carbsG: item.carbsPer100g,
          fatG: item.fatPer100g,
          fiberG: item.fiberPer100g,
          sodiumMg: item.sodiumPer100g,
          missingNutrientFields: missingNutrients,
          energyKcal: energyKcal,
          aminoAcidProfile: profile,
        ),
      );
    }

    FoodItem catalog({
      required String id,
      required Set<String> missing,
      required double protein,
      required double energy,
    }) => FoodItem(
      id: id,
      name: 'Synthetic $id',
      category: FoodCategory.protein,
      sourceSystem: 'USDA_FDC',
      sourceFoodCode: 'synthetic:$id',
      jurisdiction: 'US',
      textureClass: 'solid',
      proteinG: protein,
      carbsG: protein,
      fatG: protein,
      fiberG: protein,
      sodiumMg: protein,
      missingNutrientFields: missing,
      energyKcal: energy,
    );

    MealItem meal(String id, double quantityFactor) => MealItem(
      foodId: id,
      foodName: 'Synthetic $id',
      foodCategory: FoodCategory.protein,
      quantityFactor: quantityFactor,
      foodTags: const <String>[],
      proteinPer100g: 20,
      carbsPer100g: 5,
      fatPer100g: 2,
      fiberPer100g: 1,
      sodiumPer100g: 10,
    );

    AminoAcidProfile profile({
      String unit = 'g',
      String basis = 'per_100g',
      double leucine = 2,
    }) => AminoAcidProfile(
      leucine: leucine,
      isoleucine: 1,
      valine: 1.5,
      phenylalanine: 0.8,
      tyrosine: 0.6,
      tryptophan: 0.2,
      unit: unit,
      basis: basis,
      nutrientIds: const <String>['501', '503', '504', '508', '509', '510'],
      sourceRefs: const <String>['FDC:synthetic'],
    );

    final missing = projectCatalog(
      catalog(
        id: 'missing',
        missing: const <String>{
          'proteinG',
          'carbsG',
          'fatG',
          'fiberG',
          'energyKcal',
        },
        protein: 12,
        energy: 180,
      ),
    ).components.single;
    final zero = projectCatalog(
      catalog(id: 'zero', missing: const <String>{}, protein: 0, energy: 0),
    ).components.single;
    final half = projectMeal(meal('half', 0.5), profile());
    final zeroServing = projectMeal(meal('zero-serving', 0), profile());
    final staleEnergy = projectMeal(
      meal('stale-energy', 0.5),
      profile(),
      energyKcal: 180,
      missingNutrients: const <String>{'energyKcal'},
    );
    final unrelatedServing = projectMeal(
      meal('source-serving', 0.5),
      profile(basis: 'per_serving'),
    );
    final unknownBasis = projectMeal(
      meal('unknown-basis', 0.5),
      profile(basis: 'unknown'),
    );
    final unknownUnit = projectMeal(
      meal('unknown-unit', 0.5),
      profile(unit: 'unknown'),
    );
    final negativeServing = projectMeal(meal('negative', -0.5), profile());
    final nanServing = projectMeal(meal('nan', double.nan), profile());
    final infiniteServing = projectMeal(
      meal('infinite', double.infinity),
      profile(),
    );
    final invalidSource = projectMeal(
      meal('invalid-source', 1),
      profile(leucine: -2),
    );
    final nanSource = projectMeal(
      meal('nan-source', 1),
      profile(leucine: double.nan),
    );
    final infiniteSource = projectMeal(
      meal('infinite-source', 1),
      profile(leucine: double.infinity),
    );

    return CatalogCandidateProjectionInvariantProbe._(
      observations: <String, Object?>{
        'probe.version': probeVersion,
        'probe.invocation_count': invocationCount,
        'catalog.missing.protein_null': missing.proteinGrams == null,
        'catalog.missing.carbs_null': missing.carbohydrateGrams == null,
        'catalog.missing.fat_null': missing.fatGrams == null,
        'catalog.missing.fiber_null': missing.fiberGrams == null,
        'catalog.missing.energy_null': missing.calories == null,
        'catalog.zero.protein_g': zero.proteinGrams,
        'catalog.zero.energy_kcal': zero.calories,
        'catalog.zero.source_ref': zero.sourceDocId,
        'portion.half.grams': half.portionGrams,
        'portion.half.protein_g': half.proteinGrams,
        'portion.half.basis': half.aminoAcidProfile?.basis,
        'portion.half.leucine_g': half.aminoAcidProfile?.leucine,
        'portion.half.competing_lnaa_g':
            half.aminoAcidProfile?.competingLnaaGrams,
        'portion.half.nutrient_ids': half.aminoAcidProfile?.nutrientIds,
        'portion.half.source_refs': half.aminoAcidProfile?.sourceRefs,
        'portion.zero.profile_present': zeroServing.aminoAcidProfile != null,
        'portion.zero.basis': zeroServing.aminoAcidProfile?.basis,
        'portion.zero.leucine_g': zeroServing.aminoAcidProfile?.leucine,
        'portion.zero.competing_lnaa_g':
            zeroServing.aminoAcidProfile?.competingLnaaGrams,
        'catalog.meal_missing.energy_null': staleEnergy.calories == null,
        'basis.per_serving.held': unrelatedServing.aminoAcidProfile == null,
        'basis.unknown.held': unknownBasis.aminoAcidProfile == null,
        'unit.unknown.held': unknownUnit.aminoAcidProfile == null,
        'portion.negative.held': negativeServing.aminoAcidProfile == null,
        'portion.nan.held': nanServing.aminoAcidProfile == null,
        'portion.infinity.held': infiniteServing.aminoAcidProfile == null,
        'source.negative.held': invalidSource.aminoAcidProfile == null,
        'source.nan.held': nanSource.aminoAcidProfile == null,
        'source.infinity.held': infiniteSource.aminoAcidProfile == null,
      },
    );
  }

  final Map<String, Object?> observations;

  CatalogCandidateProjectionInvariantProbe withObservation(
    String key,
    Object? value,
  ) => CatalogCandidateProjectionInvariantProbe._(
    observations: <String, Object?>{...observations, key: value},
  );

  CatalogCandidateProjectionInvariantProbe withoutObservation(String key) =>
      CatalogCandidateProjectionInvariantProbe._(
        observations: <String, Object?>{...observations}..remove(key),
      );
}
