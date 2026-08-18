import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const protectedSecretStoreContractVersion = 1;

/// Honest, platform-specific protection statement for secrets stored by the
/// application. This is an engineering capability statement, not attestation
/// that a particular key is hardware-backed.
final class ProtectedSecretStoreCapability {
  const ProtectedSecretStoreCapability({
    required this.id,
    required this.storageMechanism,
    required this.binding,
    required this.backupBehavior,
    required this.availabilityBoundary,
    required this.isEncryptedAtRest,
    required this.isHardwareBackedVerified,
  });

  final String id;
  final String storageMechanism;
  final String binding;
  final String backupBehavior;
  final String availabilityBoundary;
  final bool isEncryptedAtRest;
  final bool isHardwareBackedVerified;
}

ProtectedSecretStoreCapability currentProtectedSecretStoreCapability() {
  if (kIsWeb) {
    return const ProtectedSecretStoreCapability(
      id: 'web_origin_bound_webcrypto_v1',
      storageMechanism: 'webcrypto_encrypted_origin_storage',
      binding: 'browser_origin_and_profile',
      backupBehavior: 'browser_profile_behavior_not_attested',
      availabilityBoundary: 'https_or_localhost_secure_context_required',
      isEncryptedAtRest: true,
      isHardwareBackedVerified: false,
    );
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => const ProtectedSecretStoreCapability(
      id: 'apple_keychain_this_device_only_v1',
      storageMechanism: 'apple_data_protection_keychain',
      binding: 'this_device_only_keychain_item',
      backupBehavior: 'not_synchronizable_not_migratable',
      availabilityBoundary: 'device_must_be_unlocked',
      isEncryptedAtRest: true,
      isHardwareBackedVerified: false,
    ),
    TargetPlatform.macOS => const ProtectedSecretStoreCapability(
      id: 'macos_data_protection_keychain_this_device_only_v1',
      storageMechanism: 'apple_data_protection_keychain',
      binding: 'this_device_only_keychain_item',
      backupBehavior: 'not_synchronizable_not_migratable',
      availabilityBoundary: 'keychain_must_be_available_and_unlocked',
      isEncryptedAtRest: true,
      isHardwareBackedVerified: false,
    ),
    TargetPlatform.android => const ProtectedSecretStoreCapability(
      id: 'android_keystore_wrapped_aes_gcm_v1',
      storageMechanism: 'rsa_oaep_keystore_wrapped_aes_gcm',
      binding: 'application_installation_and_android_keystore',
      backupBehavior: 'app_backup_and_device_transfer_denied_by_manifest',
      availabilityBoundary: 'android_api_23_or_newer_keystore_required',
      isEncryptedAtRest: true,
      isHardwareBackedVerified: false,
    ),
    TargetPlatform.windows => const ProtectedSecretStoreCapability(
      id: 'windows_user_bound_dpapi_v1',
      storageMechanism: 'windows_dpapi_encrypted_file',
      binding: 'windows_user_profile',
      backupBehavior: 'profile_backup_behavior_not_attested',
      availabilityBoundary: 'windows_dpapi_user_context_required',
      isEncryptedAtRest: true,
      isHardwareBackedVerified: false,
    ),
    TargetPlatform.linux => const ProtectedSecretStoreCapability(
      id: 'linux_secret_service_v1',
      storageMechanism: 'freedesktop_secret_service',
      binding: 'desktop_keyring_account',
      backupBehavior: 'keyring_backup_behavior_not_attested',
      availabilityBoundary: 'libsecret_and_unlocked_keyring_required',
      isEncryptedAtRest: true,
      isHardwareBackedVerified: false,
    ),
    TargetPlatform.fuchsia => const ProtectedSecretStoreCapability(
      id: 'unsupported_platform_v1',
      storageMechanism: 'none',
      binding: 'none',
      backupBehavior: 'unavailable',
      availabilityBoundary: 'platform_not_supported',
      isEncryptedAtRest: false,
      isHardwareBackedVerified: false,
    ),
  };
}

final class ProtectedSecretStoreException implements Exception {
  const ProtectedSecretStoreException(this.code);

  final String code;

  @override
  String toString() => 'ProtectedSecretStoreException($code)';
}

abstract interface class ProtectedSecretStore {
  ProtectedSecretStoreCapability get capability;

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Platform adapter with explicit, non-synchronizing Apple policy and an
/// isolated Android namespace. Android reset-on-error is disabled because
/// silently erasing an owner capability would sever existing package binding.
final class FlutterProtectedSecretStore implements ProtectedSecretStore {
  const FlutterProtectedSecretStore({FlutterSecureStorage storage = _storage})
    : _delegate = storage;

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accountName: 'parkinsum.protected-secrets.v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
      useSecureEnclave: false,
    ),
    mOptions: MacOsOptions(
      accountName: 'parkinsum.protected-secrets.v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
      usesDataProtectionKeychain: true,
      useSecureEnclave: false,
    ),
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: false,
      enforceBiometrics: false,
      storageNamespace: 'parkinsum_protected_secrets_v1',
    ),
    webOptions: WebOptions(
      dbName: 'ParkinSUMProtectedSecretsV1',
      publicKey: 'ParkinSUMProtectedSecretsV1',
      useSessionStorage: false,
    ),
  );

  final FlutterSecureStorage _delegate;

  static final RegExp _keyPattern = RegExp(r'^[a-z][a-z0-9._:-]{7,159}$');

  @override
  ProtectedSecretStoreCapability get capability =>
      currentProtectedSecretStoreCapability();

  void _validateKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      throw const ProtectedSecretStoreException('invalid_key');
    }
    if (capability.id == 'unsupported_platform_v1') {
      throw const ProtectedSecretStoreException('unsupported_platform');
    }
  }

  @override
  Future<String?> read(String key) async {
    _validateKey(key);
    try {
      return await _delegate.read(key: key);
    } catch (_) {
      throw const ProtectedSecretStoreException('read_failed');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _validateKey(key);
    if (value.isEmpty || value.length > 16 * 1024) {
      throw const ProtectedSecretStoreException('invalid_value');
    }
    try {
      await _delegate.write(key: key, value: value);
    } catch (_) {
      throw const ProtectedSecretStoreException('write_failed');
    }
  }

  @override
  Future<void> delete(String key) async {
    _validateKey(key);
    try {
      await _delegate.delete(key: key);
    } catch (_) {
      throw const ProtectedSecretStoreException('delete_failed');
    }
  }
}
