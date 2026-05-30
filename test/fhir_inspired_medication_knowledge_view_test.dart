import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_inspired_medication_knowledge_view.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

/// Phase γ / S1: the FHIR-inspired, PHI-free MedicationKnowledge view. Verifies
/// the mapping preserves product metadata + provenance, deterministically
/// serializes, separates product strength from user intake dose, and — critically
/// — emits NO patient-care / clinical-workflow keys (recursive key-level scan,
/// since `phi_policy` value intentionally names what is omitted).
void main() {
  const mapper = FhirInspiredMedicationKnowledgeMapper();

  // Forbidden FHIR patient-care / clinical-workflow KEYS (key-level, recursive).
  const forbiddenKeys = {
    'patient',
    'subject',
    'encounter',
    'practitioner',
    'careteam',
    'care_team',
    'diagnosis',
    'treatment',
    'medicationrequest',
    'medication_request',
    'medicationadministration',
    'medication_administration',
    'dosageinstruction',
    'dosage_instruction',
    'timing',
    'recommendation',
    'prescription',
  };

  // String values allowed to carry safety/policy wording without being scanned
  // for banned medical-advice phrases.
  const safetyCopyKeys = {
    'phi_policy',
    'safety_boundary',
    'not_advice_text',
    'conformance_status',
    'view_type',
    'limitation_text',
    'provenance_summary',
  };

  void scanKeys(Object? node) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        expect(forbiddenKeys.contains(key), isFalse,
            reason:
                'forbidden patient-care/clinical-workflow key present: ${entry.key}');
        scanKeys(entry.value);
      }
    } else if (node is List) {
      for (final e in node) {
        scanKeys(e);
      }
    }
  }

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

  // --- Synthetic fixtures (no real product, no PHI) -------------------------

  MechanisticMedicationMetadata carbidopaLevodopa({
    String releaseType = 'immediate',
    String releaseTypeSource = 'structured_variant_metadata',
    List<LabelSectionRef> sections = const [],
  }) {
    return MechanisticMedicationMetadata(
      sourceSystem: 'DailyMed',
      sourceDocId: 'spl:carbidopa-levodopa-demo',
      sourceDocVersion: '3',
      effectiveDate: '2025-01-01',
      jurisdiction: 'US',
      language: 'en',
      drugProductVariantId: 'synthetic:carbidopa-levodopa-25-100',
      doseForm: 'tablet',
      route: 'oral',
      releaseType: releaseType,
      releaseTypeSource: releaseTypeSource,
      components: const [
        MedicationComponent(
          ingredientName: 'carbidopa',
          role: 'decarboxylase_inhibitor',
          sourceRefs: ['src.spl.composition'],
        ),
        MedicationComponent(
          ingredientName: 'levodopa',
          role: 'active',
          sourceRefs: ['src.spl.composition'],
        ),
      ],
      labelSectionRefs: sections,
      sourceRefs: const ['src.spl.identity'],
      limitationText: 'Provenance only; not clinically calibrated.',
      metadataCompleteness: sections.isEmpty ? 'partial' : 'adequate',
    );
  }

  const irSection = LabelSectionRef(
    sourceSystem: 'DailyMed',
    sourceDocId: 'spl:carbidopa-levodopa-demo',
    sourceDocVersion: '3',
    jurisdiction: 'US',
    language: 'en',
    sectionId: '34068-7',
    sectionKey: 'dosage_and_administration',
    sectionTitle: 'Dosage Forms and Strengths',
    sourceRefs: ['src.spl.section'],
  );

  // Single-ingredient ER variant carrying a product strength on the component.
  MechanisticMedicationMetadata levodopaErWithStrength() =>
      const MechanisticMedicationMetadata(
        sourceSystem: 'DailyMed',
        sourceDocId: 'spl:levodopa-er-demo',
        sourceDocVersion: '1',
        effectiveDate: '2025-02-02',
        jurisdiction: 'US',
        language: 'en',
        doseForm: 'tablet, extended release',
        route: 'oral',
        releaseType: 'extended',
        releaseTypeSource: 'structured_variant_metadata',
        components: [
          MedicationComponent(
            ingredientName: 'levodopa',
            role: 'active',
            strengthValue: 200,
            strengthUnit: 'mg',
            sourceRefs: ['src.spl.composition'],
          ),
        ],
        labelSectionRefs: [irSection],
        sourceRefs: ['src.spl.identity'],
        limitationText: 'Provenance only.',
        metadataCompleteness: 'adequate',
      );

  // --- Tests ----------------------------------------------------------------

  test('1. maps mechanistic medication metadata into the view', () {
    final view = mapper.fromMechanisticMetadata(
      carbidopaLevodopa(sections: const [irSection]),
      demoDrugProductId: 'demo-cl-ir-1',
      genericName: 'carbidopa/levodopa',
    );
    expect(view.demoDrugProductId, 'demo-cl-ir-1');
    expect(view.sourceSystem, 'DailyMed');
    expect(view.doseForm, 'tablet');
    expect(view.route, 'oral');
    expect(view.genericName, 'carbidopa/levodopa');
  });

  test('2. preserves combination components incl. carbidopa and levodopa', () {
    final view = mapper.fromMechanisticMetadata(carbidopaLevodopa(),
        demoDrugProductId: 'demo-cl-ir-1');
    final names = view.combinationComponents.map((c) => c.ingredientName);
    expect(names, containsAll(['carbidopa', 'levodopa']));
    expect(view.activeIngredients, containsAll(['carbidopa', 'levodopa']));
    expect(view.combinationComponents, hasLength(2));
  });

  test('3. preserves product strength as product metadata', () {
    final view = mapper.fromMechanisticMetadata(levodopaErWithStrength(),
        demoDrugProductId: 'demo-ldopa-er-1');
    expect(view.strengths, hasLength(1));
    final s = view.strengths.single;
    expect(s.strengthValue, 200);
    expect(s.strengthUnit, 'mg');
    expect(s.strengthBasis, 'product_label_metadata');
    expect(FhirInspiredMedicationKnowledgeView.kStrengthIsProductMetadata,
        'product_label_metadata');
  });

  test('4. does not present product strength as a user intake dose', () {
    final json = mapper
        .fromMechanisticMetadata(levodopaErWithStrength(),
            demoDrugProductId: 'demo-ldopa-er-1')
        .toJson();
    // No intake-dose / timing / frequency keys anywhere.
    scanKeys(json);
    for (final banned in const [
      'intake_dose',
      'user_dose',
      'taken_dose',
      'dose_taken',
      'frequency',
      'schedule',
      'dosage_instruction',
    ]) {
      expect(jsonEncode(json).contains(banned), isFalse,
          reason: 'must not expose $banned (strength is product metadata)');
    }
    // Every strength is explicitly tagged as product metadata.
    for (final s in (json['strengths'] as List)) {
      expect((s as Map)['strength_basis'], 'product_label_metadata');
    }
  });

  test('5. preserves label section refs', () {
    final view = mapper.fromMechanisticMetadata(
        carbidopaLevodopa(sections: const [irSection]),
        demoDrugProductId: 'demo-cl-ir-1');
    expect(view.labelSectionRefs, hasLength(1));
    final ref = view.labelSectionRefs.single;
    expect(ref.sectionId, '34068-7');
    expect(ref.sectionCode, 'dosage_and_administration'); // key in code slot
    expect(ref.sourceSystem, 'DailyMed');
  });

  test('6. preserves release type and release type source', () {
    final ir = mapper.fromMechanisticMetadata(carbidopaLevodopa(),
        demoDrugProductId: 'd1');
    expect(ir.releaseType, 'immediate');
    expect(ir.releaseTypeSource, 'structured_variant_metadata');
    final er = mapper.fromMechanisticMetadata(levodopaErWithStrength(),
        demoDrugProductId: 'd2');
    expect(er.releaseType, 'extended');
  });

  test('7. preserves sourceRefs and provenance summary', () {
    final view = mapper.fromMechanisticMetadata(
        carbidopaLevodopa(sections: const [irSection]),
        demoDrugProductId: 'demo-cl-ir-1');
    expect(view.sourceRefs, contains('src.spl.identity'));
    expect(view.sourceRefs, contains('src.spl.composition'));
    expect(view.sourceRefs, contains('src.spl.section'));
    expect(view.sourceDocument.sourceDocId, 'spl:carbidopa-levodopa-demo');
    expect(view.sourceDocument.sourceDocVersion, '3');
    expect(view.sourceDocument.effectiveDate, '2025-01-01');
    expect(view.provenanceSummary, contains('release_type_source='));
    expect(view.provenanceSummary, contains('label_section_refs=1'));
  });

  test('8. omits patient/subject/encounter/administration/prescription keys',
      () {
    final json = mapper
        .fromMechanisticMetadata(carbidopaLevodopa(sections: const [irSection]),
            demoDrugProductId: 'demo-cl-ir-1')
        .toJson();
    scanKeys(json); // recursive key-level scan
    expect(json['phi_policy'], 'no_patient_no_administration_no_phi');
    expect(json.containsKey('patient'), isFalse);
    expect(json.containsKey('subject'), isFalse);
    expect(json.containsKey('encounter'), isFalse);
  });

  test('9. does not claim FHIR conformance', () {
    final json = mapper
        .fromMechanisticMetadata(carbidopaLevodopa(), demoDrugProductId: 'd')
        .toJson();
    expect(json['conformance_status'], 'inspired_not_conformant');
    expect(json['view_type'], 'fhir_inspired_medication_knowledge');
  });

  test('10. does not claim clinical calibration', () {
    final json = mapper
        .fromMechanisticMetadata(carbidopaLevodopa(), demoDrugProductId: 'd')
        .toJson();
    expect(json['not_clinically_calibrated'], isTrue);
  });

  test('11. emits no medication-timing or dose-advice phrases', () {
    final json = mapper
        .fromMechanisticMetadata(levodopaErWithStrength(),
            demoDrugProductId: 'd')
        .toJson();
    // Free-text scan (skipping safety-policy fields).
    for (final t in freeTextValues(json)) {
      expect(findBannedSubstrings(t), isEmpty,
          reason: 'banned medical-advice phrase in free text: "$t"');
    }
    // Stronger: full serialized JSON is banned-phrase-clean too.
    expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
  });

  test('12. JSON output is deterministic', () {
    final meta = carbidopaLevodopa(sections: const [irSection]);
    final a = jsonEncode(
        mapper.fromMechanisticMetadata(meta, demoDrugProductId: 'd').toJson());
    final b = jsonEncode(
        mapper.fromMechanisticMetadata(meta, demoDrugProductId: 'd').toJson());
    expect(a, b);
  });

  test('13. unitless user dosage stays insufficient despite product strength',
      () {
    // The bridge attaches rich product strength metadata, but a unitless user
    // dose must NOT be rescued — the dose path stays insufficient, and the view
    // still presents strength only as product metadata (never an intake dose).
    final validator = MedicationEntryValidator();
    final meta = levodopaErWithStrength(); // has 200 mg product strength
    final result = validator.validate(RawMedicationEntry(
      freeText: 'levodopa 200', // unitless
      activeIngredients: const ['levodopa'],
      drugProductVariant: 'v1',
      form: 'tablet',
      route: 'oral',
      releaseType: 'extended',
      jurisdiction: 'US',
      sourceDocId: 'spl:levodopa-er-demo',
      medicationMetadata: meta,
    ));
    expect(result.validity, isNot(MedicationContextValidity.valid));
    expect(result.normalized, isNull); // no dose fabricated from metadata

    // The product-knowledge view still renders the strength — as metadata.
    final view = mapper.fromMechanisticMetadata(meta, demoDrugProductId: 'd');
    expect(view.strengths.single.strengthBasis, 'product_label_metadata');
  });

  test('14. reuses shared safety copy', () {
    final view = mapper.fromMechanisticMetadata(carbidopaLevodopa(),
        demoDrugProductId: 'd');
    expect(view.notAdviceText, RuleExplanation.defaultNotAdvice);
    expect(view.safetyBoundary, RuleExplanation.defaultSafetyBoundary);
  });

  // Task 6 — replay-style SPL IR + ER fixtures map to a PHI-free view.
  test('replay-style SPL IR + ER metadata map to PHI-free views', () {
    final ir = mapper
        .fromMechanisticMetadata(
            carbidopaLevodopa(
                releaseType: 'immediate', sections: const [irSection]),
            demoDrugProductId: 's39-cl-ir')
        .toJson();
    final er = mapper
        .fromMechanisticMetadata(levodopaErWithStrength(),
            demoDrugProductId: 's40-ldopa-er')
        .toJson();
    for (final json in [ir, er]) {
      scanKeys(json);
      expect(json['phi_policy'], 'no_patient_no_administration_no_phi');
      expect(json['conformance_status'], 'inspired_not_conformant');
      expect((json['label_section_refs'] as List), isNotEmpty);
    }
    expect(ir['release_type'], 'immediate');
    expect(er['release_type'], 'extended');
  });

  test('component with no strength is recorded missing, not fabricated', () {
    final view = mapper.fromMechanisticMetadata(carbidopaLevodopa(),
        demoDrugProductId: 'd');
    // Carbidopa/levodopa fixture carries no per-component strength.
    for (final c in view.combinationComponents) {
      expect(c.strengthValue, isNull);
      expect(c.limitationText, contains('missing'));
    }
    expect(view.strengths, isEmpty); // nothing fabricated
  });

  test('fromNormalizedContext returns null when no metadata attached', () {
    const ctx = NormalizedMedicationContext(
      drugProductVariant: 'v1',
      activeIngredients: ['levodopa'],
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      strength: 100,
      unit: 'mg',
      jurisdiction: 'US',
      sourceDocId: 'spl:demo',
      labelSection: null,
      extractionConfidence: null,
      limitationText: '',
    );
    final view = mapper.fromNormalizedContext(ctx, demoDrugProductId: 'd');
    expect(view, isNull);
  });
}
