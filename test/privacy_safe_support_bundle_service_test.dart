import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/privacy_safe_support_snapshot_service.dart';
import 'package:parkinsum_companion/domain/usecases/privacy_safe_support_bundle_service.dart';

void main() {
  group('PrivacySafeSupportBundleService', () {
    const service = PrivacySafeSupportBundleService();

    test('creates deterministic exact-schema JSON without user data', () {
      final first = service.create(
        snapshot: _snapshot(),
        options: PrivacySafeSupportBundleOptions(),
        generatedAt: DateTime.utc(2026, 8, 18, 12, 30),
      );
      final second = service.create(
        snapshot: _snapshot(),
        options: PrivacySafeSupportBundleOptions(),
        generatedAt: DateTime.utc(2026, 8, 18, 12, 30),
      );

      expect(first.prettyJson, second.prettyJson);
      expect(first.artifactSha256, second.artifactSha256);
      expect(first.byteLength, lessThan(privacySafeSupportBundleMaxBytes));
      expect(first.fileName, startsWith('parkinsum-support-2026-08-18-'));

      final decoded = jsonDecode(first.prettyJson) as Map<String, dynamic>;
      expect(decoded['schema'], privacySafeSupportBundleSchema);
      expect(decoded['schema_version'], privacySafeSupportBundleSchemaVersion);
      expect((decoded['content'] as Map<String, dynamic>).keys.toSet(), {
        'build',
        'diagnostics',
        'governance',
        'platform',
      });
      final lower = first.prettyJson.toLowerCase();
      for (final forbidden in const [
        'patient_id',
        'user_id',
        'email',
        'activation_token',
        'endpoint',
        'stack_trace',
        '/users/',
        'https://',
      ]) {
        expect(lower, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('selected sections are the only sections materialized', () {
      final artifact = service.create(
        snapshot: _snapshot(),
        options: PrivacySafeSupportBundleOptions(
          sections: {
            PrivacySafeSupportSection.build,
            PrivacySafeSupportSection.diagnostics,
          },
        ),
        generatedAt: DateTime.utc(2026, 8, 18),
      );
      final decoded = jsonDecode(artifact.prettyJson) as Map<String, dynamic>;
      expect(decoded['selected_sections'], ['build', 'diagnostics']);
      expect((decoded['content'] as Map<String, dynamic>).keys.toSet(), {
        'build',
        'diagnostics',
      });
    });

    test(
      'changing a safe source fact changes revision and artifact digest',
      () {
        final base = _snapshot();
        final changed = _snapshot(
          platform: const PrivacySafeSupportPlatformSnapshot(
            platformFamily: 'android',
            scheduledNotificationsSupported: true,
            protectedStoreCapability: 'android_keystore_wrapped_aes_gcm_v1',
            protectedStoreEncryptedAtRest: true,
            protectedStoreHardwareBackingVerified: false,
            firebaseBackendEnabled: false,
            appCheckEnabled: false,
            appCheckDebugEnabled: false,
          ),
        );
        expect(base.revisionSha256, isNot(changed.revisionSha256));
        final first = service.create(
          snapshot: base,
          options: PrivacySafeSupportBundleOptions(),
          generatedAt: DateTime.utc(2026, 8, 18),
        );
        final second = service.create(
          snapshot: changed,
          options: PrivacySafeSupportBundleOptions(),
          generatedAt: DateTime.utc(2026, 8, 18),
        );
        expect(first.artifactSha256, isNot(second.artifactSha256));
      },
    );

    test('fails closed on empty selection and malformed identifiers', () {
      expect(
        () => service.create(
          snapshot: _snapshot(),
          options: PrivacySafeSupportBundleOptions(sections: {}),
          generatedAt: DateTime.utc(2026, 8, 18),
        ),
        throwsFormatException,
      );
      expect(
        () => service.create(
          snapshot: _snapshot(
            diagnostics: const [
              PrivacySafeSupportDiagnosticCheck(
                checkId: 'unsafe/check',
                status: PrivacySafeSupportCheckStatus.unavailable,
                observedCount: 0,
                expectedCount: 0,
                findingCodes: ['contains_user@example.com'],
              ),
            ],
          ),
          options: PrivacySafeSupportBundleOptions(),
          generatedAt: DateTime.utc(2026, 8, 18),
        ),
        throwsFormatException,
      );
    });

    test('fails closed before oversized diagnostic materialization', () {
      final diagnostics = List.generate(
        129,
        (index) => PrivacySafeSupportDiagnosticCheck(
          checkId: 'check_${index.toString().padLeft(3, '0')}',
          status: PrivacySafeSupportCheckStatus.pass,
          observedCount: 1,
          expectedCount: 1,
          findingCodes: const [],
        ),
      );
      expect(
        () => service.create(
          snapshot: _snapshot(diagnostics: diagnostics),
          options: PrivacySafeSupportBundleOptions(),
          generatedAt: DateTime.utc(2026, 8, 18),
        ),
        throwsFormatException,
      );
    });
  });

  group('PrivacySafeSupportSnapshotService', () {
    test(
      'collects the real safe snapshot and the bundle passes privacy gate',
      () {
        const collector = PrivacySafeSupportSnapshotService();
        const bundleService = PrivacySafeSupportBundleService();
        final snapshot = collector.collect();
        final artifact = bundleService.create(
          snapshot: snapshot,
          options: PrivacySafeSupportBundleOptions(),
          generatedAt: DateTime.utc(2026, 8, 18),
        );

        expect(snapshot.diagnostics, isNotEmpty);
        expect(
          snapshot.diagnostics.every(
            (item) => item.status == PrivacySafeSupportCheckStatus.pass,
          ),
          isTrue,
        );
        expect(artifact.artifactSha256, hasLength(64));
      },
    );

    test('unknown exception text is replaced by one stable finding code', () {
      const collector = PrivacySafeSupportSnapshotService(
        beforeCopyDiagnostic: _throwSensitiveException,
      );
      final snapshot = collector.collect();
      final check = snapshot.diagnostics.singleWhere(
        (item) => item.checkId == 'explanation_copy_compiler',
      );
      expect(check.status, PrivacySafeSupportCheckStatus.unavailable);
      expect(check.findingCodes, ['explanation_copy_compiler_unavailable']);
      expect(
        jsonEncode(snapshot.toJson()),
        isNot(contains('user@example.com')),
      );
      expect(jsonEncode(snapshot.toJson()), isNot(contains('/Users/private')));
    });

    test('checked-in version defaults match pubspec version', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull);
      expect(privacySafeSupportDefaultAppVersion, match!.group(1));
      expect(privacySafeSupportDefaultBuildNumber, match.group(2));
    });
  });
}

Never _throwSensitiveException() => throw StateError(
  'user@example.com /Users/private Bearer secret-token must never escape',
);

PrivacySafeSupportSnapshot _snapshot({
  PrivacySafeSupportPlatformSnapshot platform =
      const PrivacySafeSupportPlatformSnapshot(
        platformFamily: 'web',
        scheduledNotificationsSupported: false,
        protectedStoreCapability: 'web_origin_bound_webcrypto_v1',
        protectedStoreEncryptedAtRest: true,
        protectedStoreHardwareBackingVerified: false,
        firebaseBackendEnabled: false,
        appCheckEnabled: false,
        appCheckDebugEnabled: false,
      ),
  List<PrivacySafeSupportDiagnosticCheck> diagnostics = const [
    PrivacySafeSupportDiagnosticCheck(
      checkId: 'mechanistic_replay',
      status: PrivacySafeSupportCheckStatus.pass,
      observedCount: 41,
      expectedCount: 41,
      findingCodes: [],
    ),
  ],
}) => PrivacySafeSupportSnapshot(
  build: const PrivacySafeSupportBuildSnapshot(
    appVersion: '0.2.0',
    buildNumber: '2',
    buildCommitSha256: 'unavailable',
    backendMode: 'local',
    environment: 'prod',
    algorithmConfigurationSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    algorithmSourceBundleSha256:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  ),
  platform: platform,
  diagnostics: diagnostics,
  governance: const PrivacySafeSupportGovernanceSnapshot(
    safeCopyTemplateCount: 20,
    localizationSurfaceCount: 5000,
    replayScenarioCount: 41,
    foodCatalogCount: 25,
    medicationCatalogCount: 8,
    sourceDocumentCount: 62,
    nonLiveSourceDocumentCount: 5,
    placeholderSourceCodeCount: 0,
    ruleCount: 14,
    modelAssumptionCount: 23,
  ),
);
