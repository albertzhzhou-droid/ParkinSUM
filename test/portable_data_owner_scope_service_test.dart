import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/security/protected_secret_store.dart';
import 'package:parkinsum_companion/core/services/portable_data_owner_scope_service.dart';

void main() {
  const rawScope = 'local_sensitive@example.test';

  test(
    'concurrent local resolution creates one protected capability',
    () async {
      final protected = _MemoryProtectedSecretStore();
      final legacy = _MemoryLegacyStore();
      final random = _DeterministicRandom();
      final resolver = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: legacy,
        randomBytes: random.call,
        now: () => DateTime.utc(2026, 8, 18, 12),
      );

      final resolved = await Future.wait(<Future<PortableDataResolvedOwner>>[
        for (var index = 0; index < 12; index++)
          resolver.resolve(
            rawScope: rawScope,
            scopeKind: localPortableScopeKind,
          ),
      ]);

      expect(
        resolved.map((value) => value.effectiveOpaqueScope).toSet(),
        hasLength(1),
      );
      expect(resolved.singleOrNull, isNull);
      expect(resolved.first.revision, 1);
      expect(resolved.first.protectionClass, protected.capability.id);
      expect(resolved.first.migratedFromLegacy, isFalse);
      expect(
        resolved.first.effectiveOpaqueScope,
        matches(r'^odt_[0-9a-f]{64}$'),
      );
      expect(protected.values, hasLength(1));
      expect(protected.values.keys.single, isNot(contains(rawScope)));
      expect(protected.values.values.single, isNot(contains(rawScope)));
      expect(
        random.calls,
        2,
        reason: 'one secret and one key id are generated',
      );

      final envelope = jsonDecode(protected.values.values.single) as Map;
      expect(envelope['schemaVersion'], 1);
      expect(envelope['revision'], 1);
      expect(envelope['protectionClass'], protected.capability.id);
      expect(envelope.keys, hasLength(10));
    },
  );

  test(
    'verified v1 SharedPreferences value migrates once and is removed',
    () async {
      const legacySecret =
          'odt_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final protected = _MemoryProtectedSecretStore();
      final legacy = _MemoryLegacyStore(<String, String>{
        _legacyKey(rawScope): legacySecret,
      });
      final resolver = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: legacy,
        randomBytes: _DeterministicRandom().call,
        now: () => DateTime.utc(2026, 8, 18, 12),
      );

      final owner = await resolver.resolve(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );

      expect(owner.effectiveOpaqueScope, legacySecret);
      expect(owner.migratedFromLegacy, isTrue);
      expect(legacy.values, isEmpty);
      expect(protected.values, hasLength(1));
      final again = await resolver.resolve(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );
      expect(again.effectiveOpaqueScope, legacySecret);
      expect(again.migratedFromLegacy, isFalse);
    },
  );

  test('malformed protected state fails closed without regeneration', () async {
    final protected = _MemoryProtectedSecretStore(<String, String>{
      _protectedKey(rawScope): '{"schemaVersion":1}',
    });
    final random = _DeterministicRandom();
    final resolver = PersistentPortableDataOwnerScopeResolver(
      protectedStore: protected,
      legacyStore: _MemoryLegacyStore(),
      randomBytes: random.call,
    );

    await expectLater(
      resolver.resolve(rawScope: rawScope, scopeKind: localPortableScopeKind),
      throwsStateError,
    );
    expect(random.calls, 0);
    expect(protected.values[_protectedKey(rawScope)], '{"schemaVersion":1}');
  });

  test('protected and legacy capability conflict fails closed', () async {
    final protected = _MemoryProtectedSecretStore();
    final legacy = _MemoryLegacyStore();
    final resolver = PersistentPortableDataOwnerScopeResolver(
      protectedStore: protected,
      legacyStore: legacy,
      randomBytes: _DeterministicRandom().call,
      now: () => DateTime.utc(2026, 8, 18, 12),
    );
    await resolver.resolve(
      rawScope: rawScope,
      scopeKind: localPortableScopeKind,
    );
    legacy.values[_legacyKey(rawScope)] =
        'odt_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    await expectLater(
      resolver.resolve(rawScope: rawScope, scopeKind: localPortableScopeKind),
      throwsStateError,
    );
    expect(legacy.values, isNotEmpty);
  });

  test('write acknowledgement loss recovers but dropped write fails', () async {
    final recoveredStore = _MemoryProtectedSecretStore()
      ..writeMode = _WriteMode.throwAfterWrite;
    final recovered = PersistentPortableDataOwnerScopeResolver(
      protectedStore: recoveredStore,
      legacyStore: _MemoryLegacyStore(),
      randomBytes: _DeterministicRandom().call,
    );
    expect(
      await recovered.resolve(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      ),
      isA<PortableDataResolvedOwner>(),
    );

    final droppedStore = _MemoryProtectedSecretStore()
      ..writeMode = _WriteMode.drop;
    final dropped = PersistentPortableDataOwnerScopeResolver(
      protectedStore: droppedStore,
      legacyStore: _MemoryLegacyStore(),
      randomBytes: _DeterministicRandom().call,
    );
    await expectLater(
      dropped.resolve(rawScope: rawScope, scopeKind: localPortableScopeKind),
      throwsStateError,
    );
  });

  test(
    'rotation changes binding and revision; revocation removes both stores',
    () async {
      final protected = _MemoryProtectedSecretStore();
      final legacy = _MemoryLegacyStore();
      final resolver = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: legacy,
        randomBytes: _DeterministicRandom().call,
        now: () => DateTime.utc(2026, 8, 18, 12),
      );
      final first = await resolver.resolve(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );
      final rotated = await resolver.rotate(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );
      expect(rotated.revision, 2);
      expect(rotated.effectiveOpaqueScope, isNot(first.effectiveOpaqueScope));
      expect(rotated.keyId, isNot(first.keyId));

      await resolver.revoke(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );
      expect(protected.values, isEmpty);
      expect(legacy.values, isEmpty);
    },
  );

  test(
    'local accounts remain isolated and Firebase does not create a secret',
    () async {
      final protected = _MemoryProtectedSecretStore();
      final resolver = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: _MemoryLegacyStore(),
        randomBytes: _DeterministicRandom().call,
      );
      final a = await resolver.resolve(
        rawScope: 'local_a',
        scopeKind: localPortableScopeKind,
      );
      final b = await resolver.resolve(
        rawScope: 'local_b',
        scopeKind: localPortableScopeKind,
      );
      expect(a.effectiveOpaqueScope, isNot(b.effectiveOpaqueScope));
      expect(protected.values, hasLength(2));

      final firebase = await resolver.resolve(
        rawScope: 'firebase_uid_123',
        scopeKind: firebasePortableScopeKind,
      );
      expect(firebase.effectiveOpaqueScope, 'firebase_uid_123');
      expect(
        firebase.protectionClass,
        'firebase_account_identity_not_local_secret',
      );
      expect(firebase.keyId, isNull);
      expect(protected.values, hasLength(2));
    },
  );

  test(
    'rotation rejects clock rollback and nonadvancing random values',
    () async {
      var now = DateTime.utc(2026, 8, 18, 12);
      final protected = _MemoryProtectedSecretStore();
      final random = _DeterministicRandom();
      final resolver = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: _MemoryLegacyStore(),
        randomBytes: random.call,
        now: () => now,
      );
      final first = await resolver.resolve(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );
      final beforeRollback = Map<String, String>.from(protected.values);
      now = DateTime.utc(2026, 8, 18, 11);
      await expectLater(
        resolver.rotate(rawScope: rawScope, scopeKind: localPortableScopeKind),
        throwsStateError,
      );
      expect(protected.values, beforeRollback);

      final stuck = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: _MemoryLegacyStore(),
        randomBytes: (length) => length == 32
            ? _bytesFromHex(first.effectiveOpaqueScope.substring(4))
            : _bytesFromHex(first.keyId!.substring(4)),
        now: () => DateTime.utc(2026, 8, 18, 13),
      );
      await expectLater(
        stuck.rotate(rawScope: rawScope, scopeKind: localPortableScopeKind),
        throwsStateError,
      );
      expect(protected.values, beforeRollback);
    },
  );

  test(
    'noncanonical or duplicate-key protected envelopes fail closed',
    () async {
      final protected = _MemoryProtectedSecretStore();
      final resolver = PersistentPortableDataOwnerScopeResolver(
        protectedStore: protected,
        legacyStore: _MemoryLegacyStore(),
        randomBytes: _DeterministicRandom().call,
        now: () => DateTime.utc(2026, 8, 18, 12),
      );
      await resolver.resolve(
        rawScope: rawScope,
        scopeKind: localPortableScopeKind,
      );
      final key = protected.values.keys.single;
      final canonical = protected.values[key]!;
      protected.values[key] = canonical.replaceFirst('{', '{ ');
      await expectLater(
        resolver.resolve(rawScope: rawScope, scopeKind: localPortableScopeKind),
        throwsStateError,
      );
      protected.values[key] = canonical.replaceFirst(
        '"schemaVersion":1',
        '"schemaVersion":1,"schemaVersion":1',
      );
      await expectLater(
        resolver.resolve(rawScope: rawScope, scopeKind: localPortableScopeKind),
        throwsStateError,
      );
    },
  );

  test('capability labels never claim hardware attestation', () {
    final capability = _MemoryProtectedSecretStore().capability;
    expect(capability.isEncryptedAtRest, isTrue);
    expect(capability.isHardwareBackedVerified, isFalse);
  });
}

