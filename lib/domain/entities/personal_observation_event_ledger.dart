import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'local_time_resolution.dart';
import 'personal_observation.dart';

const int personalObservationEventLedgerSchemaVersion = 2;
const String personalObservationEventLedgerSchema =
    'parkinsum.personal-observation-event-ledger/2';
const String personalObservationEventLedgerBoundary =
    'Read-only owner-record projection. Free-text labels, notes, recorder IDs, and owner IDs are omitted. Optional caller-supplied local-time resolution evidence is bound per event. No network, persistence, clinical interpretation, or algorithm input.';

enum PersonalObservationLedgerMeasurementState { known, unknown, notCollected }

enum PersonalObservationLedgerDimension { pressure, ordinalSeverity }

enum PersonalObservationLedgerOrigin { observedOriginal, syntheticFixture }

/// A unit-bearing measurement in the local, read-only observation projection.
final class PersonalObservationLedgerMeasurement {
  PersonalObservationLedgerMeasurement({
    required this.id,
    required this.state,
    required this.dimension,
    required this.origin,
    required this.originalUnit,
    required this.canonicalUnit,
    this.originalValue,
    this.canonicalValue,
  }) {
    _validate();
  }

  final String id;
  final PersonalObservationLedgerMeasurementState state;
  final PersonalObservationLedgerDimension dimension;
  final PersonalObservationLedgerOrigin origin;
  final double? originalValue;
  final String originalUnit;
  final double? canonicalValue;
  final String canonicalUnit;

  void _validate() {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id)) {
      throw ArgumentError('Invalid observation measurement identity.');
    }
    if (originalUnit.trim().isEmpty || canonicalUnit.trim().isEmpty) {
      throw ArgumentError('Observation measurements require explicit units.');
    }
    if ((originalValue != null && !originalValue!.isFinite) ||
        (canonicalValue != null && !canonicalValue!.isFinite)) {
      throw ArgumentError('Observation measurement values must be finite.');
    }
    if (state == PersonalObservationLedgerMeasurementState.known) {
      if (originalValue == null || canonicalValue == null) {
        throw ArgumentError('Known observations require both values.');
      }
    } else if (originalValue != null || canonicalValue != null) {
      throw ArgumentError('Missing observations cannot carry point values.');
    }
    if (dimension == PersonalObservationLedgerDimension.pressure &&
        (!PersonalObservationLedgerUnitConverter.supportsPressureUnit(
              originalUnit,
            ) ||
            canonicalUnit != PersonalObservation.bloodPressureUnit ||
            (state == PersonalObservationLedgerMeasurementState.known &&
                (originalValue! <= 0 || canonicalValue! <= 0)))) {
      throw ArgumentError('Unsupported pressure unit.');
    }
    if (dimension == PersonalObservationLedgerDimension.ordinalSeverity &&
        (originalUnit != 'severity_0_to_10' ||
            canonicalUnit != 'severity_0_to_10' ||
            (state == PersonalObservationLedgerMeasurementState.known &&
                (originalValue! < 0 ||
                    originalValue! > 10 ||
                    originalValue!.truncateToDouble() != originalValue ||
                    canonicalValue != originalValue)))) {
      throw ArgumentError('Unsupported ordinal severity unit.');
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'state': state.name,
    'dimension': dimension.name,
    'origin': origin.name,
    'original_value': originalValue,
    'original_unit': originalUnit,
    'canonical_value': canonicalValue,
    'canonical_unit': canonicalUnit,
  };

  factory PersonalObservationLedgerMeasurement.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const <String>{
      'id',
      'state',
      'dimension',
      'origin',
      'original_value',
      'original_unit',
      'canonical_value',
      'canonical_unit',
    }, 'observation measurement');
    return PersonalObservationLedgerMeasurement(
      id: _string(json['id'], 'measurement.id'),
      state: _enumByName(
        PersonalObservationLedgerMeasurementState.values,
        json['state'],
        'measurement.state',
      ),
      dimension: _enumByName(
        PersonalObservationLedgerDimension.values,
        json['dimension'],
        'measurement.dimension',
      ),
      origin: _enumByName(
        PersonalObservationLedgerOrigin.values,
        json['origin'],
        'measurement.origin',
      ),
      originalValue: _nullableDouble(
        json['original_value'],
        'measurement.original_value',
      ),
      originalUnit: _string(json['original_unit'], 'measurement.original_unit'),
      canonicalValue: _nullableDouble(
        json['canonical_value'],
        'measurement.canonical_value',
      ),
      canonicalUnit: _string(
        json['canonical_unit'],
        'measurement.canonical_unit',
      ),
    );
  }
}

