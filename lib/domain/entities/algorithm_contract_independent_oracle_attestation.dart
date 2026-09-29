import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../usecases/algorithm_executable_contract_gate.dart';

const String algorithmContractRelationRegistrySchema =
    'parkinsum.algorithm-contract-relation-registry/1';
const int algorithmContractRelationRegistrySchemaVersion = 1;
const String algorithmContractIndependentOracleReportSchema =
    'parkinsum.algorithm-contract-independent-oracle-report/1';
const int algorithmContractIndependentOracleReportSchemaVersion = 1;

enum AlgorithmContractIndependentOracleStatus {
  verifiedOffline,
  stale,
  invalid,
}

final class AlgorithmContractIndependentOracleAttestation {
  const AlgorithmContractIndependentOracleAttestation({
    required this.relationRegistrySha256,
    required this.independentOracleSha256,
    required this.executableSpecificationSha256,
    required this.configurationSha256,
    required this.sourceBundleSha256,
    required this.reportSha256,
    required this.relationCount,
    required this.relationPassedCount,
    required this.mutationCount,
    required this.mutationKilledCount,
    required this.mutationSurvivorCount,
    required this.invalidRelationFixtureCount,
    required this.invalidRelationRejectedCount,
    required this.schedulerCaseCount,
    required this.schedulerPassedCount,
  });

  static const String expectedRelationRegistrySha256 =
      'b4c4dd5f9093439cb32194ca6a3457d0e94539900e8687a57ea8109a7446e54e';
  static const String expectedIndependentOracleSha256 =
      'aa96bf83f6916fe73b47be8057129ef57ae3420a8b615b5c6a07a40f5e8d04e0';
  static const String expectedExecutableSpecificationSha256 =
      '8dab2d3d0c7da97aee60917defeeae4f8d0a889e2ee9918305468d6da06caf1d';
  static const String expectedReportSha256 =
      '4f4e3ac3713f2e823ec86e4c9d5fb6db4bd11136306043afc438038f85d5c57e';

  static const String boundary =
      'Committed offline cross-runtime software-verification evidence over '
      'fixed synthetic observations. It is not a live in-app Node execution '
      'and does not establish scientific truth, model quality, clinical '
      'calibration, patient-level accuracy, benefit, safety, regulatory '
      'qualification, or medical advice.';

  factory AlgorithmContractIndependentOracleAttestation.current() =>
      AlgorithmContractIndependentOracleAttestation(
        relationRegistrySha256: expectedRelationRegistrySha256,
        independentOracleSha256: expectedIndependentOracleSha256,
        executableSpecificationSha256: expectedExecutableSpecificationSha256,
        configurationSha256:
            AlgorithmConfigurationIdentity.defaults().sha256Digest,
        sourceBundleSha256: AlgorithmConfigurationIdentity
            .registeredAlgorithmSourceBundleSha256,
        reportSha256: expectedReportSha256,
        relationCount: 8,
        relationPassedCount: 8,
        mutationCount: 16,
        mutationKilledCount: 16,
        mutationSurvivorCount: 0,
        invalidRelationFixtureCount: 3,
        invalidRelationRejectedCount: 3,
        schedulerCaseCount: 6,
        schedulerPassedCount: 6,
      );

  final String relationRegistrySha256;
  final String independentOracleSha256;
  final String executableSpecificationSha256;
  final String configurationSha256;
  final String sourceBundleSha256;
  final String reportSha256;
  final int relationCount;
  final int relationPassedCount;
  final int mutationCount;
  final int mutationKilledCount;
  final int mutationSurvivorCount;
  final int invalidRelationFixtureCount;
  final int invalidRelationRejectedCount;
  final int schedulerCaseCount;
  final int schedulerPassedCount;

  AlgorithmContractIndependentOracleAttestation copyWith({
    String? relationRegistrySha256,
    String? independentOracleSha256,
    String? executableSpecificationSha256,
    String? configurationSha256,
    String? sourceBundleSha256,
    String? reportSha256,
    int? relationCount,
    int? relationPassedCount,
    int? mutationCount,
    int? mutationKilledCount,
    int? mutationSurvivorCount,
    int? invalidRelationFixtureCount,
    int? invalidRelationRejectedCount,
    int? schedulerCaseCount,
    int? schedulerPassedCount,
  }) => AlgorithmContractIndependentOracleAttestation(
    relationRegistrySha256:
        relationRegistrySha256 ?? this.relationRegistrySha256,
    independentOracleSha256:
        independentOracleSha256 ?? this.independentOracleSha256,
    executableSpecificationSha256:
        executableSpecificationSha256 ?? this.executableSpecificationSha256,
    configurationSha256: configurationSha256 ?? this.configurationSha256,
    sourceBundleSha256: sourceBundleSha256 ?? this.sourceBundleSha256,
    reportSha256: reportSha256 ?? this.reportSha256,
    relationCount: relationCount ?? this.relationCount,
    relationPassedCount: relationPassedCount ?? this.relationPassedCount,
    mutationCount: mutationCount ?? this.mutationCount,
    mutationKilledCount: mutationKilledCount ?? this.mutationKilledCount,
    mutationSurvivorCount: mutationSurvivorCount ?? this.mutationSurvivorCount,
    invalidRelationFixtureCount:
        invalidRelationFixtureCount ?? this.invalidRelationFixtureCount,
    invalidRelationRejectedCount:
        invalidRelationRejectedCount ?? this.invalidRelationRejectedCount,
    schedulerCaseCount: schedulerCaseCount ?? this.schedulerCaseCount,
    schedulerPassedCount: schedulerPassedCount ?? this.schedulerPassedCount,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': algorithmContractIndependentOracleReportSchema,
    'schema_version': algorithmContractIndependentOracleReportSchemaVersion,
    'relation_registry_schema': algorithmContractRelationRegistrySchema,
    'relation_registry_sha256': relationRegistrySha256,
    'independent_oracle_sha256': independentOracleSha256,
    'executable_contract_specification_sha256': executableSpecificationSha256,
    'configuration_sha256': configurationSha256,
    'source_bundle_sha256': sourceBundleSha256,
    'report_sha256': reportSha256,
    'relation_count': relationCount,
    'relation_passed_count': relationPassedCount,
    'mutation_count': mutationCount,
    'mutation_killed_count': mutationKilledCount,
    'mutation_survivor_count': mutationSurvivorCount,
    'invalid_relation_fixture_count': invalidRelationFixtureCount,
    'invalid_relation_rejected_count': invalidRelationRejectedCount,
    'scheduler_case_count': schedulerCaseCount,
    'scheduler_passed_count': schedulerPassedCount,
    'boundary': boundary,
  };
}

