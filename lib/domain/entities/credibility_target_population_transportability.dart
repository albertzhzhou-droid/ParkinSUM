import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'credibility_bayesian_multisource_model_criticism.dart';

enum TargetSampleRole { randomizedTrial, targetPopulation }

enum TransportModelSpecification { correct, misspecified }

enum TransportEstimatorKind {
  trialOnly,
  outcomeRegression,
  inverseOddsSampling,
  augmentedInverseOdds,
}

enum TransportScenarioFamily {
  correctModels,
  samplingModelMisspecified,
  outcomeModelMisspecified,
  dualMisspecification,
  rareTreatment,
  censoringMisspecified,
  supportViolation,
}

enum TransportOperatingStatus { estimated, heldNonidentifiable }

enum TargetTransportabilityStatus {
  mechanicallyObserved,
  held,
  failed,
  revoked,
}

enum TargetTransportabilityFindingKind {
  futureSchema,
  upstreamIdentity,
  runtimeIdentity,
  chronology,
  contractIncomplete,
  causalGraphIncomplete,
  assumptionIncomplete,
  recordIdentity,
  targetOutcomeLeakage,
  trialRecordIncomplete,
  covariateIncomplete,
  nonsyntheticRecord,
  overlapMismatch,
  supportViolationLaundered,
  unknownCovariateLaundered,
  weightMismatch,
  balanceMismatch,
  estimatorCatalog,
  estimatorArithmetic,
  doubleRobustness,
  sensitivityIncomplete,
  scenarioCatalog,
  operatingArithmetic,
  operatingCalibration,
  nonidentifiableEstimated,
  independentReplication,
  resultRetention,
  boundaryOverclaim,
  revoked,
}

final class CausalGraphEdge {
  final String from;
  final String to;
  final String rationale;

  const CausalGraphEdge({
    required this.from,
    required this.to,
    required this.rationale,
  });

  Map<String, Object?> toJson() => {
    'from': from,
    'to': to,
    'rationale': rationale,
  };
}

final class IdentificationAssumption {
  final String id;
  final String statement;
  final String observableDiagnostic;
  final String failureDisposition;

  const IdentificationAssumption({
    required this.id,
    required this.statement,
    required this.observableDiagnostic,
    required this.failureDisposition,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'statement': statement,
    'observable_diagnostic': observableDiagnostic,
    'failure_disposition': failureDisposition,
  };
}

final class TargetPopulationTransportabilityContract {
  final String contractId;
  final String targetPopulationId;
  final String targetEligibility;
  final String trialEligibility;
  final String causalContrast;
  final String treatmentId;
  final List<String> treatmentVersions;
  final String comparatorId;
  final String outcomeId;
  final String followUpWindow;
  final String censoringStrategy;
  final String samplingMechanism;
  final List<String> targetCovariates;
  final List<String> effectModifiers;
  final List<String> graphNodes;
  final List<CausalGraphEdge> graphEdges;
  final List<IdentificationAssumption> assumptions;
  final double randomizedTreatmentProbability;
  final double influentialWeightThreshold;
  final double maximumAcceptedWeight;
  final double maximumAcceptedWeightedSmd;
  final String outcomeModelId;
  final String samplingModelId;
  final String estimatorCodeSha256;
  final String independentScriptSha256;
  final String authoredAtUtc;
  final String targetSampleFrozenAtUtc;
  final String firstOutcomeVisibleAtUtc;
  final String boundary;

  TargetPopulationTransportabilityContract({
    required this.contractId,
    required this.targetPopulationId,
    required this.targetEligibility,
    required this.trialEligibility,
    required this.causalContrast,
    required this.treatmentId,
    required List<String> treatmentVersions,
    required this.comparatorId,
    required this.outcomeId,
    required this.followUpWindow,
    required this.censoringStrategy,
    required this.samplingMechanism,
    required List<String> targetCovariates,
    required List<String> effectModifiers,
    required List<String> graphNodes,
    required List<CausalGraphEdge> graphEdges,
    required List<IdentificationAssumption> assumptions,
    required this.randomizedTreatmentProbability,
    required this.influentialWeightThreshold,
    required this.maximumAcceptedWeight,
    required this.maximumAcceptedWeightedSmd,
    required this.outcomeModelId,
    required this.samplingModelId,
    required this.estimatorCodeSha256,
    required this.independentScriptSha256,
    required this.authoredAtUtc,
    required this.targetSampleFrozenAtUtc,
    required this.firstOutcomeVisibleAtUtc,
    required this.boundary,
  }) : treatmentVersions = List.unmodifiable(treatmentVersions),
       targetCovariates = List.unmodifiable(targetCovariates),
       effectModifiers = List.unmodifiable(effectModifiers),
       graphNodes = List.unmodifiable(graphNodes),
       graphEdges = List.unmodifiable(graphEdges),
       assumptions = List.unmodifiable(assumptions);

  TargetPopulationTransportabilityContract copyWith({
    String? targetPopulationId,
    String? causalContrast,
    List<String>? targetCovariates,
    List<String>? effectModifiers,
    List<String>? graphNodes,
    List<CausalGraphEdge>? graphEdges,
    List<IdentificationAssumption>? assumptions,
    double? maximumAcceptedWeight,
    String? estimatorCodeSha256,
    String? independentScriptSha256,
    String? authoredAtUtc,
    String? targetSampleFrozenAtUtc,
    String? firstOutcomeVisibleAtUtc,
    String? boundary,
  }) => TargetPopulationTransportabilityContract(
    contractId: contractId,
    targetPopulationId: targetPopulationId ?? this.targetPopulationId,
    targetEligibility: targetEligibility,
    trialEligibility: trialEligibility,
    causalContrast: causalContrast ?? this.causalContrast,
    treatmentId: treatmentId,
    treatmentVersions: treatmentVersions,
    comparatorId: comparatorId,
    outcomeId: outcomeId,
    followUpWindow: followUpWindow,
    censoringStrategy: censoringStrategy,
    samplingMechanism: samplingMechanism,
    targetCovariates: targetCovariates ?? this.targetCovariates,
    effectModifiers: effectModifiers ?? this.effectModifiers,
    graphNodes: graphNodes ?? this.graphNodes,
    graphEdges: graphEdges ?? this.graphEdges,
    assumptions: assumptions ?? this.assumptions,
    randomizedTreatmentProbability: randomizedTreatmentProbability,
    influentialWeightThreshold: influentialWeightThreshold,
    maximumAcceptedWeight: maximumAcceptedWeight ?? this.maximumAcceptedWeight,
    maximumAcceptedWeightedSmd: maximumAcceptedWeightedSmd,
    outcomeModelId: outcomeModelId,
    samplingModelId: samplingModelId,
    estimatorCodeSha256: estimatorCodeSha256 ?? this.estimatorCodeSha256,
    independentScriptSha256:
        independentScriptSha256 ?? this.independentScriptSha256,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    targetSampleFrozenAtUtc:
        targetSampleFrozenAtUtc ?? this.targetSampleFrozenAtUtc,
    firstOutcomeVisibleAtUtc:
        firstOutcomeVisibleAtUtc ?? this.firstOutcomeVisibleAtUtc,
    boundary: boundary ?? this.boundary,
  );

