import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../entities/credibility_bayesian_borrowing_calibration.dart';
import '../entities/credibility_adaptive_design_simulation.dart';

final class BayesianBorrowingOperatingCharacteristicsSimulator {
  const BayesianBorrowingOperatingCharacteristicsSimulator();

  List<BayesianOperatingCharacteristicsResult> run({
    required BayesianPriorLikelihoodContract contract,
    required BayesianSeedCustody custody,
    required List<BayesianBorrowingScenario> scenarios,
  }) => List.unmodifiable([
    for (final scenario in scenarios)
      _runScenario(contract: contract, custody: custody, scenario: scenario),
  ]);

  BayesianOperatingCharacteristicsResult _runScenario({
    required BayesianPriorLikelihoodContract contract,
    required BayesianSeedCustody custody,
    required BayesianBorrowingScenario scenario,
  }) {
    final rng = _XorShift32Normal(
      custody.masterSeed ^ _stableStringSeed(scenario.scenarioId),
    );
    final controlN = math.max(
      8,
      (scenario.currentControlSampleSize *
              (1 - scenario.missingRate) *
              (1 - 0.5 * scenario.delayedOutcomeRate))
          .round(),
    );
    final treatmentN = math.max(
      8,
      (scenario.currentTreatmentSampleSize *
              (1 - scenario.missingRate) *
              (1 - 0.5 * scenario.delayedOutcomeRate))
          .round(),
    );
    final qualityEligible =
        scenario.externalQuality >= contract.minimumExternalQuality &&
        scenario.externalRelevance >= contract.minimumExternalRelevance;
    final effectiveExternalN = qualityEligible
        ? math.min(
            contract.maximumPriorEffectiveSampleSize,
            scenario.externalSampleSize *
                contract.maximumBorrowingFraction *
                scenario.externalQuality *
                scenario.externalRelevance,
          )
        : 0.0;
    final informativeAlpha =
        contract.weakPriorAlpha +
        scenario.externalControlRate * effectiveExternalN;
    final informativeBeta =
        contract.weakPriorBeta +
        (1 - scenario.externalControlRate) * effectiveExternalN;
    final baseInformativeWeight = qualityEligible
        ? contract.informativeMixtureWeight
        : 0.0;
    final controlLookup = [
      for (var successes = 0; successes <= controlN; successes++)
        _controlPosterior(
          successes: successes,
          total: controlN,
          weakAlpha: contract.weakPriorAlpha,
          weakBeta: contract.weakPriorBeta,
          informativeAlpha: informativeAlpha,
          informativeBeta: informativeBeta,
          baseInformativeWeight: baseInformativeWeight,
          maximumBorrowingFraction: contract.maximumBorrowingFraction,
          effectiveExternalN: effectiveExternalN,
          priorMean: scenario.externalControlRate,
        ),
    ];
    final treatmentLookup = [
      for (var successes = 0; successes <= treatmentN; successes++)
        _betaSummary(
          contract.weakPriorAlpha + successes,
          contract.weakPriorBeta + treatmentN - successes,
        ),
    ];

    var decisionCount = 0;
    var coverageCount = 0;
    var failureCount = 0;
    var posteriorEffectSum = 0.0;
    var posteriorProbabilitySum = 0.0;
    var borrowingWeightSum = 0.0;
    var borrowedEssSum = 0.0;
    var conflictScoreSum = 0.0;
    final trueEffect = scenario.trueTreatmentRate - scenario.trueControlRate;
    final observedTreatmentRate =
        scenario.trueTreatmentRate * (1 - scenario.nonAdherenceRate) +
        scenario.trueControlRate * scenario.nonAdherenceRate;

    for (var iteration = 0; iteration < scenario.repetitions; iteration++) {
      final controlSuccesses = _drawApproximateBinomial(
        rng,
        controlN,
        scenario.trueControlRate,
        scenario.likelihoodOverdispersion,
      );
      final treatmentSuccesses = _drawApproximateBinomial(
        rng,
        treatmentN,
        observedTreatmentRate,
        scenario.likelihoodOverdispersion,
      );
      final control = controlLookup[controlSuccesses];
      final treatment = treatmentLookup[treatmentSuccesses];
      final informativeDifferenceVariance =
          treatment.variance + control.informativeVariance;
      final weakDifferenceVariance = treatment.variance + control.weakVariance;
      if (informativeDifferenceVariance <= 0 ||
          weakDifferenceVariance <= 0 ||
          !informativeDifferenceVariance.isFinite ||
          !weakDifferenceVariance.isFinite) {
        failureCount++;
        continue;
      }
      final informativeProbability =
          1 -
          _normalCdf(
            (contract.treatmentEffectThreshold -
                    (treatment.mean - control.informativeMean)) /
                math.sqrt(informativeDifferenceVariance),
          );
      final weakProbability =
          1 -
          _normalCdf(
            (contract.treatmentEffectThreshold -
                    (treatment.mean - control.weakMean)) /
                math.sqrt(weakDifferenceVariance),
          );
      final posteriorProbability =
          control.informativeWeight * informativeProbability +
          (1 - control.informativeWeight) * weakProbability;
      final posteriorControlMean =
          control.informativeWeight * control.informativeMean +
          (1 - control.informativeWeight) * control.weakMean;
      final posteriorEffect = treatment.mean - posteriorControlMean;
      final posteriorControlVariance =
          control.informativeWeight *
              (control.informativeVariance +
                  math.pow(control.informativeMean - posteriorControlMean, 2)) +
          (1 - control.informativeWeight) *
              (control.weakVariance +
                  math.pow(control.weakMean - posteriorControlMean, 2));
      final effectStandardDeviation = math.sqrt(
        treatment.variance + posteriorControlVariance,
      );
      if (posteriorEffect - 1.96 * effectStandardDeviation <= trueEffect &&
          posteriorEffect + 1.96 * effectStandardDeviation >= trueEffect) {
        coverageCount++;
      }
      if (posteriorProbability >= contract.posteriorSuccessProbability) {
        decisionCount++;
      }
      posteriorEffectSum += posteriorEffect;
      posteriorProbabilitySum += posteriorProbability;
      borrowingWeightSum += control.informativeWeight;
      borrowedEssSum += control.borrowedEffectiveSampleSize;
      conflictScoreSum += control.conflictScore;
    }

    final retained = scenario.repetitions - failureCount;
    final decisionProbability = decisionCount / scenario.repetitions;
    final meanPosteriorEffect = retained == 0
        ? double.nan
        : posteriorEffectSum / retained;
    return BayesianOperatingCharacteristicsResult(
      scenarioId: scenario.scenarioId,
      scenarioSha256: scenario.scenarioSha256,
      repetitions: scenario.repetitions,
      decisionCount: decisionCount,
      coverageCount: coverageCount,
      failureCount: failureCount,
      decisionProbability: decisionProbability,
      monteCarloStandardError: math.sqrt(
        decisionProbability * (1 - decisionProbability) / scenario.repetitions,
      ),
      meanPosteriorEffect: meanPosteriorEffect,
      bias: meanPosteriorEffect - trueEffect,
      intervalCoverage: coverageCount / scenario.repetitions,
      meanPosteriorProbability: retained == 0
          ? double.nan
          : posteriorProbabilitySum / retained,
      meanBorrowingWeight: retained == 0
          ? double.nan
          : borrowingWeightSum / retained,
      meanBorrowedEffectiveSampleSize: retained == 0
          ? double.nan
          : borrowedEssSum / retained,
      meanConflictScore: retained == 0
          ? double.nan
          : conflictScoreSum / retained,
      computationConverged: failureCount == 0,
    );
  }

