import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../entities/credibility_target_population_transportability.dart';
import '../entities/credibility_transportability_sensitivity.dart';

final class TransportabilityBiasFunctionSensitivityFixture {
  static const String boundary =
      'This synthetic sensitivity package can expose how prespecified '
      'violations change a target estimand, but passing cannot establish '
      'conditional transportability, identify an unknown clinical effect, or '
      'repair structural positivity failure. It is methodology-governance '
      'evidence only, not clinical validation, benefit, safety, regulatory '
      'acceptance, or medical advice.';

  static CredibilityTransportabilitySensitivityPackage build({
    required CredibilityTargetPopulationTransportabilityPackage
    transportPackage,
  }) {
    final contract = _contract(transportPackage);
    final grid = _grid(contract);
    final scenarios = _scenarios();
    return CredibilityTransportabilitySensitivityPackage(
      packageId: 'parkinsum-synthetic-transportability-sensitivity',
      transportPackage: transportPackage,
      transportPackageSha256: transportPackage.packageSha256,
      configurationSha256: transportPackage.configurationSha256,
      algorithmSourceBundleSha256: transportPackage.algorithmSourceBundleSha256,
      contract: contract,
      gridPoints: grid,
      localCases: _localCases(contract),
      globalIndices: transportGlobalSensitivityIndices(grid),
      partialIdentification: _partialIdentification(contract, grid),
      scenarios: scenarios,
      operatingResults: TransportSensitivityOperatingSimulator(
        seed: 0x73656e73,
      ).run(scenarios),
      independentReplication: TransportSensitivityIndependentReplication(
        language: 'Python',
        dependencyLock: 'python-stdlib-only',
        scriptPath: 'tool/independent_transportability_sensitivity_oracle.py',
        scriptSha256: CredibilityTransportabilitySensitivityVerifier
            .expectedIndependentScriptSha256,
        cases: const {
          'no_violation': 0.18,
          'decision_tipping': 0.10,
          'null_crossing': -0.0175,
          'protective_shift': 0.26,
          'measurement_only': 0.14,
          'dependent_modifiers': 0.08625,
        },
        gridSummary: const {
          'total_points': 2625,
          'admissible_points': 2375,
          'excluded_points': 250,
          'lower_effect': -0.0175,
          'upper_effect': 0.3775,
          'decision_tipping_points': 465,
          'null_crossing_points': 12,
        },
        tolerance: 1e-12,
        importsProductionCode: false,
        importsGoldenOutputs: false,
      ),
      allPrespecifiedResultsRetained: true,
      analysisStartedAtUtc: '2026-08-27T12:05:00Z',
      analysisCompletedAtUtc: '2026-08-27T12:35:00Z',
      revoked: false,
      syntheticDemoOnly: true,
      boundary: boundary,
    );
  }

  static TransportBiasSensitivityContract _contract(
    CredibilityTargetPopulationTransportabilityPackage transportPackage,
  ) => TransportBiasSensitivityContract(
    contractId: 'target-transportability-bias-sensitivity-v1',
    targetEstimand: transportPackage.contract.causalContrast,
    biasFunctionDefinition: 'u(a,X) = E[Y^a | X,S=1] - E[Y^a | X,S=0]',
    deltaDefinition:
        'delta(X) = u(1,X) - u(0,X); axes parameterize E_target[delta(X)]',
    adjustmentFormula:
        'adjusted target effect = naive target effect - E_target[delta(X)]',
    outcomeScale: 'synthetic continuous mean-difference scale',
    referenceControlMean: 0.275,
    naiveEstimate: 0.18,
    naiveStandardError: 0.04,
    decisionThreshold: 0.10,
    nullThreshold: 0,
    axes: _axes(),
    elicitationRecords: _elicitationRecords(),
    deterministicGridId: 'cartesian-3x7x5x5x5-v1',
    simulatorCodeSha256: _digest(
      'transportability-bias-function-sensitivity-simulator-v1',
    ),
    independentScriptSha256: CredibilityTransportabilitySensitivityVerifier
        .expectedIndependentScriptSha256,
    authoredAtUtc: '2026-08-27T10:00:00Z',
    elicitationFrozenAtUtc: '2026-08-27T11:00:00Z',
    referenceResultVisibleAtUtc: '2026-08-27T12:00:00Z',
    boundary: boundary,
  );

