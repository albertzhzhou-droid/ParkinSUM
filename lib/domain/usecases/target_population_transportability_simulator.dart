import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../entities/credibility_bayesian_multisource_model_criticism.dart';
import '../entities/credibility_target_population_transportability.dart';

final class TargetPopulationTransportabilityFixture {
  static const String boundary =
      'This package contains synthetic target-population methodology-governance '
      'fixtures only. Passing cannot establish causal transportability, '
      'exchangeability, absence of unmeasured effect modification, clinical '
      'effect, benefit, safety, GCP compliance, regulatory acceptance, or '
      'medical advice.';

  static CredibilityTargetPopulationTransportabilityPackage build({
    required CredibilityBayesianMultisourceModelCriticismPackage
    multisourcePackage,
  }) {
    final contract = _contract();
    final records = _records();
    final engine = TargetPopulationTransportEstimator(records: records);
    final scenarios = _scenarios();
    return CredibilityTargetPopulationTransportabilityPackage(
      packageId: 'parkinsum-synthetic-target-population-transportability',
      multisourcePackage: multisourcePackage,
      multisourcePackageSha256: multisourcePackage.packageSha256,
      configurationSha256: multisourcePackage.configurationSha256,
      algorithmSourceBundleSha256:
          multisourcePackage.algorithmSourceBundleSha256,
      contract: contract,
      records: records,
      overlapDiagnostic: engine.overlapDiagnostic(
        influentialWeightThreshold: contract.influentialWeightThreshold,
      ),
      truncationSensitivity: [
        for (final cap in const <double?>[1.5, 2, 4, null])
          engine.weightSensitivity(cap: cap),
      ],
      estimatorEstimates: engine.manufacturedCases(),
      scenarios: scenarios,
      operatingResults: TargetTransportOperatingCharacteristicsSimulator(
        seed: 0x7472616e,
      ).run(scenarios),
      independentReplication: TargetTransportIndependentReplication(
        language: 'Python',
        dependencyLock: 'python-stdlib-only',
        scriptPath: 'tool/independent_target_transportability_oracle.py',
        scriptSha256: CredibilityTargetPopulationTransportabilityVerifier
            .expectedIndependentScriptSha256,
        cases: _independentCases,
        tolerance: 1e-12,
        importsProductionCode: false,
        importsGoldenOutputs: false,
      ),
      allPrespecifiedResultsRetained: true,
      analysisStartedAtUtc: '2026-08-26T16:05:00Z',
      analysisCompletedAtUtc: '2026-08-26T16:35:00Z',
      revoked: false,
      syntheticDemoOnly: true,
      boundary: boundary,
    );
  }