  _ControlPosterior _controlPosterior({
    required int successes,
    required int total,
    required double weakAlpha,
    required double weakBeta,
    required double informativeAlpha,
    required double informativeBeta,
    required double baseInformativeWeight,
    required double maximumBorrowingFraction,
    required double effectiveExternalN,
    required double priorMean,
  }) {
    final informative = _betaSummary(
      informativeAlpha + successes,
      informativeBeta + total - successes,
    );
    final weak = _betaSummary(
      weakAlpha + successes,
      weakBeta + total - successes,
    );
    var posteriorWeight = 0.0;
    if (baseInformativeWeight > 0) {
      final logOdds =
          math.log(baseInformativeWeight) -
          math.log(1 - baseInformativeWeight) +
          _logBeta(
            informativeAlpha + successes,
            informativeBeta + total - successes,
          ) -
          _logBeta(informativeAlpha, informativeBeta) -
          _logBeta(weakAlpha + successes, weakBeta + total - successes) +
          _logBeta(weakAlpha, weakBeta);
      posteriorWeight = logOdds >= 0
          ? 1 / (1 + math.exp(-logOdds))
          : math.exp(logOdds) / (1 + math.exp(logOdds));
      posteriorWeight = math.min(maximumBorrowingFraction, posteriorWeight);
    }
    return _ControlPosterior(
      informativeMean: informative.mean,
      informativeVariance: informative.variance,
      weakMean: weak.mean,
      weakVariance: weak.variance,
      informativeWeight: posteriorWeight,
      borrowedEffectiveSampleSize: posteriorWeight * effectiveExternalN,
      conflictScore: (successes / total - priorMean).abs(),
    );
  }

