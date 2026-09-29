import 'dart:async';
import 'dart:convert';

import '../../domain/entities/signed_capability_manifest.dart';
import 'capability_manifest_distribution.dart';
import 'data_service.dart';

const capabilityActivationStateSchema =
    'parkinsum.capability-activation-state/2';
const capabilityActivationStateSchemaVersion = 2;
const _legacyCapabilityActivationStateSchema =
    'parkinsum.capability-activation-state/1';
const capabilityActivationStorageKey =
    'parkinsum_capability_activation_state_v1';

enum CapabilityActivationStatus {
  conservativeDefaults,
  active,
  unconfigured,
  verificationRejected,
  replayRejected,
  downgradeRejected,
  chainRejected,
  rollbackRejected,
  keyTransitionRejected,
  persistenceFailed,
  recoveredAfterAcknowledgementLoss,
  idempotent,
  cleared,
}

enum CapabilityDecisionSource { signedManifest, conservativeDefault }

final class CapabilityDecision {
  const CapabilityDecision({
    required this.id,
    required this.enabled,
    required this.source,
    required this.reason,
    this.manifestSequence,
  });

  final SignedCapabilityId id;
  final bool enabled;
  final CapabilityDecisionSource source;
  final String reason;
  final int? manifestSequence;
}

final class CapabilityDistributionActivationResult {
  const CapabilityDistributionActivationResult({
    required this.fetch,
    required this.snapshot,
  });

  final CapabilityManifestFetchResult fetch;
  final CapabilityRolloutSnapshot snapshot;

  bool get candidateActivated =>
      fetch.hasCandidate &&
      (snapshot.activationStatus == CapabilityActivationStatus.active ||
          snapshot.activationStatus == CapabilityActivationStatus.idempotent ||
          snapshot.activationStatus ==
              CapabilityActivationStatus.recoveredAfterAcknowledgementLoss);
}

final class CapabilityRolloutSnapshot {
  CapabilityRolloutSnapshot({
    required this.activationStatus,
    required this.verificationStatus,
    required this.reason,
    required this.trustConfigured,
    this.envelope,
    this.activatedAtUtc,
    this.distributionCache,
    List<CapabilityManifestHistoryEntry> history =
        const <CapabilityManifestHistoryEntry>[],
  }) : history = List<CapabilityManifestHistoryEntry>.unmodifiable(history);

  final CapabilityActivationStatus activationStatus;
  final CapabilityManifestVerificationStatus? verificationStatus;
  final String reason;
  final bool trustConfigured;
  final SignedCapabilityEnvelope? envelope;
  final DateTime? activatedAtUtc;
  final CapabilityDistributionCacheState? distributionCache;
  final List<CapabilityManifestHistoryEntry> history;

  bool get hasActiveManifest =>
      envelope != null &&
      verificationStatus == CapabilityManifestVerificationStatus.verified &&
      activationStatus != CapabilityActivationStatus.conservativeDefaults &&
      activationStatus != CapabilityActivationStatus.unconfigured &&
      activationStatus != CapabilityActivationStatus.cleared;

  CapabilityDecision evaluate(
    SignedCapabilityId id, {
    bool localPrerequisiteSatisfied = true,
  }) {
    final manifest = hasActiveManifest ? envelope?.manifest : null;
    if (manifest == null) {
      return CapabilityDecision(
        id: id,
        enabled: false,
        source: CapabilityDecisionSource.conservativeDefault,
        reason: reason,
      );
    }
    final signedValue = manifest.capabilityValues[id] ?? false;
    if (!localPrerequisiteSatisfied) {
      return CapabilityDecision(
        id: id,
        enabled: false,
        source: CapabilityDecisionSource.signedManifest,
        reason: 'local_prerequisite_not_satisfied',
        manifestSequence: manifest.sequence,
      );
    }
    return CapabilityDecision(
      id: id,
      enabled: signedValue,
      source: CapabilityDecisionSource.signedManifest,
      reason: signedValue ? 'signed_enabled' : 'signed_disabled',
      manifestSequence: manifest.sequence,
    );
  }

  static CapabilityRolloutSnapshot defaults({
    required bool trustConfigured,
    CapabilityActivationStatus? status,
    String? reason,
  }) => CapabilityRolloutSnapshot(
    activationStatus:
        status ??
        (trustConfigured
            ? CapabilityActivationStatus.conservativeDefaults
            : CapabilityActivationStatus.unconfigured),
    verificationStatus: null,
    reason:
        reason ??
        (trustConfigured
            ? 'no_active_signed_manifest'
            : 'no_trusted_capability_key_configured'),
    trustConfigured: trustConfigured,
  );
}