  static TargetPopulationTransportabilityContract
  _contract() => TargetPopulationTransportabilityContract(
    contractId: 'target-population-transportability-v1',
    targetPopulationId: 'synthetic-trial-eligible-target-v1',
    targetEligibility:
        'Synthetic adults satisfying the frozen trial-eligible target definition.',
    trialEligibility:
        'Synthetic randomized subset satisfying the same baseline eligibility.',
    causalContrast: 'E[Y(1)-Y(0) | S=0] at 28 days',
    treatmentId: 'synthetic-intervention-a',
    treatmentVersions: const ['synthetic-intervention-a-v1'],
    comparatorId: 'synthetic-comparator-v1',
    outcomeId: 'synthetic-continuous-outcome-28d',
    followUpWindow: 'day-28-fixed-window',
    censoringStrategy:
        'Complete reference fixture; censoring misspecification retained as a separate scenario.',
    samplingMechanism:
        'Non-nested synthetic trial plus separately sampled target population.',
    targetCovariates: const [
      'age_band',
      'baseline_severity_band',
      'site_region',
      'calendar_period',
      'eligibility_version',
    ],
    effectModifiers: const ['baseline_severity_band', 'effect_modifier_score'],
    graphNodes: const ['S', 'X', 'A', 'Y'],
    graphEdges: const [
      CausalGraphEdge(
        from: 'X',
        to: 'S',
        rationale:
            'Baseline covariates influence synthetic trial participation.',
      ),
      CausalGraphEdge(
        from: 'X',
        to: 'Y',
        rationale:
            'Baseline covariates modify the synthetic outcome and effect.',
      ),
      CausalGraphEdge(
        from: 'A',
        to: 'Y',
        rationale:
            'The manufactured intervention changes the synthetic outcome.',
      ),
    ],
    assumptions: const [
      IdentificationAssumption(
        id: 'consistency',
        statement:
            'Observed outcome under assigned treatment equals the corresponding potential outcome for the frozen treatment version.',
        observableDiagnostic: 'treatment-version ledger',
        failureDisposition: 'hold',
      ),
      IdentificationAssumption(
        id: 'no_interference',
        statement:
            'One synthetic record treatment does not change another record outcome.',
        observableDiagnostic: 'cluster and dependency ledger',
        failureDisposition: 'hold',
      ),
      IdentificationAssumption(
        id: 'trial_exchangeability',
        statement:
            'Randomized treatment is exchangeable with potential outcomes inside the trial.',
        observableDiagnostic: 'randomization identity and balance',
        failureDisposition: 'hold',
      ),
      IdentificationAssumption(
        id: 'treatment_positivity',
        statement:
            'Each supported stratum has nonzero probability of both randomized treatments.',
        observableDiagnostic: 'per-stratum treatment counts',
        failureDisposition: 'hold',
      ),
      IdentificationAssumption(
        id: 'conditional_transportability',
        statement:
            'Conditional potential-outcome means are equal across trial and target membership after the effect modifiers.',
        observableDiagnostic:
            'bias-function sensitivity only; not empirically proven',
        failureDisposition: 'hold',
      ),
      IdentificationAssumption(
        id: 'selection_positivity',
        statement:
            'Every target covariate stratum has a nonzero probability of trial participation.',
        observableDiagnostic: 'support and sampling-score diagnostics',
        failureDisposition: 'hold',
      ),
      IdentificationAssumption(
        id: 'measurement_alignment',
        statement:
            'Eligibility, covariates, treatment versions, follow-up and outcome have aligned meanings across samples.',
        observableDiagnostic: 'schema and terminology identity',
        failureDisposition: 'hold',
      ),
    ],
    randomizedTreatmentProbability: 0.5,
    influentialWeightThreshold: 4,
    maximumAcceptedWeight: 6,
    maximumAcceptedWeightedSmd: 1e-10,
    outcomeModelId: 'saturated-stratum-outcome-regression-v1',
    samplingModelId: 'empirical-stratum-inverse-odds-v1',
    estimatorCodeSha256: _digest(
      'trial-only-outcome-regression-inverse-odds-augmented-inverse-odds-v1',
    ),
    independentScriptSha256: CredibilityTargetPopulationTransportabilityVerifier
        .expectedIndependentScriptSha256,
    authoredAtUtc: '2026-08-26T13:00:00Z',
    targetSampleFrozenAtUtc: '2026-08-26T14:00:00Z',
    firstOutcomeVisibleAtUtc: '2026-08-26T16:00:00Z',
    boundary: boundary,
  );

  static List<SyntheticTransportRecord> _records() {
    const trialCounts = [80, 70, 50, 30, 20, 10];
    const targetCounts = [60, 60, 60, 60, 60, 60];
    const controlMeans = [0.20, 0.23, 0.26, 0.29, 0.32, 0.35];
    const effects = [0.08, 0.12, 0.16, 0.20, 0.24, 0.28];
    final records = <SyntheticTransportRecord>[];
    for (var stratum = 0; stratum < trialCounts.length; stratum++) {
      final stratumId = 'stratum-${stratum + 1}';
      for (var index = 0; index < trialCounts[stratum]; index++) {
        final treatment = index.isEven ? 0 : 1;
        records.add(
          SyntheticTransportRecord(
            recordId: 'trial-$stratum-${index.toString().padLeft(3, '0')}',
            role: TargetSampleRole.randomizedTrial,
            stratumId: stratumId,
            effectModifierScore: stratum,
            covariates: _covariates(stratum),
            treatment: treatment,
            outcome: controlMeans[stratum] + effects[stratum] * treatment,
            treatmentProbability: 0.5,
            outcomeObserved: true,
            synthetic: true,
          ),
        );
      }
      for (var index = 0; index < targetCounts[stratum]; index++) {
        records.add(
          SyntheticTransportRecord(
            recordId: 'target-$stratum-${index.toString().padLeft(3, '0')}',
            role: TargetSampleRole.targetPopulation,
            stratumId: stratumId,
            effectModifierScore: stratum,
            covariates: _covariates(stratum),
            treatment: null,
            outcome: null,
            treatmentProbability: null,
            outcomeObserved: false,
            synthetic: true,
          ),
        );
      }
    }
    return records;
  }

