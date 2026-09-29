import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum ReminderNotificationPlatform {
  android,
  iOS,
  macOS,
  web,
  windows,
  linux,
  unknown,
}

enum ReminderNotificationDeliveryMode { scheduled, planOnly }

enum ReminderNotificationCapability {
  scheduleAdapter,
  permissionRequest,
  permissionInspection,
  pendingInspection,
  bodyTap,
  coldStart,
  backgroundAction,
  visibleDelivery,
}

/// The strongest evidence ParkinSUM currently has for one platform capability.
///
/// `implementedUnverified` means a code path exists, but no checksum-bound
/// release artifact and target-device observation proves the user-visible
/// behavior. It must never be rendered as verified delivery.
enum ReminderNotificationCapabilityEvidence {
  unavailable,
  implementedUnverified,
  artifactVerified,
}

enum ReminderNotificationBehavior {
  oneTimeScheduling,
  recurringScheduling,
  rebootRestoration,
  timezoneAdjustment,
  foregroundResponse,
  coldStartResponse,
  backgroundAction,
}

enum ReminderNotificationSupportLevel {
  supported,
  conditional,
  unsupported,
  unknown,
}

enum ReminderNotificationBehaviorConstraint {
  productPathNotEnabled,
  androidOemMayDeferBackgroundDelivery,
  androidBootReceiverAndPermissionRequired,
  rebootBehaviorNotDeviceVerified,
  timezoneRefreshedOnReconciliation,
  timezoneBehaviorNotDeviceVerified,
  iosPendingNotificationsLimitedTo64,
  linuxSchedulerUnavailable,
  browserSchedulerUnavailable,
  windowsRepeatingNotificationsUnavailable,
  foregroundCallbackRequiresRunningApp,
  backgroundActionHandlerNotConfigured,
  legacyGatewaySupportUnqualified,
}

@immutable
class ReminderNotificationBehaviorProfile {
  factory ReminderNotificationBehaviorProfile({
    required ReminderNotificationSupportLevel platformSupport,
    required ReminderNotificationSupportLevel pluginSupport,
    required bool productEnabled,
    required Set<ReminderNotificationBehaviorConstraint> constraints,
  }) {
    final profile = ReminderNotificationBehaviorProfile._(
      platformSupport: platformSupport,
      pluginSupport: pluginSupport,
      productEnabled: productEnabled,
      constraints: Set.unmodifiable(Set.of(constraints)),
    );
    profile.validate();
    return profile;
  }

  const ReminderNotificationBehaviorProfile._({
    required this.platformSupport,
    required this.pluginSupport,
    required this.productEnabled,
    required this.constraints,
  });

  factory ReminderNotificationBehaviorProfile.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'platform_support',
      'plugin_support',
      'product_enabled',
      'constraints',
    }, context: 'notification behavior profile');
    final platformSupport = _parseEnum(
      ReminderNotificationSupportLevel.values,
      json['platform_support'],
      context: 'platform support',
    );
    final pluginSupport = _parseEnum(
      ReminderNotificationSupportLevel.values,
      json['plugin_support'],
      context: 'plugin support',
    );
    final productEnabled = json['product_enabled'];
    final rawConstraints = json['constraints'];
    if (productEnabled is! bool || rawConstraints is! List) {
      throw const FormatException('invalid notification behavior profile');
    }
    final constraints = <ReminderNotificationBehaviorConstraint>{};
    for (final raw in rawConstraints) {
      final constraint = _parseEnum(
        ReminderNotificationBehaviorConstraint.values,
        raw,
        context: 'behavior constraint',
      );
      if (!constraints.add(constraint)) {
        throw const FormatException(
          'duplicate notification behavior constraint',
        );
      }
    }
    return ReminderNotificationBehaviorProfile(
      platformSupport: platformSupport,
      pluginSupport: pluginSupport,
      productEnabled: productEnabled,
      constraints: constraints,
    );
  }

  final ReminderNotificationSupportLevel platformSupport;
  final ReminderNotificationSupportLevel pluginSupport;
  final bool productEnabled;
  final Set<ReminderNotificationBehaviorConstraint> constraints;

  Map<String, Object?> toJson() => {
    'platform_support': platformSupport.name,
    'plugin_support': pluginSupport.name,
    'product_enabled': productEnabled,
    'constraints': [
      for (final constraint in ReminderNotificationBehaviorConstraint.values)
        if (constraints.contains(constraint)) constraint.name,
    ],
  };

  void validate() {
    if (productEnabled ==
        constraints.contains(
          ReminderNotificationBehaviorConstraint.productPathNotEnabled,
        )) {
      throw const FormatException(
        'product enablement conflicts with its behavior constraints',
      );
    }
  }
}

@immutable
class ReminderNotificationPluginPin {
  const ReminderNotificationPluginPin({
    required this.package,
    required this.version,
    required this.archiveSha256,
    required this.lockfileSha256,
  });

