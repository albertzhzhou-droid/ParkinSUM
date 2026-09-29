import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import 'dosage_note_parser.dart';

class DataIntegrityReport {
  const DataIntegrityReport({
    required this.intakeCount,
    required this.intakesWithParseableDose,
    required this.intakesWithResultEligibleDose,
    required this.intakesWithFormulationSnapshot,
    required this.orphanedIntakeCount,
    required this.mealCount,
    required this.mealsWithExplicitTime,
    required this.emptyMealCount,
    required this.mealItemCount,
    required this.resolvedMealItemCount,
    required this.foodCount,
    required this.traceableFoodCount,
    required this.foodsWithMissingCoreNutrients,
    required this.medicationCount,
    required this.traceableMedicationCount,
    required this.medicationsWithIncompleteFormulation,
  });

  final int intakeCount;
  final int intakesWithParseableDose;
  final int intakesWithResultEligibleDose;

  /// Compatibility name retained for existing UI call sites. "Computable"
  /// now means the confirmation- and assertion-gated result-use state, not
  /// merely that a legacy string parser found a number and unit.
  int get intakesWithComputableDose => intakesWithResultEligibleDose;
  final int intakesWithFormulationSnapshot;
  final int orphanedIntakeCount;
  final int mealCount;
  final int mealsWithExplicitTime;
  final int emptyMealCount;
  final int mealItemCount;
  final int resolvedMealItemCount;
  final int foodCount;
  final int traceableFoodCount;
  final int foodsWithMissingCoreNutrients;
  final int medicationCount;
  final int traceableMedicationCount;
  final int medicationsWithIncompleteFormulation;

  int get missingDoseCount => intakeCount - intakesWithResultEligibleDose;
  int get missingFormulationSnapshotCount =>
      intakeCount - intakesWithFormulationSnapshot;
  int get unresolvedMealItemCount => mealItemCount - resolvedMealItemCount;

  bool get requiresReview =>
      orphanedIntakeCount > 0 ||
      missingDoseCount > 0 ||
      emptyMealCount > 0 ||
      unresolvedMealItemCount > 0;

  double? get parseableDoseCoverage =>
      _coverage(intakesWithParseableDose, intakeCount);
  double? get doseCoverage =>
      _coverage(intakesWithResultEligibleDose, intakeCount);
  double? get formulationSnapshotCoverage =>
      _coverage(intakesWithFormulationSnapshot, intakeCount);
  double? get mealTimeCoverage => _coverage(mealsWithExplicitTime, mealCount);
  double? get mealItemResolutionCoverage =>
      _coverage(resolvedMealItemCount, mealItemCount);
  double? get foodTraceabilityCoverage =>
      _coverage(traceableFoodCount, foodCount);
  double? get medicationTraceabilityCoverage =>
      _coverage(traceableMedicationCount, medicationCount);

  static DataIntegrityReport assess({
    required List<Intake> intakes,
    required List<Meal> meals,
    required List<FoodItem> foods,
    required List<DrugDefinition> medications,
    required bool Function(Intake intake) doseResultEligibility,
    DosageNoteParser? dosageNoteParser,
  }) {
    final parser = dosageNoteParser ?? DosageNoteParser();
    final foodIds = foods.map((food) => food.id).toSet();
    final medicationIds = medications.map((drug) => drug.id).toSet();
    final mealItems = meals.expand((meal) => meal.items).toList();

    return DataIntegrityReport(
      intakeCount: intakes.length,
      intakesWithParseableDose: intakes
          .where((intake) => parser.parseIntake(intake).explicit)
          .length,
      intakesWithResultEligibleDose: intakes
          .where(doseResultEligibility)
          .length,
      intakesWithFormulationSnapshot: intakes
          .where(
            (intake) =>
                _isKnown(intake.dosageForm) &&
                _isKnown(intake.route) &&
                _isKnown(intake.releaseType),
          )
          .length,
      orphanedIntakeCount: intakes
          .where((intake) => !medicationIds.contains(intake.drugId))
          .length,
      mealCount: meals.length,
      mealsWithExplicitTime: meals
          .where(
            (meal) =>
                meal.timeSource != 'implicit_now' &&
                meal.timeSource != 'migration_legacy',
          )
          .length,
      emptyMealCount: meals.where((meal) => meal.items.isEmpty).length,
      mealItemCount: mealItems.length,
      resolvedMealItemCount: mealItems
          .where((item) => foodIds.contains(item.foodId))
          .length,
      foodCount: foods.length,
      traceableFoodCount: foods
          .where(
            (food) =>
                food.sourceSystem != 'LOCAL_SEED' &&
                _isKnown(food.sourceFoodCode),
          )
          .length,
      foodsWithMissingCoreNutrients: foods
          .where(
            (food) => const <String>{
              'proteinG',
              'carbsG',
              'fatG',
              'fiberG',
              'sodiumMg',
            }.any(food.missingNutrientFields.contains),
          )
          .length,
      medicationCount: medications.length,
      traceableMedicationCount: medications
          .where(
            (drug) =>
                drug.sourceSystem != 'LOCAL_SEED' &&
                _isKnown(drug.sourceProductCode),
          )
          .length,
      medicationsWithIncompleteFormulation: medications
          .where(
            (drug) =>
                !_isKnown(drug.dosageForm) ||
                !_isKnown(drug.route) ||
                !_isKnown(drug.releaseType),
          )
          .length,
    );
  }

  static double? _coverage(int numerator, int denominator) =>
      denominator == 0 ? null : numerator / denominator;

  static bool _isKnown(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null &&
        normalized.isNotEmpty &&
        normalized != 'unspecified' &&
        normalized != 'unknown';
  }
}
