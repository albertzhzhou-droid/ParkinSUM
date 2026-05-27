import '../entities/meal_composition.dart';
import '../entities/time_axis_events.dart';

/// Pure normalization: never invents nutrient values, never widens precision,
/// records every missing field for the downstream uncertainty model.
class MealCompositionNormalizer {
  /// Build a `MealComposition` from a set of food components and an optional
  /// already-known physical form. The normalizer multiplies per-portion
  /// nutrient values by component portion when present, otherwise records
  /// the field as missing.
  MealComposition normalize({
    required String mealId,
    required List<FoodComponent> components,
    MealPhysicalForm? declaredPhysicalForm,
  }) {
    if (components.isEmpty) {
      return MealComposition(
        id: mealId,
        totalCalories: null,
        proteinGrams: null,
        fatGrams: null,
        fiberGrams: null,
        carbohydrateGrams: null,
        liquidFraction: null,
        mealPhysicalForm: declaredPhysicalForm ?? MealPhysicalForm.unknown,
        portionSizeBand: PortionSizeBand.unknown,
        proteinAmountBand: AmountBand.unknown,
        fatAmountBand: AmountBand.unknown,
        fiberAmountBand: AmountBand.unknown,
        calorieBand: AmountBand.unknown,
        compositionCompleteness: 0.0,
        missingFields: const [
          'food_components',
          'total_calories',
          'protein_grams',
          'fat_grams',
          'fiber_grams',
          'carbohydrate_grams',
          'liquid_fraction',
        ],
        foodComponents: const [],
      );
    }

    double? sumOrNull(Iterable<double?> xs) {
      var any = false;
      var total = 0.0;
      for (final x in xs) {
        if (x == null) continue;
        any = true;
        total += x;
      }
      return any ? total : null;
    }

    final protein = sumOrNull(components.map((c) => c.proteinGrams));
    final fat = sumOrNull(components.map((c) => c.fatGrams));
    final fiber = sumOrNull(components.map((c) => c.fiberGrams));
    final carbs = sumOrNull(components.map((c) => c.carbohydrateGrams));
    final calories = sumOrNull(components.map((c) => c.calories));

    final liquidMass = components
        .where((c) => c.physicalForm == MealPhysicalForm.liquid)
        .map((c) => c.portionGrams ?? 0)
        .fold<double>(0, (a, b) => a + b);
    final totalMass = components
        .map((c) => c.portionGrams ?? 0)
        .fold<double>(0, (a, b) => a + b);
    final liquidFraction = totalMass > 0 ? liquidMass / totalMass : null;

    final form = declaredPhysicalForm ?? _inferForm(components, liquidFraction);

    final missing = <String>[];
    if (protein == null) missing.add('protein_grams');
    if (fat == null) missing.add('fat_grams');
    if (fiber == null) missing.add('fiber_grams');
    if (carbs == null) missing.add('carbohydrate_grams');
    if (calories == null) missing.add('total_calories');
    if (liquidFraction == null) missing.add('liquid_fraction');

    const possibleFields = 6;
    final presentFields = possibleFields - missing.length;
    final completeness = presentFields / possibleFields;

    return MealComposition(
      id: mealId,
      totalCalories: calories,
      proteinGrams: protein,
      fatGrams: fat,
      fiberGrams: fiber,
      carbohydrateGrams: carbs,
      liquidFraction: liquidFraction,
      mealPhysicalForm: form,
      portionSizeBand: _portionBand(calories ?? -1),
      proteinAmountBand: _proteinBand(protein),
      fatAmountBand: _fatBand(fat, calories),
      fiberAmountBand: _fiberBand(fiber),
      calorieBand: _calorieBand(calories),
      compositionCompleteness: completeness,
      missingFields: missing,
      foodComponents: List.unmodifiable(components),
    );
  }

  MealPhysicalForm _inferForm(
      List<FoodComponent> components, double? liquidFraction) {
    if (liquidFraction == null) {
      final forms = components.map((c) => c.physicalForm).toSet();
      if (forms.length == 1) return forms.single;
      if (forms.length > 1) return MealPhysicalForm.mixed;
      return MealPhysicalForm.unknown;
    }
    if (liquidFraction >= 0.85) return MealPhysicalForm.liquid;
    if (liquidFraction <= 0.15) return MealPhysicalForm.solid;
    return MealPhysicalForm.mixed;
  }

  PortionSizeBand _portionBand(double calories) {
    if (calories < 0) return PortionSizeBand.unknown;
    if (calories < 250) return PortionSizeBand.small;
    if (calories < 600) return PortionSizeBand.medium;
    return PortionSizeBand.large;
  }

  AmountBand _proteinBand(double? p) {
    if (p == null) return AmountBand.unknown;
    if (p <= 0) return AmountBand.none;
    if (p < 7) return AmountBand.low;
    if (p < 20) return AmountBand.moderate;
    return AmountBand.high;
  }

  AmountBand _fatBand(double? fat, double? cal) {
    if (fat == null) return AmountBand.unknown;
    if (fat <= 0) return AmountBand.none;
    if (cal != null && cal > 0) {
      final fatKcal = fat * 9.0;
      final fraction = fatKcal / cal;
      if (fraction >= 0.3) return AmountBand.high;
      if (fraction >= 0.15) return AmountBand.moderate;
      return AmountBand.low;
    }
    if (fat < 5) return AmountBand.low;
    if (fat < 15) return AmountBand.moderate;
    return AmountBand.high;
  }

  AmountBand _fiberBand(double? f) {
    if (f == null) return AmountBand.unknown;
    if (f <= 0) return AmountBand.none;
    if (f < 3) return AmountBand.low;
    if (f < 8) return AmountBand.moderate;
    return AmountBand.high;
  }

  AmountBand _calorieBand(double? c) {
    if (c == null) return AmountBand.unknown;
    if (c <= 0) return AmountBand.none;
    if (c < 250) return AmountBand.low;
    if (c < 600) return AmountBand.moderate;
    return AmountBand.high;
  }
}