final class AlgorithmContractIndependentOracleAssessment {
  const AlgorithmContractIndependentOracleAssessment({
    required this.attestation,
    required this.status,
    required this.findings,
  });

  final AlgorithmContractIndependentOracleAttestation attestation;
  final AlgorithmContractIndependentOracleStatus status;
  final List<String> findings;

  bool get passed =>
      status == AlgorithmContractIndependentOracleStatus.verifiedOffline &&
      findings.isEmpty;
}

final class AlgorithmContractIndependentOracleVerifier {
  const AlgorithmContractIndependentOracleVerifier();

  AlgorithmContractIndependentOracleAssessment verify(
    AlgorithmContractIndependentOracleAttestation attestation,
  ) {
    final findings = <String>[];
    void requireSha(String value, String code) {
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) findings.add(code);
    }

    requireSha(
      attestation.relationRegistrySha256,
      'oracle.relation_registry_identity_invalid',
    );
    requireSha(
      attestation.independentOracleSha256,
      'oracle.implementation_identity_invalid',
    );
    requireSha(
      attestation.executableSpecificationSha256,
      'oracle.executable_specification_identity_invalid',
    );
    requireSha(
      attestation.configurationSha256,
      'oracle.configuration_identity_invalid',
    );
    requireSha(
      attestation.sourceBundleSha256,
      'oracle.source_bundle_identity_invalid',
    );
    requireSha(attestation.reportSha256, 'oracle.report_identity_invalid');

    final stale = <String>[
      if (attestation.relationRegistrySha256 !=
          AlgorithmContractIndependentOracleAttestation
              .expectedRelationRegistrySha256)
        'oracle.relation_registry_drift',
      if (attestation.independentOracleSha256 !=
          AlgorithmContractIndependentOracleAttestation
              .expectedIndependentOracleSha256)
        'oracle.implementation_drift',
      if (attestation.executableSpecificationSha256 !=
              AlgorithmExecutableContractGate.specificationSha256 ||
          attestation.executableSpecificationSha256 !=
              AlgorithmContractIndependentOracleAttestation
                  .expectedExecutableSpecificationSha256)
        'oracle.executable_specification_drift',
      if (attestation.configurationSha256 !=
          AlgorithmConfigurationIdentity.defaults().sha256Digest)
        'oracle.configuration_identity_drift',
      if (attestation.sourceBundleSha256 !=
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256)
        'oracle.source_bundle_identity_drift',
      if (attestation.reportSha256 !=
          AlgorithmContractIndependentOracleAttestation.expectedReportSha256)
        'oracle.report_identity_drift',
    ];
    findings.addAll(stale);

    if (attestation.relationCount != 8 ||
        attestation.relationPassedCount != attestation.relationCount) {
      findings.add('oracle.relation_coverage_incomplete');
    }
    if (attestation.mutationCount != 16 ||
        attestation.mutationKilledCount != attestation.mutationCount ||
        attestation.mutationSurvivorCount != 0) {
      findings.add('oracle.mutation_survivor_present');
    }
    if (attestation.invalidRelationFixtureCount != 3 ||
        attestation.invalidRelationRejectedCount !=
            attestation.invalidRelationFixtureCount) {
      findings.add('oracle.false_relation_fixture_not_rejected');
    }
    if (attestation.schedulerCaseCount != 6 ||
        attestation.schedulerPassedCount != attestation.schedulerCaseCount) {
      findings.add('oracle.scheduler_interleaving_incomplete');
    }

    final unique = findings.toSet().toList(growable: false)..sort();
    final status = unique.isEmpty
        ? AlgorithmContractIndependentOracleStatus.verifiedOffline
        : unique.any((entry) => entry.endsWith('_invalid'))
        ? AlgorithmContractIndependentOracleStatus.invalid
        : AlgorithmContractIndependentOracleStatus.stale;
    return AlgorithmContractIndependentOracleAssessment(
      attestation: attestation,
      status: status,
      findings: List<String>.unmodifiable(unique),
    );
  }
}
