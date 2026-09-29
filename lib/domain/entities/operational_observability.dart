library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const String operationalObservabilityEnvelopeSchema =
    'parkinsum.operational-observability-envelope/1';
const int operationalObservabilityEnvelopeSchemaVersion = 1;
const int operationalObservabilityPolicyVersion = 1;
const int operationalObservabilityNoticeVersion = 1;
const Duration operationalObservabilityLocalRetention = Duration(hours: 24);
const int operationalObservabilityMaxLocalRecords = 2048;
const int operationalObservabilityMaxAggregateCells = 32;
const int operationalObservabilityMaxAggregateCount = 10000;

enum OperationalSignalCategory {
  startup,
  backend,
  notification,
  modelAvailability,
}

enum OperationalOutcome {
  success,
  unavailable,
  timeout,
  abstained,
  integrityBlocked,
}

enum OperationalDurationBucket {
  notMeasured,
  under250Ms,
  from250To999Ms,
  from1To4S,
  atLeast5S,
}

enum OperationalCapabilityState {
  supported,
  planOnly,
  unavailable,
  notApplicable,
}

enum OperationalRegion { canada, unitedStates, europeanUnion }

enum OperationalEndpoint { regionalAggregateCollector }

enum OperationalAccessRole { privacyReviewedOperations }

/// The user-facing purpose text whose exact identity must be reviewed before
/// any future off-device aggregate is materialized.
///
/// This notice does not itself grant consent and does not implement a network
/// exporter. Local, in-memory diagnostics remain available without it.
final class OperationalObservabilityNotice {
  static const String purposeId =
      'privacy_bounded_operational_reliability_aggregates';
  static const String purpose =
      'Optionally send coarse app-reliability aggregates to a reviewed '
      'regional operations endpoint.';
  static const List<String> allowedCategories = <String>[
    'startup outcome and coarse duration bucket',
    'backend outcome and coarse duration bucket',
    'notification capability or reconciliation outcome',
    'model availability or abstention outcome',
  ];
  static const List<String> exclusions = <String>[
    'No medication, meal, dose, symptom, free text, source document, or '
        'notification content.',
    'No email, UID, account hash, session identifier, IP address, URL, '
        'credential, raw exception, stack, path, or exact user timestamp.',
    'Telemetry is operational evidence only and is never clinical evidence.',
  ];

  static Map<String, Object> get canonicalPayload => <String, Object>{
    'allowed_categories': allowedCategories,
    'exclusions': exclusions,
    'notice_version': operationalObservabilityNoticeVersion,
    'purpose': purpose,
    'purpose_id': purposeId,
  };

  static String get sha256Digest =>
      sha256.convert(utf8.encode(_canonicalJson(canonicalPayload))).toString();
}

final class OperationalObservation {
  const OperationalObservation({
    required this.category,
    required this.outcome,
    this.duration = OperationalDurationBucket.notMeasured,
    this.capability = OperationalCapabilityState.notApplicable,
  });

  final OperationalSignalCategory category;
  final OperationalOutcome outcome;
  final OperationalDurationBucket duration;
  final OperationalCapabilityState capability;
}

final class OperationalAggregate {
  const OperationalAggregate({
    required this.category,
    required this.outcome,
    required this.duration,
    required this.capability,
    required this.count,
  });

  final OperationalSignalCategory category;
  final OperationalOutcome outcome;
  final OperationalDurationBucket duration;
  final OperationalCapabilityState capability;
  final int count;

  String get key => <String>[
    category.name,
    outcome.name,
    duration.name,
    capability.name,
  ].join('|');

  Map<String, Object> toJson() => <String, Object>{
    'capability': capability.name,
    'category': category.name,
    'count': count,
    'duration_bucket': duration.name,
    'outcome': outcome.name,
  };
}

final class OperationalLocalSnapshot {
  OperationalLocalSnapshot({
    required List<OperationalAggregate> aggregates,
    required this.windowMinutes,
    required this.collectionEnabled,
    this.droppedObservationCount = 0,
  }) : aggregates = List<OperationalAggregate>.unmodifiable(aggregates);

