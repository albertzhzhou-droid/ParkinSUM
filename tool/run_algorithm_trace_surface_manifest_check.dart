import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/algorithm_descriptor.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

void main(List<String> arguments) {
  final manifest = AlgorithmTraceSurfaceManifest(
    algorithms: AlgorithmRegistry.all,
    providers: const [AlgorithmObservatoryService.traceProviderContract],
  );
  final actual = manifest.toJson();

  if (arguments.contains('--print')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(actual));
    return;
  }

  final failures = <String>[];
  final manifestFile = File('config/algorithm_trace_surface_manifest.json');
  if (!manifestFile.existsSync()) {
    failures.add('missing config/algorithm_trace_surface_manifest.json');
  } else {
    final expected = jsonDecode(manifestFile.readAsStringSync());
    if (_canonicalJson(expected) != _canonicalJson(actual)) {
      failures.add(
        'compiled trace surface differs from the reviewed config manifest',
      );
    }
  }

  for (final provider in manifest.providers) {
    for (final path in <String>[
      provider.routeSourcePath,
      provider.providerSourcePath,
      ...provider.executableTestPaths,
    ]) {
      if (!File(path).existsSync()) {
        failures.add('missing declared path: $path');
      }
    }
    final routeSource = File(provider.routeSourcePath).readAsStringSync();
    if (!routeSource.contains('AlgorithmObservatoryPage')) {
      failures.add(
        '${provider.routeId} no longer opens AlgorithmObservatoryPage',
      );
    }
    final destinationId = provider.routeId.split('.').last;
    if (!routeSource.contains("id: '$destinationId'")) {
      failures.add(
        '${provider.routeId} no longer matches its registered destination id',
      );
    }
  }

  final report = <String, dynamic>{
    'report_type': 'parkinsum_algorithm_trace_surface_check',
    'schema_version': 1,
    'pass': failures.isEmpty,
    'failures': failures,
    'manifest_sha256': manifest.sha256Digest,
    'algorithm_count': manifest.algorithms.length,
    'production_trace_count': manifest.liveCount,
    'static_contract_only_count': manifest.staticOnlyCount,
    'provider_count': manifest.providers.length,
    'boundary':
        'Production trace means fixed synthetic production-engine execution; '
        'it is not clinical calibration, patient evidence, benefit, safety, '
        'or medical advice.',
  };
  final output = File('build/algorithm_trace_surface/latest.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );

  if (failures.isNotEmpty) {
    stderr.writeln('Algorithm trace surface: FAIL');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Algorithm trace surface: PASS '
    '(${manifest.liveCount}/${manifest.algorithms.length} production traces; '
    '${manifest.staticOnlyCount} static contracts; '
    '${manifest.sha256Digest})',
  );
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonicalize).toList();
  return value;
}
