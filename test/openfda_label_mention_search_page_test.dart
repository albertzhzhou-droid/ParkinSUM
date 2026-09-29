import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/openfda_label_mention_search.dart';
import 'package:parkinsum_companion/data/datasources/remote/rxnorm_name_candidate_search.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/openfda_label_mention_search_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('external label queries require fresh explicit consent', (
    tester,
  ) async {
    final fetcher = _RecordingLabelFetchClient();
    MethodCall? clipboardCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardCall = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final lookup = OpenFdaLabelMentionSearch(fetchClient: fetcher);
    await pumpFeaturePage(
      tester,
      OpenFdaLabelMentionSearchPage(localeTag: 'en', lookup: lookup),
      surfaceSize: const Size(1290, 6900),
    );

    expect(find.textContaining('unvalidated'), findsOneWidget);
    expect(find.textContaining('network address'), findsNWidgets(2));
    expect(find.textContaining('saved medication'), findsNWidgets(2));
    expect(fetcher.requests, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-first-name')),
      'Alpha Compound',
    );
    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-second-name')),
      'Beta Compound',
    );
    final searchButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('openfda-label-search')),
    );
    expect(searchButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('openfda-label-external-query-consent')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('openfda-label-search')));
    await tester.pumpAndSettle();

    expect(fetcher.requests, hasLength(2));
    await tester.scrollUntilVisible(
      find.textContaining('literal text “Beta Compound”'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('literal text “Beta Compound”'), findsOneWidget);
    expect(
      find.textContaining('This does not prove that no interaction exists.'),
      findsOneWidget,
    );
    expect(find.textContaining('clinical conclusion'), findsOneWidget);
    expect(
      find.textContaining('Literal text match in: drug_interactions'),
      findsOneWidget,
    );
    expect(find.text('contraindications'), findsOneWidget);
    expect(find.text('boxed_warning'), findsOneWidget);
    expect(find.text('warnings_and_cautions'), findsOneWidget);
    final copyDailyMed = find.byKey(
      const ValueKey(
        'copy-dailymed-reference-550e8400-e29b-41d4-a716-446655440000',
      ),
    );
    expect(copyDailyMed, findsOneWidget);
    expect(
      find.textContaining(
        'https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=550e8400-e29b-41d4-a716-446655440000&version=2',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(copyDailyMed);
    await tester.tap(copyDailyMed);
    await tester.pumpAndSettle();
    expect(
      fetcher.requests,
      hasLength(2),
      reason: 'copying a DailyMed reference is offline',
    );
    expect(clipboardCall?.method, 'Clipboard.setData');
    expect(
      (clipboardCall?.arguments as Map<Object?, Object?>?)?['text'],
      'https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=550e8400-e29b-41d4-a716-446655440000&version=2',
    );
    final consentTile = find.byKey(
      const ValueKey('openfda-label-external-query-consent'),
    );
    await tester.scrollUntilVisible(
      consentTile,
      -240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(consentTile).value,
      isFalse,
      reason: 'each pair lookup requires fresh confirmation',
    );
    expectNoWidgetErrors();
  });

  testWidgets('editing either name clears consent and previous results', (
    tester,
  ) async {
    final fetcher = _RecordingLabelFetchClient();
    await pumpFeaturePage(
      tester,
      OpenFdaLabelMentionSearchPage(
        localeTag: 'zh-CN',
        lookup: OpenFdaLabelMentionSearch(fetchClient: fetcher),
      ),
      surfaceSize: const Size(1290, 4500),
    );

    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-first-name')),
      'Alpha Compound',
    );
    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-second-name')),
      'Beta Compound',
    );
    await tester.tap(
      find.byKey(const ValueKey('openfda-label-external-query-consent')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('openfda-label-external-query-consent')),
          )
          .value,
      isTrue,
    );
    expect(fetcher.requests, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-second-name')),
      'Gamma Compound',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('openfda-label-external-query-consent')),
          )
          .value,
      isFalse,
    );
    expect(fetcher.requests, isEmpty);
  });

  testWidgets('RxNorm lookup has separate consent and never triggers FDA', (
    tester,
  ) async {
    final fdaFetcher = _RecordingLabelFetchClient();
    final rxNormFetcher = _RecordingRxNormNameFetchClient();
    await pumpFeaturePage(
      tester,
      OpenFdaLabelMentionSearchPage(
        localeTag: 'en',
        lookup: OpenFdaLabelMentionSearch(fetchClient: fdaFetcher),
        rxNormLookup: RxNormNameCandidateSearch(fetchClient: rxNormFetcher),
      ),
      surfaceSize: const Size(1290, 5600),
    );

    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-first-name')),
      'Alpha Compound',
    );
    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-second-name')),
      'Beta Compound',
    );
    expect(find.textContaining('not responsible for'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('rxnorm-name-candidate-search')),
          )
          .onPressed,
      isNull,
    );
    expect(fdaFetcher.requests, isEmpty);
    expect(rxNormFetcher.requests, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('rxnorm-name-candidate-consent')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rxnorm-name-candidate-search')),
    );
    await tester.pumpAndSettle();

    expect(rxNormFetcher.requests, hasLength(2));
    expect(fdaFetcher.requests, isEmpty);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('openfda-label-first-name')),
          )
          .controller!
          .text,
      'Alpha Compound',
      reason: 'candidate discovery does not replace the typed term',
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('openfda-label-external-query-consent')),
          )
          .value,
      isFalse,
      reason: 'RxNorm consent does not grant FDA consent',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('openfda-label-search')),
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('alpha 10 MG [Alpha]'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha 10 MG [Alpha]'), findsOneWidget);
    expect(find.text('alpha 10 MG [Alpha package]'), findsOneWidget);
    expect(find.text('RxCUI: 111'), findsOneWidget);
    expect(find.text('RxCUI: 222'), findsOneWidget);
    expect(
      find.text('RxNav lexical rank: 1 (search ordering only)'),
      findsNWidgets(3),
    );
    expect(find.textContaining('12.7'), findsNothing);
    expectNoWidgetErrors();
  });

  testWidgets('editing a term clears RxNorm consent and displayed candidates', (
    tester,
  ) async {
    final rxNormFetcher = _RecordingRxNormNameFetchClient();
    await pumpFeaturePage(
      tester,
      OpenFdaLabelMentionSearchPage(
        localeTag: 'zh-CN',
        rxNormLookup: RxNormNameCandidateSearch(
          fetchClient: rxNormFetcher,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        ),
      ),
      surfaceSize: const Size(1290, 5600),
    );

    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-first-name')),
      'Alpha Compound',
    );
    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-second-name')),
      'Beta Compound',
    );
    await tester.tap(
      find.byKey(const ValueKey('rxnorm-name-candidate-consent')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('rxnorm-name-candidate-search')),
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha 10 MG [Alpha]'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('openfda-label-first-name')),
      'Gamma Compound',
    );
    await tester.pumpAndSettle();
    expect(find.text('alpha 10 MG [Alpha]'), findsNothing);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('rxnorm-name-candidate-consent')),
          )
          .value,
      isFalse,
    );
    expectNoWidgetErrors();
  });

  testWidgets(
    'RxNorm concept properties need separate consent and send only the selected RxCUI',
    (tester) async {
      final fdaFetcher = _RecordingLabelFetchClient();
      final rxNormFetcher = _RecordingRxNormNameFetchClient();
      await pumpFeaturePage(
        tester,
        OpenFdaLabelMentionSearchPage(
          localeTag: 'en',
          lookup: OpenFdaLabelMentionSearch(fetchClient: fdaFetcher),
          rxNormLookup: RxNormNameCandidateSearch(fetchClient: rxNormFetcher),
        ),
        surfaceSize: const Size(1290, 6200),
      );
      final firstNameController = tester
          .widget<TextField>(
            find.byKey(const ValueKey('openfda-label-first-name')),
          )
          .controller!;

      await tester.enterText(
        find.byKey(const ValueKey('openfda-label-first-name')),
        'Alpha Compound',
      );
      await tester.enterText(
        find.byKey(const ValueKey('openfda-label-second-name')),
        'Beta Compound',
      );
      await tester.tap(
        find.byKey(const ValueKey('rxnorm-name-candidate-consent')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rxnorm-name-candidate-search')),
      );
      await tester.pumpAndSettle();

      final detailConsent = find.byKey(
        const ValueKey('rxnorm-concept-properties-consent'),
      );
      final inspectButton = find.byKey(const ValueKey('rxnorm-properties-111'));
      expect(rxNormFetcher.requests, hasLength(2));
      await tester.scrollUntilVisible(
        detailConsent,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(detailConsent);
      await tester.pumpAndSettle();
      await tester.tap(detailConsent);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        inspectButton,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(inspectButton);
      await tester.pumpAndSettle();

      expect(rxNormFetcher.requests, hasLength(3));
      final propertiesRequest = rxNormFetcher.requests.last;
      expect(propertiesRequest.path, '/REST/rxcui/111/properties.json');
      expect(propertiesRequest.queryParameters, isEmpty);
      expect(fdaFetcher.requests, isEmpty);
      expect(find.text('TTY: SCD'), findsOneWidget);
      expect(
        find.text('NLM concept name: alpha 10 MG [Alpha]'),
        findsOneWidget,
      );
      final secondCandidateDetail = find.byKey(
        const ValueKey('rxnorm-properties-222'),
      );
      await tester.scrollUntilVisible(
        secondCandidateDetail,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(secondCandidateDetail).onPressed,
        isNull,
        reason: 'the detail consent expires after one selected concept',
      );

      firstNameController.text = 'Gamma Compound';
      await tester.pumpAndSettle();
      expect(find.text('TTY: SCD'), findsNothing);
      expect(find.text('NLM concept name: alpha 10 MG [Alpha]'), findsNothing);
      expectNoWidgetErrors();
    },
  );

  testWidgets(
    'RxNorm history status needs separate consent and never applies replacements',
    (tester) async {
      final fdaFetcher = _RecordingLabelFetchClient();
      final rxNormFetcher = _RecordingRxNormNameFetchClient();
      await pumpFeaturePage(
        tester,
        OpenFdaLabelMentionSearchPage(
          localeTag: 'en',
          lookup: OpenFdaLabelMentionSearch(fetchClient: fdaFetcher),
          rxNormLookup: RxNormNameCandidateSearch(fetchClient: rxNormFetcher),
        ),
        surfaceSize: const Size(1290, 6200),
      );
      await tester.enterText(
        find.byKey(const ValueKey('openfda-label-first-name')),
        'Alpha Compound',
      );
      await tester.enterText(
        find.byKey(const ValueKey('openfda-label-second-name')),
        'Beta Compound',
      );
      await tester.tap(
        find.byKey(const ValueKey('rxnorm-name-candidate-consent')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rxnorm-name-candidate-search')),
      );
      await tester.pumpAndSettle();

      final consent = find.byKey(
        const ValueKey('rxnorm-history-status-consent'),
      );
      final historyButton = find.byKey(const ValueKey('rxnorm-history-111'));
      expect(rxNormFetcher.requests, hasLength(2));
      await tester.scrollUntilVisible(
        consent,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(consent);
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(historyButton).onPressed, isNull);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        historyButton,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(historyButton);
      await tester.pumpAndSettle();

      expect(rxNormFetcher.requests, hasLength(3));
      expect(
        rxNormFetcher.requests.last.path,
        '/REST/rxcui/111/historystatus.json',
      );
      expect(rxNormFetcher.requests.last.queryParameters, isEmpty);
      expect(fdaFetcher.requests, isEmpty);
      expect(find.text('RxNorm status: Remapped'), findsOneWidget);
      expect(find.text('RxCUI 849389 · TTY SCD · Active YES'), findsOneWidget);
      expect(find.text('RxCUI 849394 · TTY SBD · Active NO'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('rxnorm-history-222')),
            )
            .onPressed,
        isNull,
        reason: 'history consent expires after one candidate request',
      );
      expectNoWidgetErrors();
    },
  );

  testWidgets(
    'selected RxNorm names reach FDA only after selection and separate consent',
    (tester) async {
      final manuallyEnteredFdaFetcher = _RecordingLabelFetchClient();
      final selectedCandidateFdaFetcher = _RecordingLabelFetchClient();
      final rxNormFetcher = _RecordingRxNormNameFetchClient(
        useSimpleCandidateNames: true,
      );
      await pumpFeaturePage(
        tester,
        OpenFdaLabelMentionSearchPage(
          localeTag: 'en',
          lookup: OpenFdaLabelMentionSearch(
            fetchClient: manuallyEnteredFdaFetcher,
          ),
          rxNormLookup: RxNormNameCandidateSearch(fetchClient: rxNormFetcher),
          rxNormCandidateLookup:
              OpenFdaLabelMentionSearch.forSelectedRxNormCandidates(
                fetchClient: selectedCandidateFdaFetcher,
              ),
        ),
        surfaceSize: const Size(1290, 7600),
      );

      await tester.enterText(
        find.byKey(const ValueKey('openfda-label-first-name')),
        'Alpha Compound',
      );
      final firstNameController = tester
          .widget<TextField>(
            find.byKey(const ValueKey('openfda-label-first-name')),
          )
          .controller!;
      await tester.enterText(
        find.byKey(const ValueKey('openfda-label-second-name')),
        'Beta Compound',
      );
      await tester.tap(
        find.byKey(const ValueKey('rxnorm-name-candidate-consent')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('rxnorm-name-candidate-search')),
      );
      await tester.pumpAndSettle();

      expect(selectedCandidateFdaFetcher.requests, isEmpty);
      final firstCandidate = find.byKey(
        const ValueKey('rxnorm-candidate-select-first-211'),
      );
      await tester.scrollUntilVisible(
        firstCandidate,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstCandidate);

      final secondCandidate = find.byKey(
        const ValueKey('rxnorm-candidate-select-second-214'),
      );
      await tester.scrollUntilVisible(
        secondCandidate,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(secondCandidate);

      final candidateConsent = find.byKey(
        const ValueKey('rxnorm-candidate-openfda-consent'),
      );
      final candidateSearch = find.byKey(
        const ValueKey('rxnorm-candidate-openfda-search'),
      );
      await tester.scrollUntilVisible(
        candidateConsent,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(candidateConsent).value, isFalse);
      expect(tester.widget<FilledButton>(candidateSearch).onPressed, isNull);
      expect(selectedCandidateFdaFetcher.requests, isEmpty);
      expect(manuallyEnteredFdaFetcher.requests, isEmpty);

      await tester.tap(candidateConsent);
      await tester.pumpAndSettle();
      await tester.tap(candidateSearch);
      await tester.pumpAndSettle();

      expect(selectedCandidateFdaFetcher.requests, hasLength(2));
      expect(
        selectedCandidateFdaFetcher.requests
            .map((uri) => uri.queryParameters['search'])
            .toSet(),
        {
          'openfda.generic_name:"Alpha Synonym"',
          'openfda.generic_name:"Beta Synonym"',
        },
      );
      expect(
        selectedCandidateFdaFetcher.requests.every(
          (uri) =>
              uri.path == '/drug/label.json' &&
              uri.queryParameters.keys.toSet().containsAll({'search', 'limit'}),
        ),
        isTrue,
      );
      expect(manuallyEnteredFdaFetcher.requests, isEmpty);
      expect(
        tester.widget<CheckboxListTile>(candidateConsent).value,
        isFalse,
        reason: 'candidate-name FDA consent expires after one lookup',
      );
      expect(firstNameController.text, 'Alpha Compound');
      expectNoWidgetErrors();
    },
  );

  testWidgets('workbench is reachable from engineering diagnostics', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const EngineeringDiagnosticsPage(),
      surfaceSize: const Size(1290, 18000),
    );
    await tester.pump();

    final entry = find.byKey(const Key('open-openfda-label-mention-search'));
    await tester.scrollUntilVisible(
      entry,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(OpenFdaLabelMentionSearchPage), findsOneWidget);
    expect(find.text('FDA drug-label text search'), findsOneWidget);
    expect(find.textContaining('public U.S. FDA API'), findsOneWidget);
    expectNoWidgetErrors();
  });
}

