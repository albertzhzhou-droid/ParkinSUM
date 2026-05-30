import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P1 — the two local FHIR-inspired views (NutritionIntake + MedicationKnowledge)
/// must stay symmetric and safe: identical common envelope fields, the same
/// shared safety copy, an explicit non-conformance marker, and no
/// patient-care/clinical keys. Uses the shared no-PHI helper so both views are
/// held to identical key-level rules.
void main() {
  // The 8 common envelope fields both views must expose.
  const commonKeys = {
    'view_type',
    'conformance_status',
    'phi_policy',
    'source_refs',
    'provenance_summary',
    'not_clinically_calibrated',
    'not_advice_text',
    'safety_boundary',
  };

  Map<String, dynamic> nutritionJson() {
    final normalizer = MealCompositionNormalizer();
    const mapper = FhirInspiredNutritionIntakeMapper();
    final comp = normalizer.normalize(
      mealId: 'comp_demo',
      declaredPhysicalForm: MealPhysicalForm.solid,
      components: const [
        FoodComponent(
          id: 'food.demo.synth',
          name: 'demo food (synthetic)',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 10,
          fatGrams: 5,
          fiberGrams: 2,
          carbohydrateGrams: 20,
          calories: 180,
          portionGrams: 150,
          sourceDocId: 'synthetic:demo_food',
        ),
      ],
    );
    return mapper.fromMealComposition(comp, demoMealId: 'demo-meal').toJson();
  }

  Map<String, dynamic> medicationJson() {
    const mapper = FhirInspiredMedicationKnowledgeMapper();
    const meta = MechanisticMedicationMetadata(
      sourceSystem: 'DailyMed',
      sourceDocId: 'spl:demo',
      jurisdiction: 'US',
      language: 'en',
      doseForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      releaseTypeSource: 'structured_variant_metadata',
      components: [
        MedicationComponent(ingredientName: 'levodopa', role: 'active'),
      ],
      labelSectionRefs: [],
      sourceRefs: ['src.spl.identity'],
      limitationText: 'Provenance only.',
      metadataCompleteness: 'partial',
    );
    return mapper
        .fromMechanisticMetadata(meta, demoDrugProductId: 'demo-prod')
        .toJson();
  }

  test('both views expose the 8 common envelope fields', () {
    for (final json in [nutritionJson(), medicationJson()]) {
      for (final k in commonKeys) {
        expect(json.containsKey(k), isTrue,
            reason: 'missing common envelope field: $k');
      }
    }
  });

  test('both views pass the shared recursive no-PHI key scan', () {
    scanNoPhiKeys(nutritionJson());
    scanNoPhiKeys(medicationJson());
  });

  test('both views share the same safety-boundary + not-advice copy', () {
    final n = nutritionJson();
    final m = medicationJson();
    expect(n['safety_boundary'], RuleExplanation.defaultSafetyBoundary);
    expect(m['safety_boundary'], RuleExplanation.defaultSafetyBoundary);
    expect(n['not_advice_text'], RuleExplanation.defaultNotAdvice);
    expect(m['not_advice_text'], RuleExplanation.defaultNotAdvice);
    expect(n['safety_boundary'], m['safety_boundary']);
    expect(n['not_advice_text'], m['not_advice_text']);
  });

  test('both views declare inspired_not_conformant + not clinically calibrated',
      () {
    for (final json in [nutritionJson(), medicationJson()]) {
      expect(json['conformance_status'], 'inspired_not_conformant');
      expect(json['not_clinically_calibrated'], isTrue);
    }
  });

  test('neither view emits banned medical-advice phrases', () {
    for (final json in [nutritionJson(), medicationJson()]) {
      for (final t in collectFreeTextValues(json)) {
        expect(findBannedSubstrings(t), isEmpty,
            reason: 'banned phrase in free text: "$t"');
      }
      expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
    }
  });

  test('both views serialize deterministically', () {
    expect(jsonEncode(nutritionJson()), jsonEncode(nutritionJson()));
    expect(jsonEncode(medicationJson()), jsonEncode(medicationJson()));
  });
}
