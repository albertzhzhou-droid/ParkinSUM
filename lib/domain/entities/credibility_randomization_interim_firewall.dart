import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'credibility_evidence_execution_attestation.dart';
import 'credibility_statistical_analysis.dart';

enum RandomizationMethod { permutedBlockStratified, simple, minimization }

enum RandomizationRole {
  sequenceGenerator,
  enrollmentOperator,
  blindedInvestigator,
  unblindedStatistician,
  dataManager,
  committeeMember,
  sponsor,
  safetyOfficer,
}

enum RandomizationAccessKind {
  contractLock,
  assignmentIssued,
  treatmentIdentityViewed,
  emergencyUnblinding,
  interimDatasetCut,
  interimAnalysis,
  committeeRecommendation,
  sponsorResponse,
  correction,
  revocation,
}

enum InterimRecommendation {
  continueTrial,
  modifyForSafety,
  stopForFutility,
  stopForEfficacy,
  stopForSafety,
  hold,
  revoked,
}

enum RandomizationInterimGovernanceStatus {
  mechanicallyObserved,
  held,
  unknown,
  violated,
  revoked,
}

enum RandomizationInterimFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  contractIncomplete,
  contractNotProspective,
  scheduleCommitmentMismatch,
  seedOrFutureAssignmentExposed,
  predictableOrDuplicateAssignment,
  assignmentChainBroken,
  ineligibleAssignment,
  roleCollapse,
  unauthorizedAccess,
  prematureUnblinding,
  emergencyUnblindingInvalid,
  accessChainBroken,
  committeeIncomplete,
  committeeConflict,
  interimPlanMismatch,
  interimLookReplay,
  alphaSpendingDrift,
  recommendationTampered,
  insufficientQuorum,
  sponsorInterimExposure,
  recommendationOverride,
  decisionChainBroken,
  invalidClock,
  revocation,
}

final class RandomizationContract {
  final String contractId;
  final RandomizationMethod method;
  final List<String> stratumIds;
  final List<int> permittedBlockSizes;
  final String scheduleCommitmentSha256;
  final String seedCommitmentSha256;
  final String generatorVersion;
  final String assignmentServiceSha256;
  final String eligibilityInputSchemaSha256;
  final String concealmentMechanism;
  final String generatorActorId;
  final String enrollmentActorId;
  final String sponsorActorId;
  final String unblindedStatisticianId;
  final String emergencyUnblindingPolicy;
  final String authoredAtUtc;
  final String lockedAtUtc;
  final String firstEnrollmentAtUtc;
  final bool publicArtifactContainsSeed;
  final bool publicArtifactContainsFutureAssignments;

  RandomizationContract({
    required this.contractId,
    required this.method,
    required List<String> stratumIds,
    required List<int> permittedBlockSizes,
    required this.scheduleCommitmentSha256,
    required this.seedCommitmentSha256,
    required this.generatorVersion,
    required this.assignmentServiceSha256,
    required this.eligibilityInputSchemaSha256,
    required this.concealmentMechanism,
    required this.generatorActorId,
    required this.enrollmentActorId,
    required this.sponsorActorId,
    required this.unblindedStatisticianId,
    required this.emergencyUnblindingPolicy,
    required this.authoredAtUtc,
    required this.lockedAtUtc,
    required this.firstEnrollmentAtUtc,
    required this.publicArtifactContainsSeed,
    required this.publicArtifactContainsFutureAssignments,
  }) : stratumIds = List.unmodifiable(stratumIds),
       permittedBlockSizes = List.unmodifiable(permittedBlockSizes);

  RandomizationContract copyWith({
    RandomizationMethod? method,
    List<String>? stratumIds,
    List<int>? permittedBlockSizes,
    String? scheduleCommitmentSha256,
    String? seedCommitmentSha256,
    String? generatorVersion,
    String? assignmentServiceSha256,
    String? eligibilityInputSchemaSha256,
    String? concealmentMechanism,
    String? generatorActorId,
    String? enrollmentActorId,
    String? sponsorActorId,
    String? unblindedStatisticianId,
    String? emergencyUnblindingPolicy,
    String? authoredAtUtc,
    String? lockedAtUtc,
    String? firstEnrollmentAtUtc,
    bool? publicArtifactContainsSeed,
    bool? publicArtifactContainsFutureAssignments,
  }) => RandomizationContract(
    contractId: contractId,
    method: method ?? this.method,
    stratumIds: stratumIds ?? this.stratumIds,
    permittedBlockSizes: permittedBlockSizes ?? this.permittedBlockSizes,
    scheduleCommitmentSha256:
        scheduleCommitmentSha256 ?? this.scheduleCommitmentSha256,
    seedCommitmentSha256: seedCommitmentSha256 ?? this.seedCommitmentSha256,
    generatorVersion: generatorVersion ?? this.generatorVersion,
    assignmentServiceSha256:
        assignmentServiceSha256 ?? this.assignmentServiceSha256,
    eligibilityInputSchemaSha256:
        eligibilityInputSchemaSha256 ?? this.eligibilityInputSchemaSha256,
    concealmentMechanism: concealmentMechanism ?? this.concealmentMechanism,
    generatorActorId: generatorActorId ?? this.generatorActorId,
    enrollmentActorId: enrollmentActorId ?? this.enrollmentActorId,
    sponsorActorId: sponsorActorId ?? this.sponsorActorId,
    unblindedStatisticianId:
        unblindedStatisticianId ?? this.unblindedStatisticianId,
    emergencyUnblindingPolicy:
        emergencyUnblindingPolicy ?? this.emergencyUnblindingPolicy,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    lockedAtUtc: lockedAtUtc ?? this.lockedAtUtc,
    firstEnrollmentAtUtc: firstEnrollmentAtUtc ?? this.firstEnrollmentAtUtc,
    publicArtifactContainsSeed:
        publicArtifactContainsSeed ?? this.publicArtifactContainsSeed,
    publicArtifactContainsFutureAssignments:
        publicArtifactContainsFutureAssignments ??
        this.publicArtifactContainsFutureAssignments,
  );

  Map<String, Object?> toJson() => {
    'contract_id': contractId,
    'method': method.name,
    'stratum_ids': [...stratumIds]..sort(),
    'permitted_block_sizes': [...permittedBlockSizes]..sort(),
    'schedule_commitment_sha256': scheduleCommitmentSha256,
    'seed_commitment_sha256': seedCommitmentSha256,
    'generator_version': generatorVersion,
    'assignment_service_sha256': assignmentServiceSha256,
    'eligibility_input_schema_sha256': eligibilityInputSchemaSha256,
    'concealment_mechanism': concealmentMechanism,
    'generator_actor_id': generatorActorId,
    'enrollment_actor_id': enrollmentActorId,
    'sponsor_actor_id': sponsorActorId,
    'unblinded_statistician_id': unblindedStatisticianId,
    'emergency_unblinding_policy': emergencyUnblindingPolicy,
    'authored_at_utc': authoredAtUtc,
    'locked_at_utc': lockedAtUtc,
    'first_enrollment_at_utc': firstEnrollmentAtUtc,
    'public_artifact_contains_seed': publicArtifactContainsSeed,
    'public_artifact_contains_future_assignments':
        publicArtifactContainsFutureAssignments,
  };
}

final class RandomizationScheduleCustody {
  final String commitmentSalt;
  final String seedSecret;
  final List<String> assignmentCodes;

  RandomizationScheduleCustody({
    required this.commitmentSalt,
    required this.seedSecret,
    required List<String> assignmentCodes,
  }) : assignmentCodes = List.unmodifiable(assignmentCodes);

