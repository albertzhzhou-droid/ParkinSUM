import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'evidence_currency.dart';
import 'mechanistic_medication_applicability.dart';

enum EvidenceClaimKind {
  empiricalAssociation,
  measurementMethod,
  dataContract,
  governanceGuidance,
}

enum EvidenceFindingDirection {
  supports,
  nullFinding,
  opposes,
  adverse,
  notApplicable,
}

enum EvidenceStudyDesign {
  selectedHumanPharmacokinetic,
  observationalCohort,
  measurementValidation,
  sourceSpecification,
  regulatoryGuidance,
  randomizedTrial,
  systematicReview,
}

enum EvidenceRiskOfBias { low, someConcerns, high, notAssessed }

enum EvidenceApplicability { direct, partiallyIndirect, indirect, notAssessed }

enum EvidencePrecision { precise, imprecise, veryImprecise, notAssessed }

enum EvidenceReportingBias { unlikely, suspected, likely, notAssessed }

enum EvidenceBodyCertainty { high, moderate, low, veryLow, notAssessed }

enum EvidenceSynthesisReviewState {
  complete,
  awaitingIndependentReview,
  reviewerDisagreement,
  stale,
}

enum EvidenceSynthesisDisposition {
  allowResearchTraceOnly,
  holdForReview,
  blockAffectedProviders,
}

enum EvidenceDependencyRelation {
  sameCohort,
  overlappingParticipants,
  samePublication,
  secondaryAnalysis,
  sharedDataset,
}

enum EvidenceDependencyReviewState { confirmed, suspected, unresolved }

/// A reviewer-declared link between findings that may not be independent.
/// Edges are undirected; their canonical identity sorts the finding IDs.
final class EvidenceFindingDependency {
  final String firstFindingId;
  final String secondFindingId;
  final EvidenceDependencyRelation relation;
  final EvidenceDependencyReviewState reviewState;
  final List<String> sourceEvidenceIds;
  final String rationale;

  EvidenceFindingDependency({
    required this.firstFindingId,
    required this.secondFindingId,
    required this.relation,
    required this.reviewState,
    required List<String> sourceEvidenceIds,
    required this.rationale,
  }) : sourceEvidenceIds = List.unmodifiable(sourceEvidenceIds);

  List<String> get canonicalFindingIds =>
      [firstFindingId, secondFindingId]..sort();

  String get identity => '${canonicalFindingIds.join('|')}:${relation.name}';

  List<String> integrityReasons({required String bodyClaimId}) {
    final reasons = <String>[];
    if (!_isSafeId(firstFindingId) || !_isSafeId(secondFindingId)) {
      reasons.add('dependency_finding_id_invalid:$bodyClaimId:$identity');
    }
    if (firstFindingId == secondFindingId) {
      reasons.add('dependency_self_link:$bodyClaimId:$identity');
    }
    if (sourceEvidenceIds.isEmpty ||
        sourceEvidenceIds.any((id) => !_isSafeId(id)) ||
        sourceEvidenceIds.toSet().length != sourceEvidenceIds.length) {
      reasons.add('dependency_source_evidence_invalid:$bodyClaimId:$identity');
    }
    if (rationale.trim().isEmpty) {
      reasons.add('dependency_rationale_missing:$bodyClaimId:$identity');
    }
    return List.unmodifiable(reasons);
  }

  Map<String, Object?> get canonicalPayload => {
    'finding_ids': canonicalFindingIds,
    'relation': relation.name,
    'review_state': reviewState.name,
    'source_evidence_ids': _sorted(sourceEvidenceIds),
    'rationale': rationale,
  };
}

final class EvidenceStudyFinding {
  final String findingId;
  final String evidenceCurrencyClaimId;
  final String sourceRevision;
  final String independenceGroupId;
  final EvidenceStudyDesign studyDesign;
  final String population;
  final String interventionOrExposure;
  final String comparator;
  final String outcomeId;
  final String measureId;
  final EvidenceFindingDirection direction;
  final double? effectEstimate;
  final double? lowerBound;
  final double? upperBound;
  final String? effectUnit;
  final EvidenceRiskOfBias riskOfBias;
  final EvidenceApplicability applicability;
  final EvidencePrecision precision;
  final EvidenceReportingBias reportingBias;
  final String limitation;

  const EvidenceStudyFinding({
    required this.findingId,
    required this.evidenceCurrencyClaimId,
    required this.sourceRevision,
    required this.independenceGroupId,
    required this.studyDesign,
    required this.population,
    required this.interventionOrExposure,
    required this.comparator,
    required this.outcomeId,
    required this.measureId,
    required this.direction,
    required this.effectEstimate,
    required this.lowerBound,
    required this.upperBound,
    required this.effectUnit,
    required this.riskOfBias,
    required this.applicability,
    required this.precision,
    required this.reportingBias,
    required this.limitation,
  });

