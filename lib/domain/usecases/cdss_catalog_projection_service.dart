import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/utils/qualified_value_parser.dart';
import '../../core/utils/texture_support.dart';
import '../../core/db/cdss_database.dart';
import 'dart:convert';

/// 把 CDSS 事实库投影回 App 可消费目录。
///
/// 价值：
/// - 下一餐推荐与目录搜索不再只能依赖内置 seed；
/// - 后续 ETL 完成后，可以优先消费真实 variant / observation。
///
/// 未完成：
/// - 当前只做基础营养与剂型投影；
/// - crosswalk 已优先用于 app id 投影；per-jurisdiction 最优 variant 仍由 resolver/runtime 路径处理。
class CdssCatalogProjectionService {
  final CdssDatabase database;

  const CdssCatalogProjectionService({required this.database});

  Future<List<FoodItem>> projectFoods() async {
    final variants = await database.queryTable('food_variant');
    final concepts = await database.queryTable('food_concept');
    final observations = await database.queryTable('observation');
    final crosswalks = await database.queryTable('concept_variant_crosswalk');

    final conceptById = {
      for (final row in concepts) '${row['food_concept_id']}': row,
    };
    final nutrientByVariant = <String, Map<String, double>>{};
    final appIdByVariant = <String, String>{};
    for (final row in crosswalks.where((row) => row['domain'] == 'food')) {
      final variantId = '${row['variant_id'] ?? ''}';
      final appId = '${row['app_entity_id'] ?? ''}';
      if (variantId.isNotEmpty && appId.isNotEmpty) {
        appIdByVariant[variantId] = appId;
      }
    }

    for (final row in observations) {
      final entityKey = '${row['entity_key'] ?? ''}';
      if (entityKey.isEmpty) continue;
      final qualifierKind = '${row['qualifier_kind'] ?? ''}';
      if (qualifierKind != QualifierKind.exact.wireValue) continue;
      final attributeCode = '${row['attribute_code'] ?? ''}';
      final valueNum = row['value_num'];
      if (attributeCode.isEmpty || valueNum is! num) continue;
      nutrientByVariant.putIfAbsent(
              entityKey, () => <String, double>{})[attributeCode] =
          valueNum.toDouble();
    }

    return variants.map((row) {
      final variantId = '${row['food_variant_id']}';
      final hasCrosswalk = appIdByVariant.containsKey(variantId);
      final projectedId = appIdByVariant[variantId] ??
          'food_projected_${variantId.toLowerCase()}';
      final concept = conceptById['${row['food_concept_id']}'];
      final nutrients =
          nutrientByVariant[variantId] ?? const <String, double>{};
      final description = _buildFoodProjectionDescription(
        sourceFamily: '${row['source_family'] ?? 'CDSS'}',
        jurisdiction: '${row['jurisdiction'] ?? 'GLOBAL'}',
        nutrients: nutrients,
        fallbackWarning: hasCrosswalk
            ? null
            : 'missing_concept_variant_crosswalk; legacy_variant_id_projection',
      );
      return FoodItem(
        id: projectedId,
        name:
            '${row['display_name_local'] ?? concept?['canonical_name_en'] ?? variantId}',
        category: _inferFoodCategory('${concept?['food_group'] ?? 'other'}'),
        aliases: [
          if (concept?['canonical_name_en'] != null)
            '${concept!['canonical_name_en']}',
          if (concept?['canonical_name_zh'] != null)
            '${concept!['canonical_name_zh']}',
        ],
        description: description,
        sourceSystem: '${row['source_family'] ?? 'CDSS'}',
        sourceFoodCode: row['source_food_code']?.toString(),
        jurisdiction: '${row['jurisdiction'] ?? 'GLOBAL'}',
        textureClass: inferTextureClassFromText(
          name:
              '${row['display_name_local'] ?? concept?['canonical_name_en'] ?? variantId}',
          description: description,
          categoryName: '${concept?['food_group'] ?? 'other'}',
        ),
        iddsiLevel: inferIddsiLevelFromTextureClass(
          inferTextureClassFromText(
            name:
                '${row['display_name_local'] ?? concept?['canonical_name_en'] ?? variantId}',
            description: description,
            categoryName: '${concept?['food_group'] ?? 'other'}',
          ),
        ),
        proteinG: nutrients['protein_g'] ?? 0,
        carbsG: nutrients['carbohydrate_g'] ?? 0,
        fatG: nutrients['fat_g'] ?? 0,
        fiberG: nutrients['fiber_g'] ?? 0,
        sodiumMg: nutrients['sodium_mg'] ?? 0,
      );
    }).toList(growable: false);
  }

