import '../../domain/entities/amino_acid_profile.dart';

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
  //
  // 这些 getter 仍是 non-nullable double（UI 兼容）。但“缺失 ≠ 0”：
  // 当某个营养字段实际上没有来源数据时，它的名字会出现在
  // [missingNutrientFields]，下游（candidate → MealComposition）据此向模型
  // 传 null 而不是 0，从而避免把“未知”伪装成“真实的 0 g”。
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;

  /// Names of nutrient fields that were NOT present in the source data and are
  /// therefore unknown (NOT a true zero). Recognized values mirror the field
  /// names: 'proteinG', 'carbsG', 'fatG', 'fiberG', 'sodiumMg', 'energyKcal',
  /// 'waterG'. Additive and default-empty so existing call sites are unaffected.
  final Set<String> missingNutrientFields;

  /// Optional model-ready fields, carried only when the source actually
  /// provides them (never fabricated). Absent → null, and the corresponding
  /// name should appear in [missingNutrientFields] when relevant.
  final double? energyKcal;
  final double? waterG;

  /// Actual amino-acid profile (e.g. from USDA FDC amino-acid fields), carried
  /// for the LNAA competition layer. Null → the proxy fallback is used.
  final AminoAcidProfile? aminoAcidProfile;

  /// Optional provenance/measurement-context strings preserved when available.
  /// e.g. basisType 'per_100g'; preparationState 'cooked'/'raw';
  /// qualifierKind 'analytical'/'calculated'/'assumed'.
  final String? basisType;
  final String? preparationState;
  final String? qualifierKind;

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
    this.missingNutrientFields = const <String>{},
    this.energyKcal,
    this.waterG,
    this.aminoAcidProfile,
    this.basisType,
    this.preparationState,
    this.qualifierKind,
  });

  /// True when the named nutrient field has no source data (unknown, not 0).
  bool isNutrientMissing(String field) => missingNutrientFields.contains(field);

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
        'missingNutrientFields': missingNutrientFields.toList(),
        'energyKcal': energyKcal,
        'waterG': waterG,
        'aminoAcidProfile': aminoAcidProfile?.toJson(),
        'basisType': basisType,
        'preparationState': preparationState,
        'qualifierKind': qualifierKind,
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
      missingNutrientFields:
          (json['missingNutrientFields'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toSet(),
      energyKcal: (json['energyKcal'] as num?)?.toDouble(),
      waterG: (json['waterG'] as num?)?.toDouble(),
      aminoAcidProfile: json['aminoAcidProfile'] is Map<String, dynamic>
          ? AminoAcidProfile.fromJson(
              json['aminoAcidProfile'] as Map<String, dynamic>)
          : null,
      basisType: json['basisType'] as String?,
      preparationState: json['preparationState'] as String?,
      qualifierKind: json['qualifierKind'] as String?,
    );
  }
}
