import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'credibility_evidence_execution_attestation.dart';
import 'credibility_protocol_transparency_ledger.dart';

enum ReplicationOutcomeStatus { reported, nullResult, failed, adverse, missing }

enum ReplicationDiscrepancyClass {
  code,
  data,
  environment,
  dependency,
  analysis,
  protocol,
  stochastic,
  clock,
  authorization,
  unknown,
}

enum ReplicationAdjudicationDecision {
  agreementAccepted,
  discrepancyHeld,
  correctionRequired,
  rerunRequired,
  rejected,
  revoked,
}

enum BlindedReplicationStatus {
  mechanicallyObserved,
  held,
  unknown,
  violated,
  revoked,
}

enum BlindedReplicationFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  expectedValueInCapsule,
  rawParticipantDataIncluded,
  capsuleExpired,
  actorNotIndependent,
  authorityMissing,
  blindingBreach,
  responseBindingMismatch,
  responseChainBroken,
  responseReplay,
  invalidClock,
  partialExecution,
  privacyUnsafeLog,
  tolerancePolicyChanged,
  custodyCommitmentMismatch,
  adjudicationChainBroken,
  adjudicationMismatch,
  revocation,
}

final class ReplicationOutcomeRecord {
  final String outcomeId;
  final ReplicationOutcomeStatus status;
  final String resultSha256;
  final String detailCode;

  const ReplicationOutcomeRecord({
    required this.outcomeId,
    required this.status,
    required this.resultSha256,
    required this.detailCode,
  });

  ReplicationOutcomeRecord copyWith({
    ReplicationOutcomeStatus? status,
    String? resultSha256,
    String? detailCode,
  }) => ReplicationOutcomeRecord(
    outcomeId: outcomeId,
    status: status ?? this.status,
    resultSha256: resultSha256 ?? this.resultSha256,
    detailCode: detailCode ?? this.detailCode,
  );

  Map<String, Object?> toJson() => {
    'outcome_id': outcomeId,
    'status': status.name,
    'result_sha256': resultSha256,
    'detail_code': detailCode,
  };
}

final class BlindedReplicationCapsule {
  final String capsuleId;
  final String protocolLedgerSha256;
  final String lastAcceptedProtocolEventSha256;
  final String executionAttestationSha256;
  final String lockedInputManifestSha256;
  final String analysisPlanSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final String codeSha256;
  final String environmentSha256;
  final String dependencyLockSha256;
  final String deterministicCommand;
  final String outputSchema;
  final int randomSeed;
  final String tolerancePolicySha256;
  final String expectedResultCommitmentSha256;
  final bool containsExpectedResultValues;
  final bool containsRawParticipantData;
  final String creatorId;
  final String creatorAuthorityId;
  final String createdAtUtc;
  final String expiresAtUtc;
  final String resultVisibilityPolicy;

  const BlindedReplicationCapsule({
    required this.capsuleId,
    required this.protocolLedgerSha256,
    required this.lastAcceptedProtocolEventSha256,
    required this.executionAttestationSha256,
    required this.lockedInputManifestSha256,
    required this.analysisPlanSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.codeSha256,
    required this.environmentSha256,
    required this.dependencyLockSha256,
    required this.deterministicCommand,
    required this.outputSchema,
    required this.randomSeed,
    required this.tolerancePolicySha256,
    required this.expectedResultCommitmentSha256,
    required this.containsExpectedResultValues,
    required this.containsRawParticipantData,
    required this.creatorId,
    required this.creatorAuthorityId,
    required this.createdAtUtc,
    required this.expiresAtUtc,
    required this.resultVisibilityPolicy,
  });

  BlindedReplicationCapsule copyWith({
    String? protocolLedgerSha256,
    String? lastAcceptedProtocolEventSha256,
    String? configurationSha256,
    String? environmentSha256,
    String? expectedResultCommitmentSha256,
    bool? containsExpectedResultValues,
    bool? containsRawParticipantData,
    String? creatorAuthorityId,
    String? expiresAtUtc,
  }) => BlindedReplicationCapsule(
    capsuleId: capsuleId,
    protocolLedgerSha256: protocolLedgerSha256 ?? this.protocolLedgerSha256,
    lastAcceptedProtocolEventSha256:
        lastAcceptedProtocolEventSha256 ?? this.lastAcceptedProtocolEventSha256,
    executionAttestationSha256: executionAttestationSha256,
    lockedInputManifestSha256: lockedInputManifestSha256,
    analysisPlanSha256: analysisPlanSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256: algorithmSourceBundleSha256,
    codeSha256: codeSha256,
    environmentSha256: environmentSha256 ?? this.environmentSha256,
    dependencyLockSha256: dependencyLockSha256,
    deterministicCommand: deterministicCommand,
    outputSchema: outputSchema,
    randomSeed: randomSeed,
    tolerancePolicySha256: tolerancePolicySha256,
    expectedResultCommitmentSha256:
        expectedResultCommitmentSha256 ?? this.expectedResultCommitmentSha256,
    containsExpectedResultValues:
        containsExpectedResultValues ?? this.containsExpectedResultValues,
    containsRawParticipantData:
        containsRawParticipantData ?? this.containsRawParticipantData,
    creatorId: creatorId,
    creatorAuthorityId: creatorAuthorityId ?? this.creatorAuthorityId,
    createdAtUtc: createdAtUtc,
    expiresAtUtc: expiresAtUtc ?? this.expiresAtUtc,
    resultVisibilityPolicy: resultVisibilityPolicy,
  );

