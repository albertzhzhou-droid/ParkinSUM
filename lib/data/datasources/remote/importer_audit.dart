/// Shared importer-side audit metadata helpers.
///
/// Importers attach this metadata onto:
/// - `source_document.raw_payload` (per-source-document audit summary), or
/// - `ConceptVariantCrosswalkRecord.mappingPayloadJson` (per-crosswalk
///   confidence reason + source identifier type).
///
/// These helpers intentionally live in the importer layer only. Core services
/// (CDSS, resolver, release readiness) should consume them as opaque JSON
/// blobs through the existing `P0ImportBundle` boundary.
class ImporterAudit {
  const ImporterAudit._();

  /// Stable taxonomy for `source_identifier_type` keys recorded inside
  /// `mapping_payload_json`. Keeping the taxonomy local prevents importers
  /// from drifting into ad-hoc strings.
  static const sourceIdTypeAuthoritativeProductCode =
      'authoritative_product_code';
  static const sourceIdTypeAuthoritativeFoodCode = 'authoritative_food_code';
  static const sourceIdTypePackageOrPortionCode = 'package_or_portion_code';
  static const sourceIdTypeRegulatorMetadataUrl = 'regulator_metadata_url';
  static const sourceIdTypeRegulatorDocumentUrl = 'regulator_document_url';
  static const sourceIdTypeRegulatorMonographUrl = 'regulator_monograph_url';
  static const sourceIdTypeReferenceTranslationUrl =
      'reference_translation_url';
  static const sourceIdTypePageIdentifier = 'page_identifier';
  static const sourceIdTypeCountryDietProfile = 'country_diet_profile';
  static const sourceIdTypeMetadataAttribute = 'metadata_attribute';

  /// Standard envelope for explaining why a particular crosswalk row was
  /// emitted at the given confidence value.
  static Map<String, Object?> confidenceReason({
    required String sourceIdentifierType,
    required String reason,
    String? promotionDecision,
    List<String> promotedFields = const <String>[],
    List<String> nonPromotedFields = const <String>[],
    String? parserLimitation,
  }) {
    return <String, Object?>{
      'source_identifier_type': sourceIdentifierType,
      'confidence_reason': reason,
      'promoted_fields': promotedFields,
      'non_promoted_fields': nonPromotedFields,
      if (promotionDecision != null) 'promotion_decision': promotionDecision,
      if (parserLimitation != null) 'parser_limitation': parserLimitation,
    };
  }

  /// Fills the standard importer-side audit envelope for a crosswalk row.
  ///
  /// Individual importers should still provide source-specific reasons when
  /// they know them. This fallback keeps older and low-risk crosswalks from
  /// drifting into partially documented payloads.
  static Map<String, Object?> crosswalkPayload({
    required String externalIdSystem,
    required Map<String, Object?> payload,
  }) {
    final normalized = Map<String, Object?>.from(payload);
    normalized.putIfAbsent(
      'source_identifier_type',
      () => _inferSourceIdentifierType(externalIdSystem),
    );
    normalized.putIfAbsent(
      'confidence_reason',
      () => 'Identifier copied verbatim from importer-local source field.',
    );
    normalized.putIfAbsent(
      'promoted_fields',
      () => <String>['external_id_system', 'external_id_value'],
    );
    normalized.putIfAbsent('non_promoted_fields', () => const <String>[]);
    normalized.putIfAbsent('parser_limitation', () => null);
    final inferredLocator = _inferSourceLocator(normalized);
    if (inferredLocator != null) {
      normalized.putIfAbsent('source_locator', () => inferredLocator);
    }
    return normalized;
  }

  /// Picks the best available URL-like value out of an importer-supplied
  /// payload so every crosswalk row exposes a consistent `source_locator` key
  /// when one is reasonably available. Returns `null` when no locator can be
  /// derived (e.g. for purely identifier-only crosswalks).
  static String? _inferSourceLocator(Map<String, Object?> payload) {
    if (payload['source_locator'] is String &&
        (payload['source_locator'] as String).isNotEmpty) {
      return payload['source_locator'] as String;
    }
    const candidateKeys = <String>[
      'source_url',
      'origin_url',
      'medicine_url',
      'detail_url',
      'document_url',
      'monograph_url',
      'page_url',
    ];
    for (final key in candidateKeys) {
      final value = payload[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Standard envelope for explaining why a field was *not* promoted into a
  /// structured fact / table. Importers attach this inside
  /// `source_document.raw_payload` audit_gap entries.
  static Map<String, Object?> auditGap({
    required String fieldName,
    required String reason,
    int? observedCount,
    List<String>? observedKeys,
  }) {
    return <String, Object?>{
      'field': fieldName,
      'reason': reason,
      if (observedCount != null) 'observed_count': observedCount,
      if (observedKeys != null && observedKeys.isNotEmpty)
        'observed_keys': observedKeys,
    };
  }

  static String _inferSourceIdentifierType(String externalIdSystem) {
    final lower = externalIdSystem.toLowerCase();
    if (lower.contains('url')) {
      if (lower.contains('monograph')) {
        return sourceIdTypeRegulatorMonographUrl;
      }
      if (lower.contains('document') || lower.contains('smpc')) {
        return sourceIdTypeRegulatorDocumentUrl;
      }
      if (lower.contains('translation') || lower.contains('leaflet')) {
        return sourceIdTypeReferenceTranslationUrl;
      }
      return sourceIdTypeRegulatorMetadataUrl;
    }
    if (lower.contains('package') ||
        lower.contains('ndc') ||
        lower.contains('upc') ||
        lower.contains('portion')) {
      return sourceIdTypePackageOrPortionCode;
    }
    if (lower.contains('food code') || lower.contains('fdc id')) {
      return sourceIdTypeAuthoritativeFoodCode;
    }
    if (lower.contains('page id')) return sourceIdTypePageIdentifier;
    if (lower.contains('country code')) return sourceIdTypeCountryDietProfile;
    if (lower.contains('product') ||
        lower.contains('din') ||
        lower.contains('drug_code')) {
      return sourceIdTypeAuthoritativeProductCode;
    }
    return sourceIdTypeMetadataAttribute;
  }
}
