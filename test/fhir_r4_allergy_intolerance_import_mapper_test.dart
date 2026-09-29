import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r4_allergy_intolerance_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_allergy_intolerance_import_mapper.dart';

void main() {
  const mapper = FhirR4AllergyIntoleranceImportMapper();
  const context = FhirR4AllergyPreviewContext(
    fhirVersion: '4.0.1',
    jurisdiction: 'CA',
    expectedPatientReference: 'Patient/synthetic-1',
  );

  test('projects distinct statuses, source coding, and lexical dates', () {
    final preview = mapper.previewJson(
      input: jsonEncode(_resource()),
      context: context,
    );
    final entry = preview.entries.single;

    expect(preview.previewable, isTrue);
    expect(preview.containerType, 'AllergyIntolerance');
    expect(preview.inputSha256, hasLength(64));
    expect(entry.clinicalStatus!.codings.single.code, 'active');
    expect(entry.patientReferenceMatched, isTrue);
    expect(entry.verificationStatus!.codings.single.code, 'unconfirmed');
    expect(entry.clinicalStatus, isNot(same(entry.verificationStatus)));
    expect(entry.type, 'allergy');
    expect(entry.category, ['medication']);
    expect(entry.criticality, 'unable-to-assess');
    expect(entry.code!.codings.single.system, 'https://example.org/substances');
    expect(entry.code!.codings.single.code, 'substance-1');
    expect(entry.onset!.lexical, '2026-09');
    expect(entry.onset!.precision, FhirR4AllergyTimePrecision.month);
    expect(entry.recordedDate!.precision, FhirR4AllergyTimePrecision.day);
    expect(
      entry.reactions.single.manifestations.single.codings.single.code,
      'rash-1',
    );
    expect(entry.reactions.single.severity, 'mild');
    expect(FhirR4AllergyIntoleranceImportPreview.persistsData, isFalse);
    expect(FhirR4AllergyIntoleranceImportPreview.algorithmEligible, isFalse);
  });

  test('accepts the required status codes without merging their meanings', () {
    const clinical = ['active', 'inactive', 'resolved'];
    const verification = ['unconfirmed', 'confirmed', 'refuted'];
    for (final code in clinical) {
      final entry = mapper
          .previewJson(
            input: jsonEncode(
              _resource(clinicalStatus: code, verificationStatus: 'confirmed'),
            ),
            context: context,
          )
          .entries
          .single;
      expect(entry.clinicalStatus!.codings.single.code, code);
      expect(entry.verificationStatus!.codings.single.code, 'confirmed');
      expect(entry.previewable, isTrue);
    }
    for (final code in verification) {
      final entry = mapper
          .previewJson(
            input: jsonEncode(
              _resource(clinicalStatus: 'inactive', verificationStatus: code),
            ),
            context: context,
          )
          .entries
          .single;
      expect(entry.clinicalStatus!.codings.single.code, 'inactive');
      expect(entry.verificationStatus!.codings.single.code, code);
      expect(entry.previewable, isTrue);
    }
  });

  test('holds entered-in-error and enforces its clinicalStatus constraint', () {
    final withoutClinical = _resource(verificationStatus: 'entered-in-error')
      ..remove('clinicalStatus');
    final held = mapper
        .previewJson(input: jsonEncode(withoutClinical), context: context)
        .entries
        .single;
    expect(held.verificationStatus!.codings.single.code, 'entered-in-error');
    expect(held.clinicalStatus, isNull);
    expect(held.previewable, isFalse);
    expect(held.reasonCodes, contains('fhir.verification_entered_in_error'));

    final invalid = mapper
        .previewJson(
          input: jsonEncode(_resource(verificationStatus: 'entered-in-error')),
          context: context,
        )
        .entries
        .single;
    expect(invalid.previewable, isFalse);
    expect(
      invalid.reasonCodes,
      contains('fhir.entered_in_error_clinical_status_forbidden'),
    );
  });

  test('requires the R4 status value sets and exact Patient scope', () {
    final resource = _resource()
      ..['clinicalStatus'] = _status('https://example.org/status', 'active')
      ..['verificationStatus'] = _status(
        'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification',
        'confirmed',
      )
      ..['patient'] = {'reference': 'Patient/other'};
    final entry = mapper
        .previewJson(input: jsonEncode(resource), context: context)
        .entries
        .single;
    expect(entry.previewable, isFalse);
    expect(entry.reasonCodes, contains('fhir.clinical_status_binding_invalid'));
    expect(entry.reasonCodes, contains('fhir.patient_reference_mismatch'));
    expect(entry.patientReferenceMatched, isFalse);
    expect(entry.verificationStatus!.codings.single.code, 'confirmed');
  });

  test(
    'holds unknown, known-but-unprojected, and narrative reaction fields',
    () {
      final resource = _resource()
        ..['extension'] = [
          {'url': 'https://example.org/extension', 'valueString': 'synthetic'},
        ]
        ..['unexpectedField'] = true;
      final reaction =
          (resource['reaction'] as List).single as Map<String, Object?>;
      reaction['description'] = 'Synthetic narrative only';
      reaction['note'] = [
        {'text': 'Synthetic note'},
      ];
      final entry = mapper
          .previewJson(input: jsonEncode(resource), context: context)
          .entries
          .single;
      expect(entry.previewable, isFalse);
      expect(entry.reasonCodes, contains('fhir.unmapped_fields'));
      expect(entry.unmappedPaths, contains('AllergyIntolerance.extension'));
      expect(
        entry.unmappedPaths,
        contains('AllergyIntolerance.unexpectedField'),
      );
      expect(
        entry.unmappedPaths,
        contains('AllergyIntolerance.reaction[0].description'),
      );
      expect(
        entry.unmappedPaths,
        contains('AllergyIntolerance.reaction[0].note'),
      );
    },
  );

  test('collection bundle is bounded and retains entry scope', () {
    final bundle = {
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {
          'fullUrl': 'urn:uuid:synthetic-1',
          'resource': _resource(id: 'synthetic-allergy-1'),
        },
        {
          'fullUrl': 'urn:uuid:synthetic-2',
          'resource': _resource(
            id: 'synthetic-allergy-2',
            clinicalStatus: 'resolved',
            verificationStatus: 'refuted',
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
    expect(
      preview.entries.map((entry) => entry.clinicalStatus!.codings.single.code),
      ['active', 'resolved'],
    );
    expect(
      preview.entries.map(
        (entry) => entry.verificationStatus!.codings.single.code,
      ),
      ['unconfirmed', 'refuted'],
    );
    expect(preview.entries.every((entry) => entry.previewable), isTrue);

    final oversized = mapper.previewJson(
      input: jsonEncode({
        ...bundle,
        'entry': List.generate(
          FhirR4AllergyIntoleranceImportPreview.maximumEntries + 1,
          (index) => {'resource': _resource(id: 'synthetic-allergy-$index')},
        ),
      }),
      context: context,
    );
    expect(oversized.entries, isEmpty);
    expect(
      oversized.reasonCodes,
      contains('fhir.bundle_entry_count_out_of_bounds'),
    );
  });

  test(
    'holds date-choice conflicts, malformed dates, and bad bundle shape',
    () {
      final resource = _resource()
        ..['onsetAge'] = {'value': 4, 'unit': 'years'}
        ..['recordedDate'] = '2026-02-30';
      final entry = mapper
          .previewJson(input: jsonEncode(resource), context: context)
          .entries
          .single;
      expect(entry.previewable, isFalse);
      expect(entry.reasonCodes, contains('fhir.onset_choice_conflict'));
      expect(entry.reasonCodes, contains('fhir.date_time_invalid'));
      expect(entry.unmappedPaths, contains('AllergyIntolerance.onsetAge'));

      final transaction = mapper.previewJson(
        input: jsonEncode({
          'resourceType': 'Bundle',
          'type': 'transaction',
          'entry': [
            {'resource': _resource()},
          ],
        }),
        context: context,
      );
      expect(transaction.previewable, isFalse);
      expect(
        transaction.reasonCodes,
        contains('fhir.bundle_type_not_collection'),
      );
    },
  );

  test('invalid context and malformed or oversized input fail closed', () {
    final wrongContext = const FhirR4AllergyPreviewContext(
      fhirVersion: '5.0.0',
      jurisdiction: 'Canada',
      expectedPatientReference: 'Patient/bad reference',
    );
    final preview = mapper.previewJson(
      input: jsonEncode(_resource()),
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
      () => mapper.previewJson(input: '{not json', context: context),
      throwsFormatException,
    );
    expect(
      () => mapper.previewJson(
        input:
            ' ' * (FhirR4AllergyIntoleranceImportPreview.maximumInputBytes + 1),
        context: context,
      ),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _resource({
  String id = 'synthetic-allergy-1',
  String clinicalStatus = 'active',
  String verificationStatus = 'unconfirmed',
}) => {
  'resourceType': 'AllergyIntolerance',
  'id': id,
  'clinicalStatus': _status(
    'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',
    clinicalStatus,
  ),
  'verificationStatus': _status(
    'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification',
    verificationStatus,
  ),
  'type': 'allergy',
  'category': ['medication'],
  'criticality': 'unable-to-assess',
  'code': {
    'coding': [
      {
        'system': 'https://example.org/substances',
        'version': 'synthetic-v1',
        'code': 'substance-1',
        'display': 'Synthetic substance',
      },
    ],
  },
  'patient': {'reference': 'Patient/synthetic-1'},
  'onsetDateTime': '2026-09',
  'recordedDate': '2026-09-20',
  'lastOccurrence': '2026-09-20T12:00:00Z',
  'reaction': [
    {
      'manifestation': [
        {
          'coding': [
            {
              'system': 'https://example.org/findings',
              'code': 'rash-1',
              'display': 'Synthetic rash',
            },
          ],
        },
      ],
      'onset': '2026-09-20T12:00:00Z',
      'severity': 'mild',
    },
  ],
};

Map<String, Object?> _status(String system, String code) => {
  'coding': [
    {'system': system, 'code': code},
  ],
};
