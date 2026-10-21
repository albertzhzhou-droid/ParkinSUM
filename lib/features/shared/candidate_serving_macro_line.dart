import '../../core/i18n/app_i18n.dart';
import '../../core/models/food_item.dart';
import '../../domain/entities/food_serving_reference.dart';
import '../../domain/usecases/food_serving_reference_resolver.dart';

/// Macro line for a next-meal candidate at the amount it is evaluated at:
/// per reference serving with its basis, or per 100 g labelled "serving
/// unknown". A nutrient the source marks missing reads as unknown, never 0.
///
/// Formatting only; the serving comes from the registered resolver.
String candidateServingMacroLine(AppI18n i18n, FoodItem food) {
  final amount = FoodServingNutrients(food);
  String value(String field) {
    final grams = amount.displayValue(field);
    return grams == null
        ? i18n.tr('serving.value_unknown')
        : i18n.tr('serving.value_grams', {'value': grams.toStringAsFixed(1)});
  }

  final values = <String, String>{
    'protein': value('proteinG'),
    'carbs': value('carbsG'),
    'fat': value('fatG'),
  };
  final serving = amount.serving;
  final servingGrams = serving.grams;
  if (servingGrams == null) {
    return i18n.tr('serving.macro_line_per_100g_unknown', values);
  }
  return i18n.tr('serving.macro_line', {
    ...values,
    'grams': servingGrams.toStringAsFixed(0),
    'basis': i18n.tr(
      serving.basis == FoodServingBasis.sourcePortion
          ? 'serving.basis.source_portion'
          : 'serving.basis.category_default',
    ),
  });
}