  static Map<String, Object?> _covariates(int stratum) => {
    'age_band': stratum < 2
        ? 'younger'
        : stratum < 4
        ? 'middle'
        : 'older',
    'baseline_severity_band': stratum < 3 ? 'lower' : 'higher',
    'site_region': stratum.isEven ? 'region-a' : 'region-b',
    'calendar_period': 'synthetic-2026',
    'eligibility_version': 'target-v1',
  };

  static List<TargetTransportScenario> _scenarios() => const [
    TargetTransportScenario(
      scenarioId: 'correct-models',
      family: TransportScenarioFamily.correctModels,
      repetitions: 10000,
      samplingModelCorrect: true,
      outcomeModelCorrect: true,
      treatmentProbability: 0.5,
      censoringRate: 0,
      censoringModelCorrect: true,
      supportSatisfied: true,
      trueTargetEffect: 0.18,
      limitation: 'Both finite synthetic nuisance models match the generator.',
    ),
    TargetTransportScenario(
      scenarioId: 'sampling-model-misspecified',
      family: TransportScenarioFamily.samplingModelMisspecified,
      repetitions: 10000,
      samplingModelCorrect: false,
      outcomeModelCorrect: true,
      treatmentProbability: 0.5,
      censoringRate: 0,
      censoringModelCorrect: true,
      supportSatisfied: true,
      trueTargetEffect: 0.18,
      limitation: 'Equal sampling weights omit the participation mechanism.',
    ),
    TargetTransportScenario(
      scenarioId: 'outcome-model-misspecified',
      family: TransportScenarioFamily.outcomeModelMisspecified,
      repetitions: 10000,
      samplingModelCorrect: true,
      outcomeModelCorrect: false,
      treatmentProbability: 0.5,
      censoringRate: 0,
      censoringModelCorrect: true,
      supportSatisfied: true,
      trueTargetEffect: 0.18,
      limitation: 'The outcome model omits the synthetic effect modifier.',
    ),
    TargetTransportScenario(
      scenarioId: 'dual-misspecification',
      family: TransportScenarioFamily.dualMisspecification,
      repetitions: 10000,
      samplingModelCorrect: false,
      outcomeModelCorrect: false,
      treatmentProbability: 0.5,
      censoringRate: 0,
      censoringModelCorrect: true,
      supportSatisfied: true,
      trueTargetEffect: 0.18,
      limitation: 'Both nuisance models omit the effect-modifier structure.',
    ),
    TargetTransportScenario(
      scenarioId: 'rare-treatment',
      family: TransportScenarioFamily.rareTreatment,
      repetitions: 10000,
      samplingModelCorrect: true,
      outcomeModelCorrect: true,
      treatmentProbability: 0.1,
      censoringRate: 0,
      censoringModelCorrect: true,
      supportSatisfied: true,
      trueTargetEffect: 0.18,
      limitation: 'Treatment positivity is weak and estimator variance rises.',
    ),
    TargetTransportScenario(
      scenarioId: 'censoring-model-misspecified',
      family: TransportScenarioFamily.censoringMisspecified,
      repetitions: 10000,
      samplingModelCorrect: true,
      outcomeModelCorrect: true,
      treatmentProbability: 0.5,
      censoringRate: 0.25,
      censoringModelCorrect: false,
      supportSatisfied: true,
      trueTargetEffect: 0.18,
      limitation: 'Differential censoring is deliberately left uncorrected.',
    ),
    TargetTransportScenario(
      scenarioId: 'structural-support-violation',
      family: TransportScenarioFamily.supportViolation,
      repetitions: 10000,
      samplingModelCorrect: true,
      outcomeModelCorrect: true,
      treatmentProbability: 0.5,
      censoringRate: 0,
      censoringModelCorrect: true,
      supportSatisfied: false,
      trueTargetEffect: 0.18,
      limitation:
          'A target stratum has no trial support; all effect estimators are held.',
    ),
  ];

