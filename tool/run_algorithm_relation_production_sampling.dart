import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_executable_contract_gate.dart';

const String productionSamplingReportSchema =
    'parkinsum.algorithm-relation-production-sampling-report/1';
const int productionSamplingReportSchemaVersion = 1;
const String samplingPlanSchema =
    'parkinsum.algorithm-relation-domain-sampling-plan/2';
const String relationRegistrySchema =
    'parkinsum.algorithm-contract-relation-registry/1';
const List<String> requiredPartitions = <String>[
  'normal',
  'boundary',
  'missing',
  'malformed',
  'adversarial',
];
const Set<String> heldPartitions = <String>{'missing', 'malformed'};
const String outputPath =
    'build/algorithm_relation_production_sampling/latest.json';
const String runnerSourcePath =
    'tool/run_algorithm_relation_production_sampling.dart';
const String executorSourcePath =
    'lib/domain/usecases/algorithm_executable_contract_gate.dart';

Future<void> main() async {
  final plan = _readJson('config/algorithm_relation_domain_sampling_plan.json');
  final registry = _readJson(
    'config/algorithm_contract_relation_registry.json',
  );
  final failures = <String>{};
  if (plan[r'$schema'] != samplingPlanSchema || plan['schemaVersion'] != 2) {
    failures.add('production_sampling.plan_schema_unsupported');
  }
  if (registry[r'$schema'] != relationRegistrySchema ||
      registry['schemaVersion'] != 1) {
    failures.add('production_sampling.registry_schema_unsupported');
  }
  final partitions = (plan['partitions'] as List<Object?>? ?? const <Object?>[])
      .map((entry) => entry.toString())
      .toList(growable: false);
  if (!_sameStrings(partitions, requiredPartitions)) {
    failures.add('production_sampling.partition_contract_drift');
  }
  final profiles = (plan['relations'] as List<Object?>? ?? const <Object?>[])
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
  final registryRelations =
      (registry['relations'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .toList(growable: false);
  final profileIds =
      profiles.map((entry) => entry['relationId'].toString()).toList()..sort();
  final registryIds =
      registryRelations.map((entry) => entry['id'].toString()).toList()..sort();
  if (!_sameStrings(profileIds, registryIds) || profileIds.length != 8) {
    failures.add('production_sampling.relation_membership_drift');
  }

  const gate = AlgorithmExecutableContractGate();
  final cases = <Map<String, Object?>>[];
  for (final profile in profiles) {
    final relationId = profile['relationId'].toString();
    final algorithmId = registryRelations
        .firstWhere(
          (entry) => entry['id'] == relationId,
          orElse: () => const <String, Object?>{},
        )['algorithmId']
        ?.toString();
    final seeds = (profile['seeds'] as List<Object?>? ?? const <Object?>[])
        .whereType<num>()
        .map((entry) => entry.toInt())
        .toList(growable: false);
    if (seeds.length != 4 || seeds.toSet().length != 4) {
      failures.add('production_sampling.seed_contract_invalid.$relationId');
      continue;
    }
    for (final partition in requiredPartitions) {
      for (final seed in seeds) {
        final id = '$relationId.$partition.$seed';
        if (heldPartitions.contains(partition)) {
          final sourceInput = <String, Object?>{
            'relation_id': relationId,
            'partition': partition,
            'seed': seed,
            'synthetic': true,
            if (partition == 'missing')
              'precondition_fault': 'required_input_removed'
            else
              'precondition_fault': 'required_input_type_malformed',
          };
          final followUpInput = <String, Object?>{
            ...sourceInput,
            'transformation': 'held_before_production_execution',
          };
          cases.add(<String, Object?>{
            'id': id,
            'relation_id': relationId,
            'algorithm_id': algorithmId,
            'generator_id': profile['generatorId'],
            'generator_version': profile['generatorVersion'],
            'seed': seed,
            'partition': partition,
            'synthetic': true,
            'precondition_status': 'held',
            'production_api_executed_for_case': false,
            'source_api_invocation_count': 0,
            'follow_up_api_invocation_count': 0,
            'production_api_invocation_count': 0,
            'source_input_sha256': _digest(sourceInput),
            'follow_up_input_sha256': _digest(followUpInput),
            'source_output_sha256': null,
            'follow_up_output_sha256': null,
            'relation_observation': null,
            'execution_status': 'held_precondition',
            'failure_codes': const <String>[],
          });
          continue;
        }
        try {
          final execution = await gate.runProductionSample(
            relationId: relationId,
            partition: partition,
            seed: seed,
          );
          final relationObservation = execution.relationObservation;
          cases.add(<String, Object?>{
            'id': id,
            'relation_id': relationId,
            'algorithm_id': algorithmId,
            'generator_id': profile['generatorId'],
            'generator_version': profile['generatorVersion'],
            'seed': seed,
            'partition': partition,
            'synthetic': true,
            'precondition_status': 'met',
            'production_api_executed_for_case': true,
            'source_api_invocation_count': execution.sourceApiInvocationCount,
            'follow_up_api_invocation_count':
                execution.followUpApiInvocationCount,
            'production_api_invocation_count':
                execution.productionApiInvocationCount,
            'source_input_sha256': _digest(execution.sourceInput),
            'follow_up_input_sha256': _digest(execution.followUpInput),
            'source_output_sha256': _digest(execution.sourceOutput),
            'follow_up_output_sha256': _digest(execution.followUpOutput),
            'relation_observation_sha256': _digest(relationObservation),
            'relation_observation': relationObservation,
            'execution_status': 'executed_pending_independent_oracle',
            'failure_codes': const <String>[],
          });
        } catch (error) {
          final failureCode =
              'production_sampling.execution_blocked.${error.runtimeType}';
          failures.add('$failureCode.$relationId.$partition.$seed');
          cases.add(<String, Object?>{
            'id': id,
            'relation_id': relationId,
            'algorithm_id': algorithmId,
            'generator_id': profile['generatorId'],
            'generator_version': profile['generatorVersion'],
            'seed': seed,
            'partition': partition,
            'synthetic': true,
            'precondition_status': 'met',
            'production_api_executed_for_case': false,
            'source_api_invocation_count': 0,
            'follow_up_api_invocation_count': 0,
            'production_api_invocation_count': 0,
            'source_input_sha256': null,
            'follow_up_input_sha256': null,
            'source_output_sha256': null,
            'follow_up_output_sha256': null,
            'relation_observation': null,
            'execution_status': 'blocked',
            'failure_codes': <String>[failureCode],
          });
        }
      }
    }
  }

  final relationSummaries = <Map<String, Object?>>[];
  for (final relationId in profileIds) {
    final profile = profiles.firstWhere(
      (entry) => entry['relationId'] == relationId,
    );
    final minimumDiversityBudget =
        profile['minimumDiversityBudget'] as int? ?? -1;
    final relationCases = cases
        .where((entry) => entry['relation_id'] == relationId)
        .toList(growable: false);
    final inputDigests = <String>{
      for (final entry in relationCases)
        if (entry['source_input_sha256'] case final String digest) digest,
      for (final entry in relationCases)
        if (entry['follow_up_input_sha256'] case final String digest) digest,
    };
    final summary = <String, Object?>{
      'relation_id': relationId,
      'case_count': relationCases.length,
      'production_api_case_count': relationCases
          .where((entry) => entry['production_api_executed_for_case'] == true)
          .length,
      'precondition_hold_count': relationCases
          .where((entry) => entry['precondition_status'] == 'held')
          .length,
      'production_api_invocation_count': relationCases.fold<int>(
        0,
        (sum, entry) =>
            sum + (entry['production_api_invocation_count'] as int? ?? 0),
      ),
      'unique_input_digest_count': inputDigests.length,
      'minimum_diversity_budget': minimumDiversityBudget,
      'partition_counts': <String, int>{
        for (final partition in requiredPartitions)
          partition: relationCases
              .where((entry) => entry['partition'] == partition)
              .length,
      },
    };
    final passed =
        summary['case_count'] == 20 &&
        summary['production_api_case_count'] == 12 &&
        summary['precondition_hold_count'] == 8 &&
        minimumDiversityBudget == 20 &&
        (summary['unique_input_digest_count'] as int) >=
            minimumDiversityBudget &&
        (summary['production_api_invocation_count'] as int) > 0 &&
        (summary['partition_counts'] as Map<String, int>).values.every(
          (count) => count == 4,
        );
    summary['passed'] = passed;
    if (!passed) {
      failures.add('production_sampling.relation_incomplete.$relationId');
    }
    relationSummaries.add(summary);
  }

  final productionCases = cases
      .where((entry) => entry['production_api_executed_for_case'] == true)
      .length;
  final heldCases = cases
      .where((entry) => entry['precondition_status'] == 'held')
      .length;
  final invocationCount = cases.fold<int>(
    0,
    (sum, entry) =>
        sum + (entry['production_api_invocation_count'] as int? ?? 0),
  );
  if (cases.length != 160 || productionCases != 96 || heldCases != 64) {
    failures.add('production_sampling.aggregate_count_drift');
  }
  final reportWithoutDigest = <String, Object?>{
    'schema': productionSamplingReportSchema,
    'schema_version': productionSamplingReportSchemaVersion,
    'plan_sha256': _digest(plan),
    'relation_registry_sha256': _digest(registry),
    'runner_sha256': _rawFileSha256(runnerSourcePath),
    'executor_sha256': _rawFileSha256(executorSourcePath),
    'configuration_sha256':
        AlgorithmConfigurationIdentity.defaults().sha256Digest,
    'source_bundle_sha256':
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    'relation_count': relationSummaries.length,
    'relation_passed_count': relationSummaries
        .where((entry) => entry['passed'] == true)
        .length,
    'case_count': cases.length,
    'production_api_case_count': productionCases,
    'paired_production_execution_count': productionCases,
    'precondition_hold_count': heldCases,
    'production_api_invocation_count': invocationCount,
    'independent_relation_evaluation_count': 0,
    'execution_layer': 'dart_production_api',
    'real_health_data_used': false,
    'integrity_failure_codes': failures.toList()..sort(),
    'boundary':
        'Applicable synthetic source/follow-up inputs execute Dart production '
        'APIs. Missing and malformed inputs are held before execution. This '
        'report does not evaluate relations independently and does not establish '
        'scientific truth, clinical calibration, benefit, safety, or advice.',
    'relations': relationSummaries,
    'cases': cases,
  };
  reportWithoutDigest['passed'] =
      failures.isEmpty &&
      relationSummaries.length == 8 &&
      relationSummaries.every((entry) => entry['passed'] == true) &&
      productionCases == 96 &&
      heldCases == 64;
  final report = <String, Object?>{
    ...reportWithoutDigest,
    'report_sha256': _digest(reportWithoutDigest),
  };
  Directory(
    'build/algorithm_relation_production_sampling',
  ).createSync(recursive: true);
  File(outputPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Algorithm relation production sampling: '
    '${report['relation_passed_count']}/${report['relation_count']} relations; '
    '${report['case_count']} cases; production=$productionCases; holds=$heldCases; '
    'invocations=$invocationCount; artifact=$outputPath',
  );
  if (report['passed'] != true) {
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    exitCode = 1;
  }
}

Map<String, Object?> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

String _digest(Object? value) =>
    AlgorithmConfigurationIdentity.digestConfiguration(
      _normalizeWholeNumbers(value),
    );

Object? _normalizeWholeNumbers(Object? value) {
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  if (value is List<Object?>) {
    return value.map(_normalizeWholeNumbers).toList(growable: false);
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _normalizeWholeNumbers(entry.value),
    };
  }
  return value;
}

String _rawFileSha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
