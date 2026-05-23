import '../models/food_item.dart';
import '../constants/p0_food_source_seed.dart';
import 'nutrition_rules.dart';

/// FoodRepository：
/// 1) 提供内置食物目录（你后续可以改成从本地/云端加载，但对上层 API 不变）
/// 2) 提供一些“默认推荐/分类辅助”的字段
class FoodRepository {
  List<FoodItem> _foods;

  FoodRepository._(this._foods);

  /// 工厂：构建默认目录
  factory FoodRepository.createDefault() {
    // 默认目录优先复用已经接入数据库设计的 P0 食物集合，避免 UI 搜索与 CDSS 事实库脱节。
    return FoodRepository._(buildP0FoodCatalog());
  }

  List<FoodItem> get allFoods => List.unmodifiable(_foods);

  /// AppState 在 bootstrap 后可以用数据库里更完整的目录覆盖默认值。
  /// 这样能兼容：
  /// 1. 首次启动时的内置种子；
  /// 2. 后续通过本地数据库/ETL 扩充后的真实目录。
  void replaceAll(List<FoodItem> foods) {
    if (foods.isEmpty) return;
    _foods = List<FoodItem>.from(foods);
  }

  FoodItem? getById(String id) {
    try {
      return _foods.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 一个“便捷规则”：判断是否高蛋白
  bool isHighProtein(FoodItem food) {
    return food.proteinG >= NutritionRules.highProteinPer100gG;
  }
}
