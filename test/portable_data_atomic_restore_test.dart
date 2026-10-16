import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/portable_data_restore_coordinator.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = 'local_synthetic_owner';
const _effective = 'opaque_synthetic_owner';
const _kind = 'local_device_account';
final _time = DateTime.utc(2026, 9, 29, 12);
final _food = FoodItem(
  id: 'synthetic_food',
  name: 'Synthetic source food',
  category: FoodCategory.other,
  proteinG: 0,
  carbsG: 10,
  fatG: 1,
  fiberG: 2,
  sodiumMg: 3,
  missingNutrientFields: const {'proteinG', 'energyKcal', 'waterG'},
  sourceSystem: 'SYNTHETIC_TEST',
  sourceFoodCode: 'fixture_1',
  basisType: 'per_100g',
  preparationState: 'raw',
);
Meal _meal(String id) => Meal(
  id: id,
  eatenAt: _time,
  recordedAt: _time.add(const Duration(minutes: 5)),
  occurredAt: _time,
  timeSource: 'user_entered',
  title: 'Synthetic meal',
  items: [MealItem.fromFood(food: _food, quantityFactor: 1.5)],
);
String _package({
  List<Meal>? meals,
  List<Intake> intakes = const [],
  List<UserLoggingReminder> reminders = const [],
  List<PersonalObservation> observations = const [],
  String effective = _effective,
  List<FoodItem>? foods,
}) => const UserPortableDataPackageService()
    .create(
      snapshot: UserPortableDataSnapshot(
        userScope: effective,
        doseOwnerScope: _owner,
        scopeKind: _kind,
        profile: UserProfile.defaults().copyWith(patientId: _owner),
        activeDrugIds: const [],
        intakes: intakes,
        meals: meals ?? [_meal('incoming')],
        medicationCatalog: const [],
        foodCatalog: foods ?? [_food],
        reminders: reminders,
        observations: observations,
      ),
      generatedAt: _time.add(const Duration(hours: 1)),
    )
    .prettyJson;
