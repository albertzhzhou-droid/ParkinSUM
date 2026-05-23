import '../../core/analysis/food_repository.dart';
import '../../core/analysis/medication_repository.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../entities/next_meal_recommendation_models.dart';
import '../entities/recommendation_benchmark_models.dart';
import '../entities/recommendation_replay_models.dart';
import 'next_meal_recommendation_orchestrator.dart';

/// RecommendationReplayRunner：
/// - 使用同一套 deterministic / hybrid orchestrator 跑离线 benchmark；
/// - 直接产出 deterministic 排名、AI rerank 排名、gate 原因和差异报告；
/// - 先验证“规则和数据先准”，而不是直接依赖模型主观表现。
class RecommendationReplayRunner {
  final NextMealRecommendationOrchestrator hybridOrchestrator;
  final NextMealRecommendationOrchestrator deterministicOrchestrator;
  final FoodRepository foodRepository;
  final MedicationRepository medicationRepository;

  const RecommendationReplayRunner({
    required this.hybridOrchestrator,
    required this.deterministicOrchestrator,
    required this.foodRepository,
    required this.medicationRepository,
  });

  Future<RecommendationReplayRunReport> run({
    RecommendationBenchmarkDataset dataset =
        defaultRecommendationBenchmarkDataset,
  }) async {
    final reports = <RecommendationReplayCaseReport>[];
    for (final benchmarkCase in dataset.cases) {
      reports.add(await _runCase(benchmarkCase));
    }
    return RecommendationReplayRunReport(
      generatedAtIso: DateTime.now().toIso8601String(),
      datasetVersion: dataset.version,
      cases: reports,
    );
  }

  Future<RecommendationReplayCaseReport> _runCase(
    RecommendationBenchmarkCase benchmarkCase,
  ) async {
    final request = _buildRequest(benchmarkCase);
    final candidates = benchmarkCase.candidateFoodIds
        .map(foodRepository.getById)
        .whereType<FoodItem>()
        .toList(growable: false);

    final deterministic = await deterministicOrchestrator.recommend(
      request: request.copyWith(
        mode: RecommendationMode.conservativeOnly,
        userConsentedToAi: false,
      ),
      candidateFoods: candidates,
    );
    final hybrid = await hybridOrchestrator.recommend(
      request: request.copyWith(
        mode: RecommendationMode.hybridLocalLlm,
        userConsentedToAi: benchmarkCase.expectAiGateOpen,
      ),
      candidateFoods: candidates,
    );

    final deterministicRanking = deterministic.recommendations
        .map((item) => item.food.id)
        .toList(growable: false);
    final aiRanking = hybrid.recommendations
        .map((item) => item.food.id)
        .toList(growable: false);
    final matchedExpected = benchmarkCase.expectedTopFoodIds
        .where((id) => aiRanking
            .take(benchmarkCase.expectedTopFoodIds.length)
            .contains(id))
        .toList(growable: false);
    final missingExpected = benchmarkCase.expectedTopFoodIds
        .where((id) => !matchedExpected.contains(id))
        .toList(growable: false);

    return RecommendationReplayCaseReport(
      benchmarkCase: benchmarkCase,
      deterministicRanking: deterministicRanking,
      aiRanking: aiRanking,
      aiUsed: hybrid.aiRerankUsed,
      decisionPath: hybrid.decisionPath,
      gateReasons: hybrid.gateReasons,
      explanations: hybrid.explanations,
      rankingDiffs: _buildRankingDiffs(
        deterministicRanking: deterministicRanking,
        aiRanking: aiRanking,
      ),
      matchedExpectedTopFoodIds: matchedExpected,
      missingExpectedTopFoodIds: missingExpected,
    );
  }

