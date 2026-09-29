import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';

void main() {
  group('ReminderNotificationCapabilityMatrix', () {
    test('current matrix is exhaustive and fail-closed by platform', () {
      final matrix = ReminderNotificationCapabilityMatrix.current;

      expect(
        matrix.profiles.map((profile) => profile.platform).toSet(),
        ReminderNotificationPlatform.values.toSet(),
      );
      for (final platform in const {
        ReminderNotificationPlatform.android,
        ReminderNotificationPlatform.iOS,
        ReminderNotificationPlatform.macOS,
      }) {
        final profile = matrix.profileFor(platform);
        expect(
          profile.supportsScheduledDelivery,
          isTrue,
          reason: platform.name,
        );
        expect(profile.supportsPermissionRequest, isTrue);
        expect(
          profile.evidenceFor(
            ReminderNotificationCapability.permissionInspection,
          ),
          ReminderNotificationCapabilityEvidence.implementedUnverified,
        );
        expect(
          profile.evidenceFor(ReminderNotificationCapability.visibleDelivery),
          ReminderNotificationCapabilityEvidence.implementedUnverified,
        );
        expect(
          profile
              .behaviorFor(ReminderNotificationBehavior.recurringScheduling)
              .productEnabled,
          isTrue,
        );
        expect(
          profile
              .behaviorFor(ReminderNotificationBehavior.oneTimeScheduling)
              .productEnabled,
          isFalse,
        );
      }
      for (final platform in const {
        ReminderNotificationPlatform.web,
        ReminderNotificationPlatform.windows,
        ReminderNotificationPlatform.linux,
        ReminderNotificationPlatform.unknown,
      }) {
        final profile = matrix.profileFor(platform);
        expect(profile.deliveryMode, ReminderNotificationDeliveryMode.planOnly);
        expect(profile.supportsScheduledDelivery, isFalse);
        expect(
          profile.behaviors,
          hasLength(ReminderNotificationBehavior.values.length),
        );
        expect(
          profile.behaviors.values.where((behavior) => behavior.productEnabled),
          isEmpty,
        );
        expect(
          profile.capabilities.values,
          everyElement(ReminderNotificationCapabilityEvidence.unavailable),
        );
      }
    });

    test(
      'behavior support, product enablement, and evidence stay separate',
      () {
        final matrix = ReminderNotificationCapabilityMatrix.current;
        final android = matrix.profileFor(ReminderNotificationPlatform.android);
        final recurring = android.behaviorFor(
          ReminderNotificationBehavior.recurringScheduling,
        );
        expect(
          recurring.platformSupport,
          ReminderNotificationSupportLevel.supported,
        );
        expect(
          recurring.pluginSupport,
          ReminderNotificationSupportLevel.supported,
        );
        expect(recurring.productEnabled, isTrue);
        expect(
          android
              .behaviorFor(ReminderNotificationBehavior.rebootRestoration)
              .constraints,
          contains(
            ReminderNotificationBehaviorConstraint
                .rebootBehaviorNotDeviceVerified,
          ),
        );
        expect(
          android
              .behaviorFor(ReminderNotificationBehavior.timezoneAdjustment)
              .constraints,
          contains(
            ReminderNotificationBehaviorConstraint
                .timezoneRefreshedOnReconciliation,
          ),
        );
        expect(
          android.evidenceFor(ReminderNotificationCapability.visibleDelivery),
          ReminderNotificationCapabilityEvidence.implementedUnverified,
        );

        final windows = matrix.profileFor(ReminderNotificationPlatform.windows);
        final windowsRecurring = windows.behaviorFor(
          ReminderNotificationBehavior.recurringScheduling,
        );
        expect(
          windowsRecurring.platformSupport,
          ReminderNotificationSupportLevel.conditional,
        );
        expect(
          windowsRecurring.pluginSupport,
          ReminderNotificationSupportLevel.unsupported,
        );
        expect(windowsRecurring.productEnabled, isFalse);
        expect(
          windowsRecurring.constraints,
          contains(
            ReminderNotificationBehaviorConstraint
                .windowsRepeatingNotificationsUnavailable,
          ),
        );
      },
    );

    test('matrix pins the exact notification package and lockfile', () {
      final pin = ReminderNotificationCapabilityMatrix.current.pluginPin;
      expect(pin.package, 'flutter_local_notifications');
      expect(pin.version, '22.3.0');
      expect(
        pin.archiveSha256,
        '1447ba911c60f2ba3f25dae1af151ec187162566b0f57e37771bf0b400f013ad',
      );
      expect(
        sha256.convert(File('pubspec.lock').readAsBytesSync()).toString(),
        pin.lockfileSha256,
      );
    });

    test('behavior constraints are immutable and enablement is explicit', () {
      final mutable = <ReminderNotificationBehaviorConstraint>{
        ReminderNotificationBehaviorConstraint.productPathNotEnabled,
      };
      final profile = ReminderNotificationBehaviorProfile(
        platformSupport: ReminderNotificationSupportLevel.supported,
        pluginSupport: ReminderNotificationSupportLevel.supported,
        productEnabled: false,
        constraints: mutable,
      );
      mutable.add(
        ReminderNotificationBehaviorConstraint
            .androidOemMayDeferBackgroundDelivery,
      );

      expect(profile.constraints, {
        ReminderNotificationBehaviorConstraint.productPathNotEnabled,
      });
      expect(
        () => profile.constraints.add(
          ReminderNotificationBehaviorConstraint
              .androidOemMayDeferBackgroundDelivery,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => ReminderNotificationBehaviorProfile(
          platformSupport: ReminderNotificationSupportLevel.supported,
          pluginSupport: ReminderNotificationSupportLevel.supported,
          productEnabled: true,
          constraints: const {
            ReminderNotificationBehaviorConstraint.productPathNotEnabled,
          },
        ),
        throwsFormatException,
      );
    });

    test('manifest round-trips with one stable content identity', () {
      final source = ReminderNotificationCapabilityMatrix.current;
      final decoded = ReminderNotificationCapabilityMatrix.fromJson(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(source.toJson())) as Map,
        ),
      );

      expect(decoded.toJson(), source.toJson());
      expect(decoded.manifestSha256, source.manifestSha256);
      expect(source.manifestSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('profiles defensively copy capability evidence before hashing', () {
      final mutable =
          <
            ReminderNotificationCapability,
            ReminderNotificationCapabilityEvidence
          >{
            for (final capability in ReminderNotificationCapability.values)
              capability: ReminderNotificationCapabilityEvidence.unavailable,
          };
      final profile = ReminderNotificationCapabilityProfile(
        platform: ReminderNotificationPlatform.web,
        deliveryMode: ReminderNotificationDeliveryMode.planOnly,
        capabilities: mutable,
        behaviors: ReminderNotificationCapabilityMatrix.current
            .profileFor(ReminderNotificationPlatform.web)
            .behaviors,
      );
      final digest = profile.contentSha256;

      mutable[ReminderNotificationCapability.visibleDelivery] =
          ReminderNotificationCapabilityEvidence.artifactVerified;

      expect(
        profile.evidenceFor(ReminderNotificationCapability.visibleDelivery),
        ReminderNotificationCapabilityEvidence.unavailable,
      );
      expect(profile.contentSha256, digest);
      expect(
        () =>
            profile.capabilities[ReminderNotificationCapability
                    .visibleDelivery] =
                ReminderNotificationCapabilityEvidence.artifactVerified,
        throwsUnsupportedError,
      );
    });

    test(
      'future schema, duplicate platform, and partial profile are rejected',
      () {
        Map<String, Object?> clone() => Map<String, Object?>.from(
          jsonDecode(
                jsonEncode(
                  ReminderNotificationCapabilityMatrix.current.toJson(),
                ),
              )
              as Map,
        );

        final future = clone()..['schema_version'] = 3;
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(future),
          throwsFormatException,
        );

        final duplicate = clone();
        final duplicateProfiles = duplicate['profiles']! as List;
        duplicateProfiles.add(
          jsonDecode(jsonEncode(duplicateProfiles.first)) as Object,
        );
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(duplicate),
          throwsFormatException,
        );

        final partial = clone();
        final first = (partial['profiles']! as List).first as Map;
        (first['capabilities']! as Map).remove('visibleDelivery');
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(partial),
          throwsFormatException,
        );

        final missingBehavior = clone();
        final firstProfile =
            (missingBehavior['profiles']! as List).first as Map;
        (firstProfile['behaviors']! as Map).remove('timezoneAdjustment');
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(missingBehavior),
          throwsFormatException,
        );
      },
    );

    test('capability and readiness serialization excludes user content', () {
      final binding = ReminderNotificationCapabilityBinding.forMatrix(
        matrix: ReminderNotificationCapabilityMatrix.current,
        platform: ReminderNotificationPlatform.android,
      );
      final readiness = ReminderDeliveryReadiness(
        capabilityBinding: binding,
        localPlan: ReminderLocalPlanReadiness.savedLocally,
        scheduleRequest: ReminderScheduleRequestReadiness.applied,
        permissionRequest: ReminderPermissionRequestReadiness.returnedAllowed,
        permissionInspection: ReminderPermissionInspectionReadiness.enabled,
        registry: ReminderRegistryReadiness.matched,
        visibleDelivery: ReminderVisibleDeliveryReadiness.unverified,
      );
      final encoded = jsonEncode(readiness.toJson()).toLowerCase();

      for (final forbidden in const {
        'reminder label',
        'activation_token',
        'medication',
        'levodopa',
        'dose_mg',
        'meal',
        'user_scope',
        'email',
      }) {
        expect(encoded, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(
        readiness.visibleDelivery,
        ReminderVisibleDeliveryReadiness.unverified,
      );
    });

    test(
      'matrix rejects unknown fields, changed boundary, and type confusion',
      () {
        Map<String, Object?> clone() => Map<String, Object?>.from(
          jsonDecode(
                jsonEncode(
                  ReminderNotificationCapabilityMatrix.current.toJson(),
                ),
              )
              as Map,
        );

        final unknownTopLevel = clone()..['extra'] = true;
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(unknownTopLevel),
          throwsFormatException,
        );

        final changedBoundary = clone()..['boundary'] = 'delivery verified';
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(changedBoundary),
          throwsFormatException,
        );

        final changedPluginPin = clone();
        (changedPluginPin['pinned_plugin']! as Map)['version'] = '22.3.1';
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(changedPluginPin),
          throwsFormatException,
        );

        final unboundedEnabledBehavior = clone();
        final androidProfile =
            (unboundedEnabledBehavior['profiles']! as List).first as Map;
        final recurring =
            (androidProfile['behaviors']! as Map)['recurringScheduling']!
                as Map;
        recurring['plugin_support'] = 'unknown';
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(
            unboundedEnabledBehavior,
          ),
          throwsFormatException,
        );

        final invalidEntry = clone()..['profiles'] = <Object?>['android'];
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(invalidEntry),
          throwsFormatException,
        );

        final unknownProfileField = clone();
        ((unknownProfileField['profiles']! as List).first as Map)['extra'] =
            true;
        expect(
          () => ReminderNotificationCapabilityMatrix.fromJson(
            unknownProfileField,
          ),
          throwsFormatException,
        );
      },
    );

    test('matrix identity is canonical across profile order', () {
      final reversed = Map<String, Object?>.from(
        jsonDecode(
              jsonEncode(ReminderNotificationCapabilityMatrix.current.toJson()),
            )
            as Map,
      );
      (reversed['profiles']! as List).setAll(
        0,
        (reversed['profiles']! as List).reversed.toList(),
      );

      final decoded = ReminderNotificationCapabilityMatrix.fromJson(reversed);
      expect(
        decoded.manifestSha256,
        ReminderNotificationCapabilityMatrix.current.manifestSha256,
      );
    });

    test('readiness rejects contradictory or unbound delivery claims', () {
      final matrix = ReminderNotificationCapabilityMatrix.current;
      final planOnly = ReminderNotificationCapabilityBinding.forMatrix(
        matrix: matrix,
        platform: ReminderNotificationPlatform.web,
      );
      expect(
        () => ReminderDeliveryReadiness(
          capabilityBinding: planOnly,
          localPlan: ReminderLocalPlanReadiness.savedLocally,
          scheduleRequest: ReminderScheduleRequestReadiness.applied,
          permissionRequest: ReminderPermissionRequestReadiness.returnedAllowed,
          permissionInspection: ReminderPermissionInspectionReadiness.enabled,
          registry: ReminderRegistryReadiness.matched,
          visibleDelivery: ReminderVisibleDeliveryReadiness.unverified,
        ),
        throwsFormatException,
      );

      final scheduled = ReminderNotificationCapabilityBinding.forMatrix(
        matrix: matrix,
        platform: ReminderNotificationPlatform.android,
      );
      expect(
        () => ReminderDeliveryReadiness(
          capabilityBinding: scheduled,
          localPlan: ReminderLocalPlanReadiness.savedLocally,
          scheduleRequest: ReminderScheduleRequestReadiness.applied,
          permissionRequest: ReminderPermissionRequestReadiness.returnedAllowed,
          permissionInspection: ReminderPermissionInspectionReadiness.enabled,
          registry: ReminderRegistryReadiness.matched,
          visibleDelivery: ReminderVisibleDeliveryReadiness.artifactVerified,
        ),
        throwsFormatException,
      );

      expect(
        () => ReminderNotificationCapabilityBinding.fromProvider(
          matrix: matrix,
          profile: matrix.profileFor(ReminderNotificationPlatform.android),
          manifestSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsFormatException,
      );
    });

    test(
      'production gateway resolves the matrix and unknown targets plan-only',
      () async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
        final gateway = LocalReminderNotificationGateway();

        expect(
          gateway.notificationCapabilityProfile.platform,
          ReminderNotificationPlatform.unknown,
        );
        expect(gateway.supportsScheduledDelivery, isFalse);
        expect(await gateway.requestPermission(), isFalse);
        await expectLater(gateway.startResponseHandling(), completes);
      },
    );
  });
}
