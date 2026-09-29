import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/algorithm_configuration_change_impact_service.dart';

void main(List<String> arguments) {
  final package = const AlgorithmConfigurationChangeImpactService()
      .buildCurrentFixture();
  final encoded = const JsonEncoder.withIndent('  ').convert(package.toJson());
  if (arguments.contains('--stdout')) {
    stdout.writeln(encoded);
    return;
  }
  final directory = Directory('build/algorithm_configuration_change_impact')
    ..createSync(recursive: true);
  final output = File('${directory.path}/latest.json')
    ..writeAsStringSync(encoded);
  stdout.writeln(
    'Algorithm configuration change impact: ${package.changes.length} changes, '
    '${package.replayDeltas.length} replay outputs, '
    '${package.integrityReasons.length} graph holds, '
    'artifact=${output.path}, sha256=${package.packageSha256}',
  );
}
