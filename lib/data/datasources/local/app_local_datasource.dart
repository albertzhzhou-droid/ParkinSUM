import '../../../core/db/app_database.dart';
import '../../../core/models/atomic_onboarding_commit.dart';
import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../core/models/intake.dart';
import '../../../core/models/meal.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/recoverable_user_event.dart';
import '../../../core/db/recoverable_user_event_store.dart';
import '../../models/interaction_rule_record.dart';

class AppLocalDataSource {
  final AppDatabase database;

  AppLocalDataSource({required this.database});

  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) {
    return database.initialize(
      seedFoods: seedFoods,
      seedMedications: seedMedications,
      seedRules: seedRules,
    );
  }

  Future<bool> loadOnboarded() => database.loadOnboarded();
  Future<void> saveOnboarded(bool value) => database.saveOnboarded(value);
  Future<UserProfile> loadUserProfile() => database.loadUserProfile();
  Future<void> saveUserProfile(UserProfile profile) =>
      database.saveUserProfile(profile);
  Future<void> commitOnboarding(AtomicOnboardingCommit commit) =>
      database.commitOnboarding(commit);

  Future<List<String>> loadActiveDrugIds() => database.loadActiveDrugIds();
  Future<void> saveActiveDrugIds(List<String> ids) =>
      database.saveActiveDrugIds(ids);

  Future<List<Meal>> loadMeals() => database.loadMeals();
  Future<void> saveMeals(List<Meal> meals) => database.saveMeals(meals);

  Future<List<Intake>> loadIntakes() => database.loadIntakes();
  Future<void> saveIntakes(List<Intake> intakes) =>
      database.saveIntakes(intakes);

  Future<List<FoodItem>> loadFoods() => database.loadFoods();
  Future<List<DrugDefinition>> loadMedications() => database.loadMedications();
  Future<List<InteractionRuleRecord>> loadInteractionRules() =>
      database.loadInteractionRules();

  Future<List<RecoverableUserEventRevision>> loadRecoverableUserEventHistory() {
    final store = database;
    if (store is! RecoverableUserEventStore) {
      return Future<List<RecoverableUserEventRevision>>.value(
        const <RecoverableUserEventRevision>[],
      );
    }
    return (store as RecoverableUserEventStore)
        .loadRecoverableUserEventHistory();
  }

  Future<void> commitRecoverableUserEventMutation(
    RecoverableUserEventMutation mutation,
  ) {
    final store = database;
    if (store is! RecoverableUserEventStore) {
      throw UnsupportedError(
        'This app database does not support recoverable event mutations.',
      );
    }
    return (store as RecoverableUserEventStore)
        .commitRecoverableUserEventMutation(mutation);
  }
}
