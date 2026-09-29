import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';

void main() {
  test(
    'conservative result carries source-range sensitivity assessment',
    () async {
      final orchestrator = NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: const CdssCatalogProjectionService(
          database: _EmptyCdssDatabase(),
        ),
        localAiAdapter: null,
      );
      final foods = <FoodItem>[
        _foodWithProteinRange(),
        FoodItem(
          id: 'fixed_protein',
          name: 'Fixed protein',
          category: FoodCategory.other,
          sourceSystem: 'TEST_FIXTURE',
          jurisdiction: 'US',
          proteinG: 12,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 0,
        ),
      ];
      final result = await orchestrator.recommend(
        request: NextMealRecommendationRequest(
          userProfile: UserProfile.defaults(),
          history: const [],
          activeDrugs: <DrugDefinition>[
            DrugDefinition(
              id: 'levodopa-fixture',
              genericName: 'Levodopa',
              brandNames: const <String>[],
              tags: const <DrugTag>[DrugTag.levodopaLike],
              notes: '',
            ),
          ],
          now: DateTime.utc(2026, 9, 26),
          mode: RecommendationMode.conservativeOnly,
        ),
        candidateFoods: foods,
      );

      final assessment = result.rankSensitivityAssessment;
      expect(assessment, isNotNull);
      expect(
        assessment!.candidateSetSha256,
        result.candidateSetSnapshot.sha256Digest,
      );
      expect(assessment.hasBoundedScenarios, isTrue);
      expect(assessment.scenariosEvaluated, greaterThan(0));
      expect(assessment.fullRankStabilityAssessed, isFalse);
      expect(assessment.unresolvedReasonCounts, isNotEmpty);
    },
  );

  test('AI copy polish stays on when rerank is blocked by safety gate', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount += 1;
      if (request.url.path == '/api/tags') {
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
      final messages = body['messages'] as List<dynamic>;
      final content = (messages.first as Map<String, dynamic>)['content']
          .toString();

      if (content.contains('polishing ParkinSUM next-meal')) {
        return http.Response(
          jsonEncode({
            'message': {
              'content': jsonEncode({
                'summary':
                    'AI polished the wording while the conservative order stayed unchanged.',
                'candidate_notes': {
                  'banana':
                      'A plain-language reason for the same banana recommendation.',
                },
              }),
            },
          }),
          200,
        );
      }

      return http.Response(
        jsonEncode({
          'message': {'content': '{"ok":true}'},
        }),
        200,
      );
    });
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: const CdssCatalogProjectionService(
        database: _EmptyCdssDatabase(),
      ),
      localAiAdapter: LocalAiRecommendationAdapter(client: client),
    );

    final result = await orchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: UserProfile.defaults()
            .copyWith(
              localAiProviderPreference: LocalAiProviders.ollama,
              localAiModel: 'gemma3n:e2b',
              localAiMedicalModel:
                  'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M',
            )
            .withLocalAiConsentDecision(
              enabled: true,
              recordedAt: DateTime.utc(2026, 8, 18),
              source: 'test_fixture',
            ),
        history: const [],
        activeDrugs: const [],
        now: DateTime(2026, 5, 12),
        mode: RecommendationMode.hybridLocalLlm,
        userConsentedToAi: true,
      ),
      candidateFoods: [
        FoodItem(
          id: 'banana',
          name: 'Banana',
          category: FoodCategory.fruit,
          proteinG: 1,
          carbsG: 20,
          fatG: 0,
          fiberG: 2,
          sodiumMg: 1,
        ),
      ],
    );

    expect(result.decisionPath, 'conservative_safety_gate');
    expect(result.aiUsed, isTrue);
    expect(result.aiRerankUsed, isFalse);
    expect(result.gateReasons, isNotEmpty);
    expect(
      result.recommendations.single.reasons.first,
      contains('plain-language'),
    );
    expect(callCount, 3);
  });
}

FoodItem _foodWithProteinRange() => FoodItem(
  id: 'ranged_protein',
  name: 'Ranged protein',
  category: FoodCategory.other,
  sourceSystem: 'TEST_FIXTURE',
  jurisdiction: 'US',
  proteinG: 10,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
  nutrientObservationEvidence: <NutrientObservationEvidence>[
    _proteinObservation(
      id: 'protein_point',
      valueNum: 10,
      low: 10,
      high: 10,
      qualifierKind: 'exact',
      selected: true,
    ),
    _proteinObservation(
      id: 'protein_range',
      valueNum: null,
      low: 0,
      high: 25,
      qualifierKind: 'range',
      selected: false,
    ),
  ],
);

NutrientObservationEvidence _proteinObservation({
  required String id,
  required double? valueNum,
  required double? low,
  required double? high,
  required String qualifierKind,
  required bool selected,
}) => NutrientObservationEvidence(
  observationId: id,
  domain: 'food',
  entityType: 'food_variant',
  entityKey: 'food_variant_range_fixture',
  attributeCode: 'protein_g',
  valueType: 'numeric_interval',
  valueNum: valueNum,
  low: low,
  high: high,
  qualifierKind: qualifierKind,
  rawValueText: qualifierKind == 'exact' ? '$valueNum' : '$low-$high',
  unit: 'g',
  basisType: 'per_100g_edible_part',
  basisAmount: 100,
  scopeHash: 'scope_range_fixture',
  sourceDocId: 'source_range_fixture',
  recordLocator: id,
  methodCode: 'method_range_fixture',
  extractionConfidence: 1,
  selectedForLegacyPointProjection: selected,
);

class _EmptyCdssDatabase implements CdssDatabase {
  const _EmptyCdssDatabase();

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      const <Map<String, Object?>>[];

  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {}

  @override
  Future<void> insertCountryDietProfile(
    CountryDietProfileRecord record,
  ) async {}

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
    DrugProductPackagingRecord record,
  ) async {}

  @override
  Future<void> insertDrugProductVariant(
    DrugProductVariantRecord record,
  ) async {}

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {}

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {}

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {}

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {}

  @override
  Future<void> insertLocaleResourceBundle(
    LocaleResourceBundleRecord record,
  ) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {}

  @override
  Future<void> insertObservation(ObservationRecord record) async {}

  @override
  Future<void> insertRecommendationAuditLog(
    RecommendationAuditLogRecord record,
  ) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
    RegionJurisdictionMapRecord record,
  ) async {}

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {}

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {}

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {}

  @override
  Future<void> insertSnapshotDistribution(
    SnapshotDistributionRecord record,
  ) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}
}
