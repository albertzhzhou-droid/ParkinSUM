import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/local_time_resolution.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation_event_ledger.dart';
import 'package:parkinsum_companion/domain/usecases/personal_observation_event_ledger_projector.dart';
import 'package:parkinsum_companion/domain/usecases/timezone_local_time_resolver.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

PersonalObservation _symptom({
  required String id,
  required String recorderId,
  required PersonalObservationStatus status,
  int? severity,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.parse('2026-09-28T12:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-28T12:05:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: recorderId,
  status: status,
  symptomLabel: 'private symptom label $id',
  severity: severity,
  notes: 'private free text $id',
);

PersonalObservation _pressure({
  required String id,
  required PersonalObservationStatus status,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.parse('2026-09-28T13:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-28T13:01:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'owner-a',
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? 120 : null,
  diastolic: status == PersonalObservationStatus.recorded ? 80 : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
);

void main() {
  setUpAll(timezone_data.initializeTimeZones);

  group('PersonalObservationEventLedgerProjector', () {
    test(
      'projects only the owner and omits direct identifiers and free text',
      () {
        final source = <PersonalObservation>[
          _symptom(
            id: 'owner-private-record',
            recorderId: 'owner-a',
            status: PersonalObservationStatus.recorded,
            severity: 0,
          ),
          _symptom(
            id: 'other-owner-record',
            recorderId: 'owner-b',
            status: PersonalObservationStatus.recorded,
            severity: 5,
          ),
          _pressure(
            id: 'pressure-record',
            status: PersonalObservationStatus.recorded,
          ),
        ];

        final ledger = const PersonalObservationEventLedgerProjector().project(
          observations: source,
          ownerId: 'owner-a',
          synthetic: false,
        );
        final encoded = jsonEncode(ledger.toJson());

        expect(ledger.events, hasLength(2));
        expect(encoded, isNot(contains('private symptom label')));
        expect(encoded, isNot(contains('private free text')));
        expect(encoded, isNot(contains('owner-private-record')));
        expect(encoded, isNot(contains('pressure-record')));
        expect(encoded, isNot(contains('other-owner-record')));
        expect(encoded, isNot(contains('owner-a')));
        expect(encoded, isNot(contains('owner-b')));
        expect(encoded, contains('America/Toronto'));
        expect(ledger.events.first.labelOmitted, isTrue);
        expect(ledger.events.first.measurements.single.originalValue, 0);
        expect(
          ledger.events.first.measurements.single.state,
          PersonalObservationLedgerMeasurementState.known,
        );
      },
    );

    test('keeps unknown separate from not measured', () {
      final ledger = const PersonalObservationEventLedgerProjector().project(
        observations: [
          _pressure(
            id: 'unknown-bp',
            status: PersonalObservationStatus.unknown,
          ),
          _pressure(
            id: 'not-measured-bp',
            status: PersonalObservationStatus.notMeasured,
          ),
        ],
        ownerId: 'owner-a',
        synthetic: true,
      );

      expect(
        ledger.events.map((event) => event.measurements.first.state).toSet(),
        <PersonalObservationLedgerMeasurementState>{
          PersonalObservationLedgerMeasurementState.unknown,
          PersonalObservationLedgerMeasurementState.notCollected,
        },
      );
      expect(ledger.events.every((event) => event.synthetic), isTrue);
    });

    test('sorts deterministically and verifies a strict digest round trip', () {
      final records = <PersonalObservation>[
        _pressure(id: 'later', status: PersonalObservationStatus.recorded),
        _symptom(
          id: 'earlier',
          recorderId: 'owner-a',
          status: PersonalObservationStatus.recorded,
          severity: 3,
        ),
      ];
      final projector = const PersonalObservationEventLedgerProjector();
      final first = projector.project(
        observations: records,
        ownerId: 'owner-a',
        synthetic: false,
      );
      final reversed = projector.project(
        observations: records.reversed,
        ownerId: 'owner-a',
        synthetic: false,
      );
      final restored = PersonalObservationEventLedger.fromJson(first.toJson());

      expect(first.sha256Digest, reversed.sha256Digest);
      expect(first.sha256Digest, restored.sha256Digest);
      expect(first.events.first.kind, PersonalObservationKind.symptom);
      final tampered = Map<String, Object?>.of(first.toJson())
        ..['boundary'] = 'changed';
      expect(
        () => PersonalObservationEventLedger.fromJson(tampered),
        throwsFormatException,
      );
    });

    test(
      'binds optional timezone evidence only to its selected owner record',
      () {
        final evidence = const TimezoneLocalTimeResolver().resolve(
          localCivilTime: LocalCivilDateTime(
            year: 2026,
            month: 9,
            day: 28,
            hour: 12,
            minute: 0,
            second: 0,
          ),
          ianaZoneId: 'America/Toronto',
          utcOffsetMinutes: -240,
          foldChoice: LocalTimeFoldChoice.reject,
          snapshot: TimezoneRuleSnapshot(
            database: tz.timeZoneDatabase,
            tzdbRelease: '2025c',
            providerIdentity: 'timezone/0.11.1:data/latest_all',
          ),
        );
        final records = <PersonalObservation>[
          _symptom(
            id: 'evidence-record',
            recorderId: 'owner-a',
            status: PersonalObservationStatus.recorded,
            severity: 2,
          ),
          _symptom(
            id: 'other-owner-record',
            recorderId: 'owner-b',
            status: PersonalObservationStatus.recorded,
            severity: 7,
          ),
        ];
        final projection = const PersonalObservationEventLedgerProjector()
            .project(
              observations: records,
              ownerId: 'owner-a',
              synthetic: false,
              resolutionEvidenceByRecordId:
                  <String, LocalTimeResolutionEvidence>{
                    'evidence-record': evidence,
                  },
            );
        final restored = PersonalObservationEventLedger.fromJson(
          projection.toJson(),
        );
        final encoded = jsonEncode(restored.toJson());

        expect(restored.events, hasLength(1));
        expect(
          restored.events.single.localTimeResolutionEvidence!.sha256Digest,
          evidence.sha256Digest,
        );
        expect(encoded, isNot(contains('evidence-record')));
        expect(encoded, isNot(contains('owner-a')));
        expect(encoded, isNot(contains('other-owner-record')));
        expect(
          () => const PersonalObservationEventLedgerProjector().project(
            observations: records,
            ownerId: 'owner-a',
            synthetic: false,
            resolutionEvidenceByRecordId: <String, LocalTimeResolutionEvidence>{
              'other-owner-record': evidence,
            },
          ),
          throwsArgumentError,
        );
      },
    );

    test('uses the bounded NIST pressure conversion factor', () {
      expect(
        PersonalObservationLedgerUnitConverter.convertPressure(
          value: 1,
          fromUnit: 'kPa',
          toUnit: 'mm[Hg]',
        ),
        closeTo(7.500615, 1e-12),
      );
      expect(
        PersonalObservationLedgerUnitConverter.convertPressure(
          value: 7.500615,
          fromUnit: 'mmHg',
          toUnit: 'kPa',
        ),
        closeTo(1, 1e-12),
      );
      expect(
        () => PersonalObservationLedgerUnitConverter.convertPressure(
          value: 1,
          fromUnit: 'psi',
          toUnit: 'mm[Hg]',
        ),
        throwsArgumentError,
      );
    });
  });
}
