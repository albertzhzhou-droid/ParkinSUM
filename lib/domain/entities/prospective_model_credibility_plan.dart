import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'mechanistic_medication_applicability.dart';

enum CredibilityModelInfluence { negligible, minor, moderate, major, primary }

enum CredibilityDecisionConsequence { minimal, low, moderate, serious, severe }

enum CredibilityFactor {
  softwareQualityAssurance,
  numericalCodeVerification,
  calculationVerification,
  modelForm,
  modelInputs,
  comparatorOrValidationData,
  applicabilityToContextOfUse,
  uncertaintyQuantification,
  useError,
  humanFactors,
}

enum CredibilityActivityStatus {
  planned,
  executedPassed,
  executedFailed,
  held,
  notApplicable,
}

enum CredibilityAdequacyPhase { prospective, postStudy }

enum CredibilityAdequacyDisposition {
  notAssessed,
  blocked,
  adequateForResearchTraceOnly,
  rejected,
  revoked,
}

final class CredibilityGoal {
  final CredibilityFactor factor;
  final String targetGradation;
  final String rationale;
  final String plannedActivity;
  final String acceptanceCriterion;
  final String observableId;
  final String datasetManifestId;
  final String datasetSha256;
  final String independenceGroupId;
  final String applicabilityBoundary;
  final bool independentReviewerRequired;
  final String expiresAtUtc;
  final String failureDisposition;
  final CredibilityActivityStatus status;
  final List<String> resultArtifactIds;
  final String? resultReviewer;
  final String? resultRecordedAtUtc;

  CredibilityGoal({
    required this.factor,
    required this.targetGradation,
    required this.rationale,
    required this.plannedActivity,
    required this.acceptanceCriterion,
    required this.observableId,
    required this.datasetManifestId,
    required this.datasetSha256,
    required this.independenceGroupId,
    required this.applicabilityBoundary,
    required this.independentReviewerRequired,
    required this.expiresAtUtc,
    required this.failureDisposition,
    required this.status,
    required List<String> resultArtifactIds,
    required this.resultReviewer,
    required this.resultRecordedAtUtc,
  }) : resultArtifactIds = List.unmodifiable(resultArtifactIds);

  List<String> get integrityReasons {
    final reasons = <String>[];
    final prefix = 'goal.${factor.name}';
    final requiredText = <String, String>{
      'target_gradation': targetGradation,
      'rationale': rationale,
      'planned_activity': plannedActivity,
      'acceptance_criterion': acceptanceCriterion,
      'observable_id': observableId,
      'dataset_manifest_id': datasetManifestId,
      'independence_group_id': independenceGroupId,
      'applicability_boundary': applicabilityBoundary,
      'failure_disposition': failureDisposition,
    };
    for (final entry in requiredText.entries) {
      if (entry.value.trim().isEmpty) {
        reasons.add('$prefix.${entry.key}_missing');
      }
    }
    if (!_isSha256(datasetSha256)) {
      reasons.add('$prefix.dataset_sha256_invalid');
    }
    if (!_isUtcTimestamp(expiresAtUtc)) reasons.add('$prefix.expiry_invalid');

    final executed =
        status == CredibilityActivityStatus.executedPassed ||
        status == CredibilityActivityStatus.executedFailed;
    if (executed) {
      if (resultArtifactIds.isEmpty) {
        reasons.add('$prefix.result_artifact_missing');
      }
      if (resultReviewer == null || resultReviewer!.trim().isEmpty) {
        reasons.add('$prefix.result_reviewer_missing');
      }
      if (!_isUtcTimestamp(resultRecordedAtUtc)) {
        reasons.add('$prefix.result_time_invalid');
      }
    } else if (resultArtifactIds.isNotEmpty ||
        resultReviewer != null ||
        resultRecordedAtUtc != null) {
      reasons.add('$prefix.unexecuted_has_result');
    }
    if (status == CredibilityActivityStatus.notApplicable &&
        targetGradation != 'not_applicable') {
      reasons.add('$prefix.not_applicable_gradation_mismatch');
    }
    return List.unmodifiable(reasons);
  }