  Map<String, Object?> toJson() => {
    'contract_id': contractId,
    'target_population_id': targetPopulationId,
    'target_eligibility': targetEligibility,
    'trial_eligibility': trialEligibility,
    'causal_contrast': causalContrast,
    'treatment_id': treatmentId,
    'treatment_versions': treatmentVersions,
    'comparator_id': comparatorId,
    'outcome_id': outcomeId,
    'follow_up_window': followUpWindow,
    'censoring_strategy': censoringStrategy,
    'sampling_mechanism': samplingMechanism,
    'target_covariates': targetCovariates,
    'effect_modifiers': effectModifiers,
    'causal_graph': {
      'nodes': graphNodes,
      'edges': graphEdges.map((edge) => edge.toJson()).toList(),
    },
    'identification_assumptions': assumptions
        .map((assumption) => assumption.toJson())
        .toList(),
    'randomized_treatment_probability': randomizedTreatmentProbability,
    'influential_weight_threshold': influentialWeightThreshold,
    'maximum_accepted_weight': maximumAcceptedWeight,
    'maximum_accepted_weighted_smd': maximumAcceptedWeightedSmd,
    'outcome_model_id': outcomeModelId,
    'sampling_model_id': samplingModelId,
    'estimator_code_sha256': estimatorCodeSha256,
    'independent_script_sha256': independentScriptSha256,
    'authored_at_utc': authoredAtUtc,
    'target_sample_frozen_at_utc': targetSampleFrozenAtUtc,
    'first_outcome_visible_at_utc': firstOutcomeVisibleAtUtc,
    'boundary': boundary,
  };
}

final class SyntheticTransportRecord {
  final String recordId;
  final TargetSampleRole role;
  final String stratumId;
  final int effectModifierScore;
  final Map<String, Object?> covariates;
  final int? treatment;
  final double? outcome;
  final double? treatmentProbability;
  final bool outcomeObserved;
  final bool synthetic;

  SyntheticTransportRecord({
    required this.recordId,
    required this.role,
    required this.stratumId,
    required this.effectModifierScore,
    required Map<String, Object?> covariates,
    required this.treatment,
    required this.outcome,
    required this.treatmentProbability,
    required this.outcomeObserved,
    required this.synthetic,
  }) : covariates = Map.unmodifiable(covariates);

  SyntheticTransportRecord copyWith({
    String? recordId,
    Map<String, Object?>? covariates,
    int? treatment,
    double? outcome,
    double? treatmentProbability,
    bool? outcomeObserved,
    bool? synthetic,
  }) => SyntheticTransportRecord(
    recordId: recordId ?? this.recordId,
    role: role,
    stratumId: stratumId,
    effectModifierScore: effectModifierScore,
    covariates: covariates ?? this.covariates,
    treatment: treatment ?? this.treatment,
    outcome: outcome ?? this.outcome,
    treatmentProbability: treatmentProbability ?? this.treatmentProbability,
    outcomeObserved: outcomeObserved ?? this.outcomeObserved,
    synthetic: synthetic ?? this.synthetic,
  );

  Map<String, Object?> toJson() => {
    'record_id': recordId,
    'role': role.name,
    'stratum_id': stratumId,
    'effect_modifier_score': effectModifierScore,
    'covariates': {
      for (final key in covariates.keys.toList()..sort()) key: covariates[key],
    },
    'treatment': treatment,
    'outcome': outcome,
    'treatment_probability': treatmentProbability,
    'outcome_observed': outcomeObserved,
    'synthetic': synthetic,
  };
}

final class TargetOverlapDiagnostic {
  final int trialCount;
  final int targetCount;
  final List<String> supportViolationStrata;
  final List<String> unknownTargetCovariates;
  final List<String> excludedTargetStrata;
  final double minimumSamplingScore;
  final double maximumSamplingScore;
  final double minimumInverseOddsWeight;
  final double maximumInverseOddsWeight;
  final double p99InverseOddsWeight;
  final double effectiveTargetSampleSize;
  final double effectModifierMeanTarget;
  final double effectModifierMeanTrial;
  final double effectModifierMeanWeightedTrial;
  final double maximumSmdBeforeWeighting;
  final double maximumSmdAfterWeighting;
  final int influentialRecordCount;

  TargetOverlapDiagnostic({
    required this.trialCount,
    required this.targetCount,
    required List<String> supportViolationStrata,
    required List<String> unknownTargetCovariates,
    required List<String> excludedTargetStrata,
    required this.minimumSamplingScore,
    required this.maximumSamplingScore,
    required this.minimumInverseOddsWeight,
    required this.maximumInverseOddsWeight,
    required this.p99InverseOddsWeight,
    required this.effectiveTargetSampleSize,
    required this.effectModifierMeanTarget,
    required this.effectModifierMeanTrial,
    required this.effectModifierMeanWeightedTrial,
    required this.maximumSmdBeforeWeighting,
    required this.maximumSmdAfterWeighting,
    required this.influentialRecordCount,
  }) : supportViolationStrata = List.unmodifiable(supportViolationStrata),
       unknownTargetCovariates = List.unmodifiable(unknownTargetCovariates),
       excludedTargetStrata = List.unmodifiable(excludedTargetStrata);

