import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';
import 'app_database.dart';

class WebAppDatabase implements AppDatabase {
  static const _kOnboarded = 'db.meta.onboarded';
  static const _kActiveDrugs = 'db.active_drugs';
  static const _kMeals = 'db.meals';
  static const _kIntakes = 'db.intakes';
  static const _kFoods = 'db.foods';
  static const _kMedications = 'db.medications';
  static const _kRules = 'db.rules';
  static const _kUserProfile = 'db.user_profile';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
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
          seedMedications.map((medication) => medication.toJson()).toList()),
    );
    await prefs.setString(
      _kRules,
      jsonEncode(seedRules.map((rule) => rule.toJson()).toList()),
    );
  }

  @override
  Future<bool> loadOnboarded() async {
    final prefs = await _ensure();
    return prefs.getString(_kOnboarded) == 'true';
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    final prefs = await _ensure();
    await prefs.setString(_kOnboarded, value ? 'true' : 'false');
  }

  @override
  Future<UserProfile> loadUserProfile() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kUserProfile);
    if (raw == null) return UserProfile.defaults();
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await _ensure();
    await prefs.setString(_kUserProfile, jsonEncode(profile.toJson()));
  }

  @override
  Future<List<String>> loadActiveDrugIds() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kActiveDrugs);
    if (raw == null) return <String>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => value.toString())
        .toList(growable: false);
  }

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    final prefs = await _ensure();
    await prefs.setString(_kActiveDrugs, jsonEncode(ids));
  }

  @override
  Future<List<Meal>> loadMeals() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kMeals);
    if (raw == null) return <Meal>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => Meal.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> saveMeals(List<Meal> meals) async {
    final prefs = await _ensure();
    await prefs.setString(
      _kMeals,
      jsonEncode(meals.map((meal) => meal.toJson()).toList()),
    );
  }

  @override
  Future<List<Intake>> loadIntakes() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_kIntakes);
    if (raw == null) return <Intake>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => Intake.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    final prefs = await _ensure();
    await prefs.setString(
      _kIntakes,
      jsonEncode(intakes.map((intake) => intake.toJson()).toList()),
    );
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
        .map((value) =>
            InteractionRuleRecord.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }
}

AppDatabase createAppDatabaseImpl() => WebAppDatabase();
