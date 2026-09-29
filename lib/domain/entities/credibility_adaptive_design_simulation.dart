import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'credibility_evidence_execution_attestation.dart';
import 'credibility_randomization_interim_firewall.dart';

enum AdaptiveDesignKind { groupSequential }

enum AdaptiveScenarioFamily {
  nullNormal,
  nullVarianceGrid,
  alternativeNormal,
  boundaryEffect,
  heavyTail,
  correlatedEndpoints,
  timeTrend,
  delayedOutcome,
  missingAtRandom,
  nonAdherence,
  sparseData,
  modelMisspecification,
}

enum AdaptiveDecisionAction {
  efficacy,
  futility,
  continueToNextLook,
  completeNoEfficacy,
}

enum AdaptiveSimulationGovernanceStatus {
  mechanicallyObserved,
  held,
  violated,
  unknown,
  revoked,
}

enum AdaptiveSimulationFindingKind {
  schemaUnsupported,
  identityMismatch,
  malformedDigest,
  contractIncomplete,
  prospectiveLockBroken,
  seedManifestMismatch,
  decisionTimingDrift,
  adaptationRuleDrift,
  scenarioCoverageIncomplete,
  scenarioMalformed,
  scenarioAddedAfterLock,
  resultMissingOrDuplicate,
  resultIdentityMismatch,
  resultArithmeticMismatch,
  monteCarloUnderpowered,
  typeOneErrorInflated,
  powerInsufficient,
  biasExcessive,
  coverageInsufficient,
  sampleSizeInvalid,
  oracleIncomplete,
  oracleMismatch,
  historyBroken,
  resultSuppressed,
  revocation,
}

final class AdaptiveSimulationSeedCustody {
  final int masterSeed;
  final String commitmentSalt;
  final List<String> scenarioIds;