  TargetOverlapDiagnostic copyWith({
    List<String>? supportViolationStrata,
    List<String>? unknownTargetCovariates,
    List<String>? excludedTargetStrata,
    double? maximumInverseOddsWeight,
    double? effectiveTargetSampleSize,
    double? maximumSmdAfterWeighting,
  }) => TargetOverlapDiagnostic(
    trialCount: trialCount,
    targetCount: targetCount,
    supportViolationStrata:
        supportViolationStrata ?? this.supportViolationStrata,
    unknownTargetCovariates:
        unknownTargetCovariates ?? this.unknownTargetCovariates,
    excludedTargetStrata: excludedTargetStrata ?? this.excludedTargetStrata,
    minimumSamplingScore: minimumSamplingScore,
    maximumSamplingScore: maximumSamplingScore,
    minimumInverseOddsWeight: minimumInverseOddsWeight,
    maximumInverseOddsWeight:
        maximumInverseOddsWeight ?? this.maximumInverseOddsWeight,
    p99InverseOddsWeight: p99InverseOddsWeight,
    effectiveTargetSampleSize:
        effectiveTargetSampleSize ?? this.effectiveTargetSampleSize,
    effectModifierMeanTarget: effectModifierMeanTarget,
    effectModifierMeanTrial: effectModifierMeanTrial,
    effectModifierMeanWeightedTrial: effectModifierMeanWeightedTrial,
    maximumSmdBeforeWeighting: maximumSmdBeforeWeighting,
    maximumSmdAfterWeighting:
        maximumSmdAfterWeighting ?? this.maximumSmdAfterWeighting,
    influentialRecordCount: influentialRecordCount,
  );

  Map<String, Object?> toJson() => {
    'trial_count': trialCount,
    'target_count': targetCount,
    'support_violation_strata': supportViolationStrata,
    'unknown_target_covariates': unknownTargetCovariates,
    'excluded_target_strata': excludedTargetStrata,
    'minimum_sampling_score': minimumSamplingScore,
    'maximum_sampling_score': maximumSamplingScore,
    'minimum_inverse_odds_weight': minimumInverseOddsWeight,
    'maximum_inverse_odds_weight': maximumInverseOddsWeight,
    'p99_inverse_odds_weight': p99InverseOddsWeight,
    'effective_target_sample_size': effectiveTargetSampleSize,
    'effect_modifier_mean_target': effectModifierMeanTarget,
    'effect_modifier_mean_trial': effectModifierMeanTrial,
    'effect_modifier_mean_weighted_trial': effectModifierMeanWeightedTrial,
    'maximum_smd_before_weighting': maximumSmdBeforeWeighting,
    'maximum_smd_after_weighting': maximumSmdAfterWeighting,
    'influential_record_count': influentialRecordCount,
  };
}

final class TransportWeightSensitivity {
  final double? truncationCap;
  final double estimate;
  final double effectiveSampleSize;
  final double maximumWeight;

  const TransportWeightSensitivity({
    required this.truncationCap,
    required this.estimate,
    required this.effectiveSampleSize,
    required this.maximumWeight,
  });

  Map<String, Object?> toJson() => {
    'truncation_cap': truncationCap,
    'estimate': estimate,
    'effective_sample_size': effectiveSampleSize,
    'maximum_weight': maximumWeight,
  };
}

final class TransportEstimatorEstimate {
  final String caseId;
  final TransportEstimatorKind estimator;
  final TransportModelSpecification samplingModel;
  final TransportModelSpecification outcomeModel;
  final double estimate;
  final double standardError;
  final double lower95;
  final double upper95;

  const TransportEstimatorEstimate({
    required this.caseId,
    required this.estimator,
    required this.samplingModel,
    required this.outcomeModel,
    required this.estimate,
    required this.standardError,
    required this.lower95,
    required this.upper95,
  });

  TransportEstimatorEstimate copyWith({double? estimate}) =>
      TransportEstimatorEstimate(
        caseId: caseId,
        estimator: estimator,
        samplingModel: samplingModel,
        outcomeModel: outcomeModel,
        estimate: estimate ?? this.estimate,
        standardError: standardError,
        lower95: lower95,
        upper95: upper95,
      );

  Map<String, Object?> toJson() => {
    'case_id': caseId,
    'estimator': estimator.name,
    'sampling_model': samplingModel.name,
    'outcome_model': outcomeModel.name,
    'estimate': estimate,
    'standard_error': standardError,
    'lower_95': lower95,
    'upper_95': upper95,
  };
}

final class TargetTransportScenario {
  final String scenarioId;
  final TransportScenarioFamily family;
  final int repetitions;
  final bool samplingModelCorrect;
  final bool outcomeModelCorrect;
  final double treatmentProbability;
  final double censoringRate;
  final bool censoringModelCorrect;
  final bool supportSatisfied;
  final double trueTargetEffect;
  final String limitation;

  const TargetTransportScenario({
    required this.scenarioId,
    required this.family,
    required this.repetitions,
    required this.samplingModelCorrect,
    required this.outcomeModelCorrect,
    required this.treatmentProbability,
    required this.censoringRate,
    required this.censoringModelCorrect,
    required this.supportSatisfied,
    required this.trueTargetEffect,
    required this.limitation,
  });

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'family': family.name,
    'repetitions': repetitions,
    'sampling_model_correct': samplingModelCorrect,
    'outcome_model_correct': outcomeModelCorrect,
    'treatment_probability': treatmentProbability,
    'censoring_rate': censoringRate,
    'censoring_model_correct': censoringModelCorrect,
    'support_satisfied': supportSatisfied,
    'true_target_effect': trueTargetEffect,
    'limitation': limitation,
  };
}

final class TargetTransportOperatingResult {
  final String scenarioId;
  final TransportEstimatorKind estimator;
  final TransportOperatingStatus status;
  final int repetitions;
  final double? meanEstimate;
  final double? bias;
  final double? empiricalVariance;
  final double? coverage95;
  final double? positiveDecisionProbability;
  final double? monteCarloStandardError;
  final String disposition;

  const TargetTransportOperatingResult({
    required this.scenarioId,
    required this.estimator,
    required this.status,
    required this.repetitions,
    required this.meanEstimate,
    required this.bias,
    required this.empiricalVariance,
    required this.coverage95,
    required this.positiveDecisionProbability,
    required this.monteCarloStandardError,
    required this.disposition,
  });

  TargetTransportOperatingResult copyWith({
    TransportOperatingStatus? status,
    double? meanEstimate,
    double? bias,
    double? coverage95,
  }) => TargetTransportOperatingResult(
    scenarioId: scenarioId,
    estimator: estimator,
    status: status ?? this.status,
    repetitions: repetitions,
    meanEstimate: meanEstimate ?? this.meanEstimate,
    bias: bias ?? this.bias,
    empiricalVariance: empiricalVariance,
    coverage95: coverage95 ?? this.coverage95,
    positiveDecisionProbability: positiveDecisionProbability,
    monteCarloStandardError: monteCarloStandardError,
    disposition: disposition,
  );

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'estimator': estimator.name,
    'status': status.name,
    'repetitions': repetitions,
    'mean_estimate': meanEstimate,
    'bias': bias,
    'empirical_variance': empiricalVariance,
    'coverage_95': coverage95,
    'positive_decision_probability': positiveDecisionProbability,
    'monte_carlo_standard_error': monteCarloStandardError,
    'disposition': disposition,
  };
}

