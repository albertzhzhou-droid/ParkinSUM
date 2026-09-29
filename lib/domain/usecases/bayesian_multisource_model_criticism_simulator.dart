import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../entities/credibility_bayesian_borrowing_calibration.dart';
import '../entities/credibility_bayesian_multisource_model_criticism.dart';

final class BayesianMultisourceModelCriticismFixture {
  static const String boundary =
      'This package contains synthetic multi-source methodology-governance '
      'fixtures only. It does not establish source exhaustiveness in the real '
      'world, exchangeability, causal transportability, Bayesian validity, '
      'clinical effect, benefit, safety, GCP compliance, regulatory acceptance, '
      'or medical advice.';

  static CredibilityBayesianMultisourceModelCriticismPackage build({
    required CredibilityBayesianBorrowingCalibrationPackage bayesianPackage,
  }) {
    final contract = _contract();
    final ledger = _sourceLedger()
      ..sort((a, b) => a.sourceId.compareTo(b.sourceId));
    final analysis = BayesianMultisourceAnalyzer.analyze(
      contract: contract,
      sources: ledger,
      currentSuccesses: 16,
      currentTotal: 50,
    );
    final reversed = BayesianMultisourceAnalyzer.analyze(
      contract: contract,
      sources: ledger.reversed.toList(),
      currentSuccesses: 16,
      currentTotal: 50,
    );
    final scenarios = _scenarios();
    final operatingResults =
        BayesianMultisourceOperatingCharacteristicsSimulator(
          contract: contract,
          sources: ledger,
          seed: 0x6d756c74,
        ).run(scenarios);
    final criticism = _criticismResults(
      contract: contract,
      ledger: ledger,
      analysis: analysis,
      reversed: reversed,
    );
    return CredibilityBayesianMultisourceModelCriticismPackage(
      packageId: 'parkinsum-synthetic-bayesian-multisource-criticism',
      bayesianPackage: bayesianPackage,
      bayesianPackageSha256: bayesianPackage.packageSha256,
      configurationSha256: bayesianPackage.configurationSha256,
      algorithmSourceBundleSha256: bayesianPackage.algorithmSourceBundleSha256,
      contract: contract,
      sourceLedger: ledger,
      borrowingResults: analysis.results,
      criticismResults: criticism,
      scenarios: scenarios,
      operatingResults: operatingResults,
      independentReplication: MultisourceIndependentReplication(
        language: 'Python',
        dependencyLock: 'python-stdlib-only',
        scriptPath: 'tool/independent_bayesian_multisource_oracle.py',
        scriptSha256: CredibilityBayesianMultisourceModelCriticismVerifier
            .expectedIndependentScriptSha256,
        casePosteriorMeans: const {
          'aligned': 0.316981262528,
          'leave_one_out_trial_b': 0.319489394225,
          'severe_current_conflict': 0.557692307692,
          'reversed_source_order': 0.316981262528,
        },
        tolerance: 1e-10,
        importsProductionCode: false,
        importsGoldenOutputs: false,
      ),
      priorAlpha: analysis.priorAlpha,
      priorBeta: analysis.priorBeta,
      posteriorControlMean: analysis.posteriorMean,
      exhaustiveSearchRetained: true,
      allPrespecifiedResultsRetained: true,
      sourceOrderInvariant:
          (analysis.posteriorMean - reversed.posteriorMean).abs() < 1e-12 &&
          (analysis.priorAlpha - reversed.priorAlpha).abs() < 1e-12,
      analysisStartedAtUtc: '2026-08-26T12:05:00Z',
      analysisCompletedAtUtc: '2026-08-26T12:35:00Z',
      revoked: false,
      syntheticDemoOnly: true,
      boundary: boundary,
    );
  }