  _BetaSummary _betaSummary(double alpha, double beta) {
    final total = alpha + beta;
    return _BetaSummary(
      mean: alpha / total,
      variance: alpha * beta / (total * total * (total + 1)),
    );
  }

  int _drawApproximateBinomial(
    _XorShift32Normal rng,
    int total,
    double probability,
    double overdispersion,
  ) {
    final mean = total * probability;
    final standardDeviation = math.sqrt(
      total * probability * (1 - probability) * overdispersion,
    );
    return (mean + standardDeviation * rng.nextNormal()).round().clamp(
      0,
      total,
    );
  }
}

final class BayesianBorrowingSyntheticFixture {
  static const String authoredAtUtc = '2026-08-26T13:00:00.000Z';
  static const String lockedAtUtc = '2026-08-26T13:05:00.000Z';
  static const String simulationStartedAtUtc = '2026-08-26T13:10:00.000Z';
  static const String simulationCompletedAtUtc = '2026-08-26T13:16:00.000Z';
  static const String firstResultVisibleAtUtc = '2026-08-26T13:17:00.000Z';

  const BayesianBorrowingSyntheticFixture._();

  static CredibilityBayesianBorrowingCalibrationPackage build({
    required CredibilityAdaptiveDesignSimulationPackage adaptivePackage,
  }) {
    final adaptive = adaptivePackage;
    final scenarios = _scenarios();
    final custody = BayesianSeedCustody(
      masterSeed: 2026082602,
      commitmentSalt: 'synthetic-bayesian-borrowing-seed-custody-v1',
      scenarioIds: scenarios.map((item) => item.scenarioId).toList(),
    );
    final contract = BayesianPriorLikelihoodContract(
      contractId: 'synthetic-robust-beta-mixture-borrowing-v1',
      priorFamilyId: 'robust-beta-mixture/1',
      weakPriorAlpha: 1,
      weakPriorBeta: 1,
      informativeMixtureWeight: 0.70,
      maximumBorrowingFraction: 0.80,
      maximumPriorEffectiveSampleSize: 40,
      minimumExternalQuality: 0.75,
      minimumExternalRelevance: 0.75,
      discountingRuleId: 'posterior-robust-mixture-weight/1',
      conflictMildThreshold: 0.08,
      conflictSevereThreshold: 0.18,
      likelihoodId: 'binomial-beta-conjugate/1',
      estimandId: 'synthetic-response-risk-difference-v1',
      missingDataStrategyId: 'synthetic-effective-sample-attenuation-v1',
      treatmentEffectThreshold: 0,
      posteriorSuccessProbability: 0.975,
      computationMethodId: 'closed-form-beta-mixture/1',
      convergenceRuleId: 'finite-closed-form-and-mass-sum/1',
      modelCodeSha256:
          '22850e77d1d55aac7d24a75bf78287dbcb538bab8c8dd3291074361e55d35dbc',
      randomNumberGeneratorId: 'parkinsum.xorshift32-box-muller/1',
      seedManifestSha256: custody.seedManifestSha256,
      scenarioCatalogSha256: _digest(
        scenarios.map((item) => item.toJson()).toList(),
      ),
      authoredAtUtc: authoredAtUtc,
      lockedAtUtc: lockedAtUtc,
      firstResultVisibleAtUtc: firstResultVisibleAtUtc,
      boundary:
          'Synthetic robust Beta-mixture and normal posterior-difference approximation; not a clinical analysis recommendation.',
    );
    final results = const BayesianBorrowingOperatingCharacteristicsSimulator()
        .run(contract: contract, custody: custody, scenarios: scenarios);
    return CredibilityBayesianBorrowingCalibrationPackage(
      packageId: 'synthetic-bayesian-borrowing-calibration-v1',
      adaptivePackage: adaptive,
      adaptivePackageSha256: adaptive.packageSha256,
      configurationSha256: adaptive.configurationSha256,
      algorithmSourceBundleSha256: adaptive.algorithmSourceBundleSha256,
      contract: contract,
      custody: custody,
      externalEvidence: _externalEvidence(),
      scenarios: scenarios,
      results: results,
      oracleVectors: _oracleVectors(),
      simulationStartedAtUtc: simulationStartedAtUtc,
      simulationCompletedAtUtc: simulationCompletedAtUtc,
      allRelevantExternalEvidenceRetained: true,
      allPrespecifiedResultsRetained: true,
      revoked: false,
      syntheticDemoOnly: true,
      boundary:
          'Deterministic synthetic Bayesian-methodology governance only. It is not Bayesian validity, a clinical-trial result, GCP compliance, regulatory acceptance, benefit, safety, or medical advice. FDA January 2026 Bayesian guidance remains Draft — Not for Implementation.',
    );
  }

