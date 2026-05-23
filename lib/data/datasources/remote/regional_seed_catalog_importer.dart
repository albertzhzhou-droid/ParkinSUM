import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';

/// Regional seed catalog importer.
///
/// Goal: complement the global `SeedCatalogImporter` with region-specific
/// foods (Chinese, Japanese, Korean, South Asian, Mediterranean, Mexican /
/// Latin, Southeast Asian, Middle Eastern, Russian / Eastern European) and
/// region-relevant medications, so users in different countries can log
/// realistic meals and prescriptions out-of-the-box.
///
/// Conservative boundaries (same as `SeedCatalogImporter`):
/// - Per-100g nutrition values are rough generic estimates for UX/search
///   only — they never become `ObservationRecord` rows.
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
          'Per-100g values are rough generic estimates, not authoritative.',
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
                'Regional per-100g values are generic estimates for UX/search '
                'only. Authoritative composition still comes from FDC / Ciqual '
                '/ China CDC / MEXT etc.',
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
      _R('seed_cn_jujube', 'Chinese jujube (red dates)',
          ['红枣', 'hong zao', 'da zao'], FoodCategory.fruit, 'CN',
          p: 1.2, c: 79, f: 0.3, fb: 7.6, na: 3, tex: 'soft', iddsi: 5),
      _R('seed_cn_goji', 'Goji berries', ['枸杞', 'wolfberries'],
          FoodCategory.fruit, 'CN',
          p: 14, c: 64, f: 0.4, fb: 13, na: 298, tex: 'regular', iddsi: 7),
      _R('seed_cn_white_fungus', 'White fungus (snow ear)', ['银耳', 'tremella'],
          FoodCategory.vegetable, 'CN',
          p: 1.5, c: 6.6, f: 0.2, fb: 4.7, na: 7, tex: 'soft', iddsi: 5),
      _R('seed_cn_black_fungus', 'Black fungus (wood ear)', ['黑木耳', 'mu er'],
          FoodCategory.vegetable, 'CN',
          p: 1.4, c: 6.5, f: 0.1, fb: 5, na: 9, tex: 'soft', iddsi: 5),
      _R('seed_cn_lotus_root', 'Lotus root (cooked)', ['莲藕', 'lian ou'],
          FoodCategory.vegetable, 'CN',
          p: 2.6, c: 16, f: 0.1, fb: 3.1, na: 45, tex: 'regular', iddsi: 7),
      _R('seed_cn_bamboo_shoots', 'Bamboo shoots', ['竹笋', 'zhu sun'],
          FoodCategory.vegetable, 'CN',
          p: 2.6, c: 5.2, f: 0.3, fb: 2.2, na: 4, tex: 'regular', iddsi: 7),
      _R('seed_cn_hawthorn', 'Hawthorn fruit', ['山楂', 'shan zha'],
          FoodCategory.fruit, 'CN',
          p: 0.8, c: 25, f: 0.6, fb: 3.1, na: 6, tex: 'soft', iddsi: 5),
      _R('seed_cn_longan', 'Longan', ['桂圆', '龙眼', 'long yan'],
          FoodCategory.fruit, 'CN',
          p: 1.3, c: 15, f: 0.1, fb: 1.1, na: 0, tex: 'soft', iddsi: 5),
      _R('seed_cn_lychee', 'Lychee', ['荔枝', 'li zhi'], FoodCategory.fruit, 'CN',
          p: 0.8, c: 17, f: 0.4, fb: 1.3, na: 1, tex: 'soft', iddsi: 5),
      _R('seed_cn_persimmon', 'Persimmon', ['柿子', 'shi zi'], FoodCategory.fruit,
          'CN',
          p: 0.6, c: 19, f: 0.2, fb: 3.6, na: 1, tex: 'soft', iddsi: 5),
      _R('seed_cn_bitter_melon', 'Bitter melon (cooked)', ['苦瓜', 'ku gua'],
          FoodCategory.vegetable, 'CN',
          p: 1, c: 4.3, f: 0.2, fb: 2, na: 5, tex: 'soft', iddsi: 5),
      _R('seed_cn_winter_melon', 'Winter melon (cooked)', ['冬瓜', 'dong gua'],
          FoodCategory.vegetable, 'CN',
          p: 0.4, c: 3, f: 0.2, fb: 2.9, na: 6, tex: 'soft', iddsi: 5),
      _R('seed_cn_baozi', 'Steamed pork bun', ['包子', 'bao zi'],
          FoodCategory.protein, 'CN',
          p: 8, c: 30, f: 6, fb: 1.5, na: 380, tex: 'soft', iddsi: 5),
      _R('seed_cn_zongzi', 'Zongzi (sticky rice in leaves)', ['粽子', 'zong zi'],
          FoodCategory.carbs, 'CN',
          p: 4, c: 35, f: 4, fb: 1, na: 220, tex: 'soft', iddsi: 5),
      _R('seed_cn_mooncake', 'Mooncake', ['月饼', 'yue bing'], FoodCategory.carbs,
          'CN',
          p: 7, c: 60, f: 18, fb: 2, na: 130, tex: 'regular', iddsi: 7),
      _R('seed_cn_youcai', 'Youcai (Chinese rapeseed greens)',
          ['油菜', 'you cai'], FoodCategory.vegetable, 'CN',
          p: 1.8, c: 2.8, f: 0.5, fb: 1.1, na: 55, tex: 'soft', iddsi: 5),
      _R('seed_cn_chives', 'Chinese chives', ['韭菜', 'jiu cai'],
          FoodCategory.vegetable, 'CN',
          p: 2.4, c: 4.6, f: 0.6, fb: 1.4, na: 8, tex: 'soft', iddsi: 5),
      _R('seed_cn_bean_sprouts', 'Mung bean sprouts', ['豆芽', 'dou ya'],
          FoodCategory.vegetable, 'CN',
          p: 3, c: 5.9, f: 0.2, fb: 1.8, na: 6, tex: 'regular', iddsi: 7),
      _R('seed_cn_black_rice', 'Black rice (cooked)', ['黑米', 'hei mi'],
          FoodCategory.carbs, 'CN',
          p: 4.6, c: 23, f: 0.7, fb: 2.4, na: 4, tex: 'soft', iddsi: 5),
      _R('seed_cn_jiaozi_pork', 'Boiled pork dumplings', ['水饺', 'jiao zi'],
          FoodCategory.protein, 'CN',
          p: 9, c: 24, f: 7, fb: 1.5, na: 380, tex: 'soft', iddsi: 5),

      // ===== Japan (JP) =====
      _R('seed_jp_tai', 'Sea bream (tai)', ['鯛', 'red sea bream'],
          FoodCategory.protein, 'JP',
          p: 21, c: 0, f: 5, fb: 0, na: 60, tex: 'soft', iddsi: 6),
      _R('seed_jp_saba', 'Mackerel (saba)', ['鯖', 'mackerel'],
          FoodCategory.protein, 'JP',
          p: 19, c: 0, f: 13, fb: 0, na: 90, tex: 'soft', iddsi: 6),
      _R('seed_jp_buri', 'Yellowtail (buri / hamachi)', ['鰤', 'hamachi'],
          FoodCategory.protein, 'JP',
          p: 22, c: 0, f: 14, fb: 0, na: 70, tex: 'soft', iddsi: 6),
      _R('seed_jp_natto', 'Natto (fermented soybeans)', ['納豆'],
          FoodCategory.protein, 'JP',
          p: 18, c: 12, f: 11, fb: 5.4, na: 2, tex: 'soft', iddsi: 5),
      _R('seed_jp_miso', 'Miso paste', ['味噌'], FoodCategory.other, 'JP',
          p: 12, c: 26, f: 6, fb: 5.4, na: 3700, tex: 'soft', iddsi: 4),
      _R('seed_jp_soy_sauce', 'Soy sauce (shoyu)', ['醤油', 'shoyu'],
          FoodCategory.other, 'JP',
          p: 8, c: 8, f: 0, fb: 0.8, na: 5500, tex: 'liquid', iddsi: 0),
      _R('seed_jp_nori', 'Nori (dried seaweed sheets)', ['海苔'],
          FoodCategory.vegetable, 'JP',
          p: 41, c: 44, f: 2, fb: 28, na: 48, tex: 'regular', iddsi: 7),
      _R('seed_jp_kombu', 'Kombu (kelp)', ['昆布'], FoodCategory.vegetable, 'JP',
          p: 1.7, c: 9.6, f: 0.6, fb: 1.3, na: 233, tex: 'regular', iddsi: 7),
      _R('seed_jp_wakame', 'Wakame seaweed', ['若布', 'わかめ'],
          FoodCategory.vegetable, 'JP',
          p: 3, c: 9, f: 0.6, fb: 0.5, na: 872, tex: 'soft', iddsi: 5),
      _R('seed_jp_hijiki', 'Hijiki seaweed', ['ひじき'], FoodCategory.vegetable,
          'JP',
          p: 7.4, c: 56, f: 1.3, fb: 43, na: 1800, tex: 'soft', iddsi: 5),
      _R('seed_jp_daikon', 'Daikon radish', ['大根'], FoodCategory.vegetable,
          'JP',
          p: 0.6, c: 4.1, f: 0.1, fb: 1.6, na: 21, tex: 'soft', iddsi: 5),
      _R('seed_jp_renkon', 'Renkon (lotus root, JP)', ['蓮根'],
          FoodCategory.vegetable, 'JP',
          p: 1.9, c: 17, f: 0.1, fb: 2, na: 64, tex: 'regular', iddsi: 7),
      _R('seed_jp_shiitake', 'Shiitake mushrooms', ['椎茸'],
          FoodCategory.vegetable, 'JP',
          p: 2.2, c: 6.8, f: 0.5, fb: 2.5, na: 9, tex: 'soft', iddsi: 5),
      _R('seed_jp_gobo', 'Burdock root (gobo)', ['牛蒡', 'gobo'],
          FoodCategory.vegetable, 'JP',
          p: 1.5, c: 18, f: 0.2, fb: 3.3, na: 5, tex: 'regular', iddsi: 7),
      _R('seed_jp_mochi', 'Mochi (rice cake)', ['餅'], FoodCategory.carbs, 'JP',
          p: 4, c: 50, f: 0.5, fb: 0.5, na: 3, tex: 'soft', iddsi: 5),
      _R('seed_jp_udon', 'Udon noodles (cooked)', ['饂飩'], FoodCategory.carbs,
          'JP',
          p: 2.6, c: 21, f: 0.1, fb: 0.8, na: 110, tex: 'soft', iddsi: 5),
      _R('seed_jp_soba', 'Soba (buckwheat noodles, cooked)', ['蕎麦'],
          FoodCategory.carbs, 'JP',
          p: 5.1, c: 24, f: 0.1, fb: 2.1, na: 60, tex: 'soft', iddsi: 5),
      _R('seed_jp_umeboshi', 'Umeboshi (pickled plum)', ['梅干し'],
          FoodCategory.other, 'JP',
          p: 0.9, c: 8.6, f: 0.4, fb: 3.6, na: 8000, tex: 'soft', iddsi: 4),
      _R('seed_jp_matcha', 'Matcha (powdered green tea)', ['抹茶'],
          FoodCategory.beverage, 'JP',
          p: 30, c: 39, f: 5, fb: 38, na: 2, tex: 'liquid', iddsi: 0),

      // ===== Korea (KR) =====
      _R('seed_kr_kimchi', 'Kimchi', ['김치'], FoodCategory.vegetable, 'KR',
          p: 1.7, c: 4, f: 0.5, fb: 1.6, na: 670, tex: 'soft', iddsi: 5),
      _R('seed_kr_tteok', 'Tteok (rice cake)', ['떡'], FoodCategory.carbs, 'KR',
          p: 2.1, c: 50, f: 0.4, fb: 0.6, na: 6, tex: 'soft', iddsi: 5),
      _R('seed_kr_gochujang', 'Gochujang (red pepper paste)', ['고추장'],
          FoodCategory.other, 'KR',
          p: 5, c: 60, f: 1, fb: 5, na: 3500, tex: 'soft', iddsi: 4),
      _R('seed_kr_doenjang', 'Doenjang (soybean paste)', ['된장'],
          FoodCategory.other, 'KR',
          p: 12, c: 13, f: 6, fb: 4, na: 4000, tex: 'soft', iddsi: 4),
      _R('seed_kr_miyeok', 'Miyeok (sea mustard) soup', ['미역국'],
          FoodCategory.beverage, 'KR',
          p: 1.5, c: 1.8, f: 0.6, fb: 0.9, na: 600, tex: 'liquid', iddsi: 0),
      _R('seed_kr_bibimbap', 'Bibimbap (mixed rice bowl)', ['비빔밥'],
          FoodCategory.protein, 'KR',
          p: 8, c: 30, f: 7, fb: 3, na: 600, tex: 'soft', iddsi: 5),
      _R('seed_kr_japchae', 'Japchae (glass noodles stir-fry)', ['잡채'],
          FoodCategory.carbs, 'KR',
          p: 3.5, c: 24, f: 4, fb: 1, na: 350, tex: 'soft', iddsi: 5),
      _R('seed_kr_kimbap', 'Kimbap (seaweed rice roll)', ['김밥'],
          FoodCategory.carbs, 'KR',
          p: 6, c: 28, f: 4, fb: 2, na: 380, tex: 'regular', iddsi: 7),

      // ===== South Asia (IN) =====
      _R('seed_in_dal', 'Dal (lentil curry)', ['daal', 'masoor dal'],
          FoodCategory.protein, 'IN',
          p: 6, c: 14, f: 3, fb: 4, na: 250, tex: 'soft', iddsi: 4),
      _R('seed_in_chapati', 'Chapati (roti)', ['roti', 'phulka'],
          FoodCategory.carbs, 'IN',
          p: 8, c: 56, f: 4, fb: 7, na: 380, tex: 'regular', iddsi: 7),
      _R('seed_in_naan', 'Naan bread', [], FoodCategory.carbs, 'IN',
          p: 9, c: 48, f: 5, fb: 2.2, na: 530, tex: 'regular', iddsi: 7),
      _R('seed_in_paneer', 'Paneer (Indian cheese)', [], FoodCategory.dairy,
          'IN',
          p: 18, c: 1.2, f: 22, fb: 0, na: 18, tex: 'soft', iddsi: 5),
      _R('seed_in_ghee', 'Ghee (clarified butter)', [], FoodCategory.fat, 'IN',
          p: 0.3, c: 0, f: 100, fb: 0, na: 2, tex: 'liquid', iddsi: 0),
      _R('seed_in_basmati', 'Basmati rice (cooked)', [], FoodCategory.carbs,
          'IN',
          p: 3, c: 25, f: 0.4, fb: 0.4, na: 1, tex: 'soft', iddsi: 5),
      _R('seed_in_idli', 'Idli (steamed rice cake)', [], FoodCategory.carbs,
          'IN',
          p: 2, c: 17, f: 0.3, fb: 1, na: 200, tex: 'soft', iddsi: 5),
      _R('seed_in_dosa', 'Dosa (rice-lentil crepe)', [], FoodCategory.carbs,
          'IN',
          p: 3, c: 17, f: 4, fb: 0.8, na: 280, tex: 'soft', iddsi: 5),
      _R('seed_in_chana_masala', 'Chana masala', ['chickpea curry'],
          FoodCategory.protein, 'IN',
          p: 7, c: 18, f: 5, fb: 5, na: 380, tex: 'soft', iddsi: 5),
      _R('seed_in_biryani', 'Chicken biryani', [], FoodCategory.protein, 'IN',
          p: 9, c: 25, f: 7, fb: 1.5, na: 400, tex: 'soft', iddsi: 5),
      _R('seed_in_raita', 'Raita (yogurt sauce)', [], FoodCategory.dairy, 'IN',
          p: 3, c: 4, f: 2, fb: 0.2, na: 200, tex: 'soft', iddsi: 4),
      _R('seed_in_lassi', 'Lassi (yogurt drink)', [], FoodCategory.beverage,
          'IN',
          p: 3, c: 8, f: 2, fb: 0, na: 50, tex: 'liquid', iddsi: 0),
      _R('seed_in_paratha', 'Paratha (layered flatbread)', [],
          FoodCategory.carbs, 'IN',
          p: 8, c: 45, f: 12, fb: 5, na: 350, tex: 'regular', iddsi: 7),
      _R('seed_in_tandoori_chicken', 'Tandoori chicken', [],
          FoodCategory.protein, 'IN',
          p: 28, c: 2, f: 8, fb: 0.3, na: 400, tex: 'regular', iddsi: 7),

      // ===== Mediterranean / Levant (MED) =====
      _R('seed_med_hummus', 'Hummus', [], FoodCategory.protein, 'MED',
          p: 7.9, c: 14, f: 10, fb: 6, na: 380, tex: 'soft', iddsi: 4),
      _R('seed_med_falafel', 'Falafel', [], FoodCategory.protein, 'MED',
          p: 13, c: 32, f: 18, fb: 4.9, na: 290, tex: 'regular', iddsi: 7),
      _R('seed_med_pita', 'Pita bread', [], FoodCategory.carbs, 'MED',
          p: 9, c: 56, f: 1.2, fb: 2.2, na: 540, tex: 'regular', iddsi: 7),
      _R('seed_med_tabbouleh', 'Tabbouleh', [], FoodCategory.vegetable, 'MED',
          p: 2, c: 16, f: 3, fb: 3.5, na: 280, tex: 'regular', iddsi: 7),
      _R('seed_med_baba_ganoush', 'Baba ganoush', [], FoodCategory.fat, 'MED',
          p: 3, c: 12, f: 12, fb: 4, na: 280, tex: 'soft', iddsi: 4),
      _R('seed_med_tzatziki', 'Tzatziki', [], FoodCategory.dairy, 'MED',
          p: 4, c: 4, f: 4, fb: 0.4, na: 300, tex: 'soft', iddsi: 4),
      _R('seed_med_feta', 'Feta cheese', [], FoodCategory.dairy, 'MED',
          p: 14, c: 4.1, f: 21, fb: 0, na: 1116, tex: 'soft', iddsi: 5),
      _R('seed_med_olives', 'Olives', [], FoodCategory.fat, 'MED',
          p: 0.8, c: 3.8, f: 11, fb: 3.2, na: 1556, tex: 'soft', iddsi: 5),
      _R('seed_med_dolma', 'Dolma (stuffed grape leaves)', [],
          FoodCategory.vegetable, 'MED',
          p: 4, c: 16, f: 4, fb: 2, na: 250, tex: 'soft', iddsi: 5),
      _R('seed_med_shakshuka', 'Shakshuka', [], FoodCategory.protein, 'MED',
          p: 7, c: 7, f: 7, fb: 2, na: 350, tex: 'soft', iddsi: 4),

      // ===== Mexico / Latin (MX) =====
      _R('seed_mx_tortilla_corn', 'Corn tortilla', [], FoodCategory.carbs, 'MX',
          p: 5.7, c: 45, f: 2.9, fb: 6.3, na: 45, tex: 'regular', iddsi: 7),
      _R('seed_mx_refried_beans', 'Refried beans', [], FoodCategory.protein,
          'MX',
          p: 5.5, c: 16, f: 2.7, fb: 5.4, na: 470, tex: 'soft', iddsi: 4),
      _R('seed_mx_guacamole', 'Guacamole', [], FoodCategory.fat, 'MX',
          p: 2, c: 9, f: 14, fb: 6, na: 290, tex: 'soft', iddsi: 4),
      _R('seed_mx_salsa', 'Salsa (tomato)', [], FoodCategory.vegetable, 'MX',
          p: 1.5, c: 7, f: 0.3, fb: 1.5, na: 580, tex: 'soft', iddsi: 5),
      _R('seed_mx_tamale', 'Tamale (chicken)', [], FoodCategory.protein, 'MX',
          p: 8, c: 22, f: 10, fb: 2.5, na: 520, tex: 'soft', iddsi: 5),
      _R('seed_mx_taco', 'Beef taco', [], FoodCategory.protein, 'MX',
          p: 14, c: 21, f: 11, fb: 3, na: 480, tex: 'regular', iddsi: 7),
      _R('seed_mx_quesadilla', 'Cheese quesadilla', [], FoodCategory.carbs,
          'MX',
          p: 12, c: 28, f: 14, fb: 2, na: 600, tex: 'regular', iddsi: 7),

      // ===== Southeast Asia (SEA) =====
      _R('seed_sea_pho', 'Pho (Vietnamese noodle soup)', ['phở'],
          FoodCategory.protein, 'SEA',
          p: 7, c: 18, f: 2.5, fb: 1, na: 750, tex: 'liquid', iddsi: 4),
      _R('seed_sea_banh_mi', 'Bánh mì sandwich', [], FoodCategory.protein,
          'SEA',
          p: 13, c: 38, f: 8, fb: 2, na: 720, tex: 'regular', iddsi: 7),
      _R('seed_sea_pad_thai', 'Pad Thai', [], FoodCategory.carbs, 'SEA',
          p: 9, c: 32, f: 8, fb: 2, na: 620, tex: 'soft', iddsi: 5),
      _R('seed_sea_satay', 'Chicken satay', [], FoodCategory.protein, 'SEA',
          p: 22, c: 6, f: 12, fb: 1, na: 560, tex: 'regular', iddsi: 7),
      _R('seed_sea_nasi_goreng', 'Nasi goreng (fried rice)', [],
          FoodCategory.carbs, 'SEA',
          p: 7, c: 32, f: 7, fb: 1.5, na: 580, tex: 'soft', iddsi: 5),
      _R('seed_sea_rendang', 'Beef rendang', [], FoodCategory.protein, 'SEA',
          p: 18, c: 6, f: 18, fb: 1.5, na: 480, tex: 'regular', iddsi: 7),
      _R('seed_sea_laksa', 'Laksa', [], FoodCategory.protein, 'SEA',
          p: 9, c: 22, f: 11, fb: 2, na: 720, tex: 'liquid', iddsi: 4),
      _R('seed_sea_tom_yum', 'Tom yum soup', [], FoodCategory.beverage, 'SEA',
          p: 5, c: 5, f: 3, fb: 1, na: 720, tex: 'liquid', iddsi: 0),
      _R('seed_sea_sticky_rice', 'Sticky rice (Thai)',
          ['glutinous rice', '糯米饭'], FoodCategory.carbs, 'SEA',
          p: 2.6, c: 33, f: 0.2, fb: 0.6, na: 4, tex: 'soft', iddsi: 5),

      // ===== Russia / Eastern Europe (EE) =====
      _R('seed_ee_borscht', 'Borscht (beet soup)', [], FoodCategory.beverage,
          'EE',
          p: 2.5, c: 10, f: 1.5, fb: 2, na: 480, tex: 'liquid', iddsi: 0),
      _R('seed_ee_pelmeni', 'Pelmeni (meat dumplings)', [],
          FoodCategory.protein, 'EE',
          p: 11, c: 27, f: 8, fb: 1.5, na: 380, tex: 'soft', iddsi: 5),
      _R('seed_ee_blini', 'Blini', [], FoodCategory.carbs, 'EE',
          p: 6, c: 25, f: 6, fb: 1, na: 250, tex: 'soft', iddsi: 5),
      _R('seed_ee_kasha', 'Kasha (buckwheat porridge)', [], FoodCategory.carbs,
          'EE',
          p: 3.4, c: 20, f: 0.6, fb: 2.7, na: 4, tex: 'soft', iddsi: 4),

      // ===== North Africa / Middle East (MENA) =====
      _R('seed_mena_couscous_tagine', 'Couscous with tagine', [],
          FoodCategory.protein, 'MENA',
          p: 9, c: 28, f: 6, fb: 3, na: 420, tex: 'soft', iddsi: 5),
      _R('seed_mena_harira', 'Harira soup', [], FoodCategory.beverage, 'MENA',
          p: 5, c: 13, f: 2, fb: 2, na: 480, tex: 'liquid', iddsi: 0),
      _R('seed_mena_shawarma_chicken', 'Chicken shawarma', [],
          FoodCategory.protein, 'MENA',
          p: 22, c: 8, f: 11, fb: 1, na: 600, tex: 'regular', iddsi: 7),
      _R('seed_mena_kibbeh', 'Kibbeh', [], FoodCategory.protein, 'MENA',
          p: 11, c: 22, f: 10, fb: 2, na: 380, tex: 'regular', iddsi: 7),
    ];
    return entries
        .map((entry) => FoodItem(
              id: entry.id,
              name: entry.name,
              category: entry.category,
              aliases: entry.aliases,
              description:
                  'Built-in regional seed catalog entry (jurisdiction: '
                  '${entry.jurisdiction}). Per-100g values are rough generic '
                  'estimates for UX/search; not authoritative.',
              sourceSystem: 'LOCAL_SEED_CATALOG_REGIONAL',
              sourceFoodCode: entry.id,
              jurisdiction: entry.jurisdiction,
              textureClass: entry.tex,
              iddsiLevel: entry.iddsi,
              proteinG: entry.p,
              carbsG: entry.c,
              fatG: entry.f,
              fiberG: entry.fb,
              sodiumMg: entry.na,
            ))
        .toList(growable: false);
  }

  // ---------- regional / comorbid drugs ------------------------------------

  List<DrugDefinition> _regionalDrugs() {
    final entries = <_D>[
      // Cognitive comorbidities (used internationally)
      _D('seed_drug_donepezil', 'Donepezil', ['Aricept'],
          [DrugTag.cholinesteraseInhibitor]),
      _D('seed_drug_galantamine', 'Galantamine', ['Razadyne', 'Reminyl'],
          [DrugTag.cholinesteraseInhibitor]),
      _D('seed_drug_memantine', 'Memantine', ['Namenda', 'Ebixa'],
          const <DrugTag>[]),
      // PD-related anxiety / sleep / restless legs
      _D('seed_drug_clonazepam', 'Clonazepam', ['Klonopin', 'Rivotril'],
          const <DrugTag>[]),
      _D('seed_drug_lorazepam', 'Lorazepam', ['Ativan'], const <DrugTag>[]),
      _D('seed_drug_zolpidem', 'Zolpidem', ['Ambien', 'Stilnox'],
          const <DrugTag>[]),
      _D('seed_drug_mirtazapine', 'Mirtazapine', ['Remeron'],
          const <DrugTag>[]),
      _D('seed_drug_trazodone', 'Trazodone', ['Desyrel'], const <DrugTag>[]),
      // Pain / spasticity often co-prescribed
      _D('seed_drug_gabapentin', 'Gabapentin', ['Neurontin'],
          const <DrugTag>[]),
      _D('seed_drug_pregabalin', 'Pregabalin', ['Lyrica'], const <DrugTag>[]),
      _D('seed_drug_baclofen', 'Baclofen', ['Lioresal'], const <DrugTag>[]),
      _D('seed_drug_tizanidine', 'Tizanidine', ['Zanaflex'], const <DrugTag>[]),
      _D('seed_drug_tramadol', 'Tramadol', ['Ultram'], const <DrugTag>[]),
      // Common GI / nausea (orthostatic / med-related)
      _D('seed_drug_domperidone', 'Domperidone', ['Motilium'],
          const <DrugTag>[]),
      _D('seed_drug_ondansetron', 'Ondansetron', ['Zofran'], const <DrugTag>[]),
      // Common cardiac / metabolic
      _D('seed_drug_losartan', 'Losartan', ['Cozaar'], const <DrugTag>[]),
      _D('seed_drug_bisoprolol', 'Bisoprolol', ['Concor'], const <DrugTag>[]),
      _D('seed_drug_rosuvastatin', 'Rosuvastatin', ['Crestor'],
          const <DrugTag>[]),
      _D('seed_drug_furosemide', 'Furosemide', ['Lasix'], const <DrugTag>[]),
      _D('seed_drug_levothyroxine', 'Levothyroxine', ['Synthroid', 'Euthyrox'],
          const <DrugTag>[]),
      // Vitamin / nutrition often co-prescribed
      _D('seed_drug_vitamin_d3', 'Vitamin D3 (cholecalciferol)', [],
          const <DrugTag>[]),
      _D('seed_drug_vitamin_b12', 'Vitamin B12 (cyanocobalamin)', [],
          const <DrugTag>[]),
    ];
    return entries
        .map((entry) => DrugDefinition(
              id: entry.id,
              genericName: entry.genericName,
              brandNames: entry.brandNames,
              tags: entry.tags,
              notes: 'Built-in regional seed catalog entry. Catalog metadata '
                  'only; the interaction engine still runs only off the '
                  'curated rule registry.',
              sourceSystem: 'LOCAL_SEED_CATALOG_REGIONAL',
              sourceProductCode: entry.id,
              jurisdiction: 'GLOBAL',
            ))
        .toList(growable: false);
  }
}

class _R {
  final String id;
  final String name;
  final List<String> aliases;
  final FoodCategory category;
  final String jurisdiction;
  final double p;
  final double c;
  final double f;
  final double fb;
  final double na;
  final String? tex;
  final int? iddsi;

  _R(
    this.id,
    this.name,
    this.aliases,
    this.category,
    this.jurisdiction, {
    required this.p,
    required this.c,
    required this.f,
    required this.fb,
    required this.na,
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
