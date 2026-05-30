import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/label_section_code.dart';
import 'package:parkinsum_companion/domain/entities/medication_source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/label_section_code_mapper.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P2 — conservative LOINC section-code mapping. Verifies known FDA SPL section
/// keys map to the verified LOINC codes, unknown/ambiguous stays unknown (never
/// guessed), the original section key is always preserved, and the medication
/// view surfaces both section_code and the optional loinc_code.
void main() {
  const mapper = LabelSectionCodeMapper();

  test('known section keys map to verified LOINC codes', () {
    const cases = {
      'indications_and_usage': '34067-9',
      'dosage_and_administration': '34068-7',
      'contraindications': '34070-3',
      'warnings_and_precautions': '43685-7',
      'drug_interactions': '34073-7',
      'clinical_pharmacology': '34090-1',
      'description': '34089-3',
      'how_supplied': '34069-5',
      'adverse_reactions': '34084-4',
    };
    cases.forEach((key, expectedCode) {
      final r = mapper.map(sectionKey: key);
      expect(r.isMapped, isTrue, reason: '$key should map');
      expect(r.loincCode, expectedCode, reason: '$key → $expectedCode');
      expect(r.loincDisplay, isNotNull);
      expect(r.sourceRefs, contains('src.fda.spl.standard'));
    });
  });

  test('mapping works via title when key is opaque', () {
    final r = mapper.map(
        sectionKey: 'section_2', sectionTitle: 'Dosage and Administration');
    expect(r.loincCode, '34068-7');
    expect(r.mappingConfidence, SectionCodeMappingConfidence.mapped);
  });

  test('unknown section key remains unknown (not guessed)', () {
    final r = mapper.map(sectionKey: 'spl_unstructured_blob_42');
    expect(r.isMapped, isFalse);
    expect(r.loincCode, isNull);
    expect(r.loincDisplay, isNull);
    expect(r.mappingConfidence, SectionCodeMappingConfidence.unknown);
    expect(r.sourceRefs, isEmpty);
  });

  test('ambiguous / non-section title remains unknown', () {
    final r = mapper.map(
        sectionKey: 'misc', sectionTitle: 'Additional information of interest');
    expect(r.isMapped, isFalse);
    expect(r.loincCode, isNull);
  });

  test('original section key is always preserved', () {
    final mapped = mapper.map(sectionKey: 'Dosage_And_Administration');
    expect(mapped.sourceSectionKey, 'Dosage_And_Administration');
    final unknown = mapper.map(sectionKey: 'weird_key');
    expect(unknown.sourceSectionKey, 'weird_key');
  });

  test('synonym maps conservatively', () {
    expect(mapper.map(sectionKey: 'drug interaction').loincCode, '34073-7');
    expect(mapper.map(sectionKey: 'storage and handling').loincCode, '34069-5');
  });

  test('LabelSectionCode JSON is deterministic and complete', () {
    final r = mapper.map(sectionKey: 'contraindications');
    final a = jsonEncode(r.toJson());
    final b = jsonEncode(r.toJson());
    expect(a, b);
    final json = r.toJson();
    expect(json['source_section_key'], 'contraindications');
    expect(json['loinc_code'], '34070-3');
    expect(json['mapping_confidence'], 'mapped');
  });

  group('medication view surfaces section_code + optional loinc_code', () {
    const viewMapper = FhirInspiredMedicationKnowledgeMapper();

    MechanisticMedicationMetadata metaWith(LabelSectionRef ref) =>
        MechanisticMedicationMetadata(
          sourceSystem: 'DailyMed',
          sourceDocId: 'spl:demo',
          jurisdiction: 'US',
          language: 'en',
          doseForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          releaseTypeSource: 'structured_variant_metadata',
          components: const [
            MedicationComponent(ingredientName: 'levodopa', role: 'active'),
          ],
          labelSectionRefs: [ref],
          sourceRefs: const ['src.spl.identity'],
          limitationText: 'Provenance only.',
          metadataCompleteness: 'adequate',
        );

    test('known section → both section_code and loinc_code present', () {
      const ref = LabelSectionRef(
        sourceSystem: 'DailyMed',
        sourceDocId: 'spl:demo',
        jurisdiction: 'US',
        language: 'en',
        sectionId: '34068-7',
        sectionKey: 'dosage_and_administration',
        sectionTitle: 'Dosage and Administration',
        sourceRefs: ['src.spl.section'],
      );
      final json = viewMapper
          .fromMechanisticMetadata(metaWith(ref), demoDrugProductId: 'd')
          .toJson();
      final sec = (json['label_section_refs'] as List).single as Map;
      expect(sec['section_code'], 'dosage_and_administration'); // source key
      expect(sec['loinc_code'], '34068-7');
      expect(sec['loinc_display'], 'Dosage and administration');
      expect(sec['loinc_mapping_confidence'], 'mapped');
      // LOINC source citation unioned into the ref's source_refs.
      expect((sec['source_refs'] as List), contains('src.fda.spl.standard'));
      expect((sec['source_refs'] as List), contains('src.spl.section'));
      scanNoPhiKeys(json);
      expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
    });

    test('unknown section → section_code present, loinc_code null', () {
      const ref = LabelSectionRef(
        sourceSystem: 'DailyMed',
        sourceDocId: 'spl:demo',
        jurisdiction: 'US',
        language: 'en',
        sectionId: 'x',
        sectionKey: 'proprietary_blob',
        sectionTitle: 'Opaque section',
        sourceRefs: ['src.spl.section'],
      );
      final json = viewMapper
          .fromMechanisticMetadata(metaWith(ref), demoDrugProductId: 'd')
          .toJson();
      final sec = (json['label_section_refs'] as List).single as Map;
      expect(sec['section_code'], 'proprietary_blob');
      expect(sec['loinc_code'], isNull);
      expect(sec['loinc_mapping_confidence'], 'unknown');
    });
  });
}
