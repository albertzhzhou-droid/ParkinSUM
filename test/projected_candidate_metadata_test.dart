import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';

/// Guards issue 2: mechanistic candidate scoring + CandidateMetadata are built
/// from the SAME merged/projected candidate list the conservative path uses —
/// not the original candidateFoods. Projected (official/CDSS) foods win id
/// collisions so their provenance + completeness metadata reaches the scorer.
void main() {
  // A rich, official-style projected food (USDA food-composition table).
  FoodItem projectedUsda(String id, {String jurisdiction = 'US'}) => FoodItem(
        id: id,
        name: 'projected official food',
        category: FoodCategory.protein,
        sourceSystem: 'USDA_FDC',
        sourceFoodCode: '173688',
        jurisdiction: jurisdiction,
        proteinG: 26,
        carbsG: 0,
        fatG: 5,
        fiberG: 0,
        sodiumMg: 70,
        energyKcal: 200,
        basisType: 'per_100g',
        aminoAcidProfile: const AminoAcidProfile(leucine: 2.1, valine: 1.3),
      );

  // A poor seed food sharing the same id (would win under the old putIfAbsent).
  FoodItem seedDuplicate(String id) => FoodItem(
        id: id,
        name: 'seed food',
        category: FoodCategory.protein,
        sourceSystem: 'LOCAL_SEED',
        jurisdiction: 'GLOBAL',
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        fiberG: 0,
        sodiumMg: 0,
        missingNutrientFields: const {
          'proteinG',
          'carbsG',
          'fatG',
          'fiberG',
          'sodiumMg',
          'energyKcal',
          'waterG',
        },
      );

  NextMealRecommendationRequest requestWithWindow() {
    final now = DateTime.utc(2026, 1, 1, 8);
    return NextMealRecommendationRequest(
      userProfile: UserProfile.defaults().copyWith(
        registrationRegion: 'US',
        contentJurisdictionOverride: const ['US'],
      ),
      history: const [],
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa',
          genericName: 'levodopa',
          brandNames: const ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
          jurisdiction: 'US',
        ),
      ],
      intakes: [
        Intake(
          id: 'intake_1',
          drugId: 'drug_levodopa',
          takenAt: now.add(const Duration(minutes: 30)),
          dosageNote: '100 mg',
        ),
      ],
      now: now,
      userConsentedToAi: false,
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(now) + 60,
          endMinute: dateTimeToMinute(now) + 120,
        ),
        source: 'test',
      ),
    );
  }

  test('projected food metadata reaches MechanisticNextMealScorer', () async {
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService:
          _FakeProjectionService([projectedUsda('food_official')]),
      localAiAdapter: null,
    );

    final result = await orchestrator.recommend(
      request: requestWithWindow(),
      candidateFoods: const [],
    );

    final scores = result.mechanisticCandidateScores;
    expect(scores, isNotNull);
    final official =
        scores!.firstWhere((s) => s.candidateFoodId == 'food_official');
    // The projected source system + real provenance/completeness reached the
    // scorer — NOT the neutral 0.5 defaults used when metadata is absent.
    expect(official.sourceSystem, 'USDA_FDC');
    expect(official.insufficientContext, isFalse);
    expect(official.provenanceQualityScore, greaterThan(0.5));
    expect(official.metadataCompletenessScore, greaterThan(0.5));
    expect(official.sourceAuthorityScore, greaterThan(0.3));
  });

  test(
      'duplicate seed/projected food id prefers the richer official/projected '
      'metadata for mechanistic scoring', () async {
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      // Projection emits the rich USDA entry for the shared id.
      projectionService: _FakeProjectionService([projectedUsda('food_dup')]),
      localAiAdapter: null,
    );

    final result = await orchestrator.recommend(
      request: requestWithWindow(),
      // Caller supplies a poor seed entry with the SAME id.
      candidateFoods: [seedDuplicate('food_dup')],
    );

    final scores = result.mechanisticCandidateScores;
    expect(scores, isNotNull);
    final dup = scores!.firstWhere((s) => s.candidateFoodId == 'food_dup');
    // The official/projected entry won the merge → its provenance drives
    // scoring, not the seed's empty metadata.
    expect(dup.sourceSystem, 'USDA_FDC');
    expect(dup.sourceSystem, isNot('LOCAL_SEED'));
    expect(dup.provenanceQualityScore, greaterThan(0.5));
  });
}

/// Test double: returns injected projected foods without touching a database.
class _FakeProjectionService extends CdssCatalogProjectionService {
  _FakeProjectionService(this._foods) : super(database: const _StubDb());

  final List<FoodItem> _foods;

  @override
  Future<List<FoodItem>> projectFoods() async => _foods;

  @override
  Future<ProjectedDrugDetail?> projectDrugDetail(DrugDefinition drug) async =>
      null;
}

/// Minimal CdssDatabase stub; no method is exercised because the projection
/// service methods used by the orchestrator are overridden above.
class _StubDb implements CdssDatabase {
  const _StubDb();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