  Map<String, Object?> toJson() => {
    'factor': factor.name,
    'target_gradation': targetGradation,
    'rationale': rationale,
    'planned_activity': plannedActivity,
    'acceptance_criterion': acceptanceCriterion,
    'observable_id': observableId,
    'dataset_manifest_id': datasetManifestId,
    'dataset_sha256': datasetSha256,
    'independence_group_id': independenceGroupId,
    'applicability_boundary': applicabilityBoundary,
    'independent_reviewer_required': independentReviewerRequired,
    'expires_at_utc': expiresAtUtc,
    'failure_disposition': failureDisposition,
    'status': status.name,
    'result_artifact_ids': [...resultArtifactIds]..sort(),
    'result_reviewer': resultReviewer,
    'result_recorded_at_utc': resultRecordedAtUtc,
  };
}

final class CredibilityAdequacyDecision {
  final CredibilityAdequacyPhase phase;
  final CredibilityAdequacyDisposition disposition;
  final String rationale;
  final String? reviewer;
  final String? decidedAtUtc;
  final String? planSha256;
  final List<String> evidenceArtifactIds;

  CredibilityAdequacyDecision({
    required this.phase,
    required this.disposition,
    required this.rationale,
    required this.reviewer,
    required this.decidedAtUtc,
    required this.planSha256,
    required List<String> evidenceArtifactIds,
  }) : evidenceArtifactIds = List.unmodifiable(evidenceArtifactIds);

  List<String> get integrityReasons {
    final reasons = <String>[];
    final prefix = 'decision.${phase.name}';
    if (rationale.trim().isEmpty) reasons.add('$prefix.rationale_missing');
    if (phase == CredibilityAdequacyPhase.prospective) {
      if (disposition == CredibilityAdequacyDisposition.notAssessed) {
        reasons.add('$prefix.not_assessed');
      }
      if (reviewer == null || reviewer!.trim().isEmpty) {
        reasons.add('$prefix.reviewer_missing');
      }
      if (!_isUtcTimestamp(decidedAtUtc)) reasons.add('$prefix.time_invalid');
      if (!_isSha256(planSha256)) reasons.add('$prefix.plan_sha256_invalid');
    } else if (disposition == CredibilityAdequacyDisposition.notAssessed) {
      if (reviewer != null ||
          decidedAtUtc != null ||
          planSha256 != null ||
          evidenceArtifactIds.isNotEmpty) {
        reasons.add('$prefix.not_assessed_has_decision_evidence');
      }
    } else {
      if (reviewer == null || reviewer!.trim().isEmpty) {
        reasons.add('$prefix.reviewer_missing');
      }
      if (!_isUtcTimestamp(decidedAtUtc)) reasons.add('$prefix.time_invalid');
      if (!_isSha256(planSha256)) reasons.add('$prefix.plan_sha256_invalid');
      if (evidenceArtifactIds.isEmpty) reasons.add('$prefix.evidence_missing');
    }
    return List.unmodifiable(reasons);
  }

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'disposition': disposition.name,
    'rationale': rationale,
    'reviewer': reviewer,
    'decided_at_utc': decidedAtUtc,
    'plan_sha256': planSha256,
    'evidence_artifact_ids': [...evidenceArtifactIds]..sort(),
  };
}

/// Prospective credibility contract for the current educational mechanism stack.
///
/// It intentionally records a structurally valid plan whose promotion remains
/// blocked. Passing this contract proves only that the missing evidence is
/// explicit and that prospective and post-study decisions cannot collapse into
/// one another.
final class ProspectiveModelCredibilityPlan {
  static const String schema = 'parkinsum.prospective-model-credibility-plan/1';
  static const int schemaVersion = 1;
  static const String planVersion = '2026.10.08-v39';
  static const String expectedManifestSha256 =
      '3e560401c21a1fd3eec3ed75e24f8753797e7e8d14f70b495086bb5fe2db0dc7';
  static const String expectedConfigurationSha256 =
      '48b6ede1c08109c0a2b60af162ebe30fc5e35315257d0cb9999f3c31eacb1427';

