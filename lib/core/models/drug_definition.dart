/// 药物标签：用于规则引擎识别药物类别（比直接用字符串安全）
enum DrugTag {
  levodopaLike,
  comtInhibitor,
  maoi,
  mineralSupplement,
  dopamineAgonist,
  adenosineA2aAntagonist,
  amantadineLike,
  cholinesteraseInhibitor,
  pressorAgent,
  laxative,
}

/// DrugDefinition：药物目录定义（非处方建议，只是结构化信息）
class DrugDefinition {
  final String id;
  final String genericName;
  final List<String> brandNames;
  final List<String> aliases;
  final List<DrugTag> tags;
  final String notes;
  final String interactionSummary;
  final String sourceSystem;
  final String? sourceProductCode;
  final String jurisdiction;
  final String route;
  final String dosageForm;
  final String releaseType;

  DrugDefinition({
    required this.id,
    required this.genericName,
    required this.brandNames,
    this.aliases = const <String>[],
    required this.tags,
    required this.notes,
    this.interactionSummary = '',
    this.sourceSystem = 'LOCAL_SEED',
    this.sourceProductCode,
    this.jurisdiction = 'GLOBAL',
    this.route = 'oral',
    this.dosageForm = 'unspecified',
    this.releaseType = 'unspecified',
  });

  /// UI 用展示名：优先通用名
  String get displayName => genericName;

  /// 搜索索引文本：
  /// - 让目录页能通过通用名、商品名、别名、剂型、来源系统、交互摘要检索。
  /// - 这里仍是 UI 辅助索引，不替代正式标签解析。
  String get searchableText => [
        id,
        genericName,
        ...brandNames,
        ...aliases,
        notes,
        interactionSummary,
        sourceSystem,
        jurisdiction,
        route,
        dosageForm,
        releaseType,
        sourceProductCode ?? '',
      ].join(' ').toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'genericName': genericName,
        'brandNames': brandNames,
        'aliases': aliases,
        'tags': tags.map((e) => e.name).toList(),
        'notes': notes,
        'interactionSummary': interactionSummary,
        'sourceSystem': sourceSystem,
        'sourceProductCode': sourceProductCode,
        'jurisdiction': jurisdiction,
        'route': route,
        'dosageForm': dosageForm,
        'releaseType': releaseType,
      };

  static DrugDefinition fromJson(Map<String, dynamic> json) {
    final tagsRaw = (json['tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);

    return DrugDefinition(
      id: json['id'] as String,
      genericName: json['genericName'] as String,
      brandNames: (json['brandNames'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      tags: tagsRaw
          .map((t) => DrugTag.values.firstWhere((x) => x.name == t,
              orElse: () => DrugTag.levodopaLike))
          .toList(),
      notes: (json['notes'] as String?) ?? '',
      interactionSummary: (json['interactionSummary'] as String?) ?? '',
      sourceSystem: (json['sourceSystem'] as String?) ?? 'LOCAL_SEED',
      sourceProductCode: json['sourceProductCode'] as String?,
      jurisdiction: (json['jurisdiction'] as String?) ?? 'GLOBAL',
      route: (json['route'] as String?) ?? 'oral',
      dosageForm: (json['dosageForm'] as String?) ?? 'unspecified',
      releaseType: (json['releaseType'] as String?) ?? 'unspecified',
    );
  }
}
