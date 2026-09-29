import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'reminder_notification_capability_matrix.dart';

enum ReminderNotificationRunMode { development, candidate }

enum ReminderNotificationDeviceKind { emulator, physical, unknown }

enum ReminderNotificationSignerIdentityAssurance {
  observedUnreviewed,
  reviewedAttestation,
}

enum ReminderNotificationProcessStartProvider { linuxProcStat, darwinNoReclaim }

enum ReminderNotificationRunExecutionResourceKind {
  buildOutput,
  deviceApplication,
}

@immutable
final class ReminderNotificationRunExecutionResource {
  factory ReminderNotificationRunExecutionResource({
    required ReminderNotificationRunExecutionResourceKind kind,
    required String resourceKeySha256,
    required String ownerTokenSha256,
  }) {
    final value = ReminderNotificationRunExecutionResource._(
      kind: kind,
      resourceKeySha256: resourceKeySha256,
      ownerTokenSha256: ownerTokenSha256,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunExecutionResource.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'kind',
      'resource_key_sha256',
      'owner_token_sha256',
    }, context: 'reminder execution isolation resource');
    return ReminderNotificationRunExecutionResource(
      kind: _requiredEnum(
        json,
        'kind',
        ReminderNotificationRunExecutionResourceKind.values,
      ),
      resourceKeySha256: _requiredString(json, 'resource_key_sha256'),
      ownerTokenSha256: _requiredString(json, 'owner_token_sha256'),
    );
  }

  const ReminderNotificationRunExecutionResource._({
    required this.kind,
    required this.resourceKeySha256,
    required this.ownerTokenSha256,
  });

  final ReminderNotificationRunExecutionResourceKind kind;
  final String resourceKeySha256;
  final String ownerTokenSha256;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'resource_key_sha256': resourceKeySha256,
    'owner_token_sha256': ownerTokenSha256,
  };

  void _validate() {
    _requireSha256(resourceKeySha256, 'resource_key_sha256');
    _requireSha256(ownerTokenSha256, 'owner_token_sha256');
  }
}

@immutable
final class ReminderNotificationRunExecutionIsolation {
  factory ReminderNotificationRunExecutionIsolation({
    required String ownerIdentitySha256,
    required ReminderNotificationProcessStartProvider processStartProvider,
    required int heartbeatIntervalMs,
    required int staleAfterMs,
    required int staleReclaims,
    required Iterable<ReminderNotificationRunExecutionResource> resources,
    required Iterable<String> checkpoints,
    required String leaseEvidenceSha256,
    required bool continuousOwnershipVerified,
    required bool childrenDrainedBeforeDeviceCleanup,
    required bool deviceCleanupCompletedWhileOwned,
  }) {
    final normalizedResources = resources.toList(growable: false)
      ..sort((left, right) => left.kind.index.compareTo(right.kind.index));
    final value = ReminderNotificationRunExecutionIsolation._(
      ownerIdentitySha256: ownerIdentitySha256,
      processStartProvider: processStartProvider,
      heartbeatIntervalMs: heartbeatIntervalMs,
      staleAfterMs: staleAfterMs,
      staleReclaims: staleReclaims,
      resources: List<ReminderNotificationRunExecutionResource>.unmodifiable(
        normalizedResources,
      ),
      checkpoints: List<String>.unmodifiable(checkpoints),
      leaseEvidenceSha256: leaseEvidenceSha256,
      continuousOwnershipVerified: continuousOwnershipVerified,
      childrenDrainedBeforeDeviceCleanup: childrenDrainedBeforeDeviceCleanup,
      deviceCleanupCompletedWhileOwned: deviceCleanupCompletedWhileOwned,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunExecutionIsolation.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'schema_uri',
      'schema_version',
      'owner_identity_sha256',
      'process_start_provider',
      'heartbeat_interval_ms',
      'stale_after_ms',
      'stale_reclaims',
      'resources',
      'checkpoints',
      'lease_evidence_sha256',
      'continuous_ownership_verified',
      'children_drained_before_device_cleanup',
      'device_cleanup_completed_while_owned',
    }, context: 'reminder run execution isolation');
    if (json['schema_uri'] != schemaUri ||
        json['schema_version'] != schemaVersion) {
      throw const FormatException(
        'unsupported reminder execution isolation schema',
      );
    }
    final rawResources = json['resources'];
    if (rawResources is! List) {
      throw const FormatException('resources must be an object list');
    }
    return ReminderNotificationRunExecutionIsolation(
      ownerIdentitySha256: _requiredString(json, 'owner_identity_sha256'),
      processStartProvider: _requiredEnum(
        json,
        'process_start_provider',
        ReminderNotificationProcessStartProvider.values,
      ),
      heartbeatIntervalMs: _requiredInt(json, 'heartbeat_interval_ms'),
      staleAfterMs: _requiredInt(json, 'stale_after_ms'),
      staleReclaims: _requiredInt(json, 'stale_reclaims'),
      resources: rawResources.map((resource) {
        if (resource is! Map || resource.keys.any((key) => key is! String)) {
          throw const FormatException(
            'resources must contain string-key objects',
          );
        }
        return ReminderNotificationRunExecutionResource.fromJson(
          Map<String, Object?>.from(resource),
        );
      }),
      checkpoints: _requiredStringList(json, 'checkpoints'),
      leaseEvidenceSha256: _requiredString(json, 'lease_evidence_sha256'),
      continuousOwnershipVerified: _requiredBool(
        json,
        'continuous_ownership_verified',
      ),
      childrenDrainedBeforeDeviceCleanup: _requiredBool(
        json,
        'children_drained_before_device_cleanup',
      ),
      deviceCleanupCompletedWhileOwned: _requiredBool(
        json,
        'device_cleanup_completed_while_owned',
      ),
    );
  }

  const ReminderNotificationRunExecutionIsolation._({
    required this.ownerIdentitySha256,
    required this.processStartProvider,
    required this.heartbeatIntervalMs,
    required this.staleAfterMs,
    required this.staleReclaims,
    required this.resources,
    required this.checkpoints,
    required this.leaseEvidenceSha256,
    required this.continuousOwnershipVerified,
    required this.childrenDrainedBeforeDeviceCleanup,
    required this.deviceCleanupCompletedWhileOwned,
  });

  static const String schemaUri =
      'parkinsum.android-reminder-execution-isolation/2';
  static const int schemaVersion = 2;
  static const List<String> requiredCheckpoints = [
    'acquiredBeforeSourceAndDeviceInspection',
    'beforeBuild',
    'afterBuildBeforeStage',
    'beforeDeviceAbsenceCheck',
    'beforeFlutterDrive',
    'afterFlutterDriveBeforePull',
    'childrenDrainedBeforeDeviceCleanup',
    'deviceCleanupCompletedWhileOwned',
    'beforeAttestationPublish',
  ];

  final String ownerIdentitySha256;
  final ReminderNotificationProcessStartProvider processStartProvider;
  final int heartbeatIntervalMs;
  final int staleAfterMs;
  final int staleReclaims;
  final List<ReminderNotificationRunExecutionResource> resources;
  final List<String> checkpoints;
  final String leaseEvidenceSha256;
  final bool continuousOwnershipVerified;
  final bool childrenDrainedBeforeDeviceCleanup;
  final bool deviceCleanupCompletedWhileOwned;

  Map<String, Object?> toJson() => {
    'schema_uri': schemaUri,
    'schema_version': schemaVersion,
    'owner_identity_sha256': ownerIdentitySha256,
    'process_start_provider': processStartProvider.name,
    'heartbeat_interval_ms': heartbeatIntervalMs,
    'stale_after_ms': staleAfterMs,
    'stale_reclaims': staleReclaims,
    'resources': resources.map((resource) => resource.toJson()).toList(),
    'checkpoints': checkpoints,
    'lease_evidence_sha256': leaseEvidenceSha256,
    'continuous_ownership_verified': continuousOwnershipVerified,
    'children_drained_before_device_cleanup':
        childrenDrainedBeforeDeviceCleanup,
    'device_cleanup_completed_while_owned': deviceCleanupCompletedWhileOwned,
  };

  void _validate() {
    _requireSha256(ownerIdentitySha256, 'owner_identity_sha256');
    _requireSha256(leaseEvidenceSha256, 'lease_evidence_sha256');
    if (heartbeatIntervalMs <= 0 || staleAfterMs < 3 * heartbeatIntervalMs) {
      throw const FormatException(
        'stale_after_ms must be at least three heartbeat intervals',
      );
    }
    if (staleReclaims < 0 || staleReclaims > 2) {
      throw const FormatException('stale_reclaims must be between 0 and 2');
    }
    if (processStartProvider ==
            ReminderNotificationProcessStartProvider.darwinNoReclaim &&
        staleReclaims != 0) {
      throw const FormatException(
        'darwinNoReclaim cannot reclaim a stale process owner',
      );
    }
    final resourceKinds = resources.map((resource) => resource.kind).toSet();
    final resourceKeys = resources
        .map((resource) => resource.resourceKeySha256)
        .toSet();
    final ownerTokens = resources
        .map((resource) => resource.ownerTokenSha256)
        .toSet();
    final allResourceIdentities = {...resourceKeys, ...ownerTokens};
    if (resources.length != 2 ||
        resourceKinds.length != 2 ||
        !resourceKinds.containsAll(
          ReminderNotificationRunExecutionResourceKind.values,
        ) ||
        resourceKeys.length != resources.length ||
        ownerTokens.length != resources.length ||
        allResourceIdentities.length != resources.length * 2) {
      throw const FormatException(
        'resources must uniquely bind build output and device application',
      );
    }
    if (!listEquals(checkpoints, requiredCheckpoints)) {
      throw const FormatException(
        'execution ownership checkpoints are missing or out of order',
      );
    }
    if (!continuousOwnershipVerified ||
        !childrenDrainedBeforeDeviceCleanup ||
        !deviceCleanupCompletedWhileOwned) {
      throw const FormatException(
        'execution isolation must retain ownership through child drain and cleanup',
      );
    }
  }
}

