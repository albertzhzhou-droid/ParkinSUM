import '../../core/i18n/app_i18n.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../../core/utils/texture_support.dart';
import '../entities/food_recommendation.dart';

class GetFoodRecommendationsUseCase {
  List<FoodRecommendation> call({
    required List<Meal> history,
    required List<DrugDefinition> drugs,
    required List<FoodItem> allFoods,
    required UserProfile userProfile,
  }) {
    final i18n = AppI18n.fromLocaleTag(userProfile.displayLocale);
    final hasLevodopa =
        drugs.any((drug) => drug.tags.contains(DrugTag.levodopaLike));
    final latestMeal = history.isEmpty
        ? null
        : ([...history]..sort((a, b) =>
                b.effectiveOccurredAt.compareTo(a.effectiveOccurredAt)))
            .first;
    final averageProtein = history.isEmpty
        ? 0.0
        : history
                .map((meal) => meal.computeTotals().totalProteinG)
                .fold<double>(0, (sum, value) => sum + value) /
            history.length;
    final region = userProfile.contentJurisdictionOverride.isNotEmpty
        ? userProfile.contentJurisdictionOverride.first
        : userProfile.registrationRegion;
    final dietRegion = userProfile.dietProfileRegion ?? region;
    final swallowingTextureMode = userProfile.swallowingTextureMode;
    final hasIronCoevent =
        latestMeal?.coeventSubstanceTags.contains('iron_salt') ?? false;
    final hasIronMultivitaminCoevent =
        latestMeal?.coeventSubstanceTags.contains('multivitamin_with_iron') ??
            false;
    final hasThickenerContext = latestMeal?.thickenerType != null;
    final hasContinuousEnteralFeed =
        latestMeal?.enteralFeedMode == 'continuous';

    final recommendations = allFoods.map((food) {
      final safetyScore = _safetyScore(food: food, hasLevodopa: hasLevodopa);
      final nutrientMatch = _nutrientMatch(food, averageProtein);
      final scheduleFit = _scheduleFit(
        food: food,
        hasLevodopa: hasLevodopa,
        latestMeal: latestMeal,
      );
      final culturalAffinity = _culturalAffinity(food, dietRegion);
      final recentlyUsed = _recentlyUsed(food, history);
      final userPreference = recentlyUsed ? 0.82 : 0.68;
      final provenanceScore = _provenanceScore(food);
      final usedDatabaseFacts = _usedDatabaseFacts(food);
      final databaseFactCoverage = usedDatabaseFacts ? 1.0 : 0.35;
      final hasPreciseTimingWindow = latestMeal?.nextMealWindowStart != null &&
          latestMeal?.nextMealWindowEnd != null &&
          latestMeal?.timeSource != 'migration_legacy';
      final timingWindowClarity = hasPreciseTimingWindow
          ? 1.0
          : latestMeal == null
              ? 0.0
              : 0.35;
      final drugTimingSensitivity = hasLevodopa
          ? (food.proteinG >= 20
              ? 1.0
              : food.proteinG >= 15
                  ? 0.7
                  : 0.35)
          : 0.0;
      final regionMatchScore = _regionMatchScore(
        foodJurisdiction: food.jurisdiction,
        requestedRegion: region,
      );
      final fallbackUsed = _fallbackUsed(
        requestedRegion: region,
        food: food,
      );
      final fallbackPenalty = fallbackUsed ? 0.35 : 0.0;
      final repetitionPenalty = recentlyUsed ? 0.18 : 0.0;
      final fiberSupportScore = _fiberSupportScore(food);
      final mealContextPenalty = _mealContextPenalty(
        hasLevodopa: hasLevodopa,
        food: food,
        hasIronCoevent: hasIronCoevent,
        hasIronMultivitaminCoevent: hasIronMultivitaminCoevent,
        hasContinuousEnteralFeed: hasContinuousEnteralFeed,
      );
      final contextDataGapPenalty = _contextDataGapPenalty(
        food: food,
        hasThickenerContext: hasThickenerContext,
        hasContinuousEnteralFeed: hasContinuousEnteralFeed,
      );
      final swallowingTexturePenalty = _swallowingTexturePenalty(
        food: food,
        swallowingTextureMode: swallowingTextureMode,
      );
      final contextPenaltyPoints = 100 *
          ((0.06 * mealContextPenalty) +
              (0.04 * contextDataGapPenalty) +
              (0.08 * swallowingTexturePenalty));
      final riskTags = <String>[
        if (hasLevodopa) 'levodopa_sensitive',
        if (food.proteinG >= 20) 'high_protein_candidate',
        if (!hasPreciseTimingWindow) 'timing_window_unclear',
        if (!usedDatabaseFacts) 'local_seed_only',
        if (fallbackUsed) 'fallback_chain',
        if (mealContextPenalty > 0) 'meal_context_penalty',
        if (contextDataGapPenalty > 0) 'context_data_gap',
        if (swallowingTexturePenalty > 0) 'swallowing_texture_penalty',
      ];
      final score = 100 *
          ((0.40 * safetyScore) +
              (0.20 * nutrientMatch) +
              (0.15 * scheduleFit) +
              (0.10 * culturalAffinity) +
              (0.10 * userPreference) +
              (0.05 * provenanceScore) +
              (0.03 * databaseFactCoverage) +
              (0.02 * timingWindowClarity) +
              (0.02 * regionMatchScore) +
              (0.02 * fiberSupportScore) -
              (0.06 * mealContextPenalty) -
              (0.04 * contextDataGapPenalty) -
              (0.08 * swallowingTexturePenalty) -
              (0.03 * fallbackPenalty) -
              (0.02 * repetitionPenalty) -
              (0.04 * drugTimingSensitivity));
      final reasons = <String>[];
      var decision = 'ALLOW';

      if (food.proteinG < 10) {
        reasons.add(i18n.tr('recommend.low_protein'));
      }
      if (hasLevodopa && food.proteinG >= 20) {
        reasons.add(i18n.tr('recommend.protein_window_caution'));
        decision = 'WARN';
      }
      if (averageProtein > 25 && food.proteinG < 8) {
        reasons.add(i18n.tr('recommend.history_low_protein'));
      }
      if (_matchesCulture(food, dietRegion)) {
        reasons.add(i18n.tr('recommend.culture_match'));
      }
      final textureReason = _swallowingTextureReason(
        i18n: i18n,
        food: food,
        swallowingTextureMode: swallowingTextureMode,
      );
      if (textureReason != null) {
        reasons.add(textureReason);
      }
      if ((hasIronCoevent || hasIronMultivitaminCoevent) &&
          hasLevodopa &&
          food.proteinG >= 15) {
        reasons.add(i18n.tr('recommend.context_iron_penalty'));
      }
      if (hasContinuousEnteralFeed && hasLevodopa && food.proteinG >= 15) {
        reasons.add(i18n.tr('recommend.context_enteral_penalty'));
      }
      if (hasThickenerContext) {
        if (isTextureStructuredSafeForThickener(food.textureClass)) {
          reasons.add(i18n.tr('recommend.context_texture_supported'));
        } else {
          reasons.add(i18n.tr('recommend.context_texture_gap_penalty'));
        }
      }
      if (fallbackUsed) {
        reasons.add(i18n.tr('recommend.fallback_chain'));
      }
      if (!usedDatabaseFacts) {
        reasons.add(i18n.tr('recommend.local_seed_metadata'));
      }
      if (!hasPreciseTimingWindow) {
        reasons.add(i18n.tr('recommend.timing_window_incomplete'));
      }

      return FoodRecommendation(
        food: food,
        score: score,
        reasons:
            reasons.isEmpty ? [i18n.tr('recommend.general_friendly')] : reasons,
        decision: decision,
        jurisdiction: region,
        fallbackUsed: fallbackUsed,
        scoreBreakdown: {
          'safety_score': safetyScore,
          'nutrient_match': nutrientMatch,
          'medication_schedule_fit': scheduleFit,
          'cultural_affinity': culturalAffinity,
          'user_preference_score': userPreference,
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
          'context_penalty_points': contextPenaltyPoints,
        },
        featureSnapshot: RecommendationFeatureSnapshot(
          safetyScore: safetyScore,
          nutrientMatch: nutrientMatch,
          medicationScheduleFit: scheduleFit,
          culturalAffinity: culturalAffinity,
          userPreferenceScore: userPreference,
          provenanceScore: provenanceScore,
          databaseFactCoverage: databaseFactCoverage,
          timingWindowClarity: timingWindowClarity,
          drugTimingSensitivity: drugTimingSensitivity,
          fallbackPenalty: fallbackPenalty,
          repetitionPenalty: repetitionPenalty,
          fiberSupportScore: fiberSupportScore,
          regionMatchScore: regionMatchScore,
          mealContextPenalty: mealContextPenalty,
          contextDataGapPenalty: contextDataGapPenalty,
          swallowingTexturePenalty: swallowingTexturePenalty,
          templateTextureAffinity: 0.0,
          usedDatabaseFacts: usedDatabaseFacts,
          hasPreciseTimingWindow: hasPreciseTimingWindow,
          levodopaSensitive: hasLevodopa,
          riskTags: riskTags,
        ),
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return recommendations.take(5).toList(growable: false);
  }

  double _scheduleFit({
    required FoodItem food,
    required bool hasLevodopa,
    required Meal? latestMeal,
  }) {
    if (!hasLevodopa) return 0.9;
    final hasWindow = latestMeal?.nextMealWindowStart != null &&
        latestMeal?.nextMealWindowEnd != null;
    if (!hasWindow) {
      // 未拿到完整时间窗时，不做更激进的排序，只保留保守惩罚。
      return food.proteinG >= 20 ? 0.5 : 0.82;
    }
    return food.proteinG >= 20 ? 0.45 : 0.92;
  }

  double _safetyScore({
    required FoodItem food,
    required bool hasLevodopa,
  }) {
    if (hasLevodopa && food.proteinG >= 25) return 0.4;
    if (hasLevodopa && food.proteinG >= 15) return 0.65;
    return 0.95;
  }

  double _nutrientMatch(FoodItem food, double averageProtein) {
    if (averageProtein > 25 && food.proteinG < 8) return 0.95;
    if (food.fiberG >= 2 || food.category == FoodCategory.fruit) return 0.85;
    return 0.7;
  }

  double _provenanceScore(FoodItem food) {
    switch (food.sourceSystem.toUpperCase()) {
      case 'CIQUAL':
      case 'FDC':
      case 'USDA_FDC':
      case 'DAILYMED':
      case 'HEALTH_CANADA_DPD':
      case 'DPD':
        return 0.95;
      case 'LOCAL_SEED':
        return 0.55;
      default:
        return food.sourceFoodCode == null ? 0.6 : 0.85;
    }
  }

  bool _usedDatabaseFacts(FoodItem food) =>
      food.sourceSystem.toUpperCase() != 'LOCAL_SEED';

  bool _recentlyUsed(FoodItem food, List<Meal> history) {
    return history.any(
      (meal) => meal.items.any((item) => item.foodId == food.id),
    );
  }

  bool _fallbackUsed({
    required String requestedRegion,
    required FoodItem food,
  }) {
    final requested = requestedRegion.toUpperCase();
    final foodJurisdiction = food.jurisdiction.toUpperCase();
    if (requested == 'GLOBAL' || foodJurisdiction == requested) return false;
    // 对 JP 等当前仍缺 authoritative food source 的地区，GLOBAL/LOCAL_SEED
    // 也应显式视为 fallback，而不是伪装成“本地权威值”。
    return true;
  }

  double _regionMatchScore({
    required String foodJurisdiction,
    required String requestedRegion,
  }) {
    final requested = requestedRegion.toUpperCase();
    final actual = foodJurisdiction.toUpperCase();
    if (requested == actual) return 1.0;
    if (actual == 'GLOBAL') return 0.7;
    return 0.45;
  }

  double _fiberSupportScore(FoodItem food) {
    if (food.fiberG >= 4) return 1.0;
    if (food.fiberG >= 2) return 0.8;
    return 0.45;
  }

  double _mealContextPenalty({
    required bool hasLevodopa,
    required FoodItem food,
    required bool hasIronCoevent,
    required bool hasIronMultivitaminCoevent,
    required bool hasContinuousEnteralFeed,
  }) {
    var penalty = 0.0;
    // 这是推荐排序层的保守惩罚，不是新的医学硬规则。
    if (hasLevodopa &&
        (hasIronCoevent || hasIronMultivitaminCoevent) &&
        food.proteinG >= 15) {
      penalty += 0.35;
    }
    if (hasLevodopa && hasContinuousEnteralFeed && food.proteinG >= 15) {
      penalty += 0.5;
    }
    return penalty.clamp(0.0, 1.0);
  }

  double _contextDataGapPenalty({
    required FoodItem food,
    required bool hasThickenerContext,
    required bool hasContinuousEnteralFeed,
  }) {
    var penalty = 0.0;
    // 当前 food catalog 还没有结构化 texture/IDDSI 字段，因此只做数据缺口惩罚。
    if (hasThickenerContext) {
      if (isTextureStructuredSafeForThickener(food.textureClass)) {
        penalty += 0.0;
      } else {
        penalty += 0.25;
      }
    }
    // 连续肠内营养场景下，蛋白较高的候选需要更保守的默认排序。
    if (hasContinuousEnteralFeed && food.proteinG >= 15) {
      penalty += 0.15;
    }
    return penalty.clamp(0.0, 1.0);
  }

  double _swallowingTexturePenalty({
    required FoodItem food,
    required String swallowingTextureMode,
  }) {
    switch (swallowingTextureMode) {
      case 'soft_or_liquid':
        if (food.textureClass == 'soft' || food.textureClass == 'liquid') {
          return 0.0;
        }
        return food.textureClass == null ? 0.45 : 0.75;
      case 'liquid_only':
        if (food.textureClass == 'liquid') return 0.0;
        return food.textureClass == null ? 0.55 : 0.85;
      default:
        return 0.0;
    }
  }

  String? _swallowingTextureReason({
    required AppI18n i18n,
    required FoodItem food,
    required String swallowingTextureMode,
  }) {
    if (swallowingTextureMode == 'unrestricted') return null;
    if (food.textureClass == null) {
      return i18n.tr('recommend.texture_profile_missing');
    }
    switch (swallowingTextureMode) {
      case 'soft_or_liquid':
        if (food.textureClass == 'soft' || food.textureClass == 'liquid') {
          return i18n.tr('recommend.texture_profile_supported_soft_or_liquid');
        }
        return i18n.tr('recommend.texture_profile_incompatible');
      case 'liquid_only':
        if (food.textureClass == 'liquid') {
          return i18n.tr('recommend.texture_profile_supported_liquid_only');
        }
        return i18n.tr('recommend.texture_profile_incompatible');
      default:
        return null;
    }
  }

  double _culturalAffinity(FoodItem food, String dietRegion) {
    switch (dietRegion.toUpperCase()) {
      case 'JP':
        if (food.category == FoodCategory.carbs ||
            food.category == FoodCategory.vegetable) {
          return 0.9;
        }
        return 0.65;
      case 'FR':
        if (food.category == FoodCategory.fruit ||
            food.category == FoodCategory.vegetable) {
          return 0.88;
        }
        return 0.7;
      case 'CA':
      case 'US':
        if (food.category == FoodCategory.fruit ||
            food.category == FoodCategory.vegetable ||
            food.category == FoodCategory.carbs) {
          return 0.86;
        }
        return 0.72;
      default:
        return 0.75;
    }
  }

  bool _matchesCulture(FoodItem food, String dietRegion) {
    switch (dietRegion.toUpperCase()) {
      case 'JP':
        return food.category == FoodCategory.carbs ||
            food.category == FoodCategory.vegetable;
      case 'FR':
        return food.category == FoodCategory.fruit ||
            food.category == FoodCategory.vegetable;
      default:
        return food.category == FoodCategory.fruit ||
            food.category == FoodCategory.vegetable ||
            food.category == FoodCategory.carbs;
    }
  }
}
