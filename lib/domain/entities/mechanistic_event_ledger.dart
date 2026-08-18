import 'dart:convert';

import 'package:crypto/crypto.dart';

const int mechanisticEventLedgerSchemaVersion = 1;
const String mechanisticEventLedgerSchema =
    'parkinsum.mechanistic-event-ledger/1';

enum MechanisticLedgerEventKind { dose, meal, observation, context }

enum MechanisticLedgerValueState {
  known,
  unknown,
  notCollected,
  belowQuantification,
  censored,
}

enum MechanisticLedgerValueOrigin {
  observedOriginal,
  canonicalProjection,
  syntheticFixture,
}

enum MechanisticLedgerDimension {
  mass,
  energy,
  duration,
  fraction,
  categorical,
}

final class MechanisticLedgerMeasurement {
  MechanisticLedgerMeasurement({
    required this.id,
    required this.state,
    required this.dimension,
    required this.origin,
    required this.originalValue,
    required this.originalUnit,
    required this.canonicalValue,
    required this.canonicalUnit,
    this.lowerQuantificationLimit,
  }) {
    _validate();
  }

  final String id;
  final MechanisticLedgerValueState state;
  final MechanisticLedgerDimension dimension;
  final MechanisticLedgerValueOrigin origin;
  final double? originalValue;
  final String? originalUnit;
  final double? canonicalValue;
  final String? canonicalUnit;
  final double? lowerQuantificationLimit;

  void _validate() {
    _requireSafeId(id, 'measurement id');
    final finiteOriginal = originalValue == null || originalValue!.isFinite;
    final finiteCanonical = canonicalValue == null || canonicalValue!.isFinite;
    if (!finiteOriginal || !finiteCanonical) {
      throw ArgumentError('Ledger values must be finite.');
    }
    if (state == MechanisticLedgerValueState.known) {
      if (originalValue == null || canonicalValue == null) {
        throw ArgumentError(
          'Known values require original and canonical values.',
        );
      }
      if ((originalUnit ?? '').trim().isEmpty ||
          (canonicalUnit ?? '').trim().isEmpty) {
        throw ArgumentError('Known values require explicit units.');
      }
    } else if (originalValue != null || canonicalValue != null) {
      throw ArgumentError(
        'Unknown or censored values cannot carry point values.',
      );
    }
    if (state == MechanisticLedgerValueState.belowQuantification) {
      if (lowerQuantificationLimit == null ||
          !lowerQuantificationLimit!.isFinite ||
          lowerQuantificationLimit! <= 0) {
        throw ArgumentError(
          'Below-quantification values require a positive limit.',
        );
      }
    } else if (lowerQuantificationLimit != null) {
      throw ArgumentError('Only below-quantification values carry a limit.');
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
    'lower_quantification_limit': lowerQuantificationLimit,
  };

  factory MechanisticLedgerMeasurement.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'id',
      'state',
      'dimension',
      'origin',
      'original_value',
      'original_unit',
      'canonical_value',
      'canonical_unit',
      'lower_quantification_limit',
    }, 'measurement');
    return MechanisticLedgerMeasurement(
      id: _string(json['id'], 'measurement.id'),
      state: _enumByName(
        MechanisticLedgerValueState.values,
        json['state'],
        'measurement.state',
      ),
      dimension: _enumByName(
        MechanisticLedgerDimension.values,
        json['dimension'],
        'measurement.dimension',
      ),
      origin: _enumByName(
        MechanisticLedgerValueOrigin.values,
        json['origin'],
        'measurement.origin',
      ),
      originalValue: _nullableDouble(json['original_value'], 'original_value'),
      originalUnit: _nullableString(json['original_unit'], 'original_unit'),
      canonicalValue: _nullableDouble(
        json['canonical_value'],
        'canonical_value',
      ),
      canonicalUnit: _nullableString(json['canonical_unit'], 'canonical_unit'),
      lowerQuantificationLimit: _nullableDouble(
        json['lower_quantification_limit'],
        'lower_quantification_limit',
      ),
    );
  }
}

final class MechanisticLedgerEvent {
  MechanisticLedgerEvent({
    required this.id,
    required this.kind,
    required this.originalTimestamp,
    required this.occurredAtUtc,
    required this.timezoneOffsetMinutes,
    required this.orderAtTimestamp,
    required this.sourceId,
    required this.revisionId,
    required this.synthetic,
    required List<MechanisticLedgerMeasurement> measurements,
    Map<String, String> attributes = const <String, String>{},
    this.formulation,
    this.route,
    this.compartment,
  }) : measurements = List<MechanisticLedgerMeasurement>.unmodifiable(
         measurements,
       ),
       attributes = Map<String, String>.unmodifiable(attributes) {
    _validate();
  }

