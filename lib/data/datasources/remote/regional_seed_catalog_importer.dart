import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'seed_catalog_composition.dart';

/// Regional seed catalog importer.
///
/// Goal: complement the global `SeedCatalogImporter` with region-specific
/// foods (Chinese, Japanese, Korean, South Asian, Mediterranean, Mexican /
/// Latin, Southeast Asian, Middle Eastern, Russian / Eastern European) and
/// region-relevant medications, so users in different countries can log
/// realistic meals and prescriptions out-of-the-box.
///
/// Conservative boundaries (same as `SeedCatalogImporter`):
/// - Per-100g nutrition values are copied from the USDA FoodData Central
///   record mapped in `tool/data/seed_food_sources.json`; foods without a
///   defensible record carry no nutrient values. They never become
///   `ObservationRecord` rows.
/// - Drug entries are catalog metadata only; no rules added.
/// - Each row carries `sourceSystem = 'LOCAL_SEED_CATALOG_REGIONAL'` plus a
///   per-row `jurisdiction` (e.g. 'CN', 'JP', 'KR', 'IN', 'MX', 'MED',
///   'SEA', 'MENA', 'EE') so authoritative ETL imports can still override.
/// - One `SourceDocumentRecord` is emitted with explicit audit_gaps.
class RegionalSeedCatalogImporter {
  const RegionalSeedCatalogImporter();