  Map<String, Object?> get canonicalPayload => {
    'capsule_id': capsuleId,
    'protocol_ledger_sha256': protocolLedgerSha256,
    'last_accepted_protocol_event_sha256': lastAcceptedProtocolEventSha256,
    'execution_attestation_sha256': executionAttestationSha256,
    'locked_input_manifest_sha256': lockedInputManifestSha256,
    'analysis_plan_sha256': analysisPlanSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'code_sha256': codeSha256,
    'environment_sha256': environmentSha256,
    'dependency_lock_sha256': dependencyLockSha256,
    'deterministic_command': deterministicCommand,
    'output_schema': outputSchema,
    'random_seed': randomSeed,
    'tolerance_policy_sha256': tolerancePolicySha256,
    'expected_result_commitment_sha256': expectedResultCommitmentSha256,
    'contains_expected_result_values': containsExpectedResultValues,
    'contains_raw_participant_data': containsRawParticipantData,
    'creator_id': creatorId,
    'creator_authority_id': creatorAuthorityId,
    'created_at_utc': createdAtUtc,
    'expires_at_utc': expiresAtUtc,
    'result_visibility_policy': resultVisibilityPolicy,
  };

  String get capsuleSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'capsule_sha256': capsuleSha256,
  };
}

final class BlindedExpectedResultCustody {
  final String custodianId;
  final String custodianAuthorityId;
  final String capsuleSha256;
  final String commitmentSalt;
  final List<ReplicationOutcomeRecord> expectedOutcomes;
  final String sealedAtUtc;
  final String releasedAtUtc;

  BlindedExpectedResultCustody({
    required this.custodianId,
    required this.custodianAuthorityId,
    required this.capsuleSha256,
    required this.commitmentSalt,
    required List<ReplicationOutcomeRecord> expectedOutcomes,
    required this.sealedAtUtc,
    required this.releasedAtUtc,
  }) : expectedOutcomes = List.unmodifiable(expectedOutcomes);

  BlindedExpectedResultCustody copyWith({
    String? capsuleSha256,
    String? custodianId,
    String? custodianAuthorityId,
    String? commitmentSalt,
    List<ReplicationOutcomeRecord>? expectedOutcomes,
    String? releasedAtUtc,
  }) => BlindedExpectedResultCustody(
    custodianId: custodianId ?? this.custodianId,
    custodianAuthorityId: custodianAuthorityId ?? this.custodianAuthorityId,
    capsuleSha256: capsuleSha256 ?? this.capsuleSha256,
    commitmentSalt: commitmentSalt ?? this.commitmentSalt,
    expectedOutcomes: expectedOutcomes ?? this.expectedOutcomes,
    sealedAtUtc: sealedAtUtc,
    releasedAtUtc: releasedAtUtc ?? this.releasedAtUtc,
  );

  String get commitmentSha256 => _sha256({
    'salt': commitmentSalt,
    'outcomes': expectedOutcomes.map((item) => item.toJson()).toList()
      ..sort(
        (left, right) => (left['outcome_id']! as String).compareTo(
          right['outcome_id']! as String,
        ),
      ),
  });

  Map<String, Object?> toJson() => {
    'custodian_id': custodianId,
    'custodian_authority_id': custodianAuthorityId,
    'capsule_sha256': capsuleSha256,
    'commitment_salt': commitmentSalt,
    'expected_outcomes': expectedOutcomes.map((item) => item.toJson()).toList(),
    'sealed_at_utc': sealedAtUtc,
    'released_at_utc': releasedAtUtc,
    'commitment_sha256': commitmentSha256,
  };
}

final class IndependentReplicationResponse {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String responseId;
  final String predecessorResponseSha256;
  final String capsuleSha256;
  final String replicatorId;
  final String replicatorAuthorityId;
  final String replicatorOrganizationId;
  final bool independentlyAuthorized;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final String codeSha256;
  final String environmentSha256;
  final String dependencyLockSha256;
  final String deterministicCommand;
  final String outputSchema;
  final int randomSeed;
  final List<ReplicationOutcomeRecord> outcomes;
  final String startedAtUtc;
  final String finalizedAtUtc;
  final int monotonicStartMicros;
  final int monotonicEndMicros;
  final bool expectedResultsAccessedBeforeFinalization;
  final bool rawParticipantDataAccessed;
  final bool privacyBoundedLogs;
  final bool completeExecution;
  final String reviewerId;
  final String syntheticSignatureSha256;

  IndependentReplicationResponse({
    required this.sequence,
    required this.responseId,
    required this.predecessorResponseSha256,
    required this.capsuleSha256,
    required this.replicatorId,
    required this.replicatorAuthorityId,
    required this.replicatorOrganizationId,
    required this.independentlyAuthorized,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.codeSha256,
    required this.environmentSha256,
    required this.dependencyLockSha256,
    required this.deterministicCommand,
    required this.outputSchema,
    required this.randomSeed,
    required List<ReplicationOutcomeRecord> outcomes,
    required this.startedAtUtc,
    required this.finalizedAtUtc,
    required this.monotonicStartMicros,
    required this.monotonicEndMicros,
    required this.expectedResultsAccessedBeforeFinalization,
    required this.rawParticipantDataAccessed,
    required this.privacyBoundedLogs,
    required this.completeExecution,
    required this.reviewerId,
    required this.syntheticSignatureSha256,
  }) : outcomes = List.unmodifiable(outcomes);

