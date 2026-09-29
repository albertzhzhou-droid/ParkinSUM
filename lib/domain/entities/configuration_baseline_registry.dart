import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ConfigurationBaselineTransitionKind { promote, rollback, revoke }

enum ConfigurationBaselineEventKind {
  activated,
  promotionRejected,
  rolledBack,
  rollbackRejected,
  revoked,
  revocationRejected,
}

enum ConfigurationBaselineObligationStatus {
  unresolved,
  satisfied,
  notApplicable,
  rejected,
}

final class ConfigurationBaselineReviewerSignature {
  const ConfigurationBaselineReviewerSignature({
    required this.reviewerId,
    required this.authorityRole,
    required this.keyId,
    required this.signatureBase64,
  });

  final String reviewerId;
  final String authorityRole;
  final String keyId;
  final String signatureBase64;

  Map<String, Object?> toJson() => {
    'reviewer_id': reviewerId,
    'authority_role': authorityRole,
    'key_id': keyId,
    'signature_base64': signatureBase64,
  };
}

/// Exact, independently reviewable authorization request for one active
/// configuration transition. Signatures cover [canonicalSigningPayload].
final class ConfigurationBaselinePromotionReceipt {
  static const String schema =
      'parkinsum.configuration-baseline-promotion-receipt/1';
  static const int schemaVersion = 1;

  ConfigurationBaselinePromotionReceipt({
    required this.receiptId,
    required this.transitionKind,
    required this.proposerId,
    required this.environment,
    required this.targetPopulationScope,
    required this.expectedActiveConfigurationSha256,
    required this.candidateConfigurationSha256,
    required this.rollbackTargetConfigurationSha256,
    required this.sourceBundleSha256,
    required this.buildArtifactSha256,
    required this.changeImpactPackageSha256,
    required this.replayArtifactSha256,
    required this.contextOfUseRecordSha256,
    required this.obligationMatrixSha256,
    required Map<String, ConfigurationBaselineObligationStatus> obligations,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
    required List<ConfigurationBaselineReviewerSignature> signatures,
    required this.boundary,
  }) : obligations = Map.unmodifiable(obligations),
       signatures = List.unmodifiable(signatures) {
    _validate();
  }

  final String receiptId;
  final ConfigurationBaselineTransitionKind transitionKind;
  final String proposerId;
  final String environment;
  final String targetPopulationScope;
  final String expectedActiveConfigurationSha256;
  final String candidateConfigurationSha256;
  final String? rollbackTargetConfigurationSha256;
  final String sourceBundleSha256;
  final String buildArtifactSha256;
  final String changeImpactPackageSha256;
  final String replayArtifactSha256;
  final String contextOfUseRecordSha256;
  final String obligationMatrixSha256;
  final Map<String, ConfigurationBaselineObligationStatus> obligations;
  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;
  final List<ConfigurationBaselineReviewerSignature> signatures;
  final String boundary;

