import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';

/// Broad seed catalog importer.
///
/// Goal: give the App's food/medication search catalog enough breadth that a
/// typical user can log realistic meals and active prescriptions even before
/// any external (FDC / Ciqual / DailyMed / DPD / EMA / PMDA / China-CDC / FAO)
/// import has run.
///
/// Conservative boundaries:
/// - Per-100g nutrition values are **rough generic estimates** intended for
///   UX display and the conservative recommendation engine, NOT authoritative
///   composition data. They never become `ObservationRecord` rows.
/// - Drug entries are catalog metadata only. `interactionSummary` is left as
///   the empty string. The interaction engine continues to run only off the
///   curated rule registry — adding a drug here does NOT add a rule.
/// - Every item is tagged `sourceSystem = 'LOCAL_SEED_CATALOG'` so downstream
///   consumers can distinguish seed entries from authoritative ETL imports.
/// - One `SourceDocumentRecord` is emitted to record provenance and an
///   explicit `audit_gap` for the unparsed nutrition / interaction fields.
class SeedCatalogImporter {
  const SeedCatalogImporter();

  P0ImportBundle importSeedCatalog() {
    final foods = _seedFoods();
    final drugs = _seedDrugs();
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'LOCAL_SEED_CATALOG',
      externalKey: 'broad_v1',
    );
    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'LOCAL_SEED_CATALOG',
      organization: 'ParkinSUM Companion (built-in catalog)',
      jurisdiction: 'GLOBAL',
      docType: 'app_seed_catalog',
      title: 'Broad app seed catalog (foods + drugs)',
      originUrl: 'app://local-seed-catalog/broad_v1',
      licenseNote: 'Built-in seed catalog. Nutrition values are rough per-100g '
          'generic estimates, not authoritative composition data.',
      language: 'en',
      dataTier: KnowledgeDataTier.p2,
      ingestionStrategy: SourceIngestionStrategy.controlledExport,
      rawPayload: stringifyPayload({
        'food_count': foods.length,
        'drug_count': drugs.length,
        'audit_gaps': <Map<String, Object?>>[
          ImporterAudit.auditGap(
            fieldName: 'food_nutrition_values',
            reason: 'Per-100g protein/carbs/fat/fiber/sodium are rough generic '
                'estimates for UX/search. They are NOT promoted into the '
                'observation table; authoritative values still come from FDC '
                '/ Ciqual / China CDC etc.',
            observedCount: foods.length,
          ),
          ImporterAudit.auditGap(
            fieldName: 'drug_interaction_summary',
            reason:
                'Seed drug entries carry catalog metadata only. The runtime '
                'interaction engine continues to evaluate only the curated '
                'rule registry; adding a drug here does NOT add a rule.',
            observedCount: drugs.length,
          ),
        ],
        'parser_limitation':
            'Seed catalog rows are app-level pointers; they intentionally do '
                'not produce ObservationRecord, ResolvedFactRecord, or '
                'ConceptVariantCrosswalkRecord rows.',
      }),
    );
    return P0ImportBundle(
      sourceDocuments: [sourceDocument],
      projectedFoods: foods,
      projectedDrugs: drugs,
    );
  }

  // ---------- food catalog --------------------------------------------------

  List<FoodItem> _seedFoods() {
    final entries = <_SeedFood>[
      // staples & grains
      _SeedFood('seed_white_rice', 'White rice (cooked)',
          ['rice', 'steamed rice', '米饭'], FoodCategory.carbs,
          p: 2.7, c: 28, f: 0.3, fb: 0.4, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood(
          'seed_brown_rice', 'Brown rice (cooked)', ['糙米饭'], FoodCategory.carbs,
          p: 2.6, c: 23, f: 0.9, fb: 1.8, na: 5, tex: 'soft', iddsi: 5),
      _SeedFood('seed_oatmeal', 'Oatmeal (cooked)', ['porridge', 'oats', '燕麦粥'],
          FoodCategory.carbs,
          p: 2.4, c: 12, f: 1.4, fb: 1.7, na: 4, tex: 'soft', iddsi: 4),
      _SeedFood('seed_bread_white', 'White bread', ['toast', '白面包'],
          FoodCategory.carbs,
          p: 9, c: 49, f: 3.2, fb: 2.7, na: 491, tex: 'regular', iddsi: 7),
      _SeedFood('seed_bread_whole_wheat', 'Whole wheat bread', ['全麦面包'],
          FoodCategory.carbs,
          p: 13, c: 41, f: 4.2, fb: 7, na: 400, tex: 'regular', iddsi: 7),
      _SeedFood('seed_pasta', 'Pasta (cooked)', ['spaghetti', 'noodles', '意面'],
          FoodCategory.carbs,
          p: 5.8, c: 30, f: 1.1, fb: 1.8, na: 6, tex: 'soft', iddsi: 5),
      _SeedFood('seed_quinoa', 'Quinoa (cooked)', ['藜麦'], FoodCategory.carbs,
          p: 4.4, c: 21, f: 1.9, fb: 2.8, na: 7, tex: 'soft', iddsi: 5),
      _SeedFood('seed_couscous', 'Couscous (cooked)', ['cous cous'],
          FoodCategory.carbs,
          p: 3.8, c: 23, f: 0.2, fb: 1.4, na: 5, tex: 'soft', iddsi: 5),
      _SeedFood('seed_potato_boiled', 'Boiled potato', ['potatoes', '土豆'],
          FoodCategory.carbs,
          p: 1.9, c: 17, f: 0.1, fb: 1.8, na: 5, tex: 'soft', iddsi: 5),
      _SeedFood('seed_sweet_potato', 'Sweet potato (baked)',
          ['yam', '红薯', '番薯'], FoodCategory.carbs,
          p: 2, c: 21, f: 0.1, fb: 3.3, na: 36, tex: 'soft', iddsi: 5),
      _SeedFood('seed_corn', 'Corn (cooked)', ['玉米'], FoodCategory.carbs,
          p: 3.4, c: 21, f: 1.5, fb: 2.4, na: 1, tex: 'regular', iddsi: 7),
      _SeedFood('seed_congee', 'Rice congee', ['粥', '稀饭'], FoodCategory.carbs,
          p: 1.1, c: 12, f: 0.1, fb: 0.2, na: 90, tex: 'liquid', iddsi: 3),

      // proteins (animal)
      _SeedFood('seed_chicken_breast', 'Chicken breast (cooked)', ['鸡胸肉'],
          FoodCategory.protein,
          p: 31, c: 0, f: 3.6, fb: 0, na: 74, tex: 'regular', iddsi: 7),
      _SeedFood('seed_chicken_thigh', 'Chicken thigh (cooked)', ['鸡腿'],
          FoodCategory.protein,
          p: 26, c: 0, f: 11, fb: 0, na: 86, tex: 'regular', iddsi: 7),
      _SeedFood('seed_pork_loin', 'Pork loin (cooked)', ['pork', '猪肉', '里脊'],
          FoodCategory.protein,
          p: 27, c: 0, f: 9, fb: 0, na: 65, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_beef_lean', 'Lean beef (cooked)', ['牛肉'], FoodCategory.protein,
          p: 26, c: 0, f: 11, fb: 0, na: 72, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_lamb', 'Lamb (cooked)', ['mutton', '羊肉'], FoodCategory.protein,
          p: 25, c: 0, f: 21, fb: 0, na: 72, tex: 'regular', iddsi: 7),
      _SeedFood('seed_salmon', 'Salmon (cooked)', ['三文鱼'], FoodCategory.protein,
          p: 25, c: 0, f: 13, fb: 0, na: 75, tex: 'regular', iddsi: 6),
      _SeedFood('seed_tuna_canned', 'Canned tuna in water', ['金枪鱼'],
          FoodCategory.protein,
          p: 26, c: 0, f: 1, fb: 0, na: 320, tex: 'regular', iddsi: 6),
      _SeedFood('seed_white_fish', 'White fish (cooked)',
          ['cod', 'tilapia', '鳕鱼'], FoodCategory.protein,
          p: 22, c: 0, f: 1, fb: 0, na: 82, tex: 'soft', iddsi: 6),
      _SeedFood('seed_shrimp', 'Shrimp (cooked)', ['prawns', '虾'],
          FoodCategory.protein,
          p: 24, c: 0.2, f: 0.3, fb: 0, na: 111, tex: 'regular', iddsi: 6),
      _SeedFood('seed_egg_whole', 'Whole egg (boiled)', ['eggs', '鸡蛋'],
          FoodCategory.protein,
          p: 13, c: 1.1, f: 11, fb: 0, na: 124, tex: 'soft', iddsi: 5),
      _SeedFood('seed_egg_white', 'Egg white', ['蛋白'], FoodCategory.protein,
          p: 11, c: 0.7, f: 0.2, fb: 0, na: 166, tex: 'soft', iddsi: 4),

      // proteins (plant)
      _SeedFood('seed_tofu_firm', 'Firm tofu', ['豆腐'], FoodCategory.protein,
          p: 8, c: 1.9, f: 4.8, fb: 0.3, na: 7, tex: 'soft', iddsi: 5),
      _SeedFood('seed_tempeh', 'Tempeh', ['天贝'], FoodCategory.protein,
          p: 19, c: 9, f: 11, fb: 0, na: 9, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_lentils', 'Lentils (cooked)', ['扁豆'], FoodCategory.protein,
          p: 9, c: 20, f: 0.4, fb: 7.9, na: 2, tex: 'soft', iddsi: 5),
      _SeedFood('seed_chickpeas', 'Chickpeas (cooked)', ['garbanzo', '鹰嘴豆'],
          FoodCategory.protein,
          p: 9, c: 27, f: 2.6, fb: 7.6, na: 7, tex: 'soft', iddsi: 5),
      _SeedFood('seed_black_beans', 'Black beans (cooked)', ['黑豆'],
          FoodCategory.protein,
          p: 8.9, c: 24, f: 0.5, fb: 8.7, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_kidney_beans', 'Kidney beans (cooked)', ['芸豆'],
          FoodCategory.protein,
          p: 8.7, c: 23, f: 0.5, fb: 6.4, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_edamame', 'Edamame', ['毛豆'], FoodCategory.protein,
          p: 11, c: 9, f: 5, fb: 5.2, na: 6, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_peanut_butter', 'Peanut butter', ['花生酱'], FoodCategory.fat,
          p: 25, c: 20, f: 50, fb: 6, na: 17, tex: 'soft', iddsi: 4),

      // dairy & alternatives
      _SeedFood('seed_milk_whole', 'Whole milk', ['牛奶'], FoodCategory.dairy,
          p: 3.2, c: 4.8, f: 3.3, fb: 0, na: 43, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_milk_skim', 'Skim milk', ['脱脂牛奶'], FoodCategory.dairy,
          p: 3.4, c: 5, f: 0.1, fb: 0, na: 42, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_yogurt_plain', 'Plain yogurt', ['酸奶'], FoodCategory.dairy,
          p: 3.5, c: 4.7, f: 3.3, fb: 0, na: 46, tex: 'soft', iddsi: 4),
      _SeedFood(
          'seed_greek_yogurt', 'Greek yogurt', ['希腊酸奶'], FoodCategory.dairy,
          p: 9, c: 3.6, f: 0.4, fb: 0, na: 36, tex: 'soft', iddsi: 4),
      _SeedFood(
          'seed_cheese_cheddar', 'Cheddar cheese', ['奶酪'], FoodCategory.dairy,
          p: 25, c: 1.3, f: 33, fb: 0, na: 621, tex: 'regular', iddsi: 7),
      _SeedFood('seed_cottage_cheese', 'Cottage cheese', ['cottage'],
          FoodCategory.dairy,
          p: 11, c: 3.4, f: 4.3, fb: 0, na: 364, tex: 'soft', iddsi: 4),
      _SeedFood('seed_soy_milk', 'Soy milk (unsweetened)', ['豆浆'],
          FoodCategory.beverage,
          p: 3.3, c: 1.8, f: 1.8, fb: 0.5, na: 51, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_almond_milk', 'Almond milk (unsweetened)', ['杏仁奶'],
          FoodCategory.beverage,
          p: 0.6, c: 0.6, f: 1.2, fb: 0.4, na: 72, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_oat_milk', 'Oat milk', ['燕麦奶'], FoodCategory.beverage,
          p: 1, c: 7, f: 1.5, fb: 0.8, na: 42, tex: 'liquid', iddsi: 0),

      // vegetables
      _SeedFood(
          'seed_broccoli', 'Broccoli (cooked)', ['西兰花'], FoodCategory.vegetable,
          p: 2.4, c: 7, f: 0.4, fb: 3.3, na: 41, tex: 'soft', iddsi: 6),
      _SeedFood(
          'seed_carrot', 'Carrot (cooked)', ['胡萝卜'], FoodCategory.vegetable,
          p: 0.8, c: 8.2, f: 0.2, fb: 3, na: 58, tex: 'soft', iddsi: 5),
      _SeedFood(
          'seed_spinach', 'Spinach (cooked)', ['菠菜'], FoodCategory.vegetable,
          p: 3, c: 3.8, f: 0.3, fb: 2.4, na: 70, tex: 'soft', iddsi: 4),
      _SeedFood('seed_kale', 'Kale (cooked)', ['羽衣甘蓝'], FoodCategory.vegetable,
          p: 2.9, c: 5.6, f: 0.4, fb: 2, na: 23, tex: 'soft', iddsi: 5),
      _SeedFood(
          'seed_lettuce', 'Lettuce', ['romaine', '生菜'], FoodCategory.vegetable,
          p: 1.4, c: 2.9, f: 0.2, fb: 1.3, na: 28, tex: 'regular', iddsi: 7),
      _SeedFood('seed_tomato', 'Tomato', ['番茄'], FoodCategory.vegetable,
          p: 0.9, c: 3.9, f: 0.2, fb: 1.2, na: 5, tex: 'soft', iddsi: 5),
      _SeedFood('seed_cucumber', 'Cucumber', ['黄瓜'], FoodCategory.vegetable,
          p: 0.7, c: 3.6, f: 0.1, fb: 0.5, na: 2, tex: 'regular', iddsi: 7),
      _SeedFood('seed_zucchini', 'Zucchini (cooked)', ['courgette', '西葫芦'],
          FoodCategory.vegetable,
          p: 1.2, c: 3.1, f: 0.3, fb: 1, na: 8, tex: 'soft', iddsi: 5),
      _SeedFood('seed_bell_pepper', 'Bell pepper', ['capsicum', '彩椒'],
          FoodCategory.vegetable,
          p: 1, c: 6, f: 0.3, fb: 2.1, na: 4, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_cabbage', 'Cabbage (cooked)', ['卷心菜'], FoodCategory.vegetable,
          p: 1, c: 5.5, f: 0.1, fb: 1.9, na: 8, tex: 'soft', iddsi: 5),
      _SeedFood(
          'seed_bok_choy', 'Bok choy (cooked)', ['小白菜'], FoodCategory.vegetable,
          p: 1.6, c: 1.8, f: 0.2, fb: 1, na: 34, tex: 'soft', iddsi: 5),
      _SeedFood('seed_eggplant', 'Eggplant (cooked)', ['aubergine', '茄子'],
          FoodCategory.vegetable,
          p: 0.8, c: 8.7, f: 0.2, fb: 2.5, na: 1, tex: 'soft', iddsi: 4),
      _SeedFood(
          'seed_mushroom', 'Mushrooms (cooked)', ['蘑菇'], FoodCategory.vegetable,
          p: 3.1, c: 4.6, f: 0.5, fb: 2.2, na: 7, tex: 'soft', iddsi: 5),
      _SeedFood('seed_onion', 'Onion (cooked)', ['洋葱'], FoodCategory.vegetable,
          p: 1.4, c: 10, f: 0.2, fb: 1.4, na: 4, tex: 'soft', iddsi: 5),
      _SeedFood('seed_garlic', 'Garlic', ['大蒜'], FoodCategory.vegetable,
          p: 6.4, c: 33, f: 0.5, fb: 2.1, na: 17, tex: 'soft', iddsi: 5),
      _SeedFood('seed_avocado', 'Avocado', ['鳄梨', '牛油果'], FoodCategory.fat,
          p: 2, c: 8.5, f: 15, fb: 6.7, na: 7, tex: 'soft', iddsi: 4),

      // fruits
      _SeedFood('seed_apple', 'Apple', ['苹果'], FoodCategory.fruit,
          p: 0.3, c: 14, f: 0.2, fb: 2.4, na: 1, tex: 'regular', iddsi: 7),
      _SeedFood('seed_banana', 'Banana', ['香蕉'], FoodCategory.fruit,
          p: 1.1, c: 23, f: 0.3, fb: 2.6, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_orange', 'Orange', ['橙子'], FoodCategory.fruit,
          p: 0.9, c: 12, f: 0.1, fb: 2.4, na: 0, tex: 'soft', iddsi: 5),
      _SeedFood('seed_grapes', 'Grapes', ['葡萄'], FoodCategory.fruit,
          p: 0.7, c: 18, f: 0.2, fb: 0.9, na: 2, tex: 'regular', iddsi: 7),
      _SeedFood('seed_strawberries', 'Strawberries', ['草莓'], FoodCategory.fruit,
          p: 0.7, c: 7.7, f: 0.3, fb: 2, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_blueberries', 'Blueberries', ['蓝莓'], FoodCategory.fruit,
          p: 0.7, c: 14, f: 0.3, fb: 2.4, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_pear', 'Pear', ['梨'], FoodCategory.fruit,
          p: 0.4, c: 15, f: 0.1, fb: 3.1, na: 1, tex: 'regular', iddsi: 7),
      _SeedFood('seed_watermelon', 'Watermelon', ['西瓜'], FoodCategory.fruit,
          p: 0.6, c: 7.6, f: 0.2, fb: 0.4, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_mango', 'Mango', ['芒果'], FoodCategory.fruit,
          p: 0.8, c: 15, f: 0.4, fb: 1.6, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_pineapple', 'Pineapple', ['菠萝'], FoodCategory.fruit,
          p: 0.5, c: 13, f: 0.1, fb: 1.4, na: 1, tex: 'soft', iddsi: 5),
      _SeedFood('seed_kiwi', 'Kiwi', ['猕猴桃'], FoodCategory.fruit,
          p: 1.1, c: 15, f: 0.5, fb: 3, na: 3, tex: 'soft', iddsi: 5),
      _SeedFood('seed_peach', 'Peach', ['桃'], FoodCategory.fruit,
          p: 0.9, c: 10, f: 0.3, fb: 1.5, na: 0, tex: 'soft', iddsi: 5),

      // fats / oils / nuts
      _SeedFood('seed_olive_oil', 'Olive oil', ['橄榄油'], FoodCategory.fat,
          p: 0, c: 0, f: 100, fb: 0, na: 2, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_butter', 'Butter', ['黄油'], FoodCategory.fat,
          p: 0.9, c: 0.1, f: 81, fb: 0, na: 11, tex: 'soft', iddsi: 4),
      _SeedFood('seed_almonds', 'Almonds', ['杏仁'], FoodCategory.fat,
          p: 21, c: 22, f: 50, fb: 12, na: 1, tex: 'regular', iddsi: 7),
      _SeedFood('seed_walnuts', 'Walnuts', ['核桃'], FoodCategory.fat,
          p: 15, c: 14, f: 65, fb: 6.7, na: 2, tex: 'regular', iddsi: 7),
      _SeedFood('seed_chia_seeds', 'Chia seeds', ['奇亚籽'], FoodCategory.fat,
          p: 17, c: 42, f: 31, fb: 34, na: 16, tex: 'regular', iddsi: 7),

      // beverages
      _SeedFood('seed_water', 'Water', ['水'], FoodCategory.beverage,
          p: 0, c: 0, f: 0, fb: 0, na: 0, tex: 'liquid', iddsi: 0),
      _SeedFood(
          'seed_coffee_black', 'Coffee (black)', ['咖啡'], FoodCategory.beverage,
          p: 0.1, c: 0, f: 0, fb: 0, na: 2, tex: 'liquid', iddsi: 0),
      _SeedFood(
          'seed_tea_green', 'Green tea (brewed)', ['绿茶'], FoodCategory.beverage,
          p: 0, c: 0, f: 0, fb: 0, na: 1, tex: 'liquid', iddsi: 0),
      _SeedFood(
          'seed_tea_black', 'Black tea (brewed)', ['红茶'], FoodCategory.beverage,
          p: 0, c: 0.3, f: 0, fb: 0, na: 3, tex: 'liquid', iddsi: 0),
      _SeedFood(
          'seed_orange_juice', 'Orange juice', ['橙汁'], FoodCategory.beverage,
          p: 0.7, c: 10, f: 0.2, fb: 0.2, na: 1, tex: 'liquid', iddsi: 0),
      _SeedFood(
          'seed_apple_juice', 'Apple juice', ['苹果汁'], FoodCategory.beverage,
          p: 0.1, c: 11, f: 0.1, fb: 0.2, na: 4, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_broth_chicken', 'Chicken broth', ['stock', '鸡汤'],
          FoodCategory.beverage,
          p: 1.5, c: 0.4, f: 0.5, fb: 0, na: 360, tex: 'liquid', iddsi: 0),

      // common ready / convenience meals
      _SeedFood('seed_sandwich_turkey', 'Turkey sandwich', ['三明治'],
          FoodCategory.protein,
          p: 12, c: 25, f: 5, fb: 2, na: 600, tex: 'regular', iddsi: 7),
      _SeedFood('seed_pizza_cheese', 'Cheese pizza (slice)', ['披萨'],
          FoodCategory.carbs,
          p: 11, c: 33, f: 10, fb: 2, na: 600, tex: 'regular', iddsi: 7),
      _SeedFood('seed_burger_beef', 'Beef burger', ['hamburger', '汉堡'],
          FoodCategory.protein,
          p: 17, c: 27, f: 14, fb: 2, na: 480, tex: 'regular', iddsi: 7),
      _SeedFood('seed_fries', 'French fries', ['薯条'], FoodCategory.carbs,
          p: 3.4, c: 41, f: 15, fb: 3.8, na: 290, tex: 'regular', iddsi: 7),
      _SeedFood('seed_salad_garden', 'Garden salad (no dressing)', ['沙拉'],
          FoodCategory.vegetable,
          p: 1.2, c: 4.7, f: 0.2, fb: 1.7, na: 14, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_dumpling_pork', 'Pork dumplings', ['饺子'], FoodCategory.protein,
          p: 8, c: 24, f: 7, fb: 1.5, na: 380, tex: 'soft', iddsi: 5),
      _SeedFood(
          'seed_curry_chicken', 'Chicken curry', ['咖喱鸡'], FoodCategory.protein,
          p: 14, c: 7, f: 9, fb: 1.5, na: 400, tex: 'soft', iddsi: 5),
      _SeedFood('seed_miso_soup', 'Miso soup', ['味噌汤'], FoodCategory.beverage,
          p: 2, c: 3, f: 1, fb: 0.5, na: 700, tex: 'liquid', iddsi: 0),
      _SeedFood('seed_ramen_basic', 'Ramen noodles (basic)', ['拉面'],
          FoodCategory.carbs,
          p: 7, c: 36, f: 5, fb: 1.5, na: 800, tex: 'soft', iddsi: 5),
      _SeedFood(
          'seed_chocolate_dark', 'Dark chocolate', ['黑巧克力'], FoodCategory.other,
          p: 7.8, c: 46, f: 43, fb: 11, na: 20, tex: 'regular', iddsi: 7),
      _SeedFood(
          'seed_ice_cream', 'Vanilla ice cream', ['冰淇淋'], FoodCategory.dairy,
          p: 3.5, c: 24, f: 11, fb: 0.7, na: 80, tex: 'soft', iddsi: 4),
    ];
    return entries
        .map((entry) => FoodItem(
              id: entry.id,
              name: entry.name,
              category: entry.category,
              aliases: entry.aliases,
              description:
                  'Built-in seed catalog entry. Per-100g values are rough '
                  'generic estimates for UX/search; not authoritative.',
              sourceSystem: 'LOCAL_SEED_CATALOG',
              sourceFoodCode: entry.id,
              jurisdiction: 'GLOBAL',
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

  // ---------- drug catalog --------------------------------------------------

  List<DrugDefinition> _seedDrugs() {
    final entries = <_SeedDrug>[
      // Parkinson's-specific (already covered by ETL imports — kept here so
      // the app catalog has a baseline before any external import runs).
      _SeedDrug('seed_drug_levodopa_carbidopa', 'Levodopa/Carbidopa',
          ['Sinemet', 'Atamet'], [DrugTag.levodopaLike]),
      _SeedDrug('seed_drug_levodopa_benserazide', 'Levodopa/Benserazide',
          ['Madopar', 'Prolopa'], [DrugTag.levodopaLike]),
      _SeedDrug('seed_drug_entacapone', 'Entacapone', ['Comtan'],
          [DrugTag.comtInhibitor]),
      _SeedDrug('seed_drug_opicapone', 'Opicapone', ['Ongentys'],
          [DrugTag.comtInhibitor]),
      _SeedDrug(
          'seed_drug_rasagiline', 'Rasagiline', ['Azilect'], [DrugTag.maoi]),
      _SeedDrug('seed_drug_selegiline', 'Selegiline', ['Eldepryl', 'Zelapar'],
          [DrugTag.maoi]),
      _SeedDrug(
          'seed_drug_safinamide', 'Safinamide', ['Xadago'], [DrugTag.maoi]),
      _SeedDrug('seed_drug_pramipexole', 'Pramipexole', ['Mirapex'],
          [DrugTag.dopamineAgonist]),
      _SeedDrug('seed_drug_ropinirole', 'Ropinirole', ['Requip'],
          [DrugTag.dopamineAgonist]),
      _SeedDrug('seed_drug_rotigotine', 'Rotigotine', ['Neupro'],
          [DrugTag.dopamineAgonist]),
      _SeedDrug('seed_drug_apomorphine', 'Apomorphine', ['Apokyn'],
          [DrugTag.dopamineAgonist]),
      _SeedDrug('seed_drug_amantadine', 'Amantadine', ['Symmetrel', 'Gocovri'],
          [DrugTag.amantadineLike]),
      _SeedDrug('seed_drug_istradefylline', 'Istradefylline', ['Nourianz'],
          [DrugTag.adenosineA2aAntagonist]),
      _SeedDrug('seed_drug_rivastigmine', 'Rivastigmine', ['Exelon'],
          [DrugTag.cholinesteraseInhibitor]),
      _SeedDrug('seed_drug_droxidopa', 'Droxidopa', ['Northera'],
          [DrugTag.pressorAgent]),
      _SeedDrug('seed_drug_midodrine', 'Midodrine', ['ProAmatine'],
          [DrugTag.pressorAgent]),

      // Common comorbid medications (catalog entries only; no rules added).
      _SeedDrug('seed_drug_atorvastatin', 'Atorvastatin', ['Lipitor'],
          const <DrugTag>[]),
      _SeedDrug(
          'seed_drug_simvastatin', 'Simvastatin', ['Zocor'], const <DrugTag>[]),
      _SeedDrug('seed_drug_metformin', 'Metformin', ['Glucophage'],
          const <DrugTag>[]),
      _SeedDrug('seed_drug_lisinopril', 'Lisinopril', ['Prinivil', 'Zestril'],
          const <DrugTag>[]),
      _SeedDrug(
          'seed_drug_amlodipine', 'Amlodipine', ['Norvasc'], const <DrugTag>[]),
      _SeedDrug('seed_drug_omeprazole', 'Omeprazole', ['Prilosec'],
          const <DrugTag>[]),
      _SeedDrug('seed_drug_pantoprazole', 'Pantoprazole', ['Protonix'],
          const <DrugTag>[]),
      _SeedDrug(
          'seed_drug_warfarin', 'Warfarin', ['Coumadin'], const <DrugTag>[]),
      _SeedDrug(
          'seed_drug_apixaban', 'Apixaban', ['Eliquis'], const <DrugTag>[]),
      _SeedDrug('seed_drug_aspirin', 'Aspirin', ['Bayer'], const <DrugTag>[]),
      _SeedDrug('seed_drug_acetaminophen', 'Acetaminophen',
          ['Tylenol', 'Paracetamol'], const <DrugTag>[]),
      _SeedDrug('seed_drug_ibuprofen', 'Ibuprofen', ['Advil', 'Motrin'],
          const <DrugTag>[]),
      _SeedDrug(
          'seed_drug_sertraline', 'Sertraline', ['Zoloft'], const <DrugTag>[]),
      _SeedDrug('seed_drug_quetiapine', 'Quetiapine', ['Seroquel'],
          const <DrugTag>[]),
      _SeedDrug('seed_drug_melatonin', 'Melatonin', [], const <DrugTag>[]),
      _SeedDrug('seed_drug_calcium_carbonate', 'Calcium carbonate', ['Tums'],
          const <DrugTag>[]),
      _SeedDrug('seed_drug_iron_sulfate', 'Ferrous sulfate',
          ['iron supplement', '硫酸亚铁'], [DrugTag.mineralSupplement]),
      _SeedDrug('seed_drug_polyethylene_glycol', 'Polyethylene glycol 3350',
          ['Miralax', 'PEG 3350'], [DrugTag.laxative]),
      _SeedDrug('seed_drug_senna', 'Senna', ['Senokot'], [DrugTag.laxative]),
    ];
    return entries
        .map((entry) => DrugDefinition(
              id: entry.id,
              genericName: entry.genericName,
              brandNames: entry.brandNames,
              tags: entry.tags,
              notes: 'Built-in seed catalog entry. Catalog metadata only; the '
                  'interaction engine still runs only off the curated rule '
                  'registry.',
              sourceSystem: 'LOCAL_SEED_CATALOG',
              sourceProductCode: entry.id,
              jurisdiction: 'GLOBAL',
            ))
        .toList(growable: false);
  }
}

class _SeedFood {
  final String id;
  final String name;
  final List<String> aliases;
  final FoodCategory category;
  final double p;
  final double c;
  final double f;
  final double fb;
  final double na;
  final String? tex;
  final int? iddsi;

  _SeedFood(
    this.id,
    this.name,
    this.aliases,
    this.category, {
    required this.p,
    required this.c,
    required this.f,
    required this.fb,
    required this.na,
    this.tex,
    this.iddsi,
  });
}

class _SeedDrug {
  final String id;
  final String genericName;
  final List<String> brandNames;
  final List<DrugTag> tags;

  _SeedDrug(this.id, this.genericName, this.brandNames, this.tags);
}