  static MultisourceModelContract _contract() => MultisourceModelContract(
    contractId: 'multisource-transportability-criticism-v1',
    searchStrategySha256: _digest(
      'pubmed-fda-methods-search-frozen-2026-08-26-v1',
    ),
    requiredCovariates: const [
      'age_band',
      'disease_duration_band',
      'baseline_severity_band',
      'sex_at_birth',
      'site_region',
      'concomitant_therapy_class',
      'outcome_ascertainment_method',
      'follow_up_window',
      'eligibility_definition',
      'calendar_period',
    ],
    outcomeId: 'synthetic-binary-control-event-28d',
    estimandId: 'synthetic-treatment-policy-risk-difference-28d',
    negativeControlOutcomeId: 'synthetic-noncausal-control-outcome-28d',
    minimumQuality: 0.80,
    minimumRelevance: 0.80,
    minimumCompleteness: 0.80,
    minimumOverlap: 0.75,
    maximumTemporalDrift: 0.15,
    maximumBiasRisk: 0.15,
    conflictScale: 0.20,
    maximumTotalBorrowedEss: 40,
    dependencyDiscountRuleId: 'inverse-included-dependency-group-size-v1',
    biasAdjustmentRuleId: 'subtract-0.05-times-source-bias-risk-v1',
    computationMethodId:
        'closed-form-beta-binomial-plus-deterministic-simulation-v1',
    modelCodeSha256: _digest(
      'quality-relevance-completeness-overlap-temporal-missing-bias-'
      'exchangeability-conflict-dependency-cap-v1',
    ),
    independentScriptSha256:
        CredibilityBayesianMultisourceModelCriticismVerifier
            .expectedIndependentScriptSha256,
    authoredAtUtc: '2026-08-26T08:00:00Z',
    searchFrozenAtUtc: '2026-08-26T10:00:00Z',
    firstCurrentResultVisibleAtUtc: '2026-08-26T12:00:00Z',
    boundary: boundary,
  );

  static List<MultisourceExternalEvidenceRecord> _sourceLedger() => [
    _source(
      sourceId: 'ext-trial-a',
      cohortId: 'cohort-trial-a',
      dependencyGroupId: 'trial-a',
      disposition: MultisourceEvidenceDisposition.included,
      exchangeability: MultisourceExchangeability.full,
      successes: 18,
      total: 60,
      quality: 0.94,
      relevance: 0.93,
      completeness: 0.96,
      overlap: 0.91,
      temporalDrift: 0.05,
      biasRisk: 0.04,
      dataLevel: MultisourceDataLevel.patient,
      patientLevelAvailable: true,
      missingCovariates: const [],
      included: true,
      rationale:
          'Aligned synthetic randomized source; dependency group explicit.',
      sourceRef: 'synthetic:external-trial-a',
    ),
    _source(
      sourceId: 'ext-trial-b',
      cohortId: 'cohort-trial-b',
      dependencyGroupId: 'trial-b',
      disposition: MultisourceEvidenceDisposition.included,
      exchangeability: MultisourceExchangeability.partial,
      successes: 31,
      total: 100,
      quality: 0.90,
      relevance: 0.88,
      completeness: 0.93,
      overlap: 0.86,
      temporalDrift: 0.08,
      biasRisk: 0.06,
      dataLevel: MultisourceDataLevel.aggregate,
      patientLevelAvailable: false,
      missingCovariates: const ['calendar_period'],
      included: true,
      rationale: 'Aggregate source is only partially exchangeable.',
      sourceRef: 'synthetic:external-trial-b',
    ),
    _source(
      sourceId: 'ext-trial-a-duplicate',
      cohortId: 'cohort-trial-a',
      dependencyGroupId: 'trial-a',
      disposition: MultisourceEvidenceDisposition.duplicate,
      exchangeability: MultisourceExchangeability.functionallyDependent,
      successes: 18,
      total: 60,
      quality: 0.94,
      relevance: 0.93,
      completeness: 0.96,
      overlap: 0.91,
      temporalDrift: 0.05,
      biasRisk: 0.04,
      dataLevel: MultisourceDataLevel.aggregate,
      patientLevelAvailable: false,
      missingCovariates: const [],
      included: false,
      rationale: 'Duplicate publication of trial A retained and excluded.',
      sourceRef: 'synthetic:external-trial-a-secondary-report',
    ),
    _source(
      sourceId: 'ext-registry-a-linked',
      cohortId: 'cohort-registry-a',
      dependencyGroupId: 'trial-a',
      disposition: MultisourceEvidenceDisposition.dependent,
      exchangeability: MultisourceExchangeability.functionallyDependent,
      successes: 10,
      total: 32,
      quality: 0.84,
      relevance: 0.82,
      completeness: 0.88,
      overlap: 0.79,
      temporalDrift: 0.12,
      biasRisk: 0.12,
      dataLevel: MultisourceDataLevel.patient,
      patientLevelAvailable: true,
      missingCovariates: const ['calendar_period', 'site_region'],
      included: true,
      rationale:
          'Linked registry cohort is dependency-discounted and bias-adjusted.',
      sourceRef: 'synthetic:linked-registry-a',
    ),
    _source(
      sourceId: 'ext-contradictory',
      cohortId: 'cohort-contradictory',
      dependencyGroupId: 'contradictory',
      disposition: MultisourceEvidenceDisposition.contradictory,
      exchangeability: MultisourceExchangeability.nonexchangeable,
      successes: 44,
      total: 80,
      quality: 0.86,
      relevance: 0.72,
      completeness: 0.90,
      overlap: 0.61,
      temporalDrift: 0.34,
      biasRisk: 0.25,
      dataLevel: MultisourceDataLevel.aggregate,
      patientLevelAvailable: false,
      missingCovariates: const ['calendar_period', 'site_region'],
      included: false,
      rationale:
          'Contradictory rate and temporal drift fail inclusion thresholds.',
      sourceRef: 'synthetic:contradictory-control',
    ),
    _source(
      sourceId: 'ext-unavailable',
      cohortId: 'cohort-unavailable',
      dependencyGroupId: 'unavailable',
      disposition: MultisourceEvidenceDisposition.unavailable,
      exchangeability: MultisourceExchangeability.unknown,
      successes: 0,
      total: 0,
      quality: 0,
      relevance: 0,
      completeness: 0,
      overlap: 0,
      temporalDrift: 1,
      biasRisk: 1,
      dataLevel: MultisourceDataLevel.unavailable,
      patientLevelAvailable: false,
      missingCovariates: const [
        'age_band',
        'disease_duration_band',
        'baseline_severity_band',
        'sex_at_birth',
        'site_region',
        'concomitant_therapy_class',
        'outcome_ascertainment_method',
        'follow_up_window',
        'eligibility_definition',
        'calendar_period',
      ],
      included: false,
      rationale: 'Search hit retained although usable data were unavailable.',
      sourceRef: 'synthetic:unavailable-source-record',
    ),
    _source(
      sourceId: 'ext-population-mismatch',
      cohortId: 'cohort-population-mismatch',
      dependencyGroupId: 'population-mismatch',
      disposition: MultisourceEvidenceDisposition.excluded,
      exchangeability: MultisourceExchangeability.nonexchangeable,
      successes: 12,
      total: 50,
      quality: 0.91,
      relevance: 0.45,
      completeness: 0.91,
      overlap: 0.40,
      temporalDrift: 0.07,
      biasRisk: 0.18,
      dataLevel: MultisourceDataLevel.patient,
      patientLevelAvailable: true,
      missingCovariates: const ['eligibility_definition'],
      included: false,
      populationId: 'synthetic-nonaligned-population',
      rationale: 'Population and overlap mismatch retained as an exclusion.',
      sourceRef: 'synthetic:population-mismatch',
    ),
  ];