@immutable
final class ReminderNotificationRunSource {
  factory ReminderNotificationRunSource({
    required String headSha,
    required String headTreeSha,
    required bool dirty,
    required String sourceStateSha256,
    required bool prePostMatch,
  }) {
    final value = ReminderNotificationRunSource._(
      headSha: headSha,
      headTreeSha: headTreeSha,
      dirty: dirty,
      sourceStateSha256: sourceStateSha256,
      prePostMatch: prePostMatch,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunSource.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'head_sha',
      'head_tree_sha',
      'dirty',
      'source_state_sha256',
      'pre_post_match',
    }, context: 'reminder run source');
    return ReminderNotificationRunSource(
      headSha: _requiredString(json, 'head_sha'),
      headTreeSha: _requiredString(json, 'head_tree_sha'),
      dirty: _requiredBool(json, 'dirty'),
      sourceStateSha256: _requiredString(json, 'source_state_sha256'),
      prePostMatch: _requiredBool(json, 'pre_post_match'),
    );
  }

  const ReminderNotificationRunSource._({
    required this.headSha,
    required this.headTreeSha,
    required this.dirty,
    required this.sourceStateSha256,
    required this.prePostMatch,
  });

  final String headSha;
  final String headTreeSha;
  final bool dirty;
  final String sourceStateSha256;
  final bool prePostMatch;

  Map<String, Object?> toJson() => {
    'head_sha': headSha,
    'head_tree_sha': headTreeSha,
    'dirty': dirty,
    'source_state_sha256': sourceStateSha256,
    'pre_post_match': prePostMatch,
  };

  void _validate() {
    _requireGitObjectId(headSha, 'head_sha');
    _requireGitObjectId(headTreeSha, 'head_tree_sha');
    _requireSha256(sourceStateSha256, 'source_state_sha256');
  }
}

@immutable
final class ReminderNotificationRunSigning {
  factory ReminderNotificationRunSigning({
    required bool signatureVerified,
    required int signerCount,
    required String certificateSha256,
    required Iterable<String> verifiedSchemes,
    required bool warningsAsErrors,
    required String buildToolsRevision,
    required String apksignerVersion,
    required String apksignerJarSha256,
    required ReminderNotificationSignerIdentityAssurance identityAssurance,
    String? expectedCertificateSha256,
    required bool expectedCertificateMatch,
  }) {
    final value = ReminderNotificationRunSigning._(
      signatureVerified: signatureVerified,
      signerCount: signerCount,
      certificateSha256: certificateSha256,
      verifiedSchemes: _canonicalStringList(
        verifiedSchemes,
        field: 'verified_schemes',
      ),
      warningsAsErrors: warningsAsErrors,
      buildToolsRevision: buildToolsRevision,
      apksignerVersion: apksignerVersion,
      apksignerJarSha256: apksignerJarSha256,
      identityAssurance: identityAssurance,
      expectedCertificateSha256: expectedCertificateSha256,
      expectedCertificateMatch: expectedCertificateMatch,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunSigning.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'signature_verified',
      'signer_count',
      'certificate_sha256',
      'verified_schemes',
      'warnings_as_errors',
      'build_tools_revision',
      'apksigner_version',
      'apksigner_jar_sha256',
      'identity_assurance',
      'expected_certificate_sha256',
      'expected_certificate_match',
    }, context: 'reminder run APK signing');
    final expectedCertificate = json['expected_certificate_sha256'];
    if (expectedCertificate != null && expectedCertificate is! String) {
      throw const FormatException(
        'expected_certificate_sha256 must be a string or null',
      );
    }
    return ReminderNotificationRunSigning(
      signatureVerified: _requiredBool(json, 'signature_verified'),
      signerCount: _requiredInt(json, 'signer_count'),
      certificateSha256: _requiredString(json, 'certificate_sha256'),
      verifiedSchemes: _requiredStringList(json, 'verified_schemes'),
      warningsAsErrors: _requiredBool(json, 'warnings_as_errors'),
      buildToolsRevision: _requiredString(json, 'build_tools_revision'),
      apksignerVersion: _requiredString(json, 'apksigner_version'),
      apksignerJarSha256: _requiredString(json, 'apksigner_jar_sha256'),
      identityAssurance: _requiredEnum(
        json,
        'identity_assurance',
        ReminderNotificationSignerIdentityAssurance.values,
      ),
      expectedCertificateSha256: expectedCertificate as String?,
      expectedCertificateMatch: _requiredBool(
        json,
        'expected_certificate_match',
      ),
    );
  }

  const ReminderNotificationRunSigning._({
    required this.signatureVerified,
    required this.signerCount,
    required this.certificateSha256,
    required this.verifiedSchemes,
    required this.warningsAsErrors,
    required this.buildToolsRevision,
    required this.apksignerVersion,
    required this.apksignerJarSha256,
    required this.identityAssurance,
    required this.expectedCertificateSha256,
    required this.expectedCertificateMatch,
  });

  static const Set<String> supportedSchemes = {'v1', 'v2', 'v3', 'v3.1', 'v4'};

  final bool signatureVerified;
  final int signerCount;
  final String certificateSha256;
  final List<String> verifiedSchemes;
  final bool warningsAsErrors;
  final String buildToolsRevision;
  final String apksignerVersion;
  final String apksignerJarSha256;
  final ReminderNotificationSignerIdentityAssurance identityAssurance;
  final String? expectedCertificateSha256;
  final bool expectedCertificateMatch;

  Map<String, Object?> toJson() => {
    'signature_verified': signatureVerified,
    'signer_count': signerCount,
    'certificate_sha256': certificateSha256,
    'verified_schemes': verifiedSchemes,
    'warnings_as_errors': warningsAsErrors,
    'build_tools_revision': buildToolsRevision,
    'apksigner_version': apksignerVersion,
    'apksigner_jar_sha256': apksignerJarSha256,
    'identity_assurance': identityAssurance.name,
    'expected_certificate_sha256': expectedCertificateSha256,
    'expected_certificate_match': expectedCertificateMatch,
  };

  void _validate() {
    if (!signatureVerified || signerCount != 1 || !warningsAsErrors) {
      throw const FormatException(
        'APK signature must pass one-signer verification with warnings fatal',
      );
    }
    _requireSha256(certificateSha256, 'certificate_sha256');
    _requireSha256(apksignerJarSha256, 'apksigner_jar_sha256');
    if (verifiedSchemes.isEmpty ||
        verifiedSchemes.any((scheme) => !supportedSchemes.contains(scheme)) ||
        !verifiedSchemes.contains('v2')) {
      throw const FormatException(
        'verified_schemes must contain the reviewed APK v2 scheme',
      );
    }
    if (!_safeLabelPattern.hasMatch(buildToolsRevision) ||
        !_safeLabelPattern.hasMatch(apksignerVersion)) {
      throw const FormatException('invalid apksigner tool identity');
    }
    switch (identityAssurance) {
      case ReminderNotificationSignerIdentityAssurance.observedUnreviewed:
        if (expectedCertificateSha256 != null || expectedCertificateMatch) {
          throw const FormatException(
            'unreviewed signer cannot claim an expected certificate match',
          );
        }
        break;
      case ReminderNotificationSignerIdentityAssurance.reviewedAttestation:
        final expected = expectedCertificateSha256;
        if (expected == null) {
          throw const FormatException(
            'reviewed signer requires an expected certificate digest',
          );
        }
        _requireSha256(expected, 'expected_certificate_sha256');
        if (!expectedCertificateMatch || expected != certificateSha256) {
          throw const FormatException(
            'reviewed signer certificate does not match policy',
          );
        }
        break;
    }
  }
}