  factory ReminderNotificationPluginPin.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'package',
      'version',
      'archive_sha256',
      'lockfile_sha256',
    }, context: 'notification plugin pin');
    return ReminderNotificationPluginPin(
      package: _requiredString(json, 'package'),
      version: _requiredString(json, 'version'),
      archiveSha256: _requiredString(json, 'archive_sha256'),
      lockfileSha256: _requiredString(json, 'lockfile_sha256'),
    );
  }

  final String package;
  final String version;
  final String archiveSha256;
  final String lockfileSha256;

  Map<String, Object?> toJson() => {
    'package': package,
    'version': version,
    'archive_sha256': archiveSha256,
    'lockfile_sha256': lockfileSha256,
  };

  void validate() {
    if (package != 'flutter_local_notifications' ||
        version != '22.3.0' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(archiveSha256) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(lockfileSha256)) {
      throw const FormatException('notification plugin pin is incomplete');
    }
  }
}

@immutable
class ReminderNotificationCapabilityProfile {
  factory ReminderNotificationCapabilityProfile({
    required ReminderNotificationPlatform platform,
    required ReminderNotificationDeliveryMode deliveryMode,
    required Map<
      ReminderNotificationCapability,
      ReminderNotificationCapabilityEvidence
    >
    capabilities,
    required Map<
      ReminderNotificationBehavior,
      ReminderNotificationBehaviorProfile
    >
    behaviors,
  }) {
    final profile = ReminderNotificationCapabilityProfile._(
      platform: platform,
      deliveryMode: deliveryMode,
      capabilities: Map.unmodifiable(
        Map<
          ReminderNotificationCapability,
          ReminderNotificationCapabilityEvidence
        >.from(capabilities),
      ),
      behaviors: Map.unmodifiable(
        Map<
          ReminderNotificationBehavior,
          ReminderNotificationBehaviorProfile
        >.from(behaviors),
      ),
    );
    profile.validate();
    return profile;
  }

  const ReminderNotificationCapabilityProfile._({
    required this.platform,
    required this.deliveryMode,
    required this.capabilities,
    required this.behaviors,
  });

