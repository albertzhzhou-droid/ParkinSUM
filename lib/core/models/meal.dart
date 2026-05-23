import 'food_item.dart';

/// MealItem：
/// - 复用 FoodItem 的营养信息
/// - quantityFactor：份量系数（以“每 100g”为基准，1.0=100g，2.0=200g）
class MealItem {
  final String foodId;
  final String foodName;
  final FoodCategory foodCategory;
  final double quantityFactor;

  // 扩展标签（例如 high_tyramine），方便规则引擎识别
  final List<String> foodTags;

  // 用于计算的营养数据（每100g）
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double sodiumPer100g;

  MealItem({
    required this.foodId,
    required this.foodName,
    required this.foodCategory,
    required this.quantityFactor,
    required this.foodTags,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.sodiumPer100g,
  });

  /// 从目录 FoodItem 快速构建
  factory MealItem.fromFood({
    required FoodItem food,
    required double quantityFactor,
    List<String>? foodTags,
  }) {
    return MealItem(
      foodId: food.id,
      foodName: food.name,
      foodCategory: food.category,
      quantityFactor: quantityFactor,
      foodTags: foodTags ?? const [],
      proteinPer100g: food.proteinG,
      carbsPer100g: food.carbsG,
      fatPer100g: food.fatG,
      fiberPer100g: food.fiberG,
      sodiumPer100g: food.sodiumMg,
    );
  }

  double get proteinG => proteinPer100g * quantityFactor;
  double get carbsG => carbsPer100g * quantityFactor;
  double get fatG => fatPer100g * quantityFactor;
  double get fiberG => fiberPer100g * quantityFactor;
  double get sodiumMg => sodiumPer100g * quantityFactor;
  double get grams => quantityFactor * 100;

  String get foodCategoryName => foodCategory.name;

