import 'dart:convert';

import 'package:crypto/crypto.dart';

enum EvidenceSplitRole { fit, tune, calibration, comparator, lockedTest }

enum EvidenceIndependenceDimension {
  subject,
  relatedSubject,
  site,
  acquisition,
  device,
  sourceRow,
  time,
  preprocessing,
  accessOrder,
  outcomeCompleteness,
}

enum EvidenceIndependenceStatus {
  declared,
  mechanicallyObserved,
  independentlyReviewed,
  unknown,
  violated,
  revoked,
}

enum EvidenceAccessAction {
  planFreeze,
  rawRead,
  transformationFit,
  lockedHoldoutRead,
  resultAccess,
  planAmendment,
}

enum EvidenceLeakageKind {
  duplicateSubject,
  relatedSubjectAcrossSplits,
  siteAcrossSplits,
  acquisitionAcrossSplits,
  deviceAcrossSplits,
  sourceRowAcrossSplits,
  fitRecordAfterCutoff,
  targetDerivedFeature,
  futureDerivedFeature,
  preprocessingFitOutsideDevelopment,
  accessBeforePlanFreeze,
  unauthorizedAccess,
  resultBeforeHoldout,
  resultAwarePlanAmendment,
  selectiveOutcomeOmission,
  malformedIdentity,
}

final class EvidenceDatasetRecord {
  final String recordId;
  final EvidenceSplitRole split;
  final String subjectGroupId;
  final String relatedSubjectGroupId;
  final String siteId;
  final String acquisitionId;
  final String deviceId;
  final String collectedAtUtc;
  final String sourceRowSha256;

  const EvidenceDatasetRecord({
    required this.recordId,
    required this.split,
    required this.subjectGroupId,
    required this.relatedSubjectGroupId,
    required this.siteId,
    required this.acquisitionId,
    required this.deviceId,
    required this.collectedAtUtc,
    required this.sourceRowSha256,
  });

  EvidenceDatasetRecord copyWith({
    EvidenceSplitRole? split,
    String? subjectGroupId,
    String? relatedSubjectGroupId,
    String? siteId,
    String? acquisitionId,
    String? deviceId,
    String? collectedAtUtc,
    String? sourceRowSha256,
  }) => EvidenceDatasetRecord(
    recordId: recordId,
    split: split ?? this.split,
    subjectGroupId: subjectGroupId ?? this.subjectGroupId,
    relatedSubjectGroupId: relatedSubjectGroupId ?? this.relatedSubjectGroupId,
    siteId: siteId ?? this.siteId,
    acquisitionId: acquisitionId ?? this.acquisitionId,
    deviceId: deviceId ?? this.deviceId,
    collectedAtUtc: collectedAtUtc ?? this.collectedAtUtc,
    sourceRowSha256: sourceRowSha256 ?? this.sourceRowSha256,
  );

  Map<String, Object?> toJson() => {
    'record_id': recordId,
    'split': split.name,
    'subject_group_id': subjectGroupId,
    'related_subject_group_id': relatedSubjectGroupId,
    'site_id': siteId,
    'acquisition_id': acquisitionId,
    'device_id': deviceId,
    'collected_at_utc': collectedAtUtc,
    'source_row_sha256': sourceRowSha256,
  };
}

final class EvidenceTransformationStep {
  final String stepId;
  final List<EvidenceSplitRole> fittedOnSplits;
  final bool usesTarget;
  final bool usesFutureInformation;
  final String fittedAtUtc;
  final String implementationSha256;

  EvidenceTransformationStep({
    required this.stepId,
    required List<EvidenceSplitRole> fittedOnSplits,
    required this.usesTarget,
    required this.usesFutureInformation,
    required this.fittedAtUtc,
    required this.implementationSha256,
  }) : fittedOnSplits = List.unmodifiable(fittedOnSplits);

  EvidenceTransformationStep copyWith({
    List<EvidenceSplitRole>? fittedOnSplits,
    bool? usesTarget,
    bool? usesFutureInformation,
  }) => EvidenceTransformationStep(
    stepId: stepId,
    fittedOnSplits: fittedOnSplits ?? this.fittedOnSplits,
    usesTarget: usesTarget ?? this.usesTarget,
    usesFutureInformation: usesFutureInformation ?? this.usesFutureInformation,
    fittedAtUtc: fittedAtUtc,
    implementationSha256: implementationSha256,
  );