  factory ReminderNotificationCapabilityProfile.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      'platform',
      'delivery_mode',
      'capabilities',
      'behaviors',
    }, context: 'notification capability profile');
    final rawCapabilities = json['capabilities'];
    if (rawCapabilities is! Map) {
      throw const FormatException('capabilities must be an object');
    }
    final rawBehaviors = json['behaviors'];
    if (rawBehaviors is! Map) {
      throw const FormatException('behaviors must be an object');
    }
    _requireExactKeys(
      rawBehaviors,
      ReminderNotificationBehavior.values
          .map((behavior) => behavior.name)
          .toSet(),
      context: 'notification behavior profiles',
    );
    final behaviors =
        <ReminderNotificationBehavior, ReminderNotificationBehaviorProfile>{};
    for (final behavior in ReminderNotificationBehavior.values) {
      final raw = rawBehaviors[behavior.name];
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        throw FormatException('invalid behavior profile for ${behavior.name}');
      }
      behaviors[behavior] = ReminderNotificationBehaviorProfile.fromJson(
        Map<String, Object?>.from(raw),
      );
    }
    _requireExactKeys(
      rawCapabilities,
      ReminderNotificationCapability.values
          .map((capability) => capability.name)
          .toSet(),
      context: 'notification capability evidence',
    );
    final capabilities =
        <
          ReminderNotificationCapability,
          ReminderNotificationCapabilityEvidence
        >{};
    for (final capability in ReminderNotificationCapability.values) {
      final raw = rawCapabilities[capability.name];
      capabilities[capability] =
          ReminderNotificationCapabilityEvidence.values
              .where((value) => value.name == raw)
              .firstOrNull ??
          (throw FormatException(
            'invalid capability evidence for ${capability.name}',
          ));
    }
    final platform = ReminderNotificationPlatform.values
        .where((value) => value.name == json['platform'])
        .firstOrNull;
    final deliveryMode = ReminderNotificationDeliveryMode.values
        .where((value) => value.name == json['delivery_mode'])
        .firstOrNull;
    if (platform == null || deliveryMode == null) {
      throw const FormatException('invalid notification platform profile');
    }
    return ReminderNotificationCapabilityProfile(
      platform: platform,
      deliveryMode: deliveryMode,
      capabilities: Map.unmodifiable(capabilities),
      behaviors: Map.unmodifiable(behaviors),
    );
  }

  /// Compatibility-only profile for injected test or integration gateways.
  /// Production platform decisions use [ReminderNotificationCapabilityMatrix].
  factory ReminderNotificationCapabilityProfile.legacyGateway({
    required bool supportsScheduledDelivery,
    bool supportsPermissionInspection = false,
    bool supportsPendingInspection = false,
    bool supportsResponseHandling = false,
  }) => ReminderNotificationCapabilityProfile(
    platform: ReminderNotificationPlatform.unknown,
    deliveryMode: supportsScheduledDelivery
        ? ReminderNotificationDeliveryMode.scheduled
        : ReminderNotificationDeliveryMode.planOnly,
    capabilities: Map.unmodifiable({
      for (final capability in ReminderNotificationCapability.values)
        capability:
            (capability == ReminderNotificationCapability.scheduleAdapter ||
                    capability ==
                        ReminderNotificationCapability.permissionRequest ||
                    capability ==
                            ReminderNotificationCapability
                                .permissionInspection &&
                        supportsPermissionInspection ||
                    capability ==
                            ReminderNotificationCapability.pendingInspection &&
                        supportsPendingInspection ||
                    (capability == ReminderNotificationCapability.bodyTap ||
                            capability ==
                                ReminderNotificationCapability.coldStart) &&
                        supportsResponseHandling) &&
                supportsScheduledDelivery
            ? ReminderNotificationCapabilityEvidence.implementedUnverified
            : ReminderNotificationCapabilityEvidence.unavailable,
    }),
    behaviors: {
      for (final behavior in ReminderNotificationBehavior.values)
        behavior: ReminderNotificationBehaviorProfile(
          platformSupport: ReminderNotificationSupportLevel.unknown,
          pluginSupport: ReminderNotificationSupportLevel.unknown,
          productEnabled:
              (behavior == ReminderNotificationBehavior.recurringScheduling &&
                  supportsScheduledDelivery) ||
              (supportsResponseHandling &&
                  (behavior ==
                          ReminderNotificationBehavior.foregroundResponse ||
                      behavior ==
                          ReminderNotificationBehavior.coldStartResponse)),
          constraints: {
            ReminderNotificationBehaviorConstraint
                .legacyGatewaySupportUnqualified,
            if (!((behavior ==
                        ReminderNotificationBehavior.recurringScheduling &&
                    supportsScheduledDelivery) ||
                (supportsResponseHandling &&
                    (behavior ==
                            ReminderNotificationBehavior.foregroundResponse ||
                        behavior ==
                            ReminderNotificationBehavior.coldStartResponse))))
              ReminderNotificationBehaviorConstraint.productPathNotEnabled,
          },
        ),
    },
  );

  final ReminderNotificationPlatform platform;
  final ReminderNotificationDeliveryMode deliveryMode;
  final Map<
    ReminderNotificationCapability,
    ReminderNotificationCapabilityEvidence
  >
  capabilities;
  final Map<ReminderNotificationBehavior, ReminderNotificationBehaviorProfile>
  behaviors;

  ReminderNotificationBehaviorProfile behaviorFor(
    ReminderNotificationBehavior behavior,
  ) =>
      behaviors[behavior] ??
      (throw StateError('missing notification behavior ${behavior.name}'));

  ReminderNotificationCapabilityEvidence evidenceFor(
    ReminderNotificationCapability capability,
  ) =>
      capabilities[capability] ??
      ReminderNotificationCapabilityEvidence.unavailable;

  bool get supportsScheduledDelivery =>
      deliveryMode == ReminderNotificationDeliveryMode.scheduled &&
      evidenceFor(ReminderNotificationCapability.scheduleAdapter) !=
          ReminderNotificationCapabilityEvidence.unavailable &&
      behaviorFor(
        ReminderNotificationBehavior.recurringScheduling,
      ).productEnabled;

  bool get supportsPermissionRequest =>
      evidenceFor(ReminderNotificationCapability.permissionRequest) !=
      ReminderNotificationCapabilityEvidence.unavailable;

  bool get supportsPermissionInspection =>
      evidenceFor(ReminderNotificationCapability.permissionInspection) !=
      ReminderNotificationCapabilityEvidence.unavailable;

  bool get supportsResponseHandling =>
      evidenceFor(ReminderNotificationCapability.bodyTap) !=
          ReminderNotificationCapabilityEvidence.unavailable ||
      evidenceFor(ReminderNotificationCapability.coldStart) !=
          ReminderNotificationCapabilityEvidence.unavailable;

  Map<String, Object?> toJson() => {
    'platform': platform.name,
    'delivery_mode': deliveryMode.name,
    'capabilities': {
      for (final capability in ReminderNotificationCapability.values)
        capability.name: evidenceFor(capability).name,
    },
    'behaviors': {
      for (final behavior in ReminderNotificationBehavior.values)
        behavior.name: behaviorFor(behavior).toJson(),
    },
  };

  String get contentSha256 =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  void validate() {
    if (capabilities.length != ReminderNotificationCapability.values.length ||
        !capabilities.keys.toSet().containsAll(
          ReminderNotificationCapability.values,
        )) {
      throw const FormatException('capability profile must be exhaustive');
    }
    if (behaviors.length != ReminderNotificationBehavior.values.length ||
        !behaviors.keys.toSet().containsAll(
          ReminderNotificationBehavior.values,
        )) {
      throw const FormatException('behavior profile must be exhaustive');
    }
    for (final behavior in behaviors.values) {
      behavior.validate();
    }
    if (deliveryMode == ReminderNotificationDeliveryMode.scheduled &&
        evidenceFor(ReminderNotificationCapability.scheduleAdapter) ==
            ReminderNotificationCapabilityEvidence.unavailable) {
      throw const FormatException(
        'scheduled delivery requires an implemented adapter',
      );
    }
    if (deliveryMode == ReminderNotificationDeliveryMode.scheduled &&
        !behaviorFor(
          ReminderNotificationBehavior.recurringScheduling,
        ).productEnabled) {
      throw const FormatException(
        'scheduled delivery requires a product-enabled recurring path',
      );
    }
    if (deliveryMode == ReminderNotificationDeliveryMode.planOnly &&
            capabilities.values.any(
              (value) =>
                  value != ReminderNotificationCapabilityEvidence.unavailable,
            ) ||
        deliveryMode == ReminderNotificationDeliveryMode.planOnly &&
            behaviors.values.any((behavior) => behavior.productEnabled)) {
      throw const FormatException(
        'plan-only profiles cannot expose native notification capabilities',
      );
    }
  }
}

