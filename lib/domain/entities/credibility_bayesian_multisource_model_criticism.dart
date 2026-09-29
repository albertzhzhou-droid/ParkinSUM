import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'credibility_bayesian_borrowing_calibration.dart';

enum MultisourceEvidenceDisposition {
  included,
  excluded,
  duplicate,
  dependent,
  unavailable,
  contradictory,
}

enum MultisourceExchangeability {
  full,
  partial,
  biasParameter,
  functionallyDependent,
  nonexchangeable,
  unknown,
}

enum MultisourceDataLevel { patient, aggregate, unavailable }

enum MultisourceCriticismKind {
  priorPredictive,
  simulationBasedCalibration,
  posteriorPredictive,
  alternativePrior,
  effectiveSampleSize,
  leaveOneSourceOut,
  sourceOrderInvariance,
  negativeControl,
  deliberateIncompatibility,
}

enum MultisourceScenarioFamily {
  aligned,
  partialExchangeability,
  temporalDrift,
  hiddenBias,
  dependencyViolation,
  positivityFailure,
}

enum MultisourceGovernanceStatus {
  mechanicallyObserved,
  held,
  violated,
  unknown,
  revoked,
}

enum MultisourceFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  searchLedgerIncomplete,
  postResultSelection,
  sourceDuplicateIncluded,
  sourceDependencyUnresolved,
  sourceMismatchIncluded,
  transportabilityUnresolved,
  exchangeabilityOverclaimed,
  biasAdjustmentMissing,
  borrowingArithmeticMismatch,
  borrowingUnbounded,
  criticismIncomplete,
  priorPredictiveFailure,
  simulationCalibrationFailure,
  posteriorPredictiveFailure,
  sensitivityIncomplete,
  sourceOrderDrift,
  negativeControlFailure,
  deliberateIncompatibilityMissed,
  scenarioIncomplete,
  operatingResultMismatch,
  monteCarloUnderpowered,
  falsePositiveInflated,
  powerInsufficient,
  biasExcessive,
  coverageInsufficient,
  independentImplementationMissing,
  independentImplementationMismatch,
  resultOmission,
  historyBroken,
  revocation,
}

final class MultisourceExternalEvidenceRecord {
  final String sourceId;
  final String cohortId;
  final String dependencyGroupId;
  final MultisourceEvidenceDisposition disposition;
  final MultisourceExchangeability exchangeability;
  final String populationId;
  final String settingId;
  final String timeWindowId;
  final String treatmentId;
  final String comparatorId;
  final String outcomeId;
  final String estimandId;
  final List<String> covariates;
  final List<String> missingCovariates;
  final List<String> effectModifiers;
  final MultisourceDataLevel dataLevel;
  final int successes;
  final int total;
  final double qualityScore;
  final double relevanceScore;
  final double completenessScore;
  final double overlapScore;
  final double temporalDriftScore;
  final double biasRiskScore;
  final bool patientLevelAvailable;
  final bool included;
  final String sourceRef;
  final String reviewerRationale;
  final String discoveredAtUtc;
  final String assessedAtUtc;

  MultisourceExternalEvidenceRecord({
    required this.sourceId,
    required this.cohortId,
    required this.dependencyGroupId,
    required this.disposition,
    required this.exchangeability,
    required this.populationId,
    required this.settingId,
    required this.timeWindowId,
    required this.treatmentId,
    required this.comparatorId,
    required this.outcomeId,
    required this.estimandId,
    required List<String> covariates,
    required List<String> missingCovariates,
    required List<String> effectModifiers,
    required this.dataLevel,
    required this.successes,
    required this.total,
    required this.qualityScore,
    required this.relevanceScore,
    required this.completenessScore,
    required this.overlapScore,
    required this.temporalDriftScore,
    required this.biasRiskScore,
    required this.patientLevelAvailable,
    required this.included,
    required this.sourceRef,
    required this.reviewerRationale,
    required this.discoveredAtUtc,
    required this.assessedAtUtc,
  }) : covariates = List.unmodifiable(covariates),
       missingCovariates = List.unmodifiable(missingCovariates),
       effectModifiers = List.unmodifiable(effectModifiers);

  MultisourceExternalEvidenceRecord copyWith({
    String? sourceId,
    String? cohortId,
    String? dependencyGroupId,
    MultisourceEvidenceDisposition? disposition,
    MultisourceExchangeability? exchangeability,
    String? populationId,
    String? settingId,
    String? timeWindowId,
    String? treatmentId,
    String? comparatorId,
    String? outcomeId,
    String? estimandId,
    List<String>? covariates,
    List<String>? missingCovariates,
    List<String>? effectModifiers,
    MultisourceDataLevel? dataLevel,
    int? successes,
    int? total,
    double? qualityScore,
    double? relevanceScore,
    double? completenessScore,
    double? overlapScore,
    double? temporalDriftScore,
    double? biasRiskScore,
    bool? patientLevelAvailable,
    bool? included,
    String? sourceRef,
    String? reviewerRationale,
    String? discoveredAtUtc,
    String? assessedAtUtc,
  }) => MultisourceExternalEvidenceRecord(
    sourceId: sourceId ?? this.sourceId,
    cohortId: cohortId ?? this.cohortId,
    dependencyGroupId: dependencyGroupId ?? this.dependencyGroupId,
    disposition: disposition ?? this.disposition,
    exchangeability: exchangeability ?? this.exchangeability,
    populationId: populationId ?? this.populationId,
    settingId: settingId ?? this.settingId,
    timeWindowId: timeWindowId ?? this.timeWindowId,
    treatmentId: treatmentId ?? this.treatmentId,
    comparatorId: comparatorId ?? this.comparatorId,
    outcomeId: outcomeId ?? this.outcomeId,
    estimandId: estimandId ?? this.estimandId,
    covariates: covariates ?? this.covariates,
    missingCovariates: missingCovariates ?? this.missingCovariates,
    effectModifiers: effectModifiers ?? this.effectModifiers,
    dataLevel: dataLevel ?? this.dataLevel,
    successes: successes ?? this.successes,
    total: total ?? this.total,
    qualityScore: qualityScore ?? this.qualityScore,
    relevanceScore: relevanceScore ?? this.relevanceScore,
    completenessScore: completenessScore ?? this.completenessScore,
    overlapScore: overlapScore ?? this.overlapScore,
    temporalDriftScore: temporalDriftScore ?? this.temporalDriftScore,
    biasRiskScore: biasRiskScore ?? this.biasRiskScore,
    patientLevelAvailable: patientLevelAvailable ?? this.patientLevelAvailable,
    included: included ?? this.included,
    sourceRef: sourceRef ?? this.sourceRef,
    reviewerRationale: reviewerRationale ?? this.reviewerRationale,
    discoveredAtUtc: discoveredAtUtc ?? this.discoveredAtUtc,
    assessedAtUtc: assessedAtUtc ?? this.assessedAtUtc,
  );