  static List<BiasFunctionAxis> _axes() => [
    BiasFunctionAxis(
      axisId: 'u0',
      label: 'Control potential-outcome selection bias',
      units: 'outcome-mean difference',
      minimum: -0.08,
      maximum: 0.08,
      values: const [-0.08, 0, 0.08],
      interpretation:
          'Trial-minus-target control potential-outcome mean after measured covariates.',
      provenance:
          'Result-blind elicitation informed by src.pmc.dahabreh.transport-bias-functions.2023.',
      resultBlind: true,
    ),
    BiasFunctionAxis(
      axisId: 'delta',
      label: 'Treatment-effect selection bias',
      units: 'outcome-mean difference',
      minimum: -0.12,
      maximum: 0.12,
      values: const [-0.12, -0.08, -0.04, 0, 0.04, 0.08, 0.12],
      interpretation:
          'Difference between treatment and control bias functions averaged over the target.',
      provenance:
          'Result-blind elicitation informed by bias-function and global-sensitivity methods.',
      resultBlind: true,
    ),
    BiasFunctionAxis(
      axisId: 'modifier_slope',
      label: 'Omitted effect-modifier slope',
      units: 'effect per standardized modifier unit',
      minimum: -0.06,
      maximum: 0.06,
      values: const [-0.06, -0.03, 0, 0.03, 0.06],
      interpretation:
          'Linear shift induced by a standardized unmeasured effect modifier.',
      provenance:
          'Prospective synthetic stress range; not estimated from patient data.',
      resultBlind: true,
    ),
    BiasFunctionAxis(
      axisId: 'measurement_shift',
      label: 'Cross-sample measurement shift',
      units: 'outcome-mean difference',
      minimum: -0.04,
      maximum: 0.04,
      values: const [-0.04, -0.02, 0, 0.02, 0.04],
      interpretation:
          'Outcome or modifier measurement alignment error across trial and target samples.',
      provenance:
          'Prospective measurement-review stress range; not a correction claim.',
      resultBlind: true,
    ),
    BiasFunctionAxis(
      axisId: 'modifier_correlation',
      label: 'Dependence among sensitivity modifiers',
      units: 'correlation-like stress coefficient',
      minimum: -0.75,
      maximum: 0.75,
      values: const [-0.75, -0.375, 0, 0.375, 0.75],
      interpretation:
          'Dependence stress that changes the measurement-shift contribution.',
      provenance:
          'Prospective global-sensitivity dependence grid; not an observed correlation.',
      resultBlind: true,
    ),
  ];

  static List<SensitivityElicitationRecord> _elicitationRecords() => [
    SensitivityElicitationRecord(
      recordId: 'elicitation-methods-001',
      role: 'causal-methods reviewer',
      organization: 'synthetic independent methods panel',
      axisIds: const ['u0', 'delta', 'modifier_slope'],
      method: 'structured result-blind plausible-range elicitation',
      rationale:
          'Retain sign-reversing and decision-tipping violations without selecting a preferred value.',
      observedAtUtc: '2026-08-27T10:15:00Z',
      beforeReferenceResult: true,
      independentOfModelDevelopers: true,
      disposition: 'retained',
    ),
    SensitivityElicitationRecord(
      recordId: 'elicitation-measurement-001',
      role: 'measurement reviewer',
      organization: 'synthetic terminology and measurement panel',
      axisIds: const ['measurement_shift'],
      method: 'cross-sample measurement stress review',
      rationale:
          'Keep possible measurement non-equivalence separate from unmeasured effect modification.',
      observedAtUtc: '2026-08-27T10:30:00Z',
      beforeReferenceResult: true,
      independentOfModelDevelopers: true,
      disposition: 'retained',
    ),
    SensitivityElicitationRecord(
      recordId: 'elicitation-dependence-001',
      role: 'simulation statistician',
      organization: 'synthetic operating-characteristics panel',
      axisIds: const ['modifier_correlation'],
      method: 'prespecified dependence stress grid',
      rationale:
          'Prevent an independence assumption from silently narrowing the sensitivity region.',
      observedAtUtc: '2026-08-27T10:45:00Z',
      beforeReferenceResult: true,
      independentOfModelDevelopers: false,
      disposition: 'retained',
    ),
  ];

