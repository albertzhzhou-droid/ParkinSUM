import 'medication_entry_validation.dart';

/// Evidence strength for an educational rule explanation.
///
/// These labels are documentation-level only. They are *not* clinical
/// evidence grades and must not be presented as such in user-facing copy.
enum RuleEvidenceStrength {
  /// Backed by official label / authoritative source documentation.
  label,

  /// Backed by published mechanism description, but specific to a study
  /// population rather than a regulatory document.
  mechanism,

  /// Inferred educational analogy — must always be paired with limitation
  /// text and an "uncertain" output type.
  analogy,

  /// Insufficient sourcing — the rule should not have fired; explanation is
  /// emitted only for traceability.
  insufficient,
}

/// Structured rule explanation. This is the auditable form of "why this rule
/// triggered" — it intentionally separates raw evidence/provenance fields
/// from display copy so tests can verify each layer independently.
class RuleExplanation {
  final String ruleId;

  /// Stable descriptors of which sub-conditions matched (e.g. "meal.protein_g
  /// >= moderate", "drug.release_type == immediate").
  final List<String> triggeredConditions;

  /// Paths into the runtime context that the rule actually consumed.
  final List<String> inputFieldsUsed;

  /// Source document references attached to the underlying rule.
  final List<String> sourceRefs;

  /// One-line summary of where the rule's authority comes from.
  final String provenanceSummary;

  final RuleEvidenceStrength evidenceStrength;

  /// Sentence-level limitation copy, e.g. why the result cannot be treated
  /// as personal medical advice.
  final String limitationText;

  /// Inputs the rule could not evaluate (e.g. timing was missing, formulation
  /// was unknown). These must always be surfaced when the output type is not
  /// `educationalInfo`.
  final List<String> missingOrUncertainInputs;

  /// Hard safety boundary copy, e.g. "Do not change medication, diet, or
  /// timing based on this app."
  final String safetyBoundary;

  /// Explicit "not advice" disclaimer copy, in plain language.
  final String notAdviceText;

  final MedicationExplanationOutputType outputType;

  const RuleExplanation({
    required this.ruleId,
    required this.triggeredConditions,
    required this.inputFieldsUsed,
    required this.sourceRefs,
    required this.provenanceSummary,
    required this.evidenceStrength,
    required this.limitationText,
    required this.missingOrUncertainInputs,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.outputType,
  });

  /// Default not-advice and safety-boundary copy. Centralized so tests can
  /// detect drift if the boundary language is weakened.
  static const String defaultNotAdvice =
      'This is an educational prototype output. It is not medical advice and '
      'must not be used to make medication, dietary, or timing decisions.';

  static const String defaultSafetyBoundary =
      'Do not change medication, diet, or timing based on this app. Review '
      'with a qualified clinician before making health decisions.';

  /// Convenience constructor for the "invalid medication context" case.
  ///
  /// This produces an explanation that records *why no rule fired*, which is
  /// itself a useful audit trail. It must never be confused with a conflict
  /// result.
  factory RuleExplanation.invalidMedicationContext({
    required String ruleId,
    required MedicationContextValidationResult validation,
  }) {
    return RuleExplanation(
      ruleId: ruleId,
      triggeredConditions: const [],
      inputFieldsUsed: const ['medication_entry'],
      sourceRefs: const [],
      provenanceSummary:
          'No rule fired because medication context failed the validity gate.',
      evidenceStrength: RuleEvidenceStrength.insufficient,
      limitationText: validation.safeUserCopy,
      missingOrUncertainInputs:
          validation.issues.map((i) => i.code).toList(growable: false),
      safetyBoundary: defaultSafetyBoundary,
      notAdviceText: defaultNotAdvice,
      outputType: MedicationExplanationOutputType.invalidContext,
    );
  }

  Map<String, dynamic> toJson() => {
        'rule_id': ruleId,
        'triggered_conditions': triggeredConditions,
        'input_fields_used': inputFieldsUsed,
        'source_refs': sourceRefs,
        'provenance_summary': provenanceSummary,
        'evidence_strength': evidenceStrength.name,
        'limitation_text': limitationText,
        'missing_or_uncertain_inputs': missingOrUncertainInputs,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
        'output_type': outputType.name,
      };
}

/// Banned phrase substrings that must never appear in user-facing rule
/// explanation copy. Tests assert against this list to keep educational
/// outputs from drifting into prescriptive medical advice.
const List<String> bannedExplanationSubstrings = <String>[
  'take your medication',
  'change your dose',
  'avoid protein',
  'recommended timing',
  'clinically validated',
  'follow this treatment',
  'this food is safe for you',
  'no doctor review is needed',
];

/// Reusable assertion helper for tests.
List<String> findBannedSubstrings(String text) {
  final lower = text.toLowerCase();
  return bannedExplanationSubstrings
      .where((needle) => lower.contains(needle))
      .toList(growable: false);
}
