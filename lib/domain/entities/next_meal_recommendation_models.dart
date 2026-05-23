import '../../core/models/user_profile.dart';
import '../../core/models/meal.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import 'food_recommendation.dart';
import 'recommendation_benchmark_models.dart';

enum RecommendationMode {
  conservativeOnly,
  hybridLocalLlm,
  auto,
}

class NextMealRecommendationRequest {
  final UserProfile userProfile;
  final List<Meal> history;
  final List<DrugDefinition> activeDrugs;
  final List<Intake> intakes;
  final DateTime now;
  final RecommendationMode mode;
  final bool userConsentedToAi;

  const NextMealRecommendationRequest({
    required this.userProfile,
    required this.history,
    required this.activeDrugs,
    this.intakes = const <Intake>[],
    required this.now,
    this.mode = RecommendationMode.auto,
    this.userConsentedToAi = false,
  });
}

class NextMealRecommendationResult {
  final List<FoodRecommendation> recommendations;
  final bool aiUsed;
  final String decisionPath;
  final List<String> explanations;
  final List<String> gateReasons;
  final String? templateCountryCode;
  final String? templateMealSlot;
  final String? templateTextureLevel;
  final String? aiProvider;
  final String? aiModel;
  final String? aiEndpoint;
  final bool aiRerankUsed;
  final RecommendationBenchmarkDataset benchmarkDataset;

  const NextMealRecommendationResult({
    required this.recommendations,
    required this.aiUsed,
    required this.decisionPath,
    required this.explanations,
    this.gateReasons = const <String>[],
    this.templateCountryCode,
    this.templateMealSlot,
    this.templateTextureLevel,
    this.aiProvider,
    this.aiModel,
    this.aiEndpoint,
    this.aiRerankUsed = false,
    this.benchmarkDataset = defaultRecommendationBenchmarkDataset,
  });
}