  static List<BiasFunctionGridPoint> _grid(
    TransportBiasSensitivityContract contract,
  ) {
    final axes = {for (final axis in contract.axes) axis.axisId: axis.values};
    final points = <BiasFunctionGridPoint>[];
    var index = 0;
    for (final u0 in axes['u0']!) {
      for (final delta in axes['delta']!) {
        for (final slope in axes['modifier_slope']!) {
          for (final measurement in axes['measurement_shift']!) {
            for (final correlation in axes['modifier_correlation']!) {
              final bias = transportSensitivityWeightedBias(
                delta,
                slope,
                measurement,
                correlation,
              );
              final effect = contract.naiveEstimate - bias;
              final control = contract.referenceControlMean - u0;
              final reasons = <String>[];
              if ((u0 + delta).abs() > 0.18 + 1e-12) {
                reasons.add(
                  'u1 outside the prespecified [-0.18,0.18] plausibility envelope',
                );
              }
              if (bias.abs() > 0.20 + 1e-12) {
                reasons.add(
                  'weighted bias outside the prespecified [-0.20,0.20] envelope',
                );
              }
              points.add(
                BiasFunctionGridPoint(
                  pointId: 'grid-${index.toString().padLeft(4, '0')}',
                  u0: u0,
                  delta: delta,
                  modifierSlope: slope,
                  measurementShift: measurement,
                  modifierCorrelation: correlation,
                  weightedBias: bias,
                  adjustedControlMean: control,
                  adjustedTreatmentMean: control + effect,
                  adjustedEffect: effect,
                  admissible: reasons.isEmpty,
                  exclusionReason: reasons.isEmpty ? null : reasons.join('; '),
                  decisionTipping: effect <= contract.decisionThreshold + 1e-12,
                  nullCrossing: effect <= contract.nullThreshold + 1e-12,
                ),
              );
              index++;
            }
          }
        }
      }
    }
    return points;
  }

  static List<LocalBiasFunctionCase> _localCases(
    TransportBiasSensitivityContract contract,
  ) => [
    _local(
      contract,
      'no_violation',
      0,
      0,
      0,
      0,
      0,
      'Reference assumption with no bias-function violation.',
    ),
    _local(
      contract,
      'decision_tipping',
      0,
      0.08,
      0,
      0,
      0,
      'Exactly reaches the prespecified decision threshold.',
    ),
    _local(
      contract,
      'null_crossing',
      0,
      0.12,
      0.06,
      0.04,
      0.75,
      'Joint violation crosses the null without exceeding the admissible bias envelope.',
    ),
    _local(
      contract,
      'protective_shift',
      -0.08,
      -0.08,
      0,
      0,
      0,
      'Opposite-direction selection violation increases the adjusted effect.',
    ),
    _local(
      contract,
      'measurement_only',
      0,
      0,
      0,
      0.04,
      0,
      'Measurement non-equivalence alone changes the target contrast.',
    ),
    _local(
      contract,
      'dependent_modifiers',
      0.08,
      0.04,
      0.06,
      0.02,
      0.75,
      'Correlated modifier and measurement stress approaches decision reversal.',
    ),
  ];

