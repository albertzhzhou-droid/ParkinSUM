import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_approval_envelope.dart';

final _time = DateTime.utc(2026, 9, 22, 12);
String _digest(String character) => character * 64;

KnowledgeApprovalBinding _binding({
  int sequence = 1,
  String? previous,
  String? ruleId,
  String? ruleVersion,
}) => KnowledgeApprovalBinding(
  packId: 'pack-a',
  packVersion: '1.0.0',
  packDigest: _digest('a'),
  engineDigest: _digest('b'),
  suiteDigest: _digest('c'),
  sequence: sequence,
  previousEnvelopeDigest: previous,
  ruleId: ruleId,
  ruleVersion: ruleVersion,
);

KnowledgeApprovalStatement _statement() => KnowledgeApprovalStatement(
  approvalId: 'approval-1',
  issuer: 'authority-test',
  environment: 'test',
  keyId: 'author-key',
  subjectId: 'author-subject',
  authorSubjectId: 'author-subject',
  role: KnowledgeApprovalRole.author,
  decision: KnowledgeApprovalDecision.authored,
  binding: _binding(),
  issuedAtUtc: _time,
  notBeforeUtc: _time,
  expiresAtUtc: _time.add(const Duration(days: 1)),
);

KnowledgeApprovalEnvelope _envelope() => KnowledgeApprovalEnvelope(
  statement: _statement(),
  signatureBase64Url: base64Url.encode(List.filled(64, 0)).replaceAll('=', ''),
);