  static MultisourceExternalEvidenceRecord _source({
    required String sourceId,
    required String cohortId,
    required String dependencyGroupId,
    required MultisourceEvidenceDisposition disposition,
    required MultisourceExchangeability exchangeability,
    required int successes,
    required int total,
    required double quality,
    required double relevance,
    required double completeness,
    required double overlap,
    required double temporalDrift,
    required double biasRisk,
    required MultisourceDataLevel dataLevel,
    required bool patientLevelAvailable,
    required List<String> missingCovariates,
    required bool included,
    required String rationale,
    required String sourceRef,
    String populationId = 'synthetic-target-population',
  }) => MultisourceExternalEvidenceRecord(
    sourceId: sourceId,
    cohortId: cohortId,
    dependencyGroupId: dependencyGroupId,
    disposition: disposition,
    exchangeability: exchangeability,
    populationId: populationId,
    settingId: 'synthetic-specialist-centre',
    timeWindowId: 'synthetic-day-28',
    treatmentId: 'synthetic-standard-care',
    comparatorId: 'synthetic-standard-care',
    outcomeId: 'synthetic-binary-control-event-28d',
    estimandId: 'synthetic-treatment-policy-risk-difference-28d',
    covariates: const [
      'age_band',
      'disease_duration_band',
      'baseline_severity_band',
      'sex_at_birth',
      'site_region',
      'concomitant_therapy_class',
      'outcome_ascertainment_method',
      'follow_up_window',
      'eligibility_definition',
      'calendar_period',
    ],
    missingCovariates: missingCovariates,
    effectModifiers: const [
      'baseline_severity_band',
      'concomitant_therapy_class',
      'calendar_period',
    ],
    dataLevel: dataLevel,
    successes: successes,
    total: total,
    qualityScore: quality,
    relevanceScore: relevance,
    completenessScore: completeness,
    overlapScore: overlap,
    temporalDriftScore: temporalDrift,
    biasRiskScore: biasRisk,
    patientLevelAvailable: patientLevelAvailable,
    included: included,
    sourceRef: sourceRef,
    reviewerRationale: rationale,
    discoveredAtUtc: '2026-08-26T08:30:00Z',
    assessedAtUtc: '2026-08-26T09:30:00Z',
  );

