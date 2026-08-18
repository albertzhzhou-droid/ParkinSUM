import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'intake.dart';
import 'meal.dart';

const int recoverableUserEventSchemaVersion = 1;
const String recoverableUserEventAbsentDigest =
    '5f241252bd523e3a76ad6b4c740ed6d0c3289a72edb9942de2c2453c0f6b78af';

enum RecoverableUserEventType { meal, intake }

enum RecoverableUserEventMutationType { create, update, delete, restore }

/// Append-only evidence for one durable meal or intake transition.
///
/// Ordering is not inferred from wall-clock time. [historyId] is the canonical
/// identity of this exact transition and [operationId] is the idempotency key
/// used by storage adapters. Restore safety is based on the before/after
/// content digests, so a newer edit is never overwritten merely because a
/// user selected an older history row.
final class RecoverableUserEventRevision {
  RecoverableUserEventRevision._({
    required this.historyId,
    required this.operationId,
    required this.eventType,
    required this.recordId,
    required this.mutationType,
    required this.beforePayload,
    required this.afterPayload,
    required this.beforeDigest,
    required this.afterDigest,
    required this.recordedAtUtc,
    required this.source,
    required this.restoresHistoryId,
  });

  final String historyId;
  final String operationId;
  final RecoverableUserEventType eventType;
  final String recordId;
  final RecoverableUserEventMutationType mutationType;
  final Map<String, Object?>? beforePayload;
  final Map<String, Object?>? afterPayload;
  final String beforeDigest;
  final String afterDigest;
  final DateTime recordedAtUtc;
  final String source;
  final String? restoresHistoryId;

  bool get isRestorable => true;

  static RecoverableUserEventRevision create({
    required String operationId,
    required RecoverableUserEventType eventType,
    required String recordId,
    required RecoverableUserEventMutationType mutationType,
    required Map<String, Object?>? beforePayload,
    required Map<String, Object?>? afterPayload,
    required DateTime recordedAtUtc,
    required String source,
    String? restoresHistoryId,
  }) {
    final normalizedBefore = normalizeRecoverableUserEventPayload(
      eventType,
      beforePayload,
      expectedRecordId: recordId,
    );
    final normalizedAfter = normalizeRecoverableUserEventPayload(
      eventType,
      afterPayload,
      expectedRecordId: recordId,
    );
    _validateTransition(
      mutationType: mutationType,
      beforePayload: normalizedBefore,
      afterPayload: normalizedAfter,
      restoresHistoryId: restoresHistoryId,
    );
    final beforeDigest = recoverableUserEventPayloadDigest(normalizedBefore);
    final afterDigest = recoverableUserEventPayloadDigest(normalizedAfter);
    final identityPayload = _identityPayload(
      operationId: operationId,
      eventType: eventType,
      recordId: recordId,
      mutationType: mutationType,
      beforePayload: normalizedBefore,
      afterPayload: normalizedAfter,
      beforeDigest: beforeDigest,
      afterDigest: afterDigest,
      recordedAtUtc: recordedAtUtc.toUtc(),
      source: source,
      restoresHistoryId: restoresHistoryId,
    );
    final historyId = 'history_${_sha256(_canonicalJson(identityPayload))}';
    final revision = RecoverableUserEventRevision._(
      historyId: historyId,
      operationId: operationId,
      eventType: eventType,
      recordId: recordId,
      mutationType: mutationType,
      beforePayload: normalizedBefore,
      afterPayload: normalizedAfter,
      beforeDigest: beforeDigest,
      afterDigest: afterDigest,
      recordedAtUtc: recordedAtUtc.toUtc(),
      source: source,
      restoresHistoryId: restoresHistoryId,
    );
    revision.validate();
    return revision;
  }