class _RecordingLabelFetchClient extends FakeSourceFetchClient {
  _RecordingLabelFetchClient() : super(textByUrl: const {});

  final requests = <Uri>[];

  @override
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(url);
    requests.add(uri);
    final match = RegExp(
      r'"([^"]+)"',
    ).firstMatch(uri.queryParameters['search'] ?? '');
    final name = match?.group(1) ?? '';
    return jsonDecode(
          jsonEncode({
            'meta': {
              'last_updated': '2026-09-11',
              'results': {'total': 1},
            },
            'results': [
              {
                'id': 'synthetic-id',
                'set_id': name.toLowerCase().contains('alpha')
                    ? '550e8400-e29b-41d4-a716-446655440000'
                    : '550e8400-e29b-41d4-a716-446655440001',
                'version': 2,
                'effective_time': '20260901',
                'openfda': {
                  'generic_name': [name],
                },
                'drug_interactions': [
                  name.toLowerCase().contains('alpha')
                      ? 'Beta Compound is present as a synthetic label phrase.'
                      : 'No matching term appears in this synthetic section.',
                ],
                if (name.toLowerCase().contains('alpha')) ...{
                  'contraindications': [
                    'Beta Compound is also in a synthetic contraindication field.',
                  ],
                  'boxed_warning': [
                    'Synthetic boxed warning without a pairwise conclusion.',
                  ],
                  'warnings_and_cautions': [
                    'Synthetic warning field for Beta Compound.',
                  ],
                },
              },
            ],
          }),
        )
        as Map<String, dynamic>;
  }
}

