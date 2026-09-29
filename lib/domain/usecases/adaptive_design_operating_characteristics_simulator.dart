import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../entities/credibility_adaptive_design_simulation.dart';
import '../entities/credibility_randomization_interim_firewall.dart';

final class AdaptiveDesignOperatingCharacteristicsSimulator {
  const AdaptiveDesignOperatingCharacteristicsSimulator();

  List<AdaptiveOperatingCharacteristicsResult> run({
    required AdaptiveDecisionRuleContract contract,
    required AdaptiveSimulationSeedCustody custody,
    required List<AdaptiveSimulationScenario> scenarios,
  }) => List.unmodifiable([
    for (final scenario in scenarios)
      _runScenario(contract: contract, custody: custody, scenario: scenario),
  ]);

  AdaptiveOperatingCharacteristicsResult _runScenario({
    required AdaptiveDecisionRuleContract contract,
    required AdaptiveSimulationSeedCustody custody,
    required AdaptiveSimulationScenario scenario,
  }) {
    final rng = _XorShift32Normal(
      custody.masterSeed ^ _stableStringSeed(scenario.scenarioId),
    );
    final firstN = contract.minimumSampleSize;
    final finalN = contract.maximumSampleSize;
    final firstInformation =
        (firstN / 4) * (1 - scenario.missingRate) / scenario.varianceMultiplier;
    final finalInformation =
        (finalN / 4) * (1 - scenario.missingRate) / scenario.varianceMultiplier;
    final informationCorrelation = math.sqrt(
      firstInformation / finalInformation,
    );
    final independentWeight = math.sqrt(
      1 - informationCorrelation * informationCorrelation,
    );

    var successCount = 0;
    var earlyEfficacyCount = 0;
    var futilityCount = 0;
    var maximumSampleCount = 0;
    var coverageCount = 0;
    var selectionCount = 0;
    var failureCount = 0;
    var estimateSum = 0.0;
    var sampleSizeSum = 0.0;

    for (var iteration = 0; iteration < scenario.repetitions; iteration++) {
      final firstNoise = _scenarioNoise(rng, scenario);
      final secondIndependentNoise = _scenarioNoise(rng, scenario);
      final earlyEffect =
          scenario.trueStandardizedEffect *
          (1 - 0.55 * scenario.delayedOutcomeFraction);
      final zeroMeanOperationalPerturbation =
          scenario.timeTrend * 0.20 * rng.nextNormal();
      final firstZ =
          earlyEffect * math.sqrt(firstInformation) +
          firstNoise +
          zeroMeanOperationalPerturbation;

      var usedInformation = firstInformation;
      var usedSampleSize = firstN;
      var finalZ = firstZ;
      var success = false;

      if (firstZ >= contract.efficacyZBoundaries.first) {
        success = true;
        earlyEfficacyCount++;
      } else if (firstZ <= contract.futilityZBoundaries.first) {
        futilityCount++;
      } else {
        maximumSampleCount++;
        usedInformation = finalInformation;
        usedSampleSize = finalN;
        finalZ =
            scenario.trueStandardizedEffect * math.sqrt(finalInformation) +
            informationCorrelation * firstNoise +
            independentWeight * secondIndependentNoise +
            zeroMeanOperationalPerturbation;
        success = finalZ >= contract.efficacyZBoundaries.last;
      }

      if (!finalZ.isFinite || usedInformation <= 0) {
        failureCount++;
        continue;
      }
      if (success) successCount++;
      final estimate = finalZ / math.sqrt(usedInformation);
      final standardError = 1 / math.sqrt(usedInformation);
      final lower = estimate - 1.96 * standardError;
      final upper = estimate + 1.96 * standardError;
      if (lower <= scenario.trueStandardizedEffect &&
          upper >= scenario.trueStandardizedEffect) {
        coverageCount++;
      }
      if (scenario.family == AdaptiveScenarioFamily.correlatedEndpoints) {
        final secondary =
            scenario.endpointCorrelation * firstNoise +
            math.sqrt(
                  1 -
                      scenario.endpointCorrelation *
                          scenario.endpointCorrelation,
                ) *
                secondIndependentNoise;
        if (secondary > firstNoise) selectionCount++;
      }
      estimateSum += estimate;
      sampleSizeSum += usedSampleSize;
    }

    final retained = scenario.repetitions - failureCount;
    final successProbability = successCount / scenario.repetitions;
    final mcse = math.sqrt(
      successProbability * (1 - successProbability) / scenario.repetitions,
    );
    final meanEstimate = retained == 0 ? double.nan : estimateSum / retained;
    final meanSampleSize = retained == 0
        ? double.nan
        : sampleSizeSum / retained;
    return AdaptiveOperatingCharacteristicsResult(
      scenarioId: scenario.scenarioId,
      scenarioSha256: scenario.scenarioSha256,
      repetitions: scenario.repetitions,
      successCount: successCount,
      efficacyStopCount: earlyEfficacyCount,
      futilityStopCount: futilityCount,
      maximumSampleCount: maximumSampleCount,
      coverageCount: coverageCount,
      selectionCount: selectionCount,
      failureCount: failureCount,
      successProbability: successProbability,
      monteCarloStandardError: mcse,
      meanEstimate: meanEstimate,
      bias: meanEstimate - scenario.trueStandardizedEffect,
      intervalCoverage: coverageCount / scenario.repetitions,
      meanSampleSize: meanSampleSize,
      expectedDurationFraction: meanSampleSize / contract.maximumSampleSize,
      selectionProbability: selectionCount / scenario.repetitions,
    );
  }

