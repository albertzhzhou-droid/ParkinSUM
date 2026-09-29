import 'dart:convert';

import 'knowledge_approval_envelope.dart';
import 'knowledge_pack.dart';
import 'rule_test_case.dart';

const knowledgeGovernanceSchemaVersion = 1;
const knowledgeGovernanceMaxBytes = 8 * 1024 * 1024;

enum KnowledgeGovernanceEventKind {
  draftSaved,
  submitted,
  reviewAccepted,
  activated,
  withdrawn,
}

enum KnowledgePackStatus {
  draft,
  submitted,
  reviewed,
  rejected,
  active,
  superseded,
  withdrawn,
}

final class KnowledgeGovernanceEvent {
  final int sequence;
  final String? previousDigest;
  final KnowledgeGovernanceEventKind kind;
  final String actorId;
  final DateTime occurredAtUtc;
  final Map<String, dynamic> payload;

  KnowledgeGovernanceEvent({
    required this.sequence,
    required this.previousDigest,
    required this.kind,
    required this.actorId,
    required this.occurredAtUtc,
    required Map<String, dynamic> payload,
  }) : payload = knowledgeFreeze(payload) as Map<String, dynamic> {
    if (sequence < 1 || !occurredAtUtc.isUtc) {
      throw const FormatException('Invalid event sequence or timestamp.');
    }
    if (previousDigest != null) knowledgeDigest(previousDigest);
    knowledgeText(actorId, 'actor_id');
    knowledgeUtc(occurredAtUtc.toIso8601String());
    knowledgeCheckJson(payload, maxBytes: knowledgePackMaxBytes + 65536);
  }

  late final String payloadDigest = _payloadDigest();
  String _payloadDigest() {
    if (kind == KnowledgeGovernanceEventKind.draftSaved) {
      knowledgeKeys(payload, {'pack'});
      return KnowledgePack.fromJson(knowledgeMap(payload['pack'])).digest;
    }
    return ruleTestJsonDigest('knowledge-event-payload-v1', payload);
  }

  late final String digest = ruleTestJsonDigest('knowledge-event-v1', {
    'sequence': sequence,
    'previous_digest': previousDigest,
    'kind': kind.name,
    'actor_id': actorId,
    'occurred_at_utc': occurredAtUtc.toIso8601String(),
    'payload_digest': payloadDigest,
  });
  Map<String, dynamic> toJson() => {
    'sequence': sequence,
    'previous_digest': previousDigest,
    'kind': kind.name,
    'actor_id': actorId,
    'occurred_at_utc': occurredAtUtc.toIso8601String(),
    'payload': knowledgeCopy(payload),
    'digest': digest,
  };
  factory KnowledgeGovernanceEvent.fromJson(Map<String, dynamic> json) {
    knowledgeKeys(json, {
      'sequence',
      'previous_digest',
      'kind',
      'actor_id',
      'occurred_at_utc',
      'payload',
      'digest',
    });
    if (json['sequence'] is! int) {
      throw const FormatException('Event sequence must be an integer.');
    }
    final result = KnowledgeGovernanceEvent(
      sequence: json['sequence'] as int,
      previousDigest: json['previous_digest'] == null
          ? null
          : knowledgeDigest(json['previous_digest']),
      kind: knowledgeEnum(KnowledgeGovernanceEventKind.values, json['kind']),
      actorId: knowledgeText(json['actor_id'], 'actor_id'),
      occurredAtUtc: knowledgeUtc(json['occurred_at_utc']),
      payload: knowledgeMap(json['payload']),
    );
    if (result.digest != json['digest']) {
      throw const FormatException('Governance event digest mismatch.');
    }
    return result;
  }
}

