import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/local_time_resolution.dart';
import '../entities/personal_observation.dart';
import '../entities/personal_observation_event_ledger.dart';

/// Projects only the active account holder's saved observations into a local
/// audit view. The result is never passed to a recommendation or prediction.
final class PersonalObservationEventLedgerProjector {
  const PersonalObservationEventLedgerProjector();

  PersonalObservationEventLedger project({
    required Iterable<PersonalObservation> observations,
    required String ownerId,
    required bool synthetic,
    Map<String, LocalTimeResolutionEvidence> resolutionEvidenceByRecordId =
        const <String, LocalTimeResolutionEvidence>{},
  }) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError('An active owner is required for projection.');
    }
    final selected = observations
        .where((observation) => observation.recorderId == ownerId)
        .toList();
    final selectedRecordIds = selected
        .map((observation) => observation.id)
        .toSet();
    if (resolutionEvidenceByRecordId.keys.any(
      (recordId) => !selectedRecordIds.contains(recordId),
    )) {
      throw ArgumentError(
        'Local time evidence must reference selected owner records.',
      );
    }
    final identityByRecord = <PersonalObservation, String>{
      for (final observation in selected)
        observation: _eventIdentity(ownerId, observation.id),
    };
    selected.sort((left, right) {
      final byOccurrence = left.occurredAt.compareTo(right.occurredAt);
      if (byOccurrence != 0) return byOccurrence;
      final byRecorded = left.recordedAt.compareTo(right.recordedAt);
      if (byRecorded != 0) return byRecorded;
      return identityByRecord[left]!.compareTo(identityByRecord[right]!);
    });

    final orderByOccurrence = <int, int>{};
    final events = <PersonalObservationLedgerEvent>[];
    final seenIdentities = <String>{};
    for (final observation in selected) {
      final eventIdentity = identityByRecord[observation]!;
      if (!seenIdentities.add(eventIdentity)) {
        throw const FormatException(
          'Duplicate owner observation identity cannot be projected.',
        );
      }
      final occurredAtUtc = observation.occurredAt.toUtc();
      final instantKey = occurredAtUtc.microsecondsSinceEpoch;
      final order = orderByOccurrence.update(
        instantKey,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      events.add(
        _event(
          observation,
          eventIdentity,
          occurredAtUtc,
          order,
          synthetic,
          resolutionEvidenceByRecordId[observation.id],
        ),
      );
    }
    return PersonalObservationEventLedger(events: events);
  }

  PersonalObservationLedgerEvent _event(
    PersonalObservation observation,
    String eventIdentity,
    DateTime occurredAtUtc,
    int orderAtTimestamp,
    bool synthetic,
    LocalTimeResolutionEvidence? localTimeResolutionEvidence,
  ) {
    final origin = synthetic
        ? PersonalObservationLedgerOrigin.syntheticFixture
        : PersonalObservationLedgerOrigin.observedOriginal;
    final measurements = <PersonalObservationLedgerMeasurement>[];
    SelfReportedMotorState? motorState;
    BloodPressurePosture? posture;
    switch (observation.kind) {
      case PersonalObservationKind.symptom:
        final knownSeverity =
            observation.status == PersonalObservationStatus.recorded &&
            observation.severity != null;
        measurements.add(
          PersonalObservationLedgerMeasurement(
            id: 'severity',
            state: _measurementState(
              observation.status,
              hasRecordedValue: knownSeverity,
              recordedValueMissingIsUnknown: true,
            ),
            dimension: PersonalObservationLedgerDimension.ordinalSeverity,
            origin: origin,
            originalValue: knownSeverity
                ? observation.severity!.toDouble()
                : null,
            originalUnit: 'severity_0_to_10',
            canonicalValue: knownSeverity
                ? observation.severity!.toDouble()
                : null,
            canonicalUnit: 'severity_0_to_10',
          ),
        );
      case PersonalObservationKind.selfReportedMotorState:
        motorState = observation.motorState;
      case PersonalObservationKind.bloodPressure:
        posture = observation.posture;
        final isRecorded =
            observation.status == PersonalObservationStatus.recorded;
        final originalUnit = observation.unit!;
        final systolic = observation.systolic;
        final diastolic = observation.diastolic;
        measurements.addAll(<PersonalObservationLedgerMeasurement>[
          _pressureMeasurement(
            id: 'systolic',
            value: isRecorded ? systolic : null,
            unit: originalUnit,
            status: observation.status,
            origin: origin,
          ),
          _pressureMeasurement(
            id: 'diastolic',
            value: isRecorded ? diastolic : null,
            unit: originalUnit,
            status: observation.status,
            origin: origin,
          ),
        ]);
    }
    return PersonalObservationLedgerEvent(
      eventIdSha256: eventIdentity,
      kind: observation.kind,
      status: observation.status,
      source: observation.source,
      occurredAtUtc: occurredAtUtc,
      recordedAtUtc: observation.recordedAt.toUtc(),
      declaredTimezone: observation.originalTimezone,
      orderAtTimestamp: orderAtTimestamp,
      synthetic: synthetic,
      labelOmitted: observation.kind == PersonalObservationKind.symptom,
      measurements: measurements,
      localTimeResolutionEvidence: localTimeResolutionEvidence,
      motorState: motorState,
      posture: posture,
    );
  }

  PersonalObservationLedgerMeasurement _pressureMeasurement({
    required String id,
    required double? value,
    required String unit,
    required PersonalObservationStatus status,
    required PersonalObservationLedgerOrigin origin,
  }) {
    final isKnown = status == PersonalObservationStatus.recorded;
    return PersonalObservationLedgerMeasurement(
      id: id,
      state: _measurementState(
        status,
        hasRecordedValue: isKnown && value != null,
        recordedValueMissingIsUnknown: false,
      ),
      dimension: PersonalObservationLedgerDimension.pressure,
      origin: origin,
      originalValue: isKnown ? value : null,
      originalUnit: unit,
      canonicalValue: isKnown
          ? PersonalObservationLedgerUnitConverter.convertPressure(
              value: value!,
              fromUnit: unit,
              toUnit: PersonalObservation.bloodPressureUnit,
            )
          : null,
      canonicalUnit: PersonalObservation.bloodPressureUnit,
    );
  }

  PersonalObservationLedgerMeasurementState _measurementState(
    PersonalObservationStatus status, {
    required bool hasRecordedValue,
    required bool recordedValueMissingIsUnknown,
  }) => switch (status) {
    PersonalObservationStatus.unknown =>
      PersonalObservationLedgerMeasurementState.unknown,
    PersonalObservationStatus.notMeasured =>
      PersonalObservationLedgerMeasurementState.notCollected,
    PersonalObservationStatus.recorded when hasRecordedValue =>
      PersonalObservationLedgerMeasurementState.known,
    PersonalObservationStatus.recorded when recordedValueMissingIsUnknown =>
      PersonalObservationLedgerMeasurementState.unknown,
    PersonalObservationStatus.recorded => throw const FormatException(
      'A recorded measurement is missing a required value.',
    ),
  };

  String _eventIdentity(String ownerId, String recordId) =>
      sha256.convert(utf8.encode('$ownerId\u0000$recordId')).toString();
}