  double _scenarioNoise(
    _XorShift32Normal rng,
    AdaptiveSimulationScenario scenario,
  ) {
    final normal = rng.nextNormal();
    return switch (scenario.distributionId) {
      'normal-standardized' => normal,
      'normal-variance-standardized' => normal,
      'heavy-tail-mixture-standardized' =>
        (rng.nextUniform() < 0.04 ? normal * 3 : normal) / math.sqrt(1.32),
      'skew-mixture-standardized' =>
        (normal + 0.18 * (rng.nextNormal().abs() - math.sqrt(2 / math.pi))) /
            math.sqrt(1 + 0.18 * 0.18 * (1 - 2 / math.pi)),
      _ => normal,
    };
  }
}

final class AdaptiveDesignSyntheticFixture {
  static const String authoredAtUtc = '2026-08-26T12:00:00.000Z';
  static const String lockedAtUtc = '2026-08-26T12:05:00.000Z';
  static const String simulationStartedAtUtc = '2026-08-26T12:10:00.000Z';
  static const String simulationCompletedAtUtc = '2026-08-26T12:14:00.000Z';
  static const String firstResultVisibleAtUtc = '2026-08-26T12:15:00.000Z';

  const AdaptiveDesignSyntheticFixture._();

  static CredibilityAdaptiveDesignSimulationPackage build({
    required CredibilityRandomizationInterimPackage randomizationPackage,
  }) {
    final scenarios = _scenarios();
    final governedBoundaries = randomizationPackage.boundaryPlan.boundaries;
    final custody = AdaptiveSimulationSeedCustody(
      masterSeed: 2026082601,
      commitmentSalt: 'synthetic-adaptive-simulation-seed-custody-v1',
      scenarioIds: scenarios.map((item) => item.scenarioId).toList(),
    );
    final contract = AdaptiveDecisionRuleContract(
      contractId: 'synthetic-group-sequential-operating-characteristics-v1',
      designKind: AdaptiveDesignKind.groupSequential,
      adaptationIds: const ['early_efficacy', 'nonbinding_futility'],
      informationFractions: governedBoundaries
          .map((item) => item.informationFraction)
          .toList(growable: false),
      efficacyZBoundaries: governedBoundaries
          .map((item) => item.efficacyBoundary)
          .toList(growable: false),
      futilityZBoundaries: governedBoundaries
          .map((item) => item.futilityBoundary)
          .toList(growable: false),
      oneSidedAlpha: 0.025,
      targetPower: 0.80,
      minimumSampleSize: 100,
      maximumSampleSize: 200,
      analysisModelSha256:
          '3c5a0a717782f8ce56699263bcbcfefcff43f192040391024d4215b3ace7f7fd',
      decisionRuleCodeSha256:
          '9c04fb48a2190e102924ecfbbe11d1ad8e21f9fbe2b639bdd7c9fce7a38816d8',
      randomNumberGeneratorId: 'parkinsum.xorshift32-box-muller/1',
      seedManifestSha256: custody.seedManifestSha256,
      scenarioCatalogSha256: _digest(
        scenarios.map((item) => item.toJson()).toList(),
      ),
      authoredAtUtc: authoredAtUtc,
      lockedAtUtc: lockedAtUtc,
      firstResultVisibleAtUtc: firstResultVisibleAtUtc,
      boundary:
          'Fixed synthetic normal-approximation group-sequential design; not a clinical-trial design recommendation.',
    );
    final results = const AdaptiveDesignOperatingCharacteristicsSimulator().run(
      contract: contract,
      custody: custody,
      scenarios: scenarios,
    );
    return CredibilityAdaptiveDesignSimulationPackage(
      packageId: 'synthetic-adaptive-design-simulation-package-v1',
      randomizationPackage: randomizationPackage,
      randomizationPackageSha256: randomizationPackage.packageSha256,
      statisticalPackageSha256: randomizationPackage.statisticalPackageSha256,
      configurationSha256: randomizationPackage.configurationSha256,
      algorithmSourceBundleSha256:
          randomizationPackage.algorithmSourceBundleSha256,
      contract: contract,
      custody: custody,
      scenarios: scenarios,
      results: results,
      oracleVectors: _oracleVectors(),
      simulationStartedAtUtc: simulationStartedAtUtc,
      simulationCompletedAtUtc: simulationCompletedAtUtc,
      allPrespecifiedResultsRetained: true,
      revoked: false,
      syntheticDemoOnly: true,
      boundary:
          'Deterministic synthetic simulation-governance fixture only. It does not establish study adequacy, universal error control, statistical or clinical validation, GCP compliance, regulatory acceptance, benefit, safety, or medical advice. ICH E20 remains draft and not for implementation.',
    );
  }

