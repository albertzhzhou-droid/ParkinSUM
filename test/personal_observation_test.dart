import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';

PersonalObservation _symptom({
  int? severity,
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
}) => PersonalObservation.create(
  id: 'observation-1',
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.utc(2026, 9, 21, 14),
  recordedAt: DateTime.utc(2026, 9, 22, 10),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'demo-owner',
  status: status,
  symptomLabel: 'Tremor',
  severity: severity,
);

void main() {
  test(
    'round trip retains original instants, provenance and unknown versus true zero',
    () {
      final missing = _symptom();
      final zero = _symptom(severity: 0);
      final decoded = PersonalObservation.fromJson(missing.toJson());
      expect(decoded.severity, isNull);
      expect(decoded.occurredAt, DateTime.utc(2026, 9, 21, 14));
      expect(decoded.recordedAt, DateTime.utc(2026, 9, 22, 10));
      expect(decoded.originalTimezone, 'America/Toronto');
      expect(decoded.recorderId, 'demo-owner');
      expect(PersonalObservation.fromJson(zero.toJson()).severity, 0);
      expect(decoded.toJson(), missing.toJson());
    },
  );

  test(
    'absent and malformed timestamps are rejected instead of replaced with now',
    () {
      for (final bad in [
        null,
        '',
        '2026-09-22',
        '2026-09-22T09:30:00',
        '2026-02-30T09:30:00Z',
        '2026-09-22T25:30:00Z',
        '2026-09-22T09:30:00+14:30',
      ]) {
        final json = _symptom().toJson()..['occurredAt'] = bad;
        expect(
          () => PersonalObservation.fromJson(json),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(
        PersonalObservation.parseExplicitTimestamp('2026-09-22T09:30:00-04:00'),
        DateTime.utc(2026, 9, 22, 13, 30),
      );
    },
  );

  test('unknown status retains no measured value and labels remain usable', () {
    final json = _symptom(status: PersonalObservationStatus.unknown).toJson();
    expect(PersonalObservation.fromJson(json).summary(), 'Tremor · Unknown');
    expect(
      () => _symptom(severity: 0, status: PersonalObservationStatus.unknown),
      throwsFormatException,
    );
    expect(() => _symptom(severity: -1), throwsFormatException);
    expect(() => _symptom(severity: 11), throwsFormatException);
    expect(
      () =>
          PersonalObservation.fromJson(_symptom().toJson()..['severity'] = 2.5),
      throwsFormatException,
    );
  });

  test(
    'schema, enum, provenance and unrelated measurement fields fail closed',
    () {
      for (final change in <String, dynamic>{
        'schemaVersion': 2,
        'kind': 'diagnosis',
        'source': 'inferred',
        'status': 'normal',
        'originalTimezone': 'local',
        'recorderId': '',
        'unit': 'mm[Hg]',
        'newField': true,
      }.entries) {
        expect(
          () => PersonalObservation.fromJson(
            _symptom().toJson()..[change.key] = change.value,
          ),
          throwsFormatException,
          reason: change.key,
        );
      }
    },
  );

  test('blood pressure requires finite positive pairs and exact UCUM unit', () {
    PersonalObservation pressure(
      double? systolic,
      double? diastolic, {
      String unit = 'mm[Hg]',
      PersonalObservationStatus status = PersonalObservationStatus.recorded,
      BloodPressurePosture posture = BloodPressurePosture.unknown,
    }) => PersonalObservation.create(
      id: 'bp-1',
      kind: PersonalObservationKind.bloodPressure,
      occurredAt: DateTime.utc(2026, 9, 22),
      recordedAt: DateTime.utc(2026, 9, 22, 1),
      originalTimezone: 'UTC+00:00',
      source: PersonalObservationSource.deviceManual,
      recorderId: 'demo-owner',
      status: status,
      systolic: systolic,
      diastolic: diastolic,
      unit: unit,
      posture: posture,
    );
    final value = pressure(120, 80);
    expect(PersonalObservation.fromJson(value.toJson()).systolic, 120);
    expect(value.summary(), 'Blood pressure · 120 / 80 mmHg · Posture unknown');
    expect(
      pressure(
        120,
        80,
        posture: BloodPressurePosture.sitting,
      ).summary(chinese: true),
      '血压 · 120 / 80 mmHg · 坐位',
    );
    expect(
      pressure(120, 80, posture: BloodPressurePosture.standing).summary(),
      'Blood pressure · 120 / 80 mmHg · Standing',
    );
    for (final bad in [null, 0.0, -1.0, double.nan, double.infinity]) {
      expect(() => pressure(bad, 80), throwsFormatException);
    }
    expect(() => pressure(120, 80, unit: 'mmHg'), throwsFormatException);
    final absent = pressure(
      null,
      null,
      status: PersonalObservationStatus.notMeasured,
    );
    expect(PersonalObservation.fromJson(absent.toJson()).diastolic, isNull);
  });

  test('ON/OFF is an explicit self-report and unknown does not infer OFF', () {
    final json = _symptom().toJson()
      ..['kind'] = 'selfReportedMotorState'
      ..['symptomLabel'] = null
      ..['motorState'] = 'uncertain';
    final value = PersonalObservation.fromJson(json);
    expect(value.motorState, SelfReportedMotorState.uncertain);
    expect(value.summary(), 'Self-reported motor state · Uncertain');
    expect(
      () => PersonalObservation.fromJson({...json, 'motorState': null}),
      throwsFormatException,
    );
    final unknown = PersonalObservation.fromJson({
      ...json,
      'status': 'unknown',
      'motorState': null,
    });
    expect(unknown.motorState, isNull);
  });
}