/// One owner-entered record with stable, hashed identity and no free text.
final class PersonalObservationLedgerEvent {
  PersonalObservationLedgerEvent({
    required this.eventIdSha256,
    required this.kind,
    required this.status,
    required this.source,
    required this.occurredAtUtc,
    required this.recordedAtUtc,
    required this.declaredTimezone,
    required this.orderAtTimestamp,
    required this.synthetic,
    required this.labelOmitted,
    required List<PersonalObservationLedgerMeasurement> measurements,
    this.localTimeResolutionEvidence,
    this.motorState,
    this.posture,
  }) : measurements = List<PersonalObservationLedgerMeasurement>.unmodifiable(
         measurements,
       ) {
    _validate();
  }

  final String eventIdSha256;
  final PersonalObservationKind kind;
  final PersonalObservationStatus status;
  final PersonalObservationSource source;
  final DateTime occurredAtUtc;
  final DateTime recordedAtUtc;
  final String declaredTimezone;
  final int orderAtTimestamp;
  final bool synthetic;
  final bool labelOmitted;
  final List<PersonalObservationLedgerMeasurement> measurements;
  final LocalTimeResolutionEvidence? localTimeResolutionEvidence;
  final SelfReportedMotorState? motorState;
  final BloodPressurePosture? posture;

  void _validate() {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(eventIdSha256)) {
      throw ArgumentError('Observation event identity must be SHA-256.');
    }
    if (!occurredAtUtc.isUtc || !recordedAtUtc.isUtc) {
      throw ArgumentError('Observation event instants must be UTC.');
    }
    if (!PersonalObservation.isExplicitTimezone(declaredTimezone)) {
      throw ArgumentError('Observation timezone must remain explicit.');
    }
    if (localTimeResolutionEvidence case final evidence?) {
      if (evidence.ianaZoneId != declaredTimezone ||
          evidence.resolvedAtUtc != occurredAtUtc) {
        throw ArgumentError(
          'Local time evidence must match the observation zone and instant.',
        );
      }
    }
    if (orderAtTimestamp < 0) {
      throw ArgumentError('Observation order must be non-negative.');
    }
    if (measurements.map((item) => item.id).toSet().length !=
        measurements.length) {
      throw ArgumentError('Observation measurement identities must be unique.');
    }
    final expectedOrigin = synthetic
        ? PersonalObservationLedgerOrigin.syntheticFixture
        : PersonalObservationLedgerOrigin.observedOriginal;
    if (measurements.any((item) => item.origin != expectedOrigin)) {
      throw ArgumentError('Observation and measurement origins must agree.');
    }
    switch (kind) {
      case PersonalObservationKind.symptom:
        if (!labelOmitted ||
            motorState != null ||
            posture != null ||
            measurements.length != 1 ||
            measurements.single.id != 'severity') {
          throw ArgumentError('Symptom projection fields are invalid.');
        }
        final severity = measurements.single;
        if (severity.dimension !=
            PersonalObservationLedgerDimension.ordinalSeverity) {
          throw ArgumentError('Symptom severity dimension is invalid.');
        }
        if (status == PersonalObservationStatus.unknown &&
            severity.state !=
                PersonalObservationLedgerMeasurementState.unknown) {
          throw ArgumentError('Unknown symptom status must remain unknown.');
        }
        if (status == PersonalObservationStatus.notMeasured &&
            severity.state !=
                PersonalObservationLedgerMeasurementState.notCollected) {
          throw ArgumentError(
            'Unmeasured symptom status must remain unmeasured.',
          );
        }
        if (status == PersonalObservationStatus.recorded &&
            severity.state ==
                PersonalObservationLedgerMeasurementState.notCollected) {
          throw ArgumentError(
            'Recorded symptom severity cannot be unmeasured.',
          );
        }
      case PersonalObservationKind.selfReportedMotorState:
        if (labelOmitted ||
            posture != null ||
            measurements.isNotEmpty ||
            (status == PersonalObservationStatus.recorded) !=
                (motorState != null)) {
          throw ArgumentError('Motor-state projection fields are invalid.');
        }
      case PersonalObservationKind.bloodPressure:
        if (labelOmitted ||
            motorState != null ||
            posture == null ||
            measurements.length != 2 ||
            !measurements.any((item) => item.id == 'systolic') ||
            !measurements.any((item) => item.id == 'diastolic') ||
            measurements.any(
              (item) =>
                  item.dimension != PersonalObservationLedgerDimension.pressure,
            )) {
          throw ArgumentError('Blood-pressure projection fields are invalid.');
        }
        final expectedState = switch (status) {
          PersonalObservationStatus.recorded =>
            PersonalObservationLedgerMeasurementState.known,
          PersonalObservationStatus.unknown =>
            PersonalObservationLedgerMeasurementState.unknown,
          PersonalObservationStatus.notMeasured =>
            PersonalObservationLedgerMeasurementState.notCollected,
        };
        if (measurements.any((item) => item.state != expectedState)) {
          throw ArgumentError('Blood-pressure status and values disagree.');
        }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'event_id_sha256': eventIdSha256,
    'kind': kind.name,
    'status': status.name,
    'source': source.name,
    'occurred_at_utc': occurredAtUtc.toIso8601String(),
    'recorded_at_utc': recordedAtUtc.toIso8601String(),
    'declared_timezone': declaredTimezone,
    'order_at_timestamp': orderAtTimestamp,
    'synthetic': synthetic,
    'label_omitted': labelOmitted,
    'measurements': measurements.map((item) => item.toJson()).toList(),
    'local_time_resolution_evidence': localTimeResolutionEvidence?.toJson(),
    'motor_state': motorState?.name,
    'posture': posture?.name,
  };

