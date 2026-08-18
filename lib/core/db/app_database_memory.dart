import '../../data/models/interaction_rule_record.dart';
import '../models/atomic_onboarding_commit.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../models/recoverable_user_event.dart';
import 'app_database.dart';
import 'recoverable_user_event_store.dart';

/// Process-local [AppDatabase] used by deterministic demos and device tests.
///
/// It exercises the same repository and [AppState] persistence boundaries as
/// production storage without touching an installed user's SQLite database,
/// shared preferences, or cloud account. Every read returns a defensive copy
/// so callers cannot mutate durable state without a corresponding save.
class InMemoryAppDatabase implements AppDatabase, RecoverableUserEventStore {
  bool _onboarded = false;
  UserProfile _profile = UserProfile.defaults();
  List<String> _activeDrugIds = <String>[];
  List<Meal> _meals = <Meal>[];
  List<Intake> _intakes = <Intake>[];
  List<FoodItem> _foods = <FoodItem>[];
  List<DrugDefinition> _medications = <DrugDefinition>[];
  List<InteractionRuleRecord> _rules = <InteractionRuleRecord>[];
  List<RecoverableUserEventRevision> _eventHistory =
      <RecoverableUserEventRevision>[];
  String? _completedOnboardingOperationId;

  @override
  Future<void> commitOnboarding(AtomicOnboardingCommit commit) async {
    if (_completedOnboardingOperationId == commit.operationId) return;

    // Prepare every defensive copy before publishing any field. No await or
    // fallible transformation occurs between these assignments.
    final nextProfile = commit.profile;
    final nextActiveDrugIds = List<String>.from(commit.activeDrugIds);
    final nextIntakes = List<Intake>.from(commit.intakes);
    _profile = nextProfile;
    _activeDrugIds = nextActiveDrugIds;
    _intakes = nextIntakes;
    _onboarded = true;
    _completedOnboardingOperationId = commit.operationId;
  }

  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) async {
    if (_foods.isEmpty) _foods = List<FoodItem>.from(seedFoods);
    if (_medications.isEmpty) {
      _medications = List<DrugDefinition>.from(seedMedications);
    }
    if (_rules.isEmpty) _rules = List<InteractionRuleRecord>.from(seedRules);
  }

  @override
  Future<List<String>> loadActiveDrugIds() async =>
      List<String>.from(_activeDrugIds);

  @override
  Future<List<FoodItem>> loadFoods() async => List<FoodItem>.from(_foods);

  @override
  Future<List<Intake>> loadIntakes() async => List<Intake>.from(_intakes);

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() async =>
      List<InteractionRuleRecord>.from(_rules);

  @override
  Future<List<DrugDefinition>> loadMedications() async =>
      List<DrugDefinition>.from(_medications);

  @override
  Future<List<Meal>> loadMeals() async => List<Meal>.from(_meals);

  @override
  Future<bool> loadOnboarded() async => _onboarded;

  @override
  Future<UserProfile> loadUserProfile() async => _profile;

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    _activeDrugIds = List<String>.from(ids);
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    _intakes = List<Intake>.from(intakes);
  }

  @override
  Future<void> saveMeals(List<Meal> meals) async {
    _meals = List<Meal>.from(meals);
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    _onboarded = value;
    if (!value) _completedOnboardingOperationId = null;
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<List<RecoverableUserEventRevision>>
  loadRecoverableUserEventHistory() async =>
      List<RecoverableUserEventRevision>.from(_eventHistory.reversed);

  @override
  Future<void> commitRecoverableUserEventMutation(
    RecoverableUserEventMutation mutation,
  ) async {
    final revision = mutation.revision..validate();
    final existing = _eventHistory
        .where(
          (entry) =>
              entry.historyId == revision.historyId ||
              entry.operationId == revision.operationId,
        )
        .toList(growable: false);
    final currentPayload = _currentPayload(revision);
    final currentDigest = recoverableUserEventPayloadDigest(currentPayload);
    if (existing.isNotEmpty) {
      if (existing.length != 1 ||
          existing.single.historyId != revision.historyId ||
          currentDigest != revision.afterDigest) {
        throw RecoverableUserEventConflict(
          recordId: revision.recordId,
          expectedDigest: revision.afterDigest,
          actualDigest: currentDigest,
        );
      }
      return;
    }
    if (currentDigest != mutation.expectedCurrentDigest) {
      throw RecoverableUserEventConflict(
        recordId: revision.recordId,
        expectedDigest: mutation.expectedCurrentDigest,
        actualDigest: currentDigest,
      );
    }
    switch (revision.eventType) {
      case RecoverableUserEventType.meal:
        _meals = _replaceMeal(_meals, revision);
      case RecoverableUserEventType.intake:
        _intakes = _replaceIntake(_intakes, revision);
    }
    _eventHistory = <RecoverableUserEventRevision>[..._eventHistory, revision];
  }

  Map<String, Object?>? _currentPayload(RecoverableUserEventRevision revision) {
    return switch (revision.eventType) {
      RecoverableUserEventType.meal =>
        _meals
            .where((meal) => meal.id == revision.recordId)
            .map((meal) => Map<String, Object?>.from(meal.toJson()))
            .firstOrNull,
      RecoverableUserEventType.intake =>
        _intakes
            .where((intake) => intake.id == revision.recordId)
            .map((intake) => Map<String, Object?>.from(intake.toJson()))
            .firstOrNull,
    };
  }

  List<Meal> _replaceMeal(
    List<Meal> current,
    RecoverableUserEventRevision revision,
  ) {
    final next = current
        .where((meal) => meal.id != revision.recordId)
        .toList(growable: true);
    final payload = revision.afterPayload;
    if (payload != null) {
      next.insert(0, Meal.fromJson(Map<String, dynamic>.from(payload)));
    }
    return next;
  }

  List<Intake> _replaceIntake(
    List<Intake> current,
    RecoverableUserEventRevision revision,
  ) {
    final next = current
        .where((intake) => intake.id != revision.recordId)
        .toList(growable: true);
    final payload = revision.afterPayload;
    if (payload != null) {
      next.insert(0, Intake.fromJson(Map<String, dynamic>.from(payload)));
    }
    return next;
  }
}
