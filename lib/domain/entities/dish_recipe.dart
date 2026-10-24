/// Curated example dishes for the Advanced page of Next meal.
///
/// A dish is declarative data: names, region tags, equipment, short
/// preparation steps written for this app, and ingredients with grams per
/// serving. Ingredients point at catalog food ids; an ingredient without a
/// catalog id is listed but carries no nutrition (unknown, never zero).
/// Nutrition is computed at runtime by `DishNutritionView` from the catalog,
/// so no nutrient value is typed into a dish.
library;

/// English and Chinese copy carried by the dish data itself. Other language
/// families fall back to English.
final class DishText {
  const DishText({required this.en, required this.zh});

  final String en;
  final String zh;

  String forFamily(String languageFamily) => languageFamily == 'zh' ? zh : en;
}

/// Texture tags use IDDSI food level names as a vocabulary only. A tag
/// describes how the dish is prepared here; it is not the result of IDDSI
/// testing and not a swallowing recommendation.
enum DishTexture {
  /// IDDSI level 7 wording: regular.
  regular(7),

  /// IDDSI level 6 wording: soft and bite-sized.
  softBiteSized(6),

  /// IDDSI level 5 wording: minced and moist.
  mincedMoist(5),

  /// IDDSI level 4 wording: pureed.
  pureed(4),

  /// IDDSI level 3 wording: liquidised.
  liquidised(3);

  const DishTexture(this.iddsiLevel);

  final int iddsiLevel;
}

/// An alternative texture the same dish can be prepared at, with a short
/// description of the preparation change. A texture option only; texture
/// needs are set with a speech-language pathologist or clinician.
final class DishTextureOption {
  const DishTextureOption({required this.texture, required this.note});

  final DishTexture texture;
  final DishText note;
}

/// Equipment vocabulary; labels live in the advanced-dishes translations.
enum DishEquipment {
  pot,
  saucepan,
  fryingPan,
  wok,
  steamer,
  oven,
  blender,
  riceCooker,
  bowl,
}

final class DishIngredient {
  const DishIngredient({
    required this.name,
    required this.gramsPerServing,
    this.foodId,
  });

  /// Catalog food id (`food_ref_usda_*` or a P0 id), or null when the
  /// ingredient has no catalog entry.
  final String? foodId;
  final DishText name;
  final double gramsPerServing;

  bool get inCatalog => foodId != null;
}

final class DishRecipe {
  const DishRecipe({
    required this.id,
    required this.name,
    required this.regions,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.equipment,
    required this.ingredients,
    required this.steps,
    required this.texture,
    this.textureOption,
  });

  /// Stable id, `dish_<region>_<slug>`.
  final String id;
  final DishText name;

  /// Registration-region codes (see `kSupportedRegistrationRegions`).
  final List<String> regions;

  /// Servings the steps make. Ingredient grams are per one serving.
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<DishEquipment> equipment;
  final List<DishIngredient> ingredients;
  final List<DishText> steps;

  /// Texture as the steps prepare it.
  final DishTexture texture;
  final DishTextureOption? textureOption;

  int get totalMinutes => prepMinutes + cookMinutes;

  /// True when the dish is prepared at, or offers an option for, [level].
  bool offersTexture(DishTexture level) =>
      texture == level || textureOption?.texture == level;
}