  Map<String, Object?> toJson() => {
    'step_id': stepId,
    'fitted_on_splits': fittedOnSplits.map((split) => split.name).toList()
      ..sort(),
    'uses_target': usesTarget,
    'uses_future_information': usesFutureInformation,
    'fitted_at_utc': fittedAtUtc,
    'implementation_sha256': implementationSha256,
  };
}

final class EvidenceAccessEvent {
  final int sequence;
  final String actorId;
  final String role;
  final EvidenceAccessAction action;
  final EvidenceSplitRole? split;
  final String occurredAtUtc;
  final bool authorized;

  const EvidenceAccessEvent({
    required this.sequence,
    required this.actorId,
    required this.role,
    required this.action,
    required this.split,
    required this.occurredAtUtc,
    required this.authorized,
  });

  EvidenceAccessEvent copyWith({
    int? sequence,
    EvidenceAccessAction? action,
    EvidenceSplitRole? split,
    String? occurredAtUtc,
    bool? authorized,
  }) => EvidenceAccessEvent(
    sequence: sequence ?? this.sequence,
    actorId: actorId,
    role: role,
    action: action ?? this.action,
    split: split ?? this.split,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    authorized: authorized ?? this.authorized,
  );

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'actor_id': actorId,
    'role': role,
    'action': action.name,
    'split': split?.name,
    'occurred_at_utc': occurredAtUtc,
    'authorized': authorized,
  };
}

final class EvidenceLeakageFinding {
  final EvidenceLeakageKind kind;
  final EvidenceIndependenceDimension dimension;
  final String detail;
  final List<String> affectedIds;

  EvidenceLeakageFinding({
    required this.kind,
    required this.dimension,
    required this.detail,
    required List<String> affectedIds,
  }) : affectedIds = List.unmodifiable(affectedIds);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'dimension': dimension.name,
    'detail': detail,
    'affected_ids': [...affectedIds]..sort(),
  };
}

final class CredibilityEvidenceExecutionAttestation {
  static const String schema =
      'parkinsum.credibility-evidence-execution-attestation/1';
  static const int schemaVersion = 1;
  static const String attestationVersion = '2026.09.29-v36';
  static const String expectedManifestSha256 =
      '3e560401c21a1fd3eec3ed75e24f8753797e7e8d14f70b495086bb5fe2db0dc7';
  static const String expectedConfigurationSha256 =
      'e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05';
  static const String expectedAlgorithmSourceBundleSha256 =
      '8f05e6ff6ad02ace71b621ea840cb795831d63562ebd91b54ae8139ab999dcc2';

  final String attestationId;
  final String prospectivePlanSha256;
  final String manifestSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final String rawDatasetManifestSha256;
  final String derivedDatasetManifestSha256;
  final String partitionAssignmentSha256;
  final String transformationGraphSha256;
  final String dataCutoffUtc;
  final String planFrozenAtUtc;
  final String executionEnvironment;
  final List<EvidenceDatasetRecord> records;
  final List<EvidenceTransformationStep> transformations;
  final List<EvidenceAccessEvent> accessEvents;
  final List<String> plannedOutcomeIds;
  final List<String> reportedOutcomeIds;
  final List<String> resultArtifactIds;
  final bool syntheticDemoOnly;
  final bool revoked;
  final String? independentReviewer;
  final String? independentlyReviewedAtUtc;
  final List<String> independentReviewArtifactIds;
  final String boundary;

  CredibilityEvidenceExecutionAttestation({
    required this.attestationId,
    required this.prospectivePlanSha256,
    required this.manifestSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.rawDatasetManifestSha256,
    required this.derivedDatasetManifestSha256,
    required this.partitionAssignmentSha256,
    required this.transformationGraphSha256,
    required this.dataCutoffUtc,
    required this.planFrozenAtUtc,
    required this.executionEnvironment,
    required List<EvidenceDatasetRecord> records,
    required List<EvidenceTransformationStep> transformations,
    required List<EvidenceAccessEvent> accessEvents,
    required List<String> plannedOutcomeIds,
    required List<String> reportedOutcomeIds,
    required List<String> resultArtifactIds,
    required this.syntheticDemoOnly,
    required this.revoked,
    required this.independentReviewer,
    required this.independentlyReviewedAtUtc,
    required List<String> independentReviewArtifactIds,
    required this.boundary,
  }) : records = List.unmodifiable(records),
       transformations = List.unmodifiable(transformations),
       accessEvents = List.unmodifiable(accessEvents),
       plannedOutcomeIds = List.unmodifiable(plannedOutcomeIds),
       reportedOutcomeIds = List.unmodifiable(reportedOutcomeIds),
       resultArtifactIds = List.unmodifiable(resultArtifactIds),
       independentReviewArtifactIds = List.unmodifiable(
         independentReviewArtifactIds,
       );

