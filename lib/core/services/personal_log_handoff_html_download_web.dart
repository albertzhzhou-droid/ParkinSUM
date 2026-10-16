import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

final class HandoffHtmlDownloadException implements Exception {
  const HandoffHtmlDownloadException(this.code);

  final String code;
}

/// Requests an offline browser download. This cannot observe whether the user
/// subsequently saves or cancels the browser's own download flow.
Future<void> downloadHtml({
  required Uint8List bytes,
  required String fileName,
  required bool Function() authorize,
}) async {
  if (!RegExp(
    r'^parkinsum-personal-log-[A-Za-z0-9._-]+\.html$',
  ).hasMatch(fileName)) {
    throw const HandoffHtmlDownloadException('invalid_file_name');
  }
  if (bytes.isEmpty || bytes.length > 32 * 1024 * 1024) {
    throw const HandoffHtmlDownloadException('invalid_html_bytes');
  }
  if (!authorize()) {
    throw const HandoffHtmlDownloadException('authorization_expired');
  }
  final body = web.document.body;
  if (body == null) {
    throw const HandoffHtmlDownloadException('html_download_unavailable');
  }
  String? url;
  web.HTMLAnchorElement? anchor;
  var requested = false;
  try {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    url = web.URL.createObjectURL(blob);
    anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    body.append(anchor);
    // Recheck the current owner, session and frozen-artifact lease at the
    // external side effect, after preparing the local browser objects.
    if (!authorize()) {
      throw const HandoffHtmlDownloadException('authorization_expired');
    }
    anchor.click();
    requested = true;
  } on HandoffHtmlDownloadException {
    rethrow;
  } catch (_) {
    throw const HandoffHtmlDownloadException('html_download_failed');
  } finally {
    if (url != null) {
      if (requested && anchor != null) {
        // WebKit may still consume the Blob after click returns. The bounded
        // cleanup retains only this local anchor/URL, never an owner or lease.
        _releaseAfterDownload(anchor, url);
      } else {
        anchor?.remove();
        web.URL.revokeObjectURL(url);
      }
    }
  }
}

void _releaseAfterDownload(web.HTMLAnchorElement anchor, String url) {
  Timer(const Duration(seconds: 1), () {
    anchor.remove();
    web.URL.revokeObjectURL(url);
  });
}
