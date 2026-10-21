import '../../domain/entities/food_serving_reference.dart';

/// Reference amounts per product category used as the category default and
/// as the target of the source-portion rule (see
/// `food_serving_reference_resolver.dart`).
///
/// Sources, read from the current regulation text on 2026-10-20:
/// - FDA, 21 CFR 101.12(b) Table 2, reference amounts customarily consumed
///   per eating occasion (RACC), as amended at 81 FR 34000 (27 May 2016).
/// - USDA FSIS, 9 CFR 317.312(b) Table 2 (meat) and 9 CFR 381.412(b) Table 2
///   (poultry); the FDA table does not cover meat and poultry cuts.
/// - Household measures: 21 CFR 101.9(b)(5)(viii) (1 tsp = 5 mL,
///   1 tbsp = 15 mL, 1 cup = 240 mL, 1 fl oz = 30 mL).
///
/// The amounts are labeling reference amounts, used here only so foods can
/// be compared on a realistic amount. They are not portion advice, and the
/// app claims no labeling compliance. Product-category wording is abridged.
const String fdaRaccCitation = '21 CFR 101.12(b), Table 2';
const String fsisMeatRaccCitation = '9 CFR 317.312(b), Table 2';
const String fsisPoultryRaccCitation = '9 CFR 381.412(b), Table 2';

