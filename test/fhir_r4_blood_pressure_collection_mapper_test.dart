import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/blood_pressure_trend_projection.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_blood_pressure_collection_mapper.dart';

PersonalObservation _pressure({
  required String id,
  required DateTime occurredAt,
  required DateTime recordedAt,
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: occurredAt,
  recordedAt: recordedAt,
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'private-recorder-id',
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? 120 : null,
  diastolic: status == PersonalObservationStatus.recorded ? 80 : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
  notes: 'private free-text note',
);

PersonalObservation _symptom() => PersonalObservation.create(
  id: 'symptom-1',
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.utc(2026, 9, 20, 13),
  recordedAt: DateTime.utc(2026, 9, 20, 13, 2),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'private-recorder-id',
  status: PersonalObservationStatus.recorded,
  symptomLabel: 'Tremor',
);

void main() {
  const mapper = FhirR4BloodPressureCollectionMapper();
  const patientReference = 'Patient/patient-123';
  final early = DateTime.utc(2026, 9, 20, 13);
  final late = DateTime.utc(2026, 9, 20, 14);

  test('creates a bounded collection Bundle in deterministic time order', () {
    final bundle = mapper.fromObservations([
      _pressure(id: 'bp-late', occurredAt: late, recordedAt: late),
      _pressure(id: 'bp-early', occurredAt: early, recordedAt: early),
      _pressure(
        id: 'bp-tie',
        occurredAt: early,
        recordedAt: early.add(const Duration(minutes: 1)),
      ),
    ], patientReference: patientReference);
    final entries = (bundle['entry'] as List).cast<Map<String, dynamic>>();
    final resources = entries
        .map((entry) => entry['resource'] as Map<String, dynamic>)
        .toList();

    expect(bundle['resourceType'], 'Bundle');
    expect(bundle['type'], 'collection');
    expect(resources.map((resource) => resource['effectiveDateTime']), [
      early.toIso8601String(),
      early.toIso8601String(),
      late.toIso8601String(),
    ]);
    expect(resources.map((resource) => resource['issued']), [
      early.toIso8601String(),
      early.add(const Duration(minutes: 1)).toIso8601String(),
      late.toIso8601String(),
    ]);
    expect(
      resources,
      everyElement(containsPair('resourceType', 'Observation')),
    );
    expect(
      resources.map((resource) => (resource['subject'] as Map)['reference']),
      everyElement(patientReference),
    );
    final fullUrls = entries
        .map((entry) => entry['fullUrl'] as String)
        .toList();
    expect(fullUrls.toSet().length, entries.length);
    for (var index = 0; index < entries.length; index++) {
      final resource = resources[index];
      expect(fullUrls[index].split(':').last, resource['id']);
      expect(
        resource['id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
    expect(bundle.toString(), isNot(contains('bp-early')));
    expect(bundle.toString(), isNot(contains('bp-tie')));
    expect(bundle.toString(), isNot(contains('bp-late')));
    expect(bundle.keys, containsAll(['resourceType', 'type', 'entry']));
    expect(bundle, isNot(contains('request')));
  });

  test('retains unknown and not-measured entries and absent reasons', () {
    final bundle = mapper.fromObservations([
      _pressure(
        id: 'bp-unknown',
        occurredAt: early,
        recordedAt: early,
        status: PersonalObservationStatus.unknown,
      ),
      _pressure(
        id: 'bp-not-measured',
        occurredAt: late,
        recordedAt: late,
        status: PersonalObservationStatus.notMeasured,
      ),
    ], patientReference: patientReference);
    final resources = (bundle['entry'] as List)
        .map((entry) => (entry as Map)['resource'] as Map)
        .toList();

    expect(
      resources.map(
        (resource) =>
            (((resource['dataAbsentReason'] as Map)['coding'] as List).first
                as Map)['code'],
      ),
      ['unknown', 'not-performed'],
    );
  });

  test('rejects empty, oversized, duplicate, and invalid inputs', () {
    expect(
      () => mapper.fromObservations([], patientReference: patientReference),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservations(
        List.generate(
          FhirR4BloodPressureCollectionMapper.maximumEntries + 1,
          (index) => _pressure(
            id: 'bp-$index',
            occurredAt: early.add(Duration(minutes: index)),
            recordedAt: early.add(Duration(minutes: index)),
          ),
        ),
        patientReference: patientReference,
      ),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservations([
        _pressure(id: 'bp-duplicate', occurredAt: early, recordedAt: early),
        _pressure(id: 'bp-duplicate', occurredAt: late, recordedAt: late),
      ], patientReference: patientReference),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservations([
        _pressure(id: 'bp-1', occurredAt: early, recordedAt: early),
      ], patientReference: 'Patient/'),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservations([
        _symptom(),
      ], patientReference: patientReference),
      throwsFormatException,
    );
  });

  test('deep-freezes the bundle and nested observation resources', () {
    final bundle = mapper.fromObservations([
      _pressure(id: 'bp-1', occurredAt: early, recordedAt: early),
    ], patientReference: patientReference);
    final entries = bundle['entry'] as List;
    final resource = (entries.single as Map)['resource'] as Map;

    expect(() => bundle['type'] = 'transaction', throwsUnsupportedError);
    expect(() => entries.add(const {}), throwsUnsupportedError);
    expect(() => resource['status'] = 'final', throwsUnsupportedError);
    expect(bundle.toString(), isNot(contains('private-recorder-id')));
    expect(bundle.toString(), isNot(contains('private free-text note')));
  });

  test('collection limit matches the timeline trend window', () {
    expect(
      FhirR4BloodPressureCollectionMapper.maximumEntries,
      BloodPressureTrendProjection.maximumVisibleObservations,
    );
  });
}
