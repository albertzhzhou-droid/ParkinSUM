import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/constants/local_ai_replay_scenarios.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/domain/usecases/recommendation_replay_runner.dart';

/// P1 — Synthetic scenario replay system.
///
/// Replays the five fixed Local-AI scenario archetypes through the real
/// deterministic + hybrid orchestrators with an offline, scripted Local AI
/// (MockClient). Asserts per-archetype decision paths, a Local-AI safety
/// invariant (the AI path may only reorder the deterministic candidate set),
/// and that the structured JSON snapshot is byte-stable across runs (drift
/// guard). Educational prototype only; synthetic fixtures; no PHI.
void main() {
  /// Scripted offline Local AI: reports the model available, polishes wording
  /// with safe notes, and reranks by reversing the safe whitelist order. It
  /// never adds/drops ids or injects unsafe copy.
  MockClient buildScriptedClient() {
    List<String> jsonArrayAfter(String prompt, String marker) {
      final start = prompt.indexOf(marker);
      if (start < 0) return const <String>[];
      final rest = prompt.substring(start + marker.length);
      final open = rest.indexOf('[');
      final close = rest.indexOf(']');
      if (open < 0 || close < 0 || close < open) return const <String>[];
      return (jsonDecode(rest.substring(open, close + 1)) as List<dynamic>)
          .map((e) => e.toString())
          .toList(growable: false);
    }

    return MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/tags') {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'gemma3n:e2b', 'model': 'gemma3n:e2b'},
              {
                'name': 'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M',
                'model': 'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M',
              },
            ],
          }),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final content =
          ((body['messages'] as List).first['content'] ?? '').toString();

      if (content.contains('reply with {"ok":true}')) {
        return http.Response(
          jsonEncode({
            'message': {'content': '{"ok":true}'}
          }),
          200,
        );
      }

      if (content.contains('polishing ParkinSUM next-meal')) {
        final ids = jsonArrayAfter(content, 'Allowed food_id keys JSON: ');
        return http.Response(
          jsonEncode({
            'message': {
              'content': jsonEncode({
                'summary':
                    'Local AI polished the wording; the safe order is unchanged.',
                'candidate_notes': {
                  for (final id in ids) id: 'A plain-language reason for $id.',
                },
              })
            }
          }),
          200,
        );
      }

      if (content.contains('reranking already-safe')) {
        final allowed = jsonArrayAfter(content, 'Allowed candidate_ids JSON: ');
        final reversed = allowed.reversed.toList(growable: false);
        return http.Response(
          jsonEncode({
            'message': {
              'content': jsonEncode({
                'candidate_ids': reversed,
                'summary': 'Local AI replay reranked only the safe whitelist.',
                'safety_checks': ['Preserved the safe whitelist only.'],
                'ranking_rationale': ['Used the provided candidate features.'],
              })
            }
          }),
          200,
        );
      }

      return http.Response(
        jsonEncode({
          'message': {'content': '{}'}
        }),
        200,
      );
    });
  }

  RecommendationReplayRunner buildRunner() {
    const projection =
        CdssCatalogProjectionService(database: InMemoryCdssDatabase());
    final hybrid = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: projection,
      localAiAdapter:
          LocalAiRecommendationAdapter(client: buildScriptedClient()),
    );
    final deterministic = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: projection,
      localAiAdapter: null,
    );
    return RecommendationReplayRunner(
      hybridOrchestrator: hybrid,
      deterministicOrchestrator: deterministic,
      foodRepository: FoodRepository.createDefault(),
      medicationRepository: MedicationRepository.createDefault(),
    );
  }

  test('replays the five archetypes with expected decision paths', () async {
    final report =
        await buildRunner().run(dataset: localAiReplayScenarioDataset);
    expect(report.cases, hasLength(5));

    final byId = {for (final c in report.cases) c.benchmarkCase.caseId: c};

    // 1 — missing medication time/dose ⇒ conservative safety gate, gate reasons.
    final missing = byId['replay_missing_medication_time_or_dose']!;
    expect(missing.decisionPath, 'conservative_safety_gate');
    expect(missing.gateReasons, isNotEmpty);

    // 2 — low-risk next meal ⇒ Local AI rerank allowed.
    final lowRisk = byId['replay_low_risk_next_meal']!;
    expect(lowRisk.decisionPath, 'hybrid_local_ai');
    expect(lowRisk.aiUsed, isTrue);
    expect(lowRisk.rankingDiffs, isNotEmpty);

    // 3 — source fallback (AI disabled) ⇒ conservative deterministic path.
    final fallback = byId['replay_source_fallback_partial_provenance']!;
    expect(fallback.decisionPath, 'conservative_cdss');
    expect(fallback.aiUsed, isFalse);

    // 4 — levodopa-sensitive window ⇒ safety gate blocks reranking.
    final gated = byId['replay_safety_gate_blocks_local_ai']!;
    expect(gated.decisionPath, 'conservative_safety_gate');
    expect(gated.gateReasons, isNotEmpty);

    // 5 — medication catalog selection with safe candidates ⇒ AI path.
    final catalog = byId['replay_medication_catalog_selection_context']!;
    expect(catalog.decisionPath, 'hybrid_local_ai');
    expect(catalog.aiUsed, isTrue);
  });

  test('Local AI never changes the deterministic candidate set (safety)',
      () async {
    final report =
        await buildRunner().run(dataset: localAiReplayScenarioDataset);
    expect(report.allPreservedCandidateSet, isTrue);
    for (final c in report.cases) {
      // Whatever the AI did, the resulting set of food ids equals the
      // deterministic set (reorder-only; never invent or drop).
      expect(c.aiRanking.toSet(), c.deterministicRanking.toSet(),
          reason: '${c.benchmarkCase.caseId} changed the candidate set');
    }
  });

  test('structured JSON snapshot is byte-stable across runs (drift guard)',
      () async {
    final first =
        await buildRunner().run(dataset: localAiReplayScenarioDataset);
    final second =
        await buildRunner().run(dataset: localAiReplayScenarioDataset);
    final a = const JsonEncoder.withIndent('  ').convert(first.toJson());
    final b = const JsonEncoder.withIndent('  ').convert(second.toJson());
    expect(a, b, reason: 'Replay output drifted between identical runs.');
    // Sanity: snapshot carries the dataset version and all five cases.
    final decoded = jsonDecode(a) as Map<String, dynamic>;
    expect(decoded['dataset_version'], localAiReplayScenarioDataset.version);
    expect((decoded['cases'] as List), hasLength(5));
  });
}
