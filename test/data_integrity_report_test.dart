import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/data_integrity_report.dart';

void main() {
  test('reports computability, orphan references, and source traceability', () {
    final foods = <FoodItem>[
      FoodItem(
        id: 'official_food',
        name: 'Official food',
        category: FoodCategory.protein,
        sourceSystem: 'USDA_FDC',
        sourceFoodCode: '123',
        proteinG: 0,
        carbsG: 10,
        fatG: 1,
        fiberG: 2,
        sodiumMg: 3,
        missingNutrientFields: const <String>{'proteinG'},
      ),
      FoodItem(
        id: 'seed_food',
        name: 'Seed food',
        category: FoodCategory.other,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        fiberG: 0,
        sodiumMg: 0,
      ),
    ];
    final medications = <DrugDefinition>[
      DrugDefinition(
        id: 'official_drug',
        genericName: 'Drug',
        brandNames: const <String>[],
        tags: const <DrugTag>[],
        notes: '',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'set-id',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
      ),
      DrugDefinition(
        id: 'seed_drug',
        genericName: 'Seed',
        brandNames: const <String>[],
        tags: const <DrugTag>[],
        notes: '',
      ),
    ];
    const owner = 'data_integrity_owner';
    final observedAt = DateTime.utc(2026, 8, 16, 14);
    final coordinator = AdministrationDoseConfirmationCoordinator();
    final confirmed = coordinator
        .prepare(
          draft: Intake(
            id: 'computable',
            drugId: 'official_drug',
            takenAt: DateTime(2026, 8, 16, 8),
            dosageNote: '100 mg',
            dosageForm: 'tablet',
            route: 'oral',
            releaseType: 'immediate',
          ),
          current: null,
          expectedRecordRevisionDigest:
              administrationDoseConfirmationAbsentRevisionDigest,
          ownerScope: owner,
          operationId: 'data_integrity_confirmation',
          confirmationRequested: true,
          assertionSource: AdministrationDoseAssertionSource.typed,
          confirmationAction: 'test.explicit_confirmation',
          uiContractVersion: 'test-dose-confirmation:1',
          confirmedAt: DateTime.utc(2026, 8, 16, 8, 1),
        )
        .intake!;
    final intakes = <Intake>[
      confirmed,
      Intake(
        id: 'orphan',
        drugId: 'missing_drug',
        takenAt: DateTime(2026, 8, 16, 9),
        dosageNote: '50 mg',
      ),
    ];
    final meals = <Meal>[
      Meal(
        id: 'explicit',
        eatenAt: DateTime(2026, 8, 16, 12),
        occurredAt: DateTime(2026, 8, 16, 12),
        timeSource: 'user_exact',
        title: 'Meal',
        items: <MealItem>[
          _mealItem('official_food'),
          _mealItem('missing_food'),
        ],
      ),
      Meal(
        id: 'empty',
        eatenAt: DateTime(2026, 8, 16, 13),
        title: 'Empty',
        items: const <MealItem>[],
      ),
    ];

    final report = DataIntegrityReport.assess(
      intakes: intakes,
      meals: meals,
      foods: foods,
      medications: medications,
      doseResultEligibility: (intake) => coordinator
          .evaluateForResultUse(
            intake,
            ownerScope: owner,
            observedAt: observedAt,
          )
          .eligible,
    );

    expect(report.doseCoverage, 0.5);
    expect(report.parseableDoseCoverage, 1);
    expect(report.intakesWithResultEligibleDose, 1);
    expect(report.intakesWithParseableDose, 2);
    expect(report.formulationSnapshotCoverage, 0.5);
    expect(report.orphanedIntakeCount, 1);
    expect(report.mealTimeCoverage, 0.5);
    expect(report.emptyMealCount, 1);
    expect(report.mealItemResolutionCoverage, 0.5);
    expect(report.foodTraceabilityCoverage, 0.5);
    expect(report.foodsWithMissingCoreNutrients, 1);
    expect(report.medicationTraceabilityCoverage, 0.5);
    expect(report.medicationsWithIncompleteFormulation, 1);
    expect(report.requiresReview, isTrue);
  });

  test('empty collections report unknown coverage rather than false 100%', () {
    final report = DataIntegrityReport.assess(
      intakes: const <Intake>[],
      meals: const <Meal>[],
      foods: const <FoodItem>[],
      medications: const <DrugDefinition>[],
      doseResultEligibility: (_) => false,
    );

    expect(report.doseCoverage, isNull);
    expect(report.parseableDoseCoverage, isNull);
    expect(report.mealTimeCoverage, isNull);
    expect(report.mealItemResolutionCoverage, isNull);
    expect(report.foodTraceabilityCoverage, isNull);
    expect(report.medicationTraceabilityCoverage, isNull);
  });
}

MealItem _mealItem(String foodId) {
  return MealItem(
    foodId: foodId,
    foodName: foodId,
    foodCategory: FoodCategory.other,
    quantityFactor: 1,
    foodTags: const <String>[],
    proteinPer100g: 0,
    carbsPer100g: 0,
    fatPer100g: 0,
    fiberPer100g: 0,
    sodiumPer100g: 0,
  );
}
