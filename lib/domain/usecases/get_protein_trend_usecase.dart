import '../../core/models/meal.dart';
import '../entities/protein_trend_point.dart';

class GetProteinTrendUseCase {
  List<ProteinTrendPoint> call(List<Meal> meals) {
    final points = meals
        .map(
          (meal) => ProteinTrendPoint(
            // 趋势图跟随更准确的发生时间语义，避免补录餐次时被 recorded time 污染。
            time: meal.effectiveOccurredAt,
            protein: meal.computeTotals().totalProteinG,
          ),
        )
        .toList();

    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  double averageProtein(List<Meal> meals) {
    if (meals.isEmpty) return 0;
    return meals
            .map((meal) => meal.computeTotals().totalProteinG)
            .fold<double>(0, (sum, value) => sum + value) /
        meals.length;
  }
}