void main() {
  test(
    'canonical envelope roundtrip retains all content, identity and chain bindings',
    () {
      final envelope = _envelope();
      final restored = KnowledgeApprovalEnvelope.parseJson(
        envelope.canonicalJson,
      );
      expect(restored.toJson(), envelope.toJson());
      expect(restored.sha256, envelope.sha256);
      expect(
        restored.statement.binding.matches(envelope.statement.binding),
        isTrue,
      );
      expect(restored.statement.scope, KnowledgeApprovalScope.pack);
      expect(() => restored.signatureBytes[0] = 1, throwsUnsupportedError);
      final exported = envelope.toJson();
      (exported['signed'] as Map)['issuer'] = 'changed';
      expect(envelope.statement.issuer, 'authority-test');
    },
  );

  test(
    'binding equality includes every artifact component and ledger predecessor',
    () {
      final binding = _binding(
        sequence: 2,
        previous: _digest('d'),
        ruleId: 'r',
        ruleVersion: '1',
      );
      final mutations = <String, Object?>{
        'pack_id': 'pack-b',
        'pack_version': '2',
        'pack_digest': _digest('e'),
        'engine_digest': _digest('e'),
        'suite_digest': _digest('e'),
        'rule_id': 'r2',
        'rule_version': '2',
        'sequence': 3,
        'previous_envelope_digest': _digest('e'),
      };
      for (final entry in mutations.entries) {
        final changed = KnowledgeApprovalBinding.fromJson({
          ...binding.toJson(),
          entry.key: entry.value,
        });
        expect(binding.matches(changed), isFalse, reason: entry.key);
      }
      expect(binding.sameArtifact(_binding()), isTrue);
    },
  );

  test(
    'sequence origin, predecessor, per-rule scope and numeric types are closed',
    () {
      for (final sequence in [0, -1, 9007199254740992]) {
        expect(() => _binding(sequence: sequence), throwsFormatException);
      }
      expect(() => _binding(sequence: 2), throwsFormatException);
      expect(() => _binding(previous: _digest('d')), throwsFormatException);
      expect(() => _binding(ruleId: 'r'), throwsFormatException);
      expect(() => _binding(ruleVersion: '1'), throwsFormatException);
      expect(
        () => KnowledgeApprovalBinding.fromJson({
          ..._binding().toJson(),
          'sequence': 1.0,
        }),
        throwsFormatException,
      );
      expect(
        () => KnowledgeApprovalBinding.fromJson({
          ..._binding().toJson(),
          'pack_digest': 'not-a-digest',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'unsupported schemas, role/scope/decision combinations and name-only claims reject',
    () {
      final base = _statement().toJson();
      final invalid = [
        {...base, 'schema_version': 2},
        {...base, 'schema_version': 1.0},
        {...base, r'$schema': 'parkinsum.signed-capability-manifest/1'},
        {...base, 'purpose': 'capability-enable'},
        {...base, 'role': 'administrator'},
        {...base, 'decision': 'approved'},
        {...base, 'scope': 'rule'},
        {...base, 'subject_id': 'another-author'},
        {...base, 'reviewer_name': 'Dr Test'},
        {'reviewer_name': 'Dr Test', 'approved': true},
      ];
      for (final json in invalid) {
        expect(
          () => KnowledgeApprovalStatement.fromJson(json),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'canonical UTC parsing rejects absent offsets, overflow and unsupported years',
    () {
      for (final timestamp in [
        '2026-09-22T12:00:00',
        '2026-09-22T12:00:00+00:00',
        '2026-02-30T12:00:00.000Z',
        '2026-09-22T25:00:00.000Z',
        '0000-01-01T00:00:00.000Z',
        '+010000-01-01T00:00:00.000Z',
      ]) {
        expect(
          () => KnowledgeApprovalStatement.fromJson({
            ..._statement().toJson(),
            'issued_at': timestamp,
          }),
          throwsFormatException,
          reason: timestamp,
        );
      }
      expect(
        () => KnowledgeApprovalStatement.fromJson({
          ..._statement().toJson(),
          'expires_at': _time.toIso8601String(),
        }),
        throwsFormatException,
      );
      expect(
        () => requireKnowledgeApprovalUtc(DateTime(2026, 9, 22)),
        throwsFormatException,
      );
    },
  );

  test(
    'strict signature metadata and canonical base64url reject malformed envelopes',
    () {
      final base = _envelope().toJson();
      final signature = Map<String, Object?>.from(base['signature']! as Map);
      for (final edited in [
        {...signature, 'algorithm': 'none'},
        {...signature, 'key_id': 'different'},
        {...signature, 'value_base64url': ''},
        {...signature, 'value_base64url': '${signature['value_base64url']}=='},
        {...signature, 'value_base64url': 'A' * 85},
        {...signature, 'public_key': 'supplied-in-document'},
      ]) {
        expect(
          () => KnowledgeApprovalEnvelope.parseJson(
            jsonEncode({...base, 'signature': edited}),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => KnowledgeApprovalEnvelope.parseJson(
          jsonEncode({'signed': _statement().toJson()}),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'duplicate keys including escaped aliases are rejected before decoding',
    () {
      final raw = _envelope().canonicalJson;
      expect(
        () => KnowledgeApprovalEnvelope.parseJson(
          raw.replaceFirst(
            '"issuer":"authority-test"',
            '"issuer":"authority-test","issuer":"authority-test"',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => KnowledgeApprovalEnvelope.parseJson(
          raw.replaceFirst(
            '"issuer":"authority-test"',
            '"issuer":"authority-test","iss\\u0075er":"authority-test"',
          ),
        ),
        throwsFormatException,
      );
      final pretty = const JsonEncoder.withIndent(
        '  ',
      ).convert(_envelope().toJson());
      expect(
        KnowledgeApprovalEnvelope.parseJson(pretty).sha256,
        _envelope().sha256,
      );
    },
  );

  test(
    'size, nesting, array, text and identifier limits reject hostile payloads',
    () {
      for (final raw in [
        ' ' * (knowledgeApprovalMaxBytes + 1),
        '${'{"x":' * 9}0${'}' * 9}',
        '[]',
        '{"signed":[]}',
      ]) {
        expect(
          () => KnowledgeApprovalEnvelope.parseJson(raw),
          throwsFormatException,
        );
      }
      for (final reason in [
        ' ',
        'x' * 2001,
        'bad\u0000text',
        String.fromCharCode(0xd800),
      ]) {
        expect(
          () => KnowledgeApprovalStatement.fromJson({
            ..._statement().toJson(),
            'reason': reason,
          }),
          throwsFormatException,
        );
      }
      for (final id in ['', 'author name', 'a' * 201, 'author\n']) {
        expect(
          () => requireKnowledgeApprovalIdentifier(id),
          throwsFormatException,
        );
      }
    },
  );
}
