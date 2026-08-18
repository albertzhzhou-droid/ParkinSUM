import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_context_metadata_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

/// Phase γ / A1-A2: bridges CDSS drug metadata into the mechanistic medication
/// context. These tests prove the BRIDGE (not parser extraction): section refs,
/// combination components, and release-type evidence reach the normalized
/// context / absorption model / per-event trace — and that product strength
/// never becomes a fabricated intake dose.
void main() {
  final adapter = MedicationContextMetadataAdapter();
  final validator = MedicationEntryValidator();

  DrugProductVariantMetadata variant({
    List<String> ingredients = const ['carbidopa', 'levodopa'],
    String releaseType = 'immediate',
    double? strength = 100,
    String? unit = 'mg',
    List<String> refs = const ['src.dailymed.sinemet.label'],
  }) => DrugProductVariantMetadata(
    drugProductVariantId: 'v1',
    sourceSystem: 'DailyMed',
    jurisdiction: 'US',
    language: 'en',
    genericName: 'carbidopa/levodopa',
    brandName: null,
    activeIngredients: ingredients,
    strengthValue: strength,
    strengthUnit: unit,
    doseForm: 'tablet',
    route: 'oral',
    releaseType: releaseType,
    productIdentifier: 'NDC-0000',
    labelSection: 'dosage',
    translationStatus: ReferenceTranslationStatus.notTranslation,
    extractionConfidence: 0.9,
    sourceRefs: refs,
    limitationText: 'educational',
  );

  DrugLabelSectionRecord section() => const DrugLabelSectionRecord(
    sectionId: 'sec-1',
    drugProductVariantId: 'v1',
    sourceDocId: 'spl:demo',
    sectionKey: 'dosage_and_administration',
    sectionTitle: 'Dosage and Administration',
    sectionText: 'Synthetic demo section text.',
  );

  test('cdss drug metadata bridge preserves label section refs', () {
    final m = adapter.fromCdssMetadata(
      variant: variant(),
      sections: [section()],
      sourceDocVersion: 'v1.0',
    );
    expect(m.labelSectionRefs, hasLength(1));
    expect(m.labelSectionRefs.single.sectionKey, 'dosage_and_administration');
    expect(m.labelSectionRefs.single.sourceDocVersion, 'v1.0');
    expect(m.hasLabelSectionProvenance, isTrue);
  });

  test('combination product preserves carbidopa and levodopa components', () {
    final m = adapter.fromCdssMetadata(variant: variant());
    expect(
      m.components.map((c) => c.ingredientName),
      containsAll(['carbidopa', 'levodopa']),
    );
    expect(m.levodopaComponent, isNotNull);
    expect(m.levodopaComponent!.role, 'active');
    final carbidopa = m.components.firstWhere(
      (c) => c.ingredientName == 'carbidopa',
    );
    expect(carbidopa.role, 'decarboxylase_inhibitor');
    expect(carbidopa.isLevodopa, isFalse); // preserved but not levodopa
  });

  test('combination per-component strength is missing, not fabricated', () {
    final m = adapter.fromCdssMetadata(variant: variant());
    // Single product strength only → no per-component split is invented.
    for (final c in m.components) {
      expect(c.strengthValue, isNull);
      expect(c.hasMissingStrength, isTrue);
    }
    expect(m.missingFields, contains('component_strength_unit'));
  });

  test(
    'single-ingredient product carries the product strength on its component',
    () {
      final m = adapter.fromCdssMetadata(
        variant: variant(ingredients: ['levodopa'], strength: 100, unit: 'mg'),
      );
      expect(m.components.single.strengthValue, 100);
      expect(m.components.single.strengthUnit, 'mg');
    },
  );

  test('release type source is structured when known, unknown otherwise', () {
    final known = adapter.fromCdssMetadata(variant: variant());
    expect(known.releaseTypeSource, 'structured_variant_metadata');
    final unknown = adapter.fromCdssMetadata(
      variant: variant(releaseType: 'unknown'),
    );
    expect(unknown.releaseTypeSource, 'unknown');
    expect(unknown.missingFields, contains('release_type'));
  });

  test('missing section provenance lowers completeness, not a fake trace', () {
    final withSec = adapter.fromCdssMetadata(
      variant: variant(),
      sections: [section()],
    );
    final without = adapter.fromCdssMetadata(variant: variant());
    expect(without.hasLabelSectionProvenance, isFalse);
    expect(without.missingFields, contains('label_section_provenance'));
    // No-section grade is not stronger than the with-section grade.
    expect(withSec.metadataCompleteness == 'complete', isTrue);
    expect(without.metadataCompleteness == 'complete', isFalse);
  });

  test(
    'normalized context carries release type + components from metadata',
    () {
      final m = adapter.fromCdssMetadata(
        variant: variant(),
        sections: [section()],
      );
      final result = validator.validate(
        RawMedicationEntry(
          activeIngredients: const ['carbidopa', 'levodopa'],
          drugProductVariant: 'v1',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: m.sourceDocId,
          medicationMetadata: m,
        ),
      );
      expect(result.validity, MedicationContextValidity.valid);
      expect(result.normalized!.metadata, isNotNull);
      expect(result.normalized!.metadata!.releaseType, 'immediate');
      expect(result.normalized!.metadata!.labelSectionRefs, isNotEmpty);
    },
  );

  test('unitless user dosage stays insufficient despite product strength', () {
    // The metadata carries a product strength (100 mg) but the user entered a
    // unitless free-text dose. Product strength must NOT fill the intake dose.
    final m = adapter.fromCdssMetadata(variant: variant());
    final result = validator.validate(
      RawMedicationEntry(
        freeText: 'levodopa 100', // unitless
        activeIngredients: const ['carbidopa', 'levodopa'],
        drugProductVariant: 'v1',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: m.sourceDocId,
        medicationMetadata: m, // rich product strength attached
      ),
    );
    expect(result.validity, isNot(MedicationContextValidity.valid));
    expect(result.normalized, isNull); // no dose fabricated from metadata
  });

  test('contradictory product metadata cannot reach the IR engine', () {
    final m = adapter.fromCdssMetadata(
      variant: variant(
        ingredients: const ['carbidopa', 'levodopa', 'entacapone'],
        releaseType: 'extended',
      ),
    );
    final validation = validator.validate(
      RawMedicationEntry(
        activeIngredients: const ['carbidopa', 'levodopa'],
        drugProductVariant: 'v1',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: m.sourceDocId,
        medicationMetadata: m,
      ),
    );
    expect(validation.validity, MedicationContextValidity.invalid);
    expect(validation.normalized, isNull);
    expect(
      validation.issues.map((issue) => issue.code),
      containsAll(const [
        'METADATA_ACTIVE_INGREDIENT_MISMATCH',
        'METADATA_RELEASE_TYPE_MISMATCH',
      ]),
    );

    final now = DateTime.utc(2026, 1, 1, 8);
    final composition = MealCompositionNormalizer().normalize(
      mealId: 'c',
      components: const [
        FoodComponent(
          id: 'food',
          name: 'synthetic food',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 10,
          fatGrams: 2,
          fiberGrams: 2,
          carbohydrateGrams: 20,
          calories: 150,
          portionGrams: 150,
          sourceDocId: 'synthetic:test',
        ),
      ],
    );
    final context = TimeAxisBuilder().build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: now.add(const Duration(minutes: 30)),
          medicationContext: validation,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'meal',
          startedAt: now,
          compositionId: composition.id,
        ),
      ],
    );
    final result = MechanisticConflictEngine().evaluate(
      context: context,
      mealCompositionsById: {composition.id: composition},
    );
    expect(result.hasModeledOutput, isFalse);
    expect(result.absorptionOpportunityWindow, isNull);
    expect(result.toJson()['interaction_score'], isNull);
  });

  group('absorption uses source-backed release type', () {
    final absorption = LevodopaAbsorptionOpportunityModel();

    MedicationTimelineEvent med(String releaseType, {required int minute}) {
      final v = validator.validate(
        RawMedicationEntry(
          activeIngredients: const ['carbidopa', 'levodopa'],
          drugProductVariant: 'v1',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: releaseType,
          jurisdiction: 'US',
          sourceDocId: 'spl:demo',
        ),
      );
      return MedicationTimelineEvent(
        id: 'm',
        minute: minute,
        context: v.normalized!,
      );
    }

    test('generic ER release abstains from the IR-only model', () {
      final er = absorption.build(medication: med('extended', minute: 60));
      expect(er.modelApplicable, isFalse);
      expect(er.window.durationMinutes, 0);
      expect(er.opennessProfile, isEmpty);
    });

    test('unknown release type is explicitly not model-applicable', () {
      final unknown = absorption.build(medication: med('unknown', minute: 60));
      expect(unknown.modelApplicable, isFalse);
      expect(unknown.window.durationMinutes, 0);
      expect(unknown.opennessProfile, isEmpty);
      expect(
        unknown.applicabilityReasons,
        contains('mechanistic_applicability.release_type_not_supported'),
      );
    });
  });

  test('per-event trace carries medication section provenance', () {
    final normalizer = MealCompositionNormalizer();
    final builder = TimeAxisBuilder();
    final engine = MechanisticConflictEngine();
    final m = adapter.fromCdssMetadata(
      variant: variant(),
      sections: [section()],
      sourceDocVersion: 'v1.0',
    );
    final v = validator.validate(
      RawMedicationEntry(
        activeIngredients: const ['carbidopa', 'levodopa'],
        drugProductVariant: 'v1',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: m.sourceDocId,
        medicationMetadata: m,
      ),
    );
    final now = DateTime.utc(2026, 1, 1, 8);
    final comp = normalizer.normalize(
      mealId: 'c',
      components: const [
        FoodComponent(
          id: 'p',
          name: 'protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 30,
          fatGrams: 5,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 180,
          sourceDocId: 'synthetic',
        ),
      ],
    );
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: now.add(const Duration(minutes: 30)),
          medicationContext: v,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'meal',
          startedAt: now,
          compositionId: comp.id,
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    );
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {comp.id: comp},
    );
    expect(r.perEventTraces, isNotEmpty);
    final t = r.perEventTraces.first;
    expect(t.levodopaComponentPresent, isTrue);
    expect(t.combinationComponentCount, 2);
    expect(t.labelSectionRefCount, 1);
    expect(t.releaseTypeSource, 'structured_variant_metadata');
    expect(t.medicationSourceSystem, 'DailyMed');
    expect(t.doseForm, 'tablet');
  });
}