@immutable
final class ReminderNotificationRunArtifact {
  factory ReminderNotificationRunArtifact({
    required String fileName,
    required String sha256Digest,
    required int bytes,
    required String sha256AfterRun,
    required bool stable,
    required String applicationId,
    required String applicationLabel,
    required String buildConfiguration,
    required int versionCode,
    required String versionName,
    required String variant,
    required String entrypoint,
    required bool debuggable,
    required int minSdk,
    required int targetSdk,
    required Iterable<String> nativeAbis,
    required String installedBaseSha256,
    required int installedBaseBytes,
    required bool installedMatchesInput,
    required int splitCount,
    required ReminderNotificationRunSigning signing,
  }) {
    final normalizedAbis = _canonicalStringList(
      nativeAbis,
      field: 'native_abis',
    );
    final value = ReminderNotificationRunArtifact._(
      fileName: fileName,
      sha256Digest: sha256Digest,
      bytes: bytes,
      sha256AfterRun: sha256AfterRun,
      stable: stable,
      applicationId: applicationId,
      applicationLabel: applicationLabel,
      buildConfiguration: buildConfiguration,
      versionCode: versionCode,
      versionName: versionName,
      variant: variant,
      entrypoint: entrypoint,
      debuggable: debuggable,
      minSdk: minSdk,
      targetSdk: targetSdk,
      nativeAbis: normalizedAbis,
      installedBaseSha256: installedBaseSha256,
      installedBaseBytes: installedBaseBytes,
      installedMatchesInput: installedMatchesInput,
      splitCount: splitCount,
      signing: signing,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunArtifact.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'file_name',
      'sha256',
      'bytes',
      'sha256_after_run',
      'stable',
      'application_id',
      'application_label',
      'build_configuration',
      'version_code',
      'version_name',
      'variant',
      'entrypoint',
      'debuggable',
      'min_sdk',
      'target_sdk',
      'native_abis',
      'installed_base_sha256',
      'installed_base_bytes',
      'installed_matches_input',
      'split_count',
      'signing',
    }, context: 'reminder run artifact');
    return ReminderNotificationRunArtifact(
      fileName: _requiredString(json, 'file_name'),
      sha256Digest: _requiredString(json, 'sha256'),
      bytes: _requiredInt(json, 'bytes'),
      sha256AfterRun: _requiredString(json, 'sha256_after_run'),
      stable: _requiredBool(json, 'stable'),
      applicationId: _requiredString(json, 'application_id'),
      applicationLabel: _requiredString(json, 'application_label'),
      buildConfiguration: _requiredString(json, 'build_configuration'),
      versionCode: _requiredInt(json, 'version_code'),
      versionName: _requiredString(json, 'version_name'),
      variant: _requiredString(json, 'variant'),
      entrypoint: _requiredString(json, 'entrypoint'),
      debuggable: _requiredBool(json, 'debuggable'),
      minSdk: _requiredInt(json, 'min_sdk'),
      targetSdk: _requiredInt(json, 'target_sdk'),
      nativeAbis: _requiredStringList(json, 'native_abis'),
      installedBaseSha256: _requiredString(json, 'installed_base_sha256'),
      installedBaseBytes: _requiredInt(json, 'installed_base_bytes'),
      installedMatchesInput: _requiredBool(json, 'installed_matches_input'),
      splitCount: _requiredInt(json, 'split_count'),
      signing: ReminderNotificationRunSigning.fromJson(
        _requiredMap(json, 'signing'),
      ),
    );
  }

  const ReminderNotificationRunArtifact._({
    required this.fileName,
    required this.sha256Digest,
    required this.bytes,
    required this.sha256AfterRun,
    required this.stable,
    required this.applicationId,
    required this.applicationLabel,
    required this.buildConfiguration,
    required this.versionCode,
    required this.versionName,
    required this.variant,
    required this.entrypoint,
    required this.debuggable,
    required this.minSdk,
    required this.targetSdk,
    required this.nativeAbis,
    required this.installedBaseSha256,
    required this.installedBaseBytes,
    required this.installedMatchesInput,
    required this.splitCount,
    required this.signing,
  });

  static const _supportedAbis = {'arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64'};
  static const requiredEntrypoint =
      'integration_test/android_reminder_scheduling_test.dart';

  final String fileName;
  final String sha256Digest;
  final int bytes;
  final String sha256AfterRun;
  final bool stable;
  final String applicationId;
  final String applicationLabel;
  final String buildConfiguration;
  final int versionCode;
  final String versionName;
  final String variant;
  final String entrypoint;
  final bool debuggable;
  final int minSdk;
  final int targetSdk;
  final List<String> nativeAbis;
  final String installedBaseSha256;
  final int installedBaseBytes;
  final bool installedMatchesInput;
  final int splitCount;
  final ReminderNotificationRunSigning signing;

  Map<String, Object?> toJson() => {
    'file_name': fileName,
    'sha256': sha256Digest,
    'bytes': bytes,
    'sha256_after_run': sha256AfterRun,
    'stable': stable,
    'application_id': applicationId,
    'application_label': applicationLabel,
    'build_configuration': buildConfiguration,
    'version_code': versionCode,
    'version_name': versionName,
    'variant': variant,
    'entrypoint': entrypoint,
    'debuggable': debuggable,
    'min_sdk': minSdk,
    'target_sdk': targetSdk,
    'native_abis': nativeAbis,
    'installed_base_sha256': installedBaseSha256,
    'installed_base_bytes': installedBaseBytes,
    'installed_matches_input': installedMatchesInput,
    'split_count': splitCount,
    'signing': signing.toJson(),
  };

  void _validate() {
    if (fileName.isEmpty ||
        fileName.length > 128 ||
        !fileName.endsWith('.apk') ||
        fileName.contains('/') ||
        fileName.contains(r'\')) {
      throw const FormatException('file_name must be a safe APK basename');
    }
    _requireSha256(sha256Digest, 'sha256');
    _requireSha256(sha256AfterRun, 'sha256_after_run');
    _requireSha256(installedBaseSha256, 'installed_base_sha256');
    if (bytes <= 0 || installedBaseBytes <= 0) {
      throw const FormatException('artifact byte sizes must be positive');
    }
    final observedStable = sha256Digest == sha256AfterRun;
    if (stable != observedStable) {
      throw const FormatException('stable contradicts artifact digests');
    }
    const expectedApplicationId = 'com.parkinsum.companion.reminderattestation';
    if (applicationId != expectedApplicationId) {
      throw const FormatException('unexpected Android application_id');
    }
    if (applicationLabel != 'ParkinSUM Reminder Attestation' ||
        buildConfiguration != 'reminder_attestation') {
      throw const FormatException(
        'artifact must use the reviewed isolated attestation configuration',
      );
    }
    if (versionCode <= 0 ||
        !_safeLabelPattern.hasMatch(versionName) ||
        !_safeLabelPattern.hasMatch(variant)) {
      throw const FormatException('invalid artifact version or variant');
    }
    if (entrypoint != requiredEntrypoint) {
      throw const FormatException(
        'artifact entrypoint must remain the reviewed integration target',
      );
    }
    if ((variant == 'debug' && !debuggable) ||
        (variant == 'release' && debuggable)) {
      throw const FormatException(
        'debuggable contradicts the reviewed build variant',
      );
    }
    if (minSdk <= 0 || targetSdk < minSdk || targetSdk > 100) {
      throw const FormatException('invalid artifact SDK range');
    }
    if (nativeAbis.isEmpty ||
        nativeAbis.any((abi) => !_supportedAbis.contains(abi))) {
      throw const FormatException('artifact native_abis are unsupported');
    }
    final observedInstalledMatch =
        sha256Digest == installedBaseSha256 && bytes == installedBaseBytes;
    if (installedMatchesInput != observedInstalledMatch) {
      throw const FormatException(
        'installed_matches_input contradicts installed APK evidence',
      );
    }
    if (splitCount <= 0) {
      throw const FormatException('split_count must be positive');
    }
  }
}

