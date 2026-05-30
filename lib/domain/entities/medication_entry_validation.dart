/// Strict medication-context validation types.
///
/// ParkinSUM is an educational prototype. It does not derive dose, schedule,
/// formulation, or pharmacokinetic meaning from free-text. A medication entry
/// must be backed by an explicit catalog variant (with active ingredient,
/// strength, unit, route, and formulation/release type) before any
/// food-medication rule can be evaluated against it.
///
/// These types describe the result of running such validation. They are
/// intentionally additive — existing engine code continues to operate against
/// `DrugRuntimeContext`; this layer simply gates *what* may be promoted to a
/// runtime context.
library;

import 'medication_source_metadata.dart';

/// Status of a medication-entry validation pass.
enum MedicationContextValidity {
  /// All required catalog-backed fields are present and units are explicit.
  valid,

  /// One or more required fields are missing (e.g. unit, active ingredient,
  /// product variant, formulation). The entry must not enter food-medication
  /// rule evaluation.
  insufficient,

  /// Input is structurally invalid (e.g. bare numeric, unparseable, or a
  /// suspected attempt to infer dose from a number alone).
  invalid,
}

/// Output type for an educational rule explanation tied to a medication entry.
enum MedicationExplanationOutputType {
  educationalInfo,
  educationalCaution,

  /// Returned when medication context could not be validated. No rule fired.
  invalidContext,
}

/// Reasons a medication entry was rejected or downgraded.
class MedicationContextIssue {
  /// Stable code (machine-readable) for tests and tracing.
  final String code;

  /// Short, non-clinical, user-safe sentence explaining what is missing.
  final String message;

  const MedicationContextIssue({required this.code, required this.message});

  Map<String, dynamic> toJson() => {'code': code, 'message': message};
}

/// Catalog-backed normalized medication context, only produced when the entry
/// passes the validity gate. Mirrors the subset of fields the rule engine
/// actually consumes, plus provenance/limitation metadata.
class NormalizedMedicationContext {
  final String drugProductVariant;
  final List<String> activeIngredients;
  final String form; // e.g. "tablet"
  final String route; // e.g. "oral"
  final String releaseType; // e.g. "immediate" | "extended"
  final double strength;
  final String unit; // e.g. "mg"
  final String jurisdiction;
  final String sourceDocId;
  final String? labelSection;
  final double? extractionConfidence;
  final String limitationText;

  /// Engine-facing medication provenance bridged from the CDSS layer (label
  /// section refs, combination components, release-type source, source-doc
  /// trace). PROVENANCE ONLY — never read as an intake dose. Null when no
  /// CDSS metadata was attached.
  final MechanisticMedicationMetadata? metadata;

  const NormalizedMedicationContext({
    required this.drugProductVariant,
    required this.activeIngredients,
    required this.form,
    required this.route,
    required this.releaseType,
    required this.strength,
    required this.unit,
    required this.jurisdiction,
    required this.sourceDocId,
    required this.labelSection,
    required this.extractionConfidence,
    required this.limitationText,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'drug_product_variant': drugProductVariant,
        'active_ingredients': activeIngredients,
        'form': form,
        'route': route,
        'release_type': releaseType,
        'strength': strength,
        'unit': unit,
        'jurisdiction': jurisdiction,
        'source_doc_id': sourceDocId,
        'label_section': labelSection,
        'extraction_confidence': extractionConfidence,
        'limitation_text': limitationText,
        'metadata': metadata?.toJson(),
      };
}

/// Result of validating a raw medication entry.
class MedicationContextValidationResult {
  final MedicationContextValidity validity;
  final List<MedicationContextIssue> issues;
  final NormalizedMedicationContext? normalized;
  final String safeUserCopy;

  const MedicationContextValidationResult({
    required this.validity,
    required this.issues,
    required this.normalized,
    required this.safeUserCopy,
  });

  bool get eligibleForRuleEvaluation =>
      validity == MedicationContextValidity.valid && normalized != null;

  Map<String, dynamic> toJson() => {
        'validity': validity.name,
        'issues': issues.map((e) => e.toJson()).toList(),
        'normalized': normalized?.toJson(),
        'safe_user_copy': safeUserCopy,
      };
}