final class CapabilityDistributionCacheState {
  CapabilityDistributionCacheState({
    required this.endpointLabel,
    required this.etag,
    required this.contentSha256,
    required this.manifestSha256,
    required this.acceptedAtUtc,
  }) {
    final endpoint = Uri.tryParse(endpointLabel);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.port != 443 ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpointLabel.length > 2048 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(contentSha256) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(manifestSha256) ||
        etag != '"$contentSha256"' ||
        !isCapabilityManifestContentEtag(etag) ||
        !acceptedAtUtc.isUtc) {
      throw const FormatException('distribution_cache_state_invalid');
    }
  }

  final String endpointLabel;
  final String etag;
  final String contentSha256;
  final String manifestSha256;
  final DateTime acceptedAtUtc;

  Map<String, Object?> toJson() => <String, Object?>{
    'accepted_at': acceptedAtUtc.toUtc().toIso8601String(),
    'content_sha256': contentSha256,
    'endpoint': endpointLabel,
    'etag': etag,
    'manifest_sha256': manifestSha256,
  };

  static CapabilityDistributionCacheState parse(Object? raw) {
    final map = _strictMap(raw, 'distribution_cache');
    _requireExactKeys(map, const <String>{
      'accepted_at',
      'content_sha256',
      'endpoint',
      'etag',
      'manifest_sha256',
    });
    return CapabilityDistributionCacheState(
      endpointLabel: _requiredString(map, 'endpoint'),
      etag: _requiredString(map, 'etag'),
      contentSha256: _requiredString(map, 'content_sha256'),
      manifestSha256: _requiredString(map, 'manifest_sha256'),
      acceptedAtUtc: _strictUtc(
        _requiredString(map, 'accepted_at'),
        'distribution_cache_timestamp',
      ),
    );
  }
}

final class CapabilityManifestHistoryEntry {
  CapabilityManifestHistoryEntry({
    required this.envelope,
    required this.activatedAtUtc,
  }) {
    if (!activatedAtUtc.isUtc) {
      throw const FormatException('history_timestamp_invalid');
    }
  }

  final SignedCapabilityEnvelope envelope;
  final DateTime activatedAtUtc;

  int get sequence => envelope.manifest.sequence;
  String get manifestId => envelope.manifest.manifestId;
  String get manifestSha256 => envelope.manifest.sha256;
  String get keyId => envelope.manifest.keyId;
  Map<SignedCapabilityId, bool> get capabilityValues =>
      envelope.manifest.capabilityValues;

  Map<String, Object?> toJson() => <String, Object?>{
    'activated_at': activatedAtUtc.toUtc().toIso8601String(),
    'envelope': envelope.toJson(),
  };

  static CapabilityManifestHistoryEntry fromEnvelope(
    SignedCapabilityEnvelope envelope, {
    required DateTime activatedAtUtc,
  }) => CapabilityManifestHistoryEntry(
    envelope: envelope,
    activatedAtUtc: activatedAtUtc,
  );

  static CapabilityManifestHistoryEntry parse(Object? raw) {
    final map = _strictMap(raw, 'history');
    _requireExactKeys(map, const <String>{'activated_at', 'envelope'});
    final activatedAtRaw = map['activated_at'];
    if (activatedAtRaw is! String) {
      throw const FormatException('history_shape_invalid');
    }
    final activatedAt = _strictUtc(activatedAtRaw, 'history_timestamp');
    final envelope = SignedCapabilityEnvelope.parseJson(
      canonicalCapabilityJson(map['envelope']),
    );
    return CapabilityManifestHistoryEntry(
      envelope: envelope,
      activatedAtUtc: activatedAt,
    );
  }
}