  final String planId;
  final String releaseArtifact;
  final String questionOfInterest;
  final String contextOfUse;
  final String manifestSha256;
  final String configurationSha256;
  final CredibilityModelInfluence modelInfluence;
  final CredibilityDecisionConsequence decisionConsequence;
  final String overallModelRisk;
  final List<String> affectedProviderIds;
  final List<String> affectedPredicateIds;
  final String authoredBy;
  final String authoredAtUtc;
  final List<CredibilityGoal> goals;
  final CredibilityAdequacyDecision prospectiveDecision;
  final CredibilityAdequacyDecision postStudyDecision;
  final String safetyBoundary;

  ProspectiveModelCredibilityPlan({
    required this.planId,
    required this.releaseArtifact,
    required this.questionOfInterest,
    required this.contextOfUse,
    required this.manifestSha256,
    required this.configurationSha256,
    required this.modelInfluence,
    required this.decisionConsequence,
    required this.overallModelRisk,
    required List<String> affectedProviderIds,
    required List<String> affectedPredicateIds,
    required this.authoredBy,
    required this.authoredAtUtc,
    required List<CredibilityGoal> goals,
    required this.prospectiveDecision,
    required this.postStudyDecision,
    required this.safetyBoundary,
  }) : affectedProviderIds = List.unmodifiable(affectedProviderIds),
       affectedPredicateIds = List.unmodifiable(affectedPredicateIds),
       goals = List.unmodifiable(goals);

  factory ProspectiveModelCredibilityPlan.current({
    required MechanisticApplicabilityManifest manifest,
    required String configurationSha256,
  }) {
    final goals = <CredibilityGoal>[
      _executedGoal(
        factor: CredibilityFactor.softwareQualityAssurance,
        activity:
            'Run the repository-wide static analysis, unit, widget, schema, privacy, and release gates against the exact source bundle.',
        criterion:
            'Every deterministic engineering gate exits zero and preserves all negative and abstention fixtures.',
        artifact: 'build/verify_all/latest.json',
      ),
      _executedGoal(
        factor: CredibilityFactor.numericalCodeVerification,
        activity:
            'Compare production-engine outputs with an independent numerical oracle over synthetic boundary vectors.',
        criterion:
            'All pinned oracle vectors pass within their declared tolerances without replacing unknown values with zero.',
        artifact: 'build/mechanistic_model_verification/latest.json',
      ),
      _executedGoal(
        factor: CredibilityFactor.calculationVerification,
        activity:
            'Evaluate normalization, monotonicity, boundedness, unit, and ordering invariants over deterministic synthetic scenarios.',
        criterion:
            'Every mathematical invariant passes and no failed invariant is hidden by an aggregate score.',
        artifact: 'build/mechanistic_model_verification/latest.json',
      ),
      for (final factor in const [
        CredibilityFactor.modelForm,
        CredibilityFactor.modelInputs,
        CredibilityFactor.comparatorOrValidationData,
        CredibilityFactor.applicabilityToContextOfUse,
        CredibilityFactor.uncertaintyQuantification,
        CredibilityFactor.useError,
        CredibilityFactor.humanFactors,
      ])
        _heldGoal(factor),
    ];
    final shell = ProspectiveModelCredibilityPlan(
      planId: 'parkinsum-mechanistic-trace-baseline',
      releaseArtifact:
          'unreleased-worktree:agent/complete-app-upgrade-20260818',
      questionOfInterest: manifest.questionOfInterest,
      contextOfUse: manifest.contextOfUse,
      manifestSha256: expectedManifestSha256,
      configurationSha256: expectedConfigurationSha256,
      modelInfluence: CredibilityModelInfluence.minor,
      decisionConsequence: CredibilityDecisionConsequence.serious,
      overallModelRisk:
          'high_interpretation_risk_despite_minor_decision_influence',
      affectedProviderIds: manifest.providers
          .map((entry) => entry.providerId)
          .toList(),
      affectedPredicateIds: manifest.predicates
          .map((entry) => entry.id)
          .toList(),
      authoredBy: 'repository-maintainers',
      authoredAtUtc: '2026-08-18T00:00:00.000Z',
      goals: goals,
      prospectiveDecision: CredibilityAdequacyDecision(
        phase: CredibilityAdequacyPhase.prospective,
        disposition: CredibilityAdequacyDisposition.blocked,
        rationale:
            'Engineering verification is planned and partly executed, but scientific validation, applicability, uncertainty, use-error, human-factors, and independent evidence goals are not prospectively sufficient. The v52 release refresh binds the current source identity only; retained synthetic fixture timestamps do not attest current-worktree review or evidence coverage.',
        reviewer: 'repository-maintainers',
        decidedAtUtc: '2026-08-18T00:05:00.000Z',
        planSha256: _sha256(
          _currentUnsignedIdentityPayload(
            manifestSha256: expectedManifestSha256,
            configurationSha256: expectedConfigurationSha256,
            goals: goals,
          ),
        ),
        evidenceArtifactIds: const [],
      ),
      postStudyDecision: CredibilityAdequacyDecision(
        phase: CredibilityAdequacyPhase.postStudy,
        disposition: CredibilityAdequacyDisposition.notAssessed,
        rationale:
            'No governed post-study adequacy assessment has been performed.',
        reviewer: null,
        decidedAtUtc: null,
        planSha256: null,
        evidenceArtifactIds: const [],
      ),
      safetyBoundary:
          'This plan governs an educational research trace only. It is not scientific or clinical validation, model qualification, regulatory review, external approval, or medical advice.',
    );
    return shell._withRuntimeIdentity(
      manifestSha256: manifest.sha256Digest,
      configurationSha256: configurationSha256,
    );
  }