/// Exhaustive, versioned product truth for notification behavior.
///
/// This is a capability and evidence contract, not proof that an operating
/// system displayed or delivered a notification.
final class ReminderNotificationCapabilityMatrix {
  ReminderNotificationCapabilityMatrix._(
    Iterable<ReminderNotificationCapabilityProfile> profiles,
    this.pluginPin,
  ) : _profiles = List.unmodifiable(
        profiles.toList(growable: false)
          ..sort((a, b) => a.platform.index.compareTo(b.platform.index)),
      ) {
    _validate();
  }

  factory ReminderNotificationCapabilityMatrix.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactKeys(json, const {
      r'$schema',
      'schema_version',
      'boundary',
      'pinned_plugin',
      'profiles',
    }, context: 'notification capability matrix');
    if (json[r'$schema'] != schema || json['schema_version'] != schemaVersion) {
      throw const FormatException('unsupported notification matrix schema');
    }
    if (json['boundary'] != boundary) {
      throw const FormatException('notification matrix boundary changed');
    }
    final rawPluginPin = json['pinned_plugin'];
    if (rawPluginPin is! Map ||
        rawPluginPin.keys.any((key) => key is! String)) {
      throw const FormatException('pinned_plugin must be an object');
    }
    final pluginPin = ReminderNotificationPluginPin.fromJson(
      Map<String, Object?>.from(rawPluginPin),
    );
    final rawProfiles = json['profiles'];
    if (rawProfiles is! List) {
      throw const FormatException('profiles must be a list');
    }
    final profiles = <ReminderNotificationCapabilityProfile>[];
    for (final raw in rawProfiles) {
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        throw const FormatException('profile entry must be a string-key map');
      }
      profiles.add(
        ReminderNotificationCapabilityProfile.fromJson(
          Map<String, Object?>.from(raw),
        ),
      );
    }
    return ReminderNotificationCapabilityMatrix._(profiles, pluginPin);
  }

  static const String schema =
      'parkinsum.reminder-notification-capability-matrix/2';
  static const int schemaVersion = 2;
  static const String boundary =
      'Platform support, pinned-plugin support, product enablement and runtime '
      'evidence are separate. None proves visible delivery, lock-screen display, '
      'activation, background execution, or timing.';

  static const ReminderNotificationPluginPin currentPluginPin =
      ReminderNotificationPluginPin(
        package: 'flutter_local_notifications',
        version: '22.3.0',
        archiveSha256:
            '1447ba911c60f2ba3f25dae1af151ec187162566b0f57e37771bf0b400f013ad',
        lockfileSha256:
            '270beb8b2ea01f4eb8d02827f06228577c129125c9fb7bb151afc28bc502e17b',
      );

  static final ReminderNotificationCapabilityMatrix current =
      ReminderNotificationCapabilityMatrix._([
        _scheduledProfile(ReminderNotificationPlatform.android),
        _scheduledProfile(ReminderNotificationPlatform.iOS),
        _scheduledProfile(ReminderNotificationPlatform.macOS),
        _planOnlyProfile(ReminderNotificationPlatform.web),
        _planOnlyProfile(ReminderNotificationPlatform.windows),
        _planOnlyProfile(ReminderNotificationPlatform.linux),
        _planOnlyProfile(ReminderNotificationPlatform.unknown),
      ], currentPluginPin);

  final List<ReminderNotificationCapabilityProfile> _profiles;
  final ReminderNotificationPluginPin pluginPin;

  List<ReminderNotificationCapabilityProfile> get profiles =>
      List.unmodifiable(_profiles);

  ReminderNotificationCapabilityProfile profileFor(
    ReminderNotificationPlatform platform,
  ) => _profiles.singleWhere(
    (profile) => profile.platform == platform,
    orElse: () => _profiles.singleWhere(
      (profile) => profile.platform == ReminderNotificationPlatform.unknown,
    ),
  );

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'boundary': boundary,
    'pinned_plugin': pluginPin.toJson(),
    'profiles': [for (final profile in _profiles) profile.toJson()],
  };

  String get manifestSha256 =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  void _validate() {
    pluginPin.validate();
    if (jsonEncode(pluginPin.toJson()) !=
        jsonEncode(currentPluginPin.toJson())) {
      throw const FormatException(
        'notification plugin pin differs from the reviewed lock identity',
      );
    }
    final platforms = <ReminderNotificationPlatform>{};
    for (final profile in _profiles) {
      profile.validate();
      for (final behavior in profile.behaviors.values) {
        if (behavior.productEnabled &&
            (behavior.platformSupport ==
                    ReminderNotificationSupportLevel.unsupported ||
                behavior.platformSupport ==
                    ReminderNotificationSupportLevel.unknown ||
                behavior.pluginSupport ==
                    ReminderNotificationSupportLevel.unsupported ||
                behavior.pluginSupport ==
                    ReminderNotificationSupportLevel.unknown)) {
          throw const FormatException(
            'product behavior cannot be enabled without bounded platform and plugin support',
          );
        }
      }
      if (!platforms.add(profile.platform)) {
        throw FormatException(
          'duplicate notification profile: ${profile.platform.name}',
        );
      }
    }
    if (platforms.length != ReminderNotificationPlatform.values.length ||
        !platforms.containsAll(ReminderNotificationPlatform.values)) {
      throw const FormatException(
        'notification matrix must cover every platform exactly once',
      );
    }
    final unknown = profileFor(ReminderNotificationPlatform.unknown);
    if (unknown.deliveryMode != ReminderNotificationDeliveryMode.planOnly ||
        unknown.supportsScheduledDelivery ||
        unknown.behaviors.values.any((behavior) => behavior.productEnabled)) {
      throw const FormatException('unknown platform must fail closed');
    }
  }

  static ReminderNotificationCapabilityProfile _scheduledProfile(
    ReminderNotificationPlatform platform,
  ) => ReminderNotificationCapabilityProfile(
    platform: platform,
    deliveryMode: ReminderNotificationDeliveryMode.scheduled,
    capabilities: Map.unmodifiable({
      ReminderNotificationCapability.scheduleAdapter:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
      ReminderNotificationCapability.permissionRequest:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
      ReminderNotificationCapability.permissionInspection:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
      ReminderNotificationCapability.pendingInspection:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
      ReminderNotificationCapability.bodyTap:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
      ReminderNotificationCapability.coldStart:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
      ReminderNotificationCapability.backgroundAction:
          ReminderNotificationCapabilityEvidence.unavailable,
      ReminderNotificationCapability.visibleDelivery:
          ReminderNotificationCapabilityEvidence.implementedUnverified,
    }),
    behaviors: _behaviorsFor(platform),
  );

  static ReminderNotificationCapabilityProfile _planOnlyProfile(
    ReminderNotificationPlatform platform,
  ) => ReminderNotificationCapabilityProfile(
    platform: platform,
    deliveryMode: ReminderNotificationDeliveryMode.planOnly,
    capabilities: Map.unmodifiable({
      for (final capability in ReminderNotificationCapability.values)
        capability: ReminderNotificationCapabilityEvidence.unavailable,
    }),
    behaviors: _behaviorsFor(platform),
  );

  static Map<ReminderNotificationBehavior, ReminderNotificationBehaviorProfile>
  _behaviorsFor(ReminderNotificationPlatform platform) {
    final isMobile =
        platform == ReminderNotificationPlatform.android ||
        platform == ReminderNotificationPlatform.iOS ||
        platform == ReminderNotificationPlatform.macOS;
    final unsupportedScheduler =
        platform == ReminderNotificationPlatform.web ||
        platform == ReminderNotificationPlatform.linux;
    final unknown = platform == ReminderNotificationPlatform.unknown;

    ReminderNotificationBehaviorProfile profile({
      required ReminderNotificationSupportLevel platformSupport,
      required ReminderNotificationSupportLevel pluginSupport,
      bool productEnabled = false,
      Set<ReminderNotificationBehaviorConstraint> constraints = const {},
    }) => ReminderNotificationBehaviorProfile(
      platformSupport: platformSupport,
      pluginSupport: pluginSupport,
      productEnabled: productEnabled,
      constraints: {
        ...constraints,
        if (!productEnabled)
          ReminderNotificationBehaviorConstraint.productPathNotEnabled,
      },
    );

    return {
      ReminderNotificationBehavior.oneTimeScheduling: profile(
        platformSupport: unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : unknown
            ? ReminderNotificationSupportLevel.unknown
            : ReminderNotificationSupportLevel.supported,
        pluginSupport: unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : unknown
            ? ReminderNotificationSupportLevel.unknown
            : ReminderNotificationSupportLevel.supported,
        constraints: {
          if (platform == ReminderNotificationPlatform.web)
            ReminderNotificationBehaviorConstraint.browserSchedulerUnavailable,
          if (platform == ReminderNotificationPlatform.linux)
            ReminderNotificationBehaviorConstraint.linuxSchedulerUnavailable,
        },
      ),
      ReminderNotificationBehavior.recurringScheduling: profile(
        platformSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : platform == ReminderNotificationPlatform.windows
            ? ReminderNotificationSupportLevel.conditional
            : unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : ReminderNotificationSupportLevel.unknown,
        pluginSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : platform == ReminderNotificationPlatform.windows ||
                  unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : ReminderNotificationSupportLevel.unknown,
        productEnabled: isMobile,
        constraints: {
          if (platform == ReminderNotificationPlatform.android)
            ReminderNotificationBehaviorConstraint
                .androidOemMayDeferBackgroundDelivery,
          if (platform == ReminderNotificationPlatform.iOS)
            ReminderNotificationBehaviorConstraint
                .iosPendingNotificationsLimitedTo64,
          if (platform == ReminderNotificationPlatform.windows)
            ReminderNotificationBehaviorConstraint
                .windowsRepeatingNotificationsUnavailable,
          if (platform == ReminderNotificationPlatform.web)
            ReminderNotificationBehaviorConstraint.browserSchedulerUnavailable,
          if (platform == ReminderNotificationPlatform.linux)
            ReminderNotificationBehaviorConstraint.linuxSchedulerUnavailable,
        },
      ),
      ReminderNotificationBehavior.rebootRestoration: profile(
        platformSupport: platform == ReminderNotificationPlatform.android
            ? ReminderNotificationSupportLevel.conditional
            : unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : ReminderNotificationSupportLevel.unknown,
        pluginSupport: platform == ReminderNotificationPlatform.android
            ? ReminderNotificationSupportLevel.conditional
            : unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : ReminderNotificationSupportLevel.unknown,
        productEnabled: platform == ReminderNotificationPlatform.android,
        constraints: {
          if (platform == ReminderNotificationPlatform.android) ...{
            ReminderNotificationBehaviorConstraint
                .androidBootReceiverAndPermissionRequired,
            ReminderNotificationBehaviorConstraint
                .rebootBehaviorNotDeviceVerified,
            ReminderNotificationBehaviorConstraint
                .androidOemMayDeferBackgroundDelivery,
          },
        },
      ),
      ReminderNotificationBehavior.timezoneAdjustment: profile(
        platformSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : ReminderNotificationSupportLevel.unknown,
        pluginSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : unsupportedScheduler
            ? ReminderNotificationSupportLevel.unsupported
            : ReminderNotificationSupportLevel.unknown,
        productEnabled: isMobile,
        constraints: {
          if (isMobile) ...{
            ReminderNotificationBehaviorConstraint
                .timezoneRefreshedOnReconciliation,
            ReminderNotificationBehaviorConstraint
                .timezoneBehaviorNotDeviceVerified,
          },
          if (platform == ReminderNotificationPlatform.iOS)
            ReminderNotificationBehaviorConstraint
                .iosPendingNotificationsLimitedTo64,
          if (platform == ReminderNotificationPlatform.web)
            ReminderNotificationBehaviorConstraint.browserSchedulerUnavailable,
          if (platform == ReminderNotificationPlatform.linux)
            ReminderNotificationBehaviorConstraint.linuxSchedulerUnavailable,
        },
      ),
      ReminderNotificationBehavior.foregroundResponse: profile(
        platformSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : platform == ReminderNotificationPlatform.linux ||
                  platform == ReminderNotificationPlatform.web
            ? ReminderNotificationSupportLevel.conditional
            : unknown
            ? ReminderNotificationSupportLevel.unknown
            : ReminderNotificationSupportLevel.supported,
        pluginSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : platform == ReminderNotificationPlatform.linux ||
                  platform == ReminderNotificationPlatform.web
            ? ReminderNotificationSupportLevel.conditional
            : unknown
            ? ReminderNotificationSupportLevel.unknown
            : ReminderNotificationSupportLevel.supported,
        productEnabled: isMobile,
        constraints: {
          if (platform == ReminderNotificationPlatform.linux)
            ReminderNotificationBehaviorConstraint
                .foregroundCallbackRequiresRunningApp,
        },
      ),
      ReminderNotificationBehavior.coldStartResponse: profile(
        platformSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : platform == ReminderNotificationPlatform.linux
            ? ReminderNotificationSupportLevel.unsupported
            : unknown || platform == ReminderNotificationPlatform.web
            ? ReminderNotificationSupportLevel.unknown
            : ReminderNotificationSupportLevel.supported,
        pluginSupport: isMobile
            ? ReminderNotificationSupportLevel.supported
            : platform == ReminderNotificationPlatform.linux
            ? ReminderNotificationSupportLevel.unsupported
            : unknown || platform == ReminderNotificationPlatform.web
            ? ReminderNotificationSupportLevel.unknown
            : ReminderNotificationSupportLevel.supported,
        productEnabled: isMobile,
        constraints: {
          if (platform == ReminderNotificationPlatform.linux)
            ReminderNotificationBehaviorConstraint
                .foregroundCallbackRequiresRunningApp,
        },
      ),
      ReminderNotificationBehavior.backgroundAction: profile(
        platformSupport:
            isMobile ||
                platform == ReminderNotificationPlatform.windows ||
                platform == ReminderNotificationPlatform.linux ||
                platform == ReminderNotificationPlatform.web
            ? ReminderNotificationSupportLevel.conditional
            : ReminderNotificationSupportLevel.unknown,
        pluginSupport:
            isMobile ||
                platform == ReminderNotificationPlatform.windows ||
                platform == ReminderNotificationPlatform.linux ||
                platform == ReminderNotificationPlatform.web
            ? ReminderNotificationSupportLevel.conditional
            : ReminderNotificationSupportLevel.unknown,
        constraints: {
          ReminderNotificationBehaviorConstraint
              .backgroundActionHandlerNotConfigured,
          if (platform == ReminderNotificationPlatform.linux)
            ReminderNotificationBehaviorConstraint
                .foregroundCallbackRequiresRunningApp,
        },
      ),
    };
  }
}

