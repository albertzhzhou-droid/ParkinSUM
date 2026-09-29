import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/decision_support_followup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reload retries missed prompts without retrying a committed meal',
    () async {
      final store = _RecoverableStore();
      final state = await _state(store);
      final meal = _meal(state, 'committed-during-workspace-failure');
      store.failWrites = true;

      expect((await state.addMeal(meal)).wasCommitted, isTrue);
      expect(state.meals.single.id, meal.id);
      expect(state.followups(), isEmpty);
      expect(state.careWorkspaceError, 'save_failed');

      store.failWrites = false;
      await state.reloadCareWorkspace();

      expect(state.careWorkspaceError, isNull);
      expect(state.followups(), isNotEmpty);
      expect(state.meals, hasLength(1));
      expect(
        state.followups().every(
          (item) => item.prompt.sourceRecordId == meal.id,
        ),
        isTrue,
      );
      final durable = await state.services.careWorkspaceService.load(
        'local_user',
      );
      expect(
        durable.followups.prompts.map((prompt) => prompt.id).toSet(),
        state.followups().map((item) => item.prompt.id).toSet(),
      );
    },
  );

  test(
    'recovery keeps prior feedback while registering newly missed prompts',
    () async {
      final store = _RecoverableStore();
      final state = await _state(store);
      final first = _meal(state, 'previously-reviewed-meal');
      expect((await state.addMeal(first)).wasCommitted, isTrue);
      final original = state.followups().first.prompt;
      expect(
        await state.recordFollowup(
          promptId: original.id,
          status: DecisionSupportFollowupStatus.dismissed,
          reason: 'Already included in my questions for the next visit.',
          reasonCategory:
              DecisionSupportFeedbackReasonCategory.duplicateOrAlreadyAddressed,
        ),
        isTrue,
      );
      final prior = state
          .followups(includeHistory: true)
          .singleWhere((item) => item.prompt.id == original.id);
      final feedbackId = prior.history.single.id;

      store.failWrites = true;
      final second = _meal(state, 'new-meal-during-failure');
      expect((await state.addMeal(second)).wasCommitted, isTrue);
      expect(state.careWorkspaceError, 'save_failed');
      expect(
        state.followups().where(
          (item) => item.prompt.sourceRecordId == second.id,
        ),
        isEmpty,
      );

      store.failWrites = false;
      await state.reloadCareWorkspace();

      expect(state.careWorkspaceError, isNull);
      expect(
        state.followups().where(
          (item) => item.prompt.sourceRecordId == second.id,
        ),
        isNotEmpty,
      );
      final recovered = state
          .followups(includeHistory: true)
          .singleWhere((item) => item.prompt.id == original.id);
      expect(recovered.status, DecisionSupportFollowupStatus.dismissed);
      expect(recovered.prompt.createdAt, original.createdAt);
      expect(recovered.history.single.id, feedbackId);
      final durable = await state.services.careWorkspaceService.load(
        'local_user',
      );
      expect(durable.followups.feedback.single.id, feedbackId);
      expect(
        durable.followups.prompts.any(
          (prompt) => prompt.sourceRecordId == second.id,
        ),
        isTrue,
      );

      final saved = store.documents['local_user'];
      await state.reloadCareWorkspace();
      expect(
        store.documents['local_user'],
        saved,
        reason:
            'Repeated recovery must not replace snapshots or duplicate feedback.',
      );
    },
  );

  test(
    'reload retains failure status when prompt registration still cannot persist',
    () async {
      final store = _RecoverableStore();
      final state = await _state(store);
      store.failWrites = true;
      expect(
        (await state.addMeal(_meal(state, 'still-unpersisted'))).wasCommitted,
        isTrue,
      );

      await state.reloadCareWorkspace();

      expect(state.careWorkspaceError, 'save_failed');
      expect(state.followups(), isEmpty);
      expect(state.meals, hasLength(1));
    },
  );
}

Future<AppState> _state(_RecoverableStore store) async {
  final services = Services.createEphemeral(careWorkspaceStore: store);
  await services.ready;
  await services.userDataService.saveActiveDrugIds(['drug_levodopa_carbidopa']);
  final state = AppState(services: services);
  addTearDown(state.dispose);
  await state.bootstrap();
  return state;
}

Meal _meal(AppState state, String id) => Meal(
  id: id,
  title: 'Prompt recovery test meal',
  eatenAt: DateTime.utc(2026, 9, 20, 12),
  items: [
    MealItem.fromFood(food: state.foodRepo.allFoods.first, quantityFactor: 1),
  ],
);

class _RecoverableStore implements CareWorkspaceStore {
  final documents = <String, String>{};
  bool failWrites = false;

  @override
  Future<String?> read(String ownerScope) async => documents[ownerScope];

  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('care_workspace_session_changed');
    if (failWrites) throw StateError('test-write-failure');
    documents[ownerScope] = document;
  }
}
