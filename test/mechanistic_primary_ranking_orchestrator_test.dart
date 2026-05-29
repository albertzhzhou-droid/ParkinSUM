import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';

/// Guards #6 end-to-end: when every mechanistic eligibility condition is true,
/// the legacy heuristic does NOT silently set the final order — the order
/// follows the mechanistic candidate scores and `rankerUsed ==
/// mechanistic_primary`. When a condition fails, it flips to
/// `heuristic_legacy_fallback` with explicit fallback reasons.
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

  NextMealRecommendationRequest request({UserDefinedMealWindow? window}) {
    final now = DateTime.utc(2026, 1, 1, 8);
    return NextMealRecommendationRequest(
      userProfile: UserProfile.defaults().copyWith(
          registrationRegion: 'US', contentJurisdictionOverride: const ['US']),
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
      userDefinedWindow: window,
    );
  }

  NextMealRecommendationOrchestrator buildOrchestrator() =>
      NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: _FakeProjectionService(const []),
        localAiAdapter: null,
      );

  test('eligible → mechanistic_primary and order follows mechanistic scores',
      () async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final result = await buildOrchestrator().recommend(
      request: request(
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

    expect(result.rankerEligibility, isNotNull);
    expect(result.rankerEligibility!.rankerUsed, 'mechanistic_primary');
    expect(result.rankerEligibility!.mechanisticPrimaryEligible, isTrue);
    expect(result.rankerEligibility!.fallbackReasons, isEmpty);

    // Final recommendation order must be consistent with the mechanistic
    // finalCandidateScore (legacy heuristic did not override it): for any two
    // recommendations that were scored, the earlier one scores >= the later.
    final scoreById = {
      for (final s in result.mechanisticCandidateScores ?? [])
        s.candidateFoodId: s.finalCandidateScore,
    };
    final ordered = result.recommendations
        .where((r) => scoreById.containsKey(r.food.id))
        .toList();
    for (var i = 1; i < ordered.length; i++) {
      expect(scoreById[ordered[i - 1].food.id]!,
          greaterThanOrEqualTo(scoreById[ordered[i].food.id]!));
    }
  });

  test('missing user window → heuristic_legacy_fallback with reason', () async {
    final result = await buildOrchestrator().recommend(
      request: request(window: null),
      candidateFoods: candidates,
    );
    expect(result.rankerEligibility!.rankerUsed, 'heuristic_legacy_fallback');
    expect(result.rankerEligibility!.mechanisticPrimaryEligible, isFalse);
    expect(result.rankerEligibility!.fallbackReasons,
        contains('missing_user_defined_window'));
  });
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