  Future<List<DrugDefinition>> projectDrugs() async {
    final concepts = await database.queryTable('drug_concept');
    final variants = await database.queryTable('drug_product_variant');
    final sections = await database.queryTable('drug_label_section');
    final media = await database.queryTable('drug_product_media');
    final crosswalks = await database.queryTable('concept_variant_crosswalk');
    final conceptById = {
      for (final row in concepts) '${row['drug_concept_id']}': row,
    };
    final sectionsByVariant = <String, List<Map<String, Object?>>>{};
    for (final row in sections) {
      final variantId = '${row['drug_product_variant_id'] ?? ''}';
      if (variantId.isEmpty) continue;
      sectionsByVariant
          .putIfAbsent(variantId, () => <Map<String, Object?>>[])
          .add(row);
    }
    final mediaCountByVariant = <String, int>{};
    final appIdByVariant = <String, String>{};
    for (final row in crosswalks.where((row) => row['domain'] == 'drug')) {
      final variantId = '${row['variant_id'] ?? ''}';
      final appId = '${row['app_entity_id'] ?? ''}';
      if (variantId.isNotEmpty && appId.isNotEmpty) {
        appIdByVariant[variantId] = appId;
      }
    }
    for (final row in media) {
      final variantId = '${row['drug_product_variant_id'] ?? ''}';
      if (variantId.isEmpty) continue;
      mediaCountByVariant.update(variantId, (value) => value + 1,
          ifAbsent: () => 1);
    }

    return variants.map((row) {
      final concept = conceptById['${row['drug_concept_id']}'];
      final genericName =
          '${concept?['generic_name'] ?? row['external_product_code'] ?? 'Unknown drug'}';
      final tag = inferDrugTag(genericName);
      final variantId = '${row['drug_product_variant_id']}';
      final hasCrosswalk = appIdByVariant.containsKey(variantId);
      final projectedId = appIdByVariant[variantId] ??
          'drug_projected_${variantId.toLowerCase()}';
      final variantSections = sectionsByVariant[variantId] ?? const [];
      final sectionSummary = variantSections
          .take(3)
          .map((item) => '${item['section_key']}: ${item['section_text']}')
          .join(' ');
      final mediaCount = mediaCountByVariant[variantId] ?? 0;
      return DrugDefinition(
        id: projectedId,
        genericName: genericName,
        brandNames: ['${row['external_product_code'] ?? genericName}'],
        aliases: ['${row['external_product_code'] ?? ''}'],
        tags: [if (tag != null) tag],
        notes: sectionSummary.isEmpty
            ? 'Projected from CDSS drug_product_variant${hasCrosswalk ? '' : ' (warning: missing_concept_variant_crosswalk; legacy_variant_id_projection)'}'
            : '$sectionSummary${hasCrosswalk ? '' : ' Warning: missing_concept_variant_crosswalk; legacy_variant_id_projection.'}',
        interactionSummary: mediaCount > 0
            ? 'Projected from imported label/product data with $mediaCount linked media resources.'
            : 'Projected from imported label/product data.',
        sourceSystem: '${row['regulator'] ?? 'CDSS'}',
        sourceProductCode: row['external_product_code']?.toString(),
        jurisdiction: '${row['jurisdiction'] ?? 'GLOBAL'}',
        route: '${row['route'] ?? 'oral'}',
        dosageForm: '${row['dosage_form'] ?? 'unspecified'}',
        releaseType: '${row['release_type'] ?? 'unspecified'}',
      );
    }).toList(growable: false);
  }

