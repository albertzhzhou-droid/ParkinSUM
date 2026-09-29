import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_medication_dispense_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_dispense_import_mapper.dart';

void main() {
  const mapper = FhirR4MedicationDispenseImportMapper();

  test('retains source status, quantities, days supply and lexical times', () {
    final preview = mapper.previewJson(
      input: jsonEncode(_dispense()),
      context: _context(),
    );
    final entry = preview.entries.single;

    expect(preview.previewable, isTrue);
    expect(preview.containerType, 'MedicationDispense');
    expect(preview.inputSha256, hasLength(64));
    expect(entry.patientReferenceMatched, isTrue);
    expect(entry.status, 'completed');
    expect(entry.medicationConceptText, 'Synthetic medication');
    expect(entry.medicationCodings.single.code, 'm1');
    expect(entry.quantity?.value, 30);
    expect(entry.quantity?.unit, 'tablets');
    expect(entry.quantity?.code, '1');
    expect(entry.daysSupply?.value, 30);
    expect(entry.daysSupply?.unit, 'days');
    expect(entry.daysSupply?.code, 'd');
    expect(entry.whenPrepared?.lexical, '2026-09-20T11:20:00-04:00');
    expect(entry.whenHandedOver?.lexical, '2026-09-20T11:30:00-04:00');
    expect(entry.reasonCodes, isEmpty);
    expect(entry.unmappedPaths, isEmpty);
    expect(FhirR4MedicationDispenseImportPreview.persistsData, isFalse);
    expect(FhirR4MedicationDispenseImportPreview.algorithmEligible, isFalse);
  });

  test('preserves all non-error R4 statuses as source values', () {
    const statuses = [
      'preparation',
      'in-progress',
      'cancelled',
      'on-hold',
      'completed',
      'stopped',
      'declined',
      'unknown',
    ];
    for (final status in statuses) {
      final preview = mapper.previewJson(
        input: jsonEncode(_dispense(status: status)),
        context: _context(),
      );
      expect(preview.entries.single.status, status);
      expect(preview.entries.single.previewable, isTrue, reason: status);
    }
  });

  test('holds entered-in-error while retaining the source status', () {
    final preview = mapper.previewJson(
      input: jsonEncode(_dispense(status: 'entered-in-error')),
      context: _context(),
    );
    expect(preview.entries.single.status, 'entered-in-error');
    expect(preview.entries.single.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.entered_in_error'));
  });

  test(
    'projects collection entries and holds mismatched or unprojected data',
    () {
      final preview = mapper.previewJson(
        input: jsonEncode({
          'resourceType': 'Bundle',
          'type': 'collection',
          'entry': [
            {'fullUrl': 'urn:uuid:dispense-1', 'resource': _dispense()},
            {
              'fullUrl': 'urn:uuid:dispense-2',
              'resource': _dispense(
                id: 'dispense-2',
                patient: 'Patient/other',
                extra: const {
                  'dosageInstruction': [
                    {'text': 'unparsed source text'},
                  ],
                  'futureFlag': true,
                },
              ),
            },
          ],
        }),
        context: _context(),
      );

      expect(preview.containerType, 'Bundle');
      expect(preview.entries, hasLength(2));
      expect(preview.entries.first.bundleEntryFullUrl, 'urn:uuid:dispense-1');
      expect(preview.entries.first.previewable, isTrue);
      expect(preview.entries.last.patientReferenceMatched, isFalse);
      expect(preview.entries.last.previewable, isFalse);
      expect(preview.reasonCodes, contains('fhir.patient_reference_mismatch'));
      expect(preview.reasonCodes, contains('fhir.unknown_field'));
      expect(
        preview.unmappedPaths,
        contains('Bundle.entry[1].resource.dosageInstruction'),
      );
      expect(
        preview.unmappedPaths,
        contains('Bundle.entry[1].resource.futureFlag'),
      );
      expect(preview.heldEntryCount, 1);
    },
  );

  test('holds medication and status reason references for review', () {
    final preview = mapper.previewJson(
      input: jsonEncode(
        _dispense(
          extra: const {
            'medicationCodeableConcept': null,
            'medicationReference': {'reference': 'Medication/example'},
            'statusReasonReference': {'reference': 'DetectedIssue/example'},
          },
        )..remove('medicationCodeableConcept'),
      ),
      context: _context(),
    );
    expect(preview.previewable, isFalse);
    expect(
      preview.unmappedPaths,
      contains('MedicationDispense.medicationReference'),
    );
    expect(
      preview.unmappedPaths,
      contains('MedicationDispense.statusReasonReference'),
    );
  });

  test(
    'rejects invalid dates, impossible chronology and malformed quantity',
    () {
      final invalidDate = mapper.previewJson(
        input: jsonEncode(_dispense(prepared: '2026-02-30', handedOver: null)),
        context: _context(),
      );
      expect(invalidDate.reasonCodes, contains('fhir.datetime_invalid'));

      final reversedTimes = mapper.previewJson(
        input: jsonEncode(
          _dispense(
            prepared: '2026-09-20T11:30:00Z',
            handedOver: '2026-09-20T11:20:00Z',
          ),
        ),
        context: _context(),
      );
      expect(
        reversedTimes.reasonCodes,
        contains('fhir.handed_over_before_prepared'),
      );

      final subMicrosecondReversedTimes = mapper.previewJson(
        input: jsonEncode(
          _dispense(
            prepared: '2026-09-20T11:30:00.0000002Z',
            handedOver: '2026-09-20T11:30:00.0000001Z',
          ),
        ),
        context: _context(),
      );
      expect(
        subMicrosecondReversedTimes.reasonCodes,
        contains('fhir.handed_over_before_prepared'),
      );

      final invalidQuantity = mapper.previewJson(
        input: jsonEncode(
          _dispense(quantity: {'value': '30', 'unit': 'tablets'}),
        ),
        context: _context(),
      );
      expect(
        invalidQuantity.reasonCodes,
        contains('fhir.quantity_value_invalid'),
      );
    },
  );

  test('holds invalid resource context and non-collection Bundles', () {
    final wrongVersion = mapper.previewJson(
      input: jsonEncode(_dispense()),
      context: _context(version: '5.0.0'),
    );
    expect(wrongVersion.previewable, isFalse);
    expect(wrongVersion.reasonCodes, contains('fhir.release_unsupported'));

    final transaction = mapper.previewJson(
      input: jsonEncode({
        'resourceType': 'Bundle',
        'type': 'transaction',
        'entry': [
          {'resource': _dispense()},
        ],
      }),
      context: _context(),
    );
    expect(
      transaction.reasonCodes,
      contains('fhir.bundle_type_not_collection'),
    );

    final invalidPatientContext = mapper.previewJson(
      input: jsonEncode(_dispense()),
      context: _context(patient: 'Patient/'),
    );
    expect(
      invalidPatientContext.reasonCodes,
      contains('fhir.expected_patient_reference_invalid'),
    );
    expect(invalidPatientContext.entries.single.previewable, isFalse);
  });

  test('enforces the input bound and rejects invalid FHIR JSON shapes', () {
    expect(
      () => mapper.previewJson(
        input:
            ' ' * (FhirR4MedicationDispenseImportPreview.maximumInputBytes + 1),
        context: _context(),
      ),
      throwsFormatException,
    );
    expect(
      () => mapper.previewJson(input: '[]', context: _context()),
      throwsFormatException,
    );
  });
}

FhirR4MedicationDispenseImportContext _context({
  String version = '4.0.1',
  String patient = 'Patient/synthetic-1',
}) => FhirR4MedicationDispenseImportContext(
  fhirVersion: version,
  jurisdiction: 'CA',
  expectedPatientReference: patient,
);

Map<String, Object?> _dispense({
  String id = 'dispense-1',
  String status = 'completed',
  String patient = 'Patient/synthetic-1',
  String? prepared = '2026-09-20T11:20:00-04:00',
  String? handedOver = '2026-09-20T11:30:00-04:00',
  Object? quantity = const {'value': 30, 'unit': 'tablets', 'code': '1'},
  Map<String, Object?> extra = const {},
}) => <String, Object?>{
  'resourceType': 'MedicationDispense',
  'id': id,
  'status': status,
  'medicationCodeableConcept': {
    'text': 'Synthetic medication',
    'coding': [
      {'system': 'https://example.org/meds', 'code': 'm1'},
    ],
  },
  'subject': {'reference': patient},
  ...?_optionalField('quantity', quantity),
  'daysSupply': {'value': 30, 'unit': 'days', 'code': 'd'},
  ...?_optionalField('whenPrepared', prepared),
  ...?_optionalField('whenHandedOver', handedOver),
  ...extra,
};

Map<String, Object?>? _optionalField(String key, Object? value) =>
    value == null ? null : <String, Object?>{key: value};
