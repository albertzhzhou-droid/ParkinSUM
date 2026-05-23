import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../../domain/repositories/app_repository.dart';
import '../datasources/local/app_local_datasource.dart';
import '../models/interaction_rule_record.dart';

class AppRepositoryImpl implements AppRepository {
  final AppLocalDataSource local;

  AppRepositoryImpl({required this.local});

  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) {
    return local.initialize(
      seedFoods: seedFoods,
      seedMedications: seedMedications,
      seedRules: seedRules,
    );
  }

  @override
  Future<List<String>> loadActiveDrugIds() => local.loadActiveDrugIds();

  @override
  Future<List<FoodItem>> loadFoods() => local.loadFoods();

  @override
  Future<List<Intake>> loadIntakes() => local.loadIntakes();

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() =>
      local.loadInteractionRules();

  @override
  Future<List<DrugDefinition>> loadMedications() => local.loadMedications();

  @override
  Future<List<Meal>> loadMeals() => local.loadMeals();

  @override
  Future<bool> loadOnboarded() => local.loadOnboarded();

  @override
  Future<UserProfile> loadUserProfile() => local.loadUserProfile();

  @override
  Future<void> saveActiveDrugIds(List<String> ids) =>
      local.saveActiveDrugIds(ids);

  @override
  Future<void> saveUserProfile(UserProfile profile) =>
      local.saveUserProfile(profile);

  @override
  Future<void> saveIntakes(List<Intake> intakes) => local.saveIntakes(intakes);

  @override
  Future<void> saveMeals(List<Meal> meals) => local.saveMeals(meals);

  @override
  Future<void> saveOnboarded(bool value) => local.saveOnboarded(value);
}
