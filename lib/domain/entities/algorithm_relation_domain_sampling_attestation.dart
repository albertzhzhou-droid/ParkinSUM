import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../usecases/algorithm_executable_contract_gate.dart';

const String algorithmRelationDomainSamplingPlanSchema =
    'parkinsum.algorithm-relation-domain-sampling-plan/2';
const int algorithmRelationDomainSamplingPlanSchemaVersion = 2;
const String algorithmRelationDomainSamplingReportSchema =
    'parkinsum.algorithm-relation-domain-sampling-report/2';
const int algorithmRelationDomainSamplingReportSchemaVersion = 2;
const String algorithmRelationProductionSamplingReportSchema =
    'parkinsum.algorithm-relation-production-sampling-report/1';
const int algorithmRelationProductionSamplingReportSchemaVersion = 1;

enum AlgorithmRelationDomainSamplingStatus { verifiedOffline, stale, invalid }

final class AlgorithmRelationDomainSamplingAttestation {
  const AlgorithmRelationDomainSamplingAttestation({
    required this.planSha256,
    required this.relationRegistrySha256,
    required this.samplerSha256,
    required this.productionAnchorReportSha256,
    required this.productionExecutionReportSha256,
    required this.productionExecutionRunnerSha256,
    required this.productionExecutorSha256,
    required this.executableSpecificationSha256,
    required this.configurationSha256,
    required this.sourceBundleSha256,
    required this.reportSha256,
    required this.relationCount,
    required this.relationPassedCount,
    required this.caseCount,
    required this.productionApiCaseCount,
    required this.productionApiInvocationCount,
    required this.productionIndependentEvaluationCount,
    required this.productionRelationPassedCount,
    required this.productionPreconditionHoldCount,
    required this.productionAnchorRelationCount,
    required this.preconditionHoldCount,
    required this.mutationCaseCount,
    required this.mutationKilledCount,
    required this.mutationSurvivorCount,
    required this.falseRelationFixtureCount,
    required this.falseRelationRejectedCount,
    required this.falseAlarmCount,
    required this.falseAlarmDenominator,
  });

  static const String expectedPlanSha256 =
      'e264686d3188365cd11905fc3c1ff11ee7a116c6b3fcf1fded60054cfef52c5c';
  static const String expectedRelationRegistrySha256 =
      'b4c4dd5f9093439cb32194ca6a3457d0e94539900e8687a57ea8109a7446e54e';
  static const String expectedSamplerSha256 =
      '8976b0d51f0f3326ece0584971b25e40e0087345824fbe35a72d2bc2605625bb';
  static const String expectedProductionAnchorReportSha256 =
      'de2e069ac9465ca0e35c5b7e19a10308112b17a4055703c7b3e6c62b4a39d9d1';
  static const String expectedProductionExecutionReportSha256 =
      '2f02e7958c741d27b007ca896f7777c0f3277fb37ec33916b4014b85c788f76e';
  static const String expectedProductionExecutionRunnerSha256 =
      '4e90aabe4009155d201e37408a1ce5d7128adb0130e320abfd0b1e1bfe20a946';
  static const String expectedProductionExecutorSha256 =
      '53736be40aee320f7e805b6449e680f4b65afdd06d69785ec91f1f9806c4f0f8';
  static const String expectedReportSha256 =
      'a51b4db9ddbe5f0697886691b2a68d2fc83cebfac58d638381fde780dd97dfa3';

  static const String generatorId =
      'parkinsum.xorshift32.relation-production-v2';
  static const String generatorVersion = '2.0.0';
  static const String executionLayer =
      'dart-production-api-plus-independent-observation-ir';
  static const String falseAlarmCalibrationPolicySchema =
      'parkinsum.defective-relation-calibration-policy/1';
  static const String falseAlarmCalibrationScope =
      'deliberately_defective_relation_fixture_decisions';
  static const String falseAlarmMetricKind =
      'defective_relation_diagnostic_exposure';
  static const String productionFalsePositiveRateStatus = 'not_estimated';
  static const String clinicalErrorRateStatus = 'not_applicable';
  static const String falseAlarmCalibrationDecisionRule =
      'reject_each_fixture_on_its_declared_failure_mode_and_match_locked_aggregate';
  static const String boundary =
      'The schema-v2 locked fixture gate executes paired Dart production '
      'APIs for 96 applicable synthetic cases and independently evaluates their '
      'observations in Node. Sixty-four missing or malformed cases remain '
      'precondition HOLDs. The separate IR mutation layer calibrates reviewed '
      'mutation sensitivity. Its 96/128 diagnostic exposures count incorrect '
      'alarms from deliberately defective relation fixtures so those fixtures '
      'can be rejected; this is not a production false-positive estimate. This '
      'is not exhaustive production-domain coverage and does not establish '
      'scientific truth, clinical calibration, patient-level accuracy, benefit, '
      'safety, regulatory qualification, or medical advice.';

