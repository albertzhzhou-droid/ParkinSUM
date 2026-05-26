import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/interaction_rule_record.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firebase_backend.dart';
import '../services/firebase_user_data_paths.dart';
import 'app_database.dart';

/// Firestore-backed app database for the existing AppDatabase seam.
///
/// Layout:
/// app_catalog/foods/rows/{foodId}
/// app_catalog/medications/rows/{drugId}
/// app_catalog/interaction_rules/rows/{ruleId}
/// users/{uid}/profile/current
/// users/{uid}/app_meta/{key}
/// users/{uid}/meals/{mealId}
/// users/{uid}/intakes/{intakeId}
/// users/{uid}/active_drugs/{drugId}
class FirestoreAppDatabase implements AppDatabase {
  final AuthService authService;
  final FirebaseFirestore? _providedFirestore;
  final bool seedCatalogOnInitialize;

  FirestoreAppDatabase({
    required this.authService,
    FirebaseFirestore? firestore,
    this.seedCatalogOnInitialize = false,
  }) : _providedFirestore = firestore;

  FirebaseFirestore get firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  Future<String> _requireUid() async {
    await FirebaseBackend.ensureInitialized();
    final uid = authService.currentUserId;
    if (uid == null) {
      throw StateError('Firebase user is not signed in.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _catalog(String table) {
    return firestore.collection('app_catalog').doc(table).collection('rows');
  }

  Future<CollectionReference<Map<String, dynamic>>> _userRows(
    String table,
  ) async {
    final uid = await _requireUid();
    final paths = FirebaseUserDataPaths(uid);
    return firestore.collection(paths.collection(table));
  }

  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) async {
    await FirebaseBackend.ensureInitialized();
    if (!seedCatalogOnInitialize) return;
    final batch = firestore.batch();
    for (final food in seedFoods) {
      batch.set(_catalog('foods').doc(food.id), food.toJson());
    }
    for (final medication in seedMedications) {
      batch.set(
          _catalog('medications').doc(medication.id), medication.toJson());
    }
    for (final rule in seedRules) {
      batch.set(_catalog('interaction_rules').doc(rule.id), rule.toJson());
    }
    await batch.commit();
  }

  @override
  Future<List<String>> loadActiveDrugIds() async {
    final snapshot = await (await _userRows('active_drugs')).get();
    return snapshot.docs.map((doc) => doc.id).toList(growable: false);
  }

  @override
  Future<List<FoodItem>> loadFoods() async {
    final snapshot = await _catalog('foods').orderBy('name').get();
    return snapshot.docs
        .map((doc) => FoodItem.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<Intake>> loadIntakes() async {
    final snapshot = await (await _userRows('intakes'))
        .orderBy('takenAtIso', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Intake.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() async {
    final snapshot = await _catalog('interaction_rules').get();
    return snapshot.docs
        .map((doc) => InteractionRuleRecord.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<DrugDefinition>> loadMedications() async {
    final snapshot = await _catalog('medications').orderBy('genericName').get();
    return snapshot.docs
        .map((doc) => DrugDefinition.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<List<Meal>> loadMeals() async {
    final snapshot = await (await _userRows('meals'))
        .orderBy('eatenAtIso', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Meal.fromJson(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<bool> loadOnboarded() async {
    final doc = await (await _userRows('app_meta')).doc('onboarded').get();
    return doc.data()?['value'] == true;
  }

  @override
  Future<UserProfile> loadUserProfile() async {
    final doc = await (await _userRows('profile')).doc('current').get();
    final data = doc.data();
    if (data == null) return UserProfile.defaults();
    return UserProfile.fromJson(data);
  }

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    final rows = await _userRows('active_drugs');
    final existing = await rows.get();
    final batch = firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final id in ids) {
      batch.set(rows.doc(id), {'id': id});
    }
    await batch.commit();
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    final rows = await _userRows('intakes');
    final existing = await rows.get();
    final batch = firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final intake in intakes) {
      batch.set(rows.doc(intake.id), {
        ...intake.toJson(),
        'takenAtIso': intake.takenAt.toIso8601String(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> saveMeals(List<Meal> meals) async {
    final rows = await _userRows('meals');
    final existing = await rows.get();
    final batch = firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final meal in meals) {
      batch.set(rows.doc(meal.id), {
        ...meal.toJson(),
        'eatenAtIso': meal.eatenAt.toIso8601String(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    await (await _userRows('app_meta')).doc('onboarded').set({'value': value});
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final uid = await _requireUid();
    final rows =
        firestore.collection(FirebaseUserDataPaths(uid).collection('profile'));
    await rows.doc('current').set(profile.copyWith(patientId: uid).toJson());
  }
}