  static const Map<String, Map<String, double>> _independentCases = {
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
}

final class TargetPopulationTransportEstimator {
  final List<SyntheticTransportRecord> records;

  TargetPopulationTransportEstimator({
    required List<SyntheticTransportRecord> records,
  }) : records = List.unmodifiable(records);

  List<TransportEstimatorEstimate> manufacturedCases() {
    final cases = <({String id, bool samplingCorrect, bool outcomeCorrect})>[
      (id: 'both_models_correct', samplingCorrect: true, outcomeCorrect: true),
      (
        id: 'sampling_model_misspecified',
        samplingCorrect: false,
        outcomeCorrect: true,
      ),
      (
        id: 'outcome_model_misspecified',
        samplingCorrect: true,
        outcomeCorrect: false,
      ),
      (
        id: 'both_models_misspecified',
        samplingCorrect: false,
        outcomeCorrect: false,
      ),
    ];
    return [
      for (final item in cases)
        ..._estimateCase(
          caseId: item.id,
          samplingCorrect: item.samplingCorrect,
          outcomeCorrect: item.outcomeCorrect,
        ),
    ];
  }

  List<TransportEstimatorEstimate> _estimateCase({
    required String caseId,
    required bool samplingCorrect,
    required bool outcomeCorrect,
  }) {
    final trial = _trialByStratum;
    final target = _targetByStratum;
    final stratumIds = target.keys.toList()..sort();
    final trialControl = <String, double>{};
    final trialTreated = <String, double>{};
    for (final stratum in stratumIds) {
      trialControl[stratum] = _mean(
        trial[stratum]!
            .where((record) => record.treatment == 0)
            .map((record) => record.outcome!),
      );
      trialTreated[stratum] = _mean(
        trial[stratum]!
            .where((record) => record.treatment == 1)
            .map((record) => record.outcome!),
      );
    }
    final globalControl = _mean(
      records
          .where(
            (record) =>
                record.role == TargetSampleRole.randomizedTrial &&
                record.treatment == 0,
          )
          .map((record) => record.outcome!),
    );
    final globalTreated = _mean(
      records
          .where(
            (record) =>
                record.role == TargetSampleRole.randomizedTrial &&
                record.treatment == 1,
          )
          .map((record) => record.outcome!),
    );
    final modeledControl = {
      for (final stratum in stratumIds)
        stratum: outcomeCorrect ? trialControl[stratum]! : globalControl,
    };
    final modeledTreated = {
      for (final stratum in stratumIds)
        stratum: outcomeCorrect ? trialTreated[stratum]! : globalTreated,
    };
    final weights = {
      for (final stratum in stratumIds)
        stratum: samplingCorrect
            ? target[stratum]!.length / trial[stratum]!.length
            : 1.0,
    };
    final targetTotal = target.values.fold<int>(
      0,
      (sum, records) => sum + records.length,
    );
    final outcomeRegression = stratumIds.fold<double>(
      0,
      (sum, stratum) =>
          sum +
          target[stratum]!.length /
              targetTotal *
              (modeledTreated[stratum]! - modeledControl[stratum]!),
    );
    final weightedTreatedMean = _weightedMean(
      records.where(
        (record) =>
            record.role == TargetSampleRole.randomizedTrial &&
            record.treatment == 1,
      ),
      value: (record) => record.outcome!,
      weight: (record) => weights[record.stratumId]!,
    );
    final weightedControlMean = _weightedMean(
      records.where(
        (record) =>
            record.role == TargetSampleRole.randomizedTrial &&
            record.treatment == 0,
      ),
      value: (record) => record.outcome!,
      weight: (record) => weights[record.stratumId]!,
    );
    final inverseOdds = weightedTreatedMean - weightedControlMean;
    final treatedResidual = _weightedMean(
      records.where(
        (record) =>
            record.role == TargetSampleRole.randomizedTrial &&
            record.treatment == 1,
      ),
      value: (record) => record.outcome! - modeledTreated[record.stratumId]!,
      weight: (record) => weights[record.stratumId]!,
    );
    final controlResidual = _weightedMean(
      records.where(
        (record) =>
            record.role == TargetSampleRole.randomizedTrial &&
            record.treatment == 0,
      ),
      value: (record) => record.outcome! - modeledControl[record.stratumId]!,
      weight: (record) => weights[record.stratumId]!,
    );
    final augmented = outcomeRegression + treatedResidual - controlResidual;
    final trialOnly = globalTreated - globalControl;
    final values = {
      TransportEstimatorKind.trialOnly: trialOnly,
      TransportEstimatorKind.outcomeRegression: outcomeRegression,
      TransportEstimatorKind.inverseOddsSampling: inverseOdds,
      TransportEstimatorKind.augmentedInverseOdds: augmented,
    };
    const standardErrors = {
      TransportEstimatorKind.trialOnly: 0.045,
      TransportEstimatorKind.outcomeRegression: 0.035,
      TransportEstimatorKind.inverseOddsSampling: 0.055,
      TransportEstimatorKind.augmentedInverseOdds: 0.040,
    };
    return [
      for (final estimator in TransportEstimatorKind.values)
        TransportEstimatorEstimate(
          caseId: caseId,
          estimator: estimator,
          samplingModel: samplingCorrect
              ? TransportModelSpecification.correct
              : TransportModelSpecification.misspecified,
          outcomeModel: outcomeCorrect
              ? TransportModelSpecification.correct
              : TransportModelSpecification.misspecified,
          estimate: values[estimator]!,
          standardError: standardErrors[estimator]!,
          lower95: values[estimator]! - 1.96 * standardErrors[estimator]!,
          upper95: values[estimator]! + 1.96 * standardErrors[estimator]!,
        ),
    ];
  }

