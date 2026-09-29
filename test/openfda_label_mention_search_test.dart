import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/services/runtime_network_egress_policy.dart';
import 'package:parkinsum_companion/data/datasources/remote/openfda_label_mention_search.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/openfda_label_mention_search.dart';

void main() {
  group('OpenFDA label-text mention lookup', () {
    test(
      'searches each manually entered generic name with a bounded query',
      () async {
        final fetcher = _RecordingLabelFetchClient();
        final lookup = OpenFdaLabelMentionSearch(
          fetchClient: fetcher,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );

        final result = await lookup.searchPair(
          firstGenericName: ' Alpha   Compound ',
          secondGenericName: 'Beta Compound',
        );

        expect(fetcher.requests, hasLength(2));
        expect(fetcher.requests.map((uri) => uri.host).toSet(), {
          'api.fda.gov',
        });
        expect(fetcher.requests.map((uri) => uri.path).toSet(), {
          '/drug/label.json',
        });
        for (final uri in fetcher.requests) {
          expect(uri.queryParameters.keys.toSet(), {'search', 'limit'});
        }
        expect(
          fetcher.requests.every((uri) => uri.queryParameters['limit'] == '5'),
          isTrue,
        );
        expect(
          fetcher.requests.map((uri) => uri.queryParameters['search']).toSet(),
          {
            'openfda.generic_name:"Alpha Compound"',
            'openfda.generic_name:"Beta Compound"',
          },
        );
        expect(result.firstLabels.resultsAreSampled, isTrue);
        expect(
          result.firstLabels.recordsMentioning('Beta Compound'),
          hasLength(1),
        );
        expect(
          result.secondLabels.recordsMentioning('Alpha Compound'),
          isEmpty,
        );
        expect(
          result.firstLabels.records.single.setId,
          '550e8400-e29b-41d4-a716-446655440000',
        );
        expect(result.firstLabels.records.single.version, 3);
        expect(
          result.firstLabels.records.single.searchedLabelSections,
          hasLength(2),
        );
        expect(result.firstLabels.retrievedAt, DateTime.utc(2026, 9, 25, 12));
      },
    );

    test(
      'DailyMed reference binds a valid set ID to the exact positive version',
      () {
        OpenFdaLabelTextRecord record({String? setId, int? version}) =>
            OpenFdaLabelTextRecord(
              id: 'revision-id',
              setId: setId ?? '550e8400-e29b-41d4-a716-446655440000',
              version: version,
              effectiveTime: null,
              genericNames: const [],
              brandNames: const [],
              searchedLabelSections: const [],
            );

        final uri = record(version: 3).dailymedExactVersionUri!;
        expect(uri.scheme, 'https');
        expect(uri.host, 'dailymed.nlm.nih.gov');
        expect(uri.path, '/dailymed/drugInfo.cfm');
        expect(uri.queryParameters, {
          'setid': '550e8400-e29b-41d4-a716-446655440000',
          'version': '3',
        });
        expect(
          record(
            setId: 'https://example.invalid/label',
            version: 3,
          ).dailymedExactVersionUri,
          isNull,
        );
        expect(record(version: null).dailymedExactVersionUri, isNull);
        expect(record(version: 0).dailymedExactVersionUri, isNull);
      },
    );

    test(
      'searches selected label fields and preserves each source field identity',
      () async {
        final fetcher = _RecordingLabelFetchClient(
          payloadByName: {
            'alpha compound': _payload(
              total: 1,
              results: [
                _record(
                  genericName: 'Alpha Compound',
                  interactionText: 'No target name in this interaction field.',
                  contraindicationsText: 'Beta Compound in contraindications.',
                  contraindicationsTableText:
                      'Beta Compound in contraindications table.',
                  boxedWarningText: 'Beta Compound in boxed warning.',
                  boxedWarningTableText:
                      'Beta Compound in boxed warning table.',
                  warningsText: 'Beta Compound in warnings.',
                  warningsTableText: 'Beta Compound in warnings table.',
                  warningsAndCautionsText:
                      'Beta Compound in warnings and cautions.',
                  warningsAndCautionsTableText:
                      'Beta Compound in warnings and cautions table.',
                ),
              ],
            ),
          },
        );
        final lookup = OpenFdaLabelMentionSearch(fetchClient: fetcher);

        final result = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        final record = result.firstLabels.records.single;
        expect(
          record
              .searchedSectionsMentioning('Beta Compound')
              .map((section) => section.field),
          [
            'contraindications',
            'contraindications_table',
            'boxed_warning',
            'boxed_warning_table',
            'warnings',
            'warnings_table',
            'warnings_and_cautions',
            'warnings_and_cautions_table',
          ],
        );
        expect(record.searchedLabelSections.map((section) => section.field), [
          'drug_interactions',
          'drug_interactions_table',
          'contraindications',
          'contraindications_table',
          'boxed_warning',
          'boxed_warning_table',
          'warnings',
          'warnings_table',
          'warnings_and_cautions',
          'warnings_and_cautions_table',
        ]);
        expect(record.searchedLabelSections, hasLength(10));
        expect(result.firstLabels.recordsWithSearchedLabelText, 1);
        expect(result.firstLabelsMentioningSecond, hasLength(1));
        expect(
          result.firstLabelsMentioningSecond.single.searchedLabelSections,
          record.searchedLabelSections,
        );
      },
    );

    test(
      'live lookup applies the FDA-only policy without retaining URL metadata',
      () async {
        final requests = <Uri>[];
        final transport = MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode(_payload(total: 0, results: const [])),
            200,
            headers: const {'etag': 'synthetic-validator'},
          );
        });
        final lookup = OpenFdaLabelMentionSearch.live(client: transport);

        await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        expect(requests, hasLength(2));
        final fetchClient = lookup.fetchClient as HttpSourceFetchClient;
        expect(
          requests.every(
            (uri) => fetchClient.lastFetchMetadata(uri.toString()).isEmpty,
          ),
          isTrue,
          reason: 'response metadata must not retain query URLs for reuse',
        );
      },
    );

    test(
      'live selected-candidate lookup uses its dedicated egress policy',
      () async {
        final requests = <Uri>[];
        final transport = MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode(_payload(total: 0, results: const [])),
            200,
          );
        });
        final lookup =
            OpenFdaLabelMentionSearch.liveForSelectedRxNormCandidates(
              client: transport,
            );

        await lookup.searchSelectedRxNormCandidatePair(
          firstCandidateDisplayName: 'Alpha Compound',
          secondCandidateDisplayName: 'Beta Compound',
        );

        expect(requests, hasLength(2));
        final fetchClient = lookup.fetchClient as HttpSourceFetchClient;
        expect(
          requests.every(
            (uri) => fetchClient.lastFetchMetadata(uri.toString()).isEmpty,
          ),
          isTrue,
          reason: 'selected display names are not retained as URL metadata',
        );
      },
    );

    test(
      'selected RxNorm display names use a separate bounded FDA phrase lookup',
      () async {
        final fetcher = _RecordingLabelFetchClient();
        final lookup = OpenFdaLabelMentionSearch.forSelectedRxNormCandidates(
          fetchClient: fetcher,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );

        final result = await lookup.searchSelectedRxNormCandidatePair(
          firstCandidateDisplayName: '  Alpha   Compound ',
          secondCandidateDisplayName: 'Beta Compound',
        );

        expect(fetcher.requests, hasLength(2));
        expect(
          fetcher.requests.map((uri) => uri.queryParameters['search']).toSet(),
          {
            'openfda.generic_name:"Alpha Compound"',
            'openfda.generic_name:"Beta Compound"',
          },
        );
        expect(
          result.firstLabels.recordsMentioning('Beta Compound'),
          hasLength(1),
        );
        expect(
          OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(
            'alpha 10 MG [Alpha]',
          ),
          isFalse,
          reason: 'unsafe query punctuation is never enabled in the UI',
        );
        await expectLater(
          lookup.searchSelectedRxNormCandidatePair(
            firstCandidateDisplayName: 'alpha" OR drug_interactions:*',
            secondCandidateDisplayName: 'Beta Compound',
          ),
          throwsArgumentError,
        );
        await expectLater(
          OpenFdaLabelMentionSearch(
            fetchClient: fetcher,
          ).searchSelectedRxNormCandidatePair(
            firstCandidateDisplayName: 'Alpha Compound',
            secondCandidateDisplayName: 'Beta Compound',
          ),
          throwsStateError,
        );
        expect(fetcher.requests, hasLength(2));
      },
    );

    test(
      'matches selected label-section text, not label identity fields',
      () async {
        final fetcher = _RecordingLabelFetchClient(
          payloadByName: {
            'alpha compound': _payload(
              total: 2,
              results: [
                _record(
                  genericName: 'Alpha Compound',
                  interactionText:
                      'Review concomitant therapy with beta compound.',
                ),
                _record(
                  genericName: 'Beta Compound',
                  interactionText: 'Store at room temperature.',
                  brandName: 'Alpha Compound',
                ),
              ],
            ),
            'beta compound': _payload(
              total: 1,
              results: [
                _record(
                  genericName: 'Beta Compound',
                  interactionText: 'Store at room temperature.',
                  brandName: 'Alpha Compound',
                ),
              ],
            ),
          },
        );
        final lookup = OpenFdaLabelMentionSearch(fetchClient: fetcher);

        final result = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        expect(result.firstLabelsMentioningSecond, hasLength(1));
        expect(result.secondLabelsMentioningFirst, isEmpty);
      },
    );

    test(
      'empty records, missing sections, 404, and server failure stay distinct',
      () async {
        final fetcher =
            _RecordingLabelFetchClient(
                payloadByName: {
                  'alpha compound': _payload(total: 0, results: const []),
                  'beta compound': _payload(
                    total: 1,
                    results: [
                      {
                        'id': 'label-without-section',
                        'openfda': {
                          'generic_name': ['Beta Compound'],
                        },
                      },
                    ],
                  ),
                },
              )
              ..notFoundNames.add('gamma compound')
              ..failedStatusByName['delta compound'] = 503;
        final lookup = OpenFdaLabelMentionSearch(fetchClient: fetcher);

        final empty = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );
        expect(
          empty.firstLabels.state,
          OpenFdaLabelSearchState.noLabelsReturned,
        );
        expect(empty.secondLabels.recordsWithSearchedLabelText, 0);
        expect(empty.secondLabels.records, hasLength(1));

        final notFound = await lookup.searchPair(
          firstGenericName: 'Gamma Compound',
          secondGenericName: 'Beta Compound',
        );
        expect(
          notFound.firstLabels.state,
          OpenFdaLabelSearchState.noLabelsReturned,
        );
        expect(notFound.firstLabels.failureStatusCode, 404);

        final unavailable = await lookup.searchPair(
          firstGenericName: 'Delta Compound',
          secondGenericName: 'Beta Compound',
        );
        expect(
          unavailable.firstLabels.state,
          OpenFdaLabelSearchState.unavailable,
        );
        expect(unavailable.firstLabels.failureStatusCode, 503);
      },
    );

    test(
      'unsafe, oversized, and duplicate names are rejected before I/O',
      () async {
        final fetcher = _RecordingLabelFetchClient();
        final lookup = OpenFdaLabelMentionSearch(fetchClient: fetcher);

        await expectLater(
          lookup.searchPair(
            firstGenericName: 'alpha" AND drug_interactions:*',
            secondGenericName: 'Beta Compound',
          ),
          throwsArgumentError,
        );
        await expectLater(
          lookup.searchPair(
            firstGenericName: 'A' * 81,
            secondGenericName: 'Beta Compound',
          ),
          throwsArgumentError,
        );
        await expectLater(
          lookup.searchPair(
            firstGenericName: 'Alpha Compound',
            secondGenericName: ' alpha   compound ',
          ),
          throwsArgumentError,
        );
        expect(fetcher.requests, isEmpty);
      },
    );

    test(
      'HTTP status errors omit the query string and retain status only',
      () async {
        final sensitiveTerm = 'synthetic private term';
        final uri = Uri.https('api.fda.gov', '/drug/label.json', {
          'search': 'openfda.generic_name:"$sensitiveTerm"',
          'limit': '5',
        });
        final client = HttpSourceFetchClient(
          client: MockClient((request) async {
            expect(request.url.queryParameters.keys.toSet(), {
              'search',
              'limit',
            });
            expect(request.followRedirects, isFalse);
            return http.Response('{"error":{"code":"NOT_FOUND"}}', 404);
          }),
          egressPolicy:
              RuntimeNetworkEgressPolicy.userInitiatedOpenFdaLabelLookup,
          egressPurpose:
              RuntimeNetworkEgressPurpose.userInitiatedOpenFdaLabelLookup,
          egressDataClasses: const {
            RuntimeNetworkDataClass.userEnteredDrugName,
          },
        );

        await expectLater(
          client.getJsonMap(uri.toString()),
          throwsA(
            isA<SourceFetchHttpException>()
                .having((error) => error.statusCode, 'statusCode', 404)
                .having(
                  (error) => error.toString(),
                  'message',
                  contains('HTTP 404'),
                )
                .having(
                  (error) => error.toString(),
                  'message excludes query',
                  isNot(contains(sensitiveTerm)),
                ),
          ),
        );
      },
    );
  });
}