  Map<String, Object?> get canonicalPayload => {
    'source_id': sourceId,
    'cohort_id': cohortId,
    'dependency_group_id': dependencyGroupId,
    'disposition': disposition.name,
    'exchangeability': exchangeability.name,
    'population_id': populationId,
    'setting_id': settingId,
    'time_window_id': timeWindowId,
    'treatment_id': treatmentId,
    'comparator_id': comparatorId,
    'outcome_id': outcomeId,
    'estimand_id': estimandId,
    'covariates': [...covariates]..sort(),
    'missing_covariates': [...missingCovariates]..sort(),
    'effect_modifiers': [...effectModifiers]..sort(),
    'data_level': dataLevel.name,
    'successes': successes,
    'total': total,
    'quality_score': qualityScore,
    'relevance_score': relevanceScore,
    'completeness_score': completenessScore,
    'overlap_score': overlapScore,
    'temporal_drift_score': temporalDriftScore,
    'bias_risk_score': biasRiskScore,
    'patient_level_available': patientLevelAvailable,
    'included': included,
    'source_ref': sourceRef,
    'reviewer_rationale': reviewerRationale,
    'discovered_at_utc': discoveredAtUtc,
    'assessed_at_utc': assessedAtUtc,
  };

  String get recordSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'record_sha256': recordSha256,
  };
}

final class MultisourceModelContract {
  final String contractId;
  final String searchStrategySha256;
  final List<String> requiredCovariates;
  final String outcomeId;
  final String estimandId;
  final String negativeControlOutcomeId;
  final double minimumQuality;
  final double minimumRelevance;
  final double minimumCompleteness;
  final double minimumOverlap;
  final double maximumTemporalDrift;
  final double maximumBiasRisk;
  final double conflictScale;
  final double maximumTotalBorrowedEss;
  final String dependencyDiscountRuleId;
  final String biasAdjustmentRuleId;
  final String computationMethodId;
  final String modelCodeSha256;
  final String independentScriptSha256;
  final String authoredAtUtc;
  final String searchFrozenAtUtc;
  final String firstCurrentResultVisibleAtUtc;
  final String boundary;

  MultisourceModelContract({
    required this.contractId,
    required this.searchStrategySha256,
    required List<String> requiredCovariates,
    required this.outcomeId,
    required this.estimandId,
    required this.negativeControlOutcomeId,
    required this.minimumQuality,
    required this.minimumRelevance,
    required this.minimumCompleteness,
    required this.minimumOverlap,
    required this.maximumTemporalDrift,
    required this.maximumBiasRisk,
    required this.conflictScale,
    required this.maximumTotalBorrowedEss,
    required this.dependencyDiscountRuleId,
    required this.biasAdjustmentRuleId,
    required this.computationMethodId,
    required this.modelCodeSha256,
    required this.independentScriptSha256,
    required this.authoredAtUtc,
    required this.searchFrozenAtUtc,
    required this.firstCurrentResultVisibleAtUtc,
    required this.boundary,
  }) : requiredCovariates = List.unmodifiable(requiredCovariates);

  MultisourceModelContract copyWith({
    String? searchStrategySha256,
    List<String>? requiredCovariates,
    double? minimumQuality,
    double? minimumRelevance,
    double? minimumCompleteness,
    double? minimumOverlap,
    double? maximumTemporalDrift,
    double? maximumBiasRisk,
    double? conflictScale,
    double? maximumTotalBorrowedEss,
    String? dependencyDiscountRuleId,
    String? biasAdjustmentRuleId,
    String? computationMethodId,
    String? modelCodeSha256,
    String? independentScriptSha256,
    String? authoredAtUtc,
    String? searchFrozenAtUtc,
    String? firstCurrentResultVisibleAtUtc,
    String? boundary,
  }) => MultisourceModelContract(
    contractId: contractId,
    searchStrategySha256: searchStrategySha256 ?? this.searchStrategySha256,
    requiredCovariates: requiredCovariates ?? this.requiredCovariates,
    outcomeId: outcomeId,
    estimandId: estimandId,
    negativeControlOutcomeId: negativeControlOutcomeId,
    minimumQuality: minimumQuality ?? this.minimumQuality,
    minimumRelevance: minimumRelevance ?? this.minimumRelevance,
    minimumCompleteness: minimumCompleteness ?? this.minimumCompleteness,
    minimumOverlap: minimumOverlap ?? this.minimumOverlap,
    maximumTemporalDrift: maximumTemporalDrift ?? this.maximumTemporalDrift,
    maximumBiasRisk: maximumBiasRisk ?? this.maximumBiasRisk,
    conflictScale: conflictScale ?? this.conflictScale,
    maximumTotalBorrowedEss:
        maximumTotalBorrowedEss ?? this.maximumTotalBorrowedEss,
    dependencyDiscountRuleId:
        dependencyDiscountRuleId ?? this.dependencyDiscountRuleId,
    biasAdjustmentRuleId: biasAdjustmentRuleId ?? this.biasAdjustmentRuleId,
    computationMethodId: computationMethodId ?? this.computationMethodId,
    modelCodeSha256: modelCodeSha256 ?? this.modelCodeSha256,
    independentScriptSha256:
        independentScriptSha256 ?? this.independentScriptSha256,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    searchFrozenAtUtc: searchFrozenAtUtc ?? this.searchFrozenAtUtc,
    firstCurrentResultVisibleAtUtc:
        firstCurrentResultVisibleAtUtc ?? this.firstCurrentResultVisibleAtUtc,
    boundary: boundary ?? this.boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'contract_id': contractId,
    'search_strategy_sha256': searchStrategySha256,
    'required_covariates': [...requiredCovariates]..sort(),
    'outcome_id': outcomeId,
    'estimand_id': estimandId,
    'negative_control_outcome_id': negativeControlOutcomeId,
    'minimum_quality': minimumQuality,
    'minimum_relevance': minimumRelevance,
    'minimum_completeness': minimumCompleteness,
    'minimum_overlap': minimumOverlap,
    'maximum_temporal_drift': maximumTemporalDrift,
    'maximum_bias_risk': maximumBiasRisk,
    'conflict_scale': conflictScale,
    'maximum_total_borrowed_ess': maximumTotalBorrowedEss,
    'dependency_discount_rule_id': dependencyDiscountRuleId,
    'bias_adjustment_rule_id': biasAdjustmentRuleId,
    'computation_method_id': computationMethodId,
    'model_code_sha256': modelCodeSha256,
    'independent_script_sha256': independentScriptSha256,
    'authored_at_utc': authoredAtUtc,
    'search_frozen_at_utc': searchFrozenAtUtc,
    'first_current_result_visible_at_utc': firstCurrentResultVisibleAtUtc,
    'boundary': boundary,
  };

