import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'credibility_adaptive_design_simulation.dart';

enum BayesianBorrowingScenarioFamily {
  noConflict,
  mildConflict,
  severeConflict,
  priorMisspecification,
  likelihoodMisspecification,
  sparseData,
  missingAtRandom,
  nonAdherence,
  delayedOutcome,
  externalDataQuality,
}

enum BayesianConflictState { none, mild, severe, unknown }

enum BayesianDecisionState { success, noSuccess, unknown }

enum BayesianGovernanceStatus {
  mechanicallyObserved,
  held,
  violated,
  unknown,
  revoked,
}

enum BayesianFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  contractIncomplete,
  prospectiveLockBroken,
  priorCherryPicking,
  externalEvidenceDuplicate,
  externalEvidenceUnsuitable,
  externalEvidenceMismatch,
  borrowingUnbounded,
  discountingDisabled,
  priorConflictSuppressed,
  scenarioCoverageIncomplete,
  scenarioMalformed,
  scenarioAddedAfterLock,
  resultMissingOrDuplicate,
  resultArithmeticMismatch,
  monteCarloUnderpowered,
  falsePositiveInflated,
  powerInsufficient,
  biasExcessive,
  coverageInsufficient,
  posteriorThresholdDrift,
  selectivePosteriorReporting,
  computationUnreliable,
  oracleIncomplete,
  oracleMismatch,
  historyBroken,
  revocation,
}

final class BayesianSeedCustody {
  final int masterSeed;
  final String commitmentSalt;
  final List<String> scenarioIds;

  BayesianSeedCustody({
    required this.masterSeed,
    required this.commitmentSalt,
    required List<String> scenarioIds,
  }) : scenarioIds = List.unmodifiable(scenarioIds);

  String get masterSeedCommitmentSha256 =>
      _sha256({'salt': commitmentSalt, 'master_seed': masterSeed});

  String get seedManifestSha256 => _sha256({
    'master_seed_commitment_sha256': masterSeedCommitmentSha256,
    'scenario_ids': [...scenarioIds]..sort(),
  });

  Map<String, Object?> get publicJson => {
    'master_seed_commitment_sha256': masterSeedCommitmentSha256,
    'seed_manifest_sha256': seedManifestSha256,
    'scenario_count': scenarioIds.length,
    'raw_seed_exposed': false,
  };
}

final class BayesianExternalEvidenceRecord {
  final String cohortId;
  final String populationId;
  final String outcomeId;
  final String estimandId;
  final int successes;
  final int total;
  final double qualityScore;
  final double relevanceScore;
  final bool patientLevelAvailable;
  final bool outcomeAligned;
  final bool populationAligned;
  final bool included;
  final String inclusionDecision;
  final String sourceRef;
  final String assessedAtUtc;

  const BayesianExternalEvidenceRecord({
    required this.cohortId,
    required this.populationId,
    required this.outcomeId,
    required this.estimandId,
    required this.successes,
    required this.total,
    required this.qualityScore,
    required this.relevanceScore,
    required this.patientLevelAvailable,
    required this.outcomeAligned,
    required this.populationAligned,
    required this.included,
    required this.inclusionDecision,
    required this.sourceRef,
    required this.assessedAtUtc,
  });

  BayesianExternalEvidenceRecord copyWith({
    String? cohortId,
    String? populationId,
    String? outcomeId,
    String? estimandId,
    int? successes,
    int? total,
    double? qualityScore,
    double? relevanceScore,
    bool? patientLevelAvailable,
    bool? outcomeAligned,
    bool? populationAligned,
    bool? included,
    String? inclusionDecision,
    String? sourceRef,
    String? assessedAtUtc,
  }) => BayesianExternalEvidenceRecord(
    cohortId: cohortId ?? this.cohortId,
    populationId: populationId ?? this.populationId,
    outcomeId: outcomeId ?? this.outcomeId,
    estimandId: estimandId ?? this.estimandId,
    successes: successes ?? this.successes,
    total: total ?? this.total,
    qualityScore: qualityScore ?? this.qualityScore,
    relevanceScore: relevanceScore ?? this.relevanceScore,
    patientLevelAvailable: patientLevelAvailable ?? this.patientLevelAvailable,
    outcomeAligned: outcomeAligned ?? this.outcomeAligned,
    populationAligned: populationAligned ?? this.populationAligned,
    included: included ?? this.included,
    inclusionDecision: inclusionDecision ?? this.inclusionDecision,
    sourceRef: sourceRef ?? this.sourceRef,
    assessedAtUtc: assessedAtUtc ?? this.assessedAtUtc,
  );

  Map<String, Object?> get canonicalPayload => {
    'cohort_id': cohortId,
    'population_id': populationId,
    'outcome_id': outcomeId,
    'estimand_id': estimandId,
    'successes': successes,
    'total': total,
    'quality_score': qualityScore,
    'relevance_score': relevanceScore,
    'patient_level_available': patientLevelAvailable,
    'outcome_aligned': outcomeAligned,
    'population_aligned': populationAligned,
    'included': included,
    'inclusion_decision': inclusionDecision,
    'source_ref': sourceRef,
    'assessed_at_utc': assessedAtUtc,
  };

  String get recordSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'record_sha256': recordSha256,
  };
}

final class BayesianPriorLikelihoodContract {
  final String contractId;
  final String priorFamilyId;
  final double weakPriorAlpha;
  final double weakPriorBeta;
  final double informativeMixtureWeight;
  final double maximumBorrowingFraction;
  final double maximumPriorEffectiveSampleSize;
  final double minimumExternalQuality;
  final double minimumExternalRelevance;
  final String discountingRuleId;
  final double conflictMildThreshold;
  final double conflictSevereThreshold;
  final String likelihoodId;
  final String estimandId;
  final String missingDataStrategyId;
  final double treatmentEffectThreshold;
  final double posteriorSuccessProbability;
  final String computationMethodId;
  final String convergenceRuleId;
  final String modelCodeSha256;
  final String randomNumberGeneratorId;
  final String seedManifestSha256;
  final String scenarioCatalogSha256;
  final String authoredAtUtc;
  final String lockedAtUtc;
  final String firstResultVisibleAtUtc;
  final String boundary;