  final String id;
  final MechanisticLedgerEventKind kind;
  final String originalTimestamp;
  final DateTime occurredAtUtc;
  final int timezoneOffsetMinutes;
  final int orderAtTimestamp;
  final String sourceId;
  final String revisionId;
  final bool synthetic;
  final List<MechanisticLedgerMeasurement> measurements;
  final Map<String, String> attributes;
  final String? formulation;
  final String? route;
  final String? compartment;

  void _validate() {
    _requireSafeId(id, 'event id');
    if (!occurredAtUtc.isUtc) {
      throw ArgumentError('Ledger timestamps must be UTC.');
    }
    final parsed = _parseTimestampWithOffset(originalTimestamp);
    if (parsed.utc != occurredAtUtc ||
        parsed.offsetMinutes != timezoneOffsetMinutes) {
      throw ArgumentError(
        'Original timestamp and canonical UTC time disagree.',
      );
    }
    if (orderAtTimestamp < 0) {
      throw ArgumentError('Equal-time order must be non-negative.');
    }
    if (sourceId.trim().isEmpty || revisionId.trim().isEmpty) {
      throw ArgumentError(
        'Ledger events require source and revision identity.',
      );
    }
    final measurementIds = measurements.map((entry) => entry.id).toSet();
    if (measurementIds.length != measurements.length) {
      throw ArgumentError('Duplicate measurement identity.');
    }
    for (final entry in attributes.entries) {
      _requireSafeId(entry.key, 'attribute key');
      if (entry.value.trim().isEmpty) {
        throw ArgumentError('Ledger attributes cannot be empty.');
      }
    }
    for (final field in <String?>[formulation, route, compartment]) {
      if (field != null && field.trim().isEmpty) {
        throw ArgumentError('Optional event fields cannot be empty strings.');
      }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'original_timestamp': originalTimestamp,
    'occurred_at_utc': occurredAtUtc.toIso8601String(),
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'order_at_timestamp': orderAtTimestamp,
    'source_id': sourceId,
    'revision_id': revisionId,
    'synthetic': synthetic,
    'measurements': measurements.map((entry) => entry.toJson()).toList(),
    'attributes': <String, String>{
      for (final key in attributes.keys.toList()..sort()) key: attributes[key]!,
    },
    'formulation': formulation,
    'route': route,
    'compartment': compartment,
  };

  factory MechanisticLedgerEvent.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'id',
      'kind',
      'original_timestamp',
      'occurred_at_utc',
      'timezone_offset_minutes',
      'order_at_timestamp',
      'source_id',
      'revision_id',
      'synthetic',
      'measurements',
      'attributes',
      'formulation',
      'route',
      'compartment',
    }, 'event');
    final rawMeasurements = json['measurements'];
    final rawAttributes = json['attributes'];
    if (rawMeasurements is! List || rawAttributes is! Map) {
      throw FormatException('Event collections have invalid shape.');
    }
    return MechanisticLedgerEvent(
      id: _string(json['id'], 'event.id'),
      kind: _enumByName(
        MechanisticLedgerEventKind.values,
        json['kind'],
        'event.kind',
      ),
      originalTimestamp: _string(
        json['original_timestamp'],
        'event.original_timestamp',
      ),
      occurredAtUtc: _utcDateTime(json['occurred_at_utc']),
      timezoneOffsetMinutes: _int(
        json['timezone_offset_minutes'],
        'event.timezone_offset_minutes',
      ),
      orderAtTimestamp: _int(
        json['order_at_timestamp'],
        'event.order_at_timestamp',
      ),
      sourceId: _string(json['source_id'], 'event.source_id'),
      revisionId: _string(json['revision_id'], 'event.revision_id'),
      synthetic: _bool(json['synthetic'], 'event.synthetic'),
      measurements: [
        for (final value in rawMeasurements)
          MechanisticLedgerMeasurement.fromJson(
            _objectMap(value, 'measurement'),
          ),
      ],
      attributes: <String, String>{
        for (final entry in rawAttributes.entries)
          _string(entry.key, 'attribute key'): _string(
            entry.value,
            'attribute value',
          ),
      },
      formulation: _nullableString(json['formulation'], 'event.formulation'),
      route: _nullableString(json['route'], 'event.route'),
      compartment: _nullableString(json['compartment'], 'event.compartment'),
    );
  }
}

