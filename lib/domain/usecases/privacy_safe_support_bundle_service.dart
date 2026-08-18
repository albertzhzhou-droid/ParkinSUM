library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const String privacySafeSupportBundleSchema =
    'parkinsum.privacy-safe-support-bundle/1';
const int privacySafeSupportBundleSchemaVersion = 1;
const int privacySafeSupportBundleMaxBytes = 64 * 1024;
const int privacySafeSupportBundleMaxNodes = 1024;
const int privacySafeSupportBundleMaxStringBytes = 512;
const Duration privacySafeSupportBundleGenerationBudget = Duration(
  milliseconds: 250,
);

enum PrivacySafeSupportSection { build, platform, diagnostics, governance }

enum PrivacySafeSupportCheckStatus { pass, review, unavailable }

/// A deliberately narrow build identity. No project ID, branch name, path,
/// endpoint, account identifier, or installer-specific identifier is accepted.
final class PrivacySafeSupportBuildSnapshot {
  const PrivacySafeSupportBuildSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.buildCommitSha256,
    required this.backendMode,
    required this.environment,
    required this.algorithmConfigurationSha256,
    required this.algorithmSourceBundleSha256,
  });

  final String appVersion;
  final String buildNumber;
  final String buildCommitSha256;
  final String backendMode;
  final String environment;
  final String algorithmConfigurationSha256;
  final String algorithmSourceBundleSha256;

  Map<String, Object?> toJson() => {
    'app_id': 'parkinsum_companion',
    'app_version': appVersion,
    'build_number': buildNumber,
    'build_commit_sha256': buildCommitSha256,
    'backend_mode': backendMode,
    'environment': environment,
    'algorithm_configuration_sha256': algorithmConfigurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
  };
}

/// Platform facts are capability statements, not a device fingerprint.
final class PrivacySafeSupportPlatformSnapshot {
  const PrivacySafeSupportPlatformSnapshot({
    required this.platformFamily,
    required this.scheduledNotificationsSupported,
    required this.protectedStoreCapability,
    required this.protectedStoreEncryptedAtRest,
    required this.protectedStoreHardwareBackingVerified,
    required this.firebaseBackendEnabled,
    required this.appCheckEnabled,
    required this.appCheckDebugEnabled,
  });

  final String platformFamily;
  final bool scheduledNotificationsSupported;
  final String protectedStoreCapability;
  final bool protectedStoreEncryptedAtRest;
  final bool protectedStoreHardwareBackingVerified;
  final bool firebaseBackendEnabled;
  final bool appCheckEnabled;
  final bool appCheckDebugEnabled;

  Map<String, Object> toJson() => {
    'platform_family': platformFamily,
    'scheduled_notifications_supported': scheduledNotificationsSupported,
    'protected_store_capability': protectedStoreCapability,
    'protected_store_encrypted_at_rest': protectedStoreEncryptedAtRest,
    'protected_store_hardware_backing_verified':
        protectedStoreHardwareBackingVerified,
    'firebase_backend_enabled': firebaseBackendEnabled,
    'app_check_enabled': appCheckEnabled,
    'app_check_debug_enabled': appCheckDebugEnabled,
  };
}

/// Stable, bounded diagnostic result. There is intentionally no free-form
/// error, exception, stack, path, URL, or message field.
final class PrivacySafeSupportDiagnosticCheck {
  const PrivacySafeSupportDiagnosticCheck({
    required this.checkId,
    required this.status,
    required this.observedCount,
    required this.expectedCount,
    required this.findingCodes,
  });

  final String checkId;
  final PrivacySafeSupportCheckStatus status;
  final int? observedCount;
  final int? expectedCount;
  final List<String> findingCodes;

  Map<String, Object?> toJson() => {
    'check_id': checkId,
    'status': status.name,
    'observed_count': observedCount,
    'expected_count': expectedCount,
    'finding_codes': findingCodes,
  };
}

final class PrivacySafeSupportGovernanceSnapshot {
  const PrivacySafeSupportGovernanceSnapshot({
    required this.safeCopyTemplateCount,
    required this.localizationSurfaceCount,
    required this.replayScenarioCount,
    required this.foodCatalogCount,
    required this.medicationCatalogCount,
    required this.sourceDocumentCount,
    required this.nonLiveSourceDocumentCount,
    required this.placeholderSourceCodeCount,
    required this.ruleCount,
    required this.modelAssumptionCount,
  });

