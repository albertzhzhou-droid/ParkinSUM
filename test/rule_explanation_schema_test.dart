import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';

/// P2 — Rule explanation schema. Verifies the auditable explanation model
/// exposes the full chain (rule id, triggered/not, decision, evidence refs,
/// missing inputs, provenance, confidence/safety boundary, and copy source)
/// and that the new fields are additive + safe. Educational prototype only.
void main() {
  RuleExplanation triggeredExample() => const RuleExplanation(
    ruleId: 'rule.levodopa_protein_timing',
    triggeredConditions: ['meal.protein_g >= moderate'],
    inputFieldsUsed: ['meal.protein_g', 'drug.release_type'],
    sourceRefs: ['src.dailymed.sinemet.label'],
    provenanceSummary: 'Backed by official label food-effect section.',
    evidenceStrength: RuleEvidenceStrength.label,
    limitationText: 'Educational only; not personal medical advice.',
    missingOrUncertainInputs: ['intake.exact_time'],
    safetyBoundary: RuleExplanation.defaultSafetyBoundary,
    notAdviceText: RuleExplanation.defaultNotAdvice,
    outputType: MedicationExplanationOutputType.educationalCaution,
    triggered: true,
    userFacingDecision: 'educational caution',
    confidenceNote: 'moderate — label-backed, timing uncertain',
    copySource: 'legacy.high_protein_detail',
  );

  test('exposes the full auditable explanation chain in JSON', () {
    final json = triggeredExample().toJson();
    // Required chain fields the task calls out.
    expect(json['rule_id'], 'rule.levodopa_protein_timing');
    expect(json['triggered'], isTrue);
    expect(json['user_facing_decision'], 'educational caution');
    expect(json['source_refs'], contains('src.dailymed.sinemet.label'));
    expect(json['missing_or_uncertain_inputs'], contains('intake.exact_time'));
    expect(json['provenance_summary'], isNotEmpty);
    expect(json['confidence_note'], contains('moderate'));
    expect(json['safety_boundary'], isNotEmpty);
    expect(json['copy_source'], 'legacy.high_protein_detail');
    expect(json['output_type'], 'educationalCaution');
  });

  test('triggered defaults to inferring from triggered conditions', () {
    const fired = RuleExplanation(
      ruleId: 'r',
      triggeredConditions: ['cond'],
      inputFieldsUsed: [],
      sourceRefs: [],
      provenanceSummary: '',
      evidenceStrength: RuleEvidenceStrength.mechanism,
      limitationText: '',
      missingOrUncertainInputs: [],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      outputType: MedicationExplanationOutputType.educationalInfo,
    );
    const notFired = RuleExplanation(
      ruleId: 'r',
      triggeredConditions: [],
      inputFieldsUsed: [],
      sourceRefs: [],
      provenanceSummary: '',
      evidenceStrength: RuleEvidenceStrength.mechanism,
      limitationText: '',
      missingOrUncertainInputs: [],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      outputType: MedicationExplanationOutputType.educationalInfo,
    );
    expect(fired.triggered, isTrue);
    expect(notFired.triggered, isFalse);
    // Explicit override wins.
    expect(fired.triggeredConditions.isNotEmpty, isTrue);
  });

  test('invalid-context factory records a not-triggered audit trail', () {
    const validation = MedicationContextValidationResult(
      validity: MedicationContextValidity.insufficient,
      issues: [
        MedicationContextIssue(
          code: 'missing_strength',
          message: 'No dose strength provided.',
        ),
      ],
      normalized: null,
      safeUserCopy: 'Medication details were incomplete, so no rule ran.',
    );
    final explanation = RuleExplanation.invalidMedicationContext(
      ruleId: 'rule.levodopa_protein_timing',
      validation: validation,
    );
    expect(explanation.triggered, isFalse);
    expect(explanation.userFacingDecision, contains('no rule fired'));
    expect(explanation.missingOrUncertainInputs, contains('missing_strength'));
    expect(explanation.toJson()['triggered'], isFalse);
  });

  test(
    'default boundary/not-advice copy contains no banned prescriptive copy',
    () {
      expect(findBannedSubstrings(RuleExplanation.defaultNotAdvice), isEmpty);
      expect(
        findBannedSubstrings(RuleExplanation.defaultSafetyBoundary),
        isEmpty,
      );
    },
  );
}