final class MechanisticEventLedger {
  MechanisticEventLedger({
    required this.ledgerId,
    required this.createdAtUtc,
    required this.configurationDigest,
    required this.boundary,
    required List<MechanisticLedgerEvent> events,
  }) : events = List<MechanisticLedgerEvent>.unmodifiable(
         <MechanisticLedgerEvent>[...events]..sort(_compareEvents),
       ) {
    _validate();
  }

  final String ledgerId;
  final DateTime createdAtUtc;
  final String configurationDigest;
  final String boundary;
  final List<MechanisticLedgerEvent> events;

  late final String sha256Digest = sha256
      .convert(utf8.encode(_canonicalJson(_bodyJson())))
      .toString();
  late final String canonicalReplayDigest = sha256
      .convert(utf8.encode(_canonicalJson(_replayJson())))
      .toString();

  void _validate() {
    _requireSafeId(ledgerId, 'ledger id');
    if (!createdAtUtc.isUtc) {
      throw ArgumentError('Ledger creation time must be UTC.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(configurationDigest)) {
      throw ArgumentError('Configuration digest must be lowercase SHA-256.');
    }
    if (boundary.trim().isEmpty) {
      throw ArgumentError('Ledger boundary is required.');
    }
    if (events.map((event) => event.id).toSet().length != events.length) {
      throw ArgumentError('Duplicate immutable event identity.');
    }
    final orderKeys = <String>{};
    for (final event in events) {
      final key =
          '${event.occurredAtUtc.microsecondsSinceEpoch}:${event.orderAtTimestamp}';
      if (!orderKeys.add(key)) {
        throw ArgumentError('Undefined duplicate equal-time ordering.');
      }
    }
  }

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema': mechanisticEventLedgerSchema,
    'schema_version': mechanisticEventLedgerSchemaVersion,
    'ledger_id': ledgerId,
    'created_at_utc': createdAtUtc.toIso8601String(),
    'configuration_digest': configurationDigest,
    'boundary': boundary,
    'events': events.map((event) => event.toJson()).toList(),
  };

  Map<String, Object?> _replayJson() => <String, Object?>{
    'schema': mechanisticEventLedgerSchema,
    'ledger_id': ledgerId,
    'configuration_digest': configurationDigest,
    'events': [
      for (final event in events)
        <String, Object?>{
          'id': event.id,
          'kind': event.kind.name,
          'occurred_at_utc': event.occurredAtUtc.toIso8601String(),
          'order_at_timestamp': event.orderAtTimestamp,
          'source_id': event.sourceId,
          'revision_id': event.revisionId,
          'synthetic': event.synthetic,
          'attributes': event.attributes,
          'formulation': event.formulation,
          'route': event.route,
          'compartment': event.compartment,
          'measurements': [
            for (final measurement in event.measurements)
              <String, Object?>{
                'id': measurement.id,
                'state': measurement.state.name,
                'dimension': measurement.dimension.name,
                'canonical_value': measurement.canonicalValue,
                'canonical_unit': measurement.canonicalUnit,
                'lower_quantification_limit':
                    measurement.lowerQuantificationLimit,
              },
          ],
        },
    ],
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'sha256_digest': sha256Digest,
    'canonical_replay_digest': canonicalReplayDigest,
  };

  factory MechanisticEventLedger.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schema',
      'schema_version',
      'ledger_id',
      'created_at_utc',
      'configuration_digest',
      'boundary',
      'events',
      'sha256_digest',
      'canonical_replay_digest',
    }, 'ledger');
    if (json['schema'] != mechanisticEventLedgerSchema ||
        json['schema_version'] != mechanisticEventLedgerSchemaVersion) {
      throw FormatException('Unsupported mechanistic ledger schema.');
    }
    final rawEvents = json['events'];
    if (rawEvents is! List) {
      throw FormatException('Ledger events must be a list.');
    }
    final ledger = MechanisticEventLedger(
      ledgerId: _string(json['ledger_id'], 'ledger_id'),
      createdAtUtc: _utcDateTime(json['created_at_utc']),
      configurationDigest: _string(
        json['configuration_digest'],
        'configuration_digest',
      ),
      boundary: _string(json['boundary'], 'boundary'),
      events: [
        for (final value in rawEvents)
          MechanisticLedgerEvent.fromJson(_objectMap(value, 'event')),
      ],
    );
    if (json['sha256_digest'] != ledger.sha256Digest) {
      throw FormatException('Mechanistic ledger digest mismatch.');
    }
    if (json['canonical_replay_digest'] != ledger.canonicalReplayDigest) {
      throw FormatException('Mechanistic replay digest mismatch.');
    }
    return ledger;
  }
}