  final List<OperationalAggregate> aggregates;
  final int windowMinutes;
  final bool collectionEnabled;
  final int droppedObservationCount;

  bool get overflowed => droppedObservationCount > 0;

  int get totalCount =>
      aggregates.fold<int>(0, (total, aggregate) => total + aggregate.count);
}

final class _TimedObservation {
  const _TimedObservation({
    required this.observation,
    required this.recordedAt,
  });

  final OperationalObservation observation;
  final DateTime recordedAt;
}

/// Bounded process-memory ledger. Exact times are used only for local expiry
/// and are never serialized, exported, persisted, or exposed to callers.
final class OperationalObservabilityLedger {
  OperationalObservabilityLedger();

  static final OperationalObservabilityLedger instance =
      OperationalObservabilityLedger();

  final List<_TimedObservation> _records = <_TimedObservation>[];
  bool _collectionEnabled = true;
  int _droppedObservationCount = 0;
  DateTime? _lastOverflowAt;

  bool get collectionEnabled => _collectionEnabled;

  void setCollectionEnabled(bool enabled) {
    _collectionEnabled = enabled;
    if (!enabled) clear();
  }

  void clear() {
    _records.clear();
    _droppedObservationCount = 0;
    _lastOverflowAt = null;
  }

  void record(OperationalObservation observation, {DateTime? now}) {
    if (!_collectionEnabled) return;
    final recordedAt = (now ?? DateTime.now()).toUtc();
    _prune(recordedAt);
    final candidateKey = _aggregateKey(observation);
    final existingKeys = _records
        .map((record) => _aggregateKey(record.observation))
        .toSet();
    if (!existingKeys.contains(candidateKey) &&
        existingKeys.length >= operationalObservabilityMaxAggregateCells) {
      _droppedObservationCount = (_droppedObservationCount + 1).clamp(
        0,
        operationalObservabilityMaxAggregateCount,
      );
      _lastOverflowAt = recordedAt;
      return;
    }
    if (_records.length >= operationalObservabilityMaxLocalRecords) {
      _records.removeAt(0);
    }
    _records.add(
      _TimedObservation(observation: observation, recordedAt: recordedAt),
    );
  }

  OperationalLocalSnapshot snapshot({DateTime? now}) {
    final observedAt = (now ?? DateTime.now()).toUtc();
    _prune(observedAt);
    final cells = <String, OperationalAggregate>{};
    for (final record in _records) {
      final observation = record.observation;
      final candidate = OperationalAggregate(
        category: observation.category,
        outcome: observation.outcome,
        duration: observation.duration,
        capability: observation.capability,
        count: 1,
      );
      final previous = cells[candidate.key];
      final nextCount = (previous?.count ?? 0) + 1;
      cells[candidate.key] = OperationalAggregate(
        category: candidate.category,
        outcome: candidate.outcome,
        duration: candidate.duration,
        capability: candidate.capability,
        count: nextCount.clamp(0, operationalObservabilityMaxAggregateCount),
      );
    }
    final ordered = cells.values.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    if (ordered.length > operationalObservabilityMaxAggregateCells) {
      throw const FormatException('observability_cardinality_budget_exceeded');
    }
    return OperationalLocalSnapshot(
      aggregates: ordered,
      windowMinutes: operationalObservabilityLocalRetention.inMinutes,
      collectionEnabled: _collectionEnabled,
      droppedObservationCount: _droppedObservationCount,
    );
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(operationalObservabilityLocalRetention);
    _records.removeWhere((record) => record.recordedAt.isBefore(cutoff));
    final lastOverflowAt = _lastOverflowAt;
    if (lastOverflowAt != null && lastOverflowAt.isBefore(cutoff)) {
      _droppedObservationCount = 0;
      _lastOverflowAt = null;
    }
  }
}

final class OperationalReleaseIdentity {
  const OperationalReleaseIdentity({
    required this.appVersion,
    required this.buildNumber,
    required this.buildCommitSha256,
    required this.platformFamily,
    required this.backendMode,
    required this.environment,
    required this.algorithmConfigurationSha256,
    required this.algorithmSourceBundleSha256,
  });

