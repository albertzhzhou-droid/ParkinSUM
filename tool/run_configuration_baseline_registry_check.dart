import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/algorithm_configuration_change_impact_service.dart';
import 'package:parkinsum_companion/domain/usecases/configuration_baseline_registry_service.dart';

Future<void> main() async {
  final impact = const AlgorithmConfigurationChangeImpactService()
      .buildCurrentFixture();
  final transition = await const ConfigurationBaselineRegistryService()
      .buildCurrentFixture(
        impact: impact,
        contextOfUseRecordSha256:
            '1111111111111111111111111111111111111111111111111111111111111111',
      );
  if (transition.accepted ||
      transition.reason != 'verification_obligations_incomplete' ||
      transition.state.integrityReasons.isNotEmpty ||
      transition.state.events.length != 2) {
    stderr.writeln('Configuration baseline registry fixture failed closed.');
    exitCode = 1;
    return;
  }
  final directory = Directory('build/configuration_baseline_registry')
    ..createSync(recursive: true);
  final output = File('${directory.path}/latest.json')
    ..writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'transition_accepted': transition.accepted,
        'transition_reason': transition.reason,
        'receipt': transition.receipt.toJson(),
        'registry': transition.state.toJson(),
      }),
    );
  stdout.writeln(
    'Configuration baseline registry: pass; revision='
    '${transition.state.revision}; events=${transition.state.events.length}; '
    'active=${transition.state.activeConfigurationSha256}; '
    'candidate=${transition.receipt.candidateConfigurationSha256}; '
    'decision=${transition.reason}; artifact=${output.path}',
  );
}