  final int? safeCopyTemplateCount;
  final int? localizationSurfaceCount;
  final int? replayScenarioCount;
  final int? foodCatalogCount;
  final int? medicationCatalogCount;
  final int? sourceDocumentCount;
  final int? nonLiveSourceDocumentCount;
  final int? placeholderSourceCodeCount;
  final int? ruleCount;
  final int? modelAssumptionCount;

  Map<String, Object?> toJson() => {
    'safe_copy_template_count': safeCopyTemplateCount,
    'localization_surface_count': localizationSurfaceCount,
    'replay_scenario_count': replayScenarioCount,
    'food_catalog_count': foodCatalogCount,
    'medication_catalog_count': medicationCatalogCount,
    'source_document_count': sourceDocumentCount,
    'non_live_source_document_count': nonLiveSourceDocumentCount,
    'placeholder_source_code_count': placeholderSourceCodeCount,
    'rule_count': ruleCount,
    'model_assumption_count': modelAssumptionCount,
  };
}

final class PrivacySafeSupportSnapshot {
  PrivacySafeSupportSnapshot({
    required this.build,
    required this.platform,
    required List<PrivacySafeSupportDiagnosticCheck> diagnostics,
    required this.governance,
  }) : diagnostics = List.unmodifiable(diagnostics);

  final PrivacySafeSupportBuildSnapshot build;
  final PrivacySafeSupportPlatformSnapshot platform;
  final List<PrivacySafeSupportDiagnosticCheck> diagnostics;
  final PrivacySafeSupportGovernanceSnapshot governance;

  Map<String, Object> toJson() => {
    'build': build.toJson(),
    'platform': platform.toJson(),
    'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
    'governance': governance.toJson(),
  };

  String get revisionSha256 => _sha256OfCanonicalJson(toJson());
}

final class PrivacySafeSupportBundleOptions {
  PrivacySafeSupportBundleOptions({
    Set<PrivacySafeSupportSection> sections = const {
      PrivacySafeSupportSection.build,
      PrivacySafeSupportSection.platform,
      PrivacySafeSupportSection.diagnostics,
      PrivacySafeSupportSection.governance,
    },
  }) : sections = Set.unmodifiable(sections);

  final Set<PrivacySafeSupportSection> sections;
}

final class PrivacySafeSupportBundleArtifact {
  const PrivacySafeSupportBundleArtifact({
    required this.prettyJson,
    required this.artifactSha256,
    required this.sourceRevisionSha256,
    required this.generatedAtUtc,
    required this.sections,
  });

  final String prettyJson;
  final String artifactSha256;
  final String sourceRevisionSha256;
  final DateTime generatedAtUtc;
  final List<PrivacySafeSupportSection> sections;

  int get byteLength => utf8.encode(prettyJson).length;

  String get fileName {
    final date = generatedAtUtc.toIso8601String().substring(0, 10);
    return 'parkinsum-support-$date-${artifactSha256.substring(0, 12)}'
        '.support.json';
  }
}

/// Creates a user-reviewed, local-only support artifact from a closed schema.
///
/// This is not a log exporter. Its inputs cannot represent health records,
/// identities, secrets, endpoints, paths, or free-form exception strings.
final class PrivacySafeSupportBundleService {
  const PrivacySafeSupportBundleService();

  PrivacySafeSupportBundleArtifact create({
    required PrivacySafeSupportSnapshot snapshot,
    required PrivacySafeSupportBundleOptions options,
    required DateTime generatedAt,
  }) {
    final stopwatch = Stopwatch()..start();
    if (options.sections.isEmpty) {
      throw const FormatException('support_sections_empty');
    }
    _validateSnapshot(snapshot);

    final orderedSections = options.sections.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    final content = <String, Object>{
      for (final section in orderedSections)
        section.name: switch (section) {
          PrivacySafeSupportSection.build => snapshot.build.toJson(),
          PrivacySafeSupportSection.platform => snapshot.platform.toJson(),
          PrivacySafeSupportSection.diagnostics =>
            snapshot.diagnostics
                .map((item) => item.toJson())
                .toList(growable: false),
          PrivacySafeSupportSection.governance => snapshot.governance.toJson(),
        },
    };
    final contentSha256 = _sha256OfCanonicalJson(content);
    final envelope = <String, Object>{
      'schema': privacySafeSupportBundleSchema,
      'schema_version': privacySafeSupportBundleSchemaVersion,
      'generated_at_utc': generatedAt.toUtc().toIso8601String(),
      'selected_sections': orderedSections.map((item) => item.name).toList(),
      'source_revision_sha256': snapshot.revisionSha256,
      'content_sha256': contentSha256,
      'content': content,
    };

    _validateEnvelopeShape(envelope, orderedSections);
    _validateBudgetsAndPrivacy(envelope, stopwatch: stopwatch);
    final canonical = _canonicalize(envelope) as Map<String, Object?>;
    final prettyJson = const JsonEncoder.withIndent('  ').convert(canonical);
    final bytes = utf8.encode(prettyJson);
    if (bytes.length > privacySafeSupportBundleMaxBytes) {
      throw const FormatException('support_byte_budget_exceeded');
    }
    if (stopwatch.elapsed > privacySafeSupportBundleGenerationBudget) {
      throw const FormatException('support_time_budget_exceeded');
    }
    return PrivacySafeSupportBundleArtifact(
      prettyJson: prettyJson,
      artifactSha256: sha256.convert(bytes).toString(),
      sourceRevisionSha256: snapshot.revisionSha256,
      generatedAtUtc: generatedAt.toUtc(),
      sections: List.unmodifiable(orderedSections),
    );
  }