  Map<String, Object?> get canonicalSigningPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'receipt_id': receiptId,
    'transition_kind': transitionKind.name,
    'proposer_id': proposerId,
    'environment': environment,
    'target_population_scope': targetPopulationScope,
    'expected_active_configuration_sha256': expectedActiveConfigurationSha256,
    'candidate_configuration_sha256': candidateConfigurationSha256,
    'rollback_target_configuration_sha256': rollbackTargetConfigurationSha256,
    'source_bundle_sha256': sourceBundleSha256,
    'build_artifact_sha256': buildArtifactSha256,
    'change_impact_package_sha256': changeImpactPackageSha256,
    'replay_artifact_sha256': replayArtifactSha256,
    'context_of_use_record_sha256': contextOfUseRecordSha256,
    'obligation_matrix_sha256': obligationMatrixSha256,
    'obligations': {
      for (final key in obligations.keys.toList()..sort())
        key: obligations[key]!.name,
    },
    'issued_at_utc': issuedAtUtc.toUtc().toIso8601String(),
    'expires_at_utc': expiresAtUtc.toUtc().toIso8601String(),
    'boundary': boundary,
  };

  String get signingPayloadJson => _canonicalJson(canonicalSigningPayload);
  String get signingPayloadSha256 => _digest(canonicalSigningPayload);
  String get receiptSha256 => _digest({
    ...canonicalSigningPayload,
    'signatures': signatures.map((signature) => signature.toJson()).toList(),
  });

  Map<String, Object?> toJson() => {
    ...canonicalSigningPayload,
    'signing_payload_sha256': signingPayloadSha256,
    'signatures': signatures.map((signature) => signature.toJson()).toList(),
    'receipt_sha256': receiptSha256,
  };

  void _validate() {
    final identifiers = [
      receiptId,
      proposerId,
      environment,
      targetPopulationScope,
    ];
    if (identifiers.any((value) => !_identifier.hasMatch(value)) ||
        boundary.trim().isEmpty ||
        !issuedAtUtc.isUtc ||
        !expiresAtUtc.isUtc ||
        !expiresAtUtc.isAfter(issuedAtUtc)) {
      throw ArgumentError('Promotion receipt metadata is invalid.');
    }
    for (final digest in [
      expectedActiveConfigurationSha256,
      candidateConfigurationSha256,
      sourceBundleSha256,
      buildArtifactSha256,
      changeImpactPackageSha256,
      replayArtifactSha256,
      contextOfUseRecordSha256,
      obligationMatrixSha256,
      ?rollbackTargetConfigurationSha256,
    ]) {
      if (!_sha256.hasMatch(digest)) {
        throw ArgumentError('Promotion receipt digest is invalid.');
      }
    }
    if ((transitionKind == ConfigurationBaselineTransitionKind.rollback) !=
        (rollbackTargetConfigurationSha256 != null)) {
      throw ArgumentError('Rollback target does not match transition kind.');
    }
    if (transitionKind == ConfigurationBaselineTransitionKind.rollback &&
        candidateConfigurationSha256 != rollbackTargetConfigurationSha256) {
      throw ArgumentError(
        'Rollback candidate and rollback target must be identical.',
      );
    }
    if (obligations.isEmpty ||
        obligations.keys.any((key) => !_identifier.hasMatch(key))) {
      throw ArgumentError('Promotion receipt obligations are invalid.');
    }
    final reviewerIds = <String>{};
    final roles = <String>{};
    final keyIds = <String>{};
    for (final signature in signatures) {
      if (!_identifier.hasMatch(signature.reviewerId) ||
          !_identifier.hasMatch(signature.authorityRole) ||
          !_identifier.hasMatch(signature.keyId) ||
          signature.signatureBase64.trim().isEmpty ||
          signature.reviewerId == proposerId ||
          !reviewerIds.add(signature.reviewerId) ||
          !roles.add(signature.authorityRole) ||
          !keyIds.add(signature.keyId)) {
        throw ArgumentError('Reviewer separation or signature is invalid.');
      }
    }
  }
}

final class ConfigurationBaselineRegistryEvent {
  ConfigurationBaselineRegistryEvent({
    required this.sequence,
    required this.kind,
    required this.configurationSha256,
    required this.activeConfigurationBeforeSha256,
    required this.activeConfigurationAfterSha256,
    required this.receiptSha256,
    required this.previousEventSha256,
    required this.recordedAtUtc,
    required this.reason,
    required this.environment,
    required this.targetPopulationScope,
  }) {
    if (sequence <= 0 ||
        !recordedAtUtc.isUtc ||
        reason.trim().isEmpty ||
        !_identifier.hasMatch(environment) ||
        !_identifier.hasMatch(targetPopulationScope)) {
      throw ArgumentError('Baseline registry event metadata is invalid.');
    }
    for (final digest in [
      configurationSha256,
      activeConfigurationBeforeSha256,
      activeConfigurationAfterSha256,
      ?receiptSha256,
      ?previousEventSha256,
    ]) {
      if (!_sha256.hasMatch(digest)) {
        throw ArgumentError('Baseline registry event digest is invalid.');
      }
    }
  }

  final int sequence;
  final ConfigurationBaselineEventKind kind;
  final String configurationSha256;
  final String activeConfigurationBeforeSha256;
  final String activeConfigurationAfterSha256;
  final String? receiptSha256;
  final String? previousEventSha256;
  final DateTime recordedAtUtc;
  final String reason;
  final String environment;
  final String targetPopulationScope;

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'kind': kind.name,
    'configuration_sha256': configurationSha256,
    'active_configuration_before_sha256': activeConfigurationBeforeSha256,
    'active_configuration_after_sha256': activeConfigurationAfterSha256,
    'receipt_sha256': receiptSha256,
    'previous_event_sha256': previousEventSha256,
    'recorded_at_utc': recordedAtUtc.toUtc().toIso8601String(),
    'reason': reason,
    'environment': environment,
    'target_population_scope': targetPopulationScope,
  };

  String get eventSha256 => _digest(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'event_sha256': eventSha256,
  };
}

final class ConfigurationBaselineRegistryState {
  static const String schema = 'parkinsum.configuration-baseline-registry/1';
  static const int schemaVersion = 1;

  ConfigurationBaselineRegistryState({
    required this.revision,
    required this.activeConfigurationSha256,
    required this.environment,
    required this.targetPopulationScope,
    required List<ConfigurationBaselineRegistryEvent> events,
  }) : events = List.unmodifiable(events) {
    final reasons = integrityReasons;
    if (reasons.isNotEmpty) {
      throw ArgumentError(
        'Baseline registry integrity failed: ${reasons.join(', ')}',
      );
    }
  }