  static LocalBiasFunctionCase _local(
    TransportBiasSensitivityContract contract,
    String id,
    double u0,
    double delta,
    double slope,
    double measurement,
    double correlation,
    String interpretation,
  ) => LocalBiasFunctionCase(
    caseId: id,
    u0: u0,
    delta: delta,
    modifierSlope: slope,
    measurementShift: measurement,
    modifierCorrelation: correlation,
    adjustedEffect:
        contract.naiveEstimate -
        transportSensitivityWeightedBias(
          delta,
          slope,
          measurement,
          correlation,
        ),
    interpretation: interpretation,
  );

  static PartialIdentificationRegion _partialIdentification(
    TransportBiasSensitivityContract contract,
    List<BiasFunctionGridPoint> grid,
  ) {
    final admissible = grid.where((point) => point.admissible).toList();
    final lower = admissible
        .map((point) => point.adjustedEffect)
        .reduce(math.min);
    final upper = admissible
        .map((point) => point.adjustedEffect)
        .reduce(math.max);
    final decision = admissible.where((point) => point.decisionTipping).length;
    final nulls = admissible.where((point) => point.nullCrossing).length;
    return PartialIdentificationRegion(
      lowerEffect: lower,
      upperEffect: upper,
      lowerConfidenceEnvelope: lower - 1.96 * contract.naiveStandardError,
      upperConfidenceEnvelope: upper + 1.96 * contract.naiveStandardError,
      totalPoints: grid.length,
      admissiblePoints: admissible.length,
      excludedPoints: grid.length - admissible.length,
      decisionTippingPoints: decision,
      nullCrossingPoints: nulls,
      decisionTippingFraction: decision / admissible.length,
      nullCrossingFraction: nulls / admissible.length,
      interpretation:
          'Range over every retained admissible parameter combination; it is not a confidence interval or a learned effect distribution.',
    );
  }

  static List<TransportSensitivityScenario> _scenarios() => const [
    TransportSensitivityScenario(
      scenarioId: 'reference-no-violation',
      repetitions: 10000,
      trueEffect: 0.18,
      actualBias: 0,
      assumedBias: 0,
      supportSatisfied: true,
      elicitationConsensus: true,
      limitation: 'No manufactured violation; reference calibration only.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'omitted-effect-modifier',
      repetitions: 10000,
      trueEffect: 0.10,
      actualBias: 0.08,
      assumedBias: 0.08,
      supportSatisfied: true,
      elicitationConsensus: true,
      limitation:
          'A single omitted modifier creates a decision-threshold case.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'severe-unmeasured-modifier',
      repetitions: 10000,
      trueEffect: -0.0175,
      actualBias: 0.1975,
      assumedBias: 0.1975,
      supportSatisfied: true,
      elicitationConsensus: true,
      limitation: 'Joint unmeasured modifier stress crosses the null.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'measurement-error',
      repetitions: 10000,
      trueEffect: 0.14,
      actualBias: 0.04,
      assumedBias: 0.04,
      supportSatisfied: true,
      elicitationConsensus: true,
      limitation: 'Only cross-sample measurement alignment is violated.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'dependent-modifiers',
      repetitions: 10000,
      trueEffect: 0.08625,
      actualBias: 0.09375,
      assumedBias: 0.09375,
      supportSatisfied: true,
      elicitationConsensus: true,
      limitation: 'Modifier and measurement contributions are dependent.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'dual-model-misspecification',
      repetitions: 10000,
      trueEffect: 0.08,
      actualBias: 0.10,
      assumedBias: 0.04,
      supportSatisfied: true,
      elicitationConsensus: true,
      limitation:
          'Sampling/outcome misspecification leaves residual bias after adjustment.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'structural-positivity-failure',
      repetitions: 10000,
      trueEffect: null,
      actualBias: null,
      assumedBias: null,
      supportSatisfied: false,
      elicitationConsensus: true,
      limitation:
          'A target region has no trial support; no effect estimate is identified.',
    ),
    TransportSensitivityScenario(
      scenarioId: 'incompatible-elicitation',
      repetitions: 10000,
      trueEffect: null,
      actualBias: null,
      assumedBias: null,
      supportSatisfied: true,
      elicitationConsensus: false,
      limitation:
          'Result-blind experts supply incompatible ranges; no preferred value is selected.',
    ),
  ];
}

