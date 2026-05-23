import 'dart:convert';

import '../../domain/entities/cdss_records.dart';

const regionalJurisdictionMapSeed = <RegionJurisdictionMapRecord>[
  RegionJurisdictionMapRecord(
    regionCode: 'CN',
    jurisdictionChainJson: '["CN","APAC","GLOBAL"]',
    foodSourcePriorityJson:
        '["CHINA_FCD_IF_AVAILABLE","USDA_FDC","CIQUAL","GLOBAL"]',
    drugSourcePriorityJson: '["NMPA_IF_AVAILABLE","GLOBAL"]',
    dietGuidelineSource: 'CN_DIETARY_GUIDELINES_2022',
  ),
  RegionJurisdictionMapRecord(
    regionCode: 'US',
    jurisdictionChainJson: '["US","NA","GLOBAL"]',
    foodSourcePriorityJson: '["USDA_FDC","EUROFIR","GLOBAL"]',
    drugSourcePriorityJson: '["DAILYMED","DRUGSATFDA","GLOBAL"]',
    dietGuidelineSource: 'MPLATE_US',
  ),
  RegionJurisdictionMapRecord(
    regionCode: 'CA',
    jurisdictionChainJson: '["CA","NA","GLOBAL"]',
    foodSourcePriorityJson:
        '["CA_SPECIFIC_IF_AVAILABLE","USDA_FDC","EUROFIR","GLOBAL"]',
    drugSourcePriorityJson: '["HEALTH_CANADA_DPD","GLOBAL"]',
    dietGuidelineSource: 'CANADA_FOOD_GUIDE',
  ),
  RegionJurisdictionMapRecord(
    regionCode: 'FR',
    jurisdictionChainJson: '["FR","EU","GLOBAL"]',
    foodSourcePriorityJson: '["CIQUAL","EUROFIR","GLOBAL"]',
    drugSourcePriorityJson: '["EMA","GLOBAL"]',
    dietGuidelineSource: 'FR_FBDG',
  ),
  RegionJurisdictionMapRecord(
    regionCode: 'JP',
    jurisdictionChainJson: '["JP","APAC","GLOBAL"]',
    foodSourcePriorityJson:
        '["JP_SPECIFIC_IF_AVAILABLE","EUROFIR","USDA_FDC","GLOBAL"]',
    drugSourcePriorityJson: '["PMDA","GLOBAL"]',
    dietGuidelineSource: 'JP_SPINNING_TOP',
  ),
  RegionJurisdictionMapRecord(
    regionCode: 'GLOBAL',
    jurisdictionChainJson: '["GLOBAL"]',
    foodSourcePriorityJson: '["USDA_FDC","CIQUAL","EUROFIR"]',
    drugSourcePriorityJson: '["DAILYMED","EMA","HEALTH_CANADA_DPD"]',
    dietGuidelineSource: 'GLOBAL_TEMPLATE',
  ),
];

const countryDietProfileSeed = <CountryDietProfileRecord>[
  CountryDietProfileRecord(
    countryCode: 'CN',
    guidelineSource:
        'Dietary Guidelines for Chinese (2022) / FAO China page / NHC guidance notices',
    mealPatternJson:
        '{"preferred_meal_slots":["breakfast","lunch","dinner"],"regular_hours_emphasis":true}',
    stapleFoodsJson:
        '["rice","noodles","tubers","whole_grains","millet","mixed_beans"]',
    preferredProteinSourcesJson:
        '["soybeans","bean_products","soy_milk","tofu","fish","eggs","lean_meat"]',
    avoidanceNotesJson:
        '["reduce_salt","limit_cooking_oil","adequate_water","increase_beans","add_milk","low_protein_breakfast_if_ldopa_morning"]',
  ),
  CountryDietProfileRecord(
    countryCode: 'US',
    guidelineSource: 'MyPlate + Dietary Guidelines for Americans',
    mealPatternJson:
        '{"preferred_meal_slots":["breakfast","lunch","dinner"],"regular_hours_emphasis":true}',
    stapleFoodsJson: '["whole_grains","fruit","vegetables"]',
    preferredProteinSourcesJson: '["beans","fish","poultry","dairy"]',
    avoidanceNotesJson: '["low_protein_breakfast_if_ldopa_morning"]',
  ),
  CountryDietProfileRecord(
    countryCode: 'CA',
    guidelineSource: 'Canada Food Guide',
    mealPatternJson:
        '{"preferred_meal_slots":["breakfast","lunch","dinner"],"regular_hours_emphasis":true}',
    stapleFoodsJson: '["whole_grains","vegetables","fruit"]',
    preferredProteinSourcesJson: '["plant_protein","fish","beans","dairy"]',
    avoidanceNotesJson:
        '["water_preferred","low_protein_breakfast_if_ldopa_morning"]',
  ),
  CountryDietProfileRecord(
    countryCode: 'FR',
    guidelineSource: 'French dietary guidance baseline',
    mealPatternJson:
        '{"preferred_meal_slots":["breakfast","lunch","dinner"],"regular_hours_emphasis":true}',
    stapleFoodsJson: '["bread","grains","vegetables"]',
    preferredProteinSourcesJson: '["fish","legumes","dairy","eggs"]',
    avoidanceNotesJson:
        '["moderate_salt","low_protein_breakfast_if_ldopa_morning"]',
  ),
  CountryDietProfileRecord(
    countryCode: 'JP',
    guidelineSource: 'Japanese Food Guide Spinning Top',
    mealPatternJson:
        '{"preferred_meal_slots":["breakfast","lunch","dinner"],"regular_hours_emphasis":true}',
    stapleFoodsJson: '["rice","noodles","bread"]',
    preferredProteinSourcesJson: '["fish","beans","milk_products"]',
    avoidanceNotesJson:
        '["reduce_salt","reduce_fat","low_protein_breakfast_if_ldopa_morning"]',
  ),
  CountryDietProfileRecord(
    countryCode: 'GLOBAL',
    guidelineSource: 'Global fallback template',
    mealPatternJson:
        '{"preferred_meal_slots":["breakfast","lunch","dinner"],"regular_hours_emphasis":true}',
    stapleFoodsJson: '["whole_grains","vegetables","fruit"]',
    preferredProteinSourcesJson: '["beans","fish","eggs"]',
    avoidanceNotesJson: '["low_protein_breakfast_if_ldopa_morning"]',
  ),
];