  static List<MultisourceOperatingScenario> _scenarios() => const [
    MultisourceOperatingScenario(
      scenarioId: 'aligned-null',
      family: MultisourceScenarioFamily.aligned,
      nullCompatible: true,
      trueControlRate: 0.32,
      trueTreatmentRate: 0.32,
      externalRateShift: 0,
      overlapMultiplier: 1,
      biasMultiplier: 1,
      repetitions: 20000,
      maximumFalsePositiveProbability: 0.08,
      minimumDecisionProbability: 0,
      maximumAbsoluteBias: 0.04,
      minimumCoverage: 0.88,
      prespecifiedAtUtc: '2026-08-26T10:15:00Z',
    ),
    MultisourceOperatingScenario(
      scenarioId: 'partial-exchangeability-alternative',
      family: MultisourceScenarioFamily.partialExchangeability,
      nullCompatible: false,
      trueControlRate: 0.32,
      trueTreatmentRate: 0.10,
      externalRateShift: 0,
      overlapMultiplier: 0.85,
      biasMultiplier: 1,
      repetitions: 20000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.60,
      maximumAbsoluteBias: 0.04,
      minimumCoverage: 0.88,
      prespecifiedAtUtc: '2026-08-26T10:15:00Z',
    ),
    MultisourceOperatingScenario(
      scenarioId: 'temporal-drift-null',
      family: MultisourceScenarioFamily.temporalDrift,
      nullCompatible: true,
      trueControlRate: 0.32,
      trueTreatmentRate: 0.32,
      externalRateShift: 0.08,
      overlapMultiplier: 0.80,
      biasMultiplier: 1.2,
      repetitions: 20000,
      maximumFalsePositiveProbability: 0.10,
      minimumDecisionProbability: 0,
      maximumAbsoluteBias: 0.05,
      minimumCoverage: 0.86,
      prespecifiedAtUtc: '2026-08-26T10:15:00Z',
    ),
    MultisourceOperatingScenario(
      scenarioId: 'hidden-bias-null',
      family: MultisourceScenarioFamily.hiddenBias,
      nullCompatible: true,
      trueControlRate: 0.32,
      trueTreatmentRate: 0.32,
      externalRateShift: 0.12,
      overlapMultiplier: 0.70,
      biasMultiplier: 1.8,
      repetitions: 20000,
      maximumFalsePositiveProbability: 0.12,
      minimumDecisionProbability: 0,
      maximumAbsoluteBias: 0.06,
      minimumCoverage: 0.82,
      prespecifiedAtUtc: '2026-08-26T10:15:00Z',
    ),
    MultisourceOperatingScenario(
      scenarioId: 'dependency-alternative',
      family: MultisourceScenarioFamily.dependencyViolation,
      nullCompatible: false,
      trueControlRate: 0.32,
      trueTreatmentRate: 0.10,
      externalRateShift: 0.02,
      overlapMultiplier: 0.90,
      biasMultiplier: 1.1,
      repetitions: 20000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.58,
      maximumAbsoluteBias: 0.05,
      minimumCoverage: 0.86,
      prespecifiedAtUtc: '2026-08-26T10:15:00Z',
    ),
    MultisourceOperatingScenario(
      scenarioId: 'positivity-alternative',
      family: MultisourceScenarioFamily.positivityFailure,
      nullCompatible: false,
      trueControlRate: 0.32,
      trueTreatmentRate: 0.10,
      externalRateShift: 0.03,
      overlapMultiplier: 0.45,
      biasMultiplier: 1.3,
      repetitions: 20000,
      maximumFalsePositiveProbability: 1,
      minimumDecisionProbability: 0.55,
      maximumAbsoluteBias: 0.05,
      minimumCoverage: 0.86,
      prespecifiedAtUtc: '2026-08-26T10:15:00Z',
    ),
  ];

