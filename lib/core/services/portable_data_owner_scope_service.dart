import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/protected_secret_store.dart';

const firebasePortableScopeKind = 'firebase_authenticated_account';
const localPortableScopeKind = 'local_device_account';

/// Version 1 stored the raw owner capability in SharedPreferences. Version 2
/// stores a strict envelope in [ProtectedSecretStore] and uses the old value
/// only as a one-way migration source.
const userPortableDataOwnerTokenSchemaVersion = 2;
const portableDataOwnerSecretEnvelopeSchemaVersion = 1;
const userPortableDataOwnerTokenPreferencePrefix =
    'portable_data_owner_token_v1_';
const userPortableDataOwnerProtectedKeyPrefix = 'portable_data_owner_token_v2_';

typedef PortableOwnerRandomBytes = List<int> Function(int length);

final class PortableDataResolvedOwner {
  const PortableDataResolvedOwner({
    required this.scopeKind,
    required this.effectiveOpaqueScope,
    required this.protectionClass,
    required this.revision,
    required this.migratedFromLegacy,
    this.keyId,
  });

  final String scopeKind;
  final String effectiveOpaqueScope;
  final String protectionClass;
  final int revision;
  final bool migratedFromLegacy;
  final String? keyId;
}

abstract interface class PortableDataOwnerScopeResolver {
  Future<PortableDataResolvedOwner> resolve({
    required String rawScope,
    required String scopeKind,
  });
}

abstract interface class PortableDataOwnerScopeManager
    implements PortableDataOwnerScopeResolver {
  ProtectedSecretStoreCapability get capability;

  Future<PortableDataResolvedOwner> rotate({
    required String rawScope,
    required String scopeKind,
  });

  Future<void> revoke({required String rawScope, required String scopeKind});
}

abstract interface class LegacyPortableOwnerTokenStore {
  Future<String?> read(String key);

  Future<void> remove(String key);
}

final class SharedPreferencesLegacyPortableOwnerTokenStore
    implements LegacyPortableOwnerTokenStore {
  const SharedPreferencesLegacyPortableOwnerTokenStore();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(key);
    if (!removed && preferences.containsKey(key)) {
      throw StateError('Legacy portable owner token removal failed.');
    }
  }
}