  IndependentReplicationResponse copyWith({
    int? sequence,
    String? predecessorResponseSha256,
    String? capsuleSha256,
    String? replicatorId,
    String? replicatorAuthorityId,
    String? replicatorOrganizationId,
    bool? independentlyAuthorized,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    String? codeSha256,
    String? environmentSha256,
    String? dependencyLockSha256,
    String? deterministicCommand,
    String? outputSchema,
    int? randomSeed,
    List<ReplicationOutcomeRecord>? outcomes,
    String? startedAtUtc,
    String? finalizedAtUtc,
    int? monotonicStartMicros,
    int? monotonicEndMicros,
    bool? expectedResultsAccessedBeforeFinalization,
    bool? rawParticipantDataAccessed,
    bool? privacyBoundedLogs,
    bool? completeExecution,
    String? reviewerId,
    String? syntheticSignatureSha256,
  }) => IndependentReplicationResponse(
    sequence: sequence ?? this.sequence,
    responseId: responseId,
    predecessorResponseSha256:
        predecessorResponseSha256 ?? this.predecessorResponseSha256,
    capsuleSha256: capsuleSha256 ?? this.capsuleSha256,
    replicatorId: replicatorId ?? this.replicatorId,
    replicatorAuthorityId: replicatorAuthorityId ?? this.replicatorAuthorityId,
    replicatorOrganizationId:
        replicatorOrganizationId ?? this.replicatorOrganizationId,
    independentlyAuthorized:
        independentlyAuthorized ?? this.independentlyAuthorized,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    codeSha256: codeSha256 ?? this.codeSha256,
    environmentSha256: environmentSha256 ?? this.environmentSha256,
    dependencyLockSha256: dependencyLockSha256 ?? this.dependencyLockSha256,
    deterministicCommand: deterministicCommand ?? this.deterministicCommand,
    outputSchema: outputSchema ?? this.outputSchema,
    randomSeed: randomSeed ?? this.randomSeed,
    outcomes: outcomes ?? this.outcomes,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    finalizedAtUtc: finalizedAtUtc ?? this.finalizedAtUtc,
    monotonicStartMicros: monotonicStartMicros ?? this.monotonicStartMicros,
    monotonicEndMicros: monotonicEndMicros ?? this.monotonicEndMicros,
    expectedResultsAccessedBeforeFinalization:
        expectedResultsAccessedBeforeFinalization ??
        this.expectedResultsAccessedBeforeFinalization,
    rawParticipantDataAccessed:
        rawParticipantDataAccessed ?? this.rawParticipantDataAccessed,
    privacyBoundedLogs: privacyBoundedLogs ?? this.privacyBoundedLogs,
    completeExecution: completeExecution ?? this.completeExecution,
    reviewerId: reviewerId ?? this.reviewerId,
    syntheticSignatureSha256:
        syntheticSignatureSha256 ?? this.syntheticSignatureSha256,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'response_id': responseId,
    'predecessor_response_sha256': predecessorResponseSha256,
    'capsule_sha256': capsuleSha256,
    'replicator_id': replicatorId,
    'replicator_authority_id': replicatorAuthorityId,
    'replicator_organization_id': replicatorOrganizationId,
    'independently_authorized': independentlyAuthorized,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'code_sha256': codeSha256,
    'environment_sha256': environmentSha256,
    'dependency_lock_sha256': dependencyLockSha256,
    'deterministic_command': deterministicCommand,
    'output_schema': outputSchema,
    'random_seed': randomSeed,
    'outcomes': outcomes.map((item) => item.toJson()).toList()
      ..sort(
        (left, right) => (left['outcome_id']! as String).compareTo(
          right['outcome_id']! as String,
        ),
      ),
    'started_at_utc': startedAtUtc,
    'finalized_at_utc': finalizedAtUtc,
    'monotonic_start_micros': monotonicStartMicros,
    'monotonic_end_micros': monotonicEndMicros,
    'expected_results_accessed_before_finalization':
        expectedResultsAccessedBeforeFinalization,
    'raw_participant_data_accessed': rawParticipantDataAccessed,
    'privacy_bounded_logs': privacyBoundedLogs,
    'complete_execution': completeExecution,
    'reviewer_id': reviewerId,
    'synthetic_signature_sha256': syntheticSignatureSha256,
  };

  String get responseSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'response_sha256': responseSha256,
  };
}

final class ReplicationDiscrepancy {
  final ReplicationDiscrepancyClass classification;
  final String field;
  final String expected;
  final String observed;

  const ReplicationDiscrepancy({
    required this.classification,
    required this.field,
    required this.expected,
    required this.observed,
  });

  Map<String, Object?> toJson() => {
    'classification': classification.name,
    'field': field,
    'expected': expected,
    'observed': observed,
  };
}

final class ReplicationAdjudicationEvent {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String eventId;
  final String predecessorSha256;
  final String responseSha256;
  final String actorId;
  final String authorityId;
  final ReplicationAdjudicationDecision decision;
  final List<ReplicationDiscrepancyClass> discrepancyClasses;
  final String reason;
  final String occurredAtUtc;
  final bool accepted;

  ReplicationAdjudicationEvent({
    required this.sequence,
    required this.eventId,
    required this.predecessorSha256,
    required this.responseSha256,
    required this.actorId,
    required this.authorityId,
    required this.decision,
    required List<ReplicationDiscrepancyClass> discrepancyClasses,
    required this.reason,
    required this.occurredAtUtc,
    required this.accepted,
  }) : discrepancyClasses = List.unmodifiable(discrepancyClasses);

  ReplicationAdjudicationEvent copyWith({
    int? sequence,
    String? predecessorSha256,
    String? responseSha256,
    String? actorId,
    String? authorityId,
    ReplicationAdjudicationDecision? decision,
    List<ReplicationDiscrepancyClass>? discrepancyClasses,
    String? reason,
    String? occurredAtUtc,
    bool? accepted,
  }) => ReplicationAdjudicationEvent(
    sequence: sequence ?? this.sequence,
    eventId: eventId,
    predecessorSha256: predecessorSha256 ?? this.predecessorSha256,
    responseSha256: responseSha256 ?? this.responseSha256,
    actorId: actorId ?? this.actorId,
    authorityId: authorityId ?? this.authorityId,
    decision: decision ?? this.decision,
    discrepancyClasses: discrepancyClasses ?? this.discrepancyClasses,
    reason: reason ?? this.reason,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    accepted: accepted ?? this.accepted,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'event_id': eventId,
    'predecessor_sha256': predecessorSha256,
    'response_sha256': responseSha256,
    'actor_id': actorId,
    'authority_id': authorityId,
    'decision': decision.name,
    'discrepancy_classes': discrepancyClasses.map((item) => item.name).toList()
      ..sort(),
    'reason': reason,
    'occurred_at_utc': occurredAtUtc,
    'accepted': accepted,
  };

  String get eventSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'event_sha256': eventSha256,
  };
}

final class CredibilityBlindedReplicationPackage {
  static const String schema =
      'parkinsum.credibility-blinded-replication-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v9';