  P0ImportBundle importRegionalSeedCatalog() {
    final foods = _regionalFoods();
    final drugs = _regionalDrugs();
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'LOCAL_SEED_CATALOG_REGIONAL',
      externalKey: 'regional_v1',
    );
    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'LOCAL_SEED_CATALOG_REGIONAL',
      organization: 'ParkinSUM Companion (built-in regional catalog)',
      jurisdiction: 'GLOBAL',
      docType: 'app_seed_catalog_regional',
      title: 'Built-in regional seed catalog (region-tagged foods + drugs)',
      originUrl: 'app://local-seed-catalog/regional_v1',
      licenseNote:
          'Built-in seed catalog. Regional/cultural items added for breadth. '
          'Per-100 g values are copied from USDA FoodData Central (public '
          'domain); unmatched foods carry no nutrient values.',
      language: 'multi',
      dataTier: KnowledgeDataTier.p2,
      ingestionStrategy: SourceIngestionStrategy.controlledExport,
      rawPayload: stringifyPayload({
        'food_count': foods.length,
        'drug_count': drugs.length,
        'jurisdictions': foods.map((f) => f.jurisdiction).toSet().toList()
          ..sort(),
        'audit_gaps': <Map<String, Object?>>[
          ImporterAudit.auditGap(
            fieldName: 'food_nutrition_values',
            reason:
                'Regional per-100 g values are copied from mapped USDA '
                'FoodData Central records; regional dishes without a '
                'defensible record are marked unknown. Imported FDC / Ciqual / '
                'China CDC / MEXT facts remain authoritative.',
            observedCount: foods.length,
          ),
          ImporterAudit.auditGap(
            fieldName: 'cultural_aliases',
            reason:
                'Aliases include native-language names (zh / ja / ko / hi / es '
                'etc.) for search; they are NOT translated authoritatively and '
                'do not establish a localization contract.',
            observedCount: foods.length,
          ),
          ImporterAudit.auditGap(
            fieldName: 'drug_interaction_summary',
            reason:
                'Regional drug catalog entries are metadata only; the runtime '
                'interaction engine still evaluates only the curated rule '
                'registry.',
            observedCount: drugs.length,
          ),
        ],
        'parser_limitation':
            'Regional seed rows are app-level catalog pointers; they '
            'intentionally do not produce ObservationRecord, '
            'ResolvedFactRecord, or ConceptVariantCrosswalkRecord rows.',
      }),
    );
    return P0ImportBundle(
      sourceDocuments: [sourceDocument],
      projectedFoods: foods,
      projectedDrugs: drugs,
    );
  }

  // ---------- regional foods ------------------------------------------------

  List<FoodItem> _regionalFoods() {
    final entries = <_R>[
      // ===== China (CN) =====
      _R(
        'seed_cn_jujube',
        'Chinese jujube (red dates)',
        ['红枣', 'hong zao', 'da zao'],
        FoodCategory.fruit,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_goji',
        'Goji berries',
        ['枸杞', 'wolfberries'],
        FoodCategory.fruit,
        'CN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_cn_white_fungus',
        'White fungus (snow ear)',
        ['银耳', 'tremella'],
        FoodCategory.vegetable,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_black_fungus',
        'Black fungus (wood ear)',
        ['黑木耳', 'mu er'],
        FoodCategory.vegetable,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_lotus_root',
        'Lotus root (cooked)',
        ['莲藕', 'lian ou'],
        FoodCategory.vegetable,
        'CN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_cn_bamboo_shoots',
        'Bamboo shoots',
        ['竹笋', 'zhu sun'],
        FoodCategory.vegetable,
        'CN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_cn_hawthorn',
        'Hawthorn fruit',
        ['山楂', 'shan zha'],
        FoodCategory.fruit,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_longan',
        'Longan',
        ['桂圆', '龙眼', 'long yan'],
        FoodCategory.fruit,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_lychee',
        'Lychee',
        ['荔枝', 'li zhi'],
        FoodCategory.fruit,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_persimmon',
        'Persimmon',
        ['柿子', 'shi zi'],
        FoodCategory.fruit,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_bitter_melon',
        'Bitter melon (cooked)',
        ['苦瓜', 'ku gua'],
        FoodCategory.vegetable,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_winter_melon',
        'Winter melon (cooked)',
        ['冬瓜', 'dong gua'],
        FoodCategory.vegetable,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_baozi',
        'Steamed pork bun',
        ['包子', 'bao zi'],
        FoodCategory.protein,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_zongzi',
        'Zongzi (sticky rice in leaves)',
        ['粽子', 'zong zi'],
        FoodCategory.carbs,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_mooncake',
        'Mooncake',
        ['月饼', 'yue bing'],
        FoodCategory.carbs,
        'CN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_cn_youcai',
        'Youcai (Chinese rapeseed greens)',
        ['油菜', 'you cai'],
        FoodCategory.vegetable,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_chives',
        'Chinese chives',
        ['韭菜', 'jiu cai'],
        FoodCategory.vegetable,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_bean_sprouts',
        'Mung bean sprouts',
        ['豆芽', 'dou ya'],
        FoodCategory.vegetable,
        'CN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_cn_black_rice',
        'Black rice (cooked)',
        ['黑米', 'hei mi'],
        FoodCategory.carbs,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_cn_jiaozi_pork',
        'Boiled pork dumplings',
        ['水饺', 'jiao zi'],
        FoodCategory.protein,
        'CN',
        tex: 'soft',
        iddsi: 5,
      ),

      // ===== Japan (JP) =====
      _R(
        'seed_jp_tai',
        'Sea bream (tai)',
        ['鯛', 'red sea bream'],
        FoodCategory.protein,
        'JP',
        tex: 'soft',
        iddsi: 6,
      ),
      _R(
        'seed_jp_saba',
        'Mackerel (saba)',
        ['鯖', 'mackerel'],
        FoodCategory.protein,
        'JP',
        tex: 'soft',
        iddsi: 6,
      ),
      _R(
        'seed_jp_buri',
        'Yellowtail (buri / hamachi)',
        ['鰤', 'hamachi'],
        FoodCategory.protein,
        'JP',
        tex: 'soft',
        iddsi: 6,
      ),
      _R(
        'seed_jp_natto',
        'Natto (fermented soybeans)',
        ['納豆'],
        FoodCategory.protein,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_miso',
        'Miso paste',
        ['味噌'],
        FoodCategory.other,
        'JP',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_jp_soy_sauce',
        'Soy sauce (shoyu)',
        ['醤油', 'shoyu'],
        FoodCategory.other,
        'JP',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_jp_nori',
        'Nori (dried seaweed sheets)',
        ['海苔'],
        FoodCategory.vegetable,
        'JP',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_jp_kombu',
        'Kombu (kelp)',
        ['昆布'],
        FoodCategory.vegetable,
        'JP',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_jp_wakame',
        'Wakame seaweed',
        ['若布', 'わかめ'],
        FoodCategory.vegetable,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_hijiki',
        'Hijiki seaweed',
        ['ひじき'],
        FoodCategory.vegetable,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_daikon',
        'Daikon radish',
        ['大根'],
        FoodCategory.vegetable,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_renkon',
        'Renkon (lotus root, JP)',
        ['蓮根'],
        FoodCategory.vegetable,
        'JP',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_jp_shiitake',
        'Shiitake mushrooms',
        ['椎茸'],
        FoodCategory.vegetable,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_gobo',
        'Burdock root (gobo)',
        ['牛蒡', 'gobo'],
        FoodCategory.vegetable,
        'JP',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_jp_mochi',
        'Mochi (rice cake)',
        ['餅'],
        FoodCategory.carbs,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_udon',
        'Udon noodles (cooked)',
        ['饂飩'],
        FoodCategory.carbs,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_soba',
        'Soba (buckwheat noodles, cooked)',
        ['蕎麦'],
        FoodCategory.carbs,
        'JP',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_jp_umeboshi',
        'Umeboshi (pickled plum)',
        ['梅干し'],
        FoodCategory.other,
        'JP',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_jp_matcha',
        'Matcha (powdered green tea)',
        ['抹茶'],
        FoodCategory.beverage,
        'JP',
        tex: 'liquid',
        iddsi: 0,
      ),

      // ===== Korea (KR) =====
      _R(
        'seed_kr_kimchi',
        'Kimchi',
        ['김치'],
        FoodCategory.vegetable,
        'KR',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_kr_tteok',
        'Tteok (rice cake)',
        ['떡'],
        FoodCategory.carbs,
        'KR',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_kr_gochujang',
        'Gochujang (red pepper paste)',
        ['고추장'],
        FoodCategory.other,
        'KR',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_kr_doenjang',
        'Doenjang (soybean paste)',
        ['된장'],
        FoodCategory.other,
        'KR',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_kr_miyeok',
        'Miyeok (sea mustard) soup',
        ['미역국'],
        FoodCategory.beverage,
        'KR',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_kr_bibimbap',
        'Bibimbap (mixed rice bowl)',
        ['비빔밥'],
        FoodCategory.protein,
        'KR',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_kr_japchae',
        'Japchae (glass noodles stir-fry)',
        ['잡채'],
        FoodCategory.carbs,
        'KR',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_kr_kimbap',
        'Kimbap (seaweed rice roll)',
        ['김밥'],
        FoodCategory.carbs,
        'KR',
        tex: 'regular',
        iddsi: 7,
      ),

      // ===== South Asia (IN) =====
      _R(
        'seed_in_dal',
        'Dal (lentil curry)',
        ['daal', 'masoor dal'],
        FoodCategory.protein,
        'IN',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_in_chapati',
        'Chapati (roti)',
        ['roti', 'phulka'],
        FoodCategory.carbs,
        'IN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_in_naan',
        'Naan bread',
        [],
        FoodCategory.carbs,
        'IN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_in_paneer',
        'Paneer (Indian cheese)',
        [],
        FoodCategory.dairy,
        'IN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_in_ghee',
        'Ghee (clarified butter)',
        [],
        FoodCategory.fat,
        'IN',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_in_basmati',
        'Basmati rice (cooked)',
        [],
        FoodCategory.carbs,
        'IN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_in_idli',
        'Idli (steamed rice cake)',
        [],
        FoodCategory.carbs,
        'IN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_in_dosa',
        'Dosa (rice-lentil crepe)',
        [],
        FoodCategory.carbs,
        'IN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_in_chana_masala',
        'Chana masala',
        ['chickpea curry'],
        FoodCategory.protein,
        'IN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_in_biryani',
        'Chicken biryani',
        [],
        FoodCategory.protein,
        'IN',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_in_raita',
        'Raita (yogurt sauce)',
        [],
        FoodCategory.dairy,
        'IN',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_in_lassi',
        'Lassi (yogurt drink)',
        [],
        FoodCategory.beverage,
        'IN',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_in_paratha',
        'Paratha (layered flatbread)',
        [],
        FoodCategory.carbs,
        'IN',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_in_tandoori_chicken',
        'Tandoori chicken',
        [],
        FoodCategory.protein,
        'IN',
        tex: 'regular',
        iddsi: 7,
      ),

      // ===== Mediterranean / Levant (MED) =====
      _R(
        'seed_med_hummus',
        'Hummus',
        [],
        FoodCategory.protein,
        'MED',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_med_falafel',
        'Falafel',
        [],
        FoodCategory.protein,
        'MED',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_med_pita',
        'Pita bread',
        [],
        FoodCategory.carbs,
        'MED',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_med_tabbouleh',
        'Tabbouleh',
        [],
        FoodCategory.vegetable,
        'MED',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_med_baba_ganoush',
        'Baba ganoush',
        [],
        FoodCategory.fat,
        'MED',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_med_tzatziki',
        'Tzatziki',
        [],
        FoodCategory.dairy,
        'MED',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_med_feta',
        'Feta cheese',
        [],
        FoodCategory.dairy,
        'MED',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_med_olives',
        'Olives',
        [],
        FoodCategory.fat,
        'MED',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_med_dolma',
        'Dolma (stuffed grape leaves)',
        [],
        FoodCategory.vegetable,
        'MED',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_med_shakshuka',
        'Shakshuka',
        [],
        FoodCategory.protein,
        'MED',
        tex: 'soft',
        iddsi: 4,
      ),

      // ===== Mexico / Latin (MX) =====
      _R(
        'seed_mx_tortilla_corn',
        'Corn tortilla',
        [],
        FoodCategory.carbs,
        'MX',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_mx_refried_beans',
        'Refried beans',
        [],
        FoodCategory.protein,
        'MX',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_mx_guacamole',
        'Guacamole',
        [],
        FoodCategory.fat,
        'MX',
        tex: 'soft',
        iddsi: 4,
      ),
      _R(
        'seed_mx_salsa',
        'Salsa (tomato)',
        [],
        FoodCategory.vegetable,
        'MX',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_mx_tamale',
        'Tamale (chicken)',
        [],
        FoodCategory.protein,
        'MX',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_mx_taco',
        'Beef taco',
        [],
        FoodCategory.protein,
        'MX',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_mx_quesadilla',
        'Cheese quesadilla',
        [],
        FoodCategory.carbs,
        'MX',
        tex: 'regular',
        iddsi: 7,
      ),

      // ===== Southeast Asia (SEA) =====
      _R(
        'seed_sea_pho',
        'Pho (Vietnamese noodle soup)',
        ['phở'],
        FoodCategory.protein,
        'SEA',
        tex: 'liquid',
        iddsi: 4,
      ),
      _R(
        'seed_sea_banh_mi',
        'Bánh mì sandwich',
        [],
        FoodCategory.protein,
        'SEA',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_sea_pad_thai',
        'Pad Thai',
        [],
        FoodCategory.carbs,
        'SEA',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_sea_satay',
        'Chicken satay',
        [],
        FoodCategory.protein,
        'SEA',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_sea_nasi_goreng',
        'Nasi goreng (fried rice)',
        [],
        FoodCategory.carbs,
        'SEA',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_sea_rendang',
        'Beef rendang',
        [],
        FoodCategory.protein,
        'SEA',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_sea_laksa',
        'Laksa',
        [],
        FoodCategory.protein,
        'SEA',
        tex: 'liquid',
        iddsi: 4,
      ),
      _R(
        'seed_sea_tom_yum',
        'Tom yum soup',
        [],
        FoodCategory.beverage,
        'SEA',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_sea_sticky_rice',
        'Sticky rice (Thai)',
        ['glutinous rice', '糯米饭'],
        FoodCategory.carbs,
        'SEA',
        tex: 'soft',
        iddsi: 5,
      ),

      // ===== Russia / Eastern Europe (EE) =====
      _R(
        'seed_ee_borscht',
        'Borscht (beet soup)',
        [],
        FoodCategory.beverage,
        'EE',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_ee_pelmeni',
        'Pelmeni (meat dumplings)',
        [],
        FoodCategory.protein,
        'EE',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_ee_blini',
        'Blini',
        [],
        FoodCategory.carbs,
        'EE',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_ee_kasha',
        'Kasha (buckwheat porridge)',
        [],
        FoodCategory.carbs,
        'EE',
        tex: 'soft',
        iddsi: 4,
      ),

      // ===== North Africa / Middle East (MENA) =====
      _R(
        'seed_mena_couscous_tagine',
        'Couscous with tagine',
        [],
        FoodCategory.protein,
        'MENA',
        tex: 'soft',
        iddsi: 5,
      ),
      _R(
        'seed_mena_harira',
        'Harira soup',
        [],
        FoodCategory.beverage,
        'MENA',
        tex: 'liquid',
        iddsi: 0,
      ),
      _R(
        'seed_mena_shawarma_chicken',
        'Chicken shawarma',
        [],
        FoodCategory.protein,
        'MENA',
        tex: 'regular',
        iddsi: 7,
      ),
      _R(
        'seed_mena_kibbeh',
        'Kibbeh',
        [],
        FoodCategory.protein,
        'MENA',
        tex: 'regular',
        iddsi: 7,
      ),
    ];
    return entries
        .map(
          (entry) => projectSeedCatalogFood(
            id: entry.id,
            name: entry.name,
            category: entry.category,
            aliases: entry.aliases,
            sourceSystem: 'LOCAL_SEED_CATALOG_REGIONAL',
            jurisdiction: entry.jurisdiction,
            textureClass: entry.tex,
            iddsiLevel: entry.iddsi,
          ),
        )
        .toList(growable: false);
  }

  // ---------- regional / comorbid drugs ------------------------------------

  List<DrugDefinition> _regionalDrugs() {
    final entries = <_D>[
      // Cognitive comorbidities (used internationally)
      _D(
        'seed_drug_donepezil',
        'Donepezil',
        ['Aricept'],
        [DrugTag.cholinesteraseInhibitor],
      ),
      _D(
        'seed_drug_galantamine',
        'Galantamine',
        ['Razadyne', 'Reminyl'],
        [DrugTag.cholinesteraseInhibitor],
      ),
      _D('seed_drug_memantine', 'Memantine', [
        'Namenda',
        'Ebixa',
      ], const <DrugTag>[]),
      // PD-related anxiety / sleep / restless legs
      _D('seed_drug_clonazepam', 'Clonazepam', [
        'Klonopin',
        'Rivotril',
      ], const <DrugTag>[]),
      _D('seed_drug_lorazepam', 'Lorazepam', ['Ativan'], const <DrugTag>[]),
      _D('seed_drug_zolpidem', 'Zolpidem', [
        'Ambien',
        'Stilnox',
      ], const <DrugTag>[]),
      _D('seed_drug_mirtazapine', 'Mirtazapine', [
        'Remeron',
      ], const <DrugTag>[]),
      _D('seed_drug_trazodone', 'Trazodone', ['Desyrel'], const <DrugTag>[]),
      // Pain / spasticity often co-prescribed
      _D('seed_drug_gabapentin', 'Gabapentin', [
        'Neurontin',
      ], const <DrugTag>[]),
      _D('seed_drug_pregabalin', 'Pregabalin', ['Lyrica'], const <DrugTag>[]),
      _D('seed_drug_baclofen', 'Baclofen', ['Lioresal'], const <DrugTag>[]),
      _D('seed_drug_tizanidine', 'Tizanidine', ['Zanaflex'], const <DrugTag>[]),
      _D('seed_drug_tramadol', 'Tramadol', ['Ultram'], const <DrugTag>[]),
      // Common GI / nausea (orthostatic / med-related)
      _D('seed_drug_domperidone', 'Domperidone', [
        'Motilium',
      ], const <DrugTag>[]),
      _D('seed_drug_ondansetron', 'Ondansetron', ['Zofran'], const <DrugTag>[]),
      // Common cardiac / metabolic
      _D('seed_drug_losartan', 'Losartan', ['Cozaar'], const <DrugTag>[]),
      _D('seed_drug_bisoprolol', 'Bisoprolol', ['Concor'], const <DrugTag>[]),
      _D('seed_drug_rosuvastatin', 'Rosuvastatin', [
        'Crestor',
      ], const <DrugTag>[]),
      _D('seed_drug_furosemide', 'Furosemide', ['Lasix'], const <DrugTag>[]),
      _D('seed_drug_levothyroxine', 'Levothyroxine', [
        'Synthroid',
        'Euthyrox',
      ], const <DrugTag>[]),
      // Vitamin / nutrition often co-prescribed
      _D(
        'seed_drug_vitamin_d3',
        'Vitamin D3 (cholecalciferol)',
        [],
        const <DrugTag>[],
      ),
      _D(
        'seed_drug_vitamin_b12',
        'Vitamin B12 (cyanocobalamin)',
        [],
        const <DrugTag>[],
      ),
    ];
    return entries
        .map(
          (entry) => DrugDefinition(
            id: entry.id,
            genericName: entry.genericName,
            brandNames: entry.brandNames,
            tags: entry.tags,
            notes:
                'Built-in regional seed catalog entry. Catalog metadata '
                'only; the interaction engine still runs only off the '
                'curated rule registry.',
            sourceSystem: 'LOCAL_SEED_CATALOG_REGIONAL',
            sourceProductCode: entry.id,
            jurisdiction: 'GLOBAL',
          ),
        )
        .toList(growable: false);
  }
}

class _R {
  final String id;
  final String name;
  final List<String> aliases;
  final FoodCategory category;
  final String jurisdiction;
  final String? tex;
  final int? iddsi;

  _R(
    this.id,
    this.name,
    this.aliases,
    this.category,
    this.jurisdiction, {
    this.tex,
    this.iddsi,
  });
}

class _D {
  final String id;
  final String genericName;
  final List<String> brandNames;
  final List<DrugTag> tags;

  _D(this.id, this.genericName, this.brandNames, this.tags);
}
