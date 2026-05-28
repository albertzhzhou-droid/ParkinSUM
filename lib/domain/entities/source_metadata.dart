/// Canonical, projection-surviving source/provenance metadata for the
/// multi-jurisdiction data flow.
///
/// The existing `cdss_records.dart` records carry most raw fields; these
/// typed objects are the view that survives projection into runtime
/// candidate/medication-context models so the mechanistic engine and the
/// next-meal scorer can see jurisdiction, language, authority, and
/// completeness. Educational prototype only — no clinical claims.
library;

/// Deterministic authority tier for a source. Higher = more authoritative
/// for its own jurisdiction. NOT a regulatory ranking; an educational
/// heuristic.
enum SourceAuthorityTier {
  officialLabelInJurisdiction, // SmPC / monograph / package insert / SPL
  officialDatabaseInJurisdiction, // DPD / dm+d / national register
  officialOutOfJurisdiction,
  referenceTranslation, // e.g. PMDA English index marked reference-only
  drugDictionary, // identity/coding strong, food-effect weak
  foodCompositionTable,
  seedOrManualDemo,
  syntheticDemo,
  unknown,
}

/// Completeness of a metadata bundle for a given use (medication context,
/// meal composition, candidate scoring, projection readiness, explanation).
enum MetadataCompletenessScore {
  complete,
  sufficient,
  partial,
  insufficient,
  invalid,
}

/// Status of a cross-jurisdiction comparison.
enum CrossJurisdictionConflictStatus {
  none,
  sameJurisdiction,
  differentJurisdictionNoConflict,
  differentJurisdictionConflict,
  unknown,
}

/// Reference translation status, important for PMDA/NMPA non-English sources.
enum ReferenceTranslationStatus {
  notTranslation,
  officialTranslation,
  referenceOnlyTranslation,
  unknown,
}

class SourceDocumentMetadata {
  final String sourceDocId;
  final String sourceSystem;
  final String jurisdiction;
  final String language;
  final String sourceOwner;
  final String docType;
  final SourceAuthorityTier authorityTier;
  final ReferenceTranslationStatus translationStatus;
  final String? publishedAt;
  final String? effectiveAt;
  final String? lastUpdated;
  final String licenseOrUseLimitations;
  final List<String> sourceRefs;
  final String limitationText;

  const SourceDocumentMetadata({
    required this.sourceDocId,
    required this.sourceSystem,
    required this.jurisdiction,
    required this.language,
    required this.sourceOwner,
    required this.docType,
    required this.authorityTier,
    required this.translationStatus,
    required this.publishedAt,
    required this.effectiveAt,
    required this.lastUpdated,
    required this.licenseOrUseLimitations,
    required this.sourceRefs,
    required this.limitationText,
  });

  bool get isSyntheticOrSeed =>
      authorityTier == SourceAuthorityTier.seedOrManualDemo ||
      authorityTier == SourceAuthorityTier.syntheticDemo;

  Map<String, dynamic> toJson() => {
        'source_doc_id': sourceDocId,
        'source_system': sourceSystem,
        'jurisdiction': jurisdiction,
        'language': language,
        'source_owner': sourceOwner,
        'doc_type': docType,
        'authority_tier': authorityTier.name,
        'translation_status': translationStatus.name,
        'published_at': publishedAt,
        'effective_at': effectiveAt,
        'last_updated': lastUpdated,
        'license_or_use_limitations': licenseOrUseLimitations,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
      };
}

/// Canonical drug-product metadata (projection-surviving).
class DrugProductVariantMetadata {
  final String drugProductVariantId;
  final String sourceSystem;
  final String jurisdiction;
  final String language;
  final String genericName;
  final String? brandName;
  final List<String> activeIngredients;
  final double? strengthValue;
  final String? strengthUnit;
  final String doseForm;
  final String route;
  final String releaseType; // immediate/extended/controlled/unknown
  final String? productIdentifier; // NDC/DIN/EMA #/dm+d/PMDA/NMPA/local
  final String? labelSection;
  final ReferenceTranslationStatus translationStatus;
  final double? extractionConfidence;
  final List<String> sourceRefs;
  final String limitationText;

  const DrugProductVariantMetadata({
    required this.drugProductVariantId,
    required this.sourceSystem,
    required this.jurisdiction,
    required this.language,
    required this.genericName,
    required this.brandName,
    required this.activeIngredients,
    required this.strengthValue,
    required this.strengthUnit,
    required this.doseForm,
    required this.route,
    required this.releaseType,
    required this.productIdentifier,
    required this.labelSection,
    required this.translationStatus,
    required this.extractionConfidence,
    required this.sourceRefs,
    required this.limitationText,
  });

  Map<String, dynamic> toJson() => {
        'drug_product_variant_id': drugProductVariantId,
        'source_system': sourceSystem,
        'jurisdiction': jurisdiction,
        'language': language,
        'generic_name': genericName,
        'brand_name': brandName,
        'active_ingredients': activeIngredients,
        'strength_value': strengthValue,
        'strength_unit': strengthUnit,
        'dose_form': doseForm,
        'route': route,
        'release_type': releaseType,
        'product_identifier': productIdentifier,
        'label_section': labelSection,
        'translation_status': translationStatus.name,
        'extraction_confidence': extractionConfidence,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
      };
}

/// Canonical food-variant metadata (projection-surviving).
class FoodVariantMetadata {
  final String foodVariantId;
  final String sourceSystem;
  final String jurisdiction;
  final String language;
  final String foodName;
  final String? basisType; // per_100g / per_serving / per_meal / label_claim
  final String? servingUnit;
  final String preparationState; // raw/cooked/branded/generic/unknown
  final bool aminoAcidFieldsPresent;
  final double? extractionConfidence;
  final List<String> sourceRefs;
  final String limitationText;

  const FoodVariantMetadata({
    required this.foodVariantId,
    required this.sourceSystem,
    required this.jurisdiction,
    required this.language,
    required this.foodName,
    required this.basisType,
    required this.servingUnit,
    required this.preparationState,
    required this.aminoAcidFieldsPresent,
    required this.extractionConfidence,
    required this.sourceRefs,
    required this.limitationText,
  });

  Map<String, dynamic> toJson() => {
        'food_variant_id': foodVariantId,
        'source_system': sourceSystem,
        'jurisdiction': jurisdiction,
        'language': language,
        'food_name': foodName,
        'basis_type': basisType,
        'serving_unit': servingUnit,
        'preparation_state': preparationState,
        'amino_acid_fields_present': aminoAcidFieldsPresent,
        'extraction_confidence': extractionConfidence,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
      };
}
