import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/atomic_onboarding_commit.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/recoverable_user_event.dart';
import '../models/user_profile.dart';
import '../models/user_preference_write_scope.dart';
import '../models/portable_data_restore.dart';
import '../services/origin_storage_coordination.dart';
import '../../data/models/interaction_rule_record.dart';
import '../../domain/entities/mechanistic_replay_capsule.dart';
import 'app_database.dart';
import 'recoverable_user_event_store.dart';
import 'portable_data_restore_store.dart';
import 'web_user_state_store.dart';
import 'web_user_state_store_factory.dart';

class WebAppDatabase
    implements
        AppDatabase,
        RecoverableUserEventStore,
        PortableDataRestoreStore,
        ScopedUserPreferenceStore {
  WebAppDatabase({this.userStateWriter, WebUserStateStore? userStateStore})
    : _providedUserStateStore = userStateStore {
    if (userStateWriter != null && userStateStore != null) {
      throw ArgumentError('Choose one personal-record storage test seam.');
    }
  }

  /// Fault-injection seam for atomic-write and lost-acknowledgment tests.
  final Future<bool> Function(
    SharedPreferences prefs,
    String key,
    String value,
  )?
  userStateWriter;
  final WebUserStateStore? _providedUserStateStore;
  late final WebUserStateStore? _userStateStore = userStateWriter != null
      ? null
      : _providedUserStateStore ?? createWebUserStateStore();

  String get userStateBackendId =>
      _userStateStore?.backendId ?? 'SharedPreferences / explicit test backend';
  static const _kOnboarded = 'db.meta.onboarded';
  static const _kActiveDrugs = 'db.active_drugs';
  static const _kMeals = 'db.meals';
  static const _kIntakes = 'db.intakes';
  static const _kFoods = 'db.foods';
  static const _kMedications = 'db.medications';
  static const _kRules = 'db.rules';
  static const _kUserProfile = 'db.user_profile';
  static const _kUserState = 'db.user_state.v1';
  static const _kMechanisticReplayCapsules =
      'db.mechanistic_replay_capsules.v1';

  SharedPreferences? _prefs;
  static Future<void> _userStateTail = Future<void>.value();
  static Future<void> _replayCapsuleTail = Future<void>.value();

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<T> _serializeUserState<T>(Future<T> Function() operation) {
    final result = _userStateTail.then((_) => operation());
    // Enqueue reads as well as writes before either starts. Same-isolate
    // Future.wait consumers must not compete for the fail-fast origin lock.
    _userStateTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<_WebUserState> _loadUserState() => _serializeUserState(() async {
    final prefs = await _ensure();
    final store = _userStateStore;
    if (store == null) {
      await prefs.reload();
      return _readUserState(prefs, prefs.getString(_kUserState));
    }
    return withOriginStorageLock('user_state.v1', () async {
      await prefs.reload();
      // Validate the original schema before preserving it in a new backend.
      _readUserState(prefs, prefs.getString(_kUserState));
      final aggregate = await store.read(_legacyUserStateSnapshot(prefs));
      return _readUserState(prefs, aggregate);
    });
  });

  WebUserStateLegacySnapshot _legacyUserStateSnapshot(
    SharedPreferences prefs,
  ) => WebUserStateLegacySnapshot({
    for (final key in webUserStateLegacyKeys) key: prefs.getString(key),
  });

  _WebUserState _readUserState(SharedPreferences prefs, String? aggregate) {
    final legacyMealsRaw = prefs.getString(_kMeals);
    final legacyMeals = legacyMealsRaw == null
        ? const <Meal>[]
        : (jsonDecode(legacyMealsRaw) as List<dynamic>)
              .map(
                (value) =>
                    Meal.fromJson(Map<String, dynamic>.from(value as Map)),
              )
              .toList(growable: false);
    if (aggregate != null) {
      return _WebUserState.fromJson(
        Map<String, dynamic>.from(jsonDecode(aggregate) as Map),
        legacyMeals: legacyMeals,
      );
    }
    final profileRaw = prefs.getString(_kUserProfile);
    final activeRaw = prefs.getString(_kActiveDrugs);
    final intakesRaw = prefs.getString(_kIntakes);
    return _WebUserState(
      onboarded: prefs.getString(_kOnboarded) == 'true',
      profile: profileRaw == null
          ? UserProfile.defaults()
          : UserProfile.fromJson(
              jsonDecode(profileRaw) as Map<String, dynamic>,
            ),
      activeDrugIds: activeRaw == null
          ? const <String>[]
          : (jsonDecode(activeRaw) as List<dynamic>)
                .map((value) => value.toString())
                .toList(growable: false),
      intakes: intakesRaw == null
          ? const <Intake>[]
          : (jsonDecode(intakesRaw) as List<dynamic>)
                .map((value) => Intake.fromJson(value as Map<String, dynamic>))
                .toList(growable: false),
      meals: legacyMeals,
      eventHistory: const <RecoverableUserEventRevision>[],
    );
  }

  Future<void> _mutateUserState(
    _WebUserState Function(_WebUserState current) transform, {
    bool Function()? authorize,
  }) {
    return _serializeUserState(
      () => withOriginStorageLock<void>('user_state.v1', () async {
        final prefs = await _ensure();
        await prefs.reload();
        if (authorize != null && !authorize()) {
          throw StateError('portable_restore_scope_changed');
        }
        final store = _userStateStore;
        final legacy = _legacyUserStateSnapshot(prefs);
        if (store != null) {
          _readUserState(prefs, prefs.getString(_kUserState));
        }
        final aggregate = store == null
            ? prefs.getString(_kUserState)
            : await store.read(legacy);
        final current = _readUserState(prefs, aggregate);
        final next = transform(current);
        if (identical(next, current)) return;
        if (authorize != null && !authorize()) {
          throw StateError('portable_restore_scope_changed');
        }
        final encoded = jsonEncode(next.toJson());
        try {
          if (store == null) {
            final saved =
                await (userStateWriter?.call(prefs, _kUserState, encoded) ??
                    prefs.setString(_kUserState, encoded));
            if (!saved) {
              throw StateError('Web user-state persistence was rejected.');
            }
          } else {
            await prefs.reload();
            await store.write(
              encoded,
              expectedDocument: aggregate,
              legacy: _legacyUserStateSnapshot(prefs),
              authorize: authorize ?? () => true,
            );
          }
          await prefs.reload();
          final observed = store == null
              ? prefs.getString(_kUserState)
              : await store.read(_legacyUserStateSnapshot(prefs));
          if (observed != encoded) {
            throw StateError('Web user-state write did not persist exactly.');
          }
          try {
            if (store != null && authorize != null && !authorize()) {
              throw StateError('portable_restore_scope_changed');
            }
          } on UserPreferenceWriteScopeChanged {
            throw const UserPreferenceWriteCommittedForPreviousSession();
          }
        } on UserPreferenceWriteCommittedForPreviousSession {
          rethrow;
        } catch (error, stackTrace) {
          // The platform can commit and then lose its acknowledgment. Read the
          // persisted single value before deciding whether retry is necessary.
          await prefs.reload();
          if (store != null && authorize != null) {
            final bool authorized;
            try {
              authorized = authorize();
            } on UserPreferenceWriteScopeChanged {
              // Expiry cannot turn an earlier storage error into a claim that
              // the operation was cancelled before persistence.
              Error.throwWithStackTrace(error, stackTrace);
            }
            if (!authorized) rethrow;
          }
          final observed = store == null
              ? prefs.getString(_kUserState)
              : await store.read(_legacyUserStateSnapshot(prefs));
          if (observed != encoded) rethrow;
        }
      }),
    );
  }

  @override
  Future<PortableDataRestoreState> loadPortableRestoreState() async =>
      PortableDataRestoreState((await _loadUserState()).toJson());

  @override
  Future<PortableDataRestoreReceipt?> loadPortableRestoreReceipt({
    required String ownerScope,
  }) async {
    final current = await _loadUserState();
    final receipt = current.portableRestoreReceipt;
    return receipt != null &&
            receipt['ownerScope'] == ownerScope &&
            current.profile.patientId == ownerScope &&
            receipt['rolledBack'] != true &&
            receipt['afterDigest'] ==
                PortableDataRestoreState(current.toJson()).digest
        ? PortableDataRestoreReceipt(receipt)
        : null;
  }

  @override
  Future<PortableDataRestoreReceipt> commitPortableRestore(
    PortableDataRestoreRequest request, {
    required bool Function() authorize,
  }) async {
    await _mutateUserState((current) {
      if (!authorize()) throw StateError('portable_restore_scope_changed');
      final witness = PortableDataRestoreState(current.toJson());
      final prior = current.portableRestoreReceipt;
      if (prior != null && prior['operationId'] == request.operationId) {
        if (prior['rolledBack'] != true &&
            prior['afterDigest'] == witness.digest) {
          return current;
        }
        throw StateError('portable_restore_retry_state_changed');
      }
      if (witness.digest != request.expectedStateDigest ||
          portableRestoreBytesDigest(request.sourcePackageJson) !=
              request.packageJsonSha256 ||
          (current.profile.patientId != request.ownerScope &&
              (current.profile.patientId != 'local_user' ||
                  witness.recordIds.values.any((ids) => ids.isNotEmpty)))) {
        throw StateError('portable_restore_stale_state_or_owner');
      }
      final payload = request.payload.json;
      final profile = UserProfile.fromJson(
        Map<String, dynamic>.from(payload['profile'] as Map),
      );
      if (profile.patientId != request.ownerScope) {
        throw StateError('portable_restore_payload_owner_mismatch');
      }
      final intakes = (payload['intakes'] as List)
          .map((row) => Intake.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
      final meals = (payload['meals'] as List)
          .map((row) => Meal.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
      final incomingIds = <String, Set<String>>{
        'intakes.json': intakes.map((row) => row.id).toSet(),
        'meals.json': meals.map((row) => row.id).toSet(),
        'medication_selections.json': <String>{
          ...(payload['activeDrugIds'] as List).cast<String>(),
          ...intakes.map((row) => row.drugId),
        },
      };
      if (incomingIds['intakes.json']!.length != intakes.length ||
          incomingIds['meals.json']!.length != meals.length ||
          incomingIds.entries.any(
            (entry) => entry.value
                .intersection(witness.recordIds[entry.key]!)
                .isNotEmpty,
          ) ||
          current.eventHistory.any(
            (revision) =>
                (revision.eventType == RecoverableUserEventType.meal
                        ? incomingIds['meals.json']!
                        : incomingIds['intakes.json']!)
                    .contains(revision.recordId),
          )) {
        throw StateError('portable_restore_record_or_history_conflict');
      }
      final next = current.copyWith(
        profile: profile,
        activeDrugIds: {
          ...current.activeDrugIds,
          ...(payload['activeDrugIds'] as List).cast<String>(),
        }.toList()..sort(),
        intakes: [...current.intakes, ...intakes],
        meals: [...current.meals, ...meals],
      );
      final receipt = <String, Object?>{
        'version': 1,
        'ownerScope': request.ownerScope,
        'operationId': request.operationId,
        'packageJsonSha256': request.packageJsonSha256,
        'sourcePackageJson': request.sourcePackageJson,
        'beforeDigest': witness.digest,
        'afterDigest': PortableDataRestoreState(next.toJson()).digest,
        'beforeState': witness.json,
        'rolledBack': false,
      };
      return next.copyWith(portableRestoreReceipt: receipt);
    }, authorize: authorize);
    final current = await _loadUserState();
    final receipt = current.portableRestoreReceipt;
    if (receipt == null || receipt['operationId'] != request.operationId) {
      throw StateError('portable_restore_receipt_changed');
    }
    return PortableDataRestoreReceipt(receipt);
  }

  @override
  Future<void> rollbackPortableRestore(
    PortableDataRestoreReceipt receipt, {
    required String ownerScope,
    required bool Function() authorize,
  }) => _mutateUserState((current) {
    if (!authorize()) throw StateError('portable_restore_scope_changed');
    final prior = current.portableRestoreReceipt;
    final digest = PortableDataRestoreState(current.toJson()).digest;
    if (prior == null ||
        prior['operationId'] != receipt.operationId ||
        prior['ownerScope'] != ownerScope ||
        receipt.json['ownerScope'] != ownerScope) {
      throw StateError('portable_restore_rollback_receipt_changed');
    }
    if (prior['rolledBack'] == true && digest == receipt.beforeDigest) {
      return current;
    }
    if (digest != receipt.afterDigest || prior['rolledBack'] == true) {
      throw StateError('portable_restore_rollback_state_changed');
    }
    final before = _WebUserState.fromJson(
      Map<String, dynamic>.from(prior['beforeState'] as Map),
    );
    if (PortableDataRestoreState(before.toJson()).digest !=
        receipt.beforeDigest) {
      throw StateError('portable_restore_rollback_snapshot_invalid');
    }
    return before.copyWith(
      portableRestoreReceipt: {...prior, 'rolledBack': true},
    );
  }, authorize: authorize);

  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) async {
    final prefs = await _ensure();

    // foods / medications / rules 都是受控目录种子，不是用户自由编辑内容；
    // 每次初始化都刷新一遍，确保新版目录能够覆盖旧版缓存。
    await prefs.setString(
      _kFoods,
      jsonEncode(seedFoods.map((food) => food.toJson()).toList()),
    );
    await prefs.setString(
      _kMedications,
      jsonEncode(
        seedMedications.map((medication) => medication.toJson()).toList(),
      ),
    );
    await prefs.setString(
      _kRules,
      jsonEncode(seedRules.map((rule) => rule.toJson()).toList()),
    );
  }

  @override
  Future<bool> loadOnboarded() async {
    return (await _loadUserState()).onboarded;
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    await _mutateUserState(
      (current) => current.copyWith(
        onboarded: value,
        clearOnboardingOperationId: !value,
      ),
    );
  }

  @override
  Future<UserProfile> loadUserProfile() async {
    return (await _loadUserState()).profile;
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    await _mutateUserState((current) => current.copyWith(profile: profile));
  }

  @override
  Future<void> saveUserProfileForSession(
    UserProfile profile, {
    required UserPreferenceWriteScope scope,
  }) async {
    scope.requireProfileOwner(profile);
    await _mutateUserState(
      (current) {
        scope.requireUnchangedProfile(current.profile);
        return current.copyWith(profile: profile);
      },
      authorize: () {
        scope.requireCurrent();
        return true;
      },
    );
  }

  @override
  Future<void> commitOnboarding(AtomicOnboardingCommit commit) async {
    await _mutateUserState((current) {
      if (current.onboarded &&
          current.onboardingOperationId == commit.operationId) {
        return current;
      }
      return _WebUserState(
        onboarded: true,
        profile: commit.profile,
        activeDrugIds: commit.activeDrugIds,
        intakes: commit.intakes,
        meals: current.meals,
        eventHistory: current.eventHistory,
        onboardingOperationId: commit.operationId,
      );
    });
  }

  @override
  Future<List<String>> loadActiveDrugIds() async {
    return List<String>.from((await _loadUserState()).activeDrugIds);
  }

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    await _mutateUserState((current) => current.copyWith(activeDrugIds: ids));
  }

  @override
  Future<void> saveActiveDrugIdsForSession(
    List<String> ids, {
    required UserPreferenceWriteScope scope,
  }) async {
    scope.requireCurrent();
    final snapshot = List<String>.unmodifiable(ids);
    await _mutateUserState(
      (current) {
        scope.requireUnchangedActiveSelection(current.activeDrugIds);
        return current.copyWith(activeDrugIds: snapshot);
      },
      authorize: () {
        scope.requireCurrent();
        return true;
      },
    );
  }

  @override
  Future<List<Meal>> loadMeals() async {
    return List<Meal>.from((await _loadUserState()).meals);
  }

  @override
  Future<void> saveMeals(List<Meal> meals) async {
    await _mutateUserState((current) => current.copyWith(meals: meals));
  }

  @override
  Future<List<Intake>> loadIntakes() async {
    return List<Intake>.from((await _loadUserState()).intakes);
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    await _mutateUserState((current) => current.copyWith(intakes: intakes));
  }

  @override
  Future<void> saveMechanisticReplayCapsule(MechanisticReplayCapsule capsule) {
    final snapshot = canonicalMechanisticReplayCapsuleSnapshot(capsule);
    final operation = _replayCapsuleTail.then(
      (_) => withOriginStorageLock<void>(
        'mechanistic_replay_capsules.v1',
        () async {
          final prefs = await _ensure();
          await prefs.reload();
          final capsules = _readMechanisticReplayCapsules(prefs).toList();
          final prior = capsules
              .where((entry) => entry.capsuleSha256 == snapshot.capsuleSha256)
              .firstOrNull;
          if (prior != null) {
            if (prior.canonicalJson != snapshot.canonicalJson) {
              throw StateError('Replay capsule digest collision.');
            }
            return;
          }
          capsules.add(snapshot);
          capsules.sort(compareMechanisticReplayCapsulesByGeneratedAt);
          final serialized = jsonEncode(
            capsules.map((entry) => entry.toJson()).toList(),
          );
          mechanisticReplayCapsulesFromJsonString(serialized);
          final saved = await prefs.setString(
            _kMechanisticReplayCapsules,
            serialized,
          );
          if (!saved) {
            throw StateError('Web replay capsule persistence was rejected.');
          }
        },
      ),
    );
    _replayCapsuleTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<List<MechanisticReplayCapsule>> loadMechanisticReplayCapsules() async {
    await _replayCapsuleTail;
    final prefs = await _ensure();
    await prefs.reload();
    final capsules = _readMechanisticReplayCapsules(prefs).toList()
      ..sort(compareMechanisticReplayCapsulesByGeneratedAt);
    return List<MechanisticReplayCapsule>.unmodifiable(capsules);
  }

  List<MechanisticReplayCapsule> _readMechanisticReplayCapsules(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_kMechanisticReplayCapsules);
    if (raw == null) return const <MechanisticReplayCapsule>[];
    final capsules = mechanisticReplayCapsulesFromJsonString(raw);
    final digests = capsules.map((entry) => entry.capsuleSha256).toSet();
    if (digests.length != capsules.length) {
      throw const FormatException(
        'Stored replay capsule digest is duplicated.',
      );
    }
    return capsules;
  }

  @override
  Future<List<FoodItem>> loadFoods() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kFoods);
    if (raw == null) return <FoodItem>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => FoodItem.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<DrugDefinition>> loadMedications() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kMedications);
    if (raw == null) return <DrugDefinition>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => DrugDefinition.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kRules);
    if (raw == null) return <InteractionRuleRecord>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map(
          (value) =>
              InteractionRuleRecord.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  @override
  Future<List<RecoverableUserEventRevision>>
  loadRecoverableUserEventHistory() async =>
      List<RecoverableUserEventRevision>.from(
        (await _loadUserState()).eventHistory.reversed,
      );

  @override
  Future<void> commitRecoverableUserEventMutation(
    RecoverableUserEventMutation mutation,
  ) async {
    final revision = mutation.revision..validate();
    await _mutateUserState((current) {
      final currentPayload = switch (revision.eventType) {
        RecoverableUserEventType.meal =>
          current.meals
              .where((meal) => meal.id == revision.recordId)
              .map((meal) => Map<String, Object?>.from(meal.toJson()))
              .firstOrNull,
        RecoverableUserEventType.intake =>
          current.intakes
              .where((intake) => intake.id == revision.recordId)
              .map((intake) => Map<String, Object?>.from(intake.toJson()))
              .firstOrNull,
      };
      final currentDigest = recoverableUserEventPayloadDigest(currentPayload);
      final prior = current.eventHistory
          .where(
            (entry) =>
                entry.historyId == revision.historyId ||
                entry.operationId == revision.operationId,
          )
          .toList(growable: false);
      if (prior.isNotEmpty) {
        if (prior.length != 1 ||
            prior.single.historyId != revision.historyId ||
            currentDigest != revision.afterDigest) {
          throw RecoverableUserEventConflict(
            recordId: revision.recordId,
            expectedDigest: revision.afterDigest,
            actualDigest: currentDigest,
          );
        }
        return current;
      }
      if (currentDigest != mutation.expectedCurrentDigest) {
        throw RecoverableUserEventConflict(
          recordId: revision.recordId,
          expectedDigest: mutation.expectedCurrentDigest,
          actualDigest: currentDigest,
        );
      }
      final history = <RecoverableUserEventRevision>[
        ...current.eventHistory,
        revision,
      ];
      switch (revision.eventType) {
        case RecoverableUserEventType.meal:
          final meals = current.meals
              .where((meal) => meal.id != revision.recordId)
              .toList(growable: true);
          if (revision.afterPayload != null) {
            meals.insert(
              0,
              Meal.fromJson(Map<String, dynamic>.from(revision.afterPayload!)),
            );
          }
          return current.copyWith(meals: meals, eventHistory: history);
        case RecoverableUserEventType.intake:
          final intakes = current.intakes
              .where((intake) => intake.id != revision.recordId)
              .toList(growable: true);
          if (revision.afterPayload != null) {
            intakes.insert(
              0,
              Intake.fromJson(
                Map<String, dynamic>.from(revision.afterPayload!),
              ),
            );
          }
          return current.copyWith(intakes: intakes, eventHistory: history);
      }
    });
  }
}

