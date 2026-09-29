import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/local_time_resolution.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_event_ledger.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_authorization.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_observation_event_importer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_capsule_service.dart';
import 'package:parkinsum_companion/domain/usecases/personal_observation_event_ledger_projector.dart';
import 'package:parkinsum_companion/domain/usecases/timezone_local_time_resolver.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  const importer = MechanisticObservationEventImporter();

  setUpAll(timezone_data.initializeTimeZones);

  test(
    'imports privacy-minimized observations as supplemental replay events',
    () {
      final snapshot = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );
      final at = snapshot.eventLedger.events.first.occurredAtUtc;
      final projection = const PersonalObservationEventLedgerProjector()
          .project(
            observations: <PersonalObservation>[
              _symptom(
                id: 'private-symptom-zero',
                recorderId: 'owner-a',
                occurredAt: at,
                status: PersonalObservationStatus.recorded,
                severity: 0,
              ),
              _symptom(
                id: 'private-symptom-unknown',
                recorderId: 'owner-a',
                occurredAt: at,
                status: PersonalObservationStatus.unknown,
              ),
              _pressure(
                id: 'private-pressure-record',
                recorderId: 'owner-a',
                occurredAt: at,
                status: PersonalObservationStatus.recorded,
              ),
              _pressure(
                id: 'private-pressure-not-collected',
                recorderId: 'owner-a',
                occurredAt: at,
                status: PersonalObservationStatus.notMeasured,
              ),
              _motorState(
                id: 'private-motor-state',
                recorderId: 'owner-a',
                occurredAt: at,
              ),
              _symptom(
                id: 'other-owner-private-record',
                recorderId: 'owner-b',
                occurredAt: at,
                status: PersonalObservationStatus.recorded,
                severity: 8,
              ),
            ],
            ownerId: 'owner-a',
            synthetic: true,
          );

      final imported = importer.appendOwnerProjection(
        ledger: snapshot.eventLedger,
        projection: projection,
      );
      final observationEvents = imported.events
          .where(
            (event) => event.kind == MechanisticLedgerEventKind.observation,
          )
          .toList(growable: false);
      final encoded = jsonEncode(imported.toJson());

      expect(observationEvents, hasLength(5));
      expect(
        imported.inputBindingSha256,
        snapshot.eventLedger.inputBindingSha256,
      );
      expect(
        imported.canonicalReplayDigest,
        isNot(snapshot.eventLedger.canonicalReplayDigest),
      );
      expect(encoded, isNot(contains('private-symptom-zero')));
      expect(encoded, isNot(contains('private-pressure-record')));
      expect(encoded, isNot(contains('owner-a')));
      expect(encoded, isNot(contains('owner-b')));
      expect(encoded, isNot(contains('private free text')));

      final zero = observationEvents.singleWhere(
        (event) =>
            event.attributes['kind'] == PersonalObservationKind.symptom.name &&
            event.attributes['observation_status'] ==
                PersonalObservationStatus.recorded.name,
      );
      expect(
        zero.measurements.single.dimension,
        MechanisticLedgerDimension.ordinalSeverity,
      );
      expect(zero.measurements.single.canonicalValue, 0);
      expect(zero.measurements.single.state, MechanisticLedgerValueState.known);
      expect(zero.attributes['declared_timezone'], 'America/Toronto');
      expect(zero.timezoneOffsetMinutes, 0);
      expect(zero.originalTimestamp, endsWith('Z'));

      final unknown = observationEvents.singleWhere(
        (event) =>
            event.attributes['kind'] == PersonalObservationKind.symptom.name &&
            event.attributes['observation_status'] ==
                PersonalObservationStatus.unknown.name,
      );
      expect(
        unknown.measurements.single.state,
        MechanisticLedgerValueState.unknown,
      );
      final notCollected = observationEvents.singleWhere(
        (event) =>
            event.attributes['observation_status'] ==
            PersonalObservationStatus.notMeasured.name,
      );
      expect(
        notCollected.measurements.first.state,
        MechanisticLedgerValueState.notCollected,
      );
      final pressure = observationEvents.singleWhere(
        (event) =>
            event.attributes['kind'] ==
                PersonalObservationKind.bloodPressure.name &&
            event.attributes['observation_status'] ==
                PersonalObservationStatus.recorded.name,
      );
      expect(
        pressure.measurements.first.dimension,
        MechanisticLedgerDimension.pressure,
      );
      expect(pressure.measurements.first.canonicalValue, 120);
      expect(pressure.measurements.first.canonicalUnit, 'mm[Hg]');
      final motor = observationEvents.singleWhere(
        (event) =>
            event.attributes['kind'] ==
            PersonalObservationKind.selfReportedMotorState.name,
      );
      expect(
        motor.attributes['motor_state'],
        SelfReportedMotorState.uncertain.name,
      );
      expect(motor.measurements, isEmpty);

      final importedAgain = importer.appendOwnerProjection(
        ledger: imported,
        projection: projection,
      );
      expect(importedAgain.sha256Digest, imported.sha256Digest);
    },
  );

  test(
    'carries explicit timezone evidence through supplemental replay only',
    () {
      final snapshot = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );
      final evidence = const TimezoneLocalTimeResolver().resolve(
        localCivilTime: LocalCivilDateTime(
          year: 2026,
          month: 11,
          day: 1,
          hour: 1,
          minute: 30,
          second: 0,
        ),
        ianaZoneId: 'America/Toronto',
        utcOffsetMinutes: -300,
        foldChoice: LocalTimeFoldChoice.later,
        snapshot: TimezoneRuleSnapshot(
          database: tz.timeZoneDatabase,
          tzdbRelease: '2025c',
          providerIdentity: 'timezone/0.11.1:data/latest_all',
        ),
      );
      final projection = const PersonalObservationEventLedgerProjector()
          .project(
            observations: <PersonalObservation>[
              _symptom(
                id: 'evidence-only-record',
                recorderId: 'owner-a',
                occurredAt: DateTime.utc(2026, 11, 1, 6, 30),
                status: PersonalObservationStatus.recorded,
                severity: 3,
              ),
            ],
            ownerId: 'owner-a',
            synthetic: true,
            resolutionEvidenceByRecordId: <String, LocalTimeResolutionEvidence>{
              'evidence-only-record': evidence,
            },
          );
      final augmented = importer.appendOwnerProjection(
        ledger: snapshot.eventLedger,
        projection: projection,
      );
      final observation = augmented.events.singleWhere(
        (event) => event.kind == MechanisticLedgerEventKind.observation,
      );
      final restoredEvent = MechanisticLedgerEvent.fromJson(
        observation.toJson(),
      );
      final tamperedEvent = Map<String, Object?>.of(observation.toJson());
      final tamperedAttributes = Map<String, String>.from(
        (tamperedEvent['attributes']! as Map).cast<String, String>(),
      );
      final evidenceJson =
          jsonDecode(tamperedAttributes['local_time_resolution_evidence_json']!)
              as Map<String, Object?>;
      evidenceJson['iana_zone_id'] = 'America/New_York';
      tamperedAttributes['local_time_resolution_evidence_json'] = jsonEncode(
        evidenceJson,
      );
      tamperedEvent['attributes'] = tamperedAttributes;

      expect(observation.originalTimestamp, '2026-11-01T01:30:00.000-05:00');
      expect(observation.timezoneOffsetMinutes, -300);
      expect(evidence.foldWasAmbiguous, isTrue);
      expect(evidence.foldChoice, LocalTimeFoldChoice.later);
      expect(
        observation.attributes['timezone_basis'],
        'iana_ruleset_resolved_civil_time_evidence',
      );
      expect(
        observation.attributes['local_time_resolution_evidence_sha256'],
        evidence.sha256Digest,
      );
      expect(restoredEvent.originalTimestamp, observation.originalTimestamp);
      expect(
        augmented.inputBindingSha256,
        snapshot.eventLedger.inputBindingSha256,
      );
      expect(
        () => MechanisticLedgerEvent.fromJson(tamperedEvent),
        throwsFormatException,
      );

      final replay = const MechanisticReplayCapsuleService().captureAndRestore(
        capsuleId: 'timezone_evidence_replay',
        generatedAtUtc: DateTime.utc(2026, 9, 29),
        ledger: augmented,
        context: snapshot.context,
        mealCompositionsById: <String, MealComposition>{
          snapshot.composition.id: snapshot.composition,
        },
        expectedConfigurationSha256:
            snapshot.configurationIdentity.sha256Digest,
      );
      expect(
        replay.restored.ledger.events
            .singleWhere(
              (event) => event.kind == MechanisticLedgerEventKind.observation,
            )
            .attributes['local_time_resolution_evidence_sha256'],
        evidence.sha256Digest,
      );
      expect(
        replay.restored.ledger.inputBindingSha256,
        snapshot.eventLedger.inputBindingSha256,
      );
    },
  );

  test(
    'keeps unit, missingness, replay, and authorization boundaries intact',
    () {
      expect(
        MechanisticUnitConverter.convert(
          value: 16,
          fromUnit: 'kPa',
          toUnit: 'mm[Hg]',
          dimension: MechanisticLedgerDimension.pressure,
        ),
        closeTo(120.00984, 1e-10),
      );
      expect(
        () => MechanisticUnitConverter.convert(
          value: 16,
          fromUnit: 'kPa',
          toUnit: 'mg',
          dimension: MechanisticLedgerDimension.pressure,
        ),
        throwsArgumentError,
      );

      final snapshot = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );
      final occurredAt = snapshot.eventLedger.events.first.occurredAtUtc;
      final projection = const PersonalObservationEventLedgerProjector()
          .project(
            observations: <PersonalObservation>[
              _symptom(
                id: 'round-trip-observation',
                recorderId: 'owner-a',
                occurredAt: occurredAt,
                status: PersonalObservationStatus.recorded,
                severity: 4,
              ),
            ],
            ownerId: 'owner-a',
            synthetic: true,
          );
      final augmented = importer.appendOwnerProjection(
        ledger: snapshot.eventLedger,
        projection: projection,
      );
      final compositions = <String, MealComposition>{
        snapshot.composition.id: snapshot.composition,
      };
      final replay = const MechanisticReplayCapsuleService().captureAndRestore(
        capsuleId: 'observation_import_replay',
        generatedAtUtc: DateTime.utc(2026, 9, 29),
        ledger: augmented,
        context: snapshot.context,
        mealCompositionsById: compositions,
        expectedConfigurationSha256:
            snapshot.configurationIdentity.sha256Digest,
      );
      expect(
        replay.restored.ledger.canonicalReplayDigest,
        augmented.canonicalReplayDigest,
      );
      expect(
        replay.restored.ledger.events.where(
          (event) => event.kind == MechanisticLedgerEventKind.observation,
        ),
        hasLength(1),
      );
      expect(replay.restored.context.toJson(), snapshot.context.toJson());
      expect(
        replay.restored.mealCompositionsById.keys,
        contains(snapshot.composition.id),
      );

      final authorization = const MechanisticEventLedgerAuthorizationService()
          .authorize(
            ledger: replay.restored.ledger,
            context: replay.restored.context,
            mealCompositionsById: replay.restored.mealCompositionsById,
            expectedConfigurationSha256:
                snapshot.configurationIdentity.sha256Digest,
          );
      expect(authorization.authorized, isTrue);
      expect(authorization.view!.context.toJson(), snapshot.context.toJson());
    },
  );

  test('rejects mixing synthetic fixtures with owner-entered observations', () {
    final snapshot = AlgorithmObservatoryService().build(
      ObservatoryScenario.mixedReference,
    );
    final projection = const PersonalObservationEventLedgerProjector().project(
      observations: <PersonalObservation>[
        _symptom(
          id: 'observed-not-synthetic',
          recorderId: 'owner-a',
          occurredAt: snapshot.eventLedger.events.first.occurredAtUtc,
          status: PersonalObservationStatus.recorded,
          severity: 1,
        ),
      ],
      ownerId: 'owner-a',
      synthetic: false,
    );
    expect(
      () => importer.appendOwnerProjection(
        ledger: snapshot.eventLedger,
        projection: projection,
      ),
      throwsArgumentError,
    );
    expect(
      () => MechanisticLedgerMeasurement(
        id: 'pressure_digest_drift',
        state: MechanisticLedgerValueState.known,
        dimension: MechanisticLedgerDimension.pressure,
        origin: MechanisticLedgerValueOrigin.observedOriginal,
        originalValue: 16,
        originalUnit: 'kPa',
        canonicalValue: 120,
        canonicalUnit: 'mm[Hg]',
      ),
      throwsArgumentError,
    );
  });
}

PersonalObservation _symptom({
  required String id,
  required String recorderId,
  required DateTime occurredAt,
  required PersonalObservationStatus status,
  int? severity,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: occurredAt,
  recordedAt: occurredAt.add(const Duration(minutes: 5)),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: recorderId,
  status: status,
  symptomLabel: 'private symptom label',
  severity: severity,
  notes: 'private free text',
);

PersonalObservation _pressure({
  required String id,
  required String recorderId,
  required DateTime occurredAt,
  required PersonalObservationStatus status,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: occurredAt,
  recordedAt: occurredAt.add(const Duration(minutes: 5)),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.deviceManual,
  recorderId: recorderId,
  status: status,
  systolic: status == PersonalObservationStatus.recorded ? 120 : null,
  diastolic: status == PersonalObservationStatus.recorded ? 80 : null,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.sitting,
);

PersonalObservation _motorState({
  required String id,
  required String recorderId,
  required DateTime occurredAt,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: occurredAt,
  recordedAt: occurredAt.add(const Duration(minutes: 5)),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: recorderId,
  status: PersonalObservationStatus.recorded,
  motorState: SelfReportedMotorState.uncertain,
);
