import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/security/protected_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  test(
    'Android upgrade preserves the existing cipher and namespace profile',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'read' ? 'existing-owner-capability' : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      const store = FlutterProtectedSecretStore();
      expect(await store.read('owner.scope.v1'), 'existing-owner-capability');
      await store.write('owner.scope.v1', 'existing-owner-capability');
      await store.delete('owner.scope.v1');

      expect(calls.map((call) => call.method), ['read', 'write', 'delete']);
      for (final call in calls) {
        final arguments = call.arguments as Map;
        final options = arguments['options'] as Map;
        expect(options['storageNamespace'], 'parkinsum_protected_secrets_v1');
        expect(
          options['keyCipherAlgorithm'],
          'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
        );
        expect(options['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
        expect(options['resetOnError'], 'false');
        expect(options['migrateOnAlgorithmChange'], 'true');
        expect(options['migrateWithBackup'], 'false');
        expect(options['enforceBiometrics'], 'false');
      }
      expect(
        store.capability.availabilityBoundary,
        'android_api_24_or_newer_keystore_required',
      );
    },
  );

  test('unavailable keystore fails closed without an adapter reset', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'keystore_unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await expectLater(
      const FlutterProtectedSecretStore().read('owner.scope.v1'),
      throwsA(
        isA<ProtectedSecretStoreException>().having(
          (error) => error.code,
          'code',
          'read_failed',
        ),
      ),
    );
    expect(calls.map((call) => call.method), ['read']);
    expect((calls.single.arguments as Map)['options']['resetOnError'], 'false');
  });

  test(
    'native platform capability statements stay distinct and conservative',
    () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final capabilities = <TargetPlatform, ProtectedSecretStoreCapability>{};
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        capabilities[platform] = currentProtectedSecretStoreCapability();
      }

      expect(
        capabilities.values.map((capability) => capability.id).toSet(),
        hasLength(TargetPlatform.values.length),
      );
      for (final entry in capabilities.entries) {
        expect(
          entry.value.isHardwareBackedVerified,
          isFalse,
          reason: '${entry.key.name} has no runtime hardware attestation',
        );
        expect(
          entry.value.isEncryptedAtRest,
          entry.key == TargetPlatform.fuchsia ? isFalse : isTrue,
        );
      }
      expect(
        capabilities[TargetPlatform.fuchsia]!.id,
        'unsupported_platform_v1',
      );
    },
  );
}
