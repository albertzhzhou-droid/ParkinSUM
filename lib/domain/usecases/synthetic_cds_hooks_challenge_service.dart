import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'synthetic_cds_hooks_card_projector.dart';
import 'synthetic_cds_hooks_sandbox_service.dart';

const syntheticCdsHooksChallengeSchemaVersion = 1;

enum SyntheticCdsHooksChallengeReason {
  informationMayBeIncorrect,
  contextMismatch,
  explanationUnclear,
  duplicateOrAlreadyAddressed,
  other,
}

/// A page-memory challenge note bound to one fixed synthetic information card.
/// It contains no actor, time, owner, persistence, or delivery identity.
final class SyntheticCdsHooksChallengeNote {
  const SyntheticCdsHooksChallengeNote({
    required this.inputDigestSha256,
    required this.cardDigestSha256,
    required this.reason,
    required this.rationale,
  });

  final String inputDigestSha256;
  final String cardDigestSha256;
  final SyntheticCdsHooksChallengeReason reason;
  final String rationale;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': 'parkinsum_synthetic_cds_hooks_challenge',
    'schemaVersion': syntheticCdsHooksChallengeSchemaVersion,
    'disposition': 'challenge',
    'inputDigestSha256': inputDigestSha256,
    'cardDigestSha256': cardDigestSha256,
    'reason': reason.name,
    'rationale': rationale,
    'persisted': false,
    'transmitted': false,
    'ruleOutcomeChanged': false,
  };
}

/// Creates an ephemeral review note for the sandbox's one synthetic card.
/// No service call, persistence, rule rerun, or response mutation occurs.
final class SyntheticCdsHooksChallengeService {
  const SyntheticCdsHooksChallengeService();

  SyntheticCdsHooksChallengeNote create({
    required SyntheticCdsHooksSandboxRun run,
    required SyntheticCdsHooksChallengeReason reason,
    required String rationale,
  }) {
    _requireDigest(run.inputDigest, 'input_digest');
    final cleanRationale = _rationale(rationale);
    final rawCards = run.response['cards'];
    if (rawCards is! List || rawCards.length != 1 || rawCards.single is! Map) {
      throw const FormatException('challenge_requires_one_synthetic_card');
    }
    final card = Map<String, dynamic>.from(rawCards.single as Map);
    final extension = card['extension'];
    if (card['indicator'] != 'info' ||
        extension is! Map ||
        extension[cdsHooksRuleTraceExtensionName] is! Map ||
        (extension[cdsHooksRuleTraceExtensionName] as Map)['inputDigest'] !=
            run.inputDigest ||
        (card['source'] is! Map) ||
        ((card['source'] as Map)['label'] !=
            'ParkinSUM synthetic rule explanation')) {
      throw const FormatException('challenge_card_binding_invalid');
    }
    final cardDigest = _digest(_canonicalJson(card));
    return SyntheticCdsHooksChallengeNote(
      inputDigestSha256: run.inputDigest,
      cardDigestSha256: cardDigest,
      reason: reason,
      rationale: cleanRationale,
    );
  }

  String _rationale(String raw) {
    final value = raw.trim();
    if (value.isEmpty ||
        value.length > 1000 ||
        utf8.encode(value).length > 4000 ||
        value.contains('\u0000') ||
        RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F]').hasMatch(value)) {
      throw const FormatException('challenge_rationale_invalid');
    }
    return value;
  }

  void _requireDigest(String value, String field) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw FormatException('challenge_invalid_digest:$field');
    }
  }

  String _canonicalJson(Object? value) => jsonEncode(_sort(value));

  Object? _sort(Object? value) {
    if (value is Map) {
      final entries = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException('challenge_card_key_invalid');
        }
        entries[entry.key as String] = _sort(entry.value);
      }
      final keys = entries.keys.toList()..sort();
      return <String, Object?>{for (final key in keys) key: entries[key]};
    }
    if (value is Iterable) return value.map(_sort).toList(growable: false);
    if (value is num && !value.isFinite) {
      throw const FormatException('challenge_card_number_invalid');
    }
    return value;
  }

  String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
}
