import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/atomic_onboarding_commit.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/recoverable_user_event.dart';
import '../models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';
import 'app_database.dart';
import 'recoverable_user_event_store.dart';

class WebAppDatabase implements AppDatabase, RecoverableUserEventStore {
  static const _kOnboarded = 'db.meta.onboarded';
  static const _kActiveDrugs = 'db.active_drugs';
  static const _kMeals = 'db.meals';
  static const _kIntakes = 'db.intakes';
  static const _kFoods = 'db.foods';
  static const _kMedications = 'db.medications';
  static const _kRules = 'db.rules';
  static const _kUserProfile = 'db.user_profile';
  static const _kUserState = 'db.user_state.v1';

  SharedPreferences? _prefs;
  Future<void> _userStateTail = Future<void>.value();

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<_WebUserState> _loadUserState() async {
    await _userStateTail;
    return _readUserState(await _ensure());
  }

  _WebUserState _readUserState(SharedPreferences prefs) {
    final legacyMealsRaw = prefs.getString(_kMeals);
    final legacyMeals = legacyMealsRaw == null
        ? const <Meal>[]
        : (jsonDecode(legacyMealsRaw) as List<dynamic>)
              .map(
                (value) =>
                    Meal.fromJson(Map<String, dynamic>.from(value as Map)),
              )
              .toList(growable: false);
    final aggregate = prefs.getString(_kUserState);
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
    _WebUserState Function(_WebUserState current) transform,
  ) {
    final operation = _userStateTail.then((_) async {
      final prefs = await _ensure();
      final current = _readUserState(prefs);
      final next = transform(current);
      if (identical(next, current)) return;
      final saved = await prefs.setString(
        _kUserState,
        jsonEncode(next.toJson()),
      );
      if (!saved) {
        throw StateError('Web user-state persistence was rejected.');
      }
    });
    _userStateTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

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

  _WebUserState copyWith({
    bool? onboarded,
    UserProfile? profile,
    List<String>? activeDrugIds,
    List<Intake>? intakes,
    List<Meal>? meals,
    List<RecoverableUserEventRevision>? eventHistory,
    String? onboardingOperationId,
    bool clearOnboardingOperationId = false,
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
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 2,
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
  };

  factory _WebUserState.fromJson(
    Map<String, dynamic> json, {
    List<Meal> legacyMeals = const <Meal>[],
  }) {
    final operationId = json['onboardingOperationId'];
    final schemaVersion = json['schemaVersion'];
    if ((schemaVersion != 1 && schemaVersion != 2) ||
        json['onboarded'] is! bool ||
        json['profile'] is! Map ||
        json['activeDrugIds'] is! List ||
        json['intakes'] is! List ||
        (schemaVersion == 2 && json['meals'] is! List) ||
        (schemaVersion == 2 && json['eventHistory'] is! List) ||
        (operationId != null &&
            (operationId is! String ||
                json['onboardingStage'] !=
                    atomicOnboardingCommitStageCommitted))) {
      throw const FormatException('Web user-state envelope is invalid.');
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
    );
  }
}
