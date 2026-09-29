import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

const signedCapabilityManifestSchema = 'parkinsum.signed-capability-manifest/1';
const signedCapabilityManifestSchemaVersion = 1;

const _safeIdentifierPattern = r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$';
const _sha256Pattern = r'^[a-f0-9]{64}$';
const _maxManifestBytes = 64 * 1024;

enum SignedCapabilityId {
  localAiReranking('local_ai_reranking'),
  externalCatalogRefresh('external_catalog_refresh'),
  offDeviceOperationalTelemetry('off_device_operational_telemetry');

  const SignedCapabilityId(this.wireName);

  final String wireName;

  static SignedCapabilityId? fromWireName(String value) {
    for (final candidate in values) {
      if (candidate.wireName == value) return candidate;
    }
    return null;
  }
}

enum CapabilityManifestReason {
  stagedEnable('staged_enable'),
  routineDisable('routine_disable'),
  emergencyDisable('emergency_disable'),
  rollback('rollback'),
  keyRotation('key_rotation');

  const CapabilityManifestReason(this.wireName);

  final String wireName;

  static CapabilityManifestReason? fromWireName(String value) {
    for (final candidate in values) {
      if (candidate.wireName == value) return candidate;
    }
    return null;
  }
}

enum CapabilityManifestVerificationStatus {
  verified,
  malformed,
  unsupportedSchema,
  untrustedIssuer,
  wrongEnvironment,
  untrustedKey,
  revokedKey,
  invalidSignature,
  notYetValid,
  expired,
  lifetimeExceeded,
  unsupportedCapability,
  unsafeCapability,
  integrityBlocked,
}

final class SignedCapabilityValue {
  const SignedCapabilityValue({required this.id, required this.enabled});

  final SignedCapabilityId id;
  final bool enabled;

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'id': id.wireName,
    'scope': 'global',
    'type': 'boolean',
  };

  static SignedCapabilityValue parse(Object? raw) {
    final map = _strictMap(raw, 'capability');
    _requireExactKeys(map, const <String>{'enabled', 'id', 'scope', 'type'});
    final idText = _requiredString(map, 'id');
    final id = SignedCapabilityId.fromWireName(idText);
    if (id == null) {
      throw CapabilityManifestFormatException('unsupported_capability:$idText');
    }
    if (map['type'] != 'boolean' || map['scope'] != 'global') {
      throw const CapabilityManifestFormatException(
        'capability_contract_invalid',
      );
    }
    final enabled = map['enabled'];
    if (enabled is! bool) {
      throw const CapabilityManifestFormatException('capability_value_invalid');
    }
    return SignedCapabilityValue(id: id, enabled: enabled);
  }
}

final class CapabilityRollbackTarget {
  const CapabilityRollbackTarget({
    required this.sequence,
    required this.manifestSha256,
  });

  final int sequence;
  final String manifestSha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'manifest_sha256': manifestSha256,
    'sequence': sequence,
  };

  static CapabilityRollbackTarget parse(Object? raw) {
    final map = _strictMap(raw, 'rollback_target');
    _requireExactKeys(map, const <String>{'manifest_sha256', 'sequence'});
    final sequence = _requiredPositiveInt(map, 'sequence');
    final digest = _requiredString(map, 'manifest_sha256');
    if (!RegExp(_sha256Pattern).hasMatch(digest)) {
      throw const CapabilityManifestFormatException('rollback_digest_invalid');
    }
    return CapabilityRollbackTarget(sequence: sequence, manifestSha256: digest);
  }
}

final class SignedCapabilityManifest {
  SignedCapabilityManifest({
    required this.manifestId,
    required this.sequence,
    required this.issuer,
    required this.keyId,
    required this.environment,
    required this.issuedAtUtc,
    required this.notBeforeUtc,
    required this.expiresAtUtc,
    required this.reason,
    required this.previousManifestSha256,
    required this.rollbackTarget,
    required Iterable<SignedCapabilityValue> capabilities,
  }) : capabilities = List<SignedCapabilityValue>.unmodifiable(capabilities) {
    _validateConstruction();
  }

