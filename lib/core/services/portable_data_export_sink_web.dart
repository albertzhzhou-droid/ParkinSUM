import 'dart:js_interop';

import 'package:web/web.dart' as web;

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
}

class PortableDataExportSink {
  const PortableDataExportSink();

  Future<PortableDataExportResult> save({
    required String fileName,
    required String contents,
    required bool Function() authorize,
  }) async {
    _validateFileName(fileName);
    final blob = web.Blob(
      <JSAny>[contents.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    try {
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      web.document.body?.append(anchor);
      if (!authorize()) {
        anchor.remove();
        throw const PortableDataExportException(residualFilePossible: false);
      }
      anchor.click();
      anchor.remove();
    } finally {
      web.URL.revokeObjectURL(url);
    }
    return const PortableDataExportResult(
      delivery: 'browser_download',
      location: null,
      userVisible: true,
    );
  }

  void _validateFileName(String value) {
    if (!RegExp(
      r'^parkinsum-(?:user-data-[A-Za-z0-9._-]+\.parkinsum|support-[A-Za-z0-9._-]+\.support)\.json$',
    ).hasMatch(value)) {
      throw ArgumentError.value(value, 'fileName', 'Unsafe export filename.');
    }
  }
}