const List<FoodServingReferenceCategory> foodServingReferenceCategories = [
  // --- Dairy -----------------------------------------------------------------
  FoodServingReferenceCategory(
    id: 'milk_and_milk_substitutes',
    productCategory:
        'Milk, milk-substitute beverages, milk-based drinks (includes soy '
        'beverage)',
    statedAmount: '240 mL',
    amount: 240,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'yogurt',
    productCategory: 'Yogurt',
    statedAmount: '170 g',
    amount: 170,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'cheese_cottage',
    productCategory: 'Cheese, cottage',
    statedAmount: '110 g',
    amount: 110,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'cheese_used_as_ingredient',
    productCategory:
        'Cheese used primarily as ingredients, e.g., dry cottage cheese, '
        'ricotta cheese',
    statedAmount: '55 g',
    amount: 55,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'cheese_grated_hard',
    productCategory: 'Cheese, grated hard, e.g., Parmesan, Romano',
    statedAmount: '5 g',
    amount: 5,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'cheese_all_others',
    productCategory:
        'Cheese, all others except those listed as separate categories '
        '(includes cream cheese and cheese spread)',
    statedAmount: '30 g',
    amount: 30,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'ice_cream_and_frozen_desserts',
    productCategory:
        'Ice cream, frozen yogurt, sherbet, frozen flavored and sweetened ice '
        'and pops, frozen fruit juices',
    statedAmount: '2/3 cup',
    amount: 160,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  // --- Eggs, fats, nuts --------------------------------------------------------
  FoodServingReferenceCategory(
    id: 'eggs',
    productCategory: 'Eggs (all sizes)',
    statedAmount: '50 g',
    amount: 50,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'fats_and_oils',
    productCategory: 'Butter, margarine, oil, shortening',
    statedAmount: '1 tbsp',
    amount: 15,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'mayonnaise_type',
    productCategory: 'Mayonnaise, sandwich spreads, mayonnaise-type dressings',
    statedAmount: '15 g',
    amount: 15,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'nuts_and_seeds',
    productCategory: 'Nuts, seeds and mixtures, all types',
    statedAmount: '30 g',
    amount: 30,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'nut_and_seed_butters',
    productCategory: 'Nut and seed butters, pastes, or creams',
    statedAmount: '2 tbsp',
    amount: 30,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  // --- Grains and bakery -------------------------------------------------------
  FoodServingReferenceCategory(
    id: 'grains_prepared',
    productCategory: 'Grains, e.g., rice, barley, plain (prepared)',
    statedAmount: '140 g prepared',
    amount: 140,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'grains_dry',
    productCategory: 'Grains, e.g., rice, barley, plain (dry)',
    statedAmount: '45 g dry',
    amount: 45,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'pastas_prepared',
    productCategory: 'Pastas, plain (prepared)',
    statedAmount: '140 g prepared',
    amount: 140,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'pastas_dry',
    productCategory: 'Pastas, plain (dry)',
    statedAmount: '55 g dry',
    amount: 55,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'breads_and_rolls',
    productCategory: 'Breads (excluding sweet quick type), rolls',
    statedAmount: '50 g',
    amount: 50,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'tortillas_and_biscuits',
    productCategory:
        'Biscuits, croissants, tortillas, soft bread sticks, soft pretzels, '
        'corn bread',
    statedAmount: '55 g',
    amount: 55,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'hot_cereal_prepared',
    productCategory:
        'Breakfast cereals (hot cereal type), hominy grits (prepared)',
    statedAmount: '1 cup prepared',
    amount: 240,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'hot_cereal_dry',
    productCategory: 'Breakfast cereals (hot cereal type), plain dry cereal',
    statedAmount: '40 g plain dry cereal',
    amount: 40,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'flours_and_cornmeal',
    productCategory: 'Flours or cornmeal',
    statedAmount: '30 g',
    amount: 30,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'starches',
    productCategory: 'Starches, e.g., cornstarch, potato starch, tapioca',
    statedAmount: '10 g',
    amount: 10,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  // --- Fish, meat, poultry, legumes -------------------------------------------
  FoodServingReferenceCategory(
    id: 'fish_shellfish_cooked',
    productCategory:
        'Entrees without sauce, e.g., plain or fried fish and shellfish '
        '(cooked)',
    statedAmount: '85 g cooked',
    amount: 85,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'fish_shellfish_uncooked',
    productCategory:
        'Entrees without sauce, e.g., plain or fried fish and shellfish '
        '(uncooked)',
    statedAmount: '110 g uncooked',
    amount: 110,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'fish_shellfish_canned',
    productCategory: 'Fish, shellfish, or game meat, canned',
    statedAmount: '85 g',
    amount: 85,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'fish_smoked_or_pickled',
    productCategory:
        'Smoked or pickled fish, shellfish, or game meat; fish or shellfish '
        'spread',
    statedAmount: '55 g',
    amount: 55,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'meat_cuts_ready_to_serve',
    productCategory: 'Entrees without sauce, cuts of meat (ready-to-serve)',
    statedAmount: '85 g ready-to-serve',
    amount: 85,
    unit: FoodServingAmountUnit.grams,
    citation: fsisMeatRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'meat_cuts_ready_to_cook',
    productCategory: 'Entrees without sauce, cuts of meat (ready-to-cook)',
    statedAmount: '114 g ready-to-cook',
    amount: 114,
    unit: FoodServingAmountUnit.grams,
    citation: fsisMeatRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'poultry_cuts_ready_to_serve',
    productCategory: 'Entrees without sauce, poultry cuts (ready-to-serve)',
    statedAmount: '85 g ready-to-serve',
    amount: 85,
    unit: FoodServingAmountUnit.grams,
    citation: fsisPoultryRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'poultry_cuts_ready_to_cook',
    productCategory: 'Entrees without sauce, poultry cuts (ready-to-cook)',
    statedAmount: '114 g ready-to-cook',
    amount: 114,
    unit: FoodServingAmountUnit.grams,
    citation: fsisPoultryRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'tofu_and_tempeh',
    productCategory: 'Tofu, tempeh',
    statedAmount: '85 g',
    amount: 85,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'beans_prepared',
    productCategory: 'Beans, plain or in sauce (others, prepared)',
    statedAmount: '90 g prepared',
    amount: 90,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'beans_in_sauce_or_refried',
    productCategory:
        'Beans in sauce or canned in liquid and refried beans (prepared)',
    statedAmount: '130 g prepared',
    amount: 130,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'beans_dry',
    productCategory: 'Beans, plain or in sauce (dry)',
    statedAmount: '35 g dry',
    amount: 35,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  // --- Fruits and vegetables ---------------------------------------------------
  FoodServingReferenceCategory(
    id: 'fruits_all_other',
    productCategory:
        'All other fruits (except those listed as separate categories), '
        'fresh, canned or frozen',
    statedAmount: '140 g',
    amount: 140,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'fruits_dried',
    productCategory: 'Fruits, dried',
    statedAmount: '40 g',
    amount: 40,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'avocado',
    productCategory: 'Fruits used primarily as ingredients, avocado',
    statedAmount: '50 g',
    amount: 50,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'watermelon',
    productCategory: 'Watermelon',
    statedAmount: '280 g',
    amount: 280,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'fruit_juices',
    productCategory: 'Juices, nectars, fruit drinks',
    statedAmount: '240 mL',
    amount: 240,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'juices_used_as_ingredients',
    productCategory:
        'Juices used as ingredients, e.g., lemon juice, lime juice',
    statedAmount: '5 mL',
    amount: 5,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'vegetables_all_other',
    productCategory:
        'All other vegetables without sauce: fresh, canned, or frozen '
        '(fresh or frozen)',
    statedAmount: '85 g',
    amount: 85,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'vegetables_for_garnish_or_flavor',
    productCategory:
        'Vegetables primarily used for garnish or flavor (e.g., pimento, '
        'parsley)',
    statedAmount: '4 g',
    amount: 4,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'vegetable_pastes',
    productCategory: 'Vegetable pastes, e.g., tomato paste',
    statedAmount: '30 g',
    amount: 30,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'pickles_and_pickled_vegetables',
    productCategory: 'Pickles and pickled vegetables, all types',
    statedAmount: '30 g',
    amount: 30,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'sprouts',
    productCategory: 'Sprouts, all types: fresh or canned',
    statedAmount: '1/4 cup',
    amount: 60,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'potatoes_plain',
    productCategory:
        'Potatoes and sweet potatoes/yams, plain (fresh or frozen)',
    statedAmount: '110 g',
    amount: 110,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  // --- Soups, salads, mixed dishes, dips ---------------------------------------
  FoodServingReferenceCategory(
    id: 'soups',
    productCategory: 'Soups, all varieties',
    statedAmount: '245 g',
    amount: 245,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'salads_all_other',
    productCategory:
        'All other salads, e.g., egg, fish, shellfish, bean, fruit, or '
        'vegetable salads',
    statedAmount: '100 g',
    amount: 100,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'mixed_dishes_measurable_with_cup',
    productCategory:
        'Mixed dishes measurable with cup, e.g., casseroles, hash, pot pies, '
        'stews',
    statedAmount: '1 cup',
    amount: 240,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'mixed_dishes_not_measurable_with_cup',
    productCategory:
        'Mixed dishes not measurable with cup, e.g., burritos, enchiladas, '
        'pizza, all types of sandwiches',
    statedAmount: '140 g',
    amount: 140,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'dips_and_salsa',
    productCategory: 'Dips, e.g., bean dips, dairy-based dips, salsa',
    statedAmount: '2 tbsp',
    amount: 30,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  // --- Beverages, sweeteners, condiments ----------------------------------------
  FoodServingReferenceCategory(
    id: 'beverages_other',
    productCategory:
        'Carbonated and noncarbonated beverages, wine coolers, water',
    statedAmount: '360 mL',
    amount: 360,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'honey_jams_jellies',
    productCategory:
        'Honey, jams, jellies, fruit butter, molasses, fruit pastes, fruit '
        'chutneys',
    statedAmount: '1 tbsp',
    amount: 15,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'sugar',
    productCategory: 'Sugar',
    statedAmount: '8 g',
    amount: 8,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'syrups',
    productCategory: 'Syrups',
    statedAmount: '30 mL',
    amount: 30,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'condiments_major',
    productCategory:
        'Major condiments, e.g., catsup, steak sauce, soy sauce, vinegar',
    statedAmount: '1 tbsp',
    amount: 15,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'salt',
    productCategory: 'Salt, salt substitutes, seasoning salts',
    statedAmount: '1/4 tsp',
    amount: 1.25,
    unit: FoodServingAmountUnit.millilitres,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'olives',
    productCategory: 'Olives',
    statedAmount: '15 g',
    amount: 15,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
  FoodServingReferenceCategory(
    id: 'candies_all_other',
    productCategory: 'All other candies',
    statedAmount: '30 g',
    amount: 30,
    unit: FoodServingAmountUnit.grams,
    citation: fdaRaccCitation,
  ),
];

/// [foodServingReferenceCategories] by id.
final Map<String, FoodServingReferenceCategory>
foodServingReferenceCategoriesById = Map.unmodifiable({
  for (final category in foodServingReferenceCategories) category.id: category,
});
