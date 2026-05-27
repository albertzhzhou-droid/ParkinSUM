import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

void main() {
  group('RuleExplanation — structured fields are present', () {
    test('a sample levodopa+protein explanation carries every required field',
        () {
      const explanation = RuleExplanation(
        ruleId: 'levodopa_protein_temporal_v1',
        triggeredConditions: [
          'drug.active_ingredients contains levodopa',
          'meal.protein_band == moderate',
          'timing.meal_to_drug within 0-60 min',
        ],
        inputFieldsUsed: [
          'drug.active_ingredients',
          'drug.release_type',
          'meal.protein_g',
          'timestamps.drug_time',
          'timestamps.meal_time',
        ],
        sourceRefs: [
          'synthetic:demo_label_carbidopa_levodopa#food_effect',
        ],
        provenanceSummary:
            'Synthetic carbidopa/levodopa label fixture, food-effect section.',
        evidenceStrength: RuleEvidenceStrength.label,
        limitationText:
            'Individual absorption varies. This prototype does not infer the '
            'patient\'s pharmacokinetics from the input.',
        missingOrUncertainInputs: ['estimatedGastricEmptyingModifier'],
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
        outputType: MedicationExplanationOutputType.educationalCaution,
      );

      expect(explanation.sourceRefs, isNotEmpty);
      expect(explanation.limitationText, isNotEmpty);
      expect(explanation.safetyBoundary, isNotEmpty);
      expect(explanation.notAdviceText, isNotEmpty);
      expect(explanation.inputFieldsUsed, isNotEmpty);
      expect(explanation.missingOrUncertainInputs, isNotEmpty);
    });
  });

  group('RuleExplanation — banned substrings never appear', () {
    test('default safety/not-advice copy contains no banned phrases', () {
      expect(
          findBannedSubstrings(RuleExplanation.defaultNotAdvice), isEmpty);
      expect(findBannedSubstrings(RuleExplanation.defaultSafetyBoundary),
          isEmpty);
    });

    test('invalid-context explanation does not leak prescriptive copy', () {
      final validation = MedicationEntryValidator()
          .validate(const RawMedicationEntry(freeText: '100'));
      final explanation = RuleExplanation.invalidMedicationContext(
        ruleId: 'levodopa_protein_temporal_v1',
        validation: validation,
      );
      expect(explanation.outputType,
          MedicationExplanationOutputType.invalidContext);
      expect(explanation.sourceRefs, isEmpty);
      expect(explanation.triggeredConditions, isEmpty);
      expect(explanation.missingOrUncertainInputs,
          contains('BARE_NUMERIC_DOSE'));

      final allCopy = [
        explanation.limitationText,
        explanation.safetyBoundary,
        explanation.notAdviceText,
        explanation.provenanceSummary,
      ].join(' ');
      expect(findBannedSubstrings(allCopy), isEmpty);
    });
  });

  group('Banned-substring list is non-empty and lowercase', () {
    test('list integrity', () {
      expect(bannedExplanationSubstrings, isNotEmpty);
      for (final s in bannedExplanationSubstrings) {
        expect(s, s.toLowerCase());
      }
    });
  });
}
