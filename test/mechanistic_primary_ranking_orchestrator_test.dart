import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/intake_dose_context_builder.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';

/// Guards the production boundary end-to-end: mechanistic candidate scores are
/// inspectable educational traces, but they are not validated or calibrated to
/// replace the conservative ranking.
void main() {
  FoodItem food(String id, String name, double protein) => FoodItem(
    id: id,
    name: name,
    category: FoodCategory.protein,
    sourceSystem: 'USDA_FDC',
    jurisdiction: 'US',
    proteinG: protein,
    carbsG: 10,
    fatG: 2,
    fiberG: 1,
    sodiumMg: 50,
    energyKcal: 150,
  );

  final candidates = [
    food('food_low', 'low protein item', 1),
    food('food_high', 'high protein item', 30),
  ];

  NextMealRecommendationRequest request({
    UserDefinedMealWindow? window,
    DrugDefinition? activeDrug,
    Intake? intakeOverride,
    List<Meal> history = const [],
  }) {
    final now = DateTime.utc(2026, 1, 1, 8);
    final drug =
        activeDrug ??
        DrugDefinition(
          id: 'drug_levodopa',
          genericName: 'carbidopa/levodopa',
          brandNames: const ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
          jurisdiction: 'US',
        );
    return NextMealRecommendationRequest(
      userProfile: UserProfile.defaults().copyWith(
        registrationRegion: 'US',
        contentJurisdictionOverride: const ['US'],
      ),
      history: history,
      activeDrugs: [drug],
      intakes: [
        intakeOverride ??
            Intake(
              id: 'intake_1',
              drugId: drug.id,
              takenAt: now.add(const Duration(minutes: 30)),
              dosageNote: '100 mg',
            ),
      ],
      now: now,
      userConsentedToAi: false,
      userDefinedWindow: window,
    );
  }

  NextMealRecommendationOrchestrator buildOrchestrator() =>
      NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: _FakeProjectionService(const []),
        localAiAdapter: null,
      );

  test(
    'eligible trace stays heuristic and preserves conservative order',
    () async {
      final now = DateTime.utc(2026, 1, 1, 8);
      final history = [
        Meal(
          id: 'known_history_meal',
          eatenAt: now.subtract(const Duration(hours: 1)),
          title: 'Known history meal',
          items: [MealItem.fromFood(food: candidates.first, quantityFactor: 1)],
        ),
      ];
      final result = await buildOrchestrator().recommend(
        request: request(
          history: history,
          window: UserDefinedMealWindow(
            window: TimelineWindow(
              startMinute: dateTimeToMinute(now) + 60,
              endMinute: dateTimeToMinute(now) + 120,
            ),
            source: 'test',
          ),
        ),
        candidateFoods: candidates,
      );
      final conservative = await buildOrchestrator().recommend(
        request: request(window: null, history: history),
        candidateFoods: candidates,
      );

      expect(result.rankerEligibility, isNotNull);
      expect(result.rankerEligibility!.rankerUsed, 'heuristic_legacy_fallback');
      expect(result.rankerEligibility!.mechanisticPrimaryEligible, isFalse);
      expect(
        result.rankerEligibility!.fallbackReasons,
        contains('mechanistic_trace_only_not_validated_for_ranking'),
      );
      expect(result.mechanisticCandidateScores, isNotEmpty);
      expect(
        result.mechanisticCandidateScores!.any(
          (score) => score.hasModeledOutput,
        ),
        isTrue,
      );
      expect(
        result.recommendations.map((item) => item.food.id),
        conservative.recommendations.map((item) => item.food.id),
      );
    },
  );

  test('missing user window → heuristic_legacy_fallback with reason', () async {
    final result = await buildOrchestrator().recommend(
      request: request(window: null),
      candidateFoods: candidates,
    );
    expect(result.rankerEligibility!.rankerUsed, 'heuristic_legacy_fallback');
    expect(result.rankerEligibility!.mechanisticPrimaryEligible, isFalse);
    expect(
      result.rankerEligibility!.fallbackReasons,
      contains('missing_user_defined_window'),
    );
  });

  test(
    'selected package without formulation snapshot blocks an otherwise IR trace',
    () async {
      final now = DateTime.utc(2026, 1, 1, 8);
      final catalogDrug = DrugDefinition(
        id: 'drug_catalog_ir',
        genericName: 'carbidopa/levodopa',
        brandNames: const ['Catalog IR fixture'],
        tags: const [DrugTag.levodopaLike],
        notes: '',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate_release',
        sourceSystem: 'DAILYMED',
        sourceProductCode: 'catalog_product_ir',
        jurisdiction: 'US',
      );
      final selectedErPackage = IntakeDoseContextBuilder()
          .build(
            id: 'intake_1',
            drugId: catalogDrug.id,
            takenAt: now.add(const Duration(minutes: 30)),
            dosageNote: '100 mg',
            drug: catalogDrug,
          )
          .copyWith(
            productSelection: const MedicationProductSelection(
              packId: 'pack_er_example',
              identifierSystem: 'ndcPackage',
              identifierValue: '00000-0000-00',
              displayName: 'Carbidopa/levodopa ER package',
              labelerName: 'fixture',
              strengthDisplay: '25 mg / 100 mg',
              packageDescription: 'extended-release fixture package',
            ),
          );
      expect(catalogDrug.releaseType, 'immediate_release');
      expect(selectedErPackage.releaseType, 'immediate_release');
      final result = await buildOrchestrator().recommend(
        request: request(
          activeDrug: catalogDrug,
          intakeOverride: selectedErPackage,
          history: [
            Meal(
              id: 'known_history_meal',
              eatenAt: now.subtract(const Duration(hours: 1)),
              title: 'Known history meal',
              items: [
                MealItem.fromFood(food: candidates.first, quantityFactor: 1),
              ],
            ),
          ],
          window: UserDefinedMealWindow(
            window: TimelineWindow(
              startMinute: dateTimeToMinute(now) + 60,
              endMinute: dateTimeToMinute(now) + 120,
            ),
            source: 'test',
          ),
        ),
        candidateFoods: candidates,
      );

      expect(
        result.mechanisticCandidateScores!.every(
          (score) => !score.hasModeledOutput,
        ),
        isTrue,
      );
      expect(result.rankerUsed, 'heuristic_legacy_fallback');
      expect(
        result.rankerEligibility!.fallbackReasons,
        contains('mechanistic_applicability.release_type_not_supported'),
      );
    },
  );

  test('rankerUsed reports an actual consented local-AI reorder', () async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final priorMeal = Meal(
      id: 'meal_history',
      eatenAt: now.subtract(const Duration(hours: 1)),
      timeSource: 'user_entered',
      nextMealWindowStart: now.add(const Duration(minutes: 60)),
      nextMealWindowEnd: now.add(const Duration(minutes: 120)),
      title: 'fixture meal',
      items: [MealItem.fromFood(food: candidates.first, quantityFactor: 1)],
    );
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: _FakeProjectionService(const []),
      localAiAdapter: _ReverseSafeListAdapter(),
    );
    final result = await orchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: UserProfile.defaults().withLocalAiConsentDecision(
          enabled: true,
          recordedAt: DateTime.utc(2026, 8, 18),
          source: 'test_fixture',
        ),
        history: [priorMeal],
        activeDrugs: const [],
        intakes: const [],
        now: now,
        mode: RecommendationMode.hybridLocalLlm,
        userConsentedToAi: true,
        userDefinedWindow: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      ),
      candidateFoods: candidates,
    );

    expect(result.aiRerankUsed, isTrue);
    expect(result.rankerUsed, 'local_ai_safe_candidate_rerank');
    expect(
      result.rankerEligibility!.rankerUsed,
      'local_ai_safe_candidate_rerank',
    );
    expect(
      result.rankerEligibility!.fallbackReasons,
      contains('mechanistic_trace_only_not_validated_for_ranking'),
    );
  });

  test('non-levodopa cannot become mechanistic_primary', () async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final result = await buildOrchestrator().recommend(
      request: request(
        activeDrug: DrugDefinition(
          id: 'drug_iron',
          genericName: 'ferrous sulfate',
          brandNames: const [],
          tags: const [DrugTag.mineralSupplement],
          notes: '',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
          jurisdiction: 'US',
        ),
        window: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      ),
      candidateFoods: candidates,
    );

    expect(result.rankerUsed, 'heuristic_legacy_fallback');
    expect(
      result.rankerEligibility!.fallbackReasons,
      contains('mechanistic_applicability.active_ingredient_not_levodopa'),
    );
    expect(
      result.mechanisticCandidateScores!.every((s) => s.insufficientContext),
      isTrue,
    );
  });

  test('levodopa-like substring and tag are not ingredient identity', () async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final result = await buildOrchestrator().recommend(
      request: request(
        activeDrug: DrugDefinition(
          id: 'drug_fake',
          genericName: 'not-levodopa-like placebo',
          brandNames: const [],
          tags: const [DrugTag.levodopaLike],
          notes: '',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
          jurisdiction: 'US',
        ),
        window: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      ),
      candidateFoods: candidates,
    );

    expect(result.rankerUsed, 'heuristic_legacy_fallback');
    expect(
      result.rankerEligibility!.fallbackReasons,
      contains('mechanistic_applicability.active_ingredient_not_levodopa'),
    );
  });

  for (final unsupported
      in <({String field, DrugDefinition drug, String reason})>[
        (
          field: 'route',
          drug: DrugDefinition(
            id: 'bad_route',
            genericName: 'levodopa/carbidopa',
            brandNames: const [],
            tags: const [DrugTag.levodopaLike],
            notes: '',
            route: 'transdermal',
            dosageForm: 'tablet',
            releaseType: 'immediate',
            jurisdiction: 'US',
          ),
          reason: 'mechanistic_applicability.route_not_supported',
        ),
        (
          field: 'missing route',
          drug: DrugDefinition(
            id: 'missing_route',
            genericName: 'levodopa/carbidopa',
            brandNames: const [],
            tags: const [DrugTag.levodopaLike],
            notes: '',
            dosageForm: 'tablet',
            releaseType: 'immediate',
            jurisdiction: 'US',
          ),
          reason: 'mechanistic_applicability.route_not_supported',
        ),
        (
          field: 'form',
          drug: DrugDefinition(
            id: 'bad_form',
            genericName: 'levodopa/carbidopa',
            brandNames: const [],
            tags: const [DrugTag.levodopaLike],
            notes: '',
            route: 'oral',
            dosageForm: 'patch',
            releaseType: 'immediate',
            jurisdiction: 'US',
          ),
          reason: 'mechanistic_applicability.dosage_form_not_supported',
        ),
        (
          field: 'release',
          drug: DrugDefinition(
            id: 'bad_release',
            genericName: 'levodopa/carbidopa',
            brandNames: const [],
            tags: const [DrugTag.levodopaLike],
            notes: '',
            route: 'oral',
            dosageForm: 'tablet',
            releaseType: 'immediate_or_extended_release',
            jurisdiction: 'US',
          ),
          reason: 'mechanistic_applicability.release_type_not_supported',
        ),
      ]) {
    test(
      'unsupported ${unsupported.field} cannot become mechanistic_primary',
      () async {
        final now = DateTime.utc(2026, 1, 1, 8);
        final result = await buildOrchestrator().recommend(
          request: request(
            activeDrug: unsupported.drug,
            window: UserDefinedMealWindow(
              window: TimelineWindow(
                startMinute: dateTimeToMinute(now) + 60,
                endMinute: dateTimeToMinute(now) + 120,
              ),
              source: 'test',
            ),
          ),
          candidateFoods: candidates,
        );

        expect(result.rankerUsed, 'heuristic_legacy_fallback');
        expect(
          result.rankerEligibility!.fallbackReasons,
          contains(unsupported.reason),
        );
      },
    );
  }
}

