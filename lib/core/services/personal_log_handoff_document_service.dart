import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/usecases/personal_log_handoff_summary_service.dart';
import 'personal_log_handoff_html_download.dart'
    if (dart.library.js_interop) 'personal_log_handoff_html_download_web.dart'
    as html_download;

const personalLogHandoffMaxPdfBytes = 32 * 1024 * 1024;
const personalLogHandoffMaxHtmlBytes = 32 * 1024 * 1024;

enum PersonalLogHandoffDeliveryStatus {
  completed,
  cancelled,
  unavailable,
  downloadRequested,
}

final class PersonalLogHandoffDeliveryException implements Exception {
  const PersonalLogHandoffDeliveryException(this.code);

  final String code;

  @override
  String toString() => 'PersonalLogHandoffDeliveryException($code)';
}

abstract interface class PersonalLogHandoffDelivery {
  Future<PersonalLogHandoffDeliveryStatus> printPdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  });

  Future<PersonalLogHandoffDeliveryStatus> saveOrSharePdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  });

  Future<PersonalLogHandoffDeliveryStatus> shareHtml({
    required Uint8List bytes,
    required String fileName,
    required Rect? sharePositionOrigin,
    required bool Function() authorize,
  });
}

final class SystemPersonalLogHandoffDelivery
    implements PersonalLogHandoffDelivery {
  const SystemPersonalLogHandoffDelivery();

  @override
  Future<PersonalLogHandoffDeliveryStatus> printPdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  }) async {
    _validate(fileName, bytes);
    if (!authorize()) {
      throw const PersonalLogHandoffDeliveryException('authorization_expired');
    }
    try {
      final printed = await Printing.layoutPdf(
        name: fileName,
        format: PdfPageFormat.a4,
        dynamicLayout: false,
        onLayout: (_) {
          if (!authorize()) {
            throw const PersonalLogHandoffDeliveryException(
              'authorization_expired',
            );
          }
          return bytes;
        },
      );
      return printed
          ? PersonalLogHandoffDeliveryStatus.completed
          : PersonalLogHandoffDeliveryStatus.cancelled;
    } on PersonalLogHandoffDeliveryException {
      rethrow;
    } catch (_) {
      throw const PersonalLogHandoffDeliveryException('print_failed');
    }
  }

  @override
  Future<PersonalLogHandoffDeliveryStatus> saveOrSharePdf({
    required Uint8List bytes,
    required String fileName,
    required bool Function() authorize,
  }) async {
    _validate(fileName, bytes);
    if (!authorize()) {
      throw const PersonalLogHandoffDeliveryException('authorization_expired');
    }
    try {
      final shared = await Printing.sharePdf(bytes: bytes, filename: fileName);
      return shared
          ? PersonalLogHandoffDeliveryStatus.completed
          : PersonalLogHandoffDeliveryStatus.cancelled;
    } catch (_) {
      throw const PersonalLogHandoffDeliveryException('save_share_failed');
    }
  }

  @override
  Future<PersonalLogHandoffDeliveryStatus> shareHtml({
    required Uint8List bytes,
    required String fileName,
    required Rect? sharePositionOrigin,
    required bool Function() authorize,
  }) async {
    _validateHtml(fileName, bytes);
    if (!authorize()) {
      throw const PersonalLogHandoffDeliveryException('authorization_expired');
    }
    if (kIsWeb) {
      try {
        await html_download.downloadHtml(
          bytes: bytes,
          fileName: fileName,
          authorize: authorize,
        );
        return PersonalLogHandoffDeliveryStatus.downloadRequested;
      } on html_download.HandoffHtmlDownloadException catch (error) {
        throw PersonalLogHandoffDeliveryException(error.code);
      } catch (_) {
        throw const PersonalLogHandoffDeliveryException('html_download_failed');
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return PersonalLogHandoffDeliveryStatus.unavailable;
    }
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(bytes, name: fileName, mimeType: 'text/html'),
          ],
          title: 'ParkinSUM personal log handoff',
          subject: 'ParkinSUM personal log handoff',
          sharePositionOrigin: sharePositionOrigin,
          fileNameOverrides: <String>[fileName],
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => PersonalLogHandoffDeliveryStatus.completed,
        ShareResultStatus.dismissed =>
          PersonalLogHandoffDeliveryStatus.cancelled,
        ShareResultStatus.unavailable =>
          PersonalLogHandoffDeliveryStatus.unavailable,
      };
    } on PersonalLogHandoffDeliveryException {
      rethrow;
    } catch (_) {
      throw const PersonalLogHandoffDeliveryException('html_share_failed');
    }
  }

  void _validate(String fileName, Uint8List bytes) {
    if (!RegExp(
      r'^parkinsum-personal-log-[A-Za-z0-9._-]+\.pdf$',
    ).hasMatch(fileName)) {
      throw const PersonalLogHandoffDeliveryException('invalid_file_name');
    }
    if (bytes.isEmpty || bytes.length > personalLogHandoffMaxPdfBytes) {
      throw const PersonalLogHandoffDeliveryException('invalid_pdf_bytes');
    }
  }

  void _validateHtml(String fileName, Uint8List bytes) {
    if (!RegExp(
      r'^parkinsum-personal-log-[A-Za-z0-9._-]+\.html$',
    ).hasMatch(fileName)) {
      throw const PersonalLogHandoffDeliveryException('invalid_file_name');
    }
    if (bytes.isEmpty || bytes.length > personalLogHandoffMaxHtmlBytes) {
      throw const PersonalLogHandoffDeliveryException('invalid_html_bytes');
    }
  }
}