  final int schemaVersion;
  final BlindedReplicationCapsule capsule;
  final BlindedExpectedResultCustody custody;
  final List<IndependentReplicationResponse> responses;
  final String comparisonTolerancePolicySha256;
  final String comparisonFinalizedAtUtc;
  final List<ReplicationAdjudicationEvent> adjudicationEvents;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityBlindedReplicationPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.capsule,
    required this.custody,
    required List<IndependentReplicationResponse> responses,
    required this.comparisonTolerancePolicySha256,
    required this.comparisonFinalizedAtUtc,
    required List<ReplicationAdjudicationEvent> adjudicationEvents,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : responses = List.unmodifiable(responses),
       adjudicationEvents = List.unmodifiable(adjudicationEvents);

  factory CredibilityBlindedReplicationPackage.syntheticCurrent({
    required CredibilityProtocolTransparencyLedger protocolLedger,
    required ProtocolTransparencyAssessment protocolAssessment,
    required String executionAttestationSha256,
    required String configurationSha256,
    required String algorithmSourceBundleSha256,
  }) {
    const analysis =
        '805d9c9e94ae708b53da466ed20fda571c93f1583d78f2cfcc9e961f248f4178';
    const code =
        '1419c8bad5986f123b09041bc2bccd82ba2b78adba3cf7f8d09a4950e5524792';
    const environment =
        '4d5ca493d2ef7dcfc9ab5ccae3f4714fb9892175442256bb15a7ec4ce647f4d6';
    const dependencies =
        'e45743cc3b423649d06347a06390790783261bc6546f8b98fb43d83a6a39f0b7';
    const tolerance =
        '765c8a6728388394254ca1073e0f8eb47b767c149e9187a1fe2f91a8b390f56f';
    const salt = 'synthetic-sealed-results-salt-v1';
    const outcomes = <ReplicationOutcomeRecord>[
      ReplicationOutcomeRecord(
        outcomeId: 'outcome.independence_dimensions_clean',
        status: ReplicationOutcomeStatus.reported,
        resultSha256:
            '6f275749b3b66c8d7341af25d3ce79c6f5725326daf99de2994411c90870856d',
        detailCode: 'synthetic_exact_match',
      ),
      ReplicationOutcomeRecord(
        outcomeId: 'outcome.mutation_suite_detected',
        status: ReplicationOutcomeStatus.reported,
        resultSha256:
            'ae859a48e6d4cf39bf5161c298510707fc175d2dfdd9e241b1f57991774b8f80',
        detailCode: 'synthetic_exact_match',
      ),
      ReplicationOutcomeRecord(
        outcomeId: 'outcome.null_fixture_retained',
        status: ReplicationOutcomeStatus.nullResult,
        resultSha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        detailCode: 'synthetic_null_not_omitted',
      ),
      ReplicationOutcomeRecord(
        outcomeId: 'outcome.failed_fixture_retained',
        status: ReplicationOutcomeStatus.failed,
        resultSha256:
            '3f42b2f7f130b56816af080ee7a0d82e3af843c121a2b05e1c59b3fca78cce2f',
        detailCode: 'synthetic_failure_not_omitted',
      ),
      ReplicationOutcomeRecord(
        outcomeId: 'outcome.adverse_fixture_retained',
        status: ReplicationOutcomeStatus.adverse,
        resultSha256:
            '3f1e51849c309ae353144b667f84aaf40b28868649b632f639f92f888b4cf01c',
        detailCode: 'synthetic_adverse_not_omitted',
      ),
    ];
    final commitment = _sha256({
      'salt': salt,
      'outcomes': outcomes.map((item) => item.toJson()).toList()
        ..sort(
          (left, right) => (left['outcome_id']! as String).compareTo(
            right['outcome_id']! as String,
          ),
        ),
    });
    final capsule = BlindedReplicationCapsule(
      capsuleId: 'synthetic-blinded-replication-v1',
      protocolLedgerSha256: protocolLedger.ledgerSha256,
      lastAcceptedProtocolEventSha256:
          protocolAssessment.lastAcceptedEventSha256,
      executionAttestationSha256: executionAttestationSha256,
      lockedInputManifestSha256: protocolLedger.expectedDatasetSha256,
      analysisPlanSha256: analysis,
      configurationSha256: configurationSha256,
      algorithmSourceBundleSha256: algorithmSourceBundleSha256,
      codeSha256: code,
      environmentSha256: environment,
      dependencyLockSha256: dependencies,
      deterministicCommand: 'dart run tool/run_credibility_replication.dart',
      outputSchema: 'parkinsum.synthetic-replication-output/1',
      randomSeed: 20260826,
      tolerancePolicySha256: tolerance,
      expectedResultCommitmentSha256: commitment,
      containsExpectedResultValues: false,
      containsRawParticipantData: false,
      creatorId: 'synthetic-capsule-publisher',
      creatorAuthorityId: 'synthetic-publisher-authority',
      createdAtUtc: '2026-08-18T01:00:00.000Z',
      expiresAtUtc: '2027-08-18T01:00:00.000Z',
      resultVisibilityPolicy: 'sealed_until_response_finalized',
    );
    final response = IndependentReplicationResponse(
      sequence: 1,
      responseId: 'synthetic-independent-response-v1',
      predecessorResponseSha256:
          IndependentReplicationResponse.genesisPredecessor,
      capsuleSha256: capsule.capsuleSha256,
      replicatorId: 'synthetic-external-replicator',
      replicatorAuthorityId: 'synthetic-replication-authority',
      replicatorOrganizationId: 'synthetic-independent-lab',
      independentlyAuthorized: true,
      configurationSha256: configurationSha256,
      algorithmSourceBundleSha256: algorithmSourceBundleSha256,
      codeSha256: code,
      environmentSha256: environment,
      dependencyLockSha256: dependencies,
      deterministicCommand: capsule.deterministicCommand,
      outputSchema: capsule.outputSchema,
      randomSeed: capsule.randomSeed,
      outcomes: outcomes,
      startedAtUtc: '2026-08-18T01:10:00.000Z',
      finalizedAtUtc: '2026-08-18T01:20:00.000Z',
      monotonicStartMicros: 1000000,
      monotonicEndMicros: 1600000,
      expectedResultsAccessedBeforeFinalization: false,
      rawParticipantDataAccessed: false,
      privacyBoundedLogs: true,
      completeExecution: true,
      reviewerId: 'synthetic-independent-reviewer',
      syntheticSignatureSha256:
          '62f0d21a26d5b5c54bed0bf6a9322701ce414862c7aa2491221743e51472296b',
    );
    final custody = BlindedExpectedResultCustody(
      custodianId: 'synthetic-results-custodian',
      custodianAuthorityId: 'synthetic-custody-authority',
      capsuleSha256: capsule.capsuleSha256,
      commitmentSalt: salt,
      expectedOutcomes: outcomes,
      sealedAtUtc: '2026-08-18T01:00:00.000Z',
      releasedAtUtc: '2026-08-18T01:21:00.000Z',
    );
    final adjudication = ReplicationAdjudicationEvent(
      sequence: 1,
      eventId: 'synthetic-agreement-review-v1',
      predecessorSha256: ReplicationAdjudicationEvent.genesisPredecessor,
      responseSha256: response.responseSha256,
      actorId: 'synthetic-independent-adjudicator',
      authorityId: 'synthetic-adjudication-authority',
      decision: ReplicationAdjudicationDecision.agreementAccepted,
      discrepancyClasses: const [],
      reason: 'Synthetic exact agreement reviewed after unblinding.',
      occurredAtUtc: '2026-08-18T01:25:00.000Z',
      accepted: true,
    );
    return CredibilityBlindedReplicationPackage(
      capsule: capsule,
      custody: custody,
      responses: [response],
      comparisonTolerancePolicySha256: tolerance,
      comparisonFinalizedAtUtc: '2026-08-18T01:22:00.000Z',
      adjudicationEvents: [adjudication],
      syntheticDemoOnly: true,
      boundary:
          'This is a deterministic synthetic role-separation fixture. It is '
          'not external scientific replication, dataset representativeness, '
          'model credibility, clinical validation, regulatory acceptance, or '
          'patient-specific safety evidence.',
    );
  }

