import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_personal_observation_collection_mapper.dart';

PersonalObservation _bloodPressure({
  required String id,
  required int minute,
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 9, 23, 12, minute),
  recordedAt: DateTime.utc(2026, 9, 23, 13, minute),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'private-recorder-id',
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? 120 : null,
  diastolic: status == PersonalObservationStatus.recorded ? 80 : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
  notes: 'private blood-pressure note',
);

PersonalObservation _symptom({
  required String id,
  required int minute,
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.utc(2026, 9, 23, 12, minute),
  recordedAt: DateTime.utc(2026, 9, 23, 13, minute),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'private-recorder-id',
  status: status,
  symptomLabel: 'Stiffness',
  severity: status == PersonalObservationStatus.recorded ? 4 : null,
  notes: 'private symptom note',
);

PersonalObservation _motor({
  required String id,
  required int minute,
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.utc(2026, 9, 23, 12, minute),
  recordedAt: DateTime.utc(2026, 9, 23, 13, minute),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'private-recorder-id',
  status: status,
  motorState: status == PersonalObservationStatus.recorded
      ? SelfReportedMotorState.off
      : null,
  notes: 'private motor-state note',
);

void main() {
  const mapper = FhirR4PersonalObservationCollectionMapper();
  const patientReference = 'Patient/patient-123';

  test('combines supported kinds in time order with one Patient reference', () {
    final bundle = mapper.fromObservations([
      _bloodPressure(id: 'local-bp-3', minute: 3),
      _motor(id: 'local-motor-2', minute: 2),
      _symptom(id: 'local-symptom-1', minute: 1),
    ], patientReference: patientReference);

    final entries = (bundle['entry'] as List).cast<Map<String, dynamic>>();
    final resources = entries
        .map((entry) => entry['resource'] as Map<String, dynamic>)
        .toList();
    expect(bundle['resourceType'], 'Bundle');
    expect(bundle['type'], 'collection');
    expect(resources.map((resource) => resource['effectiveDateTime']), [
      '2026-09-23T12:01:00.000Z',
      '2026-09-23T12:02:00.000Z',
      '2026-09-23T12:03:00.000Z',
    ]);
    expect(
      resources.map((resource) => (resource['subject'] as Map)['reference']),
      everyElement(patientReference),
    );
    expect(
      resources.map((resource) => resource['resourceType']),
      everyElement('Observation'),
    );
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
    expect(json, contains('85354-9'));
    expect(json, contains('parkinsum-personal-observation'));
    expect(json, contains(patientReference));
    expect(json, isNot(contains('local-bp-3')));
    expect(json, isNot(contains('local-motor-2')));
    expect(json, isNot(contains('local-symptom-1')));
    expect(json, isNot(contains('private-recorder-id')));
    expect(json, isNot(contains('private blood-pressure note')));
    expect(json, isNot(contains('private symptom note')));
    expect(json, isNot(contains('private motor-state note')));
    expect(bundle.keys, containsAll(['resourceType', 'type', 'entry']));
    expect(bundle, isNot(contains('request')));
  });

  test(
    'preserves unknown and not-measured states across the combined bundle',
    () {
      final bundle = mapper.fromObservations([
        _bloodPressure(
          id: 'bp-unknown',
          minute: 1,
          status: PersonalObservationStatus.unknown,
        ),
        _symptom(
          id: 'symptom-not-measured',
          minute: 2,
          status: PersonalObservationStatus.notMeasured,
        ),
      ], patientReference: patientReference);
      final resources = (bundle['entry'] as List)
          .cast<Map<String, dynamic>>()
          .map((entry) => entry['resource'] as Map<String, dynamic>)
          .toList();

      expect(resources, everyElement(contains('dataAbsentReason')));
      expect(resources, everyElement(isNot(contains('valueInteger'))));
      expect(resources, everyElement(isNot(contains('valueCodeableConcept'))));
      expect(
        (((resources[0]['dataAbsentReason'] as Map)['coding'] as List).single
            as Map)['code'],
        'unknown',
      );
      expect(
        (((resources[1]['dataAbsentReason'] as Map)['coding'] as List).single
            as Map)['code'],
        'not-performed',
      );
    },
  );

  test('accepts the full 12 plus 12 bounded window', () {
    final observations = <PersonalObservation>[
      for (var index = 0; index < 12; index++) ...[
        _bloodPressure(id: 'bp-$index', minute: index),
        _symptom(id: 'symptom-$index', minute: index),
      ],
    ];
    final bundle = mapper.fromObservations(
      observations,
      patientReference: patientReference,
    );

    expect(FhirR4PersonalObservationCollectionMapper.maximumEntries, 24);
    expect(bundle['entry'], hasLength(24));
  });

  test(
    'rejects empty input, invalid references, duplicates, and per-kind overflow',
    () {
      expect(
        () => mapper.fromObservations([], patientReference: patientReference),
        throwsFormatException,
      );
      expect(
        () => mapper.fromObservations([
          _symptom(id: 'symptom', minute: 1),
        ], patientReference: 'Patient/'),
        throwsFormatException,
      );
      expect(
        () => mapper.fromObservations([
          _bloodPressure(id: 'shared-id', minute: 1),
          _symptom(id: 'shared-id', minute: 2),
        ], patientReference: patientReference),
        throwsFormatException,
      );
      expect(
        () => mapper.fromObservations([
          for (var index = 0; index < 13; index++)
            _bloodPressure(id: 'bp-$index', minute: index),
        ], patientReference: patientReference),
        throwsFormatException,
      );
      expect(
        () => mapper.fromObservations([
          for (var index = 0; index < 13; index++)
            _symptom(id: 'symptom-$index', minute: index),
        ], patientReference: patientReference),
        throwsFormatException,
      );
    },
  );

  test('returns a deeply immutable collection', () {
    final bundle = mapper.fromObservations([
      _bloodPressure(id: 'bp', minute: 1),
    ], patientReference: patientReference);
    final entries = bundle['entry'] as List;
    final resource = (entries.single as Map)['resource'] as Map;

    expect(() => bundle['type'] = 'searchset', throwsUnsupportedError);
    expect(() => entries.clear(), throwsUnsupportedError);
    expect(() => resource['status'] = 'final', throwsUnsupportedError);
  });
}
