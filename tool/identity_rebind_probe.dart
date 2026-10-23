// Read-only probe for tool/identity_rebind.mjs. It reports the identity values
// that production code derives from the current tree, so the rebind never
// re-implements a digest. The last stdout line is one JSON object.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_configuration_change_impact_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

const _identityPath = 'lib/algorithm_sdk/algorithm_configuration_identity.dart';

/// Same payload as the registered-source-bundle test in
/// `test/parkinsum_algorithm_sdk_test.dart`.
String registeredSourceBundleSha256() {
  final paths =
      AlgorithmRegistry.all
          .expand((descriptor) => descriptor.sourcePaths)
          .where((path) => path != _identityPath)
          .toSet()
          .toList()
        ..sort();
  final payload = StringBuffer();
  for (final path in paths) {
    payload.writeln('$path:${sha256.convert(File(path).readAsBytesSync())}');
  }
  return sha256.convert(utf8.encode(payload.toString())).toString();
}

/// The manufactured previous identity is private to the impact service; its
/// own pin check reports the digest it derived when the pin is stale.
String impactBaselineSha256() {
  try {
    const AlgorithmConfigurationChangeImpactService().buildCurrentFixture();
    return AlgorithmConfigurationChangeImpactService.baselineFixtureSha256Pin;
  } on StateError catch (error) {
    final match = RegExp(
      r'^previous configuration identity rejected: expected \S+, actual ([a-f0-9]{64})$',
    ).firstMatch(error.message);
    if (match != null) return match.group(1)!;
    if (error.message.startsWith('current configuration identity rejected')) {
      return AlgorithmConfigurationChangeImpactService.baselineFixtureSha256Pin;
    }
    rethrow;
  }
}

void main(List<String> arguments) {
  final identity = AlgorithmConfigurationIdentity.defaults();
  final result = <String, Object?>{
    'version': AlgorithmConfigurationIdentity.defaultVersion,
    'configuration_sha256': identity.sha256Digest,
    'pinned_source_bundle_sha256':
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    'source_bundle_sha256': registeredSourceBundleSha256(),
  };
  if (arguments.contains('--impact')) {
    result['impact_baseline_sha256'] = impactBaselineSha256();
  }
  stdout.writeln(jsonEncode(result));
}
