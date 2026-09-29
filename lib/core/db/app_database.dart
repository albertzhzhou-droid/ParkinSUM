import 'dart:convert';

import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/atomic_onboarding_commit.dart';
import '../models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';
import '../../domain/entities/mechanistic_replay_capsule.dart';
import 'app_database_factory.dart';

abstract class AppDatabase {
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  });

  Future<bool> loadOnboarded();
  Future<void> saveOnboarded(bool value);
  Future<UserProfile> loadUserProfile();
  Future<void> saveUserProfile(UserProfile profile);

  /// Atomically publishes the complete registered-user first-day state.
  Future<void> commitOnboarding(AtomicOnboardingCommit commit);

  Future<List<String>> loadActiveDrugIds();
  Future<void> saveActiveDrugIds(List<String> ids);

  Future<List<Meal>> loadMeals();
  Future<void> saveMeals(List<Meal> meals);

  Future<List<Intake>> loadIntakes();
  Future<void> saveIntakes(List<Intake> intakes);

  /// Persists one immutable, content-addressed mechanistic replay capsule.
  /// Re-saving identical canonical bytes is idempotent; digest collisions fail.
  Future<void> saveMechanisticReplayCapsule(MechanisticReplayCapsule capsule);
  Future<List<MechanisticReplayCapsule>> loadMechanisticReplayCapsules();

  Future<List<FoodItem>> loadFoods();
  Future<List<DrugDefinition>> loadMedications();
  Future<List<InteractionRuleRecord>> loadInteractionRules();
}

AppDatabase createAppDatabase() => createAppDatabaseImpl();

/// Re-parses canonical bytes into an independent persistence-safe snapshot.
MechanisticReplayCapsule canonicalMechanisticReplayCapsuleSnapshot(
  MechanisticReplayCapsule capsule,
) => MechanisticReplayCapsule.fromJson(
  Map<String, Object?>.from(jsonDecode(capsule.canonicalJson) as Map),
);

/// Newest generated capsule first, with digest as a stable tie-break.
int compareMechanisticReplayCapsulesByGeneratedAt(
  MechanisticReplayCapsule left,
  MechanisticReplayCapsule right,
) {
  final generatedAt = right.generatedAtUtc.compareTo(left.generatedAtUtc);
  return generatedAt != 0
      ? generatedAt
      : left.capsuleSha256.compareTo(right.capsuleSha256);
}