  CredibilityBlindedReplicationPackage copyWith({
    int? schemaVersion,
    BlindedReplicationCapsule? capsule,
    BlindedExpectedResultCustody? custody,
    List<IndependentReplicationResponse>? responses,
    String? comparisonTolerancePolicySha256,
    String? comparisonFinalizedAtUtc,
    List<ReplicationAdjudicationEvent>? adjudicationEvents,
  }) => CredibilityBlindedReplicationPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    capsule: capsule ?? this.capsule,
    custody: custody ?? this.custody,
    responses: responses ?? this.responses,
    comparisonTolerancePolicySha256:
        comparisonTolerancePolicySha256 ?? this.comparisonTolerancePolicySha256,
    comparisonFinalizedAtUtc:
        comparisonFinalizedAtUtc ?? this.comparisonFinalizedAtUtc,
    adjudicationEvents: adjudicationEvents ?? this.adjudicationEvents,
    syntheticDemoOnly: syntheticDemoOnly,
    boundary: boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'capsule': capsule.toJson(),
    'custody': custody.toJson(),
    'responses': responses.map((item) => item.toJson()).toList(),
    'comparison_tolerance_policy_sha256': comparisonTolerancePolicySha256,
    'comparison_finalized_at_utc': comparisonFinalizedAtUtc,
    'adjudication_events': adjudicationEvents
        .map((item) => item.toJson())
        .toList(),
    'synthetic_demo_only': syntheticDemoOnly,
    'boundary': boundary,
  };

  String get packageSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'package_version': packageVersion,
    ...canonicalPayload,
    'package_sha256': packageSha256,
  };
}

final class BlindedReplicationFinding {
  final BlindedReplicationFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  BlindedReplicationFinding({
    required this.kind,
    required this.detail,
    required List<String> affectedIds,
  }) : affectedIds = List.unmodifiable(affectedIds);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'detail': detail,
    'affected_ids': [...affectedIds]..sort(),
  };
}

final class BlindedReplicationAssessment {
  final CredibilityBlindedReplicationPackage package;
  final BlindedReplicationStatus status;
  final List<BlindedReplicationFinding> findings;
  final List<ReplicationDiscrepancy> discrepancies;
  final int lastAcceptedAdjudicationSequence;
  final String lastAcceptedAdjudicationSha256;

  BlindedReplicationAssessment._({
    required this.package,
    required this.status,
    required List<BlindedReplicationFinding> findings,
    required List<ReplicationDiscrepancy> discrepancies,
    required this.lastAcceptedAdjudicationSequence,
    required this.lastAcceptedAdjudicationSha256,
  }) : findings = List.unmodifiable(findings),
       discrepancies = List.unmodifiable(discrepancies);

  bool get integrityVerified => findings.isEmpty;
  bool get canSupportScientificCredibility => false;

