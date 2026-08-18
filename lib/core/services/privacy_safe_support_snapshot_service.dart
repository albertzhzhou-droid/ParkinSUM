import 'package:flutter/foundation.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../domain/usecases/catalog_inventory_diagnostics.dart';
import '../../domain/usecases/explanation_copy_diagnostics.dart';
import '../../domain/usecases/localization_lint_diagnostics.dart';
import '../../domain/usecases/mechanistic_replay_runner.dart';
import '../../domain/usecases/privacy_safe_support_bundle_service.dart';
import '../../domain/usecases/safe_copy_template_registry.dart';
import '../security/protected_secret_store.dart';
import 'firebase_backend.dart';

const String privacySafeSupportDefaultAppVersion = '0.2.0';
const String privacySafeSupportDefaultBuildNumber = '2';
const Duration privacySafeSupportSnapshotCollectionBudget = Duration(
  seconds: 2,
);

final class PrivacySafeSupportCollectionException implements Exception {
  const PrivacySafeSupportCollectionException(this.code);

  final String code;

  @override
  String toString() => 'PrivacySafeSupportCollectionException($code)';
}

/// Collects only schema-whitelisted, non-user technical facts.
///
/// Every caught diagnostic failure becomes a stable code. Raw exception text,
/// stack traces, paths, endpoints, and account state are neither retained nor
/// accepted by [PrivacySafeSupportSnapshot].
final class PrivacySafeSupportSnapshotService {
  const PrivacySafeSupportSnapshotService({this.beforeCopyDiagnostic});

  /// Test seam proving that arbitrary failures are reduced to stable codes.
  /// Production leaves this null and no thrown object is retained.
  final void Function()? beforeCopyDiagnostic;

