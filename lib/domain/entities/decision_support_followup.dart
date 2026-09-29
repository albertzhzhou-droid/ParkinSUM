import 'dart:convert';

import 'package:crypto/crypto.dart';

enum DecisionSupportFollowupStatus {
  unread,
  read,
  needsReview,
  snoozed,
  dismissed,
  resolved,
  notApplicable,
  declined,
}

/// A person-selected category for challenging or closing a saved prompt.
/// Categories organize feedback only; they do not verify the underlying claim.
enum DecisionSupportFeedbackReasonCategory {
  informationMayBeIncorrect,
  contextMismatch,
  explanationUnclear,
  duplicateOrAlreadyAddressed,
  other,
}

const Set<DecisionSupportFollowupStatus> _closedFollowupStatuses = {
  DecisionSupportFollowupStatus.dismissed,
  DecisionSupportFollowupStatus.resolved,
  DecisionSupportFollowupStatus.notApplicable,
  DecisionSupportFollowupStatus.declined,
};

const Set<DecisionSupportFollowupStatus> _reasonRequiredFollowupStatuses = {
  DecisionSupportFollowupStatus.dismissed,
  DecisionSupportFollowupStatus.notApplicable,
  DecisionSupportFollowupStatus.declined,
};

/// Person-selected views for the local follow-up list. These are workflow
/// filters, not clinical urgency or importance levels.
enum DecisionSupportFollowupView { open, needsReview, snoozed, all }

/// All feedback requires a person's explicit action. Engine output is not an
/// actor, and none of these workflow states proves clinical acceptance.
enum DecisionSupportFollowupActorRole { user, caregiver, clinician }

/// The exact explanation shown to a person, with the inputs and provenance
/// needed to review it later. Generated timestamps do not determine identity.
final class DecisionSupportPrompt {
  DecisionSupportPrompt._({
    required this.id,
    required this.ownerScopeDigest,
    required this.ruleId,
    required this.ruleVersion,
    required this.sourceRecordId,
    required this.candidateId,
    required this.inputSnapshot,
    required this.inputSnapshotDigest,
    required this.title,
    required this.explanation,
    required this.sourceRefs,
    required this.missingInputs,
    required this.createdAt,
  });

  final String id;
  final String ownerScopeDigest;
  final String ruleId;
  final String ruleVersion;
  final String sourceRecordId;
  final String candidateId;
  final Map<String, Object?> inputSnapshot;
  final String inputSnapshotDigest;
  final String title;
  final String explanation;
  final List<String> sourceRefs;
  final List<String> missingInputs;
  final DateTime createdAt;

  factory DecisionSupportPrompt.create({
    required String ownerScope,
    required String ruleId,
    required String ruleVersion,
    required String sourceRecordId,
    required String candidateId,
    required Map<String, Object?> inputSnapshot,
    required String title,
    required String explanation,
    required List<String> sourceRefs,
    required List<String> missingInputs,
    required DateTime createdAt,
  }) {
    final ownerDigest = decisionSupportOwnerScopeDigest(ownerScope);
    for (final value in [ruleId, ruleVersion, sourceRecordId, candidateId]) {
      _text(value, 'prompt identity', max: 512);
    }
    _text(title, 'title', max: 300);
    _text(explanation, 'explanation', max: 8000);
    final inputs = _freezeInputs(inputSnapshot);
    final inputDigest = _digest(inputs);
    final refs = _orderedStrings(sourceRefs, 'sourceRefs');
    final missing = _orderedStrings(missingInputs, 'missingInputs');
    final identity = <String, Object?>{
      'ownerScopeDigest': ownerDigest,
      'ruleId': ruleId,
      'ruleVersion': ruleVersion,
      'sourceRecordId': sourceRecordId,
      'candidateId': candidateId,
      'inputSnapshotDigest': inputDigest,
      'title': title,
      'explanation': explanation,
      'sourceRefs': refs,
      'missingInputs': missing,
    };
    return DecisionSupportPrompt._(
      id: 'followup_${_digest(identity)}',
      ownerScopeDigest: ownerDigest,
      ruleId: ruleId,
      ruleVersion: ruleVersion,
      sourceRecordId: sourceRecordId,
      candidateId: candidateId,
      inputSnapshot: inputs,
      inputSnapshotDigest: inputDigest,
      title: title,
      explanation: explanation,
      sourceRefs: refs,
      missingInputs: missing,
      createdAt: createdAt.toUtc(),
    );
  }

