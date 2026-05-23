import '../../../core/models/food_item.dart';
import '../../../core/utils/texture_support.dart';
import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';
import 'crosswalk_builders.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'source_fetch_client.dart';

/// 中国 CDC 食物营养成分查询平台导入器。
///
/// 当前策略：
/// - 只抓取已核验的官方 `foodinfo/{id}.html` 页面；
/// - 明确保留“未经许可不得用于商业目的”的站点声明；
/// - 在未确认官方 bulk ZIP / API 前，不把这个页面级导入伪装成国家级整库出口。
///
/// 已知边界：
/// - 当前是受控页面集 importer，不是开放式站点爬虫；
/// - 页面字段结构若变化，需补测试与解析器；
/// - 当前只抽取 P0 推荐与搜索最有价值的核心营养字段。
class ChinaCdcFoodPlatformImporter {
  final SourceFetchClient fetchClient;

  const ChinaCdcFoodPlatformImporter({required this.fetchClient});

  /// 受控官方页面清单：
  /// - 每个条目都要求先通过官方页面模式核验；
  /// - 当前只扩到“常见中国饮食场景里高价值”的代表性食物，不伪装成整库镜像。
  static const selectedFoodPages = <_ChinaFoodSeed>[
    _ChinaFoodSeed(
      key: 'tofu_average',
      url: P0SourceUrls.chinaFoodTofuAverage,
    ),
    _ChinaFoodSeed(
      key: 'rice_steamed_average',
      url: P0SourceUrls.chinaFoodRiceSteamedAverage,
    ),
    _ChinaFoodSeed(
      key: 'mantou_average',
      url: P0SourceUrls.chinaFoodMantouAverage,
    ),
    _ChinaFoodSeed(
      key: 'noodles_average',
      url: P0SourceUrls.chinaFoodNoodlesAverage,
    ),
    _ChinaFoodSeed(
      key: 'millet_porridge',
      url: P0SourceUrls.chinaFoodMilletPorridge,
    ),
    _ChinaFoodSeed(
      key: 'soy_milk',
      url: P0SourceUrls.chinaFoodSoyMilk,
    ),
    _ChinaFoodSeed(
      key: 'egg_average',
      url: P0SourceUrls.chinaFoodEggAverage,
    ),
    _ChinaFoodSeed(
      key: 'apple_guoguang',
      url: P0SourceUrls.chinaFoodAppleGuoguang,
    ),
    _ChinaFoodSeed(
      key: 'banana',
      url: P0SourceUrls.chinaFoodBanana,
    ),
    _ChinaFoodSeed(
      key: 'spinach',
      url: P0SourceUrls.chinaFoodSpinach,
    ),
    _ChinaFoodSeed(
      key: 'pork_tenderloin',
      url: P0SourceUrls.chinaFoodPorkTenderloin,
    ),
    _ChinaFoodSeed(
      key: 'xiao_bai_cai',
      url: P0SourceUrls.chinaFoodXiaoBaiCai,
    ),
    _ChinaFoodSeed(
      key: 'you_tiao',
      url: P0SourceUrls.chinaFoodYouTiao,
    ),
  ];

  /// 公开静态 URL 列表，方便 orchestrator 在 resume notes 里记录。
  static List<String> get selectedFoodUrls =>
      selectedFoodPages.map((seed) => seed.url).toList(growable: false);

  Future<P0ImportBundle> fetchSelectedFoods() async {
    var bundle = const P0ImportBundle();
    for (final seed in selectedFoodPages) {
      final html = await fetchClient.getText(seed.url);
      bundle = bundle.merge(importFoodPage(url: seed.url, html: html));
    }
    return bundle;
  }