final class CapabilityActivationState {
  CapabilityActivationState({
    required this.activeEnvelope,
    required this.activatedAtUtc,
    required Iterable<CapabilityManifestHistoryEntry> history,
    this.distributionCache,
  }) : history = List<CapabilityManifestHistoryEntry>.unmodifiable(history) {
    if (!activatedAtUtc.isUtc ||
        history.length > 16 ||
        (distributionCache != null &&
            distributionCache!.manifestSha256 !=
                activeEnvelope.manifest.sha256)) {
      throw const FormatException('activation_state_invalid');
    }
    final sequences = <int>{};
    CapabilityManifestHistoryEntry? previous;
    for (final entry in history) {
      if (!sequences.add(entry.sequence) ||
          entry.sequence >= activeEnvelope.manifest.sequence) {
        throw const FormatException('activation_history_invalid');
      }
      if (previous != null &&
          (entry.sequence != previous.sequence + 1 ||
              entry.envelope.manifest.previousManifestSha256 !=
                  previous.manifestSha256)) {
        throw const FormatException('activation_history_chain_invalid');
      }
      previous = entry;
    }
    if (previous == null) {
      if (activeEnvelope.manifest.sequence != 1 ||
          activeEnvelope.manifest.previousManifestSha256 != null) {
        throw const FormatException('activation_history_anchor_invalid');
      }
    } else if (activeEnvelope.manifest.sequence != previous.sequence + 1 ||
        activeEnvelope.manifest.previousManifestSha256 !=
            previous.manifestSha256) {
      throw const FormatException('activation_history_head_invalid');
    }
  }

  final SignedCapabilityEnvelope activeEnvelope;
  final DateTime activatedAtUtc;
  final List<CapabilityManifestHistoryEntry> history;
  final CapabilityDistributionCacheState? distributionCache;

  Map<String, Object?> toJson() => <String, Object?>{
    r'$schema': capabilityActivationStateSchema,
    'activated_at': activatedAtUtc.toUtc().toIso8601String(),
    'active_envelope': activeEnvelope.toJson(),
    'active_manifest_sha256': activeEnvelope.manifest.sha256,
    'distribution_cache': distributionCache?.toJson(),
    'history': history.map((entry) => entry.toJson()).toList(growable: false),
  };

  String get canonicalJson => canonicalCapabilityJson(toJson());

  static CapabilityActivationState parse(String raw) {
    if (utf8.encode(raw).length > 512 * 1024) {
      throw const FormatException('activation_state_too_large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('activation_state_json_invalid');
    }
    final map = _strictMap(decoded, 'activation_state');
    final schema = map[r'$schema'];
    if (schema == capabilityActivationStateSchema) {
      _requireExactKeys(map, const <String>{
        r'$schema',
        'activated_at',
        'active_envelope',
        'active_manifest_sha256',
        'distribution_cache',
        'history',
      });
    } else if (schema == _legacyCapabilityActivationStateSchema) {
      _requireExactKeys(map, const <String>{
        r'$schema',
        'activated_at',
        'active_envelope',
        'active_manifest_sha256',
        'history',
      });
    } else {
      throw const FormatException('activation_state_schema_unsupported');
    }
    final envelopeJson = canonicalCapabilityJson(map['active_envelope']);
    final envelope = SignedCapabilityEnvelope.parseJson(envelopeJson);
    if (map['active_manifest_sha256'] != envelope.manifest.sha256) {
      throw const FormatException('activation_state_digest_mismatch');
    }
    final historyRaw = map['history'];
    if (historyRaw is! List || historyRaw.length > 16) {
      throw const FormatException('activation_history_invalid');
    }
    return CapabilityActivationState(
      activeEnvelope: envelope,
      activatedAtUtc: _strictUtc(
        _requiredString(map, 'activated_at'),
        'activation_timestamp',
      ),
      history: historyRaw.map(CapabilityManifestHistoryEntry.parse),
      distributionCache:
          schema == capabilityActivationStateSchema &&
              map['distribution_cache'] != null
          ? CapabilityDistributionCacheState.parse(map['distribution_cache'])
          : null,
    );
  }
}

abstract interface class CapabilityActivationStore {
  String get mutationScope;

  Future<String?> read();

  Future<void> writeExact(String canonicalState);

  Future<void> clear();
}

final class DataServiceCapabilityActivationStore
    implements CapabilityActivationStore {
  DataServiceCapabilityActivationStore({
    required DataService dataService,
    this.storageKey = capabilityActivationStorageKey,
  }) : _dataService = dataService;

  final DataService _dataService;
  final String storageKey;

  @override
  String get mutationScope => 'data-service:$storageKey';

  @override
  Future<String?> read() => _dataService.getString(storageKey);

  @override
  Future<void> writeExact(String canonicalState) async {
    await _dataService.setString(storageKey, canonicalState);
    final readBack = await _dataService.getString(storageKey);
    if (readBack != canonicalState) {
      throw StateError('capability_state_readback_mismatch');
    }
  }

  @override
  Future<void> clear() async {
    await _dataService.remove(storageKey);
    if (await _dataService.getString(storageKey) != null) {
      throw StateError('capability_state_clear_failed');
    }
  }
}

final class MemoryCapabilityActivationStore
    implements CapabilityActivationStore {
  MemoryCapabilityActivationStore({
    this.scope = 'memory-capability-rollout',
    String? initialValue,
  }) : _value = initialValue;

  final String scope;
  String? _value;

  @override
  String get mutationScope => scope;

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> writeExact(String canonicalState) async {
    _value = canonicalState;
  }
}

final class CapabilityRolloutService {
  CapabilityRolloutService({
    required this.store,
    required this.verifier,
    this.distributionClient,
    DateTime Function()? utcNow,
  }) : _utcNow = utcNow ?? (() => DateTime.now().toUtc()),
       _snapshot = CapabilityRolloutSnapshot.defaults(
         trustConfigured: verifier.trustPolicy.isConfigured,
       );