  factory RecoverableUserEventRevision.fromJson(Map<String, dynamic> json) {
    const requiredKeys = <String>{
      'schema_version',
      'history_id',
      'operation_id',
      'event_type',
      'record_id',
      'mutation_type',
      'before_payload',
      'after_payload',
      'before_digest',
      'after_digest',
      'recorded_at_utc',
      'source',
      'restores_history_id',
    };
    if (json.keys.toSet().length != requiredKeys.length ||
        !json.keys.toSet().containsAll(requiredKeys) ||
        json['schema_version'] != recoverableUserEventSchemaVersion) {
      throw const FormatException(
        'Recoverable event revision shape is invalid.',
      );
    }
    final historyId = json['history_id'];
    final operationId = json['operation_id'];
    final rawEventType = json['event_type'];
    final recordId = json['record_id'];
    final rawMutationType = json['mutation_type'];
    final beforeDigest = json['before_digest'];
    final afterDigest = json['after_digest'];
    final rawRecordedAt = json['recorded_at_utc'];
    final source = json['source'];
    final restoresHistoryId = json['restores_history_id'];
    if (historyId is! String ||
        operationId is! String ||
        rawEventType is! String ||
        recordId is! String ||
        rawMutationType is! String ||
        beforeDigest is! String ||
        afterDigest is! String ||
        rawRecordedAt is! String ||
        source is! String ||
        (restoresHistoryId != null && restoresHistoryId is! String)) {
      throw const FormatException(
        'Recoverable event revision field types are invalid.',
      );
    }
    final RecoverableUserEventType eventType;
    final RecoverableUserEventMutationType mutationType;
    final DateTime recordedAtUtc;
    try {
      eventType = RecoverableUserEventType.values.byName(rawEventType);
      mutationType = RecoverableUserEventMutationType.values.byName(
        rawMutationType,
      );
      recordedAtUtc = DateTime.parse(rawRecordedAt);
    } on Object {
      throw const FormatException(
        'Recoverable event revision enum or timestamp is invalid.',
      );
    }
    final before = normalizeRecoverableUserEventPayload(
      eventType,
      _optionalPayload(json['before_payload']),
      expectedRecordId: recordId,
    );
    final after = normalizeRecoverableUserEventPayload(
      eventType,
      _optionalPayload(json['after_payload']),
      expectedRecordId: recordId,
    );
    final revision = RecoverableUserEventRevision._(
      historyId: historyId,
      operationId: operationId,
      eventType: eventType,
      recordId: recordId,
      mutationType: mutationType,
      beforePayload: before,
      afterPayload: after,
      beforeDigest: beforeDigest,
      afterDigest: afterDigest,
      recordedAtUtc: recordedAtUtc,
      source: source,
      restoresHistoryId: restoresHistoryId as String?,
    );
    revision.validate();
    return revision;
  }

