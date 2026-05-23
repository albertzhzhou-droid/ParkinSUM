import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'cdss_artifact_store.dart';

CdssArtifactStore createPlatformArtifactStore() =>
    const LocalCdssArtifactStore();

class LocalCdssArtifactStore implements CdssArtifactStore {
  const LocalCdssArtifactStore();

  @override
  Future<CdssArtifactWriteResult> writeArtifactSet({
    required String artifactId,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
  }) async {
    final databasePath = await _artifactBasePath();
    final safeArtifactId = _safePathSegment(artifactId);
    final baseDir = Directory(
      p.join(databasePath, 'parkinsum_cdss_artifacts', safeArtifactId),
    );
    await baseDir.create(recursive: true);
    final written = <String, String>{};
    for (final entry in files.entries) {
      final file = File(p.join(baseDir.path, entry.key));
      await file.writeAsString(entry.value);
      written[entry.key] = file.path;
    }
    final manifestFile = File(p.join(baseDir.path, 'snapshot_manifest.json'));
    await manifestFile.writeAsString(artifactManifestJson(
      artifactId: artifactId,
      files: written,
      extra: manifest,
    ));
    written['snapshot_manifest.json'] = manifestFile.path;
    return CdssArtifactWriteResult(
      artifactPath: baseDir.path,
      files: written,
      durable: true,
    );
  }

  Future<String> _artifactBasePath() async {
    try {
      return await getDatabasesPath();
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }

  String _safePathSegment(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    if (sanitized.length <= 80) return sanitized;
    return '${sanitized.substring(0, 32)}_${sanitized.hashCode.abs()}';
  }
}