  final String appVersion;
  final String buildNumber;
  final String buildCommitSha256;
  final String platformFamily;
  final String backendMode;
  final String environment;
  final String algorithmConfigurationSha256;
  final String algorithmSourceBundleSha256;

  Map<String, Object> toJson() => <String, Object>{
    'algorithm_configuration_sha256': algorithmConfigurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'app_id': 'parkinsum_companion',
    'app_version': appVersion,
    'backend_mode': backendMode,
    'build_commit_sha256': buildCommitSha256,
    'build_number': buildNumber,
    'environment': environment,
    'platform_family': platformFamily,
  };
}

final class OperationalExportAuthorization {
  const OperationalExportAuthorization({
    required this.current,
    required this.noticeVersion,
    required this.noticeSha256,
    required this.receiptSha256,
  });

  final bool current;
  final int noticeVersion;
  final String noticeSha256;
  final String receiptSha256;
}

final class OperationalExportPolicy {
  const OperationalExportPolicy({
    this.offDeviceEnabled = false,
    this.emergencyDisabled = true,
    this.region = OperationalRegion.canada,
    this.endpoint = OperationalEndpoint.regionalAggregateCollector,
    this.accessRole = OperationalAccessRole.privacyReviewedOperations,
    this.samplingPermille = 0,
    this.retentionDays = 7,
    this.deletionSlaDays = 30,
    this.maxCardinality = operationalObservabilityMaxAggregateCells,
  });

  final bool offDeviceEnabled;
  final bool emergencyDisabled;
  final OperationalRegion region;
  final OperationalEndpoint endpoint;
  final OperationalAccessRole accessRole;
  final int samplingPermille;
  final int retentionDays;
  final int deletionSlaDays;
  final int maxCardinality;
}

final class OperationalEnvelopeArtifact {
  const OperationalEnvelopeArtifact({
    required this.canonicalJson,
    required this.envelopeSha256,
  });

  final String canonicalJson;
  final String envelopeSha256;
}

final class OperationalObservabilityEnvelopeService {
  const OperationalObservabilityEnvelopeService();

  OperationalEnvelopeArtifact create({
    required OperationalLocalSnapshot snapshot,
    required OperationalReleaseIdentity release,
    required OperationalExportPolicy policy,
    required OperationalExportAuthorization authorization,
  }) {
    _validateExportGate(policy, authorization);
    _validateRelease(release);
    if (!snapshot.collectionEnabled) {
      throw const FormatException('observability_collection_disabled');
    }
    if (snapshot.overflowed) {
      throw const FormatException('observability_local_overflow_unresolved');
    }
    if (snapshot.aggregates.length > policy.maxCardinality) {
      throw const FormatException('observability_cardinality_budget_exceeded');
    }
    for (final aggregate in snapshot.aggregates) {
      if (aggregate.count <= 0 ||
          aggregate.count > operationalObservabilityMaxAggregateCount) {
        throw const FormatException('observability_count_budget_exceeded');
      }
    }
    final content = <String, Object>{
      'aggregates': snapshot.aggregates
          .map((aggregate) => aggregate.toJson())
          .toList(growable: false),
      'policy': <String, Object>{
        'access_role': policy.accessRole.name,
        'deletion_sla_days': policy.deletionSlaDays,
        'endpoint': policy.endpoint.name,
        'max_cardinality': policy.maxCardinality,
        'policy_version': operationalObservabilityPolicyVersion,
        'region': policy.region.name,
        'retention_days': policy.retentionDays,
        'sampling_permille': policy.samplingPermille,
      },
      'release': release.toJson(),
      'schema': operationalObservabilityEnvelopeSchema,
      'schema_version': operationalObservabilityEnvelopeSchemaVersion,
      'window_minutes': snapshot.windowMinutes,
    };
    final contentDigest = sha256
        .convert(utf8.encode(_canonicalJson(content)))
        .toString();
    final envelope = <String, Object>{
      ...content,
      'envelope_sha256': contentDigest,
    };
    final encoded = _canonicalJson(envelope);
    validateSerializedEnvelope(encoded);
    return OperationalEnvelopeArtifact(
      canonicalJson: encoded,
      envelopeSha256: contentDigest,
    );
  }