  Map<String, String> get lanes => {
    'capsule':
        findings.any(
          (item) =>
              item.kind == BlindedReplicationFindingKind.schemaUnsupported ||
              item.kind == BlindedReplicationFindingKind.identityMismatch ||
              item.kind == BlindedReplicationFindingKind.malformedDigest ||
              item.kind ==
                  BlindedReplicationFindingKind.expectedValueInCapsule ||
              item.kind ==
                  BlindedReplicationFindingKind.rawParticipantDataIncluded,
        )
        ? 'blocked'
        : 'contentAddressed',
    'blinding':
        findings.any(
          (item) => item.kind == BlindedReplicationFindingKind.blindingBreach,
        )
        ? 'breached'
        : 'sealedUntilFinalization',
    'independentResponse':
        findings.any(
          (item) =>
              item.kind == BlindedReplicationFindingKind.actorNotIndependent ||
              item.kind == BlindedReplicationFindingKind.authorityMissing,
        )
        ? 'blocked'
        : 'roleSeparated',
    'environmentMatch':
        discrepancies.any(
          (item) =>
              item.classification == ReplicationDiscrepancyClass.environment ||
              item.classification == ReplicationDiscrepancyClass.dependency,
        )
        ? 'different'
        : 'matched',
    'comparison': discrepancies.isEmpty ? 'exactAgreement' : 'discrepant',
    'adjudication': status == BlindedReplicationStatus.mechanicallyObserved
        ? 'acceptedSyntheticAgreement'
        : status.name,
  };

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'lanes': lanes,
    'findings': findings.map((item) => item.toJson()).toList(),
    'discrepancies': discrepancies.map((item) => item.toJson()).toList(),
    'last_accepted_adjudication_sequence': lastAcceptedAdjudicationSequence,
    'last_accepted_adjudication_sha256': lastAcceptedAdjudicationSha256,
    'can_support_scientific_credibility': canSupportScientificCredibility,
    'boundary': package.boundary,
  };
}

final class CredibilityBlindedReplicationVerifier {
  const CredibilityBlindedReplicationVerifier();

  BlindedReplicationAssessment verify(
    CredibilityBlindedReplicationPackage package,
  ) {
    final findings = <BlindedReplicationFinding>[];
    _checkCapsule(package, findings);
    _checkResponses(package, findings);
    final discrepancies = _compare(package);
    _checkCustodyAndComparison(package, findings);
    _checkAdjudication(package, discrepancies, findings);

    var lastAcceptedSequence = 0;
    var lastAcceptedSha = ReplicationAdjudicationEvent.genesisPredecessor;
    for (final event in package.adjudicationEvents) {
      if (event.accepted) {
        lastAcceptedSequence = event.sequence;
        lastAcceptedSha = event.eventSha256;
      }
    }
    final revoked = package.adjudicationEvents.any(
      (item) =>
          item.decision == ReplicationAdjudicationDecision.revoked &&
          item.accepted,
    );
    final unknownOnly =
        findings.isNotEmpty &&
        findings.every(
          (item) =>
              item.kind == BlindedReplicationFindingKind.schemaUnsupported ||
              item.kind == BlindedReplicationFindingKind.identityMismatch ||
              item.kind == BlindedReplicationFindingKind.malformedDigest,
        );
    final heldDecision = package.adjudicationEvents.any(
      (item) =>
          !item.accepted ||
          item.decision == ReplicationAdjudicationDecision.discrepancyHeld ||
          item.decision == ReplicationAdjudicationDecision.correctionRequired ||
          item.decision == ReplicationAdjudicationDecision.rerunRequired ||
          item.decision == ReplicationAdjudicationDecision.rejected,
    );
    final status = revoked
        ? BlindedReplicationStatus.revoked
        : findings.isNotEmpty
        ? unknownOnly
              ? BlindedReplicationStatus.unknown
              : BlindedReplicationStatus.violated
        : discrepancies.isNotEmpty || heldDecision
        ? BlindedReplicationStatus.held
        : BlindedReplicationStatus.mechanicallyObserved;
    return BlindedReplicationAssessment._(
      package: package,
      status: status,
      findings: findings,
      discrepancies: discrepancies,
      lastAcceptedAdjudicationSequence: lastAcceptedSequence,
      lastAcceptedAdjudicationSha256: lastAcceptedSha,
    );
  }

  void _checkCapsule(
    CredibilityBlindedReplicationPackage package,
    List<BlindedReplicationFinding> findings,
  ) {
    final capsule = package.capsule;
    if (package.schemaVersion !=
        CredibilityBlindedReplicationPackage.currentSchemaVersion) {
      _add(
        findings,
        BlindedReplicationFindingKind.schemaUnsupported,
        'Unsupported replication package schema.',
        ['${package.schemaVersion}'],
      );
    }
    if (capsule.configurationSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedConfigurationSha256 ||
        capsule.algorithmSourceBundleSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedAlgorithmSourceBundleSha256) {
      _add(
        findings,
        BlindedReplicationFindingKind.identityMismatch,
        'Capsule is not bound to the governed runtime identity.',
        const ['configuration', 'algorithm_source_bundle'],
      );
    }
    for (final entry in <String, String>{
      'protocol_ledger': capsule.protocolLedgerSha256,
      'protocol_event': capsule.lastAcceptedProtocolEventSha256,
      'execution_attestation': capsule.executionAttestationSha256,
      'input_manifest': capsule.lockedInputManifestSha256,
      'analysis_plan': capsule.analysisPlanSha256,
      'configuration': capsule.configurationSha256,
      'source_bundle': capsule.algorithmSourceBundleSha256,
      'code': capsule.codeSha256,
      'environment': capsule.environmentSha256,
      'dependencies': capsule.dependencyLockSha256,
      'tolerance': capsule.tolerancePolicySha256,
      'expected_commitment': capsule.expectedResultCommitmentSha256,
    }.entries) {
      if (!_isSha256(entry.value)) {
        _add(
          findings,
          BlindedReplicationFindingKind.malformedDigest,
          'Malformed ${entry.key} identity.',
          [entry.key],
        );
      }
    }
    if (capsule.containsExpectedResultValues) {
      _add(
        findings,
        BlindedReplicationFindingKind.expectedValueInCapsule,
        'Capsule exposes expected result values before replication.',
        [capsule.capsuleId],
      );
    }
    if (capsule.containsRawParticipantData) {
      _add(
        findings,
        BlindedReplicationFindingKind.rawParticipantDataIncluded,
        'Capsule contains raw participant data without separate authority.',
        [capsule.capsuleId],
      );
    }
    final created = _parseUtc(capsule.createdAtUtc);
    final expires = _parseUtc(capsule.expiresAtUtc);
    if (created == null || expires == null || !expires.isAfter(created)) {
      _add(
        findings,
        BlindedReplicationFindingKind.capsuleExpired,
        'Capsule time window is invalid.',
        [capsule.capsuleId],
      );
    }
    if (capsule.creatorId.trim().isEmpty ||
        capsule.creatorAuthorityId.trim().isEmpty ||
        capsule.deterministicCommand.trim().isEmpty ||
        capsule.outputSchema.trim().isEmpty ||
        capsule.resultVisibilityPolicy != 'sealed_until_response_finalized') {
      _add(
        findings,
        BlindedReplicationFindingKind.authorityMissing,
        'Capsule authority or execution contract is incomplete.',
        [capsule.capsuleId],
      );
    }
  }

