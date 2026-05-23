import '../../domain/repositories/app_repository.dart';
import '../models/drug_definition.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';

/// UserDataService：
/// 作为旧 AppState 与新 repository/data layer 之间的过渡层。
class UserDataService {
  final AppRepository repository;

  UserDataService({required this.repository});

  Future<bool> loadOnboarded() => repository.loadOnboarded();
  Future<void> saveOnboarded(bool value) => repository.saveOnboarded(value);
  Future<UserProfile> loadUserProfile() => repository.loadUserProfile();
  Future<void> saveUserProfile(UserProfile profile) =>
      repository.saveUserProfile(profile);

  Future<List<String>> loadActiveDrugIds() => repository.loadActiveDrugIds();
  Future<void> saveActiveDrugIds(List<String> ids) =>
      repository.saveActiveDrugIds(ids);

  Future<List<String>> loadActiveDrugIdsCompat() =>
      repository.loadActiveDrugIds();

  Future<List<Meal>> loadMeals() => repository.loadMeals();
  Future<void> saveMeals(List<Meal> meals) => repository.saveMeals(meals);

  Future<List<Intake>> loadIntakes() => repository.loadIntakes();
  Future<void> saveIntakes(List<Intake> intakes) =>
      repository.saveIntakes(intakes);

  List<String> drugIdsFromDefinitions(List<DrugDefinition> drugs) {
    return drugs.map((d) => d.id).toList(growable: false);
  }
}