final class TargetTransportIndependentReplication {
  final String language;
  final String dependencyLock;
  final String scriptPath;
  final String scriptSha256;
  final Map<String, Map<String, double>> cases;
  final double tolerance;
  final bool importsProductionCode;
  final bool importsGoldenOutputs;

  TargetTransportIndependentReplication({
    required this.language,
    required this.dependencyLock,
    required this.scriptPath,
    required this.scriptSha256,
    required Map<String, Map<String, double>> cases,
    required this.tolerance,
    required this.importsProductionCode,
    required this.importsGoldenOutputs,
  }) : cases = Map.unmodifiable({
         for (final entry in cases.entries)
           entry.key: Map<String, double>.unmodifiable(entry.value),
       });

  TargetTransportIndependentReplication copyWith({
    String? scriptSha256,
    Map<String, Map<String, double>>? cases,
    bool? importsProductionCode,
  }) => TargetTransportIndependentReplication(
    language: language,
    dependencyLock: dependencyLock,
    scriptPath: scriptPath,
    scriptSha256: scriptSha256 ?? this.scriptSha256,
    cases: cases ?? this.cases,
    tolerance: tolerance,
    importsProductionCode: importsProductionCode ?? this.importsProductionCode,
    importsGoldenOutputs: importsGoldenOutputs,
  );

  Map<String, Object?> toJson() => {
    'language': language,
    'dependency_lock': dependencyLock,
    'script_path': scriptPath,
    'script_sha256': scriptSha256,
    'cases': {
      for (final caseId in cases.keys.toList()..sort())
        caseId: {
          for (final estimator in cases[caseId]!.keys.toList()..sort())
            estimator: cases[caseId]![estimator],
        },
    },
    'tolerance': tolerance,
    'imports_production_code': importsProductionCode,
    'imports_golden_outputs': importsGoldenOutputs,
  };
}

final class CredibilityTargetPopulationTransportabilityPackage {
  static const String schema =
      'parkinsum.credibility-target-population-transportability-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v3';

  final int schemaVersion;
  final String packageId;
  final CredibilityBayesianMultisourceModelCriticismPackage multisourcePackage;
  final String multisourcePackageSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final TargetPopulationTransportabilityContract contract;
  final List<SyntheticTransportRecord> records;
  final TargetOverlapDiagnostic overlapDiagnostic;
  final List<TransportWeightSensitivity> truncationSensitivity;
  final List<TransportEstimatorEstimate> estimatorEstimates;
  final List<TargetTransportScenario> scenarios;
  final List<TargetTransportOperatingResult> operatingResults;
  final TargetTransportIndependentReplication independentReplication;
  final bool allPrespecifiedResultsRetained;
  final String analysisStartedAtUtc;
  final String analysisCompletedAtUtc;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityTargetPopulationTransportabilityPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.multisourcePackage,
    required this.multisourcePackageSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.contract,
    required List<SyntheticTransportRecord> records,
    required this.overlapDiagnostic,
    required List<TransportWeightSensitivity> truncationSensitivity,
    required List<TransportEstimatorEstimate> estimatorEstimates,
    required List<TargetTransportScenario> scenarios,
    required List<TargetTransportOperatingResult> operatingResults,
    required this.independentReplication,
    required this.allPrespecifiedResultsRetained,
    required this.analysisStartedAtUtc,
    required this.analysisCompletedAtUtc,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : records = List.unmodifiable(records),
       truncationSensitivity = List.unmodifiable(truncationSensitivity),
       estimatorEstimates = List.unmodifiable(estimatorEstimates),
       scenarios = List.unmodifiable(scenarios),
       operatingResults = List.unmodifiable(operatingResults);

  CredibilityTargetPopulationTransportabilityPackage copyWith({
    int? schemaVersion,
    String? multisourcePackageSha256,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    TargetPopulationTransportabilityContract? contract,
    List<SyntheticTransportRecord>? records,
    TargetOverlapDiagnostic? overlapDiagnostic,
    List<TransportWeightSensitivity>? truncationSensitivity,
    List<TransportEstimatorEstimate>? estimatorEstimates,
    List<TargetTransportScenario>? scenarios,
    List<TargetTransportOperatingResult>? operatingResults,
    TargetTransportIndependentReplication? independentReplication,
    bool? allPrespecifiedResultsRetained,
    String? analysisStartedAtUtc,
    String? analysisCompletedAtUtc,
    bool? revoked,
    bool? syntheticDemoOnly,
    String? boundary,
  }) => CredibilityTargetPopulationTransportabilityPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    multisourcePackage: multisourcePackage,
    multisourcePackageSha256:
        multisourcePackageSha256 ?? this.multisourcePackageSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    contract: contract ?? this.contract,
    records: records ?? this.records,
    overlapDiagnostic: overlapDiagnostic ?? this.overlapDiagnostic,
    truncationSensitivity: truncationSensitivity ?? this.truncationSensitivity,
    estimatorEstimates: estimatorEstimates ?? this.estimatorEstimates,
    scenarios: scenarios ?? this.scenarios,
    operatingResults: operatingResults ?? this.operatingResults,
    independentReplication:
        independentReplication ?? this.independentReplication,
    allPrespecifiedResultsRetained:
        allPrespecifiedResultsRetained ?? this.allPrespecifiedResultsRetained,
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
    'multisource_package_sha256': multisourcePackageSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'contract': contract.toJson(),
    'records': records.map((record) => record.toJson()).toList(),
    'overlap_diagnostic': overlapDiagnostic.toJson(),
    'truncation_sensitivity': truncationSensitivity
        .map((item) => item.toJson())
        .toList(),
    'estimator_estimates': estimatorEstimates
        .map((estimate) => estimate.toJson())
        .toList(),
    'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
    'operating_results': operatingResults
        .map((result) => result.toJson())
        .toList(),
    'independent_replication': independentReplication.toJson(),
    'all_prespecified_results_retained': allPrespecifiedResultsRetained,
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

final class TargetTransportabilityFinding {
  final TargetTransportabilityFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  TargetTransportabilityFinding({
    required this.kind,
    required this.detail,
    required List<String> affectedIds,
  }) : affectedIds = List.unmodifiable(affectedIds);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'detail': detail,
    'affected_ids': affectedIds,
  };
}

