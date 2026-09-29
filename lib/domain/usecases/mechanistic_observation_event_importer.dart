import 'dart:convert';

import '../entities/mechanistic_event_ledger.dart';
import '../entities/personal_observation_event_ledger.dart';

/// Adds a privacy-minimized owner-observation projection as supplemental
/// events on a mechanistic audit ledger. These events are covered by the
/// ledger/replay digests but remain outside the engine-input binding and are
/// never passed to a recommendation calculation.
final class MechanisticObservationEventImporter {
  const MechanisticObservationEventImporter();

  static const String _revisionId = 'personal_observation_ledger_v2';
  static const String _boundaryNote =
      'Owner observation events are supplemental audit annotations. They do '
      'not extend the engine-input binding or enter conflict, ranking, or '
      'recommendation calculations. UTC instants and declared timezone labels '
      'remain the fallback when explicit local-time evidence is absent.';

  MechanisticEventLedger appendOwnerProjection({
    required MechanisticEventLedger ledger,
    required PersonalObservationEventLedger projection,
  }) {
    if (projection.events.isEmpty) return ledger;
    final syntheticStates = <bool>{
      ...ledger.events.map((event) => event.synthetic),
      ...projection.events.map((event) => event.synthetic),
    };
    if (syntheticStates.length != 1) {
      throw ArgumentError(
        'Synthetic and owner-entered events cannot share a ledger.',
      );
    }

    final sourceDigest = projection.sha256Digest;
    final projectedEvents = projection.events
        .map((event) => _projectEvent(event, sourceDigest))
        .toList(growable: false);
    final existingById = <String, MechanisticLedgerEvent>{
      for (final event in ledger.events) event.id: event,
    };
    final overlaps = projectedEvents
        .where((event) => existingById.containsKey(event.id))
        .toList(growable: false);
    if (overlaps.isNotEmpty) {
      if (overlaps.length != projectedEvents.length) {
        throw StateError('A partial observation import cannot be resumed.');
      }
      for (final event in projectedEvents) {
        final existing = existingById[event.id]!;
        if (!_sameExceptOrder(existing, event)) {
          throw StateError('An imported observation identity has drifted.');
        }
      }
      return ledger;
    }

    final projectedByInstant = <int, List<MechanisticLedgerEvent>>{};
    for (final event in projectedEvents) {
      projectedByInstant
          .putIfAbsent(event.occurredAtUtc.microsecondsSinceEpoch, () => [])
          .add(event);
    }
    final imported = <MechanisticLedgerEvent>[];
    for (final group in projectedByInstant.values) {
      group.sort((left, right) {
        final bySourceOrder = left.orderAtTimestamp.compareTo(
          right.orderAtTimestamp,
        );
        return bySourceOrder != 0 ? bySourceOrder : left.id.compareTo(right.id);
      });
      final timestamp = group.first.occurredAtUtc;
      final existingAtTime = ledger.events
          .where((event) => event.occurredAtUtc == timestamp)
          .toList(growable: false);
      final nextOrder = existingAtTime.isEmpty
          ? null
          : existingAtTime
                    .map((event) => event.orderAtTimestamp)
                    .reduce((left, right) => left > right ? left : right) +
                1;
      for (var index = 0; index < group.length; index++) {
        final event = group[index];
        imported.add(
          _copyWithOrder(
            event,
            nextOrder == null ? event.orderAtTimestamp : nextOrder + index,
          ),
        );
      }
    }

    return MechanisticEventLedger(
      ledgerId: ledger.ledgerId,
      createdAtUtc: ledger.createdAtUtc,
      configurationDigest: ledger.configurationDigest,
      inputBindingSha256: ledger.inputBindingSha256,
      boundary: '${ledger.boundary} $_boundaryNote',
      events: <MechanisticLedgerEvent>[...ledger.events, ...imported],
    );
  }