AppDatabase createAppDatabaseImpl() => WebAppDatabase();

class _WebUserState {
  _WebUserState({
    required this.onboarded,
    required this.profile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
    required List<Meal> meals,
    required List<RecoverableUserEventRevision> eventHistory,
    this.onboardingOperationId,
    this.portableRestoreReceipt,
  }) : activeDrugIds = List<String>.unmodifiable(activeDrugIds),
       intakes = List<Intake>.unmodifiable(intakes),
       meals = List<Meal>.unmodifiable(meals),
       eventHistory = List<RecoverableUserEventRevision>.unmodifiable(
         eventHistory,
       );

  final bool onboarded;
  final UserProfile profile;
  final List<String> activeDrugIds;
  final List<Intake> intakes;
  final List<Meal> meals;
  final List<RecoverableUserEventRevision> eventHistory;
  final String? onboardingOperationId;
  final Map<String, Object?>? portableRestoreReceipt;

  _WebUserState copyWith({
    bool? onboarded,
    UserProfile? profile,
    List<String>? activeDrugIds,
    List<Intake>? intakes,
    List<Meal>? meals,
    List<RecoverableUserEventRevision>? eventHistory,
    String? onboardingOperationId,
    bool clearOnboardingOperationId = false,
    Map<String, Object?>? portableRestoreReceipt,
  }) => _WebUserState(
    onboarded: onboarded ?? this.onboarded,
    profile: profile ?? this.profile,
    activeDrugIds: activeDrugIds ?? this.activeDrugIds,
    intakes: intakes ?? this.intakes,
    meals: meals ?? this.meals,
    eventHistory: eventHistory ?? this.eventHistory,
    onboardingOperationId: clearOnboardingOperationId
        ? null
        : onboardingOperationId ?? this.onboardingOperationId,
    portableRestoreReceipt:
        portableRestoreReceipt ?? this.portableRestoreReceipt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 3,
    'onboarded': onboarded,
    'profile': profile.toJson(),
    'activeDrugIds': activeDrugIds,
    'intakes': intakes.map((intake) => intake.toJson()).toList(growable: false),
    'meals': meals.map((meal) => meal.toJson()).toList(growable: false),
    'eventHistory': eventHistory
        .map((revision) => revision.toJson())
        .toList(growable: false),
    if (onboardingOperationId != null) ...<String, Object?>{
      'onboardingOperationId': onboardingOperationId,
      'onboardingStage': atomicOnboardingCommitStageCommitted,
    },
    if (portableRestoreReceipt != null)
      'portableRestoreReceipt': portableRestoreReceipt,
  };