  void _checkResponses(
    CredibilityBlindedReplicationPackage package,
    List<BlindedReplicationFinding> findings,
  ) {
    final ids = <String>{};
    final digests = <String>{};
    var predecessor = IndependentReplicationResponse.genesisPredecessor;
    for (var index = 0; index < package.responses.length; index += 1) {
      final response = package.responses[index];
      if (response.sequence != index + 1 ||
          response.predecessorResponseSha256 != predecessor) {
        _add(
          findings,
          BlindedReplicationFindingKind.responseChainBroken,
          'Response lineage is non-contiguous or has a broken predecessor.',
          [response.responseId],
        );
      }
      predecessor = response.responseSha256;
      if (!ids.add(response.responseId) ||
          !digests.add(response.responseSha256)) {
        _add(
          findings,
          BlindedReplicationFindingKind.responseReplay,
          'Response identity or body was replayed.',
          [response.responseId],
        );
      }
      if (response.capsuleSha256 != package.capsule.capsuleSha256) {
        _add(
          findings,
          BlindedReplicationFindingKind.responseBindingMismatch,
          'Response does not bind the exact capsule.',
          [response.responseId],
        );
      }
      if (response.replicatorId == package.capsule.creatorId ||
          response.replicatorId == package.custody.custodianId ||
          response.replicatorOrganizationId.trim().isEmpty ||
          !response.independentlyAuthorized) {
        _add(
          findings,
          BlindedReplicationFindingKind.actorNotIndependent,
          'Replication actor is not separately authorized and role-separated.',
          [response.responseId, response.replicatorId],
        );
      }
      if (response.replicatorAuthorityId.trim().isEmpty ||
          response.reviewerId.trim().isEmpty ||
          !_isSha256(response.syntheticSignatureSha256)) {
        _add(
          findings,
          BlindedReplicationFindingKind.authorityMissing,
          'Replication authority, reviewer or response attestation is missing.',
          [response.responseId],
        );
      }
      if (response.expectedResultsAccessedBeforeFinalization) {
        _add(
          findings,
          BlindedReplicationFindingKind.blindingBreach,
          'Expected results were accessed before response finalization.',
          [response.responseId],
        );
      }
      if (response.rawParticipantDataAccessed) {
        _add(
          findings,
          BlindedReplicationFindingKind.rawParticipantDataIncluded,
          'Replication accessed unauthorized raw participant data.',
          [response.responseId],
        );
      }
      if (!response.privacyBoundedLogs) {
        _add(
          findings,
          BlindedReplicationFindingKind.privacyUnsafeLog,
          'Replication logs are not bounded to reviewed technical fields.',
          [response.responseId],
        );
      }
      if (!response.completeExecution || response.outcomes.isEmpty) {
        _add(
          findings,
          BlindedReplicationFindingKind.partialExecution,
          'Replication execution is partial or has no outcomes.',
          [response.responseId],
        );
      }
      final started = _parseUtc(response.startedAtUtc);
      final finalized = _parseUtc(response.finalizedAtUtc);
      if (started == null ||
          finalized == null ||
          !finalized.isAfter(started) ||
          response.monotonicEndMicros <= response.monotonicStartMicros) {
        _add(
          findings,
          BlindedReplicationFindingKind.invalidClock,
          'UTC or monotonic response order is invalid.',
          [response.responseId],
        );
      }
      final expires = _parseUtc(package.capsule.expiresAtUtc);
      if (finalized != null && expires != null && finalized.isAfter(expires)) {
        _add(
          findings,
          BlindedReplicationFindingKind.capsuleExpired,
          'Replication finalized after capsule expiry.',
          [response.responseId],
        );
      }
    }
    if (package.responses.isEmpty) {
      _add(
        findings,
        BlindedReplicationFindingKind.partialExecution,
        'No independent replication response exists.',
        const [],
      );
    }
  }

  List<ReplicationDiscrepancy> _compare(
    CredibilityBlindedReplicationPackage package,
  ) {
    if (package.responses.isEmpty) return const [];
    final response = package.responses.last;
    final discrepancies = <ReplicationDiscrepancy>[];
    void compare(
      ReplicationDiscrepancyClass classification,
      String field,
      Object expected,
      Object observed,
    ) {
      if (expected == observed) return;
      discrepancies.add(
        ReplicationDiscrepancy(
          classification: classification,
          field: field,
          expected: '$expected',
          observed: '$observed',
        ),
      );
    }

    compare(
      ReplicationDiscrepancyClass.code,
      'configuration_sha256',
      package.capsule.configurationSha256,
      response.configurationSha256,
    );
    compare(
      ReplicationDiscrepancyClass.code,
      'algorithm_source_bundle_sha256',
      package.capsule.algorithmSourceBundleSha256,
      response.algorithmSourceBundleSha256,
    );
    compare(
      ReplicationDiscrepancyClass.code,
      'code_sha256',
      package.capsule.codeSha256,
      response.codeSha256,
    );
    compare(
      ReplicationDiscrepancyClass.environment,
      'environment_sha256',
      package.capsule.environmentSha256,
      response.environmentSha256,
    );
    compare(
      ReplicationDiscrepancyClass.dependency,
      'dependency_lock_sha256',
      package.capsule.dependencyLockSha256,
      response.dependencyLockSha256,
    );
    compare(
      ReplicationDiscrepancyClass.protocol,
      'deterministic_command',
      package.capsule.deterministicCommand,
      response.deterministicCommand,
    );
    compare(
      ReplicationDiscrepancyClass.protocol,
      'output_schema',
      package.capsule.outputSchema,
      response.outputSchema,
    );
    compare(
      ReplicationDiscrepancyClass.stochastic,
      'random_seed',
      package.capsule.randomSeed,
      response.randomSeed,
    );
    final observedById = {
      for (final outcome in response.outcomes) outcome.outcomeId: outcome,
    };
    for (final expected in package.custody.expectedOutcomes) {
      final observed = observedById.remove(expected.outcomeId);
      if (observed == null) {
        discrepancies.add(
          ReplicationDiscrepancy(
            classification: ReplicationDiscrepancyClass.analysis,
            field: 'outcome.${expected.outcomeId}',
            expected: expected.status.name,
            observed: ReplicationOutcomeStatus.missing.name,
          ),
        );
        continue;
      }
      compare(
        ReplicationDiscrepancyClass.analysis,
        'outcome.${expected.outcomeId}.status',
        expected.status.name,
        observed.status.name,
      );
      compare(
        ReplicationDiscrepancyClass.analysis,
        'outcome.${expected.outcomeId}.result_sha256',
        expected.resultSha256,
        observed.resultSha256,
      );
    }
    for (final extra in observedById.values) {
      discrepancies.add(
        ReplicationDiscrepancy(
          classification: ReplicationDiscrepancyClass.unknown,
          field: 'outcome.${extra.outcomeId}',
          expected: 'absent',
          observed: extra.status.name,
        ),
      );
    }
    return discrepancies;
  }