/// Account-bound owner capability resolver with verified migration, read-back,
/// rotation, and revocation. It never regenerates over malformed or conflicting
/// state because that would silently invalidate previously exported packages.
final class PersistentPortableDataOwnerScopeResolver
    implements PortableDataOwnerScopeManager {
  PersistentPortableDataOwnerScopeResolver({
    ProtectedSecretStore? protectedStore,
    LegacyPortableOwnerTokenStore? legacyStore,
    PortableOwnerRandomBytes? randomBytes,
    DateTime Function()? now,
  }) : _protectedStore = protectedStore ?? const FlutterProtectedSecretStore(),
       _legacyStore =
           legacyStore ??
           const SharedPreferencesLegacyPortableOwnerTokenStore(),
       _randomBytes = randomBytes ?? _secureRandomBytes,
       _now = now ?? DateTime.now;

  static final Map<String, Future<void>> _mutationTails =
      <String, Future<void>>{};

  final ProtectedSecretStore _protectedStore;
  final LegacyPortableOwnerTokenStore _legacyStore;
  final PortableOwnerRandomBytes _randomBytes;
  final DateTime Function() _now;

  static final RegExp _secretPattern = RegExp(r'^odt_[0-9a-f]{64}$');
  static final RegExp _keyIdPattern = RegExp(r'^pok_[0-9a-f]{32}$');
  static final RegExp _digestPattern = RegExp(r'^[0-9a-f]{64}$');

  @override
  ProtectedSecretStoreCapability get capability => _protectedStore.capability;

  @override
  Future<PortableDataResolvedOwner> resolve({
    required String rawScope,
    required String scopeKind,
  }) async {
    final scope = _scopeIdentity(rawScope: rawScope, scopeKind: scopeKind);
    if (scopeKind == firebasePortableScopeKind) {
      return PortableDataResolvedOwner(
        scopeKind: scopeKind,
        effectiveOpaqueScope: scope.normalizedScope,
        protectionClass: 'firebase_account_identity_not_local_secret',
        revision: 0,
        migratedFromLegacy: false,
      );
    }
    return _serialized(scope.protectedKey, () => _resolveLocal(scope));
  }

  @override
  Future<PortableDataResolvedOwner> rotate({
    required String rawScope,
    required String scopeKind,
  }) async {
    final scope = _scopeIdentity(rawScope: rawScope, scopeKind: scopeKind);
    if (scopeKind != localPortableScopeKind) {
      throw StateError('Only a local portable owner capability can rotate.');
    }
    return _serialized(scope.protectedKey, () async {
      final current = await _loadOrCreateEnvelope(scope);
      final timestamp = _now().toUtc();
      if (timestamp.isBefore(current.envelope.rotatedAt)) {
        throw StateError('Portable owner capability clock moved backwards.');
      }
      final nextSecret = _newSecret();
      final nextKeyId = _newKeyId();
      if (nextSecret == current.envelope.secret ||
          nextKeyId == current.envelope.keyId) {
        throw StateError('Portable owner capability rotation did not advance.');
      }
      final next = _PortableOwnerSecretEnvelope(
        ownerLookupSha256: scope.lookupDigest,
        secret: nextSecret,
        keyId: nextKeyId,
        revision: current.envelope.revision + 1,
        createdAt: current.envelope.createdAt,
        rotatedAt: timestamp,
        protectionClass: capability.id,
      );
      await _writeVerified(scope.protectedKey, next);
      debugPrint(
        '[PortableOwnerSecret] rotated revision=${next.revision} '
        'protection=${capability.id}',
      );
      return _resolved(scopeKind, next, migratedFromLegacy: false);
    });
  }

  @override
  Future<void> revoke({
    required String rawScope,
    required String scopeKind,
  }) async {
    final scope = _scopeIdentity(rawScope: rawScope, scopeKind: scopeKind);
    if (scopeKind != localPortableScopeKind) return;
    await _serialized(scope.protectedKey, () async {
      Object? deleteError;
      try {
        await _protectedStore.delete(scope.protectedKey);
      } catch (error) {
        deleteError = error;
      }
      final remaining = await _protectedStore.read(scope.protectedKey);
      if (remaining != null) {
        throw StateError('Portable owner capability revocation failed.');
      }
      await _removeLegacyVerified(scope.legacyKey, expectedSecret: null);
      if (deleteError != null) {
        debugPrint(
          '[PortableOwnerSecret] recovered delete acknowledgement loss',
        );
      }
      debugPrint('[PortableOwnerSecret] revoked protection=${capability.id}');
    });
  }

  Future<PortableDataResolvedOwner> _resolveLocal(
    _PortableOwnerScopeIdentity scope,
  ) async {
    final loaded = await _loadOrCreateEnvelope(scope);
    return _resolved(
      localPortableScopeKind,
      loaded.envelope,
      migratedFromLegacy: loaded.migratedFromLegacy,
    );
  }

  PortableDataResolvedOwner _resolved(
    String scopeKind,
    _PortableOwnerSecretEnvelope envelope, {
    required bool migratedFromLegacy,
  }) => PortableDataResolvedOwner(
    scopeKind: scopeKind,
    effectiveOpaqueScope: envelope.secret,
    protectionClass: envelope.protectionClass,
    revision: envelope.revision,
    migratedFromLegacy: migratedFromLegacy,
    keyId: envelope.keyId,
  );

  Future<_LoadedPortableOwnerEnvelope> _loadOrCreateEnvelope(
    _PortableOwnerScopeIdentity scope,
  ) async {
    final protectedRaw = await _protectedStore.read(scope.protectedKey);
    if (protectedRaw != null) {
      final envelope = _PortableOwnerSecretEnvelope.parse(
        protectedRaw,
        expectedOwnerLookupSha256: scope.lookupDigest,
        expectedProtectionClass: capability.id,
      );
      final legacy = await _legacyStore.read(scope.legacyKey);
      if (legacy != null) {
        if (!_secretPattern.hasMatch(legacy) || legacy != envelope.secret) {
          throw StateError(
            'Protected and legacy portable owner capabilities conflict.',
          );
        }
        await _removeLegacyVerified(
          scope.legacyKey,
          expectedSecret: envelope.secret,
        );
        debugPrint('[PortableOwnerSecret] completed legacy cleanup');
      }
      return _LoadedPortableOwnerEnvelope(envelope, false);
    }

    final legacy = await _legacyStore.read(scope.legacyKey);
    if (legacy != null && !_secretPattern.hasMatch(legacy)) {
      throw StateError('Persisted legacy portable owner token is invalid.');
    }
    final timestamp = _now().toUtc();
    final envelope = _PortableOwnerSecretEnvelope(
      ownerLookupSha256: scope.lookupDigest,
      secret: legacy ?? _newSecret(),
      keyId: _newKeyId(),
      revision: 1,
      createdAt: timestamp,
      rotatedAt: timestamp,
      protectionClass: capability.id,
    );
    await _writeVerified(scope.protectedKey, envelope);
    if (legacy != null) {
      await _removeLegacyVerified(scope.legacyKey, expectedSecret: legacy);
      debugPrint(
        '[PortableOwnerSecret] migrated legacy capability '
        'protection=${capability.id}',
      );
    } else {
      debugPrint(
        '[PortableOwnerSecret] created revision=1 '
        'protection=${capability.id}',
      );
    }
    return _LoadedPortableOwnerEnvelope(envelope, legacy != null);
  }

  Future<void> _writeVerified(
    String key,
    _PortableOwnerSecretEnvelope envelope,
  ) async {
    final encoded = envelope.encode();
    Object? writeError;
    try {
      await _protectedStore.write(key, encoded);
    } catch (error) {
      writeError = error;
    }
    final readBack = await _protectedStore.read(key);
    if (readBack != encoded) {
      throw StateError('Protected portable owner capability write failed.');
    }
    _PortableOwnerSecretEnvelope.parse(
      readBack!,
      expectedOwnerLookupSha256: envelope.ownerLookupSha256,
      expectedProtectionClass: envelope.protectionClass,
    );
    if (writeError != null) {
      debugPrint('[PortableOwnerSecret] recovered write acknowledgement loss');
    }
  }

  Future<void> _removeLegacyVerified(
    String legacyKey, {
    required String? expectedSecret,
  }) async {
    final before = await _legacyStore.read(legacyKey);
    if (expectedSecret != null && before != expectedSecret) {
      throw StateError('Legacy portable owner capability changed.');
    }
    if (before == null) return;
    await _legacyStore.remove(legacyKey);
    if (await _legacyStore.read(legacyKey) != null) {
      throw StateError('Legacy portable owner capability cleanup failed.');
    }
  }

  _PortableOwnerScopeIdentity _scopeIdentity({
    required String rawScope,
    required String scopeKind,
  }) {
    final normalizedScope = rawScope.trim();
    if (normalizedScope.isEmpty) {
      throw StateError('Portable owner scope is unavailable.');
    }
    if (scopeKind != firebasePortableScopeKind &&
        scopeKind != localPortableScopeKind) {
      throw StateError('Portable owner scope kind is unsupported.');
    }
    final lookupDigest = sha256
        .convert(
          utf8.encode(
            'parkinsum-portable-owner-token-lookup-v2|$scopeKind|'
            '$normalizedScope',
          ),
        )
        .toString();
    final legacyLookupDigest = sha256
        .convert(
          utf8.encode(
            'parkinsum-portable-owner-token-lookup-v1|$scopeKind|'
            '$normalizedScope',
          ),
        )
        .toString();
    return _PortableOwnerScopeIdentity(
      normalizedScope: normalizedScope,
      lookupDigest: lookupDigest,
      protectedKey: '$userPortableDataOwnerProtectedKeyPrefix$lookupDigest',
      legacyKey:
          '$userPortableDataOwnerTokenPreferencePrefix$legacyLookupDigest',
    );
  }

  String _newSecret() => 'odt_${_hex(_randomBytes(32), expectedLength: 32)}';

  String _newKeyId() => 'pok_${_hex(_randomBytes(16), expectedLength: 16)}';

  static String _hex(List<int> bytes, {required int expectedLength}) {
    if (bytes.length != expectedLength ||
        bytes.any((value) => value < 0 || value > 255)) {
      throw StateError('Secure random source returned invalid bytes.');
    }
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static Future<T> _serialized<T>(
    String key,
    Future<T> Function() operation,
  ) async {
    final previous = _mutationTails[key] ?? Future<void>.value();
    final done = Completer<void>();
    final tail = previous.then<void>(
      (_) => done.future,
      onError: (_) => done.future,
    );
    _mutationTails[key] = tail;
    try {
      try {
        await previous;
      } catch (_) {
        // A failed predecessor must release the queue but cannot authorize this
        // operation; the current operation re-reads durable state itself.
      }
      return await operation();
    } finally {
      if (!done.isCompleted) done.complete();
      if (identical(_mutationTails[key], tail)) {
        _mutationTails.remove(key);
      }
    }
  }
}

final class _PortableOwnerScopeIdentity {
  const _PortableOwnerScopeIdentity({
    required this.normalizedScope,
    required this.lookupDigest,
    required this.protectedKey,
    required this.legacyKey,
  });

  final String normalizedScope;
  final String lookupDigest;
  final String protectedKey;
  final String legacyKey;
}

final class _LoadedPortableOwnerEnvelope {
  const _LoadedPortableOwnerEnvelope(this.envelope, this.migratedFromLegacy);

  final _PortableOwnerSecretEnvelope envelope;
  final bool migratedFromLegacy;
}

final class _PortableOwnerSecretEnvelope {
  const _PortableOwnerSecretEnvelope({
    required this.ownerLookupSha256,
    required this.secret,
    required this.keyId,
    required this.revision,
    required this.createdAt,
    required this.rotatedAt,
    required this.protectionClass,
  });

  static const String purpose = 'portable_owner_binding';
  static const String status = 'active';
  static const Set<String> _keys = <String>{
    'schemaVersion',
    'purpose',
    'status',
    'ownerLookupSha256',
    'secret',
    'keyId',
    'revision',
    'createdAt',
    'rotatedAt',
    'protectionClass',
  };

  final String ownerLookupSha256;
  final String secret;
  final String keyId;
  final int revision;
  final DateTime createdAt;
  final DateTime rotatedAt;
  final String protectionClass;

  String encode() => jsonEncode(<String, Object>{
    'schemaVersion': portableDataOwnerSecretEnvelopeSchemaVersion,
    'purpose': purpose,
    'status': status,
    'ownerLookupSha256': ownerLookupSha256,
    'secret': secret,
    'keyId': keyId,
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'rotatedAt': rotatedAt.toUtc().toIso8601String(),
    'protectionClass': protectionClass,
  });

  static _PortableOwnerSecretEnvelope parse(
    String raw, {
    required String expectedOwnerLookupSha256,
    required String expectedProtectionClass,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw StateError('Protected portable owner envelope is malformed.');
    }
    if (decoded is! Map<String, dynamic> ||
        !setEquals(decoded.keys.toSet(), _keys)) {
      throw StateError('Protected portable owner envelope shape is invalid.');
    }
    final createdAt = _parseUtc(decoded['createdAt']);
    final rotatedAt = _parseUtc(decoded['rotatedAt']);
    final revision = decoded['revision'];
    final ownerLookup = decoded['ownerLookupSha256'];
    final secret = decoded['secret'];
    final keyId = decoded['keyId'];
    final protectionClass = decoded['protectionClass'];
    if (decoded['schemaVersion'] !=
            portableDataOwnerSecretEnvelopeSchemaVersion ||
        decoded['purpose'] != purpose ||
        decoded['status'] != status ||
        ownerLookup is! String ||
        !PersistentPortableDataOwnerScopeResolver._digestPattern.hasMatch(
          ownerLookup,
        ) ||
        ownerLookup != expectedOwnerLookupSha256 ||
        secret is! String ||
        !PersistentPortableDataOwnerScopeResolver._secretPattern.hasMatch(
          secret,
        ) ||
        keyId is! String ||
        !PersistentPortableDataOwnerScopeResolver._keyIdPattern.hasMatch(
          keyId,
        ) ||
        revision is! int ||
        revision < 1 ||
        createdAt == null ||
        rotatedAt == null ||
        rotatedAt.isBefore(createdAt) ||
        protectionClass is! String ||
        protectionClass != expectedProtectionClass) {
      throw StateError('Protected portable owner envelope is invalid.');
    }
    final envelope = _PortableOwnerSecretEnvelope(
      ownerLookupSha256: ownerLookup,
      secret: secret,
      keyId: keyId,
      revision: revision,
      createdAt: createdAt,
      rotatedAt: rotatedAt,
      protectionClass: protectionClass,
    );
    if (envelope.encode() != raw) {
      throw StateError('Protected portable owner envelope is not canonical.');
    }
    return envelope;
  }

  static DateTime? _parseUtc(Object? value) {
    if (value is! String || !value.endsWith('Z')) return null;
    final parsed = DateTime.tryParse(value);
    return parsed?.isUtc == true ? parsed : null;
  }
}