  final CapabilityActivationStore store;
  final SignedCapabilityManifestVerifier verifier;
  final CapabilityManifestDistributionClient? distributionClient;
  final DateTime Function() _utcNow;
  CapabilityRolloutSnapshot _snapshot;
  CapabilityManifestFetchResult? _lastDistributionFetch;
  int _distributionGeneration = 0;

  CapabilityRolloutSnapshot get snapshot => _snapshot;
  CapabilityManifestFetchResult? get lastDistributionFetch =>
      _lastDistributionFetch;
  bool get distributionConfigured =>
      distributionClient?.policy.isConfigured ?? false;
  String get distributionConfigurationReason =>
      distributionClient?.policy.configurationReason ??
      'distribution_client_not_available';
  String? get distributionEndpointLabel =>
      distributionClient?.policy.safeEndpointLabel;

  Future<CapabilityRolloutSnapshot> load() =>
      _CapabilityMutationSerial.run(store.mutationScope, () async {
        _snapshot = await _loadPersisted();
        _restoreAcceptedDistributionValidator(_snapshot);
        return _snapshot;
      });

  Future<CapabilityDistributionActivationResult> fetchAndActivate() =>
      _CapabilityMutationSerial.run('${store.mutationScope}:fetch', () async {
        final generation = _distributionGeneration;
        final client = distributionClient;
        if (client == null) {
          final fetch = CapabilityManifestFetchResult(
            status: CapabilityManifestFetchStatus.unconfigured,
            reason: 'distribution_client_not_available',
            endpointLabel: null,
          );
          _lastDistributionFetch = fetch;
          return CapabilityDistributionActivationResult(
            fetch: fetch,
            snapshot: _snapshot,
          );
        }
        await _CapabilityMutationSerial.run(store.mutationScope, () async {
          _snapshot = await _loadPersisted();
          _restoreAcceptedDistributionValidator(_snapshot);
        });
        final fetch = await client.fetch();
        _lastDistributionFetch = fetch;
        return _CapabilityMutationSerial.run(store.mutationScope, () async {
          _snapshot = await _loadPersisted();
          _restoreAcceptedDistributionValidator(_snapshot);
          if (!fetch.hasCandidate || generation != _distributionGeneration) {
            return CapabilityDistributionActivationResult(
              fetch: fetch,
              snapshot: _snapshot,
            );
          }
          final activated = await _activateLocked(
            fetch.body!,
            distributionFetch: fetch,
          );
          if (activated.distributionCache?.etag == fetch.etag &&
              activated.distributionCache?.endpointLabel ==
                  fetch.endpointLabel &&
              (activated.activationStatus ==
                      CapabilityActivationStatus.active ||
                  activated.activationStatus ==
                      CapabilityActivationStatus.idempotent ||
                  activated.activationStatus ==
                      CapabilityActivationStatus
                          .recoveredAfterAcknowledgementLoss)) {
            client.commitFetchedValidator(fetch);
          }
          return CapabilityDistributionActivationResult(
            fetch: fetch,
            snapshot: activated,
          );
        });
      });

  Future<CapabilityRolloutSnapshot> activate(String envelopeJson) {
    _distributionGeneration += 1;
    return _CapabilityMutationSerial.run(
      store.mutationScope,
      () => _activateLocked(envelopeJson),
    );
  }