  final String manifestId;
  final int sequence;
  final String issuer;
  final String keyId;
  final String environment;
  final DateTime issuedAtUtc;
  final DateTime notBeforeUtc;
  final DateTime expiresAtUtc;
  final CapabilityManifestReason reason;
  final String? previousManifestSha256;
  final CapabilityRollbackTarget? rollbackTarget;
  final List<SignedCapabilityValue> capabilities;

  Map<SignedCapabilityId, bool> get capabilityValues =>
      Map<SignedCapabilityId, bool>.unmodifiable(<SignedCapabilityId, bool>{
        for (final capability in capabilities)
          capability.id: capability.enabled,
      });

  Map<String, Object?> toJson() => <String, Object?>{
    r'$schema': signedCapabilityManifestSchema,
    'capabilities': capabilities.map((value) => value.toJson()).toList(),
    'environment': environment,
    'expires_at': _canonicalUtc(expiresAtUtc),
    'issued_at': _canonicalUtc(issuedAtUtc),
    'issuer': issuer,
    'key_id': keyId,
    'manifest_id': manifestId,
    'not_before': _canonicalUtc(notBeforeUtc),
    'previous_manifest_sha256': previousManifestSha256,
    'reason_code': reason.wireName,
    'rollback_target': rollbackTarget?.toJson(),
    'sequence': sequence,
  };

  String get canonicalJson => canonicalCapabilityJson(toJson());

  String get sha256 => sha256OfCanonicalCapabilityJson(toJson());

  void _validateConstruction() {
    for (final identifier in <String>[manifestId, issuer, keyId, environment]) {
      if (!RegExp(_safeIdentifierPattern).hasMatch(identifier)) {
        throw const CapabilityManifestFormatException(
          'manifest_identifier_invalid',
        );
      }
    }
    if (sequence <= 0 ||
        !issuedAtUtc.isUtc ||
        !notBeforeUtc.isUtc ||
        !expiresAtUtc.isUtc ||
        notBeforeUtc.isBefore(issuedAtUtc) ||
        !expiresAtUtc.isAfter(notBeforeUtc)) {
      throw const CapabilityManifestFormatException(
        'manifest_time_or_sequence_invalid',
      );
    }
    final ids = capabilities.map((value) => value.id).toList();
    if (ids.isEmpty || ids.toSet().length != ids.length) {
      throw const CapabilityManifestFormatException('capability_set_invalid');
    }
    final ordered = [...ids]
      ..sort((left, right) => left.wireName.compareTo(right.wireName));
    if (!_sameList(ids, ordered)) {
      throw const CapabilityManifestFormatException('capability_order_invalid');
    }
    if (previousManifestSha256 != null &&
        !RegExp(_sha256Pattern).hasMatch(previousManifestSha256!)) {
      throw const CapabilityManifestFormatException(
        'previous_manifest_digest_invalid',
      );
    }
    if (rollbackTarget != null &&
        reason != CapabilityManifestReason.rollback &&
        reason != CapabilityManifestReason.emergencyDisable) {
      throw const CapabilityManifestFormatException('rollback_reason_invalid');
    }
  }

