import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/food_recommendation.dart';
import '../models/intake.dart';
import '../models/interaction_result.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'firebase_backend.dart';
import 'firebase_user_data_paths.dart';

/// Stores patient-visible runtime audit events under users/{uid}/...
///
/// Knowledge-base audit remains in user-scoped cdss_tables for each account.
/// Patient runtime checks use this private user scope so Firestore owner-only
/// rules keep meal/intake context isolated by Firebase Auth uid.
class UserClinicalAuditService {
  final AuthService authService;
  final FirebaseFirestore? _providedFirestore;

  UserClinicalAuditService({
    required this.authService,
    FirebaseFirestore? firestore,
  }) : _providedFirestore = firestore;

  FirebaseFirestore get firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  Future<void> recordMealCheck({
    required Meal meal,
    required InteractionResult result,
    required UserProfile userProfile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
  }) async {
    if (!FirebaseBackend.enabled) return;
    final uid = authService.currentUserId;
    if (uid == null) return;
    await FirebaseBackend.ensureInitialized();
    final auditId =
        'meal_check_${meal.id}_${result.generatedAt.microsecondsSinceEpoch}';
    await firestore.doc(FirebaseUserDataPaths(uid).clinicalAudit(auditId)).set({
      ...buildMealCheckPayload(
        meal: meal,
        result: result,
        userProfile: userProfile,
        activeDrugIds: activeDrugIds,
        intakes: intakes,
      ),
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordRecommendationRefresh({
    required UserProfile userProfile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
    required List<Meal> meals,
    required List<FoodRecommendation> recommendations,
    required String decisionPath,
    required List<String> explanations,
    required List<String> gateReasons,
    required bool aiUsed,
  }) async {
    if (!FirebaseBackend.enabled) return;
    final uid = authService.currentUserId;
    if (uid == null) return;
    await FirebaseBackend.ensureInitialized();
    final now = DateTime.now();
    final auditId = 'recommendation_dashboard_${now.microsecondsSinceEpoch}';
    await firestore.doc(FirebaseUserDataPaths(uid).clinicalAudit(auditId)).set({
      ...buildRecommendationPayload(
        generatedAt: now,
        userProfile: userProfile,
        activeDrugIds: activeDrugIds,
        intakes: intakes,
        meals: meals,
        recommendations: recommendations,
        decisionPath: decisionPath,
        explanations: explanations,
        gateReasons: gateReasons,
        aiUsed: aiUsed,
      ),
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Map<String, Object?> buildMealCheckPayload({
    required Meal meal,
    required InteractionResult result,
    required UserProfile userProfile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
  }) {
    return {
      'type': 'meal_check',
      'meal_id': meal.id,
      'patient_id': userProfile.patientId,
      'registration_region': userProfile.registrationRegion,
      'display_locale': userProfile.displayLocale,
      'diet_profile_region': userProfile.dietProfileRegion,
      'active_drug_ids': activeDrugIds,
      'intake_ids': intakes.map((item) => item.id).toList(growable: false),
      'related_intakes': intakes
          .map(
            (item) => {
              'id': item.id,
              'drug_id': item.drugId,
              'taken_at': item.takenAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      'meal': meal.toJson(),
      'result': result.toJson(),
      'score': result.score,
      'severity': result.overallSeverity.name,
      'generated_at': result.generatedAt.toIso8601String(),
    };
  }

  static Map<String, Object?> buildRecommendationPayload({
    required DateTime generatedAt,
    required UserProfile userProfile,
    required List<String> activeDrugIds,
    required List<Intake> intakes,
    required List<Meal> meals,
    required List<FoodRecommendation> recommendations,
    required String decisionPath,
    required List<String> explanations,
    required List<String> gateReasons,
    required bool aiUsed,
  }) {
    return {
      'type': 'recommendation_refresh',
      'patient_id': userProfile.patientId,
      'registration_region': userProfile.registrationRegion,
      'display_locale': userProfile.displayLocale,
      'diet_profile_region': userProfile.dietProfileRegion,
      'active_drug_ids': activeDrugIds,
      'intake_count': intakes.length,
      'meal_count': meals.length,
      'decision_path': decisionPath,
      'explanations': explanations,
      'gate_reasons': gateReasons,
      'ai_used': aiUsed,
      'recommendations': recommendations
          .take(10)
          .map(
            (item) => {
              'food_id': item.food.id,
              'food_name': item.food.name,
              'decision': item.decision,
              'jurisdiction': item.jurisdiction,
              'fallback_used': item.fallbackUsed,
              'score': item.score,
              'reasons': item.reasons,
              'score_breakdown': item.scoreBreakdown,
              'feature_snapshot': item.featureSnapshot.toJson(),
            },
          )
          .toList(growable: false),
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