  MealItem copyWith({
    String? foodId,
    String? foodName,
    FoodCategory? foodCategory,
    double? quantityFactor,
    List<String>? foodTags,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    double? sodiumPer100g,
  }) {
    return MealItem(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      foodCategory: foodCategory ?? this.foodCategory,
      quantityFactor: quantityFactor ?? this.quantityFactor,
      foodTags: foodTags ?? this.foodTags,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      fiberPer100g: fiberPer100g ?? this.fiberPer100g,
      sodiumPer100g: sodiumPer100g ?? this.sodiumPer100g,
    );
  }

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'foodName': foodName,
        'foodCategory': foodCategory.name,
        'quantityFactor': quantityFactor,
        'foodTags': foodTags,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'fiberPer100g': fiberPer100g,
        'sodiumPer100g': sodiumPer100g,
      };

  static MealItem fromJson(Map<String, dynamic> json) {
    final catName =
        (json['foodCategory'] as String?) ?? FoodCategory.other.name;
    final cat = FoodCategory.values
        .firstWhere((c) => c.name == catName, orElse: () => FoodCategory.other);

    return MealItem(
      foodId: json['foodId'] as String,
      foodName: (json['foodName'] as String?) ?? '',
      foodCategory: cat,
      quantityFactor: (json['quantityFactor'] as num?)?.toDouble() ?? 1.0,
      foodTags: (json['foodTags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      proteinPer100g: (json['proteinPer100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble() ?? 0,
      fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble() ?? 0,
      sodiumPer100g: (json['sodiumPer100g'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Meal：一餐记录
class Meal {
  final String id;
  // `eatenAt` 作为旧字段保留，避免破坏现有规则与页面。
  // 新逻辑应尽量使用 `effectiveOccurredAt` / `occurredAt` 这组更准确的时间语义。
  final DateTime eatenAt;
  final DateTime recordedAt;
  final DateTime? occurredAt;
  final DateTime? occurredRangeStart;
  final DateTime? occurredRangeEnd;
  final String timeSource;
  final String timePrecision;
  final DateTime? nextMealWindowStart;
  final DateTime? nextMealWindowEnd;
  // 共事件上下文：
  // - 用于补充剂、增稠剂等与餐次一起影响冲突引擎的输入；
  // - 当前只接入最小高风险集合，避免把 UI 做成无边界病历表单。
  final DateTime? coeventTime;
  final List<String> coeventSubstanceTags;
  final String? thickenerType;
  // 肠内营养上下文：
  // - 当前只接连续喂养 + 蛋白量这组最关键输入；
  // - 其余更细粒度配方信息后续再扩。
  final String? enteralFeedMode;
  final String? enteralFeedFormula;
  final double? enteralFeedProteinGPerDay;
  final String title;
  final List<MealItem> items;

  Meal({
    required this.id,
    required this.eatenAt,
    DateTime? recordedAt,
    this.occurredAt,
    this.occurredRangeStart,
    this.occurredRangeEnd,
    this.timeSource = 'implicit_now',
    this.timePrecision = 'exact',
    this.nextMealWindowStart,
    this.nextMealWindowEnd,
    this.coeventTime,
    this.coeventSubstanceTags = const <String>[],
    this.thickenerType,
    this.enteralFeedMode,
    this.enteralFeedFormula,
    this.enteralFeedProteinGPerDay,
    required this.title,
    required this.items,
  }) : recordedAt = recordedAt ?? eatenAt;

  /// 引擎、时间轴和趋势图应优先读取这个时间，而不是直接依赖旧的 `eatenAt`。
  DateTime get effectiveOccurredAt =>
      occurredAt ?? occurredRangeStart ?? eatenAt;

  Meal copyWith({
    String? id,
    DateTime? eatenAt,
    DateTime? recordedAt,
    DateTime? occurredAt,
    DateTime? occurredRangeStart,
    DateTime? occurredRangeEnd,
    String? timeSource,
    String? timePrecision,
    DateTime? nextMealWindowStart,
    DateTime? nextMealWindowEnd,
    DateTime? coeventTime,
    List<String>? coeventSubstanceTags,
    String? thickenerType,
    String? enteralFeedMode,
    String? enteralFeedFormula,
    double? enteralFeedProteinGPerDay,
    String? title,
    List<MealItem>? items,
  }) {
    return Meal(
      id: id ?? this.id,
      eatenAt: eatenAt ?? this.eatenAt,
      recordedAt: recordedAt ?? this.recordedAt,
      occurredAt: occurredAt ?? this.occurredAt,
      occurredRangeStart: occurredRangeStart ?? this.occurredRangeStart,
      occurredRangeEnd: occurredRangeEnd ?? this.occurredRangeEnd,
      timeSource: timeSource ?? this.timeSource,
      timePrecision: timePrecision ?? this.timePrecision,
      nextMealWindowStart: nextMealWindowStart ?? this.nextMealWindowStart,
      nextMealWindowEnd: nextMealWindowEnd ?? this.nextMealWindowEnd,
      coeventTime: coeventTime ?? this.coeventTime,
      coeventSubstanceTags: coeventSubstanceTags ?? this.coeventSubstanceTags,
      thickenerType: thickenerType ?? this.thickenerType,
      enteralFeedMode: enteralFeedMode ?? this.enteralFeedMode,
      enteralFeedFormula: enteralFeedFormula ?? this.enteralFeedFormula,
      enteralFeedProteinGPerDay:
          enteralFeedProteinGPerDay ?? this.enteralFeedProteinGPerDay,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }

  /// 计算合计（用于规则引擎）
  MealTotals computeTotals() {
    double p = 0, c = 0, f = 0, fi = 0, s = 0;
    for (final it in items) {
      p += it.proteinG;
      c += it.carbsG;
      f += it.fatG;
      fi += it.fiberG;
      s += it.sodiumMg;
    }
    return MealTotals(
      totalProteinG: p,
      totalCarbsG: c,
      totalFatG: f,
      totalFiberG: fi,
      totalSodiumMg: s,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eatenAt': eatenAt.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
        'occurredAt': occurredAt?.toIso8601String(),
        'occurredRangeStart': occurredRangeStart?.toIso8601String(),
        'occurredRangeEnd': occurredRangeEnd?.toIso8601String(),
        'timeSource': timeSource,
        'timePrecision': timePrecision,
        'nextMealWindowStart': nextMealWindowStart?.toIso8601String(),
        'nextMealWindowEnd': nextMealWindowEnd?.toIso8601String(),
        'coeventTime': coeventTime?.toIso8601String(),
        'coeventSubstanceTags': coeventSubstanceTags,
        'thickenerType': thickenerType,
        'enteralFeedMode': enteralFeedMode,
        'enteralFeedFormula': enteralFeedFormula,
        'enteralFeedProteinGPerDay': enteralFeedProteinGPerDay,
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };

  static Meal fromJson(Map<String, dynamic> json) {
    final eatenAt = DateTime.parse(json['eatenAt'] as String);
    return Meal(
      id: json['id'] as String,
      eatenAt: eatenAt,
      recordedAt: json['recordedAt'] == null
          ? eatenAt
          : DateTime.parse(json['recordedAt'] as String),
      occurredAt: json['occurredAt'] == null
          ? null
          : DateTime.parse(json['occurredAt'] as String),
      occurredRangeStart: json['occurredRangeStart'] == null
          ? null
          : DateTime.parse(json['occurredRangeStart'] as String),
      occurredRangeEnd: json['occurredRangeEnd'] == null
          ? null
          : DateTime.parse(json['occurredRangeEnd'] as String),
      timeSource: (json['timeSource'] as String?) ?? 'migration_legacy',
      timePrecision: (json['timePrecision'] as String?) ?? 'exact',
      nextMealWindowStart: json['nextMealWindowStart'] == null
          ? null
          : DateTime.parse(json['nextMealWindowStart'] as String),
      nextMealWindowEnd: json['nextMealWindowEnd'] == null
          ? null
          : DateTime.parse(json['nextMealWindowEnd'] as String),
      coeventTime: json['coeventTime'] == null
          ? null
          : DateTime.parse(json['coeventTime'] as String),
      coeventSubstanceTags:
          (json['coeventSubstanceTags'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
      thickenerType: json['thickenerType'] as String?,
      enteralFeedMode: json['enteralFeedMode'] as String?,
      enteralFeedFormula: json['enteralFeedFormula'] as String?,
      enteralFeedProteinGPerDay:
          (json['enteralFeedProteinGPerDay'] as num?)?.toDouble(),
      title: (json['title'] as String?) ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// MealTotals：合计数据结构
class MealTotals {
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final double totalFiberG;
  final double totalSodiumMg;

  MealTotals({
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.totalFiberG,
    required this.totalSodiumMg,
  });
}
