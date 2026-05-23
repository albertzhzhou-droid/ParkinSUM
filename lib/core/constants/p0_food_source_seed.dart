import 'dart:convert';

import '../models/food_item.dart';
import '../../domain/entities/cdss_records.dart';
import '../utils/qualified_value_parser.dart';
import '../utils/texture_support.dart';
import 'clinical_evidence_source_seed.dart';

/// Local bootstrap bundle for the CDSS knowledge base.
///
/// This is intentionally a bootstrap layer, not the final ETL output.
/// 这里的内容主要用于把数据库、变体解析和规则引擎主链路先接通。
/// 真正上线所需的完整官方数据，仍应来自正式的源抓取与入库流程。
class KnowledgeBaseSeedBundle {
  final List<SourceDocumentRecord> sourceDocuments;
  final List<FoodConceptRecord> foodConcepts;
  final List<FoodVariantRecord> foodVariants;
  final List<VariantScopeRecord> variantScopes;
  final List<ObservationRecord> observations;
  final List<ResolvedFactRecord> resolvedFacts;

  const KnowledgeBaseSeedBundle({
    required this.sourceDocuments,
    required this.foodConcepts,
    required this.foodVariants,
    required this.variantScopes,
    required this.observations,
    required this.resolvedFacts,
  });
}