  Future<CapabilityRolloutSnapshot> _activateLocked(
    String envelopeJson, {
    CapabilityManifestFetchResult? distributionFetch,
  }) async {
    final now = _utcNow();
    final current = await _loadPersisted();
    final verification = await verifier.verify(envelopeJson, nowUtc: now);
    if (!verification.isVerified) {
      _snapshot = _withOperationFailure(
        current,
        CapabilityActivationStatus.verificationRejected,
        verification.status,
        verification.reason,
      );
      return _snapshot;
    }
    final candidate = verification.envelope!;
    final nextDistributionCache = distributionFetch == null
        ? null
        : _distributionCacheFor(
            distributionFetch,
            manifestSha256: candidate.manifest.sha256,
            acceptedAtUtc: now,
          );
    final transitionFailure = _validateTransition(current, candidate);
    if (transitionFailure != null) {
      _snapshot = _withOperationFailure(
        current,
        transitionFailure.status,
        verification.status,
        transitionFailure.reason,
      );
      return _snapshot;
    }

    final existing = current.envelope;
    if (existing != null &&
        existing.manifest.sha256 == candidate.manifest.sha256) {
      if (nextDistributionCache != null) {
        final idempotentState = CapabilityActivationState(
          activeEnvelope: existing,
          activatedAtUtc: current.activatedAtUtc ?? now,
          history: current.history,
          distributionCache: nextDistributionCache,
        );
        try {
          await store.writeExact(idempotentState.canonicalJson);
          final loaded = await _loadPersisted();
          if (!loaded.hasActiveManifest ||
              loaded.distributionCache?.etag != nextDistributionCache.etag ||
              loaded.distributionCache?.endpointLabel !=
                  nextDistributionCache.endpointLabel) {
            throw StateError('distribution_cache_readback_unverified');
          }
          _snapshot = CapabilityRolloutSnapshot(
            activationStatus: CapabilityActivationStatus.idempotent,
            verificationStatus: verification.status,
            reason: 'manifest_already_active_distribution_cache_committed',
            trustConfigured: verifier.trustPolicy.isConfigured,
            envelope: loaded.envelope,
            activatedAtUtc: loaded.activatedAtUtc,
            distributionCache: loaded.distributionCache,
            history: loaded.history,
          );
          return _snapshot;
        } catch (_) {
          try {
            final recovered = await _loadPersisted();
            if (recovered.hasActiveManifest &&
                recovered.envelope?.manifest.sha256 ==
                    candidate.manifest.sha256 &&
                recovered.distributionCache?.etag ==
                    nextDistributionCache.etag &&
                recovered.distributionCache?.endpointLabel ==
                    nextDistributionCache.endpointLabel) {
              _snapshot = CapabilityRolloutSnapshot(
                activationStatus: CapabilityActivationStatus
                    .recoveredAfterAcknowledgementLoss,
                verificationStatus:
                    CapabilityManifestVerificationStatus.verified,
                reason:
                    'distribution_cache_recovered_after_acknowledgement_loss',
                trustConfigured: verifier.trustPolicy.isConfigured,
                envelope: recovered.envelope,
                activatedAtUtc: recovered.activatedAtUtc,
                distributionCache: recovered.distributionCache,
                history: recovered.history,
              );
              return _snapshot;
            }
          } catch (_) {
            // Preserve the previously verified state below.
          }
          _snapshot = _withOperationFailure(
            current,
            CapabilityActivationStatus.persistenceFailed,
            verification.status,
            'distribution_cache_persistence_failed',
          );
          return _snapshot;
        }
      }
      _snapshot = CapabilityRolloutSnapshot(
        activationStatus: CapabilityActivationStatus.idempotent,
        verificationStatus: verification.status,
        reason: 'manifest_already_active',
        trustConfigured: verifier.trustPolicy.isConfigured,
        envelope: existing,
        activatedAtUtc: current.activatedAtUtc,
        distributionCache: current.distributionCache,
        history: current.history,
      );
      return _snapshot;
    }

    final history = <CapabilityManifestHistoryEntry>[
      ...current.history,
      if (existing != null)
        CapabilityManifestHistoryEntry.fromEnvelope(
          existing,
          activatedAtUtc: now,
        ),
    ];
    final boundedHistory = history.length <= 16
        ? history
        : history.sublist(history.length - 16);
    final nextState = CapabilityActivationState(
      activeEnvelope: candidate,
      activatedAtUtc: now,
      history: boundedHistory,
      distributionCache: nextDistributionCache,
    );
    try {
      await store.writeExact(nextState.canonicalJson);
      final loaded = await _loadPersisted();
      if (loaded.envelope?.manifest.sha256 != candidate.manifest.sha256 ||
          !loaded.hasActiveManifest) {
        throw StateError('capability_activation_readback_unverified');
      }
      _snapshot = loaded;
      return _snapshot;
    } catch (_) {
      try {
        final recovered = await _loadPersisted();
        if (recovered.envelope?.manifest.sha256 == candidate.manifest.sha256 &&
            recovered.hasActiveManifest) {
          _snapshot = CapabilityRolloutSnapshot(
            activationStatus:
                CapabilityActivationStatus.recoveredAfterAcknowledgementLoss,
            verificationStatus: CapabilityManifestVerificationStatus.verified,
            reason: 'activation_recovered_after_acknowledgement_loss',
            trustConfigured: verifier.trustPolicy.isConfigured,
            envelope: recovered.envelope,
            activatedAtUtc: recovered.activatedAtUtc,
            distributionCache: recovered.distributionCache,
            history: recovered.history,
          );
          return _snapshot;
        }
      } catch (_) {
        // Preserve the last verified in-memory snapshot below.
      }
      _snapshot = _withOperationFailure(
        current,
        CapabilityActivationStatus.persistenceFailed,
        verification.status,
        'activation_persistence_failed',
      );
      return _snapshot;
    }
  }