/// Serializes the frozen semantic blocks to a self-contained, offline HTML
/// document. This is structured HTML output; it is not a tagged PDF or a
/// declaration of screen-reader, language-tag, or PDF/UA conformance.
final class PersonalLogHandoffHtmlSerializer {
  const PersonalLogHandoffHtmlSerializer();

  Uint8List render(PersonalLogHandoffArtifact artifact) {
    if (artifact.documentBlocks.isEmpty) {
      throw const FormatException('handoff_document_blocks_missing');
    }
    final metadata = artifact.semanticDocument['document'];
    final language = metadata is Map ? metadata['language'] ?? 'en' : 'en';
    final direction = metadata is Map
        ? metadata['direction'] ?? 'auto'
        : 'auto';
    if (language is! String ||
        !RegExp(
          r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8}){0,3}$',
        ).hasMatch(language) ||
        !const ['auto', 'ltr', 'rtl'].contains(direction)) {
      throw const FormatException('handoff_document_language_invalid');
    }
    final html = StringBuffer()
      ..write('<!doctype html>\n')
      ..write('<html lang="$language" dir="$direction">\n<head>\n')
      ..write('<meta charset="utf-8">\n')
      ..write(
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
      )
      ..write(
        '<meta name="parkinsum-document-schema" content="$personalLogHandoffDocumentSchemaVersion">\n',
      )
      ..write(
        '<meta name="parkinsum-content-sha256" content="${_escape(artifact.contentSha256)}">\n',
      )
      ..write('<title>ParkinSUM personal log handoff</title>\n')
      ..write('<style>\n')
      ..write(
        'body{font-family:system-ui,-apple-system,"Segoe UI",sans-serif;line-height:1.55;color:#111827;background:#fff;margin:0;padding:1.5rem}\n',
      )
      ..write('main{max-width:72ch;margin:0 auto}\n')
      ..write('h1{font-size:1.7rem;line-height:1.2}\n')
      ..write('h2{font-size:1.25rem;margin-top:1.7rem}\n')
      ..write('ul{padding-inline-start:1.5rem}\n')
      ..write('li{margin-block:.55rem}\n')
      ..write('.detail{margin:.2rem 0;color:#374151}\n')
      ..write(
        '.boundary{border-inline-start:.25rem solid #9a3412;padding:.25rem 1rem;margin-block:.65rem;background:#fff7ed}\n',
      )
      ..write('</style>\n</head>\n<body>\n<main>\n<article>\n');

    for (final block in artifact.documentBlocks) {
      switch (block) {
        case PersonalLogHandoffHeadingBlock(:final level, :final text):
          final tag = level == 1 ? 'h1' : 'h2';
          final id = level == 1 ? ' id="document-title"' : '';
          html.write('<$tag$id dir="auto">${_escape(text)}</$tag>\n');
        case PersonalLogHandoffParagraphBlock(:final text, :final warning):
          if (warning) {
            html.write(
              '<aside class="boundary" aria-label="Important boundary"><p dir="auto">${_escape(text)}</p></aside>\n',
            );
          } else {
            html.write('<p dir="auto">${_escape(text)}</p>\n');
          }
        case PersonalLogHandoffListBlock(:final items):
          html.write('<ul>\n');
          for (final item in items) {
            html.write('<li dir="auto"><p>${_escape(item.text)}</p>\n');
            for (final detail in item.details) {
              html.write('<p class="detail">${_escape(detail)}</p>\n');
            }
            html.write('</li>\n');
          }
          html.write('</ul>\n');
      }
    }
    html.write('</article>\n</main>\n</body>\n</html>\n');
    final bytes = Uint8List.fromList(utf8.encode(html.toString()));
    if (bytes.isEmpty || bytes.length > personalLogHandoffMaxHtmlBytes) {
      throw const FormatException('handoff_html_byte_budget_exceeded');
    }
    return bytes;
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Produces a PDF from the same fixed-size Flutter page widget used by the UI
/// preview. Text is rasterized with the platform's Flutter font fallback, so
/// user-entered non-Latin text does not require a network font download.
///
/// This preserves visual fidelity and offline behavior, but the resulting PDF
/// is image-based rather than a tagged/searchable accessibility document. That
/// limitation is deliberately exposed in the feature UI and upgrade queue.
abstract interface class PersonalLogHandoffRenderer {
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  });
}