abstract interface class ReminderNotificationCapabilityProvider {
  ReminderNotificationCapabilityMatrix get notificationCapabilityMatrix;
  ReminderNotificationCapabilityProfile get notificationCapabilityProfile;
  String get notificationCapabilityManifestSha256;
}

enum ReminderNotificationCapabilityBindingKind { matrix, legacyGateway }

@immutable
class ReminderNotificationCapabilityBinding {
  factory ReminderNotificationCapabilityBinding.fromProvider({
    required ReminderNotificationCapabilityMatrix matrix,
    required ReminderNotificationCapabilityProfile profile,
    required String manifestSha256,
  }) {
    profile.validate();
    final matrixProfile = matrix.profileFor(profile.platform);
    if (jsonEncode(profile.toJson()) != jsonEncode(matrixProfile.toJson()) ||
        manifestSha256 != matrix.manifestSha256 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(manifestSha256)) {
      throw const FormatException(
        'notification capability profile is not bound to its matrix',
      );
    }
    return ReminderNotificationCapabilityBinding._(
      profile: matrixProfile,
      contractSha256: manifestSha256,
      kind: ReminderNotificationCapabilityBindingKind.matrix,
    );
  }

  factory ReminderNotificationCapabilityBinding.forMatrix({
    required ReminderNotificationCapabilityMatrix matrix,
    required ReminderNotificationPlatform platform,
  }) => ReminderNotificationCapabilityBinding.fromProvider(
    matrix: matrix,
    profile: matrix.profileFor(platform),
    manifestSha256: matrix.manifestSha256,
  );

