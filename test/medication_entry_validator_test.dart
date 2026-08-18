import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

void main() {
  final validator = MedicationEntryValidator();

  group('MedicationEntryValidator — invalid free-text inputs', () {
    test('rejects a bare numeric "100"', () {
      final result = validator.validate(
        const RawMedicationEntry(freeText: '100'),
      );
      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(result.normalized, isNull);
      expect(result.issues.any((i) => i.code == 'BARE_NUMERIC_DOSE'), isTrue);
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
      final result = validator.validate(
        const RawMedicationEntry(strength: 100, unit: 'mg'),
      );
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(
        result.issues.any((i) => i.code == 'MISSING_ACTIVE_INGREDIENT'),
        isTrue,
      );
    });

    test('rejects ingredient+strength but no unit (no dose inference)', () {
      final result = validator.validate(
        const RawMedicationEntry(
          activeIngredient: 'levodopa',
          strength: 100,
          drugProductVariant: 'synthetic_demo_variant',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(result.issues.any((i) => i.code == 'MISSING_UNIT'), isTrue);
    });

    test('rejects when formulation/release_type is missing', () {
      final result = validator.validate(
        const RawMedicationEntry(
          activeIngredient: 'levodopa',
          drugProductVariant: 'synthetic_demo_variant',
          strength: 100,
          unit: 'mg',
          route: 'oral',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      expect(result.eligibleForRuleEvaluation, isFalse);
      expect(
        result.issues.any(
          (i) => i.code == 'MISSING_FORM' || i.code == 'MISSING_RELEASE_TYPE',
        ),
        isTrue,
      );
    });

    test('produces safe validation copy and no conflict result', () {
      final result = validator.validate(
        const RawMedicationEntry(freeText: '100'),
      );
      expect(
        result.safeUserCopy.toLowerCase(),
        contains('context is incomplete'),
      );
      expect(
        result.safeUserCopy.toLowerCase(),
        contains('does not provide medication dosing'),
      );
      // No banned advice copy may leak into the safe validation message.
      expect(findBannedSubstrings(result.safeUserCopy), isEmpty);
    });
  });

  group('MedicationEntryValidator — valid catalog-backed entry', () {
    test('accepts synthetic carbidopa/levodopa entry', () {
      final result = validator.validate(
        const RawMedicationEntry(
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
        ),
      );
      expect(result.validity, MedicationContextValidity.valid);
      expect(result.eligibleForRuleEvaluation, isTrue);
      final n = result.normalized!;
      expect(n.activeIngredients, containsAll(['carbidopa', 'levodopa']));
      expect(n.unit, 'mg');
      expect(n.releaseType, 'immediate');
      expect(n.limitationText.toLowerCase(), contains('not medical advice'));
    });
  });

  group('MedicationEntryValidator — governed metadata integrity', () {
    test(
      'rejects adversarial ingredient, route, form, and release mismatch',
      () {
        final result = validator.validate(
          _validEntry(
            metadata: _metadata(
              ingredients: const ['carbidopa', 'levodopa', 'entacapone'],
              route: 'transdermal',
              doseForm: 'patch',
              releaseType: 'extended',
            ),
          ),
        );

        expect(result.validity, MedicationContextValidity.invalid);
        expect(result.eligibleForRuleEvaluation, isFalse);
        expect(result.normalized, isNull);
        expect(
          result.issues.map((issue) => issue.code),
          containsAll(const [
            'METADATA_ACTIVE_INGREDIENT_MISMATCH',
            'METADATA_ROUTE_MISMATCH',
            'METADATA_FORM_MISMATCH',
            'METADATA_RELEASE_TYPE_MISMATCH',
          ]),
        );
      },
    );

    test('canonical equivalent metadata remains valid', () {
      final result = validator.validate(
        _validEntry(
          metadata: _metadata(
            ingredients: const [' Carbidopa / LEVODOPA '],
            route: ' Oral ',
            doseForm: 'tablet',
            releaseType: 'immediate-release',
          ),
        ),
      );

      expect(result.validity, MedicationContextValidity.valid);
      expect(result.eligibleForRuleEvaluation, isTrue);
    });

    test('rejects metadata bound to a different product or source', () {
      final result = validator.validate(
        _validEntry(
          metadata: _metadata(
            drugProductVariantId: 'synthetic:different-product',
            sourceDocId: 'synthetic:different-source',
            jurisdiction: 'CA',
          ),
        ),
      );

      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.normalized, isNull);
      expect(
        result.issues.map((issue) => issue.code),
        containsAll(const [
          'METADATA_DRUG_PRODUCT_VARIANT_MISMATCH',
          'METADATA_SOURCE_DOC_MISMATCH',
          'METADATA_JURISDICTION_MISMATCH',
        ]),
      );
    });

    test('rejects governed metadata whose product identity is unbound', () {
      final result = validator.validate(
        _validEntry(
          metadata: _metadata(
            drugProductVariantId: null,
            sourceDocId: 'unknown',
            jurisdiction: 'unspecified',
          ),
        ),
      );

      expect(result.validity, MedicationContextValidity.invalid);
      expect(result.normalized, isNull);
      expect(
        result.issues.map((issue) => issue.code),
        containsAll(const [
          'METADATA_DRUG_PRODUCT_VARIANT_UNBOUND',
          'METADATA_SOURCE_DOC_UNBOUND',
          'METADATA_JURISDICTION_UNBOUND',
        ]),
      );
    });

    test('missing or unknown governed metadata keeps conservative policy', () {
      final withoutMetadata = validator.validate(_validEntry());
      final unknownMetadata = validator.validate(
        _validEntry(
          metadata: _metadata(
            ingredients: const [],
            route: 'unknown',
            doseForm: 'unspecified',
            releaseType: 'unknown',
          ),
        ),
      );

      expect(withoutMetadata.validity, MedicationContextValidity.valid);
      expect(unknownMetadata.validity, MedicationContextValidity.valid);
    });

    test('rejects non-finite and out-of-range extraction confidence', () {
      for (final confidence in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -0.01,
        1.01,
      ]) {
        final result = validator.validate(
          _validEntry(extractionConfidence: confidence),
        );
        expect(result.validity, MedicationContextValidity.invalid);
        expect(result.normalized, isNull);
        expect(
          result.issues.map((issue) => issue.code),
          contains('INVALID_EXTRACTION_CONFIDENCE'),
        );
      }
    });

    test('rejects invalid nested metadata extraction confidence', () {
      final componentResult = validator.validate(
        _validEntry(metadata: _metadata(componentConfidence: 1.1)),
      );
      final sectionResult = validator.validate(
        _validEntry(metadata: _metadata(sectionConfidence: double.nan)),
      );

      for (final result in [componentResult, sectionResult]) {
        expect(result.validity, MedicationContextValidity.invalid);
        expect(result.normalized, isNull);
        expect(
          result.issues.map((issue) => issue.code),
          contains('INVALID_METADATA_EXTRACTION_CONFIDENCE'),
        );
      }
    });
  });
}

RawMedicationEntry _validEntry({
  MechanisticMedicationMetadata? metadata,
  double? extractionConfidence = 0.95,
}) => RawMedicationEntry(
  activeIngredients: const ['carbidopa', 'levodopa'],
  drugProductVariant: 'synthetic:carbidopa-levodopa-ir',
  strength: 100,
  unit: 'mg',
  form: 'tablet',
  route: 'oral',
  releaseType: 'immediate',
  jurisdiction: 'US',
  sourceDocId: 'synthetic:test',
  extractionConfidence: extractionConfidence,
  medicationMetadata: metadata,
);

MechanisticMedicationMetadata _metadata({
  List<String> ingredients = const ['carbidopa', 'levodopa'],
  String? drugProductVariantId = 'synthetic:carbidopa-levodopa-ir',
  String sourceDocId = 'synthetic:test',
  String jurisdiction = 'US',
  String route = 'oral',
  String doseForm = 'tablet',
  String releaseType = 'immediate',
  double? componentConfidence = 0.9,
  double? sectionConfidence,
}) => MechanisticMedicationMetadata(
  sourceSystem: 'synthetic',
  sourceDocId: sourceDocId,
  jurisdiction: jurisdiction,
  language: 'en',
  drugProductVariantId: drugProductVariantId,
  doseForm: doseForm,
  route: route,
  releaseType: releaseType,
  releaseTypeSource: releaseType == 'unknown'
      ? 'unknown'
      : 'structured_variant_metadata',
  components: ingredients
      .map(
        (ingredient) => MedicationComponent(
          ingredientName: ingredient,
          role: 'active',
          extractionConfidence: componentConfidence,
        ),
      )
      .toList(growable: false),
  labelSectionRefs: sectionConfidence == null
      ? const []
      : [
          LabelSectionRef(
            sourceSystem: 'synthetic',
            sourceDocId: 'synthetic:test',
            jurisdiction: 'US',
            language: 'en',
            sectionId: 'identity',
            sectionKey: 'identity',
            sectionTitle: 'Identity',
            extractionConfidence: sectionConfidence,
          ),
        ],
  sourceRefs: const ['synthetic:test'],
  limitationText: 'Synthetic metadata fixture.',
  metadataCompleteness: 'complete',
);