enum PersonalLogHandoffFailureStage {
  snapshot,
  summary,
  renderPdf,
  canvasLayout,
  canvasRasterize,
  pdfEncode,
  validateRevision,
  delivery,
}

/// Failure diagnostics contain no exception message, URL, identifier or record.
/// Release Web stacks retain only the compiled source basename and coordinates.
final class PersonalLogHandoffFailureDiagnostic {
  const PersonalLogHandoffFailureDiagnostic._(
    this.stage,
    this.failureType,
    this.sourceFrames,
  );

  factory PersonalLogHandoffFailureDiagnostic.capture({
    required PersonalLogHandoffFailureStage stage,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final type = switch (error) {
      FormatException() => 'FormatException',
      StateError() => 'StateError',
      ArgumentError() => 'ArgumentError',
      FlutterError() => 'FlutterError',
      PdfException() => 'PdfException',
      DiagnosticsNode() => 'DiagnosticsNode',
      Error() => 'Error',
      Exception() => 'Exception',
      _ => 'Object',
    };
    // An allowlist prevents arbitrary stack text and filesystem/URL data from
    // becoming log output. Method names and error.toString() are never emitted.
    const sourceNames = <String>{
      'personal_log_handoff_document_service.dart',
      'personal_log_handoff_page.dart',
      'personal_log_handoff_summary_service.dart',
      'adapter.dart',
      'framework.dart',
      'diagnostics.dart',
      'object.dart',
      'layer.dart',
      'proxy_box.dart',
      'view.dart',
      'widget_wrapper.dart',
      'document.dart',
      'image_provider.dart',
      'main.dart.js',
    };
    final frames = <String>[];
    final locations = RegExp(
      r'(?:^|[/\s(])([a-zA-Z0-9_]+\.dart(?:\.js)?):(\d{1,8}):(\d{1,8})(?=\D|$)',
      multiLine: true,
    );
    for (final match in locations.allMatches(stackTrace.toString())) {
      final source = match.group(1)!;
      if (!sourceNames.contains(source)) continue;
      final frame = '$source:${match.group(2)}:${match.group(3)}';
      if (!frames.contains(frame)) frames.add(frame);
      if (frames.length == 6) break;
    }
    return PersonalLogHandoffFailureDiagnostic._(
      stage,
      type,
      List<String>.unmodifiable(frames),
    );
  }

  final PersonalLogHandoffFailureStage stage;
  final String failureType;
  final List<String> sourceFrames;

  String get logLine =>
      '[PersonalLogHandoff] failed stage=${stage.name} '
      'type=$failureType source=${sourceFrames.isEmpty ? 'unavailable' : sourceFrames.join(',')}';
}

final class PersonalLogHandoffRenderException implements Exception {
  const PersonalLogHandoffRenderException(this.diagnostic);

