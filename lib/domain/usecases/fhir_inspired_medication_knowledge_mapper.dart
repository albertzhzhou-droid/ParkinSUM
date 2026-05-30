import '../entities/fhir_inspired_medication_knowledge_view.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/medication_source_metadata.dart';
import '../entities/rule_explanation.dart';
import 'label_section_code_mapper.dart';

/// Maps ParkinSUM's engine-facing `MechanisticMedicationMetadata` (the
/// provenance bridged from the CDSS importer layer in PR #33) into a local,
/// **FHIR-inspired** (NOT FHIR-conformant), PHI-free
/// `FhirInspiredMedicationKnowledgeView`.
///
/// Educational/research prototype only. The mapper:
/// - preserves combination components (carbidopa + levodopa both kept);
/// - preserves `sourceRefs`, label section refs, release type + source,
///   dose form, route, source-document id/version/effective date, and the
///   metadata-completeness grade;
/// - copies per-component strength as-is **including null** (missing strength is
///   recorded, never fabricated);
/// - marks every strength as `product_label_metadata` — product strength is
///   product metadata, NOT a user intake dose;
/// - **omits** patient / subject / encounter / practitioner / careTeam /
///   MedicationRequest / MedicationAdministration / dosageInstruction / timing —
///   it never constructs any of them;
/// - marks the output `inspired_not_conformant` + `no_patient_no_administration_no_phi`;
/// - reuses the shared non-prescriptive safety copy.
///
/// Pure and deterministic: no I/O, no clock. `sourceAuthorityScore` is only set
/// when a caller supplies it (the metadata itself does not carry one).
class FhirInspiredMedicationKnowledgeMapper {
  const FhirInspiredMedicationKnowledgeMapper();

  static const LabelSectionCodeMapper _sectionCodeMapper =
      LabelSectionCodeMapper();

  FhirInspiredMedicationKnowledgeView fromMechanisticMetadata(
    MechanisticMedicationMetadata meta, {
    required String demoDrugProductId,
    String? productName,
    String? genericName,
    String? brandName,
    double? sourceAuthorityScore,
  }) {
    // Section ids/keys carried by the product, used to back components.
    final sectionRefIds = <String>{
      for (final s in meta.labelSectionRefs) s.sectionId,
      for (final s in meta.labelSectionRefs) s.sectionKey,
    }.where((s) => s.isNotEmpty).toList(growable: false)
      ..sort();

    final components = meta.components
        .map((c) => _componentEntry(c, sectionRefIds))
        .toList(growable: false);

    // Strengths = components that actually carry a strength value (product
    // metadata). Components with only product-level strength stay out of the
    // strengths list and remain recorded as missing in combinationComponents.
    final strengths = components
        .where((c) => c.strengthValue != null)
        .toList(growable: false);

    final activeIngredients = <String>{
      for (final c in meta.components) c.ingredientName,
    }.toList(growable: false)
      ..sort();

    final labelSectionRefs =
        meta.labelSectionRefs.map(_labelSectionRef).toList(growable: false);

    // Union of metadata + component source refs (no new ref is minted).
    final sourceRefs = <String>{
      ...meta.sourceRefs,
      for (final c in meta.components) ...c.sourceRefs,
      for (final s in meta.labelSectionRefs) ...s.sourceRefs,
    }.toList(growable: false)
      ..sort();

    final provenanceSummary = 'release_type_source=${meta.releaseTypeSource}; '
        'label_section_refs=${meta.labelSectionRefs.length}; '
        'components=${meta.components.length}; '
        'metadata_completeness=${meta.metadataCompleteness}; '
        'missing_fields=${meta.missingFields.length}';

    return FhirInspiredMedicationKnowledgeView(
      demoDrugProductId: demoDrugProductId,
      sourceSystem: meta.sourceSystem,
      jurisdiction: meta.jurisdiction,
      language: meta.language,
      productName: productName,
      genericName: genericName,
      brandName: brandName,
      activeIngredients: activeIngredients,
      combinationComponents: components,
      strengths: strengths,
      doseForm: meta.doseForm,
      route: meta.route,
      releaseType: meta.releaseType,
      releaseTypeSource: meta.releaseTypeSource,
      sourceDocument: FhirInspiredSourceDocument(
        sourceDocId: meta.sourceDocId,
        sourceDocVersion: meta.sourceDocVersion,
        effectiveDate: meta.effectiveDate,
      ),
      labelSectionRefs: labelSectionRefs,
      sourceRefs: sourceRefs,
      metadataCompleteness: meta.metadataCompleteness,
      sourceAuthorityScore: sourceAuthorityScore,
      provenanceSummary: provenanceSummary,
      limitationText: meta.limitationText,
      notClinicallyCalibrated: true,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
    );
  }

  /// Convenience: map from a normalized medication context. Returns null when
  /// no provenance metadata is attached (the bridge was not exercised) — the
  /// caller decides what to do, and the dose path is never read here.
  FhirInspiredMedicationKnowledgeView? fromNormalizedContext(
    NormalizedMedicationContext ctx, {
    required String demoDrugProductId,
    String? productName,
    String? genericName,
    String? brandName,
    double? sourceAuthorityScore,
  }) {
    final meta = ctx.metadata;
    if (meta == null) return null;
    return fromMechanisticMetadata(
      meta,
      demoDrugProductId: demoDrugProductId,
      productName: productName,
      genericName: genericName,
      brandName: brandName,
      sourceAuthorityScore: sourceAuthorityScore,
    );
  }

  FhirInspiredMedicationComponentEntry _componentEntry(
    MedicationComponent c,
    List<String> productSectionRefIds,
  ) {
    return FhirInspiredMedicationComponentEntry(
      ingredientName: c.ingredientName,
      ingredientRole: c.role,
      // Copied as-is including null: missing per-component strength is recorded,
      // not fabricated. This is product metadata, not an intake dose.
      strengthValue: c.strengthValue,
      strengthUnit: c.strengthUnit,
      sourceRefs: c.sourceRefs,
      labelSectionRefs: productSectionRefIds,
      limitationText: c.hasMissingStrength
          ? 'Per-component strength not carried by the source record; recorded '
              'as missing (not fabricated). Product metadata only.'
          : null,
    );
  }

  FhirInspiredLabelSectionRef _labelSectionRef(LabelSectionRef s) {
    // Conservative LOINC mapping from the CDSS section key/title. Unknown stays
    // unknown (never guessed); the original section key is preserved as
    // section_code. When a LOINC code is found, its source citation is unioned
    // into the ref's sourceRefs (sorted, deduped).
    final code = _sectionCodeMapper.map(
      sectionKey: s.sectionKey,
      sectionTitle: s.sectionTitle.isEmpty ? null : s.sectionTitle,
    );
    final refs = <String>{...s.sourceRefs, ...code.sourceRefs}
        .toList(growable: false)
      ..sort();
    return FhirInspiredLabelSectionRef(
      sourceSystem: s.sourceSystem,
      sourceDocId: s.sourceDocId,
      sectionId: s.sectionId,
      // CDSS section key occupies the section-code slot (source identity).
      sectionCode: s.sectionKey.isEmpty ? null : s.sectionKey,
      loincCode: code.loincCode,
      loincDisplay: code.loincDisplay,
      loincMappingConfidence: code.mappingConfidence.name,
      sectionTitle: s.sectionTitle,
      sectionPath: s.sectionPath,
      jurisdiction: s.jurisdiction,
      language: s.language,
      sourceRefs: refs,
      limitationText: s.limitationText,
    );
  }
}