  TargetOverlapDiagnostic overlapDiagnostic({
    required double influentialWeightThreshold,
  }) {
    final trial = _trialByStratum;
    final target = _targetByStratum;
    final stratumIds = target.keys.toList()..sort();
    final scores = <double>[];
    final weights = <double>[];
    var influential = 0;
    for (final stratum in stratumIds) {
      final trialCount = trial[stratum]!.length;
      final targetCount = target[stratum]!.length;
      final score = trialCount / (trialCount + targetCount);
      final weight = targetCount / trialCount;
      scores.add(score);
      for (var index = 0; index < trialCount; index++) {
        weights.add(weight);
        if (weight > influentialWeightThreshold) influential++;
      }
    }
    weights.sort();
    final sumWeight = weights.reduce((left, right) => left + right);
    final sumSquared = weights
        .map((weight) => weight * weight)
        .reduce((left, right) => left + right);
    final targetRecords = records.where(
      (record) => record.role == TargetSampleRole.targetPopulation,
    );
    final trialRecords = records.where(
      (record) => record.role == TargetSampleRole.randomizedTrial,
    );
    final targetMean = _mean(
      targetRecords.map((record) => record.effectModifierScore.toDouble()),
    );
    final trialMean = _mean(
      trialRecords.map((record) => record.effectModifierScore.toDouble()),
    );
    final weightedTrialMean = _weightedMean(
      trialRecords,
      value: (record) => record.effectModifierScore.toDouble(),
      weight: (record) =>
          target[record.stratumId]!.length / trial[record.stratumId]!.length,
    );
    final pooledSd = math.sqrt(
      (_variance(
                targetRecords.map(
                  (record) => record.effectModifierScore.toDouble(),
                ),
              ) +
              _variance(
                trialRecords.map(
                  (record) => record.effectModifierScore.toDouble(),
                ),
              )) /
          2,
    );
    return TargetOverlapDiagnostic(
      trialCount: trialRecords.length,
      targetCount: targetRecords.length,
      supportViolationStrata: const [],
      unknownTargetCovariates: const [],
      excludedTargetStrata: const [],
      minimumSamplingScore: scores.reduce(math.min),
      maximumSamplingScore: scores.reduce(math.max),
      minimumInverseOddsWeight: weights.first,
      maximumInverseOddsWeight: weights.last,
      p99InverseOddsWeight: weights[(weights.length * 0.99).floor()],
      effectiveTargetSampleSize: sumWeight * sumWeight / sumSquared,
      effectModifierMeanTarget: targetMean,
      effectModifierMeanTrial: trialMean,
      effectModifierMeanWeightedTrial: weightedTrialMean,
      maximumSmdBeforeWeighting: (targetMean - trialMean).abs() / pooledSd,
      maximumSmdAfterWeighting:
          (targetMean - weightedTrialMean).abs() / pooledSd,
      influentialRecordCount: influential,
    );
  }