  static SignedCapabilityManifest parse(Object? raw) {
    final map = _strictMap(raw, 'manifest');
    _requireExactKeys(map, const <String>{
      r'$schema',
      'capabilities',
      'environment',
      'expires_at',
      'issued_at',
      'issuer',
      'key_id',
      'manifest_id',
      'not_before',
      'previous_manifest_sha256',
      'reason_code',
      'rollback_target',
      'sequence',
    });
    if (map[r'$schema'] != signedCapabilityManifestSchema) {
      throw const CapabilityManifestFormatException(
        'manifest_schema_unsupported',
      );
    }
    final rawCapabilities = map['capabilities'];
    if (rawCapabilities is! List || rawCapabilities.length > 16) {
      throw const CapabilityManifestFormatException('capability_set_invalid');
    }
    final reasonText = _requiredString(map, 'reason_code');
    final reason = CapabilityManifestReason.fromWireName(reasonText);
    if (reason == null) {
      throw const CapabilityManifestFormatException('reason_code_invalid');
    }
    final previous = map['previous_manifest_sha256'];
    if (previous != null && previous is! String) {
      throw const CapabilityManifestFormatException(
        'previous_manifest_digest_invalid',
      );
    }
    final rawRollback = map['rollback_target'];
    return SignedCapabilityManifest(
      manifestId: _requiredString(map, 'manifest_id'),
      sequence: _requiredPositiveInt(map, 'sequence'),
      issuer: _requiredString(map, 'issuer'),
      keyId: _requiredString(map, 'key_id'),
      environment: _requiredString(map, 'environment'),
      issuedAtUtc: _requiredUtc(map, 'issued_at'),
      notBeforeUtc: _requiredUtc(map, 'not_before'),
      expiresAtUtc: _requiredUtc(map, 'expires_at'),
      reason: reason,
      previousManifestSha256: previous as String?,
      rollbackTarget: rawRollback == null
          ? null
          : CapabilityRollbackTarget.parse(rawRollback),
      capabilities: rawCapabilities.map(SignedCapabilityValue.parse),
    );
  }
}

final class SignedCapabilityEnvelope {
  const SignedCapabilityEnvelope({
    required this.manifest,
    required this.signatureBase64Url,
  });

  final SignedCapabilityManifest manifest;
  final String signatureBase64Url;

  Map<String, Object?> toJson() => <String, Object?>{
    'signature': <String, Object?>{
      'algorithm': 'Ed25519',
      'key_id': manifest.keyId,
      'value_base64url': signatureBase64Url,
    },
    'signed': manifest.toJson(),
  };

  String get canonicalJson => canonicalCapabilityJson(toJson());

  static SignedCapabilityEnvelope parseJson(String raw) {
    if (utf8.encode(raw).length > _maxManifestBytes) {
      throw const CapabilityManifestFormatException('manifest_too_large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const CapabilityManifestFormatException('manifest_json_invalid');
    }
    final map = _strictMap(decoded, 'envelope');
    _requireExactKeys(map, const <String>{'signature', 'signed'});
    final manifest = SignedCapabilityManifest.parse(map['signed']);
    final signature = _strictMap(map['signature'], 'signature');
    _requireExactKeys(signature, const <String>{
      'algorithm',
      'key_id',
      'value_base64url',
    });
    if (signature['algorithm'] != 'Ed25519' ||
        signature['key_id'] != manifest.keyId) {
      throw const CapabilityManifestFormatException(
        'signature_metadata_invalid',
      );
    }
    final encoded = _requiredString(signature, 'value_base64url');
    final decodedSignature = _decodeBase64Url(encoded, 'signature_invalid');
    if (decodedSignature.length != 64 ||
        _encodeBase64Url(decodedSignature) != encoded) {
      throw const CapabilityManifestFormatException('signature_invalid');
    }
    return SignedCapabilityEnvelope(
      manifest: manifest,
      signatureBase64Url: encoded,
    );
  }
}

final class CapabilityTrustPolicy {
  CapabilityTrustPolicy({
    required this.environment,
    required this.issuer,
    required Map<String, List<int>> trustedEd25519PublicKeys,
    Set<String> revokedKeyIds = const <String>{},
    Set<SignedCapabilityId> allowedCapabilities = const <SignedCapabilityId>{
      SignedCapabilityId.localAiReranking,
      SignedCapabilityId.externalCatalogRefresh,
      SignedCapabilityId.offDeviceOperationalTelemetry,
    },
    this.maximumManifestLifetime = const Duration(days: 14),
    this.clockSkew = const Duration(minutes: 5),
  }) : trustedEd25519PublicKeys =
           Map<String, List<int>>.unmodifiable(<String, List<int>>{
             for (final entry in trustedEd25519PublicKeys.entries)
               entry.key: List<int>.unmodifiable(entry.value),
           }),
       revokedKeyIds = Set<String>.unmodifiable(revokedKeyIds),
       allowedCapabilities = Set<SignedCapabilityId>.unmodifiable(
         allowedCapabilities,
       ) {
    _validate();
  }