  factory ReminderNotificationCapabilityBinding.legacyGateway({
    required bool supportsScheduledDelivery,
    bool supportsPermissionInspection = false,
    bool supportsPendingInspection = false,
    bool supportsResponseHandling = false,
  }) {
    final profile = ReminderNotificationCapabilityProfile.legacyGateway(
      supportsScheduledDelivery: supportsScheduledDelivery,
      supportsPermissionInspection: supportsPermissionInspection,
      supportsPendingInspection: supportsPendingInspection,
      supportsResponseHandling: supportsResponseHandling,
    );
    return ReminderNotificationCapabilityBinding._(
      profile: profile,
      contractSha256: sha256
          .convert(
            utf8.encode(
              'parkinsum.reminder-notification-legacy-binding-v1\n'
              '${profile.contentSha256}',
            ),
          )
          .toString(),
      kind: ReminderNotificationCapabilityBindingKind.legacyGateway,
    );
  }

  const ReminderNotificationCapabilityBinding._({
    required this.profile,
    required this.contractSha256,
    required this.kind,
  });

  final ReminderNotificationCapabilityProfile profile;
  final String contractSha256;
  final ReminderNotificationCapabilityBindingKind kind;
}

enum ReminderLocalPlanReadiness { noneConfigured, savedLocally }

