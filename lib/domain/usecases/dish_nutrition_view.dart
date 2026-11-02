import '../../core/models/food_item.dart';
import '../entities/dish_recipe.dart';

/// Nutrients shown per serving on the Advanced dishes page.
enum DishNutrient { protein, energy, fat, carbohydrate, fiber, competingLnaa }

/// How an ingredient's nutrition was obtained.
enum DishIngredientStatus {
  /// The ingredient has no catalog food; its nutrition is unknown.
  notInCatalog,

  /// The dish names a catalog id this catalog does not contain.
  catalogIdUnresolved,

  /// The catalog food has no per-100 g edible-mass basis, so grams cannot be
  /// applied to it.
  noMassBasis,

  /// Per-100 g catalog values scaled to the ingredient's grams.
  resolved,
}

/// Where an ingredient's competing-LNAA value came from.
enum DishLnaaBasis {
  /// All six competing LNAAs are reported by the source amino-acid profile.
  measuredProfile,

  /// The source reports 0 g protein, so no amino acid can be present.
  zeroProtein,

  /// No complete profile and no reported zero protein: unknown.
  unknown,
}

final class DishIngredientNutrition {
  const DishIngredientNutrition({
    required this.ingredient,
    required this.status,
    required this.values,
    this.food,
    this.lnaaBasis = DishLnaaBasis.unknown,
  });

  final DishIngredient ingredient;
  final DishIngredientStatus status;
  final FoodItem? food;

  /// Amount in this ingredient's grams; null means unknown (never zero).
  final Map<DishNutrient, double?> values;
  final DishLnaaBasis lnaaBasis;

  bool get resolved => status == DishIngredientStatus.resolved;
  double? valueOf(DishNutrient nutrient) => values[nutrient];
}

/// Sum of the known ingredient values of one nutrient, with how many
/// ingredients were known. An incomplete total is a lower bound of the
/// known part only; it is never shown as the dish total.
final class DishNutrientTotal {
  const DishNutrientTotal({
    required this.nutrient,
    required this.knownSum,
    required this.knownCount,
    required this.ingredientCount,
  });

  final DishNutrient nutrient;
  final double knownSum;
  final int knownCount;
  final int ingredientCount;

  bool get complete => knownCount == ingredientCount;
  bool get anyKnown => knownCount > 0;
  int get unknownCount => ingredientCount - knownCount;

  /// The per-serving total when every ingredient is known, else null.
  double? get value => complete ? knownSum : null;
}

final class DishNutrition {
  const DishNutrition({
    required this.dish,
    required this.ingredients,
    required this.totals,
  });

  final DishRecipe dish;
  final List<DishIngredientNutrition> ingredients;
  final Map<DishNutrient, DishNutrientTotal> totals;

  DishNutrientTotal total(DishNutrient nutrient) => totals[nutrient]!;

  int get ingredientCount => ingredients.length;
  int get resolvedCount => ingredients.where((i) => i.resolved).length;

  double get gramsPerServing =>
      ingredients.fold(0, (sum, i) => sum + i.ingredient.gramsPerServing);
  double get resolvedGramsPerServing => ingredients
      .where((i) => i.resolved)
      .fold(0, (sum, i) => sum + i.ingredient.gramsPerServing);

  /// True when every nutrient of every ingredient is known.
  bool get complete => totals.values.every((t) => t.complete);
}

/// Per-serving dish nutrition as a plain view over catalog data.
///
/// For each ingredient the catalog's per-100 g value is multiplied by
/// grams / 100 and the ingredient values are added. Nothing is estimated:
/// a field the catalog marks missing, an ingredient without a catalog food
/// and a food without an edible-mass basis all stay unknown and are counted,
/// never added as 0. Competing LNAA (leucine, isoleucine, valine,
/// phenylalanine, tyrosine, tryptophan) is used only from a source profile
/// that reports all six, or as 0 when the source reports 0 g protein.
/// Cooking losses and water changes are not modelled.
final class DishNutritionView {
  const DishNutritionView();

  DishNutrition compute(
    DishRecipe dish,
    FoodItem? Function(String foodId) lookup,
  ) {
    final rows = [
      for (final ingredient in dish.ingredients)
        _ingredient(ingredient, lookup),
    ];
    return DishNutrition(
      dish: dish,
      ingredients: List.unmodifiable(rows),
      totals: {
        for (final nutrient in DishNutrient.values)
          nutrient: _total(nutrient, rows),
      },
    );
  }

  DishIngredientNutrition _ingredient(
    DishIngredient ingredient,
    FoodItem? Function(String foodId) lookup,
  ) {
    final unknown = {for (final n in DishNutrient.values) n: null};
    final id = ingredient.foodId;
    if (id == null) {
      return DishIngredientNutrition(
        ingredient: ingredient,
        status: DishIngredientStatus.notInCatalog,
        values: unknown,
      );
    }
    final food = lookup(id);
    if (food == null) {
      return DishIngredientNutrition(
        ingredient: ingredient,
        status: DishIngredientStatus.catalogIdUnresolved,
        values: unknown,
      );
    }
    final grams = ingredient.gramsPerServing;
    if (!food.supportsEdibleMassPoint || !grams.isFinite || grams <= 0) {
      return DishIngredientNutrition(
        ingredient: ingredient,
        status: DishIngredientStatus.noMassBasis,
        food: food,
        values: unknown,
      );
    }
    double? scaled(double? per100) {
      if (per100 == null || !per100.isFinite || per100 < 0) return null;
      return per100 * grams / 100;
    }

    double? field(String name, double value) =>
        food.isNutrientMissing(name) ? null : value;

    final protein = scaled(field('proteinG', food.proteinG));
    final (lnaa, lnaaBasis) = _lnaa(food, grams, protein);
    return DishIngredientNutrition(
      ingredient: ingredient,
      status: DishIngredientStatus.resolved,
      food: food,
      lnaaBasis: lnaaBasis,
      values: {
        DishNutrient.protein: protein,
        DishNutrient.energy: food.isNutrientMissing('energyKcal')
            ? null
            : scaled(food.energyKcal),
        DishNutrient.fat: scaled(field('fatG', food.fatG)),
        DishNutrient.carbohydrate: scaled(field('carbsG', food.carbsG)),
        DishNutrient.fiber: scaled(field('fiberG', food.fiberG)),
        DishNutrient.competingLnaa: lnaa,
      },
    );
  }

  (double?, DishLnaaBasis) _lnaa(FoodItem food, double grams, double? protein) {
    final profile = food.aminoAcidProfile;
    if (profile != null && profile.presentLnaaFieldCount == 6) {
      final value = profile.scaledToGrams(grams)?.competingLnaaGrams;
      if (value != null && value.isFinite) {
        return (value, DishLnaaBasis.measuredProfile);
      }
    }
    if (protein == 0) return (0, DishLnaaBasis.zeroProtein);
    return (null, DishLnaaBasis.unknown);
  }

  DishNutrientTotal _total(
    DishNutrient nutrient,
    List<DishIngredientNutrition> rows,
  ) {
    var sum = 0.0;
    var known = 0;
    for (final row in rows) {
      final value = row.valueOf(nutrient);
      if (value == null) continue;
      sum += value;
      known += 1;
    }
    return DishNutrientTotal(
      nutrient: nutrient,
      knownSum: sum,
      knownCount: known,
      ingredientCount: rows.length,
    );
  }
}