  factory CredibilityEvidenceExecutionAttestation.syntheticCurrent({
    required String prospectivePlanSha256,
    required String manifestSha256,
    required String configurationSha256,
    required String algorithmSourceBundleSha256,
  }) {
    final records = <EvidenceDatasetRecord>[
      _record('fit-a', EvidenceSplitRole.fit, 1, '2026-08-10T10:00:00.000Z'),
      _record('tune-b', EvidenceSplitRole.tune, 2, '2026-08-11T10:00:00.000Z'),
      _record(
        'calibration-c',
        EvidenceSplitRole.calibration,
        3,
        '2026-08-12T10:00:00.000Z',
      ),
      _record(
        'comparator-d',
        EvidenceSplitRole.comparator,
        4,
        '2026-08-13T10:00:00.000Z',
      ),
      _record(
        'locked-test-e',
        EvidenceSplitRole.lockedTest,
        5,
        '2026-08-17T12:00:00.000Z',
      ),
    ];
    final transformations = <EvidenceTransformationStep>[
      EvidenceTransformationStep(
        stepId: 'synthetic-normalization-v1',
        fittedOnSplits: const [EvidenceSplitRole.fit],
        usesTarget: false,
        usesFutureInformation: false,
        fittedAtUtc: '2026-08-18T00:12:00.000Z',
        implementationSha256:
            '1419c8bad5986f123b09041bc2bccd82ba2b78adba3cf7f8d09a4950e5524792',
      ),
    ];
    final access = <EvidenceAccessEvent>[
      const EvidenceAccessEvent(
        sequence: 1,
        actorId: 'synthetic-governance-runner',
        role: 'plan-owner',
        action: EvidenceAccessAction.planFreeze,
        split: null,
        occurredAtUtc: '2026-08-18T00:10:00.000Z',
        authorized: true,
      ),
      const EvidenceAccessEvent(
        sequence: 2,
        actorId: 'synthetic-execution-runner',
        role: 'model-development',
        action: EvidenceAccessAction.rawRead,
        split: EvidenceSplitRole.fit,
        occurredAtUtc: '2026-08-18T00:11:00.000Z',
        authorized: true,
      ),
      const EvidenceAccessEvent(
        sequence: 3,
        actorId: 'synthetic-execution-runner',
        role: 'model-development',
        action: EvidenceAccessAction.transformationFit,
        split: EvidenceSplitRole.fit,
        occurredAtUtc: '2026-08-18T00:12:00.000Z',
        authorized: true,
      ),
      const EvidenceAccessEvent(
        sequence: 4,
        actorId: 'synthetic-holdout-runner',
        role: 'locked-evaluation',
        action: EvidenceAccessAction.lockedHoldoutRead,
        split: EvidenceSplitRole.lockedTest,
        occurredAtUtc: '2026-08-18T00:20:00.000Z',
        authorized: true,
      ),
      const EvidenceAccessEvent(
        sequence: 5,
        actorId: 'synthetic-results-runner',
        role: 'results-custodian',
        action: EvidenceAccessAction.resultAccess,
        split: null,
        occurredAtUtc: '2026-08-18T00:25:00.000Z',
        authorized: true,
      ),
    ];
    return CredibilityEvidenceExecutionAttestation(
      attestationId: 'synthetic-independence-execution-v1',
      prospectivePlanSha256: prospectivePlanSha256,
      manifestSha256: manifestSha256,
      configurationSha256: configurationSha256,
      algorithmSourceBundleSha256: algorithmSourceBundleSha256,
      rawDatasetManifestSha256:
          'c29184d8baa05d5c0313ed93a00cd60bc43f03e9786899958c2254d740e1e4bb',
      derivedDatasetManifestSha256:
          'c567c1c75602923537e2d69bc9b8051f441653578f62deab43c4d912c238a8ea',
      partitionAssignmentSha256: _sha256(
        records.map((record) => record.toJson()).toList(),
      ),
      transformationGraphSha256: _sha256(
        transformations.map((step) => step.toJson()).toList(),
      ),
      dataCutoffUtc: '2026-08-15T23:59:59.000Z',
      planFrozenAtUtc: '2026-08-18T00:10:00.000Z',
      executionEnvironment: 'offline-synthetic-fixture-only',
      records: records,
      transformations: transformations,
      accessEvents: access,
      plannedOutcomeIds: const [
        'outcome.independence_dimensions_clean',
        'outcome.mutation_suite_detected',
      ],
      reportedOutcomeIds: const [
        'outcome.independence_dimensions_clean',
        'outcome.mutation_suite_detected',
      ],
      resultArtifactIds: const [
        'build/credibility_evidence_execution/latest.json',
      ],
      syntheticDemoOnly: true,
      revoked: false,
      independentReviewer: null,
      independentlyReviewedAtUtc: null,
      independentReviewArtifactIds: const [],
      boundary:
          'This attestation covers deterministic synthetic fixtures only. It '
          'does not establish dataset representativeness, scientific or '
          'clinical validity, qualification, regulatory acceptance, or safety. '
          'The v52 release refresh rebinds this synthetic execution fixture '
          'to the release source identity only; retained fixture timestamps do not '
          'attest current-worktree review or evidence coverage.',
    );
  }