  void _validateSnapshot(PrivacySafeSupportSnapshot snapshot) {
    final build = snapshot.build;
    _requireMatch(build.appVersion, _versionPattern, 'support_app_version');
    _requireMatch(build.buildNumber, _buildNumberPattern, 'support_build');
    _requireShaOrUnavailable(build.buildCommitSha256, 'support_build_commit');
    if (!const {'local', 'firebase'}.contains(build.backendMode)) {
      throw const FormatException('support_backend_mode_invalid');
    }
    if (!const {'dev', 'stage', 'prod'}.contains(build.environment)) {
      throw const FormatException('support_environment_invalid');
    }
    _requireSha(
      build.algorithmConfigurationSha256,
      'support_algorithm_configuration',
    );
    _requireSha(
      build.algorithmSourceBundleSha256,
      'support_algorithm_source_bundle',
    );

    final platform = snapshot.platform;
    if (!const {
      'web',
      'android',
      'ios',
      'macos',
      'windows',
      'linux',
      'fuchsia',
    }.contains(platform.platformFamily)) {
      throw const FormatException('support_platform_invalid');
    }
    _requireMatch(
      platform.protectedStoreCapability,
      _identifierPattern,
      'support_capability',
    );

    final seenChecks = <String>{};
    for (final check in snapshot.diagnostics) {
      _requireMatch(check.checkId, _identifierPattern, 'support_check_id');
      if (!seenChecks.add(check.checkId)) {
        throw const FormatException('support_duplicate_check');
      }
      _requireOptionalCount(check.observedCount);
      _requireOptionalCount(check.expectedCount);
      final seenCodes = <String>{};
      for (final code in check.findingCodes) {
        _requireMatch(code, _identifierPattern, 'support_finding_code');
        if (!seenCodes.add(code)) {
          throw const FormatException('support_duplicate_finding');
        }
      }
      if (check.status == PrivacySafeSupportCheckStatus.pass &&
          check.findingCodes.isNotEmpty) {
        throw const FormatException('support_pass_with_finding');
      }
      if (check.status != PrivacySafeSupportCheckStatus.pass &&
          check.findingCodes.isEmpty) {
        throw const FormatException('support_status_without_finding');
      }
      if (check.status == PrivacySafeSupportCheckStatus.unavailable &&
          (check.observedCount != null || check.expectedCount != null)) {
        throw const FormatException('support_unavailable_with_count');
      }
      if (check.status != PrivacySafeSupportCheckStatus.unavailable &&
          (check.observedCount == null || check.expectedCount == null)) {
        throw const FormatException('support_available_without_count');
      }
    }
    for (final value in snapshot.governance.toJson().values) {
      _requireOptionalCount(value as int?);
    }
  }