  String get contractSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'contract_sha256': contractSha256,
  };
}

final class MultisourceBorrowingResult {
  final String sourceId;
  final String sourceRecordSha256;
  final double sourceRate;
  final double biasAdjustedRate;
  final double conflictScore;
  final double dependencyDiscount;
  final double rawWeight;
  final double adjustedWeight;
  final double borrowedEffectiveSampleSize;

  const MultisourceBorrowingResult({
    required this.sourceId,
    required this.sourceRecordSha256,
    required this.sourceRate,
    required this.biasAdjustedRate,
    required this.conflictScore,
    required this.dependencyDiscount,
    required this.rawWeight,
    required this.adjustedWeight,
    required this.borrowedEffectiveSampleSize,
  });

  MultisourceBorrowingResult copyWith({
    String? sourceRecordSha256,
    double? biasAdjustedRate,
    double? conflictScore,
    double? dependencyDiscount,
    double? rawWeight,
    double? adjustedWeight,
    double? borrowedEffectiveSampleSize,
  }) => MultisourceBorrowingResult(
    sourceId: sourceId,
    sourceRecordSha256: sourceRecordSha256 ?? this.sourceRecordSha256,
    sourceRate: sourceRate,
    biasAdjustedRate: biasAdjustedRate ?? this.biasAdjustedRate,
    conflictScore: conflictScore ?? this.conflictScore,
    dependencyDiscount: dependencyDiscount ?? this.dependencyDiscount,
    rawWeight: rawWeight ?? this.rawWeight,
    adjustedWeight: adjustedWeight ?? this.adjustedWeight,
    borrowedEffectiveSampleSize:
        borrowedEffectiveSampleSize ?? this.borrowedEffectiveSampleSize,
  );

  Map<String, Object?> get canonicalPayload => {
    'source_id': sourceId,
    'source_record_sha256': sourceRecordSha256,
    'source_rate': sourceRate,
    'bias_adjusted_rate': biasAdjustedRate,
    'conflict_score': conflictScore,
    'dependency_discount': dependencyDiscount,
    'raw_weight': rawWeight,
    'adjusted_weight': adjustedWeight,
    'borrowed_effective_sample_size': borrowedEffectiveSampleSize,
  };

  String get resultSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'result_sha256': resultSha256,
  };
}

final class MultisourceCriticismResult {
  final String checkId;
  final MultisourceCriticismKind kind;
  final bool passed;
  final double observedValue;
  final double acceptableLower;
  final double acceptableUpper;
  final int repetitions;
  final double monteCarloStandardError;
  final List<String> relatedSourceIds;
  final String rationale;

  MultisourceCriticismResult({
    required this.checkId,
    required this.kind,
    required this.passed,
    required this.observedValue,
    required this.acceptableLower,
    required this.acceptableUpper,
    required this.repetitions,
    required this.monteCarloStandardError,
    required List<String> relatedSourceIds,
    required this.rationale,
  }) : relatedSourceIds = List.unmodifiable(relatedSourceIds);

  MultisourceCriticismResult copyWith({
    bool? passed,
    double? observedValue,
    double? acceptableLower,
    double? acceptableUpper,
    int? repetitions,
    double? monteCarloStandardError,
    List<String>? relatedSourceIds,
    String? rationale,
  }) => MultisourceCriticismResult(
    checkId: checkId,
    kind: kind,
    passed: passed ?? this.passed,
    observedValue: observedValue ?? this.observedValue,
    acceptableLower: acceptableLower ?? this.acceptableLower,
    acceptableUpper: acceptableUpper ?? this.acceptableUpper,
    repetitions: repetitions ?? this.repetitions,
    monteCarloStandardError:
        monteCarloStandardError ?? this.monteCarloStandardError,
    relatedSourceIds: relatedSourceIds ?? this.relatedSourceIds,
    rationale: rationale ?? this.rationale,
  );

  Map<String, Object?> get canonicalPayload => {
    'check_id': checkId,
    'kind': kind.name,
    'passed': passed,
    'observed_value': observedValue,
    'acceptable_lower': acceptableLower,
    'acceptable_upper': acceptableUpper,
    'repetitions': repetitions,
    'monte_carlo_standard_error': monteCarloStandardError,
    'related_source_ids': [...relatedSourceIds]..sort(),
    'rationale': rationale,
  };

  String get resultSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'result_sha256': resultSha256,
  };
}

final class MultisourceOperatingScenario {
  final String scenarioId;
  final MultisourceScenarioFamily family;
  final bool nullCompatible;
  final double trueControlRate;
  final double trueTreatmentRate;
  final double externalRateShift;
  final double overlapMultiplier;
  final double biasMultiplier;
  final int repetitions;
  final double maximumFalsePositiveProbability;
  final double minimumDecisionProbability;
  final double maximumAbsoluteBias;
  final double minimumCoverage;
  final String prespecifiedAtUtc;

  const MultisourceOperatingScenario({
    required this.scenarioId,
    required this.family,
    required this.nullCompatible,
    required this.trueControlRate,
    required this.trueTreatmentRate,
    required this.externalRateShift,
    required this.overlapMultiplier,
    required this.biasMultiplier,
    required this.repetitions,
    required this.maximumFalsePositiveProbability,
    required this.minimumDecisionProbability,
    required this.maximumAbsoluteBias,
    required this.minimumCoverage,
    required this.prespecifiedAtUtc,
  });

  MultisourceOperatingScenario copyWith({
    String? scenarioId,
    MultisourceScenarioFamily? family,
    bool? nullCompatible,
    double? trueControlRate,
    double? trueTreatmentRate,
    double? externalRateShift,
    double? overlapMultiplier,
    double? biasMultiplier,
    int? repetitions,
    double? maximumFalsePositiveProbability,
    double? minimumDecisionProbability,
    double? maximumAbsoluteBias,
    double? minimumCoverage,
    String? prespecifiedAtUtc,
  }) => MultisourceOperatingScenario(
    scenarioId: scenarioId ?? this.scenarioId,
    family: family ?? this.family,
    nullCompatible: nullCompatible ?? this.nullCompatible,
    trueControlRate: trueControlRate ?? this.trueControlRate,
    trueTreatmentRate: trueTreatmentRate ?? this.trueTreatmentRate,
    externalRateShift: externalRateShift ?? this.externalRateShift,
    overlapMultiplier: overlapMultiplier ?? this.overlapMultiplier,
    biasMultiplier: biasMultiplier ?? this.biasMultiplier,
    repetitions: repetitions ?? this.repetitions,
    maximumFalsePositiveProbability:
        maximumFalsePositiveProbability ?? this.maximumFalsePositiveProbability,
    minimumDecisionProbability:
        minimumDecisionProbability ?? this.minimumDecisionProbability,
    maximumAbsoluteBias: maximumAbsoluteBias ?? this.maximumAbsoluteBias,
    minimumCoverage: minimumCoverage ?? this.minimumCoverage,
    prespecifiedAtUtc: prespecifiedAtUtc ?? this.prespecifiedAtUtc,
  );

