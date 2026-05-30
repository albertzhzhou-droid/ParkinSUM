/// Local, **FHIR-inspired** (NOT FHIR-conformant) serialization view of a
/// medication *product* and its source provenance.
///
/// Educational/research prototype only. This view exists for local educational
/// traceability and reviewability; it does **not** claim HL7 FHIR conformance
/// or clinical interoperability, and it is **not** a clinical record.
///
/// HL7 FHIR `MedicationKnowledge` (R5) is a clinical knowledge resource that
/// sits inside medication-request / administration / dispensing workflows. This
/// view DELIBERATELY OMITS every patient-care semantic: no `patient`, `subject`,
/// `encounter`, `practitioner`, `careTeam`, `MedicationRequest`,
/// `MedicationAdministration`, `dosageInstruction`, timing, prescription, or
/// recommendation. It serializes only synthetic/demo product metadata +
/// provenance.
///
/// **Dose boundary:** product strength here is *product label metadata* (what
/// the manufactured product contains). It is NOT a user intake dose and must
/// never be presented as what a person took or should take. There is no field
/// for a user-taken dose, frequency, or timing.
///
/// No PHI is ever emitted. The `phiPolicy` field names what is omitted; that is
/// evidence of compliance, not a violation — tests assert the absence of
/// patient-linkage *keys*, not the literal words in this policy string.
library;

/// One active/adjunct component of a (possibly combination) product, e.g.
/// carbidopa + levodopa. Per-component strength is nullable and copied as-is:
/// when the source carries only a single product-level strength, per-component
/// strength stays null (missing ≠ fabricated). Strength is product metadata.
class FhirInspiredMedicationComponentEntry {
  final String ingredientName;
  final String ingredientRole;
  final double? strengthValue;
  final String? strengthUnit;

  /// Marks the strength as product label metadata, never an intake dose.
  final String strengthBasis;
  final List<String> sourceRefs;

  /// Section ids/keys (from the product's label section refs) that back this
  /// component; empty when none are carried.
  final List<String> labelSectionRefs;
  final String? limitationText;

  const FhirInspiredMedicationComponentEntry({
    required this.ingredientName,
    required this.ingredientRole,
    required this.strengthValue,
    required this.strengthUnit,
    this.strengthBasis =
        FhirInspiredMedicationKnowledgeView.kStrengthIsProductMetadata,
    required this.sourceRefs,
    required this.labelSectionRefs,
    required this.limitationText,
  });

  Map<String, dynamic> toJson() => {
        'ingredient_name': ingredientName,
        'ingredient_role': ingredientRole,
        'strength_value': strengthValue,
        'strength_unit': strengthUnit,
        'strength_basis': strengthBasis,
        'source_refs': sourceRefs,
        'label_section_refs': labelSectionRefs,
        'limitation_text': limitationText,
      };
}

/// A reference to a labeled section of an official product-information document
/// (SPL / SmPC / monograph) backing a product attribute. Provenance only — it
/// does not assert clinical validity, and a section is listed only when the
/// source record actually carries it.
class FhirInspiredLabelSectionRef {
  final String sourceSystem;
  final String sourceDocId;
  final String sectionId;

  /// Section *code* slot — the original CDSS section key (source identity,
  /// never overwritten).
  final String? sectionCode;

  /// Discrete **LOINC** document-section code, when the section key/title maps
  /// to a known, stable FDA SPL heading; null otherwise (never guessed). A
  /// missing LOINC code does not invalidate the section provenance above.
  final String? loincCode;

  /// LOINC display name, when [loincCode] is present.
  final String? loincDisplay;

  /// `mapped` / `unknown` — the confidence of the LOINC mapping.
  final String loincMappingConfidence;

  final String sectionTitle;
  final String? sectionPath;
  final String jurisdiction;
  final String language;
  final List<String> sourceRefs;
  final String? limitationText;

  const FhirInspiredLabelSectionRef({
    required this.sourceSystem,
    required this.sourceDocId,
    required this.sectionId,
    required this.sectionCode,
    this.loincCode,
    this.loincDisplay,
    this.loincMappingConfidence = 'unknown',
    required this.sectionTitle,
    required this.sectionPath,
    required this.jurisdiction,
    required this.language,
    required this.sourceRefs,
    required this.limitationText,
  });

