import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_memory.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/recoverable_user_event_store.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recoverable event revision contract', () {
    test('canonical identity and payload digests detect tampering', () {
      final revision = _revision(
        operationId: 'event_op_1',
        mutationType: RecoverableUserEventMutationType.create,
        before: null,
        after: _meal('meal_a', 'Original').toJson(),
      );
      final restored = RecoverableUserEventRevision.fromJson(
        Map<String, dynamic>.from(revision.toJson()),
      );
      expect(restored.toJson(), revision.toJson());
      final tampered =
          jsonDecode(jsonEncode(revision.toJson())) as Map<String, dynamic>;
      (tampered['after_payload'] as Map<String, dynamic>)['title'] = 'Changed';
      expect(
        () => RecoverableUserEventRevision.fromJson(tampered),
        throwsFormatException,
      );
    });

    test('non-canonical or no-op transitions fail closed', () {
      expect(
        () => _revision(
          operationId: 'event_op_noop',
          mutationType: RecoverableUserEventMutationType.update,
          before: _meal('meal_a', 'Same').toJson(),
          after: _meal('meal_a', 'Same').toJson(),
        ),
        throwsFormatException,
      );
      expect(
        () => _revision(
          operationId: 'event_op_wrong_id',
          mutationType: RecoverableUserEventMutationType.create,
          before: null,
          after: _meal('meal_b', 'Wrong').toJson(),
        ),
        throwsFormatException,
      );
    });
  });

  group('production backend recoverable mutation conformance', () {
    for (final backend in <(String, RecoverableUserEventStore Function())>[
      ('memory', InMemoryAppDatabase.new),
      ('web', WebAppDatabase.new),
    ]) {
      test(
        '${backend.$1} atomically appends, restores, and rejects stale CAS',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final store = backend.$2();
          final database = store as dynamic;
          final original = _meal('meal_a', 'Original');
          final created = _revision(
            operationId: 'event_op_create',
            mutationType: RecoverableUserEventMutationType.create,
            before: null,
            after: original.toJson(),
          );
          await store.commitRecoverableUserEventMutation(
            RecoverableUserEventMutation(revision: created),
          );
          await store.commitRecoverableUserEventMutation(
            RecoverableUserEventMutation(revision: created),
          );
          expect((await database.loadMeals()).single.title, 'Original');
          expect(await store.loadRecoverableUserEventHistory(), hasLength(1));

          final reusedOperation = _revision(
            operationId: created.operationId,
            recordId: 'meal_b',
            mutationType: RecoverableUserEventMutationType.create,
            before: null,
            after: _meal('meal_b', 'Must not commit').toJson(),
          );
          await expectLater(
            store.commitRecoverableUserEventMutation(
              RecoverableUserEventMutation(revision: reusedOperation),
            ),
            throwsA(isA<RecoverableUserEventConflict>()),
          );
          expect(
            (await database.loadMeals()).map((meal) => meal.id),
            isNot(contains('meal_b')),
          );
          expect(await store.loadRecoverableUserEventHistory(), hasLength(1));

          final edited = _meal('meal_a', 'Edited');
          final updated = _revision(
            operationId: 'event_op_update',
            mutationType: RecoverableUserEventMutationType.update,
            before: original.toJson(),
            after: edited.toJson(),
          );
          await store.commitRecoverableUserEventMutation(
            RecoverableUserEventMutation(revision: updated),
          );
          expect((await database.loadMeals()).single.title, 'Edited');

          final restore = RecoverableUserEventRevision.create(
            operationId: 'event_op_restore',
            eventType: RecoverableUserEventType.meal,
            recordId: 'meal_a',
            mutationType: RecoverableUserEventMutationType.restore,
            beforePayload: edited.toJson(),
            afterPayload: original.toJson(),
            recordedAtUtc: DateTime.utc(2026, 8, 18, 12, 2),
            source: 'test',
            restoresHistoryId: updated.historyId,
          );
          await store.commitRecoverableUserEventMutation(
            RecoverableUserEventMutation(revision: restore),
          );
          expect((await database.loadMeals()).single.title, 'Original');
          expect(await store.loadRecoverableUserEventHistory(), hasLength(3));

          await database.saveMeals(<Meal>[_meal('meal_a', 'External edit')]);
          final staleRestore = RecoverableUserEventRevision.create(
            operationId: 'event_op_stale',
            eventType: RecoverableUserEventType.meal,
            recordId: 'meal_a',
            mutationType: RecoverableUserEventMutationType.restore,
            beforePayload: original.toJson(),
            afterPayload: edited.toJson(),
            recordedAtUtc: DateTime.utc(2026, 8, 18, 12, 3),
            source: 'test',
            restoresHistoryId: restore.historyId,
          );
          await expectLater(
            store.commitRecoverableUserEventMutation(
              RecoverableUserEventMutation(revision: staleRestore),
            ),
            throwsA(isA<RecoverableUserEventConflict>()),
          );
          expect((await database.loadMeals()).single.title, 'External edit');
          expect(await store.loadRecoverableUserEventHistory(), hasLength(3));
        },
      );
    }

    test(
      'web migrates legacy meals into the v2 aggregate on first mutation',
      () async {
        final original = _meal('meal_legacy', 'Legacy');
        SharedPreferences.setMockInitialValues(<String, Object>{
          'db.meals': jsonEncode(<Object?>[original.toJson()]),
        });
        final database = WebAppDatabase();
        expect((await database.loadMeals()).single.title, 'Legacy');
        final deleted = _revision(
          operationId: 'event_op_migrate',
          recordId: 'meal_legacy',
          mutationType: RecoverableUserEventMutationType.delete,
          before: original.toJson(),
          after: null,
        );
        await database.commitRecoverableUserEventMutation(
          RecoverableUserEventMutation(revision: deleted),
        );
        final prefs = await SharedPreferences.getInstance();
        final aggregate =
            jsonDecode(prefs.getString('db.user_state.v1')!)
                as Map<String, dynamic>;
        expect(aggregate['schemaVersion'], 2);
        expect(aggregate['meals'], isEmpty);
        expect(aggregate['eventHistory'], hasLength(1));
      },
    );
  });

  test('AppState delete and restore survive a fresh state instance', () async {
    final database = InMemoryAppDatabase();
    final firstServices = Services.createEphemeral(appDatabase: database);
    await firstServices.ready;
    final first = AppState(services: firstServices);
    addTearDown(first.dispose);
    await first.bootstrap();
    final meal = _meal('meal_restart', 'Before delete');
    expect((await first.addMeal(meal)).wasCommitted, isTrue);
    expect((await first.updateMeal(meal)).wasCommitted, isFalse);
    expect(first.recoverableEventHistory, hasLength(1));
    expect((await first.deleteMeal(meal.id)).wasCommitted, isTrue);
    final deletion = first.latestRecoverableRevisionFor(
      eventType: RecoverableUserEventType.meal,
      recordId: meal.id,
    );
    expect(deletion?.mutationType, RecoverableUserEventMutationType.delete);

    final secondServices = Services.createEphemeral(appDatabase: database);
    await secondServices.ready;
    final second = AppState(services: secondServices);
    addTearDown(second.dispose);
    await second.bootstrap();
    expect(second.meals, isEmpty);
    expect(await second.restoreRecoverableEvent(deletion!.historyId), isTrue);
    expect(second.meals.single.title, 'Before delete');
    expect(
      second.recoverableEventHistory.first.mutationType,
      RecoverableUserEventMutationType.restore,
    );
  });
}

RecoverableUserEventRevision _revision({
  required String operationId,
  String recordId = 'meal_a',
  required RecoverableUserEventMutationType mutationType,
  required Map<String, Object?>? before,
  required Map<String, Object?>? after,
}) => RecoverableUserEventRevision.create(
  operationId: operationId,
  eventType: RecoverableUserEventType.meal,
  recordId: recordId,
  mutationType: mutationType,
  beforePayload: before,
  afterPayload: after,
  recordedAtUtc: DateTime.utc(2026, 8, 18, 12),
  source: 'test',
);

Meal _meal(String id, String title) => Meal(
  id: id,
  eatenAt: DateTime.utc(2026, 8, 18, 8),
  recordedAt: DateTime.utc(2026, 8, 18, 8, 1),
  occurredAt: DateTime.utc(2026, 8, 18, 8),
  timeSource: 'test',
  timePrecision: 'exact',
  title: title,
  items: const <MealItem>[],
);
