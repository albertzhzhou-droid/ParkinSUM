import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';

void main() {
  const service = PersonalLogHandoffSummaryService();
  final options = PersonalLogHandoffOptions(
    startDate: DateTime.utc(2026, 8, 1),
    endDateInclusive: DateTime.utc(2026, 8, 31),
    sections: PersonalLogHandoffSection.values.toSet(),
    redaction: PersonalLogHandoffRedaction.detailed,
  );

  test('creates a deterministic bounded truth-preserving handoff', () {
    final snapshot = _snapshot();
    final artifact = service.create(
      snapshot: snapshot,
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.recordCounts, <String, int>{
      'currentMedications': 1,
      'historicalMedications': 1,
      'intakes': 2,
      'meals': 1,
      'mealItems': 2,
    });
    expect(artifact.plainText, contains('Current medication selections'));
    expect(artifact.plainText, contains('Historical-only medications'));
    expect(artifact.plainText, contains('Active medicine'));
    expect(artifact.plainText, contains('Historical medicine'));
    expect(artifact.plainText, contains('original dose=0.25 g'));
    expect(artifact.plainText, contains('canonical dose=250 mg'));
    expect(artifact.plainText, contains('original dose=unknown'));
    expect(artifact.plainText, contains('timezone=unknown'));
    expect(artifact.plainText, contains('protein=0 g'));
    expect(artifact.plainText, contains('protein=unknown'));
    expect(artifact.plainText, contains('source=TEST_FOOD'));
    expect(artifact.plainText, contains('USER-ENTERED PERSONAL LOG'));
    expect(artifact.plainText, contains('CLINICALLY VERIFIED'));
    expect(artifact.plainText, contains('no algorithm rank'));
    expect(artifact.plainText, isNot(contains('outside-range-note')));
    expect(artifact.plainText, isNot(contains('owner@example.test')));
    expect(artifact.plainText, isNot(contains('patient@example.test')));
    expect(artifact.pages, isNotEmpty);
    expect(
      artifact.pages.length,
      lessThanOrEqualTo(personalLogHandoffMaxPages),
    );

    final reordered = service.create(
      snapshot: _snapshot(reverseInputs: true),
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );
    expect(reordered.sourceRevisionSha256, artifact.sourceRevisionSha256);
    expect(reordered.contentSha256, artifact.contentSha256);
    expect(reordered.plainText, artifact.plainText);
  });

  test('counts-only redaction omits names, notes and source codes', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      options: PersonalLogHandoffOptions(
        startDate: options.startDate,
        endDateInclusive: options.endDateInclusive,
        sections: PersonalLogHandoffSection.values.toSet(),
        redaction: PersonalLogHandoffRedaction.countsOnly,
      ),
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.plainText, contains('Redaction: countsOnly'));
    expect(artifact.plainText, contains('- Count: 1'));
    expect(artifact.plainText, contains('- Meals: 1'));
    expect(artifact.plainText, isNot(contains('Active medicine')));
    expect(artifact.plainText, isNot(contains('sensitive dose note')));
    expect(artifact.plainText, isNot(contains('FOOD-CODE-ZERO')));
  });

  test(
    'same-id content, options, and range changes rotate source revision',
    () {
      final original = service.sourceRevisionDigest(
        snapshot: _snapshot(),
        options: options,
      );
      final changed = service.sourceRevisionDigest(
        snapshot: _snapshot(intakeDoseAmount: 0.5),
        options: options,
      );
      final fewerSections = service.sourceRevisionDigest(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: options.startDate,
          endDateInclusive: options.endDateInclusive,
          sections: const <PersonalLogHandoffSection>{
            PersonalLogHandoffSection.intakeLog,
          },
          redaction: options.redaction,
        ),
      );
      final shorterRange = service.sourceRevisionDigest(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: DateTime.utc(2026, 8, 2),
          endDateInclusive: options.endDateInclusive,
          sections: options.sections,
          redaction: options.redaction,
        ),
      );

      expect(changed, isNot(original));
      expect(fewerSections, isNot(original));
      expect(shorterRange, isNot(original));
    },
  );

  test('invalid inputs fail closed before an artifact exists', () {
    expect(
      () => service.create(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: DateTime.utc(2026, 8, 2),
          endDateInclusive: DateTime.utc(2026, 8, 1),
          sections: const <PersonalLogHandoffSection>{
            PersonalLogHandoffSection.intakeLog,
          },
          redaction: PersonalLogHandoffRedaction.standard,
        ),
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(duplicateIntake: true),
        options: options,
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(intakeDoseAmount: double.nan),
        options: options,
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: DateTime.utc(2025, 1, 1),
          endDateInclusive: DateTime.utc(2026, 8, 31),
          sections: const <PersonalLogHandoffSection>{
            PersonalLogHandoffSection.intakeLog,
          },
          redaction: PersonalLogHandoffRedaction.standard,
        ),
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
  });
}

