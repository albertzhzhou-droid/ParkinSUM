import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'credibility_target_population_transportability.dart';

enum TransportSensitivityStatus { mechanicallyObserved, held, failed, revoked }

enum SensitivityOperatingStatus {
  estimated,
  heldNonidentifiable,
  heldNoConsensus,
}

enum TransportSensitivityFindingKind {
  futureSchema,
  upstreamIdentity,
  runtimeIdentity,
  chronology,
  contractIncomplete,
  signConventionDrift,
  axisCatalog,
  elicitationIncomplete,
  postResultElicitation,
  gridIncomplete,
  gridArithmetic,
  exclusionLaundered,
  localCaseDrift,
  globalIndexDrift,
  partialBoundsDrift,
  tippingRegionDrift,
  scenarioCatalog,
  operatingCalibration,
  nonidentifiableEstimated,
  noConsensusEstimated,
  independentReplication,
  resultRetention,
  boundaryOverclaim,
  revoked,
}

final class BiasFunctionAxis {
  final String axisId;
  final String label;
  final String units;
  final double minimum;
  final double maximum;
  final List<double> values;
  final String interpretation;
  final String provenance;
  final bool resultBlind;

  BiasFunctionAxis({
    required this.axisId,
    required this.label,
    required this.units,
    required this.minimum,
    required this.maximum,
    required List<double> values,
    required this.interpretation,
    required this.provenance,
    required this.resultBlind,
  }) : values = List.unmodifiable(values);

  BiasFunctionAxis copyWith({
    String? axisId,
    double? minimum,
    double? maximum,
    List<double>? values,
    String? provenance,
    bool? resultBlind,
  }) => BiasFunctionAxis(
    axisId: axisId ?? this.axisId,
    label: label,
    units: units,
    minimum: minimum ?? this.minimum,
    maximum: maximum ?? this.maximum,
    values: values ?? this.values,
    interpretation: interpretation,
    provenance: provenance ?? this.provenance,
    resultBlind: resultBlind ?? this.resultBlind,
  );

  Map<String, Object?> toJson() => {
    'axis_id': axisId,
    'label': label,
    'units': units,
    'minimum': minimum,
    'maximum': maximum,
    'values': values,
    'interpretation': interpretation,
    'provenance': provenance,
    'result_blind': resultBlind,
  };
}

final class SensitivityElicitationRecord {
  final String recordId;
  final String role;
  final String organization;
  final List<String> axisIds;
  final String method;
  final String rationale;
  final String observedAtUtc;
  final bool beforeReferenceResult;
  final bool independentOfModelDevelopers;
  final String disposition;

  SensitivityElicitationRecord({
    required this.recordId,
    required this.role,
    required this.organization,
    required List<String> axisIds,
    required this.method,
    required this.rationale,
    required this.observedAtUtc,
    required this.beforeReferenceResult,
    required this.independentOfModelDevelopers,
    required this.disposition,
  }) : axisIds = List.unmodifiable(axisIds);

  SensitivityElicitationRecord copyWith({
    String? recordId,
    List<String>? axisIds,
    String? observedAtUtc,
    bool? beforeReferenceResult,
    bool? independentOfModelDevelopers,
    String? disposition,
  }) => SensitivityElicitationRecord(
    recordId: recordId ?? this.recordId,
    role: role,
    organization: organization,
    axisIds: axisIds ?? this.axisIds,
    method: method,
    rationale: rationale,
    observedAtUtc: observedAtUtc ?? this.observedAtUtc,
    beforeReferenceResult: beforeReferenceResult ?? this.beforeReferenceResult,
    independentOfModelDevelopers:
        independentOfModelDevelopers ?? this.independentOfModelDevelopers,
    disposition: disposition ?? this.disposition,
  );

  Map<String, Object?> toJson() => {
    'record_id': recordId,
    'role': role,
    'organization': organization,
    'axis_ids': axisIds,
    'method': method,
    'rationale': rationale,
    'observed_at_utc': observedAtUtc,
    'before_reference_result': beforeReferenceResult,
    'independent_of_model_developers': independentOfModelDevelopers,
    'disposition': disposition,
  };
}

final class TransportBiasSensitivityContract {
  final String contractId;
  final String targetEstimand;
  final String biasFunctionDefinition;
  final String deltaDefinition;
  final String adjustmentFormula;
  final String outcomeScale;
  final double referenceControlMean;
  final double naiveEstimate;
  final double naiveStandardError;
  final double decisionThreshold;
  final double nullThreshold;
  final List<BiasFunctionAxis> axes;
  final List<SensitivityElicitationRecord> elicitationRecords;
  final String deterministicGridId;
  final String simulatorCodeSha256;
  final String independentScriptSha256;
  final String authoredAtUtc;
  final String elicitationFrozenAtUtc;
  final String referenceResultVisibleAtUtc;
  final String boundary;

  TransportBiasSensitivityContract({
    required this.contractId,
    required this.targetEstimand,
    required this.biasFunctionDefinition,
    required this.deltaDefinition,
    required this.adjustmentFormula,
    required this.outcomeScale,
    required this.referenceControlMean,
    required this.naiveEstimate,
    required this.naiveStandardError,
    required this.decisionThreshold,
    required this.nullThreshold,
    required List<BiasFunctionAxis> axes,
    required List<SensitivityElicitationRecord> elicitationRecords,
    required this.deterministicGridId,
    required this.simulatorCodeSha256,
    required this.independentScriptSha256,
    required this.authoredAtUtc,
    required this.elicitationFrozenAtUtc,
    required this.referenceResultVisibleAtUtc,
    required this.boundary,
  }) : axes = List.unmodifiable(axes),
       elicitationRecords = List.unmodifiable(elicitationRecords);

