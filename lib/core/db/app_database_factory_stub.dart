import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';
import 'app_database.dart';

class UnsupportedAppDatabase implements AppDatabase {
  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) {
    throw UnsupportedError(
        'No database implementation available on this platform.');
  }

  @override
  Future<List<String>> loadActiveDrugIds() async => <String>[];

  @override
  Future<List<FoodItem>> loadFoods() async => <FoodItem>[];

  @override
  Future<List<Intake>> loadIntakes() async => <Intake>[];

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() async =>
      <InteractionRuleRecord>[];

  @override
  Future<List<DrugDefinition>> loadMedications() async => <DrugDefinition>[];

  @override
  Future<List<Meal>> loadMeals() async => <Meal>[];

  @override
  Future<bool> loadOnboarded() async => false;

  @override
  Future<UserProfile> loadUserProfile() async => UserProfile.defaults();

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {}

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {}

  @override
  Future<void> saveMeals(List<Meal> meals) async {}

  @override
  Future<void> saveOnboarded(bool value) async {}

  @override
  Future<void> saveUserProfile(UserProfile profile) async {}
}

AppDatabase createAppDatabaseImpl() => UnsupportedAppDatabase();
