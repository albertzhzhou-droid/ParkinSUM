import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/services/runtime_network_egress_policy.dart';
import 'package:parkinsum_companion/data/datasources/remote/rxnorm_name_candidate_search.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  group('RxNorm approximate name candidate lookup', () {
    test('sends only two bounded active-concept lexical queries', () async {
      final fetcher = _RecordingRxNormFetchClient();
      final lookup = RxNormNameCandidateSearch(
        fetchClient: fetcher,
        clock: () => DateTime.utc(2026, 9, 25, 12),
      );

      final result = await lookup.searchPair(
        firstGenericName: ' Alpha   Compound ',
        secondGenericName: 'Beta Compound',
      );

      expect(fetcher.requests, hasLength(2));
      expect(fetcher.requests.map((uri) => uri.host).toSet(), {
        'rxnav.nlm.nih.gov',
      });
      expect(fetcher.requests.map((uri) => uri.path).toSet(), {
        '/REST/approximateTerm.json',
      });
      for (final uri in fetcher.requests) {
        expect(uri.queryParameters.keys.toSet(), {
          'term',
          'maxEntries',
          'option',
        });
        expect(uri.queryParameters['maxEntries'], '10');
        expect(uri.queryParameters['option'], '1');
      }
      expect(
        fetcher.requests.map((uri) => uri.queryParameters['term']).toSet(),
        {'Alpha Compound', 'Beta Compound'},
      );
      expect(
        result.firstTerm.state,
        RxNormNameCandidateSearchState.candidatesReturned,
      );
      expect(result.firstTerm.candidates, hasLength(1));
      expect(result.firstTerm.candidates.single.name, 'alpha 10 MG');
      expect(result.firstTerm.candidates.single.rxCui, '12345');
      expect(result.firstTerm.candidates.single.rxAui, '67890');
      expect(result.firstTerm.candidates.single.lexicalRank, 1);
      expect(result.firstTerm.retrievedAt, DateTime.utc(2026, 9, 25, 12));
      expect(
        result.secondTerm.state,
        RxNormNameCandidateSearchState.noNamedRxNormCandidate,
        reason: 'an empty candidate list is not described as drug absence',
      );
    });

    test(
      'omits restricted sources, unnamed rows, scores, and malformed rows',
      () async {
        final lookup = RxNormNameCandidateSearch(
          fetchClient: _FixedRxNormFetchClient({
            'Alpha Compound': {
              'approximateGroup': {
                'candidate': [
                  {
                    'rxcui': '12345',
                    'rxaui': '67890',
                    'score': '999',
                    'rank': '2',
                    'name': 'Alpha ingredient 10 MG',
                    'source': 'RXNORM',
                  },
                  {
                    'rxcui': '12345',
                    'rxaui': '67891',
                    'score': '999',
                    'rank': '2',
                    'source': 'GS',
                  },
                  {
                    'rxcui': 'not-an-id',
                    'rxaui': '67892',
                    'rank': '2',
                    'name': 'Malformed row',
                    'source': 'RXNORM',
                  },
                  {
                    'rxcui': '12346',
                    'rxaui': '67893',
                    'rank': '2',
                    'name': '   ',
                    'source': 'RXNORM',
                  },
                ],
              },
            },
            'Beta Compound': {
              'approximateGroup': {'candidate': <Object?>[]},
            },
          }),
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );

        final result = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        expect(result.firstTerm.candidates, hasLength(1));
        expect(
          result.firstTerm.candidates.single.name,
          'Alpha ingredient 10 MG',
        );
        expect(result.firstTerm.candidates.single.lexicalRank, 2);
        expect(result.secondTerm.candidates, isEmpty);
      },
    );

    test('validation and pair rate limit prevent extra requests', () async {
      final fetcher = _RecordingRxNormFetchClient();
      var now = DateTime.utc(2026, 9, 25, 12);
      final lookup = RxNormNameCandidateSearch(
        fetchClient: fetcher,
        clock: () => now,
      );

      await expectLater(
        lookup.searchPair(
          firstGenericName: 'alpha" AND *',
          secondGenericName: 'Beta Compound',
        ),
        throwsArgumentError,
      );
      await lookup.searchPair(
        firstGenericName: 'Alpha Compound',
        secondGenericName: 'Beta Compound',
      );
      await expectLater(
        lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Gamma Compound',
        ),
        throwsA(isA<RxNormNameCandidateRateLimitException>()),
      );
      expect(fetcher.requests, hasLength(2));

      now = now.add(RxNormNameCandidateSearch.minimumPairInterval);
      await lookup.searchPair(
        firstGenericName: 'Alpha Compound',
        secondGenericName: 'Gamma Compound',
      );
      expect(fetcher.requests, hasLength(4));
    });

    test(
      'concept properties require a recent candidate and rate limit',
      () async {
        final fetcher = _RecordingRxNormFetchClient();
        var now = DateTime.utc(2026, 9, 25, 12);
        final lookup = RxNormNameCandidateSearch(
          fetchClient: fetcher,
          clock: () => now,
        );
        final candidates = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );
        final candidate = candidates.firstTerm.candidates.single;

        final properties = await lookup.lookupConceptProperties(candidate);
        expect(
          properties.state,
          RxNormConceptPropertiesState.activePropertiesReturned,
        );
        expect(properties.rxCui, '12345');
        expect(properties.conceptName, 'alpha 10 MG');
        expect(properties.termTypeCode, 'SCD');
        expect(properties.synonym, 'Alpha');
        expect(properties.language, 'ENG');
        expect(properties.suppress, 'N');
        final request = fetcher.requests.last;
        expect(request.host, 'rxnav.nlm.nih.gov');
        expect(request.path, '/REST/rxcui/12345/properties.json');
        expect(request.queryParameters, isEmpty);
        expect(
          () => lookup.lookupConceptProperties(
            const RxNormNameCandidate(
              rxCui: '99999',
              rxAui: '99998',
              name: 'unrelated',
              lexicalRank: 1,
            ),
          ),
          throwsArgumentError,
        );
        await expectLater(
          lookup.lookupConceptProperties(candidate),
          throwsA(isA<RxNormNameCandidateRateLimitException>()),
        );
        expect(fetcher.requests, hasLength(3));

        now = now.add(
          RxNormNameCandidateSearch.minimumConceptPropertiesInterval,
        );
        await lookup.lookupConceptProperties(candidate);
        expect(fetcher.requests, hasLength(4));
      },
    );

    test('missing active properties do not mean retired or absent', () async {
      final fetcher = _RecordingRxNormFetchClient(withProperties: false);
      final lookup = RxNormNameCandidateSearch(
        fetchClient: fetcher,
        clock: () => DateTime.utc(2026, 9, 25, 12),
      );
      final candidates = await lookup.searchPair(
        firstGenericName: 'Alpha Compound',
        secondGenericName: 'Beta Compound',
      );

      final properties = await lookup.lookupConceptProperties(
        candidates.firstTerm.candidates.single,
      );

      expect(
        properties.state,
        RxNormConceptPropertiesState.notInCurrentActiveDataset,
      );
      expect(properties.conceptName, isNull);
    });

    test(
      'history status preserves every replacement as an unselected candidate',
      () async {
        final fetcher = _RecordingRxNormFetchClient();
        final lookup = RxNormNameCandidateSearch(
          fetchClient: fetcher,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );
        final candidates = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        final history = await lookup.lookupConceptHistory(
          candidates.firstTerm.candidates.single,
        );

        expect(history.status, RxNormConceptHistoryStatus.remapped);
        expect(history.rxCui, '12345');
        expect(history.source, 'RXNORM');
        expect(history.conceptName, 'old alpha product');
        expect(history.termTypeCode, 'SBD');
        expect(history.releaseStartDate, '042005');
        expect(history.remappedDate, '062009');
        expect(history.remappedConcepts, hasLength(2));
        expect(history.remappedConcepts.map((item) => item.rxCui), [
          '849389',
          '849394',
        ]);
        expect(history.remappedConcepts.map((item) => item.active), [
          'YES',
          'NO',
        ]);
        expect(history.mayHaveMoreRemappedConcepts, isFalse);
        final request = fetcher.requests.last;
        expect(request.host, 'rxnav.nlm.nih.gov');
        expect(request.path, '/REST/rxcui/12345/historystatus.json');
        expect(request.queryParameters, isEmpty);
      },
    );

    test(
      'history lookup rejects a candidate outside the most recent result',
      () async {
        final fetcher = _RecordingRxNormFetchClient();
        final lookup = RxNormNameCandidateSearch(
          fetchClient: fetcher,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );
        await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );
        await expectLater(
          lookup.lookupConceptHistory(
            const RxNormNameCandidate(
              rxCui: '99999',
              rxAui: '99998',
              name: 'unrelated',
              lexicalRank: 1,
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'history preview caps remapped candidates and reports truncation',
      () async {
        final fetcher = _RecordingRxNormFetchClient(remappedConceptCount: 21);
        final lookup = RxNormNameCandidateSearch(
          fetchClient: fetcher,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );
        final candidates = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        final history = await lookup.lookupConceptHistory(
          candidates.firstTerm.candidates.single,
        );

        expect(history.remappedConcepts, hasLength(20));
        expect(history.mayHaveMoreRemappedConcepts, isTrue);
        expect(history.remappedConcepts.last.rxCui, '849408');
      },
    );

    test(
      'live client uses exact RxNav egress and discards request metadata',
      () async {
        final requestUris = <Uri>[];
        final transport = MockClient((request) async {
          requestUris.add(request.url);
          expect(request.method, 'GET');
          expect(request.followRedirects, isFalse);
          expect(request.headers.keys.map((key) => key.toLowerCase()), [
            'accept',
          ]);
          expect(request.headers['Authorization'], isNull);
          if (request.url.path.endsWith('/properties.json')) {
            expect(request.url.queryParameters, isEmpty);
            return http.Response(
              jsonEncode({
                'properties': {
                  'rxcui': '12345',
                  'name': 'alpha 10 MG',
                  'tty': 'SCD',
                },
              }),
              200,
              headers: const {'etag': 'must-not-be-retained'},
            );
          }
          if (request.url.path.endsWith('/historystatus.json')) {
            expect(request.url.queryParameters, isEmpty);
            return http.Response(
              jsonEncode({
                'rxcuiStatusHistory': {
                  'metaData': {
                    'status': 'Remapped',
                    'source': 'RXNORM',
                    'remappedDate': '062009',
                  },
                  'attributes': {
                    'rxcui': '12345',
                    'name': 'old alpha product',
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
                    ],
                  },
                },
              }),
              200,
              headers: const {'etag': 'must-not-be-retained'},
            );
          }
          return http.Response(
            jsonEncode({
              'approximateGroup': {
                'candidate': [
                  {
                    'rxcui': '12345',
                    'rxaui': '67890',
                    'rank': '1',
                    'name': 'alpha 10 MG',
                    'source': 'RXNORM',
                  },
                ],
              },
            }),
            200,
            headers: const {'etag': 'must-not-be-retained'},
          );
        });
        var now = DateTime.utc(2026, 9, 25, 12);
        final lookup = RxNormNameCandidateSearch.live(
          client: transport,
          clock: () => now,
        );

        final candidates = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );
        final properties = await lookup.lookupConceptProperties(
          candidates.firstTerm.candidates.single,
        );
        now = now.add(const Duration(seconds: 1));
        final history = await lookup.lookupConceptHistory(
          candidates.firstTerm.candidates.single,
        );

        expect(requestUris, hasLength(4));
        expect(requestUris[2].path, '/REST/rxcui/12345/properties.json');
        expect(properties.conceptName, 'alpha 10 MG');
        expect(requestUris.last.path, '/REST/rxcui/12345/historystatus.json');
        expect(history.status, RxNormConceptHistoryStatus.remapped);
        expect(
          RuntimeNetworkEgressPolicy
              .userInitiatedRxNormNameCandidateLookup
              .rules
              .single
              .hosts,
          {'rxnav.nlm.nih.gov'},
        );
        expect(
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptPropertiesLookup(
            '12345',
          ).rules.single.exactPaths,
          {'/REST/rxcui/12345/properties.json'},
        );
      },
    );

    test(
      'transport failures expose only a status and never echo the term',
      () async {
        final transport = MockClient((request) async {
          return http.Response('synthetic sensitive term: Alpha Compound', 429);
        });
        final lookup = RxNormNameCandidateSearch.live(
          client: transport,
          clock: () => DateTime.utc(2026, 9, 25, 12),
        );

        final result = await lookup.searchPair(
          firstGenericName: 'Alpha Compound',
          secondGenericName: 'Beta Compound',
        );

        expect(
          result.firstTerm.state,
          RxNormNameCandidateSearchState.unavailable,
        );
        expect(result.firstTerm.failureStatusCode, 429);
        expect(result.firstTerm.toString(), isNot(contains('Alpha Compound')));
      },
    );
  });
}

