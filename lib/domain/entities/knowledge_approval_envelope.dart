import 'dart:convert';

import 'signed_capability_manifest.dart'
    show canonicalCapabilityJson, sha256OfCanonicalCapabilityJson;

const knowledgeApprovalSchema = 'parkinsum.knowledge-approval/1';
const knowledgeApprovalSchemaVersion = 1;
const knowledgeApprovalMaxBytes = 64 * 1024;

enum KnowledgeApprovalRole { author, reviewer, publisher }

enum KnowledgeApprovalScope { pack, rule }

enum KnowledgeApprovalDecision {
  authored,
  approved,
  rejected,
  published,
  withdrawn,
}

/// All result-affecting content and the expected ledger position are signed.
/// The caller must derive sequence/predecessor from its authoritative ledger;
/// accepting the envelope's own values as expectations provides no replay gate.
final class KnowledgeApprovalBinding {
  KnowledgeApprovalBinding({
    required this.packId,
    required this.packVersion,
    required this.packDigest,
    required this.engineDigest,
    required this.suiteDigest,
    required this.sequence,
    required this.previousEnvelopeDigest,
    this.ruleId,
    this.ruleVersion,
  }) {
    for (final id in [packId, packVersion, ?ruleId, ?ruleVersion]) {
      requireKnowledgeApprovalIdentifier(id);
    }
    for (final digest in [
      packDigest,
      engineDigest,
      suiteDigest,
      ?previousEnvelopeDigest,
    ]) {
      _requireDigest(digest);
    }
    if ((ruleId == null) != (ruleVersion == null) ||
        sequence < 1 ||
        sequence > 9007199254740991 ||
        (sequence == 1) != (previousEnvelopeDigest == null)) {
      throw const FormatException('knowledge_approval_binding_invalid');
    }
  }

  final String packId;
  final String packVersion;
  final String packDigest;
  final String engineDigest;
  final String suiteDigest;
  final int sequence;
  final String? previousEnvelopeDigest;
  final String? ruleId;
  final String? ruleVersion;

  KnowledgeApprovalScope get scope => ruleId == null
      ? KnowledgeApprovalScope.pack
      : KnowledgeApprovalScope.rule;

  bool matches(KnowledgeApprovalBinding other) =>
      sameArtifact(other) &&
      ruleId == other.ruleId &&
      ruleVersion == other.ruleVersion &&
      sequence == other.sequence &&
      previousEnvelopeDigest == other.previousEnvelopeDigest;

  /// Pack-scoped authorship can establish the author of a per-rule review.
  /// This comparison deliberately does not authorize a ledger transition.
  bool sameArtifact(KnowledgeApprovalBinding other) =>
      packId == other.packId &&
      packVersion == other.packVersion &&
      packDigest == other.packDigest &&
      engineDigest == other.engineDigest &&
      suiteDigest == other.suiteDigest;

  Map<String, Object?> toJson() => {
    'pack_id': packId,
    'pack_version': packVersion,
    'pack_digest': packDigest,
    'engine_digest': engineDigest,
    'suite_digest': suiteDigest,
    'rule_id': ruleId,
    'rule_version': ruleVersion,
    'sequence': sequence,
    'previous_envelope_digest': previousEnvelopeDigest,
  };

  factory KnowledgeApprovalBinding.fromJson(Map<String, dynamic> json) {
    _keys(json, const {
      'pack_id',
      'pack_version',
      'pack_digest',
      'engine_digest',
      'suite_digest',
      'rule_id',
      'rule_version',
      'sequence',
      'previous_envelope_digest',
    });
    final sequence = json['sequence'];
    if (sequence is! int) {
      throw const FormatException('knowledge_approval_sequence_invalid');
    }
    return KnowledgeApprovalBinding(
      packId: _string(json['pack_id']),
      packVersion: _string(json['pack_version']),
      packDigest: _string(json['pack_digest']),
      engineDigest: _string(json['engine_digest']),
      suiteDigest: _string(json['suite_digest']),
      ruleId: _nullableString(json['rule_id']),
      ruleVersion: _nullableString(json['rule_version']),
      sequence: sequence,
      previousEnvelopeDigest: _nullableString(json['previous_envelope_digest']),
    );
  }
}