  final PersonalLogHandoffFailureDiagnostic diagnostic;
}

final class SystemPersonalLogHandoffPdfRenderer
    implements PersonalLogHandoffRenderer {
  const SystemPersonalLogHandoffPdfRenderer({this.pixelRatio = 1.5});

  final double pixelRatio;

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) async {
    if (!pixelRatio.isFinite || pixelRatio < 1 || pixelRatio > 3) {
      throw const FormatException('handoff_pdf_pixel_ratio_invalid');
    }
    final document = pw.Document(
      title: 'ParkinSUM personal log handoff',
      author: 'ParkinSUM Companion',
      subject: 'User-entered personal log; not clinically verified',
      creator: 'ParkinSUM Companion',
      producer: 'ParkinSUM Companion via package:pdf',
      compress: true,
    );
    for (final page in artifact.pages) {
      if (!context.mounted) {
        throw const FormatException('handoff_pdf_context_disposed');
      }
      final wrapped =
          await _rasterizePage(
            context: context,
            page: page,
            totalPages: artifact.pages.length,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw const FormatException('handoff_pdf_render_timeout'),
          );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(wrapped, fit: pw.BoxFit.fill),
        ),
      );
    }
    final Uint8List bytes;
    try {
      bytes = await document.save();
    } catch (error, stackTrace) {
      throw PersonalLogHandoffRenderException(
        PersonalLogHandoffFailureDiagnostic.capture(
          stage: PersonalLogHandoffFailureStage.pdfEncode,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
    if (bytes.isEmpty || bytes.length > personalLogHandoffMaxPdfBytes) {
      throw const FormatException('handoff_pdf_byte_budget_exceeded');
    }
    return bytes;
  }

  Future<pw.ImageProvider> _rasterizePage({
    required BuildContext context,
    required PersonalLogHandoffDocumentPage page,
    required int totalPages,
  }) async {
    const size = Size(
      PersonalLogHandoffPageCanvas.pageWidth,
      PersonalLogHandoffPageCanvas.pageHeight,
    );
    final boundary = RenderRepaintBoundary();
    final position = RenderPositionedBox(child: boundary);
    final renderView = RenderView(
      view: View.of(context),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
      child: position,
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    final focusManager = FocusManager();
    final buildOwner = BuildOwner(focusManager: focusManager);
    RenderObjectToWidgetElement<RenderBox>? root;
    ui.Image? image;
    var stage = PersonalLogHandoffFailureStage.canvasLayout;
    try {
      renderView.prepareInitialFrame();
      // WidgetWrapper.fromWidget reads debugFillProperties to discover these
      // constraints. Flutter drops DiagnosticPropertiesBuilder.add in release,
      // so that path throws before painting. Use the explicit page constraints
      // and the same canvas with public rendering APIs in every build mode.
      root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.fromSize(
            size: size,
            child: PersonalLogHandoffPageCanvas(
              page: page,
              totalPages: totalPages,
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);
      buildOwner
        ..buildScope(root)
        ..finalizeTree();
      pipeline
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();
      stage = PersonalLogHandoffFailureStage.canvasRasterize;
      image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw const FormatException('handoff_pdf_image_data_unavailable');
      }
      return pw.RawImage(
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: image.width,
        height: image.height,
      );
    } catch (error, stackTrace) {
      throw PersonalLogHandoffRenderException(
        PersonalLogHandoffFailureDiagnostic.capture(
          stage: stage,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      image?.dispose();
      if (root != null) {
        RenderObjectToWidgetAdapter<RenderBox>(
          container: boundary,
        ).attachToRenderTree(buildOwner, root);
        buildOwner
          ..buildScope(root)
          ..finalizeTree();
      }
      pipeline.rootNode = null;
      position.child = null;
      // The adapter now has no children; its local root can be collected. The
      // detached host render objects are owned here and released explicitly.
      boundary.dispose();
      renderView.child = null;
      position.dispose();
      renderView.dispose();
      focusManager.dispose();
      pipeline.dispose();
    }
  }
}

/// Fixed A4-ratio page shared by the in-app preview and PDF rasterizer.
class PersonalLogHandoffPageCanvas extends StatelessWidget {
  const PersonalLogHandoffPageCanvas({
    super.key,
    required this.page,
    required this.totalPages,
  });

  static const double pageWidth = 595;
  static const double pageHeight = 842;

  final PersonalLogHandoffDocumentPage page;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(38, 34, 38, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in page.lines) _line(line),
              const Spacer(),
              const Divider(height: 10, color: Color(0xFFB5B5B5)),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ParkinSUM user-entered personal log — not clinically verified',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: Color(0xFF444444),
                        fontFamily: 'monospace',
                        fontSize: 8,
                      ),
                    ),
                  ),
                  Text(
                    '${page.number}/$totalPages',
                    style: const TextStyle(
                      color: Color(0xFF444444),
                      fontFamily: 'monospace',
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String line) {
    final isTitle = line.startsWith('# ');
    final isSection = line.startsWith('## ');
    final isWarning = line.startsWith('! ');
    final visible = isTitle
        ? line.substring(2)
        : isSection
        ? line.substring(3)
        : isWarning
        ? line.substring(2)
        : line;
    final style = TextStyle(
      color: isWarning ? const Color(0xFF9A3412) : const Color(0xFF111827),
      fontFamily: 'monospace',
      fontSize: isTitle
          ? 18
          : isSection
          ? 13
          : isWarning
          ? 10
          : 9.5,
      height: 1.2,
      fontWeight: isTitle || isSection || isWarning
          ? FontWeight.w700
          : FontWeight.w400,
    );
    return SizedBox(
      height: isTitle
          ? 28
          : isSection
          ? 21
          : isWarning
          ? 16
          : 14,
      child: Text(
        visible,
        maxLines: 1,
        overflow: TextOverflow.clip,
        textDirection: TextDirection.ltr,
        style: style,
      ),
    );
  }
}