  CapabilityDistributionCacheState _distributionCacheFor(
    CapabilityManifestFetchResult fetch, {
    required String manifestSha256,
    required DateTime acceptedAtUtc,
  }) {
    final endpoint = fetch.endpointLabel;
    final etag = fetch.etag;
    if (!fetch.hasCandidate ||
        endpoint == null ||
        etag == null ||
        !isCapabilityManifestContentEtag(etag)) {
      throw StateError('distribution_fetch_not_cacheable');
    }
    return CapabilityDistributionCacheState(
      endpointLabel: endpoint,
      etag: etag,
      contentSha256: etag.substring(1, etag.length - 1),
      manifestSha256: manifestSha256,
      acceptedAtUtc: acceptedAtUtc,
    );
  }

  Future<CapabilityRolloutSnapshot> clearToConservativeDefaults() {
    _distributionGeneration += 1;
    return _CapabilityMutationSerial.run(store.mutationScope, () async {
      try {
        await store.clear();
        distributionClient?.clearAcceptedValidator();
        _snapshot = CapabilityRolloutSnapshot.defaults(
          trustConfigured: verifier.trustPolicy.isConfigured,
          status: CapabilityActivationStatus.cleared,
          reason: 'local_activation_state_cleared',
        );
      } catch (_) {
        _snapshot = _withOperationFailure(
          _snapshot,
          CapabilityActivationStatus.persistenceFailed,
          _snapshot.verificationStatus,
          'activation_clear_failed',
        );
      }
      return _snapshot;
    });
  }

  Future<CapabilityRolloutSnapshot> _loadPersisted() async {
    final raw = await store.read();
    if (raw == null) {
      return CapabilityRolloutSnapshot.defaults(
        trustConfigured: verifier.trustPolicy.isConfigured,
      );
    }
    final CapabilityActivationState state;
    try {
      state = CapabilityActivationState.parse(raw);
    } catch (_) {
      return CapabilityRolloutSnapshot.defaults(
        trustConfigured: verifier.trustPolicy.isConfigured,
        status: CapabilityActivationStatus.conservativeDefaults,
        reason: 'persisted_activation_state_invalid',
      );
    }
    final verification = await verifier.verify(
      state.activeEnvelope.canonicalJson,
      nowUtc: _utcNow(),
    );
    if (!verification.isVerified) {
      return CapabilityRolloutSnapshot(
        activationStatus: CapabilityActivationStatus.conservativeDefaults,
        verificationStatus: verification.status,
        reason: verification.reason,
        trustConfigured: verifier.trustPolicy.isConfigured,
        envelope: state.activeEnvelope,
        activatedAtUtc: state.activatedAtUtc,
        distributionCache: state.distributionCache,
        history: state.history,
      );
    }
    for (final entry in state.history) {
      final historicalVerification = await verifier.verify(
        entry.envelope.canonicalJson,
        nowUtc: entry.envelope.manifest.notBeforeUtc,
      );
      if (!historicalVerification.isVerified) {
        return CapabilityRolloutSnapshot.defaults(
          trustConfigured: verifier.trustPolicy.isConfigured,
          status: CapabilityActivationStatus.conservativeDefaults,
          reason:
              'persisted_history_verification_failed:${historicalVerification.status.name}',
        );
      }
    }
    return CapabilityRolloutSnapshot(
      activationStatus: CapabilityActivationStatus.active,
      verificationStatus: verification.status,
      reason: 'last_known_good_manifest_active',
      trustConfigured: verifier.trustPolicy.isConfigured,
      envelope: verification.envelope,
      activatedAtUtc: state.activatedAtUtc,
      distributionCache: state.distributionCache,
      history: state.history,
    );
  }

