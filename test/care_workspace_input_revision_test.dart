import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a pending meal check cannot restore prompts after active drugs change',
    () async {
      final database = _PausedReadDatabase();
      final store = MemoryCareWorkspaceStore();
      final services = Services.createEphemeral(
        cdssDatabase: database,
        careWorkspaceStore: store,
      );
      await services.ready;
      await services.userDataService.saveActiveDrugIds([
        'drug_levodopa_carbidopa',
      ]);
      final state = AppState(services: services);
      addTearDown(state.dispose);
      await state.bootstrap();
      final meal = Meal(
        id: 'input-revision-meal',
        title: 'Saved meal for the input revision regression',
        eatenAt: DateTime.utc(2026, 9, 20, 12),
        items: [
          MealItem.fromFood(
            food: state.foodRepo.allFoods.first,
            quantityFactor: 1,
          ),
        ],
      );
      expect((await state.addMeal(meal)).wasCommitted, isTrue);
      expect(
        state.cachedMealCheck(meal).followupPrompts,
        isNotEmpty,
        reason: 'The original medication context must produce real prompts.',
      );
      expect(state.followups(), isNotEmpty);

      // Pause the real check after it has captured the original drug list.
      // Only this read waits; the medication update can complete its own
      // recommendation and meal checks while the old check is still pending.
      final pendingRead = database.pauseNextRegionLookup();
      addTearDown(pendingRead.release);
      final oldCheck = state.checkMeal(meal);
      await pendingRead.started.future.timeout(const Duration(seconds: 5));
      try {
        expect((await state.setActiveDrugIds([])).wasCommitted, isTrue);
        final currentResult = state.cachedMealCheck(meal);
        expect(currentResult.followupPrompts, isEmpty);
        expect(state.followups(), isEmpty);
        final persistedAfterUpdate =
            store.documents[careWorkspaceStorageKey('local_user')];

        pendingRead.release();
        final oldResult = await oldCheck;
        expect(
          oldResult.followupPrompts,
          isNotEmpty,
          reason: 'The released result must still reflect the old input.',
        );
        expect(
          state.cachedMealCheck(meal),
          same(currentResult),
          reason: 'A stale response must not replace the new cached check.',
        );
        expect(
          state.followups(),
          isEmpty,
          reason: 'Removing active drugs must not resurrect old prompts.',
        );
        expect(
          store.documents[careWorkspaceStorageKey('local_user')],
          persistedAfterUpdate,
          reason: 'Discarding stale output must not change the saved ledger.',
        );
      } finally {
        pendingRead.release();
        await oldCheck;
      }
    },
  );
}

class _PausedReadDatabase extends InMemoryCdssDatabase {
  _PendingRead? _nextRegionLookup;

  _PendingRead pauseNextRegionLookup() {
    final pending = _PendingRead();
    _nextRegionLookup = pending;
    return pending;
  }

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async {
    final pending = _nextRegionLookup;
    if (table == 'region_jurisdiction_map' && pending != null) {
      _nextRegionLookup = null;
      pending.started.complete();
      await pending.released.future;
    }
    return super.queryTable(table);
  }
}

class _PendingRead {
  final started = Completer<void>();
  final released = Completer<void>();

  void release() {
    if (!released.isCompleted) released.complete();
  }
}
