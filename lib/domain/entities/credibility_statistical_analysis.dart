import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'credibility_evidence_execution_attestation.dart';

enum StatisticalEndpointRole {
  primary,
  keySecondary,
  secondary,
  exploratory,
  safety,
}

enum StatisticalIntercurrentEventStrategy {
  treatmentPolicy,
  hypothetical,
  compositeVariable,
  whileOnTreatment,
  principalStratum,
}

enum StatisticalResultStatus {
  reported,
  nullResult,
  inconclusive,
  failed,
  contradictory,
  adverse,
  missing,
}

enum StatisticalMultiplicityMethod {
  noneSinglePrimary,
  fixedSequence,
  bonferroni,
  holm,
  gatekeeping,
}

enum StatisticalGovernanceStatus {
  mechanicallyObserved,
  held,
  unknown,
  violated,
  revoked,
}

enum StatisticalFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  contractIncomplete,
  contractNotProspective,
  estimandMismatch,
  endpointContractMismatch,
  analysisSetChanged,
  missingDataMethodChanged,
  alphaInflation,
  multiplicityMissing,
  interimPlanMismatch,
  sampleSizeDrift,
  resultOmitted,
  intervalInvalid,
  pValueIntervalMismatch,
  multiplicityResultMismatch,
  denominatorMismatch,
  sensitivityMissing,
  sensitivityEstimandChanged,
  unplannedSensitivity,
  deviationChainBroken,
  postResultChange,
  invalidClock,
  revocation,
}

final class StatisticalIntercurrentEventHandling {
  final String eventId;
  final String definition;
  final StatisticalIntercurrentEventStrategy strategy;
  final String rationale;

  const StatisticalIntercurrentEventHandling({
    required this.eventId,
    required this.definition,
    required this.strategy,
    required this.rationale,
  });

  StatisticalIntercurrentEventHandling copyWith({
    String? definition,
    StatisticalIntercurrentEventStrategy? strategy,
    String? rationale,
  }) => StatisticalIntercurrentEventHandling(
    eventId: eventId,
    definition: definition ?? this.definition,
    strategy: strategy ?? this.strategy,
    rationale: rationale ?? this.rationale,
  );

  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'definition': definition,
    'strategy': strategy.name,
    'rationale': rationale,
  };
}

final class StatisticalEstimand {
  final String estimandId;
  final String scientificQuestion;
  final String treatmentCondition;
  final String population;
  final String variable;
  final String timeHorizon;
  final String populationSummary;
  final String effectMeasure;
  final List<StatisticalIntercurrentEventHandling> intercurrentEvents;

  StatisticalEstimand({
    required this.estimandId,
    required this.scientificQuestion,
    required this.treatmentCondition,
    required this.population,
    required this.variable,
    required this.timeHorizon,
    required this.populationSummary,
    required this.effectMeasure,
    required List<StatisticalIntercurrentEventHandling> intercurrentEvents,
  }) : intercurrentEvents = List.unmodifiable(intercurrentEvents);

  StatisticalEstimand copyWith({
    String? scientificQuestion,
    String? population,
    String? variable,
    String? populationSummary,
    String? effectMeasure,
    List<StatisticalIntercurrentEventHandling>? intercurrentEvents,
  }) => StatisticalEstimand(
    estimandId: estimandId,
    scientificQuestion: scientificQuestion ?? this.scientificQuestion,
    treatmentCondition: treatmentCondition,
    population: population ?? this.population,
    variable: variable ?? this.variable,
    timeHorizon: timeHorizon,
    populationSummary: populationSummary ?? this.populationSummary,
    effectMeasure: effectMeasure ?? this.effectMeasure,
    intercurrentEvents: intercurrentEvents ?? this.intercurrentEvents,
  );

  Map<String, Object?> toJson() => {
    'estimand_id': estimandId,
    'scientific_question': scientificQuestion,
    'treatment_condition': treatmentCondition,
    'population': population,
    'variable': variable,
    'time_horizon': timeHorizon,
    'population_summary': populationSummary,
    'effect_measure': effectMeasure,
    'intercurrent_events': intercurrentEvents
        .map((item) => item.toJson())
        .toList(),
  };
}

final class StatisticalEndpointSpecification {
  final String endpointId;
  final String estimandId;
  final StatisticalEndpointRole role;
  final int hierarchyOrder;
  final String familyId;
  final String analysisSetId;
  final String estimatorId;
  final String missingDataMethodId;
  final String hypothesisId;
  final int sidedness;
  final double allocatedAlpha;
  final double nullValue;
  final String decisionRule;

  const StatisticalEndpointSpecification({
    required this.endpointId,
    required this.estimandId,
    required this.role,
    required this.hierarchyOrder,
    required this.familyId,
    required this.analysisSetId,
    required this.estimatorId,
    required this.missingDataMethodId,
    required this.hypothesisId,
    required this.sidedness,
    required this.allocatedAlpha,
    required this.nullValue,
    required this.decisionRule,
  });

  bool get confirmatory =>
      role == StatisticalEndpointRole.primary ||
      role == StatisticalEndpointRole.keySecondary;

  StatisticalEndpointSpecification copyWith({
    String? estimandId,
    StatisticalEndpointRole? role,
    int? hierarchyOrder,
    String? familyId,
    String? analysisSetId,
    String? estimatorId,
    String? missingDataMethodId,
    int? sidedness,
    double? allocatedAlpha,
    String? decisionRule,
  }) => StatisticalEndpointSpecification(
    endpointId: endpointId,
    estimandId: estimandId ?? this.estimandId,
    role: role ?? this.role,
    hierarchyOrder: hierarchyOrder ?? this.hierarchyOrder,
    familyId: familyId ?? this.familyId,
    analysisSetId: analysisSetId ?? this.analysisSetId,
    estimatorId: estimatorId ?? this.estimatorId,
    missingDataMethodId: missingDataMethodId ?? this.missingDataMethodId,
    hypothesisId: hypothesisId,
    sidedness: sidedness ?? this.sidedness,
    allocatedAlpha: allocatedAlpha ?? this.allocatedAlpha,
    nullValue: nullValue,
    decisionRule: decisionRule ?? this.decisionRule,
  );

  Map<String, Object?> toJson() => {
    'endpoint_id': endpointId,
    'estimand_id': estimandId,
    'role': role.name,
    'hierarchy_order': hierarchyOrder,
    'family_id': familyId,
    'analysis_set_id': analysisSetId,
    'estimator_id': estimatorId,
    'missing_data_method_id': missingDataMethodId,
    'hypothesis_id': hypothesisId,
    'sidedness': sidedness,
    'allocated_alpha': allocatedAlpha,
    'null_value': nullValue,
    'decision_rule': decisionRule,
  };
}

final class StatisticalErrorControlPlan {
  final double overallAlpha;
  final double confidenceLevel;
  final StatisticalMultiplicityMethod multiplicityMethod;
  final String confirmatoryFamilyId;
  final int interimLookCount;
  final String alphaSpendingPlanSha256;
  final int targetSampleSize;
  final int minimumInformativeSampleSize;
  final double targetPower;
  final double assumedEffect;
  final double assumedStandardDeviation;
  final double expectedAttritionFraction;
  final String sampleSizeMethod;
  final String authoredAtUtc;
  final String frozenAtUtc;
  final String firstResultAccessAtUtc;
  final bool lockedBeforeResultAccess;

