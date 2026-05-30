import '../entities/evidence_trace_bundle.dart';
import '../entities/fhir_inspired_medication_knowledge_view.dart';
import '../entities/fhir_inspired_nutrition_intake_view.dart';
import '../entities/rule_explanation.dart';

/// Builds a **ParkinSUM-local** `EvidenceTraceBundle` from the two FHIR-inspired,
/// PHI-free views.
///
/// Educational/research prototype only. The builder:
/// - pairs the already-PHI-free NutritionIntake + MedicationKnowledge views
///   (either may be null);
/// - unions both sides' `sourceRefs` (sorted, deduped) — no new ref is minted;
/// - summarizes missingness from both sides;
/// - reuses the shared non-prescriptive safety copy;
/// - never constructs a FHIR Bundle / Patient / subject / encounter; never adds
///   dose, timing, prescription, or administration semantics.
///
/// Pure and deterministic: no I/O, no clock. `createdAt` is caller-supplied
/// (never a real patient timeline).
class EvidenceTraceBundleBuilder {
  const EvidenceTraceBundleBuilder();

  EvidenceTraceBundle build({
    required String bundleId,
    required String createdAt,
    FhirInspiredNutritionIntakeView? nutritionView,
    FhirInspiredMedicationKnowledgeView? medicationKnowledgeView,
    MechanisticTraceSummary? mechanisticTraceSummary,
  }) {
    final sourceRefs = <String>{
      ...?nutritionView?.sourceRefs,
      ...?medicationKnowledgeView?.sourceRefs,
    }.toList(growable: false)
      ..sort();

    // Missingness summary draws only on what each view already records (missing
    // ≠ fabricated). Absent sides are recorded as not present, not as zero.
    final missingness = <String, dynamic>{
      'nutrition_view_present': nutritionView != null,
      'medication_view_present': medicationKnowledgeView != null,
      'nutrition_missing_fields': nutritionView?.missingFields ?? const [],
      'medication_metadata_completeness':
          medicationKnowledgeView?.metadataCompleteness,
      'medication_label_section_ref_count':
          medicationKnowledgeView?.labelSectionRefs.length ?? 0,
    };

    final provenanceSummary = 'nutrition_view='
        '${nutritionView != null ? 'present' : 'absent'}; '
        'medication_view='
        '${medicationKnowledgeView != null ? 'present' : 'absent'}; '
        'source_refs=${sourceRefs.length}';

    return EvidenceTraceBundle(
      bundleId: bundleId,
      createdAt: createdAt,
      nutritionView: nutritionView,
      medicationKnowledgeView: medicationKnowledgeView,
      mechanisticTraceSummary:
          mechanisticTraceSummary ?? const MechanisticTraceSummary(),
      sourceRefs: sourceRefs,
      provenanceSummary: provenanceSummary,
      missingnessSummary: missingness,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
    );
  }
}
