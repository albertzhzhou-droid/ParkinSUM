import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/services/user_clinical_audit_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/features/shared/interaction_result_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _at = DateTime.utc(2026, 9, 30, 12, 30);
const _unknown = 'synthetic-medication-not-in-catalogue';

Meal _meal() => Meal(
  id: 'synthetic-medication-reference-meal',
  title: 'Synthetic known captured protein',
  eatenAt: _at,
  recordedAt: _at,
  items: [MealItem.fromFood(food: _food(), quantityFactor: 1)],
);

FoodItem _food() => FoodItem(
  id: 'synthetic-captured-food',
  name: 'Synthetic captured source',
  category: FoodCategory.other,
  proteinG: 20,
  carbsG: 10,
  fatG: 1,
  fiberG: 2,
  sodiumMg: 3,
);

Future<AppState> _state() async {
  final services = Services.createEphemeral();
  await services.ready;
  final state = AppState(services: services);
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(timezone: 'Etc/UTC', displayLocale: 'en-US'),
  );
  services.foodRepository.replaceAll([_food()]);
  addTearDown(state.dispose);
  return state;
}

void _expectUnassessed(InteractionResult result) {
  expect(result.status, InteractionStatus.unassessed);
  expect(result.hasAssessment, isFalse);
  expect(result.score, isNull);
  expect(result.overallSeverity, isNull);
  expect(result.scoreFactors, isEmpty);
  expect(result.mechanisticTraceJson, isNull);
  expect(result.unresolvedDrugIds, [_unknown]);
  expect(result.assessmentReasons, ['unresolved_medication_identity']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final bytes = File(
    'test/fixtures/unresolved_medication_independent_expectations.json',
  ).readAsBytesSync();
  final frozen = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  test('pre-implementation questions and both input cases remain exact', () {
    expect(
      sha256.convert(bytes).toString(),
      '09ce0f494104a7e6825f9ce3c7b73c32d87882a8ba2580f4fd2be1fe5afb6759',
    );
    expect((frozen['cases'] as List).length, 2);
  });

  for (final row in (frozen['cases'] as List).cast<Map>()) {
    test('saved AppState and direct engine: ${row['id']}', () async {
      final state = await _state();
      for (final intake in (row['intakes'] as List).cast<Map>()) {
        final mutation = await state.addIntake(
          Intake.fromJson(Map<String, dynamic>.from(intake)),
        );
        expect(mutation.wasCommitted, isTrue);
      }
      final meal = _meal();
      expect((await state.addMeal(meal)).wasCommitted, isTrue);
      final app = await state.checkMeal(meal);
      final direct = await state.services.databaseBackedMealCheckUseCase(
        meal: meal,
        activeDrugs: const [],
        intakes: state.intakes,
        userProfile: state.userProfile,
        now: _at,
      );
      expect(
        (await state.services.userDataService.loadIntakes()).length,
        (row['intakes'] as List).length,
      );
      for (final result in [app, direct, state.cachedMealCheck(meal)!]) {
        if (row['id'] == 'explicit_absence') {
          expect(result.status, InteractionStatus.ok);
          expect(result.hasAssessment, isTrue);
          expect(result.score, 0);
          expect(result.overallSeverity, InteractionSeverity.low);
        } else {
          _expectUnassessed(result);
        }
      }
      final recommendation = await state.requestNextMealRecommendation(
        nextMealAt: _at,
        useLocalAi: true,
        windowDuration: const Duration(minutes: 30),
      );
      if (row['id'] == 'explicit_absence') {
        expect(recommendation.recommendations, isNotEmpty);
        expect(recommendation.unresolvedDrugIds, isEmpty);
      } else {
        expect(recommendation.recommendations, isEmpty);
        expect(recommendation.unresolvedDrugIds, [_unknown]);
        expect(recommendation.decisionPath, 'unassessed_medication_context');
        expect(recommendation.mechanisticTrace, isNull);
        expect(recommendation.mechanisticCandidateScores, isNull);
        expect(recommendation.aiUsed, isFalse);
        expect(recommendation.aiRerankUsed, isFalse);
        expect(recommendation.rankerEligibility!.fallbackReasons, [
          'unresolved_medication_identity',
        ]);
      }
    });
  }

  test(
    'persisted selection cannot disappear when the catalogue drops its definition',
    () async {
      final state = await _state();
      await state.services.userDataService.saveActiveDrugIds([_unknown]);
      await state.bootstrap();
      expect(state.activeDrugIds, {_unknown});
      expect(state.activeDrugs, isEmpty);
      _expectUnassessed(await state.checkMeal(_meal()));
    },
  );

  test(
    'one known drug cannot hide another unresolved reference or a historical shortcut',
    () async {
      final state = await _state();
      final known = state.medRepo.getById('drug_levodopa_carbidopa')!;
      for (final now in [_at, _at.add(const Duration(days: 90))]) {
        final result = await state.services.databaseBackedMealCheckUseCase(
          meal: _meal(),
          activeDrugs: [known],
          intakes: const [],
          requiredDrugIds: [known.id, _unknown],
          userProfile: state.userProfile,
          now: now,
        );
        _expectUnassessed(result);
        expect(result.generatedAt, now);
      }
    },
  );

  test(
    'catalogue loss invalidates a previously completed saved-record cache',
    () async {
      final state = await _state();
      await state.setActiveDrugIds(['drug_levodopa_carbidopa']);
      final meal = _meal();
      await state.addMeal(meal);
      expect(state.cachedMealCheck(meal)!.hasAssessment, isTrue);
      state.medRepo.replaceAll([state.medRepo.getById('drug_entacapone')!]);
      expect(state.cachedMealCheck(meal), isNull);
      final result = await state.checkMeal(meal);
      expect(result.status, InteractionStatus.unassessed);
      expect(result.score, isNull);
      expect(result.unresolvedDrugIds, ['drug_levodopa_carbidopa']);
    },
  );

  test(
    'a known saved medication is resolved even without an active selection',
    () async {
      final state = await _state();
      expect(state.activeDrugIds, isEmpty);
      final intake = Intake(
        id: 'synthetic-known-intake',
        drugId: 'drug_levodopa_carbidopa',
        takenAt: _at,
        dosageNote: 'synthetic only',
      );
      expect((await state.addIntake(intake)).wasCommitted, isTrue);
      expect((await state.checkMeal(_meal())).hasAssessment, isTrue);
      final recommendation = await state.requestNextMealRecommendation(
        nextMealAt: _at,
        useLocalAi: false,
      );
      expect(recommendation.unresolvedDrugIds, isEmpty);
      expect(
        recommendation.decisionPath,
        isNot('unassessed_medication_context'),
      );
      expect(
        state.activeDrugIds,
        isEmpty,
        reason: 'Recorded use must not change the selection.',
      );
    },
  );

  test(
    'wire round-trip and audit keep absence distinct from unresolved input',
    () async {
      final state = await _state();
      final result = await state.services.databaseBackedMealCheckUseCase(
        meal: _meal(),
        activeDrugs: const [],
        intakes: const [],
        requiredDrugIds: [_unknown],
        userProfile: state.userProfile,
      );
      _expectUnassessed(InteractionResult.fromJson(result.toJson()));
      _expectUnassessed(result.copyWith(summary: 'Reworded without a score'));
      final audit = UserClinicalAuditService.buildMealCheckPayload(
        meal: _meal(),
        result: result,
        userProfile: state.userProfile,
        activeDrugIds: [_unknown],
        intakes: const [],
      );
      expect(audit['score'], isNull);
      expect(audit['severity'], isNull);
      expect(audit['assessment_status'], 'unassessed');
      expect(
        () => InteractionResult.fromJson({...result.toJson(), 'score': 0}),
        throwsArgumentError,
      );
      expect(
        () => InteractionResult.fromJson({
          ...result.toJson(),
          'status': 'future_status',
        }),
        throwsFormatException,
      );
      final legacy = InteractionResult.ok(
        mealId: 'legacy',
        message: 'Explicit absence',
      );
      expect(InteractionResult.fromJson(legacy.toJson()).score, 0);
      final withoutScore = Map<String, dynamic>.from(legacy.toJson())
        ..remove('score');
      expect(
        () => InteractionResult.fromJson(withoutScore),
        throwsArgumentError,
      );
    },
  );

  test(
    'unassessed result cannot trigger an AI request even with current consent',
    () async {
      var calls = 0;
      final adapter = LocalAiRecommendationAdapter(
        client: MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final state = await _state();
      final result = await state.services.databaseBackedMealCheckUseCase(
        meal: _meal(),
        activeDrugs: const [],
        intakes: const [],
        requiredDrugIds: [_unknown],
        userProfile: state.userProfile,
      );
      final profile = state.userProfile.withLocalAiConsentDecision(
        enabled: true,
        recordedAt: DateTime.now().toUtc(),
        source: 'synthetic_test',
      );
      expect(profile.hasCurrentLocalAiConsent, isTrue);
      final polished = await adapter.polishInteractionResult(
        userProfile: profile,
        meal: _meal(),
        result: result,
        activeDrugs: const [],
        intakes: const [],
      );
      expect(polished, same(result));
      final existing = state.services.nextMealRecommendationOrchestrator;
      final orchestrator = NextMealRecommendationOrchestrator(
        conservativeRecommender: existing.conservativeRecommender,
        projectionService: existing.projectionService,
        localAiAdapter: adapter,
      );
      final recommendation = await orchestrator.recommend(
        request: NextMealRecommendationRequest(
          userProfile: profile,
          history: [_meal()],
          activeDrugs: const [],
          requiredDrugIds: [_unknown],
          now: _at,
          mode: RecommendationMode.hybridLocalLlm,
          userConsentedToAi: true,
        ),
        candidateFoods: [_food()],
      );
      expect(recommendation.recommendations, isEmpty);
      expect(recommendation.aiUsed, isFalse);
      expect(recommendation.mechanisticTrace, isNull);
      expect(calls, 0);
    },
  );

  for (final locale in ['en-US', 'zh-CN']) {
    testWidgets('summary card withholds low/severity/score labels in $locale', (
      tester,
    ) async {
      final state = await _state();
      await state.saveUserProfile(
        state.userProfile.copyWith(displayLocale: locale),
      );
      final result = await state.services.databaseBackedMealCheckUseCase(
        meal: _meal(),
        activeDrugs: const [],
        intakes: const [],
        requiredDrugIds: [_unknown],
        userProfile: state.userProfile,
      );
      final i18n = AppI18n.fromLocaleTag(locale);
      final copy = ResponseCopyService(i18n: i18n);
      expect(copy.interactionSummary(result), result.summary);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(body: InteractionSummaryCard(result: result)),
          ),
        ),
      );
      expect(find.text(i18n.tr('interaction.unassessed')), findsOneWidget);
      expect(find.text(i18n.tr('interaction.low')), findsNothing);
      expect(
        find.text(i18n.tr('interaction.score', {'value': '0'})),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
