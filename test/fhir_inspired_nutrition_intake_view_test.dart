import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

/// Phase γ / F2: the FHIR-inspired, PHI-free NutritionIntake view. Verifies the
/// mapping preserves missingness/provenance, deterministically serializes, and
/// — critically — emits NO patient-linkage keys (key-level scan, since the
/// `phi_policy` value intentionally names what is omitted).
void main() {
  final normalizer = MealCompositionNormalizer();
  const mapper = FhirInspiredNutritionIntakeMapper();

  // Forbidden FHIR patient-linkage / clinical KEYS (key-level, recursive).
  const forbiddenKeys = {
    'subject',
    'patient',
    'patient_id',
    'patientidentifier',
    'patient_identifier',
    'encounter',
    'practitioner',
    'careteam',
    'care_team',
    'diagnosis',
    'treatment',
    'recommendation',
    'clinicaldecisionsupport',
    'clinical_decision_support',
  };

  // String values that are allowed to contain safety/policy wording without
  // being scanned for "banned medical-advice phrases".
  const safetyCopyKeys = {
    'phi_policy',
    'safety_boundary',
    'not_advice_text',
    'conformance_status',
    'view_type',
  };

  void scanKeys(Object? node) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        expect(forbiddenKeys.contains(key), isFalse,
            reason:
                'forbidden patient-linkage/clinical key present: ${entry.key}');
        scanKeys(entry.value);
      }
    } else if (node is List) {
      for (final e in node) {
        scanKeys(e);
      }
    }
  }

  // Collect free-text string values, skipping known safety/policy fields, for
  // a banned-medical-advice-phrase scan.
  List<String> freeTextValues(Object? node) {
    final out = <String>[];
    void walk(Object? n) {
      if (n is Map) {
        for (final e in n.entries) {
          if (safetyCopyKeys.contains(e.key.toString())) continue;
          walk(e.value);
        }
      } else if (n is List) {
        for (final e in n) {
          walk(e);
        }
      } else if (n is String) {
        out.add(n);
      }
    }

    walk(node);
    return out;
  }

  MealComposition buildComposition({
    AminoAcidProfile? aa,
    double? protein = 26,
    double? calories = 200,
    double? portion = 150,
  }) {
    return normalizer.normalize(
      mealId: 'comp_demo_meal_1',
      declaredPhysicalForm: MealPhysicalForm.solid,
      components: [
        FoodComponent(
          id: 'food.chicken.synth',
          name: 'chicken breast (synthetic demo)',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: protein,
          fatGrams: 5,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: calories,
          portionGrams: portion,
          sourceDocId: 'synthetic:usda_fdc_demo',
          aminoAcidProfile: aa,
        ),
      ],
    );
  }

  AminoAcidProfile analyticalProfile() => const AminoAcidProfile(
        leucine: 2.1,
        isoleucine: 1.2,
        valine: 1.3,
        phenylalanine: 1.0,
        tyrosine: 0.9,
        tryptophan: 0.3,
        basis: 'per_serving',
        nutrientIds: ['504', '503', '510', '508', '509', '501'],
        sourceRefs: ['src.fdc.api.amino_acid_fields'],
        fdcDataType: 'Foundation',
        derivations: {
          'leucine': NutrientDerivation(
              derivationCode: 'A', derivationDescription: 'Analytical'),
        },
      );

  test('1. maps meal composition into the FHIR-inspired view', () {
    final view = mapper.fromMealComposition(
        buildComposition(aa: analyticalProfile()),
        demoMealId: 'demo-meal-1',
        relativeTimeMinutes: 30);
    expect(view.foodComponents, hasLength(1));
    expect(view.foodComponents.single.foodName, contains('chicken'));
    expect(view.foodComponents.single.amount, 150);
    expect(view.foodComponents.single.amountUnit, 'g');
    expect(view.demoMealId, 'demo-meal-1');
    expect(view.relativeTimeMinutes, 30);
  });

  test('2. omits subject/patient/encounter and asserts phi_policy (key-level)',
      () {
    final view =
        mapper.fromMealComposition(buildComposition(aa: analyticalProfile()));
    final json = view.toJson();
    scanKeys(json); // recursive: no forbidden patient-linkage/clinical keys
    expect(json['phi_policy'], 'subject_omitted_no_phi');
    // No top-level patient-linkage keys.
    expect(json.containsKey('subject'), isFalse);
    expect(json.containsKey('patient'), isFalse);
    expect(json.containsKey('encounter'), isFalse);
  });

  test('3. preserves missing nutrient fields (null stays null)', () {
    final view = mapper.fromMealComposition(
        buildComposition(aa: null, calories: null, portion: null));
    expect(view.nutrientSummary.energyKcal, isNull);
    expect(view.nutrientSummary.missingness['energy_kcal'], isTrue);
    final c = view.foodComponents.single;
    expect(c.amount, isNull);
    expect(c.missingFields, contains('calories'));
    expect(c.missingFields, contains('portion_grams'));
  });

  test('4. preserves amino-acid data mode + confidence tier', () {
    final view =
        mapper.fromMealComposition(buildComposition(aa: analyticalProfile()));
    expect(view.aminoAcidSummary.aminoAcidDataMode, 'actualAminoAcidFields');
    expect(view.aminoAcidSummary.aminoAcidConfidenceTier, 'analytical');
    expect(view.aminoAcidSummary.competingLnaaGrams, isNotNull);
    // No amino-acid fields → mode 'none', tier null (missing ≠ confident).
    final noAa = mapper.fromMealComposition(buildComposition(aa: null));
    expect(noAa.aminoAcidSummary.aminoAcidDataMode, 'none');
    expect(noAa.aminoAcidSummary.aminoAcidConfidenceTier, isNull);
    expect(noAa.aminoAcidSummary.competingLnaaGrams, isNull);
  });

  test('5. preserves sourceRefs + derivation/provenance', () {
    final view =
        mapper.fromMealComposition(buildComposition(aa: analyticalProfile()));
    expect(view.sourceRefs, contains('src.fdc.api.amino_acid_fields'));
    expect(view.aminoAcidSummary.aminoAcidNutrientIds, contains('504'));
    expect(view.aminoAcidSummary.fdcDataType, 'Foundation');
    expect(view.provenanceSummary, contains('amino_acid_data_mode='));
  });

  test('6. JSON output is deterministic', () {
    final comp = buildComposition(aa: analyticalProfile());
    final a =
        jsonEncode(mapper.fromMealComposition(comp, demoMealId: 'm').toJson());
    final b =
        jsonEncode(mapper.fromMealComposition(comp, demoMealId: 'm').toJson());
    expect(a, b);
  });

  test('7. safety copy is non-prescriptive (banned-phrase scan, skip policy)',
      () {
    final view =
        mapper.fromMealComposition(buildComposition(aa: analyticalProfile()));
    final texts = freeTextValues(view.toJson());
    for (final t in texts) {
      expect(findBannedSubstrings(t), isEmpty,
          reason: 'banned medical-advice phrase in free text: "$t"');
    }
  });

  test('8. does not claim FHIR conformance', () {
    final json = mapper.fromMealComposition(buildComposition()).toJson();
    expect(json['conformance_status'], 'inspired_not_conformant');
    expect(json['view_type'], 'fhir_inspired_nutrition_intake');
  });

  test('9. does not claim clinical calibration', () {
    final json = mapper.fromMealComposition(buildComposition()).toJson();
    expect(json['not_clinically_calibrated'], isTrue);
  });

  test('10. emits no banned medical-advice phrases anywhere in free text', () {
    // Stronger: scan the full serialized JSON for banned phrases (these phrases
    // do not appear in the allowed safety-copy fields either).
    final encoded = jsonEncode(mapper
        .fromMealComposition(buildComposition(aa: analyticalProfile()))
        .toJson());
    expect(findBannedSubstrings(encoded), isEmpty);
  });

  test('reuses shared safety copy', () {
    final view = mapper.fromMealComposition(buildComposition());
    expect(view.notAdviceText, RuleExplanation.defaultNotAdvice);
    expect(view.safetyBoundary, RuleExplanation.defaultSafetyBoundary);
  });

  test('replay-style composition maps to a PHI-free view (Task 6)', () {
    // A composition shaped like the replay runner builds (multi-component,
    // mixed form). Demonstrates exportability without touching the runner.
    final comp = normalizer.normalize(
      mealId: 'comp_s11_mixed',
      components: const [
        FoodComponent(
          id: 'food.oatmeal.synth',
          name: 'oatmeal (synthetic demo)',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 5,
          fatGrams: 3,
          fiberGrams: 4,
          carbohydrateGrams: 27,
          calories: 158,
          portionGrams: 200,
          sourceDocId: 'synthetic:demo_food',
        ),
        FoodComponent(
          id: 'food.water.synth',
          name: 'water (synthetic demo)',
          physicalForm: MealPhysicalForm.liquid,
          proteinGrams: 0,
          fatGrams: 0,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 0,
          portionGrams: 250,
          sourceDocId: 'synthetic:demo_food',
        ),
      ],
    );
    final json = mapper.fromMealComposition(comp).toJson();
    scanKeys(json);
    expect((json['food_components'] as List), hasLength(2));
    expect(json['phi_policy'], 'subject_omitted_no_phi');
    expect(json['conformance_status'], 'inspired_not_conformant');
  });
}
