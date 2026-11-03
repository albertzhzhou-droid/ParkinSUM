import '../../domain/entities/dish_recipe.dart';

/// Curated example dishes shown on Next meal → Advanced.
///
/// - Steps are short, written for this app, and describe one simple way to
///   prepare each dish. They are not dietary advice.
/// - Ingredient grams are per serving. `foodId` names a food in the built-in
///   catalog (`FoodRepository.createDefault`); null means the ingredient has
///   no catalog entry, so its nutrition is unknown (never zero).
/// - No nutrient value is typed here: `DishNutritionView` computes them from
///   the catalog at runtime.
/// - Bump [kDishCatalogVersion] whenever a dish, an ingredient or an amount
///   changes.
const String kDishCatalogVersion = 'dish_catalog_v1_2026_10_23';

// Catalog ids used below (USDA FDC SR Legacy reference subset).
const _egg = 'food_ref_usda_171287'; // egg, whole, raw
const _tomato = 'food_ref_usda_170457'; // tomato, red, ripe, raw
const _tomatoPaste = 'food_ref_usda_170459';
const _soybeanOil = 'food_ref_usda_171411';
const _peanutOil = 'food_ref_usda_171410';
const _oliveOil = 'food_ref_usda_171413';
const _butter = 'food_ref_usda_173410';
const _salt = 'food_ref_usda_173468';
const _sugar = 'food_ref_usda_169655';
const _honey = 'food_ref_usda_169640';
const _mapleSyrup = 'food_ref_usda_169661';
const _soySauce = 'food_ref_usda_174277';
const _miso = 'food_ref_usda_172442';
const _ciderVinegar = 'food_ref_usda_173469';
const _lemonJuice = 'food_ref_usda_167747';
const _riceRaw = 'food_ref_usda_169756'; // white rice, long-grain, raw
const _riceCooked = 'food_ref_usda_169757'; // white rice, cooked, no salt
const _millet = 'food_ref_usda_169702';
const _buckwheatCooked = 'food_ref_usda_170686';
const _oatsDry = 'food_ref_usda_173904';
const _pastaDry = 'food_ref_usda_169736';
const _riceNoodlesDry = 'food_ref_usda_169742';
const _wheatBread = 'food_ref_usda_172686';
const _wholeWheatBread = 'food_ref_usda_172688';
const _tofuFirm = 'food_ref_usda_172475';
const _tofuSoft = 'food_ref_usda_172476';
const _natto = 'food_ref_usda_172443';
const _lentilsDry = 'food_ref_usda_172420';
const _splitPeasDry = 'food_ref_usda_172428';
const _blackBeansBoiled = 'food_ref_usda_173735';
const _kidneyBeansBoiled = 'food_ref_usda_173740';
const _cod = 'food_ref_usda_171955';
const _salmon = 'food_ref_usda_175167'; // salmon, Atlantic, farmed, raw
const _tunaCanned = 'food_ref_usda_175158';
const _mackerel = 'food_ref_usda_173672';
const _chickenDark = 'food_ref_usda_171067'; // chicken dark meat, raw
const _turkey = 'food_ref_usda_171480'; // turkey meat only, raw
const _porkLoin = 'food_ref_usda_167889';
const _ham = 'food_ref_usda_169906';
const _milk2 = 'food_ref_usda_171267';
const _yogurtLowFat = 'food_ref_usda_170886';
const _yogurtWhole = 'food_ref_usda_171284';
const _mayonnaise = 'food_ref_usda_171403';
const _bokChoy = 'food_ref_usda_170390';
const _spinachRaw = 'food_ref_usda_168462';
const _spinachBoiled = 'food_ref_usda_168463';
const _shiitake = 'food_ref_usda_169242';
const _whiteMushroom = 'food_ref_usda_169251';
const _garlic = 'food_ref_usda_169230';
const _onion = 'food_ref_usda_170000';
const _carrot = 'food_ref_usda_170393';
const _celery = 'food_ref_usda_169988';
const _cucumber = 'food_ref_usda_168409';
const _cucumberPeeled = 'food_ref_usda_169225';
const _greenPepper = 'food_ref_usda_170427';
const _eggplant = 'food_ref_usda_169228';
const _zucchini = 'food_ref_usda_169291';
const _butternut = 'food_ref_usda_169295';
const _potatoBoiled = 'food_ref_usda_170440';
const _sweetPotato = 'food_ref_usda_168482';
const _lettuce = 'food_ref_usda_169247';
const _parsley = 'food_ref_usda_170416';
const _kimchi = 'food_ref_usda_170392';
const _sesameSeeds = 'food_ref_usda_170150';
const _banana = 'food_ref_usda_173944';
const _blueberries = 'food_ref_usda_171711';
const _strawberries = 'food_ref_usda_167762';

// Shared ingredient names.
const _nEgg = DishText(en: 'Egg', zh: '鸡蛋');
const _nTomato = DishText(en: 'Tomato', zh: '番茄');
const _nOil = DishText(en: 'Cooking oil (soybean)', zh: '食用油（大豆油）');
const _nPeanutOil = DishText(en: 'Peanut oil', zh: '花生油');
const _nOliveOil = DishText(en: 'Olive oil', zh: '橄榄油');
const _nButter = DishText(en: 'Butter', zh: '黄油');
const _nSalt = DishText(en: 'Salt', zh: '盐');
const _nSugar = DishText(en: 'Sugar', zh: '白糖');
const _nSoySauce = DishText(en: 'Soy sauce', zh: '酱油');
const _nGarlic = DishText(en: 'Garlic', zh: '大蒜');
const _nOnion = DishText(en: 'Onion', zh: '洋葱');
const _nCarrot = DishText(en: 'Carrot', zh: '胡萝卜');
const _nCelery = DishText(en: 'Celery', zh: '芹菜');
const _nScallion = DishText(en: 'Scallion', zh: '葱');
const _nGinger = DishText(en: 'Fresh ginger', zh: '生姜');
const _nCornstarch = DishText(en: 'Cornstarch', zh: '玉米淀粉');
const _nSesameOil = DishText(en: 'Sesame oil', zh: '香油');
const _nLemonJuice = DishText(en: 'Lemon juice', zh: '柠檬汁');
const _nCumin = DishText(en: 'Ground cumin', zh: '孜然粉');
const _nTurmeric = DishText(en: 'Ground turmeric', zh: '姜黄粉');
const _nCilantro = DishText(en: 'Cilantro', zh: '香菜');
const _nFishSauce = DishText(en: 'Fish sauce', zh: '鱼露');
const _nRiceCooked = DishText(en: 'Cooked white rice', zh: '米饭');
const _nShiitake = DishText(en: 'Shiitake mushrooms', zh: '香菇');
const _nChicken = DishText(en: 'Chicken thigh, skinless', zh: '去皮鸡腿肉');

DishIngredient _i(String? foodId, DishText name, double grams) =>
    DishIngredient(foodId: foodId, name: name, gramsPerServing: grams);

DishText _t(String en, String zh) => DishText(en: en, zh: zh);

