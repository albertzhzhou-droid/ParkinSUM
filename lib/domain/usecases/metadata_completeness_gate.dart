import '../entities/source_metadata.dart';

/// Deterministic metadata-completeness scoring. Composes with the existing
/// `MedicationEntryValidator` (which stays the hard input gate); this layer
/// adds the softer downgrade/uncertainty grading used by scoring + the
/// explanation trace.
///
/// Core rules (educational, never fake precision):
/// - no unit → no dose
/// - no active ingredient → no drug context
/// - no dose form / release type → limited/blocked PK interpretation
/// - no provenance (sourceRefs) → no evidence-linked explanation
/// - no jurisdiction → unknown-jurisdiction behavior (lower confidence)
/// - incomplete → widen uncertainty rather than assert precision
class MetadataCompletenessGate {
  MetadataCompletenessScore scoreMedicationContext(
      DrugProductVariantMetadata? meta) {
    if (meta == null) return MetadataCompletenessScore.invalid;
    if (meta.activeIngredients.isEmpty) {
      return MetadataCompletenessScore.invalid; // no ingredient → no context
    }
    if (meta.strengthValue == null || (meta.strengthUnit ?? '').isEmpty) {
      return MetadataCompletenessScore.insufficient; // no unit → no dose
    }
    final missing = <bool>[
      meta.doseForm.isEmpty,
      meta.releaseType.isEmpty || meta.releaseType == 'unknown',
      meta.route.isEmpty,
      meta.sourceRefs.isEmpty,
      meta.jurisdiction.isEmpty,
    ].where((m) => m).length;
    if (missing == 0) return MetadataCompletenessScore.complete;
    if (missing <= 1) return MetadataCompletenessScore.sufficient;
    if (missing <= 3) return MetadataCompletenessScore.partial;
    return MetadataCompletenessScore.insufficient;
  }

  MetadataCompletenessScore scoreCandidateFood(
    FoodVariantMetadata? meta, {
    required double nutrientCompleteness, // 0..1 from composition normalizer
  }) {
    if (meta == null) {
      // No provenance metadata; fall back to nutrient completeness only.
      if (nutrientCompleteness >= 0.99) {
        return MetadataCompletenessScore.partial;
      }
      if (nutrientCompleteness >= 0.5) {
        return MetadataCompletenessScore.insufficient;
      }
      return MetadataCompletenessScore.invalid;
    }
    final missing = <bool>[
      (meta.basisType ?? '').isEmpty,
      meta.sourceRefs.isEmpty,
      meta.jurisdiction.isEmpty,
      nutrientCompleteness < 0.5,
    ].where((m) => m).length;
    if (missing == 0 && nutrientCompleteness >= 0.99) {
      return MetadataCompletenessScore.complete;
    }
    if (missing <= 1) return MetadataCompletenessScore.sufficient;
    if (missing <= 2) return MetadataCompletenessScore.partial;
    return MetadataCompletenessScore.insufficient;
  }

  MetadataCompletenessScore scoreRuleExplanation({
    required List<String> sourceRefs,
    required bool hasLimitationText,
    required bool hasSafetyBoundary,
  }) {
    if (sourceRefs.isEmpty) {
      // No provenance → source-linked explanation must be blocked/downgraded.
      return MetadataCompletenessScore.insufficient;
    }
    if (!hasLimitationText || !hasSafetyBoundary) {
      return MetadataCompletenessScore.partial;
    }
    return MetadataCompletenessScore.complete;
  }

  /// Map a completeness score to a 0..1 numeric weight for scoring use.
  double toWeight(MetadataCompletenessScore score) {
    switch (score) {
      case MetadataCompletenessScore.complete:
        return 1.0;
      case MetadataCompletenessScore.sufficient:
        return 0.8;
      case MetadataCompletenessScore.partial:
        return 0.5;
      case MetadataCompletenessScore.insufficient:
        return 0.25;
      case MetadataCompletenessScore.invalid:
        return 0.0;
    }
  }
}