  CredibilityEvidenceExecutionAttestation copyWith({
    List<EvidenceDatasetRecord>? records,
    List<EvidenceTransformationStep>? transformations,
    List<EvidenceAccessEvent>? accessEvents,
    List<String>? reportedOutcomeIds,
    bool? revoked,
  }) => CredibilityEvidenceExecutionAttestation(
    attestationId: attestationId,
    prospectivePlanSha256: prospectivePlanSha256,
    manifestSha256: manifestSha256,
    configurationSha256: configurationSha256,
    algorithmSourceBundleSha256: algorithmSourceBundleSha256,
    rawDatasetManifestSha256: rawDatasetManifestSha256,
    derivedDatasetManifestSha256: derivedDatasetManifestSha256,
    partitionAssignmentSha256: records == null
        ? partitionAssignmentSha256
        : _sha256(records.map((record) => record.toJson()).toList()),
    transformationGraphSha256: transformations == null
        ? transformationGraphSha256
        : _sha256(transformations.map((step) => step.toJson()).toList()),
    dataCutoffUtc: dataCutoffUtc,
    planFrozenAtUtc: planFrozenAtUtc,
    executionEnvironment: executionEnvironment,
    records: records ?? this.records,
    transformations: transformations ?? this.transformations,
    accessEvents: accessEvents ?? this.accessEvents,
    plannedOutcomeIds: plannedOutcomeIds,
    reportedOutcomeIds: reportedOutcomeIds ?? this.reportedOutcomeIds,
    resultArtifactIds: resultArtifactIds,
    syntheticDemoOnly: syntheticDemoOnly,
    revoked: revoked ?? this.revoked,
    independentReviewer: independentReviewer,
    independentlyReviewedAtUtc: independentlyReviewedAtUtc,
    independentReviewArtifactIds: independentReviewArtifactIds,
    boundary: boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'attestation_id': attestationId,
    'prospective_plan_sha256': prospectivePlanSha256,
    'manifest_sha256': manifestSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'raw_dataset_manifest_sha256': rawDatasetManifestSha256,
    'derived_dataset_manifest_sha256': derivedDatasetManifestSha256,
    'partition_assignment_sha256': partitionAssignmentSha256,
    'transformation_graph_sha256': transformationGraphSha256,
    'data_cutoff_utc': dataCutoffUtc,
    'plan_frozen_at_utc': planFrozenAtUtc,
    'execution_environment': executionEnvironment,
    'records': records.map((record) => record.toJson()).toList()
      ..sort(
        (left, right) => (left['record_id']! as String).compareTo(
          right['record_id']! as String,
        ),
      ),
    'transformations': transformations.map((step) => step.toJson()).toList()
      ..sort(
        (left, right) =>
            (left['step_id']! as String).compareTo(right['step_id']! as String),
      ),
    'access_events': accessEvents.map((event) => event.toJson()).toList()
      ..sort(
        (left, right) =>
            (left['sequence']! as int).compareTo(right['sequence']! as int),
      ),
    'planned_outcome_ids': [...plannedOutcomeIds]..sort(),
    'reported_outcome_ids': [...reportedOutcomeIds]..sort(),
    'result_artifact_ids': [...resultArtifactIds]..sort(),
    'synthetic_demo_only': syntheticDemoOnly,
    'revoked': revoked,
    'independent_reviewer': independentReviewer,
    'independently_reviewed_at_utc': independentlyReviewedAtUtc,
    'independent_review_artifact_ids': [...independentReviewArtifactIds]
      ..sort(),
    'boundary': boundary,
  };

