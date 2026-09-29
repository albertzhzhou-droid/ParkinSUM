import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_blood_pressure_mapper.dart';

PersonalObservation _pressure({
  String id = 'bp-1',
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  double? systolic = 120,
  double? diastolic = 80,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.parse('2026-09-20T09:30:00-04:00'),
  recordedAt: DateTime.parse('2026-09-20T09:32:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'private-recorder-id',
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? systolic : null,
  diastolic: status == PersonalObservationStatus.recorded ? diastolic : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
  notes: 'private free-text note',
);

PersonalObservation _symptom() => PersonalObservation.create(
  id: 'symptom-1',
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.utc(2026, 9, 20, 13, 30),
  recordedAt: DateTime.utc(2026, 9, 20, 13, 32),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'recorder-1',
  status: PersonalObservationStatus.recorded,
  symptomLabel: 'Tremor',
);

void main() {
  const mapper = FhirR4BloodPressureMapper();

  test('maps only explicit blood-pressure facts to the R4 BP profile', () {
    final mapped = mapper.fromObservation(
      _pressure(),
      patientReference: 'Patient/patient-123',
    );
    final components = mapped['component'] as List<dynamic>;
    final systolic = components[0] as Map<String, dynamic>;
    final diastolic = components[1] as Map<String, dynamic>;

    expect(mapped['resourceType'], 'Observation');
    expect(
      FhirR4BloodPressureMapper.schemaUri,
      'parkinsum.fhir-r4-bp-mapper/2',
    );
    expect(FhirR4BloodPressureMapper.loincVersion, '2.83');
    expect(FhirR4BloodPressureMapper.ucumSpecificationVersion, '2.2');
    expect(mapped['meta'], {
      'profile': [FhirR4BloodPressureMapper.bloodPressureProfile],
    });
    expect(mapped['status'], 'preliminary');
    final panelCoding = ((mapped['code'] as Map)['coding'] as List).single;
    expect(panelCoding['system'], 'http://loinc.org');
    expect(panelCoding['code'], '85354-9');
    expect(panelCoding['version'], '2.83');
    expect((mapped['subject'] as Map)['reference'], 'Patient/patient-123');
    expect(mapped['effectiveDateTime'], '2026-09-20T13:30:00.000Z');
    expect(mapped['issued'], '2026-09-20T13:32:00.000Z');
    final systolicCoding = ((systolic['code'] as Map)['coding'] as List).single;
    final diastolicCoding =
        ((diastolic['code'] as Map)['coding'] as List).single;
    expect(systolicCoding['system'], 'http://loinc.org');
    expect(systolicCoding['code'], '8480-6');
    expect(systolicCoding['version'], '2.83');
    expect(diastolicCoding['system'], 'http://loinc.org');
    expect(diastolicCoding['code'], '8462-4');
    expect(diastolicCoding['version'], '2.83');
    expect(systolic['valueQuantity'], {
      'value': 120,
      'unit': 'mmHg',
      'system': 'http://unitsofmeasure.org',
      'code': 'mm[Hg]',
    });
    expect(systolic['valueQuantity'], isNot(contains('version')));
    expect(diastolic['valueQuantity'], containsPair('value', 80));
    expect(mapped.toString(), isNot(contains('private-recorder-id')));
    expect(mapped.toString(), isNot(contains('private free-text note')));
    expect(mapped.toString(), contains('originalTimezone=America/Toronto'));
  });

  test(
    'keeps unknown and not measured distinct using standard absent reasons',
    () {
      for (final (status, reason) in [
        (PersonalObservationStatus.unknown, 'unknown'),
        (PersonalObservationStatus.notMeasured, 'not-performed'),
      ]) {
        final mapped = mapper.fromObservation(
          _pressure(status: status),
          patientReference: 'Patient/patient-123',
        );
        final components = mapped['component'] as List<dynamic>;

        expect(
          (((mapped['dataAbsentReason'] as Map)['coding'] as List).first
              as Map)['code'],
          reason,
        );
        for (final component in components.cast<Map<String, dynamic>>()) {
          expect(component, isNot(contains('valueQuantity')));
          expect(
            (((component['dataAbsentReason'] as Map)['coding'] as List).first
                as Map)['code'],
            reason,
          );
        }
      }
    },
  );

  test('rejects implicit, malformed, or unsupported source facts', () {
    expect(
      () => mapper.fromObservation(_pressure(), patientReference: 'Patient/'),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservation(
        _pressure(),
        patientReference: 'http://example.org/Patient/123',
      ),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservation(
        _pressure(id: 'bp with spaces'),
        patientReference: 'Patient/patient-123',
      ),
      throwsFormatException,
    );
    expect(
      () => mapper.fromObservation(
        _symptom(),
        patientReference: 'Patient/patient-123',
      ),
      throwsFormatException,
    );
  });

  test('freezes nested FHIR maps and lists', () {
    final mapped = mapper.fromObservation(
      _pressure(),
      patientReference: 'Patient/patient-123',
    );

    expect(() => mapped['status'] = 'final', throwsUnsupportedError);
    expect(
      () => (mapped['component'] as List).add(const {}),
      throwsUnsupportedError,
    );
    expect(
      () => (mapped['subject'] as Map)['reference'] = 'Patient/other',
      throwsUnsupportedError,
    );
  });
}