  /// 食品详情投影：
  /// - 直接从 CDSS variant / observation / source_document 读取真实导入值；
  /// - 用于“添加一餐”的信息弹层和目录详情页。
  Future<ProjectedFoodDetail?> projectFoodDetail(FoodItem food) async {
    final variants = await database.queryTable('food_variant');
    final observations = await database.queryTable('observation');
    final sourceDocuments = await database.queryTable('source_document');

    final matchingVariants = variants.where((row) {
      final sameCode = food.sourceFoodCode != null &&
          '${row['source_food_code'] ?? ''}' == food.sourceFoodCode;
      final sameJurisdiction =
          '${row['jurisdiction'] ?? 'GLOBAL'}' == food.jurisdiction;
      return sameCode && sameJurisdiction;
    }).toList(growable: false);
    if (matchingVariants.isEmpty) return null;

    final variantIds =
        matchingVariants.map((row) => '${row['food_variant_id']}').toSet();
    final sourceDocById = {
      for (final row in sourceDocuments) '${row['source_doc_id']}': row,
    };
    final nutrientLines = observations
        .where((row) => variantIds.contains('${row['entity_key'] ?? ''}'))
        .map((row) => ProjectedNutrientLine(
              attributeCode: '${row['attribute_code'] ?? ''}',
              displayLabel: _attributeLabel('${row['attribute_code'] ?? ''}'),
              rawValueText: '${row['raw_value_text'] ?? ''}',
              unit: '${row['unit'] ?? ''}',
              qualifierKind: '${row['qualifier_kind'] ?? ''}',
              methodCode: row['method_code']?.toString(),
              sourceDocTitle: sourceDocById['${row['source_doc_id'] ?? ''}']
                      ?['title']
                  ?.toString(),
            ))
        .toList(growable: false);

    return ProjectedFoodDetail(
      food: food,
      variantIds: variantIds.toList(growable: false),
      nutrientLines: nutrientLines,
      sourceTitles: matchingVariants
          .map((row) => row['source_family']?.toString() ?? 'CDSS')
          .toSet()
          .toList(growable: false),
    );
  }