  List<String> integrityReasons({required String bodyClaimId}) {
    final reasons = <String>[];
    if (!_isSafeId(findingId)) {
      reasons.add('finding_id_invalid:$bodyClaimId:$findingId');
    }
    if (!_isSafeId(evidenceCurrencyClaimId)) {
      reasons.add('finding_currency_claim_invalid:$bodyClaimId:$findingId');
    }
    if (sourceRevision.trim().isEmpty) {
      reasons.add('finding_source_revision_missing:$bodyClaimId:$findingId');
    }
    if (!_isSafeId(independenceGroupId)) {
      reasons.add('finding_independence_group_invalid:$bodyClaimId:$findingId');
    }
    if (population.trim().isEmpty ||
        interventionOrExposure.trim().isEmpty ||
        comparator.trim().isEmpty ||
        limitation.trim().isEmpty) {
      reasons.add('finding_narrative_boundary_missing:$bodyClaimId:$findingId');
    }
    if (!_isSafeId(outcomeId) || !_isSafeId(measureId)) {
      reasons.add('finding_outcome_measure_invalid:$bodyClaimId:$findingId');
    }
    final numericValues = [
      effectEstimate,
      lowerBound,
      upperBound,
    ].whereType<double>();
    if (numericValues.any((value) => !value.isFinite)) {
      reasons.add('finding_nonfinite_effect:$bodyClaimId:$findingId');
    }
    if ((lowerBound == null) != (upperBound == null)) {
      reasons.add('finding_interval_incomplete:$bodyClaimId:$findingId');
    }
    if (lowerBound != null && upperBound != null && lowerBound! > upperBound!) {
      reasons.add('finding_interval_reversed:$bodyClaimId:$findingId');
    }
    if (effectEstimate != null &&
        lowerBound != null &&
        upperBound != null &&
        (effectEstimate! < lowerBound! || effectEstimate! > upperBound!)) {
      reasons.add('finding_estimate_outside_interval:$bodyClaimId:$findingId');
    }
    final hasNumeric = effectEstimate != null || lowerBound != null;
    if (hasNumeric && (effectUnit == null || effectUnit!.trim().isEmpty)) {
      reasons.add('finding_effect_unit_missing:$bodyClaimId:$findingId');
    }
    if (!hasNumeric && effectUnit != null) {
      reasons.add('finding_effect_unit_without_value:$bodyClaimId:$findingId');
    }
    if (direction == EvidenceFindingDirection.notApplicable && hasNumeric) {
      reasons.add(
        'finding_non_effect_has_numeric_value:$bodyClaimId:$findingId',
      );
    }
    return List.unmodifiable(reasons);
  }

  Map<String, Object?> get canonicalPayload => {
    'finding_id': findingId,
    'evidence_currency_claim_id': evidenceCurrencyClaimId,
    'source_revision': sourceRevision,
    'independence_group_id': independenceGroupId,
    'study_design': studyDesign.name,
    'population': population,
    'intervention_or_exposure': interventionOrExposure,
    'comparator': comparator,
    'outcome_id': outcomeId,
    'measure_id': measureId,
    'direction': direction.name,
    'effect_estimate': effectEstimate,
    'lower_bound': lowerBound,
    'upper_bound': upperBound,
    'effect_unit': effectUnit,
    'risk_of_bias': riskOfBias.name,
    'applicability': applicability.name,
    'precision': precision.name,
    'reporting_bias': reportingBias.name,
    'limitation': limitation,
  };

  String get findingSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'finding_sha256': findingSha256,
  };
}

final class EvidenceSynthesisBody {
  final String claimId;
  final String claim;
  final EvidenceClaimKind claimKind;
  final List<String> providerIds;
  final String expectedOutcomeId;
  final String expectedMeasureId;
  final EvidenceFindingDirection expectedDirection;
  final int minimumIndependentFamilies;
  final List<EvidenceStudyFinding> findings;
  final List<EvidenceFindingDependency> dependencies;
  final EvidenceBodyCertainty declaredCertainty;
  final EvidenceSynthesisReviewState reviewState;
  final List<String> reviewers;
  final List<String> reviewArtifactIds;
  final String? reviewedAtUtc;
  final String reviewByUtc;
  final String rationale;
  final String applicabilityBoundary;

  EvidenceSynthesisBody({
    required this.claimId,
    required this.claim,
    required this.claimKind,
    required List<String> providerIds,
    required this.expectedOutcomeId,
    required this.expectedMeasureId,
    required this.expectedDirection,
    required this.minimumIndependentFamilies,
    required List<EvidenceStudyFinding> findings,
    List<EvidenceFindingDependency> dependencies = const [],
    required this.declaredCertainty,
    required this.reviewState,
    required List<String> reviewers,
    required List<String> reviewArtifactIds,
    required this.reviewedAtUtc,
    required this.reviewByUtc,
    required this.rationale,
    required this.applicabilityBoundary,
  }) : providerIds = List.unmodifiable(providerIds),
       findings = List.unmodifiable(findings),
       dependencies = List.unmodifiable(dependencies),
       reviewers = List.unmodifiable(reviewers),
       reviewArtifactIds = List.unmodifiable(reviewArtifactIds);