  ProspectiveModelCredibilityPlan _withRuntimeIdentity({
    required String manifestSha256,
    required String configurationSha256,
  }) => ProspectiveModelCredibilityPlan(
    planId: planId,
    releaseArtifact: releaseArtifact,
    questionOfInterest: questionOfInterest,
    contextOfUse: contextOfUse,
    manifestSha256: manifestSha256,
    configurationSha256: configurationSha256,
    modelInfluence: modelInfluence,
    decisionConsequence: decisionConsequence,
    overallModelRisk: overallModelRisk,
    affectedProviderIds: affectedProviderIds,
    affectedPredicateIds: affectedPredicateIds,
    authoredBy: authoredBy,
    authoredAtUtc: authoredAtUtc,
    goals: goals,
    prospectiveDecision: prospectiveDecision,
    postStudyDecision: postStudyDecision,
    safetyBoundary: safetyBoundary,
  );

  Map<String, Object?> get unsignedIdentityPayload => {
    'plan_id': planId,
    'release_artifact': releaseArtifact,
    'question_of_interest': questionOfInterest,
    'context_of_use': contextOfUse,
    'manifest_sha256': manifestSha256,
    'configuration_sha256': configurationSha256,
    'model_influence': modelInfluence.name,
    'decision_consequence': decisionConsequence.name,
    'overall_model_risk': overallModelRisk,
    'affected_provider_ids': [...affectedProviderIds]..sort(),
    'affected_predicate_ids': [...affectedPredicateIds]..sort(),
    'authored_by': authoredBy,
    'authored_at_utc': authoredAtUtc,
    'goals': goals.map((goal) => goal.toJson()).toList(growable: false)
      ..sort(
        (a, b) => (a['factor']! as String).compareTo(b['factor']! as String),
      ),
    'safety_boundary': safetyBoundary,
  };

  String get planSha256 => _sha256(unsignedIdentityPayload);