  const BayesianPriorLikelihoodContract({
    required this.contractId,
    required this.priorFamilyId,
    required this.weakPriorAlpha,
    required this.weakPriorBeta,
    required this.informativeMixtureWeight,
    required this.maximumBorrowingFraction,
    required this.maximumPriorEffectiveSampleSize,
    required this.minimumExternalQuality,
    required this.minimumExternalRelevance,
    required this.discountingRuleId,
    required this.conflictMildThreshold,
    required this.conflictSevereThreshold,
    required this.likelihoodId,
    required this.estimandId,
    required this.missingDataStrategyId,
    required this.treatmentEffectThreshold,
    required this.posteriorSuccessProbability,
    required this.computationMethodId,
    required this.convergenceRuleId,
    required this.modelCodeSha256,
    required this.randomNumberGeneratorId,
    required this.seedManifestSha256,
    required this.scenarioCatalogSha256,
    required this.authoredAtUtc,
    required this.lockedAtUtc,
    required this.firstResultVisibleAtUtc,
    required this.boundary,
  });

  BayesianPriorLikelihoodContract copyWith({
    double? weakPriorAlpha,
    double? weakPriorBeta,
    double? informativeMixtureWeight,
    double? maximumBorrowingFraction,
    double? maximumPriorEffectiveSampleSize,
    double? minimumExternalQuality,
    double? minimumExternalRelevance,
    String? discountingRuleId,
    double? conflictMildThreshold,
    double? conflictSevereThreshold,
    String? likelihoodId,
    String? estimandId,
    String? missingDataStrategyId,
    double? treatmentEffectThreshold,
    double? posteriorSuccessProbability,
    String? computationMethodId,
    String? convergenceRuleId,
    String? modelCodeSha256,
    String? randomNumberGeneratorId,
    String? seedManifestSha256,
    String? scenarioCatalogSha256,
    String? authoredAtUtc,
    String? lockedAtUtc,
    String? firstResultVisibleAtUtc,
    String? boundary,
  }) => BayesianPriorLikelihoodContract(
    contractId: contractId,
    priorFamilyId: priorFamilyId,
    weakPriorAlpha: weakPriorAlpha ?? this.weakPriorAlpha,
    weakPriorBeta: weakPriorBeta ?? this.weakPriorBeta,
    informativeMixtureWeight:
        informativeMixtureWeight ?? this.informativeMixtureWeight,
    maximumBorrowingFraction:
        maximumBorrowingFraction ?? this.maximumBorrowingFraction,
    maximumPriorEffectiveSampleSize:
        maximumPriorEffectiveSampleSize ?? this.maximumPriorEffectiveSampleSize,
    minimumExternalQuality:
        minimumExternalQuality ?? this.minimumExternalQuality,
    minimumExternalRelevance:
        minimumExternalRelevance ?? this.minimumExternalRelevance,
    discountingRuleId: discountingRuleId ?? this.discountingRuleId,
    conflictMildThreshold: conflictMildThreshold ?? this.conflictMildThreshold,
    conflictSevereThreshold:
        conflictSevereThreshold ?? this.conflictSevereThreshold,
    likelihoodId: likelihoodId ?? this.likelihoodId,
    estimandId: estimandId ?? this.estimandId,
    missingDataStrategyId: missingDataStrategyId ?? this.missingDataStrategyId,
    treatmentEffectThreshold:
        treatmentEffectThreshold ?? this.treatmentEffectThreshold,
    posteriorSuccessProbability:
        posteriorSuccessProbability ?? this.posteriorSuccessProbability,
    computationMethodId: computationMethodId ?? this.computationMethodId,
    convergenceRuleId: convergenceRuleId ?? this.convergenceRuleId,
    modelCodeSha256: modelCodeSha256 ?? this.modelCodeSha256,
    randomNumberGeneratorId:
        randomNumberGeneratorId ?? this.randomNumberGeneratorId,
    seedManifestSha256: seedManifestSha256 ?? this.seedManifestSha256,
    scenarioCatalogSha256: scenarioCatalogSha256 ?? this.scenarioCatalogSha256,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    lockedAtUtc: lockedAtUtc ?? this.lockedAtUtc,
    firstResultVisibleAtUtc:
        firstResultVisibleAtUtc ?? this.firstResultVisibleAtUtc,
    boundary: boundary ?? this.boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    'contract_id': contractId,
    'prior_family_id': priorFamilyId,
    'weak_prior_alpha': weakPriorAlpha,
    'weak_prior_beta': weakPriorBeta,
    'informative_mixture_weight': informativeMixtureWeight,
    'maximum_borrowing_fraction': maximumBorrowingFraction,
    'maximum_prior_effective_sample_size': maximumPriorEffectiveSampleSize,
    'minimum_external_quality': minimumExternalQuality,
    'minimum_external_relevance': minimumExternalRelevance,
    'discounting_rule_id': discountingRuleId,
    'conflict_mild_threshold': conflictMildThreshold,
    'conflict_severe_threshold': conflictSevereThreshold,
    'likelihood_id': likelihoodId,
    'estimand_id': estimandId,
    'missing_data_strategy_id': missingDataStrategyId,
    'treatment_effect_threshold': treatmentEffectThreshold,
    'posterior_success_probability': posteriorSuccessProbability,
    'computation_method_id': computationMethodId,
    'convergence_rule_id': convergenceRuleId,
    'model_code_sha256': modelCodeSha256,
    'random_number_generator_id': randomNumberGeneratorId,
    'seed_manifest_sha256': seedManifestSha256,
    'scenario_catalog_sha256': scenarioCatalogSha256,
    'authored_at_utc': authoredAtUtc,
    'locked_at_utc': lockedAtUtc,
    'first_result_visible_at_utc': firstResultVisibleAtUtc,
    'boundary': boundary,
  };