  MechanisticLedgerEvent _projectEvent(
    PersonalObservationLedgerEvent event,
    String sourceDigest,
  ) {
    final measurements = event.measurements
        .map(_projectMeasurement)
        .toList(growable: false);
    final resolutionEvidence = event.localTimeResolutionEvidence;
    return MechanisticLedgerEvent(
      id: 'observation_${event.eventIdSha256}',
      kind: MechanisticLedgerEventKind.observation,
      originalTimestamp:
          resolutionEvidence?.offsetTimestamp ??
          event.occurredAtUtc.toIso8601String(),
      occurredAtUtc: event.occurredAtUtc,
      timezoneOffsetMinutes: resolutionEvidence?.utcOffsetMinutes ?? 0,
      orderAtTimestamp: event.orderAtTimestamp,
      sourceId: 'personal_observation:${event.source.name}',
      revisionId: _revisionId,
      synthetic: event.synthetic,
      measurements: measurements,
      attributes: <String, String>{
        'declared_timezone': event.declaredTimezone,
        'kind': event.kind.name,
        'label_omitted': '${event.labelOmitted}',
        'observation_status': event.status.name,
        'recorded_at_utc': event.recordedAtUtc.toIso8601String(),
        'source_ledger_sha256': sourceDigest,
        'source_type': event.source.name,
        'timezone_basis': resolutionEvidence == null
            ? 'utc_instant_declared_zone_label_only'
            : 'iana_ruleset_resolved_civil_time_evidence',
        if (resolutionEvidence != null)
          'local_time_resolution_evidence_json': jsonEncode(
            resolutionEvidence.toJson(),
          ),
        if (resolutionEvidence != null)
          'local_time_resolution_evidence_sha256':
              resolutionEvidence.sha256Digest,
        if (event.motorState != null) 'motor_state': event.motorState!.name,
        if (event.posture != null) 'posture': event.posture!.name,
      },
    );
  }

  MechanisticLedgerMeasurement _projectMeasurement(
    PersonalObservationLedgerMeasurement measurement,
  ) {
    final dimension = switch (measurement.dimension) {
      PersonalObservationLedgerDimension.pressure =>
        MechanisticLedgerDimension.pressure,
      PersonalObservationLedgerDimension.ordinalSeverity =>
        MechanisticLedgerDimension.ordinalSeverity,
    };
    final state = switch (measurement.state) {
      PersonalObservationLedgerMeasurementState.known =>
        MechanisticLedgerValueState.known,
      PersonalObservationLedgerMeasurementState.unknown =>
        MechanisticLedgerValueState.unknown,
      PersonalObservationLedgerMeasurementState.notCollected =>
        MechanisticLedgerValueState.notCollected,
    };
    final canonicalValue = switch (state) {
      MechanisticLedgerValueState.known
          when dimension == MechanisticLedgerDimension.pressure =>
        MechanisticUnitConverter.convert(
          value: measurement.originalValue!,
          fromUnit: measurement.originalUnit,
          toUnit: 'mm[Hg]',
          dimension: dimension,
        ),
      MechanisticLedgerValueState.known => measurement.originalValue,
      _ => null,
    };
    return MechanisticLedgerMeasurement(
      id: measurement.id,
      state: state,
      dimension: dimension,
      origin: switch (measurement.origin) {
        PersonalObservationLedgerOrigin.observedOriginal =>
          MechanisticLedgerValueOrigin.observedOriginal,
        PersonalObservationLedgerOrigin.syntheticFixture =>
          MechanisticLedgerValueOrigin.syntheticFixture,
      },
      originalValue: state == MechanisticLedgerValueState.known
          ? measurement.originalValue
          : null,
      originalUnit: measurement.originalUnit,
      canonicalValue: canonicalValue,
      canonicalUnit: dimension == MechanisticLedgerDimension.pressure
          ? 'mm[Hg]'
          : measurement.canonicalUnit,
    );
  }

  bool _sameExceptOrder(
    MechanisticLedgerEvent existing,
    MechanisticLedgerEvent projected,
  ) =>
      _canonicalEventJson(existing) ==
      _canonicalEventJson(_copyWithOrder(projected, existing.orderAtTimestamp));

  MechanisticLedgerEvent _copyWithOrder(
    MechanisticLedgerEvent event,
    int order,
  ) => MechanisticLedgerEvent(
    id: event.id,
    kind: event.kind,
    originalTimestamp: event.originalTimestamp,
    occurredAtUtc: event.occurredAtUtc,
    timezoneOffsetMinutes: event.timezoneOffsetMinutes,
    orderAtTimestamp: order,
    sourceId: event.sourceId,
    revisionId: event.revisionId,
    synthetic: event.synthetic,
    measurements: event.measurements,
    attributes: event.attributes,
    formulation: event.formulation,
    route: event.route,
    compartment: event.compartment,
  );

  String _canonicalEventJson(MechanisticLedgerEvent event) =>
      jsonEncode(event.toJson());
}
