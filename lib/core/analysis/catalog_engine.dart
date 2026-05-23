import '../models/food_item.dart';
import '../models/drug_definition.dart';
import '../models/interaction_result.dart';
import '../models/meal.dart';
import 'food_repository.dart';
import 'medication_repository.dart';
import 'interaction_engine.dart';
import 'nutrition_classifier.dart';

/// CatalogEngine：聚合 FoodRepository + MedicationRepository + InteractionEngine
/// 负责给 UI 提供“可搜索目录 + 快速交互检查”等能力。
class CatalogEngine {
  final FoodRepository foodRepo;
  final MedicationRepository medRepo;
  final InteractionEngine interactionEngine;
  final NutritionClassifier nutritionClassifier;

  CatalogEngine({
    required this.foodRepo,
    required this.medRepo,
    required this.interactionEngine,
    required this.nutritionClassifier,
  });

  /// 食物目录搜索：按名称模糊匹配（大小写不敏感）
  List<FoodItem> searchFoods(String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return foodRepo.allFoods;
    return foodRepo.allFoods
        .where((f) => f.searchableText.contains(k))
        .toList(growable: false);
  }

  /// 药物目录搜索
  List<DrugDefinition> searchDrugs(String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return medRepo.allDrugs;
    return medRepo.allDrugs
        .where((d) => d.searchableText.contains(k))
        .toList(growable: false);
  }

  /// 对一个 meal 做快速营养分类（规则化标签）
  Map<String, dynamic> classifyMeal(Meal meal) {
    // 返回结构给 UI 或日志用
    final tags = nutritionClassifier.classifyMeal(meal);
    return {
      'mealId': meal.id,
      'tags': tags,
    };
  }

  /// 对“某个 meal + 当前用药方案”做快速交互检查
  InteractionResult checkMealAgainstMeds({
    required Meal meal,
    required List<DrugDefinition> activeDrugs,
  }) {
    return interactionEngine.evaluateMealWithDrugs(
        meal: meal, drugs: activeDrugs);
  }
}
