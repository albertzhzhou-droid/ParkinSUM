import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_document_service.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_text_pdf_renderer.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';

PersonalLogHandoffArtifact _artifact(
  List<List<String>> pages,
  String language, {
  String id = 'synthetic',
}) => PersonalLogHandoffArtifact(
  artifactId: id,
  ownerBindingSha256:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  sourceRevisionSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  contentSha256:
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  fileName: 'parkinsum-personal-log-$id.pdf',
  plainText: pages.expand((page) => page).join('\n'),
  documentBlocks: pages
      .expand((page) => page)
      .map((line) => PersonalLogHandoffParagraphBlock(text: line))
      .toList(),
  pages: [
    for (var i = 0; i < pages.length; i++)
      PersonalLogHandoffDocumentPage(number: i + 1, lines: pages[i]),
  ],
  recordCounts: const {},
  unsupportedFields: const [],
  semanticDocument: {
    'document': {'language': language, 'direction': 'auto'},
  },
);

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext current;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          current = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return current;
}

void main() {
  final expectations =
      jsonDecode(
            File(
              'test/fixtures/handoff_text_pdf_expectations.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final raw in expectations['cases'] as List) {
    final fixture = raw as Map<String, dynamic>;
    final id = fixture['id'] as String;
    testWidgets(
      'bundled fonts create real text PDF for independent $id pages',
      (tester) async {
        final context = await _context(tester);
        final pages = (fixture['pages'] as List)
            .map((page) => (page as List).cast<String>())
            .toList();
        final artifact = _artifact(
          pages,
          fixture['language'] as String,
          id: id,
        );
        final bytes = await tester.runAsync(
          () => const SystemPersonalLogHandoffTextPdfRenderer().render(
            context: context,
            artifact: artifact,
          ),
        );
        expect(bytes, isNotNull);
        expect(ascii.decode(bytes!.take(5).toList()), '%PDF-');
        expect(latin1.decode(bytes), contains('/ToUnicode'));
        final outputDirectory =
            Platform.environment['PARKINSUM_TEXT_PDF_ARTIFACT_DIR'];
        if (outputDirectory != null) {
          Directory(outputDirectory).createSync(recursive: true);
          final output = File('$outputDirectory/$id.pdf');
          if (output.existsSync()) {
            throw StateError('Retain earlier PDF execution');
          }
          output.writeAsBytesSync(bytes);
        }
      },
    );
  }

  testWidgets('unavailable font data fails before document delivery', (
    tester,
  ) async {
    final context = await _context(tester);
    await expectLater(
      SystemPersonalLogHandoffTextPdfRenderer(
        fontLoader: () async => [],
      ).render(
        context: context,
        artifact: _artifact([
          ['Synthetic record'],
        ], 'en'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'code',
          'handoff_pdf_font_unavailable',
        ),
      ),
    );
  });

  testWidgets('uncovered glyphs fail instead of silently exporting tofu', (
    tester,
  ) async {
    final context = await _context(tester);
    await tester.runAsync(
      () => expectLater(
        const SystemPersonalLogHandoffTextPdfRenderer().render(
          context: context,
          artifact: _artifact([
            ['Uncovered glyph 🧬'],
          ], 'en'),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'code',
            'handoff_pdf_glyph_unavailable',
          ),
        ),
      ),
    );
  });

  for (final corrupt in [false, true]) {
    testWidgets(
      'font ${corrupt ? 'corruption' : 'load failure'} has a bounded failure code',
      (tester) async {
        final context = await _context(tester);
        await expectLater(
          SystemPersonalLogHandoffTextPdfRenderer(
            fontLoader: () async {
              if (!corrupt) {
                throw StateError('Synthetic unavailable local asset');
              }
              return List.generate(3, (_) => ByteData(2));
            },
          ).render(
            context: context,
            artifact: _artifact([
              ['Synthetic record'],
            ], 'en'),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'code',
              'handoff_pdf_font_unavailable',
            ),
          ),
        );
      },
    );
  }

  testWidgets('over-budget text pages fail instead of truncating content', (
    tester,
  ) async {
    final context = await _context(tester);
    await tester.runAsync(
      () => expectLater(
        const SystemPersonalLogHandoffTextPdfRenderer().render(
          context: context,
          artifact: _artifact([List.filled(39, 'Synthetic record')], 'en'),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'code',
            'handoff_pdf_text_page_budget_exceeded',
          ),
        ),
      ),
    );
  });

  testWidgets('disposed context rejects a delayed font load', (tester) async {
    final context = await _context(tester);
    final started = Completer<void>();
    final pendingFonts = Completer<List<ByteData>>();
    final renderer = SystemPersonalLogHandoffTextPdfRenderer(
      fontLoader: () {
        started.complete();
        return pendingFonts.future;
      },
    );
    final future = renderer.render(
      context: context,
      artifact: _artifact([
        ['Synthetic record'],
      ], 'en'),
    );
    final checked = expectLater(
      future,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'code',
          'handoff_pdf_context_disposed',
        ),
      ),
    );
    await started.future;
    await tester.pumpWidget(const SizedBox());
    pendingFonts.complete([]);
    await checked;
  });

  for (final metadata in [
    {'language': 'en" onload="alert(1)', 'direction': 'auto'},
    {'language': 'en', 'direction': 'rtl" onload="alert(1)'},
  ]) {
    test(
      'HTML rejects malformed language or direction before serialization',
      () {
        final base = _artifact([
          ['Synthetic record'],
        ], 'en');
        final artifact = PersonalLogHandoffArtifact(
          artifactId: base.artifactId,
          ownerBindingSha256: base.ownerBindingSha256,
          sourceRevisionSha256: base.sourceRevisionSha256,
          contentSha256: base.contentSha256,
          fileName: base.fileName,
          plainText: base.plainText,
          documentBlocks: base.documentBlocks,
          pages: base.pages,
          recordCounts: base.recordCounts,
          unsupportedFields: base.unsupportedFields,
          semanticDocument: {'document': metadata},
        );
        expect(
          () => const PersonalLogHandoffHtmlSerializer().render(artifact),
          throwsFormatException,
        );
      },
    );
  }
}