final class TransportSensitivityOperatingSimulator {
  final int seed;

  const TransportSensitivityOperatingSimulator({required this.seed});

  List<TransportSensitivityOperatingResult> run(
    List<TransportSensitivityScenario> scenarios,
  ) => [
    for (var index = 0; index < scenarios.length; index++)
      _runScenario(scenarios[index], index),
  ];

  TransportSensitivityOperatingResult _runScenario(
    TransportSensitivityScenario scenario,
    int scenarioIndex,
  ) {
    if (!scenario.supportSatisfied) {
      return TransportSensitivityOperatingResult(
        scenarioId: scenario.scenarioId,
        status: SensitivityOperatingStatus.heldNonidentifiable,
        repetitions: scenario.repetitions,
        meanAdjustedEstimate: null,
        bias: null,
        coverage95: null,
        decisionTippingProbability: null,
        nullCrossingProbability: null,
        monteCarloStandardError: null,
        disposition:
            'Held: structural positivity failure requires additional identifying information.',
      );
    }
    if (!scenario.elicitationConsensus) {
      return TransportSensitivityOperatingResult(
        scenarioId: scenario.scenarioId,
        status: SensitivityOperatingStatus.heldNoConsensus,
        repetitions: scenario.repetitions,
        meanAdjustedEstimate: null,
        bias: null,
        coverage95: null,
        decisionTippingProbability: null,
        nullCrossingProbability: null,
        monteCarloStandardError: null,
        disposition:
            'Held: incompatible result-blind ranges remain visible without averaging.',
      );
    }
    final truth = scenario.trueEffect!;
    final actualBias = scenario.actualBias!;
    final assumedBias = scenario.assumedBias!;
    const standardError = 0.04;
    final random = _XorShift32(seed ^ ((scenarioIndex + 1) * 0x9e3779b1));
    var sum = 0.0;
    var coverage = 0;
    var decision = 0;
    var nulls = 0;
    for (var repetition = 0; repetition < scenario.repetitions; repetition++) {
      final naive =
          truth + actualBias + standardError * random.nextStandardNormal();
      final adjusted = naive - assumedBias;
      sum += adjusted;
      if (adjusted - 1.96 * standardError <= truth &&
          adjusted + 1.96 * standardError >= truth) {
        coverage++;
      }
      if (adjusted <= 0.10) decision++;
      if (adjusted <= 0) nulls++;
    }
    final mean = sum / scenario.repetitions;
    return TransportSensitivityOperatingResult(
      scenarioId: scenario.scenarioId,
      status: SensitivityOperatingStatus.estimated,
      repetitions: scenario.repetitions,
      meanAdjustedEstimate: mean,
      bias: mean - truth,
      coverage95: coverage / scenario.repetitions,
      decisionTippingProbability: decision / scenario.repetitions,
      nullCrossingProbability: nulls / scenario.repetitions,
      monteCarloStandardError: standardError / math.sqrt(scenario.repetitions),
      disposition:
          'Estimated only inside the prespecified synthetic identifiable scenario.',
    );
  }
}

final class _XorShift32 {
  int _state;
  double? _spare;

  _XorShift32(int seed) : _state = seed & 0xffffffff {
    if (_state == 0) _state = 0x6d2b79f5;
  }

  int _nextUint32() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return _state;
  }

  double _nextUnit() => (_nextUint32() + 1) / 4294967297;

  double nextStandardNormal() {
    final spare = _spare;
    if (spare != null) {
      _spare = null;
      return spare;
    }
    final radius = math.sqrt(-2 * math.log(_nextUnit()));
    final angle = 2 * math.pi * _nextUnit();
    _spare = radius * math.sin(angle);
    return radius * math.cos(angle);
  }
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
