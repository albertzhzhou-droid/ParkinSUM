import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_medication_request_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_request_import_mapper.dart';

void main() {
  const mapper = FhirR4MedicationRequestImportMapper();
  const context = FhirR4MedicationRequestPreviewContext(
    fhirVersion: '4.0.1',
    jurisdiction: 'CA',
    expectedPatientReference: 'Patient/synthetic-1',
  );

  test(
    'preserves request status, intent, source fields, and date precision',
    () {
      final input = jsonEncode(_request());
      final preview = mapper.previewJson(input: input, context: context);
      final entry = preview.entries.single;

      expect(preview.previewable, isTrue);
      expect(preview.containerType, 'MedicationRequest');
      expect(preview.inputSha256, hasLength(64));
      expect(entry.resourceId, 'synthetic-request-1');
      expect(entry.resourceVersionId, '3');
      expect(entry.status, 'active');
      expect(entry.intent, 'order');
      expect(entry.medicationConceptText, 'Synthetic medication');
      expect(entry.medicationCodings.single.system, 'https://example.org/code');
      expect(entry.medicationCodings.single.version, 'synthetic-v1');
      expect(entry.medicationCodings.single.code, 'med-1');
      expect(entry.subjectReference, context.expectedPatientReference);
      expect(entry.authoredOn!.lexical, '2026-09');
      expect(
        entry.authoredOn!.precision,
        FhirR4MedicationRequestTimePrecision.month,
      );
      expect(entry.authoredOn!.utc, isNull);
      expect(entry.requesterReference, 'Practitioner/synthetic-requester');
      expect(entry.dosageTexts, ['Source instruction text; not parsed.']);
      expect(FhirR4MedicationRequestImportPreview.persistsData, isFalse);
      expect(FhirR4MedicationRequestImportPreview.algorithmEligible, isFalse);
    },
  );

  test('accepts the eight R4 status and intent codes without merging them', () {
    const statuses = [
      'active',
      'on-hold',
      'cancelled',
      'completed',
      'entered-in-error',
      'stopped',
      'draft',
      'unknown',
    ];
    const intents = [
      'proposal',
      'plan',
      'order',
      'original-order',
      'reflex-order',
      'filler-order',
      'instance-order',
      'option',
    ];

    for (final status in statuses) {
      final entry = mapper
          .previewJson(
            input: jsonEncode(_request(status: status)),
            context: context,
          )
          .entries
          .single;
      expect(entry.status, status);
      if (status == 'entered-in-error') {
        expect(entry.previewable, isFalse);
        expect(entry.reasonCodes, contains('fhir.status_entered_in_error'));
      } else {
        expect(entry.previewable, isTrue, reason: status);
      }
    }

    for (final intent in intents) {
      final entry = mapper
          .previewJson(
            input: jsonEncode(_request(intent: intent)),
            context: context,
          )
          .entries
          .single;
      expect(entry.intent, intent);
      expect(entry.previewable, isTrue, reason: intent);
    }
  });

  test('accepts a collection and keeps every request scoped to Patient', () {
    final bundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {'fullUrl': 'urn:uuid:request-1', 'resource': _request()},
        {
          'fullUrl': 'urn:uuid:request-2',
          'resource': _request(
            id: 'synthetic-request-2',
            status: 'on-hold',
            intent: 'plan',
            authoredOn: '2026-09-20T12:00:00Z',
          ),
        },
      ],
    };
    final preview = mapper.previewJson(
      input: jsonEncode(bundle),
      context: context,
    );

    expect(preview.previewable, isTrue);
    expect(preview.entries, hasLength(2));
    expect(preview.entries.map((entry) => entry.status), ['active', 'on-hold']);
    expect(preview.entries.map((entry) => entry.intent), ['order', 'plan']);
    expect(
      preview.entries.every(
        (entry) => entry.subjectReference == context.expectedPatientReference,
      ),
      isTrue,
    );
  });

  test('holds mismatch, modifier and unsupported dosage semantics by path', () {
    final request = _request()
      ..['subject'] = {'reference': 'Patient/other'}
      ..['doNotPerform'] = true
      ..['dosageInstruction'] = [
        {
          'text': 'Source text',
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
        .previewJson(input: jsonEncode(request), context: context)
        .entries
        .single;

    expect(entry.previewable, isFalse);
    expect(entry.reasonCodes, contains('fhir.patient_reference_mismatch'));
    expect(entry.reasonCodes, contains('fhir.unmapped_fields'));
    expect(entry.unmappedPaths, contains('MedicationRequest.doNotPerform'));
    expect(entry.unmappedPaths, contains('MedicationRequest.extension'));
    expect(
      entry.unmappedPaths,
      contains('MedicationRequest.dosageInstruction[0].doseAndRate'),
    );
    expect(entry.dosageTexts, ['Source text']);
  });

  test(
    'previews Medication reference and requester without resolving them',
    () {
      final request = _request()
        ..remove('medicationCodeableConcept')
        ..['medicationReference'] = {
          'reference': 'https://ehr.example.org/fhir/Medication/med-4',
          'display': 'Source medication display',
        };
      final entry = mapper
          .previewJson(input: jsonEncode(request), context: context)
          .entries
          .single;

      expect(entry.previewable, isTrue);
      expect(
        entry.medicationReference,
        'https://ehr.example.org/fhir/Medication/med-4',
      );
      expect(entry.medicationReferenceDisplay, 'Source medication display');
      expect(entry.medicationCodings, isEmpty);
      expect(entry.requesterReference, 'Practitioner/synthetic-requester');
    },
  );

  test('holds duplicate collection identities and non-collection bundles', () {
    final bundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {'fullUrl': 'urn:uuid:same', 'resource': _request()},
        {'fullUrl': 'urn:uuid:same', 'resource': _request()},
      ],
    };
    final duplicate = mapper.previewJson(
      input: jsonEncode(bundle),
      context: context,
    );
    expect(duplicate.previewable, isFalse);
    expect(duplicate.reasonCodes, contains('fhir.bundle_full_url_duplicate'));
    expect(duplicate.reasonCodes, contains('fhir.resource_id_duplicate'));

    final transaction = mapper.previewJson(
      input: jsonEncode({...bundle, 'type': 'transaction'}),
      context: context,
    );
    expect(transaction.previewable, isFalse);
    expect(
      transaction.reasonCodes,
      contains('fhir.bundle_type_not_collection'),
    );
  });

  test('rejects invalid context, wrong choice, and unsupported fields', () {
    final wrongContext = const FhirR4MedicationRequestPreviewContext(
      fhirVersion: '5.0.0',
      jurisdiction: 'Canada',
      expectedPatientReference: 'Patient/bad reference',
    );
    final badRequest = _request()
      ..['intent'] = 'proposal-with-typo'
      ..['medicationReference'] = {'reference': 'Medication/also-present'};
    final preview = mapper.previewJson(
      input: jsonEncode(badRequest),
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
    expect(
      preview.entries.single.reasonCodes,
      contains('fhir.intent_missing_or_unsupported'),
    );
    expect(
      preview.entries.single.reasonCodes,
      contains('fhir.medication_choice_invalid'),
    );
  });

  test(
    'rejects malformed, unsupported, and oversized JSON without echoing it',
    () {
      expect(
        () => mapper.previewJson(input: '{not json', context: context),
        throwsFormatException,
      );
      expect(
        () => mapper.previewJson(
          input: jsonEncode({'resourceType': 'MedicationStatement'}),
          context: context,
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.previewJson(
          input: jsonEncode({
            'resourceType': 'MedicationRequest',
            'padding': List<String>.filled(
              FhirR4MedicationRequestImportPreview.maximumInputBytes,
              'x',
            ).join(),
          }),
          context: context,
        ),
        throwsFormatException,
      );
      final invalid = _request()..['authoredOn'] = '2026-02-30';
      final held = mapper
          .previewJson(input: jsonEncode(invalid), context: context)
          .entries
          .single;
      expect(held.previewable, isFalse);
      expect(held.reasonCodes, contains('fhir.datetime_invalid'));
    },
  );
}

Map<String, Object?> _request({
  String id = 'synthetic-request-1',
  String status = 'active',
  String intent = 'order',
  String authoredOn = '2026-09',
}) => {
  'resourceType': 'MedicationRequest',
  'id': id,
  'meta': {
    'versionId': '3',
    'source': 'https://ehr.example.org/fhir/MedicationRequest/demo',
    'lastUpdated': '2026-09-20T12:05:00Z',
  },
  'status': status,
  'intent': intent,
  'medicationCodeableConcept': {
    'coding': [
      {
        'system': 'https://example.org/code',
        'version': 'synthetic-v1',
        'code': 'med-1',
        'display': 'Synthetic medication',
      },
    ],
    'text': 'Synthetic medication',
  },
  'subject': {'reference': 'Patient/synthetic-1'},
  'authoredOn': authoredOn,
  'requester': {
    'reference': 'Practitioner/synthetic-requester',
    'display': 'Synthetic requester',
  },
  'dosageInstruction': [
    {'text': 'Source instruction text; not parsed.'},
  ],
};
