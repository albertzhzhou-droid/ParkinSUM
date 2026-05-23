import '../../../core/db/app_database.dart';
import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../core/models/intake.dart';
import '../../../core/models/meal.dart';
import '../../../core/models/user_profile.dart';
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
}