  const StatisticalErrorControlPlan({
    required this.overallAlpha,
    required this.confidenceLevel,
    required this.multiplicityMethod,
    required this.confirmatoryFamilyId,
    required this.interimLookCount,
    required this.alphaSpendingPlanSha256,
    required this.targetSampleSize,
    required this.minimumInformativeSampleSize,
    required this.targetPower,
    required this.assumedEffect,
    required this.assumedStandardDeviation,
    required this.expectedAttritionFraction,
    required this.sampleSizeMethod,
    required this.authoredAtUtc,
    required this.frozenAtUtc,
    required this.firstResultAccessAtUtc,
    required this.lockedBeforeResultAccess,
  });

  StatisticalErrorControlPlan copyWith({
    double? overallAlpha,
    double? confidenceLevel,
    StatisticalMultiplicityMethod? multiplicityMethod,
    int? interimLookCount,
    String? alphaSpendingPlanSha256,
    int? targetSampleSize,
    int? minimumInformativeSampleSize,
    double? targetPower,
    double? assumedEffect,
    double? assumedStandardDeviation,
    double? expectedAttritionFraction,
    String? sampleSizeMethod,
    String? authoredAtUtc,
    String? frozenAtUtc,
    String? firstResultAccessAtUtc,
    bool? lockedBeforeResultAccess,
  }) => StatisticalErrorControlPlan(
    overallAlpha: overallAlpha ?? this.overallAlpha,
    confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    multiplicityMethod: multiplicityMethod ?? this.multiplicityMethod,
    confirmatoryFamilyId: confirmatoryFamilyId,
    interimLookCount: interimLookCount ?? this.interimLookCount,
    alphaSpendingPlanSha256:
        alphaSpendingPlanSha256 ?? this.alphaSpendingPlanSha256,
    targetSampleSize: targetSampleSize ?? this.targetSampleSize,
    minimumInformativeSampleSize:
        minimumInformativeSampleSize ?? this.minimumInformativeSampleSize,
    targetPower: targetPower ?? this.targetPower,
    assumedEffect: assumedEffect ?? this.assumedEffect,
    assumedStandardDeviation:
        assumedStandardDeviation ?? this.assumedStandardDeviation,
    expectedAttritionFraction:
        expectedAttritionFraction ?? this.expectedAttritionFraction,
    sampleSizeMethod: sampleSizeMethod ?? this.sampleSizeMethod,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    frozenAtUtc: frozenAtUtc ?? this.frozenAtUtc,
    firstResultAccessAtUtc:
        firstResultAccessAtUtc ?? this.firstResultAccessAtUtc,
    lockedBeforeResultAccess:
        lockedBeforeResultAccess ?? this.lockedBeforeResultAccess,
  );

  Map<String, Object?> toJson() => {
    'overall_alpha': overallAlpha,
    'confidence_level': confidenceLevel,
    'multiplicity_method': multiplicityMethod.name,
    'confirmatory_family_id': confirmatoryFamilyId,
    'interim_look_count': interimLookCount,
    'alpha_spending_plan_sha256': alphaSpendingPlanSha256,
    'target_sample_size': targetSampleSize,
    'minimum_informative_sample_size': minimumInformativeSampleSize,
    'target_power': targetPower,
    'assumed_effect': assumedEffect,
    'assumed_standard_deviation': assumedStandardDeviation,
    'expected_attrition_fraction': expectedAttritionFraction,
    'sample_size_method': sampleSizeMethod,
    'authored_at_utc': authoredAtUtc,
    'frozen_at_utc': frozenAtUtc,
    'first_result_access_at_utc': firstResultAccessAtUtc,
    'locked_before_result_access': lockedBeforeResultAccess,
  };
}

final class StatisticalAnalysisResult {
  final String endpointId;
  final String estimandId;
  final StatisticalResultStatus status;
  final double? estimate;
  final double? lowerConfidenceLimit;
  final double? upperConfidenceLimit;
  final double? pValue;
  final double? multiplicityAdjustedPValue;
  final double confidenceLevel;
  final int denominator;
  final int missingCount;
  final int excludedCount;
  final String analysisSetId;
  final String estimatorId;
  final String missingDataMethodId;
  final String resultArtifactSha256;
  final String recordedAtUtc;
  final String interpretation;

  const StatisticalAnalysisResult({
    required this.endpointId,
    required this.estimandId,
    required this.status,
    required this.estimate,
    required this.lowerConfidenceLimit,
    required this.upperConfidenceLimit,
    required this.pValue,
    required this.multiplicityAdjustedPValue,
    required this.confidenceLevel,
    required this.denominator,
    required this.missingCount,
    required this.excludedCount,
    required this.analysisSetId,
    required this.estimatorId,
    required this.missingDataMethodId,
    required this.resultArtifactSha256,
    required this.recordedAtUtc,
    required this.interpretation,
  });

  StatisticalAnalysisResult copyWith({
    String? endpointId,
    String? estimandId,
    StatisticalResultStatus? status,
    double? estimate,
    double? lowerConfidenceLimit,
    double? upperConfidenceLimit,
    double? pValue,
    double? multiplicityAdjustedPValue,
    double? confidenceLevel,
    int? denominator,
    int? missingCount,
    int? excludedCount,
    String? analysisSetId,
    String? estimatorId,
    String? missingDataMethodId,
    String? resultArtifactSha256,
    String? recordedAtUtc,
    String? interpretation,
    bool clearEstimate = false,
    bool clearInterval = false,
    bool clearPValue = false,
    bool clearAdjustedPValue = false,
  }) => StatisticalAnalysisResult(
    endpointId: endpointId ?? this.endpointId,
    estimandId: estimandId ?? this.estimandId,
    status: status ?? this.status,
    estimate: clearEstimate ? null : estimate ?? this.estimate,
    lowerConfidenceLimit: clearInterval
        ? null
        : lowerConfidenceLimit ?? this.lowerConfidenceLimit,
    upperConfidenceLimit: clearInterval
        ? null
        : upperConfidenceLimit ?? this.upperConfidenceLimit,
    pValue: clearPValue ? null : pValue ?? this.pValue,
    multiplicityAdjustedPValue: clearAdjustedPValue
        ? null
        : multiplicityAdjustedPValue ?? this.multiplicityAdjustedPValue,
    confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    denominator: denominator ?? this.denominator,
    missingCount: missingCount ?? this.missingCount,
    excludedCount: excludedCount ?? this.excludedCount,
    analysisSetId: analysisSetId ?? this.analysisSetId,
    estimatorId: estimatorId ?? this.estimatorId,
    missingDataMethodId: missingDataMethodId ?? this.missingDataMethodId,
    resultArtifactSha256: resultArtifactSha256 ?? this.resultArtifactSha256,
    recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
    interpretation: interpretation ?? this.interpretation,
  );

  Map<String, Object?> toJson() => {
    'endpoint_id': endpointId,
    'estimand_id': estimandId,
    'status': status.name,
    'estimate': estimate,
    'lower_confidence_limit': lowerConfidenceLimit,
    'upper_confidence_limit': upperConfidenceLimit,
    'p_value': pValue,
    'multiplicity_adjusted_p_value': multiplicityAdjustedPValue,
    'confidence_level': confidenceLevel,
    'denominator': denominator,
    'missing_count': missingCount,
    'excluded_count': excludedCount,
    'analysis_set_id': analysisSetId,
    'estimator_id': estimatorId,
    'missing_data_method_id': missingDataMethodId,
    'result_artifact_sha256': resultArtifactSha256,
    'recorded_at_utc': recordedAtUtc,
    'interpretation': interpretation,
  };
}

