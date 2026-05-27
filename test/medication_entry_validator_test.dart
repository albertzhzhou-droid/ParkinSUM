import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

void main() {
  final validator = MedicationEntryValidator();

  group('MedicationEntryValidator — invalid free-text inputs', () {
    test('rejects a bare numeric "100"', () {
      final result = validator.validate(const RawMedicationEntry(freeText: '100'));
      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(result.normalized, isNull);
      expect(
        result.issues.any((i) => i.code == 'BARE_NUMERIC_DOSE'),
        isTrue,
      );
    });

    test('rejects "100 tablets"', () {
      final result = validator.validate(
        const RawMedicationEntry(freeText: '100 tablets'),
      );
      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.eligibleForRuleEvaluation, isFalse);
    });

    test('rejects "one pill"', () {
      final result = validator.validate(
        const RawMedicationEntry(freeText: 'one pill'),
      );
      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.eligibleForRuleEvaluation, isFalse);
    });

    test('rejects "25/100" without unit', () {
      final result = validator.validate(
        const RawMedicationEntry(freeText: '25/100'),
      );
      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.eligibleForRuleEvaluation, isFalse);
    });

    test('rejects "levodopa 100" with no unit and no structured fields', () {
      final result = validator.validate(
        const RawMedicationEntry(freeText: 'levodopa 100'),
      );
      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.eligibleForRuleEvaluation, isFalse);
    });
  });

  group('MedicationEntryValidator — insufficient context', () {
    test('rejects strength+unit but no ingredient', () {
      final result = validator.validate(const RawMedicationEntry(
        strength: 100,
        unit: 'mg',
      ));
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(
        result.issues.any((i) => i.code == 'MISSING_ACTIVE_INGREDIENT'),
        isTrue,
      );
    });

    test('rejects ingredient+strength but no unit (no dose inference)', () {
      final result = validator.validate(const RawMedicationEntry(
        activeIngredient: 'levodopa',
        strength: 100,
        drugProductVariant: 'synthetic_demo_variant',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ));
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(result.issues.any((i) => i.code == 'MISSING_UNIT'), isTrue);
    });

    test('rejects when formulation/release_type is missing', () {
      final result = validator.validate(const RawMedicationEntry(
        activeIngredient: 'levodopa',
        drugProductVariant: 'synthetic_demo_variant',
        strength: 100,
        unit: 'mg',
        route: 'oral',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ));
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(
        result.issues.any((i) =>
            i.code == 'MISSING_FORM' || i.code == 'MISSING_RELEASE_TYPE'),
        isTrue,
      );
    });

    test('produces safe validation copy and no conflict result', () {
      final result = validator.validate(const RawMedicationEntry(freeText: '100'));
      expect(result.safeUserCopy.toLowerCase(),
          contains('context is incomplete'));
      expect(result.safeUserCopy.toLowerCase(),
          contains('does not provide medication dosing'));
      // No banned advice copy may leak into the safe validation message.
      expect(findBannedSubstrings(result.safeUserCopy), isEmpty);
    });
  });

  group('MedicationEntryValidator — valid catalog-backed entry', () {
    test('accepts synthetic carbidopa/levodopa entry', () {
      final result = validator.validate(const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:carbidopa-levodopa-25-100-ir-tablet',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo_label_carbidopa_levodopa',
        labelSection: 'dosage_and_administration',
        extractionConfidence: 0.95,
      ));
      expect(result.validity, MedicationContextValidity.valid);
      expect(result.eligibleForRuleEvaluation, isTrue);
      final n = result.normalized!;
      expect(n.activeIngredients, containsAll(['carbidopa', 'levodopa']));
      expect(n.unit, 'mg');
      expect(n.releaseType, 'immediate');
      expect(n.limitationText.toLowerCase(), contains('not medical advice'));
    });
  });
}