  String get contractSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'contract_sha256': contractSha256,
  };
}

final class BayesianBorrowingScenario {
  final String scenarioId;
  final BayesianBorrowingScenarioFamily family;
  final bool nullCompatible;
  final double trueControlRate;
  final double trueTreatmentRate;
  final double externalControlRate;
  final int externalSampleSize;
  final int currentControlSampleSize;
  final int currentTreatmentSampleSize;
  final double externalQuality;
  final double externalRelevance;
  final double missingRate;
  final double nonAdherenceRate;
  final double delayedOutcomeRate;
  final double likelihoodOverdispersion;
  final int repetitions;
  final double maximumFalsePositiveProbability;
  final double minimumDecisionProbability;
  final double maximumAbsoluteBias;
  final double minimumCoverage;
  final String prespecifiedAtUtc;
  final String rationale;

  const BayesianBorrowingScenario({
    required this.scenarioId,
    required this.family,
    required this.nullCompatible,
    required this.trueControlRate,
    required this.trueTreatmentRate,
    required this.externalControlRate,
    required this.externalSampleSize,
    required this.currentControlSampleSize,
    required this.currentTreatmentSampleSize,
    required this.externalQuality,
    required this.externalRelevance,
    required this.missingRate,
    required this.nonAdherenceRate,
    required this.delayedOutcomeRate,
    required this.likelihoodOverdispersion,
    required this.repetitions,
    required this.maximumFalsePositiveProbability,
    required this.minimumDecisionProbability,
    required this.maximumAbsoluteBias,
    required this.minimumCoverage,
    required this.prespecifiedAtUtc,
    required this.rationale,
  });

  BayesianBorrowingScenario copyWith({
    String? scenarioId,
    BayesianBorrowingScenarioFamily? family,
    bool? nullCompatible,
    double? trueControlRate,
    double? trueTreatmentRate,
    double? externalControlRate,
    int? externalSampleSize,
    int? currentControlSampleSize,
    int? currentTreatmentSampleSize,
    double? externalQuality,
    double? externalRelevance,
    double? missingRate,
    double? nonAdherenceRate,
    double? delayedOutcomeRate,
    double? likelihoodOverdispersion,
    int? repetitions,
    double? maximumFalsePositiveProbability,
    double? minimumDecisionProbability,
    double? maximumAbsoluteBias,
    double? minimumCoverage,
    String? prespecifiedAtUtc,
    String? rationale,
  }) => BayesianBorrowingScenario(
    scenarioId: scenarioId ?? this.scenarioId,
    family: family ?? this.family,
    nullCompatible: nullCompatible ?? this.nullCompatible,
    trueControlRate: trueControlRate ?? this.trueControlRate,
    trueTreatmentRate: trueTreatmentRate ?? this.trueTreatmentRate,
    externalControlRate: externalControlRate ?? this.externalControlRate,
    externalSampleSize: externalSampleSize ?? this.externalSampleSize,
    currentControlSampleSize:
        currentControlSampleSize ?? this.currentControlSampleSize,
    currentTreatmentSampleSize:
        currentTreatmentSampleSize ?? this.currentTreatmentSampleSize,
    externalQuality: externalQuality ?? this.externalQuality,
    externalRelevance: externalRelevance ?? this.externalRelevance,
    missingRate: missingRate ?? this.missingRate,
    nonAdherenceRate: nonAdherenceRate ?? this.nonAdherenceRate,
    delayedOutcomeRate: delayedOutcomeRate ?? this.delayedOutcomeRate,
    likelihoodOverdispersion:
        likelihoodOverdispersion ?? this.likelihoodOverdispersion,
    repetitions: repetitions ?? this.repetitions,
    maximumFalsePositiveProbability:
        maximumFalsePositiveProbability ?? this.maximumFalsePositiveProbability,
    minimumDecisionProbability:
        minimumDecisionProbability ?? this.minimumDecisionProbability,
    maximumAbsoluteBias: maximumAbsoluteBias ?? this.maximumAbsoluteBias,
    minimumCoverage: minimumCoverage ?? this.minimumCoverage,
    prespecifiedAtUtc: prespecifiedAtUtc ?? this.prespecifiedAtUtc,
    rationale: rationale ?? this.rationale,
  );

  Map<String, Object?> get canonicalPayload => {
    'scenario_id': scenarioId,
    'family': family.name,
    'null_compatible': nullCompatible,
    'true_control_rate': trueControlRate,
    'true_treatment_rate': trueTreatmentRate,
    'external_control_rate': externalControlRate,
    'external_sample_size': externalSampleSize,
    'current_control_sample_size': currentControlSampleSize,
    'current_treatment_sample_size': currentTreatmentSampleSize,
    'external_quality': externalQuality,
    'external_relevance': externalRelevance,
    'missing_rate': missingRate,
    'non_adherence_rate': nonAdherenceRate,
    'delayed_outcome_rate': delayedOutcomeRate,
    'likelihood_overdispersion': likelihoodOverdispersion,
    'repetitions': repetitions,
    'maximum_false_positive_probability': maximumFalsePositiveProbability,
    'minimum_decision_probability': minimumDecisionProbability,
    'maximum_absolute_bias': maximumAbsoluteBias,
    'minimum_coverage': minimumCoverage,
    'prespecified_at_utc': prespecifiedAtUtc,
    'rationale': rationale,
  };

  String get scenarioSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'scenario_sha256': scenarioSha256,
  };
}

final class BayesianOperatingCharacteristicsResult {
  final String scenarioId;
  final String scenarioSha256;
  final int repetitions;
  final int decisionCount;
  final int coverageCount;
  final int failureCount;
  final double decisionProbability;
  final double monteCarloStandardError;
  final double meanPosteriorEffect;
  final double bias;
  final double intervalCoverage;
  final double meanPosteriorProbability;
  final double meanBorrowingWeight;
  final double meanBorrowedEffectiveSampleSize;
  final double meanConflictScore;
  final bool computationConverged;