  factory DecisionSupportPrompt.fromJson(
    Map<String, dynamic> json, {
    required String ownerScope,
  }) {
    _exactKeys(json, const {
      'id',
      'ownerScopeDigest',
      'ruleId',
      'ruleVersion',
      'sourceRecordId',
      'candidateId',
      'inputSnapshot',
      'inputSnapshotDigest',
      'title',
      'explanation',
      'sourceRefs',
      'missingInputs',
      'createdAt',
    });
    final prompt = DecisionSupportPrompt.create(
      ownerScope: ownerScope,
      ruleId: _text(json['ruleId'], 'ruleId', max: 512),
      ruleVersion: _text(json['ruleVersion'], 'ruleVersion', max: 512),
      sourceRecordId: _text(json['sourceRecordId'], 'sourceRecordId', max: 512),
      candidateId: _text(json['candidateId'], 'candidateId', max: 512),
      inputSnapshot: _object(json['inputSnapshot']),
      title: _text(json['title'], 'title', max: 300),
      explanation: _text(json['explanation'], 'explanation', max: 8000),
      sourceRefs: _strings(json['sourceRefs']),
      missingInputs: _strings(json['missingInputs']),
      createdAt: _utc(json['createdAt']),
    );
    if (json['id'] != prompt.id ||
        json['ownerScopeDigest'] != prompt.ownerScopeDigest ||
        json['inputSnapshotDigest'] != prompt.inputSnapshotDigest ||
        _canonical(json['sourceRefs']) != _canonical(prompt.sourceRefs) ||
        _canonical(json['missingInputs']) != _canonical(prompt.missingInputs)) {
      throw const FormatException('Prompt identity or owner does not match.');
    }
    return prompt;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerScopeDigest': ownerScopeDigest,
    'ruleId': ruleId,
    'ruleVersion': ruleVersion,
    'sourceRecordId': sourceRecordId,
    'candidateId': candidateId,
    'inputSnapshot': inputSnapshot,
    'inputSnapshotDigest': inputSnapshotDigest,
    'title': title,
    'explanation': explanation,
    'sourceRefs': sourceRefs,
    'missingInputs': missingInputs,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// An append-only workflow action. Resolution means the user closed this task;
/// it never means that a recommendation was followed or clinically verified.
final class DecisionSupportFeedback {
  DecisionSupportFeedback._({
    required this.id,
    required this.promptId,
    required this.status,
    required this.actorId,
    required this.actorRole,
    required this.occurredAt,
    required this.reason,
    required this.reasonCategory,
    required this.snoozedUntil,
  });

  final String id;
  final String promptId;
  final DecisionSupportFollowupStatus status;
  final String actorId;
  final DecisionSupportFollowupActorRole actorRole;
  final DateTime occurredAt;
  final String? reason;
  final DecisionSupportFeedbackReasonCategory? reasonCategory;
  final DateTime? snoozedUntil;

  factory DecisionSupportFeedback.create({
    required String promptId,
    required DecisionSupportFollowupStatus status,
    required String actorId,
    required DecisionSupportFollowupActorRole actorRole,
    required DateTime occurredAt,
    String? reason,
    DecisionSupportFeedbackReasonCategory? reasonCategory,
    DateTime? snoozedUntil,
  }) => DecisionSupportFeedback._create(
    promptId: promptId,
    status: status,
    actorId: actorId,
    actorRole: actorRole,
    occurredAt: occurredAt,
    reason: reason,
    reasonCategory: reasonCategory,
    allowUnclassifiedReasonCategory: false,
    snoozedUntil: snoozedUntil,
  );

  factory DecisionSupportFeedback._create({
    required String promptId,
    required DecisionSupportFollowupStatus status,
    required String actorId,
    required DecisionSupportFollowupActorRole actorRole,
    required DateTime occurredAt,
    String? reason,
    DecisionSupportFeedbackReasonCategory? reasonCategory,
    required bool allowUnclassifiedReasonCategory,
    DateTime? snoozedUntil,
  }) {
    if (reasonCategory != null &&
        !_reasonRequiredFollowupStatuses.contains(status)) {
      throw const FormatException(
        'A reason category is only valid for reasoned feedback.',
      );
    }
    if (!RegExp(r'^followup_[a-f0-9]{64}$').hasMatch(promptId)) {
      throw const FormatException('Invalid follow-up prompt identity.');
    }
    _text(actorId, 'actorId', max: 512);
    if (reason != null) _text(reason, 'reason', max: 2000);
    if (status == DecisionSupportFollowupStatus.unread) {
      throw const FormatException('Unread is the initial state, not feedback.');
    }
    if (_reasonRequiredFollowupStatuses.contains(status) && reason == null) {
      throw const FormatException('Closing a prompt requires a reason.');
    }
    if (_reasonRequiredFollowupStatuses.contains(status) &&
        reasonCategory == null &&
        !allowUnclassifiedReasonCategory) {
      throw const FormatException(
        'Closing feedback requires a reason category.',
      );
    }
    if (status == DecisionSupportFollowupStatus.snoozed) {
      if (snoozedUntil == null || !snoozedUntil.isAfter(occurredAt)) {
        throw const FormatException('Snooze must end after the action time.');
      }
    } else if (snoozedUntil != null) {
      throw const FormatException('Only snoozed feedback may have a deadline.');
    }
    final utcTime = occurredAt.toUtc();
    final utcUntil = snoozedUntil?.toUtc();
    final fields = _feedbackFields(
      promptId: promptId,
      status: status,
      actorId: actorId,
      actorRole: actorRole,
      occurredAt: utcTime,
      reason: reason,
      reasonCategory: reasonCategory,
      snoozedUntil: utcUntil,
    );
    return DecisionSupportFeedback._(
      id: 'feedback_${_digest(fields)}',
      promptId: promptId,
      status: status,
      actorId: actorId,
      actorRole: actorRole,
      occurredAt: utcTime,
      reason: reason,
      reasonCategory: reasonCategory,
      snoozedUntil: utcUntil,
    );
  }

  factory DecisionSupportFeedback.fromJson(
    Map<String, dynamic> json, {
    required int ledgerSchemaVersion,
  }) {
    final legacy = ledgerSchemaVersion < 3;
    _exactKeys(json, {
      'id',
      'promptId',
      'status',
      'actorId',
      'actorRole',
      'occurredAt',
      'reason',
      'snoozedUntil',
      if (!legacy) 'reasonCategory',
    });
    final feedback = DecisionSupportFeedback._create(
      promptId: _text(json['promptId'], 'promptId'),
      status: _enumValue(DecisionSupportFollowupStatus.values, json['status']),
      actorId: _text(json['actorId'], 'actorId', max: 512),
      actorRole: _enumValue(
        DecisionSupportFollowupActorRole.values,
        json['actorRole'],
      ),
      occurredAt: _utc(json['occurredAt']),
      reason: json['reason'] == null
          ? null
          : _text(json['reason'], 'reason', max: 2000),
      reasonCategory: legacy || json['reasonCategory'] == null
          ? null
          : _enumValue(
              DecisionSupportFeedbackReasonCategory.values,
              json['reasonCategory'],
            ),
      allowUnclassifiedReasonCategory: true,
      snoozedUntil: json['snoozedUntil'] == null
          ? null
          : _utc(json['snoozedUntil']),
    );
    if (feedback.id != json['id']) {
      throw const FormatException('Feedback identity does not match.');
    }
    return feedback;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    ..._feedbackFields(
      promptId: promptId,
      status: status,
      actorId: actorId,
      actorRole: actorRole,
      occurredAt: occurredAt,
      reason: reason,
      reasonCategory: reasonCategory,
      snoozedUntil: snoozedUntil,
      includeUnclassifiedReasonCategory: true,
    ),
  };
}

/// Local persistence envelope. Owner validation is mandatory on every restore.
/// Limits reject an overfull ledger rather than silently discard its history.
final class DecisionSupportFollowupLedger {
  DecisionSupportFollowupLedger._({
    required this.ownerScopeDigest,
    required this.prompts,
    required this.feedback,
  });

  static const int schemaVersion = 3;
  static const Set<int> acceptedLegacyVersions = {1, 2};
  static const int maxPrompts = 1000;
  static const int maxFeedback = 5000;
  static const int maxJsonLength = 8 * 1024 * 1024;

  final String ownerScopeDigest;
  final List<DecisionSupportPrompt> prompts;
  final List<DecisionSupportFeedback> feedback;

  factory DecisionSupportFollowupLedger.empty(String ownerScope) =>
      DecisionSupportFollowupLedger.create(ownerScope: ownerScope);

  factory DecisionSupportFollowupLedger.decode(
    String encoded, {
    required String ownerScope,
  }) {
    if (encoded.length > maxJsonLength) {
      throw const FormatException('Follow-up ledger size limit exceeded.');
    }
    return DecisionSupportFollowupLedger.fromJson(
      _object(jsonDecode(encoded)),
      ownerScope: ownerScope,
    );
  }

  factory DecisionSupportFollowupLedger.create({
    required String ownerScope,
    List<DecisionSupportPrompt> prompts = const [],
    List<DecisionSupportFeedback> feedback = const [],
  }) {
    final digest = decisionSupportOwnerScopeDigest(ownerScope);
    if (prompts.length > maxPrompts || feedback.length > maxFeedback) {
      throw const FormatException('Follow-up ledger capacity exceeded.');
    }
    final byId = <String, DecisionSupportPrompt>{};
    for (final prompt in prompts) {
      if (prompt.ownerScopeDigest != digest || byId.containsKey(prompt.id)) {
        throw const FormatException('Prompt owner mismatch or duplicate.');
      }
      byId[prompt.id] = prompt;
    }
    final last = <String, DecisionSupportFeedback>{};
    final eventIds = <String>{};
    for (final event in feedback) {
      final prompt = byId[event.promptId];
      final previous = last[event.promptId];
      if (prompt == null || !eventIds.add(event.id)) {
        throw const FormatException('Unknown prompt or duplicate feedback.');
      }
      if (event.occurredAt.isBefore(previous?.occurredAt ?? prompt.createdAt)) {
        throw const FormatException('Feedback cannot precede its history.');
      }
      final from = previous?.status ?? DecisionSupportFollowupStatus.unread;
      if (event.status == from &&
          from != DecisionSupportFollowupStatus.snoozed) {
        throw const FormatException('Feedback must change the workflow state.');
      }
      if (_closedFollowupStatuses.contains(from) &&
          event.status != DecisionSupportFollowupStatus.needsReview) {
        throw const FormatException('Reopen a closed prompt for review first.');
      }
      last[event.promptId] = event;
    }
    final ledger = DecisionSupportFollowupLedger._(
      ownerScopeDigest: digest,
      prompts: List.unmodifiable(prompts),
      feedback: List.unmodifiable(feedback),
    );
    if (jsonEncode(ledger.toJson()).length > maxJsonLength) {
      throw const FormatException('Follow-up ledger size limit exceeded.');
    }
    return ledger;
  }

  factory DecisionSupportFollowupLedger.fromJson(
    Map<String, dynamic> json, {
    required String ownerScope,
  }) {
    _exactKeys(json, const {
      'schemaVersion',
      'ownerScopeDigest',
      'prompts',
      'feedback',
    });
    final version = json['schemaVersion'];
    if (version is! int ||
        (version != schemaVersion &&
            !acceptedLegacyVersions.contains(version)) ||
        json['ownerScopeDigest'] !=
            decisionSupportOwnerScopeDigest(ownerScope)) {
      throw const FormatException('Follow-up schema or owner mismatch.');
    }
    final prompts = _list(json['prompts'], maxPrompts);
    final feedbackRows = _list(json['feedback'], maxFeedback);
    final feedback = feedbackRows
        .map(
          (value) => DecisionSupportFeedback.fromJson(
            _object(value),
            ledgerSchemaVersion: version,
          ),
        )
        .toList();
    if (version == 1 &&
        feedback.any(
          (event) =>
              event.status == DecisionSupportFollowupStatus.notApplicable ||
              event.status == DecisionSupportFollowupStatus.declined,
        )) {
      throw const FormatException('Schema v1 cannot contain schema-v2 states.');
    }
    return DecisionSupportFollowupLedger.create(
      ownerScope: ownerScope,
      prompts: prompts
          .map(
            (value) => DecisionSupportPrompt.fromJson(
              _object(value),
              ownerScope: ownerScope,
            ),
          )
          .toList(),
      feedback: feedback,
    );
  }

  void requireOwner(String ownerScope) {
    if (ownerScopeDigest != decisionSupportOwnerScopeDigest(ownerScope)) {
      throw const FormatException('Follow-up ledger belongs to another owner.');
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'ownerScopeDigest': ownerScopeDigest,
    'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
    'feedback': feedback.map((event) => event.toJson()).toList(),
  };
}

/// Time-dependent display projection; expiry does not fabricate user feedback.
final class DecisionSupportFollowupItem {
  DecisionSupportFollowupItem({
    required this.prompt,
    required List<DecisionSupportFeedback> history,
    required DateTime now,
  }) : history = List.unmodifiable(history),
       now = now.toUtc();

  final DecisionSupportPrompt prompt;
  final List<DecisionSupportFeedback> history;
  final DateTime now;

  DecisionSupportFeedback? get latestFeedback =>
      history.isEmpty ? null : history.last;
  DecisionSupportFollowupStatus get recordedStatus =>
      latestFeedback?.status ?? DecisionSupportFollowupStatus.unread;
  DateTime? get snoozedUntil => latestFeedback?.snoozedUntil;
  bool get isSnoozed =>
      recordedStatus == DecisionSupportFollowupStatus.snoozed &&
      snoozedUntil!.isAfter(now);
  DecisionSupportFollowupStatus get status =>
      recordedStatus == DecisionSupportFollowupStatus.snoozed && !isSnoozed
      ? DecisionSupportFollowupStatus.needsReview
      : recordedStatus;
  bool get hasUserFeedback => history.isNotEmpty;
  bool get isClosed => _closedFollowupStatuses.contains(recordedStatus);
  bool get isSuppressed =>
      isSnoozed || isClosed || status == DecisionSupportFollowupStatus.read;
}

String decisionSupportOwnerScopeDigest(String ownerScope) {
  _text(ownerScope, 'ownerScope', max: 512);
  return _digest({'ownerScope': ownerScope, 'domain': 'decision-support/1'});
}

Map<String, Object?> _feedbackFields({
  required String promptId,
  required DecisionSupportFollowupStatus status,
  required String actorId,
  required DecisionSupportFollowupActorRole actorRole,
  required DateTime occurredAt,
  required String? reason,
  required DecisionSupportFeedbackReasonCategory? reasonCategory,
  required DateTime? snoozedUntil,
  bool includeUnclassifiedReasonCategory = false,
}) {
  final fields = <String, Object?>{
    'promptId': promptId,
    'status': status.name,
    'actorId': actorId,
    'actorRole': actorRole.name,
    'occurredAt': occurredAt.toIso8601String(),
    'reason': reason,
    'snoozedUntil': snoozedUntil?.toIso8601String(),
  };
  if (reasonCategory != null || includeUnclassifiedReasonCategory) {
    fields['reasonCategory'] = reasonCategory?.name;
  }
  return fields;
}

String _text(Object? value, String field, {int max = 256}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      value.contains('\u0000')) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected a JSON object.');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Object? value, int max) {
  if (value is! List || value.length > max) {
    throw const FormatException('Expected a bounded list.');
  }
  return value;
}

List<String> _strings(Object? value) => _list(
  value,
  128,
).map((item) => _text(item, 'list item', max: 2000)).toList();

List<String> _orderedStrings(List<String> values, String field) {
  if (values.length > 128) throw FormatException('Too many $field.');
  for (final value in values) {
    _text(value, field, max: 2000);
  }
  return List.unmodifiable(values.toSet().toList()..sort());
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length || !expected.containsAll(json.keys)) {
    throw const FormatException('Unexpected follow-up JSON fields.');
  }
}

T _enumValue<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw const FormatException('Unknown follow-up enum value.');
}

