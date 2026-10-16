import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/rule_registry_models.dart';

Future<AppState> stateWithMeal() async {
  final services = Services.createEphemeral();
  await services.ready;
  final state = AppState(services: services);
  await state.bootstrap();
  await state.addMeal(
    Meal(
      id: 'synthetic-derived-source',
      title: 'Synthetic source-bound meal',
      eatenAt: DateTime.utc(2026, 10, 1, 12),
      items: [
        MealItem.fromFood(
          food: state.foodRepo.allFoods.first,
          quantityFactor: 1,
        ),
      ],
    ),
  );
  addTearDown(state.dispose);
  expect(state.cachedMealCheck(state.meals.single), isNotNull);
  expect(state.recommendations, isNotEmpty);
  return state;
}

String rawRecords(AppState state) => jsonEncode({
  'meals': state.meals.map((m) => m.toJson()).toList(),
  'intakes': state.intakes.map((i) => i.toJson()).toList(),
  'history': state.recoverableEventHistory.map((r) => r.toJson()).toList(),
});

RuleRegistryEntry changeRule(RuleRegistryEntry rule, String field) =>
    RuleRegistryEntry(
      ruleId: rule.ruleId,
      version: field == 'version'
          ? '\${rule.version}.synthetic_review'
          : rule.version,
      status: rule.status,
      ruleType: rule.ruleType,
      priorityBand: rule.priorityBand,
      specificityBand: rule.specificityBand,
      jurisdictions: rule.jurisdictions,
      appliesTo: rule.appliesTo,
      conditions: field == 'condition_body'
          ? {
              ...rule.conditions,
              'synthetic_missing_dependency': {'value': false},
            }
          : rule.conditions,
      thenClause: field == 'localized_message'
          ? RuleThenClause(
              decision: rule.thenClause.decision,
              severity: rule.thenClause.severity,
              messages: RuleMessageSet(
                zh: rule.thenClause.messages.zh,
                en: rule.thenClause.messages.en,
                localized: {
                  ...rule.thenClause.messages.localized,
                  'en': 'Synthetic revised explanation',
                },
              ),
              actions: rule.thenClause.actions,
              outputTags: rule.thenClause.outputTags,
            )
          : rule.thenClause,
      provenance: field == 'source_ref'
          ? RuleProvenance(
              evidenceLevel: rule.provenance.evidenceLevel,
              sourceRefs: [
                ...rule.provenance.sourceRefs,
                'synthetic_source_revision',
              ],
              effectiveFrom: rule.provenance.effectiveFrom,
              effectiveTo: rule.provenance.effectiveTo,
            )
          : rule.provenance,
      override: rule.override,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final catalog in ['food', 'medication']) {
    test(
      '\$catalog revision hides the entire old recommendation presentation',
      () async {
        final state = await stateWithMeal();
        final raw = rawRecords(state);
        final revision = state.derivedResultInputRevision;
        if (catalog == 'food') {
          state.foodRepo.replaceAll(state.foodRepo.allFoods);
        } else {
          state.medRepo.replaceAll(state.medRepo.allDrugs);
        }
        expect(state.derivedResultInputRevision, isNot(revision));
        expect(state.cachedMealCheck(state.meals.single), isNull);
        expect(state.recommendations, isEmpty);
        expect(state.recommendationExplanations, isEmpty);
        expect(state.recommendationDecisionPath, 'pending_input_refresh');
        expect(state.recommendationAiUsed, isFalse);
        expect(state.recommendationTemplateCountryCode, isNull);
        expect(state.recommendationRankPresentationWithheld, isTrue);
        expect(rawRecords(state), raw);
        await state.bootstrap();
        expect(state.recommendations, isNotEmpty);
        expect(state.cachedMealCheck(state.meals.single), isNotNull);
        expect(rawRecords(state), raw);
      },
    );
  }
  for (final field in [
    'version',
    'condition_body',
    'localized_message',
    'source_ref',
  ]) {
    test(
      'compiled rule \$field invalidates even with unchanged catalogs and meal ID',
      () async {
        final state = await stateWithMeal();
        final raw = rawRecords(state);
        final foodRevision = state.foodRepo.revision;
        final rules =
            state.services.databaseBackedMealCheckUseCase.compiledRules;
        rules[0] = changeRule(rules.first, field);
        expect(state.foodRepo.revision, foodRevision);
        expect(state.cachedMealCheck(state.meals.single), isNull);
        expect(state.recommendations, isEmpty);
        expect(rawRecords(state), raw);
        final current = await state.checkMeal(state.meals.single);
        expect(state.cachedMealCheck(state.meals.single), same(current));
      },
    );
  }
  test(
    'failed known import invalidates before await and cannot revive old results',
    () async {
      final state = await stateWithMeal();
      final raw = rawRecords(state);
      final operation = state.runRemoteImportTask(
        'synthetic_unsupported_source',
      );
      expect(state.cachedMealCheck(state.meals.single), isNull);
      expect(state.recommendations, isEmpty);
      await operation;
      expect(state.latestImportTask!.succeeded, isFalse);
      expect(state.cachedMealCheck(state.meals.single), isNull);
      expect(state.recommendations, isEmpty);
      expect(rawRecords(state), raw);
      await state.bootstrap();
      expect(state.cachedMealCheck(state.meals.single), isNotNull);
      expect(state.recommendations, isNotEmpty);
      expect(rawRecords(state), raw);
    },
  );
}