  const BayesianOperatingCharacteristicsResult({
    required this.scenarioId,
    required this.scenarioSha256,
    required this.repetitions,
    required this.decisionCount,
    required this.coverageCount,
    required this.failureCount,
    required this.decisionProbability,
    required this.monteCarloStandardError,
    required this.meanPosteriorEffect,
    required this.bias,
    required this.intervalCoverage,
    required this.meanPosteriorProbability,
    required this.meanBorrowingWeight,
    required this.meanBorrowedEffectiveSampleSize,
    required this.meanConflictScore,
    required this.computationConverged,
  });

  BayesianOperatingCharacteristicsResult copyWith({
    String? scenarioId,
    String? scenarioSha256,
    int? repetitions,
    int? decisionCount,
    int? coverageCount,
    int? failureCount,
    double? decisionProbability,
    double? monteCarloStandardError,
    double? meanPosteriorEffect,
    double? bias,
    double? intervalCoverage,
    double? meanPosteriorProbability,
    double? meanBorrowingWeight,
    double? meanBorrowedEffectiveSampleSize,
    double? meanConflictScore,
    bool? computationConverged,
  }) => BayesianOperatingCharacteristicsResult(
    scenarioId: scenarioId ?? this.scenarioId,
    scenarioSha256: scenarioSha256 ?? this.scenarioSha256,
    repetitions: repetitions ?? this.repetitions,
    decisionCount: decisionCount ?? this.decisionCount,
    coverageCount: coverageCount ?? this.coverageCount,
    failureCount: failureCount ?? this.failureCount,
    decisionProbability: decisionProbability ?? this.decisionProbability,
    monteCarloStandardError:
        monteCarloStandardError ?? this.monteCarloStandardError,
    meanPosteriorEffect: meanPosteriorEffect ?? this.meanPosteriorEffect,
    bias: bias ?? this.bias,
    intervalCoverage: intervalCoverage ?? this.intervalCoverage,
    meanPosteriorProbability:
        meanPosteriorProbability ?? this.meanPosteriorProbability,
    meanBorrowingWeight: meanBorrowingWeight ?? this.meanBorrowingWeight,
    meanBorrowedEffectiveSampleSize:
        meanBorrowedEffectiveSampleSize ?? this.meanBorrowedEffectiveSampleSize,
    meanConflictScore: meanConflictScore ?? this.meanConflictScore,
    computationConverged: computationConverged ?? this.computationConverged,
  );

  Map<String, Object?> get canonicalPayload => {
    'scenario_id': scenarioId,
    'scenario_sha256': scenarioSha256,
    'repetitions': repetitions,
    'decision_count': decisionCount,
    'coverage_count': coverageCount,
    'failure_count': failureCount,
    'decision_probability': decisionProbability,
    'monte_carlo_standard_error': monteCarloStandardError,
    'mean_posterior_effect': meanPosteriorEffect,
    'bias': bias,
    'interval_coverage': intervalCoverage,
    'mean_posterior_probability': meanPosteriorProbability,
    'mean_borrowing_weight': meanBorrowingWeight,
    'mean_borrowed_effective_sample_size': meanBorrowedEffectiveSampleSize,
    'mean_conflict_score': meanConflictScore,
    'computation_converged': computationConverged,
  };

  String get resultSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'result_sha256': resultSha256,
  };
}

final class BayesianOracleVector {
  final String vectorId;
  final double observedControlRate;
  final double priorControlRate;
  final double posteriorProbability;
  final BayesianConflictState expectedConflictState;
  final BayesianDecisionState expectedDecisionState;
  final String rationale;

  const BayesianOracleVector({
    required this.vectorId,
    required this.observedControlRate,
    required this.priorControlRate,
    required this.posteriorProbability,
    required this.expectedConflictState,
    required this.expectedDecisionState,
    required this.rationale,
  });

  BayesianOracleVector copyWith({
    double? observedControlRate,
    double? priorControlRate,
    double? posteriorProbability,
    BayesianConflictState? expectedConflictState,
    BayesianDecisionState? expectedDecisionState,
  }) => BayesianOracleVector(
    vectorId: vectorId,
    observedControlRate: observedControlRate ?? this.observedControlRate,
    priorControlRate: priorControlRate ?? this.priorControlRate,
    posteriorProbability: posteriorProbability ?? this.posteriorProbability,
    expectedConflictState: expectedConflictState ?? this.expectedConflictState,
    expectedDecisionState: expectedDecisionState ?? this.expectedDecisionState,
    rationale: rationale,
  );

  Map<String, Object?> get canonicalPayload => {
    'vector_id': vectorId,
    'observed_control_rate': observedControlRate,
    'prior_control_rate': priorControlRate,
    'posterior_probability': posteriorProbability,
    'expected_conflict_state': expectedConflictState.name,
    'expected_decision_state': expectedDecisionState.name,
    'rationale': rationale,
  };

  String get vectorSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'vector_sha256': vectorSha256,
  };
}

final class CredibilityBayesianBorrowingCalibrationPackage {
  static const String schema =
      'parkinsum.credibility-bayesian-borrowing-calibration-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v5';

  final int schemaVersion;
  final String packageId;
  final CredibilityAdaptiveDesignSimulationPackage adaptivePackage;
  final String adaptivePackageSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final BayesianPriorLikelihoodContract contract;
  final BayesianSeedCustody custody;
  final List<BayesianExternalEvidenceRecord> externalEvidence;
  final List<BayesianBorrowingScenario> scenarios;
  final List<BayesianOperatingCharacteristicsResult> results;
  final List<BayesianOracleVector> oracleVectors;
  final String simulationStartedAtUtc;
  final String simulationCompletedAtUtc;
  final bool allRelevantExternalEvidenceRetained;
  final bool allPrespecifiedResultsRetained;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityBayesianBorrowingCalibrationPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.adaptivePackage,
    required this.adaptivePackageSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.contract,
    required this.custody,
    required List<BayesianExternalEvidenceRecord> externalEvidence,
    required List<BayesianBorrowingScenario> scenarios,
    required List<BayesianOperatingCharacteristicsResult> results,
    required List<BayesianOracleVector> oracleVectors,
    required this.simulationStartedAtUtc,
    required this.simulationCompletedAtUtc,
    required this.allRelevantExternalEvidenceRetained,
    required this.allPrespecifiedResultsRetained,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : externalEvidence = List.unmodifiable(externalEvidence),
       scenarios = List.unmodifiable(scenarios),
       results = List.unmodifiable(results),
       oracleVectors = List.unmodifiable(oracleVectors);