  /// 药品详情投影：
  /// - 把标签 section / packaging / media 从真实导入数据读出来；
  /// - 给药品页和目录页展示更细的监管来源信息。
  Future<ProjectedDrugDetail?> projectDrugDetail(DrugDefinition drug) async {
    final variants = await database.queryTable('drug_product_variant');
    final sections = await database.queryTable('drug_label_section');
    final packagings = await database.queryTable('drug_product_packaging');
    final medias = await database.queryTable('drug_product_media');
    final sourceDocuments = await database.queryTable('source_document');

    final matchingVariants = variants.where((row) {
      final sameCode = drug.sourceProductCode != null &&
          '${row['external_product_code'] ?? ''}' == drug.sourceProductCode;
      final sameJurisdiction =
          '${row['jurisdiction'] ?? 'GLOBAL'}' == drug.jurisdiction;
      return sameCode && sameJurisdiction;
    }).toList(growable: false);
    if (matchingVariants.isEmpty) return null;

    final variantIds = matchingVariants
        .map((row) => '${row['drug_product_variant_id']}')
        .toSet();
    final sourceDocById = {
      for (final row in sourceDocuments) '${row['source_doc_id']}': row,
    };

    return ProjectedDrugDetail(
      drug: drug,
      variantIds: variantIds.toList(growable: false),
      sections: sections
          .where((row) =>
              variantIds.contains('${row['drug_product_variant_id'] ?? ''}'))
          .map((row) => ProjectedDrugSection(
                sectionKey: '${row['section_key'] ?? ''}',
                sectionTitle: '${row['section_title'] ?? ''}',
                sectionText: '${row['section_text'] ?? ''}',
                sourceDocTitle: sourceDocById['${row['source_doc_id'] ?? ''}']
                        ?['title']
                    ?.toString(),
              ))
          .toList(growable: false),
      packagingDescriptions: packagings
          .where((row) =>
              variantIds.contains('${row['drug_product_variant_id'] ?? ''}'))
          .map((row) => '${row['description'] ?? ''}')
          .where((text) => text.trim().isNotEmpty)
          .toList(growable: false),
      mediaLinks: medias
          .where((row) =>
              variantIds.contains('${row['drug_product_variant_id'] ?? ''}'))
          .map((row) => '${row['media_url'] ?? ''}')
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false),
      labelFacts: _extractProjectedLabelFacts(
        sections: sections,
        variantIds: variantIds,
        sourceDocById: sourceDocById,
      ),
    );
  }

  List<ProjectedDrugLabelFact> _extractProjectedLabelFacts({
    required List<Map<String, Object?>> sections,
    required Set<String> variantIds,
    required Map<String, Map<String, Object?>> sourceDocById,
  }) {
    final sourceDocIds = sections
        .where((row) =>
            variantIds.contains('${row['drug_product_variant_id'] ?? ''}'))
        .map((row) => '${row['source_doc_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final facts = <ProjectedDrugLabelFact>[];
    for (final sourceDocId in sourceDocIds) {
      final sourceDoc = sourceDocById[sourceDocId];
      if (sourceDoc == null) continue;
      final rawPayload = '${sourceDoc['raw_payload'] ?? ''}';
      if (rawPayload.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map) continue;
        final labelFacts = decoded['label_facts'];
        if (labelFacts is! List) continue;
        for (final item in labelFacts.whereType<Map>()) {
          facts.add(
            ProjectedDrugLabelFact(
              factType: '${item['fact_type'] ?? ''}',
              label: '${item['label'] ?? ''}',
              valueText: item['value_text']?.toString(),
              sourceSectionKey: item['source_section_key']?.toString(),
              sourceSectionTitle: item['source_section_title']?.toString(),
              sourceExcerpt: item['source_excerpt']?.toString(),
              sourceDocTitle: sourceDoc['title']?.toString(),
            ),
          );
        }
      } catch (_) {
        // raw_payload 允许同时承载不同来源的原始 JSON；
        // 如果某条来源没有 label_facts，就在详情投影里安全忽略。
      }
    }
    return facts;
  }

  FoodCategory _inferFoodCategory(String foodGroup) {
    final lower = foodGroup.toLowerCase();
    if (lower.contains('fruit')) return FoodCategory.fruit;
    if (lower.contains('vegetable')) return FoodCategory.vegetable;
    if (lower.contains('dairy')) return FoodCategory.dairy;
    if (lower.contains('oil') || lower.contains('fat')) return FoodCategory.fat;
    if (lower.contains('beverage')) return FoodCategory.beverage;
    if (lower.contains('protein') ||
        lower.contains('meat') ||
        lower.contains('fish') ||
        lower.contains('legume')) {
      return FoodCategory.protein;
    }
    if (lower.contains('grain') ||
        lower.contains('cereal') ||
        lower.contains('starch') ||
        lower.contains('carb')) {
      return FoodCategory.carbs;
    }
    return FoodCategory.other;
  }

  String _buildFoodProjectionDescription({
    required String sourceFamily,
    required String jurisdiction,
    required Map<String, double> nutrients,
    String? fallbackWarning,
  }) {
    final details = <String>[
      '$sourceFamily/$jurisdiction',
      if (nutrients.containsKey('fiber_g'))
        'fiber ${nutrients['fiber_g']!.toStringAsFixed(1)} g',
      if (nutrients.containsKey('fat_g'))
        'fat ${nutrients['fat_g']!.toStringAsFixed(1)} g',
      if (nutrients.containsKey('sodium_mg'))
        'sodium ${nutrients['sodium_mg']!.toStringAsFixed(0)} mg',
      if (fallbackWarning != null) 'warning $fallbackWarning',
    ];
    return 'Projected from CDSS food_variant + observation (${details.join(', ')}).';
  }

  String _attributeLabel(String attributeCode) {
    switch (attributeCode) {
      case 'protein_g':
        return 'Protein';
      case 'carbohydrate_g':
        return 'Carbohydrate';
      case 'fat_g':
        return 'Fat';
      case 'fiber_g':
        return 'Fiber';
      case 'sugars_total_g':
        return 'Sugars';
      case 'iron_mg':
        return 'Iron';
      case 'sodium_mg':
        return 'Sodium';
      default:
        return attributeCode;
    }
  }
}