const mealTemplateSeed = <MealTemplateRecord>[
  MealTemplateRecord(
    mealTemplateId: 'template_cn_breakfast_soft',
    countryCode: 'CN',
    mealSlot: 'breakfast',
    templateJson:
        '{"base":["rice","millet_or_oats","vegetables"],"optional":["soy_milk","fruit"],"protein_bias":"light","hydration":"water_or_tea"}',
    textureLevel: 'soft',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_cn_lunch_balanced',
    countryCode: 'CN',
    mealSlot: 'lunch',
    templateJson:
        '{"base":["rice_or_noodles","vegetables"],"optional":["tofu","fish","egg","mushrooms"],"protein_bias":"moderate","hydration":"water_or_soup"}',
    textureLevel: 'regular',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_cn_dinner_light',
    countryCode: 'CN',
    mealSlot: 'dinner',
    templateJson:
        '{"base":["rice_or_tubers","vegetables"],"optional":["tofu","fish","leafy_greens"],"protein_bias":"moderate","hydration":"water_or_tea"}',
    textureLevel: 'regular',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_cn_snack_low_conflict',
    countryCode: 'CN',
    mealSlot: 'snack',
    templateJson:
        '{"base":["fruit"],"optional":["walnuts_small_portion","warm_water"],"protein_bias":"light","hydration":"water"}',
    textureLevel: 'soft',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_us_breakfast_soft',
    countryCode: 'US',
    mealSlot: 'breakfast',
    templateJson:
        '{"base":["fruit","whole_grains"],"protein_bias":"light","hydration":"water"}',
    textureLevel: 'soft',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_ca_breakfast_soft',
    countryCode: 'CA',
    mealSlot: 'breakfast',
    templateJson:
        '{"base":["fruit","whole_grains"],"protein_bias":"light","hydration":"water"}',
    textureLevel: 'soft',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_fr_breakfast_soft',
    countryCode: 'FR',
    mealSlot: 'breakfast',
    templateJson:
        '{"base":["fruit","bread"],"protein_bias":"light","hydration":"water_or_tea"}',
    textureLevel: 'soft',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_jp_breakfast_soft',
    countryCode: 'JP',
    mealSlot: 'breakfast',
    templateJson:
        '{"base":["rice","fruit"],"protein_bias":"light","hydration":"tea_or_water"}',
    textureLevel: 'soft',
  ),
  MealTemplateRecord(
    mealTemplateId: 'template_global_breakfast_soft',
    countryCode: 'GLOBAL',
    mealSlot: 'breakfast',
    templateJson:
        '{"base":["fruit","whole_grains"],"protein_bias":"light","hydration":"water"}',
    textureLevel: 'soft',
  ),
];

const localeResourceBundleSeed = <LocaleResourceBundleRecord>[
  LocaleResourceBundleRecord(
    localeTag: 'zh-CN',
    namespace: 'recommendation',
    key: 'fallback_source',
    text: '当前地区暂无权威食品底库，已回退到次优来源。',
    pluralRule: null,
  ),
  LocaleResourceBundleRecord(
    localeTag: 'zh-CN',
    namespace: 'recommendation',
    key: 'safe_pick',
    text: '已按安全规则、地区模板和近期历史完成排序。',
    pluralRule: null,
  ),
];

String encodeJsonList(List<Object> values) => jsonEncode(values);
