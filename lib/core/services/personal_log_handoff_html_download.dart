import 'dart:typed_data';

final class HandoffHtmlDownloadException implements Exception {
  const HandoffHtmlDownloadException(this.code);

  final String code;
}

/// Selected only outside Web; native delivery remains the system share sheet.
Future<void> downloadHtml({
  required Uint8List bytes,
  required String fileName,
  required bool Function() authorize,
}) async {
  throw const HandoffHtmlDownloadException('html_download_unavailable');
}