  static List<BayesianExternalEvidenceRecord> _externalEvidence() => const [
    BayesianExternalEvidenceRecord(
      cohortId: 'synthetic-aligned-external-control',
      populationId: 'synthetic-target-like-population',
      outcomeId: 'synthetic-binary-response',
      estimandId: 'synthetic-response-risk-difference-v1',
      successes: 60,
      total: 100,
      qualityScore: 0.90,
      relevanceScore: 0.90,
      patientLevelAvailable: true,
      outcomeAligned: true,
      populationAligned: true,
      included: true,
      inclusionDecision:
          'Included in the synthetic prior fixture after declared alignment checks.',
      sourceRef: 'synthetic://external-control/aligned-v1',
      assessedAtUtc: authoredAtUtc,
    ),
    BayesianExternalEvidenceRecord(
      cohortId: 'synthetic-mismatched-external-control',
      populationId: 'synthetic-foreign-population',
      outcomeId: 'synthetic-surrogate-response',
      estimandId: 'synthetic-surrogate-odds-ratio-v1',
      successes: 42,
      total: 60,
      qualityScore: 0.55,
      relevanceScore: 0.35,
      patientLevelAvailable: false,
      outcomeAligned: false,
      populationAligned: false,
      included: false,
      inclusionDecision:
          'Excluded but retained because population, outcome, estimand, quality, and completeness do not align.',
      sourceRef: 'synthetic://external-control/excluded-v1',
      assessedAtUtc: authoredAtUtc,
    ),
  ];

