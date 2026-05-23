import '../../core/i18n/app_i18n.dart';
import '../../core/constants/regional_master_data.dart';
import '../../core/constants/p0_food_source_seed.dart';
import '../../core/models/intake.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/user_profile.dart';
import '../entities/food_recommendation.dart';
import '../entities/next_meal_recommendation_models.dart';
import '../entities/cdss_records.dart';
import 'cdss_catalog_projection_service.dart';
import 'get_food_recommendations_usecase.dart';
import 'local_ai_recommendation_adapter.dart';

/// 双路径下一餐推荐编排器。
///
/// 当前实现目标：
/// 1. 保守路径始终可用；
/// 2. 优先消费 CDSS facts 投影出来的真实 food variant，而不是只依赖目录 seed；
/// 3. 把用户填写的“下一餐时间窗”纳入打分；
/// 4. 若用户显式允许且本地模型可用，仅做白名单候选重排。
///
/// 已知边界：
/// - 目前 AI 仍只做 rerank + 简短 explanation，不会生成全新候选；
/// - 这里的药物/餐时窗口仍是 P0 operational scoring，不等于完整 PK/PD 模型。
class NextMealRecommendationOrchestrator {
  final GetFoodRecommendationsUseCase conservativeRecommender;
  final CdssCatalogProjectionService projectionService;
  final LocalAiRecommendationAdapter? localAiAdapter;

  const NextMealRecommendationOrchestrator({
    required this.conservativeRecommender,
    required this.projectionService,
    required this.localAiAdapter,
  });

