import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_symptom_motor_observation_mapper.dart';

PersonalObservation _symptom({
  required String id,
  required PersonalObservationStatus status,
  int? severity,
  PersonalObservationSource source = PersonalObservationSource.selfReported,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.parse('2026-09-23T08:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-23T08:12:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: source,
  recorderId: 'private-recorder-id',
  status: status,
  symptomLabel: 'Stiffness',
  severity: status == PersonalObservationStatus.recorded ? severity : null,
  notes: 'Private free-text note',
);

PersonalObservation _motor({
  required String id,
  required PersonalObservationStatus status,
  SelfReportedMotorState state = SelfReportedMotorState.uncertain,
  PersonalObservationSource source =
      PersonalObservationSource.caregiverReported,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.parse('2026-09-23T08:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-23T08:12:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: source,
  recorderId: 'private-recorder-id',
  status: status,
  motorState: status == PersonalObservationStatus.recorded ? state : null,
  notes: 'Private free-text note',
);

Map<String, dynamic> _coding(Map<String, dynamic> resource) =>
    (((resource['code'] as Map)['coding'] as List).single
        as Map<String, dynamic>);

void main() {
  const mapper = FhirR4SymptomMotorObservationMapper();

  test('maps a recorded symptom and its unvalidated entered severity', () {
    final resource = mapper.fromObservation(
      _symptom(
        id: 'local-id-1',
        status: PersonalObservationStatus.recorded,
        severity: 0,
      ),
      patientReference: 'Patient/synthetic-1',
    );

    expect(resource['resourceType'], 'Observation');
    expect(resource['status'], 'preliminary');
    expect(resource, isNot(contains('id')));
    expect(resource, isNot(contains('performer')));
    expect(resource['subject'], {'reference': 'Patient/synthetic-1'});
    expect(resource['effectiveDateTime'], '2026-09-23T12:00:00.000Z');
    expect(resource['issued'], '2026-09-23T12:12:00.000Z');
    expect(
      _coding(resource)['system'],
      FhirR4SymptomMotorObservationMapper.codeSystem,
    );
    expect(
      _coding(resource)['version'],
      FhirR4SymptomMotorObservationMapper.codeSystemVersion,
    );
    expect(_coding(resource)['code'], 'symptom');
    expect((resource['code'] as Map)['text'], 'Stiffness');
    final component = (resource['component'] as List).single as Map;
    expect(component['valueInteger'], 0);
    expect(
      (((component['code'] as Map)['coding'] as List).single as Map)['display'],
      contains('not clinically validated'),
    );
    final sourceCoding =
        (((resource['method'] as Map)['coding'] as List).single as Map);
    expect(sourceCoding['code'], 'self-reported');
    expect(
      (resource['note'] as List).single['text'],
      'Original timezone: America/Toronto',
    );
    final json = resource.toString();
    expect(json, isNot(contains('private-recorder-id')));
    expect(json, isNot(contains('Private free-text note')));
  });

  test(
    'maps ON, OFF, and uncertain as custom values without clinical coding',
    () {
      for (final state in SelfReportedMotorState.values) {
        final resource = mapper.fromObservation(
          _motor(
            id: 'motor-${state.name}',
            status: PersonalObservationStatus.recorded,
            state: state,
          ),
          patientReference: 'Patient/synthetic-1',
        );
        final value = resource['valueCodeableConcept'] as Map;
        expect(
          (value['coding'] as List).single['system'],
          FhirR4SymptomMotorObservationMapper.codeSystem,
        );
        expect((value['coding'] as List).single['code'], state.name);
        expect(value['text'], switch (state) {
          SelfReportedMotorState.on => 'ON',
          SelfReportedMotorState.off => 'OFF',
          SelfReportedMotorState.uncertain => 'Uncertain',
        });
        expect(resource, isNot(contains('dataAbsentReason')));
      }
    },
  );

  test('keeps unknown and not-measured distinct without a value', () {
    for (final (status, expectedCode) in [
      (PersonalObservationStatus.unknown, 'unknown'),
      (PersonalObservationStatus.notMeasured, 'not-performed'),
    ]) {
      for (final record in [
        _symptom(id: 'symptom-${status.name}', status: status),
        _motor(id: 'motor-${status.name}', status: status),
      ]) {
        final resource = mapper.fromObservation(
          record,
          patientReference: 'Patient/synthetic-1',
        );
        expect(resource, contains('dataAbsentReason'));
        expect(resource, isNot(contains('valueInteger')));
        expect(resource, isNot(contains('valueCodeableConcept')));
        expect(
          ((((resource['dataAbsentReason'] as Map)['coding'] as List).single
              as Map)['code']),
          expectedCode,
        );
      }
    }
  });

  test('collection is chronological, bounded, and omits internal IDs', () {
    const collectionMapper = FhirR4SymptomMotorObservationCollectionMapper();
    final bundle = collectionMapper.fromObservations([
      _motor(id: 'z-later', status: PersonalObservationStatus.recorded),
      _symptom(id: 'a-earlier', status: PersonalObservationStatus.unknown),
    ], patientReference: 'Patient/synthetic-1');
    final entries = (bundle['entry'] as List)
        .cast<Map<String, dynamic>>()
        .toList();
    final resources = entries
        .map((entry) => entry['resource'] as Map<String, dynamic>)
        .toList();
    expect(bundle['resourceType'], 'Bundle');
    expect(bundle['type'], 'collection');
    expect(resources.map((item) => item['effectiveDateTime']), [
      '2026-09-23T12:00:00.000Z',
      '2026-09-23T12:00:00.000Z',
    ]);
    expect(resources.every((item) => !item.containsKey('id')), isTrue);
    final fullUrls = entries
        .map((entry) => entry['fullUrl'] as String)
        .toList();
    expect(fullUrls.toSet().length, entries.length);
    expect(
      fullUrls,
      everyElement(
        matches(
          RegExp(
            r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      ),
    );
    expect(bundle.toString(), isNot(contains('private-recorder-id')));
    expect(bundle.toString(), isNot(contains('a-earlier')));
  });

  test(
    'rejects invalid references, unsupported types, duplicate IDs, and overflow',
    () {
      const collectionMapper = FhirR4SymptomMotorObservationCollectionMapper();
      final symptom = _symptom(
        id: 'symptom',
        status: PersonalObservationStatus.recorded,
        severity: 5,
      );
      expect(
        () => mapper.fromObservation(symptom, patientReference: 'Patient/'),
        throwsFormatException,
      );
      expect(
        () => mapper.fromObservation(
          _bloodPressure(),
          patientReference: 'Patient/1',
        ),
        throwsFormatException,
      );
      expect(
        () => collectionMapper.fromObservations([
          symptom,
          symptom,
        ], patientReference: 'Patient/1'),
        throwsFormatException,
      );
      expect(
        () => collectionMapper.fromObservations([
          for (var i = 0; i < 13; i++)
            _symptom(
              id: 'symptom-$i',
              status: PersonalObservationStatus.recorded,
              severity: 2,
            ),
        ], patientReference: 'Patient/1'),
        throwsFormatException,
      );
    },
  );
}

PersonalObservation _bloodPressure() => PersonalObservation.create(
  id: 'bp',
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 1, 1),
  recordedAt: DateTime.utc(2026, 1, 1),
  originalTimezone: 'UTC',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'owner',
  status: PersonalObservationStatus.recorded,
  systolic: 120,
  diastolic: 80,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
);