/// A statement to sign, not evidence that its claimed signer is trusted.
/// Roles and subjects become authoritative only after cryptographic verification
/// against an externally supplied trust policy.
final class KnowledgeApprovalStatement {
  KnowledgeApprovalStatement({
    required this.approvalId,
    required this.issuer,
    required this.environment,
    required this.keyId,
    required this.subjectId,
    required this.authorSubjectId,
    required this.role,
    required this.decision,
    required this.binding,
    required this.issuedAtUtc,
    required this.notBeforeUtc,
    required this.expiresAtUtc,
    this.reason,
  }) {
    for (final id in [
      approvalId,
      issuer,
      environment,
      keyId,
      subjectId,
      authorSubjectId,
    ]) {
      requireKnowledgeApprovalIdentifier(id);
    }
    for (final time in [issuedAtUtc, notBeforeUtc, expiresAtUtc]) {
      requireKnowledgeApprovalUtc(time);
    }
    if (notBeforeUtc.isBefore(issuedAtUtc) ||
        !expiresAtUtc.isAfter(notBeforeUtc)) {
      throw const FormatException('knowledge_approval_time_window_invalid');
    }
    final validContract = switch (role) {
      KnowledgeApprovalRole.author =>
        decision == KnowledgeApprovalDecision.authored &&
            binding.scope == KnowledgeApprovalScope.pack &&
            subjectId == authorSubjectId,
      KnowledgeApprovalRole.reviewer =>
        (decision == KnowledgeApprovalDecision.approved ||
                decision == KnowledgeApprovalDecision.rejected) &&
            binding.scope == KnowledgeApprovalScope.rule,
      KnowledgeApprovalRole.publisher =>
        (decision == KnowledgeApprovalDecision.published ||
                decision == KnowledgeApprovalDecision.withdrawn) &&
            binding.scope == KnowledgeApprovalScope.pack,
    };
    if (!validContract) {
      throw const FormatException(
        'knowledge_approval_role_scope_decision_invalid',
      );
    }
    if (reason != null) _requireReason(reason!);
  }

  final String approvalId;
  final String issuer;
  final String environment;
  final String keyId;
  final String subjectId;
  final String authorSubjectId;
  final KnowledgeApprovalRole role;
  final KnowledgeApprovalDecision decision;
  final KnowledgeApprovalBinding binding;
  final DateTime issuedAtUtc;
  final DateTime notBeforeUtc;
  final DateTime expiresAtUtc;
  final String? reason;

  KnowledgeApprovalScope get scope => binding.scope;

  Map<String, Object?> toJson() => {
    r'$schema': knowledgeApprovalSchema,
    'schema_version': knowledgeApprovalSchemaVersion,
    'purpose': 'knowledge-lifecycle-approval',
    'approval_id': approvalId,
    'issuer': issuer,
    'environment': environment,
    'key_id': keyId,
    'subject_id': subjectId,
    'author_subject_id': authorSubjectId,
    'role': role.name,
    'scope': scope.name,
    'decision': decision.name,
    'binding': binding.toJson(),
    'issued_at': issuedAtUtc.toIso8601String(),
    'not_before': notBeforeUtc.toIso8601String(),
    'expires_at': expiresAtUtc.toIso8601String(),
    'reason': reason,
  };

  String get canonicalJson => canonicalCapabilityJson(toJson());

  factory KnowledgeApprovalStatement.fromJson(Map<String, dynamic> json) {
    _keys(json, const {
      r'$schema',
      'schema_version',
      'purpose',
      'approval_id',
      'issuer',
      'environment',
      'key_id',
      'subject_id',
      'author_subject_id',
      'role',
      'scope',
      'decision',
      'binding',
      'issued_at',
      'not_before',
      'expires_at',
      'reason',
    });
    if (json[r'$schema'] != knowledgeApprovalSchema ||
        json['schema_version'] is! int ||
        json['schema_version'] != knowledgeApprovalSchemaVersion ||
        json['purpose'] != 'knowledge-lifecycle-approval') {
      throw const FormatException('knowledge_approval_schema_unsupported');
    }
    final statement = KnowledgeApprovalStatement(
      approvalId: _string(json['approval_id']),
      issuer: _string(json['issuer']),
      environment: _string(json['environment']),
      keyId: _string(json['key_id']),
      subjectId: _string(json['subject_id']),
      authorSubjectId: _string(json['author_subject_id']),
      role: _choice(KnowledgeApprovalRole.values, json['role']),
      decision: _choice(KnowledgeApprovalDecision.values, json['decision']),
      binding: KnowledgeApprovalBinding.fromJson(_map(json['binding'])),
      issuedAtUtc: _time(json['issued_at']),
      notBeforeUtc: _time(json['not_before']),
      expiresAtUtc: _time(json['expires_at']),
      reason: _nullableString(json['reason']),
    );
    if (json['scope'] != statement.scope.name) {
      throw const FormatException('knowledge_approval_scope_invalid');
    }
    return statement;
  }
}

final class KnowledgeApprovalEnvelope {
  KnowledgeApprovalEnvelope({
    required this.statement,
    required this.signatureBase64Url,
  }) {
    _signature(signatureBase64Url);
  }

  final KnowledgeApprovalStatement statement;
  final String signatureBase64Url;

  /// Ed25519 signatures use the UTF-8 bytes of statement.canonicalJson.
  List<int> get signatureBytes =>
      List.unmodifiable(_signature(signatureBase64Url));

  Map<String, Object?> toJson() => {
    'signed': statement.toJson(),
    'signature': {
      'algorithm': 'Ed25519',
      'key_id': statement.keyId,
      'value_base64url': signatureBase64Url,
    },
  };

  String get canonicalJson => canonicalCapabilityJson(toJson());
  String get sha256 => sha256OfCanonicalCapabilityJson(toJson());