  Future<NextMealRecommendationResult> recommend({
    required NextMealRecommendationRequest request,
    required List<FoodItem> candidateFoods,
  }) async {
    final i18n = AppI18n.fromLocaleTag(request.userProfile.displayLocale);
    final projectedFoods = await projectionService.projectFoods();
    final projectedDrugDetails =
        await _projectActiveDrugDetails(request.activeDrugs);
    final latestMeal = request.history.isEmpty
        ? null
        : ([...request.history]..sort((a, b) =>
                b.effectiveOccurredAt.compareTo(a.effectiveOccurredAt)))
            .first;
    final labelExplanationLines = _buildImportedLabelFactExplanations(
      details: projectedDrugDetails,
      i18n: i18n,
    );
    final mealContextLines = latestMeal == null
        ? const <String>[]
        : _buildLatestMealContextExplanations(
            meal: latestMeal,
            i18n: i18n,
          );
    final mergedCandidates = _mergeCandidates(
      projectedFoods,
      candidateFoods.isEmpty ? buildP0FoodCatalog() : candidateFoods,
    );

    final baseline = conservativeRecommender.call(
      history: request.history,
      drugs: request.activeDrugs,
      allFoods: mergedCandidates,
      userProfile: request.userProfile,
    );
    final templateContext = _resolveTemplateContext(
      history: request.history,
      userProfile: request.userProfile,
      i18n: i18n,
    );
    final windowAware = _applyNextMealWindow(
      baseline: baseline,
      history: request.history,
      activeDrugs: request.activeDrugs,
      intakes: request.intakes,
      userProfile: request.userProfile,
      i18n: i18n,
    );
    final gateReasons = _gateAiReasons(
      history: request.history,
      activeDrugs: request.activeDrugs,
      intakes: request.intakes,
      safeCandidates: windowAware,
      i18n: i18n,
    );

    final aiEligible = request.mode != RecommendationMode.conservativeOnly &&
        request.userConsentedToAi &&
        localAiAdapter != null;

    if (!aiEligible) {
      return NextMealRecommendationResult(
        recommendations: windowAware,
        aiUsed: false,
        decisionPath: 'conservative_cdss',
        explanations: [
          i18n.tr('recommend.general_friendly'),
          i18n.tr('recommend.runtime.cdss_conservative_observations'),
          if (templateContext.explanationLine != null)
            templateContext.explanationLine!,
          ...mealContextLines.take(3),
          ...labelExplanationLines.take(3),
        ],
        gateReasons: request.userConsentedToAi
            ? gateReasons
            : [i18n.tr('recommend.runtime.local_ai_not_consented')],
        templateCountryCode: templateContext.countryCode,
        templateMealSlot: templateContext.mealSlot,
        templateTextureLevel: templateContext.textureLevel,
      );
    }

    final availability =
        await localAiAdapter!.probe(userProfile: request.userProfile);
    if (!availability.available) {
      return NextMealRecommendationResult(
        recommendations: windowAware,
        aiUsed: false,
        decisionPath: 'conservative_gate_block',
        explanations: [
          i18n.tr('recommend.runtime.local_ai_unavailable'),
          i18n.tr('recommend.runtime.returned_conservative'),
          if (templateContext.explanationLine != null)
            templateContext.explanationLine!,
          ...mealContextLines.take(3),
          ...labelExplanationLines.take(3),
        ],
        gateReasons: [availability.message],
        templateCountryCode: templateContext.countryCode,
        templateMealSlot: templateContext.mealSlot,
        templateTextureLevel: templateContext.textureLevel,
        aiProvider: availability.provider,
        aiModel: availability.model,
        aiEndpoint: availability.endpoint,
      );
    }

    final copyPolish = await localAiAdapter!.polishRecommendationReasons(
      userProfile: request.userProfile,
      recommendations: windowAware,
      contextLines: [
        ...mealContextLines.take(3),
        ...labelExplanationLines.take(3),
      ],
      availability: availability,
    );
    final polishedWindowAware = _applyAiCandidateNotes(
      windowAware,
      copyPolish?.candidateNotes ?? const <String, String>{},
    );
    final copyPolishExplanations = copyPolish == null
        ? const <String>[]
        : <String>[
            copyPolish.summary,
            i18n.tr('recommend.runtime.local_ai_copy_polish_success'),
          ];

    if (gateReasons.isNotEmpty) {
      return NextMealRecommendationResult(
        recommendations: polishedWindowAware,
        aiUsed: copyPolish?.hasNotes ?? false,
        decisionPath: 'conservative_safety_gate',
        explanations: [
          i18n.tr('recommend.runtime.safety_gate_conservative'),
          ...copyPolishExplanations,
          if (templateContext.explanationLine != null)
            templateContext.explanationLine!,
          ...mealContextLines.take(3),
          ...labelExplanationLines.take(3),
        ],
        gateReasons: gateReasons,
        templateCountryCode: templateContext.countryCode,
        templateMealSlot: templateContext.mealSlot,
        templateTextureLevel: templateContext.textureLevel,
        aiProvider: availability.provider,
        aiModel: availability.model,
        aiEndpoint: availability.endpoint,
      );
    }

    final safeCandidates = windowAware
        .where((item) => item.decision != 'BLOCK')
        .toList(growable: false);
    final rerankResult = await localAiAdapter!.rerankSafeCandidates(
      userProfile: request.userProfile,
      candidates: safeCandidates,
      contextLines: _buildAiContext(
        request: request,
        safeCandidates: safeCandidates,
        projectedDrugDetails: projectedDrugDetails,
      ),
      availability: availability,
    );
    if (rerankResult == null || rerankResult.candidateIds.isEmpty) {
      return NextMealRecommendationResult(
        recommendations: polishedWindowAware,
        aiUsed: copyPolish?.hasNotes ?? false,
        decisionPath: 'fallback_invalid_ai',
        explanations: [
          i18n.tr('recommend.runtime.ai_invalid_whitelist'),
          i18n.tr('recommend.runtime.returned_conservative'),
          ...copyPolishExplanations,
          if (templateContext.explanationLine != null)
            templateContext.explanationLine!,
          ...mealContextLines.take(3),
          ...labelExplanationLines.take(3),
        ],
        gateReasons: [i18n.tr('recommend.runtime.ai_validation_failed')],
        templateCountryCode: templateContext.countryCode,
        templateMealSlot: templateContext.mealSlot,
        templateTextureLevel: templateContext.textureLevel,
        aiProvider: availability.provider,
        aiModel: availability.model,
        aiEndpoint: availability.endpoint,
      );
    }

    final reranked = _applyAiCandidateNotes(
      _rerank(polishedWindowAware, rerankResult.candidateIds),
      rerankResult.candidateNotes.isEmpty
          ? copyPolish?.candidateNotes ?? const <String, String>{}
          : rerankResult.candidateNotes,
    );
    return NextMealRecommendationResult(
      recommendations: reranked,
      aiUsed: true,
      decisionPath: 'hybrid_local_ai',
      aiRerankUsed: true,
      explanations: [
        rerankResult.summary,
        ...copyPolishExplanations,
        if (templateContext.explanationLine != null)
          templateContext.explanationLine!,
        ...rerankResult.safetyChecks,
        ...rerankResult.rankingRationale,
        ...mealContextLines.take(3),
        ...labelExplanationLines.take(3),
      ],
      gateReasons: const [],
      templateCountryCode: templateContext.countryCode,
      templateMealSlot: templateContext.mealSlot,
      templateTextureLevel: templateContext.textureLevel,
      aiProvider: rerankResult.provider,
      aiModel: rerankResult.model,
      aiEndpoint: rerankResult.endpoint,
    );
  }

