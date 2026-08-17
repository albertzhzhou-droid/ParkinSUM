import 'dart:convert';

import 'cdss_artifact_store.dart';

CdssArtifactStore createPlatformArtifactStore() => InlineCdssArtifactStore();

/// Artifact store for platforms without a filesystem (web).
///
/// Content is retained in process memory so a written artifact set can be read
/// back within the same session — otherwise the audit records this project
/// writes would be unverifiable on this platform. It is explicitly
/// **non-durable**: `durable: false` on both the write and read result, and
/// nothing survives a reload.
class InlineCdssArtifactStore implements CdssArtifactStore {
  InlineCdssArtifactStore();

  final Map<String, _InlineArtifact> _artifacts = <String, _InlineArtifact>{};

  @override
  Future<CdssArtifactWriteResult> writeArtifactSet({
    required String artifactId,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
  }) async {
    _artifacts[artifactId] = _InlineArtifact(
      files: Map<String, String>.unmodifiable(files),
      manifest: Map<String, dynamic>.unmodifiable(manifest),
    );
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

  @override
  Future<CdssArtifactReadResult?> readArtifactSet(String artifactId) async {
    final artifact = _artifacts[artifactId];
    if (artifact == null) return null;
    return CdssArtifactReadResult(
      artifactId: artifactId,
      files: artifact.files,
      manifest: artifact.manifest,
      durable: false,
    );
  }
}

class _InlineArtifact {
  final Map<String, String> files;
  final Map<String, dynamic> manifest;

  const _InlineArtifact({required this.files, required this.manifest});
}
