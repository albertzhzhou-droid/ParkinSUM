import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/blood_pressure_trend_projection.dart';

PersonalObservation _bloodPressure(
  String id,
  int minute, {
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  double? systolic = 120,
  double? diastolic = 80,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 1, 1, 0, minute),
  recordedAt: DateTime.utc(2026, 1, 1, 1, minute),
  originalTimezone: 'UTC',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'synthetic-owner',
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? systolic : null,
  diastolic: status == PersonalObservationStatus.recorded ? diastolic : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.unknown,
);

PersonalObservation _motorRecord() => PersonalObservation.create(
  id: 'motor',
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.utc(2026, 1, 1),
  recordedAt: DateTime.utc(2026, 1, 1),
  originalTimezone: 'UTC',
  source: PersonalObservationSource.selfReported,
  recorderId: 'synthetic-owner',
  status: PersonalObservationStatus.recorded,
  motorState: SelfReportedMotorState.on,
);

void main() {
  test('filters blood pressure and sorts by event, record time, then ID', () {
    final projection = BloodPressureTrendProjection.fromObservations([
      _bloodPressure('same-b', 2),
      _motorRecord(),
      _bloodPressure('later', 3),
      _bloodPressure('same-c', 2),
      _bloodPressure('same-a', 2),
    ]);

    expect(projection.observations.map((item) => item.id), [
      'same-a',
      'same-b',
      'same-c',
      'later',
    ]);
    expect(projection.omittedObservationCount, 0);
  });

  test('bounds the view and preserves unknown and not-measured states', () {
    final records = [
      for (var minute = 0; minute < 12; minute++)
        _bloodPressure('bp-$minute', minute),
      _bloodPressure(
        'bp-12',
        12,
        status: PersonalObservationStatus.notMeasured,
      ),
      _bloodPressure('bp-13', 13, status: PersonalObservationStatus.unknown),
    ];
    final projection = BloodPressureTrendProjection.fromObservations(records);

    expect(
      projection.observations,
      hasLength(BloodPressureTrendProjection.maximumVisibleObservations),
    );
    expect(projection.omittedObservationCount, 2);
    expect(projection.observations.first.id, 'bp-2');
    expect(projection.observations.last.id, 'bp-13');
    expect(projection.recordedCount, 10);
    expect(projection.notMeasuredCount, 1);
    expect(projection.unknownCount, 1);
    expect(
      projection.recordedObservations.map((item) => item.id),
      isNot(contains('bp-12')),
    );
  });

  test(
    'does not turn absent values into zero or include other observations',
    () {
      final projection = BloodPressureTrendProjection.fromObservations([
        _motorRecord(),
        _bloodPressure('unknown', 1, status: PersonalObservationStatus.unknown),
        _bloodPressure(
          'not-measured',
          2,
          status: PersonalObservationStatus.notMeasured,
        ),
      ]);

      expect(projection.observations, hasLength(2));
      expect(projection.recordedObservations, isEmpty);
      expect(
        projection.observations.map((item) => [item.systolic, item.diastolic]),
        everyElement([null, null]),
      );
      expect(projection.omittedObservationCount, 0);
    },
  );
}
