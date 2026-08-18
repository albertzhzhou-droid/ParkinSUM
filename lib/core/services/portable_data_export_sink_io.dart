import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class PortableDataExportResult {
  const PortableDataExportResult({
    required this.delivery,
    required this.location,
    required this.userVisible,
  });

  final String delivery;
  final String? location;
  final bool userVisible;
}

class PortableDataExportException implements Exception {
  const PortableDataExportException({required this.residualFilePossible});

  final bool residualFilePossible;

  @override
  String toString() => 'Portable data export could not be completed safely.';
}

/// Conservative desktop export boundary.
///
/// Dart's portable [File] API does not expose a cross-platform atomic
/// no-replace publish primitive or a stable file-identity witness that remains
/// valid from an exclusive reservation through rename/copy. Consequently this
/// sink never creates a new desktop file. A missing target returns
/// `unsupported`, allowing the page to fall back to its authorized Copy JSON
/// path. An already-existing byte-identical file may be acknowledged, but is
/// never changed or deleted.
class PortableDataExportSink {
  const PortableDataExportSink({
    this.downloadsDirectory,
    this.beforeUnsupportedReturn,
  });

  final Directory? downloadsDirectory;

  /// Test seam used to prove that a file appearing after the absence check is
  /// neither overwritten nor removed. Production leaves this null.
  final FutureOr<void> Function(File target)? beforeUnsupportedReturn;

  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async {
    _validateFileName(fileName);
    final directory = downloadsDirectory ?? _defaultDownloadsDirectory();
    if (directory == null || !await directory.exists()) {
      return const PortableDataExportResult(
        delivery: 'unsupported',
        location: null,
        userVisible: false,
      );
    }

    final target = File(path.join(directory.path, fileName));
    if (!authorize()) {
      throw const PortableDataExportException(residualFilePossible: false);
    }

    if (await target.exists()) {
      RandomAccessFile? handle;
      try {
        final expectedBytes = utf8.encode(contents);
        handle = await target.open(mode: FileMode.read);
        final actualLength = await handle.length();
        if (actualLength != expectedBytes.length) {
          throw const PortableDataExportException(residualFilePossible: false);
        }
        final actualBytes = await handle.read(expectedBytes.length);
        final trailingByte = await handle.readByte();
        if (!authorize()) {
          throw const PortableDataExportException(residualFilePossible: false);
        }
        if (actualBytes.length != expectedBytes.length ||
            trailingByte != -1 ||
            sha256.convert(actualBytes) != sha256.convert(expectedBytes)) {
          throw const PortableDataExportException(residualFilePossible: false);
        }
        return PortableDataExportResult(
          delivery: 'existing_verified',
          location: target.path,
          userVisible: true,
        );
      } on PortableDataExportException {
        rethrow;
      } catch (_) {
        throw const PortableDataExportException(residualFilePossible: false);
      } finally {
        try {
          await handle?.close();
        } catch (_) {
          // A read-only handle close failure does not authorize a pathname
          // cleanup or turn this sink into a writer.
        }
      }
    }

    try {
      await beforeUnsupportedReturn?.call(target);
    } catch (_) {
      // This sink has not created a target or temporary file, so cleanup by
      // pathname would risk deleting another process's file. Leave all paths
      // untouched and return a generic failure.
      throw const PortableDataExportException(residualFilePossible: false);
    }
    if (!authorize()) {
      throw const PortableDataExportException(residualFilePossible: false);
    }
    return const PortableDataExportResult(
      delivery: 'unsupported',
      location: null,
      userVisible: false,
    );
  }

  Directory? _defaultDownloadsDirectory() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.trim().isEmpty) return null;
    return Directory(path.join(home, 'Downloads'));
  }

  void _validateFileName(String value) {
    if (!RegExp(
      r'^parkinsum-(?:user-data-[A-Za-z0-9._-]+\.parkinsum|support-[A-Za-z0-9._-]+\.support)\.json$',
    ).hasMatch(value)) {
      throw ArgumentError.value(value, 'fileName', 'Unsafe export filename.');
    }
  }
}