  List<String> get integrityReasons {
    final reasons = <String>[];
    if (!_isSafeId(claimId)) reasons.add('body_claim_id_invalid:$claimId');
    if (claim.trim().isEmpty) reasons.add('body_claim_missing:$claimId');
    if (providerIds.isEmpty ||
        providerIds.any((id) => !_isSafeId(id)) ||
        providerIds.toSet().length != providerIds.length) {
      reasons.add('body_provider_ids_invalid:$claimId');
    }
    if (!_isSafeId(expectedOutcomeId) || !_isSafeId(expectedMeasureId)) {
      reasons.add('body_expected_outcome_measure_invalid:$claimId');
    }
    if (expectedDirection != EvidenceFindingDirection.supports &&
        expectedDirection != EvidenceFindingDirection.notApplicable) {
      reasons.add('body_expected_direction_invalid:$claimId');
    }
    if (minimumIndependentFamilies < 1 || minimumIndependentFamilies > 20) {
      reasons.add('body_independent_family_requirement_invalid:$claimId');
    }
    if (findings.isEmpty) reasons.add('body_findings_empty:$claimId');
    final findingIds = <String>{};
    final findingHashes = <String>{};
    for (final finding in findings) {
      reasons.addAll(finding.integrityReasons(bodyClaimId: claimId));
      if (!findingIds.add(finding.findingId)) {
        reasons.add('body_finding_id_duplicate:$claimId:${finding.findingId}');
      }
      if (!findingHashes.add(finding.findingSha256)) {
        reasons.add('body_finding_duplicate:$claimId:${finding.findingId}');
      }
    }
    final dependencyIdentities = <String>{};
    for (final dependency in dependencies) {
      reasons.addAll(dependency.integrityReasons(bodyClaimId: claimId));
      if (!findingIds.contains(dependency.firstFindingId) ||
          !findingIds.contains(dependency.secondFindingId)) {
        reasons.add(
          'body_dependency_finding_unknown:$claimId:${dependency.identity}',
        );
      }
      if (!dependencyIdentities.add(dependency.identity)) {
        reasons.add(
          'body_dependency_duplicate:$claimId:${dependency.identity}',
        );
      }
    }
    if (reviewers.any((id) => !_isSafeId(id)) ||
        reviewers.toSet().length != reviewers.length) {
      reasons.add('body_reviewers_invalid:$claimId');
    }
    if (reviewArtifactIds.any((id) => !_isSafeId(id)) ||
        reviewArtifactIds.toSet().length != reviewArtifactIds.length) {
      reasons.add('body_review_artifacts_invalid:$claimId');
    }
    final reviewedAt = reviewedAtUtc == null
        ? null
        : DateTime.tryParse(reviewedAtUtc!);
    final reviewBy = DateTime.tryParse(reviewByUtc);
    if (reviewedAtUtc != null && (reviewedAt == null || !reviewedAt.isUtc)) {
      reasons.add('body_reviewed_at_invalid:$claimId');
    }
    if (reviewBy == null || !reviewBy.isUtc) {
      reasons.add('body_review_by_invalid:$claimId');
    }
    if (reviewedAt != null &&
        reviewBy != null &&
        !reviewBy.isAfter(reviewedAt)) {
      reasons.add('body_review_window_invalid:$claimId');
    }
    if (reviewState == EvidenceSynthesisReviewState.complete &&
        (reviewers.length < 2 ||
            reviewArtifactIds.length < 2 ||
            reviewedAt == null)) {
      reasons.add('body_complete_review_evidence_missing:$claimId');
    }
    if (rationale.trim().isEmpty || applicabilityBoundary.trim().isEmpty) {
      reasons.add('body_decision_boundary_missing:$claimId');
    }
    return List.unmodifiable(reasons);
  }

  Map<String, Object?> get canonicalPayload => {
    'claim_id': claimId,
    'claim': claim,
    'claim_kind': claimKind.name,
    'provider_ids': _sorted(providerIds),
    'expected_outcome_id': expectedOutcomeId,
    'expected_measure_id': expectedMeasureId,
    'expected_direction': expectedDirection.name,
    'minimum_independent_families': minimumIndependentFamilies,
    'findings': findings
        .map((finding) => finding.canonicalPayload)
        .toList(growable: false),
    'dependencies':
        dependencies
            .map((dependency) => dependency.canonicalPayload)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                _canonicalJson(left).compareTo(_canonicalJson(right)),
          ),
    'declared_certainty': declaredCertainty.name,
    'review_state': reviewState.name,
    'reviewers': _sorted(reviewers),
    'review_artifact_ids': _sorted(reviewArtifactIds),
    'reviewed_at_utc': reviewedAtUtc,
    'review_by_utc': reviewByUtc,
    'rationale': rationale,
    'applicability_boundary': applicabilityBoundary,
  };

  String get bodySha256 => _sha256(canonicalPayload);

  EvidenceSynthesisBody copyWith({
    List<EvidenceStudyFinding>? findings,
    List<EvidenceFindingDependency>? dependencies,
    EvidenceBodyCertainty? declaredCertainty,
    EvidenceSynthesisReviewState? reviewState,
    List<String>? reviewers,
    List<String>? reviewArtifactIds,
    String? reviewedAtUtc,
    String? reviewByUtc,
    int? minimumIndependentFamilies,
  }) {
    return EvidenceSynthesisBody(
      claimId: claimId,
      claim: claim,
      claimKind: claimKind,
      providerIds: providerIds,
      expectedOutcomeId: expectedOutcomeId,
      expectedMeasureId: expectedMeasureId,
      expectedDirection: expectedDirection,
      minimumIndependentFamilies:
          minimumIndependentFamilies ?? this.minimumIndependentFamilies,
      findings: findings ?? this.findings,
      dependencies: dependencies ?? this.dependencies,
      declaredCertainty: declaredCertainty ?? this.declaredCertainty,
      reviewState: reviewState ?? this.reviewState,
      reviewers: reviewers ?? this.reviewers,
      reviewArtifactIds: reviewArtifactIds ?? this.reviewArtifactIds,
      reviewedAtUtc: reviewedAtUtc ?? this.reviewedAtUtc,
      reviewByUtc: reviewByUtc ?? this.reviewByUtc,
      rationale: rationale,
      applicabilityBoundary: applicabilityBoundary,
    );
  }
}