enum ReminderScheduleRequestReadiness {
  notRequested,
  applied,
  rolledBack,
  superseded,
  unsupported,
  failed,
  recoveryRequired,
}

enum ReminderPermissionRequestReadiness {
  notRequested,
  returnedAllowed,
  returnedNotAllowed,
  adapterUnavailable,
  failed,
}

enum ReminderPermissionInspectionReadiness {
  notInspected,
  enabled,
  disabled,
  unavailable,
  failed,
}

enum ReminderRegistryReadiness {
  notInspected,
  matched,
  drift,
  uninspectable,
  unsupported,
}

enum ReminderVisibleDeliveryReadiness { unverified, artifactVerified }

@immutable
class ReminderDeliveryReadiness {
  factory ReminderDeliveryReadiness({
    required ReminderNotificationCapabilityBinding capabilityBinding,
    required ReminderLocalPlanReadiness localPlan,
    required ReminderScheduleRequestReadiness scheduleRequest,
    required ReminderPermissionRequestReadiness permissionRequest,
    required ReminderPermissionInspectionReadiness permissionInspection,
    required ReminderRegistryReadiness registry,
    required ReminderVisibleDeliveryReadiness visibleDelivery,
  }) {
    final readiness = ReminderDeliveryReadiness._(
      capabilityBinding: capabilityBinding,
      profile: capabilityBinding.profile,
      manifestSha256: capabilityBinding.contractSha256,
      localPlan: localPlan,
      scheduleRequest: scheduleRequest,
      permissionRequest: permissionRequest,
      permissionInspection: permissionInspection,
      registry: registry,
      visibleDelivery: visibleDelivery,
    );
    readiness.validate();
    return readiness;
  }