const p0SourceDocumentSeed = <SourceDocumentRecord>[
  SourceDocumentRecord(
    sourceDocId: 'source_ciqual_2025_dataset',
    sourceFamily: 'CIQUAL',
    organization: 'ANSES',
    jurisdiction: 'FR',
    docType: 'dataset_index',
    title: 'Ciqual 2025 dataset',
    originUrl:
        'https://entrepot.recherche.data.gouv.fr/dataset.xhtml?persistentId=doi:10.57745/RDMHWY',
    publishedAt: null,
    effectiveAt: null,
    language: 'fr-FR',
    licenseNote: 'Etalab Open License 2.0',
    checksum: 'ciqual_2025_dataset',
    sourceStatus: 'active',
    rawPayload:
        '{"dataset_doi":"10.57745/RDMHWY","formats":["XML","XLS","XLSX","PDF"]}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_ciqual_2025_xlsx',
    sourceFamily: 'CIQUAL',
    organization: 'ANSES',
    jurisdiction: 'FR',
    docType: 'xlsx',
    title: 'Table Ciqual 2025 FR',
    originUrl:
        'https://entrepot.recherche.data.gouv.fr/api/access/datafile/:persistentId?persistentId=doi:10.57745/RPWYZD',
    publishedAt: null,
    effectiveAt: null,
    language: 'fr-FR',
    licenseNote: 'Etalab Open License 2.0',
    checksum: 'ciqual_2025_xlsx_rpwyzd',
    sourceStatus: 'active',
    rawPayload:
        '{"file_doi":"10.57745/RPWYZD","suggested_file":"Table Ciqual 2025_FR_2025_11_03.xlsx"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_fdc_api_guide',
    sourceFamily: 'USDA_FDC',
    organization: 'USDA',
    jurisdiction: 'US',
    docType: 'api_guide',
    title: 'FoodData Central API Guide',
    originUrl: 'https://fdc.nal.usda.gov/api-guide',
    publishedAt: null,
    effectiveAt: null,
    language: 'en-US',
    licenseNote: 'CC0 1.0',
    checksum: 'fdc_api_guide',
    sourceStatus: 'active',
    rawPayload:
        '{"formats":["JSON"],"api_requires":"data.gov api key","rate_limit":"1000 requests/hour/IP"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_fdc_foundation_2025_json',
    sourceFamily: 'USDA_FDC',
    organization: 'USDA',
    jurisdiction: 'US',
    docType: 'zip_json',
    title: 'FoodData Central Foundation Foods JSON 2025-12-18',
    originUrl:
        'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2025-12-18.zip',
    publishedAt: null,
    effectiveAt: null,
    language: 'en-US',
    licenseNote: 'CC0 1.0',
    checksum: 'fdc_foundation_json_2025_12_18',
    sourceStatus: 'active',
    rawPayload: '{"data_type":"Foundation Foods","format":"ZIP(JSON)"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_foodexplorer_portal',
    sourceFamily: 'FOODEXPLORER',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.controlledExport,
    organization: 'EuroFIR AISBL',
    jurisdiction: 'EU',
    docType: 'portal',
    title: 'FoodEXplorer access portal',
    originUrl: 'https://www.eurofir.org/our-tools/foodexplorer/',
    publishedAt: null,
    effectiveAt: null,
    language: 'en',
    licenseNote: 'Access controlled; national licence may apply',
    checksum: 'foodexplorer_portal',
    sourceStatus: 'access_controlled',
    rawPayload:
        '{"formats":["FDTP","Excel"],"access":"member_or_pay_per_view"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_ebasis_portal',
    sourceFamily: 'EBASIS',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.controlledExport,
    organization: 'EuroFIR AISBL',
    jurisdiction: 'EU',
    docType: 'portal',
    title: 'eBASIS access portal',
    originUrl: 'http://ebasis.eurofir.org/',
    publishedAt: null,
    effectiveAt: null,
    language: 'en',
    licenseNote: 'Access controlled; redistribution terms unspecified',
    checksum: 'ebasis_portal',
    sourceStatus: 'access_controlled',
    rawPayload:
        '{"format":"spreadsheet_export","query_dimensions":["compound","food","bioeffect"]}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_fao_fbdg_index',
    sourceFamily: 'FAO_FBDG',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'FAO',
    jurisdiction: 'GLOBAL',
    docType: 'html_index',
    title: 'FAO Food-Based Dietary Guidelines index',
    originUrl:
        'https://www.fao.org/nutrition/nutrition-education/food-dietary-guidelines/en/',
    publishedAt: null,
    effectiveAt: null,
    language: 'en',
    licenseNote: 'UNSPECIFIED',
    checksum: 'fao_fbdg_index',
    sourceStatus: 'active',
    rawPayload: '{"resource_type":"country_diet_profile_source"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_china_food_expression_standard',
    sourceFamily: 'CHINA_FCD_STANDARD',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'National Health Commission of the PRC',
    jurisdiction: 'CN',
    docType: 'standard_page',
    title: 'WS/T 464-2015 食物成分数据表达规范',
    originUrl:
        'https://www.nhc.gov.cn/wjw/yingyang/201505/3cbe4ecd6e48465899557a25a5ae1be9.shtml',
    publishedAt: null,
    effectiveAt: null,
    language: 'zh-CN',
    licenseNote: 'UNSPECIFIED',
    checksum: 'china_food_expression_standard_wst464_2015',
    sourceStatus: 'active_reference',
    rawPayload:
        '{"standard_id":"WS/T 464-2015","notes":"Defines food component naming, coding, qualifier semantics, and data expression rules for Chinese food composition data."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_china_food_monitoring_network',
    sourceFamily: 'CHINA_FCD_NETWORK',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'China CDC / National Institute for Nutrition and Health',
    jurisdiction: 'CN',
    docType: 'program_page',
    title: 'China national food composition data network overview',
    originUrl: 'https://www.chinacdc.cn/gzdt/zsdw/202509/t20250929_312801.html',
    publishedAt: null,
    effectiveAt: null,
    language: 'zh-CN',
    licenseNote: 'UNSPECIFIED',
    checksum: 'china_food_monitoring_network_overview_2025',
    sourceStatus: 'active_reference',
    rawPayload:
        '{"network_scope":"31 provinces","notes":"Official page confirms a national food composition monitoring network covering major consumed foods and regional specialty foods, but no stable public bulk-download endpoint is specified."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_china_fbdg_2022_fao',
    sourceFamily: 'FAO_FBDG',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'FAO',
    jurisdiction: 'CN',
    docType: 'html_country_page',
    title: 'Food-based dietary guidelines - China',
    originUrl:
        'https://www.fao.org/nutrition/education/food-dietary-guidelines/regions/countries/China/en',
    publishedAt: null,
    effectiveAt: null,
    language: 'en',
    licenseNote: 'UNSPECIFIED',
    checksum: 'fao_china_fbdg_2022',
    sourceStatus: 'active',
    rawPayload:
        '{"official_name":"Dietary Guidelines for Chinese (2022)","messages":["vegetables","fruits","dairy","whole_grains","soybeans","fish","poultry","eggs","lean_meat","limit_salt_sugar_oil","adequate_water"]}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_china_dietary_guidelines_2022_nhc_reply',
    sourceFamily: 'CHINA_DIET_GUIDANCE',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'National Health Commission of the PRC',
    jurisdiction: 'CN',
    docType: 'policy_reply',
    title: 'NHC reply referencing Dietary Guidelines for Chinese (2022)',
    originUrl:
        'https://www.nhc.gov.cn/wjw/jiany/202301/bd6c614391274ebd955fc9018f2032a2.shtml',
    publishedAt: null,
    effectiveAt: null,
    language: 'zh-CN',
    licenseNote: 'UNSPECIFIED',
    checksum: 'china_dietary_guidelines_2022_nhc_reply',
    sourceStatus: 'active_reference',
    rawPayload:
        '{"messages":["foods_variety","vegetables","fruits","dairy","whole_grains","soybeans","tubers"],"notes":"Official NHC reply summarises the 2022 dietary guideline emphasis and intake ranges for grains, whole grains, legumes, and tubers."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_china_reduce_oil_increase_beans_milk_2024',
    sourceFamily: 'CHINA_DIET_GUIDANCE',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'National Health Commission of the PRC',
    jurisdiction: 'CN',
    docType: 'guidance_notice',
    title: 'Reduce oil, increase beans, add milk core information',
    originUrl:
        'https://www.nhc.gov.cn/sps/c100087/202404/90c64c79708740a1bca0ee31e524caf7.shtml',
    publishedAt: null,
    effectiveAt: null,
    language: 'zh-CN',
    licenseNote: 'UNSPECIFIED',
    checksum: 'china_reduce_oil_increase_beans_milk_2024',
    sourceStatus: 'active_reference',
    rawPayload:
        '{"messages":["soybeans","tofu","soy_milk","milk","low_oil"],"notes":"Official NHC core messages provide China-specific daily soybean and dairy guidance with tofu and soy milk equivalence examples."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_china_food_composition_table_authority_reference',
    sourceFamily: 'CHINA_FCD_REFERENCE',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'National Health Commission of the PRC',
    jurisdiction: 'CN',
    docType: 'reference_page',
    title: 'NHC reference page for 中国食物成分表',
    originUrl:
        'https://www.nhc.gov.cn/wjw/zcjd/201207/7b021c922308465d94bd2ae5aa32c375.shtml',
    publishedAt: null,
    effectiveAt: null,
    language: 'zh-CN',
    licenseNote: 'UNSPECIFIED',
    checksum: 'china_food_composition_table_authority_reference',
    sourceStatus: 'active_reference',
    rawPayload:
        '{"notes":"Official NHC Q&A treats 中国食物成分表 as an authoritative reference for nutrient values in common foods. However, this page still does not publish a stable machine-readable national bulk package or API. Until such an export is verified, China-specific foods should stay at source-metadata/search/template level rather than being auto-promoted into authoritative observation rows."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_nmpa_portal_pending',
    sourceFamily: 'NMPA',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.futurePlanned,
    organization: 'National Medical Products Administration',
    jurisdiction: 'CN',
    docType: 'portal',
    title: 'NMPA public service portal',
    originUrl: 'https://zwfw.nmpa.gov.cn/web/index',
    publishedAt: null,
    effectiveAt: null,
    language: 'zh-CN',
    licenseNote: 'UNSPECIFIED',
    checksum: 'nmpa_portal_pending',
    sourceStatus: 'pending_structured_endpoint',
    rawPayload:
        '{"notes":"Public national regulator portal confirmed, but this project has not yet verified a DailyMed-like stable structured drug label bulk endpoint for automated P0 ingestion."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_dailymed_web_services',
    sourceFamily: 'DAILYMED',
    organization: 'National Library of Medicine',
    jurisdiction: 'US',
    docType: 'api_guide',
    title: 'DailyMed web services entry',
    originUrl:
        'https://dailymed.nlm.nih.gov/dailymed/app-support-web-services.cfm',
    publishedAt: null,
    effectiveAt: null,
    language: 'en-US',
    licenseNote: 'UNSPECIFIED',
    checksum: 'dailymed_web_services',
    sourceStatus: 'active',
    rawPayload: '{"formats":["JSON","XML","ZIP","PDF"]}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_drugsatfda_zip',
    sourceFamily: 'DRUGSATFDA',
    organization: 'U.S. Food and Drug Administration',
    jurisdiction: 'US',
    docType: 'zip',
    title: 'Drugs@FDA data files',
    originUrl:
        'https://www.fda.gov/drugs/drug-approvals-and-databases/drugsfda-data-files',
    publishedAt: null,
    effectiveAt: null,
    language: 'en-US',
    licenseNote: 'UNSPECIFIED',
    checksum: 'drugsatfda_zip',
    sourceStatus: 'active',
    rawPayload:
        '{"suggested_file":"drugsatfda.zip","format":"ZIP->tab_delimited_TXT"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_ema_medicines_xlsx',
    sourceFamily: 'EMA',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
    organization: 'European Medicines Agency',
    jurisdiction: 'EU',
    docType: 'xlsx',
    title: 'EMA medicines output report',
    originUrl:
        'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines-report_en.xlsx',
    publishedAt: null,
    effectiveAt: null,
    language: 'en',
    licenseNote: 'UNSPECIFIED',
    checksum: 'ema_medicines_xlsx',
    sourceStatus: 'active',
    rawPayload: '{"formats":["XLSX","JSON","HTML"]}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_health_canada_dpd_api',
    sourceFamily: 'HEALTH_CANADA_DPD',
    organization: 'Health Canada',
    jurisdiction: 'CA',
    docType: 'api_guide',
    title: 'Health Canada DPD API',
    originUrl:
        'https://health-products.canada.ca/api/documentation/dpd-documentation-en.html',
    publishedAt: null,
    effectiveAt: null,
    language: 'en-CA',
    licenseNote: 'UNSPECIFIED',
    checksum: 'health_canada_dpd_api',
    sourceStatus: 'active',
    rawPayload: '{"formats":["JSON","XML","ZIP"]}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_pmda_epack_index',
    sourceFamily: 'PMDA',
    dataTier: KnowledgeDataTier.p1,
    ingestionStrategy: SourceIngestionStrategy.officialReference,
    organization: 'Pharmaceuticals and Medical Devices Agency',
    jurisdiction: 'JP',
    docType: 'html_index',
    title: 'PMDA e-package insert information',
    originUrl:
        'https://www.pmda.go.jp/english/safety/info-services/e-pack-ins/0001.html',
    publishedAt: null,
    effectiveAt: null,
    language: 'en-JP',
    licenseNote:
        'English translation reference only; Japanese original prevails',
    checksum: 'pmda_epack_index',
    sourceStatus: 'reference_only',
    rawPayload:
        '{"english_reference_only":true,"japanese_primary_url":"https://www.pmda.go.jp/safety/info-services/0003.html"}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_future_p3_specialized_registry',
    sourceFamily: 'P3_FUTURE_REGISTRY',
    dataTier: KnowledgeDataTier.p3,
    ingestionStrategy: SourceIngestionStrategy.futurePlanned,
    organization: 'ParkinSUM Planning Registry',
    jurisdiction: 'GLOBAL',
    docType: 'future_plan',
    title: 'Planned P3 specialized registry layer',
    originUrl: 'about:parkinsum/p3-planned-layer',
    publishedAt: null,
    effectiveAt: null,
    language: 'und',
    licenseNote: 'Internal planning placeholder only',
    checksum: 'future_p3_specialized_registry',
    sourceStatus: 'planned',
    rawPayload:
        '{"notes":"Reserved tier for future specialist registries or disease-specific structured datasets after authority and reproducible export are verified."}',
  ),
  SourceDocumentRecord(
    sourceDocId: 'source_future_p4_exploratory_evidence',
    sourceFamily: 'P4_FUTURE_REGISTRY',
    dataTier: KnowledgeDataTier.p4,
    ingestionStrategy: SourceIngestionStrategy.futurePlanned,
    organization: 'ParkinSUM Planning Registry',
    jurisdiction: 'GLOBAL',
    docType: 'future_plan',
    title: 'Planned P4 exploratory evidence layer',
    originUrl: 'about:parkinsum/p4-planned-layer',
    publishedAt: null,
    effectiveAt: null,
    language: 'und',
    licenseNote: 'Internal planning placeholder only',
    checksum: 'future_p4_exploratory_evidence',
    sourceStatus: 'planned',
    rawPayload:
        '{"notes":"Reserved tier for future exploratory or lower-authority evidence once governance, review thresholds, and ingestion policy are finalized."}',
  ),
];