final class TargetTransportabilityAssessment {
  final CredibilityTargetPopulationTransportabilityPackage package;
  final TargetTransportabilityStatus status;
  final List<TargetTransportabilityFinding> findings;
  final Map<String, String> lanes;
  final Map<String, int> counts;

  TargetTransportabilityAssessment({
    required this.package,
    required this.status,
    required List<TargetTransportabilityFinding> findings,
    required Map<String, String> lanes,
    required Map<String, int> counts,
  }) : findings = List.unmodifiable(findings),
       lanes = Map.unmodifiable(lanes),
       counts = Map.unmodifiable(counts);

  Map<String, Object?> toJson() => {
    'status': status.name,
    'findings': findings.map((finding) => finding.toJson()).toList(),
    'lanes': lanes,
    'counts': counts,
    'package': package.toJson(),
  };
}

final class CredibilityTargetPopulationTransportabilityVerifier {
  const CredibilityTargetPopulationTransportabilityVerifier();

  static const String expectedIndependentScriptSha256 =
      'c71d6ac79dccba1310901af8a892d06467f7733878437c31402a0fda73419baf';

  static const Set<String> _requiredAssumptions = {
    'consistency',
    'no_interference',
    'trial_exchangeability',
    'treatment_positivity',
    'conditional_transportability',
    'selection_positivity',
    'measurement_alignment',
  };

  static const Map<String, Map<String, double>> _expectedCases = {
    'both_models_correct': {
      'truth': 0.18,
      'trial_only': 0.14,
      'outcome_regression': 0.18,
      'inverse_odds_sampling': 0.18,
      'augmented_inverse_odds': 0.18,
    },
    'sampling_model_misspecified': {
      'truth': 0.18,
      'trial_only': 0.14,
      'outcome_regression': 0.18,
      'inverse_odds_sampling': 0.14,
      'augmented_inverse_odds': 0.18,
    },
    'outcome_model_misspecified': {
      'truth': 0.18,
      'trial_only': 0.14,
      'outcome_regression': 0.14,
      'inverse_odds_sampling': 0.18,
      'augmented_inverse_odds': 0.18,
    },
    'both_models_misspecified': {
      'truth': 0.18,
      'trial_only': 0.14,
      'outcome_regression': 0.14,
      'inverse_odds_sampling': 0.14,
      'augmented_inverse_odds': 0.14,
    },
  };

  TargetTransportabilityAssessment verify(
    CredibilityTargetPopulationTransportabilityPackage package,
  ) {
    final findings = <TargetTransportabilityFinding>[];
    void add(
      TargetTransportabilityFindingKind kind,
      String detail, [
      Iterable<String> ids = const [],
    ]) => findings.add(
      TargetTransportabilityFinding(
        kind: kind,
        detail: detail,
        affectedIds: ids.toList(),
      ),
    );

    if (package.schemaVersion !=
        CredibilityTargetPopulationTransportabilityPackage
            .currentSchemaVersion) {
      add(
        TargetTransportabilityFindingKind.futureSchema,
        'Only the current target-transportability schema is accepted.',
      );
    }
    if (package.multisourcePackageSha256 !=
            package.multisourcePackage.packageSha256 ||
        package.multisourcePackageSha256.isEmpty) {
      add(
        TargetTransportabilityFindingKind.upstreamIdentity,
        'The exact upstream multi-source package identity is required.',
      );
    }
    if (package.configurationSha256 !=
            package.multisourcePackage.configurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            package.multisourcePackage.algorithmSourceBundleSha256 ||
        !_isSha256(package.configurationSha256) ||
        !_isSha256(package.algorithmSourceBundleSha256)) {
      add(
        TargetTransportabilityFindingKind.runtimeIdentity,
        'Configuration and source-bundle identities must match upstream.',
      );
    }
    _verifyContract(package, add);
    _verifyRecords(package, add);
    _verifyOverlap(package, add);
    _verifyEstimators(package, add);
    _verifyScenarios(package, add);
    _verifyIndependent(package, add);
    if (!package.allPrespecifiedResultsRetained) {
      add(
        TargetTransportabilityFindingKind.resultRetention,
        'Every prespecified estimator and scenario result must be retained.',
      );
    }
    if (!package.syntheticDemoOnly ||
        !package.boundary.toLowerCase().contains('synthetic') ||
        !package.boundary.toLowerCase().contains('cannot establish') ||
        !package.boundary.toLowerCase().contains('causal transportability')) {
      add(
        TargetTransportabilityFindingKind.boundaryOverclaim,
        'The synthetic non-clinical causal boundary must remain explicit.',
      );
    }
    if (package.revoked) {
      add(
        TargetTransportabilityFindingKind.revoked,
        'A revoked package cannot remain mechanically observed.',
      );
    }

    final uniqueFindings = <String, TargetTransportabilityFinding>{};
    for (final finding in findings) {
      uniqueFindings['${finding.kind.name}:${finding.detail}:${finding.affectedIds.join(',')}'] =
          finding;
    }
    final retained = uniqueFindings.values.toList();
    final status = package.revoked
        ? TargetTransportabilityStatus.revoked
        : retained.isEmpty
        ? TargetTransportabilityStatus.mechanicallyObserved
        : TargetTransportabilityStatus.held;
    final laneValue = retained.isEmpty ? 'mechanicallyObserved' : 'held';
    final heldKinds = retained.map((finding) => finding.kind).toSet();
    String lane(Set<TargetTransportabilityFindingKind> kinds) =>
        heldKinds.intersection(kinds).isEmpty ? laneValue : 'held';

    return TargetTransportabilityAssessment(
      package: package,
      status: status,
      findings: retained,
      lanes: {
        'identification': lane({
          TargetTransportabilityFindingKind.contractIncomplete,
          TargetTransportabilityFindingKind.causalGraphIncomplete,
          TargetTransportabilityFindingKind.assumptionIncomplete,
          TargetTransportabilityFindingKind.chronology,
        }),
        'overlap': lane({
          TargetTransportabilityFindingKind.overlapMismatch,
          TargetTransportabilityFindingKind.supportViolationLaundered,
          TargetTransportabilityFindingKind.unknownCovariateLaundered,
        }),
        'weighting': lane({
          TargetTransportabilityFindingKind.weightMismatch,
          TargetTransportabilityFindingKind.balanceMismatch,
        }),
        'outcomeModeling': lane({
          TargetTransportabilityFindingKind.estimatorCatalog,
          TargetTransportabilityFindingKind.estimatorArithmetic,
        }),
        'estimatorAgreement': lane({
          TargetTransportabilityFindingKind.doubleRobustness,
        }),
        'sensitivity': lane({
          TargetTransportabilityFindingKind.sensitivityIncomplete,
          TargetTransportabilityFindingKind.nonidentifiableEstimated,
        }),
        'operatingCharacteristics': lane({
          TargetTransportabilityFindingKind.scenarioCatalog,
          TargetTransportabilityFindingKind.operatingArithmetic,
          TargetTransportabilityFindingKind.operatingCalibration,
        }),
        'independentReplication': lane({
          TargetTransportabilityFindingKind.independentReplication,
        }),
        'unresolvedLimitations': package.syntheticDemoOnly
            ? 'explicitlyHeld'
            : 'held',
      },
      counts: {
        'trialRecords': package.records
            .where((record) => record.role == TargetSampleRole.randomizedTrial)
            .length,
        'targetRecords': package.records
            .where((record) => record.role == TargetSampleRole.targetPopulation)
            .length,
        'assumptions': package.contract.assumptions.length,
        'estimators': TransportEstimatorKind.values.length,
        'manufacturedCases': _expectedCases.length,
        'scenarios': package.scenarios.length,
        'totalRepetitions': package.scenarios.fold(
          0,
          (sum, scenario) => sum + scenario.repetitions,
        ),
        'supportViolations':
            package.overlapDiagnostic.supportViolationStrata.length,
        'independentCases': package.independentReplication.cases.length,
      },
    );
  }

