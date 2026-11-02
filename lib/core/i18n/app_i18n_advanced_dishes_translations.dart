import '../constants/dish_catalog.dart';

/// Next meal → Advanced: simple preparation examples with catalog-derived
/// nutrition. Descriptive only: no dish is called best, recommended or safe,
/// a texture option is not swallowing advice, and no value is a target.
/// Other language families fall back to English pending native-language
/// review; key and placeholder parity is checked by tests.
const Map<String, Map<String, String>> kAdvancedDishesUiTranslations = {
  'en': {
    'shell.group.meals': 'Meals & food',
    'dishes.title': 'Advanced: dishes & preparation',
    'dishes.subtitle':
        'Simple ways to prepare common dishes, with ingredients and '
        'nutrition per serving calculated from the food catalog.',
    'dishes.framing':
        'These are simple preparation examples with nutrition calculated '
        'from the food catalog, not dietary advice. Review diet changes with '
        'a qualified clinician or dietitian.',
    'dishes.back': 'Back to Next meal',
    'dishes.open_next_meal': 'Open Next meal',
    'dishes.search_label': 'Search dishes or ingredients',
    'dishes.search_clear': 'Clear search',
    'dishes.region_title': 'Region',
    'dishes.region_mine': 'My region ({region})',
    'dishes.region_all': 'All regions',
    'dishes.region_others': 'Other regions',
    'dishes.region_none_for_mine':
        'No example dishes are tagged for {region} yet, so all regions are '
        'shown.',
    'dishes.texture_title': 'Texture',
    'dishes.texture_any': 'Any texture',
    'dishes.texture_filter_note':
        'A texture matches dishes prepared at it or offering it as a texture '
        'option.',
    'dishes.texture_boundary':
        'Texture tags use IDDSI level names to describe how a dish is '
        'prepared here. The dishes have not been tested with IDDSI methods, '
        'and a texture option is not swallowing advice; texture needs are set '
        'with a speech-language pathologist or clinician.',
    'dishes.texture.regular': 'Regular',
    'dishes.texture.softBiteSized': 'Soft & bite-sized',
    'dishes.texture.mincedMoist': 'Minced & moist',
    'dishes.texture.pureed': 'Pureed',
    'dishes.texture.liquidised': 'Liquidised',
    'dishes.texture_tag': '{texture} (IDDSI {level} wording)',
    'dishes.texture_option': 'Texture option: {texture}',
    'dishes.result_count': '{count} dishes',
    'dishes.empty': 'No dishes match these filters.',
    'dishes.clear_filters': 'Clear filters',
    'dishes.minutes': '{minutes} min',
    'dishes.time_detail': 'Prep {prep} min · cook {cook} min',
    'dishes.servings': 'Servings: {count}',
    'dishes.open_dish': 'Open {name}',
    'dishes.ingredients_title': 'Ingredients per serving',
    'dishes.grams': '{grams} g',
    'dishes.not_in_catalog': 'Not in catalog · nutrition unknown',
    'dishes.id_unresolved': 'Catalog entry not found · nutrition unknown',
    'dishes.no_mass_basis': 'No per-100 g basis · nutrition unknown',
    'dishes.open_catalog': 'Open the catalog entry for {name}',
    'dishes.steps_title': 'Preparation',
    'dishes.step_n': 'Step {n}',
    'dishes.step_label': '{step}: {text}',
    'dishes.equipment_title': 'Equipment',
    'dishes.equipment.pot': 'Pot',
    'dishes.equipment.saucepan': 'Saucepan',
    'dishes.equipment.fryingPan': 'Frying pan',
    'dishes.equipment.wok': 'Wok or large frying pan',
    'dishes.equipment.steamer': 'Steamer',
    'dishes.equipment.oven': 'Oven',
    'dishes.equipment.blender': 'Blender',
    'dishes.equipment.riceCooker': 'Rice cooker',
    'dishes.equipment.bowl': 'Mixing bowl',
    'dishes.texture_section': 'Texture',
    'dishes.nutrition_title': 'Nutrition per serving',
    'dishes.nutrient.protein': 'Protein',
    'dishes.nutrient.energy': 'Energy',
    'dishes.nutrient.fat': 'Fat',
    'dishes.nutrient.carbohydrate': 'Carbohydrate (available)',
    'dishes.nutrient.fiber': 'Fiber',
    'dishes.nutrient.competingLnaa': 'Competing LNAA',
    'dishes.value_unknown': 'Unknown',
    'dishes.value_partial': '{value} from {known} of {total} ingredients',
    'dishes.value_partial_caption':
        'known for {known} of {total} ingredients; the rest unknown',
    'dishes.completeness':
        'Catalog coverage: {resolved} of {total} ingredients '
        '({percent}% of ingredient weight)',
    'dishes.complete_all': 'Every nutrient is known for every ingredient.',
    'dishes.incomplete_note':
        'Some values are unknown. A partial figure covers only the '
        'ingredients that are known; unknown values are never counted as '
        'zero.',
    'dishes.nutrition_note':
        'Catalog values per 100 g, scaled to the grams listed and added up. '
        'Cooking losses and water changes are not modelled.',
    'dishes.lnaa_note':
        'Competing LNAA: leucine, isoleucine, valine, phenylalanine, tyrosine '
        'and tryptophan, from source amino-acid profiles only.',
    'dishes.provenance_button': 'Sources and details',
    'dishes.provenance_title': 'Ingredient sources',
    'dishes.provenance_intro':
        'Each ingredient with its catalog food and source. Values are per '
        'serving.',
    'dishes.provenance_catalog_food': 'Catalog food: {name}',
    'dishes.provenance_source': 'Source: {system} · code {code}',
    'dishes.provenance_missing': 'Not reported by the source: {fields}',
    'dishes.provenance_lnaa_measured':
        'LNAA from the source amino-acid profile',
    'dishes.provenance_lnaa_zero': 'LNAA 0: the source reports 0 g protein',
    'dishes.provenance_lnaa_unknown':
        'LNAA unknown: no complete amino-acid profile',
    'dishes.provenance_version': 'Dish set: {version}',
    'dishes.close': 'Close',
    'dishes.add_to_plate': 'Add ingredients to plate',
    'dishes.add_to_plate_note':
        'Sends the {count} catalog ingredients of one serving to the '
        'Next-meal plate, as servings rounded to the nearest half. '
        'Ingredients not in the catalog are left out.',
    'dishes.added_to_plate':
        '{count} catalog ingredients sent to the Next-meal plate; {skipped} '
        'not in the catalog were left out.',
    'dishes.add_to_plate_unavailable':
        'None of these ingredients are in the catalog, so there is nothing to '
        'add.',
    'dishes.region.CN': 'China',
    'dishes.region.US': 'United States',
    'dishes.region.CA': 'Canada',
    'dishes.region.FR': 'France',
    'dishes.region.ES': 'Spain',
    'dishes.region.JP': 'Japan',
    'dishes.region.KR': 'Korea',
    'dishes.region.IN': 'India',
    'dishes.region.MX': 'Mexico',
    'dishes.region.VN': 'Vietnam',
    'dishes.region.TH': 'Thailand',
    'dishes.region.ID': 'Indonesia',
    'dishes.region.RU': 'Russia',
    'dishes.region.PL': 'Poland',
    'dishes.region.SA': 'Saudi Arabia',
  },
  'zh': {
    'shell.group.meals': '餐食与食物',
    'dishes.title': '进阶：菜式与做法',
    'dishes.subtitle': '常见菜式的简单做法，附食材和按食物目录计算的每份营养。',
    'dishes.framing': '这里是简单的做法示例，营养数值按食物目录计算，不是饮食建议。调整饮食前，请与合格的临床医生或营养师讨论。',
    'dishes.back': '返回下一餐',
    'dishes.open_next_meal': '打开下一餐',
    'dishes.search_label': '搜索菜式或食材',
    'dishes.search_clear': '清除搜索',
    'dishes.region_title': '地区',
    'dishes.region_mine': '我的地区（{region}）',
    'dishes.region_all': '全部地区',
    'dishes.region_others': '其他地区',
    'dishes.region_none_for_mine': '暂时没有标注为{region}的示例菜式，因此显示全部地区。',
    'dishes.texture_title': '质地',
    'dishes.texture_any': '不限质地',
    'dishes.texture_filter_note': '按质地筛选时，包括按该质地制作或提供该质地选项的菜式。',
    'dishes.texture_boundary':
        '质地标签借用 IDDSI 等级名称来描述这里的做法。这些菜式未经 IDDSI 方法测试，质地选项也不是吞咽建议；质地需求请与言语治疗师或临床医生确定。',
    'dishes.texture.regular': '普通',
    'dishes.texture.softBiteSized': '软质、一口大小',
    'dishes.texture.mincedMoist': '细碎湿润',
    'dishes.texture.pureed': '泥状',
    'dishes.texture.liquidised': '流质',
    'dishes.texture_tag': '{texture}（IDDSI {level} 级用语）',
    'dishes.texture_option': '质地选项：{texture}',
    'dishes.result_count': '{count} 道菜',
    'dishes.empty': '没有符合这些筛选条件的菜式。',
    'dishes.clear_filters': '清除筛选',
    'dishes.minutes': '{minutes} 分钟',
    'dishes.time_detail': '准备 {prep} 分钟 · 烹饪 {cook} 分钟',
    'dishes.servings': '份数：{count}',
    'dishes.open_dish': '打开{name}',
    'dishes.ingredients_title': '每份食材',
    'dishes.grams': '{grams} 克',
    'dishes.not_in_catalog': '目录中没有 · 营养未知',
    'dishes.id_unresolved': '未找到目录条目 · 营养未知',
    'dishes.no_mass_basis': '没有每 100 克基准 · 营养未知',
    'dishes.open_catalog': '打开{name}的目录条目',
    'dishes.steps_title': '做法',
    'dishes.step_n': '第 {n} 步',
    'dishes.step_label': '{step}：{text}',
    'dishes.equipment_title': '用具',
    'dishes.equipment.pot': '汤锅',
    'dishes.equipment.saucepan': '小锅',
    'dishes.equipment.fryingPan': '平底锅',
    'dishes.equipment.wok': '炒锅或大平底锅',
    'dishes.equipment.steamer': '蒸锅',
    'dishes.equipment.oven': '烤箱',
    'dishes.equipment.blender': '搅拌机',
    'dishes.equipment.riceCooker': '电饭煲',
    'dishes.equipment.bowl': '调料碗',
    'dishes.texture_section': '质地',
    'dishes.nutrition_title': '每份营养',
    'dishes.nutrient.protein': '蛋白质',
    'dishes.nutrient.energy': '能量',
    'dishes.nutrient.fat': '脂肪',
    'dishes.nutrient.carbohydrate': '碳水化合物（可利用）',
    'dishes.nutrient.fiber': '膳食纤维',
    'dishes.nutrient.competingLnaa': '竞争性大分子中性氨基酸（LNAA）',
    'dishes.value_unknown': '未知',
    'dishes.value_partial': '{value}（{total} 种食材中已知 {known} 种）',
    'dishes.value_partial_caption': '{total} 种食材中已知 {known} 种，其余未知',
    'dishes.completeness': '目录覆盖：{total} 种食材中有 {resolved} 种（占食材重量的 {percent}%）',
    'dishes.complete_all': '每种食材的各项营养都已知。',
    'dishes.incomplete_note': '部分数值未知。部分合计只包括已知的食材；未知数值从不按零计算。',
    'dishes.nutrition_note': '按目录中每 100 克的数值，换算到所列克数后相加。未计算烹饪损耗和水分变化。',
    'dishes.lnaa_note': '竞争性 LNAA：亮氨酸、异亮氨酸、缬氨酸、苯丙氨酸、酪氨酸和色氨酸，仅采用来源中的氨基酸数据。',
    'dishes.provenance_button': '来源与详情',
    'dishes.provenance_title': '食材来源',
    'dishes.provenance_intro': '每种食材对应的目录食物及其来源。数值为每份。',
    'dishes.provenance_catalog_food': '目录食物：{name}',
    'dishes.provenance_source': '来源：{system} · 编码 {code}',
    'dishes.provenance_missing': '来源未报告：{fields}',
    'dishes.provenance_lnaa_measured': 'LNAA 来自来源的氨基酸数据',
    'dishes.provenance_lnaa_zero': 'LNAA 为 0：来源报告蛋白质为 0 克',
    'dishes.provenance_lnaa_unknown': 'LNAA 未知：没有完整的氨基酸数据',
    'dishes.provenance_version': '菜式集：{version}',
    'dishes.close': '关闭',
    'dishes.add_to_plate': '把食材加入餐盘',
    'dishes.add_to_plate_note':
        '把一份的 {count} 种目录食材发送到下一餐的餐盘，份数四舍五入到半份。目录中没有的食材不会加入。',
    'dishes.added_to_plate':
        '已把 {count} 种目录食材发送到下一餐的餐盘；{skipped} 种目录中没有的食材未加入。',
    'dishes.add_to_plate_unavailable': '这些食材都不在目录中，没有可加入的内容。',
    'dishes.region.CN': '中国',
    'dishes.region.US': '美国',
    'dishes.region.CA': '加拿大',
    'dishes.region.FR': '法国',
    'dishes.region.ES': '西班牙',
    'dishes.region.JP': '日本',
    'dishes.region.KR': '韩国',
    'dishes.region.IN': '印度',
    'dishes.region.MX': '墨西哥',
    'dishes.region.VN': '越南',
    'dishes.region.TH': '泰国',
    'dishes.region.ID': '印度尼西亚',
    'dishes.region.RU': '俄罗斯',
    'dishes.region.PL': '波兰',
    'dishes.region.SA': '沙特阿拉伯',
  },
};

/// Dish names, steps, ingredient names and texture notes from the dish
/// catalog as dictionary entries, so the localization safety lint scans
/// them with the rest of the app copy.
Map<String, Map<String, String>> advancedDishCatalogTranslations() {
  final en = <String, String>{};
  final zh = <String, String>{};
  for (final dish in kDishCatalog) {
    final base = 'dishes.catalog.${dish.id}';
    en['$base.name'] = dish.name.en;
    zh['$base.name'] = dish.name.zh;
    for (final (index, step) in dish.steps.indexed) {
      en['$base.step.${index + 1}'] = step.en;
      zh['$base.step.${index + 1}'] = step.zh;
    }
    for (final (index, ingredient) in dish.ingredients.indexed) {
      en['$base.ingredient.${index + 1}'] = ingredient.name.en;
      zh['$base.ingredient.${index + 1}'] = ingredient.name.zh;
    }
    if (dish.textureOption case final option?) {
      en['$base.texture_option'] = option.note.en;
      zh['$base.texture_option'] = option.note.zh;
    }
  }
  return {'en': en, 'zh': zh};
}
