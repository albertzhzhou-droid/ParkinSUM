import '../../core/constants/food_serving_reference_amounts.dart';
import '../../core/constants/food_serving_reference_assignments.dart';
import '../../core/models/food_item.dart';
import '../entities/food_serving_reference.dart';

/// Resolves the reference serving a catalog food is evaluated at
/// (`food_serving_rule_v1`). Pure and deterministic; never invents a value.
///
/// 1. Values that are not per 100 g edible portion cannot be scaled by a
///    gram weight: no serving.
/// 2. Usable source portions have a finite positive gram weight and all name
///    the same source food; for an FDC-coded catalog item that source food
///    must be the item itself.
/// 3. Exactly one usable portion described as the source's NLEA serving is
///    the serving.
/// 4. Otherwise, when the food has a product category, the usable portion
///    closest to the category reference amount is the serving, among
///    portions above 50 % and below 200 % of it (the single-unit range of
///    21 CFR 101.9(b)(2)(i)(B)-(C)). A mass amount is compared in grams; a
///    volume amount is compared with portions stated in tsp, tbsp, cup,
///    fl oz, mL or L, using the 21 CFR 101.9(b)(5)(viii) equivalents. Ties go
///    to the lower source sequence number, then the earlier record.
/// 5. Otherwise a mass reference amount of the food's category is the
///    category default.
/// 6. Otherwise no serving: values stay per 100 g.
///
/// A serving describes an amount used to compare foods. It is not a portion
/// recommendation.
final class FoodServingReferenceResolver {
  const FoodServingReferenceResolver({
    this.categoryAssignments = foodServingReferenceCategoryAssignments,
  });

  /// Food id → product-category id.
  final Map<String, String> categoryAssignments;

  /// A portion qualifies only above this fraction of the reference amount.
  static const double minimumReferenceFraction = 0.5;

  /// A portion qualifies only below this multiple of the reference amount.
  static const double maximumReferenceMultiple = 2.0;

  /// Labeling equivalents of 21 CFR 101.9(b)(5)(viii), plus metric volumes.
  static const Map<String, double> householdMeasureMillilitres = {
    'tsp': 5,
    'tbsp': 15,
    'cup': 240,
    'fl oz': 30,
    'ml': 1,
    'l': 1000,
  };

  static final RegExp _nleaServing = RegExp(
    r'\bNLEA\s+serving\b',
    caseSensitive: false,
  );

  static final RegExp _householdVolume = RegExp(
    r'(?:(\d+\s*/\s*\d+|\d+(?:\.\d+)?(?:\s*-\s*\d+\s*/\s*\d+)?)\s*)?'
    r'\b(fl\.?\s*oz|fluid\s+ounces?|tablespoons?|tbsps?|teaspoons?|tsps?|'
    r'cups?|milliliters?|millilitres?|ml|liters?|litres?)\b',
    caseSensitive: false,
  );

  static final RegExp _fdcCode = RegExp(r'^\d+$');

  /// Category assigned to [food], if any.
  FoodServingReferenceCategory? categoryFor(FoodItem food) {
    final id = categoryAssignments[food.id];
    return id == null ? null : foodServingReferenceCategoriesById[id];
  }