  factory PersonalObservationLedgerEvent.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'event_id_sha256',
      'kind',
      'status',
      'source',
      'occurred_at_utc',
      'recorded_at_utc',
      'declared_timezone',
      'order_at_timestamp',
      'synthetic',
      'label_omitted',
      'measurements',
      'local_time_resolution_evidence',
      'motor_state',
      'posture',
    }, 'observation event');
    final rawMeasurements = json['measurements'];
    if (rawMeasurements is! List) {
      throw const FormatException('Observation measurements must be a list.');
    }
    return PersonalObservationLedgerEvent(
      eventIdSha256: _string(json['event_id_sha256'], 'event_id_sha256'),
      kind: _enumByName(
        PersonalObservationKind.values,
        json['kind'],
        'event.kind',
      ),
      status: _enumByName(
        PersonalObservationStatus.values,
        json['status'],
        'event.status',
      ),
      source: _enumByName(
        PersonalObservationSource.values,
        json['source'],
        'event.source',
      ),
      occurredAtUtc: _utcDateTime(json['occurred_at_utc']),
      recordedAtUtc: _utcDateTime(json['recorded_at_utc']),
      declaredTimezone: _string(json['declared_timezone'], 'declared_timezone'),
      orderAtTimestamp: _int(json['order_at_timestamp'], 'order_at_timestamp'),
      synthetic: _bool(json['synthetic'], 'synthetic'),
      labelOmitted: _bool(json['label_omitted'], 'label_omitted'),
      measurements: [
        for (final value in rawMeasurements)
          PersonalObservationLedgerMeasurement.fromJson(
            _objectMap(value, 'measurement'),
          ),
      ],
      localTimeResolutionEvidence:
          json['local_time_resolution_evidence'] == null
          ? null
          : LocalTimeResolutionEvidence.fromJson(
              _objectMap(
                json['local_time_resolution_evidence'],
                'local time resolution evidence',
              ),
            ),
      motorState: _nullableEnumByName(
        SelfReportedMotorState.values,
        json['motor_state'],
        'event.motor_state',
      ),
      posture: _nullableEnumByName(
        BloodPressurePosture.values,
        json['posture'],
        'event.posture',
      ),
    );
  }
}

/// A canonical digest over an in-memory owner-observation projection.
final class PersonalObservationEventLedger {
  PersonalObservationEventLedger({
    required List<PersonalObservationLedgerEvent> events,
  }) : events = List<PersonalObservationLedgerEvent>.unmodifiable(
         <PersonalObservationLedgerEvent>[...events]..sort(_compareEvents),
       ) {
    _validate();
  }

  final List<PersonalObservationLedgerEvent> events;
  late final String sha256Digest = sha256
      .convert(utf8.encode(_canonicalJson(_bodyJson())))
      .toString();

  void _validate() {
    if (events.map((item) => item.eventIdSha256).toSet().length !=
        events.length) {
      throw ArgumentError('Duplicate observation event identity.');
    }
    final orderByInstant = <int, Set<int>>{};
    for (final event in events) {
      final orders = orderByInstant.putIfAbsent(
        event.occurredAtUtc.microsecondsSinceEpoch,
        () => <int>{},
      );
      if (!orders.add(event.orderAtTimestamp)) {
        throw ArgumentError('Equal-time observation order must be unique.');
      }
    }
  }

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema': personalObservationEventLedgerSchema,
    'schema_version': personalObservationEventLedgerSchemaVersion,
    'boundary': personalObservationEventLedgerBoundary,
    'events': events.map((event) => event.toJson()).toList(),
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'sha256_digest': sha256Digest,
  };

  factory PersonalObservationEventLedger.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schema',
      'schema_version',
      'boundary',
      'events',
      'sha256_digest',
    }, 'observation ledger');
    if (json['schema'] != personalObservationEventLedgerSchema ||
        json['schema_version'] != personalObservationEventLedgerSchemaVersion ||
        json['boundary'] != personalObservationEventLedgerBoundary) {
      throw const FormatException('Unsupported observation ledger schema.');
    }
    final rawEvents = json['events'];
    if (rawEvents is! List) {
      throw const FormatException('Observation ledger events must be a list.');
    }
    final ledger = PersonalObservationEventLedger(
      events: [
        for (final value in rawEvents)
          PersonalObservationLedgerEvent.fromJson(
            _objectMap(value, 'observation event'),
          ),
      ],
    );
    if (json['sha256_digest'] != ledger.sha256Digest) {
      throw const FormatException('Observation ledger digest mismatch.');
    }
    return ledger;
  }
}