@immutable
final class ReminderNotificationRunPlatformBinding {
  factory ReminderNotificationRunPlatformBinding({
    required String pubspecLockSha256,
    required String notificationPluginVersion,
    required String notificationPluginPackageSha256,
    required String sourceManifestSha256,
    required String mergedManifestSha256,
    required String apkManifestTreeSha256,
    required String outputMetadataSha256,
    required int compileSdk,
    required int minSdk,
    required int targetSdk,
    required bool postNotificationsDeclared,
    required bool rebootReceiversDeclared,
    required String buildMode,
  }) {
    final value = ReminderNotificationRunPlatformBinding._(
      pubspecLockSha256: pubspecLockSha256,
      notificationPluginVersion: notificationPluginVersion,
      notificationPluginPackageSha256: notificationPluginPackageSha256,
      sourceManifestSha256: sourceManifestSha256,
      mergedManifestSha256: mergedManifestSha256,
      apkManifestTreeSha256: apkManifestTreeSha256,
      outputMetadataSha256: outputMetadataSha256,
      compileSdk: compileSdk,
      minSdk: minSdk,
      targetSdk: targetSdk,
      postNotificationsDeclared: postNotificationsDeclared,
      rebootReceiversDeclared: rebootReceiversDeclared,
      buildMode: buildMode,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunPlatformBinding.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'pubspec_lock_sha256',
      'notification_plugin_version',
      'notification_plugin_package_sha256',
      'source_manifest_sha256',
      'merged_manifest_sha256',
      'apk_manifest_tree_sha256',
      'output_metadata_sha256',
      'compile_sdk',
      'min_sdk',
      'target_sdk',
      'post_notifications_declared',
      'reboot_receivers_declared',
      'build_mode',
    }, context: 'reminder run platform binding');
    return ReminderNotificationRunPlatformBinding(
      pubspecLockSha256: _requiredString(json, 'pubspec_lock_sha256'),
      notificationPluginVersion: _requiredString(
        json,
        'notification_plugin_version',
      ),
      notificationPluginPackageSha256: _requiredString(
        json,
        'notification_plugin_package_sha256',
      ),
      sourceManifestSha256: _requiredString(json, 'source_manifest_sha256'),
      mergedManifestSha256: _requiredString(json, 'merged_manifest_sha256'),
      apkManifestTreeSha256: _requiredString(json, 'apk_manifest_tree_sha256'),
      outputMetadataSha256: _requiredString(json, 'output_metadata_sha256'),
      compileSdk: _requiredInt(json, 'compile_sdk'),
      minSdk: _requiredInt(json, 'min_sdk'),
      targetSdk: _requiredInt(json, 'target_sdk'),
      postNotificationsDeclared: _requiredBool(
        json,
        'post_notifications_declared',
      ),
      rebootReceiversDeclared: _requiredBool(json, 'reboot_receivers_declared'),
      buildMode: _requiredString(json, 'build_mode'),
    );
  }

  const ReminderNotificationRunPlatformBinding._({
    required this.pubspecLockSha256,
    required this.notificationPluginVersion,
    required this.notificationPluginPackageSha256,
    required this.sourceManifestSha256,
    required this.mergedManifestSha256,
    required this.apkManifestTreeSha256,
    required this.outputMetadataSha256,
    required this.compileSdk,
    required this.minSdk,
    required this.targetSdk,
    required this.postNotificationsDeclared,
    required this.rebootReceiversDeclared,
    required this.buildMode,
  });

  static const String requiredNotificationPluginVersion = '22.3.0';
  static const Set<String> supportedBuildModes = {
    'debug',
    'profile',
    'release',
  };

  final String pubspecLockSha256;
  final String notificationPluginVersion;
  final String notificationPluginPackageSha256;
  final String sourceManifestSha256;
  final String mergedManifestSha256;
  final String apkManifestTreeSha256;
  final String outputMetadataSha256;
  final int compileSdk;
  final int minSdk;
  final int targetSdk;
  final bool postNotificationsDeclared;
  final bool rebootReceiversDeclared;
  final String buildMode;

  Map<String, Object?> toJson() => {
    'pubspec_lock_sha256': pubspecLockSha256,
    'notification_plugin_version': notificationPluginVersion,
    'notification_plugin_package_sha256': notificationPluginPackageSha256,
    'source_manifest_sha256': sourceManifestSha256,
    'merged_manifest_sha256': mergedManifestSha256,
    'apk_manifest_tree_sha256': apkManifestTreeSha256,
    'output_metadata_sha256': outputMetadataSha256,
    'compile_sdk': compileSdk,
    'min_sdk': minSdk,
    'target_sdk': targetSdk,
    'post_notifications_declared': postNotificationsDeclared,
    'reboot_receivers_declared': rebootReceiversDeclared,
    'build_mode': buildMode,
  };

  void _validate() {
    _requireSha256(pubspecLockSha256, 'pubspec_lock_sha256');
    _requireSha256(
      notificationPluginPackageSha256,
      'notification_plugin_package_sha256',
    );
    _requireSha256(sourceManifestSha256, 'source_manifest_sha256');
    _requireSha256(mergedManifestSha256, 'merged_manifest_sha256');
    _requireSha256(apkManifestTreeSha256, 'apk_manifest_tree_sha256');
    _requireSha256(outputMetadataSha256, 'output_metadata_sha256');
    if (notificationPluginVersion != requiredNotificationPluginVersion) {
      throw const FormatException(
        'notification plugin version must match the reviewed lock',
      );
    }
    if (minSdk <= 0 ||
        targetSdk < minSdk ||
        compileSdk < targetSdk ||
        compileSdk > 100) {
      throw const FormatException('invalid platform SDK binding');
    }
    if (!postNotificationsDeclared || !rebootReceiversDeclared) {
      throw const FormatException(
        'Android permission and reboot receiver declarations are required',
      );
    }
    if (!supportedBuildModes.contains(buildMode)) {
      throw const FormatException('unsupported Android build_mode');
    }
  }
}

