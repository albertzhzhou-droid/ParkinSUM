import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_firestore.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/auth_service.dart';
import 'package:parkinsum_companion/core/services/firebase_user_data_paths.dart';
import 'package:parkinsum_companion/core/services/user_clinical_audit_service.dart';

class SignedOutAuthService implements AuthService {
  @override
  String? get currentUserEmail => null;

  @override
  String? get currentUserId => null;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream<AuthUser?>.empty();

  @override
  Future<String> ensureUser() async {
    throw StateError('Firebase user is not signed in.');
  }

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  test('Firebase user data paths isolate account A and account B', () {
    const userA = FirebaseUserDataPaths('uid_a');
    const userB = FirebaseUserDataPaths('uid_b');

    expect(userA.profile, 'users/uid_a/profile/current');
    expect(userA.meal('meal_1'), 'users/uid_a/meals/meal_1');
    expect(userA.intake('intake_1'), 'users/uid_a/intakes/intake_1');
    expect(
      userA.clinicalAudit('audit_1'),
      'users/uid_a/clinical_audits/audit_1',
    );
    expect(
      userA.cdssRow('ingestion_run', 'run_1'),
      'users/uid_a/cdss_tables/ingestion_run/rows/run_1',
    );
    expect(userA.meal('meal_1'), isNot(userB.meal('meal_1')));
    expect(userA.intake('intake_1'), isNot(userB.intake('intake_1')));
    expect(
      userA.clinicalAudit('audit_1'),
      isNot(userB.clinicalAudit('audit_1')),
    );
    expect(
      userA.cdssRow('ingestion_run', 'run_1'),
      isNot(userB.cdssRow('ingestion_run', 'run_1')),
    );
  });

  test('Firestore private writes are blocked before Firebase sign-in',
      () async {
    final database = FirestoreAppDatabase(authService: SignedOutAuthService());

    await expectLater(
      database.saveMeals(<Meal>[]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('not signed in'),
        ),
      ),
    );
  });

  test('Firestore rules keep user writes on explicit safe collections', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, isNot(contains('match /users/{uid}/{document=**}')));
    expect(rules, isNot(contains('allow read, write: if isOwner(uid);')));
    expect(rules, contains('request.resource.data.patientId == uid'));
    expect(rules, contains('match /profile/{profileId}'));
    expect(rules, contains('match /meals/{mealId}'));
    expect(rules, contains('match /intakes/{intakeId}'));
    expect(rules, contains('match /clinical_audits/{auditId}'));
    expect(
        rules,
        contains(
            'allow create: if isOwner(uid) && validClinicalAudit(uid, auditId);'));
    expect(rules, contains('allow update, delete: if false;'));
    expect(rules, contains('match /cdss_tables/{table}/rows/{rowId}'));
    expect(
      rules,
      contains(
          'allow read: if isOwner(uid) && safeId(table) && safeId(rowId);'),
    );
    expect(rules, contains('match /cdss_tables/{table}/rows/{rowId}'));
    expect(rules, contains('match /app_catalog/{table}/rows/{rowId}'));
    expect(rules, contains('validAppCatalogWrite(table, rowId)'));
    expect(rules, contains('allow read, write: if false;'));
    expect(rules, isNot(contains('allow read, write: if true')));
    expect(
        rules,
        isNot(contains(
            'match /cdss_tables/{table}/rows/{rowId} {\n      allow read: if signedIn();')));
  });

  test('Firebase patient meal-check audit payload stays user-scoped', () {
    final now = DateTime.utc(2026, 5, 6, 12);
    final meal = Meal(
      id: 'meal_1',
      eatenAt: now,
      title: 'Protein meal',
      items: [
        MealItem(
          foodId: 'food_salmon',
          foodName: 'Salmon',
          foodCategory: FoodCategory.protein,
          quantityFactor: 1,
          foodTags: const [],
          proteinPer100g: 22,
          carbsPer100g: 0,
          fatPer100g: 13,
          fiberPer100g: 0,
          sodiumPer100g: 50,
        ),
      ],
    );
    final result = InteractionResult(
      mealId: 'meal_1',
      status: InteractionStatus.warning,
      summary: 'High risk',
      issues: const [],
      generatedAt: now,
      score: 81,
    );
    final intake = Intake(
      id: 'intake_1',
      drugId: 'drug_levodopa_carbidopa',
      takenAt: now,
      dosageNote: 'smoke dose',
    );

    final payload = UserClinicalAuditService.buildMealCheckPayload(
      meal: meal,
      result: result,
      userProfile: UserProfile.defaults(),
      activeDrugIds: const ['drug_levodopa_carbidopa'],
      intakes: [intake],
    );

    expect(payload['type'], 'meal_check');
    expect(payload['meal_id'], 'meal_1');
    expect(payload['score'], 81);
    expect(payload['severity'], 'high');
    expect(payload['active_drug_ids'], contains('drug_levodopa_carbidopa'));
    expect(payload['intake_ids'], contains('intake_1'));
    expect((payload['result'] as Map<String, dynamic>)['summary'], 'High risk');
    expect((payload['meal'] as Map<String, dynamic>)['title'], 'Protein meal');
  });
}
