import '../../../domain/entities/source_metadata.dart';

/// Concrete, deterministic NHS dm+d (GB) medication identity parser.
///
/// dm+d is identity/coding-strong (SNOMED CT concept ids; VTM/VMP/AMP model)
/// but is NOT a complete product-label / food-effect source on its own. The
/// parser therefore maps to canonical drug *identity* metadata with an
/// authority tier of `drugDictionary`, and records that mechanism (food-effect)
/// evidence requires a label/SmPC source. No network — the caller decodes the
/// payload and hands the map to `parse`. Educational prototype; synthetic only.
class DmdImporter {
  DmdParseResult parse(Map<String, dynamic> payload) {
    final notes = <String>[];
    String s(String key) => (payload[key] ?? '').toString().trim();

    final sourceDocId =
        s('source_doc_id').isEmpty ? 'dmd:unknown' : s('source_doc_id');
    final jurisdiction = s('jurisdiction').isEmpty ? 'GB' : s('jurisdiction');
    final language = s('language').isEmpty ? 'en' : s('language');

    final ingredients = <String>[
      ...((payload['active_ingredients'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
    ];
    if (ingredients.isEmpty) notes.add('missing:active_ingredients');

    final productIdentifier = s('vmp_id').isNotEmpty
        ? s('vmp_id')
        : (s('amp_id').isNotEmpty
            ? s('amp_id')
            : (s('snomed_concept_id').isEmpty ? null : s('snomed_concept_id')));
    if (productIdentifier == null) notes.add('missing:product_identifier');

    final hasFoodEffect = payload['has_food_effect_label_section'] == true;
    if (!hasFoodEffect) {
      notes.add('no_food_effect_label_section:identity_only');
    }

    final confidenceRaw = payload['extraction_confidence'];
    var confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.7;
    if (notes.any((n) => n.startsWith('missing:'))) {
      confidence = (confidence - 0.05 * notes.length).clamp(0.0, 1.0);
    }

    const limitation =
        'NHS dm+d supports medicine identity and coding (SNOMED CT). It is '
        'not a complete product-label / food-effect source; mechanism '
        'evidence requires a label/SmPC source. Synthetic demo; educational '
        'prototype, not medical advice.';

    final doc = SourceDocumentMetadata(
      sourceDocId: sourceDocId,
      sourceSystem: 'NHS_DMD',
      jurisdiction: jurisdiction,
      language: language,
      sourceOwner: s('source_owner').isEmpty
          ? 'NHSBSA / NHS England'
          : s('source_owner'),
      docType: 'drug_dictionary_entry',
      authorityTier: SourceAuthorityTier.drugDictionary,
      translationStatus: ReferenceTranslationStatus.notTranslation,
      publishedAt: null,
      effectiveAt: null,
      lastUpdated: null,
      licenseOrUseLimitations:
          'dm+d licence; SNOMED CT licensing applies. Identity/coding source.',
      sourceRefs: const ['src.nhs.dmd'],
      limitationText: limitation,
    );

    final variant = DrugProductVariantMetadata(
      drugProductVariantId: sourceDocId,
      sourceSystem: 'NHS_DMD',
      jurisdiction: jurisdiction,
      language: language,
      genericName: s('generic_name'),
      brandName: payload['brand_name']?.toString(),
      activeIngredients: ingredients,
      // dm+d strengths live in VMP descriptions; identity parser does not
      // assert a numeric strength/unit unless explicitly present.
      strengthValue: (payload['strength_value'] is num)
          ? (payload['strength_value'] as num).toDouble()
          : null,
      strengthUnit: s('strength_unit').isEmpty ? null : s('strength_unit'),
      doseForm: s('dose_form'),
      route: s('route'),
      releaseType: s('release_type').isEmpty ? 'unknown' : s('release_type'),
      productIdentifier: productIdentifier,
      labelSection: null,
      translationStatus: ReferenceTranslationStatus.notTranslation,
      extractionConfidence: confidence,
      sourceRefs: const ['src.nhs.dmd'],
      limitationText: limitation,
    );

    return DmdParseResult(
      document: doc,
      variant: variant,
      supportsMechanismEvidenceAlone: hasFoodEffect,
      normalizationNotes: List.unmodifiable(notes),
      extractionMethod: 'nhs_dmd_identity_payload_parser_v1',
    );
  }
}

class DmdParseResult {
  final SourceDocumentMetadata document;
  final DrugProductVariantMetadata variant;

  /// dm+d identity alone cannot supply food-effect mechanism evidence.
  final bool supportsMechanismEvidenceAlone;
  final List<String> normalizationNotes;
  final String extractionMethod;

  const DmdParseResult({
    required this.document,
    required this.variant,
    required this.supportsMechanismEvidenceAlone,
    required this.normalizationNotes,
    required this.extractionMethod,
  });
}
