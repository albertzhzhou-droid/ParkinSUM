import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_medication_administration_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_administration_import_mapper.dart';

void main() {
  const mapper = FhirR4MedicationAdministrationImportMapper();

  test('retains administration source status, coding and lexical time', () {
    const input =
        '{"resourceType":"MedicationAdministration","id":"admin-1",'
        '"status":"completed","medicationCodeableConcept":{"text":"Synthetic",'
        '"coding":[{"system":"https://example.org/meds","code":"m1"}]},'
        '"subject":{"reference":"Patient/synthetic-1"},'
        '"effectiveDateTime":"2026-09-20T11:30:00-04:00"}';
    final preview = mapper.previewJson(input: input, context: _context());
    final entry = preview.entries.single;

    expect(preview.previewable, isTrue);
    expect(preview.containerType, 'MedicationAdministration');
    expect(preview.inputSha256, hasLength(64));
    expect(entry.resourceId, 'admin-1');
    expect(entry.patientReferenceMatched, isTrue);
    expect(entry.status, 'completed');
    expect(entry.medicationConceptText, 'Synthetic');
    expect(entry.medicationCodings.single.code, 'm1');
    expect(entry.effectiveDateTime?.lexical, '2026-09-20T11:30:00-04:00');
    expect(
      entry.effectiveDateTime?.precision,
      FhirR4MedicationAdministrationTimePrecision.second,
    );
    expect(entry.reasonCodes, isEmpty);
    expect(entry.unmappedPaths, isEmpty);
    expect(FhirR4MedicationAdministrationImportPreview.persistsData, isFalse);
    expect(
      FhirR4MedicationAdministrationImportPreview.algorithmEligible,
      isFalse,
    );
  });

  test('preserves all R4 status codes as source values', () {
    const statuses = [
      'in-progress',
      'not-done',
      'on-hold',
      'completed',
      'stopped',
      'unknown',
    ];
    for (final status in statuses) {
      final preview = mapper.previewJson(
        input: jsonEncode(_administration(status: status)),
        context: _context(),
      );
      expect(preview.entries.single.status, status);
      expect(preview.entries.single.previewable, isTrue, reason: status);
    }
  });

  test('holds entered-in-error without treating it as an administration', () {
    final preview = mapper.previewJson(
      input: jsonEncode(_administration(status: 'entered-in-error')),
      context: _context(),
    );
    expect(preview.entries.single.status, 'entered-in-error');
    expect(preview.entries.single.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.entered_in_error'));
  });

  test('previews bounded collection entries and holds unprojected dosage', () {
    final preview = mapper.previewJson(
      input: jsonEncode({
        'resourceType': 'Bundle',
        'type': 'collection',
        'entry': [
          {'fullUrl': 'urn:uuid:admin-1', 'resource': _administration()},
          {
            'fullUrl': 'urn:uuid:admin-2',
            'resource': _administration(
              id: 'admin-2',
              patient: 'Patient/other',
              extra: const {
                'dosage': {
                  'dose': {'value': 1, 'unit': 'mg'},
                },
              },
            ),
          },
        ],
      }),
      context: _context(),
    );

    expect(preview.containerType, 'Bundle');
    expect(preview.entries, hasLength(2));
    expect(preview.entries.first.bundleEntryFullUrl, 'urn:uuid:admin-1');
    expect(preview.entries.first.previewable, isTrue);
    expect(preview.entries.last.patientReferenceMatched, isFalse);
    expect(preview.entries.last.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.patient_reference_mismatch'));
    expect(preview.unmappedPaths, contains('Bundle.entry[1].resource.dosage'));
    expect(preview.heldEntryCount, 1);
  });

  test('supports source period bounds and rejects invalid time choices', () {
    final period = mapper.previewJson(
      input: jsonEncode(
        _administration(
          effective: null,
          period: {'start': '2026-09', 'end': '2026-10-01'},
        ),
      ),
      context: _context(),
    );
    expect(period.previewable, isTrue);
    expect(period.entries.single.effectivePeriodStart?.lexical, '2026-09');
    expect(period.entries.single.effectivePeriodEnd?.lexical, '2026-10-01');

    final both = mapper.previewJson(
      input: jsonEncode(_administration(period: {'start': '2026-09-20'})),
      context: _context(),
    );
    expect(both.reasonCodes, contains('fhir.effective_choice_invalid'));

    final invalid = mapper.previewJson(
      input: jsonEncode(_administration(effective: '2026-02-30')),
      context: _context(),
    );
    expect(invalid.reasonCodes, contains('fhir.datetime_invalid'));
  });

  test(
    'holds unknown fields, wrong Patient context and unsupported Bundles',
    () {
      final unknown = mapper.previewJson(
        input: jsonEncode(_administration(extra: const {'futureFlag': true})),
        context: _context(),
      );
      expect(unknown.reasonCodes, contains('fhir.unknown_field'));

      final wrongContext = mapper.previewJson(
        input: jsonEncode(_administration()),
        context: _context(version: '5.0.0'),
      );
      expect(wrongContext.reasonCodes, contains('fhir.release_unsupported'));

      final transaction = mapper.previewJson(
        input: jsonEncode({
          'resourceType': 'Bundle',
          'type': 'transaction',
          'entry': [
            {'resource': _administration()},
          ],
        }),
        context: _context(),
      );
      expect(
        transaction.reasonCodes,
        contains('fhir.bundle_type_not_collection'),
      );
    },
  );

  test('enforces size and context bounds', () {
    expect(
      () => mapper.previewJson(
        input:
            ' ' *
            (FhirR4MedicationAdministrationImportPreview.maximumInputBytes + 1),
        context: _context(),
      ),
      throwsFormatException,
    );
    final preview = mapper.previewJson(
      input: jsonEncode(_administration()),
      context: _context(patient: 'Patient/'),
    );
    expect(
      preview.reasonCodes,
      contains('fhir.expected_patient_reference_invalid'),
    );
  });
}

FhirR4MedicationAdministrationImportContext _context({
  String version = '4.0.1',
  String patient = 'Patient/synthetic-1',
}) => FhirR4MedicationAdministrationImportContext(
  fhirVersion: version,
  jurisdiction: 'CA',
  expectedPatientReference: patient,
);

Map<String, Object?> _administration({
  String id = 'admin-1',
  String status = 'completed',
  String patient = 'Patient/synthetic-1',
  String? effective = '2026-09-20',
  Map<String, Object?>? period,
  Map<String, Object?> extra = const {},
}) => <String, Object?>{
  'resourceType': 'MedicationAdministration',
  'id': id,
  'status': status,
  'medicationCodeableConcept': {
    'text': 'Synthetic medication',
    'coding': [
      {'system': 'https://example.org/meds', 'code': 'synthetic-medication'},
    ],
  },
  'subject': {'reference': patient},
  ...?_fieldIfPresent('effectiveDateTime', effective),
  ...?_fieldIfPresent('effectivePeriod', period),
  ...extra,
};

Map<String, Object?>? _fieldIfPresent(String key, Object? value) =>
    value == null ? null : <String, Object?>{key: value};