  Map<String, Object?> get canonicalPayload => {
    'scenario_id': scenarioId,
    'family': family.name,
    'null_compatible': nullCompatible,
    'true_control_rate': trueControlRate,
    'true_treatment_rate': trueTreatmentRate,
    'external_rate_shift': externalRateShift,
    'overlap_multiplier': overlapMultiplier,
    'bias_multiplier': biasMultiplier,
    'repetitions': repetitions,
    'maximum_false_positive_probability': maximumFalsePositiveProbability,
    'minimum_decision_probability': minimumDecisionProbability,
    'maximum_absolute_bias': maximumAbsoluteBias,
    'minimum_coverage': minimumCoverage,
    'prespecified_at_utc': prespecifiedAtUtc,
  };

  String get scenarioSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'scenario_sha256': scenarioSha256,
  };
}

final class MultisourceOperatingResult {
  final String scenarioId;
  final String scenarioSha256;
  final int repetitions;
  final int decisionCount;
  final int coverageCount;
  final double decisionProbability;
  final double monteCarloStandardError;
  final double meanPosteriorEffect;
  final double bias;
  final double coverage;
  final double meanBorrowedEffectiveSampleSize;

  const MultisourceOperatingResult({
    required this.scenarioId,
    required this.scenarioSha256,
    required this.repetitions,
    required this.decisionCount,
    required this.coverageCount,
    required this.decisionProbability,
    required this.monteCarloStandardError,
    required this.meanPosteriorEffect,
    required this.bias,
    required this.coverage,
    required this.meanBorrowedEffectiveSampleSize,
  });

  MultisourceOperatingResult copyWith({
    String? scenarioSha256,
    int? repetitions,
    int? decisionCount,
    int? coverageCount,
    double? decisionProbability,
    double? monteCarloStandardError,
    double? meanPosteriorEffect,
    double? bias,
    double? coverage,
    double? meanBorrowedEffectiveSampleSize,
  }) => MultisourceOperatingResult(
    scenarioId: scenarioId,
    scenarioSha256: scenarioSha256 ?? this.scenarioSha256,
    repetitions: repetitions ?? this.repetitions,
    decisionCount: decisionCount ?? this.decisionCount,
    coverageCount: coverageCount ?? this.coverageCount,
    decisionProbability: decisionProbability ?? this.decisionProbability,
    monteCarloStandardError:
        monteCarloStandardError ?? this.monteCarloStandardError,
    meanPosteriorEffect: meanPosteriorEffect ?? this.meanPosteriorEffect,
    bias: bias ?? this.bias,
    coverage: coverage ?? this.coverage,
    meanBorrowedEffectiveSampleSize:
        meanBorrowedEffectiveSampleSize ?? this.meanBorrowedEffectiveSampleSize,
  );

  Map<String, Object?> get canonicalPayload => {
    'scenario_id': scenarioId,
    'scenario_sha256': scenarioSha256,
    'repetitions': repetitions,
    'decision_count': decisionCount,
    'coverage_count': coverageCount,
    'decision_probability': decisionProbability,
    'monte_carlo_standard_error': monteCarloStandardError,
    'mean_posterior_effect': meanPosteriorEffect,
    'bias': bias,
    'coverage': coverage,
    'mean_borrowed_effective_sample_size': meanBorrowedEffectiveSampleSize,
  };

  String get resultSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'result_sha256': resultSha256,
  };
}

final class MultisourceIndependentReplication {
  final String language;
  final String dependencyLock;
  final String scriptPath;
  final String scriptSha256;
  final Map<String, double> casePosteriorMeans;
  final double tolerance;
  final bool importsProductionCode;
  final bool importsGoldenOutputs;

  MultisourceIndependentReplication({
    required this.language,
    required this.dependencyLock,
    required this.scriptPath,
    required this.scriptSha256,
    required Map<String, double> casePosteriorMeans,
    required this.tolerance,
    required this.importsProductionCode,
    required this.importsGoldenOutputs,
  }) : casePosteriorMeans = Map.unmodifiable(casePosteriorMeans);

  MultisourceIndependentReplication copyWith({
    String? language,
    String? dependencyLock,
    String? scriptPath,
    String? scriptSha256,
    Map<String, double>? casePosteriorMeans,
    double? tolerance,
    bool? importsProductionCode,
    bool? importsGoldenOutputs,
  }) => MultisourceIndependentReplication(
    language: language ?? this.language,
    dependencyLock: dependencyLock ?? this.dependencyLock,
    scriptPath: scriptPath ?? this.scriptPath,
    scriptSha256: scriptSha256 ?? this.scriptSha256,
    casePosteriorMeans: casePosteriorMeans ?? this.casePosteriorMeans,
    tolerance: tolerance ?? this.tolerance,
    importsProductionCode: importsProductionCode ?? this.importsProductionCode,
    importsGoldenOutputs: importsGoldenOutputs ?? this.importsGoldenOutputs,
  );

  Map<String, Object?> get canonicalPayload => {
    'language': language,
    'dependency_lock': dependencyLock,
    'script_path': scriptPath,
    'script_sha256': scriptSha256,
    'case_posterior_means': {
      for (final key in casePosteriorMeans.keys.toList()..sort())
        key: casePosteriorMeans[key],
    },
    'tolerance': tolerance,
    'imports_production_code': importsProductionCode,
    'imports_golden_outputs': importsGoldenOutputs,
  };

  String get evidenceSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'evidence_sha256': evidenceSha256,
  };
}

final class CredibilityBayesianMultisourceModelCriticismPackage {
  static const String schema =
      'parkinsum.credibility-bayesian-multisource-model-criticism-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v4';

