/// A **ParkinSUM-local** evidence-trace artifact that pairs the two
/// FHIR-inspired, PHI-free views (NutritionIntake + MedicationKnowledge) for
/// demo/review traceability.
///
/// Educational/research prototype only. This is **NOT a FHIR Bundle**: there is
/// no `resourceType`, no `Bundle`, and no patient / subject / encounter /
/// practitioner / care-team / request / administration semantics. It is a local
/// container for two already-PHI-free views plus a small, optional mechanistic
/// trace summary. It implies no clinical interoperability and is not clinically
/// calibrated.
library;

import 'fhir_inspired_medication_knowledge_view.dart';
import 'fhir_inspired_nutrition_intake_view.dart';

/// Small, optional summary of the mechanistic run that produced the paired
/// views. Every field is optional and is only populated when the value is
/// already available upstream (never fabricated). No dose/timing instruction.
class MechanisticTraceSummary {
  final String? severityBand;
  final String? confidenceBand;
  final String? rankerUsed;
  final String? replayScenarioId;
  final double? topSourceAuthorityScore;
  final String? medicationMetadataCompleteness;

  const MechanisticTraceSummary({
    this.severityBand,
    this.confidenceBand,
    this.rankerUsed,
    this.replayScenarioId,
    this.topSourceAuthorityScore,
    this.medicationMetadataCompleteness,
  });

  Map<String, dynamic> toJson() => {
        'severity_band': severityBand,
        'confidence_band': confidenceBand,
        'ranker_used': rankerUsed,
        'replay_scenario_id': replayScenarioId,
        'top_source_authority_score': topSourceAuthorityScore,
        'medication_metadata_completeness': medicationMetadataCompleteness,
      };
}

/// The local evidence-trace bundle. Deterministic JSON; PHI-free; not a FHIR
/// Bundle.
class EvidenceTraceBundle {
  /// Constant artifact-type marker (deliberately not "Bundle").
  static const String kBundleType = 'parkinsum_local_evidence_trace_bundle';

  /// Constant conformance marker — local artifact, explicitly NOT a FHIR Bundle.
  static const String kConformanceStatus = 'local_not_fhir_bundle';

  /// Constant PHI policy — no patient, subject, or encounter linkage.
  static const String kPhiPolicy = 'no_patient_no_subject_no_encounter';

  final String bundleId;

  /// Caller-supplied creation marker (e.g. an ISO date or relative label). Never
  /// a real patient timeline.
  final String createdAt;

  final FhirInspiredNutritionIntakeView? nutritionView;
  final FhirInspiredMedicationKnowledgeView? medicationKnowledgeView;
  final MechanisticTraceSummary mechanisticTraceSummary;
  final List<String> sourceRefs;
  final String provenanceSummary;
  final Map<String, dynamic> missingnessSummary;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;

  const EvidenceTraceBundle({
    required this.bundleId,
    required this.createdAt,
    required this.nutritionView,
    required this.medicationKnowledgeView,
    required this.mechanisticTraceSummary,
    required this.sourceRefs,
    required this.provenanceSummary,
    required this.missingnessSummary,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
  });

  Map<String, dynamic> toJson() => {
        'bundle_type': kBundleType,
        'conformance_status': kConformanceStatus,
        'phi_policy': kPhiPolicy,
        'bundle_id': bundleId,
        'created_at': createdAt,
        'nutrition_view': nutritionView?.toJson(),
        'medication_knowledge_view': medicationKnowledgeView?.toJson(),
        'mechanistic_trace_summary': mechanisticTraceSummary.toJson(),
        'source_refs': sourceRefs,
        'provenance_summary': provenanceSummary,
        'missingness_summary': missingnessSummary,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
        'not_clinically_calibrated': notClinicallyCalibrated,
      };
}
