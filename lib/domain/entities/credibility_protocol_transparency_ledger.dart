import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'credibility_evidence_execution_attestation.dart';

enum ProtocolTransparencyEventType {
  initialProtocol,
  amendment,
  deviation,
  correction,
  analysisPlanChange,
  datasetLockTransition,
  endpointChange,
  exclusionChange,
  transformationChange,
  reviewerDecision,
  resultUpdate,
  withdrawal,
  revocation,
}

enum ProtocolActorRole {
  protocolOwner,
  dataCustodian,
  analyst,
  independentReviewer,
  resultsCustodian,
  observer,
}

enum ProtocolReviewDecision { accepted, rejected, disputed, pending }

enum ProtocolOutcomeStatus {
  planned,
  reported,
  postHoc,
  withdrawn,
  notCollected,
  unavailable,
  omitted,
}

enum ProtocolResultVisibility {
  aggregate,
  subgroup,
  nullResult,
  failed,
  contradictory,
  adverse,
}

enum ProtocolTransparencyStatus {
  mechanicallyObserved,
  held,
  unknown,
  violated,
  revoked,
}

enum ProtocolTransparencyFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  duplicateSequence,
  duplicateEvent,
  brokenPredecessor,
  invalidTimestamp,
  clockRegression,
  concurrentChange,
  missingAcknowledgement,
  missingIndependentReview,
  reviewerDisagreement,
  roleEscalation,
  postResultProspectiveClaim,
  resultVisibilityErased,
  resultBeforeDatasetLock,
  correctionHistoryMissing,
  outcomeContractMismatch,
  omittedPlannedOutcome,
  resultBindingMismatch,
  revoked,
}

final class ProtocolOutcomeRecord {
  final String outcomeId;
  final ProtocolOutcomeStatus status;
  final bool originallyPlanned;
  final String analysisPlanSha256;
  final String datasetSha256;
  final String codeSha256;
  final String? resultValueSha256;
  final String reason;
  final String recordedAtUtc;

  const ProtocolOutcomeRecord({
    required this.outcomeId,
    required this.status,
    required this.originallyPlanned,
    required this.analysisPlanSha256,
    required this.datasetSha256,
    required this.codeSha256,
    required this.resultValueSha256,
    required this.reason,
    required this.recordedAtUtc,
  });

  ProtocolOutcomeRecord copyWith({
    ProtocolOutcomeStatus? status,
    bool? originallyPlanned,
    String? analysisPlanSha256,
    String? datasetSha256,
    String? codeSha256,
    String? resultValueSha256,
    String? reason,
    String? recordedAtUtc,
  }) => ProtocolOutcomeRecord(
    outcomeId: outcomeId,
    status: status ?? this.status,
    originallyPlanned: originallyPlanned ?? this.originallyPlanned,
    analysisPlanSha256: analysisPlanSha256 ?? this.analysisPlanSha256,
    datasetSha256: datasetSha256 ?? this.datasetSha256,
    codeSha256: codeSha256 ?? this.codeSha256,
    resultValueSha256: resultValueSha256 ?? this.resultValueSha256,
    reason: reason ?? this.reason,
    recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
  );

  Map<String, Object?> toJson() => {
    'outcome_id': outcomeId,
    'status': status.name,
    'originally_planned': originallyPlanned,
    'analysis_plan_sha256': analysisPlanSha256,
    'dataset_sha256': datasetSha256,
    'code_sha256': codeSha256,
    'result_value_sha256': resultValueSha256,
    'reason': reason,
    'recorded_at_utc': recordedAtUtc,
  };
}

final class ProtocolTransparencyEvent {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String eventId;
  final String predecessorSha256;
  final ProtocolTransparencyEventType type;
  final String authorId;
  final ProtocolActorRole authorRole;
  final String authorityId;
  final String reviewerId;
  final ProtocolReviewDecision reviewDecision;
  final String reason;
  final String occurredAtUtc;
  final String observedAtUtc;
  final List<EvidenceSplitRole> accessedSplits;
  final List<ProtocolResultVisibility> visibleResults;
  final bool assertedProspective;
  final List<String> affectedFactorIds;
  final List<String> affectedOutcomeIds;
  final String analysisPlanSha256;
  final String datasetSha256;
  final String codeSha256;
  final String? supersededValueSha256;
  final String? replacementValueSha256;
  final String? sourceRecordSha256;
  final bool affectsScientificSoundness;
  final bool affectsDataValidity;
  final bool affectsParticipantRights;
  final bool affectsContextOfUse;
  final bool acknowledged;
  final bool accepted;

