import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_encounter_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_encounter_import_mapper.dart';

void main() {
  const mapper = FhirR4EncounterImportMapper();

  test('preserves the bounded source fields and lexical period values', () {
    final preview = mapper.previewJson(
      input: jsonEncode(_encounter()),
      context: _context(),
    );
    final entry = preview.entries.single;

    expect(preview.previewable, isTrue);
    expect(preview.containerType, 'Encounter');
    expect(preview.inputSha256, hasLength(64));
    expect(entry.status, 'finished');
    expect(entry.patientReferenceMatched, isTrue);
    expect(entry.encounterClass?.system, 'https://example.org/synthetic-class');
    expect(entry.encounterClass?.code, 'demo');
    expect(entry.periodStart?.lexical, '2026-09-20T10:00:00-04:00');
    expect(entry.periodEnd?.lexical, '2026-09');
    expect(entry.reasonCodes, isEmpty);
    expect(entry.unmappedPaths, isEmpty);
    expect(FhirR4EncounterImportPreview.persistsData, isFalse);
    expect(FhirR4EncounterImportPreview.algorithmEligible, isFalse);
  });

  test('accepts every R4 status as source data and holds entered-in-error', () {
    const statuses = [
      'planned',
      'arrived',
      'triaged',
      'in-progress',
      'onleave',
      'finished',
      'cancelled',
      'entered-in-error',
      'unknown',
    ];
    for (final status in statuses) {
      final preview = mapper.previewJson(
        input: jsonEncode(_encounter(status: status)),
        context: _context(),
      );
      expect(preview.entries.single.status, status, reason: status);
      expect(
        preview.entries.single.previewable,
        status != 'entered-in-error',
        reason: status,
      );
    }
  });

  test(
    'holds a foreign Patient and known-but-unprojected encounter fields',
    () {
      final preview = mapper.previewJson(
        input: jsonEncode({
          'resourceType': 'Bundle',
          'type': 'collection',
          'entry': [
            {'resource': _encounter()},
            {
              'resource': _encounter(
                id: 'encounter-2',
                patient: 'Patient/other',
                extra: const {
                  'reasonCode': [
                    {'text': 'Synthetic reason'},
                  ],
                },
              ),
            },
          ],
        }),
        context: _context(),
      );

      expect(preview.containerType, 'Bundle');
      expect(preview.entries, hasLength(2));
      expect(preview.entries.first.previewable, isTrue);
      expect(preview.entries.last.patientReferenceMatched, isFalse);
      expect(preview.entries.last.previewable, isFalse);
      expect(preview.reasonCodes, contains('fhir.patient_reference_mismatch'));
      expect(
        preview.unmappedPaths,
        contains('Bundle.entry[1].resource.reasonCode'),
      );
      expect(preview.heldEntryCount, 1);
    },
  );

  test(
    'rejects wrong release, unsupported Bundle types, and invalid dates',
    () {
      final wrongRelease = mapper.previewJson(
        input: jsonEncode(_encounter()),
        context: _context(version: '5.0.0'),
      );
      expect(wrongRelease.reasonCodes, contains('fhir.release_unsupported'));
      expect(wrongRelease.entries.single.previewable, isFalse);

      final transaction = mapper.previewJson(
        input: jsonEncode({
          'resourceType': 'Bundle',
          'type': 'transaction',
          'entry': [
            {'resource': _encounter()},
          ],
        }),
        context: _context(),
      );
      expect(
        transaction.reasonCodes,
        contains('fhir.bundle_type_not_collection'),
      );

      final invalidDate = mapper.previewJson(
        input: jsonEncode(_encounter(period: const {'start': '2026-02-30'})),
        context: _context(),
      );
      expect(invalidDate.reasonCodes, contains('fhir.datetime_invalid'));

      final timezoneMissing = mapper.previewJson(
        input: jsonEncode(
          _encounter(period: const {'start': '2026-09-20T10:00:00'}),
        ),
        context: _context(),
      );
      expect(timezoneMissing.reasonCodes, contains('fhir.datetime_invalid'));

      final explicitNullPeriod = mapper.previewJson(
        input: jsonEncode(_encounter()..['period'] = null),
        context: _context(),
      );
      expect(explicitNullPeriod.reasonCodes, contains('fhir.period_invalid'));
    },
  );

  test('fails closed on unknown fields and missing Patient identity', () {
    final unknown = mapper.previewJson(
      input: jsonEncode(_encounter(extra: const {'futureFlag': true})),
      context: _context(),
    );
    expect(unknown.reasonCodes, contains('fhir.unknown_field'));
    expect(unknown.unmappedPaths, contains('Encounter.futureFlag'));

    final missingSubject = mapper.previewJson(
      input: jsonEncode(_encounter()..remove('subject')),
      context: _context(),
    );
    expect(
      missingSubject.reasonCodes,
      contains('fhir.patient_reference_mismatch'),
    );
  });
}

FhirR4EncounterImportContext _context({String version = '4.0.1'}) =>
    FhirR4EncounterImportContext(
      fhirVersion: version,
      jurisdiction: 'CA',
      expectedPatientReference: 'Patient/synthetic-1',
    );

Map<String, Object?> _encounter({
  String id = 'encounter-1',
  String status = 'finished',
  String patient = 'Patient/synthetic-1',
  Map<String, Object?>? period,
  Map<String, Object?> extra = const {},
}) => {
  'resourceType': 'Encounter',
  'id': id,
  'status': status,
  'class': {'system': 'https://example.org/synthetic-class', 'code': 'demo'},
  'subject': {'reference': patient},
  if (period != null)
    'period': period
  else
    'period': {'start': '2026-09-20T10:00:00-04:00', 'end': '2026-09'},
  ...extra,
};