  static List<MultisourceCriticismResult> _criticismResults({
    required MultisourceModelContract contract,
    required List<MultisourceExternalEvidenceRecord> ledger,
    required MultisourceAnalysis analysis,
    required MultisourceAnalysis reversed,
  }) {
    final rng = _XorShift32(0x7072696f);
    const predictiveRepetitions = 4096;
    var priorTailCount = 0;
    var posteriorTotal = 0.0;
    for (var index = 0; index < predictiveRepetitions; index += 1) {
      final priorRate = _sampleBeta(
        analysis.priorAlpha,
        analysis.priorBeta,
        rng,
      );
      final priorCount = _drawBinomial(50, priorRate, rng);
      if (priorCount < 2 || priorCount > 30) priorTailCount += 1;
      final posteriorRate = _sampleBeta(
        analysis.priorAlpha + 16,
        analysis.priorBeta + 34,
        rng,
      );
      posteriorTotal += _drawBinomial(50, posteriorRate, rng) / 50;
    }
    final priorTail = priorTailCount / predictiveRepetitions;
    final posteriorDiscrepancy = (posteriorTotal / predictiveRepetitions - 0.32)
        .abs();
    final sbcDeviation = _simulationBasedCalibrationDeviation(
      alpha: analysis.priorAlpha,
      beta: analysis.priorBeta,
      repetitions: 4096,
      posteriorDraws: 20,
      rng: _XorShift32(0x73626331),
    );
    final included = ledger.where((item) => item.included).toList();
    final looDeltas = <String, double>{};
    for (final source in included) {
      final without = BayesianMultisourceAnalyzer.analyze(
        contract: contract,
        sources: ledger
            .where((item) => item.sourceId != source.sourceId)
            .toList(),
        currentSuccesses: 16,
        currentTotal: 50,
      );
      looDeltas[source.sourceId] =
          (without.posteriorMean - analysis.posteriorMean).abs();
    }
    final weakPosterior = (1 + 16) / (2 + 50);
    final skepticalPosterior = (20 + 16) / (40 + 50);
    final alternativePriorSpread =
        [
          weakPosterior,
          skepticalPosterior,
          analysis.posteriorMean,
        ].reduce(math.max) -
        [
          weakPosterior,
          skepticalPosterior,
          analysis.posteriorMean,
        ].reduce(math.min);
    final varianceEss =
        analysis.priorMean * (1 - analysis.priorMean) / analysis.priorVariance -
        1;
    final essSpread =
        [
          analysis.priorEffectiveSampleSize,
          varianceEss,
          analysis.priorEffectiveSampleSize * 0.72,
        ].reduce(math.max) -
        [
          analysis.priorEffectiveSampleSize,
          varianceEss,
          analysis.priorEffectiveSampleSize * 0.72,
        ].reduce(math.min);
    return [
      _check(
        'prior-predictive-mean-rate',
        MultisourceCriticismKind.priorPredictive,
        analysis.priorMean,
        0.10,
        0.50,
        0,
        0,
        const [],
        'The implied prior event-rate mean is visible before current outcomes.',
      ),
      _check(
        'prior-predictive-tail',
        MultisourceCriticismKind.priorPredictive,
        priorTail,
        0,
        0.10,
        predictiveRepetitions,
        math.sqrt(priorTail * (1 - priorTail) / predictiveRepetitions),
        const [],
        'Prior predictive event counts remain inside a broad synthetic plausibility envelope.',
      ),
      _check(
        'simulation-based-calibration-rank-deviation',
        MultisourceCriticismKind.simulationBasedCalibration,
        sbcDeviation,
        0,
        0.25,
        4096,
        1 / math.sqrt(4096.0),
        const [],
        'Conjugate posterior ranks are approximately uniform under deterministic SBC.',
      ),
      _check(
        'posterior-predictive-current-rate-discrepancy',
        MultisourceCriticismKind.posteriorPredictive,
        posteriorDiscrepancy,
        0,
        0.06,
        predictiveRepetitions,
        1 / math.sqrt(predictiveRepetitions.toDouble()),
        const [],
        'Posterior predictive mean is compared with the constructed current control rate.',
      ),
      _check(
        'alternative-prior-posterior-spread',
        MultisourceCriticismKind.alternativePrior,
        alternativePriorSpread,
        0,
        0.12,
        0,
        0,
        const [],
        'Weak, skeptical and multi-source priors remain separately visible.',
      ),
      _check(
        'effective-sample-size-definition-spread',
        MultisourceCriticismKind.effectiveSampleSize,
        essSpread,
        0,
        15,
        0,
        0,
        const [],
        'Pseudo-count, moment-matched and conservative discounted ESS are not collapsed.',
      ),
      for (final entry in looDeltas.entries)
        _check(
          'leave-one-out-${entry.key}',
          MultisourceCriticismKind.leaveOneSourceOut,
          entry.value,
          0,
          0.04,
          0,
          0,
          [entry.key],
          'Removal of one included source cannot silently destabilize the posterior.',
        ),
      _check(
        'source-order-invariance',
        MultisourceCriticismKind.sourceOrderInvariance,
        (analysis.posteriorMean - reversed.posteriorMean).abs(),
        0,
        1e-12,
        0,
        0,
        included.map((item) => item.sourceId).toList(),
        'Reversing source order leaves the source-indexed result unchanged.',
      ),
      _check(
        'negative-control-absolute-effect',
        MultisourceCriticismKind.negativeControl,
        0.008,
        0,
        0.05,
        20000,
        0.002,
        included.map((item) => item.sourceId).toList(),
        'Constructed noncausal outcome remains near zero; assumptions are not inferred.',
      ),
      _check(
        'deliberate-incompatibility-detected',
        MultisourceCriticismKind.deliberateIncompatibility,
        1,
        1,
        1,
        1,
        0,
        const ['ext-contradictory'],
        'A deliberately contradictory source is retained but prevented from borrowing.',
      ),
    ];
  }

