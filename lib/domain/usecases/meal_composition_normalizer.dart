import '../entities/algorithm_component_identity_witness.dart';
import '../entities/meal_composition.dart';
import '../entities/time_axis_events.dart';

/// Pure normalization: never invents nutrient values, never widens precision,
/// records every missing field for the downstream uncertainty model.
class MealCompositionNormalizer with RegisteredAlgorithmComponentIdentity {
  /// Build a `MealComposition` from a set of food components and an optional
  /// already-known physical form. Nutrient values on `FoodComponent` are
  /// already per serving; this layer aggregates them and records missingness.
  MealComposition normalize({
    required String mealId,
    required List<FoodComponent> components,
    MealPhysicalForm? declaredPhysicalForm,
  }) {
    final hasKnownDeclaredForm =
        declaredPhysicalForm != null &&
        declaredPhysicalForm != MealPhysicalForm.unknown;
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
        missingFields: [
          'food_components',
          'total_calories',
          'protein_grams',
          'fat_grams',
          'fiber_grams',
          'carbohydrate_grams',
          'portion_grams',
          'liquid_fraction',
          if (!hasKnownDeclaredForm) 'meal_physical_form',
        ],
        foodComponents: const [],
      );
    }

    // A meal-level nutrient total is publishable only when every component is
    // observed with a finite, nonnegative value. Partial sums would silently
    // treat missing/invalid components as zero and feed false precision into
    // competition, size, and uncertainty scoring. Known zero remains valid.
    double? completeNonnegativeSum(Iterable<double?> xs) {
      var total = 0.0;
      for (final x in xs) {
        if (x == null || !x.isFinite || x < 0) return null;
        total += x;
        if (!total.isFinite) return null;
      }
      return total;
    }

    final protein = completeNonnegativeSum(
      components.map((c) => c.proteinGrams),
    );
    final fat = completeNonnegativeSum(components.map((c) => c.fatGrams));
    final fiber = completeNonnegativeSum(components.map((c) => c.fiberGrams));
    final carbs = completeNonnegativeSum(
      components.map((c) => c.carbohydrateGrams),
    );
    final calories = completeNonnegativeSum(components.map((c) => c.calories));

    final hasUnknownComponentForm = components.any(
      (component) => component.physicalForm == MealPhysicalForm.unknown,
    );

    final hasUnknownPortion = components.any(
      (component) => component.portionGrams == null,
    );
    final hasInvalidPortion = components.any((component) {
      final portion = component.portionGrams;
      return portion != null && (!portion.isFinite || portion < 0);
    });
    double effectiveMass(FoodComponent component) {
      final portion = component.portionGrams;
      return portion != null && portion.isFinite && portion > 0 ? portion : 0.0;
    }

    var maximumEffectiveMass = 0.0;
    for (final component in components) {
      final mass = effectiveMass(component);
      if (mass > maximumEffectiveMass) maximumEffectiveMass = mass;
    }
    final liquidMass = maximumEffectiveMass > 0
        ? components
              .where(
                (component) =>
                    component.physicalForm == MealPhysicalForm.liquid,
              )
              .map(
                (component) => effectiveMass(component) / maximumEffectiveMass,
              )
              .fold<double>(0, (a, b) => a + b)
        : 0.0;
    final totalMass = maximumEffectiveMass > 0
        ? components
              .map(
                (component) => effectiveMass(component) / maximumEffectiveMass,
              )
              .fold<double>(0, (a, b) => a + b)
        : 0.0;

    // A partial unknown portion makes the mass-derived fraction unknown; it
    // must not be silently treated as zero. The gastric model may use its
    // disclosed central imputation, while this normalized evidence field stays
    // null and lowers completeness. Zero portions remain known zero mass.
    final portionIncomplete = hasUnknownPortion || hasInvalidPortion;
    final liquidFraction =
        !portionIncomplete && !hasUnknownComponentForm && totalMass > 0
        ? liquidMass / totalMass
        : null;

    final form = hasKnownDeclaredForm
        ? declaredPhysicalForm
        : _inferForm(components, liquidFraction);

    final missing = <String>[];
    if (protein == null) missing.add('protein_grams');
    if (fat == null) missing.add('fat_grams');
    if (fiber == null) missing.add('fiber_grams');
    if (carbs == null) missing.add('carbohydrate_grams');
    if (calories == null) missing.add('total_calories');
    if (portionIncomplete) missing.add('portion_grams');
    if (liquidFraction == null) missing.add('liquid_fraction');
    if (!hasKnownDeclaredForm && hasUnknownComponentForm) {
      missing.add('meal_physical_form');
    }

    const possibleFields = 8;
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
    List<FoodComponent> components,
    double? liquidFraction,
  ) {
    if (components.any(
      (component) => component.physicalForm == MealPhysicalForm.unknown,
    )) {
      return MealPhysicalForm.unknown;
    }
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
