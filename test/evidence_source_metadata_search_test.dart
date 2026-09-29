import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_source_metadata_search.dart';
import 'package:parkinsum_companion/features/diagnostics/evidence_source_metadata_search_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  group('EvidenceSourceMetadataSearch', () {
    test('title evidence ranks ahead of lower-weight metadata matches', () {
      final search = EvidenceSourceMetadataSearch(
        sources: [
          _source(id: 'title-match', title: 'Protein meal timing reference'),
          _source(
            id: 'license-match',
            title: 'Nutrition source overview',
            licenseNote: 'Metadata about protein meal timing',
          ),
          _source(id: 'unrelated', title: 'Catalog update record'),
        ],
      );

      final results = search.search('protein timing');

      expect(results.map((hit) => hit.source.sourceDocId), [
        'title-match',
        'license-match',
      ]);
      expect(results.first.matchedTerms, ['protein', 'timing']);
    });

    test('raw payload, URL, checksum, and record identity are not indexed', () {
      final search = EvidenceSourceMetadataSearch(
        sources: [
          _source(
            id: 'secret-term',
            title: 'Synthetic public source record',
            payload: 'moonbeam payload phrase',
            url: 'https://example.org/moonbeam',
            checksum: 'moonbeam-checksum',
          ),
        ],
      );

      expect(search.search('moonbeam'), isEmpty);
      expect(search.search('synthetic'), hasLength(1));
    });

    test('diacritic folding and ID tie-break remain deterministic', () {
      EvidenceSourceMetadataSearch build(Iterable<SourceDocumentRecord> rows) =>
          EvidenceSourceMetadataSearch(sources: rows);

      final first = _source(id: 'z-source', title: 'Café nutrition source');
      final second = _source(id: 'a-source', title: 'Cafe nutrition source');
      final forward = build([first, second]).search('café');
      final reversed = build([second, first]).search('cafe');

      expect(forward.map((hit) => hit.source.sourceDocId), [
        'a-source',
        'z-source',
      ]);
      expect(
        reversed.map((hit) => hit.source.sourceDocId),
        forward.map((hit) => hit.source.sourceDocId),
      );
    });

    test('empty query is empty and query/result bounds are enforced', () {
      final search = EvidenceSourceMetadataSearch(
        sources: [_source(id: 'one', title: 'One synthetic source')],
      );

      expect(search.search('  '), isEmpty);
      expect(
        () => search.search(List.filled(161, 'x').join()),
        throwsArgumentError,
      );
      expect(
        () =>
            search.search(List.generate(17, (index) => 'term$index').join(' ')),
        throwsArgumentError,
      );
      expect(() => search.search('one', limit: 21), throwsArgumentError);
      expect(
        () => EvidenceSourceMetadataSearch(
          sources: [
            _source(id: 'duplicate', title: 'One'),
            _source(id: 'duplicate', title: 'Two'),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  testWidgets('page searches metadata locally and distinguishes no match', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      EvidenceSourceMetadataSearchPage(
        localeTag: 'en-US',
        sources: [
          _source(
            id: 'synthetic-governance-source',
            title: 'Synthetic governance evidence note',
            payload: 'hidden payload phrase moonbeam',
          ),
        ],
      ),
      surfaceSize: const Size(1800, 3600),
    );
    expectNoWidgetErrors(reason: 'evidence source search failed to build');
    expect(
      find.byKey(const Key('evidence-source-search-input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('evidence-source-search-input')),
      'governance',
    );
    await tester.pumpAndSettle();
    expect(find.text('1. Synthetic governance evidence note'), findsOneWidget);
    expect(
      find.byKey(
        const Key('evidence-source-hit-id-synthetic-governance-source'),
      ),
      findsOneWidget,
    );
    expect(find.text('governance'), findsWidgets);
    expect(
      find.text('No claim-status record is linked to this exact source ID.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('evidence-source-search-input')),
      'moonbeam',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('evidence-source-search-no-match')),
      findsOneWidget,
    );
    expect(
      find.text(
        'No metadata match. This does not show that a source or evidence is absent.',
      ),
      findsOneWidget,
    );
    expect(find.text('1. Synthetic governance evidence note'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('evidence-source-search-input')),
      List.generate(17, (index) => 'term$index').join(' '),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('evidence-source-search-query-limit')),
      findsOneWidget,
    );
    expectNoWidgetErrors(reason: 'overlong query should be bounded in the UI');
  });

  testWidgets(
    'page shows exact linked claim status separately from search ordering',
    (tester) async {
      await pumpFeaturePage(
        tester,
        EvidenceSourceMetadataSearchPage(
          localeTag: 'en-US',
          sources: [
            _source(
              id: 'src.nutt.onoff.1984',
              title: 'Nutt 1984 synthetic source title',
            ),
          ],
          asOfUtc: DateTime.parse('2026-09-27T12:00:00Z'),
          currencyRegistry: EvidenceCurrencyRegistry.current,
        ),
        surfaceSize: const Size(1800, 3600),
      );

      await tester.enterText(
        find.byKey(const Key('evidence-source-search-input')),
        'nutt',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key(
            'evidence-source-currency-status-src.nutt.onoff.1984-'
            'claim.meal_delay_direction.nutt_1984',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Current (recorded)'), findsOneWidget);
      expect(find.textContaining('pubmed-record-6694694'), findsOneWidget);
      expect(find.textContaining('not a live lookup'), findsOneWidget);
      expectNoWidgetErrors(reason: 'currency status projection should render');
    },
  );
}

SourceDocumentRecord _source({
  required String id,
  required String title,
  String organization = 'Synthetic organization',
  String sourceFamily = 'SYNTHETIC',
  String docType = 'reference',
  String jurisdiction = 'ZZ',
  String language = 'en',
  String licenseNote = 'Synthetic fixture metadata only',
  String payload = '',
  String url = 'https://example.org/source',
  String checksum = 'synthetic-checksum',
}) => SourceDocumentRecord(
  sourceDocId: id,
  sourceFamily: sourceFamily,
  dataTier: KnowledgeDataTier.p4,
  organization: organization,
  jurisdiction: jurisdiction,
  docType: docType,
  title: title,
  originUrl: url,
  publishedAt: null,
  effectiveAt: null,
  language: language,
  licenseNote: licenseNote,
  checksum: checksum,
  sourceStatus: 'synthetic',
  rawPayload: payload,
);