  Map<String, dynamic> toJson() => {
        'source_system': sourceSystem,
        'source_doc_id': sourceDocId,
        'section_id': sectionId,
        'section_code': sectionCode,
        'loinc_code': loincCode,
        'loinc_display': loincDisplay,
        'loinc_mapping_confidence': loincMappingConfidence,
        'section_title': sectionTitle,
        'section_path': sectionPath,
        'jurisdiction': jurisdiction,
        'language': language,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
      };
}

/// Source document descriptor (no patient/encounter linkage).
class FhirInspiredSourceDocument {
  final String sourceDocId;
  final String? sourceDocVersion;
  final String? effectiveDate;

  const FhirInspiredSourceDocument({
    required this.sourceDocId,
    required this.sourceDocVersion,
    required this.effectiveDate,
  });

  Map<String, dynamic> toJson() => {
        'source_doc_id': sourceDocId,
        'source_doc_version': sourceDocVersion,
        'effective_date': effectiveDate,
      };
}

/// Top-level FHIR-inspired MedicationKnowledge view. Deterministic JSON;
/// PHI-free; product metadata only (no patient-care semantics, no intake dose).
class FhirInspiredMedicationKnowledgeView {
  /// Constant view-type marker.
  static const String kViewType = 'fhir_inspired_medication_knowledge';

  /// Constant conformance marker — inspired, NOT FHIR-conformant.
  static const String kConformanceStatus = 'inspired_not_conformant';

  /// Constant PHI policy — no patient, no administration event, no PHI.
  static const String kPhiPolicy = 'no_patient_no_administration_no_phi';

  /// Marks any strength value as product label metadata, never an intake dose.
  static const String kStrengthIsProductMetadata = 'product_label_metadata';

  final String demoDrugProductId;
  final String sourceSystem;
  final String jurisdiction;
  final String language;
  final String? productName;
  final String? genericName;
  final String? brandName;
  final List<String> activeIngredients;
  final List<FhirInspiredMedicationComponentEntry> combinationComponents;
  final List<FhirInspiredMedicationComponentEntry> strengths;
  final String doseForm;
  final String route;
  final String releaseType;
  final String releaseTypeSource;
  final FhirInspiredSourceDocument sourceDocument;
  final List<FhirInspiredLabelSectionRef> labelSectionRefs;
  final List<String> sourceRefs;
  final String metadataCompleteness;
  final double? sourceAuthorityScore;
  final String provenanceSummary;
  final String limitationText;
  final bool notClinicallyCalibrated;
  final String notAdviceText;
  final String safetyBoundary;

  const FhirInspiredMedicationKnowledgeView({
    required this.demoDrugProductId,
    required this.sourceSystem,
    required this.jurisdiction,
    required this.language,
    required this.productName,
    required this.genericName,
    required this.brandName,
    required this.activeIngredients,
    required this.combinationComponents,
    required this.strengths,
    required this.doseForm,
    required this.route,
    required this.releaseType,
    required this.releaseTypeSource,
    required this.sourceDocument,
    required this.labelSectionRefs,
    required this.sourceRefs,
    required this.metadataCompleteness,
    required this.sourceAuthorityScore,
    required this.provenanceSummary,
    required this.limitationText,
    required this.notClinicallyCalibrated,
    required this.notAdviceText,
    required this.safetyBoundary,
  });

  Map<String, dynamic> toJson() => {
        'view_type': kViewType,
        'conformance_status': kConformanceStatus,
        'phi_policy': kPhiPolicy,
        'demo_drug_product_id': demoDrugProductId,
        'source_system': sourceSystem,
        'jurisdiction': jurisdiction,
        'language': language,
        'product_name': productName,
        'generic_name': genericName,
        'brand_name': brandName,
        'active_ingredients': activeIngredients,
        'combination_components': combinationComponents
            .map((e) => e.toJson())
            .toList(growable: false),
        'strengths': strengths.map((e) => e.toJson()).toList(growable: false),
        'dose_form': doseForm,
        'route': route,
        'release_type': releaseType,
        'release_type_source': releaseTypeSource,
        'source_document': sourceDocument.toJson(),
        'label_section_refs':
            labelSectionRefs.map((e) => e.toJson()).toList(growable: false),
        'source_refs': sourceRefs,
        'metadata_completeness': metadataCompleteness,
        'source_authority_score': sourceAuthorityScore,
        'provenance_summary': provenanceSummary,
        'limitation_text': limitationText,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'not_advice_text': notAdviceText,
        'safety_boundary': safetyBoundary,
      };
}
