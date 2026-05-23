import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';

abstract class AppRepository {
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  });

  Future<bool> loadOnboarded();
  Future<void> saveOnboarded(bool value);
  Future<UserProfile> loadUserProfile();
  Future<void> saveUserProfile(UserProfile profile);

  Future<List<String>> loadActiveDrugIds();
  Future<void> saveActiveDrugIds(List<String> ids);

  Future<List<Meal>> loadMeals();
  Future<void> saveMeals(List<Meal> meals);

  Future<List<Intake>> loadIntakes();
  Future<void> saveIntakes(List<Intake> intakes);

  Future<List<FoodItem>> loadFoods();
  Future<List<DrugDefinition>> loadMedications();
  Future<List<InteractionRuleRecord>> loadInteractionRules();
}
