import '../../core/models/user_profile.dart';
import '../../core/models/meal.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import 'food_recommendation.dart';
import 'mechanistic_candidate_score.dart';
import 'mechanistic_conflict_result.dart';
import 'recommendation_benchmark_models.dart';
import 'time_axis_events.dart';

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

  /// Optional user-defined next-meal time window. When provided, the
  /// orchestrator forwards it to the mechanistic next-meal scorer. The engine
  /// never picks the window itself.
  final UserDefinedMealWindow? userDefinedWindow;

  const NextMealRecommendationRequest({
    required this.userProfile,
    required this.history,
    required this.activeDrugs,
    this.intakes = const <Intake>[],
    required this.now,
    this.mode = RecommendationMode.auto,
    this.userConsentedToAi = false,
    this.userDefinedWindow,
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

  /// Deterministic mechanistic conflict trace computed alongside the
  /// existing heuristic. Educational simulation; not medical advice.
  /// Null when the mechanistic engine could not run for this request.
  final MechanisticConflictResult? mechanisticTrace;

  /// Per-candidate mechanistic scores, only populated when the request
  /// includes a `userDefinedWindow`.
  final List<MechanisticCandidateScore>? mechanisticCandidateScores;

  /// Which ranker actually produced `recommendations` order.
  /// Values: `mechanistic_primary` (mechanistic engine had sufficient
  /// context and re-ordered the list) or `heuristic_legacy_fallback`
  /// (the existing distance-based heuristic was used).
  final String? rankerUsed;

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
    this.mechanisticTrace,
    this.mechanisticCandidateScores,
    this.rankerUsed,
  });
}