  static List<BayesianBorrowingScenario> _scenarios() => const [
    BayesianBorrowingScenario(
      scenarioId: 'null-no-conflict',
      family: BayesianBorrowingScenarioFamily.noConflict,
      nullCompatible: true,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.60,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 0.08,
      minimumDecisionProbability: 0,
      maximumAbsoluteBias: 0.05,
      minimumCoverage: 0.88,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Aligned null reference with maximum eligible borrowing.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'null-mild-conflict',
      family: BayesianBorrowingScenarioFamily.mildConflict,
      nullCompatible: true,
      trueControlRate: 0.70,
      trueTreatmentRate: 0.70,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 0.10,
      minimumDecisionProbability: 0,
      maximumAbsoluteBias: 0.07,
      minimumCoverage: 0.86,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Mild prior-data conflict must reduce borrowing visibly.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'null-severe-conflict',
      family: BayesianBorrowingScenarioFamily.severeConflict,
      nullCompatible: true,
      trueControlRate: 0.82,
      trueTreatmentRate: 0.82,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 0.12,
      minimumDecisionProbability: 0,
      maximumAbsoluteBias: 0.08,
      minimumCoverage: 0.84,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Severe conflict stress must approach weak-prior borrowing.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-prior-misspecification',
      family: BayesianBorrowingScenarioFamily.priorMisspecification,
      nullCompatible: false,
      trueControlRate: 0.55,
      trueTreatmentRate: 0.74,
      externalControlRate: 0.72,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.66,
      maximumAbsoluteBias: 0.09,
      minimumCoverage: 0.82,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Wrong-direction informative prior probes robustification.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-likelihood-misspecification',
      family: BayesianBorrowingScenarioFamily.likelihoodMisspecification,
      nullCompatible: false,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.78,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1.6,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.58,
      maximumAbsoluteBias: 0.08,
      minimumCoverage: 0.78,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Overdispersed count stress probes likelihood sensitivity.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-sparse-data',
      family: BayesianBorrowingScenarioFamily.sparseData,
      nullCompatible: false,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.82,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 36,
      currentTreatmentSampleSize: 36,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.44,
      maximumAbsoluteBias: 0.10,
      minimumCoverage: 0.80,
      prespecifiedAtUtc: authoredAtUtc,
      rationale:
          'Small current sample exposes prior influence and uncertainty.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-missing-at-random',
      family: BayesianBorrowingScenarioFamily.missingAtRandom,
      nullCompatible: false,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.79,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0.20,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.58,
      maximumAbsoluteBias: 0.09,
      minimumCoverage: 0.82,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Declared information loss never becomes observed data.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-non-adherence',
      family: BayesianBorrowingScenarioFamily.nonAdherence,
      nullCompatible: false,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.82,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0.20,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.52,
      maximumAbsoluteBias: 0.10,
      minimumCoverage: 0.78,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'ITT-scale attenuation remains explicit rather than repaired.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-delayed-outcome',
      family: BayesianBorrowingScenarioFamily.delayedOutcome,
      nullCompatible: false,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.80,
      externalControlRate: 0.60,
      externalSampleSize: 100,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.90,
      externalRelevance: 0.90,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0.30,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.58,
      maximumAbsoluteBias: 0.09,
      minimumCoverage: 0.82,
      prespecifiedAtUtc: authoredAtUtc,
      rationale: 'Delayed outcomes reduce usable information prospectively.',
    ),
    BayesianBorrowingScenario(
      scenarioId: 'alternative-low-quality-external-data',
      family: BayesianBorrowingScenarioFamily.externalDataQuality,
      nullCompatible: false,
      trueControlRate: 0.60,
      trueTreatmentRate: 0.78,
      externalControlRate: 0.60,
      externalSampleSize: 240,
      currentControlSampleSize: 100,
      currentTreatmentSampleSize: 100,
      externalQuality: 0.45,
      externalRelevance: 0.55,
      missingRate: 0,
      nonAdherenceRate: 0,
      delayedOutcomeRate: 0,
      likelihoodOverdispersion: 1,
      repetitions: 40000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.50,
      maximumAbsoluteBias: 0.08,
      minimumCoverage: 0.84,
      prespecifiedAtUtc: authoredAtUtc,
      rationale:
          'Large but unsuitable external data must contribute zero borrowing.',
    ),
  ];