  const ReminderDeliveryReadiness._({
    required this.capabilityBinding,
    required this.profile,
    required this.manifestSha256,
    required this.localPlan,
    required this.scheduleRequest,
    required this.permissionRequest,
    required this.permissionInspection,
    required this.registry,
    required this.visibleDelivery,
  });

  final ReminderNotificationCapabilityBinding capabilityBinding;
  final ReminderNotificationCapabilityProfile profile;
  final String manifestSha256;
  String get capabilityContractSha256 => manifestSha256;
  final ReminderLocalPlanReadiness localPlan;
  final ReminderScheduleRequestReadiness scheduleRequest;
  final ReminderPermissionRequestReadiness permissionRequest;
  final ReminderPermissionInspectionReadiness permissionInspection;
  final ReminderRegistryReadiness registry;
  final ReminderVisibleDeliveryReadiness visibleDelivery;

  static const String schema = 'parkinsum.reminder-delivery-readiness/1';
  static const int schemaVersion = 1;

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'capability_contract_sha256': capabilityContractSha256,
    'capability_matrix_manifest_sha256':
        capabilityBinding.kind ==
            ReminderNotificationCapabilityBindingKind.matrix
        ? capabilityContractSha256
        : null,
    'capability_binding_kind': capabilityBinding.kind.name,
    'platform': profile.platform.name,
    'delivery_mode': profile.deliveryMode.name,
    'local_plan': localPlan.name,
    'schedule_request': scheduleRequest.name,
    'permission_request': permissionRequest.name,
    'permission_inspection': permissionInspection.name,
    'permission_inspection_capability_evidence': profile
        .evidenceFor(ReminderNotificationCapability.permissionInspection)
        .name,
    'plugin_registry': registry.name,
    'visible_delivery': visibleDelivery.name,
    'boundary': ReminderNotificationCapabilityMatrix.boundary,
  };

  void validate() {
    profile.validate();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(manifestSha256)) {
      throw const FormatException(
        'capability contract identity must be a lowercase SHA-256',
      );
    }
    if (visibleDelivery == ReminderVisibleDeliveryReadiness.artifactVerified) {
      throw const FormatException(
        'readiness schema v1 has no artifact receipt and cannot verify delivery',
      );
    }
    if (profile.deliveryMode == ReminderNotificationDeliveryMode.planOnly) {
      if (scheduleRequest != ReminderScheduleRequestReadiness.unsupported ||
          permissionRequest !=
              ReminderPermissionRequestReadiness.adapterUnavailable ||
          permissionInspection !=
              ReminderPermissionInspectionReadiness.unavailable ||
          registry != ReminderRegistryReadiness.unsupported) {
        throw const FormatException(
          'plan-only readiness cannot expose a native notification result',
        );
      }
      return;
    }
    if (!profile.supportsPermissionRequest &&
        permissionRequest !=
            ReminderPermissionRequestReadiness.adapterUnavailable) {
      throw const FormatException(
        'permission request state conflicts with capability profile',
      );
    }
    if (!profile.supportsPermissionInspection &&
        permissionInspection !=
            ReminderPermissionInspectionReadiness.unavailable) {
      throw const FormatException(
        'permission inspection state conflicts with capability profile',
      );
    }
    if (scheduleRequest == ReminderScheduleRequestReadiness.unsupported) {
      throw const FormatException(
        'scheduled readiness cannot report the adapter unsupported',
      );
    }
    final supportsPendingInspection =
        profile.evidenceFor(ReminderNotificationCapability.pendingInspection) !=
        ReminderNotificationCapabilityEvidence.unavailable;
    if (supportsPendingInspection ==
        (registry == ReminderRegistryReadiness.unsupported)) {
      throw const FormatException(
        'plugin registry state conflicts with capability profile',
      );
    }
  }
}

void _requireExactKeys(
  Map<dynamic, dynamic> value,
  Set<String> expected, {
  required String context,
}) {
  final keys = value.keys;
  if (keys.any((key) => key is! String) ||
      keys.length != expected.length ||
      !expected.containsAll(keys.cast<String>())) {
    throw FormatException('$context has missing or unknown fields');
  }
}

T _parseEnum<T extends Enum>(
  Iterable<T> values,
  Object? raw, {
  required String context,
}) =>
    values.where((value) => value.name == raw).firstOrNull ??
    (throw FormatException('invalid $context'));

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}
