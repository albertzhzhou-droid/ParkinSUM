import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/domain/usecases/recoverable_event_restore_impact_service.dart';

const _algorithmDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  const service = RecoverableEventRestoreImpactService();

  test(
    'meal deletion preview binds relationship and derived invalidations',
    () {
      final meal = _meal('meal_a', 'food_a');
      final revision = _revision(
        eventType: RecoverableUserEventType.meal,
        mutationType: RecoverableUserEventMutationType.delete,
        recordId: meal.id,
        before: meal.toJson(),
        after: null,
      );
      final preview = service.build(
        revision: revision,
        currentPayload: null,
        accountScope: 'local-user-a',
        algorithmConfigurationDigest: _algorithmDigest,
        foodsById: <String, Map<String, Object?>>{
          'food_a': Map<String, Object?>.from(_food('food_a', 8).toJson()),
        },
        drugsById: const <String, Map<String, Object?>>{},
      );

      expect(preview.status, RecoverableEventRestoreImpactStatus.ready);
      expect(preview.isConfirmable, isTrue);
      expect(
        preview.targetAction,
        RecoverableEventRestoreTargetAction.restorePriorState,
      );
      expect(preview.currentRelationships, isEmpty);
      expect(preview.restoredRelationships, <String>['food:food_a']);
      expect(preview.addedRelationships, <String>['food:food_a']);
      expect(preview.missingRelationships, isEmpty);
      expect(
        preview.invalidatedDerivedArtifacts,
        containsAll(<String>[
          'meal_check',
          'recommendation_explanations',
          'mechanistic_trace',
          'personal_log_handoff',
          'portable_package_relationships',
        ]),
      );
      expect(preview.retainsImmutableHistory, isTrue);
      expect(preview.previewId, startsWith('restore_preview_'));
      expect(
        preview.toJson()['relationship_graph_version'],
        recoverableEventRestoreRelationshipGraphVersion,
      );
    },
  );

  test('unresolved restored catalog relationship blocks confirmation', () {
    final meal = _meal('meal_missing', 'food_missing');
    final revision = _revision(
      eventType: RecoverableUserEventType.meal,
      mutationType: RecoverableUserEventMutationType.delete,
      recordId: meal.id,
      before: meal.toJson(),
      after: null,
    );
    final preview = service.build(
      revision: revision,
      currentPayload: null,
      accountScope: 'local-user-a',
      algorithmConfigurationDigest: _algorithmDigest,
      foodsById: const <String, Map<String, Object?>>{},
      drugsById: const <String, Map<String, Object?>>{},
    );

    expect(
      preview.status,
      RecoverableEventRestoreImpactStatus.blockedRelationships,
    );
    expect(preview.isConfirmable, isFalse);
    expect(preview.missingRelationships, <String>['food:food_missing']);
  });

  test(
    'update preview reports deterministic relationship delta and dedupes',
    () {
      final before = Meal(
        id: 'meal_relationship_update',
        eatenAt: DateTime.utc(2026, 8, 18, 8),
        title: 'Before',
        items: <MealItem>[
          MealItem.fromFood(food: _food('food_a', 8), quantityFactor: 1),
          MealItem.fromFood(food: _food('food_a', 8), quantityFactor: 0.5),
        ],
      );
      final after = _meal(before.id, 'food_b').copyWith(title: 'After');
      final revision = _revision(
        eventType: RecoverableUserEventType.meal,
        mutationType: RecoverableUserEventMutationType.update,
        recordId: before.id,
        before: before.toJson(),
        after: after.toJson(),
      );
      final preview = service.build(
        revision: revision,
        currentPayload: after.toJson(),
        accountScope: 'local-user-a',
        algorithmConfigurationDigest: _algorithmDigest,
        foodsById: <String, Map<String, Object?>>{
          'food_a': Map<String, Object?>.from(_food('food_a', 8).toJson()),
          'food_b': Map<String, Object?>.from(_food('food_b', 10).toJson()),
        },
        drugsById: const <String, Map<String, Object?>>{},
      );

      expect(preview.status, RecoverableEventRestoreImpactStatus.ready);
      expect(preview.currentRelationships, <String>['food:food_b']);
      expect(preview.restoredRelationships, <String>['food:food_a']);
      expect(preview.addedRelationships, <String>['food:food_a']);
      expect(preview.removedRelationships, <String>['food:food_b']);
    },
  );

  test('record, account, algorithm, and catalog drift change the preview', () {
    final meal = _meal('meal_drift', 'food_a');
    final revision = _revision(
      eventType: RecoverableUserEventType.meal,
      mutationType: RecoverableUserEventMutationType.update,
      recordId: meal.id,
      before: meal.toJson(),
      after: meal.copyWith(title: 'After').toJson(),
    );
    final foods = <String, Map<String, Object?>>{
      'food_a': Map<String, Object?>.from(_food('food_a', 8).toJson()),
    };
    RecoverableEventRestoreImpactPreview build({
      String account = 'local-user-a',
      String algorithm = _algorithmDigest,
      Map<String, Object?>? current,
      Map<String, Map<String, Object?>>? catalog,
    }) => service.build(
      revision: revision,
      currentPayload: current ?? revision.afterPayload,
      accountScope: account,
      algorithmConfigurationDigest: algorithm,
      foodsById: catalog ?? foods,
      drugsById: const <String, Map<String, Object?>>{},
    );

    final baseline = build();
    final accountChanged = build(account: 'local-user-b');
    final algorithmChanged = build(
      algorithm:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    final catalogChanged = build(
      catalog: <String, Map<String, Object?>>{
        'food_a': Map<String, Object?>.from(_food('food_a', 12).toJson()),
      },
    );
    final recordChanged = build(
      current: meal.copyWith(title: 'Newer').toJson(),
    );

    expect(baseline.status, RecoverableEventRestoreImpactStatus.ready);
    expect(accountChanged.previewId, isNot(baseline.previewId));
    expect(algorithmChanged.previewId, isNot(baseline.previewId));
    expect(catalogChanged.previewId, isNot(baseline.previewId));
    expect(
      recordChanged.status,
      RecoverableEventRestoreImpactStatus.staleRecord,
    );
    expect(recordChanged.previewId, isNot(baseline.previewId));
  });

  test(
    'restoring a create predicts removal without requiring a catalog link',
    () {
      final intake = Intake(
        id: 'intake_a',
        drugId: 'drug_missing',
        takenAt: DateTime.utc(2026, 8, 18, 9),
        dosageNote: '1 tablet',
      );
      final revision = _revision(
        eventType: RecoverableUserEventType.intake,
        mutationType: RecoverableUserEventMutationType.create,
        recordId: intake.id,
        before: null,
        after: intake.toJson(),
      );
      final preview = service.build(
        revision: revision,
        currentPayload: intake.toJson(),
        accountScope: 'local-user-a',
        algorithmConfigurationDigest: _algorithmDigest,
        foodsById: const <String, Map<String, Object?>>{},
        drugsById: const <String, Map<String, Object?>>{},
      );

      expect(preview.status, RecoverableEventRestoreImpactStatus.ready);
      expect(
        preview.targetAction,
        RecoverableEventRestoreTargetAction.removeRecord,
      );
      expect(preview.currentRelationships, <String>['drug:drug_missing']);
      expect(preview.restoredRelationships, isEmpty);
      expect(preview.removedRelationships, <String>['drug:drug_missing']);
      expect(preview.missingRelationships, isEmpty);
    },
  );
}

RecoverableUserEventRevision _revision({
  required RecoverableUserEventType eventType,
  required RecoverableUserEventMutationType mutationType,
  required String recordId,
  required Map<String, Object?>? before,
  required Map<String, Object?>? after,
}) => RecoverableUserEventRevision.create(
  operationId: 'op_${recordId}_${mutationType.name}',
  eventType: eventType,
  recordId: recordId,
  mutationType: mutationType,
  beforePayload: before,
  afterPayload: after,
  recordedAtUtc: DateTime.utc(2026, 8, 18, 12),
  source: 'restore_impact_test',
);

Meal _meal(String id, String foodId) => Meal(
  id: id,
  eatenAt: DateTime.utc(2026, 8, 18, 8),
  title: 'Breakfast',
  items: <MealItem>[
    MealItem.fromFood(food: _food(foodId, 8), quantityFactor: 1),
  ],
);

FoodItem _food(String id, double protein) => FoodItem(
  id: id,
  name: id,
  category: FoodCategory.other,
  proteinG: protein,
  carbsG: 10,
  fatG: 2,
  fiberG: 1,
  sodiumMg: 20,
);