  void _validateEnvelopeShape(
    Map<String, Object> envelope,
    List<PrivacySafeSupportSection> sections,
  ) {
    _requireExactKeys(envelope, const {
      'schema',
      'schema_version',
      'generated_at_utc',
      'selected_sections',
      'source_revision_sha256',
      'content_sha256',
      'content',
    });
    final content = envelope['content']! as Map<String, Object>;
    _requireExactKeys(content, sections.map((item) => item.name).toSet());
    if (content['build'] case final Map build) {
      _requireExactKeys(build, const {
        'app_id',
        'app_version',
        'build_number',
        'build_commit_sha256',
        'backend_mode',
        'environment',
        'algorithm_configuration_sha256',
        'algorithm_source_bundle_sha256',
      });
    }
    if (content['platform'] case final Map platform) {
      _requireExactKeys(platform, const {
        'platform_family',
        'scheduled_notifications_supported',
        'protected_store_capability',
        'protected_store_encrypted_at_rest',
        'protected_store_hardware_backing_verified',
        'firebase_backend_enabled',
        'app_check_enabled',
        'app_check_debug_enabled',
      });
    }
    if (content['governance'] case final Map governance) {
      _requireExactKeys(governance, const {
        'safe_copy_template_count',
        'localization_surface_count',
        'replay_scenario_count',
        'food_catalog_count',
        'medication_catalog_count',
        'source_document_count',
        'non_live_source_document_count',
        'placeholder_source_code_count',
        'rule_count',
        'model_assumption_count',
      });
    }
    if (content['diagnostics'] case final List<Object?> diagnostics) {
      for (final item in diagnostics) {
        if (item is! Map) {
          throw const FormatException('support_diagnostic_shape_invalid');
        }
        _requireExactKeys(item, const {
          'check_id',
          'status',
          'observed_count',
          'expected_count',
          'finding_codes',
        });
      }
    }
  }

  void _validateBudgetsAndPrivacy(
    Object? value, {
    required Stopwatch stopwatch,
  }) {
    var nodes = 0;
    void walk(Object? current, String path) {
      nodes += 1;
      if (nodes > privacySafeSupportBundleMaxNodes) {
        throw const FormatException('support_node_budget_exceeded');
      }
      if (stopwatch.elapsed > privacySafeSupportBundleGenerationBudget) {
        throw const FormatException('support_time_budget_exceeded');
      }
      if (current is String) {
        if (utf8.encode(current).length >
            privacySafeSupportBundleMaxStringBytes) {
          throw const FormatException('support_string_budget_exceeded');
        }
        if (_forbiddenValuePatterns.any(
          (pattern) => pattern.hasMatch(current),
        )) {
          throw FormatException('support_privacy_scan_failed:$path');
        }
        return;
      }
      if (current is num) {
        if (!current.isFinite) {
          throw const FormatException('support_nonfinite_number');
        }
        return;
      }
      if (current == null || current is bool) return;
      if (current is List) {
        if (current.length > 128) {
          throw const FormatException('support_list_budget_exceeded');
        }
        for (var i = 0; i < current.length; i += 1) {
          walk(current[i], '$path[$i]');
        }
        return;
      }
      if (current is Map) {
        if (current.length > 32 || current.keys.any((key) => key is! String)) {
          throw const FormatException('support_map_budget_exceeded');
        }
        for (final entry in current.entries) {
          final key = entry.key as String;
          if (_forbiddenKeyTokens.any(key.toLowerCase().contains)) {
            throw FormatException('support_forbidden_key:$key');
          }
          walk(entry.value, '$path.$key');
        }
        return;
      }
      throw const FormatException('support_unsupported_value');
    }

    walk(value, r'$');
  }

  void _requireExactKeys(Map map, Set<String> expected) {
    final actual = map.keys.cast<String>().toSet();
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      throw const FormatException('support_schema_keys_invalid');
    }
  }

  void _requireCount(int value) {
    if (value < 0 || value > 1000000) {
      throw const FormatException('support_count_invalid');
    }
  }

  void _requireOptionalCount(int? value) {
    if (value != null) _requireCount(value);
  }

  void _requireMatch(String value, RegExp pattern, String code) {
    if (!pattern.hasMatch(value)) throw FormatException(code);
  }

  void _requireSha(String value, String code) {
    if (!_sha256Pattern.hasMatch(value)) throw FormatException(code);
  }

  void _requireShaOrUnavailable(String value, String code) {
    if (value != 'unavailable' && !_sha256Pattern.hasMatch(value)) {
      throw FormatException(code);
    }
  }

  static final RegExp _versionPattern = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$');
  static final RegExp _buildNumberPattern = RegExp(r'^[0-9]{1,12}$');
  static final RegExp _identifierPattern = RegExp(r'^[a-z][a-z0-9._-]{2,95}$');
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
  static const List<String> _forbiddenKeyTokens = [
    'uid',
    'email',
    'patient',
    'token',
    'secret',
    'password',
    'endpoint',
    'url',
    'path',
    'exception',
    'stack',
    'health_record',
    'user_record',
  ];
  static final List<RegExp> _forbiddenValuePatterns = [
    RegExp(r'https?://', caseSensitive: false),
    RegExp(r'file://', caseSensitive: false),
    RegExp(r'[A-Z]:\\'),
    RegExp(r'/(?:Users|home|var|private|tmp)/'),
    RegExp(r'\bBearer\s+', caseSensitive: false),
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
  ];
}

String _sha256OfCanonicalJson(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