  FoodServingReference resolve(FoodItem food) {
    final category = categoryFor(food);
    if (!food.supportsEdibleMassPoint) {
      return FoodServingReference.none(
        reason: FoodServingNoneReasons.nutrientBasisNotPer100gEdible,
        referenceCategoryId: category?.id,
      );
    }

    final portions = _usablePortions(food);
    final nlea = portions
        .where((portion) => _nleaServing.hasMatch(portion.text))
        .toList(growable: false);
    if (nlea.length == 1) {
      return _sourcePortion(
        nlea.single,
        ruleId: FoodServingRuleIds.nleaServing,
        category: category,
      );
    }

    if (category == null) {
      return const FoodServingReference.none(
        reason: FoodServingNoneReasons.noReferenceCategory,
      );
    }

    _UsablePortion? best;
    double? bestDistance;
    for (final portion in portions) {
      final comparable = category.isMass
          ? portion.record.gramWeight!
          : householdVolumeMillilitres(portion.record);
      if (comparable == null || !comparable.isFinite) continue;
      final ratio = comparable / category.amount;
      if (ratio <= minimumReferenceFraction ||
          ratio >= maximumReferenceMultiple) {
        continue;
      }
      final distance = (comparable - category.amount).abs();
      if (best == null ||
          distance < bestDistance! ||
          (distance == bestDistance && _precedes(portion, best))) {
        best = portion;
        bestDistance = distance;
      }
    }
    if (best != null) {
      return _sourcePortion(
        best,
        ruleId: FoodServingRuleIds.closestHouseholdPortion,
        category: category,
      );
    }

    if (category.isMass) return FoodServingReference.categoryDefault(category);
    return FoodServingReference.none(
      reason: FoodServingNoneReasons.volumeReferenceWithoutSourceMeasure,
      referenceCategoryId: category.id,
    );
  }

  /// Household volume of [portion] in mL, or null when the record is not
  /// stated in a supported volume measure. An embedded quantity such as
  /// `bottle 8 fl oz` or `serving 1/2 cup` multiplies the record amount.
  static double? householdVolumeMillilitres(FoodPortionEvidence portion) {
    final match = _householdVolume.firstMatch(_portionText(portion));
    if (match == null) return null;
    final unit = _canonicalVolumeUnit(match.group(2)!);
    final unitMillilitres = householdMeasureMillilitres[unit];
    if (unitMillilitres == null) return null;
    final embedded = match.group(1);
    final embeddedQuantity = embedded == null ? 1.0 : _quantity(embedded);
    if (embeddedQuantity == null) return null;
    final amount = portion.amount ?? 1.0;
    final value = amount * embeddedQuantity * unitMillilitres;
    return value.isFinite && value > 0 ? value : null;
  }

  List<_UsablePortion> _usablePortions(FoodItem food) {
    final usable = <_UsablePortion>[];
    for (var index = 0; index < food.foodPortionEvidence.length; index++) {
      final record = food.foodPortionEvidence[index];
      final weight = record.gramWeight;
      if (weight == null || !weight.isFinite || weight <= 0) continue;
      final amount = record.amount;
      if (amount != null && (!amount.isFinite || amount <= 0)) continue;
      usable.add(_UsablePortion(index, record, _portionText(record)));
    }
    if (usable.isEmpty) return const [];
    final sourceFoodIds = usable
        .map((portion) => portion.record.sourceFoodId?.trim() ?? '')
        .toSet();
    if (sourceFoodIds.length != 1 || sourceFoodIds.single.isEmpty) {
      return const [];
    }
    final code = food.sourceFoodCode?.trim() ?? '';
    if (_fdcCode.hasMatch(code) && code != sourceFoodIds.single) {
      return const [];
    }
    return usable;
  }

  FoodServingReference _sourcePortion(
    _UsablePortion portion, {
    required String ruleId,
    required FoodServingReferenceCategory? category,
  }) => FoodServingReference.sourcePortion(
    grams: portion.record.gramWeight!,
    ruleId: ruleId,
    referenceCategoryId: category?.id,
    portionRecordLocator: portion.record.recordLocator,
    portionLabel: portionLabel(portion.record),
  );

  bool _precedes(_UsablePortion left, _UsablePortion right) {
    final leftSequence = left.record.sequenceNumber;
    final rightSequence = right.record.sequenceNumber;
    if (leftSequence != null &&
        rightSequence != null &&
        leftSequence != rightSequence) {
      return leftSequence < rightSequence;
    }
    if (leftSequence != null && rightSequence == null) return true;
    if (leftSequence == null && rightSequence != null) return false;
    return left.index < right.index;
  }