class ProjectedFoodDetail {
  final FoodItem food;
  final List<String> variantIds;
  final List<ProjectedNutrientLine> nutrientLines;
  final List<String> sourceTitles;

  const ProjectedFoodDetail({
    required this.food,
    required this.variantIds,
    required this.nutrientLines,
    required this.sourceTitles,
  });
}

class ProjectedNutrientLine {
  final String attributeCode;
  final String displayLabel;
  final String rawValueText;
  final String unit;
  final String qualifierKind;
  final String? methodCode;
  final String? sourceDocTitle;

  const ProjectedNutrientLine({
    required this.attributeCode,
    required this.displayLabel,
    required this.rawValueText,
    required this.unit,
    required this.qualifierKind,
    this.methodCode,
    this.sourceDocTitle,
  });
}

class ProjectedDrugDetail {
  final DrugDefinition drug;
  final List<String> variantIds;
  final List<ProjectedDrugSection> sections;
  final List<String> packagingDescriptions;
  final List<String> mediaLinks;
  final List<ProjectedDrugLabelFact> labelFacts;

  const ProjectedDrugDetail({
    required this.drug,
    required this.variantIds,
    required this.sections,
    required this.packagingDescriptions,
    required this.mediaLinks,
    required this.labelFacts,
  });
}

class ProjectedDrugSection {
  final String sectionKey;
  final String sectionTitle;
  final String sectionText;
  final String? sourceDocTitle;

  const ProjectedDrugSection({
    required this.sectionKey,
    required this.sectionTitle,
    required this.sectionText,
    this.sourceDocTitle,
  });
}

class ProjectedDrugLabelFact {
  final String factType;
  final String label;
  final String? valueText;
  final String? sourceSectionKey;
  final String? sourceSectionTitle;
  final String? sourceExcerpt;
  final String? sourceDocTitle;

  const ProjectedDrugLabelFact({
    required this.factType,
    required this.label,
    this.valueText,
    this.sourceSectionKey,
    this.sourceSectionTitle,
    this.sourceExcerpt,
    this.sourceDocTitle,
  });
}

DrugTag? inferDrugTag(String genericName) {
  final lower = genericName.toLowerCase();
  if (lower.contains('levodopa')) return DrugTag.levodopaLike;
  if (lower.contains('entacapone') ||
      lower.contains('tolcapone') ||
      lower.contains('opicapone')) {
    return DrugTag.comtInhibitor;
  }
  if (lower.contains('rasagiline') ||
      lower.contains('selegiline') ||
      lower.contains('safinamide')) {
    return DrugTag.maoi;
  }
  if (lower.contains('pramipexole') ||
      lower.contains('ropinirole') ||
      lower.contains('rotigotine') ||
      lower.contains('apomorphine')) {
    return DrugTag.dopamineAgonist;
  }
  if (lower.contains('istradefylline')) return DrugTag.adenosineA2aAntagonist;
  if (lower.contains('amantadine')) return DrugTag.amantadineLike;
  if (lower.contains('rivastigmine')) return DrugTag.cholinesteraseInhibitor;
  if (lower.contains('droxidopa') || lower.contains('midodrine')) {
    return DrugTag.pressorAgent;
  }
  if (lower.contains('peg')) return DrugTag.laxative;
  if (lower.contains('iron')) return DrugTag.mineralSupplement;
  return null;
}