  void validateSerializedEnvelope(String encoded) {
    if (utf8.encode(encoded).length > 64 * 1024) {
      throw const FormatException('observability_envelope_too_large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } catch (_) {
      throw const FormatException('observability_json_invalid');
    }
    final root = _map(decoded, 'observability_root_invalid');
    _exactKeys(root, const <String>{
      'aggregates',
      'envelope_sha256',
      'policy',
      'release',
      'schema',
      'schema_version',
      'window_minutes',
    });
    if (root['schema'] != operationalObservabilityEnvelopeSchema ||
        root['schema_version'] !=
            operationalObservabilityEnvelopeSchemaVersion) {
      throw const FormatException('observability_schema_unsupported');
    }
    if (root['window_minutes'] !=
        operationalObservabilityLocalRetention.inMinutes) {
      throw const FormatException('observability_window_invalid');
    }
    final policy = _map(root['policy'], 'observability_policy_invalid');
    _exactKeys(policy, const <String>{
      'access_role',
      'deletion_sla_days',
      'endpoint',
      'max_cardinality',
      'policy_version',
      'region',
      'retention_days',
      'sampling_permille',
    });
    _requireEnum(
      policy['access_role'],
      OperationalAccessRole.values.map((value) => value.name),
    );
    _requireEnum(
      policy['endpoint'],
      OperationalEndpoint.values.map((value) => value.name),
    );
    _requireEnum(
      policy['region'],
      OperationalRegion.values.map((value) => value.name),
    );
    if (policy['policy_version'] != operationalObservabilityPolicyVersion) {
      throw const FormatException('observability_policy_unsupported');
    }
    _requireIntRange(policy['sampling_permille'], 1, 1000);
    _requireIntRange(policy['retention_days'], 1, 30);
    _requireIntRange(policy['deletion_sla_days'], 1, 90);
    _requireIntRange(
      policy['max_cardinality'],
      1,
      operationalObservabilityMaxAggregateCells,
    );

    final release = _map(root['release'], 'observability_release_invalid');
    _exactKeys(release, const <String>{
      'algorithm_configuration_sha256',
      'algorithm_source_bundle_sha256',
      'app_id',
      'app_version',
      'backend_mode',
      'build_commit_sha256',
      'build_number',
      'environment',
      'platform_family',
    });
    _validateReleaseJson(release);

    final aggregates = root['aggregates'];
    if (aggregates is! List<Object?> ||
        aggregates.length > operationalObservabilityMaxAggregateCells) {
      throw const FormatException('observability_aggregates_invalid');
    }
    final seen = <String>{};
    for (final value in aggregates) {
      final item = _map(value, 'observability_aggregate_invalid');
      _exactKeys(item, const <String>{
        'capability',
        'category',
        'count',
        'duration_bucket',
        'outcome',
      });
      _requireEnum(
        item['category'],
        OperationalSignalCategory.values.map((value) => value.name),
      );
      _requireEnum(
        item['outcome'],
        OperationalOutcome.values.map((value) => value.name),
      );
      _requireEnum(
        item['duration_bucket'],
        OperationalDurationBucket.values.map((value) => value.name),
      );
      _requireEnum(
        item['capability'],
        OperationalCapabilityState.values.map((value) => value.name),
      );
      _requireIntRange(
        item['count'],
        1,
        operationalObservabilityMaxAggregateCount,
      );
      final key = _canonicalJson(item);
      if (!seen.add(key)) {
        throw const FormatException('observability_duplicate_aggregate');
      }
    }
    final claimedDigest = root['envelope_sha256'];
    if (claimedDigest is! String || !_sha256Pattern.hasMatch(claimedDigest)) {
      throw const FormatException('observability_digest_invalid');
    }
    final content = Map<String, Object?>.from(root)..remove('envelope_sha256');
    final actualDigest = sha256
        .convert(utf8.encode(_canonicalJson(content)))
        .toString();
    if (claimedDigest != actualDigest) {
      throw const FormatException('observability_digest_mismatch');
    }
  }

  void _validateExportGate(
    OperationalExportPolicy policy,
    OperationalExportAuthorization authorization,
  ) {
    if (!policy.offDeviceEnabled) {
      throw const FormatException('observability_export_disabled');
    }
    if (policy.emergencyDisabled) {
      throw const FormatException('observability_emergency_disabled');
    }
    if (!authorization.current ||
        authorization.noticeVersion != operationalObservabilityNoticeVersion ||
        authorization.noticeSha256 !=
            OperationalObservabilityNotice.sha256Digest ||
        !_sha256Pattern.hasMatch(authorization.receiptSha256)) {
      throw const FormatException('observability_consent_not_current');
    }
    if (policy.samplingPermille < 1 || policy.samplingPermille > 1000) {
      throw const FormatException('observability_sampling_budget_invalid');
    }
    if (policy.retentionDays < 1 ||
        policy.retentionDays > 30 ||
        policy.deletionSlaDays < 1 ||
        policy.deletionSlaDays > 90 ||
        policy.maxCardinality < 1 ||
        policy.maxCardinality > operationalObservabilityMaxAggregateCells) {
      throw const FormatException('observability_policy_budget_invalid');
    }
  }

  void _validateRelease(OperationalReleaseIdentity release) =>
      _validateReleaseJson(release.toJson());

  void _validateReleaseJson(Map<String, Object?> release) {
    if (release['app_id'] != 'parkinsum_companion' ||
        release['app_version'] is! String ||
        !_versionPattern.hasMatch(release['app_version']! as String) ||
        release['build_number'] is! String ||
        !_buildNumberPattern.hasMatch(release['build_number']! as String) ||
        !const <String>{
          'local',
          'firebase',
        }.contains(release['backend_mode']) ||
        !const <String>{
          'dev',
          'stage',
          'prod',
        }.contains(release['environment']) ||
        !const <String>{
          'web',
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
          'fuchsia',
        }.contains(release['platform_family'])) {
      throw const FormatException('observability_release_invalid');
    }
    for (final key in const <String>{
      'algorithm_configuration_sha256',
      'algorithm_source_bundle_sha256',
    }) {
      if (release[key] is! String ||
          !_sha256Pattern.hasMatch(release[key]! as String)) {
        throw const FormatException('observability_release_identity_invalid');
      }
    }
    final commit = release['build_commit_sha256'];
    if (commit != 'unavailable' &&
        (commit is! String || !_sha256Pattern.hasMatch(commit))) {
      throw const FormatException('observability_build_identity_invalid');
    }
  }
}

String _aggregateKey(OperationalObservation observation) => <String>[
  observation.category.name,
  observation.outcome.name,
  observation.duration.name,
  observation.capability.name,
].join('|');

OperationalDurationBucket operationalDurationBucket(Duration duration) {
  if (duration.isNegative) {
    throw const FormatException('observability_duration_negative');
  }
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 250) return OperationalDurationBucket.under250Ms;
  if (milliseconds < 1000) return OperationalDurationBucket.from250To999Ms;
  if (milliseconds < 5000) return OperationalDurationBucket.from1To4S;
  return OperationalDurationBucket.atLeast5S;
}

Map<String, Object?> _map(Object? value, String code) {
  if (value is! Map) throw FormatException(code);
  return Map<String, Object?>.from(value);
}

void _exactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.keys.toSet().length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw const FormatException('observability_unknown_or_missing_field');
  }
}

void _requireEnum(Object? value, Iterable<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('observability_enum_invalid');
  }
}

void _requireIntRange(Object? value, int minimum, int maximum) {
  if (value is! int || value < minimum || value > maximum) {
    throw const FormatException('observability_integer_invalid');
  }
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  return value;
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final RegExp _versionPattern = RegExp(
  r'^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$',
);
final RegExp _buildNumberPattern = RegExp(r'^\d{1,12}$');