  NextMealRecommendationRequest _buildRequest(
    RecommendationBenchmarkCase benchmarkCase,
  ) {
    final now = DateTime.parse('2026-04-17T12:00:00-04:00');
    final mealTime = now.subtract(const Duration(hours: 5));
    final historyFoods = benchmarkCase.historyFoodIds
        .map(foodRepository.getById)
        .whereType<FoodItem>()
        .toList(growable: false);
    final meal = Meal(
      id: 'bench_meal_${benchmarkCase.caseId}',
      eatenAt: mealTime,
      occurredAt:
          benchmarkCase.historyMealTimePrecision == 'exact' ? mealTime : null,
      occurredRangeStart: benchmarkCase.historyMealTimePrecision == 'interval'
          ? mealTime
          : null,
      occurredRangeEnd: benchmarkCase.historyMealTimePrecision == 'interval'
          ? mealTime.add(const Duration(minutes: 20))
          : null,
      timeSource: benchmarkCase.historyMealTimeSource,
      timePrecision: benchmarkCase.historyMealTimePrecision,
      nextMealWindowStart: benchmarkCase.includeNextMealWindow
          ? mealTime.add(
              Duration(
                minutes: benchmarkCase.nextMealWindowStartMinutesAfterMeal,
              ),
            )
          : null,
      nextMealWindowEnd: benchmarkCase.includeNextMealWindow
          ? mealTime.add(
              Duration(
                minutes: benchmarkCase.nextMealWindowEndMinutesAfterMeal,
              ),
            )
          : null,
      title: benchmarkCase.historyMealTitle,
      items: historyFoods
          .map(
            (food) => MealItem.fromFood(
              food: food,
              quantityFactor: 1.0,
            ),
          )
          .toList(growable: false),
    );
    final drugs = benchmarkCase.activeDrugIds
        .map(medicationRepository.getById)
        .whereType<DrugDefinition>()
        .toList(growable: false);
    final intakes = benchmarkCase.intakeSpecs
        .map(
          (spec) => Intake(
            id: 'bench_intake_${benchmarkCase.caseId}_${spec.drugId}',
            drugId: spec.drugId,
            takenAt: mealTime.add(Duration(minutes: spec.minutesAfterMeal)),
            dosageNote: spec.dosageNote,
          ),
        )
        .toList(growable: false);

    return NextMealRecommendationRequest(
      userProfile: UserProfile.defaults().copyWith(
        registrationRegion: benchmarkCase.registrationRegion,
        displayLocale: benchmarkCase.displayLocale,
        dietProfileRegion: benchmarkCase.dietProfileRegion,
        localAiConsentEnabled: benchmarkCase.expectAiGateOpen,
      ),
      history: [meal],
      activeDrugs: drugs,
      intakes: intakes,
      now: now,
      mode: RecommendationMode.hybridLocalLlm,
      userConsentedToAi: benchmarkCase.expectAiGateOpen,
    );
  }

  List<String> _buildRankingDiffs({
    required List<String> deterministicRanking,
    required List<String> aiRanking,
  }) {
    final diffs = <String>[];
    for (final id in deterministicRanking) {
      final deterministicIndex = deterministicRanking.indexOf(id);
      final aiIndex = aiRanking.indexOf(id);
      if (aiIndex == -1 || aiIndex == deterministicIndex) continue;
      final delta = deterministicIndex - aiIndex;
      if (delta > 0) {
        diffs.add('$id moved up by $delta');
      } else {
        diffs.add('$id moved down by ${delta.abs()}');
      }
    }
    return diffs;
  }
}

extension on NextMealRecommendationRequest {
  NextMealRecommendationRequest copyWith({
    RecommendationMode? mode,
    bool? userConsentedToAi,
  }) {
    return NextMealRecommendationRequest(
      userProfile: userProfile,
      history: history,
      activeDrugs: activeDrugs,
      intakes: intakes,
      now: now,
      mode: mode ?? this.mode,
      userConsentedToAi: userConsentedToAi ?? this.userConsentedToAi,
    );
  }
}