  String get attestationSha256 => _sha256(canonicalPayload);

  List<String> get integrityReasons {
    final reasons = <String>{};
    if (attestationId.trim().isEmpty ||
        executionEnvironment.trim().isEmpty ||
        boundary.trim().isEmpty) {
      reasons.add('attestation.required_metadata_missing');
    }
    for (final digest in <String, String>{
      'prospective_plan': prospectivePlanSha256,
      'manifest': manifestSha256,
      'configuration': configurationSha256,
      'algorithm_source_bundle': algorithmSourceBundleSha256,
      'raw_dataset_manifest': rawDatasetManifestSha256,
      'derived_dataset_manifest': derivedDatasetManifestSha256,
      'partition_assignment': partitionAssignmentSha256,
      'transformation_graph': transformationGraphSha256,
    }.entries) {
      if (!_isSha256(digest.value)) {
        reasons.add('attestation.${digest.key}_sha256_invalid');
      }
    }
    if (manifestSha256 != expectedManifestSha256) {
      reasons.add('attestation.manifest_identity_mismatch');
    }
    if (configurationSha256 != expectedConfigurationSha256) {
      reasons.add('attestation.configuration_identity_mismatch');
    }
    if (algorithmSourceBundleSha256 != expectedAlgorithmSourceBundleSha256) {
      reasons.add('attestation.algorithm_source_bundle_identity_mismatch');
    }
    if (!_isUtcTimestamp(dataCutoffUtc) || !_isUtcTimestamp(planFrozenAtUtc)) {
      reasons.add('attestation.time_identity_invalid');
    }
    if (partitionAssignmentSha256 !=
        _sha256(records.map((record) => record.toJson()).toList())) {
      reasons.add('attestation.partition_assignment_identity_mismatch');
    }
    if (transformationGraphSha256 !=
        _sha256(transformations.map((step) => step.toJson()).toList())) {
      reasons.add('attestation.transformation_graph_identity_mismatch');
    }
    if (records.isEmpty || transformations.isEmpty || accessEvents.isEmpty) {
      reasons.add('attestation.execution_evidence_empty');
    }
    if (resultArtifactIds.isEmpty || plannedOutcomeIds.isEmpty) {
      reasons.add('attestation.result_contract_empty');
    }
    final recordIds = <String>{};
    for (final record in records) {
      if (!recordIds.add(record.recordId) ||
          record.recordId.trim().isEmpty ||
          record.subjectGroupId.trim().isEmpty ||
          record.relatedSubjectGroupId.trim().isEmpty ||
          record.siteId.trim().isEmpty ||
          record.acquisitionId.trim().isEmpty ||
          record.deviceId.trim().isEmpty ||
          !_isUtcTimestamp(record.collectedAtUtc) ||
          !_isSha256(record.sourceRowSha256)) {
        reasons.add('attestation.record_identity_invalid');
      }
    }
    final sequences = <int>{};
    for (var index = 0; index < accessEvents.length; index += 1) {
      final event = accessEvents[index];
      if (!sequences.add(event.sequence) || event.sequence != index + 1) {
        reasons.add('attestation.access_sequence_invalid');
      }
      if (event.actorId.trim().isEmpty ||
          event.role.trim().isEmpty ||
          !_isUtcTimestamp(event.occurredAtUtc)) {
        reasons.add('attestation.access_event_invalid');
      }
    }
    final hasIndependentReview =
        independentReviewer != null ||
        independentlyReviewedAtUtc != null ||
        independentReviewArtifactIds.isNotEmpty;
    if (hasIndependentReview &&
        (independentReviewer == null ||
            independentReviewer!.trim().isEmpty ||
            !_isUtcTimestamp(independentlyReviewedAtUtc) ||
            independentReviewArtifactIds.isEmpty)) {
      reasons.add('attestation.independent_review_incomplete');
    }
    return List.unmodifiable(reasons.toList()..sort());
  }

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'attestation_version': attestationVersion,
    ...canonicalPayload,
    'attestation_sha256': attestationSha256,
  };
}

