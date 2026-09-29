import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_event_ledger.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/intake_dose_context_builder.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_authorization.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_capsule_service.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';

/// Guards the production boundary end-to-end: mechanistic candidate scores are
/// inspectable educational traces, but they are not validated or calibrated to
/// replace the conservative ranking.
void main() {
  final doseConfirmation = AdministrationDoseConfirmationCoordinator();
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
    final profile = UserProfile.defaults().copyWith(
      registrationRegion: 'US',
      contentJurisdictionOverride: const ['US'],
    );
    final unconfirmed =
        intakeOverride ??
        Intake(
          id: 'intake_1',
          drugId: drug.id,
          takenAt: now.subtract(const Duration(minutes: 30)),
          dosageNote: '100 mg',
        );
    final confirmed = doseConfirmation
        .prepare(
          draft: unconfirmed,
          current: null,
          expectedRecordRevisionDigest:
              administrationDoseConfirmationAbsentRevisionDigest,
          ownerScope: profile.patientId,
          operationId: 'event_op_${unconfirmed.id}',
          confirmationRequested: true,
          assertionSource: AdministrationDoseAssertionSource.typed,
          confirmationAction: 'test.explicit_confirmation',
          uiContractVersion: 'test-dose-confirmation:1',
          confirmedAt: DateTime.utc(2026, 1, 1, 7, 59),
        )
        .intake!;
    return NextMealRecommendationRequest(
      userProfile: profile,
      history: history,
      activeDrugs: [drug],
      intakes: [confirmed],
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
      expect(
        result.candidateSetSnapshot.sha256Digest,
        conservative.candidateSetSnapshot.sha256Digest,
      );
      expect(result.candidateSetSnapshot.orderedCandidateIds, <String>[
        'food_low',
        'food_high',
      ]);
      expect(
        result.candidateSetSnapshot.tieBreakPolicy,
        'score_desc_food_id_asc',
      );
    },
  );

  test(
    'projected food override is bound to the returned candidate snapshot',
    () async {
      final projectedReplacement = food('food_low', 'projected low protein', 4);
      final callerReplacement = food('food_low', 'caller low protein', 12);
      final orchestrator = NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: _FakeProjectionService(<FoodItem>[
          projectedReplacement,
        ]),
        localAiAdapter: null,
      );
      final result = await orchestrator.recommend(
        request: request(),
        candidateFoods: <FoodItem>[callerReplacement, candidates.last],
      );

      expect(result.candidateSetSnapshot.callerCandidateCount, 2);
      expect(result.candidateSetSnapshot.projectedCandidateCount, 1);
      expect(result.candidateSetSnapshot.mergedCandidateCount, 2);
      expect(result.candidateSetSnapshot.orderedCandidateIds, <String>[
        'food_low',
        'food_high',
      ]);
      expect(
        result.candidateSetSnapshot.mergedCandidateRecords.singleWhere(
          (record) => record['id'] == 'food_low',
        )['name'],
        'projected low protein',
      );
      expect(
        result.candidateSetSnapshot.toJson()['projected_override_ids'],
        <String>['food_low'],
      );
      expect(
        (result.candidateSetSnapshot.toJson()['projection_query_audit']
            as Map<String, Object?>)['schema_id'],
        'test.synthetic-projection-query-audit/1',
      );
    },
  );

  test(
    'ledger authorization rejection blocks all numerical model output',
    () async {
      final now = DateTime.utc(2026, 1, 1, 8);
      final orchestrator = NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: _FakeProjectionService(const []),
        localAiAdapter: null,
        ledgerAuthorizer: const _RejectingLedgerAuthorizer(),
      );
      final result = await orchestrator.recommend(
        request: request(
          history: [
            Meal(
              id: 'authorization_history',
              eatenAt: now.subtract(const Duration(hours: 1)),
              title: 'Authorization fixture',
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
        result.mechanisticTrace!.availability,
        MechanisticResultAvailability.blockedIntegrity,
      );
      expect(result.mechanisticCandidateScores, isNull);
      expect(
        result.rankerEligibility!.fallbackReasons,
        contains('authorization.test_rejection'),
      );
    },
  );

  test(
    'replay reconstruction failure blocks all numerical model output',
    () async {
      final now = DateTime.utc(2026, 1, 1, 8);
      final orchestrator = NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: _FakeProjectionService(const []),
        localAiAdapter: null,
        replayRoundTripper: const _RejectingReplayRoundTripper(),
      );
      final result = await orchestrator.recommend(
        request: request(
          history: [
            Meal(
              id: 'replay_history',
              eatenAt: now.subtract(const Duration(hours: 1)),
              title: 'Replay fixture',
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
        result.mechanisticTrace!.availability,
        MechanisticResultAvailability.blockedIntegrity,
      );
      expect(result.mechanisticCandidateScores, isNull);
      expect(
        result.rankerEligibility!.fallbackReasons,
        contains('authorization.replay_pipeline_failed:StateError'),
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
    'unconfirmed legacy dose remains visible but cannot enter model',
    () async {
      final now = DateTime.utc(2026, 1, 1, 8);
      final confirmedRequest = request(
        window: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      );
      final unconfirmed = NextMealRecommendationRequest(
        userProfile: confirmedRequest.userProfile,
        history: confirmedRequest.history,
        activeDrugs: confirmedRequest.activeDrugs,
        intakes: [
          confirmedRequest.intakes.single.withoutDoseConfirmation(
            clearStructuredDose: true,
          ),
        ],
        now: confirmedRequest.now,
        userDefinedWindow: confirmedRequest.userDefinedWindow,
      );
      final result = await buildOrchestrator().recommend(
        request: unconfirmed,
        candidateFoods: candidates,
      );
      expect(
        result.mechanisticCandidateScores!.every(
          (score) => !score.hasModeledOutput,
        ),
        isTrue,
      );
      expect(
        result.rankerEligibility!.fallbackReasons,
        contains('insufficient_candidate_context'),
      );
    },
  );

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
            takenAt: now.subtract(const Duration(minutes: 30)),
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
            genericName: 'carbidopa/levodopa',
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
            genericName: 'carbidopa/levodopa',
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
            genericName: 'carbidopa/levodopa',
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
            genericName: 'carbidopa/levodopa',
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

class _RejectingLedgerAuthorizer implements MechanisticLedgerAuthorizer {
  const _RejectingLedgerAuthorizer();

  @override
  MechanisticLedgerAuthorizationDecision authorize({
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String expectedConfigurationSha256,
  }) => MechanisticLedgerAuthorizationDecision(
    assessment: MechanisticLedgerAuthorizationAssessment(
      ledger: ledger,
      expectedConfigurationSha256: expectedConfigurationSha256,
      recomputedInputBindingSha256: MechanisticLedgerInputBinding.compute(
        context: context,
        mealCompositionsById: mealCompositionsById,
      ),
      inputMedicationEventCount: context.medicationEvents.length,
      inputMealEventCount: context.mealEvents.length,
      inputFoodComponentEventCount: context.foodComponentEvents.length,
      boundCompositionCount: mealCompositionsById.length,
      findings: const ['authorization.test_rejection'],
    ),
    view: null,
  );
}

class _RejectingReplayRoundTripper
    implements MechanisticReplayCapsuleRoundTripper {
  const _RejectingReplayRoundTripper();

  @override
  MechanisticReplayRoundTrip captureAndRestore({
    required String capsuleId,
    required DateTime generatedAtUtc,
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String expectedConfigurationSha256,
  }) => throw StateError('synthetic replay failure');
}

class _FakeProjectionService extends CdssCatalogProjectionService {
  _FakeProjectionService(this._foods) : super(database: const _StubDb());
  final List<FoodItem> _foods;

  @override
  Future<List<FoodItem>> projectFoods() async => _foods;

  @override
  Future<CdssFoodProjectionResult> projectFoodsWithAudit() async =>
      CdssFoodProjectionResult(
        foods: _foods,
        queryAudit: const <String, Object?>{
          'schema_id': 'test.synthetic-projection-query-audit/1',
          'capture_status': 'synthetic_fixture',
        },
      );

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