class _P0FoodSeed {
  final String appFoodId;
  final String conceptId;
  final String canonicalNameEn;
  final String canonicalNameZh;
  final String foodGroup;
  final String displayNameLocal;
  final String sourceFoodCode;
  final String sourceDocId;
  final String preparationState;
  final String cookingState;
  final Map<String, String> nutrients;

  const _P0FoodSeed({
    required this.appFoodId,
    required this.conceptId,
    required this.canonicalNameEn,
    required this.canonicalNameZh,
    required this.foodGroup,
    required this.displayNameLocal,
    required this.sourceFoodCode,
    required this.sourceDocId,
    required this.preparationState,
    required this.cookingState,
    required this.nutrients,
  });
}

/// Curated P0 food subset used by the current app experience.
///
/// 未完成说明：
/// 1. 这里只覆盖当前“添加一餐”与基础冲突规则需要的高优先级食物，不是完整底库。
/// 2. 当前主要落的是 FR/Ciqual 侧的种子，US/FDC 等多辖区 food variant 尚未在这里并行铺满。
/// 3. 当整理资料里没有稳定外部主键时，先保留 `UNSPECIFIED_*`，避免伪造 source code。
const _p0FoodSeeds = <_P0FoodSeed>[
  _P0FoodSeed(
    appFoodId: 'food_banana',
    conceptId: 'FOOD_FOOD_BANANA',
    canonicalNameEn: 'banana',
    canonicalNameZh: '香蕉',
    foodGroup: 'fruit',
    displayNameLocal: '香蕉',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_BANANA',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'raw',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '1.06',
      'carbohydrate_g': '19.7',
      'fat_g': '<0.5',
      'fiber_g': '2.7',
      'iron_mg': 'UNSPECIFIED',
      'potassium_mg': '320',
      'vitamin_b6_mg': '0.18',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_spinach',
    conceptId: 'FOOD_FOOD_SPINACH',
    canonicalNameEn: 'spinach',
    canonicalNameZh: '菠菜',
    foodGroup: 'vegetable',
    displayNameLocal: '菠菜',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_SPINACH',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'raw',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '2.62',
      'carbohydrate_g': '2.25',
      'fat_g': '0.5',
      'fiber_g': '2.37',
      'iron_mg': '3.61',
      'potassium_mg': '504',
      'folate_ug': '207',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_tofu',
    conceptId: 'FOOD_FOOD_TOFU',
    canonicalNameEn: 'tofu, plain',
    canonicalNameZh: '原味豆腐',
    foodGroup: 'protein',
    displayNameLocal: '原味豆腐',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_TOFU',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'plain',
    cookingState: 'unspecified',
    nutrients: {
      'protein_g': '14.1',
      'carbohydrate_g': '1.2',
      'fat_g': '8.7',
      'fiber_g': '2.3',
      'iron_mg': '2.87',
      'calcium_mg': '350',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_milk',
    conceptId: 'FOOD_FOOD_MILK',
    canonicalNameEn: 'milk, semi-skimmed',
    canonicalNameZh: '半脱脂牛奶',
    foodGroup: 'dairy',
    displayNameLocal: '半脱脂牛奶',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_MILK',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'liquid',
    cookingState: 'ready_to_drink',
    nutrients: {
      'protein_g': '3.24',
      'carbohydrate_g': '4.85',
      'fat_g': '1.57',
      'fiber_g': '0',
      'calcium_mg': '119',
      'potassium_mg': '151',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_beef',
    conceptId: 'FOOD_FOOD_BEEF',
    canonicalNameEn: 'beef, lean, fried',
    canonicalNameZh: '牛肉（瘦，煎）',
    foodGroup: 'protein',
    displayNameLocal: '牛肉（瘦，煎）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_BEEF',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'lean',
    cookingState: 'fried',
    nutrients: {
      'protein_g': '25.5',
      'carbohydrate_g': '<0.1',
      'fat_g': '10.7',
      'fiber_g': '0',
      'iron_mg': '2.55',
      'potassium_mg': '279',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_chicken_breast',
    conceptId: 'FOOD_FOOD_CHICKEN_BREAST',
    canonicalNameEn: 'chicken breast, cooked',
    canonicalNameZh: '鸡胸肉（熟）',
    foodGroup: 'protein',
    displayNameLocal: '鸡胸肉（熟）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_CHICKEN_BREAST',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'lean',
    cookingState: 'cooked',
    nutrients: {
      'protein_g': '30.1',
      'carbohydrate_g': '0',
      'fat_g': '2',
      'fiber_g': '0',
      'potassium_mg': '440',
      'phosphorus_mg': '251',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_apple',
    conceptId: 'FOOD_FOOD_APPLE',
    canonicalNameEn: 'apple, raw, with skin',
    canonicalNameZh: '苹果，生，带皮',
    foodGroup: 'fruit',
    displayNameLocal: '苹果（带皮）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_APPLE_RAW_WITH_SKIN',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'raw_with_skin',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '0.25',
      'carbohydrate_g': '11.6',
      'fat_g': '0.25',
      'fiber_g': '1.4',
      'iron_mg': '0.099',
      'potassium_mg': '119',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_blueberry',
    conceptId: 'FOOD_FOOD_BLUEBERRY',
    canonicalNameEn: 'blueberry',
    canonicalNameZh: '蓝莓',
    foodGroup: 'fruit',
    displayNameLocal: '蓝莓',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_BLUEBERRY',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'raw',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '0.87',
      'carbohydrate_g': '10.6',
      'fat_g': '0.33',
      'fiber_g': '2.4',
      'iron_mg': '0.28',
      'potassium_mg': '77',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_tomato',
    conceptId: 'FOOD_FOOD_TOMATO',
    canonicalNameEn: 'tomato',
    canonicalNameZh: '番茄',
    foodGroup: 'vegetable',
    displayNameLocal: '番茄',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_TOMATO',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'raw',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '0.86',
      'carbohydrate_g': '2.49',
      'fat_g': '0.26',
      'fiber_g': '1.2',
      'iron_mg': '0.12',
      'potassium_mg': '256',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_broccoli',
    conceptId: 'FOOD_FOOD_BROCCOLI',
    canonicalNameEn: 'broccoli',
    canonicalNameZh: '西兰花',
    foodGroup: 'vegetable',
    displayNameLocal: '西兰花',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_BROCCOLI',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'raw',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '3.95',
      'carbohydrate_g': '1.7',
      'fat_g': '0.48',
      'fiber_g': '2.9',
      'iron_mg': '0.76',
      'potassium_mg': '357',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_oats',
    conceptId: 'FOOD_FOOD_OATS',
    canonicalNameEn: 'rolled oats',
    canonicalNameZh: '燕麦片',
    foodGroup: 'carbs',
    displayNameLocal: '燕麦片',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_OATS',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'rolled',
    cookingState: 'dry',
    nutrients: {
      'protein_g': '13.1',
      'carbohydrate_g': '56.2',
      'fat_g': '7.09',
      'fiber_g': '10.2',
      'iron_mg': '4.72',
      'potassium_mg': '389',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_brown_rice',
    conceptId: 'FOOD_FOOD_BROWN_RICE',
    canonicalNameEn: 'brown rice, cooked',
    canonicalNameZh: '糙米饭',
    foodGroup: 'carbs',
    displayNameLocal: '糙米饭',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_BROWN_RICE',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'cooked_grain',
    cookingState: 'cooked',
    nutrients: {
      'protein_g': '2.73',
      'carbohydrate_g': '29.9',
      'fat_g': '0.98',
      'fiber_g': '1.6',
      'iron_mg': '0.45',
      'potassium_mg': '86',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_salmon',
    conceptId: 'FOOD_FOOD_SALMON',
    canonicalNameEn: 'salmon, farmed, baked',
    canonicalNameZh: '三文鱼（养殖，烤）',
    foodGroup: 'protein',
    displayNameLocal: '三文鱼（养殖，烤）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_SALMON',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'fillet',
    cookingState: 'baked',
    nutrients: {
      'protein_g': '22.1',
      'carbohydrate_g': '0',
      'fat_g': '13.5',
      'fiber_g': '0',
      'potassium_mg': '384',
      'vitamin_b12_ug': '2.65',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_fava_beans',
    conceptId: 'FOOD_FOOD_FAVA_BEANS',
    canonicalNameEn: 'fava beans, fresh',
    canonicalNameZh: '鲜蚕豆',
    foodGroup: 'protein',
    displayNameLocal: '鲜蚕豆',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_FAVA_BEANS',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'fresh_legume',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '6.88',
      'carbohydrate_g': '8.58',
      'fat_g': '0.5',
      'fiber_g': '5.7',
      'iron_mg': '1.14',
      'potassium_mg': '320',
      'vitamin_c_mg': '33',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_potato_boiled',
    conceptId: 'FOOD_FOOD_POTATO_BOILED',
    canonicalNameEn: 'potato, boiled',
    canonicalNameZh: '土豆（水煮）',
    foodGroup: 'carbs',
    displayNameLocal: '土豆（水煮）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_POTATO_BOILED',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'boiled_tuber',
    cookingState: 'boiled',
    nutrients: {
      'protein_g': '1.60',
      'carbohydrate_g': '17',
      'fat_g': '0.10',
      'fiber_g': '1.3',
      'potassium_mg': '374',
      'vitamin_b6_mg': '0.24',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_walnuts',
    conceptId: 'FOOD_FOOD_WALNUTS',
    canonicalNameEn: 'walnuts',
    canonicalNameZh: '核桃仁',
    foodGroup: 'fat',
    displayNameLocal: '核桃仁',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_WALNUTS',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'kernel',
    cookingState: 'raw',
    nutrients: {
      'protein_g': '13.3',
      'carbohydrate_g': '7.01',
      'fat_g': '67.4',
      'fiber_g': '6.7',
      'iron_mg': '2.82',
      'potassium_mg': '454',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_olive_oil',
    conceptId: 'FOOD_FOOD_OLIVE_OIL',
    canonicalNameEn: 'extra virgin olive oil',
    canonicalNameZh: '特级初榨橄榄油',
    foodGroup: 'fat',
    displayNameLocal: '特级初榨橄榄油',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_OLIVE_OIL',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'oil',
    cookingState: 'ready_to_use',
    nutrients: {
      'protein_g': '0',
      'carbohydrate_g': '0',
      'fat_g': '99',
      'fiber_g': '0',
      'vitamin_e_mg': '22.3',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_cheddar_cheese',
    conceptId: 'FOOD_FOOD_CHEDDAR_CHEESE',
    canonicalNameEn: 'cheddar cheese',
    canonicalNameZh: '切达干酪',
    foodGroup: 'dairy',
    displayNameLocal: '切达干酪',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_CHEDDAR',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'aged_cheese',
    cookingState: 'ready_to_eat',
    nutrients: {
      'protein_g': '24',
      'carbohydrate_g': '0',
      'fat_g': '33.8',
      'fiber_g': '0',
      'calcium_mg': '675',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_egg_boiled',
    conceptId: 'FOOD_FOOD_EGG_BOILED',
    canonicalNameEn: 'egg, boiled',
    canonicalNameZh: '鸡蛋（水煮）',
    foodGroup: 'protein',
    displayNameLocal: '鸡蛋（水煮）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_EGG_BOILED',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'whole_egg',
    cookingState: 'boiled',
    nutrients: {
      'protein_g': '13.5',
      'carbohydrate_g': '0.52',
      'fat_g': '8.62',
      'fiber_g': '0',
      'iron_mg': '1.72',
      'vitamin_b12_ug': '1.11',
    },
  ),
  _P0FoodSeed(
    appFoodId: 'food_coffee',
    conceptId: 'FOOD_FOOD_COFFEE',
    canonicalNameEn: 'coffee, brewed, unsweetened',
    canonicalNameZh: '咖啡（现煮，无糖）',
    foodGroup: 'beverage',
    displayNameLocal: '咖啡（现煮，无糖）',
    sourceFoodCode: 'UNSPECIFIED_CIQUAL_COFFEE',
    sourceDocId: 'source_ciqual_2025_xlsx',
    preparationState: 'brewed',
    cookingState: 'ready_to_drink',
    nutrients: {
      'protein_g': '<0.5',
      'carbohydrate_g': '1.35',
      'fat_g': '0.018',
      'fiber_g': '0',
      'potassium_mg': '150',
      'vitamin_b6_mg': '0.73',
    },
  ),
];

/// 供 UI / AppDatabase 使用的轻量食品目录。
///
/// 重要说明：
/// - 这里会把 observation 级的限定语折叠为“可展示的近似数值”，仅用于录餐搜索与粗粒度展示。
/// - 真正需要保留 `<x` / `trace` / missing 语义的地方，仍然是 observation / resolved_fact。
List<FoodItem> buildP0FoodCatalog() {
  return _p0FoodSeeds.map((seed) {
    final protein = _catalogValue(seed.nutrients['protein_g']);
    final carbs = _catalogValue(seed.nutrients['carbohydrate_g']);
    final fat = _catalogValue(seed.nutrients['fat_g']);
    final fiber = _catalogValue(seed.nutrients['fiber_g']);
    final textureClass = inferTextureClassFromText(
      name: seed.displayNameLocal,
      description: seed.canonicalNameEn,
      categoryName: seed.foodGroup,
    );

    return FoodItem(
      id: seed.appFoodId,
      name: seed.displayNameLocal,
      category: _foodCategoryFromGroup(seed.foodGroup),
      aliases: _foodAliases(
          seed.appFoodId, seed.canonicalNameEn, seed.canonicalNameZh),
      description:
          '${seed.canonicalNameZh} / ${seed.canonicalNameEn} · CIQUAL(FR) · per 100g edible portion',
      sourceSystem: 'CIQUAL',
      sourceFoodCode: seed.sourceFoodCode,
      jurisdiction: 'FR',
      textureClass: textureClass,
      iddsiLevel: inferIddsiLevelFromTextureClass(textureClass),
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
      sodiumMg: 0,
    );
  }).toList(growable: false);
}

/// Builds a database seed from the currently verified P0 food subset.
///
/// 这里先把“可确认的数据”写入 observation/resolved_fact。
/// 对于还没有拿到官方源字段或代码的部分，宁可保留缺口，也不做猜测性填充。
KnowledgeBaseSeedBundle buildP0FoodKnowledgeBaseSeed() {
  final sourceDocuments = <SourceDocumentRecord>[
    ...p0SourceDocumentSeed,
    ...clinicalEvidenceSourceDocuments,
  ];
  final foodConcepts = <FoodConceptRecord>[];
  final foodVariants = <FoodVariantRecord>[];
  final variantScopes = <VariantScopeRecord>[];
  final observations = <ObservationRecord>[];
  final resolvedFacts = <ResolvedFactRecord>[];

  for (final seed in _p0FoodSeeds) {
    // 目前 food variant 仍以单一 FR/Ciqual 记录为主。
    // 后续正式 ETL 应在这里并行写入 FR / US / EU / CA / JP 等多司法辖区变体。
    final variantId = '${seed.conceptId}#FR#CIQUAL#${seed.sourceFoodCode}';
    final scopeHash = '${variantId}_scope';

    foodConcepts.add(
      FoodConceptRecord(
        foodConceptId: seed.conceptId,
        canonicalNameEn: seed.canonicalNameEn,
        canonicalNameZh: seed.canonicalNameZh,
        foodGroup: seed.foodGroup,
      ),
    );

    foodVariants.add(
      FoodVariantRecord(
        foodVariantId: variantId,
        foodConceptId: seed.conceptId,
        jurisdiction: 'FR',
        sourceFamily: 'CIQUAL',
        sourceFoodCode: seed.sourceFoodCode,
        displayNameLocal: seed.displayNameLocal,
        isAuthoritativeForRegion: true,
        isAuthoritativeFallback: false,
        status: 'seeded_from_verified_report',
        fallbackChainJson: jsonEncode(['FR', 'EU', 'GLOBAL']),
      ),
    );

    variantScopes.add(
      VariantScopeRecord(
        scopeHash: scopeHash,
        jurisdiction: 'FR',
        brand: null,
        dosageForm: null,
        releaseType: null,
        saltForm: null,
        route: null,
        preparationState: seed.preparationState,
        cookingState: seed.cookingState,
        plantPart: null,
        cultivar: null,
        samplingFrame: 'ciqual_verified_report_text',
      ),
    );

    seed.nutrients.forEach((attributeCode, rawValue) {
      // `UNSPECIFIED` 明确表示“当前资料未补齐”，不是 0，也不是空字符串默认值。
      // 后续应由正式的抓取器/解析器从官方文件中补入 observation。
      if (rawValue == 'UNSPECIFIED') {
        return;
      }

      final observationId = '${variantId}_$attributeCode';
      // 保留限定语是核心要求：trace / <x / range / missing 不能被拍平成普通浮点数。
      final qualifiedValue = parseQualifiedValue(rawValue);
      observations.add(
        ObservationRecord(
          observationId: observationId,
          domain: 'food',
          entityType: 'food_variant',
          entityKey: variantId,
          attributeCode: attributeCode,
          valueType: 'numeric_interval',
          value: qualifiedValue,
          unit: _unitForAttribute(attributeCode),
          basisType: 'per_100g_edible_part',
          basisAmount: 100,
          scopeHash: scopeHash,
          sourceDocId: seed.sourceDocId,
          recordLocator: '${seed.displayNameLocal}:$attributeCode',
          methodCode: null,
          extractionConfidence: 1,
        ),
      );

      resolvedFacts.add(
        ResolvedFactRecord(
          factId: 'fact_$observationId',
          entityKey: variantId,
          attributeCode: attributeCode,
          scopeHash: scopeHash,
          resolutionStatus: qualifiedValue.qualifierKind ==
                  QualifierKind.parsingUncertainty
              ? 'PARSING_UNCERTAINTY'
              // 这里暂时直接接受当前种子值。
              // 未来完整版本应由事实冲突解析器决定 SOURCE_ACCEPTED / COEXIST_VARIANT / CONTRADICTION。
              : 'SOURCE_ACCEPTED',
          chosenObservationId: observationId,
          resolvedValue: qualifiedValue,
          resolvedUnit: _unitForAttribute(attributeCode),
          resolutionPolicyId: 'p0_food_seed_v1',
          snapshotId: 'facts_p0_food_seed_v1',
          factVersion: 'p0_food_seed_v1',
          manualOverride: false,
        ),
      );
    });
  }

  return KnowledgeBaseSeedBundle(
    sourceDocuments: sourceDocuments,
    foodConcepts: foodConcepts,
    foodVariants: foodVariants,
    variantScopes: variantScopes,
    observations: observations,
    resolvedFacts: resolvedFacts,
  );
}

String _unitForAttribute(String attributeCode) {
  if (attributeCode.endsWith('_mg')) return 'mg';
  if (attributeCode.endsWith('_ug')) return 'ug';
  return 'g';
}

double _catalogValue(String? raw) {
  if (raw == null || raw == 'UNSPECIFIED') return 0;
  final qualified = parseQualifiedValue(raw);
  return qualified.valueNum ?? qualified.high ?? 0;
}

FoodCategory _foodCategoryFromGroup(String group) {
  switch (group) {
    case 'protein':
      return FoodCategory.protein;
    case 'carbs':
      return FoodCategory.carbs;
    case 'vegetable':
      return FoodCategory.vegetable;
    case 'fruit':
      return FoodCategory.fruit;
    case 'dairy':
      return FoodCategory.dairy;
    case 'fat':
      return FoodCategory.fat;
    case 'beverage':
      return FoodCategory.beverage;
    default:
      return FoodCategory.other;
  }
}

List<String> _foodAliases(
  String foodId,
  String canonicalNameEn,
  String canonicalNameZh,
) {
  final extra = <String, List<String>>{
    'food_banana': ['banana', '香蕉'],
    'food_spinach': ['spinach', '菠菜'],
    'food_tofu': [
      'tofu',
      'bean curd',
      '豆腐',
      '嫩豆腐',
      '北豆腐',
      '南豆腐',
      '老豆腐',
      '豆制品',
    ],
    'food_milk': ['milk', 'cow milk', '牛奶', '鲜奶', '奶类'],
    'food_chicken_breast': ['chicken breast', '鸡胸肉', '鸡胸'],
    'food_apple': ['apple', '苹果'],
    'food_blueberry': ['blueberry', '蓝莓'],
    'food_tomato': ['tomato', '番茄', '西红柿'],
    'food_broccoli': ['broccoli', '西兰花', '青花菜', '十字花科'],
    'food_oats': ['oats', 'rolled oats', '燕麦', '燕麦片', '全谷物', '杂粮'],
    'food_brown_rice': ['brown rice', '糙米', '糙米饭', '全谷物', '杂粮饭'],
    'food_salmon': ['salmon', '三文鱼', '鲑鱼', '鱼类'],
    'food_fava_beans': ['broad bean', '蚕豆', 'sora bean', '胡豆'],
    'food_potato_boiled': ['potato', 'boiled potato', '土豆', '马铃薯', '洋芋', '薯类'],
    'food_walnuts': ['walnut', '核桃', '核桃仁', '坚果'],
    'food_olive_oil': ['olive oil', '橄榄油', '初榨橄榄油'],
    'food_cheddar_cheese': ['cheddar', 'aged cheese', '奶酪', '干酪', '乳制品'],
    'food_egg_boiled': ['egg', 'boiled egg', '鸡蛋', '水煮蛋', '白煮蛋'],
    'food_coffee': ['coffee', 'brew coffee', '咖啡', '美式咖啡'],
  };
  return [canonicalNameEn, canonicalNameZh, ...(extra[foodId] ?? const [])];
}