  List<String> get integrityReasons {
    final reasons = <String>{};
    if (planId.trim().isEmpty ||
        releaseArtifact.trim().isEmpty ||
        questionOfInterest.trim().isEmpty ||
        contextOfUse.trim().isEmpty ||
        overallModelRisk.trim().isEmpty ||
        authoredBy.trim().isEmpty ||
        safetyBoundary.trim().isEmpty) {
      reasons.add('plan.required_metadata_missing');
    }
    if (!_isUtcTimestamp(authoredAtUtc)) {
      reasons.add('plan.authored_time_invalid');
    }
    if (manifestSha256 != expectedManifestSha256) {
      reasons.add('plan.manifest_identity_mismatch');
    }
    if (configurationSha256 != expectedConfigurationSha256) {
      reasons.add('plan.configuration_identity_mismatch');
    }
    final factors = <CredibilityFactor>{};
    for (final goal in goals) {
      if (!factors.add(goal.factor)) reasons.add('plan.factor_duplicate');
      reasons.addAll(goal.integrityReasons);
    }
    if (factors.length != CredibilityFactor.values.length) {
      reasons.add('plan.factor_matrix_incomplete');
    }
    if (affectedProviderIds.isEmpty ||
        affectedProviderIds.toSet().length != affectedProviderIds.length) {
      reasons.add('plan.provider_identity_invalid');
    }
    if (affectedPredicateIds.isEmpty ||
        affectedPredicateIds.toSet().length != affectedPredicateIds.length) {
      reasons.add('plan.predicate_identity_invalid');
    }
    reasons.addAll(prospectiveDecision.integrityReasons);
    reasons.addAll(postStudyDecision.integrityReasons);
    if (prospectiveDecision.phase != CredibilityAdequacyPhase.prospective ||
        postStudyDecision.phase != CredibilityAdequacyPhase.postStudy) {
      reasons.add('plan.adequacy_phase_mismatch');
    }
    if (prospectiveDecision.planSha256 != planSha256) {
      reasons.add('plan.prospective_decision_identity_mismatch');
    }
    final authored = DateTime.tryParse(authoredAtUtc);
    final prospective = DateTime.tryParse(
      prospectiveDecision.decidedAtUtc ?? '',
    );
    if (authored != null &&
        prospective != null &&
        prospective.isBefore(authored)) {
      reasons.add('plan.prospective_decision_backdated');
    }
    return List.unmodifiable(reasons.toList()..sort());
  }

  bool get integrityVerified => integrityReasons.isEmpty;

  List<CredibilityGoal> get incompleteGoals => goals
      .where(
        (goal) =>
            goal.status != CredibilityActivityStatus.executedPassed &&
            goal.status != CredibilityActivityStatus.notApplicable,
      )
      .toList(growable: false);

  bool get canExecuteGovernedStudy =>
      integrityVerified &&
      prospectiveDecision.disposition ==
          CredibilityAdequacyDisposition.adequateForResearchTraceOnly;

  bool get canPromoteResearchTraceOnly =>
      integrityVerified &&
      incompleteGoals.isEmpty &&
      postStudyDecision.disposition ==
          CredibilityAdequacyDisposition.adequateForResearchTraceOnly;

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'plan_version': planVersion,
    ...unsignedIdentityPayload,
    'plan_sha256': planSha256,
    'prospective_decision': prospectiveDecision.toJson(),
    'post_study_decision': postStudyDecision.toJson(),
    'integrity_verified': integrityVerified,
    'can_execute_governed_study': canExecuteGovernedStudy,
    'can_promote_research_trace_only': canPromoteResearchTraceOnly,
    'incomplete_factors': incompleteGoals
        .map((goal) => goal.factor.name)
        .toList(),
    'integrity_reasons': integrityReasons,
  };
}

