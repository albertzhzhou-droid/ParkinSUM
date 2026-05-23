import '../models/meal.dart';
import 'nutrition_rules.dart';

/// NutritionClassifier：
/// 将 Meal 映射成一组可解释的标签（用于 UI 展示、规则引擎输入等）
class NutritionClassifier {
  /// 返回一组标签字符串，尽量“稳定且可用作规则输入”
  List<String> classifyMeal(Meal meal) {
    final totals = meal.computeTotals();
    final tags = <String>[];

    // 高蛋白标签
    if (totals.totalProteinG >= NutritionRules.highProteinMealThresholdG) {
      tags.add('high_protein_meal');
    }

    // 低纤维（示例）
    if (totals.totalFiberG <= NutritionRules.lowFiberMealThresholdG) {
      tags.add('low_fiber_meal');
    }

    // 高钠（示例）
    if (totals.totalSodiumMg >= NutritionRules.highSodiumMealThresholdMg) {
      tags.add('high_sodium_meal');
    }

    // 快碳（非常简化：如果 carbs 很高且 fiber 很低）
    if (totals.totalCarbsG >= 60 && totals.totalFiberG <= 3) {
      tags.add('high_glycemic_like');
    }

    return tags;
  }
}
