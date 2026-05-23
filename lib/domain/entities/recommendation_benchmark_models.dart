/// RecommendationBenchmarkCase：
/// 用于离线 replay / benchmark 的最小场景描述。
///
/// 设计目的：
/// - 先验证“规则和上下文是否正确”，再谈模型是否更聪明；
/// - 覆盖左旋多巴时间窗、高蛋白、铁剂、高酪胺、吞咽/质地、中国常见食物、
///   以及缺失数据保守回退场景；
/// - 不把 benchmark 伪装成训练语料。它首先是评测/回放数据，不是医学知识来源。
class RecommendationBenchmarkCase {
  final String caseId;
  final String title;
  final List<String> focusTags;
  final String registrationRegion;
  final String displayLocale;
  final String? dietProfileRegion;
  final List<String> candidateFoodIds;
  final List<String> historyFoodIds;
  final String historyMealTitle;
  final String historyMealTimeSource;
  final String historyMealTimePrecision;
  final bool includeNextMealWindow;
  final int nextMealWindowStartMinutesAfterMeal;
  final int nextMealWindowEndMinutesAfterMeal;
  final List<String> activeDrugIds;
  final List<RecommendationBenchmarkIntakeSpec> intakeSpecs;
  final List<String> expectedTopFoodIds;
  final List<String> expectedRiskTags;
  final bool expectAiGateOpen;
  final String notes;

  const RecommendationBenchmarkCase({
    required this.caseId,
    required this.title,
    required this.focusTags,
    required this.registrationRegion,
    required this.displayLocale,
    required this.dietProfileRegion,
    required this.candidateFoodIds,
    this.historyFoodIds = const <String>[],
    this.historyMealTitle = 'Benchmark meal',
    this.historyMealTimeSource = 'user_exact',
    this.historyMealTimePrecision = 'exact',
    this.includeNextMealWindow = true,
    this.nextMealWindowStartMinutesAfterMeal = 300,
    this.nextMealWindowEndMinutesAfterMeal = 360,
    this.activeDrugIds = const <String>[],
    this.intakeSpecs = const <RecommendationBenchmarkIntakeSpec>[],
    required this.expectedTopFoodIds,
    required this.expectedRiskTags,
    required this.expectAiGateOpen,
    required this.notes,
  });
}

class RecommendationBenchmarkIntakeSpec {
  final String drugId;
  final int minutesAfterMeal;
  final String dosageNote;

  const RecommendationBenchmarkIntakeSpec({
    required this.drugId,
    required this.minutesAfterMeal,
    this.dosageNote = '',
  });
}

class RecommendationBenchmarkDataset {
  final String version;
  final List<RecommendationBenchmarkCase> cases;

  const RecommendationBenchmarkDataset({
    required this.version,
    required this.cases,
  });
}

/// 当前默认 benchmark 数据集。
///
/// 说明：
/// - 这里优先引用仓库中已存在的真实 food ids，避免“评测集比实际目录更理想化”；
/// - 中国常见食物先使用项目中已存在且可公开核验的条目，例如豆腐、糙米、香蕉等；
/// - 如果后续正式接入可重复导入的中国官方食品发布包，这里应直接扩展为真实 CN
///   food_variant 覆盖，而不是继续停留在模板/标签层。
const defaultRecommendationBenchmarkDataset = RecommendationBenchmarkDataset(
  version: '2026-04-17.p0',
  cases: <RecommendationBenchmarkCase>[
    RecommendationBenchmarkCase(
      caseId: 'bench_ldopa_low_protein_window',
      title: 'Levodopa morning window prefers lower-protein candidates',
      focusTags: <String>['levodopa', 'timing_window', 'protein'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>[
        'food_banana',
        'food_apple',
        'food_tofu',
        'food_oats',
      ],
      historyFoodIds: <String>['food_oats'],
      activeDrugIds: <String>['drug_levodopa_carbidopa'],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[
        RecommendationBenchmarkIntakeSpec(
          drugId: 'drug_levodopa_carbidopa',
          minutesAfterMeal: 320,
          dosageNote: '25/100',
        ),
      ],
      nextMealWindowStartMinutesAfterMeal: 330,
      nextMealWindowEndMinutesAfterMeal: 390,
      expectedTopFoodIds: <String>['food_banana', 'food_apple'],
      expectedRiskTags: <String>['levodopa_sensitive'],
      expectAiGateOpen: true,
      notes:
          'High-protein tofu/oats should not outrank lower-protein fruit near a sensitive levodopa window.',
    ),
    RecommendationBenchmarkCase(
      caseId: 'bench_iron_spacing_caution',
      title: 'Iron coevent still keeps lower-risk foods in front',
      focusTags: <String>['levodopa', 'iron', 'timing_window'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>[
        'food_banana',
        'food_brown_rice',
        'food_tofu',
      ],
      historyFoodIds: <String>['food_brown_rice'],
      activeDrugIds: <String>['drug_levodopa_carbidopa', 'drug_iron'],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[
        RecommendationBenchmarkIntakeSpec(
          drugId: 'drug_levodopa_carbidopa',
          minutesAfterMeal: 260,
          dosageNote: '25/100',
        ),
        RecommendationBenchmarkIntakeSpec(
          drugId: 'drug_iron',
          minutesAfterMeal: 280,
          dosageNote: 'ferrous sulfate',
        ),
      ],
      nextMealWindowStartMinutesAfterMeal: 300,
      nextMealWindowEndMinutesAfterMeal: 360,
      expectedTopFoodIds: <String>['food_banana'],
      expectedRiskTags: <String>['timing_window_unclear'],
      expectAiGateOpen: true,
      notes:
          'The benchmark checks that rerank stays within conservative ordering instead of making aggressive changes under interaction pressure.',
    ),
    RecommendationBenchmarkCase(
      caseId: 'bench_dysphagia_soft_cn_common',
      title: 'Soft China-common foods remain visible for conservative rerank',
      focusTags: <String>['china_common_foods', 'texture', 'fallback'],
      registrationRegion: 'CN',
      displayLocale: 'zh-CN',
      dietProfileRegion: 'CN',
      candidateFoodIds: <String>[
        'food_tofu',
        'food_banana',
        'food_brown_rice',
      ],
      historyFoodIds: <String>['food_brown_rice'],
      nextMealWindowStartMinutesAfterMeal: 240,
      nextMealWindowEndMinutesAfterMeal: 300,
      expectedTopFoodIds: <String>['food_tofu', 'food_banana'],
      expectedRiskTags: <String>[],
      expectAiGateOpen: true,
      notes:
          'Until a full CN authoritative nutrient export is integrated, tofu/banana stay useful replay candidates for China-facing food ranking.',
    ),
    RecommendationBenchmarkCase(
      caseId: 'bench_missing_window_fallback',
      title: 'Missing next-meal window forces conservative fallback',
      focusTags: <String>['missing_data', 'fallback', 'safety_gate'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>[
        'food_banana',
        'food_apple',
      ],
      historyFoodIds: <String>['food_apple'],
      includeNextMealWindow: false,
      activeDrugIds: <String>['drug_levodopa_carbidopa'],
      expectedTopFoodIds: <String>['food_banana', 'food_apple'],
      expectedRiskTags: <String>['missing_next_meal_window'],
      expectAiGateOpen: false,
      notes:
          'If the timing window is missing, AI should stay gated off and deterministic ranking should be used directly.',
    ),
  ],
);