  RandomizationScheduleCustody copyWith({
    String? commitmentSalt,
    String? seedSecret,
    List<String>? assignmentCodes,
  }) => RandomizationScheduleCustody(
    commitmentSalt: commitmentSalt ?? this.commitmentSalt,
    seedSecret: seedSecret ?? this.seedSecret,
    assignmentCodes: assignmentCodes ?? this.assignmentCodes,
  );

  String get scheduleCommitmentSha256 => _sha256({
    'commitment_salt': commitmentSalt,
    'seed_secret': seedSecret,
    'assignment_codes': assignmentCodes,
  });

  String get seedCommitmentSha256 =>
      _sha256({'commitment_salt': commitmentSalt, 'seed_secret': seedSecret});

  Map<String, Object?> toPublicJson() => {
    'schedule_commitment_sha256': scheduleCommitmentSha256,
    'seed_commitment_sha256': seedCommitmentSha256,
    'assignment_count': assignmentCodes.length,
    'secret_material_exposed': false,
  };
}

final class ConcealedAssignmentEvent {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String assignmentEventId;
  final String predecessorSha256;
  final String opaqueEnrollmentId;
  final String stratumId;
  final String assignmentCode;
  final bool eligibilityVerified;
  final String operatorId;
  final String authorityId;
  final String issuedAtUtc;

  const ConcealedAssignmentEvent({
    required this.sequence,
    required this.assignmentEventId,
    required this.predecessorSha256,
    required this.opaqueEnrollmentId,
    required this.stratumId,
    required this.assignmentCode,
    required this.eligibilityVerified,
    required this.operatorId,
    required this.authorityId,
    required this.issuedAtUtc,
  });

  ConcealedAssignmentEvent copyWith({
    int? sequence,
    String? predecessorSha256,
    String? opaqueEnrollmentId,
    String? stratumId,
    String? assignmentCode,
    bool? eligibilityVerified,
    String? operatorId,
    String? authorityId,
    String? issuedAtUtc,
  }) => ConcealedAssignmentEvent(
    sequence: sequence ?? this.sequence,
    assignmentEventId: assignmentEventId,
    predecessorSha256: predecessorSha256 ?? this.predecessorSha256,
    opaqueEnrollmentId: opaqueEnrollmentId ?? this.opaqueEnrollmentId,
    stratumId: stratumId ?? this.stratumId,
    assignmentCode: assignmentCode ?? this.assignmentCode,
    eligibilityVerified: eligibilityVerified ?? this.eligibilityVerified,
    operatorId: operatorId ?? this.operatorId,
    authorityId: authorityId ?? this.authorityId,
    issuedAtUtc: issuedAtUtc ?? this.issuedAtUtc,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'assignment_event_id': assignmentEventId,
    'predecessor_sha256': predecessorSha256,
    'opaque_enrollment_id': opaqueEnrollmentId,
    'stratum_id': stratumId,
    'assignment_code_sha256': _sha256(assignmentCode),
    'eligibility_verified': eligibilityVerified,
    'operator_id': operatorId,
    'authority_id': authorityId,
    'issued_at_utc': issuedAtUtc,
  };

  String get eventSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'event_sha256': eventSha256,
  };
}

final class RandomizationAccessEvent {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String eventId;
  final String predecessorSha256;
  final RandomizationAccessKind kind;
  final String actorId;
  final RandomizationRole role;
  final String authorityId;
  final String occurredAtUtc;
  final bool treatmentIdentityVisible;
  final bool interimComparativeResultVisible;
  final String purpose;
  final String scope;
  final bool acknowledged;
  final bool accepted;

  const RandomizationAccessEvent({
    required this.sequence,
    required this.eventId,
    required this.predecessorSha256,
    required this.kind,
    required this.actorId,
    required this.role,
    required this.authorityId,
    required this.occurredAtUtc,
    required this.treatmentIdentityVisible,
    required this.interimComparativeResultVisible,
    required this.purpose,
    required this.scope,
    required this.acknowledged,
    required this.accepted,
  });

  RandomizationAccessEvent copyWith({
    int? sequence,
    String? predecessorSha256,
    RandomizationAccessKind? kind,
    String? actorId,
    RandomizationRole? role,
    String? authorityId,
    String? occurredAtUtc,
    bool? treatmentIdentityVisible,
    bool? interimComparativeResultVisible,
    String? purpose,
    String? scope,
    bool? acknowledged,
    bool? accepted,
  }) => RandomizationAccessEvent(
    sequence: sequence ?? this.sequence,
    eventId: eventId,
    predecessorSha256: predecessorSha256 ?? this.predecessorSha256,
    kind: kind ?? this.kind,
    actorId: actorId ?? this.actorId,
    role: role ?? this.role,
    authorityId: authorityId ?? this.authorityId,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    treatmentIdentityVisible:
        treatmentIdentityVisible ?? this.treatmentIdentityVisible,
    interimComparativeResultVisible:
        interimComparativeResultVisible ?? this.interimComparativeResultVisible,
    purpose: purpose ?? this.purpose,
    scope: scope ?? this.scope,
    acknowledged: acknowledged ?? this.acknowledged,
    accepted: accepted ?? this.accepted,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'event_id': eventId,
    'predecessor_sha256': predecessorSha256,
    'kind': kind.name,
    'actor_id': actorId,
    'role': role.name,
    'authority_id': authorityId,
    'occurred_at_utc': occurredAtUtc,
    'treatment_identity_visible': treatmentIdentityVisible,
    'interim_comparative_result_visible': interimComparativeResultVisible,
    'purpose': purpose,
    'scope': scope,
    'acknowledged': acknowledged,
    'accepted': accepted,
  };

  String get eventSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'event_sha256': eventSha256,
  };
}

final class InterimBoundary {
  final int lookNumber;
  final double informationFraction;
  final double cumulativeAlpha;
  final double efficacyBoundary;
  final double futilityBoundary;
  final double safetyBoundary;

  const InterimBoundary({
    required this.lookNumber,
    required this.informationFraction,
    required this.cumulativeAlpha,
    required this.efficacyBoundary,
    required this.futilityBoundary,
    required this.safetyBoundary,
  });

  InterimBoundary copyWith({
    int? lookNumber,
    double? informationFraction,
    double? cumulativeAlpha,
    double? efficacyBoundary,
    double? futilityBoundary,
    double? safetyBoundary,
  }) => InterimBoundary(
    lookNumber: lookNumber ?? this.lookNumber,
    informationFraction: informationFraction ?? this.informationFraction,
    cumulativeAlpha: cumulativeAlpha ?? this.cumulativeAlpha,
    efficacyBoundary: efficacyBoundary ?? this.efficacyBoundary,
    futilityBoundary: futilityBoundary ?? this.futilityBoundary,
    safetyBoundary: safetyBoundary ?? this.safetyBoundary,
  );

  Map<String, Object?> toJson() => {
    'look_number': lookNumber,
    'information_fraction': informationFraction,
    'cumulative_alpha': cumulativeAlpha,
    'efficacy_boundary': efficacyBoundary,
    'futility_boundary': futilityBoundary,
    'safety_boundary': safetyBoundary,
  };
}

final class InterimBoundaryPlan {
  final String planId;
  final String authoredAtUtc;
  final String lockedAtUtc;
  final List<InterimBoundary> boundaries;

  InterimBoundaryPlan({
    required this.planId,
    required this.authoredAtUtc,
    required this.lockedAtUtc,
    required List<InterimBoundary> boundaries,
  }) : boundaries = List.unmodifiable(boundaries);

  InterimBoundaryPlan copyWith({
    String? authoredAtUtc,
    String? lockedAtUtc,
    List<InterimBoundary>? boundaries,
  }) => InterimBoundaryPlan(
    planId: planId,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    lockedAtUtc: lockedAtUtc ?? this.lockedAtUtc,
    boundaries: boundaries ?? this.boundaries,
  );