@immutable
final class ReminderNotificationRunDevice {
  factory ReminderNotificationRunDevice({
    required int sdkInt,
    required String androidRelease,
    required Iterable<String> supportedAbis,
    required String primaryAbi,
    required ReminderNotificationDeviceKind deviceKind,
    required bool prePostMatch,
    required bool applicationIdAbsentBeforeInstall,
    required bool applicationIdRemovedAfterRun,
  }) {
    final normalizedAbis = _canonicalStringList(
      supportedAbis,
      field: 'supported_abis',
    );
    final value = ReminderNotificationRunDevice._(
      sdkInt: sdkInt,
      androidRelease: androidRelease,
      supportedAbis: normalizedAbis,
      primaryAbi: primaryAbi,
      deviceKind: deviceKind,
      prePostMatch: prePostMatch,
      applicationIdAbsentBeforeInstall: applicationIdAbsentBeforeInstall,
      applicationIdRemovedAfterRun: applicationIdRemovedAfterRun,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunDevice.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'sdk_int',
      'android_release',
      'supported_abis',
      'primary_abi',
      'device_kind',
      'pre_post_match',
      'application_id_absent_before_install',
      'application_id_removed_after_run',
    }, context: 'reminder run device');
    return ReminderNotificationRunDevice(
      sdkInt: _requiredInt(json, 'sdk_int'),
      androidRelease: _requiredString(json, 'android_release'),
      supportedAbis: _requiredStringList(json, 'supported_abis'),
      primaryAbi: _requiredString(json, 'primary_abi'),
      deviceKind: _requiredEnum(
        json,
        'device_kind',
        ReminderNotificationDeviceKind.values,
      ),
      prePostMatch: _requiredBool(json, 'pre_post_match'),
      applicationIdAbsentBeforeInstall: _requiredBool(
        json,
        'application_id_absent_before_install',
      ),
      applicationIdRemovedAfterRun: _requiredBool(
        json,
        'application_id_removed_after_run',
      ),
    );
  }

  const ReminderNotificationRunDevice._({
    required this.sdkInt,
    required this.androidRelease,
    required this.supportedAbis,
    required this.primaryAbi,
    required this.deviceKind,
    required this.prePostMatch,
    required this.applicationIdAbsentBeforeInstall,
    required this.applicationIdRemovedAfterRun,
  });

  final int sdkInt;
  final String androidRelease;
  final List<String> supportedAbis;
  final String primaryAbi;
  final ReminderNotificationDeviceKind deviceKind;
  final bool prePostMatch;
  final bool applicationIdAbsentBeforeInstall;
  final bool applicationIdRemovedAfterRun;

  Map<String, Object?> toJson() => {
    'sdk_int': sdkInt,
    'android_release': androidRelease,
    'supported_abis': supportedAbis,
    'primary_abi': primaryAbi,
    'device_kind': deviceKind.name,
    'pre_post_match': prePostMatch,
    'application_id_absent_before_install': applicationIdAbsentBeforeInstall,
    'application_id_removed_after_run': applicationIdRemovedAfterRun,
  };

  void _validate() {
    if (sdkInt <= 0 || sdkInt > 100) {
      throw const FormatException('sdk_int is outside the supported range');
    }
    if (!_safeLabelPattern.hasMatch(androidRelease)) {
      throw const FormatException('android_release must be a safe label');
    }
    if (supportedAbis.isEmpty ||
        supportedAbis.any(
          (abi) =>
              !ReminderNotificationRunArtifact._supportedAbis.contains(abi),
        ) ||
        !supportedAbis.contains(primaryAbi)) {
      throw const FormatException('device ABI evidence is inconsistent');
    }
    if (deviceKind != ReminderNotificationDeviceKind.emulator) {
      throw const FormatException('schema v3 permits emulator evidence only');
    }
    if (!applicationIdAbsentBeforeInstall || !applicationIdRemovedAfterRun) {
      throw const FormatException(
        'attestation application sandbox must be absent before and after run',
      );
    }
  }
}

@immutable
final class ReminderNotificationRunCapability {
  factory ReminderNotificationRunCapability({
    required String schema,
    required int schemaVersion,
    required String manifestSha256,
    required String profileSha256,
    required String platform,
    required String deliveryMode,
  }) {
    final value = ReminderNotificationRunCapability._(
      schema: schema,
      schemaVersion: schemaVersion,
      manifestSha256: manifestSha256,
      profileSha256: profileSha256,
      platform: platform,
      deliveryMode: deliveryMode,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunCapability.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'schema',
      'schema_version',
      'manifest_sha256',
      'profile_sha256',
      'platform',
      'delivery_mode',
    }, context: 'reminder run capability');
    return ReminderNotificationRunCapability(
      schema: _requiredString(json, 'schema'),
      schemaVersion: _requiredInt(json, 'schema_version'),
      manifestSha256: _requiredString(json, 'manifest_sha256'),
      profileSha256: _requiredString(json, 'profile_sha256'),
      platform: _requiredString(json, 'platform'),
      deliveryMode: _requiredString(json, 'delivery_mode'),
    );
  }

  const ReminderNotificationRunCapability._({
    required this.schema,
    required this.schemaVersion,
    required this.manifestSha256,
    required this.profileSha256,
    required this.platform,
    required this.deliveryMode,
  });

  final String schema;
  final int schemaVersion;
  final String manifestSha256;
  final String profileSha256;
  final String platform;
  final String deliveryMode;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'schema_version': schemaVersion,
    'manifest_sha256': manifestSha256,
    'profile_sha256': profileSha256,
    'platform': platform,
    'delivery_mode': deliveryMode,
  };

  void _validate() {
    if (schema != ReminderNotificationCapabilityMatrix.schema ||
        schemaVersion != ReminderNotificationCapabilityMatrix.schemaVersion) {
      throw const FormatException('unsupported notification capability schema');
    }
    _requireSha256(manifestSha256, 'manifest_sha256');
    _requireSha256(profileSha256, 'profile_sha256');
    if (platform != ReminderNotificationPlatform.android.name ||
        deliveryMode != ReminderNotificationDeliveryMode.scheduled.name) {
      throw const FormatException(
        'reminder run capability must be scheduled Android',
      );
    }
  }
}

@immutable
final class ReminderNotificationRunIntegrationObservation {
  factory ReminderNotificationRunIntegrationObservation.create({
    required String runId,
    required String sourceHeadSha,
    required String sourceStateSha256,
    required String buildMode,
    required String notificationCapabilitySchema,
    required int notificationCapabilitySchemaVersion,
    required String notificationCapabilityManifestSha256,
    required String notificationCapabilityProfileSha256,
  }) {
    final value = ReminderNotificationRunIntegrationObservation._(
      reportSchema: reportSchemaUri,
      reportSchemaVersion: currentReportSchemaVersion,
      runId: runId,
      sourceHeadSha: sourceHeadSha,
      sourceStateSha256: sourceStateSha256,
      sourceStateBound: true,
      buildMode: buildMode,
      flutterTargetPlatform: ReminderNotificationPlatform.android.name,
      storageBoundary: requiredStorageBoundary,
      realUserDataAccessed: false,
      notificationCapabilitySchema: notificationCapabilitySchema,
      notificationCapabilitySchemaVersion: notificationCapabilitySchemaVersion,
      notificationCapabilityManifestSha256:
          notificationCapabilityManifestSha256,
      notificationCapabilityProfileSha256: notificationCapabilityProfileSha256,
      notificationCapabilityPlatform: ReminderNotificationPlatform.android.name,
      notificationDeliveryMode: ReminderNotificationDeliveryMode.scheduled.name,
      permission: requiredPermissionState,
      pluginReportedPendingAfterSchedule: expectedPendingAfterSchedule,
      pluginReportedPendingAfterClear: expectedPendingAfterClear,
      visibleDeliveryEvidence:
          ReminderNotificationCapabilityEvidence.implementedUnverified.name,
      visibleDeliveryVerified: false,
      alarmManagerInspected: false,
      notificationBoundary: requiredNotificationBoundary,
      notificationPrivacyMode: requiredPrivacyMode,
      notificationLocaleSnapshot: requiredLocaleSnapshot,
      androidRequestedVisibility: requiredAndroidVisibility,
      configuredCopyContainsUserLabel: false,
      systemVisibleCopyInspected: false,
      systemVisibleCopyContainsUserLabel: null,
      effectiveLockscreenVisibilityInspected: false,
      reportDataSha256: '',
    );
    final completed = value._withReportDataSha256(
      _sha256Json(value._reportDataPayload()),
    );
    completed._validate();
    return completed;
  }

