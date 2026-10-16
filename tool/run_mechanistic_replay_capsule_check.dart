import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/mechanistic_replay_capsule.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';

void main() {
  final failures = <String>[];
  final vectors = <Map<String, Object?>>[];
  for (final scenario in ObservatoryScenario.values) {
    final snapshot = AlgorithmObservatoryService().build(scenario);
    final capsule = MechanisticReplayCapsule.capture(
      capsuleId: 'observatory_${scenario.name}_replay',
      generatedAtUtc: DateTime.utc(2026, 1, 1, 8),
      ledger: snapshot.eventLedger,
      context: snapshot.context,
      mealCompositionsById: {snapshot.composition.id: snapshot.composition},
    );
    final parsed = MechanisticReplayCapsule.fromJsonString(
      capsule.canonicalJson,
    );
    final restored = parsed.restore(
      expectedConfigurationSha256: snapshot.configurationIdentity.sha256Digest,
    );
    if (jsonEncode(restored.ledger.toJson()) !=
        jsonEncode(snapshot.eventLedger.toJson())) {
      failures.add('${scenario.name}:ledger_round_trip_drift');
    }
    if (jsonEncode(restored.context.toJson()) !=
        jsonEncode(snapshot.context.toJson())) {
      failures.add('${scenario.name}:context_round_trip_drift');
    }
    if (jsonEncode({
          for (final entry in restored.mealCompositionsById.entries)
            entry.key: entry.value.toJson(),
        }) !=
        jsonEncode({snapshot.composition.id: snapshot.composition.toJson()})) {
      failures.add('${scenario.name}:composition_round_trip_drift');
    }
    vectors.add(<String, Object?>{
      'scenario': scenario.name,
      'capsule_sha256': capsule.capsuleSha256,
      'ledger_sha256': restored.ledger.canonicalReplayDigest,
      'input_binding_sha256': restored.ledger.inputBindingSha256,
      'canonical_json': capsule.canonicalJson,
    });
  }

  final reference =
      jsonDecode(vectors.first['canonical_json']! as String)
          as Map<String, dynamic>;
  final digestMutation = Map<String, Object?>.from(reference)
    ..['capsule_sha256'] =
        '0000000000000000000000000000000000000000000000000000000000000000';
  var digestMutationBlocked = false;
  try {
    MechanisticReplayCapsule.fromJson(digestMutation);
  } on FormatException {
    digestMutationBlocked = true;
  }
  if (!digestMutationBlocked) failures.add('digest_mutation_survived');

  final unknownFieldMutation = Map<String, Object?>.from(reference)
    ..['unknown_root_field'] = true;
  var unknownFieldBlocked = false;
  try {
    MechanisticReplayCapsule.fromJson(unknownFieldMutation);
  } on FormatException {
    unknownFieldBlocked = true;
  }
  if (!unknownFieldBlocked) failures.add('unknown_field_mutation_survived');

  final versionMutation = Map<String, Object?>.from(reference)
    ..['schema_version'] = 2;
  var versionMutationBlocked = false;
  try {
    MechanisticReplayCapsule.fromJson(versionMutation);
  } on FormatException {
    versionMutationBlocked = true;
  }
  if (!versionMutationBlocked) failures.add('version_mutation_survived');

  final referenceRaw = vectors.first['canonical_json']! as String;
  final futureRaw = Map<String, Object?>.from(reference)
    ..['schema_version'] = 2;
  final digestRaw = Map<String, Object?>.from(reference)
    ..['capsule_sha256'] = '0' * 64;
  final anomalySpecs = <(String, String, String)>[
    (
      'duplicate_root',
      referenceRaw.replaceFirst(
        '{',
        '{"capsule_id":${jsonEncode(reference['capsule_id'])},',
      ),
      'duplicate_member',
    ),
    (
      'duplicate_escaped_nested',
      referenceRaw.replaceFirst(
        '"context":{',
        '"context":{"extra":true,"ex\\u0074ra":false,',
      ),
      'duplicate_member',
    ),
    (
      'duplicate_in_array',
      '{"items":[{"a":1,"\\u0061":1}]}',
      'duplicate_member',
    ),
    (
      'depth_over_limit',
      '${'[' * (mechanisticReplayMaxJsonContainerDepth + 1)}0${']' * (mechanisticReplayMaxJsonContainerDepth + 1)}',
      'depth_limit',
    ),
    (
      'utf8_over_byte_limit',
      '"${'餐' * (mechanisticReplayMaxJsonBytes ~/ 3 + 1)}"',
      'byte_limit',
    ),
    ('future_schema', jsonEncode(futureRaw), 'schema'),
    ('corrupt_digest', jsonEncode(digestRaw), 'digest'),
    (
      'truncated_container',
      referenceRaw.substring(0, referenceRaw.length - 1),
      'invalid_json',
    ),
  ];
  final rawAnomalies = <Map<String, Object?>>[];
  final rawAnomalyResults = <String, Object?>{};
  for (final (id, raw, expectedReason) in anomalySpecs) {
    var rejected = false;
    var actualReason = 'accepted';
    try {
      MechanisticReplayCapsule.fromJsonString(raw);
    } on FormatException catch (error) {
      actualReason = switch (error.message) {
        'replay_json_duplicate_member' => 'duplicate_member',
        'replay_json_depth_limit' => 'depth_limit',
        'replay_json_byte_limit' => 'byte_limit',
        'Unsupported replay capsule schema.' => 'schema',
        'Replay capsule digest mismatch.' => 'digest',
        _ => 'invalid_json',
      };
      rejected = actualReason == expectedReason;
    }
    if (!rejected) failures.add('raw_anomaly:$id:$actualReason');
    rawAnomalyResults[id] = rejected;
    rawAnomalies.add({
      'id': id,
      'raw_json': raw,
      'expected_reason': expectedReason,
    });
  }

  final output = <String, Object?>{
    'schema': mechanisticReplayCrossRuntimeVectorsSchema,
    'schema_version': mechanisticReplayCrossRuntimeVectorsSchemaVersion,
    'pass': failures.isEmpty,
    'failures': failures,
    'vector_count': vectors.length,
    'vectors': vectors,
    'raw_json_anomalies': rawAnomalies,
    'dart_raw_json_anomaly_results': rawAnomalyResults,
    'dart_mutation_results': <String, Object?>{
      'digest_mutation_blocked': digestMutationBlocked,
      'unknown_root_field_blocked': unknownFieldBlocked,
      'incompatible_version_blocked': versionMutationBlocked,
    },
    'boundary':
        'Dart lossless reconstruction over fixed synthetic fixtures. '
        'Passing is engineering replay evidence, not timezone-rule '
        'conformance, biological truth, clinical calibration, benefit, '
        'safety, regulatory qualification, or medical advice.',
  };
  final file = File('build/mechanistic_replay_capsule/dart_vectors.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  stdout.writeln(
    'Mechanistic replay capsule Dart vectors: '
    '${failures.isEmpty ? 'pass' : 'FAIL'}; '
    '${vectors.length} scenarios; artifact=${file.path}',
  );
  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
  }
}