  Map<String, Object?> get canonicalPayload => {
    'plan_id': planId,
    'authored_at_utc': authoredAtUtc,
    'locked_at_utc': lockedAtUtc,
    'boundaries': boundaries.map((item) => item.toJson()).toList(),
  };

  String get planSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'plan_sha256': planSha256,
  };
}

final class InterimCommitteeMember {
  final String memberId;
  final String authorityId;
  final String expertise;
  final bool independentFromSponsor;
  final bool independentFromInvestigator;
  final bool conflictFree;

  const InterimCommitteeMember({
    required this.memberId,
    required this.authorityId,
    required this.expertise,
    required this.independentFromSponsor,
    required this.independentFromInvestigator,
    required this.conflictFree,
  });

  InterimCommitteeMember copyWith({
    String? authorityId,
    String? expertise,
    bool? independentFromSponsor,
    bool? independentFromInvestigator,
    bool? conflictFree,
  }) => InterimCommitteeMember(
    memberId: memberId,
    authorityId: authorityId ?? this.authorityId,
    expertise: expertise ?? this.expertise,
    independentFromSponsor:
        independentFromSponsor ?? this.independentFromSponsor,
    independentFromInvestigator:
        independentFromInvestigator ?? this.independentFromInvestigator,
    conflictFree: conflictFree ?? this.conflictFree,
  );

  Map<String, Object?> toJson() => {
    'member_id': memberId,
    'authority_id': authorityId,
    'expertise': expertise,
    'independent_from_sponsor': independentFromSponsor,
    'independent_from_investigator': independentFromInvestigator,
    'conflict_free': conflictFree,
  };
}

final class InterimReview {
  final int lookNumber;
  final String datasetCutSha256;
  final String analysisArtifactSha256;
  final String analyzedBy;
  final String occurredAtUtc;
  final double informationFraction;
  final double cumulativeAlphaSpent;
  final double observedStatistic;
  final InterimRecommendation recommendation;
  final String rationale;
  final List<String> votingMemberIds;

  InterimReview({
    required this.lookNumber,
    required this.datasetCutSha256,
    required this.analysisArtifactSha256,
    required this.analyzedBy,
    required this.occurredAtUtc,
    required this.informationFraction,
    required this.cumulativeAlphaSpent,
    required this.observedStatistic,
    required this.recommendation,
    required this.rationale,
    required List<String> votingMemberIds,
  }) : votingMemberIds = List.unmodifiable(votingMemberIds);

  InterimReview copyWith({
    int? lookNumber,
    String? datasetCutSha256,
    String? analysisArtifactSha256,
    String? analyzedBy,
    String? occurredAtUtc,
    double? informationFraction,
    double? cumulativeAlphaSpent,
    double? observedStatistic,
    InterimRecommendation? recommendation,
    String? rationale,
    List<String>? votingMemberIds,
  }) => InterimReview(
    lookNumber: lookNumber ?? this.lookNumber,
    datasetCutSha256: datasetCutSha256 ?? this.datasetCutSha256,
    analysisArtifactSha256:
        analysisArtifactSha256 ?? this.analysisArtifactSha256,
    analyzedBy: analyzedBy ?? this.analyzedBy,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    informationFraction: informationFraction ?? this.informationFraction,
    cumulativeAlphaSpent: cumulativeAlphaSpent ?? this.cumulativeAlphaSpent,
    observedStatistic: observedStatistic ?? this.observedStatistic,
    recommendation: recommendation ?? this.recommendation,
    rationale: rationale ?? this.rationale,
    votingMemberIds: votingMemberIds ?? this.votingMemberIds,
  );

  Map<String, Object?> get canonicalPayload => {
    'look_number': lookNumber,
    'dataset_cut_sha256': datasetCutSha256,
    'analysis_artifact_sha256': analysisArtifactSha256,
    'analyzed_by': analyzedBy,
    'occurred_at_utc': occurredAtUtc,
    'information_fraction': informationFraction,
    'cumulative_alpha_spent': cumulativeAlphaSpent,
    'observed_statistic': observedStatistic,
    'recommendation': recommendation.name,
    'rationale': rationale,
    'voting_member_ids': [...votingMemberIds]..sort(),
  };

  String get reviewSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'review_sha256': reviewSha256,
  };
}

final class SponsorInterimDecision {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String decisionId;
  final String predecessorSha256;
  final String reviewSha256;
  final String actorId;
  final String authorityId;
  final String occurredAtUtc;
  final bool acceptedRecommendation;
  final bool overrideAttempted;
  final String reason;

  const SponsorInterimDecision({
    required this.sequence,
    required this.decisionId,
    required this.predecessorSha256,
    required this.reviewSha256,
    required this.actorId,
    required this.authorityId,
    required this.occurredAtUtc,
    required this.acceptedRecommendation,
    required this.overrideAttempted,
    required this.reason,
  });

  SponsorInterimDecision copyWith({
    int? sequence,
    String? predecessorSha256,
    String? reviewSha256,
    String? actorId,
    String? authorityId,
    String? occurredAtUtc,
    bool? acceptedRecommendation,
    bool? overrideAttempted,
    String? reason,
  }) => SponsorInterimDecision(
    sequence: sequence ?? this.sequence,
    decisionId: decisionId,
    predecessorSha256: predecessorSha256 ?? this.predecessorSha256,
    reviewSha256: reviewSha256 ?? this.reviewSha256,
    actorId: actorId ?? this.actorId,
    authorityId: authorityId ?? this.authorityId,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    acceptedRecommendation:
        acceptedRecommendation ?? this.acceptedRecommendation,
    overrideAttempted: overrideAttempted ?? this.overrideAttempted,
    reason: reason ?? this.reason,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'decision_id': decisionId,
    'predecessor_sha256': predecessorSha256,
    'review_sha256': reviewSha256,
    'actor_id': actorId,
    'authority_id': authorityId,
    'occurred_at_utc': occurredAtUtc,
    'accepted_recommendation': acceptedRecommendation,
    'override_attempted': overrideAttempted,
    'reason': reason,
  };

  String get decisionSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'decision_sha256': decisionSha256,
  };
}

final class CredibilityRandomizationInterimPackage {
  static const String schema =
      'parkinsum.credibility-randomization-interim-firewall-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v7';

  final int schemaVersion;
  final String packageId;
  final CredibilityStatisticalAnalysisPackage statisticalPackage;
  final String statisticalPackageSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final RandomizationContract contract;
  final RandomizationScheduleCustody custody;
  final List<ConcealedAssignmentEvent> assignments;
  final InterimBoundaryPlan boundaryPlan;
  final List<InterimCommitteeMember> committeeMembers;
  final List<InterimReview> interimReviews;
  final List<RandomizationAccessEvent> accessEvents;
  final List<SponsorInterimDecision> sponsorDecisions;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityRandomizationInterimPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.statisticalPackage,
    required this.statisticalPackageSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.contract,
    required this.custody,
    required List<ConcealedAssignmentEvent> assignments,
    required this.boundaryPlan,
    required List<InterimCommitteeMember> committeeMembers,
    required List<InterimReview> interimReviews,
    required List<RandomizationAccessEvent> accessEvents,
    required List<SponsorInterimDecision> sponsorDecisions,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : assignments = List.unmodifiable(assignments),
       committeeMembers = List.unmodifiable(committeeMembers),
       interimReviews = List.unmodifiable(interimReviews),
       accessEvents = List.unmodifiable(accessEvents),
       sponsorDecisions = List.unmodifiable(sponsorDecisions);

