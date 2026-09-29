import 'dart:math' as math;

import '../../core/analysis/catalog_search_index.dart';
import '../entities/cdss_records.dart';

/// A locally ordered source-metadata match. The score is intentionally not
/// exposed: lexical order is not evidence quality, applicability, or truth.
class EvidenceSourceMetadataSearchHit {
  final SourceDocumentRecord source;
  final List<String> matchedTerms;

  EvidenceSourceMetadataSearchHit({
    required this.source,
    required Iterable<String> matchedTerms,
  }) : matchedTerms = List<String>.unmodifiable(matchedTerms);
}

/// Fielded BM25F-style search over source metadata only.
///
/// This index deliberately excludes source payloads, external URLs, hashes,
/// account state, and patient data. It is a source-finding aid, not a clinical
/// retrieval or decision-support engine.
class EvidenceSourceMetadataSearch {
  static const int maxQueryCodePoints = 160;
  static const int maxQueryTerms = 16;
  static const int maxResults = 20;
  static const double _k1 = 1.2;
  static const double _b = 0.75;

  static const Map<String, double> _fieldWeights = <String, double>{
    'title': 3.0,
    'organization': 1.5,
    'sourceFamily': 1.0,
    'docType': 1.0,
    'jurisdiction': 0.7,
    'language': 0.5,
    'licenseNote': 0.25,
  };

  final List<_IndexedEvidenceSource> _documents;
  final Map<String, double> _averageFieldLengths;
  final Map<String, int> _documentFrequency;

  EvidenceSourceMetadataSearch({
    required Iterable<SourceDocumentRecord> sources,
  }) : _documents = _indexSources(sources),
       _averageFieldLengths = <String, double>{},
       _documentFrequency = <String, int>{} {
    final totals = <String, int>{
      for (final field in _fieldWeights.keys) field: 0,
    };
    for (final document in _documents) {
      for (final field in _fieldWeights.keys) {
        totals[field] = totals[field]! + document.fieldLengths[field]!;
      }
      for (final term in document.terms) {
        _documentFrequency.update(
          term,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    for (final field in _fieldWeights.keys) {
      _averageFieldLengths[field] = _documents.isEmpty
          ? 1
          : (totals[field]! / _documents.length)
                .clamp(1, double.infinity)
                .toDouble();
    }
  }

  List<EvidenceSourceMetadataSearchHit> search(String query, {int limit = 10}) {
    if (limit < 1 || limit > maxResults) {
      throw ArgumentError.value(
        limit,
        'limit',
        'must be from 1 to $maxResults',
      );
    }
    if (query.runes.length > maxQueryCodePoints) {
      throw ArgumentError.value(
        query.length,
        'query',
        'must be at most $maxQueryCodePoints Unicode code points',
      );
    }
    final terms = normalizeCatalogSearchText(
      query,
    ).split(' ').where((term) => term.isNotEmpty).toSet().toList()..sort();
    if (terms.isEmpty) return const <EvidenceSourceMetadataSearchHit>[];
    if (terms.length > maxQueryTerms) {
      throw ArgumentError.value(
        terms.length,
        'query',
        'must contain at most $maxQueryTerms distinct terms',
      );
    }

    final scored =
        <
          ({
            _IndexedEvidenceSource document,
            double score,
            List<String> matchedTerms,
          })
        >[];
    for (final document in _documents) {
      var score = 0.0;
      final matchedTerms = <String>[];
      for (final term in terms) {
        var weightedFrequency = 0.0;
        for (final entry in _fieldWeights.entries) {
          final field = entry.key;
          final frequency = document.termFrequencies[field]![term] ?? 0;
          if (frequency == 0) continue;
          final fieldLength = document.fieldLengths[field]!;
          final averageLength = _averageFieldLengths[field]!;
          final lengthNormalization =
              (1 - _b) + _b * fieldLength / averageLength;
          weightedFrequency += entry.value * frequency / lengthNormalization;
        }
        if (weightedFrequency == 0) continue;
        matchedTerms.add(term);
        final documentCount = _documents.length;
        final frequency = _documentFrequency[term] ?? 0;
        final inverseDocumentFrequency = math.log(
          1 + (documentCount - frequency + 0.5) / (frequency + 0.5),
        );
        score +=
            inverseDocumentFrequency *
            ((_k1 + 1) * weightedFrequency) /
            (_k1 + weightedFrequency);
      }
      if (matchedTerms.isNotEmpty && score.isFinite && score > 0) {
        scored.add((
          document: document,
          score: score,
          matchedTerms: List<String>.unmodifiable(matchedTerms),
        ));
      }
    }
    scored.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      return byScore != 0
          ? byScore
          : left.document.source.sourceDocId.compareTo(
              right.document.source.sourceDocId,
            );
    });
    return List<EvidenceSourceMetadataSearchHit>.unmodifiable(
      scored
          .take(limit)
          .map(
            (row) => EvidenceSourceMetadataSearchHit(
              source: row.document.source,
              matchedTerms: row.matchedTerms,
            ),
          ),
    );
  }

  static List<_IndexedEvidenceSource> _indexSources(
    Iterable<SourceDocumentRecord> sources,
  ) {
    final rows = sources.toList(growable: false);
    final ids = <String>{};
    for (final source in rows) {
      final id = source.sourceDocId.trim();
      if (id.isEmpty || !ids.add(id)) {
        throw ArgumentError.value(
          source.sourceDocId,
          'sources',
          'source document IDs must be non-empty and unique',
        );
      }
    }
    return List<_IndexedEvidenceSource>.unmodifiable(
      rows.map(_IndexedEvidenceSource.new),
    );
  }
}

class _IndexedEvidenceSource {
  final SourceDocumentRecord source;
  final Map<String, Map<String, int>> termFrequencies;
  final Map<String, int> fieldLengths;
  final Set<String> terms;

  _IndexedEvidenceSource(this.source)
    : termFrequencies = <String, Map<String, int>>{},
      fieldLengths = <String, int>{},
      terms = <String>{} {
    final fields = <String, String>{
      'title': source.title,
      'organization': source.organization,
      'sourceFamily': source.sourceFamily,
      'docType': source.docType,
      'jurisdiction': source.jurisdiction,
      'language': source.language,
      'licenseNote': source.licenseNote,
    };
    for (final field in EvidenceSourceMetadataSearch._fieldWeights.keys) {
      final tokens = normalizeCatalogSearchText(
        fields[field]!,
      ).split(' ').where((token) => token.isNotEmpty);
      final frequencies = <String, int>{};
      for (final token in tokens) {
        frequencies.update(token, (count) => count + 1, ifAbsent: () => 1);
        terms.add(token);
      }
      termFrequencies[field] = Map<String, int>.unmodifiable(frequencies);
      fieldLengths[field] = frequencies.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
    }
  }
}
