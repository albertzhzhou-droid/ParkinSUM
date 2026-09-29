import 'package:http/http.dart' as http;

import '../../../core/services/runtime_network_egress_policy.dart';
import 'source_fetch_client.dart';

enum RxNormNameCandidateSearchState {
  candidatesReturned,
  noNamedRxNormCandidate,
  unavailable,
}

/// One named atom returned from RxNav's RXNORM source vocabulary.
///
/// RxNav's match score is deliberately discarded. [lexicalRank] describes
/// ordering within the approximate string-search response; it is not a
/// probability, identity confirmation, or clinical confidence.
final class RxNormNameCandidate {
  const RxNormNameCandidate({
    required this.rxCui,
    required this.rxAui,
    required this.name,
    required this.lexicalRank,
  });

  final String rxCui;
  final String rxAui;
  final String name;
  final int lexicalRank;
}

final class RxNormNameCandidateTermResult {
  RxNormNameCandidateTermResult({
    required this.term,
    required this.state,
    required List<RxNormNameCandidate> candidates,
    required this.retrievedAt,
    required this.mayHaveMoreCandidates,
    required this.failureStatusCode,
  }) : candidates = List<RxNormNameCandidate>.unmodifiable(candidates);

  final String term;
  final RxNormNameCandidateSearchState state;
  final List<RxNormNameCandidate> candidates;
  final DateTime retrievedAt;

  /// True when the local display cap excluded additional named RXNORM rows.
  final bool mayHaveMoreCandidates;

  /// HTTP status only; response bodies and request URLs are never retained.
  final int? failureStatusCode;
}

final class RxNormNameCandidateSearchResult {
  const RxNormNameCandidateSearchResult({
    required this.firstTerm,
    required this.secondTerm,
  });

  final RxNormNameCandidateTermResult firstTerm;
  final RxNormNameCandidateTermResult secondTerm;
}

enum RxNormConceptPropertiesState {
  activePropertiesReturned,
  notInCurrentActiveDataset,
  unavailable,
}

/// Current RxNav properties for a manually selected candidate.
///
/// The term type and source fields are descriptive metadata only. They do not
/// confirm that the selected concept represents the user's medication.
final class RxNormConceptPropertiesResult {
  const RxNormConceptPropertiesResult({
    required this.rxCui,
    required this.state,
    required this.retrievedAt,
    this.conceptName,
    this.termTypeCode,
    this.synonym,
    this.language,
    this.suppress,
    this.failureStatusCode,
  });

  final String rxCui;
  final RxNormConceptPropertiesState state;
  final DateTime retrievedAt;
  final String? conceptName;
  final String? termTypeCode;
  final String? synonym;
  final String? language;
  final String? suppress;
  final int? failureStatusCode;
}

enum RxNormConceptHistoryStatus {
  active,
  obsolete,
  remapped,
  quantified,
  notCurrent,
  unknown,
  unavailable,
}

final class RxNormRemappedConcept {
  const RxNormRemappedConcept({
    required this.rxCui,
    required this.name,
    required this.termTypeCode,
    required this.active,
  });

  final String rxCui;
  final String name;
  final String termTypeCode;
  final String active;
}

/// A bounded projection of RxNav historical status metadata.
/// Replacement CUIs remain a candidate list; none is selected or applied.
final class RxNormConceptHistoryResult {
  RxNormConceptHistoryResult({
    required this.rxCui,
    required this.status,
    required this.retrievedAt,
    required List<RxNormRemappedConcept> remappedConcepts,
    required this.mayHaveMoreRemappedConcepts,
    this.source,
    this.conceptName,
    this.termTypeCode,
    this.releaseStartDate,
    this.releaseEndDate,
    this.isCurrent,
    this.activeStartDate,
    this.activeEndDate,
    this.remappedDate,
    this.failureStatusCode,
  }) : remappedConcepts = List<RxNormRemappedConcept>.unmodifiable(
         remappedConcepts,
       );

