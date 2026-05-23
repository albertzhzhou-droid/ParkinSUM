/// NutritionRules：
/// 统一管理阈值与规则常量，避免散落在各处造成“引用不一致”
///
/// 你后续要调参，只改这里即可。
class NutritionRules {
  // 每 100g 高蛋白的经验阈值（示例）
  static const double highProteinPer100gG = 20;

  // 一餐蛋白偏高阈值（示例）
  static const double highProteinMealThresholdG = 30;

  // 与 levodopaLike 规则相关的同餐蛋白干扰阈值（工程保守值）
  static const double proteinInterferenceThresholdG = 10;

  // 低纤维阈值（示例）
  static const double lowFiberMealThresholdG = 3;

  // 高钠阈值（示例）
  static const double highSodiumMealThresholdMg = 800;
}