  factory _WebUserState.fromJson(
    Map<String, dynamic> json, {
    List<Meal> legacyMeals = const <Meal>[],
  }) {
    final operationId = json['onboardingOperationId'];
    final schemaVersion = json['schemaVersion'];
    if ((schemaVersion != 1 && schemaVersion != 2 && schemaVersion != 3) ||
        json['onboarded'] is! bool ||
        json['profile'] is! Map ||
        json['activeDrugIds'] is! List ||
        json['intakes'] is! List ||
        (schemaVersion != 1 && json['meals'] is! List) ||
        (schemaVersion != 1 && json['eventHistory'] is! List) ||
        (operationId != null &&
            (operationId is! String ||
                json['onboardingStage'] !=
                    atomicOnboardingCommitStageCommitted))) {
      throw const FormatException('Web user-state envelope is invalid.');
    }
    final receipt = json['portableRestoreReceipt'];
    if (receipt != null &&
        (schemaVersion != 3 ||
            receipt is! Map ||
            receipt['version'] != 1 ||
            receipt['operationId'] is! String ||
            receipt['ownerScope'] is! String ||
            receipt['sourcePackageJson'] is! String ||
            portableRestoreBytesDigest(
                  receipt['sourcePackageJson'] as String,
                ) !=
                receipt['packageJsonSha256'] ||
            receipt['beforeState'] is! Map ||
            receipt['rolledBack'] is! bool ||
            PortableDataRestoreState(
                  Map<String, Object?>.from(receipt['beforeState'] as Map),
                ).digest !=
                receipt['beforeDigest'])) {
      throw const FormatException('Web portable restore receipt is invalid.');
    }
    return _WebUserState(
      onboarded: json['onboarded'] as bool,
      profile: UserProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      activeDrugIds: (json['activeDrugIds'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      intakes: (json['intakes'] as List<dynamic>)
          .map(
            (value) => Intake.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(growable: false),
      meals: schemaVersion == 1
          ? legacyMeals
          : (json['meals'] as List<dynamic>)
                .map(
                  (value) =>
                      Meal.fromJson(Map<String, dynamic>.from(value as Map)),
                )
                .toList(growable: false),
      eventHistory: schemaVersion == 1
          ? const <RecoverableUserEventRevision>[]
          : (json['eventHistory'] as List<dynamic>)
                .map(
                  (value) => RecoverableUserEventRevision.fromJson(
                    Map<String, dynamic>.from(value as Map),
                  ),
                )
                .toList(growable: false),
      onboardingOperationId: operationId as String?,
      portableRestoreReceipt: receipt == null
          ? null
          : Map<String, Object?>.from(receipt as Map),
    );
  }
}
