import 'protein_source.dart';
import 'time_axis_events.dart' show MealPhysicalForm;

/// Discrete bands used to communicate uncertainty without false precision.
enum AmountBand { none, low, moderate, high, unknown }

/// Coarse meal-size category.
enum PortionSizeBand { small, medium, large, unknown }

/// Composition of a single meal, normalized for the mechanistic engine.
///
/// The normalizer never invents nutrient values. When a field is missing,
/// `missingFields` records it and `compositionCompleteness` shrinks below
/// 1.0; the downstream model widens its uncertainty band rather than
/// pretending precision.
class MealComposition {
  final String id;
  final double? totalCalories;
  final double? proteinGrams;
  final double? fatGrams;
  final double? fiberGrams;
  final double? carbohydrateGrams;
  final double? liquidFraction; // 0..1
  final MealPhysicalForm mealPhysicalForm;
  final PortionSizeBand portionSizeBand;
  final AmountBand proteinAmountBand;
  final AmountBand fatAmountBand;
  final AmountBand fiberAmountBand;
  final AmountBand calorieBand;
  final double compositionCompleteness; // 0..1
  final List<String> missingFields;
  final List<FoodComponent> foodComponents;

  const MealComposition({
    required this.id,
    required this.totalCalories,
    required this.proteinGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.carbohydrateGrams,
    required this.liquidFraction,
    required this.mealPhysicalForm,
    required this.portionSizeBand,
    required this.proteinAmountBand,
    required this.fatAmountBand,
    required this.fiberAmountBand,
    required this.calorieBand,
    required this.compositionCompleteness,
    required this.missingFields,
    required this.foodComponents,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'total_calories': totalCalories,
        'protein_grams': proteinGrams,
        'fat_grams': fatGrams,
        'fiber_grams': fiberGrams,
        'carbohydrate_grams': carbohydrateGrams,
        'liquid_fraction': liquidFraction,
        'meal_physical_form': mealPhysicalForm.name,
        'portion_size_band': portionSizeBand.name,
        'protein_amount_band': proteinAmountBand.name,
        'fat_amount_band': fatAmountBand.name,
        'fiber_amount_band': fiberAmountBand.name,
        'calorie_band': calorieBand.name,
        'composition_completeness': compositionCompleteness,
        'missing_fields': missingFields,
        'food_components':
            foodComponents.map((e) => e.toJson()).toList(growable: false),
      };
}

/// A single food contributing to a meal. Nutrient fields are *per serving*
/// already (the normalizer multiplied by portion at intake time).
class FoodComponent {
  final String id;
  final String name;
  final MealPhysicalForm physicalForm;
  final double? proteinGrams;
  final double? fatGrams;
  final double? fiberGrams;
  final double? carbohydrateGrams;
  final double? calories;
  final double? portionGrams;
  final String? sourceDocId;

  /// Coarse protein source used by the LNAA-competition proxy. Defaults to
  /// `unknown`; the model widens uncertainty when this is unknown rather
  /// than guessing.
  final ProteinSourceType proteinSource;

  const FoodComponent({
    required this.id,
    required this.name,
    required this.physicalForm,
    required this.proteinGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.carbohydrateGrams,
    required this.calories,
    required this.portionGrams,
    required this.sourceDocId,
    this.proteinSource = ProteinSourceType.unknown,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'physical_form': physicalForm.name,
        'protein_grams': proteinGrams,
        'fat_grams': fatGrams,
        'fiber_grams': fiberGrams,
        'carbohydrate_grams': carbohydrateGrams,
        'calories': calories,
        'portion_grams': portionGrams,
        'source_doc_id': sourceDocId,
        'protein_source': proteinSource.name,
      };
}
