import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_executable_contract_gate.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';

/// Collects actual bounded source/follow-up API observations. Independent
/// relation evaluation is performed by the Node reviewer, never here.
Future<void> main(List<String> args) async {
  final phase = args.isEmpty ? 'current' : args.single;
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(phase)) {
    throw ArgumentError('Unsupported observation phase');
  }
  final registry =
      jsonDecode(
            File(
              'config/algorithm_contract_relation_registry.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final rows = <Map<String, Object?>>[];
  const gate = AlgorithmExecutableContractGate();
  for (final relation in registry['relations'] as List) {
    for (final partition in ['normal', 'boundary', 'adversarial']) {
      for (final seed in [1, 17, 104729, 2147483647]) {
        final x = await gate.runProductionSample(
          relationId: relation['id'] as String,
          partition: partition,
          seed: seed,
        );
        rows.add({
          'relation_id': x.relationId,
          'partition': x.partition,
          'seed': x.seed,
          'source_input': x.sourceInput,
          'follow_up_input': x.followUpInput,
          'source_output': x.sourceOutput,
          'follow_up_output': x.followUpOutput,
          'relation_observation': x.relationObservation,
          'source_api_invocation_count': x.sourceApiInvocationCount,
          'follow_up_api_invocation_count': x.followUpApiInvocationCount,
        });
      }
    }
  }
  final trials = <Map<String, Object?>>[];
  for (final trial in [
    'one_fact_different_scope',
    'zero_fact_different_scope',
    'one_fact_same_scope',
    'equal_value_different_scope',
    'unrelated_entity',
  ]) {
    final value = trial == 'equal_value_different_scope' ? '1' : '10';
    final scope = trial == 'one_fact_same_scope' ? 'scope.a' : 'scope.b';
    final observation = ObservationRecord(
      observationId: 'synthetic.minimal.$trial',
      domain: 'food',
      entityType: 'food_variant',
      entityKey: 'SYNTHETIC_FOOD#US#1',
      attributeCode: 'protein_g',
      valueType: 'numeric_interval',
      value: parseQualifiedValue(value),
      unit: 'g',
      basisType: 'per_100g_edible_part',
      basisAmount: 100,
      scopeHash: scope,
      sourceDocId: 'synthetic:scope-test',
      recordLocator: 'synthetic',
      methodCode: null,
      extractionConfidence: 1,
    );
    final facts = trial == 'zero_fact_different_scope'
        ? <ResolvedFactRecord>[]
        : [
            ResolvedFactRecord(
              factId: 'synthetic.fact',
              entityKey: trial == 'unrelated_entity'
                  ? 'OTHER'
                  : observation.entityKey,
              attributeCode: 'protein_g',
              scopeHash: 'scope.a',
              resolutionStatus: 'resolved',
              chosenObservationId: 'synthetic.old',
              resolvedValue: parseQualifiedValue('1'),
              resolvedUnit: 'g',
              resolutionPolicyId: 'synthetic.policy',
              snapshotId: 'synthetic.snapshot',
              factVersion: 'synthetic-v1',
              manualOverride: false,
            ),
          ];
    final result = FactConflictEngine().classify(
      observation: observation,
      existingFacts: facts,
    );
    trials.add({
      'id': trial,
      'fact_count': facts.length,
      'observation_value': value,
      'observation_scope': scope,
      'classification': result.type.name,
      'reason': result.reason,
      'needs_manual_review': result.needsManualReview,
    });
  }
  final cluster = FactConflictEngine().resolveCluster(
    observations: [],
    existingFacts: [],
    sourceDocumentsById: {},
  );
  final output = File('build/algorithm_relation_contribution/$phase.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'phase': phase,
      'observed_at_utc': DateTime.now().toUtc().toIso8601String(),
      'producer_sha256': sha256.convert(File('tool/run_algorithm_relation_contribution_study.dart').readAsBytesSync()).toString(),
      'actual_source_sha256': {
        for (final path in ['lib/domain/usecases/catalog_resolution_engine.dart', 'lib/domain/usecases/source_authority_scorer.dart', 'lib/domain/usecases/fact_conflict_engine.dart']) path: sha256.convert(File(path).readAsBytesSync()).toString(),
      },
      'cases': rows,
      'minimal_scope_trials': trials,
      'empty_cluster_auxiliary': {'status': cluster.status, 'explanation': cluster.explanation},
      'real_health_data_used': false,
      'full_semantic_branch_coverage': false,
      'compiled_source_mutation_qualification': false,
    })}\n',
  );
  stdout.writeln(
    'Actual relation observations: ${rows.length}; phase=$phase; ${output.path}',
  );
}