final class StatisticalSensitivityResult {
  final String sensitivityId;
  final String endpointId;
  final String estimandId;
  final String variedAssumption;
  final String methodId;
  final bool prospectivelyPlanned;
  final StatisticalResultStatus status;
  final double estimate;
  final double lowerConfidenceLimit;
  final double upperConfidenceLimit;
  final String resultArtifactSha256;

  const StatisticalSensitivityResult({
    required this.sensitivityId,
    required this.endpointId,
    required this.estimandId,
    required this.variedAssumption,
    required this.methodId,
    required this.prospectivelyPlanned,
    required this.status,
    required this.estimate,
    required this.lowerConfidenceLimit,
    required this.upperConfidenceLimit,
    required this.resultArtifactSha256,
  });

  StatisticalSensitivityResult copyWith({
    String? endpointId,
    String? estimandId,
    String? variedAssumption,
    String? methodId,
    bool? prospectivelyPlanned,
    double? estimate,
    double? lowerConfidenceLimit,
    double? upperConfidenceLimit,
    String? resultArtifactSha256,
  }) => StatisticalSensitivityResult(
    sensitivityId: sensitivityId,
    endpointId: endpointId ?? this.endpointId,
    estimandId: estimandId ?? this.estimandId,
    variedAssumption: variedAssumption ?? this.variedAssumption,
    methodId: methodId ?? this.methodId,
    prospectivelyPlanned: prospectivelyPlanned ?? this.prospectivelyPlanned,
    status: status,
    estimate: estimate ?? this.estimate,
    lowerConfidenceLimit: lowerConfidenceLimit ?? this.lowerConfidenceLimit,
    upperConfidenceLimit: upperConfidenceLimit ?? this.upperConfidenceLimit,
    resultArtifactSha256: resultArtifactSha256 ?? this.resultArtifactSha256,
  );

  Map<String, Object?> toJson() => {
    'sensitivity_id': sensitivityId,
    'endpoint_id': endpointId,
    'estimand_id': estimandId,
    'varied_assumption': variedAssumption,
    'method_id': methodId,
    'prospectively_planned': prospectivelyPlanned,
    'status': status.name,
    'estimate': estimate,
    'lower_confidence_limit': lowerConfidenceLimit,
    'upper_confidence_limit': upperConfidenceLimit,
    'result_artifact_sha256': resultArtifactSha256,
  };
}

final class StatisticalDeviationEvent {
  static const String genesisPredecessor =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final int sequence;
  final String eventId;
  final String predecessorSha256;
  final String actorId;
  final String reviewerId;
  final String authorityId;
  final String occurredAtUtc;
  final bool resultsVisible;
  final List<String> affectedContractFields;
  final String reason;
  final bool accepted;

  StatisticalDeviationEvent({
    required this.sequence,
    required this.eventId,
    required this.predecessorSha256,
    required this.actorId,
    required this.reviewerId,
    required this.authorityId,
    required this.occurredAtUtc,
    required this.resultsVisible,
    required List<String> affectedContractFields,
    required this.reason,
    required this.accepted,
  }) : affectedContractFields = List.unmodifiable(affectedContractFields);

  StatisticalDeviationEvent copyWith({
    int? sequence,
    String? predecessorSha256,
    String? actorId,
    String? reviewerId,
    String? occurredAtUtc,
    bool? resultsVisible,
    List<String>? affectedContractFields,
    String? reason,
    bool? accepted,
  }) => StatisticalDeviationEvent(
    sequence: sequence ?? this.sequence,
    eventId: eventId,
    predecessorSha256: predecessorSha256 ?? this.predecessorSha256,
    actorId: actorId ?? this.actorId,
    reviewerId: reviewerId ?? this.reviewerId,
    authorityId: authorityId,
    occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
    resultsVisible: resultsVisible ?? this.resultsVisible,
    affectedContractFields:
        affectedContractFields ?? this.affectedContractFields,
    reason: reason ?? this.reason,
    accepted: accepted ?? this.accepted,
  );

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'event_id': eventId,
    'predecessor_sha256': predecessorSha256,
    'actor_id': actorId,
    'reviewer_id': reviewerId,
    'authority_id': authorityId,
    'occurred_at_utc': occurredAtUtc,
    'results_visible': resultsVisible,
    'affected_contract_fields': [...affectedContractFields]..sort(),
    'reason': reason,
    'accepted': accepted,
  };

  String get eventSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'event_sha256': eventSha256,
  };
}

final class CredibilityStatisticalAnalysisPackage {
  static const String schema =
      'parkinsum.credibility-statistical-analysis-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v8';

  final int schemaVersion;
  final String packageId;
  final String prospectivePlanSha256;
  final String protocolLedgerSha256;
  final String replicationPackageSha256;
  final String analysisPlanSha256;
  final String datasetSha256;
  final String codeSha256;
  final String environmentSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final String authoredBy;
  final String reviewedBy;
  final String authoredAtUtc;
  final List<StatisticalEstimand> estimands;
  final List<StatisticalEndpointSpecification> endpoints;
  final StatisticalErrorControlPlan errorControl;
  final List<StatisticalAnalysisResult> results;
  final List<StatisticalSensitivityResult> sensitivityResults;
  final List<StatisticalDeviationEvent> deviationEvents;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityStatisticalAnalysisPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.prospectivePlanSha256,
    required this.protocolLedgerSha256,
    required this.replicationPackageSha256,
    required this.analysisPlanSha256,
    required this.datasetSha256,
    required this.codeSha256,
    required this.environmentSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.authoredBy,
    required this.reviewedBy,
    required this.authoredAtUtc,
    required List<StatisticalEstimand> estimands,
    required List<StatisticalEndpointSpecification> endpoints,
    required this.errorControl,
    required List<StatisticalAnalysisResult> results,
    required List<StatisticalSensitivityResult> sensitivityResults,
    required List<StatisticalDeviationEvent> deviationEvents,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : estimands = List.unmodifiable(estimands),
       endpoints = List.unmodifiable(endpoints),
       results = List.unmodifiable(results),
       sensitivityResults = List.unmodifiable(sensitivityResults),
       deviationEvents = List.unmodifiable(deviationEvents);