final class MechanisticUnitConverter {
  const MechanisticUnitConverter._();

  static double convert({
    required double value,
    required String fromUnit,
    required String toUnit,
    required MechanisticLedgerDimension dimension,
  }) {
    if (!value.isFinite) {
      throw ArgumentError('Unit conversion requires a finite value.');
    }
    final from = fromUnit.trim().toLowerCase();
    final to = toUnit.trim().toLowerCase();
    final factors = switch (dimension) {
      MechanisticLedgerDimension.mass => const <String, double>{
        'mcg': 0.001,
        'ug': 0.001,
        'mg': 1,
        'g': 1000,
        'kg': 1000000,
      },
      MechanisticLedgerDimension.energy => const <String, double>{
        'kcal': 1,
        'kj': 0.2390057361376673,
      },
      MechanisticLedgerDimension.duration => const <String, double>{
        's': 1 / 60,
        'min': 1,
        'h': 60,
      },
      MechanisticLedgerDimension.fraction => const <String, double>{
        'fraction': 1,
        '%': 0.01,
      },
      MechanisticLedgerDimension.categorical => const <String, double>{},
    };
    final fromFactor = factors[from];
    final toFactor = factors[to];
    if (fromFactor == null || toFactor == null) {
      throw ArgumentError(
        'Unsupported or dimensionally invalid conversion: $fromUnit -> $toUnit.',
      );
    }
    final converted = value * fromFactor / toFactor;
    if (!converted.isFinite) throw ArgumentError('Unit conversion overflow.');
    return converted;
  }
}

int _compareEvents(MechanisticLedgerEvent left, MechanisticLedgerEvent right) {
  final byTime = left.occurredAtUtc.compareTo(right.occurredAtUtc);
  if (byTime != 0) return byTime;
  final byOrder = left.orderAtTimestamp.compareTo(right.orderAtTimestamp);
  if (byOrder != 0) return byOrder;
  final byKind = left.kind.index.compareTo(right.kind.index);
  return byKind != 0 ? byKind : left.id.compareTo(right.id);
}

({DateTime utc, int offsetMinutes}) _parseTimestampWithOffset(String value) {
  final match = RegExp(r'(Z|([+-])(\d{2}):(\d{2}))$').firstMatch(value);
  if (match == null) {
    throw FormatException('Timestamp requires an explicit offset.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid timestamp.');
  var offset = 0;
  if (match.group(1) != 'Z') {
    final hours = int.parse(match.group(3)!);
    final minutes = int.parse(match.group(4)!);
    if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
      throw FormatException('Invalid timezone offset.');
    }
    offset = hours * 60 + minutes;
    if (match.group(2) == '-') offset = -offset;
  }
  return (utc: parsed.toUtc(), offsetMinutes: offset);
}

void _requireSafeId(String value, String label) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value)) {
    throw ArgumentError('$label is not a safe bounded identifier.');
  }
}

void _requireExactKeys(
  Map<String, Object?> value,
  Set<String> keys,
  String label,
) {
  final actual = value.keys.toSet();
  if (actual.length != keys.length || !actual.containsAll(keys)) {
    throw FormatException('$label has unsupported or missing fields.');
  }
}

String _string(Object? value, String label) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$label must be a string.');
  }
  return value;
}

String? _nullableString(Object? value, String label) =>
    value == null ? null : _string(value, label);

double? _nullableDouble(Object? value, String label) {
  if (value == null) return null;
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$label must be finite.');
  }
  return value.toDouble();
}

int _int(Object? value, String label) {
  if (value is! int) throw FormatException('$label must be an integer.');
  return value;
}

bool _bool(Object? value, String label) {
  if (value is! bool) throw FormatException('$label must be a boolean.');
  return value;
}

DateTime _utcDateTime(Object? value) {
  final parsed = DateTime.tryParse(_string(value, 'UTC timestamp'));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Timestamp must be canonical UTC.');
  }
  return parsed;
}

Map<String, Object?> _objectMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return <String, Object?>{
    for (final entry in value.entries)
      _string(entry.key, '$label key'): entry.value,
  };
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String label) {
  final name = _string(raw, label);
  return values.where((value) => value.name == name).firstOrNull ??
      (throw FormatException('$label is unsupported.'));
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonicalize).toList();
  return value;
}
