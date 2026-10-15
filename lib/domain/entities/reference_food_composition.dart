/// Reference food composition rows (USDA SR Legacy subset) and the nutrient
/// convention metadata that makes them comparable with other sources.
///
/// Educational prototype only. These rows describe average composition of
/// sampled foods; they are not a statement about any person's diet.
library;

/// How a source defines its "carbohydrate" field. Mixing conventions without
/// conversion double-counts (or drops) dietary fibre.
enum CarbohydrateConvention {
  /// 100 − (water + protein + fat + ash). Includes dietary fibre.
  /// USDA FDC nutrient 1005 / legacy number 205.
  byDifferenceIncludingFiber,

  /// Available carbohydrate (sugars + starch [+ polyols]); excludes fibre.
  /// CIQUAL "Glucides"; USDA FDC nutrient 1050 "by summation".
  availableExcludingFiber,

  /// The source convention was not verified from its documentation. A
  /// conversion must abstain rather than guess.
  unverified,
}

/// Coarse food group used for interdependency rules and catalog grouping.
enum ReferenceFoodGroup {
  fruit,
  vegetable,
  legume,
  grain,
  dairy,
  egg,
  meat,
  poultry,
  fishSeafood,
  nutSeed,
  fatOil,
  beverage,
  alcoholicBeverage,
  sweetenerConfection,
  condiment,
  proteinSupplement,
}

ReferenceFoodGroup referenceFoodGroupFromWire(String value) {
  switch (value) {
    case 'fruit':
      return ReferenceFoodGroup.fruit;
    case 'vegetable':
      return ReferenceFoodGroup.vegetable;
    case 'legume':
      return ReferenceFoodGroup.legume;
    case 'grain':
      return ReferenceFoodGroup.grain;
    case 'dairy':
      return ReferenceFoodGroup.dairy;
    case 'egg':
      return ReferenceFoodGroup.egg;
    case 'meat':
      return ReferenceFoodGroup.meat;
    case 'poultry':
      return ReferenceFoodGroup.poultry;
    case 'fish_seafood':
      return ReferenceFoodGroup.fishSeafood;
    case 'nut_seed':
      return ReferenceFoodGroup.nutSeed;
    case 'fat_oil':
      return ReferenceFoodGroup.fatOil;
    case 'beverage':
      return ReferenceFoodGroup.beverage;
    case 'alcoholic_beverage':
      return ReferenceFoodGroup.alcoholicBeverage;
    case 'sweetener_confection':
      return ReferenceFoodGroup.sweetenerConfection;
    case 'condiment':
      return ReferenceFoodGroup.condiment;
    case 'protein_supplement':
      return ReferenceFoodGroup.proteinSupplement;
  }
  throw ArgumentError.value(value, 'value', 'Unknown reference food group');
}

/// One verbatim USDA SR Legacy row (per 100 g edible portion) plus curation
/// metadata. Null means "not reported by the source" — never zero.
///
/// The nutrient values are reproduced exactly from
/// `tool/data/usda_sr_legacy_reference_subset_2018.csv`; a test re-renders the
/// generated table from that file and fails on any drift.
final class ReferenceFoodCompositionRow {
  final int fdcId;
  final String sourceDescription;
  final String nameEn;
  final String nameZh;
  final ReferenceFoodGroup group;
  final String preparationState;
  final String? textureClass;

  final double? energyKcal;
  final double? proteinG;
  final double? fatG;

  /// USDA "Carbohydrate, by difference" (includes dietary fibre).
  final double? carbohydrateByDifferenceG;
  final double? fiberG;
  final double? calciumMg;
  final double? phosphorusMg;
  final double? ironMg;
  final double? sodiumMg;
  final double? potassiumMg;
  final double? copperMg;
  final double? zincMg;
  final double? retinolUg;
  final double? betaCaroteneUg;
  final double? thiaminMg;
  final double? riboflavinMg;
  final double? niacinMg;
  final double? vitaminCMg;

  const ReferenceFoodCompositionRow({
    required this.fdcId,
    required this.sourceDescription,
    required this.nameEn,
    required this.nameZh,
    required this.group,
    required this.preparationState,
    required this.textureClass,
    required this.energyKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbohydrateByDifferenceG,
    required this.fiberG,
    required this.calciumMg,
    required this.phosphorusMg,
    required this.ironMg,
    required this.sodiumMg,
    required this.potassiumMg,
    required this.copperMg,
    required this.zincMg,
    required this.retinolUg,
    required this.betaCaroteneUg,
    required this.thiaminMg,
    required this.riboflavinMg,
    required this.niacinMg,
    required this.vitaminCMg,
  });

  /// The carbohydrate column is USDA "Carbohydrate, by difference".
  static const CarbohydrateConvention carbohydrateConvention =
      CarbohydrateConvention.byDifferenceIncludingFiber;

  String get appFoodId => 'food_ref_usda_$fdcId';

  String get sourceFoodCode => 'FDC:$fdcId';
}
