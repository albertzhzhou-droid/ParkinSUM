import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_medication_statement_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_statement_import_mapper.dart';

void main() {
  const mapper = FhirR4MedicationStatementImportMapper();
  const context = FhirR4MedicationStatementImportContext(
    fhirVersion: '4.0.1',
    jurisdiction: 'CA',
    expectedPatientReference: 'Patient/synthetic-1',
  );

  test('previews source claims and preserves source time precision', () {
    final raw = jsonEncode(_statement());
    final preview = mapper.previewJson(input: raw, context: context);
    final entry = preview.entries.single;

    expect(preview.previewable, isTrue);
    expect(preview.containerType, 'MedicationStatement');
    expect(preview.inputSha256, isNotEmpty);
    expect(preview.inputSha256.length, 64);
    expect(preview.entries, hasLength(1));
    expect(entry.resourceId, 'synthetic-med-1');
    expect(entry.resourceVersionId, '7');
    expect(entry.status, 'active');
    expect(entry.medicationConceptText, 'Synthetic medication');
    expect(entry.medicationCodings.single.system, 'https://example.org/code');
    expect(entry.medicationCodings.single.version, 'v1');
    expect(entry.medicationCodings.single.code, 'synthetic-code');
    expect(entry.subjectReference, context.expectedPatientReference);
    expect(entry.effectiveDateTime!.lexical, '2026-09');
    expect(
      entry.effectiveDateTime!.precision,
      FhirR4MedicationStatementTimePrecision.month,
    );
    expect(entry.effectiveDateTime!.utc, isNull);
    expect(entry.dateAsserted!.utc, DateTime.utc(2026, 9, 20, 16));
    expect(entry.informationSourceReference, 'RelatedPerson/synthetic-2');
    expect(entry.dosageTexts, ['One synthetic tablet, as source-reported']);
    expect(FhirR4MedicationStatementImportPreview.persistsData, isFalse);
    expect(FhirR4MedicationStatementImportPreview.algorithmEligible, isFalse);
  });

  test('accepts a collection bundle and keeps each status source-reported', () {
    final bundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {'fullUrl': 'urn:uuid:synthetic-1', 'resource': _statement()},
        {
          'fullUrl': 'urn:uuid:synthetic-2',
          'resource': _statement(
            id: 'synthetic-med-2',
            status: 'not-taken',
            effectiveDateTime: '2026-09-20',
          ),
        },
      ],
    };
    final preview = mapper.previewJson(
      input: jsonEncode(bundle),
      context: context,
    );

    expect(preview.previewable, isTrue);
    expect(preview.containerType, 'Bundle');
    expect(preview.entries, hasLength(2));
    expect(preview.entries.map((entry) => entry.status), [
      'active',
      'not-taken',
    ]);
    expect(preview.entries.every((entry) => entry.previewable), isTrue);
  });

  test(
    'holds a Patient mismatch, unsupported status and unprojected fields',
    () {
      final statement = _statement()
        ..['status'] = 'draft'
        ..['subject'] = {'reference': 'Patient/other'}
        ..['dosage'] = [
          {
            'text': 'unparsed source instructions',
            'doseAndRate': [
              {
                'doseQuantity': {'value': 2, 'unit': 'mg'},
              },
            ],
          },
        ]
        ..['extension'] = [
          {'url': 'https://example.org/extension', 'valueString': 'held'},
        ];
      final entry = mapper
          .previewJson(input: jsonEncode(statement), context: context)
          .entries
          .single;

      expect(entry.previewable, isFalse);
      expect(entry.reasonCodes, contains('fhir.status_missing_or_unsupported'));
      expect(entry.reasonCodes, contains('fhir.patient_reference_mismatch'));
      expect(entry.reasonCodes, contains('fhir.unmapped_fields'));
      expect(
        entry.unmappedPaths,
        contains('MedicationStatement.dosage[0].doseAndRate'),
      );
      expect(entry.unmappedPaths, contains('MedicationStatement.extension'));
      expect(entry.dosageTexts, ['unparsed source instructions']);
    },
  );

  test('previews Medication reference without resolving or coding it', () {
    final statement = _statement()
      ..remove('medicationCodeableConcept')
      ..['medicationReference'] = {
        'reference': 'https://ehr.example.org/fhir/Medication/med-4',
        'display': 'Source medication display',
      };
    final entry = mapper
        .previewJson(input: jsonEncode(statement), context: context)
        .entries
        .single;

    expect(entry.previewable, isTrue);
    expect(
      entry.medicationReference,
      'https://ehr.example.org/fhir/Medication/med-4',
    );
    expect(entry.medicationReferenceDisplay, 'Source medication display');
    expect(entry.medicationCodings, isEmpty);
  });

  test('holds duplicate resources and a non-collection bundle', () {
    final duplicateBundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {'fullUrl': 'urn:uuid:same', 'resource': _statement()},
        {'fullUrl': 'urn:uuid:same', 'resource': _statement()},
      ],
    };
    final duplicatePreview = mapper.previewJson(
      input: jsonEncode(duplicateBundle),
      context: context,
    );
    expect(duplicatePreview.previewable, isFalse);
    expect(
      duplicatePreview.reasonCodes,
      contains('fhir.bundle_full_url_duplicate'),
    );
    expect(
      duplicatePreview.reasonCodes,
      contains('fhir.resource_id_duplicate'),
    );

    final transaction = mapper.previewJson(
      input: jsonEncode({...duplicateBundle, 'type': 'transaction'}),
      context: context,
    );
    expect(transaction.previewable, isFalse);
    expect(
      transaction.reasonCodes,
      contains('fhir.bundle_type_not_collection'),
    );
  });

  test(
    'holds invalid periods and never invents an instant for date-only data',
    () {
      final partial = mapper
          .previewJson(
            input: jsonEncode(_statement(effectiveDateTime: '2026-09-20')),
            context: context,
          )
          .entries
          .single;
      expect(partial.previewable, isTrue);
      expect(
        partial.effectiveDateTime!.precision,
        FhirR4MedicationStatementTimePrecision.day,
      );
      expect(partial.effectiveDateTime!.utc, isNull);

      final reversed = _statement()
        ..remove('effectiveDateTime')
        ..['effectivePeriod'] = {
          'start': '2026-09-21T12:00:00Z',
          'end': '2026-09-20T12:00:00Z',
        };
      final held = mapper
          .previewJson(input: jsonEncode(reversed), context: context)
          .entries
          .single;
      expect(held.previewable, isFalse);
      expect(held.reasonCodes, contains('fhir.effective_period_order_invalid'));
    },
  );

  test('rejects wrong release, jurisdiction and Patient context', () {
    final wrongContext = FhirR4MedicationStatementImportContext(
      fhirVersion: '5.0.0',
      jurisdiction: 'Canada',
      expectedPatientReference: 'Patient/a b',
    );
    final preview = mapper.previewJson(
      input: jsonEncode(_statement()),
      context: wrongContext,
    );
    expect(preview.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.release_unsupported'));
    expect(
      preview.reasonCodes,
      contains('fhir.jurisdiction_missing_or_invalid'),
    );
    expect(
      preview.reasonCodes,
      contains('fhir.expected_patient_reference_invalid'),
    );
  });

  test(
    'rejects malformed, unsupported and oversized inputs without echoing',
    () {
      expect(
        () => mapper.previewJson(input: '{not json', context: context),
        throwsFormatException,
      );
      expect(
        () => mapper.previewJson(
          input: jsonEncode({'resourceType': 'MedicationRequest'}),
          context: context,
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.previewJson(
          input: jsonEncode({
            'resourceType': 'MedicationStatement',
            'padding': List<String>.filled(
              FhirR4MedicationStatementImportPreview.maximumInputBytes,
              'x',
            ).join(),
          }),
          context: context,
        ),
        throwsFormatException,
      );
    },
  );
}

Map<String, Object?> _statement({
  String id = 'synthetic-med-1',
  String status = 'active',
  String effectiveDateTime = '2026-09',
}) => {
  'resourceType': 'MedicationStatement',
  'id': id,
  'meta': {
    'versionId': '7',
    'source': 'https://ehr.example.org/fhir/MedicationStatement/$id',
    'lastUpdated': '2026-09-20T12:05:00Z',
  },
  'status': status,
  'medicationCodeableConcept': {
    'coding': [
      {
        'system': 'https://example.org/code',
        'version': 'v1',
        'code': 'synthetic-code',
        'display': 'Synthetic code',
        'userSelected': true,
      },
    ],
    'text': 'Synthetic medication',
  },
  'subject': {'reference': 'Patient/synthetic-1'},
  'effectiveDateTime': effectiveDateTime,
  'dateAsserted': '2026-09-20T12:00:00-04:00',
  'informationSource': {
    'reference': 'RelatedPerson/synthetic-2',
    'display': 'Synthetic caregiver',
  },
  'dosage': [
    {'text': 'One synthetic tablet, as source-reported'},
  ],
};