  final int revision;
  final String activeConfigurationSha256;
  final String environment;
  final String targetPopulationScope;
  final List<ConfigurationBaselineRegistryEvent> events;

  Set<String> get usedReceiptSha256s =>
      events.map((event) => event.receiptSha256).whereType<String>().toSet();

  Set<String> get previouslyActiveConfigurationSha256s => events
      .where(
        (event) =>
            event.kind == ConfigurationBaselineEventKind.activated ||
            event.kind == ConfigurationBaselineEventKind.rolledBack,
      )
      .map((event) => event.activeConfigurationAfterSha256)
      .toSet();

  /// A revocation keeps the last-known identity in the audit chain but makes
  /// it unusable until an independently authorized activation supersedes the
  /// revocation. Keeping the pointer avoids misrepresenting revocation as
  /// deletion or silently falling back to an unreviewed configuration.
  bool get activeConfigurationRevoked {
    var revoked = false;
    for (final event in events) {
      switch (event.kind) {
        case ConfigurationBaselineEventKind.activated:
        case ConfigurationBaselineEventKind.rolledBack:
          revoked = false;
        case ConfigurationBaselineEventKind.revoked:
          if (event.configurationSha256 == activeConfigurationSha256) {
            revoked = true;
          }
        case ConfigurationBaselineEventKind.promotionRejected:
        case ConfigurationBaselineEventKind.rollbackRejected:
        case ConfigurationBaselineEventKind.revocationRejected:
          break;
      }
    }
    return revoked;
  }

  bool get hasUsableActiveConfiguration => !activeConfigurationRevoked;

  List<String> get integrityReasons {
    final reasons = <String>[];
    if (revision < 1 ||
        events.isEmpty ||
        !_sha256.hasMatch(activeConfigurationSha256) ||
        !_identifier.hasMatch(environment) ||
        !_identifier.hasMatch(targetPopulationScope)) {
      reasons.add('registry.header_invalid');
      return reasons;
    }
    String? previousSha;
    DateTime? previousRecordedAtUtc;
    var expectedActive = events.first.activeConfigurationBeforeSha256;
    for (var index = 0; index < events.length; index += 1) {
      final event = events[index];
      if (event.sequence != index + 1) reasons.add('registry.sequence_invalid');
      if (event.previousEventSha256 != previousSha) {
        reasons.add('registry.predecessor_invalid');
      }
      if (event.activeConfigurationBeforeSha256 != expectedActive) {
        reasons.add('registry.active_before_invalid');
      }
      if (event.environment != environment) {
        reasons.add('registry.environment_mismatch');
      }
      if (event.targetPopulationScope != targetPopulationScope) {
        reasons.add('registry.target_population_scope_mismatch');
      }
      if (previousRecordedAtUtc != null &&
          event.recordedAtUtc.isBefore(previousRecordedAtUtc)) {
        reasons.add('registry.recorded_at_not_monotonic');
      }
      final retainsActive = switch (event.kind) {
        ConfigurationBaselineEventKind.revoked ||
        ConfigurationBaselineEventKind.promotionRejected ||
        ConfigurationBaselineEventKind.rollbackRejected ||
        ConfigurationBaselineEventKind.revocationRejected => true,
        ConfigurationBaselineEventKind.activated ||
        ConfigurationBaselineEventKind.rolledBack => false,
      };
      if (retainsActive &&
          event.activeConfigurationAfterSha256 !=
              event.activeConfigurationBeforeSha256) {
        reasons.add('registry.non_activation_changed_active');
      }
      if (event.kind == ConfigurationBaselineEventKind.revoked &&
          event.configurationSha256 != event.activeConfigurationBeforeSha256) {
        reasons.add('registry.revocation_target_invalid');
      }
      previousSha = event.eventSha256;
      previousRecordedAtUtc = event.recordedAtUtc;
      expectedActive = event.activeConfigurationAfterSha256;
    }
    if (expectedActive != activeConfigurationSha256) {
      reasons.add('registry.active_head_invalid');
    }
    if (revision != events.length) reasons.add('registry.revision_invalid');
    return reasons.toSet().toList()..sort();
  }

  String get registrySha256 => _digest(canonicalPayload);

  Map<String, Object?> get canonicalPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'revision': revision,
    'active_configuration_sha256': activeConfigurationSha256,
    'active_configuration_revoked': activeConfigurationRevoked,
    'has_usable_active_configuration': hasUsableActiveConfiguration,
    'environment': environment,
    'target_population_scope': targetPopulationScope,
    'events': events.map((event) => event.toJson()).toList(),
  };

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'registry_sha256': registrySha256,
    'boundary':
        'An intact event chain records configuration-control decisions only. '
        'It is not scientific validation, regulatory approval, clinical '
        'performance evidence, or medical advice.',
  };
}

final _sha256 = RegExp(r'^[a-f0-9]{64}$');
final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');

String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  return value;
}