  P0ImportBundle importFoodPage({
    required String url,
    required String html,
  }) {
    final page = _parsePage(url, html);
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'CHINA_CDC_FOOD_PLATFORM',
      externalKey: page.externalFoodCode,
    );
    final conceptId = buildFoodConceptId(page.displayName);
    final variantId = buildFoodVariantId(
      conceptId: conceptId,
      jurisdiction: 'CN',
      sourceSystem: 'CHINA_CDC_FOOD_PLATFORM',
      sourceFoodCode: page.externalFoodCode,
    );
    final scopeHash = buildScopeHash('$variantId:china_cdc_foodinfo');

    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'CHINA_CDC_FOOD_PLATFORM',
      organization: 'China CDC NINH',
      jurisdiction: 'CN',
      docType: 'html_food_page',
      title: page.displayName,
      originUrl: url,
      licenseNote: 'Official platform states non-commercial use restriction.',
      language: 'zh',
      sourceStatus: 'official_query_page_noncommercial',
      dataTier: KnowledgeDataTier.p1,
      ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
      rawPayload: html,
    );

    final observations = <ObservationRecord>[];
    final resolvedFacts = <ResolvedFactRecord>[];
    for (final entry in page.attributeValues.entries) {
      final qualified = _toQualifiedValue(entry.value);
      final attributeCode = entry.key.$1;
      final unit = entry.key.$2;
      final observation = ObservationRecord(
        observationId:
            'obs_${stableHash('$variantId:$attributeCode:${entry.value}')}',
        domain: 'food',
        entityType: 'food_variant',
        entityKey: variantId,
        attributeCode: attributeCode,
        valueType: 'numeric_interval',
        value: qualified,
        unit: unit,
        basisType: 'per_100g_edible_part',
        basisAmount: 100,
        scopeHash: scopeHash,
        sourceDocId: sourceDocId,
        recordLocator: url,
        methodCode: 'china_cdc_foodinfo_html',
        extractionConfidence: 0.95,
      );
      observations.add(observation);
      resolvedFacts.add(
        resolvedFactFromObservation(
          observation: observation,
          policyId: 'china_cdc_foodinfo_import_v1',
          snapshotId: 'facts_china_cdc_foodinfo_import_v1',
        ),
      );
    }

    final textureClass = inferTextureClassFromText(
      name: page.displayName,
      description: '${page.foodGroup} ${page.subGroup}',
      categoryName: page.foodGroup,
    );
    final projectedFood = FoodItem(
      id: 'food_cn_${page.externalFoodCode}',
      name: page.displayName,
      category: inferFoodCategory(page.foodGroup),
      aliases: <String>[
        page.displayName,
        if (page.subGroup.isNotEmpty) page.subGroup,
      ],
      description:
          'Imported from China CDC food composition query platform (${page.foodGroup}/${page.subGroup}).',
      sourceSystem: 'CHINA_CDC_FOOD_PLATFORM',
      sourceFoodCode: page.externalFoodCode,
      jurisdiction: 'CN',
      textureClass: textureClass,
      iddsiLevel: inferIddsiLevelFromTextureClass(textureClass),
      proteinG:
          displayValueFromRaw(page.attributeValues[('protein_g', 'g')] ?? '0'),
      carbsG: displayValueFromRaw(
          page.attributeValues[('carbohydrate_g', 'g')] ?? '0'),
      fatG: displayValueFromRaw(page.attributeValues[('fat_g', 'g')] ?? '0'),
      fiberG:
          displayValueFromRaw(page.attributeValues[('fiber_g', 'g')] ?? '0'),
      sodiumMg:
          displayValueFromRaw(page.attributeValues[('sodium_mg', 'mg')] ?? '0'),
    );

    return P0ImportBundle(
      sourceDocuments: <SourceDocumentRecord>[sourceDocument],
      foodConcepts: <FoodConceptRecord>[
        FoodConceptRecord(
          foodConceptId: conceptId,
          canonicalNameEn: page.displayName,
          canonicalNameZh: page.displayName,
          foodGroup: page.foodGroup,
        ),
      ],
      foodVariants: <FoodVariantRecord>[
        FoodVariantRecord(
          foodVariantId: variantId,
          foodConceptId: conceptId,
          jurisdiction: 'CN',
          sourceFamily: 'CHINA_CDC_FOOD_PLATFORM',
          sourceFoodCode: page.externalFoodCode,
          displayNameLocal: page.displayName,
          isAuthoritativeForRegion: true,
          isAuthoritativeFallback: false,
          status: 'imported_china_cdc_food_page',
          fallbackChainJson: '["CN","GLOBAL"]',
        ),
      ],
      variantScopes: <VariantScopeRecord>[
        VariantScopeRecord(
          scopeHash: scopeHash,
          jurisdiction: 'CN',
          brand: null,
          dosageForm: null,
          releaseType: null,
          saltForm: null,
          route: null,
          preparationState: 'as_listed_on_official_page',
          cookingState: null,
          plantPart: null,
          cultivar: null,
          samplingFrame: 'china_cdc_foodinfo_selected_page',
        ),
      ],
      observations: observations,
      resolvedFacts: resolvedFacts,
      conceptVariantCrosswalks: <ConceptVariantCrosswalkRecord>[
        buildCrosswalk(
          domain: 'food',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'China CDC food page id',
          externalIdValue: page.externalFoodCode,
          jurisdiction: 'CN',
          sourceDocId: sourceDocId,
          confidence: 0.9,
          mappingPayload: {
            'name': page.displayName,
            'food_group': page.foodGroup,
            'sub_group': page.subGroup,
            'origin_url': url,
            'audit_note':
                'Source code derived from official foodinfo URL; not a national bulk identifier.',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType: ImporterAudit.sourceIdTypePageIdentifier,
              reason:
                  'Identifier extracted from /foodinfo/{id}.html URL path; this is a page identifier, NOT a national food code.',
              promotionDecision:
                  'page_identifier_only_no_promotion_to_national_code',
              parserLimitation:
                  'No authoritative China-CDC bulk identifier is published; importer does not synthesize one.',
            ),
          },
        ),
      ],
      projectedFoods: <FoodItem>[projectedFood],
    );
  }

  _ChinaFoodPage _parsePage(String url, String html) {
    final normalized = _normalizeText(html);
    final title = _firstNonEmptyLine(normalized) ??
        _firstMatch(normalized, RegExp(r'5\.\s*([^\n]+)')) ??
        '中国食物';
    final foodGroup = _firstMatch(
          normalized,
          RegExp(r'食物类：([^\s]+)'),
        ) ??
        'other';
    final subGroup = _firstMatch(
          normalized,
          RegExp(r'亚\s*类：([^\s]+)'),
        ) ??
        '';
    final pageCode =
        RegExp(r'/foodinfo/(\d+)\.html').firstMatch(url)?.group(1) ??
            stableHash(url);

    final attributeValues = <(String, String), String>{};
    for (final mapping in _attributeMap.entries) {
      final token = _extractValue(normalized, mapping.key);
      if (token == null) continue;
      attributeValues[mapping.value] = token;
    }

    return _ChinaFoodPage(
      externalFoodCode: pageCode,
      displayName: title.trim(),
      foodGroup: foodGroup.trim(),
      subGroup: subGroup.trim(),
      attributeValues: attributeValues,
    );
  }

  QualifiedValue _toQualifiedValue(String raw) {
    final normalized = raw.trim();
    if (normalized == 'Tr' || normalized == 'tr') {
      return parseQualifiedValue('trace');
    }
    if (normalized == '—') {
      return parseQualifiedValue('-');
    }
    final numeric =
        RegExp(r'^([<>]?\=?\s*[0-9]+(?:\.[0-9]+)?)').firstMatch(normalized);
    if (numeric != null) {
      return parseQualifiedValue(numeric.group(1));
    }
    return parseQualifiedValue(normalized);
  }

  String _normalizeText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), '\n');
  }

  String? _firstMatch(String text, RegExp pattern) {
    return pattern.firstMatch(text)?.group(1);
  }

  String? _firstNonEmptyLine(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String? _extractValue(String normalizedText, String label) {
    final match = RegExp(
      '${RegExp.escape(label)}\\s+([^\\n]+)',
      caseSensitive: false,
    ).firstMatch(normalizedText);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw == 'Tr' || raw == 'tr' || raw == '—') {
      return raw;
    }
    final numeric =
        RegExp(r'^[<>]?\=?\s*[0-9]+(?:\.[0-9]+)?').firstMatch(raw)?.group(0);
    return numeric ?? raw;
  }
}