  static List<AdaptiveSimulationScenario> _scenarios() => const [
    AdaptiveSimulationScenario(
      scenarioId: 'null-normal-reference',
      family: AdaptiveScenarioFamily.nullNormal,
      nullCompatible: true,
      trueStandardizedEffect: 0,
      varianceMultiplier: 1,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 100000,
      minimumAcceptablePower: 0,
      maximumAbsoluteBias: 0.12,
      minimumCoverage: 0.88,
      distributionId: 'normal-standardized',
      rationale:
          'Reference null scenario for one-sided false-positive control.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'null-variance-grid',
      family: AdaptiveScenarioFamily.nullVarianceGrid,
      nullCompatible: true,
      trueStandardizedEffect: 0,
      varianceMultiplier: 1.5,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 100000,
      minimumAcceptablePower: 0,
      maximumAbsoluteBias: 0.15,
      minimumCoverage: 0.88,
      distributionId: 'normal-variance-standardized',
      rationale:
          'Null nuisance-variance grid point with standardized analysis.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-normal-reference',
      family: AdaptiveScenarioFamily.alternativeNormal,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.78,
      maximumAbsoluteBias: 0.12,
      minimumCoverage: 0.88,
      distributionId: 'normal-standardized',
      rationale: 'Reference alternative scenario near the target-power region.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-boundary-effect',
      family: AdaptiveScenarioFamily.boundaryEffect,
      nullCompatible: false,
      trueStandardizedEffect: 0.35,
      varianceMultiplier: 1,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.58,
      maximumAbsoluteBias: 0.14,
      minimumCoverage: 0.88,
      distributionId: 'normal-standardized',
      rationale:
          'Boundary-effect scenario prevents reporting only favorable alternatives.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-heavy-tail',
      family: AdaptiveScenarioFamily.heavyTail,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.70,
      maximumAbsoluteBias: 0.14,
      minimumCoverage: 0.86,
      distributionId: 'heavy-tail-mixture-standardized',
      rationale: 'Heavy-tail stress after variance standardization.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-correlated-endpoints',
      family: AdaptiveScenarioFamily.correlatedEndpoints,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0.65,
      repetitions: 50000,
      minimumAcceptablePower: 0.76,
      maximumAbsoluteBias: 0.12,
      minimumCoverage: 0.88,
      distributionId: 'normal-standardized',
      rationale:
          'Correlated-endpoint diagnostic retains selection probability explicitly.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-time-trend',
      family: AdaptiveScenarioFamily.timeTrend,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1.05,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0.30,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.72,
      maximumAbsoluteBias: 0.14,
      minimumCoverage: 0.86,
      distributionId: 'normal-variance-standardized',
      rationale: 'Zero-mean operational time-trend perturbation stress.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-delayed-outcome',
      family: AdaptiveScenarioFamily.delayedOutcome,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1,
      missingRate: 0,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0.35,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.72,
      maximumAbsoluteBias: 0.14,
      minimumCoverage: 0.86,
      distributionId: 'normal-standardized',
      rationale: 'Delayed outcomes attenuate only the first-look signal.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-missing-at-random',
      family: AdaptiveScenarioFamily.missingAtRandom,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1,
      missingRate: 0.15,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.68,
      maximumAbsoluteBias: 0.14,
      minimumCoverage: 0.86,
      distributionId: 'normal-standardized',
      rationale: 'Missing-at-random information loss remains explicit.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-non-adherence',
      family: AdaptiveScenarioFamily.nonAdherence,
      nullCompatible: false,
      trueStandardizedEffect: 0.42,
      varianceMultiplier: 1.12,
      missingRate: 0,
      nonAdherenceRate: 0.20,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.65,
      maximumAbsoluteBias: 0.14,
      minimumCoverage: 0.86,
      distributionId: 'normal-variance-standardized',
      rationale:
          'ITT-scale effect and variance stress under declared non-adherence.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-sparse-data',
      family: AdaptiveScenarioFamily.sparseData,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1.35,
      missingRate: 0.10,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.56,
      maximumAbsoluteBias: 0.16,
      minimumCoverage: 0.84,
      distributionId: 'normal-variance-standardized',
      rationale:
          'Sparse effective information stress near the decision boundary.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
    AdaptiveSimulationScenario(
      scenarioId: 'alternative-model-misspecification',
      family: AdaptiveScenarioFamily.modelMisspecification,
      nullCompatible: false,
      trueStandardizedEffect: 0.45,
      varianceMultiplier: 1.08,
      missingRate: 0.05,
      nonAdherenceRate: 0,
      timeTrend: 0,
      delayedOutcomeFraction: 0,
      endpointCorrelation: 0,
      repetitions: 50000,
      minimumAcceptablePower: 0.66,
      maximumAbsoluteBias: 0.16,
      minimumCoverage: 0.84,
      distributionId: 'skew-mixture-standardized',
      rationale:
          'Skewed noise and mild information loss probe model misspecification.',
      prespecifiedAtUtc: authoredAtUtc,
    ),
  ];

  static List<AdaptiveDecisionOracleVector> _oracleVectors() => const [
    AdaptiveDecisionOracleVector(
      vectorId: 'interim-efficacy',
      firstLookZ: 2.90,
      finalLookZ: -9,
      expectedFirstAction: AdaptiveDecisionAction.efficacy,
      expectedFinalAction: AdaptiveDecisionAction.efficacy,
      rationale: 'Crosses the first-look efficacy boundary.',
    ),
    AdaptiveDecisionOracleVector(
      vectorId: 'interim-futility',
      firstLookZ: -0.60,
      finalLookZ: 9,
      expectedFirstAction: AdaptiveDecisionAction.futility,
      expectedFinalAction: AdaptiveDecisionAction.futility,
      rationale: 'Crosses the nonbinding first-look futility boundary.',
    ),
    AdaptiveDecisionOracleVector(
      vectorId: 'interim-continue-final-efficacy',
      firstLookZ: 1.20,
      finalLookZ: 2.10,
      expectedFirstAction: AdaptiveDecisionAction.continueToNextLook,
      expectedFinalAction: AdaptiveDecisionAction.efficacy,
      rationale: 'Continues at look one and crosses final efficacy.',
    ),
    AdaptiveDecisionOracleVector(
      vectorId: 'interim-continue-final-null',
      firstLookZ: 1.20,
      finalLookZ: 1.90,
      expectedFirstAction: AdaptiveDecisionAction.continueToNextLook,
      expectedFinalAction: AdaptiveDecisionAction.completeNoEfficacy,
      rationale: 'Continues at look one and does not cross final efficacy.',
    ),
    AdaptiveDecisionOracleVector(
      vectorId: 'boundary-equality',
      firstLookZ: 2.80,
      finalLookZ: 0,
      expectedFirstAction: AdaptiveDecisionAction.efficacy,
      expectedFinalAction: AdaptiveDecisionAction.efficacy,
      rationale: 'Boundary equality is included in the stopping rule.',
    ),
  ];
}

final class _XorShift32Normal {
  static const int _mask32 = 0xffffffff;
  static const double _twoPow32 = 4294967296.0;

  int _state;
  double? _spare;

  _XorShift32Normal(int seed) : _state = seed & _mask32 {
    if (_state == 0) _state = 0x6d2b79f5;
  }

  int _nextUint32() {
    var value = _state;
    value ^= (value << 13) & _mask32;
    value ^= value >> 17;
    value ^= (value << 5) & _mask32;
    _state = value & _mask32;
    return _state;
  }

  double nextUniform() {
    final value = (_nextUint32() + 0.5) / _twoPow32;
    return value <= 0 ? 0.5 / _twoPow32 : value;
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
  for (final codeUnit in utf8.encode(value)) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

Object? _canonicalize(Object? value) {
  if (value == null || value is String || value is bool || value is num) {
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
