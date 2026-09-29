import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_statement_collection_mapper.dart';

CareMedicationDiscussionEntry _entry({
  required String id,
  required DateTime recordedAt,
  CareMedicationReportedUse reportedUse =
      CareMedicationReportedUse.reportedCurrent,
  String name = 'User-entered medication name',
  String? doseAndScheduleText = 'as written on the package',
  String recorderId = 'owner-a',
}) => CareMedicationDiscussionEntry(
  id: id,
  name: name,
  category: CareMedicationDiscussionCategory.supplement,
  reportedUse: reportedUse,
  ingredientLabel: 'private ingredient label',
  doseAndScheduleText: doseAndScheduleText,
  question: 'private question for the visit',
  recordedAt: recordedAt,
  recorderId: recorderId,
);

void main() {
  const mapper = FhirR4MedicationStatementCollectionMapper();
  const patientReference = 'Patient/patient-123';

  test('maps self-entered discussion items to bounded R4 statements', () {
    final bundle = mapper.fromEntries(
      [
        _entry(
          id: 'local-current',
          name: 'Name as remembered',
          doseAndScheduleText: 'one tablet at an unclear time',
          recordedAt: DateTime.parse('2026-09-23T10:30:00-04:00'),
        ),
        _entry(
          id: 'local-uncertain',
          reportedUse: CareMedicationReportedUse.uncertain,
          doseAndScheduleText: null,
          recordedAt: DateTime.utc(2026, 9, 23, 13),
        ),
        _entry(
          id: 'local-stopped',
          reportedUse: CareMedicationReportedUse.reportedStopped,
          recordedAt: DateTime.utc(2026, 9, 23, 14),
        ),
      ],
      patientReference: patientReference,
      ownerId: 'owner-a',
    );

    final entries = (bundle['entry'] as List).cast<Map<String, dynamic>>();
    final resources = entries
        .map((entry) => entry['resource'] as Map<String, dynamic>)
        .toList();
    expect(bundle['resourceType'], 'Bundle');
    expect(bundle['type'], 'collection');
    expect(resources, hasLength(3));
    expect(resources.map((resource) => resource['status']), [
      'unknown',
      'stopped',
      'active',
    ]);
    expect(resources.map((resource) => resource['dateAsserted']), [
      '2026-09-23T13:00:00.000Z',
      '2026-09-23T14:00:00.000Z',
      '2026-09-23T14:30:00.000Z',
    ]);
    expect(
      resources.map(
        (resource) =>
            (resource['medicationCodeableConcept']
                as Map<String, dynamic>)['text'],
      ),
      [
        'User-entered medication name',
        'User-entered medication name',
        'Name as remembered',
      ],
    );
    expect(
      resources.map((resource) => (resource['subject'] as Map)['reference']),
      everyElement(patientReference),
    );
    expect(resources[2]['dosage'], [
      {'text': 'one tablet at an unclear time'},
    ]);
    expect(resources.first, isNot(contains('dosage')));
    expect(resources, everyElement(isNot(contains('effectiveDateTime'))));
    expect(resources, everyElement(isNot(contains('informationSource'))));

    final fullUrls = entries
        .map((entry) => entry['fullUrl'] as String)
        .toList();
    expect(fullUrls.toSet(), hasLength(entries.length));
    for (var index = 0; index < entries.length; index++) {
      expect(fullUrls[index], 'urn:uuid:${resources[index]['id']}');
      expect(
        resources[index]['id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }

    final json = bundle.toString();
    expect(json, contains(patientReference));
    expect(json, contains('Name as remembered'));
    expect(json, contains('one tablet at an unclear time'));
    for (final privateText in [
      'local-current',
      'local-uncertain',
      'local-stopped',
      'owner-a',
      'private ingredient label',
      'private question for the visit',
    ]) {
      expect(json, isNot(contains(privateText)));
    }
    expect(json, isNot(contains('"coding"')));
    expect(bundle, isNot(contains('request')));
  });

  test('accepts an explicit absolute HTTPS Patient reference', () {
    final bundle = mapper.fromEntries(
      [_entry(id: 'absolute', recordedAt: DateTime.utc(2026, 9, 23))],
      patientReference: 'https://ehr.example/fhir/Patient/p-123',
      ownerId: 'owner-a',
    );
    final resource =
        (((bundle['entry'] as List).single as Map)['resource'] as Map);
    expect(
      (resource['subject'] as Map)['reference'],
      'https://ehr.example/fhir/Patient/p-123',
    );
  });

  test(
    'rejects empty, oversized, duplicate, foreign-owner, and unsafe input',
    () {
      expect(
        () => mapper.fromEntries(
          [],
          patientReference: patientReference,
          ownerId: 'owner-a',
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.fromEntries(
          [
            for (
              var index = 0;
              index <= FhirR4MedicationStatementCollectionMapper.maximumEntries;
              index++
            )
              _entry(id: 'item-$index', recordedAt: DateTime.utc(2026, 9, 23)),
          ],
          patientReference: patientReference,
          ownerId: 'owner-a',
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.fromEntries(
          [
            _entry(id: 'duplicate', recordedAt: DateTime.utc(2026, 9, 23)),
            _entry(id: 'duplicate', recordedAt: DateTime.utc(2026, 9, 24)),
          ],
          patientReference: patientReference,
          ownerId: 'owner-a',
        ),
        throwsFormatException,
      );
      expect(
        () => mapper.fromEntries(
          [
            _entry(
              id: 'foreign',
              recordedAt: DateTime.utc(2026, 9, 23),
              recorderId: 'owner-b',
            ),
          ],
          patientReference: patientReference,
          ownerId: 'owner-a',
        ),
        throwsFormatException,
      );
      for (final invalidReference in [
        '',
        ' Patient/a',
        'Patient/',
        'Patient/patient_123',
        'http://ehr.example/fhir/Patient/patient-123',
        'https://user@ehr.example/fhir/Patient/patient-123',
        'https://ehr.example/fhir/Patient/patient-123?active=true',
        'https://ehr.example/fhir/Patient/patient-123#fragment',
        'https://ehr.example/fhir/Observation/patient-123',
        'Patient/a\n',
      ]) {
        expect(
          () => mapper.fromEntries(
            [_entry(id: 'valid-entry', recordedAt: DateTime.utc(2026, 9, 23))],
            patientReference: invalidReference,
            ownerId: 'owner-a',
          ),
          throwsFormatException,
          reason: 'Rejected Patient reference: $invalidReference',
        );
      }
      expect(
        () => mapper.fromEntries(
          [_entry(id: 'valid-entry', recordedAt: DateTime.utc(2026, 9, 23))],
          patientReference: patientReference,
          ownerId: ' \n',
        ),
        throwsFormatException,
      );
    },
  );

  test('returns a deeply immutable collection', () {
    final bundle = mapper.fromEntries(
      [_entry(id: 'immutable', recordedAt: DateTime.utc(2026, 9, 23))],
      patientReference: patientReference,
      ownerId: 'owner-a',
    );
    final entries = bundle['entry'] as List;
    final resource = (entries.single as Map)['resource'] as Map;
    final medication = resource['medicationCodeableConcept'] as Map;

    expect(() => bundle['type'] = 'searchset', throwsUnsupportedError);
    expect(() => entries.clear(), throwsUnsupportedError);
    expect(() => resource['status'] = 'stopped', throwsUnsupportedError);
    expect(() => medication['text'] = 'changed', throwsUnsupportedError);
  });
}