  TransportBiasSensitivityContract copyWith({
    String? targetEstimand,
    String? biasFunctionDefinition,
    String? adjustmentFormula,
    double? referenceControlMean,
    double? naiveEstimate,
    List<BiasFunctionAxis>? axes,
    List<SensitivityElicitationRecord>? elicitationRecords,
    String? simulatorCodeSha256,
    String? independentScriptSha256,
    String? authoredAtUtc,
    String? elicitationFrozenAtUtc,
    String? referenceResultVisibleAtUtc,
  }) => TransportBiasSensitivityContract(
    contractId: contractId,
    targetEstimand: targetEstimand ?? this.targetEstimand,
    biasFunctionDefinition:
        biasFunctionDefinition ?? this.biasFunctionDefinition,
    deltaDefinition: deltaDefinition,
    adjustmentFormula: adjustmentFormula ?? this.adjustmentFormula,
    outcomeScale: outcomeScale,
    referenceControlMean: referenceControlMean ?? this.referenceControlMean,
    naiveEstimate: naiveEstimate ?? this.naiveEstimate,
    naiveStandardError: naiveStandardError,
    decisionThreshold: decisionThreshold,
    nullThreshold: nullThreshold,
    axes: axes ?? this.axes,
    elicitationRecords: elicitationRecords ?? this.elicitationRecords,
    deterministicGridId: deterministicGridId,
    simulatorCodeSha256: simulatorCodeSha256 ?? this.simulatorCodeSha256,
    independentScriptSha256:
        independentScriptSha256 ?? this.independentScriptSha256,
    authoredAtUtc: authoredAtUtc ?? this.authoredAtUtc,
    elicitationFrozenAtUtc:
        elicitationFrozenAtUtc ?? this.elicitationFrozenAtUtc,
    referenceResultVisibleAtUtc:
        referenceResultVisibleAtUtc ?? this.referenceResultVisibleAtUtc,
    boundary: boundary,
  );

  Map<String, Object?> toJson() => {
    'contract_id': contractId,
    'target_estimand': targetEstimand,
    'bias_function_definition': biasFunctionDefinition,
    'delta_definition': deltaDefinition,
    'adjustment_formula': adjustmentFormula,
    'outcome_scale': outcomeScale,
    'reference_control_mean': referenceControlMean,
    'naive_estimate': naiveEstimate,
    'naive_standard_error': naiveStandardError,
    'decision_threshold': decisionThreshold,
    'null_threshold': nullThreshold,
    'axes': axes.map((axis) => axis.toJson()).toList(),
    'elicitation_records': elicitationRecords
        .map((record) => record.toJson())
        .toList(),
    'deterministic_grid_id': deterministicGridId,
    'simulator_code_sha256': simulatorCodeSha256,
    'independent_script_sha256': independentScriptSha256,
    'authored_at_utc': authoredAtUtc,
    'elicitation_frozen_at_utc': elicitationFrozenAtUtc,
    'reference_result_visible_at_utc': referenceResultVisibleAtUtc,
    'boundary': boundary,
  };
}

final class BiasFunctionGridPoint {
  final String pointId;
  final double u0;
  final double delta;
  final double modifierSlope;
  final double measurementShift;
  final double modifierCorrelation;
  final double weightedBias;
  final double adjustedControlMean;
  final double adjustedTreatmentMean;
  final double adjustedEffect;
  final bool admissible;
  final String? exclusionReason;
  final bool decisionTipping;
  final bool nullCrossing;

  const BiasFunctionGridPoint({
    required this.pointId,
    required this.u0,
    required this.delta,
    required this.modifierSlope,
    required this.measurementShift,
    required this.modifierCorrelation,
    required this.weightedBias,
    required this.adjustedControlMean,
    required this.adjustedTreatmentMean,
    required this.adjustedEffect,
    required this.admissible,
    required this.exclusionReason,
    required this.decisionTipping,
    required this.nullCrossing,
  });

  BiasFunctionGridPoint copyWith({
    double? weightedBias,
    double? adjustedEffect,
    bool? admissible,
    String? exclusionReason,
    bool? decisionTipping,
    bool? nullCrossing,
  }) => BiasFunctionGridPoint(
    pointId: pointId,
    u0: u0,
    delta: delta,
    modifierSlope: modifierSlope,
    measurementShift: measurementShift,
    modifierCorrelation: modifierCorrelation,
    weightedBias: weightedBias ?? this.weightedBias,
    adjustedControlMean: adjustedControlMean,
    adjustedTreatmentMean: adjustedTreatmentMean,
    adjustedEffect: adjustedEffect ?? this.adjustedEffect,
    admissible: admissible ?? this.admissible,
    exclusionReason: exclusionReason ?? this.exclusionReason,
    decisionTipping: decisionTipping ?? this.decisionTipping,
    nullCrossing: nullCrossing ?? this.nullCrossing,
  );

  Map<String, Object?> toJson() => {
    'point_id': pointId,
    'u0': u0,
    'delta': delta,
    'modifier_slope': modifierSlope,
    'measurement_shift': measurementShift,
    'modifier_correlation': modifierCorrelation,
    'weighted_bias': weightedBias,
    'adjusted_control_mean': adjustedControlMean,
    'adjusted_treatment_mean': adjustedTreatmentMean,
    'adjusted_effect': adjustedEffect,
    'admissible': admissible,
    'exclusion_reason': exclusionReason,
    'decision_tipping': decisionTipping,
    'null_crossing': nullCrossing,
  };
}

final class LocalBiasFunctionCase {
  final String caseId;
  final double u0;
  final double delta;
  final double modifierSlope;
  final double measurementShift;
  final double modifierCorrelation;
  final double adjustedEffect;
  final String interpretation;

  const LocalBiasFunctionCase({
    required this.caseId,
    required this.u0,
    required this.delta,
    required this.modifierSlope,
    required this.measurementShift,
    required this.modifierCorrelation,
    required this.adjustedEffect,
    required this.interpretation,
  });

  LocalBiasFunctionCase copyWith({double? adjustedEffect}) =>
      LocalBiasFunctionCase(
        caseId: caseId,
        u0: u0,
        delta: delta,
        modifierSlope: modifierSlope,
        measurementShift: measurementShift,
        modifierCorrelation: modifierCorrelation,
        adjustedEffect: adjustedEffect ?? this.adjustedEffect,
        interpretation: interpretation,
      );

  Map<String, Object?> toJson() => {
    'case_id': caseId,
    'u0': u0,
    'delta': delta,
    'modifier_slope': modifierSlope,
    'measurement_shift': measurementShift,
    'modifier_correlation': modifierCorrelation,
    'adjusted_effect': adjustedEffect,
    'interpretation': interpretation,
  };
}

final class GlobalSensitivityIndex {
  final String axisId;
  final double firstOrderIndex;
  final double totalEffectIndex;
  final double minimumConditionalMean;
  final double maximumConditionalMean;

  const GlobalSensitivityIndex({
    required this.axisId,
    required this.firstOrderIndex,
    required this.totalEffectIndex,
    required this.minimumConditionalMean,
    required this.maximumConditionalMean,
  });