  final int schemaVersion;
  final String packageId;
  final CredibilityBayesianBorrowingCalibrationPackage bayesianPackage;
  final String bayesianPackageSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final MultisourceModelContract contract;
  final List<MultisourceExternalEvidenceRecord> sourceLedger;
  final List<MultisourceBorrowingResult> borrowingResults;
  final List<MultisourceCriticismResult> criticismResults;
  final List<MultisourceOperatingScenario> scenarios;
  final List<MultisourceOperatingResult> operatingResults;
  final MultisourceIndependentReplication independentReplication;
  final double priorAlpha;
  final double priorBeta;
  final double posteriorControlMean;
  final bool exhaustiveSearchRetained;
  final bool allPrespecifiedResultsRetained;
  final bool sourceOrderInvariant;
  final String analysisStartedAtUtc;
  final String analysisCompletedAtUtc;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityBayesianMultisourceModelCriticismPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.bayesianPackage,
    required this.bayesianPackageSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.contract,
    required List<MultisourceExternalEvidenceRecord> sourceLedger,
    required List<MultisourceBorrowingResult> borrowingResults,
    required List<MultisourceCriticismResult> criticismResults,
    required List<MultisourceOperatingScenario> scenarios,
    required List<MultisourceOperatingResult> operatingResults,
    required this.independentReplication,
    required this.priorAlpha,
    required this.priorBeta,
    required this.posteriorControlMean,
    required this.exhaustiveSearchRetained,
    required this.allPrespecifiedResultsRetained,
    required this.sourceOrderInvariant,
    required this.analysisStartedAtUtc,
    required this.analysisCompletedAtUtc,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : sourceLedger = List.unmodifiable(sourceLedger),
       borrowingResults = List.unmodifiable(borrowingResults),
       criticismResults = List.unmodifiable(criticismResults),
       scenarios = List.unmodifiable(scenarios),
       operatingResults = List.unmodifiable(operatingResults);

  CredibilityBayesianMultisourceModelCriticismPackage copyWith({
    int? schemaVersion,
    String? bayesianPackageSha256,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    MultisourceModelContract? contract,
    List<MultisourceExternalEvidenceRecord>? sourceLedger,
    List<MultisourceBorrowingResult>? borrowingResults,
    List<MultisourceCriticismResult>? criticismResults,
    List<MultisourceOperatingScenario>? scenarios,
    List<MultisourceOperatingResult>? operatingResults,
    MultisourceIndependentReplication? independentReplication,
    double? priorAlpha,
    double? priorBeta,
    double? posteriorControlMean,
    bool? exhaustiveSearchRetained,
    bool? allPrespecifiedResultsRetained,
    bool? sourceOrderInvariant,
    String? analysisStartedAtUtc,
    String? analysisCompletedAtUtc,
    bool? revoked,
    bool? syntheticDemoOnly,
    String? boundary,
  }) => CredibilityBayesianMultisourceModelCriticismPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    bayesianPackage: bayesianPackage,
    bayesianPackageSha256: bayesianPackageSha256 ?? this.bayesianPackageSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    contract: contract ?? this.contract,
    sourceLedger: sourceLedger ?? this.sourceLedger,
    borrowingResults: borrowingResults ?? this.borrowingResults,
    criticismResults: criticismResults ?? this.criticismResults,
    scenarios: scenarios ?? this.scenarios,
    operatingResults: operatingResults ?? this.operatingResults,
    independentReplication:
        independentReplication ?? this.independentReplication,
    priorAlpha: priorAlpha ?? this.priorAlpha,
    priorBeta: priorBeta ?? this.priorBeta,
    posteriorControlMean: posteriorControlMean ?? this.posteriorControlMean,
    exhaustiveSearchRetained:
        exhaustiveSearchRetained ?? this.exhaustiveSearchRetained,
    allPrespecifiedResultsRetained:
        allPrespecifiedResultsRetained ?? this.allPrespecifiedResultsRetained,
    sourceOrderInvariant: sourceOrderInvariant ?? this.sourceOrderInvariant,
    analysisStartedAtUtc: analysisStartedAtUtc ?? this.analysisStartedAtUtc,
    analysisCompletedAtUtc:
        analysisCompletedAtUtc ?? this.analysisCompletedAtUtc,
    revoked: revoked ?? this.revoked,
    syntheticDemoOnly: syntheticDemoOnly ?? this.syntheticDemoOnly,
    boundary: boundary ?? this.boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'package_version': packageVersion,
    'package_id': packageId,
    'bayesian_package_sha256': bayesianPackageSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'contract': contract.toJson(),
    'source_ledger': sourceLedger.map((item) => item.toJson()).toList(),
    'borrowing_results': borrowingResults.map((item) => item.toJson()).toList(),
    'criticism_results': criticismResults.map((item) => item.toJson()).toList(),
    'scenarios': scenarios.map((item) => item.toJson()).toList(),
    'operating_results': operatingResults.map((item) => item.toJson()).toList(),
    'independent_replication': independentReplication.toJson(),
    'prior_alpha': priorAlpha,
    'prior_beta': priorBeta,
    'posterior_control_mean': posteriorControlMean,
    'exhaustive_search_retained': exhaustiveSearchRetained,
    'all_prespecified_results_retained': allPrespecifiedResultsRetained,
    'source_order_invariant': sourceOrderInvariant,
    'analysis_started_at_utc': analysisStartedAtUtc,
    'analysis_completed_at_utc': analysisCompletedAtUtc,
    'revoked': revoked,
    'synthetic_demo_only': syntheticDemoOnly,
    'boundary': boundary,
  };

  String get packageSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'package_sha256': packageSha256,
  };
}