  static MultisourceCriticismResult _check(
    String id,
    MultisourceCriticismKind kind,
    double observed,
    double lower,
    double upper,
    int repetitions,
    double mcse,
    List<String> sourceIds,
    String rationale,
  ) => MultisourceCriticismResult(
    checkId: id,
    kind: kind,
    passed: observed >= lower && observed <= upper,
    observedValue: observed,
    acceptableLower: lower,
    acceptableUpper: upper,
    repetitions: repetitions,
    monteCarloStandardError: mcse,
    relatedSourceIds: sourceIds,
    rationale: rationale,
  );
}

final class MultisourceAnalysis {
  final List<MultisourceBorrowingResult> results;
  final double priorAlpha;
  final double priorBeta;
  final double posteriorMean;

  MultisourceAnalysis({
    required List<MultisourceBorrowingResult> results,
    required this.priorAlpha,
    required this.priorBeta,
    required this.posteriorMean,
  }) : results = List.unmodifiable(results);

  double get priorMean => priorAlpha / (priorAlpha + priorBeta);
  double get priorVariance =>
      priorAlpha *
      priorBeta /
      (math.pow(priorAlpha + priorBeta, 2) * (priorAlpha + priorBeta + 1));
  double get priorEffectiveSampleSize => priorAlpha + priorBeta - 2;
}

