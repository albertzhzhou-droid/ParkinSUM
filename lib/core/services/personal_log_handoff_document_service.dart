import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/usecases/personal_log_handoff_summary_service.dart';

const personalLogHandoffMaxPdfBytes = 32 * 1024 * 1024;

enum PersonalLogHandoffDeliveryStatus { completed, cancelled }

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

final class SystemPersonalLogHandoffPdfRenderer
    implements PersonalLogHandoffRenderer {
  const SystemPersonalLogHandoffPdfRenderer({this.pixelRatio = 1.5});

  final double pixelRatio;

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) async {
    if (pixelRatio < 1 || pixelRatio > 3) {
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
          await WidgetWrapper.fromWidget(
            context: context,
            constraints: const BoxConstraints.tightFor(
              width: PersonalLogHandoffPageCanvas.pageWidth,
              height: PersonalLogHandoffPageCanvas.pageHeight,
            ),
            pixelRatio: pixelRatio,
            widget: PersonalLogHandoffPageCanvas(
              page: page,
              totalPages: artifact.pages.length,
            ),
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
    final bytes = await document.save();
    if (bytes.isEmpty || bytes.length > personalLogHandoffMaxPdfBytes) {
      throw const FormatException('handoff_pdf_byte_budget_exceeded');
    }
    return bytes;
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
        : isSection || isWarning
        ? line.substring(3)
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
