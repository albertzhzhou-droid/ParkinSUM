import '../../../domain/entities/source_metadata.dart';

/// Concrete, deterministic NMPA (China) medication source parser.
///
/// Parses a synthetic NMPA-style payload (decoded JSON map) into canonical
/// metadata. Chinese-language source is authoritative; any English mapping
/// produced here is marked reference-only. No live network in tests — the
/// caller decodes the fixture/string and hands the map to `parse`. Live
/// fetch, if ever added, must stay behind the existing `SourceFetchClient`.
///
/// Educational prototype only. Synthetic data only.
class NmpaImporter {
  /// Parse a decoded NMPA-style payload map into a (document, drug-variant)
  /// metadata pair. Missing required fields are recorded in
  /// `normalizationNotes` and reduce extraction confidence rather than being
  /// invented.
  NmpaParseResult parse(Map<String, dynamic> payload) {
    final notes = <String>[];
    String s(String key) => (payload[key] ?? '').toString().trim();
    final sourceDocId =
        s('source_doc_id').isEmpty ? 'nmpa:unknown' : s('source_doc_id');
    final jurisdiction = s('jurisdiction').isEmpty ? 'CN' : s('jurisdiction');
    final language = s('language').isEmpty ? 'zh' : s('language');

    final ingredients = <String>[
      ...((payload['active_ingredients'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
    ];
    if (ingredients.isEmpty) notes.add('missing:active_ingredients');

    final strengthRaw = payload['strength_value'];
    final strength = strengthRaw is num ? strengthRaw.toDouble() : null;
    if (strength == null) notes.add('missing:strength_value');
    final unit = s('strength_unit');
    if (unit.isEmpty) notes.add('missing:strength_unit');
    final doseForm = s('dose_form');
    if (doseForm.isEmpty) notes.add('missing:dose_form');
    final route = s('route');
    final release = s('release_type').isEmpty ? 'unknown' : s('release_type');
    if (s('release_type').isEmpty) notes.add('missing:release_type');

    final translation = _translation(s('translation_status'));
    final confidenceRaw = payload['extraction_confidence'];
    var confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.4;
    // Reference-only translations and missing fields reduce confidence.
    if (translation == ReferenceTranslationStatus.referenceOnlyTranslation) {
      confidence = (confidence * 0.9).clamp(0.0, 1.0);
    }
    if (notes.isNotEmpty) {
      confidence = (confidence - 0.05 * notes.length).clamp(0.0, 1.0);
    }

    final limitation = s('limitation_text').isEmpty
        ? 'NMPA source is FIXTURE-VALIDATED, NOT live-verified: this parser '
            'reads a synthetic NMPA-style payload and has not been validated '
            'against a live NMPA schema or feed. Chinese-language source is '
            'authoritative; English mapping is reference-only. Educational '
            'prototype, not medical advice, not production ingestion.'
        : s('limitation_text');

    final doc = SourceDocumentMetadata(
      sourceDocId: sourceDocId,
      sourceSystem: 'NMPA',
      jurisdiction: jurisdiction,
      language: language,
      sourceOwner: s('source_owner').isEmpty
          ? 'National Medical Products Administration'
          : s('source_owner'),
      docType: 'drug_label',
      authorityTier: SourceAuthorityTier.officialLabelInJurisdiction,
      translationStatus: translation,
      publishedAt: s('published_at').isEmpty ? null : s('published_at'),
      effectiveAt: null,
      lastUpdated: null,
      licenseOrUseLimitations:
          'NMPA terms; Chinese-language source authoritative.',
      sourceRefs: const ['src.nmpa.database'],
      limitationText: limitation,
    );

    final variant = DrugProductVariantMetadata(
      drugProductVariantId: sourceDocId,
      sourceSystem: 'NMPA',
      jurisdiction: jurisdiction,
      language: language,
      genericName: s('generic_name'),
      brandName: payload['brand_name']?.toString(),
      activeIngredients: ingredients,
      strengthValue: strength,
      strengthUnit: unit.isEmpty ? null : unit,
      doseForm: doseForm,
      route: route,
      releaseType: release,
      productIdentifier:
          s('approval_number').isEmpty ? null : s('approval_number'),
      labelSection:
          s('label_section_zh').isEmpty ? null : s('label_section_zh'),
      translationStatus: translation,
      extractionConfidence: confidence,
      sourceRefs: const ['src.nmpa.database'],
      limitationText: limitation,
    );

    return NmpaParseResult(
      document: doc,
      variant: variant,
      normalizationNotes: List.unmodifiable(notes),
      extractionMethod: 'nmpa_synthetic_payload_parser_v1',
    );
  }

  ReferenceTranslationStatus _translation(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'reference_only_translation':
        return ReferenceTranslationStatus.referenceOnlyTranslation;
      case 'official_translation':
        return ReferenceTranslationStatus.officialTranslation;
      case 'not_translation':
        return ReferenceTranslationStatus.notTranslation;
      default:
        return ReferenceTranslationStatus.unknown;
    }
  }
}

class NmpaParseResult {
  final SourceDocumentMetadata document;
  final DrugProductVariantMetadata variant;
  final List<String> normalizationNotes;
  final String extractionMethod;

  const NmpaParseResult({
    required this.document,
    required this.variant,
    required this.normalizationNotes,
    required this.extractionMethod,
  });
}
