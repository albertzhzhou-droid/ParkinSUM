import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_card_projector.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_sandbox_service.dart';

void main() {
  const service = SyntheticCdsHooksSandboxService();

  test(
    'complete synthetic scenario produces one provenance-bound info card',
    () async {
      final result = await service.run(
        SyntheticCdsHooksScenario.completeProteinMeal,
      );
      final cards = (result.response['cards'] as List)
          .cast<Map<String, dynamic>>();

      expect(cards, hasLength(1));
      expect(cards.single['indicator'], 'info');
      expect(cards.single['source'], containsPair('label', isNotEmpty));
      final extension =
          (cards.single['extension']
                  as Map<String, dynamic>)[cdsHooksRuleTraceExtensionName]
              as Map<String, dynamic>;
      expect(extension['traceDecision'], 'matched');
      expect(extension['resultState'], 'matched');
      expect(extension['rulePackVersion'], result.rulePackVersion);
      expect(extension['inputDigest'], result.inputDigest);
      for (final field in [
        'sourceRefs',
        'inputFieldsUsed',
        'missingOrUncertainInputs',
      ]) {
        final values = extension[field] as List;
        expect(values.every((value) => value is String), isTrue);
      }

      final serialized = jsonEncode(result.response).toLowerCase();
      for (final forbidden in [
        'synthetic_test_case',
        'carbidopa',
        'levodopa',
        'sinemet',
        'synthetic_meal_complete',
        'patient_id',
        'fhirauthorization',
        'suggestions',
        'systemactions',
      ]) {
        expect(serialized, isNot(contains(forbidden)));
      }
    },
  );

  test(
    'missing context remains incomplete and never becomes a negative result',
    () async {
      final result = await service.run(
        SyntheticCdsHooksScenario.missingMealContext,
      );
      final cards = (result.response['cards'] as List)
          .cast<Map<String, dynamic>>();

      expect(cards, hasLength(1));
      final extension =
          (cards.single['extension']
                  as Map<String, dynamic>)[cdsHooksRuleTraceExtensionName]
              as Map<String, dynamic>;
      expect(extension['inputCompleteness'], 'incomplete');
      expect(extension['resultState'], 'unknown');
      expect(extension['missingOrUncertainInputs'], isNotEmpty);
      expect(result.missingInputs, isNotEmpty);
    },
  );

  test(
    'low-protein synthetic scenario returns an empty no-guidance response',
    () async {
      final result = await service.run(
        SyntheticCdsHooksScenario.lowProteinMeal,
      );

      expect(result.response, <String, dynamic>{'cards': <Object?>[]});
      expect(result.traceDecision, isNull);
      expect(result.resultState, isNull);
    },
  );

  test(
    'fixed scenario produces deterministic response and input digest',
    () async {
      final first = await service.run(
        SyntheticCdsHooksScenario.completeProteinMeal,
      );
      final second = await service.run(
        SyntheticCdsHooksScenario.completeProteinMeal,
      );

      expect(jsonEncode(first.response), jsonEncode(second.response));
      expect(first.inputDigest, second.inputDigest);
    },
  );
}