PersonalLogHandoffSnapshot _snapshot({
  bool reverseInputs = false,
  bool duplicateIntake = false,
  double intakeDoseAmount = 0.25,
}) {
  final active = DrugDefinition(
    id: 'drug_active',
    genericName: 'Active medicine',
    brandNames: const <String>[],
    tags: const <DrugTag>[DrugTag.unknown],
    notes: '',
    sourceSystem: 'TEST_DRUG',
    sourceProductCode: 'ACTIVE-CODE',
    route: 'oral',
    dosageForm: 'tablet',
    releaseType: 'immediate',
  );
  final historical = DrugDefinition(
    id: 'drug_old',
    genericName: 'Historical medicine',
    brandNames: const <String>[],
    tags: const <DrugTag>[DrugTag.unknown],
    notes: '',
    sourceSystem: 'TEST_DRUG',
    sourceProductCode: 'HISTORICAL-CODE',
    route: 'oral',
    dosageForm: 'tablet',
    releaseType: 'immediate',
  );
  final intakes = <Intake>[
    Intake(
      id: 'intake_a',
      drugId: 'drug_active',
      takenAt: DateTime.parse('2026-08-05T08:00:00-04:00'),
      dosageNote: '',
      doseAmount: intakeDoseAmount,
      doseUnit: 'g',
      dosageForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
    ),
    Intake(
      id: duplicateIntake ? 'intake_a' : 'intake_b',
      drugId: 'drug_old',
      takenAt: DateTime.parse('2026-08-06T08:00:00-04:00'),
      dosageNote: '',
    ),
    Intake(
      id: 'intake_outside',
      drugId: 'drug_active',
      takenAt: DateTime.utc(2026, 7, 1),
      dosageNote: 'outside-range-note',
    ),
  ];
  final zeroFood = FoodItem(
    id: 'food_zero',
    name: 'Known zero food',
    category: FoodCategory.other,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
    sourceSystem: 'TEST_FOOD',
    sourceFoodCode: 'FOOD-CODE-ZERO',
    basisType: 'per_100g',
    qualifierKind: 'analytical',
  );
  final missingFood = FoodItem(
    id: 'food_missing',
    name: 'Unknown nutrient food',
    category: FoodCategory.other,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
    missingNutrientFields: const <String>{
      'proteinG',
      'carbsG',
      'fatG',
      'fiberG',
      'sodiumMg',
    },
    sourceSystem: 'TEST_FOOD',
  );
  final meal = Meal(
    id: 'meal_a',
    eatenAt: DateTime.parse('2026-08-07T12:00:00-04:00'),
    occurredAt: DateTime.parse('2026-08-07T12:00:00-04:00'),
    timeSource: 'user_entered',
    timePrecision: 'exact',
    title: 'Lunch',
    items: <MealItem>[
      MealItem.fromFood(food: zeroFood, quantityFactor: 1),
      MealItem.fromFood(food: missingFood, quantityFactor: 1),
    ],
  );
  return PersonalLogHandoffSnapshot(
    ownerScope: 'owner@example.test',
    profile: UserProfile.defaults().copyWith(
      patientId: 'patient@example.test',
      timezone: 'America/Toronto',
    ),
    activeDrugIds: const <String>['drug_active'],
    intakes: reverseInputs ? intakes.reversed : intakes,
    meals: <Meal>[meal],
    medicationCatalog: reverseInputs
        ? <DrugDefinition>[historical, active]
        : <DrugDefinition>[active, historical],
    foodCatalog: reverseInputs
        ? <FoodItem>[missingFood, zeroFood]
        : <FoodItem>[zeroFood, missingFood],
  );
}