  AdaptiveSimulationSeedCustody({
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

final class AdaptiveDecisionRuleContract {
  final String contractId;
  final AdaptiveDesignKind designKind;
  final List<String> adaptationIds;
  final List<double> informationFractions;
  final List<double> efficacyZBoundaries;
  final List<double> futilityZBoundaries;
  final double oneSidedAlpha;
  final double targetPower;
  final int minimumSampleSize;
  final int maximumSampleSize;
  final String analysisModelSha256;
  final String decisionRuleCodeSha256;
  final String randomNumberGeneratorId;
  final String seedManifestSha256;
  final String scenarioCatalogSha256;
  final String authoredAtUtc;
  final String lockedAtUtc;
  final String firstResultVisibleAtUtc;
  final String boundary;

  AdaptiveDecisionRuleContract({
    required this.contractId,
    required this.designKind,
    required List<String> adaptationIds,
    required List<double> informationFractions,
    required List<double> efficacyZBoundaries,
    required List<double> futilityZBoundaries,
    required this.oneSidedAlpha,
    required this.targetPower,
    required this.minimumSampleSize,
    required this.maximumSampleSize,
    required this.analysisModelSha256,
    required this.decisionRuleCodeSha256,
    required this.randomNumberGeneratorId,
    required this.seedManifestSha256,
    required this.scenarioCatalogSha256,
    required this.authoredAtUtc,
    required this.lockedAtUtc,
    required this.firstResultVisibleAtUtc,
    required this.boundary,
  }) : adaptationIds = List.unmodifiable(adaptationIds),
       informationFractions = List.unmodifiable(informationFractions),
       efficacyZBoundaries = List.unmodifiable(efficacyZBoundaries),
       futilityZBoundaries = List.unmodifiable(futilityZBoundaries);

  AdaptiveDecisionRuleContract copyWith({
    List<String>? adaptationIds,
    List<double>? informationFractions,
    List<double>? efficacyZBoundaries,
    List<double>? futilityZBoundaries,
    double? oneSidedAlpha,
    double? targetPower,
    int? minimumSampleSize,
    int? maximumSampleSize,
    String? analysisModelSha256,
    String? decisionRuleCodeSha256,
    String? randomNumberGeneratorId,
    String? seedManifestSha256,
    String? scenarioCatalogSha256,
    String? authoredAtUtc,
    String? lockedAtUtc,
    String? firstResultVisibleAtUtc,
    String? boundary,
  }) => AdaptiveDecisionRuleContract(
    contractId: contractId,
    designKind: designKind,
    adaptationIds: adaptationIds ?? this.adaptationIds,
    informationFractions: informationFractions ?? this.informationFractions,
    efficacyZBoundaries: efficacyZBoundaries ?? this.efficacyZBoundaries,
    futilityZBoundaries: futilityZBoundaries ?? this.futilityZBoundaries,
    oneSidedAlpha: oneSidedAlpha ?? this.oneSidedAlpha,
    targetPower: targetPower ?? this.targetPower,
    minimumSampleSize: minimumSampleSize ?? this.minimumSampleSize,
    maximumSampleSize: maximumSampleSize ?? this.maximumSampleSize,
    analysisModelSha256: analysisModelSha256 ?? this.analysisModelSha256,
    decisionRuleCodeSha256:
        decisionRuleCodeSha256 ?? this.decisionRuleCodeSha256,
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
    'design_kind': designKind.name,
    'adaptation_ids': adaptationIds,
    'information_fractions': informationFractions,
    'efficacy_z_boundaries': efficacyZBoundaries,
    'futility_z_boundaries': futilityZBoundaries,
    'one_sided_alpha': oneSidedAlpha,
    'target_power': targetPower,
    'minimum_sample_size': minimumSampleSize,
    'maximum_sample_size': maximumSampleSize,
    'analysis_model_sha256': analysisModelSha256,
    'decision_rule_code_sha256': decisionRuleCodeSha256,
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

final class AdaptiveSimulationScenario {
  final String scenarioId;
  final AdaptiveScenarioFamily family;
  final bool nullCompatible;
  final double trueStandardizedEffect;
  final double varianceMultiplier;
  final double missingRate;
  final double nonAdherenceRate;
  final double timeTrend;
  final double delayedOutcomeFraction;
  final double endpointCorrelation;
  final int repetitions;
  final double minimumAcceptablePower;
  final double maximumAbsoluteBias;
  final double minimumCoverage;
  final String distributionId;
  final String rationale;
  final String prespecifiedAtUtc;

  const AdaptiveSimulationScenario({
    required this.scenarioId,
    required this.family,
    required this.nullCompatible,
    required this.trueStandardizedEffect,
    required this.varianceMultiplier,
    required this.missingRate,
    required this.nonAdherenceRate,
    required this.timeTrend,
    required this.delayedOutcomeFraction,
    required this.endpointCorrelation,
    required this.repetitions,
    required this.minimumAcceptablePower,
    required this.maximumAbsoluteBias,
    required this.minimumCoverage,
    required this.distributionId,
    required this.rationale,
    required this.prespecifiedAtUtc,
  });

  AdaptiveSimulationScenario copyWith({
    String? scenarioId,
    AdaptiveScenarioFamily? family,
    bool? nullCompatible,
    double? trueStandardizedEffect,
    double? varianceMultiplier,
    double? missingRate,
    double? nonAdherenceRate,
    double? timeTrend,
    double? delayedOutcomeFraction,
    double? endpointCorrelation,
    int? repetitions,
    double? minimumAcceptablePower,
    double? maximumAbsoluteBias,
    double? minimumCoverage,
    String? distributionId,
    String? rationale,
    String? prespecifiedAtUtc,
  }) => AdaptiveSimulationScenario(
    scenarioId: scenarioId ?? this.scenarioId,
    family: family ?? this.family,
    nullCompatible: nullCompatible ?? this.nullCompatible,
    trueStandardizedEffect:
        trueStandardizedEffect ?? this.trueStandardizedEffect,
    varianceMultiplier: varianceMultiplier ?? this.varianceMultiplier,
    missingRate: missingRate ?? this.missingRate,
    nonAdherenceRate: nonAdherenceRate ?? this.nonAdherenceRate,
    timeTrend: timeTrend ?? this.timeTrend,
    delayedOutcomeFraction:
        delayedOutcomeFraction ?? this.delayedOutcomeFraction,
    endpointCorrelation: endpointCorrelation ?? this.endpointCorrelation,
    repetitions: repetitions ?? this.repetitions,
    minimumAcceptablePower:
        minimumAcceptablePower ?? this.minimumAcceptablePower,
    maximumAbsoluteBias: maximumAbsoluteBias ?? this.maximumAbsoluteBias,
    minimumCoverage: minimumCoverage ?? this.minimumCoverage,
    distributionId: distributionId ?? this.distributionId,
    rationale: rationale ?? this.rationale,
    prespecifiedAtUtc: prespecifiedAtUtc ?? this.prespecifiedAtUtc,
  );

  Map<String, Object?> get canonicalPayload => {
    'scenario_id': scenarioId,
    'family': family.name,
    'null_compatible': nullCompatible,
    'true_standardized_effect': trueStandardizedEffect,
    'variance_multiplier': varianceMultiplier,
    'missing_rate': missingRate,
    'non_adherence_rate': nonAdherenceRate,
    'time_trend': timeTrend,
    'delayed_outcome_fraction': delayedOutcomeFraction,
    'endpoint_correlation': endpointCorrelation,
    'repetitions': repetitions,
    'minimum_acceptable_power': minimumAcceptablePower,
    'maximum_absolute_bias': maximumAbsoluteBias,
    'minimum_coverage': minimumCoverage,
    'distribution_id': distributionId,
    'rationale': rationale,
    'prespecified_at_utc': prespecifiedAtUtc,
  };

  String get scenarioSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'scenario_sha256': scenarioSha256,
  };
}

final class AdaptiveOperatingCharacteristicsResult {
  final String scenarioId;
  final String scenarioSha256;
  final int repetitions;
  final int successCount;
  final int efficacyStopCount;
  final int futilityStopCount;
  final int maximumSampleCount;
  final int coverageCount;
  final int selectionCount;
  final int failureCount;
  final double successProbability;
  final double monteCarloStandardError;
  final double meanEstimate;
  final double bias;
  final double intervalCoverage;
  final double meanSampleSize;
  final double expectedDurationFraction;
  final double selectionProbability;

  const AdaptiveOperatingCharacteristicsResult({
    required this.scenarioId,
    required this.scenarioSha256,
    required this.repetitions,
    required this.successCount,
    required this.efficacyStopCount,
    required this.futilityStopCount,
    required this.maximumSampleCount,
    required this.coverageCount,
    required this.selectionCount,
    required this.failureCount,
    required this.successProbability,
    required this.monteCarloStandardError,
    required this.meanEstimate,
    required this.bias,
    required this.intervalCoverage,
    required this.meanSampleSize,
    required this.expectedDurationFraction,
    required this.selectionProbability,
  });

  AdaptiveOperatingCharacteristicsResult copyWith({
    String? scenarioId,
    String? scenarioSha256,
    int? repetitions,
    int? successCount,
    int? efficacyStopCount,
    int? futilityStopCount,
    int? maximumSampleCount,
    int? coverageCount,
    int? selectionCount,
    int? failureCount,
    double? successProbability,
    double? monteCarloStandardError,
    double? meanEstimate,
    double? bias,
    double? intervalCoverage,
    double? meanSampleSize,
    double? expectedDurationFraction,
    double? selectionProbability,
  }) => AdaptiveOperatingCharacteristicsResult(
    scenarioId: scenarioId ?? this.scenarioId,
    scenarioSha256: scenarioSha256 ?? this.scenarioSha256,
    repetitions: repetitions ?? this.repetitions,
    successCount: successCount ?? this.successCount,
    efficacyStopCount: efficacyStopCount ?? this.efficacyStopCount,
    futilityStopCount: futilityStopCount ?? this.futilityStopCount,
    maximumSampleCount: maximumSampleCount ?? this.maximumSampleCount,
    coverageCount: coverageCount ?? this.coverageCount,
    selectionCount: selectionCount ?? this.selectionCount,
    failureCount: failureCount ?? this.failureCount,
    successProbability: successProbability ?? this.successProbability,
    monteCarloStandardError:
        monteCarloStandardError ?? this.monteCarloStandardError,
    meanEstimate: meanEstimate ?? this.meanEstimate,
    bias: bias ?? this.bias,
    intervalCoverage: intervalCoverage ?? this.intervalCoverage,
    meanSampleSize: meanSampleSize ?? this.meanSampleSize,
    expectedDurationFraction:
        expectedDurationFraction ?? this.expectedDurationFraction,
    selectionProbability: selectionProbability ?? this.selectionProbability,
  );

  Map<String, Object?> get canonicalPayload => {
    'scenario_id': scenarioId,
    'scenario_sha256': scenarioSha256,
    'repetitions': repetitions,
    'success_count': successCount,
    'efficacy_stop_count': efficacyStopCount,
    'futility_stop_count': futilityStopCount,
    'maximum_sample_count': maximumSampleCount,
    'coverage_count': coverageCount,
    'selection_count': selectionCount,
    'failure_count': failureCount,
    'success_probability': successProbability,
    'monte_carlo_standard_error': monteCarloStandardError,
    'mean_estimate': meanEstimate,
    'bias': bias,
    'interval_coverage': intervalCoverage,
    'mean_sample_size': meanSampleSize,
    'expected_duration_fraction': expectedDurationFraction,
    'selection_probability': selectionProbability,
  };

  String get resultSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'result_sha256': resultSha256,
  };
}

final class AdaptiveDecisionOracleVector {
  final String vectorId;
  final double firstLookZ;
  final double finalLookZ;
  final AdaptiveDecisionAction expectedFirstAction;
  final AdaptiveDecisionAction expectedFinalAction;
  final String rationale;

  const AdaptiveDecisionOracleVector({
    required this.vectorId,
    required this.firstLookZ,
    required this.finalLookZ,
    required this.expectedFirstAction,
    required this.expectedFinalAction,
    required this.rationale,
  });

  AdaptiveDecisionOracleVector copyWith({
    double? firstLookZ,
    double? finalLookZ,
    AdaptiveDecisionAction? expectedFirstAction,
    AdaptiveDecisionAction? expectedFinalAction,
    String? rationale,
  }) => AdaptiveDecisionOracleVector(
    vectorId: vectorId,
    firstLookZ: firstLookZ ?? this.firstLookZ,
    finalLookZ: finalLookZ ?? this.finalLookZ,
    expectedFirstAction: expectedFirstAction ?? this.expectedFirstAction,
    expectedFinalAction: expectedFinalAction ?? this.expectedFinalAction,
    rationale: rationale ?? this.rationale,
  );

  Map<String, Object?> get canonicalPayload => {
    'vector_id': vectorId,
    'first_look_z': firstLookZ,
    'final_look_z': finalLookZ,
    'expected_first_action': expectedFirstAction.name,
    'expected_final_action': expectedFinalAction.name,
    'rationale': rationale,
  };

  String get vectorSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'vector_sha256': vectorSha256,
  };
}

final class CredibilityAdaptiveDesignSimulationPackage {
  static const String schema =
      'parkinsum.credibility-adaptive-design-simulation-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v6';

  final int schemaVersion;
  final String packageId;
  final CredibilityRandomizationInterimPackage randomizationPackage;
  final String randomizationPackageSha256;
  final String statisticalPackageSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final AdaptiveDecisionRuleContract contract;
  final AdaptiveSimulationSeedCustody custody;
  final List<AdaptiveSimulationScenario> scenarios;
  final List<AdaptiveOperatingCharacteristicsResult> results;
  final List<AdaptiveDecisionOracleVector> oracleVectors;
  final String simulationStartedAtUtc;
  final String simulationCompletedAtUtc;
  final bool allPrespecifiedResultsRetained;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityAdaptiveDesignSimulationPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.randomizationPackage,
    required this.randomizationPackageSha256,
    required this.statisticalPackageSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.contract,
    required this.custody,
    required List<AdaptiveSimulationScenario> scenarios,
    required List<AdaptiveOperatingCharacteristicsResult> results,
    required List<AdaptiveDecisionOracleVector> oracleVectors,
    required this.simulationStartedAtUtc,
    required this.simulationCompletedAtUtc,
    required this.allPrespecifiedResultsRetained,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : scenarios = List.unmodifiable(scenarios),
       results = List.unmodifiable(results),
       oracleVectors = List.unmodifiable(oracleVectors);

  CredibilityAdaptiveDesignSimulationPackage copyWith({
    int? schemaVersion,
    String? randomizationPackageSha256,
    String? statisticalPackageSha256,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    AdaptiveDecisionRuleContract? contract,
    AdaptiveSimulationSeedCustody? custody,
    List<AdaptiveSimulationScenario>? scenarios,
    List<AdaptiveOperatingCharacteristicsResult>? results,
    List<AdaptiveDecisionOracleVector>? oracleVectors,
    String? simulationStartedAtUtc,
    String? simulationCompletedAtUtc,
    bool? allPrespecifiedResultsRetained,
    bool? revoked,
    bool? syntheticDemoOnly,
    String? boundary,
  }) => CredibilityAdaptiveDesignSimulationPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    randomizationPackage: randomizationPackage,
    randomizationPackageSha256:
        randomizationPackageSha256 ?? this.randomizationPackageSha256,
    statisticalPackageSha256:
        statisticalPackageSha256 ?? this.statisticalPackageSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    contract: contract ?? this.contract,
    custody: custody ?? this.custody,
    scenarios: scenarios ?? this.scenarios,
    results: results ?? this.results,
    oracleVectors: oracleVectors ?? this.oracleVectors,
    simulationStartedAtUtc:
        simulationStartedAtUtc ?? this.simulationStartedAtUtc,
    simulationCompletedAtUtc:
        simulationCompletedAtUtc ?? this.simulationCompletedAtUtc,
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
    'randomization_package_sha256': randomizationPackageSha256,
    'statistical_package_sha256': statisticalPackageSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'contract': contract.toJson(),
    'seed_custody': custody.publicJson,
    'scenarios': scenarios.map((item) => item.toJson()).toList(),
    'results': results.map((item) => item.toJson()).toList(),
    'oracle_vectors': oracleVectors.map((item) => item.toJson()).toList(),
    'simulation_started_at_utc': simulationStartedAtUtc,
    'simulation_completed_at_utc': simulationCompletedAtUtc,
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

final class AdaptiveSimulationFinding {
  final AdaptiveSimulationFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  AdaptiveSimulationFinding({
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

final class AdaptiveSimulationGovernanceAssessment {
  final CredibilityAdaptiveDesignSimulationPackage package;
  final AdaptiveSimulationGovernanceStatus status;
  final List<AdaptiveSimulationFinding> findings;

  AdaptiveSimulationGovernanceAssessment._({
    required this.package,
    required this.status,
    required List<AdaptiveSimulationFinding> findings,
  }) : findings = List.unmodifiable(findings);

  bool get integrityVerified => findings.isEmpty;
  bool get canSupportClinicalOrRegulatoryClaim => false;

  Map<String, String> get lanes => {
    'designIdentity':
        _hasAny({
          AdaptiveSimulationFindingKind.schemaUnsupported,
          AdaptiveSimulationFindingKind.identityMismatch,
          AdaptiveSimulationFindingKind.contractIncomplete,
          AdaptiveSimulationFindingKind.prospectiveLockBroken,
          AdaptiveSimulationFindingKind.seedManifestMismatch,
        })
        ? 'blocked'
        : 'contentAddressed',
    'scenarioCoverage':
        _hasAny({
          AdaptiveSimulationFindingKind.scenarioCoverageIncomplete,
          AdaptiveSimulationFindingKind.scenarioMalformed,
          AdaptiveSimulationFindingKind.scenarioAddedAfterLock,
          AdaptiveSimulationFindingKind.resultMissingOrDuplicate,
          AdaptiveSimulationFindingKind.resultSuppressed,
        })
        ? 'incomplete'
        : 'twelvePrespecifiedFamilies',
    'monteCarloPrecision':
        _hasAny({
          AdaptiveSimulationFindingKind.monteCarloUnderpowered,
          AdaptiveSimulationFindingKind.resultArithmeticMismatch,
        })
        ? 'insufficient'
        : 'precisionBounded',
    'errorControl':
        _hasAny({
          AdaptiveSimulationFindingKind.typeOneErrorInflated,
          AdaptiveSimulationFindingKind.adaptationRuleDrift,
          AdaptiveSimulationFindingKind.decisionTimingDrift,
        })
        ? 'failed'
        : 'nullGridObserved',
    'powerAndBias':
        _hasAny({
          AdaptiveSimulationFindingKind.powerInsufficient,
          AdaptiveSimulationFindingKind.biasExcessive,
          AdaptiveSimulationFindingKind.coverageInsufficient,
        })
        ? 'held'
        : 'alternativeGridObserved',
    'sampleSizeAndSelection':
        _hasAny({
          AdaptiveSimulationFindingKind.sampleSizeInvalid,
          AdaptiveSimulationFindingKind.resultArithmeticMismatch,
        })
        ? 'invalid'
        : 'retained',
    'oracleAndAdjudication':
        _hasAny({
          AdaptiveSimulationFindingKind.oracleIncomplete,
          AdaptiveSimulationFindingKind.oracleMismatch,
          AdaptiveSimulationFindingKind.historyBroken,
          AdaptiveSimulationFindingKind.revocation,
        })
        ? 'blocked'
        : 'manufacturedCasesAgree',
  };

  bool _hasAny(Set<AdaptiveSimulationFindingKind> kinds) =>
      findings.any((item) => kinds.contains(item.kind));

  Map<String, int> get counts => {
    'scenarios': package.scenarios.length,
    'nullScenarios': package.scenarios
        .where((item) => item.nullCompatible)
        .length,
    'alternativeScenarios': package.scenarios
        .where((item) => !item.nullCompatible)
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

  Map<String, Object?> toJson() => {
    'package': package.toJson(),
    'status': status.name,
    'integrity_verified': integrityVerified,
    'lanes': lanes,
    'counts': counts,
    'maximum_monte_carlo_standard_error': maximumMonteCarloStandardError,
    'findings': findings.map((item) => item.toJson()).toList(),
    'can_support_clinical_or_regulatory_claim':
        canSupportClinicalOrRegulatoryClaim,
    'boundary': package.boundary,
  };
}

final class CredibilityAdaptiveDesignSimulationVerifier {
  static const Set<AdaptiveScenarioFamily> requiredScenarioFamilies = {
    AdaptiveScenarioFamily.nullNormal,
    AdaptiveScenarioFamily.nullVarianceGrid,
    AdaptiveScenarioFamily.alternativeNormal,
    AdaptiveScenarioFamily.boundaryEffect,
    AdaptiveScenarioFamily.heavyTail,
    AdaptiveScenarioFamily.correlatedEndpoints,
    AdaptiveScenarioFamily.timeTrend,
    AdaptiveScenarioFamily.delayedOutcome,
    AdaptiveScenarioFamily.missingAtRandom,
    AdaptiveScenarioFamily.nonAdherence,
    AdaptiveScenarioFamily.sparseData,
    AdaptiveScenarioFamily.modelMisspecification,
  };

  const CredibilityAdaptiveDesignSimulationVerifier();

  AdaptiveSimulationGovernanceAssessment verify(
    CredibilityAdaptiveDesignSimulationPackage package,
  ) {
    final findings = <AdaptiveSimulationFinding>[];
    _checkIdentity(package, findings);
    _checkContract(package, findings);
    _checkScenarios(package, findings);
    _checkResults(package, findings);
    _checkOracle(package, findings);
    if (package.revoked) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.revocation,
        'Adaptive simulation package was revoked.',
        [package.packageId],
      );
    }
    final unknownOnly =
        findings.isNotEmpty &&
        findings.every(
          (item) =>
              item.kind == AdaptiveSimulationFindingKind.schemaUnsupported ||
              item.kind == AdaptiveSimulationFindingKind.identityMismatch ||
              item.kind == AdaptiveSimulationFindingKind.malformedDigest,
        );
    final status = package.revoked
        ? AdaptiveSimulationGovernanceStatus.revoked
        : findings.isNotEmpty
        ? unknownOnly
              ? AdaptiveSimulationGovernanceStatus.unknown
              : AdaptiveSimulationGovernanceStatus.violated
        : !package.allPrespecifiedResultsRetained
        ? AdaptiveSimulationGovernanceStatus.held
        : AdaptiveSimulationGovernanceStatus.mechanicallyObserved;
    return AdaptiveSimulationGovernanceAssessment._(
      package: package,
      status: status,
      findings: findings,
    );
  }

  void _checkIdentity(
    CredibilityAdaptiveDesignSimulationPackage package,
    List<AdaptiveSimulationFinding> findings,
  ) {
    if (package.schemaVersion !=
        CredibilityAdaptiveDesignSimulationPackage.currentSchemaVersion) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.schemaUnsupported,
        'Unsupported adaptive-simulation package schema.',
        ['${package.schemaVersion}'],
      );
    }
    if (package.configurationSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedConfigurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            CredibilityEvidenceExecutionAttestation
                .expectedAlgorithmSourceBundleSha256 ||
        package.randomizationPackage.packageSha256 !=
            package.randomizationPackageSha256 ||
        package.randomizationPackage.statisticalPackageSha256 !=
            package.statisticalPackageSha256 ||
        package.randomizationPackage.configurationSha256 !=
            package.configurationSha256 ||
        package.randomizationPackage.algorithmSourceBundleSha256 !=
            package.algorithmSourceBundleSha256) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.identityMismatch,
        'Adaptive package is not bound to the governed randomization, statistical and runtime identities.',
        const [
          'randomization',
          'statistics',
          'configuration',
          'algorithm_source_bundle',
        ],
      );
    }
    for (final entry in <String, String>{
      'randomization_package': package.randomizationPackageSha256,
      'statistical_package': package.statisticalPackageSha256,
      'configuration': package.configurationSha256,
      'algorithm_source_bundle': package.algorithmSourceBundleSha256,
      'analysis_model': package.contract.analysisModelSha256,
      'decision_rule_code': package.contract.decisionRuleCodeSha256,
      'seed_manifest': package.contract.seedManifestSha256,
      'scenario_catalog': package.contract.scenarioCatalogSha256,
    }.entries) {
      if (!_isSha256(entry.value)) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.malformedDigest,
          'Malformed ${entry.key} identity.',
          [entry.key],
        );
      }
    }
  }

  void _checkContract(
    CredibilityAdaptiveDesignSimulationPackage package,
    List<AdaptiveSimulationFinding> findings,
  ) {
    final contract = package.contract;
    final governedBoundaries =
        package.randomizationPackage.boundaryPlan.boundaries;
    final requiredText = [
      contract.contractId,
      contract.randomNumberGeneratorId,
      contract.boundary,
    ];
    if (requiredText.any((item) => item.trim().isEmpty) ||
        contract.adaptationIds.toSet().length !=
            contract.adaptationIds.length ||
        !contract.adaptationIds.contains('early_efficacy') ||
        !contract.adaptationIds.contains('nonbinding_futility') ||
        contract.informationFractions.length != 2 ||
        contract.efficacyZBoundaries.length != 2 ||
        contract.futilityZBoundaries.length != 2 ||
        contract.minimumSampleSize <= 0 ||
        contract.maximumSampleSize <= contract.minimumSampleSize ||
        contract.oneSidedAlpha <= 0 ||
        contract.oneSidedAlpha >= 0.5 ||
        contract.targetPower <= 0.5 ||
        contract.targetPower >= 1) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.contractIncomplete,
        'Adaptive decision contract is incomplete or internally invalid.',
        [contract.contractId],
      );
    }
    if (contract.informationFractions.any(
          (item) => !item.isFinite || item <= 0 || item > 1,
        ) ||
        contract.informationFractions.first >=
            contract.informationFractions.last ||
        (contract.informationFractions.last - 1).abs() > 1e-12 ||
        contract.efficacyZBoundaries.any((item) => !item.isFinite) ||
        contract.futilityZBoundaries.any((item) => !item.isFinite)) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.decisionTimingDrift,
        'Look timing or decision boundaries are not finite, increasing, and final at full information.',
        [contract.contractId],
      );
    }
    final governedInformationFractions = governedBoundaries
        .map((item) => item.informationFraction)
        .toList(growable: false);
    if (!_sameDoubleList(
      contract.informationFractions,
      governedInformationFractions,
    )) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.decisionTimingDrift,
        'Simulation look timing no longer matches the prospectively governed interim-boundary plan.',
        [contract.contractId, package.randomizationPackage.boundaryPlan.planId],
      );
    }
    final governedEfficacyBoundaries = governedBoundaries
        .map((item) => item.efficacyBoundary)
        .toList(growable: false);
    final governedFutilityBoundaries = governedBoundaries
        .map((item) => item.futilityBoundary)
        .toList(growable: false);
    if (!_sameDoubleList(
          contract.efficacyZBoundaries,
          governedEfficacyBoundaries,
        ) ||
        !_sameDoubleList(
          contract.futilityZBoundaries,
          governedFutilityBoundaries,
        )) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.adaptationRuleDrift,
        'Simulation decision thresholds no longer match the prospectively governed interim-boundary plan.',
        [contract.contractId, package.randomizationPackage.boundaryPlan.planId],
      );
    }
    if (contract.efficacyZBoundaries.first <=
            contract.efficacyZBoundaries.last ||
        contract.futilityZBoundaries.first >=
            contract.efficacyZBoundaries.first ||
        contract.futilityZBoundaries.last >=
            contract.efficacyZBoundaries.last) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.adaptationRuleDrift,
        'Efficacy and futility rules no longer preserve the reviewed group-sequential ordering.',
        [contract.contractId],
      );
    }
    if (contract.seedManifestSha256 != package.custody.seedManifestSha256) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.seedManifestMismatch,
        'Simulation seed custody no longer matches the locked seed manifest.',
        [contract.contractId],
      );
    }
    final authored = _parseUtc(contract.authoredAtUtc);
    final locked = _parseUtc(contract.lockedAtUtc);
    final started = _parseUtc(package.simulationStartedAtUtc);
    final completed = _parseUtc(package.simulationCompletedAtUtc);
    final firstVisible = _parseUtc(contract.firstResultVisibleAtUtc);
    if (authored == null ||
        locked == null ||
        started == null ||
        completed == null ||
        firstVisible == null ||
        locked.isBefore(authored) ||
        !started.isAfter(locked) ||
        completed.isBefore(started) ||
        firstVisible.isBefore(completed)) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.prospectiveLockBroken,
        'Contract, simulation, and first-result chronology is not prospectively ordered.',
        [contract.contractId],
      );
    }
  }

  bool _sameDoubleList(List<double> left, List<double> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if ((left[index] - right[index]).abs() > 1e-12) return false;
    }
    return true;
  }

  void _checkScenarios(
    CredibilityAdaptiveDesignSimulationPackage package,
    List<AdaptiveSimulationFinding> findings,
  ) {
    final ids = <String>{};
    final families = <AdaptiveScenarioFamily>{};
    final locked = _parseUtc(package.contract.lockedAtUtc);
    for (final scenario in package.scenarios) {
      if (!ids.add(scenario.scenarioId)) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.scenarioCoverageIncomplete,
          'Duplicate scenario identity.',
          [scenario.scenarioId],
        );
      }
      families.add(scenario.family);
      final prespecified = _parseUtc(scenario.prespecifiedAtUtc);
      if (locked == null ||
          prespecified == null ||
          prespecified.isAfter(locked)) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.scenarioAddedAfterLock,
          'Scenario was not retained as prospectively specified.',
          [scenario.scenarioId],
        );
      }
      final finite = [
        scenario.trueStandardizedEffect,
        scenario.varianceMultiplier,
        scenario.missingRate,
        scenario.nonAdherenceRate,
        scenario.timeTrend,
        scenario.delayedOutcomeFraction,
        scenario.endpointCorrelation,
        scenario.minimumAcceptablePower,
        scenario.maximumAbsoluteBias,
        scenario.minimumCoverage,
      ].every((item) => item.isFinite);
      if (!finite ||
          scenario.scenarioId.trim().isEmpty ||
          scenario.distributionId.trim().isEmpty ||
          scenario.rationale.trim().isEmpty ||
          scenario.varianceMultiplier <= 0 ||
          scenario.missingRate < 0 ||
          scenario.missingRate >= 1 ||
          scenario.nonAdherenceRate < 0 ||
          scenario.nonAdherenceRate >= 1 ||
          scenario.delayedOutcomeFraction < 0 ||
          scenario.delayedOutcomeFraction >= 1 ||
          scenario.endpointCorrelation.abs() >= 1 ||
          scenario.minimumCoverage < 0.8 ||
          scenario.minimumCoverage > 1 ||
          (scenario.nullCompatible &&
              scenario.trueStandardizedEffect.abs() > 1e-12)) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.scenarioMalformed,
          'Scenario parameters are incomplete, nonfinite, or incompatible with their declared family.',
          [scenario.scenarioId],
        );
      }
      final minimumRepetitions = scenario.nullCompatible ? 100000 : 50000;
      if (scenario.repetitions < minimumRepetitions) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.monteCarloUnderpowered,
          'Scenario has fewer prospectively required repetitions.',
          [scenario.scenarioId],
        );
      }
    }
    final missing = requiredScenarioFamilies.difference(families);
    if (missing.isNotEmpty || package.scenarios.length != 12) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.scenarioCoverageIncomplete,
        'The twelve-family null, alternative, operational and misspecification grid is incomplete.',
        missing.map((item) => item.name).toList(),
      );
    }
    final expectedCatalogSha256 = _sha256(
      package.scenarios.map((item) => item.toJson()).toList(),
    );
    if (package.contract.scenarioCatalogSha256 != expectedCatalogSha256) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.historyBroken,
        'Scenario catalog identity drifted after the decision contract was locked.',
        [package.contract.contractId],
      );
    }
  }

  void _checkResults(
    CredibilityAdaptiveDesignSimulationPackage package,
    List<AdaptiveSimulationFinding> findings,
  ) {
    final byScenario = <String, List<AdaptiveOperatingCharacteristicsResult>>{};
    for (final result in package.results) {
      byScenario.putIfAbsent(result.scenarioId, () => []).add(result);
    }
    for (final scenario in package.scenarios) {
      final matches = byScenario[scenario.scenarioId] ?? const [];
      if (matches.length != 1) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.resultMissingOrDuplicate,
          'Every prespecified scenario requires exactly one retained result.',
          [scenario.scenarioId],
        );
        continue;
      }
      final result = matches.single;
      if (result.scenarioSha256 != scenario.scenarioSha256 ||
          result.repetitions != scenario.repetitions) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.resultIdentityMismatch,
          'Result is not bound to the exact scenario and repetition contract.',
          [scenario.scenarioId],
        );
      }
      final allFinite = [
        result.successProbability,
        result.monteCarloStandardError,
        result.meanEstimate,
        result.bias,
        result.intervalCoverage,
        result.meanSampleSize,
        result.expectedDurationFraction,
        result.selectionProbability,
      ].every((item) => item.isFinite);
      final expectedSuccess = result.successCount / result.repetitions;
      final expectedMcse = math.sqrt(
        expectedSuccess * (1 - expectedSuccess) / result.repetitions,
      );
      final expectedCoverage = result.coverageCount / result.repetitions;
      final expectedSelection = result.selectionCount / result.repetitions;
      final decisionCount =
          result.efficacyStopCount +
          result.futilityStopCount +
          result.maximumSampleCount;
      if (!allFinite ||
          result.repetitions <= 0 ||
          result.successCount < 0 ||
          result.successCount > result.repetitions ||
          result.failureCount < 0 ||
          decisionCount + result.failureCount != result.repetitions ||
          (result.successProbability - expectedSuccess).abs() > 1e-12 ||
          (result.monteCarloStandardError - expectedMcse).abs() > 1e-12 ||
          (result.intervalCoverage - expectedCoverage).abs() > 1e-12 ||
          (result.selectionProbability - expectedSelection).abs() > 1e-12 ||
          (result.bias -
                      (result.meanEstimate - scenario.trueStandardizedEffect))
                  .abs() >
              1e-12) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.resultArithmeticMismatch,
          'Retained counts, probabilities, bias, coverage, selection or MCSE do not reconcile.',
          [scenario.scenarioId],
        );
      }
      if (result.failureCount > 0 || !package.allPrespecifiedResultsRetained) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.resultSuppressed,
          'Simulation failures or omitted prespecified results remain unresolved.',
          [scenario.scenarioId],
        );
      }
      final upper95 =
          result.successProbability + 1.96 * result.monteCarloStandardError;
      final lower95 =
          result.successProbability - 1.96 * result.monteCarloStandardError;
      if (scenario.nullCompatible && upper95 > 0.03) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.typeOneErrorInflated,
          'Null-compatible scenario exceeds the prespecified conservative Type-I error envelope.',
          [scenario.scenarioId],
        );
      }
      if (!scenario.nullCompatible &&
          lower95 < scenario.minimumAcceptablePower) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.powerInsufficient,
          'Alternative scenario power is below its prespecified lower confidence bound.',
          [scenario.scenarioId],
        );
      }
      if (result.bias.abs() > scenario.maximumAbsoluteBias) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.biasExcessive,
          'Treatment-effect estimate bias exceeds the scenario contract.',
          [scenario.scenarioId],
        );
      }
      if (result.intervalCoverage < scenario.minimumCoverage) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.coverageInsufficient,
          'Interval coverage is below the scenario contract.',
          [scenario.scenarioId],
        );
      }
      if (result.meanSampleSize < package.contract.minimumSampleSize ||
          result.meanSampleSize > package.contract.maximumSampleSize ||
          result.expectedDurationFraction <= 0 ||
          result.expectedDurationFraction > 1 ||
          result.selectionProbability < 0 ||
          result.selectionProbability > 1) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.sampleSizeInvalid,
          'Sample-size, duration or selection operating characteristic is invalid.',
          [scenario.scenarioId],
        );
      }
      if (result.monteCarloStandardError > 0.0025) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.monteCarloUnderpowered,
          'Monte Carlo standard error exceeds the reviewed precision budget.',
          [scenario.scenarioId],
        );
      }
    }
    final extras = byScenario.keys.toSet().difference(
      package.scenarios.map((item) => item.scenarioId).toSet(),
    );
    if (extras.isNotEmpty) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.resultSuppressed,
        'Unprespecified result identities were added after the scenario lock.',
        extras.toList(),
      );
    }
  }

  void _checkOracle(
    CredibilityAdaptiveDesignSimulationPackage package,
    List<AdaptiveSimulationFinding> findings,
  ) {
    final requiredIds = {
      'interim-efficacy',
      'interim-futility',
      'interim-continue-final-efficacy',
      'interim-continue-final-null',
      'boundary-equality',
    };
    final ids = package.oracleVectors.map((item) => item.vectorId).toSet();
    if (package.oracleVectors.length != requiredIds.length ||
        !ids.containsAll(requiredIds)) {
      _add(
        findings,
        AdaptiveSimulationFindingKind.oracleIncomplete,
        'Manufactured decision-rule oracle vectors are incomplete.',
        requiredIds.difference(ids).toList(),
      );
    }
    for (final vector in package.oracleVectors) {
      final first = _oracleDecision(
        z: vector.firstLookZ,
        lookIndex: 0,
        contract: package.contract,
      );
      final finalAction = first == AdaptiveDecisionAction.continueToNextLook
          ? _oracleDecision(
              z: vector.finalLookZ,
              lookIndex: 1,
              contract: package.contract,
            )
          : first;
      if (first != vector.expectedFirstAction ||
          finalAction != vector.expectedFinalAction) {
        _add(
          findings,
          AdaptiveSimulationFindingKind.oracleMismatch,
          'Independently restated manufactured decision case disagrees with the retained expectation.',
          [vector.vectorId],
        );
      }
    }
  }

  AdaptiveDecisionAction _oracleDecision({
    required double z,
    required int lookIndex,
    required AdaptiveDecisionRuleContract contract,
  }) {
    if (z >= contract.efficacyZBoundaries[lookIndex]) {
      return AdaptiveDecisionAction.efficacy;
    }
    if (lookIndex == 0 && z <= contract.futilityZBoundaries[lookIndex]) {
      return AdaptiveDecisionAction.futility;
    }
    return lookIndex == contract.informationFractions.length - 1
        ? AdaptiveDecisionAction.completeNoEfficacy
        : AdaptiveDecisionAction.continueToNextLook;
  }

  void _add(
    List<AdaptiveSimulationFinding> findings,
    AdaptiveSimulationFindingKind kind,
    String detail,
    List<String> affectedIds,
  ) {
    findings.add(
      AdaptiveSimulationFinding(
        kind: kind,
        detail: detail,
        affectedIds: affectedIds,
      ),
    );
  }
}

DateTime? _parseUtc(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.endsWith('Z')) return null;
  return parsed.toUtc();
}

bool _isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

Object? _canonicalize(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    return value;
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return <String, Object?>{
      for (final entry in entries) entry.key: _canonicalize(entry.value),
    };
  }
  throw ArgumentError.value(value, 'value', 'must be JSON-compatible');
}