class _RecordingRxNormNameFetchClient extends FakeSourceFetchClient {
  _RecordingRxNormNameFetchClient({this.useSimpleCandidateNames = false})
    : super(textByUrl: const {});

  final bool useSimpleCandidateNames;

  final requests = <Uri>[];

  @override
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(url);
    requests.add(uri);
    if (uri.path.endsWith('/historystatus.json')) {
      final rxCui = uri.pathSegments[2];
      return {
        'rxcuiStatusHistory': {
          'metaData': {
            'status': 'Remapped',
            'source': 'RXNORM',
            'releaseStartDate': '042005',
            'remappedDate': '062009',
          },
          'attributes': {
            'rxcui': rxCui,
            'name': 'old concept $rxCui',
            'tty': 'SBD',
          },
          'derivedConcepts': {
            'remappedConcept': [
              {
                'remappedRxCui': '849389',
                'remappedName': 'alpha product',
                'remappedTTY': 'SCD',
                'remappedActive': 'YES',
              },
              {
                'remappedRxCui': '849394',
                'remappedName': 'alpha product [Brand]',
                'remappedTTY': 'SBD',
                'remappedActive': 'NO',
              },
            ],
          },
        },
      };
    }
    if (uri.path.endsWith('/properties.json')) {
      final rxCui = uri.pathSegments[2];
      return {
        'properties': {
          'rxcui': rxCui,
          'name': rxCui == '111' ? 'alpha 10 MG [Alpha]' : 'concept $rxCui',
          'tty': 'SCD',
          'synonym': 'Alpha',
          'language': 'ENG',
          'suppress': 'N',
        },
      };
    }
    final term = uri.queryParameters['term'] ?? '';
    return {
      'approximateGroup': {
        'candidate': term.startsWith('Alpha')
            ? [
                {
                  'rxcui': '111',
                  'rxaui': '211',
                  'score': '12.7',
                  'rank': '1',
                  'name': useSimpleCandidateNames
                      ? 'Alpha Synonym'
                      : 'alpha 10 MG [Alpha]',
                  'source': 'RXNORM',
                },
                {
                  'rxcui': '222',
                  'rxaui': '212',
                  'score': '12.7',
                  'rank': '1',
                  'name': useSimpleCandidateNames
                      ? 'Alpha Alternate'
                      : 'alpha 10 MG [Alpha package]',
                  'source': 'RXNORM',
                },
                {'rxcui': '111', 'rxaui': '213', 'rank': '1', 'source': 'GS'},
              ]
            : [
                {
                  'rxcui': '333',
                  'rxaui': '214',
                  'rank': '1',
                  'name': useSimpleCandidateNames
                      ? 'Beta Synonym'
                      : 'Beta ingredient 5 MG',
                  'source': 'RXNORM',
                },
              ],
      },
    };
  }
}
