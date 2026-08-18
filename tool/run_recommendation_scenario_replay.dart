// Replays the fixed Local-AI recommendation scenarios (the five archetypes) and
// writes the deterministic reviewer artifact under
// build/recommendation_scenario_replay/.
//
// Usage:
//   dart run tool/run_recommendation_scenario_replay.dart
//   (or: npm run recommend:replay)
//
// Educational/research prototype. Deterministic replay only. It runs the same
// conservative + hybrid orchestrators the app uses, with an OFFLINE scripted
// Local AI stand-in (no network) that may only reorder the safe whitelist. It
// adds no medical advice, no dose/timing/diet guidance, is not calibrated for
// real care, and uses synthetic/demo data only. No PHI. Exits non-zero iff the
// Local-AI candidate-set safety invariant is violated.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/constants/local_ai_replay_scenarios.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/domain/usecases/recommendation_replay_runner.dart';

Future<void> main() async {
  final projection = CdssCatalogProjectionService(
    database: InMemoryCdssDatabase(),
  );
  final hybrid = NextMealRecommendationOrchestrator(
    conservativeRecommender: GetFoodRecommendationsUseCase(),
    projectionService: projection,
    localAiAdapter: LocalAiRecommendationAdapter(
      client: _ScriptedLocalAiClient(),
    ),
  );
  final deterministic = NextMealRecommendationOrchestrator(
    conservativeRecommender: GetFoodRecommendationsUseCase(),
    projectionService: projection,
    localAiAdapter: null,
  );
  final runner = RecommendationReplayRunner(
    hybridOrchestrator: hybrid,
    deterministicOrchestrator: deterministic,
    foodRepository: FoodRepository.createDefault(),
    medicationRepository: MedicationRepository.createDefault(),
  );

  final report = await runner.run(dataset: localAiReplayScenarioDataset);

  final outDir = Directory('build/recommendation_scenario_replay');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
  File('${outDir.path}/latest.md').writeAsStringSync(
    report.toReviewerMarkdown(archetypeNotes: localAiReplayArchetypeNotes),
  );

  final safe = report.allPreservedCandidateSet;
  stdout
    ..writeln(
      'Recommendation scenario replay: ${report.cases.length} scenarios '
      '(dataset ${localAiReplayScenarioDataset.version}).',
    )
    ..writeln('Local-AI candidate-set safety invariant held: $safe.')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  for (final c in report.cases) {
    stdout.writeln(
      '  - ${c.benchmarkCase.caseId}: ${c.decisionPath} '
      '(ai_used=${c.aiUsed})',
    );
  }
  if (!safe) {
    stderr.writeln(
      'BLOCKER: Local AI changed the deterministic candidate set.',
    );
  }
  exitCode = safe ? 0 : 1;
}

/// Offline, deterministic Local AI stand-in (mirrors the test harness in
/// test/helpers/local_ai_replay_harness.dart). Reports the model available,
/// returns safe copy-polish notes, and reranks only by reversing the supplied
/// safe whitelist. It never adds/drops candidate ids or emits unsafe copy, so
/// the replay exercises the AI path with zero network access.
class _ScriptedLocalAiClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET' && request.url.path == '/api/tags') {
      return _json(
        jsonEncode({
          'models': [
            {'name': 'gemma3n:e2b', 'model': 'gemma3n:e2b'},
          ],
        }),
      );
    }
    final body = request is http.Request ? request.body : '';
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final content = ((decoded['messages'] as List).first['content'] ?? '')
        .toString();

    if (content.contains('reply with {"ok":true}')) {
      return _json(
        jsonEncode({
          'message': {'content': '{"ok":true}'},
        }),
      );
    }
    if (content.contains('polishing ParkinSUM next-meal')) {
      final ids = _jsonArrayAfter(content, 'Allowed food_id keys JSON: ');
      return _json(
        jsonEncode({
          'message': {
            'content': jsonEncode({
              'summary': 'Local AI polished the wording; safe order unchanged.',
              'candidate_notes': {
                for (final id in ids) id: 'A plain-language reason for $id.',
              },
            }),
          },
        }),
      );
    }
    if (content.contains('reranking already-safe')) {
      final allowed = _jsonArrayAfter(content, 'Allowed candidate_ids JSON: ');
      return _json(
        jsonEncode({
          'message': {
            'content': jsonEncode({
              'candidate_ids': allowed.reversed.toList(growable: false),
              'summary': 'Local AI replay reranked only the safe whitelist.',
              'safety_checks': ['Preserved the safe whitelist only.'],
              'ranking_rationale': ['Used the provided candidate features.'],
            }),
          },
        }),
      );
    }
    return _json(
      jsonEncode({
        'message': {'content': '{}'},
      }),
    );
  }

  List<String> _jsonArrayAfter(String prompt, String marker) {
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

  http.StreamedResponse _json(String payload) => http.StreamedResponse(
    Stream.value(utf8.encode(payload)),
    200,
    headers: {'content-type': 'application/json'},
  );
}