  factory CredibilityRandomizationInterimPackage.syntheticCurrent({
    required CredibilityStatisticalAnalysisPackage statisticalPackage,
    required String configurationSha256,
    required String algorithmSourceBundleSha256,
  }) {
    final custody = RandomizationScheduleCustody(
      commitmentSalt: 'synthetic-randomization-custody-salt-v1',
      seedSecret: 'synthetic-secret-seed-never-in-public-artifact-v1',
      assignmentCodes: const [
        'synthetic-code-A91',
        'synthetic-code-B42',
        'synthetic-code-B73',
        'synthetic-code-A64',
      ],
    );
    final contract = RandomizationContract(
      contractId: 'synthetic-randomization-contract-v1',
      method: RandomizationMethod.permutedBlockStratified,
      stratumIds: const ['synthetic-stratum-low', 'synthetic-stratum-high'],
      permittedBlockSizes: const [4, 6],
      scheduleCommitmentSha256: custody.scheduleCommitmentSha256,
      seedCommitmentSha256: custody.seedCommitmentSha256,
      generatorVersion: 'synthetic-csprng-generator/1',
      assignmentServiceSha256:
          '2635b2b2493778972c139872a6f8d66819bace115118f2c47a4da905704f1301',
      eligibilityInputSchemaSha256:
          '0806f6f7c35b42ec1641956e95ead25b30e6710c9ff792ac50d1d805a817710e',
      concealmentMechanism:
          'opaque sequential code released only after eligibility lock',
      generatorActorId: 'synthetic-sequence-generator',
      enrollmentActorId: 'synthetic-enrollment-operator',
      sponsorActorId: 'synthetic-sponsor-decision-authority',
      unblindedStatisticianId: 'synthetic-unblinded-statistician',
      emergencyUnblindingPolicy:
          'safety-only, minimum scope, attributed reason, prompt review',
      authoredAtUtc: '2026-08-18T03:00:00.000Z',
      lockedAtUtc: '2026-08-18T03:10:00.000Z',
      firstEnrollmentAtUtc: '2026-08-18T04:00:00.000Z',
      publicArtifactContainsSeed: false,
      publicArtifactContainsFutureAssignments: false,
    );
    final assignments = <ConcealedAssignmentEvent>[];
    var predecessor = ConcealedAssignmentEvent.genesisPredecessor;
    for (var index = 0; index < custody.assignmentCodes.length; index += 1) {
      final event = ConcealedAssignmentEvent(
        sequence: index + 1,
        assignmentEventId: 'synthetic-assignment-${index + 1}',
        predecessorSha256: predecessor,
        opaqueEnrollmentId: 'synthetic-enrollment-${index + 1}',
        stratumId: index.isEven
            ? 'synthetic-stratum-low'
            : 'synthetic-stratum-high',
        assignmentCode: custody.assignmentCodes[index],
        eligibilityVerified: true,
        operatorId: contract.enrollmentActorId,
        authorityId: 'synthetic-enrollment-authority',
        issuedAtUtc: '2026-08-18T0${4 + index}:00:00.000Z',
      );
      assignments.add(event);
      predecessor = event.eventSha256;
    }
    final boundaryPlan = InterimBoundaryPlan(
      planId: 'synthetic-obrien-fleming-like-plan-v1',
      authoredAtUtc: '2026-08-18T03:00:00.000Z',
      lockedAtUtc: '2026-08-18T03:10:00.000Z',
      boundaries: const [
        InterimBoundary(
          lookNumber: 1,
          informationFraction: 0.50,
          cumulativeAlpha: 0.01,
          efficacyBoundary: 2.80,
          futilityBoundary: 0.20,
          safetyBoundary: 0.15,
        ),
        InterimBoundary(
          lookNumber: 2,
          informationFraction: 1.00,
          cumulativeAlpha: 0.05,
          efficacyBoundary: 1.98,
          futilityBoundary: 0.00,
          safetyBoundary: 0.10,
        ),
      ],
    );
    const members = [
      InterimCommitteeMember(
        memberId: 'synthetic-committee-clinician',
        authorityId: 'synthetic-independent-committee-authority',
        expertise: 'clinical domain review fixture',
        independentFromSponsor: true,
        independentFromInvestigator: true,
        conflictFree: true,
      ),
      InterimCommitteeMember(
        memberId: 'synthetic-committee-statistician',
        authorityId: 'synthetic-independent-committee-authority',
        expertise: 'independent statistical review fixture',
        independentFromSponsor: true,
        independentFromInvestigator: true,
        conflictFree: true,
      ),
      InterimCommitteeMember(
        memberId: 'synthetic-committee-safety',
        authorityId: 'synthetic-independent-committee-authority',
        expertise: 'safety review fixture',
        independentFromSponsor: true,
        independentFromInvestigator: true,
        conflictFree: true,
      ),
    ];
    final review = InterimReview(
      lookNumber: 1,
      datasetCutSha256:
          '57e4125cad3f0795a866635611673e4179bf78ea55de43caf889dd80f20b40ae',
      analysisArtifactSha256:
          'ce8e72a41746e129b00c7d41835b94c8f6a39911955cf9cf4ad0d18b555c7877',
      analyzedBy: contract.unblindedStatisticianId,
      occurredAtUtc: '2026-08-18T08:20:00.000Z',
      informationFraction: 0.50,
      cumulativeAlphaSpent: 0.01,
      observedStatistic: 0.85,
      recommendation: InterimRecommendation.continueTrial,
      rationale:
          'Synthetic boundary not crossed; recommendation contains no numeric interim payload.',
      votingMemberIds: members.map((item) => item.memberId).toList(),
    );
    final accessEvents = <RandomizationAccessEvent>[];
    var accessPredecessor = RandomizationAccessEvent.genesisPredecessor;
    void addAccess(RandomizationAccessEvent event) {
      accessEvents.add(event);
      accessPredecessor = event.eventSha256;
    }

    addAccess(
      RandomizationAccessEvent(
        sequence: 1,
        eventId: 'synthetic-randomization-lock',
        predecessorSha256: accessPredecessor,
        kind: RandomizationAccessKind.contractLock,
        actorId: contract.generatorActorId,
        role: RandomizationRole.sequenceGenerator,
        authorityId: 'synthetic-randomization-authority',
        occurredAtUtc: contract.lockedAtUtc,
        treatmentIdentityVisible: true,
        interimComparativeResultVisible: false,
        purpose: 'Generate and seal the synthetic assignment schedule.',
        scope: 'schedule custody only',
        acknowledged: true,
        accepted: true,
      ),
    );
    for (var index = 0; index < assignments.length; index += 1) {
      addAccess(
        RandomizationAccessEvent(
          sequence: accessEvents.length + 1,
          eventId: 'synthetic-assignment-access-${index + 1}',
          predecessorSha256: accessPredecessor,
          kind: RandomizationAccessKind.assignmentIssued,
          actorId: contract.enrollmentActorId,
          role: RandomizationRole.enrollmentOperator,
          authorityId: 'synthetic-enrollment-authority',
          occurredAtUtc: assignments[index].issuedAtUtc,
          treatmentIdentityVisible: false,
          interimComparativeResultVisible: false,
          purpose: 'Release only the next opaque assignment code.',
          scope: assignments[index].assignmentEventId,
          acknowledged: true,
          accepted: true,
        ),
      );
    }
    addAccess(
      RandomizationAccessEvent(
        sequence: accessEvents.length + 1,
        eventId: 'synthetic-interim-dataset-cut',
        predecessorSha256: accessPredecessor,
        kind: RandomizationAccessKind.interimDatasetCut,
        actorId: 'synthetic-interim-data-manager',
        role: RandomizationRole.dataManager,
        authorityId: 'synthetic-interim-data-authority',
        occurredAtUtc: '2026-08-18T08:00:00.000Z',
        treatmentIdentityVisible: false,
        interimComparativeResultVisible: false,
        purpose:
            'Create the prospectively planned first synthetic interim cut.',
        scope: review.datasetCutSha256,
        acknowledged: true,
        accepted: true,
      ),
    );
    addAccess(
      RandomizationAccessEvent(
        sequence: accessEvents.length + 1,
        eventId: 'synthetic-interim-analysis',
        predecessorSha256: accessPredecessor,
        kind: RandomizationAccessKind.interimAnalysis,
        actorId: contract.unblindedStatisticianId,
        role: RandomizationRole.unblindedStatistician,
        authorityId: 'synthetic-interim-statistical-authority',
        occurredAtUtc: review.occurredAtUtc,
        treatmentIdentityVisible: true,
        interimComparativeResultVisible: true,
        purpose: 'Execute the locked first-look synthetic analysis.',
        scope: review.analysisArtifactSha256,
        acknowledged: true,
        accepted: true,
      ),
    );
    addAccess(
      RandomizationAccessEvent(
        sequence: accessEvents.length + 1,
        eventId: 'synthetic-committee-recommendation',
        predecessorSha256: accessPredecessor,
        kind: RandomizationAccessKind.committeeRecommendation,
        actorId: members.first.memberId,
        role: RandomizationRole.committeeMember,
        authorityId: members.first.authorityId,
        occurredAtUtc: '2026-08-18T08:40:00.000Z',
        treatmentIdentityVisible: true,
        interimComparativeResultVisible: true,
        purpose: 'Record the independent synthetic committee recommendation.',
        scope: review.reviewSha256,
        acknowledged: true,
        accepted: true,
      ),
    );
    addAccess(
      RandomizationAccessEvent(
        sequence: accessEvents.length + 1,
        eventId: 'synthetic-sponsor-response',
        predecessorSha256: accessPredecessor,
        kind: RandomizationAccessKind.sponsorResponse,
        actorId: contract.sponsorActorId,
        role: RandomizationRole.sponsor,
        authorityId: 'synthetic-sponsor-authority',
        occurredAtUtc: '2026-08-18T09:00:00.000Z',
        treatmentIdentityVisible: false,
        interimComparativeResultVisible: false,
        purpose: 'Accept the recommendation without receiving interim values.',
        scope: review.reviewSha256,
        acknowledged: true,
        accepted: true,
      ),
    );
    final decision = SponsorInterimDecision(
      sequence: 1,
      decisionId: 'synthetic-sponsor-decision-1',
      predecessorSha256: SponsorInterimDecision.genesisPredecessor,
      reviewSha256: review.reviewSha256,
      actorId: contract.sponsorActorId,
      authorityId: 'synthetic-sponsor-authority',
      occurredAtUtc: '2026-08-18T09:00:00.000Z',
      acceptedRecommendation: true,
      overrideAttempted: false,
      reason:
          'Synthetic committee recommendation accepted without data access.',
    );
    return CredibilityRandomizationInterimPackage(
      packageId: 'synthetic-randomization-interim-firewall-v1',
      statisticalPackage: statisticalPackage,
      statisticalPackageSha256: statisticalPackage.packageSha256,
      configurationSha256: configurationSha256,
      algorithmSourceBundleSha256: algorithmSourceBundleSha256,
      contract: contract,
      custody: custody,
      assignments: assignments,
      boundaryPlan: boundaryPlan,
      committeeMembers: members,
      interimReviews: [review],
      accessEvents: accessEvents,
      sponsorDecisions: [decision],
      revoked: false,
      syntheticDemoOnly: true,
      boundary:
          'This is a deterministic synthetic randomization and interim-access governance fixture. '
          'It does not conduct a trial, prove allocation concealment in practice, establish committee independence, '
          'demonstrate GCP compliance, create scientific or clinical validity, show benefit or safety, or provide medical advice.',
    );
  }