String _legacyKey(String rawScope) =>
    '$userPortableDataOwnerTokenPreferencePrefix${sha256.convert(utf8.encode('parkinsum-portable-owner-token-lookup-v1|$localPortableScopeKind|$rawScope'))}';

String _protectedKey(String rawScope) =>
    '$userPortableDataOwnerProtectedKeyPrefix${sha256.convert(utf8.encode('parkinsum-portable-owner-token-lookup-v2|$localPortableScopeKind|$rawScope'))}';

enum _WriteMode { normal, throwAfterWrite, drop }

final class _MemoryProtectedSecretStore implements ProtectedSecretStore {
  _MemoryProtectedSecretStore([Map<String, String>? initial])
    : values = <String, String>{...?initial};

  final Map<String, String> values;
  _WriteMode writeMode = _WriteMode.normal;

  @override
  ProtectedSecretStoreCapability get capability =>
      const ProtectedSecretStoreCapability(
        id: 'test_protected_store_v1',
        storageMechanism: 'memory',
        binding: 'test_process',
        backupBehavior: 'not_applicable',
        availabilityBoundary: 'test_only',
        isEncryptedAtRest: true,
        isHardwareBackedVerified: false,
      );

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (writeMode != _WriteMode.drop) values[key] = value;
    if (writeMode == _WriteMode.throwAfterWrite) {
      throw const ProtectedSecretStoreException('test_lost_ack');
    }
  }
}

final class _MemoryLegacyStore implements LegacyPortableOwnerTokenStore {
  _MemoryLegacyStore([Map<String, String>? initial])
    : values = <String, String>{...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);
}

final class _DeterministicRandom {
  int calls = 0;

  List<int> call(int length) {
    final offset = calls++;
    return List<int>.generate(length, (index) => (offset + index) % 256);
  }
}

List<int> _bytesFromHex(String value) => <int>[
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];
