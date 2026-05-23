import 'dart:convert';

import 'cdss_artifact_store_stub.dart'
    if (dart.library.io) 'cdss_artifact_store_io.dart';

class CdssArtifactWriteResult {
  final String artifactPath;
  final Map<String, String> files;
  final bool durable;

  const CdssArtifactWriteResult({
    required this.artifactPath,
    required this.files,
    required this.durable,
  });
}

abstract class CdssArtifactStore {
  Future<CdssArtifactWriteResult> writeArtifactSet({
    required String artifactId,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
  });
}

CdssArtifactStore createCdssArtifactStore() => createPlatformArtifactStore();

String artifactManifestJson({
  required String artifactId,
  required Map<String, String> files,
  required Map<String, dynamic> extra,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'artifact_id': artifactId,
    'files': files,
    ...extra,
  });
}