  final String rxCui;
  final RxNormConceptHistoryStatus status;
  final DateTime retrievedAt;
  final String? source;
  final String? conceptName;
  final String? termTypeCode;
  final String? releaseStartDate;
  final String? releaseEndDate;
  final String? isCurrent;
  final String? activeStartDate;
  final String? activeEndDate;
  final String? remappedDate;
  final List<RxNormRemappedConcept> remappedConcepts;
  final bool mayHaveMoreRemappedConcepts;
  final int? failureStatusCode;
}

final class RxNormNameCandidateRateLimitException implements Exception {
  const RxNormNameCandidateRateLimitException();
}

/// User-triggered, read-only RxNav approximate-term lookup.
///
/// It sends only two manually entered name strings, scopes the request to
/// active concepts, displays only named RXNORM-source candidates, discards
/// RxNav's numeric score, and retains results in memory only. A second,
/// separately consent-gated method can inspect properties for one candidate
/// returned by the most recent search.
final class RxNormNameCandidateSearch {
  static const endpoint = 'https://rxnav.nlm.nih.gov/REST/approximateTerm.json';
  static const maxEntries = 10;
  static const maximumDisplayedCandidates = 20;
  static const maxNameLength = 80;
  static const maxResponseBytes = 256 * 1024;
  static const minimumPairInterval = Duration(seconds: 1);
  static const minimumConceptPropertiesInterval = Duration(seconds: 1);
  static const conceptPropertiesResponseBytes = 16 * 1024;
  static const minimumConceptHistoryInterval = Duration(seconds: 1);
  static const conceptHistoryResponseBytes = 64 * 1024;
  static const maximumRemappedConcepts = 20;

  static final _safeName = RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .'-]{1,79}$");
  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

  final SourceFetchClient fetchClient;
  final SourceFetchClient Function(String rxCui)?
  conceptPropertiesFetchClientFactory;
  final SourceFetchClient Function(String rxCui)?
  conceptHistoryFetchClientFactory;
  final DateTime Function() clock;
  DateTime? _lastPairLookupAt;
  DateTime? _lastRxNormDetailLookupAt;
  final Set<String> _mostRecentCandidateRxcuis = <String>{};