  CredibilityBayesianBorrowingCalibrationPackage copyWith({
    int? schemaVersion,
    String? adaptivePackageSha256,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    BayesianPriorLikelihoodContract? contract,
    BayesianSeedCustody? custody,
    List<BayesianExternalEvidenceRecord>? externalEvidence,
    List<BayesianBorrowingScenario>? scenarios,
    List<BayesianOperatingCharacteristicsResult>? results,
    List<BayesianOracleVector>? oracleVectors,
    String? simulationStartedAtUtc,
    String? simulationCompletedAtUtc,
    bool? allRelevantExternalEvidenceRetained,
    bool? allPrespecifiedResultsRetained,
    bool? revoked,
    bool? syntheticDemoOnly,
    String? boundary,
  }) => CredibilityBayesianBorrowingCalibrationPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    adaptivePackage: adaptivePackage,
    adaptivePackageSha256: adaptivePackageSha256 ?? this.adaptivePackageSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    contract: contract ?? this.contract,
    custody: custody ?? this.custody,
    externalEvidence: externalEvidence ?? this.externalEvidence,
    scenarios: scenarios ?? this.scenarios,
    results: results ?? this.results,
    oracleVectors: oracleVectors ?? this.oracleVectors,
    simulationStartedAtUtc:
        simulationStartedAtUtc ?? this.simulationStartedAtUtc,
    simulationCompletedAtUtc:
        simulationCompletedAtUtc ?? this.simulationCompletedAtUtc,
    allRelevantExternalEvidenceRetained:
        allRelevantExternalEvidenceRetained ??
        this.allRelevantExternalEvidenceRetained,
    allPrespecifiedResultsRetained:
        allPrespecifiedResultsRetained ?? this.allPrespecifiedResultsRetained,
    revoked: revoked ?? this.revoked,
    syntheticDemoOnly: syntheticDemoOnly ?? this.syntheticDemoOnly,
    boundary: boundary ?? this.boundary,
  );

  Map<String, Object?> get canonicalPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'package_version': packageVersion,
    'package_id': packageId,
    'adaptive_package_sha256': adaptivePackageSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'contract': contract.toJson(),
    'seed_custody': custody.publicJson,
    'external_evidence': externalEvidence.map((item) => item.toJson()).toList(),
    'scenarios': scenarios.map((item) => item.toJson()).toList(),
    'results': results.map((item) => item.toJson()).toList(),
    'oracle_vectors': oracleVectors.map((item) => item.toJson()).toList(),
    'simulation_started_at_utc': simulationStartedAtUtc,
    'simulation_completed_at_utc': simulationCompletedAtUtc,
    'all_relevant_external_evidence_retained':
        allRelevantExternalEvidenceRetained,
    'all_prespecified_results_retained': allPrespecifiedResultsRetained,
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