final class EvidenceBodyAdjudication {
  final EvidenceSynthesisBody body;
  final EvidenceSynthesisDisposition disposition;
  final List<String> reasons;
  final int independentFamilyCount;
  final List<String> repeatedIndependenceGroupIds;
  final List<List<String>> dependentFindingComponents;
  final Map<EvidenceFindingDirection, int> directionCounts;

  EvidenceBodyAdjudication({
    required this.body,
    required this.disposition,
    required List<String> reasons,
    required this.independentFamilyCount,
    required List<String> repeatedIndependenceGroupIds,
    required List<List<String>> dependentFindingComponents,
    required Map<EvidenceFindingDirection, int> directionCounts,
  }) : reasons = List.unmodifiable(reasons),
       repeatedIndependenceGroupIds = List.unmodifiable(
         repeatedIndependenceGroupIds,
       ),
       dependentFindingComponents = List.unmodifiable(
         dependentFindingComponents.map(List<String>.unmodifiable),
       ),
       directionCounts = Map.unmodifiable(directionCounts);

  Map<String, Object?> toJson() => {
    ...body.canonicalPayload,
    'body_sha256': body.bodySha256,
    'disposition': disposition.name,
    'reasons': reasons,
    'independent_family_count': independentFamilyCount,
    'repeated_independence_group_ids': repeatedIndependenceGroupIds,
    'dependent_finding_components': dependentFindingComponents,
    'direction_counts': {
      for (final direction in EvidenceFindingDirection.values)
        direction.name: directionCounts[direction] ?? 0,
    },
  };
}

final class EvidenceSynthesisAssessment {
  final DateTime asOfUtc;
  final String registrySha256;
  final List<EvidenceBodyAdjudication> adjudications;
  final List<String> integrityReasons;

  EvidenceSynthesisAssessment({
    required this.asOfUtc,
    required this.registrySha256,
    required List<EvidenceBodyAdjudication> adjudications,
    required List<String> integrityReasons,
  }) : adjudications = List.unmodifiable(adjudications),
       integrityReasons = List.unmodifiable(integrityReasons);

  List<EvidenceBodyAdjudication> get heldBodies => adjudications
      .where(
        (entry) =>
            entry.disposition == EvidenceSynthesisDisposition.holdForReview,
      )
      .toList(growable: false);

  List<EvidenceBodyAdjudication> get blockedBodies => adjudications
      .where(
        (entry) =>
            entry.disposition ==
            EvidenceSynthesisDisposition.blockAffectedProviders,
      )
      .toList(growable: false);

  bool get requiresRequalification =>
      integrityReasons.isNotEmpty ||
      heldBodies.isNotEmpty ||
      blockedBodies.isNotEmpty;

  Set<String> get affectedProviderIds => {
    for (final entry in [...heldBodies, ...blockedBodies])
      ...entry.body.providerIds,
  };

  String get snapshotSha256 => _sha256(<String, Object?>{
    'registry_sha256': registrySha256,
    'as_of_utc': asOfUtc.toUtc().toIso8601String(),
    'adjudications': adjudications.map((entry) => entry.toJson()).toList(),
    'integrity_reasons': integrityReasons,
  });

  Map<String, Object?> toJson() => {
    'registry_sha256': registrySha256,
    'snapshot_sha256': snapshotSha256,
    'as_of_utc': asOfUtc.toUtc().toIso8601String(),
    'requires_requalification': requiresRequalification,
    'held_claim_ids': _sorted(heldBodies.map((entry) => entry.body.claimId)),
    'blocked_claim_ids': _sorted(
      blockedBodies.map((entry) => entry.body.claimId),
    ),
    'affected_provider_ids': _sorted(affectedProviderIds),
    'integrity_reasons': integrityReasons,
    'bodies': adjudications.map((entry) => entry.toJson()).toList(),
    'boundary':
        'This deterministic matrix preserves support, null, opposing and '
        'adverse findings without averaging them into a clinical truth score. '
        'Declared certainty is reviewer-authored and is not inferred from '
        'citation count. An allowed disposition permits only the governed '
        'research trace; it is not clinical validation, medical advice, '
        'regulatory acceptance, or a treatment-effect claim.',
  };
}