  GlobalSensitivityIndex copyWith({
    double? firstOrderIndex,
    double? totalEffectIndex,
  }) => GlobalSensitivityIndex(
    axisId: axisId,
    firstOrderIndex: firstOrderIndex ?? this.firstOrderIndex,
    totalEffectIndex: totalEffectIndex ?? this.totalEffectIndex,
    minimumConditionalMean: minimumConditionalMean,
    maximumConditionalMean: maximumConditionalMean,
  );

  Map<String, Object?> toJson() => {
    'axis_id': axisId,
    'first_order_index': firstOrderIndex,
    'total_effect_index': totalEffectIndex,
    'minimum_conditional_mean': minimumConditionalMean,
    'maximum_conditional_mean': maximumConditionalMean,
  };
}

final class PartialIdentificationRegion {
  final double lowerEffect;
  final double upperEffect;
  final double lowerConfidenceEnvelope;
  final double upperConfidenceEnvelope;
  final int totalPoints;
  final int admissiblePoints;
  final int excludedPoints;
  final int decisionTippingPoints;
  final int nullCrossingPoints;
  final double decisionTippingFraction;
  final double nullCrossingFraction;
  final String interpretation;

  const PartialIdentificationRegion({
    required this.lowerEffect,
    required this.upperEffect,
    required this.lowerConfidenceEnvelope,
    required this.upperConfidenceEnvelope,
    required this.totalPoints,
    required this.admissiblePoints,
    required this.excludedPoints,
    required this.decisionTippingPoints,
    required this.nullCrossingPoints,
    required this.decisionTippingFraction,
    required this.nullCrossingFraction,
    required this.interpretation,
  });

  PartialIdentificationRegion copyWith({
    double? lowerEffect,
    double? upperEffect,
    int? decisionTippingPoints,
  }) => PartialIdentificationRegion(
    lowerEffect: lowerEffect ?? this.lowerEffect,
    upperEffect: upperEffect ?? this.upperEffect,
    lowerConfidenceEnvelope: lowerConfidenceEnvelope,
    upperConfidenceEnvelope: upperConfidenceEnvelope,
    totalPoints: totalPoints,
    admissiblePoints: admissiblePoints,
    excludedPoints: excludedPoints,
    decisionTippingPoints: decisionTippingPoints ?? this.decisionTippingPoints,
    nullCrossingPoints: nullCrossingPoints,
    decisionTippingFraction: decisionTippingFraction,
    nullCrossingFraction: nullCrossingFraction,
    interpretation: interpretation,
  );

  Map<String, Object?> toJson() => {
    'lower_effect': lowerEffect,
    'upper_effect': upperEffect,
    'lower_confidence_envelope': lowerConfidenceEnvelope,
    'upper_confidence_envelope': upperConfidenceEnvelope,
    'total_points': totalPoints,
    'admissible_points': admissiblePoints,
    'excluded_points': excludedPoints,
    'decision_tipping_points': decisionTippingPoints,
    'null_crossing_points': nullCrossingPoints,
    'decision_tipping_fraction': decisionTippingFraction,
    'null_crossing_fraction': nullCrossingFraction,
    'interpretation': interpretation,
  };
}

final class TransportSensitivityScenario {
  final String scenarioId;
  final int repetitions;
  final double? trueEffect;
  final double? actualBias;
  final double? assumedBias;
  final bool supportSatisfied;
  final bool elicitationConsensus;
  final String limitation;

  const TransportSensitivityScenario({
    required this.scenarioId,
    required this.repetitions,
    required this.trueEffect,
    required this.actualBias,
    required this.assumedBias,
    required this.supportSatisfied,
    required this.elicitationConsensus,
    required this.limitation,
  });

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'repetitions': repetitions,
    'true_effect': trueEffect,
    'actual_bias': actualBias,
    'assumed_bias': assumedBias,
    'support_satisfied': supportSatisfied,
    'elicitation_consensus': elicitationConsensus,
    'limitation': limitation,
  };
}

final class TransportSensitivityOperatingResult {
  final String scenarioId;
  final SensitivityOperatingStatus status;
  final int repetitions;
  final double? meanAdjustedEstimate;
  final double? bias;
  final double? coverage95;
  final double? decisionTippingProbability;
  final double? nullCrossingProbability;
  final double? monteCarloStandardError;
  final String disposition;

  const TransportSensitivityOperatingResult({
    required this.scenarioId,
    required this.status,
    required this.repetitions,
    required this.meanAdjustedEstimate,
    required this.bias,
    required this.coverage95,
    required this.decisionTippingProbability,
    required this.nullCrossingProbability,
    required this.monteCarloStandardError,
    required this.disposition,
  });

  TransportSensitivityOperatingResult copyWith({
    SensitivityOperatingStatus? status,
    double? meanAdjustedEstimate,
    double? bias,
    double? coverage95,
    String? disposition,
  }) => TransportSensitivityOperatingResult(
    scenarioId: scenarioId,
    status: status ?? this.status,
    repetitions: repetitions,
    meanAdjustedEstimate: meanAdjustedEstimate ?? this.meanAdjustedEstimate,
    bias: bias ?? this.bias,
    coverage95: coverage95 ?? this.coverage95,
    decisionTippingProbability: decisionTippingProbability,
    nullCrossingProbability: nullCrossingProbability,
    monteCarloStandardError: monteCarloStandardError,
    disposition: disposition ?? this.disposition,
  );

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'status': status.name,
    'repetitions': repetitions,
    'mean_adjusted_estimate': meanAdjustedEstimate,
    'bias': bias,
    'coverage_95': coverage95,
    'decision_tipping_probability': decisionTippingProbability,
    'null_crossing_probability': nullCrossingProbability,
    'monte_carlo_standard_error': monteCarloStandardError,
    'disposition': disposition,
  };
}

final class TransportSensitivityIndependentReplication {
  final String language;
  final String dependencyLock;
  final String scriptPath;
  final String scriptSha256;
  final Map<String, double> cases;
  final Map<String, num> gridSummary;
  final double tolerance;
  final bool importsProductionCode;
  final bool importsGoldenOutputs;

  TransportSensitivityIndependentReplication({
    required this.language,
    required this.dependencyLock,
    required this.scriptPath,
    required this.scriptSha256,
    required Map<String, double> cases,
    required Map<String, num> gridSummary,
    required this.tolerance,
    required this.importsProductionCode,
    required this.importsGoldenOutputs,
  }) : cases = Map.unmodifiable(cases),
       gridSummary = Map.unmodifiable(gridSummary);