  factory AlgorithmRelationDomainSamplingAttestation.current() =>
      AlgorithmRelationDomainSamplingAttestation(
        planSha256: expectedPlanSha256,
        relationRegistrySha256: expectedRelationRegistrySha256,
        samplerSha256: expectedSamplerSha256,
        productionAnchorReportSha256: expectedProductionAnchorReportSha256,
        productionExecutionReportSha256:
            expectedProductionExecutionReportSha256,
        productionExecutionRunnerSha256:
            expectedProductionExecutionRunnerSha256,
        productionExecutorSha256: expectedProductionExecutorSha256,
        executableSpecificationSha256:
            AlgorithmExecutableContractGate.specificationSha256,
        configurationSha256:
            AlgorithmConfigurationIdentity.defaults().sha256Digest,
        sourceBundleSha256: AlgorithmConfigurationIdentity
            .registeredAlgorithmSourceBundleSha256,
        reportSha256: expectedReportSha256,
        relationCount: 8,
        relationPassedCount: 8,
        caseCount: 160,
        productionApiCaseCount: 96,
        productionApiInvocationCount: 624,
        productionIndependentEvaluationCount: 96,
        productionRelationPassedCount: 96,
        productionPreconditionHoldCount: 64,
        productionAnchorRelationCount: 8,
        preconditionHoldCount: 64,
        mutationCaseCount: 32,
        mutationKilledCount: 32,
        mutationSurvivorCount: 0,
        falseRelationFixtureCount: 3,
        falseRelationRejectedCount: 3,
        falseAlarmCount: 96,
        falseAlarmDenominator: 128,
      );

  final String planSha256;
  final String relationRegistrySha256;
  final String samplerSha256;
  final String productionAnchorReportSha256;
  final String productionExecutionReportSha256;
  final String productionExecutionRunnerSha256;
  final String productionExecutorSha256;
  final String executableSpecificationSha256;
  final String configurationSha256;
  final String sourceBundleSha256;
  final String reportSha256;
  final int relationCount;
  final int relationPassedCount;
  final int caseCount;
  final int productionApiCaseCount;
  final int productionApiInvocationCount;
  final int productionIndependentEvaluationCount;
  final int productionRelationPassedCount;
  final int productionPreconditionHoldCount;
  final int productionAnchorRelationCount;
  final int preconditionHoldCount;
  final int mutationCaseCount;
  final int mutationKilledCount;
  final int mutationSurvivorCount;
  final int falseRelationFixtureCount;
  final int falseRelationRejectedCount;
  final int falseAlarmCount;
  final int falseAlarmDenominator;

  double get falseAlarmRate =>
      falseAlarmDenominator == 0 ? 0 : falseAlarmCount / falseAlarmDenominator;

  bool get falseAlarmCalibrationPassed =>
      falseRelationFixtureCount == 3 &&
      falseRelationRejectedCount == 3 &&
      falseAlarmCount == 96 &&
      falseAlarmDenominator == 128 &&
      falseAlarmRate == 3 / 4;