  _CapabilityTransitionFailure? _validateTransition(
    CapabilityRolloutSnapshot current,
    SignedCapabilityEnvelope candidate,
  ) {
    final currentManifest = current.envelope?.manifest;
    final next = candidate.manifest;
    if (currentManifest == null) {
      if (next.sequence != 1 ||
          next.previousManifestSha256 != null ||
          next.rollbackTarget != null) {
        return const _CapabilityTransitionFailure(
          CapabilityActivationStatus.chainRejected,
          'genesis_manifest_contract_invalid',
        );
      }
      return null;
    }
    if (next.sequence == currentManifest.sequence &&
        next.sha256 == currentManifest.sha256) {
      return null;
    }
    if (next.sequence == currentManifest.sequence) {
      return const _CapabilityTransitionFailure(
        CapabilityActivationStatus.replayRejected,
        'sequence_reused_with_different_manifest',
      );
    }
    if (next.sequence < currentManifest.sequence) {
      return const _CapabilityTransitionFailure(
        CapabilityActivationStatus.downgradeRejected,
        'manifest_sequence_downgrade',
      );
    }
    if (next.sequence != currentManifest.sequence + 1) {
      return const _CapabilityTransitionFailure(
        CapabilityActivationStatus.chainRejected,
        'manifest_sequence_gap',
      );
    }
    if (next.previousManifestSha256 != currentManifest.sha256) {
      return const _CapabilityTransitionFailure(
        CapabilityActivationStatus.chainRejected,
        'previous_manifest_digest_mismatch',
      );
    }
    if (next.keyId != currentManifest.keyId &&
        next.reason != CapabilityManifestReason.keyRotation &&
        next.reason != CapabilityManifestReason.emergencyDisable) {
      return const _CapabilityTransitionFailure(
        CapabilityActivationStatus.keyTransitionRejected,
        'key_transition_reason_invalid',
      );
    }
    final currentValues = currentManifest.capabilityValues;
    final nextValues = next.capabilityValues;
    if (next.reason == CapabilityManifestReason.emergencyDisable) {
      for (final id in SignedCapabilityId.values) {
        if ((nextValues[id] ?? false) && !(currentValues[id] ?? false)) {
          return const _CapabilityTransitionFailure(
            CapabilityActivationStatus.rollbackRejected,
            'emergency_manifest_cannot_enable_capabilities',
          );
        }
      }
    }
    final rollback = next.rollbackTarget;
    if (next.reason == CapabilityManifestReason.rollback) {
      if (rollback == null || rollback.sequence >= currentManifest.sequence) {
        return const _CapabilityTransitionFailure(
          CapabilityActivationStatus.rollbackRejected,
          'rollback_target_invalid',
        );
      }
      CapabilityManifestHistoryEntry? target;
      for (final entry in current.history) {
        if (entry.sequence == rollback.sequence &&
            entry.manifestSha256 == rollback.manifestSha256) {
          target = entry;
          break;
        }
      }
      if (target == null ||
          !_equalCapabilityValues(target.capabilityValues, nextValues)) {
        return const _CapabilityTransitionFailure(
          CapabilityActivationStatus.rollbackRejected,
          'rollback_target_not_in_verified_history',
        );
      }
    } else if (rollback != null &&
        next.reason != CapabilityManifestReason.emergencyDisable) {
      return const _CapabilityTransitionFailure(
        CapabilityActivationStatus.rollbackRejected,
        'unexpected_rollback_target',
      );
    }
    return null;
  }

  CapabilityRolloutSnapshot _withOperationFailure(
    CapabilityRolloutSnapshot current,
    CapabilityActivationStatus status,
    CapabilityManifestVerificationStatus? candidateVerificationStatus,
    String reason,
  ) {
    final activeVerification = current.hasActiveManifest
        ? CapabilityManifestVerificationStatus.verified
        : null;
    final combinedReason = candidateVerificationStatus == null
        ? reason
        : '$reason:${candidateVerificationStatus.name}';
    return CapabilityRolloutSnapshot(
      activationStatus: status,
      verificationStatus: activeVerification,
      reason: combinedReason,
      trustConfigured: verifier.trustPolicy.isConfigured,
      envelope: current.envelope,
      activatedAtUtc: current.activatedAtUtc,
      distributionCache: current.distributionCache,
      history: current.history,
    );
  }