  List<FoodRecommendation> _applyAiCandidateNotes(
    List<FoodRecommendation> recommendations,
    Map<String, String> notes,
  ) {
    if (notes.isEmpty) return recommendations;
    return recommendations
        .map(
          (item) => notes[item.food.id] == null
              ? item
              : item.copyWith(
                  reasons: [
                    notes[item.food.id]!,
                    ...item.reasons.take(2),
                  ],
                ),
        )
        .toList(growable: false);
  }

  List<FoodItem> _mergeCandidates(
    List<FoodItem> projectedFoods,
    List<FoodItem> fallbackFoods,
  ) {
    final byId = <String, FoodItem>{
      for (final item in fallbackFoods) item.id: item,
      for (final item in projectedFoods) item.id: item,
    };
    return byId.values.toList(growable: false);
  }

  Future<List<ProjectedDrugDetail>> _projectActiveDrugDetails(
    List<DrugDefinition> activeDrugs,
  ) async {
    final details = await Future.wait(
      activeDrugs.map(projectionService.projectDrugDetail),
    );
    return details.whereType<ProjectedDrugDetail>().toList(growable: false);
  }

  List<String> _buildImportedLabelFactExplanations({
    required List<ProjectedDrugDetail> details,
    required AppI18n i18n,
  }) {
    final lines = <String>[];
    final seen = <String>{};
    for (final detail in details) {
      for (final fact in detail.labelFacts) {
        final line = _labelFactExplanationLine(
          drugName: detail.drug.genericName,
          fact: fact,
          i18n: i18n,
        );
        if (line == null || !seen.add(line)) continue;
        lines.add(line);
      }
    }
    return lines;
  }

  String? _labelFactExplanationLine({
    required String drugName,
    required ProjectedDrugLabelFact fact,
    required AppI18n i18n,
  }) {
    switch (fact.factType) {
      case 'meal_window_before_after':
        final value = fact.valueText?.trim();
        if (value == null || value.isEmpty) return null;
        return i18n.localeTag.startsWith('zh')
            ? '官方标签：$drugName 需要与进餐错峰（$value）。'
            : 'Official label: $drugName requires separation from meals ($value).';
      case 'high_fat_delay':
        return i18n.localeTag.startsWith('zh')
            ? '官方标签：$drugName 提示高脂高热量餐可能延迟吸收或起效。'
            : 'Official label: $drugName may be delayed by a high-fat, high-calorie meal.';
      case 'with_or_without_food':
        return i18n.localeTag.startsWith('zh')
            ? '官方标签：$drugName 可与食物同服或空腹服用。'
            : 'Official label: $drugName may be taken with or without food.';
      default:
        return null;
    }
  }

