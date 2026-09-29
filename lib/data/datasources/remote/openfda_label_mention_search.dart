import 'package:http/http.dart' as http;

import '../../../core/services/runtime_network_egress_policy.dart';
import '../../../domain/entities/openfda_label_mention_search.dart';
import 'source_fetch_client.dart';

/// User-triggered, read-only search of selected public U.S. drug-label safety
/// sections. It reads no account or saved medication state and persists
/// nothing. A separate factory accepts two user-selected RxNorm candidate
/// display strings under a distinct egress policy. Literal name matches are
/// not clinical interaction findings.
final class OpenFdaLabelMentionSearch {
  static const endpoint = 'https://api.fda.gov/drug/label.json';
  static const maxRecordsPerName = 5;
  static const maxNameLength = 80;

  static final _safeName = RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .'-]{1,79}$");

  final SourceFetchClient fetchClient;
  final DateTime Function() clock;
  final bool _selectedRxNormCandidateMode;

  OpenFdaLabelMentionSearch({
    required this.fetchClient,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       _selectedRxNormCandidateMode = false;

  OpenFdaLabelMentionSearch.forSelectedRxNormCandidates({
    required this.fetchClient,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       _selectedRxNormCandidateMode = true;

  factory OpenFdaLabelMentionSearch.live({
    http.Client? client,
    DateTime Function()? clock,
  }) => OpenFdaLabelMentionSearch(
    fetchClient: HttpSourceFetchClient(
      client: client,
      egressPolicy: RuntimeNetworkEgressPolicy.userInitiatedOpenFdaLabelLookup,
      egressPurpose:
          RuntimeNetworkEgressPurpose.userInitiatedOpenFdaLabelLookup,
      egressDataClasses: const {RuntimeNetworkDataClass.userEnteredDrugName},
      responseByteLimit: 2 * 1024 * 1024,
      captureResponseMetadata: false,
    ),
    clock: clock,
  );

  factory OpenFdaLabelMentionSearch.liveForSelectedRxNormCandidates({
    http.Client? client,
    DateTime Function()? clock,
  }) => OpenFdaLabelMentionSearch.forSelectedRxNormCandidates(
    fetchClient: HttpSourceFetchClient(
      client: client,
      egressPolicy: RuntimeNetworkEgressPolicy
          .userInitiatedOpenFdaRxNormCandidateLabelLookup,
      egressPurpose: RuntimeNetworkEgressPurpose
          .userInitiatedOpenFdaRxNormCandidateLabelLookup,
      egressDataClasses: const {
        RuntimeNetworkDataClass.userSelectedRxNormCandidateDisplayName,
      },
      responseByteLimit: 2 * 1024 * 1024,
      captureResponseMetadata: false,
    ),
    clock: clock,
  );

  static bool canSearchRxNormCandidateName(String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return name.length <= maxNameLength && _safeName.hasMatch(name);
  }

  Future<OpenFdaLabelMentionSearchResult> searchPair({
    required String firstGenericName,
    required String secondGenericName,
  }) async {
    if (_selectedRxNormCandidateMode) {
      throw StateError(
        'Selected RxNorm names require their dedicated lookup method.',
      );
    }
    final first = _validatedName(firstGenericName);
    final second = _validatedName(secondGenericName);
    return _searchValidatedPair(first, second);
  }

  /// Searches the two exact display names individually selected from the
  /// latest RxNorm candidate list. The caller must obtain separate FDA-query
  /// consent; these display names are not medication identity confirmation.
  Future<OpenFdaLabelMentionSearchResult> searchSelectedRxNormCandidatePair({
    required String firstCandidateDisplayName,
    required String secondCandidateDisplayName,
  }) async {
    if (!_selectedRxNormCandidateMode) {
      throw StateError(
        'This lookup is not configured for selected RxNorm candidate names.',
      );
    }
    final first = _validatedName(firstCandidateDisplayName);
    final second = _validatedName(secondCandidateDisplayName);
    return _searchValidatedPair(first, second);
  }

  Future<OpenFdaLabelMentionSearchResult> _searchValidatedPair(
    String first,
    String second,
  ) async {
    if (first.toLowerCase() == second.toLowerCase()) {
      throw ArgumentError('Enter two different generic names.');
    }

    final results = await Future.wait([
      _searchName(first),
      _searchName(second),
    ]);
    return OpenFdaLabelMentionSearchResult(
      firstGenericName: first,
      secondGenericName: second,
      firstLabels: results[0],
      secondLabels: results[1],
    );
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

  Future<OpenFdaLabelNameSearch> _searchName(String genericName) async {
    final retrievedAt = clock().toUtc();
    final query = 'openfda.generic_name:"$genericName"';
    final uri = Uri.https('api.fda.gov', '/drug/label.json', {
      'search': query,
      'limit': '$maxRecordsPerName',
    });
    try {
      final payload = await fetchClient
          .getJsonMap(
            uri.toString(),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      final meta = payload['meta'];
      if (meta is! Map<String, dynamic>) {
        return _unavailable(genericName, retrievedAt);
      }
      final rawResults = payload['results'];
      if (rawResults is! List) {
        return _unavailable(genericName, retrievedAt);
      }
      final records = rawResults
          .whereType<Map<String, dynamic>>()
          .take(maxRecordsPerName)
          .map(_parseRecord)
          .toList(growable: false);
      final metaResults = meta['results'];
      final total = metaResults is Map<String, dynamic>
          ? _asInt(metaResults['total'])
          : null;
      final lastUpdated = _safeString(meta['last_updated']);
      return OpenFdaLabelNameSearch(
        genericName: genericName,
        state: records.isEmpty
            ? OpenFdaLabelSearchState.noLabelsReturned
            : OpenFdaLabelSearchState.labelsReturned,
        records: records,
        totalAvailable: total,
        datasetLastUpdated: lastUpdated,
        retrievedAt: retrievedAt,
        failureStatusCode: null,
      );
    } on SourceFetchHttpException catch (error) {
      if (error.statusCode == 404) {
        return OpenFdaLabelNameSearch(
          genericName: genericName,
          state: OpenFdaLabelSearchState.noLabelsReturned,
          records: const [],
          totalAvailable: 0,
          datasetLastUpdated: null,
          retrievedAt: retrievedAt,
          failureStatusCode: 404,
        );
      }
      return _unavailable(
        genericName,
        retrievedAt,
        failureStatusCode: error.statusCode,
      );
    } catch (_) {
      // Never expose the request URL, query, or remote body in the UI/error.
      return _unavailable(genericName, retrievedAt);
    }
  }

  OpenFdaLabelTextRecord _parseRecord(Map<String, dynamic> raw) {
    final openFda = raw['openfda'];
    final object = openFda is Map<String, dynamic>
        ? openFda
        : const <String, dynamic>{};
    return OpenFdaLabelTextRecord(
      id: _safeString(raw['id']),
      setId: _safeString(raw['set_id']),
      version: _positiveInt(raw['version']),
      effectiveTime: _safeString(raw['effective_time']),
      genericNames: _strings(object['generic_name']),
      brandNames: _strings(object['brand_name']),
      searchedLabelSections: [
        ..._sections('drug_interactions', raw['drug_interactions']),
        ..._sections('drug_interactions_table', raw['drug_interactions_table']),
        ..._sections('contraindications', raw['contraindications']),
        ..._sections('contraindications_table', raw['contraindications_table']),
        ..._sections('boxed_warning', raw['boxed_warning']),
        ..._sections('boxed_warning_table', raw['boxed_warning_table']),
        ..._sections('warnings', raw['warnings']),
        ..._sections('warnings_table', raw['warnings_table']),
        ..._sections('warnings_and_cautions', raw['warnings_and_cautions']),
        ..._sections(
          'warnings_and_cautions_table',
          raw['warnings_and_cautions_table'],
        ),
      ],
    );
  }

  List<OpenFdaLabelTextSection> _sections(String field, Object? raw) =>
      _strings(raw)
          .map((text) => OpenFdaLabelTextSection(field: field, text: text))
          .toList(growable: false);

  List<String> _strings(Object? value) => value is List
      ? value.map(_safeString).whereType<String>().toList(growable: false)
      : const <String>[];

  String? _safeString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _asInt(Object? value) => value is int ? value : int.tryParse('$value');

  int? _positiveInt(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  OpenFdaLabelNameSearch _unavailable(
    String genericName,
    DateTime retrievedAt, {
    int? failureStatusCode,
  }) => OpenFdaLabelNameSearch(
    genericName: genericName,
    state: OpenFdaLabelSearchState.unavailable,
    records: const [],
    totalAvailable: null,
    datasetLastUpdated: null,
    retrievedAt: retrievedAt,
    failureStatusCode: failureStatusCode,
  );
}