  void _verifyContract(
    CredibilityTargetPopulationTransportabilityPackage package,
    void Function(TargetTransportabilityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final contract = package.contract;
    final requiredText = [
      contract.contractId,
      contract.targetPopulationId,
      contract.targetEligibility,
      contract.trialEligibility,
      contract.causalContrast,
      contract.treatmentId,
      contract.comparatorId,
      contract.outcomeId,
      contract.followUpWindow,
      contract.censoringStrategy,
      contract.samplingMechanism,
      contract.outcomeModelId,
      contract.samplingModelId,
    ];
    if (requiredText.any((value) => value.trim().isEmpty) ||
        contract.treatmentVersions.isEmpty ||
        contract.targetCovariates.isEmpty ||
        contract.effectModifiers.isEmpty ||
        !_isSha256(contract.estimatorCodeSha256)) {
      add(
        TargetTransportabilityFindingKind.contractIncomplete,
        'The target, causal contrast, intervention, outcome and model contract must be complete.',
      );
    }
    final nodes = contract.graphNodes.toSet();
    if (!nodes.containsAll({'S', 'X', 'A', 'Y'}) ||
        contract.graphEdges.isEmpty ||
        contract.graphEdges.any(
          (edge) =>
              !nodes.contains(edge.from) ||
              !nodes.contains(edge.to) ||
              edge.rationale.trim().isEmpty,
        )) {
      add(
        TargetTransportabilityFindingKind.causalGraphIncomplete,
        'The causal graph must bind selection, covariates, treatment and outcome.',
      );
    }
    final assumptionIds = contract.assumptions
        .map((assumption) => assumption.id)
        .toSet();
    if (!assumptionIds.containsAll(_requiredAssumptions) ||
        contract.assumptions.any(
          (assumption) =>
              assumption.statement.trim().isEmpty ||
              assumption.observableDiagnostic.trim().isEmpty ||
              assumption.failureDisposition != 'hold',
        )) {
      add(
        TargetTransportabilityFindingKind.assumptionIncomplete,
        'All seven identification assumptions require diagnostics and hold dispositions.',
      );
    }
    final authored = DateTime.tryParse(contract.authoredAtUtc);
    final frozen = DateTime.tryParse(contract.targetSampleFrozenAtUtc);
    final visible = DateTime.tryParse(contract.firstOutcomeVisibleAtUtc);
    final started = DateTime.tryParse(package.analysisStartedAtUtc);
    final completed = DateTime.tryParse(package.analysisCompletedAtUtc);
    if (authored == null ||
        frozen == null ||
        visible == null ||
        started == null ||
        completed == null ||
        authored.isAfter(frozen) ||
        frozen.isAfter(visible) ||
        visible.isAfter(started) ||
        started.isAfter(completed)) {
      add(
        TargetTransportabilityFindingKind.chronology,
        'Contract, target freeze, first outcome visibility and analysis order must be prospective.',
      );
    }
  }

  void _verifyRecords(
    CredibilityTargetPopulationTransportabilityPackage package,
    void Function(TargetTransportabilityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final ids = <String>{};
    final duplicates = <String>[];
    for (final record in package.records) {
      if (record.recordId.trim().isEmpty || !ids.add(record.recordId)) {
        duplicates.add(record.recordId);
      }
      if (!record.synthetic) {
        add(
          TargetTransportabilityFindingKind.nonsyntheticRecord,
          'This package may contain synthetic records only.',
          [record.recordId],
        );
      }
      final missing = package.contract.targetCovariates
          .where((key) => !record.covariates.containsKey(key))
          .toList();
      if (missing.isNotEmpty) {
        add(
          TargetTransportabilityFindingKind.covariateIncomplete,
          'Every record must retain the full target covariate contract.',
          [record.recordId, ...missing],
        );
      }
      if (record.role == TargetSampleRole.targetPopulation &&
          (record.treatment != null ||
              record.outcome != null ||
              record.treatmentProbability != null ||
              record.outcomeObserved)) {
        add(
          TargetTransportabilityFindingKind.targetOutcomeLeakage,
          'Target records must not expose treatment or outcome data.',
          [record.recordId],
        );
      }
      if (record.role == TargetSampleRole.randomizedTrial &&
          (record.treatment == null ||
              record.outcome == null ||
              record.treatmentProbability == null ||
              !record.outcomeObserved)) {
        add(
          TargetTransportabilityFindingKind.trialRecordIncomplete,
          'Trial records require randomized treatment and observed synthetic outcome.',
          [record.recordId],
        );
      }
    }
    if (duplicates.isNotEmpty) {
      add(
        TargetTransportabilityFindingKind.recordIdentity,
        'Record identities must be unique and nonempty.',
        duplicates,
      );
    }
    if (!package.records.any(
          (record) => record.role == TargetSampleRole.randomizedTrial,
        ) ||
        !package.records.any(
          (record) => record.role == TargetSampleRole.targetPopulation,
        )) {
      add(
        TargetTransportabilityFindingKind.recordIdentity,
        'Both trial and target records are required.',
      );
    }
  }

  void _verifyOverlap(
    CredibilityTargetPopulationTransportabilityPackage package,
    void Function(TargetTransportabilityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final diagnostic = package.overlapDiagnostic;
    final trialCount = package.records
        .where((record) => record.role == TargetSampleRole.randomizedTrial)
        .length;
    final targetCount = package.records
        .where((record) => record.role == TargetSampleRole.targetPopulation)
        .length;
    if (diagnostic.trialCount != trialCount ||
        diagnostic.targetCount != targetCount ||
        diagnostic.minimumSamplingScore <= 0 ||
        diagnostic.maximumSamplingScore >= 1 ||
        diagnostic.minimumSamplingScore >= diagnostic.maximumSamplingScore) {
      add(
        TargetTransportabilityFindingKind.overlapMismatch,
        'Overlap counts and sampling-score support must match the records.',
      );
    }
    if (diagnostic.supportViolationStrata.isNotEmpty ||
        diagnostic.excludedTargetStrata.isNotEmpty) {
      add(
        TargetTransportabilityFindingKind.supportViolationLaundered,
        'The reference package cannot estimate through structural non-overlap.',
        diagnostic.supportViolationStrata,
      );
    }
    if (diagnostic.unknownTargetCovariates.isNotEmpty) {
      add(
        TargetTransportabilityFindingKind.unknownCovariateLaundered,
        'Unknown target covariates must hold estimation.',
        diagnostic.unknownTargetCovariates,
      );
    }
    if (diagnostic.maximumInverseOddsWeight >
            package.contract.maximumAcceptedWeight + 1e-12 ||
        diagnostic.minimumInverseOddsWeight <= 0 ||
        diagnostic.p99InverseOddsWeight >
            diagnostic.maximumInverseOddsWeight + 1e-12 ||
        diagnostic.effectiveTargetSampleSize <= 0 ||
        diagnostic.effectiveTargetSampleSize > diagnostic.trialCount) {
      add(
        TargetTransportabilityFindingKind.weightMismatch,
        'Weight bounds, tail summary and effective sample size must remain coherent.',
      );
    }
    if (diagnostic.maximumSmdAfterWeighting >
            package.contract.maximumAcceptedWeightedSmd + 1e-12 ||
        diagnostic.maximumSmdAfterWeighting >
            diagnostic.maximumSmdBeforeWeighting + 1e-12 ||
        (diagnostic.effectModifierMeanTarget -
                    diagnostic.effectModifierMeanWeightedTrial)
                .abs() >
            1e-10) {
      add(
        TargetTransportabilityFindingKind.balanceMismatch,
        'Weighted effect-modifier balance must match the target within tolerance.',
      );
    }
  }

  void _verifyEstimators(
    CredibilityTargetPopulationTransportabilityPackage package,
    void Function(TargetTransportabilityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final byCase = <String, Map<TransportEstimatorKind, double>>{};
    for (final estimate in package.estimatorEstimates) {
      byCase.putIfAbsent(estimate.caseId, () => {})[estimate.estimator] =
          estimate.estimate;
      if (!_finite(estimate.estimate) ||
          !_finite(estimate.standardError) ||
          estimate.standardError <= 0 ||
          estimate.lower95 > estimate.estimate ||
          estimate.upper95 < estimate.estimate) {
        add(
          TargetTransportabilityFindingKind.estimatorArithmetic,
          'Estimator values and intervals must be finite and ordered.',
          [estimate.caseId, estimate.estimator.name],
        );
      }
    }
    for (final caseEntry in _expectedCases.entries) {
      final observed = byCase[caseEntry.key];
      if (observed == null ||
          !TransportEstimatorKind.values.every(observed.containsKey)) {
        add(
          TargetTransportabilityFindingKind.estimatorCatalog,
          'Every manufactured case requires all four estimators.',
          [caseEntry.key],
        );
        continue;
      }
      for (final estimator in TransportEstimatorKind.values) {
        final expected = caseEntry.value[_oracleKey(estimator)]!;
        if ((observed[estimator]! - expected).abs() > 1e-10) {
          add(
            TargetTransportabilityFindingKind.estimatorArithmetic,
            'Manufactured estimator output drifted from the frozen calculation.',
            [caseEntry.key, estimator.name],
          );
        }
      }
    }
    final samplingMiss = byCase['sampling_model_misspecified'];
    final outcomeMiss = byCase['outcome_model_misspecified'];
    final dualMiss = byCase['both_models_misspecified'];
    if (samplingMiss == null ||
        outcomeMiss == null ||
        dualMiss == null ||
        (samplingMiss[TransportEstimatorKind.augmentedInverseOdds]! - 0.18)
                .abs() >
            1e-10 ||
        (outcomeMiss[TransportEstimatorKind.augmentedInverseOdds]! - 0.18)
                .abs() >
            1e-10 ||
        (dualMiss[TransportEstimatorKind.augmentedInverseOdds]! - 0.14).abs() >
            1e-10) {
      add(
        TargetTransportabilityFindingKind.doubleRobustness,
        'The augmented estimator must retain one-model robustness but fail under dual misspecification.',
      );
    }
    if (package.truncationSensitivity.length < 4 ||
        !package.truncationSensitivity.any(
          (item) => item.truncationCap == null,
        ) ||
        package.truncationSensitivity.any(
          (item) =>
              !_finite(item.estimate) ||
              item.effectiveSampleSize <= 0 ||
              item.maximumWeight <= 0 ||
              (item.truncationCap != null &&
                  item.maximumWeight > item.truncationCap! + 1e-12),
        )) {
      add(
        TargetTransportabilityFindingKind.sensitivityIncomplete,
        'Untruncated and at least three truncated weight analyses are required.',
      );
    }
  }

  void _verifyScenarios(
    CredibilityTargetPopulationTransportabilityPackage package,
    void Function(TargetTransportabilityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final families = package.scenarios
        .map((scenario) => scenario.family)
        .toSet();
    if (!families.containsAll(TransportScenarioFamily.values) ||
        package.scenarios
                .map((scenario) => scenario.scenarioId)
                .toSet()
                .length !=
            package.scenarios.length ||
        package.scenarios.any(
          (scenario) =>
              scenario.repetitions < 1000 ||
              scenario.limitation.trim().isEmpty ||
              !_finite(scenario.trueTargetEffect),
        )) {
      add(
        TargetTransportabilityFindingKind.scenarioCatalog,
        'All seven unique scenario families and limitations are required.',
      );
    }
    final scenarioById = {
      for (final scenario in package.scenarios) scenario.scenarioId: scenario,
    };
    final resultKeys = <String>{};
    for (final result in package.operatingResults) {
      final scenario = scenarioById[result.scenarioId];
      final key = '${result.scenarioId}:${result.estimator.name}';
      if (!resultKeys.add(key) || scenario == null) {
        add(
          TargetTransportabilityFindingKind.scenarioCatalog,
          'Operating results must map uniquely to a declared scenario.',
          [key],
        );
        continue;
      }
      if (!scenario.supportSatisfied) {
        if (result.status != TransportOperatingStatus.heldNonidentifiable ||
            result.meanEstimate != null ||
            result.bias != null ||
            result.coverage95 != null) {
          add(
            TargetTransportabilityFindingKind.nonidentifiableEstimated,
            'Support violations must be held without an effect estimate.',
            [key],
          );
        }
        continue;
      }
      if (result.status != TransportOperatingStatus.estimated ||
          result.repetitions != scenario.repetitions ||
          result.meanEstimate == null ||
          result.bias == null ||
          result.empiricalVariance == null ||
          result.coverage95 == null ||
          result.positiveDecisionProbability == null ||
          result.monteCarloStandardError == null ||
          [
            result.meanEstimate!,
            result.bias!,
            result.empiricalVariance!,
            result.coverage95!,
            result.positiveDecisionProbability!,
            result.monteCarloStandardError!,
          ].any((value) => !_finite(value)) ||
          (result.bias! - (result.meanEstimate! - scenario.trueTargetEffect))
                  .abs() >
              1e-9 ||
          result.empiricalVariance! < 0 ||
          result.coverage95! < 0 ||
          result.coverage95! > 1 ||
          result.positiveDecisionProbability! < 0 ||
          result.positiveDecisionProbability! > 1 ||
          result.monteCarloStandardError! < 0) {
        add(
          TargetTransportabilityFindingKind.operatingArithmetic,
          'Operating characteristics must be complete, finite and arithmetically coherent.',
          [key],
        );
      }
    }
    final expectedResultCount =
        package.scenarios.length * TransportEstimatorKind.values.length;
    if (package.operatingResults.length != expectedResultCount ||
        resultKeys.length != expectedResultCount) {
      add(
        TargetTransportabilityFindingKind.scenarioCatalog,
        'Every scenario requires every estimator, including held results.',
      );
    }
    final byScenario =
        <
          TransportScenarioFamily,
          Map<TransportEstimatorKind, TargetTransportOperatingResult>
        >{};
    for (final scenario in package.scenarios) {
      byScenario[scenario.family] = {
        for (final result in package.operatingResults.where(
          (result) => result.scenarioId == scenario.scenarioId,
        ))
          result.estimator: result,
      };
    }
    final correct = byScenario[TransportScenarioFamily.correctModels];
    final samplingMiss =
        byScenario[TransportScenarioFamily.samplingModelMisspecified];
    final outcomeMiss =
        byScenario[TransportScenarioFamily.outcomeModelMisspecified];
    final dual = byScenario[TransportScenarioFamily.dualMisspecification];
    if (correct == null ||
        samplingMiss == null ||
        outcomeMiss == null ||
        dual == null ||
        correct[TransportEstimatorKind.augmentedInverseOdds]!.bias!.abs() >
            0.01 ||
        samplingMiss[TransportEstimatorKind.augmentedInverseOdds]!.bias!.abs() >
            0.01 ||
        outcomeMiss[TransportEstimatorKind.augmentedInverseOdds]!.bias!.abs() >
            0.01 ||
        dual[TransportEstimatorKind.augmentedInverseOdds]!.bias!.abs() < 0.02) {
      add(
        TargetTransportabilityFindingKind.operatingCalibration,
        'Scenario results must exhibit the frozen one-model robustness boundary.',
      );
    }
  }

  void _verifyIndependent(
    CredibilityTargetPopulationTransportabilityPackage package,
    void Function(TargetTransportabilityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final independent = package.independentReplication;
    if (independent.language != 'Python' ||
        independent.dependencyLock != 'python-stdlib-only' ||
        independent.scriptPath !=
            'tool/independent_target_transportability_oracle.py' ||
        independent.scriptSha256 != expectedIndependentScriptSha256 ||
        independent.scriptSha256 != package.contract.independentScriptSha256 ||
        independent.importsProductionCode ||
        independent.importsGoldenOutputs ||
        independent.tolerance <= 0 ||
        independent.cases.keys
            .toSet()
            .difference(_expectedCases.keys.toSet())
            .isNotEmpty ||
        _expectedCases.keys
            .toSet()
            .difference(independent.cases.keys.toSet())
            .isNotEmpty) {
      add(
        TargetTransportabilityFindingKind.independentReplication,
        'The exact stdlib-only independent Python oracle is required.',
      );
      return;
    }
    for (final caseEntry in _expectedCases.entries) {
      final observed = independent.cases[caseEntry.key];
      if (observed == null ||
          observed.keys
              .toSet()
              .difference(caseEntry.value.keys.toSet())
              .isNotEmpty ||
          caseEntry.value.entries.any(
            (entry) =>
                !observed.containsKey(entry.key) ||
                (observed[entry.key]! - entry.value).abs() >
                    independent.tolerance,
          )) {
        add(
          TargetTransportabilityFindingKind.independentReplication,
          'Independent manufactured values drifted.',
          [caseEntry.key],
        );
      }
    }
  }

  static String _oracleKey(TransportEstimatorKind estimator) =>
      switch (estimator) {
        TransportEstimatorKind.trialOnly => 'trial_only',
        TransportEstimatorKind.outcomeRegression => 'outcome_regression',
        TransportEstimatorKind.inverseOddsSampling => 'inverse_odds_sampling',
        TransportEstimatorKind.augmentedInverseOdds => 'augmented_inverse_odds',
      };
}

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList();
  }
  if (value is double) {
    if (!value.isFinite) {
      return value.toString();
    }
    if (value == 0) return 0.0;
    return value;
  }
  return value;
}

bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

bool _finite(double value) => value.isFinite && !value.isNaN;

double normalCdf(double value) => 0.5 * (1 + _erf(value / math.sqrt(2)));

double _erf(double value) {
  final sign = value < 0 ? -1.0 : 1.0;
  final x = value.abs();
  const p = 0.3275911;
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  final t = 1 / (1 + p * x);
  final polynomial = (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t;
  return sign * (1 - polynomial * math.exp(-x * x));
}
