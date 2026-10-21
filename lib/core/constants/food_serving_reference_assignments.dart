/// Product category of each built-in catalog food, keyed by app food id, for
/// the serving rule in `food_serving_reference_resolver.dart`. Category ids
/// refer to `food_serving_reference_amounts.dart`.
///
/// Each entry is a reviewed, explicit assignment: the app's coarse
/// `FoodCategory` cannot pick a reference amount (dairy alone spans milk,
/// yogurt and cheese). A food missing from this map has no category: it can
/// still use its source's NLEA serving, otherwise its values stay per 100 g.
/// Deliberately unassigned: unsweetened coffee and tea, alcoholic beverages,
/// protein powders, egg white, yolk and substitute, fresh seaweed, miso,
/// fermented tofu, fish roe, salted mackerel, turkey liver, vital wheat
/// gluten, french fries, falafel, dosa and rice congee (no verified reference
/// row fits them).
const Map<String, String> foodServingReferenceCategoryAssignments = {
  // --- Built-in CIQUAL catalog (buildP0FoodCatalog) --------------------------
  'food_banana': 'fruits_all_other',
  'food_spinach': 'vegetables_all_other',
  'food_tofu': 'tofu_and_tempeh',
  'food_milk': 'milk_and_milk_substitutes',
  'food_beef': 'meat_cuts_ready_to_serve',
  'food_chicken_breast': 'poultry_cuts_ready_to_serve',
  'food_apple': 'fruits_all_other',
  'food_blueberry': 'fruits_all_other',
  'food_tomato': 'vegetables_all_other',
  'food_broccoli': 'vegetables_all_other',
  'food_oats': 'hot_cereal_dry',
  'food_brown_rice': 'grains_prepared',
  'food_salmon': 'fish_shellfish_cooked',
  'food_fava_beans': 'vegetables_all_other',
  'food_potato_boiled': 'potatoes_plain',
  'food_walnuts': 'nuts_and_seeds',
  'food_olive_oil': 'fats_and_oils',
  'food_cheddar_cheese': 'cheese_all_others',
  'food_egg_boiled': 'eggs',

  // --- USDA SR Legacy reference catalog (buildReferenceFoodCatalog) ----------
  // Beverages and condiments
  'food_ref_usda_167747': 'juices_used_as_ingredients', // lemon juice, raw
  'food_ref_usda_169098': 'fruit_juices', // orange juice, raw
  'food_ref_usda_172446': 'milk_and_milk_substitutes', // soy milk
  'food_ref_usda_171403': 'mayonnaise_type',
  'food_ref_usda_173468': 'salt',
  'food_ref_usda_174277': 'condiments_major', // soy sauce (shoyu)
  'food_ref_usda_174278': 'condiments_major', // soy sauce (tamari)
  'food_ref_usda_173469': 'condiments_major', // vinegar, cider
  // Dairy
  'food_ref_usda_171251': 'cheese_all_others', // Swiss
  'food_ref_usda_172175': 'cheese_all_others', // blue
  'food_ref_usda_172177': 'cheese_all_others', // brie
  'food_ref_usda_172178': 'cheese_all_others', // camembert
  'food_ref_usda_173414': 'cheese_all_others', // cheddar
  'food_ref_usda_173419': 'cheese_all_others', // edam
  'food_ref_usda_173420': 'cheese_all_others', // feta
  'food_ref_usda_171243': 'cheese_all_others', // limburger
  'food_ref_usda_171244': 'cheese_all_others', // mozzarella
  'food_ref_usda_171250': 'cheese_all_others', // roquefort
  'food_ref_usda_173418': 'cheese_all_others', // cream cheese
  'food_ref_usda_171247': 'cheese_grated_hard', // parmesan, grated
  'food_ref_usda_171248': 'cheese_used_as_ingredient', // ricotta
  'food_ref_usda_172179': 'cheese_cottage',
  'food_ref_usda_171278': 'milk_and_milk_substitutes', // goat
  'food_ref_usda_171279': 'milk_and_milk_substitutes', // human
  'food_ref_usda_171269': 'milk_and_milk_substitutes', // nonfat
  'food_ref_usda_171267': 'milk_and_milk_substitutes', // 2 %
  'food_ref_usda_170882': 'milk_and_milk_substitutes', // sheep
  'food_ref_usda_171265': 'milk_and_milk_substitutes', // whole
  'food_ref_usda_170886': 'yogurt', // plain, low fat
  'food_ref_usda_171284': 'yogurt', // plain, whole milk
  // Eggs, fats and oils
  'food_ref_usda_173423': 'eggs', // fried
  'food_ref_usda_173424': 'eggs', // hard-boiled
  'food_ref_usda_171287': 'eggs', // raw
  'food_ref_usda_173410': 'fats_and_oils', // butter
  'food_ref_usda_171412': 'fats_and_oils', // coconut oil
  'food_ref_usda_171413': 'fats_and_oils', // olive oil
  'food_ref_usda_171410': 'fats_and_oils', // peanut oil
  'food_ref_usda_171411': 'fats_and_oils', // soybean oil
  // Fish and shellfish
  'food_ref_usda_171952': 'fish_shellfish_uncooked', // carp, raw
  'food_ref_usda_175165': 'fish_shellfish_uncooked', // catfish, raw
  'food_ref_usda_171955': 'fish_shellfish_uncooked', // cod, raw
  'food_ref_usda_175169': 'fish_shellfish_uncooked', // crayfish, raw
  'food_ref_usda_175164': 'fish_shellfish_uncooked', // king crab, raw
  'food_ref_usda_173672': 'fish_shellfish_uncooked', // mackerel, raw
  'food_ref_usda_175129': 'fish_shellfish_uncooked', // pollock, raw
  'food_ref_usda_175167': 'fish_shellfish_uncooked', // salmon farmed, raw
  'food_ref_usda_173686': 'fish_shellfish_uncooked', // salmon wild, raw
  'food_ref_usda_175156': 'fish_shellfish_uncooked', // tuna skipjack, raw
  'food_ref_usda_175159': 'fish_shellfish_uncooked', // tuna yellowfin, raw
  'food_ref_usda_171956': 'fish_shellfish_cooked', // cod, cooked
  'food_ref_usda_175168': 'fish_shellfish_cooked', // salmon, cooked
  'food_ref_usda_173668': 'fish_smoked_or_pickled', // herring, kippered
  'food_ref_usda_173687': 'fish_smoked_or_pickled', // salmon, smoked
  'food_ref_usda_175139': 'fish_shellfish_canned', // sardines
  'food_ref_usda_175158': 'fish_shellfish_canned', // tuna, canned
  // Fruits
  'food_ref_usda_171688': 'fruits_all_other', // apple
  'food_ref_usda_171697': 'fruits_all_other', // apricot
  'food_ref_usda_173944': 'fruits_all_other', // banana
  'food_ref_usda_173946': 'fruits_all_other', // blackberries
  'food_ref_usda_171711': 'fruits_all_other', // blueberries
  'food_ref_usda_171719': 'fruits_all_other', // cherries
  'food_ref_usda_168195': 'fruits_all_other', // clementine
  'food_ref_usda_174673': 'fruits_all_other', // grapefruit
  'food_ref_usda_174683': 'fruits_all_other', // grapes
  'food_ref_usda_168153': 'fruits_all_other', // kiwifruit
  'food_ref_usda_169910': 'fruits_all_other', // mango
  'food_ref_usda_169097': 'fruits_all_other', // orange
  'food_ref_usda_169926': 'fruits_all_other', // papaya
  'food_ref_usda_169928': 'fruits_all_other', // peach
  'food_ref_usda_169118': 'fruits_all_other', // pear
  'food_ref_usda_169124': 'fruits_all_other', // pineapple
  'food_ref_usda_169130': 'fruits_all_other', // plantain
  'food_ref_usda_169134': 'fruits_all_other', // pomegranate
  'food_ref_usda_167762': 'fruits_all_other', // strawberries
  'food_ref_usda_171705': 'avocado',
  'food_ref_usda_167765': 'watermelon',
  'food_ref_usda_168191': 'fruits_dried', // dates
  'food_ref_usda_174665': 'fruits_dried', // figs, dried
  'food_ref_usda_168162': 'fruits_dried', // prunes
  'food_ref_usda_168165': 'fruits_dried', // raisins
  'food_ref_usda_169094': 'olives',
  // Grains, pasta and bakery
  'food_ref_usda_169704': 'grains_prepared', // brown rice, cooked
  'food_ref_usda_170686': 'grains_prepared', // buckwheat groats, cooked
  'food_ref_usda_168917': 'grains_prepared', // quinoa, cooked
  'food_ref_usda_169746': 'grains_prepared', // spelt, cooked
  'food_ref_usda_168918': 'grains_prepared', // teff, cooked
  'food_ref_usda_169753': 'grains_prepared', // white rice, cooked
  'food_ref_usda_169757': 'grains_prepared', // white rice, cooked
  'food_ref_usda_169708': 'grains_prepared', // white rice, parboiled
  'food_ref_usda_168897': 'grains_prepared', // wild rice, cooked
  'food_ref_usda_169737': 'pastas_prepared', // pasta, cooked
  'food_ref_usda_168910': 'pastas_prepared', // whole-wheat pasta, cooked
  'food_ref_usda_168914': 'pastas_prepared', // rice noodles, cooked
  'food_ref_usda_168907': 'pastas_prepared', // soba, cooked
  'food_ref_usda_169700': 'pastas_prepared', // couscous, cooked
  'food_ref_usda_169703': 'grains_dry', // brown rice, dry
  'food_ref_usda_170688': 'grains_dry', // bulgur, dry
  'food_ref_usda_169702': 'grains_dry', // millet, dry
  'food_ref_usda_169705': 'grains_dry', // oats (grain)
  'food_ref_usda_169716': 'grains_dry', // sorghum grain
  'food_ref_usda_169745': 'grains_dry', // spelt, uncooked
  'food_ref_usda_169756': 'grains_dry', // white rice, dry
  'food_ref_usda_169736': 'pastas_dry', // pasta, dry
  'food_ref_usda_169742': 'pastas_dry', // rice noodles, dry
  'food_ref_usda_169699': 'pastas_dry', // couscous, dry
  'food_ref_usda_173905': 'hot_cereal_prepared', // oatmeal, cooked
  'food_ref_usda_173904': 'hot_cereal_dry', // oats, dry
  'food_ref_usda_169697': 'flours_and_cornmeal', // cornmeal
  'food_ref_usda_168894': 'flours_and_cornmeal', // wheat flour
  'food_ref_usda_172684': 'breads_and_rolls', // rye bread
  'food_ref_usda_172686': 'breads_and_rolls', // wheat bread
  'food_ref_usda_172688': 'breads_and_rolls', // whole-wheat bread
  'food_ref_usda_169717': 'starches', // tapioca pearls, dry
  // Legumes, soy, nuts and seeds
  'food_ref_usda_173735': 'beans_prepared', // black beans, boiled
  'food_ref_usda_173740': 'beans_prepared', // kidney beans, boiled
  'food_ref_usda_172421': 'beans_prepared', // lentils, boiled
  'food_ref_usda_173746': 'beans_prepared', // navy beans, boiled
  'food_ref_usda_174271': 'beans_prepared', // soybeans, boiled
  'food_ref_usda_172429': 'beans_prepared', // split peas, boiled
  'food_ref_usda_172443': 'beans_prepared', // natto
  'food_ref_usda_173734': 'beans_dry', // black beans, dry
  'food_ref_usda_175205': 'beans_dry', // broad beans, mature, dry
  'food_ref_usda_172420': 'beans_dry', // lentils, dry
  'food_ref_usda_174270': 'beans_dry', // soybeans, dry
  'food_ref_usda_172428': 'beans_dry', // split peas, dry
  'food_ref_usda_170378': 'vegetables_all_other', // broad beans, immature
  'food_ref_usda_170377': 'vegetables_all_other', // broad beans, immature
  'food_ref_usda_168411': 'vegetables_all_other', // edamame
  'food_ref_usda_169282': 'vegetables_all_other', // green soybeans
  'food_ref_usda_174272': 'tofu_and_tempeh', // tempeh
  'food_ref_usda_172475': 'tofu_and_tempeh', // tofu, firm
  'food_ref_usda_172476': 'tofu_and_tempeh', // tofu, regular
  'food_ref_usda_174266': 'nut_and_seed_butters', // peanut butter
  'food_ref_usda_170189': 'nut_and_seed_butters', // tahini
  'food_ref_usda_172430': 'nuts_and_seeds', // peanuts
  'food_ref_usda_170569': 'nuts_and_seeds', // Brazil nuts
  'food_ref_usda_170567': 'nuts_and_seeds', // almonds
  'food_ref_usda_170162': 'nuts_and_seeds', // cashews
  'food_ref_usda_170554': 'nuts_and_seeds', // chia seeds
  'food_ref_usda_169414': 'nuts_and_seeds', // flaxseed
  'food_ref_usda_170556': 'nuts_and_seeds', // pumpkin seed kernels
  'food_ref_usda_170150': 'nuts_and_seeds', // sesame seeds
  'food_ref_usda_170562': 'nuts_and_seeds', // sunflower seed kernels
  'food_ref_usda_170187': 'nuts_and_seeds', // walnuts
  // Meat and poultry
  'food_ref_usda_168740': 'meat_cuts_ready_to_serve', // beef, grilled
  'food_ref_usda_173407': 'meat_cuts_ready_to_serve', // beef, roasted
  'food_ref_usda_169906': 'meat_cuts_ready_to_serve', // ham, roasted
  'food_ref_usda_172480': 'meat_cuts_ready_to_serve', // lamb, cooked
  'food_ref_usda_167892': 'meat_cuts_ready_to_serve', // pork chop, fried
  'food_ref_usda_172479': 'meat_cuts_ready_to_cook', // lamb, raw
  'food_ref_usda_167889': 'meat_cuts_ready_to_cook', // pork loin, raw
  'food_ref_usda_171477': 'poultry_cuts_ready_to_serve', // chicken breast
  'food_ref_usda_171069': 'poultry_cuts_ready_to_serve', // chicken dark
  'food_ref_usda_171479': 'poultry_cuts_ready_to_serve', // turkey + skin
  'food_ref_usda_171481': 'poultry_cuts_ready_to_serve', // turkey meat
  'food_ref_usda_171067': 'poultry_cuts_ready_to_cook', // chicken dark, raw
  'food_ref_usda_171480': 'poultry_cuts_ready_to_cook', // turkey, raw
  // Sweeteners and confections
  'food_ref_usda_170273': 'candies_all_other', // dark chocolate
  'food_ref_usda_169640': 'honey_jams_jellies', // honey
  'food_ref_usda_169641': 'honey_jams_jellies', // jams and preserves
  'food_ref_usda_169661': 'syrups', // maple syrup
  'food_ref_usda_170276': 'syrups', // maple syrup, Canadian
  'food_ref_usda_169655': 'sugar',
  // Vegetables
  'food_ref_usda_170383': 'vegetables_all_other', // Brussels sprouts
  'food_ref_usda_169991': 'vegetables_all_other', // Swiss chard
  'food_ref_usda_170375': 'vegetables_all_other', // beet greens
  'food_ref_usda_170379': 'vegetables_all_other', // broccoli
  'food_ref_usda_169295': 'vegetables_all_other', // butternut squash
  'food_ref_usda_169975': 'vegetables_all_other', // cabbage
  'food_ref_usda_170393': 'vegetables_all_other', // carrot
  'food_ref_usda_169985': 'vegetables_all_other', // cassava
  'food_ref_usda_169986': 'vegetables_all_other', // cauliflower
  'food_ref_usda_169988': 'vegetables_all_other', // celery
  'food_ref_usda_169225': 'vegetables_all_other', // cucumber, peeled
  'food_ref_usda_168409': 'vegetables_all_other', // cucumber, with peel
  'food_ref_usda_169228': 'vegetables_all_other', // eggplant
  'food_ref_usda_170427': 'vegetables_all_other', // green bell pepper
  'food_ref_usda_170420': 'vegetables_all_other', // green peas, boiled
  'food_ref_usda_170419': 'vegetables_all_other', // green peas, raw
  'food_ref_usda_169248': 'vegetables_all_other', // iceberg lettuce
  'food_ref_usda_170000': 'vegetables_all_other', // onion
  'food_ref_usda_170390': 'vegetables_all_other', // pak choi
  'food_ref_usda_169276': 'vegetables_all_other', // radishes
  'food_ref_usda_169247': 'vegetables_all_other', // romaine lettuce
  'food_ref_usda_169242': 'vegetables_all_other', // shiitake
  'food_ref_usda_168463': 'vegetables_all_other', // spinach, boiled
  'food_ref_usda_168462': 'vegetables_all_other', // spinach, raw
  'food_ref_usda_169998': 'vegetables_all_other', // sweet corn
  'food_ref_usda_170457': 'vegetables_all_other', // tomato
  'food_ref_usda_169251': 'vegetables_all_other', // white mushrooms
  'food_ref_usda_169291': 'vegetables_all_other', // zucchini
  'food_ref_usda_169230': 'vegetables_for_garnish_or_flavor', // garlic
  'food_ref_usda_170416': 'vegetables_for_garnish_or_flavor', // parsley
  'food_ref_usda_170392': 'pickles_and_pickled_vegetables', // kimchi
  'food_ref_usda_169279': 'pickles_and_pickled_vegetables', // sauerkraut
  'food_ref_usda_170438': 'potatoes_plain', // potato, boiled in skin
  'food_ref_usda_170440': 'potatoes_plain', // potato, boiled
  'food_ref_usda_170434': 'potatoes_plain', // potato, baked
  'food_ref_usda_168483': 'potatoes_plain', // sweet potato, baked
  'food_ref_usda_168482': 'potatoes_plain', // sweet potato, raw
  'food_ref_usda_170459': 'vegetable_pastes', // tomato paste
  // --- Built-in seed catalogs (SeedCatalogImporter, regional importer) -------
  // Foods without a composition record carry no nutrient values and are
  // left unassigned.
  'seed_white_rice': 'grains_prepared',
  'seed_brown_rice': 'grains_prepared',
  'seed_quinoa': 'grains_prepared',
  'seed_in_basmati': 'grains_prepared',
  'seed_sea_sticky_rice': 'grains_prepared',
  'seed_ee_kasha': 'grains_prepared',
  'seed_oatmeal': 'hot_cereal_prepared',
  'seed_pasta': 'pastas_prepared',
  'seed_couscous': 'pastas_prepared',
  'seed_jp_soba': 'pastas_prepared',
  'seed_bread_white': 'breads_and_rolls',
  'seed_bread_whole_wheat': 'breads_and_rolls',
  'seed_in_naan': 'breads_and_rolls',
  'seed_med_pita': 'breads_and_rolls',
  'seed_in_chapati': 'tortillas_and_biscuits',
  'seed_in_paratha': 'tortillas_and_biscuits',
  'seed_mx_tortilla_corn': 'tortillas_and_biscuits',
  'seed_potato_boiled': 'potatoes_plain',
  'seed_sweet_potato': 'potatoes_plain',
  'seed_chicken_breast': 'poultry_cuts_ready_to_serve',
  'seed_chicken_thigh': 'poultry_cuts_ready_to_serve',
  'seed_pork_loin': 'meat_cuts_ready_to_serve',
  'seed_beef_lean': 'meat_cuts_ready_to_serve',
  'seed_lamb': 'meat_cuts_ready_to_serve',
  'seed_salmon': 'fish_shellfish_cooked',
  'seed_white_fish': 'fish_shellfish_cooked',
  'seed_shrimp': 'fish_shellfish_cooked',
  'seed_tuna_canned': 'fish_shellfish_canned',
  'seed_jp_tai': 'fish_shellfish_uncooked',
  'seed_jp_saba': 'fish_shellfish_uncooked',
  'seed_jp_buri': 'fish_shellfish_uncooked',
  'seed_egg_whole': 'eggs',
  'seed_tofu_firm': 'tofu_and_tempeh',
  'seed_tempeh': 'tofu_and_tempeh',
  'seed_lentils': 'beans_prepared',
  'seed_chickpeas': 'beans_prepared',
  'seed_black_beans': 'beans_prepared',
  'seed_kidney_beans': 'beans_prepared',
  'seed_jp_natto': 'beans_prepared',
  'seed_in_dal': 'beans_in_sauce_or_refried',
  'seed_mx_refried_beans': 'beans_in_sauce_or_refried',
  'seed_edamame': 'vegetables_all_other',
  'seed_peanut_butter': 'nut_and_seed_butters',
  'seed_almonds': 'nuts_and_seeds',
  'seed_walnuts': 'nuts_and_seeds',
  'seed_chia_seeds': 'nuts_and_seeds',
  'seed_milk_whole': 'milk_and_milk_substitutes',
  'seed_milk_skim': 'milk_and_milk_substitutes',
  'seed_soy_milk': 'milk_and_milk_substitutes',
  'seed_almond_milk': 'milk_and_milk_substitutes',
  'seed_yogurt_plain': 'yogurt',
  'seed_greek_yogurt': 'yogurt',
  'seed_cheese_cheddar': 'cheese_all_others',
  'seed_med_feta': 'cheese_all_others',
  'seed_cottage_cheese': 'cheese_cottage',
  'seed_ice_cream': 'ice_cream_and_frozen_desserts',
  'seed_olive_oil': 'fats_and_oils',
  'seed_butter': 'fats_and_oils',
  'seed_in_ghee': 'fats_and_oils',
  'seed_avocado': 'avocado',
  'seed_watermelon': 'watermelon',
  'seed_apple': 'fruits_all_other',
  'seed_banana': 'fruits_all_other',
  'seed_orange': 'fruits_all_other',
  'seed_grapes': 'fruits_all_other',
  'seed_strawberries': 'fruits_all_other',
  'seed_blueberries': 'fruits_all_other',
  'seed_pear': 'fruits_all_other',
  'seed_mango': 'fruits_all_other',
  'seed_pineapple': 'fruits_all_other',
  'seed_kiwi': 'fruits_all_other',
  'seed_peach': 'fruits_all_other',
  'seed_cn_longan': 'fruits_all_other',
  'seed_cn_lychee': 'fruits_all_other',
  'seed_cn_persimmon': 'fruits_all_other',
  'seed_cn_jujube': 'fruits_dried',
  'seed_cn_goji': 'fruits_dried',
  'seed_med_olives': 'olives',
  'seed_broccoli': 'vegetables_all_other',
  'seed_carrot': 'vegetables_all_other',
  'seed_spinach': 'vegetables_all_other',
  'seed_kale': 'vegetables_all_other',
  'seed_lettuce': 'vegetables_all_other',
  'seed_tomato': 'vegetables_all_other',
  'seed_cucumber': 'vegetables_all_other',
  'seed_zucchini': 'vegetables_all_other',
  'seed_bell_pepper': 'vegetables_all_other',
  'seed_cabbage': 'vegetables_all_other',
  'seed_bok_choy': 'vegetables_all_other',
  'seed_eggplant': 'vegetables_all_other',
  'seed_mushroom': 'vegetables_all_other',
  'seed_onion': 'vegetables_all_other',
  'seed_corn': 'vegetables_all_other',
  'seed_cn_lotus_root': 'vegetables_all_other',
  'seed_cn_bamboo_shoots': 'vegetables_all_other',
  'seed_cn_bitter_melon': 'vegetables_all_other',
  'seed_cn_winter_melon': 'vegetables_all_other',
  'seed_jp_daikon': 'vegetables_all_other',
  'seed_jp_renkon': 'vegetables_all_other',
  'seed_jp_shiitake': 'vegetables_all_other',
  'seed_jp_gobo': 'vegetables_all_other',
  'seed_garlic': 'vegetables_for_garnish_or_flavor',
  'seed_kr_kimchi': 'pickles_and_pickled_vegetables',
  'seed_cn_bean_sprouts': 'sprouts',
  'seed_water': 'beverages_other',
  'seed_orange_juice': 'fruit_juices',
  'seed_apple_juice': 'fruit_juices',
  'seed_jp_soy_sauce': 'condiments_major',
  'seed_chocolate_dark': 'candies_all_other',
  'seed_broth_chicken': 'soups',
  'seed_miso_soup': 'soups',
  'seed_kr_miyeok': 'soups',
  'seed_sea_pho': 'soups',
  'seed_ee_borscht': 'soups',
  'seed_med_tabbouleh': 'salads_all_other',
  'seed_med_hummus': 'dips_and_salsa',
  'seed_med_baba_ganoush': 'dips_and_salsa',
  'seed_med_tzatziki': 'dips_and_salsa',
  'seed_mx_guacamole': 'dips_and_salsa',
  'seed_mx_salsa': 'dips_and_salsa',
  'seed_sandwich_turkey': 'mixed_dishes_not_measurable_with_cup',
  'seed_pizza_cheese': 'mixed_dishes_not_measurable_with_cup',
  'seed_burger_beef': 'mixed_dishes_not_measurable_with_cup',
  'seed_med_dolma': 'mixed_dishes_not_measurable_with_cup',
  'seed_mx_tamale': 'mixed_dishes_not_measurable_with_cup',
  'seed_mx_taco': 'mixed_dishes_not_measurable_with_cup',
  'seed_mx_quesadilla': 'mixed_dishes_not_measurable_with_cup',
  'seed_curry_chicken': 'mixed_dishes_measurable_with_cup',
  'seed_kr_bibimbap': 'mixed_dishes_measurable_with_cup',
  'seed_in_biryani': 'mixed_dishes_measurable_with_cup',
  'seed_sea_pad_thai': 'mixed_dishes_measurable_with_cup',
};