CredibilityGoal _executedGoal({
  required CredibilityFactor factor,
  required String activity,
  required String criterion,
  required String artifact,
}) => CredibilityGoal(
  factor: factor,
  targetGradation: 'repository_engineering_verification',
  rationale:
      'The exact implementation must be reproducible before any external scientific evidence is interpreted.',
  plannedActivity: activity,
  acceptanceCriterion: criterion,
  observableId: 'mechanistic_trace.synthetic_engineering_output',
  datasetManifestId: 'synthetic-fixtures-v2026.08.26',
  datasetSha256:
      'ba7618bfb3cba3769db613f82ff43b1948ef41577f4c0f74db65aa016d9b507e',
  independenceGroupId: 'engineering-fixtures-not-scientific-validation',
  applicabilityBoundary:
      'Synthetic fixtures verify implementation behavior only; they do not represent patients or clinical outcomes.',
  independentReviewerRequired: false,
  expiresAtUtc: '2026-12-31T23:59:59.000Z',
  failureDisposition:
      'Block the release gate and preserve every failed vector.',
  status: CredibilityActivityStatus.executedPassed,
  resultArtifactIds: [artifact],
  resultReviewer: 'automated-repository-gate',
  resultRecordedAtUtc: '2026-08-26T00:00:00.000Z',
);

CredibilityGoal _heldGoal(CredibilityFactor factor) => CredibilityGoal(
  factor: factor,
  targetGradation: 'independent_evidence_required',
  rationale:
      'Repository tests and literature citations cannot establish ${factor.name} adequacy for the stated context of use.',
  plannedActivity:
      'Define and execute a preregistered independent protocol for ${factor.name}, including negative and contradictory results.',
  acceptanceCriterion:
      'A named independent reviewer confirms that every prospective criterion is met for the exact observable, dataset revision, population, and context of use.',
  observableId: 'mechanistic_trace.external_credibility.${factor.name}',
  datasetManifestId: 'external-evidence-not-yet-authorized',
  datasetSha256:
      '0000000000000000000000000000000000000000000000000000000000000000',
  independenceGroupId: 'external-independent-study-required',
  applicabilityBoundary:
      'No patient, clinical, calibration, usability, or qualification dataset has been approved or represented by this placeholder identity.',
  independentReviewerRequired: true,
  expiresAtUtc: '2026-12-31T23:59:59.000Z',
  failureDisposition:
      'Keep the factor visible, block promotion, and preserve failed, null, contradictory, and missing results.',
  status: CredibilityActivityStatus.held,
  resultArtifactIds: const [],
  resultReviewer: null,
  resultRecordedAtUtc: null,
);

Map<String, Object?> _currentUnsignedIdentityPayload({
  required String manifestSha256,
  required String configurationSha256,
  required List<CredibilityGoal> goals,
}) => {
  'plan_id': 'parkinsum-mechanistic-trace-baseline',
  'release_artifact': 'unreleased-worktree:agent/complete-app-upgrade-20260818',
  'question_of_interest':
      MechanisticApplicabilityManifest.current.questionOfInterest,
  'context_of_use': MechanisticApplicabilityManifest.current.contextOfUse,
  'manifest_sha256': manifestSha256,
  'configuration_sha256': configurationSha256,
  'model_influence': CredibilityModelInfluence.minor.name,
  'decision_consequence': CredibilityDecisionConsequence.serious.name,
  'overall_model_risk':
      'high_interpretation_risk_despite_minor_decision_influence',
  'affected_provider_ids':
      MechanisticApplicabilityManifest.current.providers
          .map((entry) => entry.providerId)
          .toList()
        ..sort(),
  'affected_predicate_ids':
      MechanisticApplicabilityManifest.current.predicates
          .map((entry) => entry.id)
          .toList()
        ..sort(),
  'authored_by': 'repository-maintainers',
  'authored_at_utc': '2026-08-18T00:00:00.000Z',
  'goals': goals.map((goal) => goal.toJson()).toList(growable: false)
    ..sort(
      (a, b) => (a['factor']! as String).compareTo(b['factor']! as String),
    ),
  'safety_boundary':
      'This plan governs an educational research trace only. It is not scientific or clinical validation, model qualification, regulatory review, external approval, or medical advice.',
};

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