  factory ReminderNotificationRunIntegrationObservation.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'report_data',
      'report_data_sha256',
    }, context: 'reminder run integration observation');
    final report = _requiredMap(json, 'report_data');
    _requireExactKeys(report, const {
      'schema_uri',
      'schema_version',
      'run_id',
      'source_head_sha',
      'source_state_sha256',
      'source_state_bound',
      'build_mode',
      'flutter_target_platform',
      'storage_boundary',
      'real_user_data_accessed',
      'notification_capability_schema',
      'notification_capability_schema_version',
      'notification_capability_manifest_sha256',
      'notification_capability_profile_sha256',
      'notification_capability_platform',
      'notification_delivery_mode',
      'permission',
      'plugin_reported_pending_after_schedule',
      'plugin_reported_pending_after_clear',
      'visible_delivery_evidence',
      'visible_delivery_verified',
      'alarm_manager_inspected',
      'notification_boundary',
      'notification_privacy_mode',
      'notification_locale_snapshot',
      'android_requested_visibility',
      'configured_copy_contains_user_label',
      'system_visible_copy_inspected',
      'system_visible_copy_contains_user_label',
      'effective_lockscreen_visibility_inspected',
    }, context: 'reminder integration report_data');
    final value = ReminderNotificationRunIntegrationObservation._(
      reportSchema: _requiredString(report, 'schema_uri'),
      reportSchemaVersion: _requiredInt(report, 'schema_version'),
      runId: _requiredString(report, 'run_id'),
      sourceHeadSha: _requiredString(report, 'source_head_sha'),
      sourceStateSha256: _requiredString(report, 'source_state_sha256'),
      sourceStateBound: _requiredBool(report, 'source_state_bound'),
      buildMode: _requiredString(report, 'build_mode'),
      flutterTargetPlatform: _requiredString(report, 'flutter_target_platform'),
      storageBoundary: _requiredString(report, 'storage_boundary'),
      realUserDataAccessed: _requiredBool(report, 'real_user_data_accessed'),
      notificationCapabilitySchema: _requiredString(
        report,
        'notification_capability_schema',
      ),
      notificationCapabilitySchemaVersion: _requiredInt(
        report,
        'notification_capability_schema_version',
      ),
      notificationCapabilityManifestSha256: _requiredString(
        report,
        'notification_capability_manifest_sha256',
      ),
      notificationCapabilityProfileSha256: _requiredString(
        report,
        'notification_capability_profile_sha256',
      ),
      notificationCapabilityPlatform: _requiredString(
        report,
        'notification_capability_platform',
      ),
      notificationDeliveryMode: _requiredString(
        report,
        'notification_delivery_mode',
      ),
      permission: _requiredString(report, 'permission'),
      pluginReportedPendingAfterSchedule: _requiredInt(
        report,
        'plugin_reported_pending_after_schedule',
      ),
      pluginReportedPendingAfterClear: _requiredInt(
        report,
        'plugin_reported_pending_after_clear',
      ),
      visibleDeliveryEvidence: _requiredString(
        report,
        'visible_delivery_evidence',
      ),
      visibleDeliveryVerified: _requiredBool(
        report,
        'visible_delivery_verified',
      ),
      alarmManagerInspected: _requiredBool(report, 'alarm_manager_inspected'),
      notificationBoundary: _requiredString(report, 'notification_boundary'),
      notificationPrivacyMode: _requiredString(
        report,
        'notification_privacy_mode',
      ),
      notificationLocaleSnapshot: _requiredString(
        report,
        'notification_locale_snapshot',
      ),
      androidRequestedVisibility: _requiredString(
        report,
        'android_requested_visibility',
      ),
      configuredCopyContainsUserLabel: _requiredBool(
        report,
        'configured_copy_contains_user_label',
      ),
      systemVisibleCopyInspected: _requiredBool(
        report,
        'system_visible_copy_inspected',
      ),
      systemVisibleCopyContainsUserLabel: _nullableBool(
        report,
        'system_visible_copy_contains_user_label',
      ),
      effectiveLockscreenVisibilityInspected: _requiredBool(
        report,
        'effective_lockscreen_visibility_inspected',
      ),
      reportDataSha256: _requiredString(json, 'report_data_sha256'),
    );
    value._validate();
    return value;
  }

  const ReminderNotificationRunIntegrationObservation._({
    required this.reportSchema,
    required this.reportSchemaVersion,
    required this.runId,
    required this.sourceHeadSha,
    required this.sourceStateSha256,
    required this.sourceStateBound,
    required this.buildMode,
    required this.flutterTargetPlatform,
    required this.storageBoundary,
    required this.realUserDataAccessed,
    required this.notificationCapabilitySchema,
    required this.notificationCapabilitySchemaVersion,
    required this.notificationCapabilityManifestSha256,
    required this.notificationCapabilityProfileSha256,
    required this.notificationCapabilityPlatform,
    required this.notificationDeliveryMode,
    required this.permission,
    required this.pluginReportedPendingAfterSchedule,
    required this.pluginReportedPendingAfterClear,
    required this.visibleDeliveryEvidence,
    required this.visibleDeliveryVerified,
    required this.alarmManagerInspected,
    required this.notificationBoundary,
    required this.notificationPrivacyMode,
    required this.notificationLocaleSnapshot,
    required this.androidRequestedVisibility,
    required this.configuredCopyContainsUserLabel,
    required this.systemVisibleCopyInspected,
    required this.systemVisibleCopyContainsUserLabel,
    required this.effectiveLockscreenVisibilityInspected,
    required this.reportDataSha256,
  });

  static const String reportSchemaUri =
      'parkinsum.android-reminder-integration-observation/4';
  static const int currentReportSchemaVersion = 4;
  static const String requiredStorageBoundary = 'no-user-storage';
  static const String requiredPermissionState = 'not-requested';
  static const int expectedPendingAfterSchedule = 7;
  static const int expectedPendingAfterClear = 0;
  static const String requiredNotificationBoundary =
      'Logging reminder only — ParkinSUM does not calculate or prescribe a '
      'dose time.';
  static const String requiredPrivacyMode = 'minimal';
  static const String requiredLocaleSnapshot = 'en';
  static const String requiredAndroidVisibility = 'secret';

  final String reportSchema;
  final int reportSchemaVersion;
  final String runId;
  final String sourceHeadSha;
  final String sourceStateSha256;
  final bool sourceStateBound;
  final String buildMode;
  final String flutterTargetPlatform;
  final String storageBoundary;
  final bool realUserDataAccessed;
  final String notificationCapabilitySchema;
  final int notificationCapabilitySchemaVersion;
  final String notificationCapabilityManifestSha256;
  final String notificationCapabilityProfileSha256;
  final String notificationCapabilityPlatform;
  final String notificationDeliveryMode;
  final String permission;
  final int pluginReportedPendingAfterSchedule;
  final int pluginReportedPendingAfterClear;
  final String visibleDeliveryEvidence;
  final bool visibleDeliveryVerified;
  final bool alarmManagerInspected;
  final String notificationBoundary;
  final String notificationPrivacyMode;
  final String notificationLocaleSnapshot;
  final String androidRequestedVisibility;
  final bool configuredCopyContainsUserLabel;
  final bool systemVisibleCopyInspected;
  final bool? systemVisibleCopyContainsUserLabel;
  final bool effectiveLockscreenVisibilityInspected;
  final String reportDataSha256;

  Map<String, Object?> toJson() => {
    'report_data': _reportDataPayload(),
    'report_data_sha256': reportDataSha256,
  };

  Map<String, Object?> _reportDataPayload() => {
    'schema_uri': reportSchema,
    'schema_version': reportSchemaVersion,
    'run_id': runId,
    'source_head_sha': sourceHeadSha,
    'source_state_sha256': sourceStateSha256,
    'source_state_bound': sourceStateBound,
    'build_mode': buildMode,
    'flutter_target_platform': flutterTargetPlatform,
    'storage_boundary': storageBoundary,
    'real_user_data_accessed': realUserDataAccessed,
    'notification_capability_schema': notificationCapabilitySchema,
    'notification_capability_schema_version':
        notificationCapabilitySchemaVersion,
    'notification_capability_manifest_sha256':
        notificationCapabilityManifestSha256,
    'notification_capability_profile_sha256':
        notificationCapabilityProfileSha256,
    'notification_capability_platform': notificationCapabilityPlatform,
    'notification_delivery_mode': notificationDeliveryMode,
    'permission': permission,
    'plugin_reported_pending_after_schedule':
        pluginReportedPendingAfterSchedule,
    'plugin_reported_pending_after_clear': pluginReportedPendingAfterClear,
    'visible_delivery_evidence': visibleDeliveryEvidence,
    'visible_delivery_verified': visibleDeliveryVerified,
    'alarm_manager_inspected': alarmManagerInspected,
    'notification_boundary': notificationBoundary,
    'notification_privacy_mode': notificationPrivacyMode,
    'notification_locale_snapshot': notificationLocaleSnapshot,
    'android_requested_visibility': androidRequestedVisibility,
    'configured_copy_contains_user_label': configuredCopyContainsUserLabel,
    'system_visible_copy_inspected': systemVisibleCopyInspected,
    'system_visible_copy_contains_user_label':
        systemVisibleCopyContainsUserLabel,
    'effective_lockscreen_visibility_inspected':
        effectiveLockscreenVisibilityInspected,
  };

  ReminderNotificationRunIntegrationObservation _withReportDataSha256(
    String value,
  ) => ReminderNotificationRunIntegrationObservation._(
    reportSchema: reportSchema,
    reportSchemaVersion: reportSchemaVersion,
    runId: runId,
    sourceHeadSha: sourceHeadSha,
    sourceStateSha256: sourceStateSha256,
    sourceStateBound: sourceStateBound,
    buildMode: buildMode,
    flutterTargetPlatform: flutterTargetPlatform,
    storageBoundary: storageBoundary,
    realUserDataAccessed: realUserDataAccessed,
    notificationCapabilitySchema: notificationCapabilitySchema,
    notificationCapabilitySchemaVersion: notificationCapabilitySchemaVersion,
    notificationCapabilityManifestSha256: notificationCapabilityManifestSha256,
    notificationCapabilityProfileSha256: notificationCapabilityProfileSha256,
    notificationCapabilityPlatform: notificationCapabilityPlatform,
    notificationDeliveryMode: notificationDeliveryMode,
    permission: permission,
    pluginReportedPendingAfterSchedule: pluginReportedPendingAfterSchedule,
    pluginReportedPendingAfterClear: pluginReportedPendingAfterClear,
    visibleDeliveryEvidence: visibleDeliveryEvidence,
    visibleDeliveryVerified: visibleDeliveryVerified,
    alarmManagerInspected: alarmManagerInspected,
    notificationBoundary: notificationBoundary,
    notificationPrivacyMode: notificationPrivacyMode,
    notificationLocaleSnapshot: notificationLocaleSnapshot,
    androidRequestedVisibility: androidRequestedVisibility,
    configuredCopyContainsUserLabel: configuredCopyContainsUserLabel,
    systemVisibleCopyInspected: systemVisibleCopyInspected,
    systemVisibleCopyContainsUserLabel: systemVisibleCopyContainsUserLabel,
    effectiveLockscreenVisibilityInspected:
        effectiveLockscreenVisibilityInspected,
    reportDataSha256: value,
  );

  void _validate() {
    if (reportSchema != reportSchemaUri ||
        reportSchemaVersion != currentReportSchemaVersion) {
      throw const FormatException('unsupported integration report schema');
    }
    _requireRunId(runId);
    _requireGitObjectId(sourceHeadSha, 'source_head_sha');
    _requireSha256(sourceStateSha256, 'source_state_sha256');
    if (!sourceStateBound ||
        !ReminderNotificationRunPlatformBinding.supportedBuildModes.contains(
          buildMode,
        ) ||
        flutterTargetPlatform != ReminderNotificationPlatform.android.name) {
      throw const FormatException('integration source/platform is not bound');
    }
    if (storageBoundary != requiredStorageBoundary || realUserDataAccessed) {
      throw const FormatException('integration run accessed user data');
    }
    if (notificationCapabilitySchema !=
            ReminderNotificationCapabilityMatrix.schema ||
        notificationCapabilitySchemaVersion !=
            ReminderNotificationCapabilityMatrix.schemaVersion ||
        notificationCapabilityPlatform !=
            ReminderNotificationPlatform.android.name ||
        notificationDeliveryMode !=
            ReminderNotificationDeliveryMode.scheduled.name) {
      throw const FormatException('integration capability identity is invalid');
    }
    _requireSha256(
      notificationCapabilityManifestSha256,
      'notification_capability_manifest_sha256',
    );
    _requireSha256(
      notificationCapabilityProfileSha256,
      'notification_capability_profile_sha256',
    );
    if (permission != requiredPermissionState) {
      throw const FormatException(
        'integration run must not request permission',
      );
    }
    if (pluginReportedPendingAfterSchedule != expectedPendingAfterSchedule ||
        pluginReportedPendingAfterClear != expectedPendingAfterClear) {
      throw const FormatException(
        'integration registry evidence must be exactly 7 then 0',
      );
    }
    if (visibleDeliveryEvidence !=
            ReminderNotificationCapabilityEvidence.implementedUnverified.name ||
        visibleDeliveryVerified) {
      throw const FormatException(
        'integration run cannot claim visible delivery',
      );
    }
    if (alarmManagerInspected ||
        notificationBoundary != requiredNotificationBoundary ||
        notificationPrivacyMode != requiredPrivacyMode ||
        notificationLocaleSnapshot != requiredLocaleSnapshot ||
        androidRequestedVisibility != requiredAndroidVisibility ||
        configuredCopyContainsUserLabel ||
        systemVisibleCopyInspected ||
        systemVisibleCopyContainsUserLabel != null ||
        effectiveLockscreenVisibilityInspected) {
      throw const FormatException(
        'integration report overstates system notification inspection',
      );
    }
    _requireSha256(reportDataSha256, 'report_data_sha256');
    if (reportDataSha256 != _sha256Json(_reportDataPayload())) {
      throw const FormatException('integration report_data digest drifted');
    }
  }
}