  final String environment;
  final String issuer;
  final Map<String, List<int>> trustedEd25519PublicKeys;
  final Set<String> revokedKeyIds;
  final Set<SignedCapabilityId> allowedCapabilities;
  final Duration maximumManifestLifetime;
  final Duration clockSkew;

  bool get isConfigured => trustedEd25519PublicKeys.isNotEmpty;

  void _validate() {
    if (!RegExp(_safeIdentifierPattern).hasMatch(environment) ||
        !RegExp(_safeIdentifierPattern).hasMatch(issuer) ||
        maximumManifestLifetime <= Duration.zero ||
        clockSkew.isNegative ||
        allowedCapabilities.isEmpty) {
      throw ArgumentError('Capability trust policy is invalid.');
    }
    for (final entry in trustedEd25519PublicKeys.entries) {
      if (!RegExp(_safeIdentifierPattern).hasMatch(entry.key) ||
          entry.value.length != 32) {
        throw ArgumentError('Capability trust key is invalid.');
      }
    }
  }
}

final class CapabilityManifestVerification {
  const CapabilityManifestVerification({
    required this.status,
    this.envelope,
    required this.reason,
  });

  final CapabilityManifestVerificationStatus status;
  final SignedCapabilityEnvelope? envelope;
  final String reason;

  bool get isVerified =>
      status == CapabilityManifestVerificationStatus.verified &&
      envelope != null;
}

final class SignedCapabilityManifestVerifier {
  SignedCapabilityManifestVerifier({
    required this.trustPolicy,
    Ed25519? algorithm,
  }) : _algorithm = algorithm ?? Ed25519();

  final CapabilityTrustPolicy trustPolicy;
  final Ed25519 _algorithm;

  Future<CapabilityManifestVerification> verify(
    String raw, {
    required DateTime nowUtc,
  }) async {
    if (!nowUtc.isUtc) {
      return const CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.integrityBlocked,
        reason: 'verification_clock_not_utc',
      );
    }
    final SignedCapabilityEnvelope envelope;
    try {
      envelope = SignedCapabilityEnvelope.parseJson(raw);
    } on CapabilityManifestFormatException catch (error) {
      final status = error.code == 'manifest_schema_unsupported'
          ? CapabilityManifestVerificationStatus.unsupportedSchema
          : error.code.startsWith('unsupported_capability:')
          ? CapabilityManifestVerificationStatus.unsupportedCapability
          : CapabilityManifestVerificationStatus.malformed;
      return CapabilityManifestVerification(status: status, reason: error.code);
    } catch (_) {
      return const CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.malformed,
        reason: 'manifest_parse_failed',
      );
    }

