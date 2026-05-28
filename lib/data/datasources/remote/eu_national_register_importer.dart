import '../../../domain/entities/source_metadata.dart';

/// Concrete, deterministic EU/EEA national-register medication parser.
///
/// National registers identify nationally authorised products and link to
/// product information (SmPC / package leaflet). This parser maps the
/// *register identity* (member state, product name, register id, MAH, PI
/// link) to canonical metadata. It distinguishes register identity from full
/// SmPC text: unless `has_smpc_text` is true, it records that full mechanism
/// (food-effect) text is not present. No network — caller hands a decoded map
/// to `parse`. Educational prototype; synthetic only.
class EuNationalRegisterImporter {
  EuNationalRegisterParseResult parse(Map<String, dynamic> payload) {
    final notes = <String>[];
    String s(String key) => (payload[key] ?? '').toString().trim();

    final sourceDocId =
        s('source_doc_id').isEmpty ? 'eu-nat:unknown' : s('source_doc_id');
    final memberState =
        s('member_state').isEmpty ? 'EU_MEMBER' : s('member_state');
    final language = s('language').isEmpty ? 'multi' : s('language');

    final ingredients = <String>[
      ...((payload['active_ingredients'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
    ];
    if (ingredients.isEmpty) notes.add('missing:active_ingredients');

    final registerId = s('register_id');
    if (registerId.isEmpty) notes.add('missing:register_id');

    final hasSmpc = payload['has_smpc_text'] == true;
    if (!hasSmpc) notes.add('no_smpc_text:identity_only');
    if (s('product_information_url').isEmpty) {
      notes.add('missing:product_information_url');
    }

    final confidenceRaw = payload['extraction_confidence'];
    var confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.6;
    if (notes.any((n) => n.startsWith('missing:'))) {
      confidence = (confidence - 0.05 * notes.length).clamp(0.0, 1.0);
    }

    final limitation = hasSmpc
        ? 'EU national-register entry with linked SmPC text. Synthetic demo; '
            'educational prototype, not medical advice.'
        : 'EU national-register entry provides product identity and a link to '
            'product information; full SmPC / food-effect text is not present '
            'in this record. Synthetic demo; educational prototype, not '
            'medical advice.';

    final doc = SourceDocumentMetadata(
      sourceDocId: sourceDocId,
      sourceSystem: 'EU_National_Register',
      jurisdiction: memberState,
      language: language,
      sourceOwner: s('source_owner').isEmpty
          ? 'National competent authority register'
          : s('source_owner'),
      docType: hasSmpc ? 'smpc' : 'national_register_entry',
      authorityTier: SourceAuthorityTier.officialDatabaseInJurisdiction,
      translationStatus: ReferenceTranslationStatus.notTranslation,
      publishedAt: null,
      effectiveAt: null,
      lastUpdated: null,
      licenseOrUseLimitations: 'Per-member-state terms.',
      sourceRefs: const ['src.ema.national_registers'],
      limitationText: limitation,
    );

    final variant = DrugProductVariantMetadata(
      drugProductVariantId: sourceDocId,
      sourceSystem: 'EU_National_Register',
      jurisdiction: memberState,
      language: language,
      genericName: s('generic_name'),
      brandName: payload['product_name']?.toString(),
      activeIngredients: ingredients,
      strengthValue: (payload['strength_value'] is num)
          ? (payload['strength_value'] as num).toDouble()
          : null,
      strengthUnit: s('strength_unit').isEmpty ? null : s('strength_unit'),
      doseForm: s('dose_form'),
      route: s('route'),
      releaseType: s('release_type').isEmpty ? 'unknown' : s('release_type'),
      productIdentifier: registerId.isEmpty ? null : registerId,
      labelSection: hasSmpc ? 'smpc' : null,
      translationStatus: ReferenceTranslationStatus.notTranslation,
      extractionConfidence: confidence,
      sourceRefs: const ['src.ema.national_registers'],
      limitationText: limitation,
    );

    return EuNationalRegisterParseResult(
      document: doc,
      variant: variant,
      memberState: memberState,
      marketingAuthorizationHolder: s('marketing_authorization_holder').isEmpty
          ? null
          : s('marketing_authorization_holder'),
      productInformationUrl: s('product_information_url').isEmpty
          ? null
          : s('product_information_url'),
      supportsMechanismEvidenceAlone: hasSmpc,
      normalizationNotes: List.unmodifiable(notes),
      extractionMethod: 'eu_national_register_payload_parser_v1',
    );
  }
}

class EuNationalRegisterParseResult {
  final SourceDocumentMetadata document;
  final DrugProductVariantMetadata variant;
  final String memberState;
  final String? marketingAuthorizationHolder;
  final String? productInformationUrl;
  final bool supportsMechanismEvidenceAlone;
  final List<String> normalizationNotes;
  final String extractionMethod;

  const EuNationalRegisterParseResult({
    required this.document,
    required this.variant,
    required this.memberState,
    required this.marketingAuthorizationHolder,
    required this.productInformationUrl,
    required this.supportsMechanismEvidenceAlone,
    required this.normalizationNotes,
    required this.extractionMethod,
  });
}
