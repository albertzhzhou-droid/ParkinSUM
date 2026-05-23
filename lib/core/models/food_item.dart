/// 食物类别：用于 UI 和规则判断（可扩展）
enum FoodCategory {
  protein,
  carbs,
  vegetable,
  fruit,
  dairy,
  fat,
  beverage,
  other,
}

/// FoodItem：
/// 统一的食物目录条目（可来自内置目录/用户自建/云端）
class FoodItem {
  final String id;
  final String name;
  final FoodCategory category;
  final List<String> aliases;
  final String description;
  final String sourceSystem;
  final String? sourceFoodCode;
  final String jurisdiction;
  // 结构化质地字段：
  // - 只在来源文本足够明确时填值；
  // - 当前用于 recommendation / catalog 的保守吞咽上下文支持；
  // - 不是 authoritative clinical swallowing classification。
  final String? textureClass;
  final int? iddsiLevel;

  // 这里用“每 100g 估算”，用于粗略规则分析（不是营养医学建议）
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const <String>[],
    this.description = '',
    this.sourceSystem = 'LOCAL_SEED',
    this.sourceFoodCode,
    this.jurisdiction = 'GLOBAL',
    this.textureClass,
    this.iddsiLevel,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
  });

  /// 搜索索引文本：
  /// - 这里服务于 UI 目录搜索，不替代数据库里的正式 crosswalk / concept-variant 解析。
  /// - 可以安全合并本地名称、别名、来源系统与简短描述，提升录餐搜索命中率。
  String get searchableText => [
        id,
        name,
        ...aliases,
        description,
        sourceSystem,
        jurisdiction,
        sourceFoodCode ?? '',
      ].join(' ').toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'aliases': aliases,
        'description': description,
        'sourceSystem': sourceSystem,
        'sourceFoodCode': sourceFoodCode,
        'jurisdiction': jurisdiction,
        'textureClass': textureClass,
        'iddsiLevel': iddsiLevel,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'fiberG': fiberG,
        'sodiumMg': sodiumMg,
      };

  static FoodItem fromJson(Map<String, dynamic> json) {
    final catName = (json['category'] as String?) ?? 'other';
    final cat = FoodCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => FoodCategory.other,
    );

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: cat,
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      description: (json['description'] as String?) ?? '',
      sourceSystem: (json['sourceSystem'] as String?) ?? 'LOCAL_SEED',
      sourceFoodCode: json['sourceFoodCode'] as String?,
      jurisdiction: (json['jurisdiction'] as String?) ?? 'GLOBAL',
      textureClass: json['textureClass'] as String?,
      iddsiLevel: (json['iddsiLevel'] as num?)?.toInt(),
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiberG'] as num?)?.toDouble() ?? 0,
      sodiumMg: (json['sodiumMg'] as num?)?.toDouble() ?? 0,
    );
  }
}