@immutable
final class ReminderNotificationRunClaims {
  factory ReminderNotificationRunClaims({
    required bool artifactExecutionBound,
    required bool schedulerRegistryRoundTripObserved,
    required bool visibleDeliveryVerified,
    required bool releaseEligible,
  }) => ReminderNotificationRunClaims._(
    artifactExecutionBound: artifactExecutionBound,
    schedulerRegistryRoundTripObserved: schedulerRegistryRoundTripObserved,
    visibleDeliveryVerified: visibleDeliveryVerified,
    releaseEligible: releaseEligible,
  );

  factory ReminderNotificationRunClaims.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'artifact_execution_bound',
      'scheduler_registry_round_trip_observed',
      'visible_delivery_verified',
      'release_eligible',
    }, context: 'reminder run claims');
    return ReminderNotificationRunClaims(
      artifactExecutionBound: _requiredBool(json, 'artifact_execution_bound'),
      schedulerRegistryRoundTripObserved: _requiredBool(
        json,
        'scheduler_registry_round_trip_observed',
      ),
      visibleDeliveryVerified: _requiredBool(json, 'visible_delivery_verified'),
      releaseEligible: _requiredBool(json, 'release_eligible'),
    );
  }

  const ReminderNotificationRunClaims._({
    required this.artifactExecutionBound,
    required this.schedulerRegistryRoundTripObserved,
    required this.visibleDeliveryVerified,
    required this.releaseEligible,
  });

  final bool artifactExecutionBound;
  final bool schedulerRegistryRoundTripObserved;
  final bool visibleDeliveryVerified;
  final bool releaseEligible;

  Map<String, Object?> toJson() => {
    'artifact_execution_bound': artifactExecutionBound,
    'scheduler_registry_round_trip_observed':
        schedulerRegistryRoundTripObserved,
    'visible_delivery_verified': visibleDeliveryVerified,
    'release_eligible': releaseEligible,
  };
}

@immutable
final class ReminderNotificationRunAttestation {
  factory ReminderNotificationRunAttestation({
    required String runId,
    required ReminderNotificationRunMode mode,
    required bool pass,
    required Iterable<String> failures,
    required ReminderNotificationRunSource source,
    required ReminderNotificationRunArtifact artifact,
    required ReminderNotificationRunPlatformBinding platformBinding,
    required ReminderNotificationRunDevice device,
    required ReminderNotificationRunExecutionIsolation executionIsolation,
    required ReminderNotificationRunCapability capability,
    required ReminderNotificationRunIntegrationObservation integration,
    required ReminderNotificationRunClaims claims,
  }) {
    final value = ReminderNotificationRunAttestation._(
      runId: runId,
      mode: mode,
      pass: pass,
      failures: _canonicalStringList(failures, field: 'failures'),
      source: source,
      artifact: artifact,
      platformBinding: platformBinding,
      device: device,
      executionIsolation: executionIsolation,
      capability: capability,
      integration: integration,
      claims: claims,
    );
    value._validate();
    return value;
  }