  RxNormNameCandidateSearch({
    required this.fetchClient,
    this.conceptPropertiesFetchClientFactory,
    this.conceptHistoryFetchClientFactory,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  factory RxNormNameCandidateSearch.live({
    http.Client? client,
    DateTime Function()? clock,
  }) {
    SourceFetchClient historyClient(String rxCui) => HttpSourceFetchClient(
      client: client,
      egressPolicy:
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptHistoryLookup(
            rxCui,
          ),
      egressPurpose:
          RuntimeNetworkEgressPurpose.userInitiatedRxNormConceptHistoryLookup,
      egressDataClasses: const {RuntimeNetworkDataClass.userSelectedRxCui},
      responseByteLimit: conceptHistoryResponseBytes,
      captureResponseMetadata: false,
    );

    SourceFetchClient propertiesClient(String rxCui) => HttpSourceFetchClient(
      client: client,
      egressPolicy:
          RuntimeNetworkEgressPolicy.userInitiatedRxNormConceptPropertiesLookup(
            rxCui,
          ),
      egressPurpose: RuntimeNetworkEgressPurpose
          .userInitiatedRxNormConceptPropertiesLookup,
      egressDataClasses: const {RuntimeNetworkDataClass.userSelectedRxCui},
      responseByteLimit: conceptPropertiesResponseBytes,
      captureResponseMetadata: false,
    );

    return RxNormNameCandidateSearch(
      fetchClient: HttpSourceFetchClient(
        client: client,
        egressPolicy:
            RuntimeNetworkEgressPolicy.userInitiatedRxNormNameCandidateLookup,
        egressPurpose:
            RuntimeNetworkEgressPurpose.userInitiatedRxNormNameCandidateLookup,
        egressDataClasses: const {RuntimeNetworkDataClass.userEnteredDrugName},
        responseByteLimit: maxResponseBytes,
        captureResponseMetadata: false,
      ),
      conceptPropertiesFetchClientFactory: propertiesClient,
      conceptHistoryFetchClientFactory: historyClient,
      clock: clock,
    );
  }

  Future<RxNormNameCandidateSearchResult> searchPair({
    required String firstGenericName,
    required String secondGenericName,
  }) async {
    final first = _validatedName(firstGenericName);
    final second = _validatedName(secondGenericName);
    if (first.toLowerCase() == second.toLowerCase()) {
      throw ArgumentError('Enter two different generic names.');
    }

    final now = clock().toUtc();
    final lastStarted = _lastPairLookupAt;
    if (lastStarted != null &&
        now.difference(lastStarted) < minimumPairInterval) {
      throw const RxNormNameCandidateRateLimitException();
    }
    _lastPairLookupAt = now;
    _mostRecentCandidateRxcuis.clear();

    final results = await Future.wait([
      _searchTerm(first),
      _searchTerm(second),
    ]);
    _mostRecentCandidateRxcuis.addAll(
      results.expand(
        (result) => result.candidates.map((candidate) => candidate.rxCui),
      ),
    );
    return RxNormNameCandidateSearchResult(
      firstTerm: results[0],
      secondTerm: results[1],
    );
  }

  /// Fetches properties only for an RxCUI present in the most recent
  /// user-initiated candidate query. A caller must put a separate consent and
  /// action in front of this method because the selected RxCUI leaves device.
  Future<RxNormConceptPropertiesResult> lookupConceptProperties(
    RxNormNameCandidate candidate,
  ) async {
    final rxCui = candidate.rxCui;
    if (!_numericId.hasMatch(rxCui) ||
        !_mostRecentCandidateRxcuis.contains(rxCui)) {
      throw ArgumentError.value(
        rxCui,
        'candidate.rxCui',
        'Must be a candidate from the most recent lookup.',
      );
    }

    final now = clock().toUtc();
    final lastStarted = _lastRxNormDetailLookupAt;
    if (lastStarted != null &&
        now.difference(lastStarted) < minimumConceptPropertiesInterval) {
      throw const RxNormNameCandidateRateLimitException();
    }
    _lastRxNormDetailLookupAt = now;

    final retrievedAt = clock().toUtc();
    final uri = Uri.https(
      'rxnav.nlm.nih.gov',
      '/REST/rxcui/$rxCui/properties.json',
    );
    final fetcher =
        conceptPropertiesFetchClientFactory?.call(rxCui) ?? fetchClient;
    try {
      final payload = await fetcher
          .getJsonMap(
            uri.toString(),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      final rawProperties = payload['properties'];
      if (rawProperties == null ||
          rawProperties is List && rawProperties.isEmpty) {
        return RxNormConceptPropertiesResult(
          rxCui: rxCui,
          state: RxNormConceptPropertiesState.notInCurrentActiveDataset,
          retrievedAt: retrievedAt,
        );
      }
      final properties = switch (rawProperties) {
        Map<String, dynamic> value => value,
        List values
            when values.length == 1 && values.single is Map<String, dynamic> =>
          values.single as Map<String, dynamic>,
        _ => null,
      };
      if (properties == null || _safeIdentifier(properties['rxcui']) != rxCui) {
        return _unavailableConceptProperties(rxCui, retrievedAt);
      }
      final conceptName = _safeNameValue(properties['name']);
      final termType = _safeTermType(properties['tty']);
      if (conceptName == null || termType == null) {
        return _unavailableConceptProperties(rxCui, retrievedAt);
      }
      return RxNormConceptPropertiesResult(
        rxCui: rxCui,
        state: RxNormConceptPropertiesState.activePropertiesReturned,
        retrievedAt: retrievedAt,
        conceptName: conceptName,
        termTypeCode: termType,
        synonym: _safeNameValue(properties['synonym']),
        language: _safeShortCode(properties['language']),
        suppress: _safeShortCode(properties['suppress']),
      );
    } on SourceFetchHttpException catch (error) {
      return _unavailableConceptProperties(
        rxCui,
        retrievedAt,
        failureStatusCode: error.statusCode,
      );
    } catch (_) {
      return _unavailableConceptProperties(rxCui, retrievedAt);
    }
  }

  /// Retrieves a bounded history/status projection for one recent candidate.
  /// A caller must put separate consent and a candidate-specific action before
  /// this request because the selected RxCUI and network address leave device.
  Future<RxNormConceptHistoryResult> lookupConceptHistory(
    RxNormNameCandidate candidate,
  ) async {
    final rxCui = candidate.rxCui;
    if (!_numericId.hasMatch(rxCui) ||
        !_mostRecentCandidateRxcuis.contains(rxCui)) {
      throw ArgumentError.value(
        rxCui,
        'candidate.rxCui',
        'Must be a candidate from the most recent lookup.',
      );
    }

    final now = clock().toUtc();
    final lastStarted = _lastRxNormDetailLookupAt;
    if (lastStarted != null &&
        now.difference(lastStarted) < minimumConceptHistoryInterval) {
      throw const RxNormNameCandidateRateLimitException();
    }
    _lastRxNormDetailLookupAt = now;

    final retrievedAt = clock().toUtc();
    final uri = Uri.https(
      'rxnav.nlm.nih.gov',
      '/REST/rxcui/$rxCui/historystatus.json',
    );
    final fetcher =
        conceptHistoryFetchClientFactory?.call(rxCui) ?? fetchClient;
    try {
      final payload = await fetcher
          .getJsonMap(
            uri.toString(),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      final rawHistory = payload['rxcuiStatusHistory'];
      final history = switch (rawHistory) {
        Map<String, dynamic> value => value,
        List values
            when values.length == 1 && values.single is Map<String, dynamic> =>
          values.single as Map<String, dynamic>,
        _ => null,
      };
      if (history == null) {
        return _unavailableConceptHistory(rxCui, retrievedAt);
      }

      final rawMetadata = history['metaData'];
      final rawAttributes = history['attributes'];
      if (rawMetadata is! Map<String, dynamic> ||
          rawAttributes is! Map<String, dynamic> ||
          _safeIdentifier(rawAttributes['rxcui']) != rxCui) {
        return _unavailableConceptHistory(rxCui, retrievedAt);
      }
      final status = _parseHistoryStatus(rawMetadata['status']);
      if (status == null) {
        return _unavailableConceptHistory(rxCui, retrievedAt);
      }
      final remapped = _parseRemappedConcepts(
        (history['derivedConcepts']
            as Map<String, dynamic>?)?['remappedConcept'],
      );
      if (remapped == null) {
        return _unavailableConceptHistory(rxCui, retrievedAt);
      }
      return RxNormConceptHistoryResult(
        rxCui: rxCui,
        status: status,
        retrievedAt: retrievedAt,
        source: _safeShortCode(rawMetadata['source']),
        conceptName: _safeNameValue(rawAttributes['name']),
        termTypeCode: _safeTermType(rawAttributes['tty']),
        releaseStartDate: _safeReleaseDate(rawMetadata['releaseStartDate']),
        releaseEndDate: _safeReleaseDate(rawMetadata['releaseEndDate']),
        isCurrent: _safeYesNo(rawMetadata['isCurrent']),
        activeStartDate: _safeReleaseDate(rawMetadata['activeStartDate']),
        activeEndDate: _safeReleaseDate(rawMetadata['activeEndDate']),
        remappedDate: _safeReleaseDate(rawMetadata['remappedDate']),
        remappedConcepts: remapped,
        mayHaveMoreRemappedConcepts:
            _remappedConceptCount(
              (history['derivedConcepts']
                  as Map<String, dynamic>?)?['remappedConcept'],
            ) >
            maximumRemappedConcepts,
      );
    } on SourceFetchHttpException catch (error) {
      return _unavailableConceptHistory(
        rxCui,
        retrievedAt,
        failureStatusCode: error.statusCode,
      );
    } catch (_) {
      return _unavailableConceptHistory(rxCui, retrievedAt);
    }
  }

  String _validatedName(String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length > maxNameLength || !_safeName.hasMatch(name)) {
      throw ArgumentError(
        'Use a generic name with letters, numbers, spaces, hyphens, '
        'apostrophes, or periods (2–80 characters).',
      );
    }
    return name;
  }

  Future<RxNormNameCandidateTermResult> _searchTerm(String term) async {
    final retrievedAt = clock().toUtc();
    final uri = Uri.https('rxnav.nlm.nih.gov', '/REST/approximateTerm.json', {
      'term': term,
      'maxEntries': '$maxEntries',
      'option': '1',
    });
    try {
      final payload = await fetchClient
          .getJsonMap(
            uri.toString(),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      final group = payload['approximateGroup'];
      if (group is! Map<String, dynamic>) {
        return _unavailable(term, retrievedAt);
      }
      final rawCandidates = group['candidate'];
      if (rawCandidates == null) {
        return _noNamedCandidate(term, retrievedAt);
      }
      final candidates = switch (rawCandidates) {
        List values => values,
        Map<String, dynamic> value => <Object?>[value],
        _ => null,
      };
      if (candidates == null) return _unavailable(term, retrievedAt);

      final namedRxNormCandidates = candidates
          .whereType<Map<String, dynamic>>()
          .where(_isNamedRxNormCandidate)
          .map(_parseCandidate)
          .whereType<RxNormNameCandidate>()
          .toList(growable: false);
      final visible = namedRxNormCandidates
          .take(maximumDisplayedCandidates)
          .toList(growable: false);
      return RxNormNameCandidateTermResult(
        term: term,
        state: visible.isEmpty
            ? RxNormNameCandidateSearchState.noNamedRxNormCandidate
            : RxNormNameCandidateSearchState.candidatesReturned,
        candidates: visible,
        retrievedAt: retrievedAt,
        mayHaveMoreCandidates:
            namedRxNormCandidates.length > maximumDisplayedCandidates,
        failureStatusCode: null,
      );
    } on SourceFetchHttpException catch (error) {
      return _unavailable(
        term,
        retrievedAt,
        failureStatusCode: error.statusCode,
      );
    } catch (_) {
      // Never expose the request URL, query, or remote body in the UI/error.
      return _unavailable(term, retrievedAt);
    }
  }

  bool _isNamedRxNormCandidate(Map<String, dynamic> raw) =>
      raw['source'] is String &&
      (raw['source'] as String).toUpperCase() == 'RXNORM' &&
      _safeIdentifier(raw['rxcui']) != null &&
      _safeIdentifier(raw['rxaui']) != null &&
      _safeNameValue(raw['name']) != null &&
      _positiveRank(raw['rank']) != null;

  RxNormNameCandidate? _parseCandidate(Map<String, dynamic> raw) {
    final rxCui = _safeIdentifier(raw['rxcui']);
    final rxAui = _safeIdentifier(raw['rxaui']);
    final name = _safeNameValue(raw['name']);
    final rank = _positiveRank(raw['rank']);
    if (rxCui == null || rxAui == null || name == null || rank == null) {
      return null;
    }
    return RxNormNameCandidate(
      rxCui: rxCui,
      rxAui: rxAui,
      name: name,
      lexicalRank: rank,
    );
  }

  String? _safeIdentifier(Object? value) {
    final text = value is String
        ? value
        : value is int
        ? '$value'
        : null;
    return text != null && _numericId.hasMatch(text) ? text : null;
  }

  String? _safeNameValue(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty ||
        text.length > 200 ||
        _controlCharacters.hasMatch(text)) {
      return null;
    }
    return text;
  }

  int? _positiveRank(Object? value) {
    final rank = value is int ? value : int.tryParse('$value');
    return rank != null && rank > 0 && rank <= 100 ? rank : null;
  }

  String? _safeTermType(Object? value) {
    if (value is! String || !RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  String? _safeShortCode(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 32 ||
        _controlCharacters.hasMatch(value)) {
      return null;
    }
    return value;
  }

  RxNormConceptHistoryStatus? _parseHistoryStatus(Object? value) =>
      switch (value) {
        'Active' => RxNormConceptHistoryStatus.active,
        'Obsolete' => RxNormConceptHistoryStatus.obsolete,
        'Remapped' => RxNormConceptHistoryStatus.remapped,
        'Quantified' => RxNormConceptHistoryStatus.quantified,
        'NotCurrent' => RxNormConceptHistoryStatus.notCurrent,
        'Unknown' => RxNormConceptHistoryStatus.unknown,
        _ => null,
      };

  String? _safeReleaseDate(Object? value) =>
      value is String && RegExp(r'^(0[1-9]|1[0-2])[0-9]{4}$').hasMatch(value)
      ? value
      : null;

  String? _safeYesNo(Object? value) =>
      value == 'YES' || value == 'NO' ? value as String : null;

  List<RxNormRemappedConcept>? _parseRemappedConcepts(Object? value) {
    if (value == null) return const <RxNormRemappedConcept>[];
    final rows = switch (value) {
      List items => items,
      Map<String, dynamic> item => <Object?>[item],
      _ => null,
    };
    if (rows == null) return null;
    final parsed = <RxNormRemappedConcept>[];
    for (final row in rows.take(maximumRemappedConcepts)) {
      if (row is! Map<String, dynamic>) return null;
      final rxCui = _safeIdentifier(row['remappedRxCui']);
      final name = _safeNameValue(row['remappedName']);
      final tty = _safeTermType(row['remappedTTY']);
      final active = _safeYesNo(row['remappedActive']);
      if (rxCui == null || name == null || tty == null || active == null) {
        return null;
      }
      parsed.add(
        RxNormRemappedConcept(
          rxCui: rxCui,
          name: name,
          termTypeCode: tty,
          active: active,
        ),
      );
    }
    return List<RxNormRemappedConcept>.unmodifiable(parsed);
  }

  int _remappedConceptCount(Object? value) => switch (value) {
    List items => items.length,
    Map<String, dynamic> _ => 1,
    _ => 0,
  };

  RxNormConceptPropertiesResult _unavailableConceptProperties(
    String rxCui,
    DateTime retrievedAt, {
    int? failureStatusCode,
  }) => RxNormConceptPropertiesResult(
    rxCui: rxCui,
    state: RxNormConceptPropertiesState.unavailable,
    retrievedAt: retrievedAt,
    failureStatusCode: failureStatusCode,
  );

  RxNormConceptHistoryResult _unavailableConceptHistory(
    String rxCui,
    DateTime retrievedAt, {
    int? failureStatusCode,
  }) => RxNormConceptHistoryResult(
    rxCui: rxCui,
    status: RxNormConceptHistoryStatus.unavailable,
    retrievedAt: retrievedAt,
    remappedConcepts: const <RxNormRemappedConcept>[],
    mayHaveMoreRemappedConcepts: false,
    failureStatusCode: failureStatusCode,
  );

  RxNormNameCandidateTermResult _noNamedCandidate(
    String term,
    DateTime retrievedAt,
  ) => RxNormNameCandidateTermResult(
    term: term,
    state: RxNormNameCandidateSearchState.noNamedRxNormCandidate,
    candidates: const [],
    retrievedAt: retrievedAt,
    mayHaveMoreCandidates: false,
    failureStatusCode: null,
  );

  RxNormNameCandidateTermResult _unavailable(
    String term,
    DateTime retrievedAt, {
    int? failureStatusCode,
  }) => RxNormNameCandidateTermResult(
    term: term,
    state: RxNormNameCandidateSearchState.unavailable,
    candidates: const [],
    retrievedAt: retrievedAt,
    mayHaveMoreCandidates: false,
    failureStatusCode: failureStatusCode,
  );
}