final class EvidenceIndependenceAssessment {
  final CredibilityEvidenceExecutionAttestation attestation;
  final List<EvidenceLeakageFinding> findings;
  final Map<EvidenceIndependenceDimension, EvidenceIndependenceStatus>
  dimensionStatuses;
  final EvidenceIndependenceStatus status;

  EvidenceIndependenceAssessment._({
    required this.attestation,
    required List<EvidenceLeakageFinding> findings,
    required Map<EvidenceIndependenceDimension, EvidenceIndependenceStatus>
    dimensionStatuses,
    required this.status,
  }) : findings = List.unmodifiable(findings),
       dimensionStatuses = Map.unmodifiable(dimensionStatuses);

  bool get integrityVerified => attestation.integrityReasons.isEmpty;

  bool get canSupportScientificCredibility =>
      integrityVerified &&
      !attestation.syntheticDemoOnly &&
      status == EvidenceIndependenceStatus.independentlyReviewed;

  Map<String, Object?> toJson() => {
    'attestation': attestation.toJson(),
    'integrity_verified': integrityVerified,
    'status': status.name,
    'dimension_statuses': {
      for (final dimension in EvidenceIndependenceDimension.values)
        dimension.name: dimensionStatuses[dimension]!.name,
    },
    'findings': findings.map((finding) => finding.toJson()).toList(),
    'can_support_scientific_credibility': canSupportScientificCredibility,
    'boundary':
        'A mechanically observed synthetic split is engineering evidence only. '
        'It is not representative data, independent scientific review, model '
        'qualification, regulatory acceptance, or clinical validation.',
  };
}

final class CredibilityEvidenceIndependenceVerifier {
  const CredibilityEvidenceIndependenceVerifier();

  EvidenceIndependenceAssessment verify(
    CredibilityEvidenceExecutionAttestation attestation,
  ) {
    final findings = <EvidenceLeakageFinding>[];
    final integrityReasons = attestation.integrityReasons;
    for (final reason in integrityReasons) {
      findings.add(
        EvidenceLeakageFinding(
          kind: EvidenceLeakageKind.malformedIdentity,
          dimension: EvidenceIndependenceDimension.accessOrder,
          detail: reason,
          affectedIds: const [],
        ),
      );
    }
    _checkSplitCoverage(attestation, findings);
    _checkGroupOverlap(attestation, findings);
    _checkTimeAndTransformations(attestation, findings);
    _checkAccessOrder(attestation, findings);
    _checkOutcomeCompleteness(attestation, findings);

    final violatedDimensions = findings
        .map((finding) => finding.dimension)
        .toSet();
    final cleanStatus =
        attestation.independentReviewer != null &&
            !attestation.syntheticDemoOnly
        ? EvidenceIndependenceStatus.independentlyReviewed
        : EvidenceIndependenceStatus.mechanicallyObserved;
    final hasObservedViolation = findings.any(
      (finding) => finding.kind != EvidenceLeakageKind.malformedIdentity,
    );
    final status = attestation.revoked
        ? EvidenceIndependenceStatus.revoked
        : findings.isNotEmpty
        ? hasObservedViolation
              ? EvidenceIndependenceStatus.violated
              : EvidenceIndependenceStatus.unknown
        : cleanStatus;
    final dimensionStatuses =
        <EvidenceIndependenceDimension, EvidenceIndependenceStatus>{
          for (final dimension in EvidenceIndependenceDimension.values)
            dimension: attestation.revoked
                ? EvidenceIndependenceStatus.revoked
                : status == EvidenceIndependenceStatus.unknown
                ? EvidenceIndependenceStatus.unknown
                : violatedDimensions.contains(dimension)
                ? EvidenceIndependenceStatus.violated
                : cleanStatus,
        };
    return EvidenceIndependenceAssessment._(
      attestation: attestation,
      findings: findings,
      dimensionStatuses: dimensionStatuses,
      status: status,
    );
  }