  static List<BayesianOracleVector> _oracleVectors() => const [
    BayesianOracleVector(
      vectorId: 'no-conflict-no-success',
      observedControlRate: 0.61,
      priorControlRate: 0.60,
      posteriorProbability: 0.80,
      expectedConflictState: BayesianConflictState.none,
      expectedDecisionState: BayesianDecisionState.noSuccess,
      rationale: 'Aligned data do not imply a successful treatment decision.',
    ),
    BayesianOracleVector(
      vectorId: 'mild-conflict-success',
      observedControlRate: 0.70,
      priorControlRate: 0.60,
      posteriorProbability: 0.99,
      expectedConflictState: BayesianConflictState.mild,
      expectedDecisionState: BayesianDecisionState.success,
      rationale: 'Conflict and posterior decision remain separate lanes.',
    ),
    BayesianOracleVector(
      vectorId: 'severe-conflict-no-success',
      observedControlRate: 0.82,
      priorControlRate: 0.60,
      posteriorProbability: 0.70,
      expectedConflictState: BayesianConflictState.severe,
      expectedDecisionState: BayesianDecisionState.noSuccess,
      rationale: 'Severe prior-data conflict does not get suppressed.',
    ),
    BayesianOracleVector(
      vectorId: 'posterior-threshold-equality',
      observedControlRate: 0.60,
      priorControlRate: 0.60,
      posteriorProbability: 0.975,
      expectedConflictState: BayesianConflictState.none,
      expectedDecisionState: BayesianDecisionState.success,
      rationale: 'Posterior success threshold includes equality.',
    ),
    BayesianOracleVector(
      vectorId: 'posterior-threshold-below',
      observedControlRate: 0.60,
      priorControlRate: 0.60,
      posteriorProbability: 0.9749,
      expectedConflictState: BayesianConflictState.none,
      expectedDecisionState: BayesianDecisionState.noSuccess,
      rationale: 'A value below the prospective threshold does not pass.',
    ),
  ];
}

final class _ControlPosterior {
  final double informativeMean;
  final double informativeVariance;
  final double weakMean;
  final double weakVariance;
  final double informativeWeight;
  final double borrowedEffectiveSampleSize;
  final double conflictScore;

  const _ControlPosterior({
    required this.informativeMean,
    required this.informativeVariance,
    required this.weakMean,
    required this.weakVariance,
    required this.informativeWeight,
    required this.borrowedEffectiveSampleSize,
    required this.conflictScore,
  });
}

final class _BetaSummary {
  final double mean;
  final double variance;

  const _BetaSummary({required this.mean, required this.variance});
}

final class _XorShift32Normal {
  int _state;
  double? _spare;

  _XorShift32Normal(int seed) : _state = seed == 0 ? 0x6d2b79f5 : seed;

  double nextUniform() {
    var value = _state & 0xffffffff;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return ((_state & 0xffffffff) + 1) / 4294967297;
  }

  double nextNormal() {
    final spare = _spare;
    if (spare != null) {
      _spare = null;
      return spare;
    }
    final radius = math.sqrt(-2 * math.log(nextUniform()));
    final angle = 2 * math.pi * nextUniform();
    _spare = radius * math.sin(angle);
    return radius * math.cos(angle);
  }
}

int _stableStringSeed(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

double _normalCdf(double value) {
  final absolute = value.abs();
  final t = 1 / (1 + 0.2316419 * absolute);
  final density = math.exp(-0.5 * absolute * absolute) / math.sqrt(2 * math.pi);
  final polynomial =
      t *
      (0.319381530 +
          t *
              (-0.356563782 +
                  t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  final upper = density * polynomial;
  return value >= 0 ? 1 - upper : upper;
}

double _logBeta(double alpha, double beta) =>
    _logGamma(alpha) + _logGamma(beta) - _logGamma(alpha + beta);

double _logGamma(double value) {
  const coefficients = [
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (value < 0.5) {
    return math.log(math.pi) -
        math.log(math.sin(math.pi * value)) -
        _logGamma(1 - value);
  }
  final adjusted = value - 1;
  var series = 0.99999999999980993;
  for (var index = 0; index < coefficients.length; index++) {
    series += coefficients[index] / (adjusted + index + 1);
  }
  final shifted = adjusted + coefficients.length - 0.5;
  return 0.5 * math.log(2 * math.pi) +
      (adjusted + 0.5) * math.log(shifted) -
      shifted +
      math.log(series);
}

String _digest(Object? value) =>
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
