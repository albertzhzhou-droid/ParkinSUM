import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/symptom_motor_observation_projection.dart';

PersonalObservation _symptom(
  String id,
  int minute, {
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  int? severity = 4,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.utc(2026, 1, 1, 0, minute),
  recordedAt: DateTime.utc(2026, 1, 1, 1, minute),
  originalTimezone: 'UTC',
  source: PersonalObservationSource.selfReported,
  recorderId: 'synthetic-owner',
  status: status,
  symptomLabel: 'Stiffness',
  severity: status == PersonalObservationStatus.recorded ? severity : null,
);

PersonalObservation _motor(String id, int minute) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.utc(2026, 1, 1, 0, minute),
  recordedAt: DateTime.utc(2026, 1, 1, 1, minute),
  originalTimezone: 'UTC',
  source: PersonalObservationSource.selfReported,
  recorderId: 'synthetic-owner',
  status: PersonalObservationStatus.recorded,
  motorState: SelfReportedMotorState.uncertain,
);

PersonalObservation _bloodPressure(String id) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 1, 1),
  recordedAt: DateTime.utc(2026, 1, 1),
  originalTimezone: 'UTC',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'synthetic-owner',
  status: PersonalObservationStatus.recorded,
  systolic: 120,
  diastolic: 80,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
);

void main() {
  test('filters BP and sorts by occurrence, record time, and ID', () {
    final projection = SymptomMotorObservationProjection.fromObservations([
      _symptom('same-b', 2),
      _bloodPressure('bp'),
      _motor('earlier', 1),
      _symptom('same-c', 2),
      _symptom('same-a', 2),
    ]);

    expect(projection.observations.map((item) => item.id), [
      'earlier',
      'same-a',
      'same-b',
      'same-c',
    ]);
    expect(projection.omittedObservationCount, 0);
  });

  test('bounds the sequence and retains unknown and not-measured records', () {
    final records = [
      for (var minute = 0; minute < 12; minute++)
        _symptom('symptom-$minute', minute),
      _symptom(
        'symptom-not-measured',
        12,
        status: PersonalObservationStatus.notMeasured,
      ),
      _symptom(
        'symptom-unknown',
        13,
        status: PersonalObservationStatus.unknown,
      ),
    ];
    final projection = SymptomMotorObservationProjection.fromObservations(
      records,
    );

    expect(
      projection.observations,
      hasLength(SymptomMotorObservationProjection.maximumVisibleObservations),
    );
    expect(projection.omittedObservationCount, 2);
    expect(projection.observations.first.id, 'symptom-2');
    expect(projection.observations.last.id, 'symptom-unknown');
    expect(projection.recordedCount, 10);
    expect(projection.notMeasuredCount, 1);
    expect(projection.unknownCount, 1);
  });

  test('empty inputs produce an empty, immutable projection', () {
    final projection = SymptomMotorObservationProjection.fromObservations([
      _bloodPressure('only-bp'),
    ]);
    expect(projection.observations, isEmpty);
    expect(projection.omittedObservationCount, 0);
  });
}