  AlgorithmRelationDomainSamplingAttestation copyWith({
    String? planSha256,
    String? relationRegistrySha256,
    String? samplerSha256,
    String? productionAnchorReportSha256,
    String? productionExecutionReportSha256,
    String? productionExecutionRunnerSha256,
    String? productionExecutorSha256,
    String? executableSpecificationSha256,
    String? configurationSha256,
    String? sourceBundleSha256,
    String? reportSha256,
    int? relationCount,
    int? relationPassedCount,
    int? caseCount,
    int? productionApiCaseCount,
    int? productionApiInvocationCount,
    int? productionIndependentEvaluationCount,
    int? productionRelationPassedCount,
    int? productionPreconditionHoldCount,
    int? productionAnchorRelationCount,
    int? preconditionHoldCount,
    int? mutationCaseCount,
    int? mutationKilledCount,
    int? mutationSurvivorCount,
    int? falseRelationFixtureCount,
    int? falseRelationRejectedCount,
    int? falseAlarmCount,
    int? falseAlarmDenominator,
  }) => AlgorithmRelationDomainSamplingAttestation(
    planSha256: planSha256 ?? this.planSha256,
    relationRegistrySha256:
        relationRegistrySha256 ?? this.relationRegistrySha256,
    samplerSha256: samplerSha256 ?? this.samplerSha256,
    productionAnchorReportSha256:
        productionAnchorReportSha256 ?? this.productionAnchorReportSha256,
    productionExecutionReportSha256:
        productionExecutionReportSha256 ?? this.productionExecutionReportSha256,
    productionExecutionRunnerSha256:
        productionExecutionRunnerSha256 ?? this.productionExecutionRunnerSha256,
    productionExecutorSha256:
        productionExecutorSha256 ?? this.productionExecutorSha256,
    executableSpecificationSha256:
        executableSpecificationSha256 ?? this.executableSpecificationSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    sourceBundleSha256: sourceBundleSha256 ?? this.sourceBundleSha256,
    reportSha256: reportSha256 ?? this.reportSha256,
    relationCount: relationCount ?? this.relationCount,
    relationPassedCount: relationPassedCount ?? this.relationPassedCount,
    caseCount: caseCount ?? this.caseCount,
    productionApiCaseCount:
        productionApiCaseCount ?? this.productionApiCaseCount,
    productionApiInvocationCount:
        productionApiInvocationCount ?? this.productionApiInvocationCount,
    productionIndependentEvaluationCount:
        productionIndependentEvaluationCount ??
        this.productionIndependentEvaluationCount,
    productionRelationPassedCount:
        productionRelationPassedCount ?? this.productionRelationPassedCount,
    productionPreconditionHoldCount:
        productionPreconditionHoldCount ?? this.productionPreconditionHoldCount,
    productionAnchorRelationCount:
        productionAnchorRelationCount ?? this.productionAnchorRelationCount,
    preconditionHoldCount: preconditionHoldCount ?? this.preconditionHoldCount,
    mutationCaseCount: mutationCaseCount ?? this.mutationCaseCount,
    mutationKilledCount: mutationKilledCount ?? this.mutationKilledCount,
    mutationSurvivorCount: mutationSurvivorCount ?? this.mutationSurvivorCount,
    falseRelationFixtureCount:
        falseRelationFixtureCount ?? this.falseRelationFixtureCount,
    falseRelationRejectedCount:
        falseRelationRejectedCount ?? this.falseRelationRejectedCount,
    falseAlarmCount: falseAlarmCount ?? this.falseAlarmCount,
    falseAlarmDenominator: falseAlarmDenominator ?? this.falseAlarmDenominator,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': algorithmRelationDomainSamplingReportSchema,
    'schema_version': algorithmRelationDomainSamplingReportSchemaVersion,
    'sampling_plan_schema': algorithmRelationDomainSamplingPlanSchema,
    'plan_sha256': planSha256,
    'relation_registry_sha256': relationRegistrySha256,
    'sampler_sha256': samplerSha256,
    'production_anchor_report_sha256': productionAnchorReportSha256,
    'production_execution_report_schema':
        algorithmRelationProductionSamplingReportSchema,
    'production_execution_report_sha256': productionExecutionReportSha256,
    'production_execution_runner_sha256': productionExecutionRunnerSha256,
    'production_executor_sha256': productionExecutorSha256,
    'executable_contract_specification_sha256': executableSpecificationSha256,
    'configuration_sha256': configurationSha256,
    'source_bundle_sha256': sourceBundleSha256,
    'report_sha256': reportSha256,
    'generator_id': generatorId,
    'generator_version': generatorVersion,
    'execution_layer': executionLayer,
    'relation_count': relationCount,
    'relation_passed_count': relationPassedCount,
    'case_count': caseCount,
    'production_api_case_count': productionApiCaseCount,
    'production_api_invocation_count': productionApiInvocationCount,
    'production_independent_evaluation_count':
        productionIndependentEvaluationCount,
    'production_relation_passed_count': productionRelationPassedCount,
    'production_precondition_hold_count': productionPreconditionHoldCount,
    'production_anchor_relation_count': productionAnchorRelationCount,
    'precondition_hold_count': preconditionHoldCount,
    'mutation_case_count': mutationCaseCount,
    'mutation_killed_count': mutationKilledCount,
    'mutation_survivor_count': mutationSurvivorCount,
    'false_relation_fixture_count': falseRelationFixtureCount,
    'false_relation_rejected_count': falseRelationRejectedCount,
    'false_alarm_count': falseAlarmCount,
    'false_alarm_denominator': falseAlarmDenominator,
    'false_alarm_rate': falseAlarmRate,
    'false_alarm_calibration_passed': falseAlarmCalibrationPassed,
    'defective_relation_calibration_policy': <String, Object?>{
      'schema': falseAlarmCalibrationPolicySchema,
      'scope': falseAlarmCalibrationScope,
      'metric_kind': falseAlarmMetricKind,
      'production_false_positive_rate_status':
          productionFalsePositiveRateStatus,
      'clinical_error_rate_status': clinicalErrorRateStatus,
      'decision_rule': falseAlarmCalibrationDecisionRule,
    },
    'boundary': boundary,
  };
}