  ProtocolTransparencyEvent({
    required this.sequence,
    required this.eventId,
    required this.predecessorSha256,
    required this.type,
    required this.authorId,
    required this.authorRole,
    required this.authorityId,
    required this.reviewerId,
    required this.reviewDecision,
    required this.reason,
    required this.occurredAtUtc,
    required this.observedAtUtc,
    required List<EvidenceSplitRole> accessedSplits,
    required List<ProtocolResultVisibility> visibleResults,
    required this.assertedProspective,
    required List<String> affectedFactorIds,
    required List<String> affectedOutcomeIds,
    required this.analysisPlanSha256,
    required this.datasetSha256,
    required this.codeSha256,
    required this.supersededValueSha256,
    required this.replacementValueSha256,
    required this.sourceRecordSha256,
    required this.affectsScientificSoundness,
    required this.affectsDataValidity,
    required this.affectsParticipantRights,
    required this.affectsContextOfUse,
    required this.acknowledged,
    required this.accepted,
  }) : accessedSplits = List.unmodifiable(accessedSplits),
       visibleResults = List.unmodifiable(visibleResults),
       affectedFactorIds = List.unmodifiable(affectedFactorIds),
       affectedOutcomeIds = List.unmodifiable(affectedOutcomeIds);

  ProtocolTransparencyEvent copyWith({
    int? sequence,
    String? predecessorSha256,
    ProtocolTransparencyEventType? type,
    ProtocolActorRole? authorRole,
    String? reviewerId,
    ProtocolReviewDecision? reviewDecision,
    String? reason,
    String? occurredAtUtc,
    String? observedAtUtc,
    List<EvidenceSplitRole>? accessedSplits,
    List<ProtocolResultVisibility>? visibleResults,
    bool? assertedProspective,
    String? analysisPlanSha256,
    String? datasetSha256,
    String? codeSha256,
    String? supersededValueSha256,
    String? replacementValueSha256,
    String? sourceRecordSha256,
    bool? acknowledged,
    bool? accepted,
  }) => ProtocolTransparencyEvent(
    sequence: sequence ?? this.sequence,
    eventId: eventId,
    predecessorSha256: predecessorSha256 ?? this.predecessorSha256,
    type: type ?? this.type,
    authorId: authorId,
    authorRole: authorRole ?? this.authorRole,
    authorityId: authorityId,
    reviewerId: reviewerId ?? this.reviewerId,
    reviewDecision: reviewDecision ?? this.reviewDecision,
    reason: reason ?? this.reason,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    observedAtUtc: observedAtUtc ?? this.observedAtUtc,
    accessedSplits: accessedSplits ?? this.accessedSplits,
    visibleResults: visibleResults ?? this.visibleResults,
    assertedProspective: assertedProspective ?? this.assertedProspective,
    affectedFactorIds: affectedFactorIds,
    affectedOutcomeIds: affectedOutcomeIds,
    analysisPlanSha256: analysisPlanSha256 ?? this.analysisPlanSha256,
    datasetSha256: datasetSha256 ?? this.datasetSha256,
    codeSha256: codeSha256 ?? this.codeSha256,
    supersededValueSha256: supersededValueSha256 ?? this.supersededValueSha256,
    replacementValueSha256:
        replacementValueSha256 ?? this.replacementValueSha256,
    sourceRecordSha256: sourceRecordSha256 ?? this.sourceRecordSha256,
    affectsScientificSoundness: affectsScientificSoundness,
    affectsDataValidity: affectsDataValidity,
    affectsParticipantRights: affectsParticipantRights,
    affectsContextOfUse: affectsContextOfUse,
    acknowledged: acknowledged ?? this.acknowledged,
    accepted: accepted ?? this.accepted,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'event_id': eventId,
    'predecessor_sha256': predecessorSha256,
    'type': type.name,
    'author_id': authorId,
    'author_role': authorRole.name,
    'authority_id': authorityId,
    'reviewer_id': reviewerId,
    'review_decision': reviewDecision.name,
    'reason': reason,
    'occurred_at_utc': occurredAtUtc,
    'observed_at_utc': observedAtUtc,
    'accessed_splits': accessedSplits.map((split) => split.name).toList()
      ..sort(),
    'visible_results': visibleResults.map((result) => result.name).toList()
      ..sort(),
    'asserted_prospective': assertedProspective,
    'affected_factor_ids': [...affectedFactorIds]..sort(),
    'affected_outcome_ids': [...affectedOutcomeIds]..sort(),
    'analysis_plan_sha256': analysisPlanSha256,
    'dataset_sha256': datasetSha256,
    'code_sha256': codeSha256,
    'superseded_value_sha256': supersededValueSha256,
    'replacement_value_sha256': replacementValueSha256,
    'source_record_sha256': sourceRecordSha256,
    'affects_scientific_soundness': affectsScientificSoundness,
    'affects_data_validity': affectsDataValidity,
    'affects_participant_rights': affectsParticipantRights,
    'affects_context_of_use': affectsContextOfUse,
    'acknowledged': acknowledged,
    'accepted': accepted,
  };