Future<PortableDataRestoreRequest> _prepare(
  WebAppDatabase db,
  String text, {
  List<FoodItem>? foods,
  bool Function()? authorize,
}) => PortableDataRestoreCoordinator(store: db).prepare(
  packageJson: text,
  ownerScope: _owner,
  effectiveOwnerScope: _effective,
  scopeKind: _kind,
  foodCatalog: foods ?? [_food],
  medicationCatalog: const [],
  authorize: authorize ?? () => true,
);
Future<PortableDataRestoreReceipt> _commit(
  WebAppDatabase db,
  PortableDataRestoreRequest request,
  String text, {
  bool confirmed = true,
  bool Function()? authorize,
}) => PortableDataRestoreCoordinator(store: db).commit(
  request: request,
  currentPackageJson: text,
  explicitlyConfirmed: confirmed,
  authorize: authorize ?? () => true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'v4 semantic round-trip preserves unknown values, provenance and times',
    () async {
      final db = WebAppDatabase();
      final text = _package();
      final request = await _prepare(db, text);
      final before = await db.loadPortableRestoreState();
      final receipt = await _commit(db, request, text);
      expect(receipt.beforeDigest, before.digest);
      final restored = (await db.loadMeals()).single;
      expect(restored.items.single.isNutrientMissing('proteinG'), isTrue);
      expect(restored.recordedAt, _time.add(const Duration(minutes: 5)));
      final reexport = const UserPortableDataPackageService().create(
        snapshot: UserPortableDataSnapshot(
          userScope: _effective,
          doseOwnerScope: _owner,
          scopeKind: _kind,
          profile: await db.loadUserProfile(),
          activeDrugIds: await db.loadActiveDrugIds(),
          intakes: await db.loadIntakes(),
          meals: await db.loadMeals(),
          medicationCatalog: const [],
          foodCatalog: [_food],
          reminders: const [],
        ),
        generatedAt: _time.add(const Duration(hours: 1)),
      );
      expect(
        (jsonDecode(reexport.prettyJson) as Map)['files'],
        (jsonDecode(text) as Map)['files'],
      );
      expect(receipt.json['sourcePackageJson'], text);
      expect((await db.loadUserProfile()).hasCurrentLocalAiConsent, isFalse);
    },
  );

  test(
    'captured unknown survives export and restore without a catalogue row',
    () async {
      final db = WebAppDatabase();
      final text = _package(foods: const []);
      final item =
          ((((jsonDecode(text) as Map)['files'] as Map)['meals.json'] as List)
                      .single
                  as Map)['items']
              as List;
      final protein =
          ((item.single as Map)['nutrientsPer100g'] as Map)['protein'] as Map;
      expect(protein['missing'], isTrue);
      expect(protein['value'], isNull);
      expect((item.single as Map)['catalogProvenance'], {
        'status': 'unresolved_at_export',
      });
      final request = await _prepare(db, text, foods: const []);
      await _commit(db, request, text);
      expect(
        (await db.loadMeals()).single.items.single.isNutrientMissing(
          'proteinG',
        ),
        isTrue,
      );
    },
  );

  test(
    'later known catalogue values do not replace captured unknown',
    () async {
      final db = WebAppDatabase();
      final known = FoodItem.fromJson({
        ..._food.toJson(),
        'missingNutrientFields': <String>[],
        'proteinG': 5,
      });
      final text = _package(foods: [known]);
      final request = await _prepare(db, text, foods: [known]);
      await _commit(db, request, text);
      expect(
        (await db.loadMeals()).single.items.single.isNutrientMissing(
          'proteinG',
        ),
        isTrue,
      );
    },
  );

  test(
    'merge preserves existing records and immutable recovery history',
    () async {
      final db = WebAppDatabase();
      await db.saveUserProfile(
        UserProfile.defaults().copyWith(patientId: _owner),
      );
      final revision = RecoverableUserEventRevision.create(
        operationId: 'synthetic_existing_op',
        eventType: RecoverableUserEventType.meal,
        recordId: 'existing',
        mutationType: RecoverableUserEventMutationType.create,
        beforePayload: null,
        afterPayload: _meal('existing').toJson(),
        recordedAtUtc: _time,
        source: 'synthetic_test',
      );
      await db.commitRecoverableUserEventMutation(
        RecoverableUserEventMutation(revision: revision),
      );
      final text = _package();
      final request = await _prepare(db, text);
      await _commit(db, request, text);
      expect((await db.loadMeals()).map((row) => row.id), [
        'existing',
        'incoming',
      ]);
      expect(
        (await db.loadRecoverableUserEventHistory()).single.toJson(),
        revision.toJson(),
      );
      await expectLater(_prepare(db, text), throwsStateError);
    },
  );

  test('same IDs with edited content make a prepared request stale', () async {
    final db = WebAppDatabase();
    await db.saveUserProfile(
      UserProfile.defaults().copyWith(patientId: _owner),
    );
    await db.saveMeals([_meal('existing')]);
    final text = _package();
    final request = await _prepare(db, text);
    await db.saveMeals([
      _meal('existing').copyWith(title: 'Changed source record'),
    ]);
    final afterEdit = (await db.loadPortableRestoreState()).digest;
    await expectLater(_commit(db, request, text), throwsStateError);
    expect((await db.loadPortableRestoreState()).digest, afterEdit);
  });

  test(
    'confirmation, changed package bytes and changed owner reject writing',
    () async {
      final db = WebAppDatabase();
      final text = _package();
      final request = await _prepare(db, text);
      final before = (await db.loadPortableRestoreState()).digest;
      await expectLater(
        _commit(db, request, text, confirmed: false),
        throwsStateError,
      );
      await expectLater(_commit(db, request, '$text '), throwsStateError);
      await expectLater(
        _commit(db, request, text, authorize: () => false),
        throwsStateError,
      );
      await expectLater(
        _prepare(db, _package(effective: 'another_owner')),
        throwsStateError,
      );
      expect((await db.loadPortableRestoreState()).digest, before);
    },
  );

  test('unknown versions and fields reject writing', () async {
    final db = WebAppDatabase();
    final before = (await db.loadPortableRestoreState()).digest;
    final source = jsonDecode(_package()) as Map;
    source['schemaVersion'] = 99;
    await expectLater(_prepare(db, jsonEncode(source)), throwsStateError);
    final unknown = jsonDecode(_package()) as Map;
    unknown['unknownField'] = 'unsupported';
    await expectLater(_prepare(db, jsonEncode(unknown)), throwsStateError);
    expect((await db.loadPortableRestoreState()).digest, before);
  });

  test(
    'nonempty observations and reminders remain outside the transaction',
    () async {
      final db = WebAppDatabase();
      final observation = PersonalObservation.create(
        id: 'synthetic_observation',
        kind: PersonalObservationKind.symptom,
        occurredAt: _time,
        recordedAt: _time,
        originalTimezone: 'UTC',
        source: PersonalObservationSource.selfReported,
        recorderId: _owner,
        status: PersonalObservationStatus.unknown,
        symptomLabel: 'Synthetic symptom',
      );
      await expectLater(
        _prepare(db, _package(observations: [observation])),
        throwsStateError,
      );
      await expectLater(
        _prepare(
          db,
          _package(
            reminders: [
              const UserLoggingReminder(
                id: 'synthetic_reminder',
                kind: UserLoggingReminderKind.mealLog,
                label: 'Synthetic prompt',
                minuteOfDay: 600,
                weekdays: {1},
                enabled: false,
              ),
            ],
          ),
        ),
        throwsStateError,
      );
      expect(await db.loadMeals(), isEmpty);
    },
  );

  test(
    'changed catalogue provenance and a lossy zero dose remain held',
    () async {
      final db = WebAppDatabase();
      await expectLater(
        _prepare(
          db,
          _package(),
          foods: [
            FoodItem.fromJson({..._food.toJson(), 'sourceFoodCode': 'changed'}),
          ],
        ),
        throwsStateError,
      );
      await expectLater(
        _prepare(
          db,
          _package(
            meals: [],
            intakes: [
              Intake(
                id: 'zero_dose',
                drugId: 'synthetic_drug',
                takenAt: _time,
                dosageNote: '',
                doseAmount: 0,
                doseUnit: 'mg',
              ),
            ],
          ),
        ),
        throwsStateError,
      );
      expect(await db.loadIntakes(), isEmpty);
    },
  );

  test(
    'failure before atomic publication preserves the entire old state',
    () async {
      var fail = false;
      final db = WebAppDatabase(
        userStateWriter: (prefs, key, value) async {
          if (fail) throw StateError('synthetic_write_failure');
          return prefs.setString(key, value);
        },
      );
      await db.saveUserProfile(
        UserProfile.defaults().copyWith(patientId: _owner),
      );
      await db.saveMeals([_meal('existing')]);
      final text = _package();
      final request = await _prepare(db, text);
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString('db.user_state.v1');
      fail = true;
      await expectLater(_commit(db, request, text), throwsStateError);
      await prefs.reload();
      expect(prefs.getString('db.user_state.v1'), before);
      fail = false;
      await _commit(db, request, text);
      expect(await db.loadMeals(), hasLength(2));
    },
  );

  test(
    'lost acknowledgment is read back and retry after restart is idempotent',
    () async {
      final db = WebAppDatabase(
        userStateWriter: (prefs, key, value) async {
          await prefs.setString(key, value);
          throw StateError('synthetic_lost_ack');
        },
      );
      final text = _package();
      final request = await _prepare(db, text);
      final first = await _commit(db, request, text);
      final restarted = WebAppDatabase();
      final retried = await _commit(restarted, request, text);
      expect(retried.canonicalJson, first.canonicalJson);
      expect(await restarted.loadMeals(), hasLength(1));
      expect(
        (await restarted.loadPortableRestoreState()).digest,
        first.afterDigest,
      );
    },
  );

  for (final corruption in ['source_bytes', 'declared_digest']) {
    test(
      'cached source digest refuses changed receipt $corruption without publishing',
      () async {
        final db = WebAppDatabase();
        final text = _package();
        final request = await _prepare(db, text);
        final receipt = await _commit(db, request, text);
        expect(
          (await db.loadPortableRestoreState()).digest,
          receipt.afterDigest,
        );
        final preferences = await SharedPreferences.getInstance();
        final original = preferences.getString('db.user_state.v1')!;
        final changed = jsonDecode(original) as Map;
        final storedReceipt = changed['portableRestoreReceipt'] as Map;
        if (corruption == 'source_bytes') {
          // Equal decoded package semantics still have different exact bytes.
          storedReceipt['sourcePackageJson'] = '$text\n';
        } else {
          storedReceipt['packageJsonSha256'] = portableRestoreBytesDigest(
            '$text\n',
          );
        }
        final corrupted = jsonEncode(changed);
        await preferences.setString('db.user_state.v1', corrupted);
        await expectLater(db.loadPortableRestoreState(), throwsFormatException);
        await expectLater(db.saveOnboarded(true), throwsFormatException);
        await expectLater(
          WebAppDatabase().loadPortableRestoreState(),
          throwsFormatException,
        );
        await preferences.reload();
        expect(preferences.getString('db.user_state.v1'), corrupted);

        await preferences.setString('db.user_state.v1', original);
        expect(
          (await db.loadPortableRestoreState()).digest,
          receipt.afterDigest,
        );
        // An unchanged source receipt must not cache mutable profile or rows.
        final edited = jsonDecode(original) as Map;
        (edited['profile'] as Map)['displayLocale'] = 'zh-CN';
        await preferences.setString('db.user_state.v1', jsonEncode(edited));
        expect((await db.loadUserProfile()).displayLocale, 'zh-CN');
        expect(await db.loadPortableRestoreReceipt(ownerScope: _owner), isNull);
      },
    );
  }

  test(
    'exact-state rollback is recoverable and refuses later modifications',
    () async {
      final db = WebAppDatabase();
      final text = _package();
      final request = await _prepare(db, text);
      final receipt = await _commit(db, request, text);
      expect(
        await WebAppDatabase().loadPortableRestoreReceipt(ownerScope: _owner),
        isNotNull,
      );
      expect(
        await WebAppDatabase().loadPortableRestoreReceipt(
          ownerScope: 'other_owner',
        ),
        isNull,
      );
      await expectLater(
        db.rollbackPortableRestore(
          receipt,
          ownerScope: 'other_owner',
          authorize: () => true,
        ),
        throwsStateError,
      );
      await db.rollbackPortableRestore(
        receipt,
        ownerScope: _owner,
        authorize: () => true,
      );
      expect(
        (await db.loadPortableRestoreState()).digest,
        receipt.beforeDigest,
      );
      await WebAppDatabase().rollbackPortableRestore(
        receipt,
        ownerScope: _owner,
        authorize: () => true,
      );
      await expectLater(_commit(db, request, text), throwsStateError);
      final next = await _prepare(db, _package(meals: [_meal('next')]));
      final second = await _commit(db, next, _package(meals: [_meal('next')]));
      await db.saveMeals([_meal('next').copyWith(title: 'Later edit')]);
      final afterEdit = (await db.loadPortableRestoreState()).digest;
      await expectLater(
        db.rollbackPortableRestore(
          second,
          ownerScope: _owner,
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect((await db.loadPortableRestoreState()).digest, afterEdit);
    },
  );
}