final class EvidenceSynthesisRegistry {
  static const String schema = 'parkinsum.claim-evidence-synthesis-registry/2';
  static const String registryVersion = '2026.09.27-v2';

  final List<EvidenceSynthesisBody> bodies;

  EvidenceSynthesisRegistry({required List<EvidenceSynthesisBody> bodies})
    : bodies = List.unmodifiable(bodies);

  static final EvidenceSynthesisRegistry current = EvidenceSynthesisRegistry(
    bodies: [
      _pendingBody(
        claimId: 'claim.meal_delay_direction.nutt_1984',
        claim:
            'A small selected human study supports meal-associated delay and '
            'LNAA competition direction, not an individual timing rule.',
        claimKind: EvidenceClaimKind.empiricalAssociation,
        providerIds: const [
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
        outcomeId: 'levodopa_timing_after_meal',
        measureId: 'directional_pk_observation',
        sourceRevision: 'pubmed-record-6694694',
        design: EvidenceStudyDesign.selectedHumanPharmacokinetic,
        population: 'Nine selected participants in a historical human study.',
        exposure: 'Meal and amino-acid exposure around levodopa.',
        comparator: 'Within-study timing and exposure comparison.',
        independenceGroupId: 'cohort.nutt_1984',
        minimumIndependentFamilies: 2,
        limitation:
            'Small selected sample and historical methods; no patient '
            'calibration or universal timing rule.',
      ),
      _pendingBody(
        claimId: 'claim.gastric_peak_association.doi_2012',
        claim:
            'A small observational Parkinson cohort associates delayed gastric '
            'emptying with later plasma levodopa peak.',
        claimKind: EvidenceClaimKind.empiricalAssociation,
        providerIds: const [
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'mechanistic_conflict',
        ],
        outcomeId: 'plasma_levodopa_peak_timing',
        measureId: 'directional_association',
        sourceRevision: 'pubmed-record-22632782',
        design: EvidenceStudyDesign.observationalCohort,
        population: 'Thirty-one participants with Parkinson disease.',
        exposure: 'Observed gastric-emptying timing.',
        comparator: 'Earlier versus later gastric-emptying observations.',
        independenceGroupId: 'cohort.doi_2012',
        minimumIndependentFamilies: 2,
        limitation:
            'Observational association; not causal proof or validation of '
            'ParkinSUM curve parameters.',
      ),
      _pendingBody(
        claimId: 'claim.gastric_halftime_measurement.zinsmeister_2012',
        claim:
            'Hourly scintigraphic measurements can estimate solid gastric '
            'half-time over the studied measurement range.',
        claimKind: EvidenceClaimKind.measurementMethod,
        providerIds: const ['gastric_emptying'],
        outcomeId: 'solid_gastric_half_time',
        measureId: 'measurement_method_agreement',
        sourceRevision: 'pubmed-record-22812490',
        design: EvidenceStudyDesign.measurementValidation,
        population: 'One hundred fifty-five studied subjects.',
        exposure: 'Hourly scintigraphic acquisition.',
        comparator: 'Reference measurement schedule in the study.',
        independenceGroupId: 'cohort.zinsmeister_2012',
        minimumIndependentFamilies: 2,
        limitation:
            'Measurement-method evidence only; it supplies no ParkinSUM point '
            'values or individual Parkinson prediction.',
      ),
      _pendingBody(
        claimId: 'claim.amino_acid_input_identity.fdc',
        claim:
            'FoodData Central exposes amino-acid nutrient fields that may be '
            'preserved as measured or missing composition inputs.',
        claimKind: EvidenceClaimKind.dataContract,
        providerIds: const [
          'meal_composition_normalizer',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
        outcomeId: 'amino_acid_field_identity',
        measureId: 'source_schema_presence',
        sourceRevision: 'api-spec-reviewed-2026-08-18',
        design: EvidenceStudyDesign.sourceSpecification,
        population: 'FoodData Central public data contract.',
        exposure: 'Amino-acid nutrient field definitions.',
        comparator: 'Not applicable to a structural source contract.',
        independenceGroupId: 'spec.usda_fdc',
        minimumIndependentFamilies: 1,
        limitation:
            'Composition identity only; field presence does not establish '
            'levodopa-food mechanism magnitude.',
        expectedDirection: EvidenceFindingDirection.notApplicable,
      ),
      _pendingBody(
        claimId: 'claim.context_of_use_credibility.fda_2023',
        claim:
            'Computational-model credibility should be assessed against a '
            'defined question of interest, context of use, risk, and evidence.',
        claimKind: EvidenceClaimKind.governanceGuidance,
        providerIds: const [
          'meal_composition_normalizer',
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
        outcomeId: 'model_credibility_governance',
        measureId: 'guidance_contract',
        sourceRevision: 'final-guidance-2023-11',
        design: EvidenceStudyDesign.regulatoryGuidance,
        population: 'FDA computational-model credibility guidance scope.',
        exposure: 'Risk-informed credibility assessment framework.',
        comparator: 'Not applicable to a governance guidance document.',
        independenceGroupId: 'guidance.fda_cms_2023',
        minimumIndependentFamilies: 1,
        limitation:
            'Governance method only; not FDA review, qualification, clearance, '
            'clinical validation, or evidence that ParkinSUM meets the guidance.',
        expectedDirection: EvidenceFindingDirection.notApplicable,
      ),
    ],
  );

  List<String> integrityReasons({
    required EvidenceCurrencyAssessment currencyAssessment,
    MechanisticApplicabilityManifest? manifest,
  }) {
    final effectiveManifest =
        manifest ?? MechanisticApplicabilityManifest.current;
    final reasons = <String>[];
    final bodyIds = <String>{};
    final bodyHashes = <String>{};
    for (final body in bodies) {
      reasons.addAll(body.integrityReasons);
      if (!bodyIds.add(body.claimId)) {
        reasons.add('synthesis_body_claim_duplicate:${body.claimId}');
      }
      if (!bodyHashes.add(body.bodySha256)) {
        reasons.add('synthesis_body_duplicate:${body.claimId}');
      }
    }
    final knownProviders = effectiveManifest.providers
        .map((provider) => provider.providerId)
        .toSet();
    final coveredProviders = bodies.expand((body) => body.providerIds).toSet();
    for (final provider in coveredProviders.difference(knownProviders)) {
      reasons.add('synthesis_provider_unknown:$provider');
    }
    for (final provider in knownProviders.difference(coveredProviders)) {
      reasons.add('synthesis_provider_missing:$provider');
    }
    final currencyClaims = currencyAssessment.records
        .map((record) => record.claimId)
        .toSet();
    final referencedCurrencyClaims = bodies
        .expand((body) => body.findings)
        .map((finding) => finding.evidenceCurrencyClaimId)
        .toSet();
    for (final claim in referencedCurrencyClaims.difference(currencyClaims)) {
      reasons.add('synthesis_currency_claim_unknown:$claim');
    }
    for (final claim in currencyClaims.difference(referencedCurrencyClaims)) {
      reasons.add('synthesis_currency_claim_unmapped:$claim');
    }
    reasons.addAll(
      currencyAssessment.integrityReasons.map(
        (reason) => 'synthesis_currency_integrity:$reason',
      ),
    );
    return List.unmodifiable(reasons);
  }

  String get registrySha256 => _sha256(<String, Object?>{
    'schema': schema,
    'registry_version': registryVersion,
    'bodies': bodies.map((body) => body.canonicalPayload).toList(),
  });

  EvidenceSynthesisAssessment assess({
    required DateTime asOfUtc,
    required EvidenceCurrencyAssessment currencyAssessment,
    MechanisticApplicabilityManifest? manifest,
  }) {
    final normalizedAsOf = asOfUtc.toUtc();
    final registryReasons = <String>[
      ...integrityReasons(
        currencyAssessment: currencyAssessment,
        manifest: manifest,
      ),
      if (currencyAssessment.asOfUtc.toUtc() != normalizedAsOf)
        'synthesis_currency_snapshot_time_mismatch',
    ];
    final currencyByClaim = {
      for (final record in currencyAssessment.records) record.claimId: record,
    };
    final heldCurrencyClaims = currencyAssessment.heldRecords
        .map((record) => record.claimId)
        .toSet();
    final blockedCurrencyClaims = currencyAssessment.blockedRecords
        .map((record) => record.claimId)
        .toSet();
    return EvidenceSynthesisAssessment(
      asOfUtc: normalizedAsOf,
      registrySha256: registrySha256,
      adjudications: bodies
          .map(
            (body) => _adjudicateBody(
              body: body,
              asOfUtc: normalizedAsOf,
              currencyByClaim: currencyByClaim,
              heldCurrencyClaims: heldCurrencyClaims,
              blockedCurrencyClaims: blockedCurrencyClaims,
            ),
          )
          .toList(growable: false),
      integrityReasons: registryReasons,
    );
  }

  Map<String, Object?> toJson({
    required DateTime asOfUtc,
    required EvidenceCurrencyAssessment currencyAssessment,
  }) => {
    'schema': schema,
    'registry_version': registryVersion,
    ...assess(
      asOfUtc: asOfUtc,
      currencyAssessment: currencyAssessment,
    ).toJson(),
  };
}

EvidenceSynthesisBody _pendingBody({
  required String claimId,
  required String claim,
  required EvidenceClaimKind claimKind,
  required List<String> providerIds,
  required String outcomeId,
  required String measureId,
  required String sourceRevision,
  required EvidenceStudyDesign design,
  required String population,
  required String exposure,
  required String comparator,
  required String independenceGroupId,
  required int minimumIndependentFamilies,
  required String limitation,
  EvidenceFindingDirection expectedDirection =
      EvidenceFindingDirection.supports,
}) {
  return EvidenceSynthesisBody(
    claimId: claimId,
    claim: claim,
    claimKind: claimKind,
    providerIds: providerIds,
    expectedOutcomeId: outcomeId,
    expectedMeasureId: measureId,
    expectedDirection: expectedDirection,
    minimumIndependentFamilies: minimumIndependentFamilies,
    findings: [
      EvidenceStudyFinding(
        findingId: 'finding.$claimId.primary',
        evidenceCurrencyClaimId: claimId,
        sourceRevision: sourceRevision,
        independenceGroupId: independenceGroupId,
        studyDesign: design,
        population: population,
        interventionOrExposure: exposure,
        comparator: comparator,
        outcomeId: outcomeId,
        measureId: measureId,
        direction: expectedDirection,
        effectEstimate: null,
        lowerBound: null,
        upperBound: null,
        effectUnit: null,
        riskOfBias: EvidenceRiskOfBias.notAssessed,
        applicability: EvidenceApplicability.notAssessed,
        precision: EvidencePrecision.notAssessed,
        reportingBias: EvidenceReportingBias.notAssessed,
        limitation: limitation,
      ),
    ],
    declaredCertainty: EvidenceBodyCertainty.notAssessed,
    reviewState: EvidenceSynthesisReviewState.awaitingIndependentReview,
    reviewers: const ['parkinsum-evidence-review'],
    reviewArtifactIds: ['review.pending.${claimId.replaceAll(':', '.')}'],
    reviewedAtUtc: null,
    reviewByUtc: '2027-02-18T22:00:00Z',
    rationale:
        'Initial source-bounded extraction is recorded, but an independent '
        'dual review and body-level certainty decision have not been completed.',
    applicabilityBoundary: limitation,
  );
}

EvidenceBodyAdjudication _adjudicateBody({
  required EvidenceSynthesisBody body,
  required DateTime asOfUtc,
  required Map<String, EvidenceCurrencyRecord> currencyByClaim,
  required Set<String> heldCurrencyClaims,
  required Set<String> blockedCurrencyClaims,
}) {
  final blockReasons = <String>{};
  final holdReasons = <String>{};
  blockReasons.addAll(body.integrityReasons);

  final groupCounts = <String, int>{};
  final parent = <String, String>{
    for (final finding in body.findings) finding.findingId: finding.findingId,
  };
  String rootOf(String findingId) {
    var root = findingId;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    var cursor = findingId;
    while (parent[cursor] != cursor) {
      final next = parent[cursor]!;
      parent[cursor] = root;
      cursor = next;
    }
    return root;
  }

  void connect(String firstFindingId, String secondFindingId) {
    if (!parent.containsKey(firstFindingId) ||
        !parent.containsKey(secondFindingId)) {
      return;
    }
    final firstRoot = rootOf(firstFindingId);
    final secondRoot = rootOf(secondFindingId);
    if (firstRoot != secondRoot) {
      final roots = [firstRoot, secondRoot]..sort();
      parent[roots.last] = roots.first;
    }
  }

  final firstFindingByGroup = <String, String>{};
  final directionCounts = {
    for (final direction in EvidenceFindingDirection.values) direction: 0,
  };
  for (final finding in body.findings) {
    groupCounts.update(
      finding.independenceGroupId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    final firstInGroup = firstFindingByGroup.putIfAbsent(
      finding.independenceGroupId,
      () => finding.findingId,
    );
    connect(firstInGroup, finding.findingId);
    directionCounts.update(finding.direction, (count) => count + 1);
    final currency = currencyByClaim[finding.evidenceCurrencyClaimId];
    if (currency == null) {
      blockReasons.add(
        'currency_claim_missing:${finding.evidenceCurrencyClaimId}',
      );
    } else if (currency.sourceRevision != finding.sourceRevision) {
      blockReasons.add('source_revision_mismatch:${finding.findingId}');
    }
    if (blockedCurrencyClaims.contains(finding.evidenceCurrencyClaimId)) {
      blockReasons.add(
        'currency_claim_blocked:${finding.evidenceCurrencyClaimId}',
      );
    } else if (heldCurrencyClaims.contains(finding.evidenceCurrencyClaimId)) {
      holdReasons.add('currency_claim_held:${finding.evidenceCurrencyClaimId}');
    }
    if (finding.outcomeId != body.expectedOutcomeId) {
      blockReasons.add('outcome_mismatch:${finding.findingId}');
    }
    if (finding.measureId != body.expectedMeasureId) {
      blockReasons.add('measure_mismatch:${finding.findingId}');
    }
    if (finding.riskOfBias == EvidenceRiskOfBias.high) {
      holdReasons.add('high_risk_of_bias:${finding.findingId}');
    }
    if (finding.applicability == EvidenceApplicability.indirect) {
      holdReasons.add('indirect_applicability:${finding.findingId}');
    }
    if (finding.precision == EvidencePrecision.veryImprecise) {
      holdReasons.add('very_imprecise:${finding.findingId}');
    }
    if (finding.reportingBias == EvidenceReportingBias.likely) {
      holdReasons.add('reporting_bias_likely:${finding.findingId}');
    }
    if (finding.riskOfBias == EvidenceRiskOfBias.notAssessed ||
        finding.applicability == EvidenceApplicability.notAssessed ||
        finding.precision == EvidencePrecision.notAssessed ||
        finding.reportingBias == EvidenceReportingBias.notAssessed) {
      holdReasons.add('finding_domains_not_assessed:${finding.findingId}');
    }
  }

  for (final dependency in body.dependencies) {
    connect(dependency.firstFindingId, dependency.secondFindingId);
    if (dependency.reviewState != EvidenceDependencyReviewState.confirmed) {
      holdReasons.add(
        'dependency_link_${dependency.reviewState.name}:${dependency.identity}',
      );
    }
  }

  final componentsByRoot = <String, List<String>>{};
  for (final finding in body.findings) {
    componentsByRoot
        .putIfAbsent(rootOf(finding.findingId), () => <String>[])
        .add(finding.findingId);
  }
  final components =
      componentsByRoot.values
          .map((members) => members..sort())
          .toList(growable: false)
        ..sort((left, right) => left.first.compareTo(right.first));
  final dependentComponents = components
      .where((members) => members.length > 1)
      .toList(growable: false);
  for (final members in dependentComponents) {
    holdReasons.add('dependent_finding_component:${members.join(',')}');
  }

  final repeatedGroups =
      groupCounts.entries
          .where((entry) => entry.value > 1)
          .map((entry) => entry.key)
          .toList(growable: false)
        ..sort();
  if (repeatedGroups.isNotEmpty) {
    holdReasons.add('dependent_evidence_groups:${repeatedGroups.join(',')}');
  }
  if (components.length < body.minimumIndependentFamilies) {
    holdReasons.add(
      'independent_evidence_insufficient:${components.length}/'
      '${body.minimumIndependentFamilies}',
    );
  }

  final supports = directionCounts[EvidenceFindingDirection.supports]!;
  final opposes = directionCounts[EvidenceFindingDirection.opposes]!;
  final adverse = directionCounts[EvidenceFindingDirection.adverse]!;
  final notApplicable =
      directionCounts[EvidenceFindingDirection.notApplicable]!;
  if (adverse > 0) blockReasons.add('adverse_finding_present');
  if (supports > 0 && opposes > 0) {
    blockReasons.add('directional_conflict');
  } else if (opposes > 0) {
    blockReasons.add('claim_opposed');
  }
  if (body.expectedDirection == EvidenceFindingDirection.supports &&
      supports == 0 &&
      opposes == 0 &&
      adverse == 0) {
    holdReasons.add('support_not_demonstrated');
  }
  if (body.expectedDirection == EvidenceFindingDirection.notApplicable &&
      notApplicable != body.findings.length) {
    blockReasons.add('non_effect_contract_direction_mismatch');
  }

  final reviewBy = DateTime.tryParse(body.reviewByUtc);
  final reviewedAt = body.reviewedAtUtc == null
      ? null
      : DateTime.tryParse(body.reviewedAtUtc!);
  if (reviewedAt != null && reviewedAt.isAfter(asOfUtc)) {
    blockReasons.add('body_reviewed_in_future');
  }
  if (reviewBy == null || asOfUtc.isAfter(reviewBy)) {
    holdReasons.add('body_review_expired');
  }
  if (body.reviewState != EvidenceSynthesisReviewState.complete) {
    holdReasons.add('review_state:${body.reviewState.name}');
  }
  if (body.reviewers.length < 2 || body.reviewArtifactIds.length < 2) {
    holdReasons.add('independent_dual_review_missing');
  }
  if (body.declaredCertainty == EvidenceBodyCertainty.notAssessed) {
    holdReasons.add('body_certainty_not_assessed');
  }

  final disposition = blockReasons.isNotEmpty
      ? EvidenceSynthesisDisposition.blockAffectedProviders
      : holdReasons.isNotEmpty
      ? EvidenceSynthesisDisposition.holdForReview
      : EvidenceSynthesisDisposition.allowResearchTraceOnly;
  final reasons =
      disposition == EvidenceSynthesisDisposition.blockAffectedProviders
      ? [...blockReasons, ...holdReasons]
      : [...holdReasons];
  reasons.sort();
  return EvidenceBodyAdjudication(
    body: body,
    disposition: disposition,
    reasons: reasons,
    independentFamilyCount: components.length,
    repeatedIndependenceGroupIds: repeatedGroups,
    dependentFindingComponents: dependentComponents,
    directionCounts: directionCounts,
  );
}

bool _isSafeId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$').hasMatch(value);

List<String> _sorted(Iterable<String> values) => values.toList()..sort();

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return jsonEncode(value);
  if (value is String) return jsonEncode(value);
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
  }
  throw ArgumentError('Unsupported canonical value: ${value.runtimeType}');
}