class _ChinaFoodSeed {
  final String key;
  final String url;

  const _ChinaFoodSeed({
    required this.key,
    required this.url,
  });
}

class _ChinaFoodPage {
  final String externalFoodCode;
  final String displayName;
  final String foodGroup;
  final String subGroup;
  final Map<(String, String), String> attributeValues;

  const _ChinaFoodPage({
    required this.externalFoodCode,
    required this.displayName,
    required this.foodGroup,
    required this.subGroup,
    required this.attributeValues,
  });
}

const _attributeMap = <String, (String, String)>{
  '食部(Edible)': ('edible_pct', '%'),
  '能量(Energy)': ('energy_kj', 'kJ'),
  '蛋白质(Protein)': ('protein_g', 'g'),
  '脂肪(Fat)': ('fat_g', 'g'),
  '碳水化合物(CHO)': ('carbohydrate_g', 'g'),
  '总膳食纤维(Dietary fiber)': ('fiber_g', 'g'),
  '钠(Na)': ('sodium_mg', 'mg'),
  '钙(Ca)': ('calcium_mg', 'mg'),
  '钾(K)': ('potassium_mg', 'mg'),
  '铁(Fe)': ('iron_mg', 'mg'),
  '维生素C(Vitamin C)': ('vitamin_c_mg', 'mg'),
};