  void _checkCustodyAndComparison(
    CredibilityBlindedReplicationPackage package,
    List<BlindedReplicationFinding> findings,
  ) {
    final custody = package.custody;
    if (custody.capsuleSha256 != package.capsule.capsuleSha256 ||
        custody.commitmentSha256 !=
            package.capsule.expectedResultCommitmentSha256) {
      _add(
        findings,
        BlindedReplicationFindingKind.custodyCommitmentMismatch,
        'Expected-result custody does not open the capsule commitment.',
        [package.capsule.capsuleId],
      );
    }
    if (custody.custodianId.trim().isEmpty ||
        custody.custodianAuthorityId.trim().isEmpty ||
        custody.custodianId == package.capsule.creatorId) {
      _add(
        findings,
        BlindedReplicationFindingKind.actorNotIndependent,
        'Expected-result custodian is missing or not role-separated.',
        [custody.custodianId],
      );
    }
    final sealed = _parseUtc(custody.sealedAtUtc);
    final released = _parseUtc(custody.releasedAtUtc);
    final comparison = _parseUtc(package.comparisonFinalizedAtUtc);
    final latestFinalized = package.responses.isEmpty
        ? null
        : _parseUtc(package.responses.last.finalizedAtUtc);
    if (sealed == null ||
        released == null ||
        comparison == null ||
        latestFinalized == null ||
        released.isBefore(latestFinalized) ||
        comparison.isBefore(released)) {
      _add(
        findings,
        BlindedReplicationFindingKind.blindingBreach,
        'Expected results were not released strictly after response finalization.',
        [package.capsule.capsuleId],
      );
    }
    if (package.comparisonTolerancePolicySha256 !=
        package.capsule.tolerancePolicySha256) {
      _add(
        findings,
        BlindedReplicationFindingKind.tolerancePolicyChanged,
        'Comparison tolerance changed after capsule publication.',
        [package.capsule.capsuleId],
      );
    }
  }

  void _checkAdjudication(
    CredibilityBlindedReplicationPackage package,
    List<ReplicationDiscrepancy> discrepancies,
    List<BlindedReplicationFinding> findings,
  ) {
    var predecessor = ReplicationAdjudicationEvent.genesisPredecessor;
    final responseDigests = package.responses
        .map((item) => item.responseSha256)
        .toSet();
    for (var index = 0; index < package.adjudicationEvents.length; index += 1) {
      final event = package.adjudicationEvents[index];
      if (event.sequence != index + 1 ||
          event.predecessorSha256 != predecessor ||
          !_isUtcTimestamp(event.occurredAtUtc)) {
        _add(
          findings,
          BlindedReplicationFindingKind.adjudicationChainBroken,
          'Adjudication chain is broken, non-contiguous or has invalid time.',
          [event.eventId],
        );
      }
      predecessor = event.eventSha256;
      if (!responseDigests.contains(event.responseSha256) ||
          event.actorId.trim().isEmpty ||
          event.authorityId.trim().isEmpty ||
          event.reason.trim().isEmpty) {
        _add(
          findings,
          BlindedReplicationFindingKind.adjudicationMismatch,
          'Adjudication does not bind an authorized retained response.',
          [event.eventId],
        );
      }
      if (event.decision == ReplicationAdjudicationDecision.agreementAccepted &&
          (discrepancies.isNotEmpty || event.discrepancyClasses.isNotEmpty)) {
        _add(
          findings,
          BlindedReplicationFindingKind.adjudicationMismatch,
          'Agreement was accepted despite unresolved discrepancies.',
          [event.eventId],
        );
      }
      if (event.decision == ReplicationAdjudicationDecision.revoked &&
          event.accepted) {
        _add(
          findings,
          BlindedReplicationFindingKind.revocation,
          'Replication package was explicitly revoked.',
          [event.eventId],
        );
      }
    }
    if (package.adjudicationEvents.isEmpty) {
      _add(
        findings,
        BlindedReplicationFindingKind.adjudicationMismatch,
        'No independent adjudication event exists.',
        const [],
      );
    }
  }

  void _add(
    List<BlindedReplicationFinding> findings,
    BlindedReplicationFindingKind kind,
    String detail,
    List<String> ids,
  ) {
    findings.add(
      BlindedReplicationFinding(kind: kind, detail: detail, affectedIds: ids),
    );
  }
}

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

bool _isSha256(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _isUtcTimestamp(String? value) => _parseUtc(value) != null;

DateTime? _parseUtc(String? value) {
  if (value == null || !value.endsWith('Z')) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.isUtc == true ? parsed : null;
}
