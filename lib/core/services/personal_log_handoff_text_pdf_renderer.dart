import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/usecases/personal_log_handoff_summary_service.dart';
import 'personal_log_handoff_document_service.dart';

typedef HandoffPdfFontLoader = Future<List<ByteData>> Function();

/// Searchable text over the exact frozen preview pages. It is not tagged PDF/UA.
/// Fonts are bundled, and unsupported glyphs fail before any delivery action.
final class SystemPersonalLogHandoffTextPdfRenderer
    implements PersonalLogHandoffRenderer {
  const SystemPersonalLogHandoffTextPdfRenderer({this.fontLoader});

  final HandoffPdfFontLoader? fontLoader;

  static Future<List<ByteData>> loadBundledFonts() async => [
    await rootBundle.load('assets/fonts/Geist-Regular.ttf'),
    await rootBundle.load('assets/fonts/ParkinSUMReportSC-Regular.ttf'),
    await rootBundle.load('assets/fonts/ParkinSUMReportArabic-Regular.ttf'),
  ];

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required PersonalLogHandoffArtifact artifact,
  }) async {
    late List<ByteData> bytes;
    try {
      bytes = await (fontLoader ?? loadBundledFonts)();
    } catch (_) {
      throw const FormatException('handoff_pdf_font_unavailable');
    }
    if (!context.mounted) {
      throw const FormatException('handoff_pdf_context_disposed');
    }
    if (bytes.length != 3 || bytes.any((data) => data.lengthInBytes == 0)) {
      throw const FormatException('handoff_pdf_font_unavailable');
    }
    late List<TtfParser> parsers;
    try {
      parsers = bytes.map(TtfParser.new).toList(growable: false);
    } catch (_) {
      throw const FormatException('handoff_pdf_font_unavailable');
    }
    if (artifact.pages.isEmpty ||
        artifact.pages.length > personalLogHandoffMaxPages ||
        artifact.pages.any(
          (page) =>
              page.lines.length > 38 ||
              page.lines.any((line) => line.runes.length > 50),
        )) {
      throw const FormatException('handoff_pdf_text_page_budget_exceeded');
    }
    for (final rune
        in artifact.pages
            .expand((page) => page.lines)
            .expand((line) => line.runes)) {
      if (rune == 0x20 || rune == 0x09 || rune == 0x0a || rune == 0x0d) {
        continue;
      }
      if (!parsers.any(
        (parser) => (parser.charToGlyphIndexMap[rune] ?? 0) != 0,
      )) {
        throw const FormatException('handoff_pdf_glyph_unavailable');
      }
    }
    final fonts = bytes.map(pw.Font.ttf).toList(growable: false);
    final document = pw.Document(
      title: 'ParkinSUM personal log handoff',
      author: 'ParkinSUM Companion',
      subject: 'Owner-entered records; not clinically verified',
      creator: 'ParkinSUM Companion',
      producer: 'ParkinSUM Companion searchable text via package:pdf',
      compress: true,
    );
    for (final page in artifact.pages) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 28),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              for (final line in page.lines)
                pw.SizedBox(height: 18, child: _line(line, fonts)),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey),
              pw.Text(
                'ParkinSUM · ${page.number}/${artifact.pages.length}',
                style: pw.TextStyle(font: fonts.first, fontSize: 8),
              ),
            ],
          ),
        ),
      );
    }
    final result = await document.save();
    if (!context.mounted) {
      throw const FormatException('handoff_pdf_context_disposed');
    }
    if (result.isEmpty || result.length > personalLogHandoffMaxPdfBytes) {
      throw const FormatException('handoff_pdf_byte_budget_exceeded');
    }
    // Font objects and report bytes are local to this render; no report cache.
    return result;
  }

  pw.Widget _line(String raw, List<pw.Font> fonts) {
    final title = raw.startsWith('# ') || raw.startsWith('## ');
    final warning = raw.startsWith('! ');
    final text = raw.replaceFirst(RegExp(r'^(?:##? |! )'), '');
    final arabic = text.runes.any(
      (rune) =>
          (rune >= 0x0600 && rune <= 0x08ff) ||
          (rune >= 0xfb50 && rune <= 0xfdff) ||
          (rune >= 0xfe70 && rune <= 0xfeff),
    );
    final rtl = _firstStrongIsRtl(text);
    final primary = arabic ? fonts[2] : fonts.first;
    final style = pw.TextStyle(
      font: primary,
      fontFallback: fonts.where((font) => !identical(font, primary)).toList(),
      fontSize: 9.8,
      color: warning
          ? PdfColors.deepOrange900
          : title
          ? PdfColors.blueGrey900
          : PdfColors.black,
    );
    pw.Widget run(String value, {required bool rightToLeft}) => pw.Text(
      value,
      textDirection: rightToLeft ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: rightToLeft ? pw.TextAlign.right : pw.TextAlign.left,
      softWrap: false,
      style: style,
    );
    // The PDF package shapes Arabic only in RTL text. Keep mixed-script runs
    // separate so an LTR prefix cannot reverse an unshaped Arabic suffix.
    final arabicRuns = RegExp(
      r'[\u0600-\u08ff\uFB50-\uFDFF\uFE70-\uFEFF]+(?:[ \t]+[\u0600-\u08ff\uFB50-\uFDFF\uFE70-\uFEFF]+)*',
    ).allMatches(text).toList(growable: false);
    if (!arabic ||
        (arabicRuns.length == 1 && arabicRuns.single.group(0) == text)) {
      return run(text, rightToLeft: rtl);
    }
    final children = <pw.Widget>[];
    var offset = 0;
    for (final match in arabicRuns) {
      if (match.start > offset) {
        children.add(
          run(text.substring(offset, match.start), rightToLeft: false),
        );
      }
      children.add(run(match.group(0)!, rightToLeft: true));
      offset = match.end;
    }
    if (offset < text.length) {
      children.add(run(text.substring(offset), rightToLeft: false));
    }
    return pw.Row(
      mainAxisAlignment: rtl
          ? pw.MainAxisAlignment.end
          : pw.MainAxisAlignment.start,
      children: rtl ? children.reversed.toList(growable: false) : children,
    );
  }

  bool _firstStrongIsRtl(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0590 && rune <= 0x08ff) ||
          (rune >= 0xfb1d && rune <= 0xfdff) ||
          (rune >= 0xfe70 && rune <= 0xfeff)) {
        return true;
      }
      if ((rune >= 0x41 && rune <= 0x5a) ||
          (rune >= 0x61 && rune <= 0x7a) ||
          (rune >= 0x3400 && rune <= 0x9fff)) {
        return false;
      }
    }
    return false;
  }
}