class _RecordingRxNormFetchClient extends FakeSourceFetchClient {
  _RecordingRxNormFetchClient({
    this.withProperties = true,
    this.remappedConceptCount = 2,
  }) : super(textByUrl: const <String, String>{});

  final bool withProperties;
  final int remappedConceptCount;

  final requests = <Uri>[];

  @override
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(url);
    requests.add(uri);
    if (uri.path.endsWith('/historystatus.json')) {
      return <String, dynamic>{
        'rxcuiStatusHistory': <String, dynamic>{
          'metaData': <String, dynamic>{
            'status': 'Remapped',
            'source': 'RXNORM',
            'releaseStartDate': '042005',
            'remappedDate': '062009',
          },
          'attributes': <String, dynamic>{
            'rxcui': '12345',
            'name': 'old alpha product',
            'tty': 'SBD',
          },
          'derivedConcepts': <String, dynamic>{
            'remappedConcept': List<Object?>.generate(
              remappedConceptCount,
              (index) => <String, dynamic>{
                'remappedRxCui': index == 1 ? '849394' : '${849389 + index}',
                'remappedName': 'alpha product $index',
                'remappedTTY': index.isEven ? 'SCD' : 'SBD',
                'remappedActive': index.isEven ? 'YES' : 'NO',
              },
            ),
          },
        },
      };
    }
    if (uri.path.endsWith('/properties.json')) {
      return withProperties
          ? <String, dynamic>{
              'properties': {
                'rxcui': '12345',
                'name': 'alpha 10 MG',
                'tty': 'SCD',
                'synonym': 'Alpha',
                'language': 'ENG',
                'suppress': 'N',
              },
            }
          : <String, dynamic>{};
    }
    if (uri.queryParameters['term'] == 'Beta Compound') {
      return <String, dynamic>{
        'approximateGroup': {'candidate': <Object?>[]},
      };
    }
    return <String, dynamic>{
      'approximateGroup': {
        'candidate': [
          {
            'rxcui': '12345',
            'rxaui': '67890',
            'score': '12.7',
            'rank': '1',
            'name': 'alpha 10 MG',
            'source': 'RXNORM',
          },
          {
            'rxcui': '12345',
            'rxaui': '67891',
            'score': '12.7',
            'rank': '1',
            'source': 'GS',
          },
        ],
      },
    };
  }
}

class _FixedRxNormFetchClient extends FakeSourceFetchClient {
  _FixedRxNormFetchClient(this.payloadByTerm)
    : super(textByUrl: const <String, String>{});

  final Map<String, Map<String, dynamic>> payloadByTerm;

  @override
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  }) async {
    final term = Uri.parse(url).queryParameters['term'];
    return payloadByTerm[term] ??
        <String, dynamic>{
          'approximateGroup': {'candidate': <Object?>[]},
        };
  }
}