  void _checkSplitCoverage(
    CredibilityEvidenceExecutionAttestation attestation,
    List<EvidenceLeakageFinding> findings,
  ) {
    final present = attestation.records.map((record) => record.split).toSet();
    for (final role in EvidenceSplitRole.values) {
      if (!present.contains(role)) {
        _add(
          findings,
          EvidenceLeakageKind.malformedIdentity,
          EvidenceIndependenceDimension.subject,
          'Required split ${role.name} is absent.',
          [role.name],
        );
      }
    }
  }

  void _checkGroupOverlap(
    CredibilityEvidenceExecutionAttestation attestation,
    List<EvidenceLeakageFinding> findings,
  ) {
    _findOverlap(
      attestation.records,
      (r) => r.subjectGroupId,
      findings,
      EvidenceLeakageKind.duplicateSubject,
      EvidenceIndependenceDimension.subject,
    );
    _findOverlap(
      attestation.records,
      (r) => r.relatedSubjectGroupId,
      findings,
      EvidenceLeakageKind.relatedSubjectAcrossSplits,
      EvidenceIndependenceDimension.relatedSubject,
    );
    _findOverlap(
      attestation.records,
      (r) => r.siteId,
      findings,
      EvidenceLeakageKind.siteAcrossSplits,
      EvidenceIndependenceDimension.site,
    );
    _findOverlap(
      attestation.records,
      (r) => r.acquisitionId,
      findings,
      EvidenceLeakageKind.acquisitionAcrossSplits,
      EvidenceIndependenceDimension.acquisition,
    );
    _findOverlap(
      attestation.records,
      (r) => r.deviceId,
      findings,
      EvidenceLeakageKind.deviceAcrossSplits,
      EvidenceIndependenceDimension.device,
    );
    _findOverlap(
      attestation.records,
      (r) => r.sourceRowSha256,
      findings,
      EvidenceLeakageKind.sourceRowAcrossSplits,
      EvidenceIndependenceDimension.sourceRow,
    );
  }

  void _findOverlap(
    List<EvidenceDatasetRecord> records,
    String Function(EvidenceDatasetRecord) valueOf,
    List<EvidenceLeakageFinding> findings,
    EvidenceLeakageKind kind,
    EvidenceIndependenceDimension dimension,
  ) {
    final splitsByValue = <String, Set<EvidenceSplitRole>>{};
    final idsByValue = <String, List<String>>{};
    for (final record in records) {
      splitsByValue.putIfAbsent(valueOf(record), () => {}).add(record.split);
      idsByValue.putIfAbsent(valueOf(record), () => []).add(record.recordId);
    }
    for (final entry in splitsByValue.entries) {
      if (entry.value.length > 1) {
        _add(
          findings,
          kind,
          dimension,
          '${dimension.name} identity spans ${entry.value.length} splits.',
          idsByValue[entry.key]!,
        );
      }
    }
  }

  void _checkTimeAndTransformations(
    CredibilityEvidenceExecutionAttestation attestation,
    List<EvidenceLeakageFinding> findings,
  ) {
    final cutoff = DateTime.tryParse(attestation.dataCutoffUtc);
    if (cutoff != null) {
      for (final record in attestation.records.where(
        (record) => record.split != EvidenceSplitRole.lockedTest,
      )) {
        final collected = DateTime.tryParse(record.collectedAtUtc);
        if (collected != null && collected.isAfter(cutoff)) {
          _add(
            findings,
            EvidenceLeakageKind.fitRecordAfterCutoff,
            EvidenceIndependenceDimension.time,
            'Development record was collected after the governed cutoff.',
            [record.recordId],
          );
        }
      }
    }
    for (final step in attestation.transformations) {
      if (step.usesTarget) {
        _add(
          findings,
          EvidenceLeakageKind.targetDerivedFeature,
          EvidenceIndependenceDimension.preprocessing,
          'Transformation consumes the evaluation target.',
          [step.stepId],
        );
      }
      if (step.usesFutureInformation) {
        _add(
          findings,
          EvidenceLeakageKind.futureDerivedFeature,
          EvidenceIndependenceDimension.preprocessing,
          'Transformation consumes future information.',
          [step.stepId],
        );
      }
      if (step.fittedOnSplits.any((split) => split != EvidenceSplitRole.fit)) {
        _add(
          findings,
          EvidenceLeakageKind.preprocessingFitOutsideDevelopment,
          EvidenceIndependenceDimension.preprocessing,
          'Transformation was fitted outside the fit split.',
          [step.stepId],
        );
      }
    }
  }