final class BayesianFinding {
  final BayesianFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  BayesianFinding({
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

final class BayesianGovernanceAssessment {
  final CredibilityBayesianBorrowingCalibrationPackage package;
  final BayesianGovernanceStatus status;
  final List<BayesianFinding> findings;

  BayesianGovernanceAssessment._({
    required this.package,
    required this.status,
    required List<BayesianFinding> findings,
  }) : findings = List.unmodifiable(findings);

  bool get integrityVerified => findings.isEmpty;
  bool get canSupportClinicalOrRegulatoryClaim => false;

  bool _hasAny(Set<BayesianFindingKind> kinds) =>
      findings.any((item) => kinds.contains(item.kind));

  Map<String, String> get lanes => {
    'priorProvenance':
        _hasAny({
          BayesianFindingKind.contractIncomplete,
          BayesianFindingKind.priorCherryPicking,
          BayesianFindingKind.posteriorThresholdDrift,
        })
        ? 'blocked'
        : 'prospectivelyLocked',
    'externalDataSuitability':
        _hasAny({
          BayesianFindingKind.externalEvidenceDuplicate,
          BayesianFindingKind.externalEvidenceUnsuitable,
          BayesianFindingKind.externalEvidenceMismatch,
        })
        ? 'held'
        : 'qualityAndRelevanceRecorded',
    'borrowing':
        _hasAny({
          BayesianFindingKind.borrowingUnbounded,
          BayesianFindingKind.discountingDisabled,
        })
        ? 'unsafe'
        : 'boundedDynamicMixture',
    'priorDataConflict':
        _hasAny({
          BayesianFindingKind.priorConflictSuppressed,
          BayesianFindingKind.scenarioCoverageIncomplete,
        })
        ? 'unresolved'
        : 'noMildSevereRetained',
    'computation':
        _hasAny({
          BayesianFindingKind.computationUnreliable,
          BayesianFindingKind.resultArithmeticMismatch,
          BayesianFindingKind.monteCarloUnderpowered,
        })
        ? 'failed'
        : 'closedFormAndPrecisionObserved',
    'posteriorDecision':
        _hasAny({
          BayesianFindingKind.posteriorThresholdDrift,
          BayesianFindingKind.selectivePosteriorReporting,
          BayesianFindingKind.resultMissingOrDuplicate,
        })
        ? 'blocked'
        : 'thresholdAndNullsRetained',
    'frequentistCalibration':
        _hasAny({
          BayesianFindingKind.falsePositiveInflated,
          BayesianFindingKind.powerInsufficient,
          BayesianFindingKind.biasExcessive,
          BayesianFindingKind.coverageInsufficient,
        })
        ? 'held'
        : 'typeOnePowerBiasCoverageObserved',
    'oracleAndAdjudication':
        _hasAny({
          BayesianFindingKind.oracleIncomplete,
          BayesianFindingKind.oracleMismatch,
          BayesianFindingKind.historyBroken,
          BayesianFindingKind.revocation,
          BayesianFindingKind.identityMismatch,
        })
        ? 'blocked'
        : 'manufacturedCasesAgree',
  };

  Map<String, int> get counts => {
    'externalEvidence': package.externalEvidence.length,
    'scenarios': package.scenarios.length,
    'nullScenarios': package.scenarios
        .where((item) => item.nullCompatible)
        .length,
    'totalRepetitions': package.results.fold(
      0,
      (total, item) => total + item.repetitions,
    ),
    'oracleVectors': package.oracleVectors.length,
  };

  double get maximumMonteCarloStandardError => package.results.isEmpty
      ? double.nan
      : package.results
            .map((item) => item.monteCarloStandardError)
            .reduce(math.max);

  double get maximumBorrowedEffectiveSampleSize => package.results.isEmpty
      ? double.nan
      : package.results
            .map((item) => item.meanBorrowedEffectiveSampleSize)
            .reduce(math.max);

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'lanes': lanes,
    'counts': counts,
    'maximum_monte_carlo_standard_error': maximumMonteCarloStandardError,
    'maximum_borrowed_effective_sample_size':
        maximumBorrowedEffectiveSampleSize,
    'findings': findings.map((item) => item.toJson()).toList(),
    'can_support_clinical_or_regulatory_claim':
        canSupportClinicalOrRegulatoryClaim,
    'boundary': package.boundary,
  };
}

final class CredibilityBayesianBorrowingCalibrationVerifier {
  static const Set<BayesianBorrowingScenarioFamily> requiredFamilies = {
    BayesianBorrowingScenarioFamily.noConflict,
    BayesianBorrowingScenarioFamily.mildConflict,
    BayesianBorrowingScenarioFamily.severeConflict,
    BayesianBorrowingScenarioFamily.priorMisspecification,
    BayesianBorrowingScenarioFamily.likelihoodMisspecification,
    BayesianBorrowingScenarioFamily.sparseData,
    BayesianBorrowingScenarioFamily.missingAtRandom,
    BayesianBorrowingScenarioFamily.nonAdherence,
    BayesianBorrowingScenarioFamily.delayedOutcome,
    BayesianBorrowingScenarioFamily.externalDataQuality,
  };

  const CredibilityBayesianBorrowingCalibrationVerifier();

  BayesianGovernanceAssessment verify(
    CredibilityBayesianBorrowingCalibrationPackage package,
  ) {
    final findings = <BayesianFinding>[];
    void add(BayesianFindingKind kind, String detail, [List<String>? ids]) {
      findings.add(
        BayesianFinding(
          kind: kind,
          detail: detail,
          affectedIds: ids ?? const [],
        ),
      );
    }

    if (package.schemaVersion !=
        CredibilityBayesianBorrowingCalibrationPackage.currentSchemaVersion) {
      add(BayesianFindingKind.schemaUnsupported, 'Unsupported schema version.');
    }
    if (package.adaptivePackageSha256 !=
            package.adaptivePackage.packageSha256 ||
        package.configurationSha256 !=
            package.adaptivePackage.configurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            package.adaptivePackage.algorithmSourceBundleSha256) {
      add(BayesianFindingKind.identityMismatch, 'Upstream identity drift.');
    }
    for (final digest in [
      package.adaptivePackageSha256,
      package.configurationSha256,
      package.algorithmSourceBundleSha256,
      package.contract.modelCodeSha256,
      package.contract.seedManifestSha256,
      package.contract.scenarioCatalogSha256,
    ]) {
      if (!_digestPattern.hasMatch(digest)) {
        add(BayesianFindingKind.malformedDigest, 'Malformed identity digest.');
        break;
      }
    }
    final contract = package.contract;
    if (contract.priorFamilyId != 'robust-beta-mixture/1' ||
        contract.likelihoodId != 'binomial-beta-conjugate/1' ||
        contract.estimandId.isEmpty ||
        contract.missingDataStrategyId.isEmpty ||
        contract.computationMethodId != 'closed-form-beta-mixture/1' ||
        contract.convergenceRuleId != 'finite-closed-form-and-mass-sum/1' ||
        !_close(contract.weakPriorAlpha, 1) ||
        !_close(contract.weakPriorBeta, 1) ||
        !_close(contract.informativeMixtureWeight, 0.70) ||
        !_close(contract.minimumExternalQuality, 0.75) ||
        !_close(contract.minimumExternalRelevance, 0.75) ||
        !_close(contract.conflictMildThreshold, 0.08) ||
        !_close(contract.conflictSevereThreshold, 0.18) ||
        contract.posteriorSuccessProbability <= 0.5 ||
        contract.posteriorSuccessProbability >= 1 ||
        contract.modelCodeSha256 !=
            '22850e77d1d55aac7d24a75bf78287dbcb538bab8c8dd3291074361e55d35dbc' ||
        contract.boundary.isEmpty ||
        !package.syntheticDemoOnly) {
      add(
        BayesianFindingKind.contractIncomplete,
        'Bayesian contract incomplete.',
      );
    }
    if (!_close(contract.treatmentEffectThreshold, 0) ||
        !_close(contract.posteriorSuccessProbability, 0.975)) {
      add(
        BayesianFindingKind.posteriorThresholdDrift,
        'Posterior decision threshold drifted after lock.',
      );
    }
    if (contract.maximumBorrowingFraction <= 0 ||
        contract.maximumBorrowingFraction >= 1 ||
        contract.maximumPriorEffectiveSampleSize <= 0 ||
        !_close(contract.maximumBorrowingFraction, 0.80) ||
        !_close(contract.maximumPriorEffectiveSampleSize, 40)) {
      add(BayesianFindingKind.borrowingUnbounded, 'Borrowing cap invalid.');
    }
    if (contract.discountingRuleId != 'posterior-robust-mixture-weight/1') {
      add(
        BayesianFindingKind.discountingDisabled,
        'Dynamic discounting drift.',
      );
    }
    final authored = DateTime.tryParse(contract.authoredAtUtc);
    final locked = DateTime.tryParse(contract.lockedAtUtc);
    final started = DateTime.tryParse(package.simulationStartedAtUtc);
    final completed = DateTime.tryParse(package.simulationCompletedAtUtc);
    final visible = DateTime.tryParse(contract.firstResultVisibleAtUtc);
    if (authored == null ||
        locked == null ||
        started == null ||
        completed == null ||
        visible == null ||
        authored.isAfter(locked) ||
        locked.isAfter(started) ||
        started.isAfter(completed) ||
        completed.isAfter(visible)) {
      add(
        BayesianFindingKind.prospectiveLockBroken,
        'Chronology is not prospective.',
      );
    }
    if (contract.seedManifestSha256 != package.custody.seedManifestSha256) {
      add(BayesianFindingKind.identityMismatch, 'Seed manifest drift.');
    }
    final expectedScenarioCatalog = _sha256(
      package.scenarios.map((item) => item.toJson()).toList(),
    );
    if (contract.scenarioCatalogSha256 != expectedScenarioCatalog) {
      add(
        BayesianFindingKind.scenarioAddedAfterLock,
        'Scenario catalog drift.',
      );
    }

    final evidenceIds = <String>{};
    for (final evidence in package.externalEvidence) {
      if (!evidenceIds.add(evidence.cohortId)) {
        add(
          BayesianFindingKind.externalEvidenceDuplicate,
          'Duplicate external cohort.',
          [evidence.cohortId],
        );
      }
      final structurallyValid =
          evidence.total > 0 &&
          evidence.successes >= 0 &&
          evidence.successes <= evidence.total &&
          evidence.qualityScore >= 0 &&
          evidence.qualityScore <= 1 &&
          evidence.relevanceScore >= 0 &&
          evidence.relevanceScore <= 1 &&
          DateTime.tryParse(evidence.assessedAtUtc) != null &&
          evidence.sourceRef.isNotEmpty &&
          evidence.inclusionDecision.isNotEmpty;
      if (!structurallyValid) {
        add(
          BayesianFindingKind.externalEvidenceUnsuitable,
          'Malformed external evidence.',
          [evidence.cohortId],
        );
      }
      if (evidence.included &&
          (evidence.qualityScore < contract.minimumExternalQuality ||
              evidence.relevanceScore < contract.minimumExternalRelevance ||
              !evidence.outcomeAligned ||
              !evidence.populationAligned)) {
        add(
          BayesianFindingKind.externalEvidenceMismatch,
          'Included external evidence is not sufficiently aligned.',
          [evidence.cohortId],
        );
      }
    }
    if (!package.allRelevantExternalEvidenceRetained ||
        package.externalEvidence.isEmpty ||
        !package.externalEvidence.any((item) => item.included) ||
        !package.externalEvidence.any((item) => !item.included)) {
      add(
        BayesianFindingKind.priorCherryPicking,
        'Included and excluded relevant evidence must both be retained.',
      );
    }

    final families = package.scenarios.map((item) => item.family).toSet();
    if (!families.containsAll(requiredFamilies)) {
      add(
        BayesianFindingKind.scenarioCoverageIncomplete,
        'Scenario grid incomplete.',
      );
    }
    final scenarioIds = <String>{};
    for (final scenario in package.scenarios) {
      final valid =
          scenarioIds.add(scenario.scenarioId) &&
          scenario.trueControlRate > 0 &&
          scenario.trueControlRate < 1 &&
          scenario.trueTreatmentRate > 0 &&
          scenario.trueTreatmentRate < 1 &&
          scenario.externalControlRate > 0 &&
          scenario.externalControlRate < 1 &&
          scenario.externalSampleSize > 0 &&
          scenario.currentControlSampleSize > 0 &&
          scenario.currentTreatmentSampleSize > 0 &&
          scenario.externalQuality >= 0 &&
          scenario.externalQuality <= 1 &&
          scenario.externalRelevance >= 0 &&
          scenario.externalRelevance <= 1 &&
          scenario.missingRate >= 0 &&
          scenario.missingRate < 0.5 &&
          scenario.nonAdherenceRate >= 0 &&
          scenario.nonAdherenceRate < 0.5 &&
          scenario.delayedOutcomeRate >= 0 &&
          scenario.delayedOutcomeRate < 0.5 &&
          scenario.likelihoodOverdispersion >= 1 &&
          DateTime.tryParse(scenario.prespecifiedAtUtc) != null;
      if (!valid) {
        add(
          BayesianFindingKind.scenarioMalformed,
          'Malformed or duplicate scenario.',
          [scenario.scenarioId],
        );
      }
      if (scenario.repetitions < 30000) {
        add(
          BayesianFindingKind.monteCarloUnderpowered,
          'Scenario is under-repeated.',
          [scenario.scenarioId],
        );
      }
    }

    final resultsById =
        <String, List<BayesianOperatingCharacteristicsResult>>{};
    for (final result in package.results) {
      resultsById.putIfAbsent(result.scenarioId, () => []).add(result);
    }
    for (final scenario in package.scenarios) {
      final matches = resultsById[scenario.scenarioId] ?? const [];
      if (matches.length != 1) {
        add(
          BayesianFindingKind.resultMissingOrDuplicate,
          'Each scenario requires one result.',
          [scenario.scenarioId],
        );
        continue;
      }
      final result = matches.single;
      if (result.scenarioSha256 != scenario.scenarioSha256 ||
          result.repetitions != scenario.repetitions ||
          result.decisionCount < 0 ||
          result.coverageCount < 0 ||
          result.failureCount < 0 ||
          result.decisionCount > result.repetitions ||
          result.coverageCount > result.repetitions ||
          !_close(
            result.decisionProbability,
            result.decisionCount / result.repetitions,
          ) ||
          !_close(
            result.intervalCoverage,
            result.coverageCount / result.repetitions,
          ) ||
          !_close(
            result.monteCarloStandardError,
            math.sqrt(
              result.decisionProbability *
                  (1 - result.decisionProbability) /
                  result.repetitions,
            ),
          ) ||
          ![
            result.decisionProbability,
            result.monteCarloStandardError,
            result.meanPosteriorEffect,
            result.bias,
            result.intervalCoverage,
            result.meanPosteriorProbability,
            result.meanBorrowingWeight,
            result.meanBorrowedEffectiveSampleSize,
            result.meanConflictScore,
          ].every((value) => value.isFinite)) {
        add(
          BayesianFindingKind.resultArithmeticMismatch,
          'Result arithmetic or identity mismatch.',
          [scenario.scenarioId],
        );
      }
      if (!result.computationConverged || result.failureCount != 0) {
        add(
          BayesianFindingKind.computationUnreliable,
          'Closed-form computation did not complete reliably.',
          [scenario.scenarioId],
        );
      }
      if (result.meanBorrowingWeight < 0 ||
          result.meanBorrowingWeight >
              contract.maximumBorrowingFraction + 1e-9 ||
          result.meanBorrowedEffectiveSampleSize < 0 ||
          result.meanBorrowedEffectiveSampleSize >
              contract.maximumPriorEffectiveSampleSize + 1e-9) {
        add(
          BayesianFindingKind.borrowingUnbounded,
          'Observed borrowing exceeds the prospective cap.',
          [scenario.scenarioId],
        );
      }
      if (scenario.nullCompatible &&
          result.decisionProbability >
              scenario.maximumFalsePositiveProbability +
                  1.96 * result.monteCarloStandardError) {
        add(
          BayesianFindingKind.falsePositiveInflated,
          'Null decision probability exceeds its bound.',
          [scenario.scenarioId],
        );
      }
      if (!scenario.nullCompatible &&
          result.decisionProbability + 1.96 * result.monteCarloStandardError <
              scenario.minimumDecisionProbability) {
        add(
          BayesianFindingKind.powerInsufficient,
          'Alternative decision probability is below its bound.',
          [scenario.scenarioId],
        );
      }
      if (result.bias.abs() > scenario.maximumAbsoluteBias) {
        add(
          BayesianFindingKind.biasExcessive,
          'Posterior effect bias exceeds its bound.',
          [scenario.scenarioId],
        );
      }
      if (result.intervalCoverage < scenario.minimumCoverage) {
        add(
          BayesianFindingKind.coverageInsufficient,
          'Approximate interval coverage is below its bound.',
          [scenario.scenarioId],
        );
      }
    }
    if (!package.allPrespecifiedResultsRetained ||
        package.results.length != package.scenarios.length) {
      add(
        BayesianFindingKind.selectivePosteriorReporting,
        'Prespecified posterior results were not all retained.',
      );
    }

    BayesianOperatingCharacteristicsResult? familyResult(
      BayesianBorrowingScenarioFamily family,
    ) {
      final scenario = package.scenarios
          .where((item) => item.family == family)
          .firstOrNull;
      if (scenario == null) return null;
      return resultsById[scenario.scenarioId]?.firstOrNull;
    }

    final noConflict = familyResult(BayesianBorrowingScenarioFamily.noConflict);
    final mild = familyResult(BayesianBorrowingScenarioFamily.mildConflict);
    final severe = familyResult(BayesianBorrowingScenarioFamily.severeConflict);
    if (noConflict == null ||
        mild == null ||
        severe == null ||
        !(noConflict.meanBorrowingWeight > mild.meanBorrowingWeight &&
            mild.meanBorrowingWeight > severe.meanBorrowingWeight) ||
        !(noConflict.meanConflictScore < mild.meanConflictScore &&
            mild.meanConflictScore < severe.meanConflictScore)) {
      add(
        BayesianFindingKind.priorConflictSuppressed,
        'Borrowing must decrease as prior-data conflict increases.',
      );
    }

    if (package.oracleVectors.length < 5) {
      add(
        BayesianFindingKind.oracleIncomplete,
        'Five oracle vectors required.',
      );
    }
    for (final vector in package.oracleVectors) {
      final difference = (vector.observedControlRate - vector.priorControlRate)
          .abs();
      final conflict = difference >= contract.conflictSevereThreshold
          ? BayesianConflictState.severe
          : difference >= contract.conflictMildThreshold
          ? BayesianConflictState.mild
          : BayesianConflictState.none;
      final decision =
          vector.posteriorProbability >= contract.posteriorSuccessProbability
          ? BayesianDecisionState.success
          : BayesianDecisionState.noSuccess;
      if (conflict != vector.expectedConflictState ||
          decision != vector.expectedDecisionState) {
        add(
          BayesianFindingKind.oracleMismatch,
          'Independent manufactured decision vector disagrees.',
          [vector.vectorId],
        );
      }
    }
    if (package.revoked) {
      add(BayesianFindingKind.revocation, 'Package explicitly revoked.');
    }

    final status = package.revoked
        ? BayesianGovernanceStatus.revoked
        : findings.isEmpty
        ? BayesianGovernanceStatus.mechanicallyObserved
        : findings.any(
            (item) => {
              BayesianFindingKind.schemaUnsupported,
              BayesianFindingKind.identityMismatch,
              BayesianFindingKind.malformedDigest,
              BayesianFindingKind.historyBroken,
            }.contains(item.kind),
          )
        ? BayesianGovernanceStatus.violated
        : BayesianGovernanceStatus.held;
    return BayesianGovernanceAssessment._(
      package: package,
      status: status,
      findings: findings,
    );
  }
}

bool _close(double left, double right, [double tolerance = 1e-12]) =>
    (left - right).abs() <= tolerance;

final RegExp _digestPattern = RegExp(r'^[a-f0-9]{64}$');

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