  PrivacySafeSupportSnapshot collect() {
    final stopwatch = Stopwatch()..start();
    final checks = <PrivacySafeSupportDiagnosticCheck>[];

    int? safeCopyTemplateCount;
    int? localizationSurfaceCount;
    int? replayScenarioCount;
    try {
      beforeCopyDiagnostic?.call();
      const registry = SafeCopyTemplateRegistry();
      safeCopyTemplateCount = registry.templates.length;
      final report = compileRegistryWithSamples(registry: registry);
      checks.add(
        PrivacySafeSupportDiagnosticCheck(
          checkId: 'explanation_copy_compiler',
          status: report.blockerCount == 0
              ? PrivacySafeSupportCheckStatus.pass
              : PrivacySafeSupportCheckStatus.review,
          observedCount: report.compiledCount,
          expectedCount: report.templateCount,
          findingCodes: report.blockerCount == 0
              ? const []
              : const ['copy_compiler_blocker'],
        ),
      );
    } catch (_) {
      checks.add(_unavailable('explanation_copy_compiler'));
    }
    _ensureBudget(stopwatch);

    try {
      final report = lintAllLocalizationSurfaces();
      localizationSurfaceCount = report.surfaceCount;
      checks.add(
        PrivacySafeSupportDiagnosticCheck(
          checkId: 'localization_safety_lint',
          status: report.blockerCount == 0
              ? PrivacySafeSupportCheckStatus.pass
              : PrivacySafeSupportCheckStatus.review,
          observedCount: report.surfaceCount - report.blockerCount,
          expectedCount: report.surfaceCount,
          findingCodes: report.blockerCount == 0
              ? const []
              : const ['localization_safety_blocker'],
        ),
      );
    } catch (_) {
      checks.add(_unavailable('localization_safety_lint'));
    }
    _ensureBudget(stopwatch);

    try {
      final report = MechanisticReplayRunner().run();
      replayScenarioCount = report.totalCount;
      checks.add(
        PrivacySafeSupportDiagnosticCheck(
          checkId: 'mechanistic_replay',
          status: report.passedCount == report.totalCount
              ? PrivacySafeSupportCheckStatus.pass
              : PrivacySafeSupportCheckStatus.review,
          observedCount: report.passedCount,
          expectedCount: report.totalCount,
          findingCodes: report.passedCount == report.totalCount
              ? const []
              : const ['mechanistic_replay_mismatch'],
        ),
      );
    } catch (_) {
      checks.add(_unavailable('mechanistic_replay'));
    }
    _ensureBudget(stopwatch);

    CatalogInventoryReport? inventory;
    try {
      inventory = buildCatalogInventory();
      checks.add(
        PrivacySafeSupportDiagnosticCheck(
          checkId: 'catalog_inventory',
          status: PrivacySafeSupportCheckStatus.pass,
          observedCount: inventory.sourceDocumentCount,
          expectedCount: inventory.sourceDocumentCount,
          findingCodes: const [],
        ),
      );
    } catch (_) {
      checks.add(_unavailable('catalog_inventory'));
    }
    _ensureBudget(stopwatch);

    final identity = _collectAlgorithmIdentity();
    _ensureBudget(stopwatch);
    final protectedStore = currentProtectedSecretStoreCapability();
    final environment = FirebaseBackend.environment;
    if (!const {'dev', 'stage', 'prod'}.contains(environment)) {
      throw const PrivacySafeSupportCollectionException(
        'environment_not_supported',
      );
    }

    return PrivacySafeSupportSnapshot(
      build: PrivacySafeSupportBuildSnapshot(
        appVersion: const String.fromEnvironment(
          'FLUTTER_BUILD_NAME',
          defaultValue: privacySafeSupportDefaultAppVersion,
        ),
        buildNumber: const String.fromEnvironment(
          'FLUTTER_BUILD_NUMBER',
          defaultValue: privacySafeSupportDefaultBuildNumber,
        ),
        buildCommitSha256: const String.fromEnvironment(
          'PARKINSUM_BUILD_SHA256',
          defaultValue: 'unavailable',
        ),
        backendMode: FirebaseBackend.backendMode,
        environment: environment,
        algorithmConfigurationSha256: identity.sha256Digest,
        algorithmSourceBundleSha256: AlgorithmConfigurationIdentity
            .registeredAlgorithmSourceBundleSha256,
      ),
      platform: PrivacySafeSupportPlatformSnapshot(
        platformFamily: _platformFamily(),
        scheduledNotificationsSupported:
            !kIsWeb &&
            const {
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.macOS,
            }.contains(defaultTargetPlatform),
        protectedStoreCapability: protectedStore.id,
        protectedStoreEncryptedAtRest: protectedStore.isEncryptedAtRest,
        protectedStoreHardwareBackingVerified:
            protectedStore.isHardwareBackedVerified,
        firebaseBackendEnabled: FirebaseBackend.enabled,
        appCheckEnabled: FirebaseBackend.appCheckEnabled,
        appCheckDebugEnabled: FirebaseBackend.appCheckDebug,
      ),
      diagnostics: checks,
      governance: PrivacySafeSupportGovernanceSnapshot(
        safeCopyTemplateCount: safeCopyTemplateCount,
        localizationSurfaceCount: localizationSurfaceCount,
        replayScenarioCount: replayScenarioCount,
        foodCatalogCount: inventory?.foodCount,
        medicationCatalogCount: inventory?.drugCount,
        sourceDocumentCount: inventory?.sourceDocumentCount,
        nonLiveSourceDocumentCount: inventory?.nonLiveSourceDocumentCount,
        placeholderSourceCodeCount: inventory?.unspecifiedSourceCodeCount,
        ruleCount: inventory?.ruleCount,
        modelAssumptionCount: inventory?.modelAssumptionCount,
      ),
    );
  }

  AlgorithmConfigurationIdentity _collectAlgorithmIdentity() {
    try {
      return AlgorithmConfigurationIdentity.defaults();
    } catch (_) {
      throw const PrivacySafeSupportCollectionException(
        'algorithm_identity_unavailable',
      );
    }
  }

  void _ensureBudget(Stopwatch stopwatch) {
    if (stopwatch.elapsed > privacySafeSupportSnapshotCollectionBudget) {
      throw const PrivacySafeSupportCollectionException(
        'collection_time_budget_exceeded',
      );
    }
  }

  PrivacySafeSupportDiagnosticCheck _unavailable(String checkId) =>
      PrivacySafeSupportDiagnosticCheck(
        checkId: checkId,
        status: PrivacySafeSupportCheckStatus.unavailable,
        observedCount: null,
        expectedCount: null,
        findingCodes: ['${checkId}_unavailable'],
      );

  String _platformFamily() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
