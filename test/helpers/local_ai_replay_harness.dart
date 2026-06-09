import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/domain/usecases/recommendation_replay_runner.dart';

/// Shared offline replay harness for the Local AI scenario tests.
///
/// [buildScriptedLocalAiClient] is a deterministic Local AI stand-in: it
/// reports the model available, returns safe wording-polish notes, and reranks
/// only by reversing the supplied safe whitelist. It never adds/drops candidate
/// ids and never emits unsafe copy, so the replay exercises the AI path with
/// zero network access. Educational prototype; synthetic fixtures; no PHI.
MockClient buildScriptedLocalAiClient() {
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

/// Builds the deterministic + hybrid orchestrator pair around the scripted
/// offline Local AI and the in-memory CDSS database, wired exactly like the
/// scenario replay tests expect.
RecommendationReplayRunner buildLocalAiReplayRunner() {
  const projection =
      CdssCatalogProjectionService(database: InMemoryCdssDatabase());
  final hybrid = NextMealRecommendationOrchestrator(
    conservativeRecommender: GetFoodRecommendationsUseCase(),
    projectionService: projection,
    localAiAdapter:
        LocalAiRecommendationAdapter(client: buildScriptedLocalAiClient()),
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