  factory CredibilityStatisticalAnalysisPackage.syntheticCurrent({
    required String prospectivePlanSha256,
    required String protocolLedgerSha256,
    required String replicationPackageSha256,
    required String configurationSha256,
    required String algorithmSourceBundleSha256,
  }) {
    const estimandId = 'estimand.synthetic_mechanistic_trace_difference';
    const familyId = 'family.synthetic_confirmatory';
    final estimands = [
      StatisticalEstimand(
        estimandId: estimandId,
        scientificQuestion:
            'For a fixed synthetic fixture, what is the mean trace difference under the declared comparison?',
        treatmentCondition: 'synthetic comparison A versus B',
        population: 'fixed non-personal synthetic fixture population',
        variable: 'dimensionless modeled trace difference at fixed horizon',
        timeHorizon: 'fixed synthetic horizon',
        populationSummary: 'mean difference',
        effectMeasure: 'difference in synthetic dimensionless means',
        intercurrentEvents: const [
          StatisticalIntercurrentEventHandling(
            eventId: 'ice.synthetic_missing_fixture',
            definition: 'A planned synthetic fixture output is unavailable.',
            strategy: StatisticalIntercurrentEventStrategy.compositeVariable,
            rationale: 'Retain unavailability as an explicit outcome state.',
          ),
          StatisticalIntercurrentEventHandling(
            eventId: 'ice.synthetic_execution_failure',
            definition: 'The deterministic synthetic execution fails.',
            strategy: StatisticalIntercurrentEventStrategy.treatmentPolicy,
            rationale:
                'Preserve failure without replacing it with a numeric zero.',
          ),
        ],
      ),
    ];
    const endpoints = [
      StatisticalEndpointSpecification(
        endpointId: 'endpoint.synthetic_primary_trace',
        estimandId: estimandId,
        role: StatisticalEndpointRole.primary,
        hierarchyOrder: 1,
        familyId: familyId,
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.mean_difference_v1',
        missingDataMethodId: 'missing.composite_state_v1',
        hypothesisId: 'hypothesis.primary_zero_difference',
        sidedness: 2,
        allocatedAlpha: 0.025,
        nullValue: 0,
        decisionRule: 'Report estimate and 95% interval; no clinical claim.',
      ),
      StatisticalEndpointSpecification(
        endpointId: 'endpoint.synthetic_key_secondary',
        estimandId: estimandId,
        role: StatisticalEndpointRole.keySecondary,
        hierarchyOrder: 2,
        familyId: familyId,
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.mean_difference_v1',
        missingDataMethodId: 'missing.composite_state_v1',
        hypothesisId: 'hypothesis.secondary_zero_difference',
        sidedness: 2,
        allocatedAlpha: 0.025,
        nullValue: 0,
        decisionRule: 'Retain null result after multiplicity adjustment.',
      ),
      StatisticalEndpointSpecification(
        endpointId: 'endpoint.synthetic_precision',
        estimandId: estimandId,
        role: StatisticalEndpointRole.secondary,
        hierarchyOrder: 3,
        familyId: 'family.descriptive',
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.mean_difference_v1',
        missingDataMethodId: 'missing.composite_state_v1',
        hypothesisId: 'hypothesis.descriptive_only',
        sidedness: 2,
        allocatedAlpha: 0,
        nullValue: 0,
        decisionRule: 'Describe uncertainty without confirmatory inference.',
      ),
      StatisticalEndpointSpecification(
        endpointId: 'endpoint.synthetic_adverse_fixture',
        estimandId: estimandId,
        role: StatisticalEndpointRole.safety,
        hierarchyOrder: 4,
        familyId: 'family.safety_descriptive',
        analysisSetId: 'analysis_set.safety_synthetic',
        estimatorId: 'estimator.risk_difference_v1',
        missingDataMethodId: 'missing.no_imputation_v1',
        hypothesisId: 'hypothesis.safety_descriptive',
        sidedness: 2,
        allocatedAlpha: 0,
        nullValue: 0,
        decisionRule:
            'Retain adverse direction without benefit-risk inference.',
      ),
      StatisticalEndpointSpecification(
        endpointId: 'endpoint.synthetic_failed_fixture',
        estimandId: estimandId,
        role: StatisticalEndpointRole.exploratory,
        hierarchyOrder: 5,
        familyId: 'family.exploratory',
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.not_executed',
        missingDataMethodId: 'missing.failure_state_v1',
        hypothesisId: 'hypothesis.none',
        sidedness: 2,
        allocatedAlpha: 0,
        nullValue: 0,
        decisionRule: 'Retain execution failure without numeric substitution.',
      ),
    ];
    const resultTime = '2026-08-18T02:30:00.000Z';
    const results = [
      StatisticalAnalysisResult(
        endpointId: 'endpoint.synthetic_primary_trace',
        estimandId: estimandId,
        status: StatisticalResultStatus.reported,
        estimate: 0.35,
        lowerConfidenceLimit: 0.10,
        upperConfidenceLimit: 0.60,
        pValue: 0.006,
        multiplicityAdjustedPValue: 0.012,
        confidenceLevel: 0.95,
        denominator: 90,
        missingCount: 7,
        excludedCount: 3,
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.mean_difference_v1',
        missingDataMethodId: 'missing.composite_state_v1',
        resultArtifactSha256:
            'fcae786548ef52a17d2eaa70ba2d509799ba8cd4c9cacfa2cb09aca472897e7f',
        recordedAtUtc: resultTime,
        interpretation: 'synthetic_engineering_signal_only',
      ),
      StatisticalAnalysisResult(
        endpointId: 'endpoint.synthetic_key_secondary',
        estimandId: estimandId,
        status: StatisticalResultStatus.nullResult,
        estimate: 0.05,
        lowerConfidenceLimit: -0.20,
        upperConfidenceLimit: 0.30,
        pValue: 0.69,
        multiplicityAdjustedPValue: 0.69,
        confidenceLevel: 0.95,
        denominator: 90,
        missingCount: 7,
        excludedCount: 3,
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.mean_difference_v1',
        missingDataMethodId: 'missing.composite_state_v1',
        resultArtifactSha256:
            '6b1768812326225456351698acb46fc41d265ac9fd81260f317c11d285d7420b',
        recordedAtUtc: resultTime,
        interpretation: 'null_not_equivalence_or_absence',
      ),
      StatisticalAnalysisResult(
        endpointId: 'endpoint.synthetic_precision',
        estimandId: estimandId,
        status: StatisticalResultStatus.inconclusive,
        estimate: 0.10,
        lowerConfidenceLimit: -0.50,
        upperConfidenceLimit: 0.70,
        pValue: 0.74,
        multiplicityAdjustedPValue: null,
        confidenceLevel: 0.95,
        denominator: 90,
        missingCount: 7,
        excludedCount: 3,
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.mean_difference_v1',
        missingDataMethodId: 'missing.composite_state_v1',
        resultArtifactSha256:
            '09ae507414436a92649725d6e17fd0af7f55478be2a14ef0415ab4c6468700c8',
        recordedAtUtc: resultTime,
        interpretation: 'inconclusive_wide_interval',
      ),
      StatisticalAnalysisResult(
        endpointId: 'endpoint.synthetic_adverse_fixture',
        estimandId: estimandId,
        status: StatisticalResultStatus.adverse,
        estimate: 0.08,
        lowerConfidenceLimit: 0.02,
        upperConfidenceLimit: 0.14,
        pValue: null,
        multiplicityAdjustedPValue: null,
        confidenceLevel: 0.95,
        denominator: 100,
        missingCount: 0,
        excludedCount: 0,
        analysisSetId: 'analysis_set.safety_synthetic',
        estimatorId: 'estimator.risk_difference_v1',
        missingDataMethodId: 'missing.no_imputation_v1',
        resultArtifactSha256:
            'b15c6f9295124970892073225477fe8019dc8b42fcb2f4d0606f53bca89ece69',
        recordedAtUtc: resultTime,
        interpretation: 'adverse_fixture_retained_descriptively',
      ),
      StatisticalAnalysisResult(
        endpointId: 'endpoint.synthetic_failed_fixture',
        estimandId: estimandId,
        status: StatisticalResultStatus.failed,
        estimate: null,
        lowerConfidenceLimit: null,
        upperConfidenceLimit: null,
        pValue: null,
        multiplicityAdjustedPValue: null,
        confidenceLevel: 0.95,
        denominator: 0,
        missingCount: 100,
        excludedCount: 0,
        analysisSetId: 'analysis_set.full_synthetic',
        estimatorId: 'estimator.not_executed',
        missingDataMethodId: 'missing.failure_state_v1',
        resultArtifactSha256:
            '5a11b18741740012121697810327781722669180e887d7682eab8321c8edb966',
        recordedAtUtc: resultTime,
        interpretation: 'execution_failed_no_numeric_substitution',
      ),
    ];
    const sensitivityResults = [
      StatisticalSensitivityResult(
        sensitivityId: 'sensitivity.synthetic_missing_tipping_point',
        endpointId: 'endpoint.synthetic_primary_trace',
        estimandId: estimandId,
        variedAssumption: 'missing fixture state departure',
        methodId: 'sensitivity.tipping_point_v1',
        prospectivelyPlanned: true,
        status: StatisticalResultStatus.reported,
        estimate: 0.31,
        lowerConfidenceLimit: 0.04,
        upperConfidenceLimit: 0.58,
        resultArtifactSha256:
            '31b80434128dd7cb4ae6dd2b11703362bd886e52608e502b114dad7f8943eea1',
      ),
      StatisticalSensitivityResult(
        sensitivityId: 'sensitivity.synthetic_complete_case',
        endpointId: 'endpoint.synthetic_primary_trace',
        estimandId: estimandId,
        variedAssumption: 'complete fixture subset only',
        methodId: 'sensitivity.complete_case_v1',
        prospectivelyPlanned: true,
        status: StatisticalResultStatus.reported,
        estimate: 0.38,
        lowerConfidenceLimit: 0.11,
        upperConfidenceLimit: 0.65,
        resultArtifactSha256:
            'fc725809569a2b11c70aa0368b7910e286785561e671b3b0df9a88efc7423374',
      ),
    ];
    final deviation = StatisticalDeviationEvent(
      sequence: 1,
      eventId: 'statistical-contract-lock-v1',
      predecessorSha256: StatisticalDeviationEvent.genesisPredecessor,
      actorId: 'synthetic-statistical-author',
      reviewerId: 'synthetic-independent-statistical-reviewer',
      authorityId: 'synthetic-statistical-governance-authority',
      occurredAtUtc: '2026-08-18T02:00:00.000Z',
      resultsVisible: false,
      affectedContractFields: const [],
      reason: 'Synthetic statistical contract locked before result access.',
      accepted: true,
    );
    return CredibilityStatisticalAnalysisPackage(
      packageId: 'synthetic-statistical-analysis-v1',
      prospectivePlanSha256: prospectivePlanSha256,
      protocolLedgerSha256: protocolLedgerSha256,
      replicationPackageSha256: replicationPackageSha256,
      analysisPlanSha256:
          '805d9c9e94ae708b53da466ed20fda571c93f1583d78f2cfcc9e961f248f4178',
      datasetSha256:
          '5bd3b447326f4370a2c9fe7c76b37dc39d2197ea201ac0d6712769c966e58866',
      codeSha256:
          '1419c8bad5986f123b09041bc2bccd82ba2b78adba3cf7f8d09a4950e5524792',
      environmentSha256:
          '4d5ca493d2ef7dcfc9ab5ccae3f4714fb9892175442256bb15a7ec4ce647f4d6',
      configurationSha256: configurationSha256,
      algorithmSourceBundleSha256: algorithmSourceBundleSha256,
      authoredBy: 'synthetic-statistical-author',
      reviewedBy: 'synthetic-independent-statistical-reviewer',
      authoredAtUtc: '2026-08-18T01:50:00.000Z',
      estimands: estimands,
      endpoints: endpoints,
      errorControl: const StatisticalErrorControlPlan(
        overallAlpha: 0.05,
        confidenceLevel: 0.95,
        multiplicityMethod: StatisticalMultiplicityMethod.holm,
        confirmatoryFamilyId: familyId,
        interimLookCount: 2,
        alphaSpendingPlanSha256:
            '2a93069de45b391a24f31c32c1cd5bca788d3b1236226001d6bbf38fabf5fd68',
        targetSampleSize: 100,
        minimumInformativeSampleSize: 80,
        targetPower: 0.80,
        assumedEffect: 0.30,
        assumedStandardDeviation: 1.0,
        expectedAttritionFraction: 0.15,
        sampleSizeMethod: 'synthetic_precision_and_power_assumption_v1',
        authoredAtUtc: '2026-08-18T01:50:00.000Z',
        frozenAtUtc: '2026-08-18T02:00:00.000Z',
        firstResultAccessAtUtc: '2026-08-18T02:30:00.000Z',
        lockedBeforeResultAccess: true,
      ),
      results: results,
      sensitivityResults: sensitivityResults,
      deviationEvents: [deviation],
      revoked: false,
      syntheticDemoOnly: true,
      boundary:
          'This is a deterministic synthetic statistical-governance fixture. '
          'It does not create real inference, establish clinical importance, '
          'model validity, causal effect, regulatory acceptance, benefit, '
          'patient safety, or medical advice.',
    );
  }