/// The versioned dish set. Order is the default list order.
final List<DishRecipe> kDishCatalog = List<DishRecipe>.unmodifiable([
  // ---------------------------------------------------------------- China
  DishRecipe(
    id: 'dish_cn_tomato_egg',
    name: _t('Tomato and egg stir-fry', '番茄炒蛋'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 8,
    equipment: const [DishEquipment.wok, DishEquipment.bowl],
    ingredients: [
      _i(_egg, _nEgg, 55),
      _i(_tomato, _nTomato, 150),
      _i(_soybeanOil, _nOil, 8),
      _i(_sugar, _nSugar, 2),
      _i(_salt, _nSalt, 1),
      _i(null, _nScallion, 5),
    ],
    steps: [
      _t(
        'Cut the tomatoes into wedges and beat the eggs with a pinch of salt.',
        '番茄切块；鸡蛋加少许盐打散。',
      ),
      _t(
        'Heat half the oil, pour in the eggs and stir gently until just set, then lift them out.',
        '锅中倒入一半油烧热，倒入蛋液轻轻翻炒至刚凝固，盛出。',
      ),
      _t(
        'Add the rest of the oil and cook the tomatoes until they soften and release juice.',
        '倒入剩余的油，下番茄翻炒至变软出汁。',
      ),
      _t(
        'Return the eggs, add the sugar and remaining salt, fold together and top with scallion.',
        '把鸡蛋倒回锅中，加糖和剩余的盐翻匀，撒上葱花。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Peel and finely chop the tomato, keep the egg soft and moist, and leave out the scallion.',
        '番茄去皮切碎，鸡蛋保持软嫩湿润，不放葱花。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_plain_congee',
    name: _t('Plain rice congee with ginger', '姜丝白粥'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 50,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_riceRaw, _t('White rice (raw)', '大米（生）'), 40),
      _i(null, _nGinger, 3),
      _i(_salt, _nSalt, 0.5),
    ],
    steps: [
      _t(
        'Rinse the rice and soak it in cold water for about 15 minutes.',
        '大米淘洗后用冷水浸泡约 15 分钟。',
      ),
      _t(
        'Bring about ten times its volume of water to a boil, add the rice and a few ginger slivers.',
        '烧开约十倍于米量的清水，下米和少许姜丝。',
      ),
      _t(
        'Simmer uncovered on low heat for 40–50 minutes, stirring now and then, until creamy.',
        '小火敞盖慢煮 40–50 分钟，不时搅拌，煮至米粒开花、粥体绵稠。',
      ),
      _t(
        'Season with a little salt and remove the ginger before serving if you prefer.',
        '加少许盐调味；如不喜欢，可在盛出前捞出姜丝。',
      ),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Remove the ginger and blend the congee until smooth, adding hot water for a thinner consistency.',
        '捞出姜丝，把粥搅打至顺滑；需要更稀时加热水调整。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_steamed_fish',
    name: _t('Steamed fish with ginger and scallion', '清蒸鱼'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 10,
    equipment: const [DishEquipment.steamer, DishEquipment.saucepan],
    ingredients: [
      _i(_cod, _t('White fish fillet (cod)', '白肉鱼柳（鳕鱼）'), 150),
      _i(null, _nGinger, 5),
      _i(null, _nScallion, 10),
      _i(_soySauce, _nSoySauce, 8),
      _i(_peanutOil, _nPeanutOil, 5),
    ],
    steps: [
      _t(
        'Pat the fillet dry and lay it on a heatproof plate over a few ginger slices.',
        '鱼柳吸干水分，放在铺有姜片的耐热盘上。',
      ),
      _t(
        'Steam over boiling water for 8–10 minutes, until the flesh is opaque and flakes easily.',
        '水开后上锅蒸 8–10 分钟，至鱼肉变白、能轻松分开。',
      ),
      _t(
        'Pour off the steaming liquid, scatter shredded scallion on top and drizzle the soy sauce.',
        '倒掉盘中蒸出的汤汁，铺上葱丝，淋上酱油。',
      ),
      _t(
        'Heat the oil until shimmering and spoon it over the scallion.',
        '把油烧热至微微冒烟，浇在葱丝上即可。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Check for bones, flake the fish finely and moisten it with the warm soy dressing.',
        '仔细挑净鱼刺，把鱼肉拆成细碎，用温热的酱汁拌湿。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_tofu_shiitake',
    name: _t('Braised tofu with shiitake', '香菇烧豆腐'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 12,
    equipment: const [DishEquipment.wok],
    ingredients: [
      _i(_tofuFirm, _t('Firm tofu', '北豆腐'), 150),
      _i(_shiitake, _nShiitake, 40),
      _i(_garlic, _nGarlic, 3),
      _i(_soySauce, _nSoySauce, 10),
      _i(_soybeanOil, _nOil, 6),
      _i(null, _nCornstarch, 3),
    ],
    steps: [
      _t(
        'Cut the tofu into cubes and slice the mushrooms and garlic.',
        '豆腐切块，香菇和大蒜切片。',
      ),
      _t(
        'Brown the tofu lightly in the oil, then push it aside and fry the garlic and mushrooms.',
        '用油把豆腐煎至微黄，拨到一边，下蒜片和香菇炒香。',
      ),
      _t(
        'Add the soy sauce and a small cup of water, cover and simmer for about 6 minutes.',
        '加入酱油和小半碗水，盖上锅盖焖煮约 6 分钟。',
      ),
      _t(
        'Stir the cornstarch into a spoonful of cold water and add it to thicken the sauce.',
        '玉米淀粉加一勺冷水调匀，倒入锅中勾芡。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Use soft tofu, chop the mushrooms very finely and mash everything with the sauce.',
        '改用嫩豆腐，香菇切成细末，与汤汁一起压碎拌匀。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_steamed_egg_custard',
    name: _t('Steamed egg custard', '蒸水蛋'),
    regions: const ['CN'],
    servings: 1,
    prepMinutes: 5,
    cookMinutes: 12,
    equipment: const [DishEquipment.steamer, DishEquipment.bowl],
    ingredients: [
      _i(_egg, _nEgg, 55),
      _i(_soySauce, _nSoySauce, 3),
      _i(null, _nSesameOil, 2),
    ],
    steps: [
      _t(
        'Beat the egg with about one and a half times its volume of warm water.',
        '鸡蛋打散，加入约 1.5 倍蛋液量的温水。',
      ),
      _t(
        'Strain the mixture into a bowl and skim off any bubbles.',
        '把蛋液过筛倒入碗中，撇去表面气泡。',
      ),
      _t(
        'Cover with a plate and steam over gentle heat for 10–12 minutes until just set.',
        '盖上盘子，小火蒸 10–12 分钟至刚好凝固。',
      ),
      _t(
        'Finish with a few drops of soy sauce and sesame oil.',
        '出锅后滴几滴酱油和香油。',
      ),
    ],
    texture: DishTexture.pureed,
  ),
  DishRecipe(
    id: 'dish_cn_garlic_bok_choy',
    name: _t('Garlic bok choy', '蒜蓉青菜'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 4,
    equipment: const [DishEquipment.wok],
    ingredients: [
      _i(_bokChoy, _t('Bok choy', '小白菜／青菜'), 200),
      _i(_garlic, _nGarlic, 5),
      _i(_soybeanOil, _nOil, 6),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Wash the bok choy and halve any thick stems; mince the garlic.',
        '青菜洗净，较粗的菜梗对半切开；大蒜切末。',
      ),
      _t(
        'Fry the garlic in hot oil for a few seconds until fragrant.',
        '热油下蒜末，炒几秒出香味。',
      ),
      _t(
        'Add the bok choy and stir-fry on high heat until the leaves wilt and the stems turn bright.',
        '下青菜大火翻炒，至菜叶变软、菜梗颜色变亮。',
      ),
      _t('Season with salt and serve.', '加盐调味即可出锅。'),
    ],
    texture: DishTexture.regular,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Cook the greens a few minutes longer, then chop them finely with a spoon of the cooking liquid.',
        '把青菜多煮几分钟，再连同一勺汤汁一起切成细末。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_spinach_tofu_soup',
    name: _t('Spinach and tofu soup', '菠菜豆腐汤'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 8,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_tofuSoft, _t('Soft tofu', '嫩豆腐'), 100),
      _i(_spinachRaw, _t('Spinach', '菠菜'), 60),
      _i(null, _nGinger, 2),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Blanch the spinach briefly, squeeze it and cut it into short lengths.',
        '菠菜焯水后挤干，切成小段。',
      ),
      _t(
        'Bring water with a slice of ginger to a boil and slide in the tofu cubes.',
        '锅中加水和一片姜烧开，放入豆腐块。',
      ),
      _t(
        'Simmer for 3 minutes, add the spinach and season with salt.',
        '小火煮 3 分钟，加入菠菜，用盐调味。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.liquidised,
      note: _t(
        'Remove the ginger and blend the soup until completely smooth.',
        '捞出姜片，把汤搅打至完全顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_smashed_cucumber',
    name: _t('Smashed cucumber salad', '拍黄瓜'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 0,
    equipment: const [DishEquipment.bowl],
    ingredients: [
      _i(_cucumber, _t('Cucumber', '黄瓜'), 150),
      _i(_garlic, _nGarlic, 4),
      _i(_soySauce, _nSoySauce, 5),
      _i(null, _t('Chinese black vinegar', '香醋'), 8),
      _i(null, _nSesameOil, 2),
    ],
    steps: [
      _t(
        'Press the cucumbers with the flat of a knife until they crack, then cut into chunks.',
        '用刀面把黄瓜拍裂，再切成小块。',
      ),
      _t(
        'Toss with a pinch of salt and leave for 10 minutes; pour off the water.',
        '加少许盐拌匀腌 10 分钟，倒掉渗出的水。',
      ),
      _t(
        'Mix in minced garlic, soy sauce, vinegar and sesame oil just before serving.',
        '上桌前拌入蒜末、酱油、香醋和香油。',
      ),
    ],
    texture: DishTexture.regular,
  ),
  DishRecipe(
    id: 'dish_cn_millet_pumpkin_porridge',
    name: _t('Millet and pumpkin porridge', '小米南瓜粥'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 35,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_millet, _t('Millet', '小米'), 30),
      _i(_butternut, _t('Pumpkin (butternut squash)', '南瓜（奶油南瓜）'), 80),
    ],
    steps: [
      _t(
        'Rinse the millet; peel the pumpkin and cut it into small cubes.',
        '小米淘洗干净；南瓜去皮切小丁。',
      ),
      _t(
        'Bring about eight times as much water as millet to a boil and add both.',
        '烧开约八倍于小米量的清水，放入小米和南瓜。',
      ),
      _t(
        'Simmer on low heat for 30 minutes, stirring often, until the pumpkin falls apart.',
        '小火煮 30 分钟，勤搅拌，煮到南瓜软烂化开。',
      ),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Blend the cooked porridge until smooth and even.',
        '把煮好的粥搅打至细腻均匀。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_cn_steamed_chicken_shiitake',
    name: _t('Steamed chicken with shiitake', '香菇蒸鸡'),
    regions: const ['CN'],
    servings: 2,
    prepMinutes: 15,
    cookMinutes: 20,
    equipment: const [DishEquipment.steamer],
    ingredients: [
      _i(_chickenDark, _nChicken, 120),
      _i(_shiitake, _nShiitake, 40),
      _i(_soySauce, _nSoySauce, 8),
      _i(null, _nGinger, 4),
      _i(null, _nCornstarch, 3),
    ],
    steps: [
      _t(
        'Cut the chicken into small pieces and slice the mushrooms.',
        '鸡腿肉切小块，香菇切片。',
      ),
      _t(
        'Mix the chicken with soy sauce, shredded ginger and cornstarch; rest for 10 minutes.',
        '鸡肉加酱油、姜丝和玉米淀粉拌匀，腌 10 分钟。',
      ),
      _t(
        'Spread the chicken and mushrooms on a plate in one layer.',
        '把鸡肉和香菇平铺在盘中。',
      ),
      _t(
        'Steam over high heat for about 18–20 minutes, until the chicken is cooked through.',
        '大火蒸约 18–20 分钟，至鸡肉完全熟透。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Use minced chicken instead of pieces and chop the mushrooms finely before steaming.',
        '改用鸡肉末，香菇切成细末后再蒸。',
      ),
    ),
  ),
  // ---------------------------------------------------- United States, Canada
  DishRecipe(
    id: 'dish_us_banana_oatmeal',
    name: _t('Banana oatmeal', '香蕉燕麦粥'),
    regions: const ['US', 'CA'],
    servings: 1,
    prepMinutes: 2,
    cookMinutes: 6,
    equipment: const [DishEquipment.saucepan],
    ingredients: [
      _i(_oatsDry, _t('Rolled oats', '燕麦片'), 40),
      _i(_milk2, _t('Milk (2%)', '低脂牛奶（2%）'), 200),
      _i(_banana, _t('Banana', '香蕉'), 60),
      _i(_mapleSyrup, _t('Maple syrup', '枫糖浆'), 5),
    ],
    steps: [
      _t(
        'Warm the milk in a small pan and stir in the oats.',
        '小锅中把牛奶加热，倒入燕麦片搅匀。',
      ),
      _t(
        'Simmer for about 5 minutes, stirring, until thick.',
        '边搅拌边小火煮约 5 分钟，至浓稠。',
      ),
      _t(
        'Mash half the banana into the pot and slice the rest on top.',
        '一半香蕉压成泥拌入锅中，另一半切片放在表面。',
      ),
      _t('Drizzle with maple syrup.', '淋上枫糖浆。'),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Mash all of the banana and blend the oatmeal with a little extra milk until smooth.',
        '香蕉全部压成泥，与燕麦粥加少许牛奶一起搅打至顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_us_scrambled_eggs_toast',
    name: _t('Soft scrambled eggs on toast', '嫩炒蛋配吐司'),
    regions: const ['US', 'CA'],
    servings: 1,
    prepMinutes: 2,
    cookMinutes: 5,
    equipment: const [DishEquipment.fryingPan],
    ingredients: [
      _i(_egg, _nEgg, 100),
      _i(_milk2, _t('Milk (2%)', '低脂牛奶（2%）'), 30),
      _i(_butter, _nButter, 5),
      _i(_wholeWheatBread, _t('Whole-wheat bread', '全麦面包'), 35),
      _i(_salt, _nSalt, 0.5),
    ],
    steps: [
      _t('Whisk the eggs with the milk and salt.', '鸡蛋加牛奶和盐搅打均匀。'),
      _t('Melt the butter over low heat and add the eggs.', '小火融化黄油，倒入蛋液。'),
      _t(
        'Stir slowly with a spatula until soft curds form, then take the pan off the heat.',
        '用铲子慢慢推动，至形成柔软的蛋块后离火。',
      ),
      _t('Toast the bread and spoon the eggs on top.', '烤好面包，把炒蛋盛在面包上。'),
    ],
    texture: DishTexture.regular,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Serve the soft eggs without the toast, kept moist with a little warm milk.',
        '不配吐司，只盛嫩炒蛋，并用少许温牛奶保持湿润。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_us_turkey_bean_chili',
    name: _t('Turkey and bean chili', '火鸡肉豆子辣酱'),
    regions: const ['US', 'CA'],
    servings: 4,
    prepMinutes: 10,
    cookMinutes: 35,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_turkey, _t('Ground turkey', '火鸡肉末'), 90),
      _i(_kidneyBeansBoiled, _t('Kidney beans, cooked', '熟芸豆'), 80),
      _i(_tomato, _nTomato, 100),
      _i(_tomatoPaste, _t('Tomato paste', '番茄膏'), 15),
      _i(_onion, _nOnion, 40),
      _i(_soybeanOil, _nOil, 5),
      _i(null, _t('Chili powder', '辣椒粉'), 2),
    ],
    steps: [
      _t(
        'Soften the chopped onion in the oil for about 5 minutes.',
        '洋葱切碎，用油炒软约 5 分钟。',
      ),
      _t(
        'Add the turkey and cook, breaking it up, until no pink remains.',
        '加入火鸡肉末，边炒边打散，炒到完全变色。',
      ),
      _t(
        'Stir in the chili powder and tomato paste, then the chopped tomatoes and beans.',
        '拌入辣椒粉和番茄膏，再加入番茄碎和芸豆。',
      ),
      _t(
        'Simmer partly covered for 25 minutes, adding water if it gets too thick.',
        '半盖锅盖小火炖 25 分钟，太稠时加水。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Mash the beans into the sauce and keep the chili moist with extra cooking liquid.',
        '把豆子压进汤汁里，多留一些汤汁保持湿润。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_us_salmon_sweet_potato',
    name: _t('Baked salmon with sweet potato', '烤三文鱼配红薯'),
    regions: const ['US', 'CA'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 30,
    equipment: const [DishEquipment.oven],
    ingredients: [
      _i(_salmon, _t('Salmon fillet', '三文鱼柳'), 120),
      _i(_sweetPotato, _t('Sweet potato', '红薯'), 150),
      _i(_oliveOil, _nOliveOil, 6),
      _i(_lemonJuice, _nLemonJuice, 5),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Heat the oven to 200 °C (400 °F). Cut the sweet potato into wedges and toss with half the oil.',
        '烤箱预热至 200 °C（400 °F）。红薯切成块，拌上一半的油。',
      ),
      _t('Roast the sweet potato for 15 minutes.', '红薯先烤 15 分钟。'),
      _t(
        'Add the salmon to the tray, brush with the remaining oil and season with salt.',
        '把三文鱼放上烤盘，刷上剩余的油，撒盐。',
      ),
      _t(
        'Bake 12–15 minutes more, until the fish flakes easily; finish with lemon juice.',
        '再烤 12–15 分钟，至鱼肉能轻松分开；出炉后淋柠檬汁。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Scoop the sweet potato out of its skin and mash it; flake the salmon finely and mix in a little lemony oil.',
        '把红薯肉挖出压成泥；三文鱼拆成细碎，拌入少许柠檬油汁。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_us_tuna_salad_sandwich',
    name: _t('Tuna salad sandwich', '金枪鱼沙拉三明治'),
    regions: const ['US', 'CA'],
    servings: 1,
    prepMinutes: 8,
    cookMinutes: 0,
    equipment: const [DishEquipment.bowl],
    ingredients: [
      _i(_tunaCanned, _t('Tuna, canned in water, drained', '水浸金枪鱼罐头（沥干）'), 60),
      _i(_mayonnaise, _t('Mayonnaise-type dressing', '蛋黄酱'), 15),
      _i(_celery, _nCelery, 20),
      _i(_wholeWheatBread, _t('Whole-wheat bread', '全麦面包'), 70),
      _i(_lettuce, _t('Romaine lettuce', '罗马生菜'), 15),
    ],
    steps: [
      _t(
        'Flake the tuna in a bowl and finely dice the celery.',
        '金枪鱼在碗中拆散，芹菜切成细丁。',
      ),
      _t(
        'Mix the tuna, celery and dressing until evenly combined.',
        '把金枪鱼、芹菜和蛋黄酱拌匀。',
      ),
      _t(
        'Spread on one slice of bread, add lettuce and close with the second slice.',
        '抹在一片面包上，放上生菜，再盖上另一片面包。',
      ),
    ],
    texture: DishTexture.regular,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Serve the tuna mixture on its own, without bread, lettuce or celery pieces, kept moist with the dressing.',
        '不用面包、生菜和芹菜丁，只盛金枪鱼酱，用酱料保持湿润。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_us_yogurt_berry_bowl',
    name: _t('Yogurt and berry bowl', '酸奶莓果碗'),
    regions: const ['US', 'CA'],
    servings: 1,
    prepMinutes: 5,
    cookMinutes: 0,
    equipment: const [DishEquipment.bowl],
    ingredients: [
      _i(_yogurtLowFat, _t('Plain yogurt, low fat', '原味低脂酸奶'), 170),
      _i(_blueberries, _t('Blueberries', '蓝莓'), 50),
      _i(_strawberries, _t('Strawberries', '草莓'), 50),
      _i(_honey, _t('Honey', '蜂蜜'), 7),
      _i(null, _t('Granola', '格兰诺拉麦片'), 20),
    ],
    steps: [
      _t('Spoon the yogurt into a bowl.', '把酸奶舀入碗中。'),
      _t(
        'Halve the strawberries and scatter them with the blueberries on top.',
        '草莓对半切开，与蓝莓一起铺在酸奶上。',
      ),
      _t('Sprinkle the granola and drizzle the honey.', '撒上格兰诺拉麦片，淋上蜂蜜。'),
    ],
    texture: DishTexture.regular,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Leave out the granola and blend the yogurt, berries and honey until smooth.',
        '不放麦片，把酸奶、莓果和蜂蜜一起搅打至顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_us_chicken_vegetable_soup',
    name: _t('Chicken and vegetable noodle soup', '鸡肉蔬菜面汤'),
    regions: const ['US', 'CA'],
    servings: 4,
    prepMinutes: 15,
    cookMinutes: 30,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_chickenDark, _nChicken, 80),
      _i(_carrot, _nCarrot, 50),
      _i(_celery, _nCelery, 40),
      _i(_onion, _nOnion, 40),
      _i(_pastaDry, _t('Small pasta (dry)', '小号意面（干）'), 25),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Dice the carrot, celery and onion; cut the chicken into small pieces.',
        '胡萝卜、芹菜和洋葱切丁；鸡肉切小块。',
      ),
      _t(
        'Simmer the chicken and vegetables in water for 20 minutes.',
        '鸡肉和蔬菜加水小火煮 20 分钟。',
      ),
      _t(
        'Add the pasta and cook until tender, about 8 minutes.',
        '下意面，煮至软熟，约 8 分钟。',
      ),
      _t('Season with salt.', '加盐调味。'),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.liquidised,
      note: _t(
        'Blend the finished soup until completely smooth.',
        '把煮好的汤搅打至完全顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_ca_split_pea_soup',
    name: _t('Split pea soup with ham', '火腿豌豆汤'),
    regions: const ['CA', 'US'],
    servings: 4,
    prepMinutes: 10,
    cookMinutes: 60,
    equipment: const [DishEquipment.pot, DishEquipment.blender],
    ingredients: [
      _i(_splitPeasDry, _t('Dried split peas', '干豌豆瓣'), 60),
      _i(_ham, _t('Ham, diced', '火腿丁'), 30),
      _i(_onion, _nOnion, 40),
      _i(_carrot, _nCarrot, 40),
      _i(null, _t('Bay leaf', '香叶'), 0.2),
    ],
    steps: [
      _t('Rinse the split peas and pick out any stones.', '豌豆瓣淘洗干净，挑出杂质。'),
      _t(
        'Put the peas, onion, carrot and bay leaf in a pot with plenty of water.',
        '把豌豆瓣、洋葱、胡萝卜和香叶放入锅中，加足量清水。',
      ),
      _t(
        'Simmer for about an hour, until the peas break down; remove the bay leaf.',
        '小火煮约一小时至豌豆软烂；取出香叶。',
      ),
      _t(
        'Blend part of the soup for a creamier texture and stir in the ham.',
        '把一部分汤搅打成泥使口感更绵，再拌入火腿丁。',
      ),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.liquidised,
      note: _t(
        'Blend all of the soup, including the ham, until completely smooth.',
        '把全部汤连同火腿一起搅打至完全顺滑。',
      ),
    ),
  ),
  // --------------------------------------------------------------- France
  DishRecipe(
    id: 'dish_fr_herb_omelette',
    name: _t('Herb omelette', '香草煎蛋卷'),
    regions: const ['FR'],
    servings: 1,
    prepMinutes: 3,
    cookMinutes: 4,
    equipment: const [DishEquipment.fryingPan],
    ingredients: [
      _i(_egg, _nEgg, 110),
      _i(_butter, _nButter, 6),
      _i(_parsley, _t('Parsley', '欧芹'), 3),
      _i(null, _t('Chives', '细香葱'), 2),
      _i(_salt, _nSalt, 0.5),
    ],
    steps: [
      _t('Beat the eggs with salt and the chopped herbs.', '鸡蛋加盐和切碎的香草打散。'),
      _t(
        'Melt the butter in a pan over medium heat until it foams.',
        '中火把黄油融化至起泡。',
      ),
      _t(
        'Pour in the eggs and stir briefly, then let them set while still soft on top.',
        '倒入蛋液稍加搅动，让蛋液定型，表面仍保持柔软。',
      ),
      _t(
        'Fold the omelette in thirds and slide it onto a plate.',
        '把蛋饼折成三折，滑入盘中。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Cook the eggs as soft, moist scrambled curds instead of folding them.',
        '不折叠，改做成柔软湿润的炒蛋。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_fr_ratatouille',
    name: _t('Ratatouille', '普罗旺斯炖菜'),
    regions: const ['FR'],
    servings: 4,
    prepMinutes: 20,
    cookMinutes: 40,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_eggplant, _t('Eggplant', '茄子'), 80),
      _i(_zucchini, _t('Zucchini', '西葫芦'), 80),
      _i(_greenPepper, _t('Bell pepper', '甜椒'), 50),
      _i(_tomato, _nTomato, 100),
      _i(_onion, _nOnion, 40),
      _i(_oliveOil, _nOliveOil, 8),
      _i(_garlic, _nGarlic, 3),
      _i(null, _t('Dried thyme', '干百里香'), 0.5),
    ],
    steps: [
      _t('Cut all the vegetables into similar-sized cubes.', '把所有蔬菜切成大小相近的块。'),
      _t(
        'Soften the onion and pepper in the oil, then add the eggplant and zucchini.',
        '用橄榄油把洋葱和甜椒炒软，再加入茄子和西葫芦。',
      ),
      _t(
        'Add the tomatoes, garlic and thyme, cover and simmer gently for 30 minutes.',
        '加入番茄、大蒜和百里香，盖上锅盖小火慢炖 30 分钟。',
      ),
      _t(
        'Uncover for the last few minutes if there is a lot of liquid.',
        '汤汁较多时，最后几分钟开盖收汁。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Peel the eggplant and pepper, cook a little longer, then mash the stew with a fork.',
        '茄子和甜椒去皮，多炖一会儿，再用叉子压碎。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_fr_vegetable_potage',
    name: _t('Blended vegetable potage', '蔬菜浓汤'),
    regions: const ['FR'],
    servings: 4,
    prepMinutes: 15,
    cookMinutes: 30,
    equipment: const [DishEquipment.pot, DishEquipment.blender],
    ingredients: [
      _i(_carrot, _nCarrot, 80),
      _i(_butternut, _t('Butternut squash', '奶油南瓜'), 100),
      _i(_onion, _nOnion, 30),
      _i(_celery, _nCelery, 30),
      _i(_milk2, _t('Milk (2%)', '低脂牛奶（2%）'), 50),
      _i(_butter, _nButter, 4),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t('Peel and chop all the vegetables.', '所有蔬菜去皮切块。'),
      _t('Soften the onion and celery in the butter.', '用黄油把洋葱和芹菜炒软。'),
      _t(
        'Add the carrot, squash and enough water to cover; simmer 25 minutes until very soft.',
        '加入胡萝卜、南瓜和没过食材的水，小火煮 25 分钟至非常软烂。',
      ),
      _t(
        'Blend until smooth, stir in the milk, warm through and season.',
        '搅打至顺滑，拌入牛奶，再加热并调味。',
      ),
    ],
    texture: DishTexture.liquidised,
  ),
  DishRecipe(
    id: 'dish_fr_lentils_carrots',
    name: _t('Lentils with carrots', '胡萝卜炖扁豆'),
    regions: const ['FR'],
    servings: 3,
    prepMinutes: 10,
    cookMinutes: 30,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_lentilsDry, _t('Green lentils (dry)', '绿扁豆（干）'), 50),
      _i(_carrot, _nCarrot, 60),
      _i(_onion, _nOnion, 30),
      _i(_oliveOil, _nOliveOil, 5),
      _i(_ciderVinegar, _t('Cider vinegar', '苹果醋'), 5),
      _i(null, _t('Bay leaf', '香叶'), 0.2),
    ],
    steps: [
      _t('Rinse the lentils; dice the carrot and onion.', '扁豆淘洗干净；胡萝卜和洋葱切丁。'),
      _t(
        'Cover the lentils, vegetables and bay leaf with cold water and bring to a simmer.',
        '扁豆、蔬菜和香叶加冷水没过，烧至微沸。',
      ),
      _t(
        'Cook 25–30 minutes until the lentils are tender; drain off any extra water.',
        '煮 25–30 分钟至扁豆软熟，倒掉多余的水。',
      ),
      _t('Dress with the oil and vinegar while warm.', '趁热拌入橄榄油和苹果醋。'),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Cook the lentils until very soft and blend them with some cooking water until smooth.',
        '把扁豆煮到非常软烂，加一些煮豆的水搅打至顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_fr_cod_papillote',
    name: _t('Cod baked in parchment', '纸包烤鳕鱼'),
    regions: const ['FR'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 15,
    equipment: const [DishEquipment.oven],
    ingredients: [
      _i(_cod, _t('Cod fillet', '鳕鱼柳'), 150),
      _i(_zucchini, _t('Zucchini', '西葫芦'), 60),
      _i(_tomato, _nTomato, 60),
      _i(_oliveOil, _nOliveOil, 5),
      _i(_lemonJuice, _nLemonJuice, 5),
      _i(_salt, _nSalt, 0.5),
    ],
    steps: [
      _t(
        'Heat the oven to 200 °C (400 °F) and slice the zucchini and tomato thinly.',
        '烤箱预热至 200 °C（400 °F），西葫芦和番茄切薄片。',
      ),
      _t(
        'Lay the vegetables on a sheet of baking parchment and place the fish on top.',
        '把蔬菜铺在烘焙纸上，再放上鱼柳。',
      ),
      _t(
        'Add oil, lemon juice and salt, then fold the paper into a sealed parcel.',
        '淋上油和柠檬汁，撒盐，把纸折起封成纸包。',
      ),
      _t(
        'Bake for 12–15 minutes and open the parcel carefully; the steam is hot.',
        '烤 12–15 分钟，小心打开纸包，注意热蒸汽。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Remove any bones, flake the fish finely and mash the vegetables with the juices.',
        '挑净鱼刺，把鱼肉拆成细碎，蔬菜连同汤汁一起压碎。',
      ),
    ),
  ),
  // ---------------------------------------------------------------- Spain
  DishRecipe(
    id: 'dish_es_potato_tortilla',
    name: _t('Spanish potato omelette', '西班牙土豆蛋饼'),
    regions: const ['ES'],
    servings: 4,
    prepMinutes: 15,
    cookMinutes: 25,
    equipment: const [DishEquipment.saucepan, DishEquipment.fryingPan],
    ingredients: [
      _i(_potatoBoiled, _t('Potato, peeled and boiled', '去皮煮土豆'), 120),
      _i(_egg, _nEgg, 75),
      _i(_onion, _nOnion, 30),
      _i(_oliveOil, _nOliveOil, 10),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Simmer thin potato slices in salted water until just tender, then drain.',
        '土豆切薄片，放入淡盐水中煮至刚软，沥干。',
      ),
      _t(
        'Cook the sliced onion slowly in the oil until soft and golden.',
        '洋葱切丝，用橄榄油慢慢炒至软身金黄。',
      ),
      _t(
        'Beat the eggs, fold in the potato and onion, and rest for 5 minutes.',
        '鸡蛋打散，拌入土豆和洋葱，静置 5 分钟。',
      ),
      _t(
        'Cook in the pan on low heat until almost set, flip using a plate and cook 2 minutes more.',
        '倒回锅中小火煎至基本凝固，借助盘子翻面，再煎 2 分钟。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Cook the potato until very soft and keep the centre moist; cut into small pieces and mash lightly.',
        '土豆煮到非常软，蛋饼中心保持湿润；切小块后稍加压碎。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_es_gazpacho',
    name: _t('Gazpacho', '西班牙冷汤'),
    regions: const ['ES'],
    servings: 2,
    prepMinutes: 15,
    cookMinutes: 0,
    equipment: const [DishEquipment.blender],
    ingredients: [
      _i(_tomato, _nTomato, 200),
      _i(_cucumberPeeled, _t('Cucumber, peeled', '去皮黄瓜'), 60),
      _i(_greenPepper, _t('Green bell pepper', '青椒'), 30),
      _i(_wheatBread, _t('Day-old bread', '隔夜面包'), 20),
      _i(_oliveOil, _nOliveOil, 10),
      _i(_ciderVinegar, _t('Vinegar (cider)', '醋（苹果醋）'), 5),
      _i(_garlic, _nGarlic, 2),
    ],
    steps: [
      _t('Roughly chop the vegetables and tear the bread.', '蔬菜粗切成块，面包撕成小块。'),
      _t(
        'Blend everything except the oil until very smooth.',
        '除橄榄油外的所有材料一起搅打至非常顺滑。',
      ),
      _t('With the blender running, pour in the oil.', '搅拌机运转时缓缓倒入橄榄油。'),
      _t(
        'Strain if you like a finer soup and chill for at least an hour.',
        '想要更细腻可以过筛，冷藏至少一小时。',
      ),
    ],
    texture: DishTexture.liquidised,
  ),
  DishRecipe(
    id: 'dish_es_chickpeas_spinach',
    name: _t('Chickpeas with spinach', '菠菜鹰嘴豆'),
    regions: const ['ES'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 12,
    equipment: const [DishEquipment.fryingPan],
    ingredients: [
      _i(null, _t('Chickpeas, cooked', '熟鹰嘴豆'), 120),
      _i(_spinachRaw, _t('Spinach', '菠菜'), 80),
      _i(_garlic, _nGarlic, 4),
      _i(_oliveOil, _nOliveOil, 8),
      _i(null, _nCumin, 1),
      _i(null, _t('Smoked paprika', '烟熏红椒粉'), 1),
    ],
    steps: [
      _t('Fry the sliced garlic gently in the oil.', '蒜切片，用橄榄油小火煎香。'),
      _t('Stir in the cumin and paprika for a few seconds.', '加入孜然粉和红椒粉，翻炒几秒。'),
      _t(
        'Add the chickpeas with a splash of water and warm through.',
        '加入鹰嘴豆和少许水，加热均匀。',
      ),
      _t('Fold in the spinach until it wilts.', '拌入菠菜，炒至变软。'),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Mash the chickpeas and chop the spinach finely, keeping the mixture moist with a little water.',
        '把鹰嘴豆压碎、菠菜切碎，加少许水保持湿润。',
      ),
    ),
  ),
  // ---------------------------------------------------------------- Japan
  DishRecipe(
    id: 'dish_jp_miso_soup',
    name: _t('Miso soup with tofu', '豆腐味噌汤'),
    regions: const ['JP'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 8,
    equipment: const [DishEquipment.saucepan],
    ingredients: [
      _i(_miso, _t('Miso', '味噌'), 15),
      _i(_tofuSoft, _t('Soft tofu', '嫩豆腐'), 50),
      _i(null, _t('Dried wakame', '干裙带菜'), 1),
      _i(null, _t('Dashi stock', '日式高汤'), 200),
      _i(null, _nScallion, 3),
    ],
    steps: [
      _t('Soak the wakame for 5 minutes and drain.', '裙带菜泡发 5 分钟后沥干。'),
      _t(
        'Heat the dashi to just below a simmer and add small tofu cubes and the wakame.',
        '高汤加热至将沸未沸，放入小豆腐丁和裙带菜。',
      ),
      _t(
        'Take the pan off the heat and dissolve the miso into the broth through a small strainer.',
        '离火，用小滤网把味噌化入汤中。',
      ),
      _t('Top with sliced scallion.', '撒上葱花。'),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.liquidised,
      note: _t(
        'Leave out the wakame and scallion and blend the soup with the tofu until smooth.',
        '不放裙带菜和葱，把汤连同豆腐一起搅打至顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_jp_natto_rice',
    name: _t('Natto on rice', '纳豆拌饭'),
    regions: const ['JP'],
    servings: 1,
    prepMinutes: 3,
    cookMinutes: 0,
    equipment: const [DishEquipment.bowl],
    ingredients: [
      _i(_natto, _t('Natto', '纳豆'), 45),
      _i(_riceCooked, _nRiceCooked, 150),
      _i(_soySauce, _nSoySauce, 5),
      _i(null, _nScallion, 3),
    ],
    steps: [
      _t('Warm the cooked rice and place it in a bowl.', '把米饭加热后盛入碗中。'),
      _t(
        'Stir the natto briskly with the soy sauce until it turns stringy.',
        '纳豆加酱油快速搅拌，直到拉出细丝。',
      ),
      _t('Spoon it over the rice and add the scallion.', '把纳豆铺在米饭上，撒上葱花。'),
    ],
    texture: DishTexture.softBiteSized,
  ),
  DishRecipe(
    id: 'dish_jp_mackerel_miso',
    name: _t('Mackerel simmered in miso', '味噌煮鲭鱼'),
    regions: const ['JP'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 15,
    equipment: const [DishEquipment.fryingPan],
    ingredients: [
      _i(_mackerel, _t('Mackerel fillet', '鲭鱼柳'), 100),
      _i(_miso, _t('Miso', '味噌'), 15),
      _i(_sugar, _nSugar, 5),
      _i(null, _nGinger, 5),
      _i(null, _t('Mirin', '味醂'), 10),
    ],
    steps: [
      _t(
        'Score the skin of the fillets and slice the ginger thinly.',
        '在鱼皮上轻划几刀，生姜切薄片。',
      ),
      _t(
        'Bring a small cup of water, the mirin, sugar and ginger to a simmer in a wide pan.',
        '宽口锅中加入小半碗水、味醂、糖和姜片，烧至微沸。',
      ),
      _t(
        'Add the fish skin side up, cover with a small lid or foil and simmer 8 minutes.',
        '鱼皮朝上放入鱼柳，盖上小锅盖或锡纸，小火煮 8 分钟。',
      ),
      _t(
        'Stir in the miso and spoon the sauce over the fish for a few more minutes until glossy.',
        '化入味噌，把酱汁反复浇在鱼上，再煮几分钟至酱汁光亮。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Remove the skin and bones, flake the fish finely and mix it with the miso sauce.',
        '去掉鱼皮和鱼刺，把鱼肉拆成细碎，与味噌酱汁拌匀。',
      ),
    ),
  ),
  // ---------------------------------------------------------------- Korea
  DishRecipe(
    id: 'dish_kr_soft_tofu_stew',
    name: _t('Mild soft tofu stew', '微辣嫩豆腐汤'),
    regions: const ['KR'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 15,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_tofuSoft, _t('Soft tofu', '嫩豆腐'), 150),
      _i(_kimchi, _t('Cabbage kimchi', '辣白菜'), 40),
      _i(_egg, _nEgg, 50),
      _i(_zucchini, _t('Zucchini', '西葫芦'), 40),
      _i(_onion, _nOnion, 20),
      _i(null, _t('Korean chili flakes', '韩式辣椒粉'), 1),
    ],
    steps: [
      _t('Chop the kimchi and dice the zucchini and onion.', '辣白菜切碎，西葫芦和洋葱切丁。'),
      _t(
        'Simmer the kimchi, onion and chili flakes in two cups of water for 5 minutes.',
        '辣白菜、洋葱和辣椒粉加两碗水小火煮 5 分钟。',
      ),
      _t(
        'Add the zucchini and spoon in large pieces of tofu; simmer 5 minutes more.',
        '加入西葫芦，用勺子舀入大块嫩豆腐，再煮 5 分钟。',
      ),
      _t(
        'Crack the egg on top and cook until it is done the way you like.',
        '在表面打入鸡蛋，煮到自己喜欢的熟度。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Leave out the kimchi pieces, cook the egg through and mash the tofu and zucchini into the broth.',
        '不放辣白菜块，鸡蛋煮熟，把豆腐和西葫芦压碎在汤里。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_kr_spinach_namul',
    name: _t('Seasoned spinach (sigeumchi namul)', '凉拌菠菜'),
    regions: const ['KR'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 2,
    equipment: const [DishEquipment.pot, DishEquipment.bowl],
    ingredients: [
      _i(_spinachBoiled, _t('Spinach, blanched and squeezed', '焯熟挤干的菠菜'), 100),
      _i(_soySauce, _nSoySauce, 4),
      _i(_garlic, _nGarlic, 2),
      _i(_sesameSeeds, _t('Sesame seeds', '芝麻'), 2),
      _i(null, _nSesameOil, 2),
    ],
    steps: [
      _t(
        'Blanch the spinach for 30 seconds, cool it in cold water and squeeze it dry.',
        '菠菜焯水 30 秒，过冷水后挤干。',
      ),
      _t('Cut it into short lengths.', '切成小段。'),
      _t(
        'Toss with soy sauce, grated garlic, sesame oil and sesame seeds.',
        '拌入酱油、蒜蓉、香油和芝麻。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Leave out the sesame seeds and chop the seasoned spinach very finely.',
        '不放芝麻，把拌好的菠菜剁成细末。',
      ),
    ),
  ),
  // ---------------------------------------------------------------- India
  DishRecipe(
    id: 'dish_in_masoor_dal',
    name: _t('Red lentil dal', '红扁豆糊（达尔）'),
    regions: const ['IN'],
    servings: 3,
    prepMinutes: 10,
    cookMinutes: 25,
    equipment: const [DishEquipment.pot, DishEquipment.fryingPan],
    ingredients: [
      _i(_lentilsDry, _t('Red lentils (dry)', '红扁豆（干）'), 50),
      _i(_tomato, _nTomato, 60),
      _i(_onion, _nOnion, 30),
      _i(_soybeanOil, _nOil, 6),
      _i(null, _nTurmeric, 1),
      _i(null, _t('Cumin seeds', '孜然籽'), 1),
    ],
    steps: [
      _t(
        'Rinse the lentils and simmer them with turmeric in three times their volume of water for 20 minutes.',
        '扁豆淘洗后加入姜黄粉和三倍量的水，小火煮 20 分钟。',
      ),
      _t(
        'Meanwhile fry the cumin seeds in the oil, then add the onion and cook until golden.',
        '同时用油把孜然籽炸香，再下洋葱炒至金黄。',
      ),
      _t(
        'Add the chopped tomato and cook until it collapses.',
        '加入番茄碎，炒到番茄软烂。',
      ),
      _t(
        'Stir this mixture into the soft lentils and season with salt to taste.',
        '把炒好的料倒入煮软的扁豆中拌匀，按口味加盐。',
      ),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Strain out the cumin seeds and blend the dal until smooth.',
        '滤掉孜然籽，把达尔搅打至顺滑。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_in_curd_rice',
    name: _t('Curd rice', '酸奶拌饭'),
    regions: const ['IN'],
    servings: 1,
    prepMinutes: 5,
    cookMinutes: 2,
    equipment: const [DishEquipment.bowl, DishEquipment.fryingPan],
    ingredients: [
      _i(_riceCooked, _nRiceCooked, 120),
      _i(_yogurtWhole, _t('Plain yogurt, whole milk', '原味全脂酸奶'), 100),
      _i(_cucumber, _t('Cucumber', '黄瓜'), 30),
      _i(_soybeanOil, _nOil, 3),
      _i(null, _t('Mustard seeds', '芥菜籽'), 1),
      _i(_salt, _nSalt, 0.5),
    ],
    steps: [
      _t(
        'Mash the cooked rice lightly while it is still warm and let it cool.',
        '米饭趁温热时稍加压散，放凉。',
      ),
      _t('Mix in the yogurt, salt and grated cucumber.', '拌入酸奶、盐和黄瓜丝。'),
      _t(
        'Fry the mustard seeds in the oil until they pop and pour over the rice.',
        '用油把芥菜籽炸至爆开，浇在饭上。',
      ),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Leave out the seeds and cucumber and blend the rice with the yogurt until smooth.',
        '不放芥菜籽和黄瓜，把米饭和酸奶一起搅打至顺滑。',
      ),
    ),
  ),
  // --------------------------------------------------------------- Mexico
  DishRecipe(
    id: 'dish_mx_black_beans_rice',
    name: _t('Black beans with rice', '黑豆配米饭'),
    regions: const ['MX'],
    servings: 2,
    prepMinutes: 5,
    cookMinutes: 15,
    equipment: const [DishEquipment.saucepan],
    ingredients: [
      _i(_blackBeansBoiled, _t('Black beans, cooked', '熟黑豆'), 120),
      _i(_riceCooked, _nRiceCooked, 100),
      _i(_onion, _nOnion, 30),
      _i(_tomato, _nTomato, 40),
      _i(_soybeanOil, _nOil, 5),
      _i(null, _nCilantro, 3),
    ],
    steps: [
      _t('Soften the chopped onion in the oil.', '洋葱切碎，用油炒软。'),
      _t('Add the diced tomato and cook for 3 minutes.', '加入番茄丁炒 3 分钟。'),
      _t(
        'Stir in the beans with a little of their liquid and simmer 8 minutes, mashing a few.',
        '加入黑豆和少许豆汤，小火煮 8 分钟，压碎一部分豆子。',
      ),
      _t('Serve over warm rice with chopped cilantro.', '盛在热米饭上，撒上香菜碎。'),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Mash all the beans into a thick, moist paste and mix in the rice.',
        '把豆子全部压成浓稠湿润的豆泥，再拌入米饭。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_mx_sopa_de_fideo',
    name: _t('Tomato noodle soup (sopa de fideo)', '番茄细面汤'),
    regions: const ['MX'],
    servings: 3,
    prepMinutes: 5,
    cookMinutes: 15,
    equipment: const [DishEquipment.pot, DishEquipment.blender],
    ingredients: [
      _i(_pastaDry, _t('Thin noodles (dry)', '细面（干）'), 30),
      _i(_tomato, _nTomato, 100),
      _i(_onion, _nOnion, 20),
      _i(_garlic, _nGarlic, 2),
      _i(_soybeanOil, _nOil, 5),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Blend the tomato, onion and garlic with a cup of water.',
        '番茄、洋葱和大蒜加一碗水搅打成汁。',
      ),
      _t(
        'Toast the noodles in the oil, stirring, until light golden.',
        '用油把细面翻炒至微黄。',
      ),
      _t(
        'Pour in the tomato mixture and two more cups of water.',
        '倒入番茄汁，再加两碗水。',
      ),
      _t(
        'Simmer 8–10 minutes until the noodles are soft; season.',
        '小火煮 8–10 分钟至面条软熟，调味。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.liquidised,
      note: _t(
        'Cook the noodles until very soft and blend the whole soup until smooth.',
        '把面条煮到非常软，再把整锅汤搅打至顺滑。',
      ),
    ),
  ),
  // -------------------------------------------------------------- Vietnam
  DishRecipe(
    id: 'dish_vn_chicken_noodle_soup',
    name: _t('Chicken rice-noodle soup (phở gà style)', '鸡肉米粉汤（越式）'),
    regions: const ['VN'],
    servings: 2,
    prepMinutes: 15,
    cookMinutes: 30,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_riceNoodlesDry, _t('Rice noodles (dry)', '米粉（干）'), 50),
      _i(_chickenDark, _nChicken, 80),
      _i(_onion, _nOnion, 30),
      _i(null, _nGinger, 5),
      _i(null, _nFishSauce, 5),
      _i(null, _t('Fresh herbs (basil, cilantro)', '新鲜香草（罗勒、香菜）'), 5),
    ],
    steps: [
      _t(
        'Char the onion and ginger in a dry pan, then simmer them with the chicken in water for 25 minutes.',
        '洋葱和生姜在干锅中煎至微焦，再与鸡肉一起加水小火煮 25 分钟。',
      ),
      _t(
        'Lift out the chicken and shred it; season the broth with fish sauce.',
        '捞出鸡肉撕成丝；用鱼露给汤调味。',
      ),
      _t(
        'Soak or boil the rice noodles until soft and divide them between bowls.',
        '米粉泡软或煮软，分装入碗。',
      ),
      _t(
        'Top with the chicken, pour over the hot broth and add the herbs.',
        '铺上鸡丝，浇入热汤，放上香草。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Cut the soft noodles short, mince the chicken and leave out the whole herb leaves.',
        '把软米粉剪短，鸡肉剁碎，不放整片香草。',
      ),
    ),
  ),
  // ------------------------------------------------------------- Thailand
  DishRecipe(
    id: 'dish_th_khao_tom',
    name: _t('Rice soup with pork (khao tom)', '泰式猪肉泡饭汤'),
    regions: const ['TH'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 15,
    equipment: const [DishEquipment.pot],
    ingredients: [
      _i(_riceCooked, _nRiceCooked, 100),
      _i(_porkLoin, _t('Pork loin, minced', '猪里脊肉末'), 60),
      _i(_garlic, _nGarlic, 3),
      _i(_celery, _nCelery, 15),
      _i(_soybeanOil, _nOil, 4),
      _i(null, _nFishSauce, 5),
    ],
    steps: [
      _t(
        'Fry the minced garlic in the oil until golden and set it aside.',
        '用油把蒜末炸至金黄，盛出备用。',
      ),
      _t(
        'Roll the pork into small balls and drop them into simmering water.',
        '猪肉末搓成小丸子，放入微沸的水中。',
      ),
      _t(
        'Add the rice and cook 8–10 minutes, until the pork is cooked through.',
        '加入米饭煮 8–10 分钟，至肉丸完全熟透。',
      ),
      _t(
        'Season with fish sauce and top with chopped celery and the fried garlic.',
        '用鱼露调味，撒上芹菜碎和炸蒜。',
      ),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Cook the rice longer until very soft, crumble the pork instead of shaping balls and leave out the crisp garlic.',
        '把米饭煮得更软烂，猪肉不搓丸子而是打散煮，不放炸蒜。',
      ),
    ),
  ),
  // ------------------------------------------------------ Russia, Poland
  DishRecipe(
    id: 'dish_ru_buckwheat_mushrooms',
    name: _t('Buckwheat with mushrooms', '蘑菇荞麦饭'),
    regions: const ['RU', 'PL'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 20,
    equipment: const [DishEquipment.saucepan, DishEquipment.fryingPan],
    ingredients: [
      _i(_buckwheatCooked, _t('Buckwheat groats, cooked', '熟荞麦米'), 150),
      _i(_whiteMushroom, _t('White mushrooms', '白蘑菇'), 60),
      _i(_onion, _nOnion, 30),
      _i(_butter, _nButter, 5),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t(
        'Simmer the buckwheat in twice its volume of water for about 15 minutes, then rest covered.',
        '荞麦米加两倍量的水小火煮约 15 分钟，盖上锅盖焖一会儿。',
      ),
      _t(
        'Cook the sliced onion and mushrooms in the butter until browned.',
        '洋葱和蘑菇切片，用黄油炒至上色。',
      ),
      _t('Fold the mushrooms into the buckwheat and season.', '把蘑菇拌入荞麦中，调味。'),
    ],
    texture: DishTexture.softBiteSized,
    textureOption: DishTextureOption(
      texture: DishTexture.mincedMoist,
      note: _t(
        'Cook the buckwheat with extra water until very soft and chop the mushrooms finely.',
        '多加水把荞麦煮到非常软，蘑菇切成细末。',
      ),
    ),
  ),
  DishRecipe(
    id: 'dish_pl_cucumber_yogurt_salad',
    name: _t('Cucumber and yogurt salad (mizeria)', '酸奶黄瓜沙拉'),
    regions: const ['PL', 'RU'],
    servings: 2,
    prepMinutes: 15,
    cookMinutes: 0,
    equipment: const [DishEquipment.bowl],
    ingredients: [
      _i(_cucumber, _t('Cucumber', '黄瓜'), 120),
      _i(_yogurtWhole, _t('Plain yogurt, whole milk', '原味全脂酸奶'), 60),
      _i(null, _t('Fresh dill', '新鲜莳萝'), 2),
      _i(_salt, _nSalt, 1),
    ],
    steps: [
      _t('Slice the cucumber very thinly.', '黄瓜切成极薄的片。'),
      _t(
        'Toss with the salt, leave for 10 minutes and pour off the liquid.',
        '加盐拌匀放 10 分钟，倒掉渗出的汁水。',
      ),
      _t('Stir in the yogurt and chopped dill.', '拌入酸奶和切碎的莳萝。'),
    ],
    texture: DishTexture.regular,
  ),
  // ----------------------------------------------------- Saudi Arabia
  DishRecipe(
    id: 'dish_sa_lentil_soup',
    name: _t('Lentil soup (shorbat adas)', '中东扁豆汤'),
    regions: const ['SA'],
    servings: 3,
    prepMinutes: 10,
    cookMinutes: 30,
    equipment: const [DishEquipment.pot, DishEquipment.blender],
    ingredients: [
      _i(_lentilsDry, _t('Red lentils (dry)', '红扁豆（干）'), 50),
      _i(_carrot, _nCarrot, 40),
      _i(_onion, _nOnion, 30),
      _i(_oliveOil, _nOliveOil, 6),
      _i(_lemonJuice, _nLemonJuice, 5),
      _i(null, _nCumin, 1),
    ],
    steps: [
      _t('Soften the chopped onion and carrot in the oil.', '洋葱和胡萝卜切碎，用油炒软。'),
      _t(
        'Add the rinsed lentils, cumin and four times their volume of water.',
        '加入洗好的扁豆、孜然粉和四倍量的水。',
      ),
      _t(
        'Simmer 25 minutes until everything is very soft.',
        '小火煮 25 分钟，至所有食材都非常软烂。',
      ),
      _t('Blend until smooth and finish with lemon juice.', '搅打至顺滑，最后加柠檬汁。'),
    ],
    texture: DishTexture.liquidised,
  ),
  DishRecipe(
    id: 'dish_sa_eggplant_yogurt',
    name: _t('Roasted eggplant with yogurt', '烤茄子拌酸奶'),
    regions: const ['SA'],
    servings: 2,
    prepMinutes: 10,
    cookMinutes: 35,
    equipment: const [DishEquipment.oven, DishEquipment.bowl],
    ingredients: [
      _i(_eggplant, _t('Eggplant', '茄子'), 150),
      _i(_yogurtWhole, _t('Plain yogurt, whole milk', '原味全脂酸奶'), 50),
      _i(_oliveOil, _nOliveOil, 5),
      _i(_lemonJuice, _nLemonJuice, 5),
      _i(_garlic, _nGarlic, 2),
    ],
    steps: [
      _t(
        'Prick the eggplant and roast it whole at 220 °C (425 °F) for 30–35 minutes, until collapsed.',
        '茄子扎几个孔，整只放入 220 °C（425 °F）烤箱烤 30–35 分钟，至完全塌软。',
      ),
      _t('Let it cool slightly, then scoop out the flesh.', '稍放凉后挖出茄肉。'),
      _t(
        'Chop the flesh and mix in the yogurt, grated garlic and lemon juice.',
        '把茄肉切碎，拌入酸奶、蒜蓉和柠檬汁。',
      ),
      _t('Drizzle with the oil.', '淋上橄榄油。'),
    ],
    texture: DishTexture.mincedMoist,
    textureOption: DishTextureOption(
      texture: DishTexture.pureed,
      note: _t(
        'Blend the eggplant flesh with the yogurt until smooth.',
        '把茄肉和酸奶一起搅打至顺滑。',
      ),
    ),
  ),
]);

/// The dish with [id], or null.
DishRecipe? dishById(String id) {
  for (final dish in kDishCatalog) {
    if (dish.id == id) return dish;
  }
  return null;
}