  TransportSensitivityIndependentReplication copyWith({
    String? scriptSha256,
    Map<String, double>? cases,
    Map<String, num>? gridSummary,
    bool? importsProductionCode,
  }) => TransportSensitivityIndependentReplication(
    language: language,
    dependencyLock: dependencyLock,
    scriptPath: scriptPath,
    scriptSha256: scriptSha256 ?? this.scriptSha256,
    cases: cases ?? this.cases,
    gridSummary: gridSummary ?? this.gridSummary,
    tolerance: tolerance,
    importsProductionCode: importsProductionCode ?? this.importsProductionCode,
    importsGoldenOutputs: importsGoldenOutputs,
  );

  Map<String, Object?> toJson() => {
    'language': language,
    'dependency_lock': dependencyLock,
    'script_path': scriptPath,
    'script_sha256': scriptSha256,
    'cases': {for (final key in cases.keys.toList()..sort()) key: cases[key]},
    'grid_summary': {
      for (final key in gridSummary.keys.toList()..sort())
        key: gridSummary[key],
    },
    'tolerance': tolerance,
    'imports_production_code': importsProductionCode,
    'imports_golden_outputs': importsGoldenOutputs,
  };
}

final class CredibilityTransportabilitySensitivityPackage {
  static const String schema =
      'parkinsum.credibility-transportability-sensitivity-package/1';
  static const int currentSchemaVersion = 1;
  static const String packageVersion = '2026.08.27-v2';

  final int schemaVersion;
  final String packageId;
  final CredibilityTargetPopulationTransportabilityPackage transportPackage;
  final String transportPackageSha256;
  final String configurationSha256;
  final String algorithmSourceBundleSha256;
  final TransportBiasSensitivityContract contract;
  final List<BiasFunctionGridPoint> gridPoints;
  final List<LocalBiasFunctionCase> localCases;
  final List<GlobalSensitivityIndex> globalIndices;
  final PartialIdentificationRegion partialIdentification;
  final List<TransportSensitivityScenario> scenarios;
  final List<TransportSensitivityOperatingResult> operatingResults;
  final TransportSensitivityIndependentReplication independentReplication;
  final bool allPrespecifiedResultsRetained;
  final String analysisStartedAtUtc;
  final String analysisCompletedAtUtc;
  final bool revoked;
  final bool syntheticDemoOnly;
  final String boundary;

  CredibilityTransportabilitySensitivityPackage({
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.transportPackage,
    required this.transportPackageSha256,
    required this.configurationSha256,
    required this.algorithmSourceBundleSha256,
    required this.contract,
    required List<BiasFunctionGridPoint> gridPoints,
    required List<LocalBiasFunctionCase> localCases,
    required List<GlobalSensitivityIndex> globalIndices,
    required this.partialIdentification,
    required List<TransportSensitivityScenario> scenarios,
    required List<TransportSensitivityOperatingResult> operatingResults,
    required this.independentReplication,
    required this.allPrespecifiedResultsRetained,
    required this.analysisStartedAtUtc,
    required this.analysisCompletedAtUtc,
    required this.revoked,
    required this.syntheticDemoOnly,
    required this.boundary,
  }) : gridPoints = List.unmodifiable(gridPoints),
       localCases = List.unmodifiable(localCases),
       globalIndices = List.unmodifiable(globalIndices),
       scenarios = List.unmodifiable(scenarios),
       operatingResults = List.unmodifiable(operatingResults);