  void _restoreAcceptedDistributionValidator(
    CapabilityRolloutSnapshot current,
  ) {
    final client = distributionClient;
    final cache = current.distributionCache;
    if (client == null || !current.hasActiveManifest || cache == null) {
      client?.clearAcceptedValidator();
      return;
    }
    client.restoreAcceptedValidator(
      endpointLabel: cache.endpointLabel,
      etag: cache.etag,
    );
  }
}

final class CapabilityRolloutProductionConfig {
  static const environment = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_ENVIRONMENT',
    defaultValue: 'development',
  );
  static const issuer = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_ISSUER',
    defaultValue: 'parkinsum-release',
  );
  static const keyId = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_KEY_ID',
    defaultValue: '',
  );
  static const publicKeyBase64Url = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_PUBLIC_KEY_BASE64URL',
    defaultValue: '',
  );
  static const revokedKeyIdsCsv = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_REVOKED_KEY_IDS',
    defaultValue: '',
  );
  static const manifestUrl = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_MANIFEST_URL',
    defaultValue: '',
  );
  static const manifestAllowedHostsCsv = String.fromEnvironment(
    'PARKINSUM_CAPABILITY_MANIFEST_ALLOWED_HOSTS',
    defaultValue: '',
  );

  static CapabilityTrustPolicy trustPolicy() {
    final trusted = <String, List<int>>{};
    if (keyId.isNotEmpty && publicKeyBase64Url.isNotEmpty) {
      try {
        final bytes = base64Url.decode(base64Url.normalize(publicKeyBase64Url));
        if (bytes.length == 32) trusted[keyId] = bytes;
      } on FormatException {
        // Invalid build-time trust configuration must disable managed
        // capabilities rather than crash application startup.
      }
    }
    final revoked = revokedKeyIdsCsv
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return CapabilityTrustPolicy(
      environment: environment,
      issuer: issuer,
      trustedEd25519PublicKeys: trusted,
      revokedKeyIds: revoked,
    );
  }

  static CapabilityRolloutService createService({DataService? dataService}) =>
      CapabilityRolloutService(
        store: DataServiceCapabilityActivationStore(
          dataService: dataService ?? SharedPrefsDataService(),
        ),
        verifier: SignedCapabilityManifestVerifier(trustPolicy: trustPolicy()),
        distributionClient: CapabilityManifestDistributionClient(
          policy: CapabilityManifestDistributionPolicy.fromConfiguration(
            endpointUrl: manifestUrl,
            allowedHostsCsv: manifestAllowedHostsCsv,
            runtimeOrigin: Uri.base,
          ),
        ),
      );
}

final class _CapabilityTransitionFailure {
  const _CapabilityTransitionFailure(this.status, this.reason);

  final CapabilityActivationStatus status;
  final String reason;
}

final class _CapabilityMutationSerial {
  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>(String scope, Future<T> Function() operation) {
    final previous = _tails[scope] ?? Future<void>.value();
    final result = Completer<T>();
    late final Future<void> next;
    next = previous
        .catchError((Object _) {})
        .then((_) async {
          try {
            result.complete(await operation());
          } catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_tails[scope], next)) _tails.remove(scope);
        });
    _tails[scope] = next;
    return result.future;
  }
}

Map<String, Object?> _strictMap(Object? raw, String label) {
  if (raw is! Map) throw FormatException('${label}_not_object');
  final map = <String, Object?>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || map.containsKey(entry.key)) {
      throw FormatException('${label}_keys_invalid');
    }
    map[entry.key as String] = entry.value;
  }
  return map;
}

void _requireExactKeys(Map<String, Object?> map, Set<String> expected) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException('unknown_or_missing_fields');
  }
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty || value.length > 256) {
    throw FormatException('${key}_invalid');
  }
  return value;
}

DateTime _strictUtc(String raw, String label) {
  final parsed = DateTime.parse(raw).toUtc();
  if (!raw.endsWith('Z') || parsed.toIso8601String() != raw) {
    throw FormatException('${label}_invalid');
  }
  return parsed;
}

bool _equalCapabilityValues(
  Map<SignedCapabilityId, bool> left,
  Map<SignedCapabilityId, bool> right,
) {
  for (final id in SignedCapabilityId.values) {
    if ((left[id] ?? false) != (right[id] ?? false)) return false;
  }
  return true;
}
