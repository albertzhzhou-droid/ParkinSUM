import 'dart:convert';

import 'cdss_artifact_store.dart';

CdssArtifactStore createPlatformArtifactStore() =>
    const InlineCdssArtifactStore();

class InlineCdssArtifactStore implements CdssArtifactStore {
  const InlineCdssArtifactStore();

  @override
  Future<CdssArtifactWriteResult> writeArtifactSet({
    required String artifactId,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
  }) async {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(manifest)));
    return CdssArtifactWriteResult(
      artifactPath: 'inline://cdss_artifacts/$artifactId?manifest=$encoded',
      files: {
        for (final entry in files.entries)
          entry.key: 'inline://cdss_artifacts/$artifactId/${entry.key}',
      },
      durable: false,
    );
  }
}
