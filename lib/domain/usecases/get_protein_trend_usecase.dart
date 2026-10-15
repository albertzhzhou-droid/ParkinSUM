import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../entities/protein_trend_point.dart';

class GetProteinTrendUseCase {
  static const Map<String, Object?> configurationIdentity = {
    'contract_schema': 'parkinsum.protein-trend-aggregation/2',
    'time_basis': 'Meal.effectiveOccurredAt',
    'time_order': 'ascending',
    'protein_value': 'Meal.knownNutrientTotal(proteinG)',
    'protein_unit': 'g_per_meal',
    'included_meals':
        'nonempty; every item has known finite nonnegative protein and finite positive quantity; finite sum',
    'missingness':
        'captured item marker or current catalog marker excludes the entire meal; measured zero remains included',
    'mean_formula': 'sum(included_meal_total_protein_g) / included_meal_count',
    'empty_known_mean_g': null,
    'legacy_double_mean_empty_fallback_g': 0,
  };

  List<ProteinTrendPoint> call(
    List<Meal> meals, {
    List<FoodItem> catalog = const [],
  }) {
    final points = <ProteinTrendPoint>[];
    for (final meal in meals) {
      final protein = meal.knownNutrientTotal('proteinG', catalog: catalog);
      if (protein == null) continue;
      points.add(
        ProteinTrendPoint(time: meal.effectiveOccurredAt, protein: protein),
      );
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  /// Null means no complete numeric meal is available. Missing meals never
  /// contribute a fabricated zero or enter the average denominator.
  double? knownAverageProtein(
    List<Meal> meals, {
    List<FoodItem> catalog = const [],
  }) {
    final points = call(meals, catalog: catalog);
    if (points.isEmpty) return null;
    final sum = points.fold<double>(0, (sum, point) => sum + point.protein);
    if (sum.isFinite) return sum / points.length;
    // Preserve the legacy arithmetic for finite sums; dividing first is needed
    // only when many individually finite totals overflow their raw sum.
    return points.fold<double>(
      0,
      (sum, point) => sum + point.protein / points.length,
    );
  }

  /// Legacy numeric API. Its empty fallback is a compatibility sentinel, not
  /// an observed mean; user interfaces must use [knownAverageProtein].
  double averageProtein(
    List<Meal> meals, {
    List<FoodItem> catalog = const [],
  }) => knownAverageProtein(meals, catalog: catalog) ?? 0;
}