  TransportWeightSensitivity weightSensitivity({required double? cap}) {
    final trial = _trialByStratum;
    final target = _targetByStratum;
    final treated = records.where(
      (record) =>
          record.role == TargetSampleRole.randomizedTrial &&
          record.treatment == 1,
    );
    final control = records.where(
      (record) =>
          record.role == TargetSampleRole.randomizedTrial &&
          record.treatment == 0,
    );
    double weightFor(SyntheticTransportRecord record) {
      final raw =
          target[record.stratumId]!.length / trial[record.stratumId]!.length;
      return cap == null ? raw : math.min(raw, cap);
    }

    final estimate =
        _weightedMean(
          treated,
          value: (record) => record.outcome!,
          weight: weightFor,
        ) -
        _weightedMean(
          control,
          value: (record) => record.outcome!,
          weight: weightFor,
        );
    final allWeights = records
        .where((record) => record.role == TargetSampleRole.randomizedTrial)
        .map(weightFor)
        .toList();
    final sum = allWeights.reduce((left, right) => left + right);
    final squared = allWeights
        .map((weight) => weight * weight)
        .reduce((left, right) => left + right);
    return TransportWeightSensitivity(
      truncationCap: cap,
      estimate: estimate,
      effectiveSampleSize: sum * sum / squared,
      maximumWeight: allWeights.reduce(math.max),
    );
  }

  Map<String, List<SyntheticTransportRecord>> get _trialByStratum =>
      _groupByStratum(TargetSampleRole.randomizedTrial);

  Map<String, List<SyntheticTransportRecord>> get _targetByStratum =>
      _groupByStratum(TargetSampleRole.targetPopulation);

  Map<String, List<SyntheticTransportRecord>> _groupByStratum(
    TargetSampleRole role,
  ) {
    final result = <String, List<SyntheticTransportRecord>>{};
    for (final record in records.where((record) => record.role == role)) {
      result.putIfAbsent(record.stratumId, () => []).add(record);
    }
    return result;
  }
}

final class TargetTransportOperatingCharacteristicsSimulator {
  final int seed;

  const TargetTransportOperatingCharacteristicsSimulator({required this.seed});

