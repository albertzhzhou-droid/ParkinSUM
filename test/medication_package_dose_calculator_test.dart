import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/usecases/medication_package_dose_calculator.dart';

void main() {
  const calculator = MedicationPackageDoseCalculator();

  MedicationProductPack product(List<MedicationIngredientStrength> strengths) {
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
      dosageForm: 'TABLET',
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
    },
  );

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
}