class _FakeProjectionService extends CdssCatalogProjectionService {
  _FakeProjectionService(this._foods) : super(database: const _StubDb());
  final List<FoodItem> _foods;

  @override
  Future<List<FoodItem>> projectFoods() async => _foods;

  @override
  Future<ProjectedDrugDetail?> projectDrugDetail(DrugDefinition drug) async =>
      null;
}

class _StubDb implements CdssDatabase {
  const _StubDb();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReverseSafeListAdapter extends LocalAiRecommendationAdapter {
  @override
  Future<LocalAiAvailability> probe({required UserProfile userProfile}) async =>
      const LocalAiAvailability(
        available: true,
        provider: LocalAiProviders.ollama,
        endpoint: 'http://127.0.0.1:11434',
        model: 'fixture',
        message: 'fixture available',
      );

  @override
  Future<LocalAiRecommendationPolishResult?> polishRecommendationReasons({
    required UserProfile userProfile,
    required List<FoodRecommendation> recommendations,
    required List<String> contextLines,
    LocalAiAvailability? availability,
  }) async => null;

  @override
  Future<LocalAiRerankResult?> rerankSafeCandidates({
    required UserProfile userProfile,
    required List<FoodRecommendation> candidates,
    required List<String> contextLines,
    LocalAiAvailability? availability,
  }) async => LocalAiRerankResult(
    candidateIds: candidates
        .map((candidate) => candidate.food.id)
        .toList(growable: false)
        .reversed
        .toList(growable: false),
    summary: 'fixture rerank',
    safetyChecks: const ['fixture whitelist preserved'],
    rankingRationale: const ['fixture order reversed'],
    provider: LocalAiProviders.ollama,
    endpoint: 'http://127.0.0.1:11434',
    model: 'fixture',
  );
}
