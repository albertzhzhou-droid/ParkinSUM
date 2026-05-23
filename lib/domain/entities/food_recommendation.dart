import '../../core/models/food_item.dart';

/// RecommendationFeatureSnapshot：
/// 给 deterministic 排序、benchmark 回放和本地 AI rerank 共享同一份结构化上下文。
///
/// 说明：
/// - 这些字段首先服务“规则和数据先准”的目标，因此优先表达数据完整度、时间窗清晰度、
///   药物时序敏感度和 fallback 风险，而不是追求复杂建模；
/// - 若底层 food_variant / observation / drug timing 仍不完整，应显式通过 riskTags
///   和低分特征暴露出来，而不是由 AI 自行脑补。
class RecommendationFeatureSnapshot {
  final double safetyScore;
  final double nutrientMatch;
  final double medicationScheduleFit;
  final double culturalAffinity;
  final double userPreferenceScore;
  final double provenanceScore;
  final double databaseFactCoverage;
  final double timingWindowClarity;
  final double drugTimingSensitivity;
  final double fallbackPenalty;
  final double repetitionPenalty;
  final double fiberSupportScore;
  final double regionMatchScore;
  final double mealContextPenalty;
  final double contextDataGapPenalty;
  final double swallowingTexturePenalty;
  final double templateTextureAffinity;
  final bool usedDatabaseFacts;
  final bool hasPreciseTimingWindow;
  final bool levodopaSensitive;
  final List<String> riskTags;

  const RecommendationFeatureSnapshot({
    required this.safetyScore,
    required this.nutrientMatch,
    required this.medicationScheduleFit,
    required this.culturalAffinity,
    required this.userPreferenceScore,
    required this.provenanceScore,
    required this.databaseFactCoverage,
    required this.timingWindowClarity,
    required this.drugTimingSensitivity,
    required this.fallbackPenalty,
    required this.repetitionPenalty,
    required this.fiberSupportScore,
    required this.regionMatchScore,
    this.mealContextPenalty = 0.0,
    this.contextDataGapPenalty = 0.0,
    this.swallowingTexturePenalty = 0.0,
    this.templateTextureAffinity = 0.0,
    required this.usedDatabaseFacts,
    required this.hasPreciseTimingWindow,
    required this.levodopaSensitive,
    this.riskTags = const <String>[],
  });

  Map<String, Object?> toJson() => {
        'safety_score': safetyScore,
        'nutrient_match': nutrientMatch,
        'medication_schedule_fit': medicationScheduleFit,
        'cultural_affinity': culturalAffinity,
        'user_preference_score': userPreferenceScore,
        'provenance_score': provenanceScore,
        'database_fact_coverage': databaseFactCoverage,
        'timing_window_clarity': timingWindowClarity,
        'drug_timing_sensitivity': drugTimingSensitivity,
        'fallback_penalty': fallbackPenalty,
        'repetition_penalty': repetitionPenalty,
        'fiber_support_score': fiberSupportScore,
        'region_match_score': regionMatchScore,
        'meal_context_penalty': mealContextPenalty,
        'context_data_gap_penalty': contextDataGapPenalty,
        'swallowing_texture_penalty': swallowingTexturePenalty,
        'template_texture_affinity': templateTextureAffinity,
        'used_database_facts': usedDatabaseFacts,
        'has_precise_timing_window': hasPreciseTimingWindow,
        'levodopa_sensitive': levodopaSensitive,
        'risk_tags': riskTags,
      };
}

class FoodRecommendation {
  final FoodItem food;
  final double score;
  final List<String> reasons;
  final String decision;
  final String jurisdiction;
  final bool fallbackUsed;
  final Map<String, double> scoreBreakdown;
  final RecommendationFeatureSnapshot featureSnapshot;

  const FoodRecommendation({
    required this.food,
    required this.score,
    required this.reasons,
    required this.decision,
    required this.jurisdiction,
    required this.fallbackUsed,
    required this.scoreBreakdown,
    required this.featureSnapshot,
  });

  FoodRecommendation copyWith({
    FoodItem? food,
    double? score,
    List<String>? reasons,
    String? decision,
    String? jurisdiction,
    bool? fallbackUsed,
    Map<String, double>? scoreBreakdown,
    RecommendationFeatureSnapshot? featureSnapshot,
  }) {
    return FoodRecommendation(
      food: food ?? this.food,
      score: score ?? this.score,
      reasons: reasons ?? this.reasons,
      decision: decision ?? this.decision,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      featureSnapshot: featureSnapshot ?? this.featureSnapshot,
    );
  }
}