  CredibilityRandomizationInterimPackage copyWith({
    int? schemaVersion,
    CredibilityStatisticalAnalysisPackage? statisticalPackage,
    String? statisticalPackageSha256,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    RandomizationContract? contract,
    RandomizationScheduleCustody? custody,
    List<ConcealedAssignmentEvent>? assignments,
    InterimBoundaryPlan? boundaryPlan,
    List<InterimCommitteeMember>? committeeMembers,
    List<InterimReview>? interimReviews,
    List<RandomizationAccessEvent>? accessEvents,
    List<SponsorInterimDecision>? sponsorDecisions,
    bool? revoked,
  }) => CredibilityRandomizationInterimPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    statisticalPackage: statisticalPackage ?? this.statisticalPackage,
    statisticalPackageSha256:
        statisticalPackageSha256 ?? this.statisticalPackageSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    contract: contract ?? this.contract,
    custody: custody ?? this.custody,
    assignments: assignments ?? this.assignments,
    boundaryPlan: boundaryPlan ?? this.boundaryPlan,
    committeeMembers: committeeMembers ?? this.committeeMembers,
    interimReviews: interimReviews ?? this.interimReviews,
    accessEvents: accessEvents ?? this.accessEvents,
    sponsorDecisions: sponsorDecisions ?? this.sponsorDecisions,
    revoked: revoked ?? this.revoked,
    syntheticDemoOnly: syntheticDemoOnly,
    boundary: boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'package_id': packageId,
    'statistical_package_sha256': statisticalPackageSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'contract': contract.toJson(),
    'custody_public_commitment': custody.toPublicJson(),
    'assignments': assignments.map((item) => item.toJson()).toList(),
    'boundary_plan': boundaryPlan.toJson(),
    'committee_members': committeeMembers.map((item) => item.toJson()).toList(),
    'interim_reviews': interimReviews.map((item) => item.toJson()).toList(),
    'access_events': accessEvents.map((item) => item.toJson()).toList(),
    'sponsor_decisions': sponsorDecisions.map((item) => item.toJson()).toList(),
    'revoked': revoked,
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

final class RandomizationInterimFinding {
  final RandomizationInterimFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  RandomizationInterimFinding({
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

final class RandomizationInterimGovernanceAssessment {
  final CredibilityRandomizationInterimPackage package;
  final RandomizationInterimGovernanceStatus status;
  final List<RandomizationInterimFinding> findings;

  RandomizationInterimGovernanceAssessment._({
    required this.package,
    required this.status,
    required List<RandomizationInterimFinding> findings,
  }) : findings = List.unmodifiable(findings);

  bool get integrityVerified => findings.isEmpty;
  bool get canSupportGcpConformance => false;

  Map<String, String> get lanes => {
    'randomizationIdentity':
        findings.any(
          (item) =>
              item.kind == RandomizationInterimFindingKind.identityMismatch ||
              item.kind == RandomizationInterimFindingKind.contractIncomplete,
        )
        ? 'blocked'
        : 'contentAddressed',
    'concealment':
        findings.any(
          (item) =>
              item.kind ==
                  RandomizationInterimFindingKind.scheduleCommitmentMismatch ||
              item.kind ==
                  RandomizationInterimFindingKind
                      .seedOrFutureAssignmentExposed ||
              item.kind ==
                  RandomizationInterimFindingKind
                      .predictableOrDuplicateAssignment,
        )
        ? 'breached'
        : 'sealedNextAssignmentOnly',
    'roleSeparation':
        findings.any(
          (item) =>
              item.kind == RandomizationInterimFindingKind.roleCollapse ||
              item.kind == RandomizationInterimFindingKind.committeeConflict,
        )
        ? 'collapsed'
        : 'independentSyntheticRoles',
    'accessHistory':
        findings.any(
          (item) =>
              item.kind == RandomizationInterimFindingKind.unauthorizedAccess ||
              item.kind == RandomizationInterimFindingKind.accessChainBroken ||
              item.kind ==
                  RandomizationInterimFindingKind.prematureUnblinding ||
              item.kind ==
                  RandomizationInterimFindingKind.sponsorInterimExposure,
        )
        ? 'blocked'
        : 'appendOnlyMinimumScope',
    'interimBoundaries':
        findings.any(
          (item) =>
              item.kind ==
                  RandomizationInterimFindingKind.interimPlanMismatch ||
              item.kind == RandomizationInterimFindingKind.interimLookReplay ||
              item.kind == RandomizationInterimFindingKind.alphaSpendingDrift,
        )
        ? 'drifted'
        : 'prospectivelyLocked',
    'committeeRecommendation':
        findings.any(
          (item) =>
              item.kind ==
                  RandomizationInterimFindingKind.committeeIncomplete ||
              item.kind == RandomizationInterimFindingKind.insufficientQuorum ||
              item.kind ==
                  RandomizationInterimFindingKind.recommendationTampered,
        )
        ? 'blocked'
        : package.interimReviews.isEmpty
        ? 'missing'
        : package.interimReviews.last.recommendation.name,
    'adjudication':
        package.accessEvents.any((item) => !item.accepted) ||
            package.sponsorDecisions.any((item) => !item.acceptedRecommendation)
        ? 'held'
        : findings.any(
            (item) =>
                item.kind ==
                    RandomizationInterimFindingKind.recommendationOverride ||
                item.kind ==
                    RandomizationInterimFindingKind.decisionChainBroken,
          )
        ? 'blocked'
        : 'acceptedWithoutInterimDisclosure',
  };

  Map<String, int> get counts => {
    'assignments': package.assignments.length,
    'accessEvents': package.accessEvents.length,
    'plannedLooks': package.boundaryPlan.boundaries.length,
    'completedLooks': package.interimReviews.length,
    'committeeMembers': package.committeeMembers.length,
    'emergencyUnblinding': package.accessEvents
        .where(
          (item) => item.kind == RandomizationAccessKind.emergencyUnblinding,
        )
        .length,
  };

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'lanes': lanes,
    'counts': counts,
    'findings': findings.map((item) => item.toJson()).toList(),
    'can_support_gcp_conformance': canSupportGcpConformance,
    'boundary': package.boundary,
  };
}

final class CredibilityRandomizationInterimVerifier {
  const CredibilityRandomizationInterimVerifier();

  RandomizationInterimGovernanceAssessment verify(
    CredibilityRandomizationInterimPackage package,
  ) {
    final findings = <RandomizationInterimFinding>[];
    _checkIdentity(package, findings);
    _checkContractAndAssignments(package, findings);
    _checkCommittee(package, findings);
    _checkAccess(package, findings);
    _checkInterim(package, findings);
    _checkDecisions(package, findings);
    if (package.revoked ||
        package.accessEvents.any(
          (item) => item.kind == RandomizationAccessKind.revocation,
        ) ||
        package.interimReviews.any(
          (item) => item.recommendation == InterimRecommendation.revoked,
        )) {
      _add(
        findings,
        RandomizationInterimFindingKind.revocation,
        'Randomization or interim-governance package was revoked.',
        [package.packageId],
      );
    }
    final unknownOnly =
        findings.isNotEmpty &&
        findings.every(
          (item) =>
              item.kind == RandomizationInterimFindingKind.schemaUnsupported ||
              item.kind == RandomizationInterimFindingKind.identityMismatch ||
              item.kind == RandomizationInterimFindingKind.malformedDigest,
        );
    final held =
        package.accessEvents.any((item) => !item.accepted) ||
        package.sponsorDecisions.any(
          (item) => !item.acceptedRecommendation && !item.overrideAttempted,
        ) ||
        package.interimReviews.any(
          (item) => item.recommendation == InterimRecommendation.hold,
        );
    final status =
        findings.any(
          (item) => item.kind == RandomizationInterimFindingKind.revocation,
        )
        ? RandomizationInterimGovernanceStatus.revoked
        : findings.isNotEmpty
        ? unknownOnly
              ? RandomizationInterimGovernanceStatus.unknown
              : RandomizationInterimGovernanceStatus.violated
        : held
        ? RandomizationInterimGovernanceStatus.held
        : RandomizationInterimGovernanceStatus.mechanicallyObserved;
    return RandomizationInterimGovernanceAssessment._(
      package: package,
      status: status,
      findings: findings,
    );
  }

  void _checkIdentity(
    CredibilityRandomizationInterimPackage package,
    List<RandomizationInterimFinding> findings,
  ) {
    if (package.schemaVersion !=
        CredibilityRandomizationInterimPackage.currentSchemaVersion) {
      _add(
        findings,
        RandomizationInterimFindingKind.schemaUnsupported,
        'Unsupported randomization/interim package schema.',
        ['${package.schemaVersion}'],
      );
    }
    if (package.configurationSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedConfigurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedAlgorithmSourceBundleSha256 ||
        package.statisticalPackage.configurationSha256 !=
            package.configurationSha256 ||
        package.statisticalPackage.algorithmSourceBundleSha256 !=
            package.algorithmSourceBundleSha256 ||
        package.statisticalPackage.packageSha256 !=
            package.statisticalPackageSha256) {
      _add(
        findings,
        RandomizationInterimFindingKind.identityMismatch,
        'Package is not bound to the governed statistical and runtime identities.',
        const ['statistics', 'configuration', 'algorithm_source_bundle'],
      );
    }
    for (final entry in <String, String>{
      'statistical_package': package.statisticalPackageSha256,
      'configuration': package.configurationSha256,
      'source_bundle': package.algorithmSourceBundleSha256,
      'assignment_service': package.contract.assignmentServiceSha256,
      'eligibility_schema': package.contract.eligibilityInputSchemaSha256,
    }.entries) {
      if (!_isSha256(entry.value)) {
        _add(
          findings,
          RandomizationInterimFindingKind.malformedDigest,
          'Malformed ${entry.key} identity.',
          [entry.key],
        );
      }
    }
  }

  void _checkContractAndAssignments(
    CredibilityRandomizationInterimPackage package,
    List<RandomizationInterimFinding> findings,
  ) {
    final contract = package.contract;
    final authored = _parseUtc(contract.authoredAtUtc);
    final locked = _parseUtc(contract.lockedAtUtc);
    final firstEnrollment = _parseUtc(contract.firstEnrollmentAtUtc);
    final required = [
      contract.contractId,
      contract.generatorVersion,
      contract.concealmentMechanism,
      contract.generatorActorId,
      contract.enrollmentActorId,
      contract.sponsorActorId,
      contract.unblindedStatisticianId,
      contract.emergencyUnblindingPolicy,
    ];
    if (required.any((item) => item.trim().isEmpty) ||
        contract.stratumIds.isEmpty ||
        contract.stratumIds.toSet().length != contract.stratumIds.length ||
        contract.permittedBlockSizes.isEmpty ||
        contract.permittedBlockSizes.any((item) => item < 2 || item.isOdd)) {
      _add(
        findings,
        RandomizationInterimFindingKind.contractIncomplete,
        'Randomization contract, strata, blocks, or roles are incomplete.',
        [contract.contractId],
      );
    }
    if (authored == null ||
        locked == null ||
        firstEnrollment == null ||
        locked.isBefore(authored) ||
        !firstEnrollment.isAfter(locked)) {
      _add(
        findings,
        RandomizationInterimFindingKind.contractNotProspective,
        'Randomization contract was not locked before first enrollment.',
        [contract.contractId],
      );
    }
    if (contract.publicArtifactContainsSeed ||
        contract.publicArtifactContainsFutureAssignments) {
      _add(
        findings,
        RandomizationInterimFindingKind.seedOrFutureAssignmentExposed,
        'Seed or future assignments were exposed in a public artifact.',
        [contract.contractId],
      );
    }
    if (contract.scheduleCommitmentSha256 !=
            package.custody.scheduleCommitmentSha256 ||
        contract.seedCommitmentSha256 != package.custody.seedCommitmentSha256 ||
        package.custody.commitmentSalt.trim().isEmpty ||
        package.custody.seedSecret.length < 24) {
      _add(
        findings,
        RandomizationInterimFindingKind.scheduleCommitmentMismatch,
        'Concealed schedule or seed commitment cannot be opened.',
        [contract.contractId],
      );
    }
    if (contract.generatorActorId == contract.enrollmentActorId ||
        contract.generatorActorId == contract.sponsorActorId ||
        contract.generatorActorId == contract.unblindedStatisticianId ||
        contract.enrollmentActorId == contract.sponsorActorId ||
        contract.enrollmentActorId == contract.unblindedStatisticianId) {
      _add(
        findings,
        RandomizationInterimFindingKind.roleCollapse,
        'Sequence generation, enrollment, sponsor, and interim statistics roles overlap.',
        [
          contract.generatorActorId,
          contract.enrollmentActorId,
          contract.sponsorActorId,
          contract.unblindedStatisticianId,
        ],
      );
    }
    if (package.custody.assignmentCodes.length != package.assignments.length ||
        package.custody.assignmentCodes.toSet().length !=
            package.custody.assignmentCodes.length ||
        package.custody.assignmentCodes.any((item) => item.length < 8)) {
      _add(
        findings,
        RandomizationInterimFindingKind.predictableOrDuplicateAssignment,
        'Concealed schedule is incomplete, duplicate, or trivially predictable.',
        [contract.contractId],
      );
    }
    var predecessor = ConcealedAssignmentEvent.genesisPredecessor;
    DateTime? prior;
    final enrollmentIds = <String>{};
    final eventIds = <String>{};
    for (var index = 0; index < package.assignments.length; index += 1) {
      final assignment = package.assignments[index];
      final issued = _parseUtc(assignment.issuedAtUtc);
      if (assignment.sequence != index + 1 ||
          !eventIds.add(assignment.assignmentEventId) ||
          !enrollmentIds.add(assignment.opaqueEnrollmentId) ||
          assignment.predecessorSha256 != predecessor ||
          issued == null ||
          (firstEnrollment != null && issued.isBefore(firstEnrollment)) ||
          (prior != null && issued.isBefore(prior)) ||
          assignment.operatorId != contract.enrollmentActorId ||
          assignment.authorityId.trim().isEmpty ||
          !contract.stratumIds.contains(assignment.stratumId) ||
          assignment.assignmentCode != package.custody.assignmentCodes[index]) {
        _add(
          findings,
          RandomizationInterimFindingKind.assignmentChainBroken,
          'Assignment order, concealment binding, actor, stratum, or clock is invalid.',
          [assignment.assignmentEventId],
        );
      }
      if (!assignment.eligibilityVerified) {
        _add(
          findings,
          RandomizationInterimFindingKind.ineligibleAssignment,
          'Assignment was issued before eligibility verification.',
          [assignment.assignmentEventId],
        );
      }
      predecessor = assignment.eventSha256;
      prior = issued ?? prior;
    }
  }

  void _checkCommittee(
    CredibilityRandomizationInterimPackage package,
    List<RandomizationInterimFinding> findings,
  ) {
    final ids = <String>{};
    final forbidden = {
      package.contract.generatorActorId,
      package.contract.enrollmentActorId,
      package.contract.sponsorActorId,
      package.contract.unblindedStatisticianId,
    };
    if (package.committeeMembers.length < 3) {
      _add(
        findings,
        RandomizationInterimFindingKind.committeeIncomplete,
        'At least three independently declared committee members are required.',
        const [],
      );
    }
    for (final member in package.committeeMembers) {
      if (!ids.add(member.memberId) ||
          member.memberId.trim().isEmpty ||
          member.authorityId.trim().isEmpty ||
          member.expertise.trim().isEmpty) {
        _add(
          findings,
          RandomizationInterimFindingKind.committeeIncomplete,
          'Committee member identity, authority, or expertise is incomplete.',
          [member.memberId],
        );
      }
      if (forbidden.contains(member.memberId) ||
          !member.independentFromSponsor ||
          !member.independentFromInvestigator ||
          !member.conflictFree) {
        _add(
          findings,
          RandomizationInterimFindingKind.committeeConflict,
          'Committee role independence or conflict declaration failed.',
          [member.memberId],
        );
      }
    }
  }

  void _checkAccess(
    CredibilityRandomizationInterimPackage package,
    List<RandomizationInterimFinding> findings,
  ) {
    var predecessor = RandomizationAccessEvent.genesisPredecessor;
    DateTime? prior;
    final ids = <String>{};
    for (var index = 0; index < package.accessEvents.length; index += 1) {
      final event = package.accessEvents[index];
      final occurred = _parseUtc(event.occurredAtUtc);
      if (event.sequence != index + 1 ||
          !ids.add(event.eventId) ||
          event.predecessorSha256 != predecessor ||
          occurred == null ||
          (prior != null && occurred.isBefore(prior)) ||
          event.actorId.trim().isEmpty ||
          event.authorityId.trim().isEmpty ||
          event.purpose.trim().isEmpty ||
          event.scope.trim().isEmpty ||
          !event.acknowledged) {
        _add(
          findings,
          RandomizationInterimFindingKind.accessChainBroken,
          'Access event chain, acknowledgement, purpose, or clock is invalid.',
          [event.eventId],
        );
      }
      final expectedRoles = <RandomizationAccessKind, Set<RandomizationRole>>{
        RandomizationAccessKind.contractLock: {
          RandomizationRole.sequenceGenerator,
        },
        RandomizationAccessKind.assignmentIssued: {
          RandomizationRole.enrollmentOperator,
        },
        RandomizationAccessKind.treatmentIdentityViewed: {
          RandomizationRole.unblindedStatistician,
          RandomizationRole.safetyOfficer,
          RandomizationRole.committeeMember,
        },
        RandomizationAccessKind.emergencyUnblinding: {
          RandomizationRole.safetyOfficer,
          RandomizationRole.blindedInvestigator,
        },
        RandomizationAccessKind.interimDatasetCut: {
          RandomizationRole.dataManager,
        },
        RandomizationAccessKind.interimAnalysis: {
          RandomizationRole.unblindedStatistician,
        },
        RandomizationAccessKind.committeeRecommendation: {
          RandomizationRole.committeeMember,
        },
        RandomizationAccessKind.sponsorResponse: {RandomizationRole.sponsor},
        RandomizationAccessKind.correction: {
          RandomizationRole.safetyOfficer,
          RandomizationRole.committeeMember,
        },
        RandomizationAccessKind.revocation: {
          RandomizationRole.safetyOfficer,
          RandomizationRole.committeeMember,
        },
      };
      if (!expectedRoles[event.kind]!.contains(event.role)) {
        _add(
          findings,
          RandomizationInterimFindingKind.unauthorizedAccess,
          'Actor role is not authorized for this access kind.',
          [event.eventId, event.role.name, event.kind.name],
        );
      }
      final canSeeInterim =
          event.role == RandomizationRole.unblindedStatistician ||
          event.role == RandomizationRole.committeeMember;
      if (event.interimComparativeResultVisible && !canSeeInterim) {
        _add(
          findings,
          event.role == RandomizationRole.sponsor
              ? RandomizationInterimFindingKind.sponsorInterimExposure
              : RandomizationInterimFindingKind.unauthorizedAccess,
          'Interim comparative results escaped the declared firewall.',
          [event.eventId],
        );
      }
      if (event.kind == RandomizationAccessKind.emergencyUnblinding &&
          (!event.treatmentIdentityVisible ||
              event.scope == 'all assignments' ||
              event.purpose.length < 16)) {
        _add(
          findings,
          RandomizationInterimFindingKind.emergencyUnblindingInvalid,
          'Emergency unblinding lacks minimum scope or documented safety reason.',
          [event.eventId],
        );
      }
      predecessor = event.eventSha256;
      prior = occurred ?? prior;
    }
    if (package.accessEvents.isEmpty) {
      _add(
        findings,
        RandomizationInterimFindingKind.accessChainBroken,
        'No randomization or interim access history exists.',
        const [],
      );
    }
  }

  void _checkInterim(
    CredibilityRandomizationInterimPackage package,
    List<RandomizationInterimFinding> findings,
  ) {
    final statisticalPlan = package.statisticalPackage.errorControl;
    final plan = package.boundaryPlan;
    final authored = _parseUtc(plan.authoredAtUtc);
    final locked = _parseUtc(plan.lockedAtUtc);
    final firstEnrollment = _parseUtc(package.contract.firstEnrollmentAtUtc);
    if (plan.planSha256 != statisticalPlan.alphaSpendingPlanSha256 ||
        plan.boundaries.length != statisticalPlan.interimLookCount ||
        authored == null ||
        locked == null ||
        firstEnrollment == null ||
        locked.isBefore(authored) ||
        !firstEnrollment.isAfter(locked)) {
      _add(
        findings,
        RandomizationInterimFindingKind.interimPlanMismatch,
        'Interim boundary plan does not match the prospectively locked statistical plan.',
        [plan.planId],
      );
    }
    var priorInformation = 0.0;
    var priorAlpha = 0.0;
    for (var index = 0; index < plan.boundaries.length; index += 1) {
      final boundary = plan.boundaries[index];
      if (boundary.lookNumber != index + 1 ||
          !_finite(boundary.informationFraction) ||
          boundary.informationFraction <= priorInformation ||
          boundary.informationFraction > 1 ||
          !_finite(boundary.cumulativeAlpha) ||
          boundary.cumulativeAlpha <= priorAlpha ||
          boundary.cumulativeAlpha > statisticalPlan.overallAlpha ||
          !_finite(boundary.efficacyBoundary) ||
          !_finite(boundary.futilityBoundary) ||
          !_finite(boundary.safetyBoundary)) {
        _add(
          findings,
          RandomizationInterimFindingKind.alphaSpendingDrift,
          'Interim information fraction, alpha spending, or boundary is invalid.',
          ['look-${boundary.lookNumber}'],
        );
      }
      priorInformation = boundary.informationFraction;
      priorAlpha = boundary.cumulativeAlpha;
    }
    final completedLooks = <int>{};
    DateTime? priorReview;
    for (final review in package.interimReviews) {
      final occurred = _parseUtc(review.occurredAtUtc);
      final boundary =
          review.lookNumber > 0 && review.lookNumber <= plan.boundaries.length
          ? plan.boundaries[review.lookNumber - 1]
          : null;
      if (!completedLooks.add(review.lookNumber) ||
          boundary == null ||
          occurred == null ||
          (priorReview != null && occurred.isBefore(priorReview)) ||
          !_isSha256(review.datasetCutSha256) ||
          !_isSha256(review.analysisArtifactSha256) ||
          review.analyzedBy != package.contract.unblindedStatisticianId ||
          (review.informationFraction - boundary.informationFraction).abs() >
              0.000001) {
        _add(
          findings,
          RandomizationInterimFindingKind.interimLookReplay,
          'Interim look is duplicate, out of order, unplanned, or identity-incomplete.',
          ['look-${review.lookNumber}'],
        );
      }
      if (boundary != null &&
          ((review.cumulativeAlphaSpent - boundary.cumulativeAlpha).abs() >
                  0.000001 ||
              !_finite(review.observedStatistic))) {
        _add(
          findings,
          RandomizationInterimFindingKind.alphaSpendingDrift,
          'Observed interim look changed the planned alpha or boundary basis.',
          ['look-${review.lookNumber}'],
        );
      }
      final memberIds = package.committeeMembers
          .map((item) => item.memberId)
          .toSet();
      if (review.votingMemberIds.toSet().length < 3 ||
          !memberIds.containsAll(review.votingMemberIds)) {
        _add(
          findings,
          RandomizationInterimFindingKind.insufficientQuorum,
          'Interim recommendation lacks a valid independent quorum.',
          ['look-${review.lookNumber}'],
        );
      }
      if (review.rationale.trim().isEmpty) {
        _add(
          findings,
          RandomizationInterimFindingKind.recommendationTampered,
          'Interim recommendation lacks a retained rationale.',
          ['look-${review.lookNumber}'],
        );
      }
      priorReview = occurred ?? priorReview;
    }
  }

  void _checkDecisions(
    CredibilityRandomizationInterimPackage package,
    List<RandomizationInterimFinding> findings,
  ) {
    final reviews = {
      for (final review in package.interimReviews) review.reviewSha256: review,
    };
    var predecessor = SponsorInterimDecision.genesisPredecessor;
    DateTime? prior;
    final ids = <String>{};
    for (var index = 0; index < package.sponsorDecisions.length; index += 1) {
      final decision = package.sponsorDecisions[index];
      final occurred = _parseUtc(decision.occurredAtUtc);
      final review = reviews[decision.reviewSha256];
      final reviewTime = _parseUtc(review?.occurredAtUtc);
      if (decision.sequence != index + 1 ||
          !ids.add(decision.decisionId) ||
          decision.predecessorSha256 != predecessor ||
          review == null ||
          occurred == null ||
          reviewTime == null ||
          occurred.isBefore(reviewTime) ||
          (prior != null && occurred.isBefore(prior)) ||
          decision.actorId != package.contract.sponsorActorId ||
          decision.authorityId.trim().isEmpty ||
          decision.reason.trim().isEmpty) {
        _add(
          findings,
          RandomizationInterimFindingKind.decisionChainBroken,
          'Sponsor decision chain, review binding, authority, or clock is invalid.',
          [decision.decisionId],
        );
      }
      if (decision.overrideAttempted) {
        _add(
          findings,
          RandomizationInterimFindingKind.recommendationOverride,
          'Sponsor attempted to override the independent recommendation.',
          [decision.decisionId],
        );
      }
      predecessor = decision.decisionSha256;
      prior = occurred ?? prior;
    }
    if (package.sponsorDecisions.length != package.interimReviews.length) {
      _add(
        findings,
        RandomizationInterimFindingKind.decisionChainBroken,
        'Every interim recommendation requires one retained sponsor response.',
        const [],
      );
    }
  }

  void _add(
    List<RandomizationInterimFinding> findings,
    RandomizationInterimFindingKind kind,
    String detail,
    List<String> affectedIds,
  ) {
    findings.add(
      RandomizationInterimFinding(
        kind: kind,
        detail: detail,
        affectedIds: affectedIds,
      ),
    );
  }
}

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

bool _isSha256(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _finite(double? value) => value != null && value.isFinite;

DateTime? _parseUtc(String? value) {
  if (value == null || !value.endsWith('Z')) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.isUtc == true ? parsed : null;
}
