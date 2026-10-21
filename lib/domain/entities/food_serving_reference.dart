/// Reference serving used to express a catalog food's per-100 g nutrient
/// values as one realistic eating occasion when next-meal candidates are
/// compared.
///
/// A reference serving is either a portion reported by the food's own source
/// record or, when no usable record exists, the reference amount documented
/// for its product category. It describes an amount used for comparison. It
/// is not a portion recommendation for any person.
///
/// Educational prototype only.
library;

/// How a reference serving was obtained.
enum FoodServingBasis {
  /// A household portion reported by the food's source record (for example
  /// an FDC `foodPortions` row), selected by the documented serving rule.
  sourcePortion('source_portion'),

  /// The reference amount documented for the food's product category
  /// (FDA/USDA reference amount customarily consumed). It is an assumed
  /// amount, so the mechanistic trace widens uncertainty.
  categoryDefault('category_default'),

  /// No serving is available. Nutrient values stay per 100 g and are labelled
  /// as such.
  none('none');

  const FoodServingBasis(this.wireName);

  final String wireName;

  static FoodServingBasis? fromWireName(String? value) {
    for (final basis in values) {
      if (basis.wireName == value) return basis;
    }
    return null;
  }
}

/// Unit of a reference amount: a mass, or a volume compared through the
/// household measures used for nutrition labeling.
enum FoodServingAmountUnit {
  grams('g'),
  millilitres('mL');

  const FoodServingAmountUnit(this.symbol);

  final String symbol;
}

/// One documented reference amount for a product category.
///
/// [amount] is the reference amount in [unit]. A volume amount stated in a
/// household measure keeps that measure in [statedAmount]; its millilitre
/// value uses the labeling equivalents of 21 CFR 101.9(b)(5)(viii)
/// (1 tsp = 5 mL, 1 tbsp = 15 mL, 1 cup = 240 mL).
final class FoodServingReferenceCategory {
  const FoodServingReferenceCategory({
    required this.id,
    required this.productCategory,
    required this.statedAmount,
    required this.amount,
    required this.unit,
    required this.citation,
  });

  final String id;

  /// Product-category wording of the cited table (abridged where the source
  /// row lists many examples).
  final String productCategory;

  /// Reference amount as the cited table states it, e.g. `140 g prepared` or
  /// `1 tbsp`.
  final String statedAmount;

  final double amount;
  final FoodServingAmountUnit unit;

  /// Regulation table the amount is taken from.
  final String citation;

  bool get isMass => unit == FoodServingAmountUnit.grams;

  /// Reference grams, or null for a volume amount. A volume amount is never
  /// converted to grams without the food's own household-measure weight.
  double? get grams => isMass ? amount : null;

  Map<String, Object?> toJson() => {
    'id': id,
    'product_category': productCategory,
    'stated_amount': statedAmount,
    'amount': amount,
    'unit': unit.symbol,
    'citation': citation,
  };
}

/// The serving one catalog food is evaluated at.
final class FoodServingReference {
  const FoodServingReference._({
    required this.basis,
    required this.grams,
    required this.ruleId,
    required this.referenceCategoryId,
    required this.portionRecordLocator,
    required this.portionLabel,
    required this.reason,
  });

  /// A portion reported by the food's source record.
  factory FoodServingReference.sourcePortion({
    required double grams,
    required String ruleId,
    required String? referenceCategoryId,
    required String? portionRecordLocator,
    required String? portionLabel,
  }) {
    if (!grams.isFinite || grams <= 0) {
      throw ArgumentError.value(grams, 'grams', 'must be finite and positive');
    }
    return FoodServingReference._(
      basis: FoodServingBasis.sourcePortion,
      grams: grams,
      ruleId: ruleId,
      referenceCategoryId: referenceCategoryId,
      portionRecordLocator: portionRecordLocator,
      portionLabel: portionLabel,
      reason: null,
    );
  }

  /// The mass reference amount of the food's product category.
  factory FoodServingReference.categoryDefault(
    FoodServingReferenceCategory category,
  ) {
    final grams = category.grams;
    if (grams == null || !grams.isFinite || grams <= 0) {
      throw ArgumentError.value(
        category.id,
        'category',
        'a category default needs a positive mass reference amount',
      );
    }
    return FoodServingReference._(
      basis: FoodServingBasis.categoryDefault,
      grams: grams,
      ruleId: FoodServingRuleIds.categoryReferenceAmount,
      referenceCategoryId: category.id,
      portionRecordLocator: null,
      portionLabel: category.statedAmount,
      reason: null,
    );
  }

  /// No serving: values stay per 100 g. [reason] names why.
  const FoodServingReference.none({
    required String this.reason,
    this.referenceCategoryId,
  }) : basis = FoodServingBasis.none,
       grams = null,
       ruleId = FoodServingRuleIds.noServing,
       portionRecordLocator = null,
       portionLabel = null;

  final FoodServingBasis basis;

  /// Serving mass in grams; null for [FoodServingBasis.none].
  final double? grams;

  /// Which step of the serving rule produced this result.
  final String ruleId;

  /// Product category assigned to the food, when one is assigned.
  final String? referenceCategoryId;

  /// Locator of the selected source portion record.
  final String? portionRecordLocator;

  /// Household description of the selected portion (for example `1 cup`) or
  /// the stated reference amount of a category default.
  final String? portionLabel;

  /// For [FoodServingBasis.none]: why no serving is available.
  final String? reason;

  bool get hasServing => grams != null;

  /// Grams the evaluated nutrient values describe: the serving, else 100 g.
  double get evaluatedGrams => grams ?? 100.0;

  /// Factor applied to per-100 g source values; 1 when no serving exists.
  double get per100gScale => grams == null ? 1.0 : grams! / 100.0;

  Map<String, Object?> toJson() => {
    'basis': basis.wireName,
    'grams': grams,
    'rule_id': ruleId,
    'reference_category_id': referenceCategoryId,
    'portion_record_locator': portionRecordLocator,
    'portion_label': portionLabel,
    'reason': reason,
  };
}

/// Identifiers of the steps of the documented serving rule.
abstract final class FoodServingRuleIds {
  static const String ruleVersion = 'food_serving_rule_v1';

  /// Exactly one usable source portion is the source's NLEA serving.
  static const String nleaServing = 'source_portion.nlea_serving';

  /// The usable source portion closest to the category reference amount,
  /// among portions above 50 % and below 200 % of it.
  static const String closestHouseholdPortion =
      'source_portion.closest_to_reference_amount';

  /// The category's mass reference amount.
  static const String categoryReferenceAmount =
      'category_default.reference_amount';

  static const String noServing = 'none';
}

/// Reasons recorded with [FoodServingBasis.none].
abstract final class FoodServingNoneReasons {
  /// Nutrient values are not on a per-100 g edible-portion basis, so they
  /// cannot be scaled by a gram weight.
  static const String nutrientBasisNotPer100gEdible =
      'nutrient_basis_not_per_100g_edible_portion';

  /// No product category is assigned and the source reports no NLEA serving.
  static const String noReferenceCategory = 'no_reference_category';

  /// The category amount is a volume and no source household measure lies
  /// within the accepted range, so grams would need an invented density.
  static const String volumeReferenceWithoutSourceMeasure =
      'volume_reference_amount_without_source_measure';
}