  /// Household description of a portion record, e.g. `1 cup` or
  /// `0.5 breast, bone and skin removed`.
  static String? portionLabel(FoodPortionEvidence portion) {
    final description = portion.portionDescription?.trim() ?? '';
    if (RegExp(r'^\d').hasMatch(description)) return description;
    final unitName = portion.measureUnitName?.trim() ?? '';
    final parts = <String>[
      if (unitName.isNotEmpty && unitName.toLowerCase() != 'undetermined')
        unitName,
      if (description.isNotEmpty) description,
      if ((portion.modifier?.trim() ?? '').isNotEmpty) portion.modifier!.trim(),
    ];
    if (parts.isEmpty) return null;
    final amount = portion.amount;
    final quantity = amount == null ? null : _formatQuantity(amount);
    return [?quantity, ...parts].join(' ');
  }

  static String _portionText(FoodPortionEvidence portion) => [
    portion.portionDescription,
    portion.modifier,
    portion.measureUnitName,
    portion.measureUnitAbbreviation,
  ].whereType<String>().join(' ');

  static String _canonicalVolumeUnit(String raw) {
    final unit = raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (unit.startsWith('fl') || unit.startsWith('fluid')) return 'fl oz';
    if (unit.startsWith('tablespoon') || unit.startsWith('tbsp')) return 'tbsp';
    if (unit.startsWith('teaspoon') || unit.startsWith('tsp')) return 'tsp';
    if (unit.startsWith('cup')) return 'cup';
    if (unit.startsWith('milli') || unit == 'ml') return 'ml';
    return 'l';
  }

  static double? _quantity(String raw) {
    final text = raw.replaceAll(' ', '');
    final mixed = RegExp(r'^(\d+)-(\d+)/(\d+)$').firstMatch(text);
    if (mixed != null) {
      final denominator = double.parse(mixed.group(3)!);
      if (denominator == 0) return null;
      return double.parse(mixed.group(1)!) +
          double.parse(mixed.group(2)!) / denominator;
    }
    final fraction = RegExp(r'^(\d+)/(\d+)$').firstMatch(text);
    if (fraction != null) {
      final denominator = double.parse(fraction.group(2)!);
      if (denominator == 0) return null;
      return double.parse(fraction.group(1)!) / denominator;
    }
    return double.tryParse(text);
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    final text = value.toString();
    return text.length > 6 ? value.toStringAsFixed(2) : text;
  }
}

class _UsablePortion {
  const _UsablePortion(this.index, this.record, this.text);

  final int index;
  final FoodPortionEvidence record;
  final String text;
}

/// Reference serving of [food] under the default category assignments.
FoodServingReference foodServingReferenceFor(FoodItem food) =>
    const FoodServingReferenceResolver().resolve(food);

/// Nutrient amounts of one catalog food at its evaluated amount: the
/// reference serving when one exists, else 100 g.
final class FoodServingNutrients {
  FoodServingNutrients(this.food, {FoodServingReference? serving})
    : serving = serving ?? foodServingReferenceFor(food);

  final FoodItem food;
  final FoodServingReference serving;

  double get evaluatedGrams => serving.evaluatedGrams;

  /// Protein compared with meal-sized ranking thresholds. A field the source
  /// marks missing keeps the legacy ranker's point value (0), as before.
  double get rankingProteinG => _scaledPoint(food.proteinG);

  /// Fiber compared with meal-sized ranking thresholds; same convention as
  /// [rankingProteinG].
  double get rankingFiberG => _scaledPoint(food.fiberG);

  /// Display value for [field] (`proteinG`, `carbsG`, `fatG`, `fiberG`) at
  /// the evaluated amount; null when the source marks it missing.
  double? displayValue(String field) {
    if (food.isNutrientMissing(field)) return null;
    final value = switch (field) {
      'proteinG' => food.proteinG,
      'carbsG' => food.carbsG,
      'fatG' => food.fatG,
      'fiberG' => food.fiberG,
      _ => null,
    };
    if (value == null || !value.isFinite || value < 0) return null;
    final scaled = value * serving.per100gScale;
    return scaled.isFinite ? scaled : null;
  }

  double _scaledPoint(double per100g) {
    final scaled = per100g * serving.per100gScale;
    return scaled.isFinite ? scaled : per100g;
  }
}
