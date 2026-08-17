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

/// An artifact set read back from a [CdssArtifactStore].
///
/// [durable] mirrors the write-side flag: `false` means the content survived
/// only in process memory and will not outlive the app.
class CdssArtifactReadResult {
  final String artifactId;

  /// File name → file content. Empty only when the artifact set itself was
  /// written empty.
  final Map<String, String> files;

  final Map<String, dynamic> manifest;
  final bool durable;

  const CdssArtifactReadResult({
    required this.artifactId,
    required this.files,
    required this.manifest,
    required this.durable,
  });
}

abstract class CdssArtifactStore {
  Future<CdssArtifactWriteResult> writeArtifactSet({
    required String artifactId,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
  });

  /// Reads back a previously written artifact set, or `null` when this store
  /// holds no artifact under [artifactId].
  ///
  /// Every backend must implement this explicitly rather than inheriting a
  /// default. A store that cannot read is required to say so by returning
  /// `null`, so "absent" is never confused with a fabricated empty success —
  /// the same rule the report generators follow with `missing_artifact`.
  ///
  /// Without a read side, the audit records this project writes could never be
  /// verified after the fact, which is the whole point of writing them.
  Future<CdssArtifactReadResult?> readArtifactSet(String artifactId);
}

CdssArtifactStore createCdssArtifactStore() => createPlatformArtifactStore();

String artifactManifestJson({
  required String artifactId,
  required Map<String, String> files,
  required Map<String, dynamic> extra,
}) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert({'artifact_id': artifactId, 'files': files, ...extra});
}
