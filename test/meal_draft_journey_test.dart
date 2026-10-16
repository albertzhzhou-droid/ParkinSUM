import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/synthetic_meal_journey.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/meal_draft.dart';
import 'package:parkinsum_companion/core/services/meal_draft_service.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/entry_food_portion_preview_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PausedDraftStore extends MemoryMealDraftStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(
    String key,
    String? document,
    bool Function() authorize,
  ) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    await super.write(key, document, authorize);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MealDraft reused() {
    final food = syntheticMealJourneyFoods().first;
    final history = syntheticMealJourneyHistory(food);
    return MealDraft.fromTemplate(
      template: MealDraft.templateFromHistory(
        history,
        countryCode: 'US',
        catalog: [food],
      ),
      draftId: 'draft-new',
      newMealId: 'meal-new',
      now: DateTime.utc(2026, 9, 29, 15),
      historyMealId: history.id,
    );
  }

  test(
    'history reuses existing template shape with fresh identity and new time',
    () {
      final food = syntheticMealJourneyFoods().first;
      final history = syntheticMealJourneyHistory(food).copyWith(
        nextMealWindowStart: DateTime.utc(2026, 9, 28, 22),
        coeventTime: DateTime.utc(2026, 9, 28, 16),
        coeventSubstanceTags: ['iron_salt'],
      );
      final original = jsonEncode(history.toJson());
      final template = MealDraft.templateFromHistory(
        history,
        countryCode: 'US',
        catalog: [food],
      );
      final draft = MealDraft.fromTemplate(
        template: template,
        draftId: 'fresh-draft',
        newMealId: 'fresh-meal',
        now: DateTime.utc(2026, 9, 29, 15),
        historyMealId: history.id,
      );
      expect(draft.meal.id, 'fresh-meal');
      expect(draft.meal.occurredAt, DateTime.utc(2026, 9, 29, 15));
      expect(draft.meal.coeventTime, isNull);
      expect(draft.meal.coeventSubstanceTags, isEmpty);
      expect(draft.meal.nextMealWindowStart, isNull);
      expect(draft.readyToSave, isFalse);
      expect(jsonEncode(history.toJson()), original);
      expect(jsonEncode(draft.toJson()), isNot(contains('trace')));
      expect(
        () => MealDraft.fromTemplate(
          template: template,
          draftId: 'bad',
          newMealId: history.id,
          now: DateTime.now(),
          historyMealId: history.id,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'draft nested fields reject lossy defaults while optional captured missingness roundtrips',
    () {
      final draft = reused();
      final roundtrip = MealDraft.fromJson(draft.toJson());
      expect(roundtrip.toJson(), draft.toJson());
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (json) => (json['meal'] as Map)['futureMealContext'] = true,
        (json) =>
            ((json['meal'] as Map)['items'] as List).first['futureNutrient'] =
                1,
        (json) => ((json['meal'] as Map)['items'] as List).first.remove(
          'proteinPer100g',
        ),
        (json) =>
            ((json['meal'] as Map)['items'] as List)
                .first['missingNutrientFields'] = [
              'futureNutrient',
            ],
      ]) {
        final input =
            jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>;
        mutate(input);
        expect(() => MealDraft.fromJson(input), throwsFormatException);
      }
      final emptyMarker =
          jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>;
      ((emptyMarker['meal'] as Map)['items'] as List)
              .first['missingNutrientFields'] =
          <String>[];
      expect(
        MealDraft.fromJson(emptyMarker).meal.items.single.missingNutrientFields,
        isEmpty,
      );
    },
  );

  test('owner keys and envelope prevent draft reads across accounts', () async {
    final store = MemoryMealDraftStore();
    final service = MealDraftService(store: store);
    await service.save('alice', reused(), authorize: () => true);
    expect(await service.load('bob'), isNull);
    expect((await service.load('alice'))!.meal.id, 'meal-new');
    expect(MealDraftService.storageKey('alice'), isNot(contains('alice')));
    store.documents[MealDraftService.storageKey('bob')] =
        store.documents[MealDraftService.storageKey('alice')]!;
    await expectLater(service.load('bob'), throwsFormatException);
  });

  test(
    'serialized checkpoint, clear and stale clear cannot resurrect or delete newer draft',
    () async {
      final service = MealDraftService(store: MemoryMealDraftStore());
      final draft = reused();
      final save = service.save('alice', draft, authorize: () => true);
      final clear = service.clear(
        'alice',
        draft.draftId,
        authorize: () => true,
      );
      await Future.wait([save, clear]);
      expect(await service.load('alice'), isNull);
      final newer = MealDraft(
        draftId: 'newer',
        meal: draft.meal,
        updatedAt: draft.updatedAt,
      );
      await service.save('alice', newer, authorize: () => true);
      await service.clear('alice', draft.draftId, authorize: () => true);
      expect((await service.load('alice'))!.draftId, 'newer');
    },
  );

  test(
    'expired authorization, future schema and invalid quantity never replace stored draft',
    () async {
      final store = MemoryMealDraftStore();
      final service = MealDraftService(store: store);
      final draft = reused();
      await service.save('alice', draft, authorize: () => true);
      final original = store.documents.values.single;
      await expectLater(
        service.save(
          'alice',
          draft.copyWith(timeConfirmed: true),
          authorize: () => false,
        ),
        throwsStateError,
      );
      expect(store.documents.values.single, original);
      final future = draft.toJson()..['schemaId'] = 'parkinsum.meal-draft/2';
      expect(() => MealDraft.fromJson(future), throwsFormatException);
      final invalid = draft.copyWith(
        meal: draft.meal.copyWith(
          items: [
            draft.meal.items.first.copyWith(quantityFactor: double.infinity),
          ],
        ),
      );
      await expectLater(
        service.save('alice', invalid, authorize: () => true),
        throwsFormatException,
      );
      expect(store.documents.values.single, original);
    },
  );

  test(
    'same input survives local storage restart without copied output',
    () async {
      final service = MealDraftService(store: LocalMealDraftStore());
      final draft = reused().copyWith(
        timeConfirmed: true,
        quantitiesConfirmed: true,
      );
      await service.save('alice', draft, authorize: () => true);
      final reopened = await MealDraftService(
        store: LocalMealDraftStore(),
      ).load('alice');
      expect(reopened!.toJson(), draft.toJson());
      expect(reopened.readyToSave, isTrue);
    },
  );

  test(
    'S1 independent source conversion and S2 unknown data use entry production path',
    () async {
      final services = Services.createEphemeral();
      await services.ready;
      final foods = syntheticMealJourneyFoods();
      final service = EntryFoodPortionPreviewService(
        projectionService: services.cdssCatalogProjectionService,
      );
      final context = await service.load(
        food: foods.first,
        registrationRegion: 'US',
      );
      final result = context.preview(
        'synthetic-1001:foodPortions:0',
        'protein_g',
      );
      // Independent rational arithmetic: 10 grams / 100 grams = 1/10;
      // a 160 gram source cup therefore contains exactly 16 grams protein.
      expect(result.status, 'calculated_preview');
      expect(result.perPortionValue, 16);
      expect(result.sourceFoodId, result.portionSourceFoodId);
      expect(result.sourceDocId, 'synthetic-fdc-shaped-document');
      expect(
        context
            .preview('synthetic-1001:foodPortions:0', 'fiber_g')
            .perPortionValue,
        isNull,
      );
      final missing = await service.load(
        food: foods.last,
        registrationRegion: 'US',
      );
      expect(missing.preview('', 'protein_g').status, 'held');
      expect(
        missing.preview('', 'protein_g').holdReason,
        'source_data_type_not_foundation',
      );
      expect(missing.preview('', 'protein_g').perPortionValue, isNull);
    },
  );

  test(
    'S3 concurrent save and retry after interruption produce one new meal',
    () async {
      final services = Services.createEphemeral();
      await services.ready;
      final state = AppState(services: services);
      await state.bootstrap();
      final food = services.foodRepository.allFoods.first;
      final history = Meal(
        id: 'old-meal',
        title: 'old',
        eatenAt: DateTime.utc(2026, 9, 28),
        items: [MealItem.fromFood(food: food, quantityFactor: 1)],
      );
      await state.addMeal(history);
      final draft = state
          .reuseMealAsDraft(history)
          .copyWith(timeConfirmed: true, quantitiesConfirmed: true);
      final owner = state.currentUserId!;
      final results = await Future.wait([
        state.saveMealDraft(draft, owner: owner),
        state.saveMealDraft(draft, owner: owner),
      ]);
      expect(results.every((result) => result.wasCommitted), isTrue);
      expect(state.meals, hasLength(2));
      expect(
        state.meals.where((meal) => meal.id == draft.meal.id),
        hasLength(1),
      );
      expect(
        state.meals.firstWhere((meal) => meal.id == history.id).toJson(),
        history.toJson(),
      );
      await state.persistMealDraft(
        draft,
        owner: owner,
      ); // simulate crash after meal commit, before draft clear
      await state.saveMealDraft(draft, owner: owner);
      expect(state.meals, hasLength(2));
      expect(await state.loadMealDraft(owner: owner), isNull);
      await expectLater(
        state.persistMealDraft(draft, owner: 'other-user'),
        throwsStateError,
      );
      expect(
        () => state.saveMealDraft(
          draft.copyWith(timeConfirmed: false),
          owner: owner,
        ),
        throwsStateError,
      );
      state.dispose();
    },
  );
  test(
    'same-owner reauthentication cannot reauthorize an old pending checkpoint',
    () async {
      final store = _PausedDraftStore();
      final services = Services.createEphemeral(mealDraftStore: store);
      await services.ready;
      final state = AppState(services: services);
      await state.bootstrap();
      final pending = state.persistMealDraft(
        reused(),
        owner: state.currentUserId!,
      );
      await store.entered.future;
      await state.signOut();
      await state.bootstrap();
      expect(state.currentUserId, 'local_user');
      store.release.complete();
      await expectLater(pending, throwsStateError);
      expect(store.documents, isEmpty);
      state.dispose();
    },
  );

  test(
    'a superseded editor cannot overwrite or save the newer draft',
    () async {
      final services = Services.createEphemeral();
      await services.ready;
      final state = AppState(services: services);
      await state.bootstrap();
      final owner = state.currentUserId!;
      final oldEditor = state.claimMealDraftEditor(owner: owner);
      final newEditor = state.claimMealDraftEditor(owner: owner);
      final newer = MealDraft(
        draftId: 'newer-editor',
        meal: reused().meal.copyWith(title: 'latest'),
        updatedAt: DateTime.now(),
      );
      await state.persistMealDraft(newer, owner: owner, editorEpoch: newEditor);
      await expectLater(
        state.persistMealDraft(reused(), owner: owner, editorEpoch: oldEditor),
        throwsStateError,
      );
      expect((await state.loadMealDraft(owner: owner))!.meal.title, 'latest');
      expect(
        () => state.saveMealDraft(
          reused().copyWith(timeConfirmed: true, quantitiesConfirmed: true),
          owner: owner,
          editorEpoch: oldEditor,
        ),
        throwsStateError,
      );
      state.dispose();
    },
  );

  test(
    'a deleted edit target retains its draft instead of reporting an unchanged save as success',
    () async {
      final services = Services.createEphemeral();
      await services.ready;
      final state = AppState(services: services);
      await state.bootstrap();
      final meal = reused().meal;
      await state.addMeal(meal);
      final draft = MealDraft(
        draftId: 'edit-retain',
        meal: meal.copyWith(title: 'unsaved edit'),
        editingMealId: meal.id,
        updatedAt: DateTime.now(),
      );
      await state.deleteMeal(meal.id);
      await expectLater(
        state.saveMealDraft(draft, owner: state.currentUserId!),
        throwsStateError,
      );
      expect(state.meals, isEmpty);
      expect(
        (await state.loadMealDraft(owner: state.currentUserId!))!.meal.title,
        'unsaved edit',
      );
      state.dispose();
    },
  );
}