  factory ReminderNotificationRunAttestation.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      r'$schema',
      'schema_version',
      'run_id',
      'mode',
      'pass',
      'failures',
      'source',
      'artifact',
      'platform_binding',
      'device',
      'execution_isolation',
      'capability',
      'integration',
      'claims',
      'boundary',
    }, context: 'Android reminder run attestation');
    if (json[r'$schema'] != schema || json['schema_version'] != schemaVersion) {
      throw const FormatException(
        'unsupported reminder run attestation schema',
      );
    }
    if (json['boundary'] != boundary) {
      throw const FormatException('reminder run attestation boundary changed');
    }
    return ReminderNotificationRunAttestation(
      runId: _requiredString(json, 'run_id'),
      mode: _requiredEnum(json, 'mode', ReminderNotificationRunMode.values),
      pass: _requiredBool(json, 'pass'),
      failures: _requiredStringList(json, 'failures'),
      source: ReminderNotificationRunSource.fromJson(
        _requiredMap(json, 'source'),
      ),
      artifact: ReminderNotificationRunArtifact.fromJson(
        _requiredMap(json, 'artifact'),
      ),
      platformBinding: ReminderNotificationRunPlatformBinding.fromJson(
        _requiredMap(json, 'platform_binding'),
      ),
      device: ReminderNotificationRunDevice.fromJson(
        _requiredMap(json, 'device'),
      ),
      executionIsolation: ReminderNotificationRunExecutionIsolation.fromJson(
        _requiredMap(json, 'execution_isolation'),
      ),
      capability: ReminderNotificationRunCapability.fromJson(
        _requiredMap(json, 'capability'),
      ),
      integration: ReminderNotificationRunIntegrationObservation.fromJson(
        _requiredMap(json, 'integration'),
      ),
      claims: ReminderNotificationRunClaims.fromJson(
        _requiredMap(json, 'claims'),
      ),
    );
  }

  const ReminderNotificationRunAttestation._({
    required this.runId,
    required this.mode,
    required this.pass,
    required this.failures,
    required this.source,
    required this.artifact,
    required this.platformBinding,
    required this.device,
    required this.executionIsolation,
    required this.capability,
    required this.integration,
    required this.claims,
  });

  static const String schema = 'parkinsum.android-reminder-run-attestation/4';
  static const int schemaVersion = 4;
  static const String boundary =
      'Cooperatively isolated, checksum-bound scheduler, plugin-registry, manifest, '
      'and APK signature integrity evidence does not fence independent build '
      'commands, prove detached descendants ended, establish a reviewed production '
      'signer, or prove '
      'visible notification delivery, display timing, lock-screen behavior, '
      'activation, background execution, or reproducible source-to-binary '
      'provenance.';

  final String runId;
  final ReminderNotificationRunMode mode;
  final bool pass;
  final List<String> failures;
  final ReminderNotificationRunSource source;
  final ReminderNotificationRunArtifact artifact;
  final ReminderNotificationRunPlatformBinding platformBinding;
  final ReminderNotificationRunDevice device;
  final ReminderNotificationRunExecutionIsolation executionIsolation;
  final ReminderNotificationRunCapability capability;
  final ReminderNotificationRunIntegrationObservation integration;
  final ReminderNotificationRunClaims claims;

  bool get releaseEligible => claims.releaseEligible;

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'run_id': runId,
    'mode': mode.name,
    'pass': pass,
    'failures': failures,
    'source': source.toJson(),
    'artifact': artifact.toJson(),
    'platform_binding': platformBinding.toJson(),
    'device': device.toJson(),
    'execution_isolation': executionIsolation.toJson(),
    'capability': capability.toJson(),
    'integration': integration.toJson(),
    'claims': claims.toJson(),
    'boundary': boundary,
  };

  String get canonicalJson => _canonicalJson(toJson());

  String get contentSha256 =>
      sha256.convert(utf8.encode(canonicalJson)).toString();

  void _validate() {
    _requireRunId(runId);
    if (mode == ReminderNotificationRunMode.candidate && source.dirty) {
      throw const FormatException('candidate evidence requires a clean source');
    }
    if (mode == ReminderNotificationRunMode.candidate &&
        artifact.signing.identityAssurance !=
            ReminderNotificationSignerIdentityAssurance.reviewedAttestation) {
      throw const FormatException(
        'candidate evidence requires a reviewed attestation signer',
      );
    }
    if (integration.runId != runId ||
        integration.sourceHeadSha != source.headSha ||
        integration.sourceStateSha256 != source.sourceStateSha256) {
      throw const FormatException('integration run/source identity drifted');
    }
    if (integration.notificationCapabilitySchema != capability.schema ||
        integration.notificationCapabilitySchemaVersion !=
            capability.schemaVersion ||
        integration.notificationCapabilityManifestSha256 !=
            capability.manifestSha256 ||
        integration.notificationCapabilityProfileSha256 !=
            capability.profileSha256 ||
        integration.notificationCapabilityPlatform != capability.platform ||
        integration.notificationDeliveryMode != capability.deliveryMode) {
      throw const FormatException(
        'integration and host capability identities drifted',
      );
    }
    if (platformBinding.minSdk != artifact.minSdk ||
        platformBinding.targetSdk != artifact.targetSdk ||
        platformBinding.buildMode != artifact.variant ||
        integration.buildMode != platformBinding.buildMode) {
      throw const FormatException(
        'platform binding contradicts the APK or integration build mode',
      );
    }
    if (device.sdkInt < artifact.minSdk ||
        !artifact.nativeAbis.contains(device.primaryAbi)) {
      throw const FormatException('artifact is incompatible with the device');
    }

    final artifactExecutionBound =
        source.prePostMatch &&
        artifact.stable &&
        artifact.installedMatchesInput &&
        artifact.splitCount == 1 &&
        device.prePostMatch &&
        device.applicationIdAbsentBeforeInstall &&
        device.applicationIdRemovedAfterRun &&
        executionIsolation.continuousOwnershipVerified &&
        executionIsolation.childrenDrainedBeforeDeviceCleanup &&
        executionIsolation.deviceCleanupCompletedWhileOwned;
    if (claims.artifactExecutionBound != artifactExecutionBound) {
      throw const FormatException(
        'artifact_execution_bound contradicts mechanical evidence',
      );
    }
    if (!claims.schedulerRegistryRoundTripObserved ||
        claims.visibleDeliveryVerified) {
      throw const FormatException(
        'claims overstate the reminder integration evidence',
      );
    }
    // This schema binds an isolated integration-test package and entrypoint,
    // never the production package distributed to users.
    const expectedReleaseEligible = false;
    if (claims.releaseEligible != expectedReleaseEligible) {
      throw const FormatException(
        'release_eligible contradicts run mode and evidence',
      );
    }
    if (pass) {
      if (failures.isNotEmpty || !artifactExecutionBound) {
        throw const FormatException(
          'passing evidence cannot retain failures or mechanical drift',
        );
      }
    } else if (failures.isEmpty) {
      throw const FormatException('failed evidence must retain a failure');
    }
  }
}

final _gitObjectIdPattern = RegExp(r'^[a-f0-9]{40}([a-f0-9]{24})?$');
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final _runIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{7,95}$');
final _safeLabelPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$');

void _requireGitObjectId(String value, String field) {
  if (!_gitObjectIdPattern.hasMatch(value)) {
    throw FormatException('$field must be a lowercase Git object id');
  }
}

void _requireSha256(String value, String field) {
  if (!_sha256Pattern.hasMatch(value)) {
    throw FormatException('$field must be a lowercase SHA-256');
  }
}

void _requireRunId(String value) {
  if (!_runIdPattern.hasMatch(value)) {
    throw const FormatException('run_id must be a safe run-scoped identifier');
  }
}

void _requireExactKeys(
  Map<Object?, Object?> map,
  Set<String> expected, {
  required String context,
}) {
  final keys = map.keys;
  if (keys.any((key) => key is! String) ||
      keys.length != expected.length ||
      !keys.toSet().containsAll(expected)) {
    throw FormatException('$context has unsupported, missing, or unknown keys');
  }
}

String _requiredString(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

bool _requiredBool(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

bool? _nullableBool(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value != null && value is! bool) {
    throw FormatException('$field must be a boolean or null');
  }
  return value as bool?;
}

Map<String, Object?> _requiredMap(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be a string-key object');
  }
  return Map<String, Object?>.from(value);
}

List<String> _requiredStringList(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field must be a string list');
  }
  return value.cast<String>();
}

T _requiredEnum<T extends Enum>(
  Map<String, Object?> map,
  String field,
  Iterable<T> values,
) {
  final raw = _requiredString(map, field);
  return values.where((value) => value.name == raw).firstOrNull ??
      (throw FormatException('$field has an unsupported value'));
}

List<String> _canonicalStringList(
  Iterable<String> values, {
  required String field,
}) {
  final copied = values.toList(growable: false);
  if (copied.any((value) => value.isEmpty) ||
      copied.toSet().length != copied.length) {
    throw FormatException('$field must contain unique non-empty strings');
  }
  return List<String>.unmodifiable(copied.toList()..sort());
}

String _sha256Json(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('canonical JSON maps require string keys');
    }
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw FormatException(
    'unsupported canonical JSON value: ${value.runtimeType}',
  );
}