final class MultisourceFinding {
  final MultisourceFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  MultisourceFinding({
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

final class MultisourceGovernanceAssessment {
  final CredibilityBayesianMultisourceModelCriticismPackage package;
  final MultisourceGovernanceStatus status;
  final List<MultisourceFinding> findings;

  MultisourceGovernanceAssessment._({
    required this.package,
    required this.status,
    required List<MultisourceFinding> findings,
  }) : findings = List.unmodifiable(findings);

  bool get integrityVerified => findings.isEmpty;
  bool get canEstablishTransportabilityOrClinicalValidity => false;

  bool _has(Set<MultisourceFindingKind> kinds) =>
      findings.any((finding) => kinds.contains(finding.kind));

  Map<String, String> get lanes => {
    'sourceDiscovery':
        _has({
          MultisourceFindingKind.searchLedgerIncomplete,
          MultisourceFindingKind.postResultSelection,
          MultisourceFindingKind.sourceDuplicateIncluded,
        })
        ? 'blocked'
        : 'frozenLedgerRetained',
    'dependency': _has({MultisourceFindingKind.sourceDependencyUnresolved})
        ? 'unresolved'
        : 'cohortLinkageDiscounted',
    'transportability':
        _has({
          MultisourceFindingKind.sourceMismatchIncluded,
          MultisourceFindingKind.transportabilityUnresolved,
        })
        ? 'held'
        : 'overlapDriftAndMissingnessVisible',
    'exchangeability': _has({MultisourceFindingKind.exchangeabilityOverclaimed})
        ? 'held'
        : 'sourceSpecificAssumptionsDeclared',
    'biasAdjustment':
        _has({
          MultisourceFindingKind.biasAdjustmentMissing,
          MultisourceFindingKind.borrowingArithmeticMismatch,
          MultisourceFindingKind.borrowingUnbounded,
        })
        ? 'failed'
        : 'sourceSpecificPenaltyApplied',
    'priorPredictiveCriticism':
        _has({
          MultisourceFindingKind.priorPredictiveFailure,
          MultisourceFindingKind.simulationCalibrationFailure,
          MultisourceFindingKind.criticismIncomplete,
        })
        ? 'held'
        : 'priorPredictiveAndSbcObserved',
    'posteriorPredictiveCriticism':
        _has({
          MultisourceFindingKind.posteriorPredictiveFailure,
          MultisourceFindingKind.criticismIncomplete,
        })
        ? 'held'
        : 'posteriorPredictiveObserved',
    'sensitivityAndNegativeControls':
        _has({
          MultisourceFindingKind.sensitivityIncomplete,
          MultisourceFindingKind.sourceOrderDrift,
          MultisourceFindingKind.negativeControlFailure,
          MultisourceFindingKind.deliberateIncompatibilityMissed,
        })
        ? 'held'
        : 'looAlternativePriorEssAndControlsObserved',
    'computation':
        _has({
          MultisourceFindingKind.scenarioIncomplete,
          MultisourceFindingKind.operatingResultMismatch,
          MultisourceFindingKind.monteCarloUnderpowered,
          MultisourceFindingKind.falsePositiveInflated,
          MultisourceFindingKind.powerInsufficient,
          MultisourceFindingKind.biasExcessive,
          MultisourceFindingKind.coverageInsufficient,
          MultisourceFindingKind.resultOmission,
        })
        ? 'failed'
        : 'operatingCharacteristicsObserved',
    'independentReplication':
        _has({
          MultisourceFindingKind.independentImplementationMissing,
          MultisourceFindingKind.independentImplementationMismatch,
          MultisourceFindingKind.identityMismatch,
          MultisourceFindingKind.historyBroken,
          MultisourceFindingKind.revocation,
        })
        ? 'blocked'
        : 'pythonManufacturedCasesAgree',
  };

  Map<String, int> get counts => {
    'sources': package.sourceLedger.length,
    'includedSources': package.sourceLedger
        .where((item) => item.included)
        .length,
    'dependencyGroups': package.sourceLedger
        .map((item) => item.dependencyGroupId)
        .toSet()
        .length,
    'criticismChecks': package.criticismResults.length,
    'scenarios': package.scenarios.length,
    'totalRepetitions': package.operatingResults.fold(
      0,
      (total, item) => total + item.repetitions,
    ),
    'independentCases':
        package.independentReplication.casePosteriorMeans.length,
  };

  double get totalBorrowedEffectiveSampleSize => package.borrowingResults.fold(
    0,
    (total, item) => total + item.borrowedEffectiveSampleSize,
  );

  double get maximumMonteCarloStandardError => package.operatingResults.isEmpty
      ? double.nan
      : package.operatingResults
            .map((item) => item.monteCarloStandardError)
            .reduce(math.max);

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'lanes': lanes,
    'counts': counts,
    'total_borrowed_effective_sample_size': totalBorrowedEffectiveSampleSize,
    'maximum_monte_carlo_standard_error': maximumMonteCarloStandardError,
    'can_establish_transportability_or_clinical_validity':
        canEstablishTransportabilityOrClinicalValidity,
    'findings': findings.map((item) => item.toJson()).toList(),
  };
}

final class CredibilityBayesianMultisourceModelCriticismVerifier {
  static const Set<String> _requiredSourceIds = {
    'ext-trial-a',
    'ext-trial-b',
    'ext-trial-a-duplicate',
    'ext-registry-a-linked',
    'ext-contradictory',
    'ext-unavailable',
    'ext-population-mismatch',
  };
  static const Set<MultisourceCriticismKind> _requiredCriticismKinds = {
    MultisourceCriticismKind.priorPredictive,
    MultisourceCriticismKind.simulationBasedCalibration,
    MultisourceCriticismKind.posteriorPredictive,
    MultisourceCriticismKind.alternativePrior,
    MultisourceCriticismKind.effectiveSampleSize,
    MultisourceCriticismKind.leaveOneSourceOut,
    MultisourceCriticismKind.sourceOrderInvariance,
    MultisourceCriticismKind.negativeControl,
    MultisourceCriticismKind.deliberateIncompatibility,
  };
  static final Set<MultisourceScenarioFamily> _requiredScenarioFamilies =
      MultisourceScenarioFamily.values.toSet();
  static const String expectedIndependentScriptSha256 =
      'e4e968e68aeb25de08346edbcb124fd871d8d74d4f75ba3df5b34095e985f7be';

  const CredibilityBayesianMultisourceModelCriticismVerifier();

  MultisourceGovernanceAssessment verify(
    CredibilityBayesianMultisourceModelCriticismPackage package,
  ) {
    final findings = <MultisourceFinding>[];
    void add(
      MultisourceFindingKind kind,
      String detail, [
      List<String> ids = const [],
    ]) => findings.add(
      MultisourceFinding(kind: kind, detail: detail, affectedIds: ids),
    );

    if (package.schemaVersion !=
        CredibilityBayesianMultisourceModelCriticismPackage
            .currentSchemaVersion) {
      add(MultisourceFindingKind.schemaUnsupported, 'schema_version');
    }
    if (package.bayesianPackageSha256 !=
            package.bayesianPackage.packageSha256 ||
        package.configurationSha256 !=
            package.bayesianPackage.configurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            package.bayesianPackage.algorithmSourceBundleSha256) {
      add(MultisourceFindingKind.identityMismatch, 'upstream_identity');
    }
    for (final digest in [
      package.bayesianPackageSha256,
      package.configurationSha256,
      package.algorithmSourceBundleSha256,
      package.contract.searchStrategySha256,
      package.contract.modelCodeSha256,
      package.contract.independentScriptSha256,
    ]) {
      if (!_isSha256(digest)) {
        add(MultisourceFindingKind.malformedDigest, 'digest', [digest]);
      }
    }
    final sourceIds = package.sourceLedger
        .map((item) => item.sourceId)
        .toList();
    if (!package.exhaustiveSearchRetained ||
        sourceIds.toSet().length != sourceIds.length ||
        !sourceIds.toSet().containsAll(_requiredSourceIds) ||
        !package.sourceLedger
            .map((item) => item.disposition)
            .toSet()
            .containsAll(MultisourceEvidenceDisposition.values)) {
      add(MultisourceFindingKind.searchLedgerIncomplete, 'source_ledger');
    }
    final frozenAt = DateTime.tryParse(package.contract.searchFrozenAtUtc);
    final firstResult = DateTime.tryParse(
      package.contract.firstCurrentResultVisibleAtUtc,
    );
    final startedAt = DateTime.tryParse(package.analysisStartedAtUtc);
    final completedAt = DateTime.tryParse(package.analysisCompletedAtUtc);
    if (frozenAt == null ||
        firstResult == null ||
        !frozenAt.isBefore(firstResult) ||
        package.sourceLedger.any((item) {
          final assessed = DateTime.tryParse(item.assessedAtUtc);
          return assessed == null || assessed.isAfter(frozenAt);
        })) {
      add(MultisourceFindingKind.postResultSelection, 'selection_chronology');
    }
    if (startedAt == null ||
        completedAt == null ||
        firstResult == null ||
        startedAt.isBefore(firstResult) ||
        !startedAt.isBefore(completedAt)) {
      add(MultisourceFindingKind.historyBroken, 'analysis_chronology');
    }

    final cohorts = <String, List<MultisourceExternalEvidenceRecord>>{};
    for (final source in package.sourceLedger) {
      cohorts.putIfAbsent(source.cohortId, () => []).add(source);
      if (source.included &&
          (source.disposition == MultisourceEvidenceDisposition.duplicate ||
              source.sourceId == 'ext-trial-a-duplicate')) {
        add(
          MultisourceFindingKind.sourceDuplicateIncluded,
          'duplicate_included',
          [source.sourceId],
        );
      }
      if (source.included &&
          (source.disposition == MultisourceEvidenceDisposition.contradictory ||
              source.disposition ==
                  MultisourceEvidenceDisposition.unavailable ||
              source.exchangeability ==
                  MultisourceExchangeability.nonexchangeable ||
              source.exchangeability == MultisourceExchangeability.unknown ||
              source.outcomeId != package.contract.outcomeId ||
              source.estimandId != package.contract.estimandId)) {
        add(
          MultisourceFindingKind.sourceMismatchIncluded,
          'unsuitable_source_included',
          [source.sourceId],
        );
      }
      if (source.included &&
          (source.qualityScore < package.contract.minimumQuality ||
              source.relevanceScore < package.contract.minimumRelevance ||
              source.completenessScore < package.contract.minimumCompleteness ||
              source.overlapScore < package.contract.minimumOverlap ||
              source.temporalDriftScore >
                  package.contract.maximumTemporalDrift ||
              source.missingCovariates.length >=
                  package.contract.requiredCovariates.length)) {
        add(
          MultisourceFindingKind.transportabilityUnresolved,
          'transportability_threshold',
          [source.sourceId],
        );
      }
      if (source.included &&
          source.exchangeability == MultisourceExchangeability.full &&
          (source.missingCovariates.isNotEmpty ||
              source.temporalDriftScore > 0.05 ||
              source.biasRiskScore > 0.05)) {
        add(
          MultisourceFindingKind.exchangeabilityOverclaimed,
          'full_exchangeability_overclaim',
          [source.sourceId],
        );
      }
    }
    if (cohorts.values.any(
      (items) => items.where((item) => item.included).length > 1,
    )) {
      add(MultisourceFindingKind.sourceDuplicateIncluded, 'cohort_reuse');
    }
    final dependencyGroups = <String, int>{};
    for (final source in package.sourceLedger.where((item) => item.included)) {
      dependencyGroups.update(
        source.dependencyGroupId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final resultBySource = {
      for (final result in package.borrowingResults) result.sourceId: result,
    };
    final includedSources = package.sourceLedger.where((item) => item.included);
    if (resultBySource.length != package.borrowingResults.length ||
        resultBySource.keys.toSet().length != includedSources.length ||
        !resultBySource.keys.toSet().containsAll(
          includedSources.map((item) => item.sourceId),
        )) {
      add(MultisourceFindingKind.resultOmission, 'borrowing_results');
    }
    for (final source in includedSources) {
      final result = resultBySource[source.sourceId];
      if (result == null) continue;
      final expectedDependency =
          1 / (dependencyGroups[source.dependencyGroupId] ?? 1);
      if ((result.dependencyDiscount - expectedDependency).abs() > 1e-12) {
        add(
          MultisourceFindingKind.sourceDependencyUnresolved,
          'dependency_discount',
          [source.sourceId],
        );
      }
      if (result.sourceRecordSha256 != source.recordSha256 ||
          result.sourceRate != source.successes / source.total ||
          result.adjustedWeight < 0 ||
          result.adjustedWeight > result.rawWeight + 1e-12 ||
          result.borrowedEffectiveSampleSize < 0) {
        add(
          MultisourceFindingKind.borrowingArithmeticMismatch,
          'source_result',
          [source.sourceId],
        );
      }
      if ((result.biasAdjustedRate -
                  (result.sourceRate - source.biasRiskScore * 0.05))
              .abs() >
          1e-12) {
        add(
          MultisourceFindingKind.biasAdjustmentMissing,
          'bias_adjusted_rate',
          [source.sourceId],
        );
      }
    }
    final borrowedEss = package.borrowingResults.fold<double>(
      0,
      (total, result) => total + result.borrowedEffectiveSampleSize,
    );
    if (borrowedEss > package.contract.maximumTotalBorrowedEss + 1e-9 ||
        package.contract.maximumTotalBorrowedEss > 40) {
      add(MultisourceFindingKind.borrowingUnbounded, 'total_ess');
    }
    final expectedPriorAlpha =
        1 +
        package.borrowingResults.fold<double>(
          0,
          (total, result) =>
              total +
              result.biasAdjustedRate * result.borrowedEffectiveSampleSize,
        );
    final expectedPriorBeta =
        1 +
        package.borrowingResults.fold<double>(
          0,
          (total, result) =>
              total +
              (1 - result.biasAdjustedRate) *
                  result.borrowedEffectiveSampleSize,
        );
    final expectedPosteriorMean =
        (expectedPriorAlpha + 16) /
        (expectedPriorAlpha + expectedPriorBeta + 50);
    if ((package.priorAlpha - expectedPriorAlpha).abs() > 1e-10 ||
        (package.priorBeta - expectedPriorBeta).abs() > 1e-10 ||
        (package.posteriorControlMean - expectedPosteriorMean).abs() > 1e-10) {
      add(
        MultisourceFindingKind.borrowingArithmeticMismatch,
        'aggregate_prior',
      );
    }

    final checkIds = package.criticismResults
        .map((item) => item.checkId)
        .toList();
    final criticismKinds = package.criticismResults
        .map((item) => item.kind)
        .toSet();
    if (checkIds.toSet().length != checkIds.length ||
        !criticismKinds.containsAll(_requiredCriticismKinds)) {
      add(MultisourceFindingKind.criticismIncomplete, 'criticism_catalog');
    }
    for (final check in package.criticismResults) {
      final arithmeticallyPassed =
          check.observedValue >= check.acceptableLower &&
          check.observedValue <= check.acceptableUpper;
      if (check.passed != arithmeticallyPassed ||
          !check.observedValue.isFinite ||
          check.repetitions < 0 ||
          check.monteCarloStandardError < 0) {
        add(
          MultisourceFindingKind.criticismIncomplete,
          'criticism_arithmetic',
          [check.checkId],
        );
      }
      if (!check.passed) {
        switch (check.kind) {
          case MultisourceCriticismKind.priorPredictive:
            add(MultisourceFindingKind.priorPredictiveFailure, check.checkId);
          case MultisourceCriticismKind.simulationBasedCalibration:
            add(
              MultisourceFindingKind.simulationCalibrationFailure,
              check.checkId,
            );
          case MultisourceCriticismKind.posteriorPredictive:
            add(
              MultisourceFindingKind.posteriorPredictiveFailure,
              check.checkId,
            );
          case MultisourceCriticismKind.sourceOrderInvariance:
            add(MultisourceFindingKind.sourceOrderDrift, check.checkId);
          case MultisourceCriticismKind.negativeControl:
            add(MultisourceFindingKind.negativeControlFailure, check.checkId);
          case MultisourceCriticismKind.deliberateIncompatibility:
            add(
              MultisourceFindingKind.deliberateIncompatibilityMissed,
              check.checkId,
            );
          case MultisourceCriticismKind.alternativePrior:
          case MultisourceCriticismKind.effectiveSampleSize:
          case MultisourceCriticismKind.leaveOneSourceOut:
            add(MultisourceFindingKind.sensitivityIncomplete, check.checkId);
        }
      }
    }
    if (!package.sourceOrderInvariant) {
      add(MultisourceFindingKind.sourceOrderDrift, 'package_flag');
    }

    final scenarioIds = package.scenarios
        .map((item) => item.scenarioId)
        .toList();
    if (scenarioIds.toSet().length != scenarioIds.length ||
        !package.scenarios
            .map((item) => item.family)
            .toSet()
            .containsAll(_requiredScenarioFamilies)) {
      add(MultisourceFindingKind.scenarioIncomplete, 'scenario_catalog');
    }
    final resultsByScenario = <String, MultisourceOperatingResult>{};
    for (final result in package.operatingResults) {
      if (resultsByScenario.containsKey(result.scenarioId)) {
        add(MultisourceFindingKind.resultOmission, 'duplicate_result', [
          result.scenarioId,
        ]);
      }
      resultsByScenario[result.scenarioId] = result;
    }
    if (!package.allPrespecifiedResultsRetained ||
        resultsByScenario.length != package.scenarios.length) {
      add(MultisourceFindingKind.resultOmission, 'operating_results');
    }
    for (final scenario in package.scenarios) {
      final result = resultsByScenario[scenario.scenarioId];
      if (result == null) continue;
      final expectedProbability = result.decisionCount / result.repetitions;
      final expectedCoverage = result.coverageCount / result.repetitions;
      final expectedMcse = math.sqrt(
        expectedProbability * (1 - expectedProbability) / result.repetitions,
      );
      if (result.scenarioSha256 != scenario.scenarioSha256 ||
          result.repetitions != scenario.repetitions ||
          (result.decisionProbability - expectedProbability).abs() > 1e-12 ||
          (result.coverage - expectedCoverage).abs() > 1e-12 ||
          (result.monteCarloStandardError - expectedMcse).abs() > 1e-12) {
        add(
          MultisourceFindingKind.operatingResultMismatch,
          'result_arithmetic',
          [scenario.scenarioId],
        );
      }
      if (result.repetitions < 20000 ||
          result.monteCarloStandardError > 0.004) {
        add(MultisourceFindingKind.monteCarloUnderpowered, 'precision', [
          scenario.scenarioId,
        ]);
      }
      if (scenario.nullCompatible &&
          result.decisionProbability >
              scenario.maximumFalsePositiveProbability) {
        add(MultisourceFindingKind.falsePositiveInflated, 'false_positive', [
          scenario.scenarioId,
        ]);
      }
      if (!scenario.nullCompatible &&
          result.decisionProbability < scenario.minimumDecisionProbability) {
        add(MultisourceFindingKind.powerInsufficient, 'decision_probability', [
          scenario.scenarioId,
        ]);
      }
      if (result.bias.abs() > scenario.maximumAbsoluteBias) {
        add(MultisourceFindingKind.biasExcessive, 'bias', [
          scenario.scenarioId,
        ]);
      }
      if (result.coverage < scenario.minimumCoverage) {
        add(MultisourceFindingKind.coverageInsufficient, 'coverage', [
          scenario.scenarioId,
        ]);
      }
    }

    final independent = package.independentReplication;
    const expectedCases = {
      'aligned': 0.316981262528,
      'leave_one_out_trial_b': 0.319489394225,
      'severe_current_conflict': 0.557692307692,
      'reversed_source_order': 0.316981262528,
    };
    if (independent.language != 'Python' ||
        independent.dependencyLock != 'python-stdlib-only' ||
        independent.importsProductionCode ||
        independent.importsGoldenOutputs ||
        independent.casePosteriorMeans.keys.toSet().length !=
            expectedCases.length ||
        !independent.casePosteriorMeans.keys.toSet().containsAll(
          expectedCases.keys,
        )) {
      add(
        MultisourceFindingKind.independentImplementationMissing,
        'independent_contract',
      );
    }
    if (independent.scriptSha256 != expectedIndependentScriptSha256 ||
        independent.scriptSha256 != package.contract.independentScriptSha256 ||
        expectedCases.entries.any(
          (entry) =>
              ((independent.casePosteriorMeans[entry.key] ?? double.nan) -
                      entry.value)
                  .abs() >
              independent.tolerance,
        )) {
      add(
        MultisourceFindingKind.independentImplementationMismatch,
        'independent_results',
      );
    }
    if (package.revoked) {
      add(MultisourceFindingKind.revocation, 'explicit_revocation');
    }
    if (!package.syntheticDemoOnly || package.boundary.trim().isEmpty) {
      add(MultisourceFindingKind.historyBroken, 'boundary');
    }

    MultisourceGovernanceStatus status;
    if (findings.any(
      (item) => item.kind == MultisourceFindingKind.revocation,
    )) {
      status = MultisourceGovernanceStatus.revoked;
    } else if (findings.any(
      (item) => {
        MultisourceFindingKind.schemaUnsupported,
        MultisourceFindingKind.identityMismatch,
        MultisourceFindingKind.malformedDigest,
        MultisourceFindingKind.historyBroken,
      }.contains(item.kind),
    )) {
      status = MultisourceGovernanceStatus.violated;
    } else if (findings.isNotEmpty) {
      status = MultisourceGovernanceStatus.held;
    } else {
      status = MultisourceGovernanceStatus.mechanicallyObserved;
    }
    return MultisourceGovernanceAssessment._(
      package: package,
      status: status,
      findings: findings,
    );
  }
}

bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return '{${entries.map((entry) => '${jsonEncode(entry.key.toString())}:${_canonicalJson(entry.value)}').join(',')}}';
  }
  throw ArgumentError('Unsupported canonical JSON value: ${value.runtimeType}');
}