    final manifest = envelope.manifest;
    if (manifest.issuer != trustPolicy.issuer) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.untrustedIssuer,
        envelope: envelope,
        reason: 'issuer_not_trusted',
      );
    }
    if (manifest.environment != trustPolicy.environment) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.wrongEnvironment,
        envelope: envelope,
        reason: 'environment_mismatch',
      );
    }
    final publicKeyBytes = trustPolicy.trustedEd25519PublicKeys[manifest.keyId];
    if (publicKeyBytes == null) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.untrustedKey,
        envelope: envelope,
        reason: 'key_not_trusted',
      );
    }
    if (trustPolicy.revokedKeyIds.contains(manifest.keyId)) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.revokedKey,
        envelope: envelope,
        reason: 'key_revoked',
      );
    }
    final manifestCapabilities = manifest.capabilities
        .map((value) => value.id)
        .toSet();
    if (!trustPolicy.allowedCapabilities.containsAll(manifestCapabilities)) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.unsafeCapability,
        envelope: envelope,
        reason: 'capability_not_allowed_by_local_policy',
      );
    }
    final lifetime = manifest.expiresAtUtc.difference(manifest.issuedAtUtc);
    if (lifetime > trustPolicy.maximumManifestLifetime) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.lifetimeExceeded,
        envelope: envelope,
        reason: 'manifest_lifetime_exceeded',
      );
    }
    if (nowUtc.add(trustPolicy.clockSkew).isBefore(manifest.notBeforeUtc)) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.notYetValid,
        envelope: envelope,
        reason: 'manifest_not_yet_valid',
      );
    }
    if (!nowUtc
        .subtract(trustPolicy.clockSkew)
        .isBefore(manifest.expiresAtUtc)) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.expired,
        envelope: envelope,
        reason: 'manifest_expired',
      );
    }

    final signatureBytes = _decodeBase64Url(
      envelope.signatureBase64Url,
      'signature_invalid',
    );
    final signature = Signature(
      signatureBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
    );
    final valid = await _algorithm.verify(
      utf8.encode(manifest.canonicalJson),
      signature: signature,
    );
    if (!valid) {
      return CapabilityManifestVerification(
        status: CapabilityManifestVerificationStatus.invalidSignature,
        envelope: envelope,
        reason: 'signature_verification_failed',
      );
    }
    return CapabilityManifestVerification(
      status: CapabilityManifestVerificationStatus.verified,
      envelope: envelope,
      reason: 'verified',
    );
  }
}

final class CapabilityManifestFormatException implements FormatException {
  const CapabilityManifestFormatException(this.code);

  final String code;

  @override
  String get message => code;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'CapabilityManifestFormatException($code)';
}

String canonicalCapabilityJson(Object? value) =>
    jsonEncode(_canonicalize(value));

String sha256OfCanonicalCapabilityJson(Object? value) =>
    sha256.convert(utf8.encode(canonicalCapabilityJson(value))).toString();

Object? _canonicalize(Object? value) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const CapabilityManifestFormatException('non_finite_number');
    }
    return value;
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  throw const CapabilityManifestFormatException('unsupported_json_value');
}

Map<String, Object?> _strictMap(Object? raw, String label) {
  if (raw is! Map) {
    throw CapabilityManifestFormatException('${label}_not_object');
  }
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || result.containsKey(entry.key)) {
      throw CapabilityManifestFormatException('${label}_keys_invalid');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _requireExactKeys(Map<String, Object?> map, Set<String> expected) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const CapabilityManifestFormatException('unknown_or_missing_fields');
  }
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty || value.length > 256) {
    throw CapabilityManifestFormatException('${key}_invalid');
  }
  return value;
}

int _requiredPositiveInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int || value <= 0 || value > 9007199254740991) {
    throw CapabilityManifestFormatException('${key}_invalid');
  }
  return value;
}

DateTime _requiredUtc(Map<String, Object?> map, String key) {
  final raw = _requiredString(map, key);
  final DateTime parsed;
  try {
    parsed = DateTime.parse(raw);
  } on FormatException {
    throw CapabilityManifestFormatException('${key}_invalid');
  }
  final utc = parsed.toUtc();
  if (!raw.endsWith('Z') || _canonicalUtc(utc) != raw) {
    throw CapabilityManifestFormatException('${key}_not_canonical_utc');
  }
  return utc;
}

String _canonicalUtc(DateTime value) => value.toUtc().toIso8601String();

List<int> _decodeBase64Url(String value, String errorCode) {
  try {
    return base64Url.decode(base64Url.normalize(value));
  } on FormatException {
    throw CapabilityManifestFormatException(errorCode);
  }
}

String _encodeBase64Url(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