  void validate() {
    final safeId = RegExp(r'^[A-Za-z0-9._:-]{1,160}$');
    final digest = RegExp(r'^[a-f0-9]{64}$');
    if (!safeId.hasMatch(historyId) ||
        !safeId.hasMatch(operationId) ||
        !safeId.hasMatch(recordId) ||
        !RegExp(r'^[a-z][a-z0-9._:-]{0,79}$').hasMatch(source) ||
        (restoresHistoryId != null && !safeId.hasMatch(restoresHistoryId!)) ||
        !recordedAtUtc.isUtc ||
        recordedAtUtc.year < 2020 ||
        !digest.hasMatch(beforeDigest) ||
        !digest.hasMatch(afterDigest)) {
      throw const FormatException(
        'Recoverable event revision values are invalid.',
      );
    }
    _validateTransition(
      mutationType: mutationType,
      beforePayload: beforePayload,
      afterPayload: afterPayload,
      restoresHistoryId: restoresHistoryId,
    );
    if (beforeDigest != recoverableUserEventPayloadDigest(beforePayload) ||
        afterDigest != recoverableUserEventPayloadDigest(afterPayload)) {
      throw const FormatException('Recoverable event payload digest mismatch.');
    }
    final expectedHistoryId =
        'history_${_sha256(_canonicalJson(_identityPayload(operationId: operationId, eventType: eventType, recordId: recordId, mutationType: mutationType, beforePayload: beforePayload, afterPayload: afterPayload, beforeDigest: beforeDigest, afterDigest: afterDigest, recordedAtUtc: recordedAtUtc, source: source, restoresHistoryId: restoresHistoryId)))}';
    if (expectedHistoryId != historyId) {
      throw const FormatException(
        'Recoverable event history identity mismatch.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': recoverableUserEventSchemaVersion,
    'history_id': historyId,
    'operation_id': operationId,
    'event_type': eventType.name,
    'record_id': recordId,
    'mutation_type': mutationType.name,
    'before_payload': beforePayload,
    'after_payload': afterPayload,
    'before_digest': beforeDigest,
    'after_digest': afterDigest,
    'recorded_at_utc': recordedAtUtc.toIso8601String(),
    'source': source,
    'restores_history_id': restoresHistoryId,
  };

  static void _validateTransition({
    required RecoverableUserEventMutationType mutationType,
    required Map<String, Object?>? beforePayload,
    required Map<String, Object?>? afterPayload,
    required String? restoresHistoryId,
  }) {
    final valid = switch (mutationType) {
      RecoverableUserEventMutationType.create =>
        beforePayload == null &&
            afterPayload != null &&
            restoresHistoryId == null,
      RecoverableUserEventMutationType.update =>
        beforePayload != null &&
            afterPayload != null &&
            restoresHistoryId == null,
      RecoverableUserEventMutationType.delete =>
        beforePayload != null &&
            afterPayload == null &&
            restoresHistoryId == null,
      RecoverableUserEventMutationType.restore =>
        restoresHistoryId != null &&
            (beforePayload != null || afterPayload != null),
    };
    if (!valid ||
        beforePayload != null &&
            afterPayload != null &&
            recoverableUserEventPayloadDigest(beforePayload) ==
                recoverableUserEventPayloadDigest(afterPayload)) {
      throw const FormatException('Recoverable event transition is invalid.');
    }
  }

  static Map<String, Object?> _identityPayload({
    required String operationId,
    required RecoverableUserEventType eventType,
    required String recordId,
    required RecoverableUserEventMutationType mutationType,
    required Map<String, Object?>? beforePayload,
    required Map<String, Object?>? afterPayload,
    required String beforeDigest,
    required String afterDigest,
    required DateTime recordedAtUtc,
    required String source,
    required String? restoresHistoryId,
  }) => <String, Object?>{
    'schema_version': recoverableUserEventSchemaVersion,
    'operation_id': operationId,
    'event_type': eventType.name,
    'record_id': recordId,
    'mutation_type': mutationType.name,
    'before_payload': beforePayload,
    'after_payload': afterPayload,
    'before_digest': beforeDigest,
    'after_digest': afterDigest,
    'recorded_at_utc': recordedAtUtc.toIso8601String(),
    'source': source,
    'restores_history_id': restoresHistoryId,
  };
}

/// One atomic compare-and-set request. Storage must append [revision] and
/// publish [nextPayload] in the same transaction or publish neither.
final class RecoverableUserEventMutation {
  const RecoverableUserEventMutation({required this.revision});

  final RecoverableUserEventRevision revision;

  String get expectedCurrentDigest => revision.beforeDigest;
  Map<String, Object?>? get nextPayload => revision.afterPayload;
}

final class RecoverableUserEventConflict implements Exception {
  const RecoverableUserEventConflict({
    required this.recordId,
    required this.expectedDigest,
    required this.actualDigest,
  });

  final String recordId;
  final String expectedDigest;
  final String actualDigest;

  @override
  String toString() => 'RecoverableUserEventConflict(recordId: $recordId)';
}

Map<String, Object?>? normalizeRecoverableUserEventPayload(
  RecoverableUserEventType eventType,
  Map<String, Object?>? payload, {
  required String expectedRecordId,
}) {
  if (payload == null) return null;
  final normalized = switch (eventType) {
    RecoverableUserEventType.meal => Meal.fromJson(
      Map<String, dynamic>.from(payload),
    ).toJson(),
    RecoverableUserEventType.intake => Intake.fromJson(
      Map<String, dynamic>.from(payload),
    ).toJson(),
  };
  if (normalized['id'] != expectedRecordId ||
      _canonicalJson(normalized) != _canonicalJson(payload)) {
    throw const FormatException('Recoverable event payload is not canonical.');
  }
  final encoded = utf8.encode(jsonEncode(normalized));
  if (encoded.length > 262144) {
    throw const FormatException('Recoverable event payload is too large.');
  }
  return Map<String, Object?>.unmodifiable(
    Map<String, Object?>.from(normalized),
  );
}

String recoverableUserEventPayloadDigest(Map<String, Object?>? payload) {
  if (payload == null) return recoverableUserEventAbsentDigest;
  return _sha256(
    'parkinsum-recoverable-user-event-payload-v1|${_canonicalJson(payload)}',
  );
}

Map<String, Object?>? _optionalPayload(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw const FormatException('Recoverable event payload must be an object.');
  }
  return Map<String, Object?>.from(raw);
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted['${entry.key}'] = _canonicalize(entry.value);
    }
    return sorted;
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  throw const FormatException('Recoverable event payload is not finite JSON.');
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

final class RecoverableUserEventIdFactory {
  RecoverableUserEventIdFactory({Random? random, DateTime Function()? clock})
    : _random = random ?? Random.secure(),
      _clock = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _clock;

  String newOperationId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final entropy = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'event_op_${_clock().toUtc().microsecondsSinceEpoch}_$entropy';
  }
}
