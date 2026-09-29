import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_condition_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_condition_import_mapper.dart';

void main() {
  const mapper = FhirR4ConditionImportMapper();

  test('projects source statuses and lexical dates without interpretation', () {
    final input = jsonEncode(_condition());
    final preview = mapper.previewJson(input: input, context: _context());
    final entry = preview.entries.single;

    expect(preview.previewable, isTrue);
    expect(preview.inputSha256, hasLength(64));
    expect(preview.containerType, 'Condition');
    expect(entry.patientReferenceMatched, isTrue);
    expect(entry.resourceId, 'condition-1');
    expect(entry.clinicalStatus?.codings.single.code, 'active');
    expect(entry.verificationStatus?.codings.single.code, 'confirmed');
    expect(entry.categories.single.codings.single.code, 'problem-list-item');
    expect(entry.code?.text, 'Synthetic condition');
    expect(entry.onsetDateTime?.lexical, '2024-03');
    expect(entry.onsetDateTime?.precision, FhirR4ConditionDatePrecision.month);
    expect(entry.recordedDate?.lexical, '2026-09-20');
    expect(entry.reasonCodes, isEmpty);
    expect(entry.unmappedPaths, isEmpty);
    expect(FhirR4ConditionImportPreview.persistsData, isFalse);
    expect(FhirR4ConditionImportPreview.algorithmEligible, isFalse);
  });

  test('holds mismatched Patient scope and known-but-unprojected fields', () {
    final bundle = <String, Object?>{
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {'fullUrl': 'urn:uuid:condition-1', 'resource': _condition()},
        {
          'fullUrl': 'urn:uuid:condition-2',
          'resource': _condition(
            id: 'condition-2',
            patientReference: 'Patient/another-person',
            extra: const <String, Object?>{
              'severity': {'text': 'not projected'},
            },
          ),
        },
      ],
    };
    final preview = mapper.previewJson(
      input: jsonEncode(bundle),
      context: _context(),
    );

    expect(preview.containerType, 'Bundle');
    expect(preview.entries, hasLength(2));
    expect(preview.entries.first.previewable, isTrue);
    expect(preview.entries.first.entryFullUrl, 'urn:uuid:condition-1');
    expect(preview.entries.last.previewable, isFalse);
    expect(preview.entries.last.patientReferenceMatched, isFalse);
    expect(
      preview.entries.last.reasonCodes,
      contains('fhir.patient_reference_mismatch_or_unsupported'),
    );
    expect(
      preview.entries.last.unmappedPaths,
      contains('Bundle.entry[1].resource.severity'),
    );
    expect(preview.previewable, isFalse);
    expect(preview.heldEntryCount, 1);
  });

  test('holds duplicate Bundle identities and malformed fullUrls', () {
    final preview = mapper.previewJson(
      input: jsonEncode({
        'resourceType': 'Bundle',
        'type': 'collection',
        'entry': [
          {'fullUrl': 'urn:uuid:duplicate', 'resource': _condition()},
          {'fullUrl': 'urn:uuid:duplicate', 'resource': _condition()},
          {'fullUrl': true, 'resource': _condition(id: 'condition-3')},
        ],
      }),
      context: _context(),
    );

    expect(preview.reasonCodes, contains('fhir.bundle_full_url_duplicate'));
    expect(preview.reasonCodes, contains('fhir.bundle_full_url_invalid'));
    expect(preview.reasonCodes, contains('fhir.resource_id_duplicate'));
  });

  test('enforces Condition status invariants without deciding diagnosis', () {
    final enteredInError = _condition(
      verificationCode: 'entered-in-error',
      clinicalCode: 'active',
    );
    final missingProblemListStatus = _condition(clinicalCode: null);
    final inconsistentAbatement = _condition(
      abatementDateTime: '2025-02',
      clinicalCode: 'active',
    );

    final previews =
        [enteredInError, missingProblemListStatus, inconsistentAbatement].map(
          (condition) => mapper.previewJson(
            input: jsonEncode(condition),
            context: _context(),
          ),
        );

    final results = previews.toList();
    expect(
      results[0].reasonCodes,
      contains('fhir.entered_in_error_has_clinical_status'),
    );
    expect(
      results[1].reasonCodes,
      contains('fhir.problem_list_requires_clinical_status'),
    );
    expect(
      results[2].reasonCodes,
      contains('fhir.abatement_status_inconsistent'),
    );
    expect(results.every((result) => !result.previewable), isTrue);
  });

  test(
    'allows entered-in-error without a clinical status as source-reported',
    () {
      final preview = mapper.previewJson(
        input: jsonEncode(
          _condition(verificationCode: 'entered-in-error', clinicalCode: null),
        ),
        context: _context(),
      );

      expect(preview.previewable, isTrue);
      expect(preview.entries.single.clinicalStatus, isNull);
      expect(
        preview.entries.single.verificationStatus?.codings.single.code,
        'entered-in-error',
      );
    },
  );

  test(
    'holds unknown fields and rejects unsupported scope or Bundle shape',
    () {
      final unknown = _condition(
        extra: const <String, Object?>{'futureFlag': true},
      );
      final unknownPreview = mapper.previewJson(
        input: jsonEncode(unknown),
        context: _context(),
      );
      expect(unknownPreview.reasonCodes, contains('fhir.unknown_field'));

      final wrongScope = mapper.previewJson(
        input: jsonEncode(_condition()),
        context: _context(version: '5.0.0'),
      );
      expect(wrongScope.reasonCodes, contains('fhir.release_unsupported'));

      final transaction = mapper.previewJson(
        input: jsonEncode({
          'resourceType': 'Bundle',
          'type': 'transaction',
          'entry': [
            {'resource': _condition()},
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

  test('rejects oversized input and invalid Patient context', () {
    expect(
      () => mapper.previewJson(
        input: ' ' * (FhirR4ConditionImportPreview.maximumInputBytes + 1),
        context: _context(),
      ),
      throwsFormatException,
    );
    final preview = mapper.previewJson(
      input: jsonEncode(_condition()),
      context: _context(patientReference: 'Patient/'),
    );
    expect(preview.reasonCodes, contains('fhir.patient_reference_invalid'));
  });
}

FhirR4ConditionPreviewContext _context({
  String version = '4.0.1',
  String patientReference = 'Patient/synthetic-1',
}) => FhirR4ConditionPreviewContext(
  fhirVersion: version,
  jurisdiction: 'CA',
  expectedPatientReference: patientReference,
);

Map<String, Object?> _condition({
  String id = 'condition-1',
  String patientReference = 'Patient/synthetic-1',
  String? clinicalCode = 'active',
  String verificationCode = 'confirmed',
  String? onsetDateTime = '2024-03',
  String? abatementDateTime,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'resourceType': 'Condition',
  'id': id,
  'meta': {
    'versionId': '1',
    'source': 'https://ehr.example.org/fhir/demo',
    'lastUpdated': '2026-09-20T12:05:00Z',
  },
  if (clinicalCode != null)
    'clinicalStatus': {
      'coding': [
        {
          'system': 'http://terminology.hl7.org/CodeSystem/condition-clinical',
          'code': clinicalCode,
          'display': clinicalCode,
        },
      ],
    },
  'verificationStatus': {
    'coding': [
      {
        'system': 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
        'code': verificationCode,
        'display': verificationCode,
      },
    ],
  },
  'category': [
    {
      'coding': [
        {
          'system': 'http://terminology.hl7.org/CodeSystem/condition-category',
          'code': 'problem-list-item',
          'display': 'Problem List Item',
        },
      ],
    },
  ],
  'code': {
    'coding': [
      {
        'system': 'https://example.org/synthetic-condition-codes',
        'code': 'demo-condition',
        'display': 'Synthetic condition',
      },
    ],
    'text': 'Synthetic condition',
  },
  'subject': {'reference': patientReference},
  'onsetDateTime': ?onsetDateTime,
  'abatementDateTime': ?abatementDateTime,
  'recordedDate': '2026-09-20',
  ...extra,
};