DateTime _utc(Object? value) {
  final text = _text(value, 'UTC time', max: 40);
  final date = DateTime.tryParse(text);
  if (date == null || !date.isUtc || date.toIso8601String() != text) {
    throw const FormatException('Expected a canonical UTC time.');
  }
  return date;
}

Map<String, Object?> _freezeInputs(Map<String, Object?> source) {
  var nodes = 0;
  Object? freeze(Object? value, int depth) {
    if (++nodes > 4096 || depth > 16) {
      throw const FormatException('Input snapshot exceeds complexity limits.');
    }
    if (value == null || value is bool) return value;
    if (value is String) {
      if (value.length > 8000) {
        throw const FormatException('Input text too long.');
      }
      return value;
    }
    if (value is num) {
      if (!value.isFinite) {
        throw const FormatException('Non-finite input value.');
      }
      return value;
    }
    if (value is List && value.length <= 1024) {
      return List<Object?>.unmodifiable(value.map((v) => freeze(v, depth + 1)));
    }
    if (value is Map &&
        value.length <= 256 &&
        value.keys.every((key) => key is String)) {
      return Map<String, Object?>.unmodifiable(
        value.map(
          (key, v) => MapEntry(_text(key, 'input key'), freeze(v, depth + 1)),
        ),
      );
    }
    throw const FormatException('Unsupported input snapshot value.');
  }

  final frozen = freeze(source, 0) as Map<String, Object?>;
  if (utf8.encode(_canonical(frozen)).length > 65536) {
    throw const FormatException('Input snapshot size limit exceeded.');
  }
  return frozen;
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonical(value))).toString();

String _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  return jsonEncode(value);
}
