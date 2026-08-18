import '../../domain/repositories/app_repository.dart';
import '../models/atomic_onboarding_commit.dart';
import '../models/drug_definition.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../models/recoverable_user_event.dart';
import 'atomic_onboarding_commit_coordinator.dart';

/// UserDataService：
/// 作为旧 AppState 与新 repository/data layer 之间的过渡层。
class UserDataService {
  final AppRepository repository;

  UserDataService({required this.repository})
    : _onboardingCoordinator = AtomicOnboardingCommitCoordinator(
        repository: repository,
      );

  final AtomicOnboardingCommitCoordinator _onboardingCoordinator;

  Future<bool> loadOnboarded() => repository.loadOnboarded();
  Future<void> saveOnboarded(bool value) => repository.saveOnboarded(value);
  Future<UserProfile> loadUserProfile() => repository.loadUserProfile();
  Future<void> saveUserProfile(UserProfile profile) =>
      repository.saveUserProfile(profile);

  Future<AtomicOnboardingCommit> commitOnboarding({
    required UserProfile profile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
  }) => _onboardingCoordinator.commit(
    profile: profile,
    activeDrugIds: activeDrugIds,
    intakes: intakes,
  );

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

  bool get supportsRecoverableUserEventHistory =>
      repository is RecoverableUserEventRepository;

  Future<List<RecoverableUserEventRevision>> loadRecoverableUserEventHistory() {
    final recoverable = repository;
    if (recoverable is! RecoverableUserEventRepository) {
      return Future<List<RecoverableUserEventRevision>>.value(
        const <RecoverableUserEventRevision>[],
      );
    }
    return (recoverable as RecoverableUserEventRepository)
        .loadRecoverableUserEventHistory();
  }

  Future<void> commitRecoverableUserEventMutation({
    required RecoverableUserEventMutation mutation,
    required List<Meal> fallbackMeals,
    required List<Intake> fallbackIntakes,
  }) async {
    final recoverable = repository;
    if (recoverable is RecoverableUserEventRepository) {
      await (recoverable as RecoverableUserEventRepository)
          .commitRecoverableUserEventMutation(mutation);
      return;
    }
    // Compatibility for narrow legacy test repositories only. Every
    // production Services graph uses AppRepositoryImpl and therefore the
    // atomic branch above.
    switch (mutation.revision.eventType) {
      case RecoverableUserEventType.meal:
        await repository.saveMeals(fallbackMeals);
      case RecoverableUserEventType.intake:
        await repository.saveIntakes(fallbackIntakes);
    }
  }

  List<String> drugIdsFromDefinitions(List<DrugDefinition> drugs) {
    return drugs.map((d) => d.id).toList(growable: false);
  }
}