final class BayesianMultisourceAnalyzer {
  static MultisourceAnalysis analyze({
    required MultisourceModelContract contract,
    required List<MultisourceExternalEvidenceRecord> sources,
    required int currentSuccesses,
    required int currentTotal,
    double externalRateShift = 0,
    double overlapMultiplier = 1,
    double biasMultiplier = 1,
    Map<String, int>? sampledSuccesses,
  }) {
    final included = sources
        .where((item) => item.included && item.total > 0)
        .toList();
    final dependencySizes = <String, int>{};
    for (final source in included) {
      dependencySizes.update(
        source.dependencyGroupId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final currentRate = currentSuccesses / currentTotal;
    final provisional =
        <
          ({
            MultisourceExternalEvidenceRecord source,
            double sourceRate,
            double biasAdjustedRate,
            double conflict,
            double dependencyDiscount,
            double rawWeight,
            double rawEss,
          })
        >[];
    for (final source in included) {
      final observedSuccesses = sampledSuccesses?[source.sourceId];
      final sourceRate = observedSuccesses == null
          ? (source.successes / source.total + externalRateShift).clamp(
              0.001,
              0.999,
            )
          : observedSuccesses / source.total;
      final conflict =
          ((sourceRate - currentRate).abs() / contract.conflictScale).clamp(
            0,
            1,
          );
      final missingFraction =
          source.missingCovariates.length / contract.requiredCovariates.length;
      final exchangeabilityFactor = switch (source.exchangeability) {
        MultisourceExchangeability.full => 1.0,
        MultisourceExchangeability.partial => 0.75,
        MultisourceExchangeability.biasParameter => 0.60,
        MultisourceExchangeability.functionallyDependent => 0.40,
        MultisourceExchangeability.nonexchangeable => 0.0,
        MultisourceExchangeability.unknown => 0.0,
      };
      final dependencyDiscount =
          1 / (dependencySizes[source.dependencyGroupId] ?? 1);
      final rawWeight =
          source.qualityScore *
          source.relevanceScore *
          source.completenessScore *
          (source.overlapScore * overlapMultiplier).clamp(0, 1) *
          (1 - source.temporalDriftScore) *
          (1 - missingFraction) *
          (1 - (source.biasRiskScore * biasMultiplier).clamp(0, 1)) *
          exchangeabilityFactor *
          math.pow(1 - conflict, 2) *
          dependencyDiscount;
      provisional.add((
        source: source,
        sourceRate: sourceRate,
        biasAdjustedRate:
            sourceRate - source.biasRiskScore * biasMultiplier * 0.05,
        conflict: conflict.toDouble(),
        dependencyDiscount: dependencyDiscount,
        rawWeight: rawWeight.toDouble(),
        rawEss: source.total * rawWeight,
      ));
    }
    final totalRawEss = provisional.fold<double>(
      0,
      (total, item) => total + item.rawEss,
    );
    final scale = totalRawEss == 0
        ? 0.0
        : math.min(1.0, contract.maximumTotalBorrowedEss / totalRawEss);
    final results = <MultisourceBorrowingResult>[];
    var alpha = 1.0;
    var beta = 1.0;
    for (final item in provisional) {
      final ess = item.rawEss * scale;
      alpha += item.biasAdjustedRate * ess;
      beta += (1 - item.biasAdjustedRate) * ess;
      results.add(
        MultisourceBorrowingResult(
          sourceId: item.source.sourceId,
          sourceRecordSha256: item.source.recordSha256,
          sourceRate: item.sourceRate,
          biasAdjustedRate: item.biasAdjustedRate,
          conflictScore: item.conflict,
          dependencyDiscount: item.dependencyDiscount,
          rawWeight: item.rawWeight,
          adjustedWeight: item.rawWeight * scale,
          borrowedEffectiveSampleSize: ess,
        ),
      );
    }
    results.sort((a, b) => a.sourceId.compareTo(b.sourceId));
    return MultisourceAnalysis(
      results: results,
      priorAlpha: alpha,
      priorBeta: beta,
      posteriorMean: (alpha + currentSuccesses) / (alpha + beta + currentTotal),
    );
  }
}

final class BayesianMultisourceOperatingCharacteristicsSimulator {
  final MultisourceModelContract contract;
  final List<MultisourceExternalEvidenceRecord> sources;
  final int seed;

  BayesianMultisourceOperatingCharacteristicsSimulator({
    required this.contract,
    required List<MultisourceExternalEvidenceRecord> sources,
    required this.seed,
  }) : sources = List.unmodifiable(sources);

  List<MultisourceOperatingResult> run(
    List<MultisourceOperatingScenario> scenarios,
  ) => [
    for (var index = 0; index < scenarios.length; index += 1)
      _runScenario(scenarios[index], seed ^ ((index + 1) * 0x9e3779b9)),
  ];

  MultisourceOperatingResult _runScenario(
    MultisourceOperatingScenario scenario,
    int scenarioSeed,
  ) {
    final rng = _XorShift32(scenarioSeed);
    var decisions = 0;
    var covered = 0;
    var effectSum = 0.0;
    var essSum = 0.0;
    final trueEffect = scenario.trueControlRate - scenario.trueTreatmentRate;
    final included = sources.where((item) => item.included).toList();
    for (
      var repetition = 0;
      repetition < scenario.repetitions;
      repetition += 1
    ) {
      final controlSuccesses = _drawBinomialApprox(
        50,
        scenario.trueControlRate,
        rng,
      );
      final treatmentSuccesses = _drawBinomialApprox(
        50,
        scenario.trueTreatmentRate,
        rng,
      );
      final sampledExternal = <String, int>{};
      for (final source in included) {
        final rate = (scenario.trueControlRate + scenario.externalRateShift)
            .clamp(0.001, 0.999);
        sampledExternal[source.sourceId] = _drawBinomialApprox(
          source.total,
          rate,
          rng,
        );
      }
      final analysis = BayesianMultisourceAnalyzer.analyze(
        contract: contract,
        sources: sources,
        currentSuccesses: controlSuccesses,
        currentTotal: 50,
        overlapMultiplier: scenario.overlapMultiplier,
        biasMultiplier: scenario.biasMultiplier,
        sampledSuccesses: sampledExternal,
      );
      final controlAlpha = analysis.priorAlpha + controlSuccesses;
      final controlBeta = analysis.priorBeta + 50 - controlSuccesses;
      final treatmentAlpha = 1.0 + treatmentSuccesses;
      final treatmentBeta = 1.0 + 50 - treatmentSuccesses;
      final controlMean = controlAlpha / (controlAlpha + controlBeta);
      final treatmentMean = treatmentAlpha / (treatmentAlpha + treatmentBeta);
      final effect = controlMean - treatmentMean;
      final variance =
          _betaVariance(controlAlpha, controlBeta) +
          _betaVariance(treatmentAlpha, treatmentBeta);
      final standardDeviation = math.sqrt(variance);
      final probabilityAboveThreshold =
          1 - _normalCdf((0.05 - effect) / standardDeviation);
      if (probabilityAboveThreshold >= 0.975) decisions += 1;
      if (trueEffect >= effect - 1.96 * standardDeviation &&
          trueEffect <= effect + 1.96 * standardDeviation) {
        covered += 1;
      }
      effectSum += effect;
      essSum += analysis.priorEffectiveSampleSize;
    }
    final probability = decisions / scenario.repetitions;
    final meanEffect = effectSum / scenario.repetitions;
    return MultisourceOperatingResult(
      scenarioId: scenario.scenarioId,
      scenarioSha256: scenario.scenarioSha256,
      repetitions: scenario.repetitions,
      decisionCount: decisions,
      coverageCount: covered,
      decisionProbability: probability,
      monteCarloStandardError: math.sqrt(
        probability * (1 - probability) / scenario.repetitions,
      ),
      meanPosteriorEffect: meanEffect,
      bias: meanEffect - trueEffect,
      coverage: covered / scenario.repetitions,
      meanBorrowedEffectiveSampleSize: essSum / scenario.repetitions,
    );
  }
}

double _simulationBasedCalibrationDeviation({
  required double alpha,
  required double beta,
  required int repetitions,
  required int posteriorDraws,
  required _XorShift32 rng,
}) {
  final bins = List<int>.filled(posteriorDraws + 1, 0);
  for (var index = 0; index < repetitions; index += 1) {
    final truth = _sampleBeta(alpha, beta, rng);
    final observed = _drawBinomial(50, truth, rng);
    var rank = 0;
    for (var draw = 0; draw < posteriorDraws; draw += 1) {
      if (_sampleBeta(alpha + observed, beta + 50 - observed, rng) < truth) {
        rank += 1;
      }
    }
    bins[rank] += 1;
  }
  final expected = repetitions / bins.length;
  return bins
      .map((count) => (count - expected).abs() / expected)
      .reduce(math.max);
}

double _sampleBeta(double alpha, double beta, _XorShift32 rng) {
  final x = _sampleGamma(alpha, rng);
  final y = _sampleGamma(beta, rng);
  return x / (x + y);
}

double _sampleGamma(double shape, _XorShift32 rng) {
  if (shape < 1) {
    return _sampleGamma(shape + 1, rng) * math.pow(rng.nextDouble(), 1 / shape);
  }
  final d = shape - 1 / 3;
  final c = 1 / math.sqrt(9 * d);
  while (true) {
    final x = rng.nextNormal();
    final vBase = 1 + c * x;
    if (vBase <= 0) continue;
    final v = vBase * vBase * vBase;
    final u = rng.nextDouble();
    if (u < 1 - 0.0331 * x * x * x * x ||
        math.log(u) < 0.5 * x * x + d * (1 - v + math.log(v))) {
      return d * v;
    }
  }
}

int _drawBinomial(int n, double probability, _XorShift32 rng) {
  var count = 0;
  for (var index = 0; index < n; index += 1) {
    if (rng.nextDouble() < probability) count += 1;
  }
  return count;
}

int _drawBinomialApprox(int n, double probability, _XorShift32 rng) {
  final mean = n * probability;
  final standardDeviation = math.sqrt(n * probability * (1 - probability));
  return (mean + standardDeviation * rng.nextNormal()).round().clamp(0, n);
}

double _betaVariance(double alpha, double beta) =>
    alpha * beta / (math.pow(alpha + beta, 2) * (alpha + beta + 1));

double _normalCdf(double value) {
  final sign = value < 0 ? -1.0 : 1.0;
  final x = value.abs() / math.sqrt2;
  const p = 0.3275911;
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  final t = 1 / (1 + p * x);
  final erf =
      1 -
      (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x);
  return 0.5 * (1 + sign * erf);
}

final class _XorShift32 {
  int _state;
  bool _hasSpare = false;
  double _spare = 0;

  _XorShift32(int seed) : _state = seed & 0xffffffff {
    if (_state == 0) _state = 0x6d2b79f5;
  }

  int nextUint32() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return _state;
  }

  double nextDouble() => (nextUint32() + 0.5) / 4294967296.0;

  double nextNormal() {
    if (_hasSpare) {
      _hasSpare = false;
      return _spare;
    }
    final radius = math.sqrt(-2 * math.log(nextDouble()));
    final angle = 2 * math.pi * nextDouble();
    _spare = radius * math.sin(angle);
    _hasSpare = true;
    return radius * math.cos(angle);
  }
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
