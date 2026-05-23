import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/recommendation_benchmark_models.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/domain/usecases/recommendation_replay_runner.dart';

void main() {
  test('replay runner outputs deterministic ranking, AI ranking and diffs',
      () async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/tags') {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'gemma3n:e2b'},
              {'name': 'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M'},
            ],
          }),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if ((body['format'] as Map<String, dynamic>?)?['required'] != null) {
        if ((body['messages'] as List)
            .first['content']
            .toString()
            .contains('reply with {"ok":true}')) {
          return http.Response(
            jsonEncode({
              'message': {'content': '{"ok":true}'}
            }),
            200,
          );
        }
      }

      final prompt =
          ((body['messages'] as List).first['content'] ?? '').toString();
      const marker = 'Candidates JSON:\n';
      final jsonStart = prompt.indexOf(marker);
      final candidateJson = prompt.substring(jsonStart + marker.length).trim();
      final candidates = (jsonDecode(candidateJson) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final reversedIds = candidates
          .map((item) => item['food_id'].toString())
          .toList(growable: false)
          .reversed
          .toList(growable: false);
      return http.Response(
        jsonEncode({
          'message': {
            'content': jsonEncode({
              'candidate_ids': reversedIds,
              'summary': 'Local AI replay reranked the whitelist.',
              'safety_checks': [
                'Preserved the safe whitelist only.',
              ],
              'ranking_rationale': [
                'Used the provided structured candidate features.',
              ],
            }),
          },
        }),
        200,
      );
    });

    final projectionService =
        CdssCatalogProjectionService(database: _EmptyCdssDatabase());
    final hybrid = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: projectionService,
      localAiAdapter: LocalAiRecommendationAdapter(client: client),
    );
    final deterministic = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: projectionService,
      localAiAdapter: null,
    );
    final runner = RecommendationReplayRunner(
      hybridOrchestrator: hybrid,
      deterministicOrchestrator: deterministic,
      foodRepository: FoodRepository.createDefault(),
      medicationRepository: MedicationRepository.createDefault(),
    );

    final dataset = RecommendationBenchmarkDataset(
      version: 'test',
      cases: <RecommendationBenchmarkCase>[
        defaultRecommendationBenchmarkDataset.cases.first,
        defaultRecommendationBenchmarkDataset.cases.last,
      ],
    );
    final report = await runner.run(dataset: dataset);

    expect(report.cases, hasLength(2));
    expect(report.cases.first.deterministicRanking, isNotEmpty);
    expect(report.cases.first.aiRanking, isNotEmpty);
    expect(report.cases.first.aiUsed, isTrue);
    expect(report.cases.first.rankingDiffs, isNotEmpty);
    expect(report.cases.last.aiUsed, isFalse);
    expect(report.cases.last.gateReasons, isNotEmpty);
    expect(report.toMarkdown(), contains('Recommendation Replay Report'));
  });
}

class _EmptyCdssDatabase implements CdssDatabase {
  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {}

  @override
  Future<void> insertCountryDietProfile(
      CountryDietProfileRecord record) async {}

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {}

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {}

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {}

  @override
  Future<void> insertDrugProductVariant(
      DrugProductVariantRecord record) async {}

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {}

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {}

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {}

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {}

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {}

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {}

  @override
  Future<void> insertObservation(ObservationRecord record) async {}

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {}

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {}

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {}

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      const <Map<String, Object?>>[];
}