Map<String, dynamic> _payload({
  required int total,
  required List<Map<String, dynamic>> results,
}) => {
  'meta': {
    'last_updated': '2026-09-11',
    'results': {'total': total},
  },
  'results': results,
};

Map<String, dynamic> _record({
  required String genericName,
  required String interactionText,
  String? brandName,
  String? contraindicationsText,
  String? contraindicationsTableText,
  String? boxedWarningText,
  String? boxedWarningTableText,
  String? warningsText,
  String? warningsTableText,
  String? warningsAndCautionsText,
  String? warningsAndCautionsTableText,
}) => {
  'id': 'synthetic-label-record-id',
  'set_id': '550e8400-e29b-41d4-a716-446655440000',
  'version': '3',
  'effective_time': '20260901',
  'openfda': {
    'generic_name': [genericName],
    if (brandName != null) 'brand_name': [brandName],
  },
  'drug_interactions': [interactionText],
  'drug_interactions_table': ['A separate synthetic table row.'],
  if (contraindicationsText != null)
    'contraindications': [contraindicationsText],
  if (contraindicationsTableText != null)
    'contraindications_table': [contraindicationsTableText],
  if (boxedWarningText != null) 'boxed_warning': [boxedWarningText],
  if (boxedWarningTableText != null)
    'boxed_warning_table': [boxedWarningTableText],
  if (warningsText != null) 'warnings': [warningsText],
  if (warningsTableText != null) 'warnings_table': [warningsTableText],
  if (warningsAndCautionsText != null)
    'warnings_and_cautions': [warningsAndCautionsText],
  if (warningsAndCautionsTableText != null)
    'warnings_and_cautions_table': [warningsAndCautionsTableText],
};

class _RecordingLabelFetchClient extends FakeSourceFetchClient {
  _RecordingLabelFetchClient({Map<String, Map<String, dynamic>>? payloadByName})
    : _payloadByName = payloadByName ?? const {},
      super(textByUrl: const {});

  final Map<String, Map<String, dynamic>> _payloadByName;
  final requests = <Uri>[];
  final notFoundNames = <String>{};
  final failedStatusByName = <String, int>{};

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
    final name = match?.group(1)?.toLowerCase() ?? '';
    final failureStatus = failedStatusByName[name];
    if (failureStatus != null) {
      throw SourceFetchHttpException(
        statusCode: failureStatus,
        message: 'synthetic HTTP $failureStatus failure',
      );
    }
    if (notFoundNames.contains(name)) {
      throw SourceFetchHttpException(
        statusCode: 404,
        message: 'synthetic HTTP 404 failure',
      );
    }
    final payload =
        _payloadByName[name] ??
        _payload(
          total: 8,
          results: [
            _record(
              genericName: name,
              interactionText: 'Beta Compound is a synthetic fixture phrase.',
            ),
          ],
        );
    return jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
  }
}