  List<FoodRecommendation> _applyNextMealWindow({
    required List<FoodRecommendation> baseline,
    required List<Meal> history,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
    required UserProfile userProfile,
    required AppI18n i18n,
  }) {
    if (baseline.isEmpty || history.isEmpty) return baseline;
    final latestMeal = [...history]
      ..sort((a, b) => b.effectiveOccurredAt.compareTo(a.effectiveOccurredAt));
    final latest = latestMeal.first;
    final start = latest.nextMealWindowStart;
    final end = latest.nextMealWindowEnd;
    if (start == null || end == null) return baseline;

    final midpoint = start
        .add(Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2));
    final gapMinutes =
        midpoint.difference(latest.effectiveOccurredAt).inMinutes;
    // 这里使用 meal_template.texture_level 做轻量排序增强：
    // 只影响 deterministic 排序和解释，不替代临床吞咽评估，也不是硬性阻断。
    final mealSlot = _inferMealSlot(midpoint);
    final templateTextureLevel = _resolveTemplateTextureLevel(
      regionCode:
          userProfile.dietProfileRegion ?? userProfile.registrationRegion,
      mealSlot: mealSlot,
    );

    return baseline.map((item) {
      var score = item.score;
      final reasons = [...item.reasons];
      final breakdown = Map<String, double>.from(item.scoreBreakdown);
      final updatedRiskTags = [...item.featureSnapshot.riskTags];
      final templateTextureAffinity = _templateTextureAffinity(
        food: item.food,
        swallowingTextureMode: userProfile.swallowingTextureMode,
        templateTextureLevel: templateTextureLevel,
      );
      final templateTextureAdjustment = (templateTextureAffinity - 0.55) * 8.0;

      // 这是工程默认排序项，不是医学硬阈值。
      if (gapMinutes < 180 && item.food.proteinG >= 15) {
        score -= 10;
        reasons.add(i18n.tr('recommend.next_meal_gap_close'));
        if (!updatedRiskTags.contains('short_next_meal_gap')) {
          updatedRiskTags.add('short_next_meal_gap');
        }
      } else if (gapMinutes >= 240 && item.food.fiberG >= 2) {
        score += 4;
        reasons.add(i18n.tr('recommend.next_meal_window_fiber'));
      }

      final intakePenalty = _levodopaWindowPenalty(
        midpoint: midpoint,
        activeDrugs: activeDrugs,
        intakes: intakes,
        food: item.food,
      );
      if (intakePenalty > 0) {
        score -= intakePenalty;
        reasons.add(i18n.tr('recommend.medication_timing_caution'));
        if (!updatedRiskTags.contains('levodopa_window_penalty')) {
          updatedRiskTags.add('levodopa_window_penalty');
        }
      }

      score += templateTextureAdjustment;
      if (templateTextureAffinity >= 0.95) {
        reasons.add(i18n.tr('recommend.texture_template_supported'));
      } else if (templateTextureAffinity <= 0.25) {
        reasons.add(i18n.tr('recommend.texture_template_mismatch'));
        if (!updatedRiskTags.contains('template_texture_mismatch')) {
          updatedRiskTags.add('template_texture_mismatch');
        }
      }

      breakdown['window_gap_minutes'] = gapMinutes.toDouble();
      breakdown['levodopa_window_penalty'] = intakePenalty;
      breakdown['template_texture_affinity'] = templateTextureAffinity;
      breakdown['template_texture_adjustment'] = templateTextureAdjustment;
      breakdown['window_adjusted_score'] = score;

      return FoodRecommendation(
        food: item.food,
        score: score,
        reasons:
            reasons.isEmpty ? [i18n.tr('recommend.general_friendly')] : reasons,
        decision: item.decision,
        jurisdiction: item.jurisdiction,
        fallbackUsed: item.fallbackUsed,
        scoreBreakdown: breakdown,
        featureSnapshot: RecommendationFeatureSnapshot(
          safetyScore: item.featureSnapshot.safetyScore,
          nutrientMatch: item.featureSnapshot.nutrientMatch,
          medicationScheduleFit: item.featureSnapshot.medicationScheduleFit,
          culturalAffinity: item.featureSnapshot.culturalAffinity,
          userPreferenceScore: item.featureSnapshot.userPreferenceScore,
          provenanceScore: item.featureSnapshot.provenanceScore,
          databaseFactCoverage: item.featureSnapshot.databaseFactCoverage,
          timingWindowClarity:
              item.featureSnapshot.hasPreciseTimingWindow ? 1.0 : 0.35,
          drugTimingSensitivity: intakePenalty > 0
              ? 1.0
              : item.featureSnapshot.drugTimingSensitivity,
          fallbackPenalty: item.featureSnapshot.fallbackPenalty,
          repetitionPenalty: item.featureSnapshot.repetitionPenalty,
          fiberSupportScore: item.featureSnapshot.fiberSupportScore,
          regionMatchScore: item.featureSnapshot.regionMatchScore,
          mealContextPenalty: item.featureSnapshot.mealContextPenalty,
          contextDataGapPenalty: item.featureSnapshot.contextDataGapPenalty,
          swallowingTexturePenalty:
              item.featureSnapshot.swallowingTexturePenalty,
          templateTextureAffinity: templateTextureAffinity,
          usedDatabaseFacts: item.featureSnapshot.usedDatabaseFacts,
          hasPreciseTimingWindow: item.featureSnapshot.hasPreciseTimingWindow,
          levodopaSensitive: item.featureSnapshot.levodopaSensitive,
          riskTags: updatedRiskTags,
        ),
      );
    }).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  String _inferMealSlot(DateTime value) {
    final hour = value.hour;
    if (hour < 10) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 21) return 'dinner';
    return 'snack';
  }

  _TemplateContext _resolveTemplateContext({
    required List<Meal> history,
    required UserProfile userProfile,
    required AppI18n i18n,
  }) {
    if (history.isEmpty) {
      return const _TemplateContext();
    }
    final latestMeal = [...history]
      ..sort((a, b) => b.effectiveOccurredAt.compareTo(a.effectiveOccurredAt));
    final latest = latestMeal.first;
    final start = latest.nextMealWindowStart;
    final end = latest.nextMealWindowEnd;
    if (start == null || end == null) {
      return const _TemplateContext();
    }
    final midpoint = start
        .add(Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2));
    final mealSlot = _inferMealSlot(midpoint);
    final regionCode =
        userProfile.dietProfileRegion ?? userProfile.registrationRegion;
    final record = _resolveTemplateRecord(
      regionCode: regionCode,
      mealSlot: mealSlot,
    );
    if (record == null) {
      return const _TemplateContext();
    }
    return _TemplateContext(
      countryCode: record.countryCode,
      mealSlot: record.mealSlot,
      textureLevel: record.textureLevel,
      explanationLine: i18n.tr(
        'dashboard.recommendation_template',
        {
          'region': i18n.regionLabel(record.countryCode),
          'mealSlot': i18n.mealSlotLabel(record.mealSlot),
          'texture': i18n.textureClassLabel(record.textureLevel),
        },
      ),
    );
  }

  MealTemplateRecord? _resolveTemplateRecord({
    required String regionCode,
    required String mealSlot,
  }) {
    for (final record in mealTemplateSeed) {
      if (record.countryCode == regionCode && record.mealSlot == mealSlot) {
        return record;
      }
    }
    for (final record in mealTemplateSeed) {
      if (record.countryCode == 'GLOBAL' && record.mealSlot == mealSlot) {
        return record;
      }
    }
    return null;
  }

  String? _resolveTemplateTextureLevel({
    required String regionCode,
    required String mealSlot,
  }) {
    return _resolveTemplateRecord(
      regionCode: regionCode,
      mealSlot: mealSlot,
    )?.textureLevel;
  }

  double _templateTextureAffinity({
    required FoodItem food,
    required String swallowingTextureMode,
    required String? templateTextureLevel,
  }) {
    final preferredTextures = <String>{};
    if (swallowingTextureMode == 'liquid_only') {
      preferredTextures.add('liquid');
    } else if (swallowingTextureMode == 'soft_or_liquid') {
      preferredTextures
        ..add('soft')
        ..add('liquid');
    } else if (templateTextureLevel == 'soft') {
      preferredTextures
        ..add('soft')
        ..add('liquid');
    } else if (templateTextureLevel == 'liquid') {
      preferredTextures.add('liquid');
    } else {
      preferredTextures.add('regular');
    }
    final textureClass = food.textureClass;
    if (textureClass == null) {
      return 0.55;
    }
    if (preferredTextures.contains(textureClass)) {
      return 1.0;
    }
    return 0.2;
  }

  double _levodopaWindowPenalty({
    required DateTime midpoint,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
    required FoodItem food,
  }) {
    final levodopaDrugIds = activeDrugs
        .where((drug) => drug.tags.contains(DrugTag.levodopaLike))
        .map((drug) => drug.id)
        .toSet();
    if (levodopaDrugIds.isEmpty || food.proteinG < 15) return 0;
    final matchingIntakes = intakes
        .where((intake) => levodopaDrugIds.contains(intake.drugId))
        .toList(growable: false);
    if (matchingIntakes.isEmpty) return 0;
    final nearestMinutes = matchingIntakes
        .map((intake) => midpoint.difference(intake.takenAt).inMinutes.abs())
        .reduce((a, b) => a < b ? a : b);
    if (nearestMinutes <= 120) return 12;
    if (nearestMinutes <= 180) return 6;
    return 0;
  }

  List<String> _gateAiReasons({
    required List<Meal> history,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
    required List<FoodRecommendation> safeCandidates,
    required AppI18n i18n,
  }) {
    final reasons = <String>[];
    final latestMeal = history.isEmpty
        ? null
        : ([...history]..sort((a, b) =>
                b.effectiveOccurredAt.compareTo(a.effectiveOccurredAt)))
            .first;
    if (latestMeal == null) {
      reasons.add(i18n.tr('recommend.runtime.no_prior_meal_history'));
      return reasons;
    }
    if (latestMeal.nextMealWindowStart == null ||
        latestMeal.nextMealWindowEnd == null) {
      reasons.add(i18n.tr('recommend.runtime.next_meal_window_missing'));
    }
    if (latestMeal.timeSource == 'migration_legacy') {
      reasons.add(i18n.tr('recommend.runtime.legacy_meal_time'));
    }
    if (latestMeal.coeventSubstanceTags.contains('iron_salt')) {
      reasons.add(i18n.tr('recommend.runtime.iron_conservative'));
    }
    if (latestMeal.coeventSubstanceTags.contains('multivitamin_with_iron')) {
      reasons.add(i18n.tr('recommend.runtime.iron_multivitamin_conservative'));
    }
    if (latestMeal.thickenerType == 'starch_based') {
      reasons.add(i18n.tr('recommend.runtime.starch_thickener_conservative'));
    }
    if (latestMeal.enteralFeedMode == 'continuous') {
      reasons.add(i18n.tr('recommend.runtime.enteral_conservative'));
    }
    final hasLevodopa =
        activeDrugs.any((drug) => drug.tags.contains(DrugTag.levodopaLike));
    final midpoint = latestMeal.nextMealWindowStart == null ||
            latestMeal.nextMealWindowEnd == null
        ? null
        : latestMeal.nextMealWindowStart!.add(
            Duration(
              milliseconds: latestMeal.nextMealWindowEnd!
                      .difference(latestMeal.nextMealWindowStart!)
                      .inMilliseconds ~/
                  2,
            ),
          );
    if (hasLevodopa &&
        midpoint != null &&
        safeCandidates.any((candidate) =>
            _levodopaWindowPenalty(
              midpoint: midpoint,
              activeDrugs: activeDrugs,
              intakes: intakes,
              food: candidate.food,
            ) >=
            12)) {
      reasons.add(i18n.tr('recommend.runtime.levodopa_ai_sensitive'));
    }
    return reasons;
  }

  List<String> _buildAiContext({
    required NextMealRecommendationRequest request,
    required List<FoodRecommendation> safeCandidates,
    List<ProjectedDrugDetail> projectedDrugDetails =
        const <ProjectedDrugDetail>[],
  }) {
    if (request.history.isEmpty) {
      return const <String>[
        'No prior meal history available.',
        'Keep the rerank conservative and preserve the deterministic ordering bias.',
      ];
    }
    final latest = [...request.history]
      ..sort((a, b) => b.effectiveOccurredAt.compareTo(a.effectiveOccurredAt));
    final meal = latest.first;
    final activeDrugNames = request.activeDrugs
        .map((drug) => drug.genericName)
        .toList(growable: false);
    final riskTags = safeCandidates
        .expand((candidate) => candidate.featureSnapshot.riskTags)
        .toSet()
        .toList(growable: false)
      ..sort();
    final importedFactLines = _buildImportedLabelFactExplanations(
      details: projectedDrugDetails,
      i18n: AppI18n.fromLocaleTag(request.userProfile.displayLocale),
    );
    return [
      'You are a local reranker for ParkinSUM. Rules and database facts are authoritative; do not reinterpret them.',
      'Latest meal title: ${meal.title}',
      'Latest meal time: ${meal.effectiveOccurredAt.toIso8601String()}',
      'Latest meal time precision: ${meal.timePrecision}',
      'Meal time source: ${meal.timeSource}',
      if (meal.coeventSubstanceTags.isNotEmpty)
        'Meal coevent tags: ${meal.coeventSubstanceTags.join(', ')}',
      if (meal.thickenerType != null)
        'Meal thickener type: ${meal.thickenerType}',
      if (meal.enteralFeedMode != null)
        'Enteral feeding: mode=${meal.enteralFeedMode}, protein_g_per_day=${meal.enteralFeedProteinGPerDay?.toStringAsFixed(0) ?? 'unspecified'}',
      if (meal.nextMealWindowStart != null && meal.nextMealWindowEnd != null)
        'Next meal window: ${meal.nextMealWindowStart!.toIso8601String()} -> ${meal.nextMealWindowEnd!.toIso8601String()}',
      'Active drugs: ${activeDrugNames.isEmpty ? 'none' : activeDrugNames.join(', ')}',
      if (importedFactLines.isNotEmpty)
        'Imported official label facts: ${importedFactLines.join(' | ')}',
      'Conservative candidate count: ${safeCandidates.length}',
      'Observed candidate risk tags: ${riskTags.isEmpty ? 'none' : riskTags.join(', ')}',
      'Do not improve variety or style at the expense of timing safety, database provenance, or fallback transparency.',
    ];
  }

  List<String> _buildLatestMealContextExplanations({
    required Meal meal,
    required AppI18n i18n,
  }) {
    final lines = <String>[];
    if (meal.coeventSubstanceTags.contains('iron_salt')) {
      lines.add(i18n.tr('recommend.context_iron_supplement'));
    }
    if (meal.coeventSubstanceTags.contains('multivitamin_with_iron')) {
      lines.add(i18n.tr('recommend.context_iron_multivitamin'));
    }
    if (meal.thickenerType == 'starch_based') {
      lines.add(i18n.tr('recommend.context_starch_thickener'));
    } else if (meal.thickenerType == 'xanthan_based') {
      lines.add(i18n.tr('recommend.context_xanthan_thickener'));
    }
    if (meal.enteralFeedMode == 'continuous') {
      lines.add(i18n.tr(
        'recommend.context_enteral_feed_continuous',
        {
          'protein': meal.enteralFeedProteinGPerDay?.toStringAsFixed(0) ??
              'unspecified',
        },
      ));
    } else if (meal.enteralFeedMode == 'bolus') {
      lines.add(i18n.tr('recommend.context_enteral_feed_bolus'));
    }
    return lines;
  }

  List<FoodRecommendation> _rerank(
    List<FoodRecommendation> baseline,
    List<String> orderedIds,
  ) {
    final byId = {
      for (final item in baseline) item.food.id: item,
    };
    final seen = <String>{};
    final result = <FoodRecommendation>[];
    for (final id in orderedIds) {
      final item = byId[id];
      if (item == null || !seen.add(id)) continue;
      result.add(item);
    }
    for (final item in baseline) {
      if (seen.add(item.food.id)) {
        result.add(item);
      }
    }
    return result;
  }
}

class _TemplateContext {
  final String? countryCode;
  final String? mealSlot;
  final String? textureLevel;
  final String? explanationLine;

  const _TemplateContext({
    this.countryCode,
    this.mealSlot,
    this.textureLevel,
    this.explanationLine,
  });
}