final class AlgorithmRelationDomainSamplingAssessment {
  const AlgorithmRelationDomainSamplingAssessment({
    required this.attestation,
    required this.status,
    required this.findings,
  });

  final AlgorithmRelationDomainSamplingAttestation attestation;
  final AlgorithmRelationDomainSamplingStatus status;
  final List<String> findings;

  bool get passed =>
      status == AlgorithmRelationDomainSamplingStatus.verifiedOffline &&
      findings.isEmpty;
}

final class AlgorithmRelationDomainSamplingVerifier {
  const AlgorithmRelationDomainSamplingVerifier();

  AlgorithmRelationDomainSamplingAssessment verify(
    AlgorithmRelationDomainSamplingAttestation attestation,
  ) {
    final findings = <String>[];
    void requireSha(String value, String code) {
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) findings.add(code);
    }

    final identities = <String, String>{
      'plan': attestation.planSha256,
      'relation_registry': attestation.relationRegistrySha256,
      'sampler': attestation.samplerSha256,
      'production_anchor': attestation.productionAnchorReportSha256,
      'production_execution_report':
          attestation.productionExecutionReportSha256,
      'production_execution_runner':
          attestation.productionExecutionRunnerSha256,
      'production_executor': attestation.productionExecutorSha256,
      'executable_specification': attestation.executableSpecificationSha256,
      'configuration': attestation.configurationSha256,
      'source_bundle': attestation.sourceBundleSha256,
      'report': attestation.reportSha256,
    };
    for (final entry in identities.entries) {
      requireSha(entry.value, 'sampling.${entry.key}_identity_invalid');
    }
    final expected = <String, String>{
      'plan': AlgorithmRelationDomainSamplingAttestation.expectedPlanSha256,
      'relation_registry': AlgorithmRelationDomainSamplingAttestation
          .expectedRelationRegistrySha256,
      'sampler':
          AlgorithmRelationDomainSamplingAttestation.expectedSamplerSha256,
      'production_anchor': AlgorithmRelationDomainSamplingAttestation
          .expectedProductionAnchorReportSha256,
      'production_execution_report': AlgorithmRelationDomainSamplingAttestation
          .expectedProductionExecutionReportSha256,
      'production_execution_runner': AlgorithmRelationDomainSamplingAttestation
          .expectedProductionExecutionRunnerSha256,
      'production_executor': AlgorithmRelationDomainSamplingAttestation
          .expectedProductionExecutorSha256,
      'executable_specification':
          AlgorithmExecutableContractGate.specificationSha256,
      'configuration': AlgorithmConfigurationIdentity.defaults().sha256Digest,
      'source_bundle':
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
      'report': AlgorithmRelationDomainSamplingAttestation.expectedReportSha256,
    };
    for (final entry in identities.entries) {
      if (entry.value != expected[entry.key]) {
        findings.add('sampling.${entry.key}_identity_drift');
      }
    }
    if (attestation.relationCount != 8 ||
        attestation.relationPassedCount != attestation.relationCount ||
        attestation.caseCount != 160 ||
        attestation.productionAnchorRelationCount != 8) {
      findings.add('sampling.relation_or_case_coverage_incomplete');
    }
    if (attestation.productionApiCaseCount != 96 ||
        attestation.productionApiInvocationCount != 624 ||
        attestation.productionIndependentEvaluationCount != 96 ||
        attestation.productionRelationPassedCount != 96 ||
        attestation.productionPreconditionHoldCount != 64) {
      findings.add('sampling.production_execution_coverage_incomplete');
    }
    if (attestation.preconditionHoldCount != 64) {
      findings.add('sampling.precondition_hold_count_drift');
    }
    if (attestation.mutationCaseCount != 32 ||
        attestation.mutationKilledCount != attestation.mutationCaseCount ||
        attestation.mutationSurvivorCount != 0) {
      findings.add('sampling.mutation_survivor_present');
    }
    if (attestation.falseRelationFixtureCount != 3 ||
        attestation.falseRelationRejectedCount !=
            attestation.falseRelationFixtureCount ||
        attestation.falseAlarmCount != 96 ||
        attestation.falseAlarmDenominator != 128 ||
        !attestation.falseAlarmCalibrationPassed) {
      findings.add('sampling.false_relation_calibration_drift');
    }

    final unique = findings.toSet().toList(growable: false)..sort();
    final status = unique.isEmpty
        ? AlgorithmRelationDomainSamplingStatus.verifiedOffline
        : unique.any((entry) => entry.endsWith('_invalid'))
        ? AlgorithmRelationDomainSamplingStatus.invalid
        : AlgorithmRelationDomainSamplingStatus.stale;
    return AlgorithmRelationDomainSamplingAssessment(
      attestation: attestation,
      status: status,
      findings: List<String>.unmodifiable(unique),
    );
  }
}