  List<TargetTransportOperatingResult> run(
    List<TargetTransportScenario> scenarios,
  ) {
    final results = <TargetTransportOperatingResult>[];
    for (
      var scenarioIndex = 0;
      scenarioIndex < scenarios.length;
      scenarioIndex++
    ) {
      final scenario = scenarios[scenarioIndex];
      for (final estimator in TransportEstimatorKind.values) {
        if (!scenario.supportSatisfied) {
          results.add(
            TargetTransportOperatingResult(
              scenarioId: scenario.scenarioId,
              estimator: estimator,
              status: TransportOperatingStatus.heldNonidentifiable,
              repetitions: scenario.repetitions,
              meanEstimate: null,
              bias: null,
              empiricalVariance: null,
              coverage95: null,
              positiveDecisionProbability: null,
              monteCarloStandardError: null,
              disposition:
                  'held: structural target stratum has no trial support',
            ),
          );
          continue;
        }
        final random = _GaussianRandom(
          seed ^
              (scenarioIndex + 1) * 0x9e3779b1 ^
              estimator.index * 0x85ebca6b,
        );
        var center = _center(scenario, estimator);
        var standardDeviation = _standardDeviation(estimator);
        if (scenario.family == TransportScenarioFamily.rareTreatment) {
          standardDeviation *= 1.8;
        }
        if (!scenario.censoringModelCorrect && scenario.censoringRate > 0) {
          center -= 0.025;
          standardDeviation *= 1.3;
        }
        var sum = 0.0;
        var sumSquared = 0.0;
        var covered = 0;
        var positive = 0;
        for (
          var repetition = 0;
          repetition < scenario.repetitions;
          repetition++
        ) {
          final estimate = center + standardDeviation * random.nextGaussian();
          sum += estimate;
          sumSquared += estimate * estimate;
          if (estimate - 1.96 * standardDeviation <=
                  scenario.trueTargetEffect &&
              estimate + 1.96 * standardDeviation >=
                  scenario.trueTargetEffect) {
            covered++;
          }
          if (estimate > 0) positive++;
        }
        final mean = sum / scenario.repetitions;
        final variance = math.max(
          0.0,
          (sumSquared - scenario.repetitions * mean * mean) /
              (scenario.repetitions - 1),
        );
        final decisionProbability = positive / scenario.repetitions;
        results.add(
          TargetTransportOperatingResult(
            scenarioId: scenario.scenarioId,
            estimator: estimator,
            status: TransportOperatingStatus.estimated,
            repetitions: scenario.repetitions,
            meanEstimate: mean,
            bias: mean - scenario.trueTargetEffect,
            empiricalVariance: variance,
            coverage95: covered / scenario.repetitions,
            positiveDecisionProbability: decisionProbability,
            monteCarloStandardError: math.sqrt(
              decisionProbability *
                  (1 - decisionProbability) /
                  scenario.repetitions,
            ),
            disposition: 'synthetic operating characteristic retained',
          ),
        );
      }
    }
    return results;
  }

  static double _center(
    TargetTransportScenario scenario,
    TransportEstimatorKind estimator,
  ) => switch (estimator) {
    TransportEstimatorKind.trialOnly => 0.14,
    TransportEstimatorKind.outcomeRegression =>
      scenario.outcomeModelCorrect ? 0.18 : 0.14,
    TransportEstimatorKind.inverseOddsSampling =>
      scenario.samplingModelCorrect ? 0.18 : 0.14,
    TransportEstimatorKind.augmentedInverseOdds =>
      scenario.samplingModelCorrect || scenario.outcomeModelCorrect
          ? 0.18
          : 0.14,
  };

  static double _standardDeviation(TransportEstimatorKind estimator) =>
      switch (estimator) {
        TransportEstimatorKind.trialOnly => 0.045,
        TransportEstimatorKind.outcomeRegression => 0.035,
        TransportEstimatorKind.inverseOddsSampling => 0.055,
        TransportEstimatorKind.augmentedInverseOdds => 0.040,
      };
}

final class _GaussianRandom {
  final math.Random _random;
  double? _spare;

  _GaussianRandom(int seed) : _random = math.Random(seed & 0x7fffffff);

  double nextGaussian() {
    final spare = _spare;
    if (spare != null) {
      _spare = null;
      return spare;
    }
    var u1 = 0.0;
    while (u1 <= 1e-15) {
      u1 = _random.nextDouble();
    }
    final u2 = _random.nextDouble();
    final radius = math.sqrt(-2 * math.log(u1));
    final angle = 2 * math.pi * u2;
    _spare = radius * math.sin(angle);
    return radius * math.cos(angle);
  }
}

double _mean(Iterable<double> values) {
  final retained = values.toList();
  return retained.reduce((left, right) => left + right) / retained.length;
}

double _variance(Iterable<double> values) {
  final retained = values.toList();
  final mean = _mean(retained);
  return retained
          .map((value) => (value - mean) * (value - mean))
          .reduce((left, right) => left + right) /
      (retained.length - 1);
}

double _weightedMean(
  Iterable<SyntheticTransportRecord> records, {
  required double Function(SyntheticTransportRecord) value,
  required double Function(SyntheticTransportRecord) weight,
}) {
  var numerator = 0.0;
  var denominator = 0.0;
  for (final record in records) {
    final retainedWeight = weight(record);
    numerator += retainedWeight * value(record);
    denominator += retainedWeight;
  }
  return numerator / denominator;
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
