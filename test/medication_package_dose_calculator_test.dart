import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/usecases/medication_package_dose_calculator.dart';

void main() {
  const calculator = MedicationPackageDoseCalculator();

  MedicationProductPack product(
    List<MedicationIngredientStrength> strengths, {
    String dosageForm = 'TABLET',
  }) {
    return MedicationProductPack(
      id: 'pack',
      genericName: 'carbidopa and levodopa',
      brandName: null,
      labelerName: 'Example labeler',
      jurisdiction: 'US',
      identifiers: const <MedicationProductIdentifier>[
        MedicationProductIdentifier(
          system: MedicationIdentifierSystem.ndcPackage,
          level: MedicationIdentifierLevel.package,
          value: '00000-000-01',
        ),
      ],
      ingredients: strengths,
      dosageForm: dosageForm,
      routes: const <String>['ORAL'],
      packageDescription: '100 TABLET in 1 BOTTLE',
      marketingStartDate: null,
      marketingEndDate: null,
      sourceSystem: 'OPENFDA_NDC',
      sourceUrl: 'https://api.fda.gov/drug/ndc.json',
      retrievedAt: null,
    );
  }

  test(
    'uses levodopa as the explicit analysis basis for combination packs',
    () {
      final pack = product(const <MedicationIngredientStrength>[
        MedicationIngredientStrength(
          ingredientName: 'CARBIDOPA',
          numeratorValue: 25,
          numeratorUnit: 'mg',
          denominatorValue: 1,
          denominatorUnit: null,
          rawStrength: '25 mg/1',
        ),
        MedicationIngredientStrength(
          ingredientName: 'LEVODOPA',
          numeratorValue: 100,
          numeratorUnit: 'mg',
          denominatorValue: 1,
          denominatorUnit: null,
          rawStrength: '100 mg/1',
        ),
      ]);

      final dose = calculator.fromConfirmedQuantity(pack, 0.5)!;
      expect(dose.ingredientName, 'LEVODOPA');
      expect(dose.dosageNote, '50 mg');
      expect(dose.packageUnitQuantity, 0.5);
      expect(dose.packageUnitLabel, 'TABLET');
      expect(dose.derivation.sourceRawStrength, '100 mg/1');
      expect(dose.derivation.denominatorDisposition, 'source_numeric_one');
      expect(dose.derivation.resultValue, 50);
    },
  );

  test('captures an explicit source-linked derivation for implicit tablet', () {
    final pack = product(const <MedicationIngredientStrength>[
      MedicationIngredientStrength(
        ingredientName: 'LEVODOPA',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: null,
        denominatorUnit: null,
        rawStrength: '100 mg',
      ),
    ]);
    final dose = calculator.fromConfirmedQuantity(pack, 0.5)!;
    final selection = MedicationProductSelection.fromPack(pack)
        .withConfirmedQuantity(
          doseBasisIngredient: dose.ingredientName,
          unitQuantity: dose.packageUnitQuantity,
          unitLabel: dose.packageUnitLabel,
          doseDerivation: dose.derivation,
        );
    final restored = MedicationProductSelection.fromJson(selection.toJson())!;

    expect(dose.dosageNote, '50 mg');
    expect(
      dose.derivation.denominatorDisposition,
      'assumed_one_discrete_dosage_unit',
    );
    expect(restored.toJson(), selection.toJson());
    expect(restored.sourceSystem, 'OPENFDA_NDC');
    expect(restored.sourceUrl, 'https://api.fda.gov/drug/ndc.json');
    expect(restored.doseDerivation?.sourceRawStrength, '100 mg');
    expect(restored.doseDerivation?.packageUnitQuantity, 0.5);
    expect(restored.doseDerivation?.resultValue, 50);
  });

  test('holds missing or mismatched liquid and dosage-unit denominators', () {
    MedicationIngredientStrength ingredient({
      double? denominatorValue,
      String? denominatorUnit,
    }) => MedicationIngredientStrength(
      ingredientName: 'LEVODOPA',
      numeratorValue: 100,
      numeratorUnit: 'mg',
      denominatorValue: denominatorValue,
      denominatorUnit: denominatorUnit,
      rawStrength:
          '100 mg${denominatorUnit == null ? '' : '/$denominatorUnit'}',
    );

    expect(
      calculator.fromConfirmedQuantity(
        product([ingredient()], dosageForm: 'ORAL SOLUTION'),
        1,
      ),
      isNull,
    );
    expect(
      calculator.fromConfirmedQuantity(
        product([ingredient(denominatorValue: 1)], dosageForm: 'ORAL SOLUTION'),
        1,
      ),
      isNull,
    );
    expect(
      calculator.fromConfirmedQuantity(
        product([
          ingredient(denominatorValue: 1, denominatorUnit: 'mL'),
        ], dosageForm: 'ORAL SOLUTION'),
        1,
      ),
      isNull,
    );
    expect(
      calculator.fromConfirmedQuantity(
        product([ingredient(denominatorValue: 1, denominatorUnit: 'capsule')]),
        1,
      ),
      isNull,
    );
    expect(
      calculator
          .fromConfirmedQuantity(
            product([
              ingredient(denominatorValue: 1, denominatorUnit: 'tablet'),
            ]),
            1,
          )
          ?.dosageNote,
      '100 mg',
    );
  });

  test('does not choose among unrelated multi-ingredient products', () {
    final pack = product(const <MedicationIngredientStrength>[
      MedicationIngredientStrength(
        ingredientName: 'A',
        numeratorValue: 10,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '10 mg/1',
      ),
      MedicationIngredientStrength(
        ingredientName: 'B',
        numeratorValue: 20,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '20 mg/1',
      ),
    ]);
    expect(calculator.fromConfirmedQuantity(pack, 1), isNull);
  });

  test('rejects invalid quantities instead of clamping silently', () {
    final pack = product(const <MedicationIngredientStrength>[
      MedicationIngredientStrength(
        ingredientName: 'LEVODOPA',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '100 mg/1',
      ),
    ]);
    expect(calculator.fromConfirmedQuantity(pack, 0), isNull);
    expect(calculator.fromConfirmedQuantity(pack, double.nan), isNull);
    expect(calculator.fromConfirmedQuantity(pack, 11), isNull);
  });

  test('rejects invalid strength metadata and multiplication overflow', () {
    MedicationProductPack invalid(double strength) => product([
      MedicationIngredientStrength(
        ingredientName: 'LEVODOPA',
        numeratorValue: strength,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '$strength mg/1',
      ),
    ]);

    expect(calculator.fromConfirmedQuantity(invalid(-100), 1), isNull);
    expect(calculator.fromConfirmedQuantity(invalid(double.nan), 1), isNull);
    expect(
      calculator.fromConfirmedQuantity(invalid(double.infinity), 1),
      isNull,
    );
    expect(
      calculator.fromConfirmedQuantity(invalid(double.maxFinite), 10),
      isNull,
    );
  });
}
