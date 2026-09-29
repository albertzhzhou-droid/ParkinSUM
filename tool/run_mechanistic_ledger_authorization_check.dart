import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_authorization.dart';

void main() {
  const authorizer = MechanisticEventLedgerAuthorizationService();
  final snapshots = <AlgorithmObservatorySnapshot>[
    for (final scenario in ObservatoryScenario.values)
      AlgorithmObservatoryService().build(scenario),
  ];
  final failures = <String>[];
  for (final snapshot in snapshots) {
    if (!snapshot.ledgerAuthorization.authorized) {
      failures.add(
        '${snapshot.scenario.name}:authorization_blocked:'
        '${snapshot.ledgerAuthorization.findings.join(',')}',
      );
    }
    if (snapshot.ledgerAuthorization.recomputedInputBindingSha256 !=
        snapshot.eventLedger.inputBindingSha256) {
      failures.add('${snapshot.scenario.name}:input_binding_mismatch');
    }
  }

  final reference = snapshots.first;
  final configurationMutation = authorizer.authorize(
    ledger: reference.eventLedger,
    context: reference.context,
    mealCompositionsById: {reference.composition.id: reference.composition},
    expectedConfigurationSha256:
        '0000000000000000000000000000000000000000000000000000000000000000',
  );
  if (configurationMutation.authorized ||
      !configurationMutation.assessment.findings.contains(
        'authorization.configuration_identity_mismatch',
      )) {
    failures.add('configuration_mutation_survived');
  }

  final contextMutation = authorizer.authorize(
    ledger: reference.eventLedger,
    context: TimeAxisConflictContext(
      referenceMinute: reference.context.referenceMinute,
      medicationEvents: reference.context.medicationEvents,
      mealEvents: reference.context.mealEvents,
      foodComponentEvents: reference.context.foodComponentEvents,
      userDefinedWindow: reference.context.userDefinedWindow,
      missingFields: {...reference.context.missingFields, 'gate_mutation'},
    ),
    mealCompositionsById: {reference.composition.id: reference.composition},
    expectedConfigurationSha256: reference.configurationIdentity.sha256Digest,
  );
  if (contextMutation.authorized ||
      !contextMutation.assessment.findings.contains(
        'authorization.input_binding_mismatch',
      )) {
    failures.add('context_mutation_survived');
  }

  final compositionMutation = authorizer.authorize(
    ledger: reference.eventLedger,
    context: reference.context,
    mealCompositionsById: {'wrong_key': reference.composition},
    expectedConfigurationSha256: reference.configurationIdentity.sha256Digest,
  );
  if (compositionMutation.authorized ||
      !compositionMutation.assessment.findings.any(
        (finding) => finding.startsWith(
          'authorization.composition_map_identity_mismatch:',
        ),
      )) {
    failures.add('composition_map_mutation_survived');
  }

  final output = <String, Object?>{
    'schema': mechanisticLedgerAuthorizationSchema,
    'schema_version': mechanisticLedgerAuthorizationSchemaVersion,
    'pass': failures.isEmpty,
    'failures': failures,
    'scenario_count': snapshots.length,
    'scenario_assessments': [
      for (final snapshot in snapshots)
        <String, Object?>{
          'scenario': snapshot.scenario.name,
          'assessment': snapshot.ledgerAuthorization.toJson(),
        },
    ],
    'mutation_results': <String, Object?>{
      'configuration_drift_blocked': !configurationMutation.authorized,
      'context_drift_blocked': !contextMutation.authorized,
      'composition_identity_drift_blocked': !compositionMutation.authorized,
    },
    'boundary':
        'Offline deterministic integrity verification over synthetic fixtures. '
        'Passing is not lossless replay, biological truth, clinical '
        'calibration, validation, benefit, safety, or medical advice.',
  };
  final file = File('build/mechanistic_ledger_authorization/latest.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  stdout.writeln(
    'Mechanistic ledger authorization: '
    '${failures.isEmpty ? 'pass' : 'FAIL'}; '
    '${snapshots.length} scenarios; 3 mutation families; artifact=${file.path}',
  );
  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
  }
}