  CredibilityStatisticalAnalysisPackage copyWith({
    int? schemaVersion,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    List<StatisticalEstimand>? estimands,
    List<StatisticalEndpointSpecification>? endpoints,
    StatisticalErrorControlPlan? errorControl,
    List<StatisticalAnalysisResult>? results,
    List<StatisticalSensitivityResult>? sensitivityResults,
    List<StatisticalDeviationEvent>? deviationEvents,
    bool? revoked,
  }) => CredibilityStatisticalAnalysisPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    prospectivePlanSha256: prospectivePlanSha256,
    protocolLedgerSha256: protocolLedgerSha256,
    replicationPackageSha256: replicationPackageSha256,
    analysisPlanSha256: analysisPlanSha256,
    datasetSha256: datasetSha256,
    codeSha256: codeSha256,
    environmentSha256: environmentSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    authoredBy: authoredBy,
    reviewedBy: reviewedBy,
    authoredAtUtc: authoredAtUtc,
    estimands: estimands ?? this.estimands,
    endpoints: endpoints ?? this.endpoints,
    errorControl: errorControl ?? this.errorControl,
    results: results ?? this.results,
    sensitivityResults: sensitivityResults ?? this.sensitivityResults,
    deviationEvents: deviationEvents ?? this.deviationEvents,
    revoked: revoked ?? this.revoked,
    syntheticDemoOnly: syntheticDemoOnly,
    boundary: boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'package_id': packageId,
    'prospective_plan_sha256': prospectivePlanSha256,
    'protocol_ledger_sha256': protocolLedgerSha256,
    'replication_package_sha256': replicationPackageSha256,
    'analysis_plan_sha256': analysisPlanSha256,
    'dataset_sha256': datasetSha256,
    'code_sha256': codeSha256,
    'environment_sha256': environmentSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'authored_by': authoredBy,
    'reviewed_by': reviewedBy,
    'authored_at_utc': authoredAtUtc,
    'estimands': estimands.map((item) => item.toJson()).toList(),
    'endpoints': endpoints.map((item) => item.toJson()).toList(),
    'error_control': errorControl.toJson(),
    'results': results.map((item) => item.toJson()).toList(),
    'sensitivity_results': sensitivityResults
        .map((item) => item.toJson())
        .toList(),
    'deviation_events': deviationEvents.map((item) => item.toJson()).toList(),
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

final class StatisticalFinding {
  final StatisticalFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  StatisticalFinding({
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

final class StatisticalGovernanceAssessment {
  final CredibilityStatisticalAnalysisPackage package;
  final StatisticalGovernanceStatus status;
  final List<StatisticalFinding> findings;

  StatisticalGovernanceAssessment._({
    required this.package,
    required this.status,
    required List<StatisticalFinding> findings,
  }) : findings = List.unmodifiable(findings);

  bool get integrityVerified => findings.isEmpty;
  bool get canSupportClinicalInference => false;

  Map<StatisticalResultStatus, int> get outcomeStatusCounts => {
    for (final status in StatisticalResultStatus.values)
      status: package.results.where((item) => item.status == status).length,
  };

  Map<String, String> get lanes => {
    'design':
        findings.any(
          (item) =>
              item.kind == StatisticalFindingKind.contractIncomplete ||
              item.kind == StatisticalFindingKind.contractNotProspective,
        )
        ? 'blocked'
        : 'prospectivelyLocked',
    'estimand':
        findings.any(
          (item) => item.kind == StatisticalFindingKind.estimandMismatch,
        )
        ? 'mismatched'
        : 'explicit',
    'estimate':
        findings.any(
          (item) =>
              item.kind == StatisticalFindingKind.resultOmitted ||
              item.kind == StatisticalFindingKind.endpointContractMismatch,
        )
        ? 'blocked'
        : 'completeWithNullFailureAdverse',
    'uncertainty':
        findings.any(
          (item) =>
              item.kind == StatisticalFindingKind.intervalInvalid ||
              item.kind == StatisticalFindingKind.pValueIntervalMismatch,
        )
        ? 'inconsistent'
        : 'intervalReported',
    'errorControl':
        findings.any(
          (item) =>
              item.kind == StatisticalFindingKind.alphaInflation ||
              item.kind == StatisticalFindingKind.multiplicityMissing ||
              item.kind == StatisticalFindingKind.interimPlanMismatch,
        )
        ? 'blocked'
        : package.errorControl.multiplicityMethod.name,
    'sensitivity':
        findings.any(
          (item) =>
              item.kind == StatisticalFindingKind.sensitivityMissing ||
              item.kind == StatisticalFindingKind.sensitivityEstimandChanged ||
              item.kind == StatisticalFindingKind.unplannedSensitivity,
        )
        ? 'blocked'
        : 'sameEstimandPlanned',
    'deviations': package.deviationEvents.any((item) => !item.accepted)
        ? 'held'
        : findings.any(
            (item) =>
                item.kind == StatisticalFindingKind.deviationChainBroken ||
                item.kind == StatisticalFindingKind.postResultChange,
          )
        ? 'blocked'
        : 'appendOnlyClean',
  };

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'lanes': lanes,
    'outcome_status_counts': {
      for (final entry in outcomeStatusCounts.entries)
        entry.key.name: entry.value,
    },
    'findings': findings.map((item) => item.toJson()).toList(),
    'can_support_clinical_inference': canSupportClinicalInference,
    'boundary': package.boundary,
  };
}

final class CredibilityStatisticalAnalysisVerifier {
  const CredibilityStatisticalAnalysisVerifier();

  StatisticalGovernanceAssessment verify(
    CredibilityStatisticalAnalysisPackage package,
  ) {
    final findings = <StatisticalFinding>[];
    _checkIdentity(package, findings);
    _checkEstimandsAndEndpoints(package, findings);
    _checkErrorControl(package, findings);
    _checkResults(package, findings);
    _checkSensitivity(package, findings);
    _checkDeviations(package, findings);
    if (package.revoked) {
      _add(
        findings,
        StatisticalFindingKind.revocation,
        'Statistical package was explicitly revoked.',
        [package.packageId],
      );
    }
    final unknownOnly =
        findings.isNotEmpty &&
        findings.every(
          (item) =>
              item.kind == StatisticalFindingKind.schemaUnsupported ||
              item.kind == StatisticalFindingKind.identityMismatch ||
              item.kind == StatisticalFindingKind.malformedDigest,
        );
    final held = package.deviationEvents.any((item) => !item.accepted);
    final status = package.revoked
        ? StatisticalGovernanceStatus.revoked
        : findings.isNotEmpty
        ? unknownOnly
              ? StatisticalGovernanceStatus.unknown
              : StatisticalGovernanceStatus.violated
        : held
        ? StatisticalGovernanceStatus.held
        : StatisticalGovernanceStatus.mechanicallyObserved;
    return StatisticalGovernanceAssessment._(
      package: package,
      status: status,
      findings: findings,
    );
  }

  void _checkIdentity(
    CredibilityStatisticalAnalysisPackage package,
    List<StatisticalFinding> findings,
  ) {
    if (package.schemaVersion !=
        CredibilityStatisticalAnalysisPackage.currentSchemaVersion) {
      _add(
        findings,
        StatisticalFindingKind.schemaUnsupported,
        'Unsupported statistical package schema.',
        ['${package.schemaVersion}'],
      );
    }
    if (package.configurationSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedConfigurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedAlgorithmSourceBundleSha256) {
      _add(
        findings,
        StatisticalFindingKind.identityMismatch,
        'Statistical package is not bound to the governed runtime identity.',
        const ['configuration', 'algorithm_source_bundle'],
      );
    }
    for (final entry in <String, String>{
      'prospective_plan': package.prospectivePlanSha256,
      'protocol_ledger': package.protocolLedgerSha256,
      'replication_package': package.replicationPackageSha256,
      'analysis_plan': package.analysisPlanSha256,
      'dataset': package.datasetSha256,
      'code': package.codeSha256,
      'environment': package.environmentSha256,
      'configuration': package.configurationSha256,
      'source_bundle': package.algorithmSourceBundleSha256,
    }.entries) {
      if (!_isSha256(entry.value)) {
        _add(
          findings,
          StatisticalFindingKind.malformedDigest,
          'Malformed ${entry.key} identity.',
          [entry.key],
        );
      }
    }
    if (package.packageId.trim().isEmpty ||
        package.authoredBy.trim().isEmpty ||
        package.reviewedBy.trim().isEmpty ||
        package.authoredBy == package.reviewedBy ||
        !_isUtcTimestamp(package.authoredAtUtc)) {
      _add(
        findings,
        StatisticalFindingKind.contractIncomplete,
        'Package identity, author, independent reviewer, or time is incomplete.',
        [package.packageId],
      );
    }
  }

  void _checkEstimandsAndEndpoints(
    CredibilityStatisticalAnalysisPackage package,
    List<StatisticalFinding> findings,
  ) {
    final estimandIds = <String>{};
    for (final estimand in package.estimands) {
      final required = [
        estimand.estimandId,
        estimand.scientificQuestion,
        estimand.treatmentCondition,
        estimand.population,
        estimand.variable,
        estimand.timeHorizon,
        estimand.populationSummary,
        estimand.effectMeasure,
      ];
      if (!estimandIds.add(estimand.estimandId) ||
          required.any((item) => item.trim().isEmpty) ||
          estimand.intercurrentEvents.isEmpty ||
          estimand.intercurrentEvents.any(
            (item) =>
                item.eventId.trim().isEmpty ||
                item.definition.trim().isEmpty ||
                item.rationale.trim().isEmpty,
          )) {
        _add(
          findings,
          StatisticalFindingKind.estimandMismatch,
          'Estimand is duplicate, incomplete, or lacks intercurrent-event handling.',
          [estimand.estimandId],
        );
      }
    }
    if (package.estimands.isEmpty) {
      _add(
        findings,
        StatisticalFindingKind.estimandMismatch,
        'No estimand is defined.',
        const [],
      );
    }
    final endpointIds = <String>{};
    final hierarchy = <int>{};
    var primaryCount = 0;
    for (final endpoint in package.endpoints) {
      if (endpoint.role == StatisticalEndpointRole.primary) primaryCount += 1;
      final required = [
        endpoint.endpointId,
        endpoint.estimandId,
        endpoint.familyId,
        endpoint.analysisSetId,
        endpoint.estimatorId,
        endpoint.missingDataMethodId,
        endpoint.hypothesisId,
        endpoint.decisionRule,
      ];
      if (!endpointIds.add(endpoint.endpointId) ||
          !hierarchy.add(endpoint.hierarchyOrder) ||
          required.any((item) => item.trim().isEmpty) ||
          !estimandIds.contains(endpoint.estimandId) ||
          endpoint.hierarchyOrder < 1 ||
          (endpoint.sidedness != 1 && endpoint.sidedness != 2) ||
          !_finite(endpoint.allocatedAlpha) ||
          endpoint.allocatedAlpha < 0 ||
          endpoint.allocatedAlpha > 0.05 ||
          (endpoint.confirmatory && endpoint.allocatedAlpha <= 0) ||
          (!endpoint.confirmatory && endpoint.allocatedAlpha != 0)) {
        _add(
          findings,
          StatisticalFindingKind.endpointContractMismatch,
          'Endpoint hierarchy or prospective analysis contract is invalid.',
          [endpoint.endpointId],
        );
      }
    }
    if (primaryCount != 1 || package.endpoints.isEmpty) {
      _add(
        findings,
        StatisticalFindingKind.endpointContractMismatch,
        'Exactly one primary endpoint is required.',
        const ['primary'],
      );
    }
  }

  void _checkErrorControl(
    CredibilityStatisticalAnalysisPackage package,
    List<StatisticalFinding> findings,
  ) {
    final plan = package.errorControl;
    final authored = _parseUtc(plan.authoredAtUtc);
    final frozen = _parseUtc(plan.frozenAtUtc);
    final resultAccess = _parseUtc(plan.firstResultAccessAtUtc);
    if (authored == null ||
        frozen == null ||
        resultAccess == null ||
        frozen.isBefore(authored) ||
        !resultAccess.isAfter(frozen) ||
        !plan.lockedBeforeResultAccess) {
      _add(
        findings,
        StatisticalFindingKind.contractNotProspective,
        'Statistical contract was not demonstrably frozen before result access.',
        [package.packageId],
      );
    }
    if (!_finite(plan.overallAlpha) ||
        plan.overallAlpha <= 0 ||
        plan.overallAlpha > 0.05 ||
        !_finite(plan.confidenceLevel) ||
        (plan.confidenceLevel - (1 - plan.overallAlpha)).abs() > 0.000001) {
      _add(
        findings,
        StatisticalFindingKind.alphaInflation,
        'Overall alpha or confidence level is invalid or inconsistent.',
        [package.packageId],
      );
    }
    final confirmatory = package.endpoints
        .where((item) => item.confirmatory)
        .toList();
    if (confirmatory.length > 1 &&
        plan.multiplicityMethod ==
            StatisticalMultiplicityMethod.noneSinglePrimary) {
      _add(
        findings,
        StatisticalFindingKind.multiplicityMissing,
        'Multiple confirmatory endpoints have no multiplicity procedure.',
        confirmatory.map((item) => item.endpointId).toList(),
      );
    }
    final allocated = confirmatory.fold<double>(
      0,
      (sum, item) => sum + item.allocatedAlpha,
    );
    if (allocated > plan.overallAlpha + 0.0000001 ||
        confirmatory.any(
          (item) => item.familyId != plan.confirmatoryFamilyId,
        )) {
      _add(
        findings,
        StatisticalFindingKind.alphaInflation,
        'Confirmatory alpha allocation exceeds the family budget.',
        confirmatory.map((item) => item.endpointId).toList(),
      );
    }
    if (plan.interimLookCount < 0 || !_isSha256(plan.alphaSpendingPlanSha256)) {
      _add(
        findings,
        StatisticalFindingKind.interimPlanMismatch,
        'Interim-look count or alpha-spending identity is invalid.',
        [package.packageId],
      );
    }
    if (plan.targetSampleSize <= 0 ||
        plan.minimumInformativeSampleSize <= 0 ||
        plan.minimumInformativeSampleSize > plan.targetSampleSize ||
        !_finite(plan.targetPower) ||
        plan.targetPower < 0.8 ||
        plan.targetPower >= 1 ||
        !_finite(plan.assumedEffect) ||
        !_finite(plan.assumedStandardDeviation) ||
        plan.assumedStandardDeviation <= 0 ||
        !_finite(plan.expectedAttritionFraction) ||
        plan.expectedAttritionFraction < 0 ||
        plan.expectedAttritionFraction >= 0.5 ||
        plan.sampleSizeMethod.trim().isEmpty) {
      _add(
        findings,
        StatisticalFindingKind.sampleSizeDrift,
        'Sample-size, precision, power, variance, or attrition basis is invalid.',
        [package.packageId],
      );
    }
  }

  void _checkResults(
    CredibilityStatisticalAnalysisPackage package,
    List<StatisticalFinding> findings,
  ) {
    final endpointById = {
      for (final endpoint in package.endpoints) endpoint.endpointId: endpoint,
    };
    final resultIds = <String>{};
    for (final result in package.results) {
      final endpoint = endpointById[result.endpointId];
      if (!resultIds.add(result.endpointId) || endpoint == null) {
        _add(
          findings,
          StatisticalFindingKind.resultOmitted,
          'Result is duplicate or does not bind a planned endpoint.',
          [result.endpointId],
        );
        continue;
      }
      if (result.estimandId != endpoint.estimandId) {
        _add(
          findings,
          StatisticalFindingKind.estimandMismatch,
          'Result changed the planned estimand.',
          [result.endpointId],
        );
      }
      if (result.analysisSetId != endpoint.analysisSetId ||
          result.estimatorId != endpoint.estimatorId) {
        _add(
          findings,
          StatisticalFindingKind.analysisSetChanged,
          'Result changed the planned analysis set or estimator.',
          [result.endpointId],
        );
      }
      if (result.missingDataMethodId != endpoint.missingDataMethodId) {
        _add(
          findings,
          StatisticalFindingKind.missingDataMethodChanged,
          'Result changed the planned missing-data method.',
          [result.endpointId],
        );
      }
      if (!_isSha256(result.resultArtifactSha256) ||
          !_isUtcTimestamp(result.recordedAtUtc) ||
          result.interpretation.trim().isEmpty) {
        _add(
          findings,
          StatisticalFindingKind.contractIncomplete,
          'Result artifact, time, or interpretation is incomplete.',
          [result.endpointId],
        );
      }
      if (result.status == StatisticalResultStatus.missing) {
        _add(
          findings,
          StatisticalFindingKind.resultOmitted,
          'A planned endpoint is marked missing.',
          [result.endpointId],
        );
      }
      final numericRequired = result.status != StatisticalResultStatus.failed;
      if (numericRequired) {
        final estimate = result.estimate;
        final lower = result.lowerConfidenceLimit;
        final upper = result.upperConfidenceLimit;
        if (!_finite(estimate) ||
            !_finite(lower) ||
            !_finite(upper) ||
            lower! >= upper! ||
            estimate! < lower ||
            estimate > upper ||
            upper - lower < 0.0001 ||
            (result.confidenceLevel - package.errorControl.confidenceLevel)
                    .abs() >
                0.000001) {
          _add(
            findings,
            StatisticalFindingKind.intervalInvalid,
            'Estimate or uncertainty interval is absent, invalid, or implausibly narrow.',
            [result.endpointId],
          );
        }
      } else if (result.estimate != null ||
          result.lowerConfidenceLimit != null ||
          result.upperConfidenceLimit != null ||
          result.pValue != null ||
          result.multiplicityAdjustedPValue != null) {
        _add(
          findings,
          StatisticalFindingKind.intervalInvalid,
          'Failed execution cannot carry substituted numerical inference.',
          [result.endpointId],
        );
      }
      final pValue = result.pValue;
      if (pValue != null) {
        if (!_finite(pValue) || pValue < 0 || pValue > 1) {
          _add(
            findings,
            StatisticalFindingKind.pValueIntervalMismatch,
            'P-value is outside [0, 1].',
            [result.endpointId],
          );
        } else if (result.lowerConfidenceLimit != null &&
            result.upperConfidenceLimit != null) {
          final containsNull =
              result.lowerConfidenceLimit! <= endpoint.nullValue &&
              result.upperConfidenceLimit! >= endpoint.nullValue;
          final threshold = endpoint.confirmatory
              ? endpoint.allocatedAlpha
              : package.errorControl.overallAlpha;
          if ((containsNull && pValue < threshold) ||
              (!containsNull && pValue >= threshold)) {
            _add(
              findings,
              StatisticalFindingKind.pValueIntervalMismatch,
              'P-value and confidence interval imply inconsistent decisions.',
              [result.endpointId],
            );
          }
        }
      }
      if (endpoint.confirmatory) {
        final adjusted = result.multiplicityAdjustedPValue;
        if (pValue == null ||
            adjusted == null ||
            !_finite(adjusted) ||
            adjusted < pValue ||
            adjusted > 1) {
          _add(
            findings,
            StatisticalFindingKind.multiplicityResultMismatch,
            'Confirmatory result lacks a valid multiplicity-adjusted p-value.',
            [result.endpointId],
          );
        }
      }
      if (result.denominator < 0 ||
          result.missingCount < 0 ||
          result.excludedCount < 0 ||
          result.denominator + result.missingCount + result.excludedCount !=
              package.errorControl.targetSampleSize ||
          (result.status != StatisticalResultStatus.failed &&
              result.denominator <
                  package.errorControl.minimumInformativeSampleSize)) {
        _add(
          findings,
          StatisticalFindingKind.denominatorMismatch,
          'Analysis denominator, missing, and excluded counts do not reconcile.',
          [result.endpointId],
        );
      }
    }
    final missingEndpoints = endpointById.keys.toSet().difference(resultIds);
    if (missingEndpoints.isNotEmpty) {
      _add(
        findings,
        StatisticalFindingKind.resultOmitted,
        'One or more planned endpoints have no retained result.',
        missingEndpoints.toList(),
      );
    }
  }

  void _checkSensitivity(
    CredibilityStatisticalAnalysisPackage package,
    List<StatisticalFinding> findings,
  ) {
    final endpointById = {
      for (final endpoint in package.endpoints) endpoint.endpointId: endpoint,
    };
    final ids = <String>{};
    for (final result in package.sensitivityResults) {
      final endpoint = endpointById[result.endpointId];
      if (!ids.add(result.sensitivityId) ||
          endpoint == null ||
          result.variedAssumption.trim().isEmpty ||
          result.methodId.trim().isEmpty ||
          !_isSha256(result.resultArtifactSha256) ||
          !_finite(result.estimate) ||
          !_finite(result.lowerConfidenceLimit) ||
          !_finite(result.upperConfidenceLimit) ||
          result.lowerConfidenceLimit >= result.upperConfidenceLimit ||
          result.estimate < result.lowerConfidenceLimit ||
          result.estimate > result.upperConfidenceLimit) {
        _add(
          findings,
          StatisticalFindingKind.sensitivityMissing,
          'Sensitivity result is duplicate, incomplete, or invalid.',
          [result.sensitivityId],
        );
        continue;
      }
      if (result.estimandId != endpoint.estimandId) {
        _add(
          findings,
          StatisticalFindingKind.sensitivityEstimandChanged,
          'Sensitivity analysis changed the target estimand.',
          [result.sensitivityId],
        );
      }
      if (!result.prospectivelyPlanned) {
        _add(
          findings,
          StatisticalFindingKind.unplannedSensitivity,
          'Sensitivity analysis was added after the prospective lock.',
          [result.sensitivityId],
        );
      }
    }
    final primaryIds = package.endpoints
        .where((item) => item.role == StatisticalEndpointRole.primary)
        .map((item) => item.endpointId);
    for (final endpointId in primaryIds) {
      if (package.sensitivityResults
              .where((item) => item.endpointId == endpointId)
              .length <
          2) {
        _add(
          findings,
          StatisticalFindingKind.sensitivityMissing,
          'Primary endpoint lacks two planned sensitivity analyses.',
          [endpointId],
        );
      }
    }
  }

  void _checkDeviations(
    CredibilityStatisticalAnalysisPackage package,
    List<StatisticalFinding> findings,
  ) {
    var predecessor = StatisticalDeviationEvent.genesisPredecessor;
    DateTime? prior;
    final ids = <String>{};
    const protectedFields = {
      'estimand',
      'endpoint',
      'hierarchy',
      'analysis_set',
      'estimator',
      'missing_data',
      'alpha',
      'multiplicity',
      'confidence_level',
      'sample_size',
      'subgroup',
      'sensitivity',
    };
    for (var index = 0; index < package.deviationEvents.length; index += 1) {
      final event = package.deviationEvents[index];
      final occurred = _parseUtc(event.occurredAtUtc);
      if (event.sequence != index + 1 ||
          !ids.add(event.eventId) ||
          event.predecessorSha256 != predecessor ||
          occurred == null ||
          (prior != null && occurred.isBefore(prior)) ||
          event.actorId.trim().isEmpty ||
          event.reviewerId.trim().isEmpty ||
          event.authorityId.trim().isEmpty ||
          event.reason.trim().isEmpty) {
        _add(
          findings,
          StatisticalFindingKind.deviationChainBroken,
          'Statistical deviation chain is broken, replayed, or incomplete.',
          [event.eventId],
        );
      }
      predecessor = event.eventSha256;
      prior = occurred ?? prior;
      if (event.resultsVisible &&
          event.accepted &&
          event.affectedContractFields.any(protectedFields.contains)) {
        _add(
          findings,
          StatisticalFindingKind.postResultChange,
          'A protected statistical choice changed after result visibility.',
          [event.eventId, ...event.affectedContractFields],
        );
      }
    }
    if (package.deviationEvents.isEmpty) {
      _add(
        findings,
        StatisticalFindingKind.deviationChainBroken,
        'No statistical lock or deviation history exists.',
        const [],
      );
    }
  }

  void _add(
    List<StatisticalFinding> findings,
    StatisticalFindingKind kind,
    String detail,
    List<String> affectedIds,
  ) {
    findings.add(
      StatisticalFinding(kind: kind, detail: detail, affectedIds: affectedIds),
    );
  }
}

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

bool _isSha256(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _finite(double? value) => value != null && value.isFinite;

bool _isUtcTimestamp(String? value) => _parseUtc(value) != null;

DateTime? _parseUtc(String? value) {
  if (value == null || !value.endsWith('Z')) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.isUtc == true ? parsed : null;
}