  void _checkAccessOrder(
    CredibilityEvidenceExecutionAttestation attestation,
    List<EvidenceLeakageFinding> findings,
  ) {
    final frozenAt = DateTime.tryParse(attestation.planFrozenAtUtc);
    DateTime? holdoutAt;
    DateTime? resultAt;
    for (final event in attestation.accessEvents) {
      final occurred = DateTime.tryParse(event.occurredAtUtc);
      if (!event.authorized) {
        _add(
          findings,
          EvidenceLeakageKind.unauthorizedAccess,
          EvidenceIndependenceDimension.accessOrder,
          'An execution access was not authorized.',
          ['${event.sequence}'],
        );
      }
      if (occurred != null &&
          frozenAt != null &&
          event.action != EvidenceAccessAction.planFreeze &&
          occurred.isBefore(frozenAt)) {
        _add(
          findings,
          EvidenceLeakageKind.accessBeforePlanFreeze,
          EvidenceIndependenceDimension.accessOrder,
          'Execution access occurred before the prospective plan freeze.',
          ['${event.sequence}'],
        );
      }
      if (event.action == EvidenceAccessAction.lockedHoldoutRead) {
        holdoutAt = occurred;
      }
      if (event.action == EvidenceAccessAction.resultAccess) {
        resultAt ??= occurred;
      }
      if (event.action == EvidenceAccessAction.planAmendment &&
          resultAt != null &&
          occurred != null &&
          !occurred.isBefore(resultAt)) {
        _add(
          findings,
          EvidenceLeakageKind.resultAwarePlanAmendment,
          EvidenceIndependenceDimension.accessOrder,
          'Plan amendment occurred after result access.',
          ['${event.sequence}'],
        );
      }
    }
    if (resultAt == null || holdoutAt == null || resultAt.isBefore(holdoutAt)) {
      _add(
        findings,
        EvidenceLeakageKind.resultBeforeHoldout,
        EvidenceIndependenceDimension.accessOrder,
        'Result access is missing or precedes the locked holdout read.',
        const [],
      );
    }
  }

  void _checkOutcomeCompleteness(
    CredibilityEvidenceExecutionAttestation attestation,
    List<EvidenceLeakageFinding> findings,
  ) {
    final missing = attestation.plannedOutcomeIds
        .where((outcome) => !attestation.reportedOutcomeIds.contains(outcome))
        .toList();
    if (missing.isNotEmpty) {
      _add(
        findings,
        EvidenceLeakageKind.selectiveOutcomeOmission,
        EvidenceIndependenceDimension.outcomeCompleteness,
        'One or more prospectively planned outcomes are absent.',
        missing,
      );
    }
  }

  void _add(
    List<EvidenceLeakageFinding> findings,
    EvidenceLeakageKind kind,
    EvidenceIndependenceDimension dimension,
    String detail,
    List<String> affectedIds,
  ) {
    findings.add(
      EvidenceLeakageFinding(
        kind: kind,
        dimension: dimension,
        detail: detail,
        affectedIds: affectedIds,
      ),
    );
  }
}

EvidenceDatasetRecord _record(
  String id,
  EvidenceSplitRole split,
  int index,
  String collectedAtUtc,
) => EvidenceDatasetRecord(
  recordId: id,
  split: split,
  subjectGroupId: 'subject-$index',
  relatedSubjectGroupId: 'relationship-$index',
  siteId: 'site-$index',
  acquisitionId: 'acquisition-$index',
  deviceId: 'device-$index',
  collectedAtUtc: collectedAtUtc,
  sourceRowSha256: sha256
      .convert(utf8.encode('synthetic-row-$index'))
      .toString(),
);

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is Iterable) return '[${value.map(_canonicalJson).join(',')}]';
  return jsonEncode(value);
}

bool _isSha256(String? value) =>
    value != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

bool _isUtcTimestamp(String? value) {
  if (value == null || !value.endsWith('Z')) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.isUtc;
}