  factory KnowledgeApprovalEnvelope.parseJson(String raw) {
    _checkJson(raw);
    final json = _map(jsonDecode(raw));
    _keys(json, const {'signed', 'signature'});
    final statement = KnowledgeApprovalStatement.fromJson(_map(json['signed']));
    final signature = _map(json['signature']);
    _keys(signature, const {'algorithm', 'key_id', 'value_base64url'});
    if (signature['algorithm'] != 'Ed25519' ||
        signature['key_id'] != statement.keyId) {
      throw const FormatException(
        'knowledge_approval_signature_metadata_invalid',
      );
    }
    return KnowledgeApprovalEnvelope(
      statement: statement,
      signatureBase64Url: _string(signature['value_base64url']),
    );
  }
}

/// Shared construction checks for this closed envelope and its trust registry.
void requireKnowledgeApprovalIdentifier(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,199}$').hasMatch(value)) {
    throw const FormatException('knowledge_approval_identifier_invalid');
  }
}

void requireKnowledgeApprovalUtc(DateTime value) {
  if (!value.isUtc || value.year < 1 || value.year > 9999) {
    throw const FormatException('knowledge_approval_utc_required');
  }
}

void _requireDigest(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const FormatException('knowledge_approval_digest_invalid');
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('knowledge_approval_object_required');
  }
  return Map<String, dynamic>.from(value);
}

void _keys(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length || !keys.containsAll(value.keys)) {
    throw const FormatException('knowledge_approval_unknown_or_missing_fields');
  }
}

String _string(Object? value) {
  if (value is! String || value.isEmpty || value.length > 2000) {
    throw const FormatException('knowledge_approval_string_invalid');
  }
  return value;
}

String? _nullableString(Object? value) => value == null ? null : _string(value);

T _choice<T extends Enum>(List<T> choices, Object? value) {
  for (final choice in choices) {
    if (choice.name == value) return choice;
  }
  throw const FormatException('knowledge_approval_enum_invalid');
}

DateTime _time(Object? value) {
  final text = _string(value);
  final time = DateTime.tryParse(text);
  if (time == null || !time.isUtc || time.toIso8601String() != text) {
    throw const FormatException('knowledge_approval_timestamp_not_canonical');
  }
  requireKnowledgeApprovalUtc(time);
  return time;
}

List<int> _signature(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{86}$').hasMatch(value)) {
    throw const FormatException('knowledge_approval_signature_invalid');
  }
  final bytes = base64Url.decode(base64Url.normalize(value));
  if (bytes.length != 64 ||
      base64Url.encode(bytes).replaceAll('=', '') != value) {
    throw const FormatException('knowledge_approval_signature_invalid');
  }
  return bytes;
}

void _requireReason(String value) {
  if (value.trim().isEmpty ||
      value.length > 2000 ||
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value)) {
    throw const FormatException('knowledge_approval_reason_invalid');
  }
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++index >= value.length ||
          value.codeUnitAt(index) < 0xdc00 ||
          value.codeUnitAt(index) > 0xdfff) {
        throw const FormatException('knowledge_approval_unicode_invalid');
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('knowledge_approval_unicode_invalid');
    }
  }
}

/// Reject oversized/deep JSON and duplicate object members before jsonDecode.
/// This fixed schema contains objects and scalars only; no arrays are allowed.
void _checkJson(String raw) {
  if (raw.length > knowledgeApprovalMaxBytes ||
      utf8.encode(raw).length > knowledgeApprovalMaxBytes) {
    throw const FormatException('knowledge_approval_payload_too_large');
  }
  final members = <Set<String>>[];
  final expectingKey = <bool>[];
  for (var index = 0; index < raw.length; index++) {
    final code = raw.codeUnitAt(index);
    if (code == 34) {
      final start = index;
      var closed = false;
      while (++index < raw.length) {
        if (raw.codeUnitAt(index) == 92) {
          index++;
          continue;
        }
        if (raw.codeUnitAt(index) == 34) {
          closed = true;
          break;
        }
      }
      if (!closed) {
        throw const FormatException('knowledge_approval_json_invalid');
      }
      if (members.isNotEmpty && expectingKey.last) {
        final key = jsonDecode(raw.substring(start, index + 1));
        if (key is! String || !members.last.add(key)) {
          throw const FormatException('knowledge_approval_duplicate_key');
        }
        expectingKey[expectingKey.length - 1] = false;
      }
    } else if (code == 123) {
      members.add(<String>{});
      expectingKey.add(true);
      if (members.length > 8) {
        throw const FormatException('knowledge_approval_depth_limit');
      }
    } else if (code == 125) {
      if (members.isEmpty) {
        throw const FormatException('knowledge_approval_json_invalid');
      }
      members.removeLast();
      expectingKey.removeLast();
    } else if (code == 44 && expectingKey.isNotEmpty) {
      expectingKey[expectingKey.length - 1] = true;
    } else if (code == 91 || code == 93) {
      throw const FormatException('knowledge_approval_array_not_allowed');
    }
  }
}
