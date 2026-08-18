import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/security/protected_secret_store.dart';

void main() {
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
