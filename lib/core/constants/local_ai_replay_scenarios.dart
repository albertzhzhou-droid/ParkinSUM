import '../../domain/entities/recommendation_benchmark_models.dart';

/// Fixed synthetic replay scenarios for the recommendation orchestrator.
///
/// These are deterministic, educational fixtures (synthetic foods/drugs only;
/// no PHI). Each case maps to one of the required archetypes via `focusTags`
/// so the replay artifact and drift test can assert per-archetype behaviour:
///
///   - `missing_medication_time_or_dose`
///   - `low_risk_next_meal`
///   - `source_fallback_partial_provenance`
///   - `safety_gate_blocks_local_ai`
///   - `medication_catalog_selection_context`
///
/// They exercise the SAME deterministic + hybrid orchestrators the app uses;
/// the Local AI path (when consented) may only reorder the safe whitelist, so
/// the replay records the deterministic vs AI ranking for drift + safety review.
const localAiReplayScenarioDataset = RecommendationBenchmarkDataset(
  version: 'local-ai-replay.2026-06.v1',
  cases: <RecommendationBenchmarkCase>[
    // 1 — Missing medication time/dose: a levodopa intake with no parsable dose
    // and no next-meal window. The orchestrator must stay conservative and
    // surface a gate reason rather than letting Local AI rerank.
    RecommendationBenchmarkCase(
      caseId: 'replay_missing_medication_time_or_dose',
      title: 'Missing medication time/dose keeps the conservative path',
      focusTags: <String>['missing_medication_time_or_dose'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>['food_banana', 'food_apple', 'food_oats'],
      historyFoodIds: <String>['food_oats'],
      includeNextMealWindow: false,
      activeDrugIds: <String>['drug_levodopa_carbidopa'],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[
        RecommendationBenchmarkIntakeSpec(
          drugId: 'drug_levodopa_carbidopa',
          minutesAfterMeal: 200,
          dosageNote: '',
        ),
      ],
      expectedTopFoodIds: <String>['food_banana', 'food_apple'],
      expectedRiskTags: <String>[],
      userConsentedToAi: true,
      notes:
          'No next-meal window and no parsable dose: a gate reason must fire and '
          'Local AI must not rerank.',
    ),
    // 2 — Low-risk next-meal: no drugs, low-protein fruit, clear window. User
    // consent is enabled and the safety checks permit Local AI to reorder the
    // safe whitelist.
    RecommendationBenchmarkCase(
      caseId: 'replay_low_risk_next_meal',
      title: 'Low-risk next meal allows safe Local AI reranking',
      focusTags: <String>['low_risk_next_meal'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>['food_banana', 'food_apple', 'food_blueberry'],
      historyFoodIds: <String>['food_apple'],
      activeDrugIds: <String>[],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[],
      expectedTopFoodIds: <String>['food_banana', 'food_apple'],
      expectedRiskTags: <String>[],
      userConsentedToAi: true,
      notes:
          'No medications and a clear window: with consent enabled, the safety '
          'checks permit Local AI to reorder only the deterministic whitelist.',
    ),
    // 3 — Source fallback / partial provenance: a CN diet profile over US seed
    // foods exercises jurisdiction fallback + capped synthetic provenance. AI
    // disabled so the deterministic conservative path is recorded.
    RecommendationBenchmarkCase(
      caseId: 'replay_source_fallback_partial_provenance',
      title: 'Source fallback keeps a transparent conservative ranking',
      focusTags: <String>['source_fallback_partial_provenance'],
      registrationRegion: 'CN',
      displayLocale: 'zh-CN',
      dietProfileRegion: 'CN',
      candidateFoodIds: <String>['food_banana', 'food_brown_rice', 'food_tofu'],
      historyFoodIds: <String>['food_brown_rice'],
      activeDrugIds: <String>[],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[],
      expectedTopFoodIds: <String>['food_banana'],
      expectedRiskTags: <String>[],
      userConsentedToAi: false,
      notes:
          'US-seed foods under a CN diet profile rely on jurisdiction fallback '
          'with capped synthetic provenance; AI disabled for this case.',
    ),
    // 4 — Safety gate blocks Local AI: an active levodopa selection combined
    // with a low-quality (legacy-migrated) meal time triggers a data-quality
    // gate, so reranking is blocked even with consent.
    RecommendationBenchmarkCase(
      caseId: 'replay_safety_gate_blocks_local_ai',
      title: 'Low-quality meal time blocks Local AI reranking',
      focusTags: <String>['safety_gate_blocks_local_ai'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>['food_tofu', 'food_oats', 'food_banana'],
      historyFoodIds: <String>['food_oats'],
      historyMealTimeSource: 'migration_legacy',
      historyMealTimePrecision: 'unknown',
      nextMealWindowStartMinutesAfterMeal: 330,
      nextMealWindowEndMinutesAfterMeal: 390,
      activeDrugIds: <String>['drug_levodopa_carbidopa'],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[
        RecommendationBenchmarkIntakeSpec(
          drugId: 'drug_levodopa_carbidopa',
          minutesAfterMeal: 350,
          dosageNote: '25/100',
        ),
      ],
      expectedTopFoodIds: <String>['food_banana'],
      expectedRiskTags: <String>[],
      userConsentedToAi: true,
      notes:
          'A legacy-migrated meal time is too low-quality to rerank against; the '
          'conservative ranking is kept and Local AI cannot rerank.',
    ),
    // 5 — Medication catalog selection context: an active levodopa selection
    // with low-protein candidates. Consent is enabled and deterministic safety
    // checks permit the medication context to flow into a safe AI-assisted path.
    RecommendationBenchmarkCase(
      caseId: 'replay_medication_catalog_selection_context',
      title: 'Medication catalog selection flows into a safe AI path',
      focusTags: <String>['medication_catalog_selection_context'],
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      candidateFoodIds: <String>['food_banana', 'food_apple', 'food_blueberry'],
      historyFoodIds: <String>['food_apple'],
      nextMealWindowStartMinutesAfterMeal: 330,
      nextMealWindowEndMinutesAfterMeal: 390,
      activeDrugIds: <String>['drug_levodopa_carbidopa'],
      intakeSpecs: <RecommendationBenchmarkIntakeSpec>[
        RecommendationBenchmarkIntakeSpec(
          drugId: 'drug_levodopa_carbidopa',
          minutesAfterMeal: 350,
          dosageNote: '25/100',
        ),
      ],
      expectedTopFoodIds: <String>['food_banana', 'food_apple'],
      expectedRiskTags: <String>[],
      userConsentedToAi: true,
      notes:
          'A levodopa catalog selection with low-protein candidates and consent '
          'enabled can flow into the safe AI path.',
    ),
  ],
);