  String get eventSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'event_sha256': eventSha256,
  };
}

final class CredibilityProtocolTransparencyLedger {
  static const String schema =
      'parkinsum.credibility-protocol-transparency-ledger/1';
  static const int currentSchemaVersion = 1;
  static const String ledgerVersion = '2026.08.27-v10';

  final int schemaVersion;
  final String ledgerId;
  final String studyId;
  final String releaseId;
  final String prospectivePlanSha256;
  final String executionAttestationSha256;
  final String manifestSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final String expectedAnalysisPlanSha256;
  final String expectedDatasetSha256;
  final String expectedCodeSha256;
  final List<String> plannedOutcomeIds;
  final List<ProtocolTransparencyEvent> events;
  final List<ProtocolOutcomeRecord> outcomes;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityProtocolTransparencyLedger({
    this.schemaVersion = currentSchemaVersion,
    required this.ledgerId,
    required this.studyId,
    required this.releaseId,
    required this.prospectivePlanSha256,
    required this.executionAttestationSha256,
    required this.manifestSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.expectedAnalysisPlanSha256,
    required this.expectedDatasetSha256,
    required this.expectedCodeSha256,
    required List<String> plannedOutcomeIds,
    required List<ProtocolTransparencyEvent> events,
    required List<ProtocolOutcomeRecord> outcomes,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : plannedOutcomeIds = List.unmodifiable(plannedOutcomeIds),
       events = List.unmodifiable(events),
       outcomes = List.unmodifiable(outcomes);

  factory CredibilityProtocolTransparencyLedger.syntheticCurrent({
    required String prospectivePlanSha256,
    required String executionAttestationSha256,
    required String manifestSha256,
    required String configurationSha256,
    required String algorithmSourceBundleSha256,
  }) {
    const analysis =
        '805d9c9e94ae708b53da466ed20fda571c93f1583d78f2cfcc9e961f248f4178';
    const dataset =
        'c567c1c75602923537e2d69bc9b8051f441653578f62deab43c4d912c238a8ea';
    const code =
        '1419c8bad5986f123b09041bc2bccd82ba2b78adba3cf7f8d09a4950e5524792';
    final events = <ProtocolTransparencyEvent>[];
    void append({
      required String id,
      required ProtocolTransparencyEventType type,
      required ProtocolActorRole role,
      required String occurred,
      required List<EvidenceSplitRole> splits,
      required List<ProtocolResultVisibility> visibility,
      required bool prospective,
      required List<String> factors,
      required List<String> outcomeIds,
      String? superseded,
      String? replacement,
      String? source,
      bool soundness = false,
      bool dataValidity = false,
      bool contextOfUse = false,
    }) {
      final sequence = events.length + 1;
      events.add(
        ProtocolTransparencyEvent(
          sequence: sequence,
          eventId: id,
          predecessorSha256: events.isEmpty
              ? ProtocolTransparencyEvent.genesisPredecessor
              : events.last.eventSha256,
          type: type,
          authorId: role == ProtocolActorRole.independentReviewer
              ? 'synthetic-independent-reviewer'
              : 'synthetic-${role.name}',
          authorRole: role,
          authorityId: 'synthetic-governance-authority',
          reviewerId: 'synthetic-independent-reviewer',
          reviewDecision: ProtocolReviewDecision.accepted,
          reason: 'Synthetic fixture event $id with an explicit audit reason.',
          occurredAtUtc: occurred,
          observedAtUtc: occurred,
          accessedSplits: splits,
          visibleResults: visibility,
          assertedProspective: prospective,
          affectedFactorIds: factors,
          affectedOutcomeIds: outcomeIds,
          analysisPlanSha256: analysis,
          datasetSha256: dataset,
          codeSha256: code,
          supersededValueSha256: superseded,
          replacementValueSha256: replacement,
          sourceRecordSha256: source,
          affectsScientificSoundness: soundness,
          affectsDataValidity: dataValidity,
          affectsParticipantRights: false,
          affectsContextOfUse: contextOfUse,
          acknowledged: true,
          accepted: true,
        ),
      );
    }

    append(
      id: 'protocol-baseline-v1',
      type: ProtocolTransparencyEventType.initialProtocol,
      role: ProtocolActorRole.protocolOwner,
      occurred: '2026-08-18T00:05:00.000Z',
      splits: const [],
      visibility: const [],
      prospective: true,
      factors: const ['softwareQualityAssurance'],
      outcomeIds: const [
        'outcome.independence_dimensions_clean',
        'outcome.mutation_suite_detected',
      ],
    );
    append(
      id: 'pre-result-amendment-v1',
      type: ProtocolTransparencyEventType.amendment,
      role: ProtocolActorRole.protocolOwner,
      occurred: '2026-08-18T00:08:00.000Z',
      splits: const [EvidenceSplitRole.fit],
      visibility: const [],
      prospective: true,
      factors: const ['softwareQualityAssurance'],
      outcomeIds: const ['outcome.mutation_suite_detected'],
    );
    append(
      id: 'dataset-lock-v1',
      type: ProtocolTransparencyEventType.datasetLockTransition,
      role: ProtocolActorRole.dataCustodian,
      occurred: '2026-08-18T00:18:00.000Z',
      splits: const [
        EvidenceSplitRole.fit,
        EvidenceSplitRole.tune,
        EvidenceSplitRole.calibration,
        EvidenceSplitRole.comparator,
      ],
      visibility: const [],
      prospective: false,
      factors: const ['comparatorOrValidationData'],
      outcomeIds: const [],
      dataValidity: true,
    );
    append(
      id: 'result-publication-v1',
      type: ProtocolTransparencyEventType.resultUpdate,
      role: ProtocolActorRole.resultsCustodian,
      occurred: '2026-08-18T00:26:00.000Z',
      splits: const [EvidenceSplitRole.lockedTest],
      visibility: const [
        ProtocolResultVisibility.aggregate,
        ProtocolResultVisibility.nullResult,
      ],
      prospective: false,
      factors: const ['comparatorOrValidationData'],
      outcomeIds: const [
        'outcome.independence_dimensions_clean',
        'outcome.mutation_suite_detected',
      ],
    );
    append(
      id: 'attributed-result-correction-v1',
      type: ProtocolTransparencyEventType.correction,
      role: ProtocolActorRole.resultsCustodian,
      occurred: '2026-08-18T00:32:00.000Z',
      splits: const [EvidenceSplitRole.lockedTest],
      visibility: const [ProtocolResultVisibility.aggregate],
      prospective: false,
      factors: const ['calculationVerification'],
      outcomeIds: const ['outcome.mutation_suite_detected'],
      superseded:
          '91cb64a7eda6f456f42f2d9f8d677006043f20a8f6d02d563b8e3d0e0f821ab6',
      replacement:
          'ae859a48e6d4cf39bf5161c298510707fc175d2dfdd9e241b1f57991774b8f80',
      source:
          '9341842814c75cc09cf842a60e7db48851566980840410454c86798379497104',
      dataValidity: true,
    );
    return CredibilityProtocolTransparencyLedger(
      ledgerId: 'synthetic-protocol-transparency-v1',
      studyId: 'synthetic-credibility-study-v1',
      releaseId: 'worktree-synthetic-release',
      prospectivePlanSha256: prospectivePlanSha256,
      executionAttestationSha256: executionAttestationSha256,
      manifestSha256: manifestSha256,
      configurationSha256: configurationSha256,
      algorithmSourceBundleSha256: algorithmSourceBundleSha256,
      expectedAnalysisPlanSha256: analysis,
      expectedDatasetSha256: dataset,
      expectedCodeSha256: code,
      plannedOutcomeIds: const [
        'outcome.independence_dimensions_clean',
        'outcome.mutation_suite_detected',
      ],
      events: events,
      outcomes: const [
        ProtocolOutcomeRecord(
          outcomeId: 'outcome.independence_dimensions_clean',
          status: ProtocolOutcomeStatus.reported,
          originallyPlanned: true,
          analysisPlanSha256: analysis,
          datasetSha256: dataset,
          codeSha256: code,
          resultValueSha256:
              '6f275749b3b66c8d7341af25d3ce79c6f5725326daf99de2994411c90870856d',
          reason: 'Synthetic planned outcome reported, including null state.',
          recordedAtUtc: '2026-08-18T00:26:00.000Z',
        ),
        ProtocolOutcomeRecord(
          outcomeId: 'outcome.mutation_suite_detected',
          status: ProtocolOutcomeStatus.reported,
          originallyPlanned: true,
          analysisPlanSha256: analysis,
          datasetSha256: dataset,
          codeSha256: code,
          resultValueSha256:
              'ae859a48e6d4cf39bf5161c298510707fc175d2dfdd9e241b1f57991774b8f80',
          reason: 'Synthetic planned outcome retained after correction.',
          recordedAtUtc: '2026-08-18T00:32:00.000Z',
        ),
        ProtocolOutcomeRecord(
          outcomeId: 'outcome.observatory_timeline_rendered',
          status: ProtocolOutcomeStatus.postHoc,
          originallyPlanned: false,
          analysisPlanSha256: analysis,
          datasetSha256: dataset,
          codeSha256: code,
          resultValueSha256:
              '35e93d047265dc98743e642bcf2e4a92c08c73d6a078d266ea6742af95cbc889',
          reason: 'Explicitly labelled post-hoc engineering UI outcome.',
          recordedAtUtc: '2026-08-18T00:34:00.000Z',
        ),
      ],
      syntheticDemoOnly: true,
      boundary:
          'This ledger is a deterministic synthetic engineering audit trail. '
          'It is not a clinical trial registry, GCP conformance evidence, '
          'scientific validation, regulatory acceptance, or patient safety.',
    );
  }

  CredibilityProtocolTransparencyLedger copyWith({
    int? schemaVersion,
    List<ProtocolTransparencyEvent>? events,
    List<ProtocolOutcomeRecord>? outcomes,
    String? configurationSha256,
  }) => CredibilityProtocolTransparencyLedger(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    ledgerId: ledgerId,
    studyId: studyId,
    releaseId: releaseId,
    prospectivePlanSha256: prospectivePlanSha256,
    executionAttestationSha256: executionAttestationSha256,
    manifestSha256: manifestSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256: algorithmSourceBundleSha256,
    expectedAnalysisPlanSha256: expectedAnalysisPlanSha256,
    expectedDatasetSha256: expectedDatasetSha256,
    expectedCodeSha256: expectedCodeSha256,
    plannedOutcomeIds: plannedOutcomeIds,
    events: events ?? this.events,
    outcomes: outcomes ?? this.outcomes,
    syntheticDemoOnly: syntheticDemoOnly,
    boundary: boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'ledger_id': ledgerId,
    'study_id': studyId,
    'release_id': releaseId,
    'prospective_plan_sha256': prospectivePlanSha256,
    'execution_attestation_sha256': executionAttestationSha256,
    'manifest_sha256': manifestSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'expected_analysis_plan_sha256': expectedAnalysisPlanSha256,
    'expected_dataset_sha256': expectedDatasetSha256,
    'expected_code_sha256': expectedCodeSha256,
    'planned_outcome_ids': [...plannedOutcomeIds]..sort(),
    'events': events.map((event) => event.toJson()).toList(),
    'outcomes': outcomes.map((outcome) => outcome.toJson()).toList()
      ..sort(
        (left, right) => (left['outcome_id']! as String).compareTo(
          right['outcome_id']! as String,
        ),
      ),
    'synthetic_demo_only': syntheticDemoOnly,
    'boundary': boundary,
  };

  String get ledgerSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'ledger_version': ledgerVersion,
    ...canonicalPayload,
    'ledger_sha256': ledgerSha256,
  };
}

final class ProtocolTransparencyFinding {
  final ProtocolTransparencyFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  ProtocolTransparencyFinding({
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

final class ProtocolTransparencyAssessment {
  final CredibilityProtocolTransparencyLedger ledger;
  final ProtocolTransparencyStatus status;
  final List<ProtocolTransparencyFinding> findings;
  final int lastAcceptedSequence;
  final String lastAcceptedEventSha256;

  ProtocolTransparencyAssessment._({
    required this.ledger,
    required this.status,
    required List<ProtocolTransparencyFinding> findings,
    required this.lastAcceptedSequence,
    required this.lastAcceptedEventSha256,
  }) : findings = List.unmodifiable(findings);

  bool get integrityVerified => findings.isEmpty;
  bool get canClaimGcpConformance => false;

  Map<ProtocolOutcomeStatus, int> get outcomeStatusCounts => {
    for (final status in ProtocolOutcomeStatus.values)
      status: ledger.outcomes
          .where((outcome) => outcome.status == status)
          .length,
  };

  Map<String, Object?> toJson() => {
    'ledger': ledger.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'last_accepted_sequence': lastAcceptedSequence,
    'last_accepted_event_sha256': lastAcceptedEventSha256,
    'outcome_status_counts': {
      for (final entry in outcomeStatusCounts.entries)
        entry.key.name: entry.value,
    },
    'findings': findings.map((finding) => finding.toJson()).toList(),
    'can_claim_gcp_conformance': canClaimGcpConformance,
    'boundary': ledger.boundary,
  };
}

final class CredibilityProtocolTransparencyVerifier {
  const CredibilityProtocolTransparencyVerifier();

  ProtocolTransparencyAssessment verify(
    CredibilityProtocolTransparencyLedger ledger,
  ) {
    final findings = <ProtocolTransparencyFinding>[];
    _checkIdentity(ledger, findings);
    _checkEvents(ledger, findings);
    _checkOutcomes(ledger, findings);

    var lastAcceptedSequence = 0;
    var lastAcceptedDigest = ProtocolTransparencyEvent.genesisPredecessor;
    for (final event in ledger.events) {
      if (event.accepted &&
          event.acknowledged &&
          event.reviewDecision == ProtocolReviewDecision.accepted) {
        lastAcceptedSequence = event.sequence;
        lastAcceptedDigest = event.eventSha256;
      }
    }
    final revoked = ledger.events.any(
      (event) =>
          event.type == ProtocolTransparencyEventType.revocation &&
          event.accepted,
    );
    final held = ledger.events.any(
      (event) =>
          !event.accepted ||
          event.reviewDecision == ProtocolReviewDecision.rejected,
    );
    final unknownOnly =
        findings.isNotEmpty &&
        findings.every(
          (finding) =>
              finding.kind ==
                  ProtocolTransparencyFindingKind.schemaUnsupported ||
              finding.kind ==
                  ProtocolTransparencyFindingKind.identityMismatch ||
              finding.kind == ProtocolTransparencyFindingKind.malformedDigest,
        );
    final status = revoked
        ? ProtocolTransparencyStatus.revoked
        : findings.isNotEmpty
        ? unknownOnly
              ? ProtocolTransparencyStatus.unknown
              : ProtocolTransparencyStatus.violated
        : held
        ? ProtocolTransparencyStatus.held
        : ProtocolTransparencyStatus.mechanicallyObserved;
    return ProtocolTransparencyAssessment._(
      ledger: ledger,
      status: status,
      findings: findings,
      lastAcceptedSequence: lastAcceptedSequence,
      lastAcceptedEventSha256: lastAcceptedDigest,
    );
  }

  void _checkIdentity(
    CredibilityProtocolTransparencyLedger ledger,
    List<ProtocolTransparencyFinding> findings,
  ) {
    if (ledger.schemaVersion !=
        CredibilityProtocolTransparencyLedger.currentSchemaVersion) {
      _add(
        findings,
        ProtocolTransparencyFindingKind.schemaUnsupported,
        'Unsupported ledger schema version.',
        ['${ledger.schemaVersion}'],
      );
    }
    if (ledger.ledgerId.trim().isEmpty ||
        ledger.studyId.trim().isEmpty ||
        ledger.releaseId.trim().isEmpty ||
        ledger.boundary.trim().isEmpty) {
      _add(
        findings,
        ProtocolTransparencyFindingKind.identityMismatch,
        'Required ledger identity is missing.',
        const [],
      );
    }
    final digests = <String, String>{
      'prospective_plan': ledger.prospectivePlanSha256,
      'execution_attestation': ledger.executionAttestationSha256,
      'manifest': ledger.manifestSha256,
      'configuration': ledger.configurationSha256,
      'algorithm_source_bundle': ledger.algorithmSourceBundleSha256,
      'analysis_plan': ledger.expectedAnalysisPlanSha256,
      'dataset': ledger.expectedDatasetSha256,
      'code': ledger.expectedCodeSha256,
    };
    for (final entry in digests.entries) {
      if (!_isSha256(entry.value)) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.malformedDigest,
          'Malformed ${entry.key} identity.',
          [entry.key],
        );
      }
    }
    if (ledger.manifestSha256 !=
            CredibilityEvidenceExecutionAttestation.expectedManifestSha256 ||
        ledger.configurationSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedConfigurationSha256 ||
        ledger.algorithmSourceBundleSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedAlgorithmSourceBundleSha256) {
      _add(
        findings,
        ProtocolTransparencyFindingKind.identityMismatch,
        'Ledger is not bound to the governed runtime identity.',
        const ['manifest', 'configuration', 'algorithm_source_bundle'],
      );
    }
  }

  void _checkEvents(
    CredibilityProtocolTransparencyLedger ledger,
    List<ProtocolTransparencyFinding> findings,
  ) {
    final sequences = <int>{};
    final ids = <String>{};
    final changeTimes = <String>{};
    var predecessor = ProtocolTransparencyEvent.genesisPredecessor;
    DateTime? priorOccurred;
    DateTime? priorObserved;
    var datasetLocked = false;
    var resultSeen = false;
    for (var index = 0; index < ledger.events.length; index += 1) {
      final event = ledger.events[index];
      if (!sequences.add(event.sequence) || event.sequence != index + 1) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.duplicateSequence,
          'Event sequence is duplicate or non-contiguous.',
          [event.eventId],
        );
      }
      if (!ids.add(event.eventId) || event.eventId.trim().isEmpty) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.duplicateEvent,
          'Event identity is duplicate or empty.',
          [event.eventId],
        );
      }
      if (event.predecessorSha256 != predecessor) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.brokenPredecessor,
          'Event predecessor does not match the prior immutable event.',
          [event.eventId],
        );
      }
      predecessor = event.eventSha256;
      final occurred = _parseUtc(event.occurredAtUtc);
      final observed = _parseUtc(event.observedAtUtc);
      if (occurred == null || observed == null || observed.isBefore(occurred)) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.invalidTimestamp,
          'Event UTC time is invalid or observed before occurrence.',
          [event.eventId],
        );
      } else {
        if ((priorOccurred != null && occurred.isBefore(priorOccurred)) ||
            (priorObserved != null && observed.isBefore(priorObserved))) {
          _add(
            findings,
            ProtocolTransparencyFindingKind.clockRegression,
            'Sequence-authoritative time regressed and cannot rewrite status.',
            [event.eventId],
          );
        }
        priorOccurred = occurred;
        priorObserved = observed;
      }
      if (_isPlanChange(event.type) && !changeTimes.add(event.occurredAtUtc)) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.concurrentChange,
          'Concurrent plan changes require an explicit resolved successor.',
          [event.eventId],
        );
      }
      if (!event.acknowledged) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.missingAcknowledgement,
          'Event acknowledgement is incomplete.',
          [event.eventId],
        );
      }
      if (event.reviewerId.trim().isEmpty ||
          event.reviewDecision == ProtocolReviewDecision.pending) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.missingIndependentReview,
          'Independent review is missing or pending.',
          [event.eventId],
        );
      }
      if (event.reviewDecision == ProtocolReviewDecision.disputed) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.reviewerDisagreement,
          'Reviewer disagreement remains unresolved.',
          [event.eventId],
        );
      }
      if (!_roleAllows(event.authorRole, event.type)) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.roleEscalation,
          'Actor role is not authorized for this event type.',
          [event.eventId, event.authorRole.name],
        );
      }
      if (resultSeen && event.assertedProspective) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.postResultProspectiveClaim,
          'A post-result event cannot acquire prospective status.',
          [event.eventId],
        );
      }
      if (resultSeen &&
          event.type != ProtocolTransparencyEventType.revocation &&
          event.visibleResults.isEmpty) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.resultVisibilityErased,
          'Prior result visibility was erased from a successor event.',
          [event.eventId],
        );
      }
      if (event.type == ProtocolTransparencyEventType.datasetLockTransition &&
          event.accepted) {
        datasetLocked = true;
      }
      if (event.type == ProtocolTransparencyEventType.resultUpdate) {
        if (!datasetLocked) {
          _add(
            findings,
            ProtocolTransparencyFindingKind.resultBeforeDatasetLock,
            'Result update occurred before a reviewed dataset lock.',
            [event.eventId],
          );
        }
        resultSeen = true;
      }
      if (event.visibleResults.isNotEmpty) resultSeen = true;
      if (event.type == ProtocolTransparencyEventType.correction &&
          (!_isSha256(event.supersededValueSha256) ||
              !_isSha256(event.replacementValueSha256) ||
              !_isSha256(event.sourceRecordSha256) ||
              event.reason.trim().isEmpty)) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.correctionHistoryMissing,
          'Correction must retain superseded, replacement, source, actor and reason.',
          [event.eventId],
        );
      }
      for (final digest in [
        event.analysisPlanSha256,
        event.datasetSha256,
        event.codeSha256,
      ]) {
        if (!_isSha256(digest)) {
          _add(
            findings,
            ProtocolTransparencyFindingKind.malformedDigest,
            'Event analysis, dataset or code identity is malformed.',
            [event.eventId],
          );
        }
      }
      if (event.type == ProtocolTransparencyEventType.revocation &&
          event.accepted) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.revoked,
          'Ledger was explicitly revoked.',
          [event.eventId],
        );
      }
    }
  }

  void _checkOutcomes(
    CredibilityProtocolTransparencyLedger ledger,
    List<ProtocolTransparencyFinding> findings,
  ) {
    final ids = <String>{};
    final records = <String, ProtocolOutcomeRecord>{};
    for (final outcome in ledger.outcomes) {
      if (!ids.add(outcome.outcomeId) || outcome.outcomeId.trim().isEmpty) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.outcomeContractMismatch,
          'Outcome identity is duplicate or empty.',
          [outcome.outcomeId],
        );
      }
      records[outcome.outcomeId] = outcome;
      if (!_isUtcTimestamp(outcome.recordedAtUtc) ||
          outcome.reason.trim().isEmpty) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.outcomeContractMismatch,
          'Outcome time or reason is missing.',
          [outcome.outcomeId],
        );
      }
      if (outcome.originallyPlanned ==
          (outcome.status == ProtocolOutcomeStatus.postHoc)) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.outcomeContractMismatch,
          'Post-hoc and prospectively planned status are inconsistent.',
          [outcome.outcomeId],
        );
      }
      if (outcome.status == ProtocolOutcomeStatus.reported ||
          outcome.status == ProtocolOutcomeStatus.postHoc) {
        if (outcome.analysisPlanSha256 != ledger.expectedAnalysisPlanSha256 ||
            outcome.datasetSha256 != ledger.expectedDatasetSha256 ||
            outcome.codeSha256 != ledger.expectedCodeSha256 ||
            !_isSha256(outcome.resultValueSha256)) {
          _add(
            findings,
            ProtocolTransparencyFindingKind.resultBindingMismatch,
            'Reported result is not bound to the exact analysis, data and code.',
            [outcome.outcomeId],
          );
        }
      }
      if (outcome.status == ProtocolOutcomeStatus.omitted) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.omittedPlannedOutcome,
          'A planned outcome is explicitly omitted.',
          [outcome.outcomeId],
        );
      }
    }
    if (ledger.plannedOutcomeIds.toSet().length !=
        ledger.plannedOutcomeIds.length) {
      _add(
        findings,
        ProtocolTransparencyFindingKind.outcomeContractMismatch,
        'Planned outcome identity is duplicated.',
        ledger.plannedOutcomeIds,
      );
    }
    for (final id in ledger.plannedOutcomeIds) {
      final outcome = records[id];
      if (outcome == null ||
          !outcome.originallyPlanned ||
          outcome.status == ProtocolOutcomeStatus.planned ||
          outcome.status == ProtocolOutcomeStatus.omitted) {
        _add(
          findings,
          ProtocolTransparencyFindingKind.omittedPlannedOutcome,
          'Planned outcome lacks a transparent terminal status.',
          [id],
        );
      }
    }
  }

  bool _isPlanChange(ProtocolTransparencyEventType type) => switch (type) {
    ProtocolTransparencyEventType.amendment ||
    ProtocolTransparencyEventType.analysisPlanChange ||
    ProtocolTransparencyEventType.endpointChange ||
    ProtocolTransparencyEventType.exclusionChange ||
    ProtocolTransparencyEventType.transformationChange => true,
    _ => false,
  };

  bool _roleAllows(
    ProtocolActorRole role,
    ProtocolTransparencyEventType type,
  ) => switch (type) {
    ProtocolTransparencyEventType.initialProtocol ||
    ProtocolTransparencyEventType.amendment ||
    ProtocolTransparencyEventType.deviation ||
    ProtocolTransparencyEventType.analysisPlanChange ||
    ProtocolTransparencyEventType.endpointChange ||
    ProtocolTransparencyEventType.exclusionChange ||
    ProtocolTransparencyEventType.transformationChange =>
      role == ProtocolActorRole.protocolOwner,
    ProtocolTransparencyEventType.datasetLockTransition =>
      role == ProtocolActorRole.dataCustodian,
    ProtocolTransparencyEventType.correction ||
    ProtocolTransparencyEventType.resultUpdate ||
    ProtocolTransparencyEventType.withdrawal =>
      role == ProtocolActorRole.resultsCustodian,
    ProtocolTransparencyEventType.reviewerDecision ||
    ProtocolTransparencyEventType.revocation =>
      role == ProtocolActorRole.independentReviewer,
  };

  void _add(
    List<ProtocolTransparencyFinding> findings,
    ProtocolTransparencyFindingKind kind,
    String detail,
    List<String> ids,
  ) {
    findings.add(
      ProtocolTransparencyFinding(kind: kind, detail: detail, affectedIds: ids),
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