/// Bounded conversion for the blood-pressure units used by this projection.
/// The kPa factor follows NIST Handbook 133, 2026 Appendix E.
final class PersonalObservationLedgerUnitConverter {
  const PersonalObservationLedgerUnitConverter._();

  static const double _mmHgPerKPa = 7.500615;

  static bool supportsPressureUnit(String unit) =>
      switch (_normalizedPressureUnit(unit)) {
        'mm[hg]' || 'mmhg' || 'kpa' => true,
        _ => false,
      };

  static double convertPressure({
    required double value,
    required String fromUnit,
    required String toUnit,
  }) {
    if (!value.isFinite) {
      throw ArgumentError('Pressure conversion requires a finite value.');
    }
    final from = _normalizedPressureUnit(fromUnit);
    final to = _normalizedPressureUnit(toUnit);
    const factors = <String, double>{
      'mm[hg]': 1,
      'mmhg': 1,
      'kpa': _mmHgPerKPa,
    };
    final fromFactor = factors[from];
    final toFactor = factors[to];
    if (fromFactor == null || toFactor == null) {
      throw ArgumentError(
        'Unsupported pressure conversion: $fromUnit -> $toUnit.',
      );
    }
    if (from == to) return value;
    final converted = value * fromFactor / toFactor;
    if (!converted.isFinite) {
      throw ArgumentError('Pressure conversion overflow.');
    }
    return converted;
  }

  static String _normalizedPressureUnit(String unit) =>
      unit.trim().toLowerCase().replaceAll(' ', '');
}

int _compareEvents(
  PersonalObservationLedgerEvent left,
  PersonalObservationLedgerEvent right,
) {
  final occurred = left.occurredAtUtc.compareTo(right.occurredAtUtc);
  if (occurred != 0) return occurred;
  final order = left.orderAtTimestamp.compareTo(right.orderAtTimestamp);
  return order != 0 ? order : left.eventIdSha256.compareTo(right.eventIdSha256);
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.toList();
    if (keys.any((key) => key is! String)) {
      throw const FormatException(
        'Canonical JSON object keys must be strings.',
      );
    }
    keys.sort((left, right) => (left as String).compareTo(right as String));
    return <String, Object?>{
      for (final key in keys) key as String: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

void _requireExactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String label,
) {
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw FormatException('Invalid $label fields.');
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String label) {
  for (final value in values) {
    if (raw == value.name) return value;
  }
  throw FormatException('Invalid $label.');
}

T? _nullableEnumByName<T extends Enum>(
  List<T> values,
  Object? raw,
  String label,
) => raw == null ? null : _enumByName(values, raw, label);

String _string(Object? raw, String label) {
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Invalid $label.');
  }
  return raw;
}

double? _nullableDouble(Object? raw, String label) {
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite) throw FormatException('Invalid $label.');
  return raw.toDouble();
}

int _int(Object? raw, String label) {
  if (raw is! int) throw FormatException('Invalid $label.');
  return raw;
}

bool _bool(Object? raw, String label) {
  if (raw is! bool) throw FormatException('Invalid $label.');
  return raw;
}

DateTime _utcDateTime(Object? raw) {
  if (raw is! String) throw const FormatException('Invalid UTC timestamp.');
  final value = DateTime.tryParse(raw);
  if (value == null || !value.isUtc || !raw.endsWith('Z')) {
    throw const FormatException('Invalid UTC timestamp.');
  }
  return value;
}

Map<String, Object?> _objectMap(Object? raw, String label) {
  if (raw is! Map) throw FormatException('Invalid $label object.');
  return <String, Object?>{
    for (final entry in raw.entries)
      if (entry.key is String) entry.key as String: entry.value,
  }..lengthCheck(raw, label);
}

extension on Map<String, Object?> {
  void lengthCheck(Map raw, String label) {
    if (length != raw.length) throw FormatException('Invalid $label keys.');
  }
}
