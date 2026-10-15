/// Official USDA FoodData Central nutrient and portion records for the SR
/// Legacy reference and seed foods.
///
/// Every record is copied from the FDC full download of 2025-04-24
/// (`food_nutrient.csv`, `food_portion.csv`, `food_nutrient_derivation.csv`).
/// Values are per 100 g edible portion. A missing optional field is missing
/// in the source; it is never filled in.
///
/// Educational prototype only. These records describe sampled foods, not any
/// person's diet.
library;

/// One FDC `food_nutrient.csv` row: the fields the app uses, verbatim.
final class ReferenceNutrientRecord {
  /// FDC `id` of the row.
  final int rowId;
  final int fdcId;

  /// FDC `nutrient_id` (see `tool/data/fdc_2025-04-24/nutrient.csv`).
  final int nutrientId;

  /// Amount per 100 g edible portion, in the nutrient's own unit.
  final double amount;

  /// Number of analytical observations; null when the source gives none.
  final int? dataPoints;

  /// FDC `derivation_id` (see [FdcDerivationCode]); null when not reported.
  final int? derivationId;
  final double? min;
  final double? max;
  final double? median;
  final int? minYearAcquired;

  const ReferenceNutrientRecord(
    this.rowId,
    this.fdcId,
    this.nutrientId,
    this.amount, [
    this.dataPoints,
    this.derivationId,
    this.min,
    this.max,
    this.median,
    this.minYearAcquired,
  ]);
}

/// One FDC `food_portion.csv` row, verbatim. A portion is source evidence
/// only; it is never a recommended serving.
final class ReferencePortionRecord {
  final int rowId;
  final int fdcId;
  final int? sequenceNumber;
  final double? amount;
  final int? measureUnitId;
  final String portionDescription;
  final String modifier;
  final double? gramWeight;
  final int? dataPoints;
  final int? minYearAcquired;

  const ReferencePortionRecord(
    this.rowId,
    this.fdcId,
    this.sequenceNumber,
    this.amount,
    this.measureUnitId,
    this.portionDescription,
    this.modifier,
    this.gramWeight, [
    this.dataPoints,
    this.minYearAcquired,
  ]);
}

/// One FDC `food_nutrient_derivation.csv` row.
final class FdcDerivationCode {
  final int id;
  final String code;
  final String description;

  const FdcDerivationCode(this.id, this.code, this.description);
}