/// Structural journal validation does not confer authority. The service replays
/// transitions, signatures, current trust policy, and executable case evidence.
final class KnowledgeGovernanceJournal {
  final List<KnowledgeGovernanceEvent> events;
  KnowledgeGovernanceJournal(Iterable<KnowledgeGovernanceEvent> events)
    : events = List.unmodifiable(events) {
    if (this.events.length > 256) {
      throw const FormatException('Governance history capacity reached.');
    }
    String? previous;
    DateTime? time;
    for (var i = 0; i < this.events.length; i++) {
      final event = this.events[i];
      if (event.sequence != i + 1 ||
          event.previousDigest != previous ||
          (time != null && event.occurredAtUtc.isBefore(time))) {
        throw const FormatException('Governance event chain is broken.');
      }
      previous = event.digest;
      time = event.occurredAtUtc;
    }
    knowledgeCheckJson(toJson(), maxBytes: knowledgeGovernanceMaxBytes);
  }
  String? get headDigest => events.lastOrNull?.digest;
  Map<String, dynamic> toJson() => {
    'schema_version': knowledgeGovernanceSchemaVersion,
    'events': events.map((e) => e.toJson()).toList(),
  };
  String encode() => jsonEncode(toJson());
  factory KnowledgeGovernanceJournal.decode(String raw) {
    final json = knowledgeDecode(raw, maxBytes: knowledgeGovernanceMaxBytes);
    knowledgeKeys(json, {'schema_version', 'events'});
    if (json['schema_version'] is! int ||
        json['schema_version'] != knowledgeGovernanceSchemaVersion) {
      throw const FormatException('Unsupported governance schema.');
    }
    return KnowledgeGovernanceJournal(
      knowledgeList(
        json['events'],
      ).map((e) => KnowledgeGovernanceEvent.fromJson(knowledgeMap(e))),
    );
  }
}

final class KnowledgePackRecord {
  final KnowledgePack pack;
  final KnowledgePackStatus status;
  final KnowledgeApprovalEnvelope? authorApproval;
  final Map<String, KnowledgeApprovalEnvelope> reviews;
  final Map<String, dynamic>? suiteResult;
  KnowledgePackRecord({
    required this.pack,
    required this.status,
    this.authorApproval,
    Map<String, KnowledgeApprovalEnvelope> reviews = const {},
    Map<String, dynamic>? suiteResult,
  }) : reviews = Map.unmodifiable(reviews),
       suiteResult = suiteResult == null
           ? null
           : knowledgeFreeze(suiteResult) as Map<String, dynamic>;
  KnowledgePackRecord copyWith({
    KnowledgePackStatus? status,
    KnowledgeApprovalEnvelope? authorApproval,
    Map<String, KnowledgeApprovalEnvelope>? reviews,
    Map<String, dynamic>? suiteResult,
  }) => KnowledgePackRecord(
    pack: pack,
    status: status ?? this.status,
    authorApproval: authorApproval ?? this.authorApproval,
    reviews: reviews ?? this.reviews,
    suiteResult: suiteResult ?? this.suiteResult,
  );
}

final class KnowledgeGovernanceState {
  final KnowledgeGovernanceJournal journal;
  final Map<String, KnowledgePackRecord> packages;
  final String? activePackDigest;
  final bool everManaged;
  final int approvalSequence;
  final String? lastEnvelopeDigest;
  KnowledgeGovernanceState.replayed({
    required this.journal,
    required Map<String, KnowledgePackRecord> packages,
    required this.activePackDigest,
    required this.everManaged,
    required this.approvalSequence,
    required this.lastEnvelopeDigest,
  }) : packages = Map.unmodifiable(packages);
  String? get headDigest => journal.headDigest;
  KnowledgePackRecord? get activePack => packages[activePackDigest];
  Map<String, dynamic> toJson() => journal.toJson();
}

Object? knowledgeFreeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final e in value.entries) e.key as String: knowledgeFreeze(e.value),
    });
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(knowledgeFreeze));
  }
  return value;
}

Object? knowledgeCopy(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries) e.key as String: knowledgeCopy(e.value),
    };
  }
  if (value is List) return value.map(knowledgeCopy).toList();
  return value;
}
