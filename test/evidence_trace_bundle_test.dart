import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/evidence_trace_bundle.dart';
import 'package:parkinsum_companion/domain/entities/fhir_inspired_medication_knowledge_view.dart';
import 'package:parkinsum_companion/domain/entities/fhir_inspired_nutrition_intake_view.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_trace_bundle_builder.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P3 — the local EvidenceTraceBundle pairs the two PHI-free views. It is a
/// ParkinSUM-local artifact, explicitly NOT a FHIR Bundle (no resourceType, no
/// Bundle, no patient/subject/encounter). Verifies sourceRefs union, missingness
/// preservation, safety boundary, determinism, and recursive key-level no-PHI.
void main() {
  const builder = EvidenceTraceBundleBuilder();
  final normalizer = MealCompositionNormalizer();

  // Bundle-specific forbidden keys: nothing may claim FHIR-Bundle shape.
  const extraForbidden = {'resourcetype', 'bundle', 'entry', 'fullurl'};

  FhirInspiredNutritionIntakeView nutritionView() {
    const mapper = FhirInspiredNutritionIntakeMapper();
    final comp = normalizer.normalize(
      mealId: 'comp_demo',
      declaredPhysicalForm: MealPhysicalForm.solid,
      components: const [
        FoodComponent(
          id: 'food.demo.synth',
          name: 'demo food (synthetic)',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 12,
          fatGrams: 4,
          fiberGrams: 3,
          carbohydrateGrams: 18,
          calories: 170,
          portionGrams: 140,
          sourceDocId: 'synthetic:usda_fdc_demo',
        ),
      ],
    );
    return mapper.fromMealComposition(comp, demoMealId: 'demo-meal');
  }

  FhirInspiredMedicationKnowledgeView medicationView() {
    const mapper = FhirInspiredMedicationKnowledgeMapper();
    const meta = MechanisticMedicationMetadata(
      sourceSystem: 'DailyMed',
      sourceDocId: 'spl:carbidopa-levodopa-demo',
      sourceDocVersion: '3',
      jurisdiction: 'US',
      language: 'en',
      doseForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      releaseTypeSource: 'structured_variant_metadata',
      components: [
        MedicationComponent(
            ingredientName: 'carbidopa', role: 'decarboxylase_inhibitor'),
        MedicationComponent(ingredientName: 'levodopa', role: 'active'),
      ],
      labelSectionRefs: [
        LabelSectionRef(
          sourceSystem: 'DailyMed',
          sourceDocId: 'spl:carbidopa-levodopa-demo',
          jurisdiction: 'US',
          language: 'en',
          sectionId: '34068-7',
          sectionKey: 'dosage_and_administration',
          sectionTitle: 'Dosage and Administration',
          sourceRefs: ['src.spl.section'],
        ),
      ],
      sourceRefs: ['src.spl.identity'],
      limitationText: 'Provenance only.',
      metadataCompleteness: 'adequate',
    );
    return mapper.fromMechanisticMetadata(meta, demoDrugProductId: 'demo-prod');
  }

  test('builds a bundle from both inspired views', () {
    final b = builder.build(
      bundleId: 'bundle-1',
      createdAt: '2026-01-01',
      nutritionView: nutritionView(),
      medicationKnowledgeView: medicationView(),
    );
    expect(b.nutritionView, isNotNull);
    expect(b.medicationKnowledgeView, isNotNull);
    final json = b.toJson();
    expect(json['bundle_type'], 'parkinsum_local_evidence_trace_bundle');
    expect(json['nutrition_view'], isNotNull);
    expect(json['medication_knowledge_view'], isNotNull);
  });

  test('preserves sourceRefs from both sides (unioned, sorted)', () {
    final b = builder.build(
      bundleId: 'bundle-1',
      createdAt: '2026-01-01',
      nutritionView: nutritionView(),
      medicationKnowledgeView: medicationView(),
    );
    // Medication side contributes spl refs + the LOINC source ref (from P2).
    expect(b.sourceRefs, contains('src.spl.identity'));
    expect(b.sourceRefs, contains('src.spl.section'));
    expect(b.sourceRefs, contains('src.fda.spl.standard'));
    final sorted = [...b.sourceRefs]..sort();
    expect(b.sourceRefs, sorted); // deterministic order
  });

  test('preserves a missingness summary from both sides', () {
    final b = builder.build(
      bundleId: 'bundle-1',
      createdAt: '2026-01-01',
      nutritionView: nutritionView(),
      medicationKnowledgeView: medicationView(),
    );
    final m = b.missingnessSummary;
    expect(m['nutrition_view_present'], isTrue);
    expect(m['medication_view_present'], isTrue);
    expect(m.containsKey('nutrition_missing_fields'), isTrue);
    expect(m['medication_metadata_completeness'], 'adequate');
    expect(m['medication_label_section_ref_count'], 1);
  });

  test('preserves the shared safety boundary + not-advice copy', () {
    final b = builder.build(bundleId: 'b', createdAt: 'x');
    expect(b.safetyBoundary, RuleExplanation.defaultSafetyBoundary);
    expect(b.notAdviceText, RuleExplanation.defaultNotAdvice);
    expect(b.notClinicallyCalibrated, isTrue);
  });

  test('JSON is deterministic', () {
    EvidenceTraceBundle make() => builder.build(
          bundleId: 'bundle-1',
          createdAt: '2026-01-01',
          nutritionView: nutritionView(),
          medicationKnowledgeView: medicationView(),
        );
    expect(jsonEncode(make().toJson()), jsonEncode(make().toJson()));
  });

  test('recursive key-level no-PHI scan passes (incl. no FHIR-Bundle keys)',
      () {
    final json = builder
        .build(
          bundleId: 'bundle-1',
          createdAt: '2026-01-01',
          nutritionView: nutritionView(),
          medicationKnowledgeView: medicationView(),
        )
        .toJson();
    scanNoPhiKeys(json, extraForbiddenKeys: extraForbidden);
  });

  test('does not claim FHIR Bundle conformance', () {
    final json = builder.build(bundleId: 'b', createdAt: 'x').toJson();
    expect(json['conformance_status'], 'local_not_fhir_bundle');
    expect(json['phi_policy'], 'no_patient_no_subject_no_encounter');
    expect(json.containsKey('resourceType'), isFalse);
    final encoded = jsonEncode(json);
    expect(encoded.contains('"resourceType"'), isFalse);
  });

  test('does not contain medical-advice phrasing', () {
    final json = builder
        .build(
          bundleId: 'bundle-1',
          createdAt: '2026-01-01',
          nutritionView: nutritionView(),
          medicationKnowledgeView: medicationView(),
        )
        .toJson();
    for (final t in collectFreeTextValues(json)) {
      expect(findBannedSubstrings(t), isEmpty,
          reason: 'banned phrase in free text: "$t"');
    }
    expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
  });

  test('builds with either side null (partial pairing recorded, not faked)',
      () {
    final medOnly = builder.build(
      bundleId: 'b',
      createdAt: 'x',
      medicationKnowledgeView: medicationView(),
    );
    expect(medOnly.nutritionView, isNull);
    expect(medOnly.missingnessSummary['nutrition_view_present'], isFalse);
    scanNoPhiKeys(medOnly.toJson(), extraForbiddenKeys: extraForbidden);
  });

  // Task 6 (optional) — a replay-style trace summary attaches without modifying
  // the replay runner.
  test('replay-style trace summary maps into the bundle', () {
    final b = builder.build(
      bundleId: 'replay-s39',
      createdAt: '2026-01-01',
      nutritionView: nutritionView(),
      medicationKnowledgeView: medicationView(),
      mechanisticTraceSummary: const MechanisticTraceSummary(
        severityBand: 'moderate',
        confidenceBand: 'medium',
        rankerUsed: 'mechanistic_primary_window_sampled',
        replayScenarioId: 's39_spl_ir_section_provenance',
        medicationMetadataCompleteness: 'adequate',
      ),
    );
    final json = b.toJson();
    final ts = json['mechanistic_trace_summary'] as Map;
    expect(ts['replay_scenario_id'], 's39_spl_ir_section_provenance');
    expect(ts['ranker_used'], 'mechanistic_primary_window_sampled');
    scanNoPhiKeys(json, extraForbiddenKeys: extraForbidden);
    expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
  });
}
