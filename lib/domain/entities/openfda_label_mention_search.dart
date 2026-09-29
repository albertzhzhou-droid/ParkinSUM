enum OpenFdaLabelSearchState { labelsReturned, noLabelsReturned, unavailable }

/// A returned label row and its unmodified selected FDA label-section text.
///
/// These fields are display-only evidence. They are not a drug interaction
/// conclusion, recommendation, rule input, or saved medication record.
final class OpenFdaLabelTextRecord {
  OpenFdaLabelTextRecord({
    required this.id,
    required this.setId,
    this.version,
    required this.effectiveTime,
    required List<String> genericNames,
    required List<String> brandNames,
    required List<OpenFdaLabelTextSection> searchedLabelSections,
  }) : genericNames = List<String>.unmodifiable(genericNames),
       brandNames = List<String>.unmodifiable(brandNames),
       searchedLabelSections = List<OpenFdaLabelTextSection>.unmodifiable(
         searchedLabelSections,
       );

  final String? id;
  final String? setId;
  final int? version;
  final String? effectiveTime;
  final List<String> genericNames;
  final List<String> brandNames;
  final List<OpenFdaLabelTextSection> searchedLabelSections;

  /// An exact-version DailyMed page only when both official identifiers have
  /// the expected shape. Copying this URI does not make a network request.
  Uri? get dailymedExactVersionUri {
    final id = setId;
    final version = this.version;
    if (id == null || version == null || version < 1 || !_isUuidSetId(id)) {
      return null;
    }
    return Uri.https('dailymed.nlm.nih.gov', '/dailymed/drugInfo.cfm', {
      'setid': id,
      'version': '$version',
    });
  }

  bool mentionsGenericName(String name) {
    return searchedSectionsMentioning(name).isNotEmpty;
  }

  List<OpenFdaLabelTextSection> searchedSectionsMentioning(String name) {
    final needle = _normalizeLabelTerm(name);
    if (needle.isEmpty) return const [];
    return List<OpenFdaLabelTextSection>.unmodifiable(
      searchedLabelSections.where((section) {
        final text = ' ${_normalizeLabelTerm(section.text)} ';
        return text.contains(' $needle ');
      }),
    );
  }
}

bool _isUuidSetId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
).hasMatch(value);

final class OpenFdaLabelTextSection {
  const OpenFdaLabelTextSection({required this.field, required this.text});

  /// API field name, for example `drug_interactions`.
  final String field;

  /// Original section text from the returned label record.
  final String text;
}

final class OpenFdaLabelNameSearch {
  OpenFdaLabelNameSearch({
    required this.genericName,
    required this.state,
    required List<OpenFdaLabelTextRecord> records,
    required this.totalAvailable,
    required this.datasetLastUpdated,
    required this.retrievedAt,
    required this.failureStatusCode,
  }) : records = List<OpenFdaLabelTextRecord>.unmodifiable(records);

  final String genericName;
  final OpenFdaLabelSearchState state;
  final List<OpenFdaLabelTextRecord> records;
  final int? totalAvailable;
  final String? datasetLastUpdated;
  final DateTime retrievedAt;

  /// HTTP status only; response bodies and request URLs are never retained.
  final int? failureStatusCode;

  bool get resultsAreSampled =>
      totalAvailable != null && totalAvailable! > records.length;

  List<OpenFdaLabelTextRecord> recordsMentioning(String otherGenericName) =>
      List<OpenFdaLabelTextRecord>.unmodifiable(
        records.where((record) => record.mentionsGenericName(otherGenericName)),
      );

  int get recordsWithSearchedLabelText =>
      records.where((record) => record.searchedLabelSections.isNotEmpty).length;
}

final class OpenFdaLabelMentionSearchResult {
  const OpenFdaLabelMentionSearchResult({
    required this.firstGenericName,
    required this.secondGenericName,
    required this.firstLabels,
    required this.secondLabels,
  });

  final String firstGenericName;
  final String secondGenericName;
  final OpenFdaLabelNameSearch firstLabels;
  final OpenFdaLabelNameSearch secondLabels;

  /// Names in the first drug's returned selected label sections that
  /// literally contain the second entered name. This text search does not
  /// establish an interaction or its direction, severity, applicability, or
  /// absence.
  List<OpenFdaLabelTextRecord> get firstLabelsMentioningSecond =>
      firstLabels.recordsMentioning(secondGenericName);

  List<OpenFdaLabelTextRecord> get secondLabelsMentioningFirst =>
      secondLabels.recordsMentioning(firstGenericName);
}

String _normalizeLabelTerm(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