  CredibilityTransportabilitySensitivityPackage copyWith({
    int? schemaVersion,
    String? transportPackageSha256,
    String? configurationSha256,
    String? algorithmSourceBundleSha256,
    TransportBiasSensitivityContract? contract,
    List<BiasFunctionGridPoint>? gridPoints,
    List<LocalBiasFunctionCase>? localCases,
    List<GlobalSensitivityIndex>? globalIndices,
    PartialIdentificationRegion? partialIdentification,
    List<TransportSensitivityScenario>? scenarios,
    List<TransportSensitivityOperatingResult>? operatingResults,
    TransportSensitivityIndependentReplication? independentReplication,
    bool? allPrespecifiedResultsRetained,
    String? analysisStartedAtUtc,
    String? analysisCompletedAtUtc,
    bool? revoked,
    bool? syntheticDemoOnly,
    String? boundary,
  }) => CredibilityTransportabilitySensitivityPackage(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    packageId: packageId,
    transportPackage: transportPackage,
    transportPackageSha256:
        transportPackageSha256 ?? this.transportPackageSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    algorithmSourceBundleSha256:
        algorithmSourceBundleSha256 ?? this.algorithmSourceBundleSha256,
    contract: contract ?? this.contract,
    gridPoints: gridPoints ?? this.gridPoints,
    localCases: localCases ?? this.localCases,
    globalIndices: globalIndices ?? this.globalIndices,
    partialIdentification: partialIdentification ?? this.partialIdentification,
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
    'transport_package_sha256': transportPackageSha256,
    'configuration_sha256': configurationSha256,
    'algorithm_source_bundle_sha256': algorithmSourceBundleSha256,
    'contract': contract.toJson(),
    'grid_points': gridPoints.map((point) => point.toJson()).toList(),
    'local_cases': localCases.map((item) => item.toJson()).toList(),
    'global_indices': globalIndices.map((item) => item.toJson()).toList(),
    'partial_identification': partialIdentification.toJson(),
    'scenarios': scenarios.map((item) => item.toJson()).toList(),
    'operating_results': operatingResults.map((item) => item.toJson()).toList(),
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

final class TransportSensitivityFinding {
  final TransportSensitivityFindingKind kind;
  final String detail;
  final List<String> affectedIds;

  TransportSensitivityFinding({
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

final class TransportSensitivityAssessment {
  final CredibilityTransportabilitySensitivityPackage package;
  final TransportSensitivityStatus status;
  final List<TransportSensitivityFinding> findings;
  final Map<String, String> lanes;
  final Map<String, int> counts;

  TransportSensitivityAssessment({
    required this.package,
    required this.status,
    required List<TransportSensitivityFinding> findings,
    required Map<String, String> lanes,
    required Map<String, int> counts,
  }) : findings = List.unmodifiable(findings),
       lanes = Map.unmodifiable(lanes),
       counts = Map.unmodifiable(counts);

  Map<String, Object?> toJson() => {
    'status': status.name,
    'findings': findings.map((item) => item.toJson()).toList(),
    'lanes': lanes,
    'counts': counts,
    'package': package.toJson(),
  };
}

final class CredibilityTransportabilitySensitivityVerifier {
  const CredibilityTransportabilitySensitivityVerifier();

  static const String expectedIndependentScriptSha256 =
      '9310ac810bbb1d25760d2ad9a239d315e250c857d07f21593ed248f8fd52dfc4';
  static const Set<String> requiredAxes = {
    'u0',
    'delta',
    'modifier_slope',
    'measurement_shift',
    'modifier_correlation',
  };
  static const Map<String, List<double>> expectedAxisValues = {
    'u0': [-0.08, 0, 0.08],
    'delta': [-0.12, -0.08, -0.04, 0, 0.04, 0.08, 0.12],
    'modifier_slope': [-0.06, -0.03, 0, 0.03, 0.06],
    'measurement_shift': [-0.04, -0.02, 0, 0.02, 0.04],
    'modifier_correlation': [-0.75, -0.375, 0, 0.375, 0.75],
  };
  static const Map<String, double> expectedCases = {
    'no_violation': 0.18,
    'decision_tipping': 0.10,
    'null_crossing': -0.0175,
    'protective_shift': 0.26,
    'measurement_only': 0.14,
    'dependent_modifiers': 0.08625,
  };
  static const Map<String, num> expectedGridSummary = {
    'total_points': 2625,
    'admissible_points': 2375,
    'excluded_points': 250,
    'lower_effect': -0.0175,
    'upper_effect': 0.3775,
    'decision_tipping_points': 465,
    'null_crossing_points': 12,
  };
  static const Set<String> requiredScenarios = {
    'reference-no-violation',
    'omitted-effect-modifier',
    'severe-unmeasured-modifier',
    'measurement-error',
    'dependent-modifiers',
    'dual-model-misspecification',
    'structural-positivity-failure',
    'incompatible-elicitation',
  };

  TransportSensitivityAssessment verify(
    CredibilityTransportabilitySensitivityPackage package,
  ) {
    final findings = <TransportSensitivityFinding>[];
    void add(
      TransportSensitivityFindingKind kind,
      String detail, [
      Iterable<String> ids = const [],
    ]) => findings.add(
      TransportSensitivityFinding(
        kind: kind,
        detail: detail,
        affectedIds: ids.toList(),
      ),
    );

    if (package.schemaVersion !=
        CredibilityTransportabilitySensitivityPackage.currentSchemaVersion) {
      add(
        TransportSensitivityFindingKind.futureSchema,
        'Only the current sensitivity schema is accepted.',
      );
    }
    if (package.transportPackageSha256 !=
            package.transportPackage.packageSha256 ||
        package.transportPackageSha256.isEmpty) {
      add(
        TransportSensitivityFindingKind.upstreamIdentity,
        'The exact target-transportability parent package is required.',
      );
    }
    if (package.configurationSha256 !=
            package.transportPackage.configurationSha256 ||
        package.algorithmSourceBundleSha256 !=
            package.transportPackage.algorithmSourceBundleSha256 ||
        !_isSha256(package.configurationSha256) ||
        !_isSha256(package.algorithmSourceBundleSha256)) {
      add(
        TransportSensitivityFindingKind.runtimeIdentity,
        'Runtime configuration and registered source bundle must match upstream.',
      );
    }
    _verifyContract(package, add);
    _verifyGrid(package, add);
    _verifyLocalAndGlobal(package, add);
    _verifyScenarios(package, add);
    _verifyIndependent(package, add);
    if (!package.allPrespecifiedResultsRetained) {
      add(
        TransportSensitivityFindingKind.resultRetention,
        'All grid, local, global, bounds, scenario and replication results are required.',
      );
    }
    final boundary = package.boundary.toLowerCase();
    if (!package.syntheticDemoOnly ||
        !boundary.contains('synthetic') ||
        !boundary.contains('cannot establish') ||
        !boundary.contains('conditional transportability') ||
        !boundary.contains('structural positivity')) {
      add(
        TransportSensitivityFindingKind.boundaryOverclaim,
        'Synthetic, assumption-bound and structural-positivity limits must remain explicit.',
      );
    }
    if (package.revoked) {
      add(
        TransportSensitivityFindingKind.revoked,
        'A revoked sensitivity package cannot remain observed.',
      );
    }

    final unique = <String, TransportSensitivityFinding>{};
    for (final finding in findings) {
      unique['${finding.kind.name}:${finding.detail}:${finding.affectedIds.join(',')}'] =
          finding;
    }
    final retained = unique.values.toList();
    final status = package.revoked
        ? TransportSensitivityStatus.revoked
        : retained.isEmpty
        ? TransportSensitivityStatus.mechanicallyObserved
        : TransportSensitivityStatus.held;
    final kinds = retained.map((item) => item.kind).toSet();
    String lane(Set<TransportSensitivityFindingKind> relevant) =>
        kinds.intersection(relevant).isEmpty ? 'mechanicallyObserved' : 'held';

    return TransportSensitivityAssessment(
      package: package,
      status: status,
      findings: retained,
      lanes: {
        'assumptions': lane({
          TransportSensitivityFindingKind.contractIncomplete,
          TransportSensitivityFindingKind.signConventionDrift,
          TransportSensitivityFindingKind.chronology,
        }),
        'elicitation': lane({
          TransportSensitivityFindingKind.elicitationIncomplete,
          TransportSensitivityFindingKind.postResultElicitation,
        }),
        'parameterSpace': lane({
          TransportSensitivityFindingKind.axisCatalog,
          TransportSensitivityFindingKind.gridIncomplete,
          TransportSensitivityFindingKind.exclusionLaundered,
        }),
        'localSensitivity': lane({
          TransportSensitivityFindingKind.localCaseDrift,
        }),
        'globalSensitivity': lane({
          TransportSensitivityFindingKind.globalIndexDrift,
        }),
        'partialIdentification': lane({
          TransportSensitivityFindingKind.partialBoundsDrift,
        }),
        'tippingRegion': lane({
          TransportSensitivityFindingKind.tippingRegionDrift,
        }),
        'operatingCharacteristics': lane({
          TransportSensitivityFindingKind.scenarioCatalog,
          TransportSensitivityFindingKind.operatingCalibration,
          TransportSensitivityFindingKind.nonidentifiableEstimated,
          TransportSensitivityFindingKind.noConsensusEstimated,
        }),
        'independentReplication': lane({
          TransportSensitivityFindingKind.independentReplication,
        }),
        'unresolvedLimitations': package.syntheticDemoOnly
            ? 'explicitlyHeld'
            : 'held',
      },
      counts: {
        'axes': package.contract.axes.length,
        'elicitationRecords': package.contract.elicitationRecords.length,
        'gridPoints': package.gridPoints.length,
        'admissiblePoints': package.gridPoints
            .where((point) => point.admissible)
            .length,
        'excludedPoints': package.gridPoints
            .where((point) => !point.admissible)
            .length,
        'localCases': package.localCases.length,
        'globalIndices': package.globalIndices.length,
        'scenarios': package.scenarios.length,
        'totalRepetitions': package.scenarios.fold(
          0,
          (sum, scenario) => sum + scenario.repetitions,
        ),
        'independentCases': package.independentReplication.cases.length,
      },
    );
  }

  void _verifyContract(
    CredibilityTransportabilitySensitivityPackage package,
    void Function(TransportSensitivityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final contract = package.contract;
    if ([
          contract.contractId,
          contract.targetEstimand,
          contract.biasFunctionDefinition,
          contract.deltaDefinition,
          contract.adjustmentFormula,
          contract.outcomeScale,
          contract.deterministicGridId,
        ].any((value) => value.trim().isEmpty) ||
        !_isSha256(contract.simulatorCodeSha256) ||
        contract.independentScriptSha256 != expectedIndependentScriptSha256 ||
        (contract.targetEstimand !=
            package.transportPackage.contract.causalContrast) ||
        (contract.referenceControlMean - 0.275).abs() > 1e-12 ||
        (contract.naiveEstimate - 0.18).abs() > 1e-12 ||
        (contract.naiveStandardError - 0.04).abs() > 1e-12) {
      add(
        TransportSensitivityFindingKind.contractIncomplete,
        'Estimand, reference estimate, scale, code and grid identity are required.',
      );
    }
    if (!contract.biasFunctionDefinition.contains('S=1') ||
        !contract.biasFunctionDefinition.contains('S=0') ||
        !contract.deltaDefinition.contains('u(1') ||
        !contract.adjustmentFormula.contains('naive') ||
        !contract.adjustmentFormula.contains('E_target')) {
      add(
        TransportSensitivityFindingKind.signConventionDrift,
        'The direction of u(a,X), delta(X), and target adjustment must be explicit.',
      );
    }
    final axisIds = contract.axes.map((axis) => axis.axisId).toSet();
    if (axisIds.length != requiredAxes.length ||
        !axisIds.containsAll(requiredAxes) ||
        contract.axes.any(
          (axis) =>
              !_sameDoubleList(
                axis.values,
                expectedAxisValues[axis.axisId] ?? const [],
              ) ||
              axis.minimum != axis.values.first ||
              axis.maximum != axis.values.last ||
              axis.values.any((value) => !value.isFinite) ||
              axis.interpretation.trim().isEmpty ||
              axis.provenance.trim().isEmpty ||
              !axis.resultBlind,
        )) {
      add(
        TransportSensitivityFindingKind.axisCatalog,
        'All five ordered, result-blind bias-function axes must be retained.',
      );
    }
    final recordIds = <String>{};
    if (contract.elicitationRecords.length < 3 ||
        contract.elicitationRecords.any(
          (record) =>
              !recordIds.add(record.recordId) ||
              record.role.trim().isEmpty ||
              record.organization.trim().isEmpty ||
              record.method.trim().isEmpty ||
              record.rationale.trim().isEmpty ||
              record.axisIds.isEmpty ||
              !axisIds.containsAll(record.axisIds) ||
              !record.beforeReferenceResult ||
              record.disposition != 'retained',
        )) {
      add(
        TransportSensitivityFindingKind.elicitationIncomplete,
        'Three attributed result-blind elicitation records are required.',
      );
    }
    final authored = DateTime.tryParse(contract.authoredAtUtc);
    final frozen = DateTime.tryParse(contract.elicitationFrozenAtUtc);
    final visible = DateTime.tryParse(contract.referenceResultVisibleAtUtc);
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
        TransportSensitivityFindingKind.chronology,
        'Contract, elicitation freeze, reference visibility and analysis order must be prospective.',
      );
    }
    if (contract.elicitationRecords.any((record) {
      final observed = DateTime.tryParse(record.observedAtUtc);
      return observed == null ||
          visible == null ||
          observed.isAfter(visible) ||
          !record.beforeReferenceResult;
    })) {
      add(
        TransportSensitivityFindingKind.postResultElicitation,
        'Sensitivity ranges cannot be elicited after the reference result.',
      );
    }
  }

  void _verifyGrid(
    CredibilityTransportabilitySensitivityPackage package,
    void Function(TransportSensitivityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final expectedCount = package.contract.axes.fold<int>(
      1,
      (count, axis) => count * axis.values.length,
    );
    final ids = <String>{};
    if (expectedCount != expectedGridSummary['total_points'] ||
        package.gridPoints.length != expectedCount ||
        package.gridPoints.any((point) => !ids.add(point.pointId))) {
      add(
        TransportSensitivityFindingKind.gridIncomplete,
        'The complete deterministic Cartesian parameter grid must be retained once.',
      );
    }
    final arithmeticDrift = <String>[];
    final exclusionDrift = <String>[];
    for (final point in package.gridPoints) {
      final bias = _weightedBias(
        point.delta,
        point.modifierSlope,
        point.measurementShift,
        point.modifierCorrelation,
      );
      final effect = package.contract.naiveEstimate - bias;
      final control = package.contract.referenceControlMean - point.u0;
      final treatment = control + effect;
      final admissible =
          (point.u0 + point.delta).abs() <= 0.18 + 1e-12 &&
          bias.abs() <= 0.20 + 1e-12;
      if ((point.weightedBias - bias).abs() > 1e-12 ||
          (point.adjustedControlMean - control).abs() > 1e-12 ||
          (point.adjustedTreatmentMean - treatment).abs() > 1e-12 ||
          (point.adjustedEffect - effect).abs() > 1e-12 ||
          point.decisionTipping !=
              (effect <= package.contract.decisionThreshold + 1e-12) ||
          point.nullCrossing !=
              (effect <= package.contract.nullThreshold + 1e-12)) {
        arithmeticDrift.add(point.pointId);
      }
      if (point.admissible != admissible ||
          (admissible && point.exclusionReason != null) ||
          (!admissible && (point.exclusionReason?.trim().isEmpty ?? true))) {
        exclusionDrift.add(point.pointId);
      }
    }
    if (arithmeticDrift.isNotEmpty) {
      add(
        TransportSensitivityFindingKind.gridArithmetic,
        'Bias-function arithmetic or tipping classification drifted.',
        arithmeticDrift.take(20),
      );
    }
    if (exclusionDrift.isNotEmpty) {
      add(
        TransportSensitivityFindingKind.exclusionLaundered,
        'Inadmissible parameter combinations require retained reasons.',
        exclusionDrift.take(20),
      );
    }
  }

  void _verifyLocalAndGlobal(
    CredibilityTransportabilitySensitivityPackage package,
    void Function(TransportSensitivityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final cases = {for (final item in package.localCases) item.caseId: item};
    if (cases.length != expectedCases.length ||
        !cases.keys.toSet().containsAll(expectedCases.keys) ||
        expectedCases.entries.any(
          (entry) =>
              (cases[entry.key]!.adjustedEffect - entry.value).abs() > 1e-12,
        )) {
      add(
        TransportSensitivityFindingKind.localCaseDrift,
        'All six manufactured local sensitivity cases must match the frozen oracle.',
      );
    }
    final indices = {
      for (final item in package.globalIndices) item.axisId: item,
    };
    final expectedIndices = {
      for (final item in transportGlobalSensitivityIndices(package.gridPoints))
        item.axisId: item,
    };
    if (indices.length != requiredAxes.length ||
        !indices.keys.toSet().containsAll(requiredAxes) ||
        indices.values.any(
          (item) =>
              !item.firstOrderIndex.isFinite ||
              !item.totalEffectIndex.isFinite ||
              item.firstOrderIndex < -1e-12 ||
              item.firstOrderIndex > 1 + 1e-12 ||
              item.totalEffectIndex < item.firstOrderIndex - 1e-9 ||
              item.totalEffectIndex > 1 + 1e-12 ||
              item.minimumConditionalMean > item.maximumConditionalMean ||
              !expectedIndices.containsKey(item.axisId) ||
              (item.firstOrderIndex -
                          expectedIndices[item.axisId]!.firstOrderIndex)
                      .abs() >
                  1e-12 ||
              (item.totalEffectIndex -
                          expectedIndices[item.axisId]!.totalEffectIndex)
                      .abs() >
                  1e-12 ||
              (item.minimumConditionalMean -
                          expectedIndices[item.axisId]!.minimumConditionalMean)
                      .abs() >
                  1e-12 ||
              (item.maximumConditionalMean -
                          expectedIndices[item.axisId]!.maximumConditionalMean)
                      .abs() >
                  1e-12,
        ) ||
        indices.values.fold<double>(
              0,
              (sum, item) => sum + item.firstOrderIndex,
            ) >
            1.01) {
      add(
        TransportSensitivityFindingKind.globalIndexDrift,
        'First-order and total-effect indices must be bounded and coherent.',
      );
    }
    final admissible = package.gridPoints
        .where((point) => point.admissible)
        .toList();
    final effects = admissible.map((point) => point.adjustedEffect).toList();
    final region = package.partialIdentification;
    final lower = effects.reduce(math.min);
    final upper = effects.reduce(math.max);
    final excluded = package.gridPoints.length - admissible.length;
    if ((region.lowerEffect - lower).abs() > 1e-12 ||
        (region.upperEffect - upper).abs() > 1e-12 ||
        region.totalPoints != package.gridPoints.length ||
        region.admissiblePoints != admissible.length ||
        region.excludedPoints != excluded ||
        region.admissiblePoints != expectedGridSummary['admissible_points'] ||
        region.excludedPoints != expectedGridSummary['excluded_points'] ||
        (region.lowerConfidenceEnvelope -
                    (lower - 1.96 * package.contract.naiveStandardError))
                .abs() >
            1e-12 ||
        (region.upperConfidenceEnvelope -
                    (upper + 1.96 * package.contract.naiveStandardError))
                .abs() >
            1e-12 ||
        region.interpretation.trim().isEmpty) {
      add(
        TransportSensitivityFindingKind.partialBoundsDrift,
        'Partial-identification bounds and retained point counts must match the grid.',
      );
    }
    final decision = admissible.where((point) => point.decisionTipping).length;
    final nulls = admissible.where((point) => point.nullCrossing).length;
    if (region.decisionTippingPoints != decision ||
        region.nullCrossingPoints != nulls ||
        decision != expectedGridSummary['decision_tipping_points'] ||
        nulls != expectedGridSummary['null_crossing_points'] ||
        (region.decisionTippingFraction - decision / admissible.length).abs() >
            1e-12 ||
        (region.nullCrossingFraction - nulls / admissible.length).abs() >
            1e-12) {
      add(
        TransportSensitivityFindingKind.tippingRegionDrift,
        'Decision and null-crossing tipping regions must match all admissible points.',
      );
    }
  }

  void _verifyScenarios(
    CredibilityTransportabilitySensitivityPackage package,
    void Function(TransportSensitivityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final scenarios = {
      for (final scenario in package.scenarios) scenario.scenarioId: scenario,
    };
    final results = {
      for (final result in package.operatingResults) result.scenarioId: result,
    };
    if (scenarios.length != requiredScenarios.length ||
        results.length != requiredScenarios.length ||
        !scenarios.keys.toSet().containsAll(requiredScenarios) ||
        !results.keys.toSet().containsAll(requiredScenarios) ||
        scenarios.values.any(
          (scenario) =>
              scenario.repetitions != 10000 ||
              scenario.limitation.trim().isEmpty,
        )) {
      add(
        TransportSensitivityFindingKind.scenarioCatalog,
        'All eight prespecified 10,000-repetition scenarios must be retained.',
      );
    }
    final positivity = results['structural-positivity-failure'];
    if (positivity == null ||
        positivity.status != SensitivityOperatingStatus.heldNonidentifiable ||
        positivity.meanAdjustedEstimate != null ||
        positivity.bias != null ||
        positivity.coverage95 != null) {
      add(
        TransportSensitivityFindingKind.nonidentifiableEstimated,
        'Structural positivity failure must be held without an effect estimate.',
      );
    }
    final consensus = results['incompatible-elicitation'];
    if (consensus == null ||
        consensus.status != SensitivityOperatingStatus.heldNoConsensus ||
        consensus.meanAdjustedEstimate != null ||
        consensus.bias != null ||
        consensus.coverage95 != null) {
      add(
        TransportSensitivityFindingKind.noConsensusEstimated,
        'Incompatible elicitation must remain held without a preferred estimate.',
      );
    }
    final reference = results['reference-no-violation'];
    final dual = results['dual-model-misspecification'];
    if (reference == null ||
        reference.status != SensitivityOperatingStatus.estimated ||
        (reference.bias?.abs() ?? 1) > 0.005 ||
        (reference.coverage95 ?? 0) < 0.94 ||
        dual == null ||
        dual.status != SensitivityOperatingStatus.estimated ||
        (dual.bias?.abs() ?? 0) < 0.02 ||
        (dual.coverage95 ?? 1) > 0.90 ||
        results.values.any(
          (result) =>
              result.repetitions != 10000 ||
              (result.status == SensitivityOperatingStatus.estimated &&
                  (result.meanAdjustedEstimate == null ||
                      result.bias == null ||
                      result.coverage95 == null ||
                      result.monteCarloStandardError == null ||
                      !result.meanAdjustedEstimate!.isFinite ||
                      !result.bias!.isFinite ||
                      result.coverage95! < 0 ||
                      result.coverage95! > 1)),
        )) {
      add(
        TransportSensitivityFindingKind.operatingCalibration,
        'Reference calibration must hold and deliberate dual misspecification must remain visible.',
      );
    }
  }

  void _verifyIndependent(
    CredibilityTransportabilitySensitivityPackage package,
    void Function(TransportSensitivityFindingKind, String, [Iterable<String>])
    add,
  ) {
    final replication = package.independentReplication;
    if (replication.language != 'Python' ||
        replication.dependencyLock != 'python-stdlib-only' ||
        replication.scriptPath !=
            'tool/independent_transportability_sensitivity_oracle.py' ||
        replication.scriptSha256 != expectedIndependentScriptSha256 ||
        replication.importsProductionCode ||
        replication.importsGoldenOutputs ||
        replication.tolerance != 1e-12 ||
        replication.cases.length != expectedCases.length ||
        expectedCases.entries.any(
          (entry) =>
              !replication.cases.containsKey(entry.key) ||
              (replication.cases[entry.key]! - entry.value).abs() >
                  replication.tolerance,
        ) ||
        expectedGridSummary.entries.any((entry) {
          final actual = replication.gridSummary[entry.key];
          return actual == null ||
              (actual.toDouble() - entry.value.toDouble()).abs() > 1e-12;
        })) {
      add(
        TransportSensitivityFindingKind.independentReplication,
        'The independent Python local cases and complete-grid summary must match.',
      );
    }
  }
}

double transportSensitivityWeightedBias(
  double delta,
  double modifierSlope,
  double measurementShift,
  double modifierCorrelation,
) => _weightedBias(delta, modifierSlope, measurementShift, modifierCorrelation);

List<GlobalSensitivityIndex> transportGlobalSensitivityIndices(
  List<BiasFunctionGridPoint> points,
) {
  if (points.isEmpty) return const [];
  final mean =
      points.fold<double>(0, (sum, point) => sum + point.adjustedEffect) /
      points.length;
  final totalVariance =
      points.fold<double>(0, (sum, point) {
        final centered = point.adjustedEffect - mean;
        return sum + centered * centered;
      }) /
      points.length;
  return [
    for (final axisId
        in CredibilityTransportabilitySensitivityVerifier.requiredAxes)
      _globalIndex(points, axisId, mean, totalVariance),
  ];
}

GlobalSensitivityIndex _globalIndex(
  List<BiasFunctionGridPoint> points,
  String axisId,
  double mean,
  double totalVariance,
) {
  final byAxis = <double, List<double>>{};
  final byOthers = <String, List<double>>{};
  for (final point in points) {
    byAxis
        .putIfAbsent(_axisValue(point, axisId), () => <double>[])
        .add(point.adjustedEffect);
    byOthers
        .putIfAbsent(_otherAxisKey(point, axisId), () => <double>[])
        .add(point.adjustedEffect);
  }
  final conditionalMeans = byAxis.values.map(_mean).toList()..sort();
  if (totalVariance <= 1e-24) {
    return GlobalSensitivityIndex(
      axisId: axisId,
      firstOrderIndex: 0,
      totalEffectIndex: 0,
      minimumConditionalMean: conditionalMeans.first,
      maximumConditionalMean: conditionalMeans.last,
    );
  }
  double betweenVariance(Iterable<List<double>> groups) =>
      groups.fold<double>(0, (sum, group) {
        final groupMean = _mean(group);
        final centered = groupMean - mean;
        return sum + group.length / points.length * centered * centered;
      });
  final first = (betweenVariance(byAxis.values) / totalVariance).clamp(
    0.0,
    1.0,
  );
  final total = (1 - betweenVariance(byOthers.values) / totalVariance).clamp(
    first,
    1.0,
  );
  return GlobalSensitivityIndex(
    axisId: axisId,
    firstOrderIndex: first,
    totalEffectIndex: total,
    minimumConditionalMean: conditionalMeans.first,
    maximumConditionalMean: conditionalMeans.last,
  );
}

double _axisValue(BiasFunctionGridPoint point, String axisId) =>
    switch (axisId) {
      'u0' => point.u0,
      'delta' => point.delta,
      'modifier_slope' => point.modifierSlope,
      'measurement_shift' => point.measurementShift,
      'modifier_correlation' => point.modifierCorrelation,
      _ => throw ArgumentError.value(axisId, 'axisId'),
    };

String _otherAxisKey(BiasFunctionGridPoint point, String excludedAxisId) => [
  for (final axisId
      in CredibilityTransportabilitySensitivityVerifier.requiredAxes)
    if (axisId != excludedAxisId) '$axisId=${_axisValue(point, axisId)}',
].join('|');

double _mean(Iterable<double> values) {
  var count = 0;
  var total = 0.0;
  for (final value in values) {
    count++;
    total += value;
  }
  if (count == 0) throw StateError('Cannot average an empty collection.');
  return total / count;
}

bool _sameDoubleList(List<double> left, List<double> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if ((left[index] - right[index]).abs() > 1e-12) return false;
  }
  return true;
}

double _weightedBias(
  double delta,
  double modifierSlope,
  double measurementShift,
  double modifierCorrelation,
) =>
    delta +
    0.5 * modifierSlope +
    measurementShift * (1 + 0.25 * modifierCorrelation);

bool _isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
