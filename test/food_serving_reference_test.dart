import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/food_serving_reference_amounts.dart';
import 'package:parkinsum_companion/core/constants/food_serving_reference_assignments.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/reference_food_catalog.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/data/datasources/remote/regional_seed_catalog_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/seed_catalog_importer.dart';
import 'package:parkinsum_companion/domain/entities/food_serving_reference.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/food_serving_reference_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/features/shared/candidate_serving_macro_line.dart';

/// Next-meal candidates are evaluated per reference serving: a source
/// portion, a documented category reference amount, or — when neither
/// exists — labelled per 100 g. Educational prototype; catalog values are
/// public reference data and every timeline is synthetic.
void main() {
  final catalog = <String, FoodItem>{
    for (final food in [
      ...buildP0FoodCatalog(),
      ...buildReferenceFoodCatalog(),
      ...const SeedCatalogImporter().importSeedCatalog().projectedFoods,
      ...const RegionalSeedCatalogImporter()
          .importRegionalSeedCatalog()
          .projectedFoods,
    ])
      food.id: food,
  };
  FoodItem catalogFood(String id) => catalog[id]!;
  final normalizer = MealCompositionNormalizer();

  FoodPortionEvidence portion({
    required String modifier,
    required double gramWeight,
    double amount = 1,
    String sourceFoodId = '999001',
    int? sequenceNumber,
  }) => FoodPortionEvidence(
    sourceDocId: 'synthetic:portion_fixture',
    sourceFoodId: sourceFoodId,
    recordLocator: 'synthetic:$modifier',
    sequenceNumber: sequenceNumber,
    amount: amount,
    measureUnitId: 9999,
    measureUnitName: null,
    measureUnitAbbreviation: null,
    portionDescription: null,
    modifier: modifier,
    gramWeight: gramWeight,
    dataPoints: null,
    footnote: null,
    minYearAcquired: null,
    sourceFields: const {},
  );

  FoodItem syntheticFood({
    String id = 'synthetic_unassigned_food',
    double protein = 20,
    Set<String> missing = const {},
    List<FoodPortionEvidence> portions = const [],
    String sourceFoodCode = '999001',
    String? basisType,
  }) => FoodItem(
    id: id,
    name: 'synthetic food',
    category: FoodCategory.protein,
    sourceSystem: 'USDA_FDC',
    sourceFoodCode: sourceFoodCode,
    jurisdiction: 'US',
    proteinG: protein,
    carbsG: 10,
    fatG: 4,
    fiberG: 2,
    sodiumMg: 50,
    energyKcal: 160,
    missingNutrientFields: missing,
    foodPortionEvidence: portions,
    basisType: basisType,
  );

  group('reference serving per catalog food', () {
    test('milk is evaluated per 1 cup source portion, not per 100 g', () {
      final milk = catalogFood('food_ref_usda_171267'); // 2 % milk
      final serving = foodServingReferenceFor(milk);
      expect(serving.basis, FoodServingBasis.sourcePortion);
      expect(serving.grams, 244);
      expect(serving.portionLabel, '1 cup');
      expect(serving.ruleId, FoodServingRuleIds.closestHouseholdPortion);
      expect(serving.referenceCategoryId, 'milk_and_milk_substitutes');

      final component = foodItemToCandidateFood(milk).components.single;
      expect(component.portionGrams, 244);
      expect(component.portionBasis, FoodComponent.sourcePortionBasis);
      expect(component.proteinGrams, closeTo(3.3 * 2.44, 1e-9));
      expect(component.proteinGrams, closeTo(8.05, 0.01));
      expect(component.calories, closeTo(milk.energyKcal! * 2.44, 1e-9));
      expect(component.fatGrams, closeTo(milk.fatG * 2.44, 1e-9));
      final profile = component.aminoAcidProfile!;
      expect(profile.basis, 'per_serving');
      expect(
        profile.leucine,
        closeTo(milk.aminoAcidProfile!.leucine! * 2.44, 1e-12),
      );
    });

    test('roasted chicken breast takes the portion nearest 85 g (FSIS)', () {
      final chicken = catalogFood('food_ref_usda_171477');
      final serving = foodServingReferenceFor(chicken);
      expect(serving.basis, FoodServingBasis.sourcePortion);
      expect(serving.grams, 86);
      expect(serving.portionLabel, '0.5 breast, bone and skin removed');
      expect(
        foodItemToCandidateFood(chicken).components.single.proteinGrams,
        closeTo(31.02 * 0.86, 1e-9),
      );
    });

    test('cooked white rice is evaluated per 1 cup (158 g)', () {
      final rice = catalogFood('food_ref_usda_169757');
      final serving = foodServingReferenceFor(rice);
      expect(serving.basis, FoodServingBasis.sourcePortion);
      expect(serving.grams, 158);
      expect(
        foodItemToCandidateFood(rice).components.single.proteinGrams,
        closeTo(2.69 * 1.58, 1e-9),
      );
      final seedRice = foodServingReferenceFor(catalogFood('seed_white_rice'));
      expect(seedRice.basis, FoodServingBasis.sourcePortion);
      expect(seedRice.grams, 158);
    });

    test('an NLEA serving takes precedence over the closest portion', () {
      final apple = foodServingReferenceFor(
        catalogFood('food_ref_usda_171688'),
      );
      expect(apple.basis, FoodServingBasis.sourcePortion);
      expect(apple.ruleId, FoodServingRuleIds.nleaServing);
      expect(apple.grams, 242);
    });

    test('a CIQUAL food without portions uses its category amount', () {
      final cheddar = catalogFood('food_cheddar_cheese');
      final serving = foodServingReferenceFor(cheddar);
      expect(serving.basis, FoodServingBasis.categoryDefault);
      expect(serving.grams, 30);
      expect(serving.referenceCategoryId, 'cheese_all_others');
      final component = foodItemToCandidateFood(cheddar).components.single;
      expect(component.portionBasis, FoodComponent.categoryDefaultPortionBasis);
      expect(component.portionGrams, 30);
      expect(component.proteinGrams, closeTo(24.0 * 0.30, 1e-9));
      // CIQUAL seed carries no energy: still missing, never scaled to 0.
      expect(component.calories, isNull);
    });

    test('a volume category amount never becomes grams without a source '
        'measure', () {
      final milk = foodServingReferenceFor(catalogFood('food_milk'));
      expect(milk.basis, FoodServingBasis.none);
      expect(
        milk.reason,
        FoodServingNoneReasons.volumeReferenceWithoutSourceMeasure,
      );
      expect(milk.referenceCategoryId, 'milk_and_milk_substitutes');
    });
  });

  group('no serving: per 100 g, labelled, with widened uncertainty', () {
    test('a food with no portion evidence and no category stays per 100 g', () {
      final food = syntheticFood();
      final serving = foodServingReferenceFor(food);
      expect(serving.basis, FoodServingBasis.none);
      expect(serving.reason, FoodServingNoneReasons.noReferenceCategory);
      expect(serving.evaluatedGrams, 100);

      final component = foodItemToCandidateFood(food).components.single;
      expect(component.portionGrams, isNull);
      expect(component.portionBasis, FoodComponent.noServingPortionBasis);
      expect(component.proteinGrams, 20);

      final macroLine = candidateServingMacroLine(
        AppI18n.fromLocaleTag('en'),
        food,
      );
      expect(macroLine, startsWith('Per 100 g — serving unknown'));
      expect(macroLine, contains('Protein 20.0 g'));
      expect(
        candidateServingMacroLine(AppI18n.fromLocaleTag('zh'), food),
        startsWith('每 100 g（份量未知）'),
      );
    });

    test('completeness ranks source portion above category default above no '
        'serving', () {
      FoodComponent component(double? grams, String basis) => FoodComponent(
        id: 'c',
        name: 'c',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 10,
        fatGrams: 2,
        fiberGrams: 1,
        carbohydrateGrams: 5,
        calories: 80,
        portionGrams: grams,
        sourceDocId: 'synthetic',
        portionBasis: basis,
      );
      MealComposition normalize(FoodComponent c) =>
          normalizer.normalize(mealId: 'm', components: [c]);

      final source = normalize(component(85, FoodComponent.sourcePortionBasis));
      final assumed = normalize(
        component(85, FoodComponent.categoryDefaultPortionBasis),
      );
      final none = normalize(
        component(null, FoodComponent.noServingPortionBasis),
      );
      expect(source.missingFields, isEmpty);
      expect(source.compositionCompleteness, 1);
      expect(assumed.missingFields, ['portion_grams_assumed']);
      expect(assumed.compositionCompleteness, 7 / 8);
      expect(none.missingFields, containsAll(['portion_grams']));
      expect(none.compositionCompleteness, lessThan(7 / 8));
      // A logged component without a basis keeps its original behaviour.
      final logged = normalizer.normalize(
        mealId: 'm',
        components: [
          FoodComponent(
            id: 'l',
            name: 'l',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 10,
            fatGrams: 2,
            fiberGrams: 1,
            carbohydrateGrams: 5,
            calories: 80,
            portionGrams: 85,
            sourceDocId: 'meal_history',
          ),
        ],
      );
      expect(logged.missingFields, isEmpty);
      expect(
        logged.foodComponents.single.toJson(),
        isNot(contains('portion_basis')),
      );
    });
  });

  group('missing stays missing', () {
    test('missing nutrients stay null when a serving scales the rest', () {
      final food = syntheticFood(
        id: 'food_ref_usda_171477', // assigned: poultry ready-to-serve
        sourceFoodCode: '999001',
        missing: {'proteinG', 'energyKcal'},
        portions: [portion(modifier: '3 oz', gramWeight: 85)],
      );
      final serving = foodServingReferenceFor(food);
      expect(serving.grams, 85);
      final component = foodItemToCandidateFood(food).components.single;
      expect(component.proteinGrams, isNull);
      expect(component.calories, isNull);
      expect(component.fatGrams, closeTo(4 * 0.85, 1e-12));
      expect(
        candidateServingMacroLine(AppI18n.fromLocaleTag('en'), food),
        contains('Protein unknown'),
      );
    });
  });

  group('serving rule', () {
    const resolver = FoodServingReferenceResolver(
      categoryAssignments: {'synthetic_poultry': 'poultry_cuts_ready_to_serve'},
    );

    test('portions outside 50–200 % of the reference fall back to the '
        'category amount', () {
      final food = syntheticFood(
        id: 'synthetic_poultry',
        portions: [
          portion(modifier: 'oz', gramWeight: 28.35), // 33 % of 85 g
          portion(modifier: 'bird', gramWeight: 1700), // 2000 %
          portion(modifier: 'cup', gramWeight: 170), // exactly 200 %
        ],
      );
      final serving = resolver.resolve(food);
      expect(serving.basis, FoodServingBasis.categoryDefault);
      expect(serving.grams, 85);
    });

    test('ties go to the lower source sequence number', () {
      final food = syntheticFood(
        id: 'synthetic_poultry',
        portions: [
          portion(modifier: 'b', gramWeight: 95, sequenceNumber: 2),
          portion(modifier: 'a', gramWeight: 75, sequenceNumber: 1),
        ],
      );
      expect(resolver.resolve(food).grams, 75);
    });

    test('portions of another source record are not used', () {
      final food = syntheticFood(
        id: 'synthetic_poultry',
        sourceFoodCode: '999001',
        portions: [
          portion(modifier: '3 oz', gramWeight: 85, sourceFoodId: '1'),
        ],
      );
      expect(resolver.resolve(food).basis, FoodServingBasis.categoryDefault);
    });

    test('values not per 100 g edible portion are never scaled', () {
      final food = syntheticFood(
        id: 'synthetic_poultry',
        basisType: 'per_100ml_product',
        portions: [portion(modifier: '3 oz', gramWeight: 85)],
      );
      final serving = resolver.resolve(food);
      expect(serving.basis, FoodServingBasis.none);
      expect(
        serving.reason,
        FoodServingNoneReasons.nutrientBasisNotPer100gEdible,
      );
    });

    test('household volumes use the labeling equivalents', () {
      double? ml(String modifier, {double amount = 1}) =>
          FoodServingReferenceResolver.householdVolumeMillilitres(
            portion(modifier: modifier, gramWeight: 1, amount: amount),
          );
      expect(ml('cup'), 240);
      expect(ml('tbsp', amount: 2), 30);
      expect(ml('bottle 8 fl oz'), 240);
      expect(ml('serving 1/2 cup'), 120);
      expect(ml('cup (8 fl oz)'), 240);
      expect(ml('fl oz', amount: 6), 180);
      expect(ml('oz'), isNull);
      expect(ml('slice'), isNull);
    });

    test('every assignment names a table category and a catalog food', () {
      for (final entry in foodServingReferenceCategoryAssignments.entries) {
        expect(
          foodServingReferenceCategoriesById,
          contains(entry.value),
          reason: entry.key,
        );
        expect(catalog, contains(entry.key), reason: 'stale id ${entry.key}');
      }
      final ids = foodServingReferenceCategories.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final category in foodServingReferenceCategories) {
        expect(category.amount, greaterThan(0), reason: category.id);
        expect(category.citation, isNotEmpty, reason: category.id);
      }
    });
  });

  group('legacy ranker compares a serving with meal-sized thresholds', () {
    final levodopa = DrugDefinition(
      id: 'synthetic_levodopa',
      genericName: 'carbidopa/levodopa',
      brandNames: const [],
      tags: const [DrugTag.levodopaLike],
      notes: 'Synthetic fixture.',
    );
    final recommender = GetFoodRecommendationsUseCase();
    Map<String, dynamic> score(FoodItem food) {
      final recommendation = recommender
          .call(
            history: const [],
            drugs: [levodopa],
            allFoods: [food],
            userProfile: UserProfile.defaults(),
          )
          .single;
      return {
        'decision': recommendation.decision,
        'breakdown': recommendation.scoreBreakdown,
        'tags': recommendation.featureSnapshot.riskTags,
      };
    }

    test('boiled soybeans: 18 g per 100 g but 31 g per 1 cup serving', () {
      final soybeans = catalogFood('food_ref_usda_174271');
      expect(soybeans.proteinG, lessThan(20));
      final result = score(soybeans);
      final breakdown = result['breakdown'] as Map<String, double>;
      expect(breakdown['evaluated_amount_g'], 172);
      expect(breakdown['evaluated_protein_g'], closeTo(18.21 * 1.72, 1e-9));
      expect(result['decision'], 'WARN');
      expect(result['tags'], contains('high_protein_candidate'));
    });

    test('cheddar: 24 g per 100 g but 7.2 g per 30 g reference amount', () {
      final result = score(catalogFood('food_cheddar_cheese'));
      final breakdown = result['breakdown'] as Map<String, double>;
      expect(breakdown['evaluated_amount_g'], 30);
      expect(breakdown['evaluated_protein_g'], closeTo(7.2, 1e-9));
      expect(result['decision'], 'ALLOW');
      expect(result['tags'], contains('serving_category_reference_amount'));
    });

    test('a food without a serving is compared per 100 g and tagged', () {
      final whey = catalogFood('food_ref_usda_173180');
      final result = score(whey);
      final breakdown = result['breakdown'] as Map<String, double>;
      expect(breakdown['evaluated_amount_g'], 100);
      expect(breakdown['evaluated_protein_g'], whey.proteinG);
      expect(result['tags'], contains('serving_unknown_per_100g'));
    });
  });

  test('serving copy keeps its non-advice meaning in en and zh', () {
    for (final locale in ['en', 'zh']) {
      final i18n = AppI18n.fromLocaleTag(locale);
      final note = i18n.tr('serving.basis_note');
      expect(note, isNot('serving.basis_note'));
      expect(findBannedSubstrings(note), isEmpty);
      expect(
        note,
        locale == 'en' ? contains('not portion advice') : contains('不是份量建议'),
      );
      for (final key in [
        'serving.macro_line',
        'serving.macro_line_per_100g_unknown',
        'serving.basis.source_portion',
        'serving.basis.category_default',
        'serving.value_unknown',
      ]) {
        expect(
          AppI18n.translationDictionary[locale],
          contains(key),
          reason: '$locale/$key',
        );
      }
    }
    expect(
      candidateServingMacroLine(
        AppI18n.fromLocaleTag('en'),
        catalogFood('food_ref_usda_171267'),
      ),
      'Per serving (≈244 g, source portion): '
      'Protein 8.1 g · Carbs 11.7 g · Fat 4.8 g',
    );
    expect(
      candidateServingMacroLine(
        AppI18n.fromLocaleTag('zh'),
        catalogFood('food_cheddar_cheese'),
      ),
      startsWith('每份（约 30 g，类别参考量）'),
    );
  });

  test(
    'catalog servings stay a trace input: ranking boundary unchanged',
    () async {
      final now = DateTime.utc(2026, 1, 1, 8);
      final drug = DrugDefinition(
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
      final intake = AdministrationDoseConfirmationCoordinator()
          .prepare(
            draft: Intake(
              id: 'intake_1',
              drugId: drug.id,
              takenAt: now.subtract(const Duration(minutes: 30)),
              dosageNote: '100 mg',
            ),
            current: null,
            expectedRecordRevisionDigest:
                administrationDoseConfirmationAbsentRevisionDigest,
            ownerScope: profile.patientId,
            operationId: 'event_op_intake_1',
            confirmationRequested: true,
            assertionSource: AdministrationDoseAssertionSource.typed,
            confirmationAction: 'test.explicit_confirmation',
            uiContractVersion: 'test-dose-confirmation:1',
            confirmedAt: DateTime.utc(2026, 1, 1, 7, 59),
          )
          .intake!;
      final candidates = [
        catalogFood('food_ref_usda_171267'),
        catalogFood('food_ref_usda_171477'),
        catalogFood('food_ref_usda_169757'),
        catalogFood('food_cheddar_cheese'),
      ];
      final history = [
        Meal(
          id: 'history_meal',
          eatenAt: now.subtract(const Duration(hours: 1)),
          title: 'Synthetic history meal',
          items: [MealItem.fromFood(food: candidates[2], quantityFactor: 1)],
        ),
      ];
      NextMealRecommendationRequest request(UserDefinedMealWindow? window) =>
          NextMealRecommendationRequest(
            userProfile: profile,
            history: history,
            activeDrugs: [drug],
            intakes: [intake],
            now: now,
            userConsentedToAi: false,
            userDefinedWindow: window,
          );
      NextMealRecommendationOrchestrator orchestrator() =>
          NextMealRecommendationOrchestrator(
            conservativeRecommender: GetFoodRecommendationsUseCase(),
            projectionService: _EmptyProjectionService(),
            localAiAdapter: null,
          );

      final traced = await orchestrator().recommend(
        request: request(
          UserDefinedMealWindow(
            window: TimelineWindow(
              startMinute: dateTimeToMinute(now) + 60,
              endMinute: dateTimeToMinute(now) + 120,
            ),
            source: 'test',
          ),
        ),
        candidateFoods: candidates,
      );
      final conservative = await orchestrator().recommend(
        request: request(null),
        candidateFoods: candidates,
      );

      expect(traced.rankerEligibility!.mechanisticPrimaryEligible, isFalse);
      expect(
        traced.rankerEligibility!.fallbackReasons,
        contains('mechanistic_trace_only_not_validated_for_ranking'),
      );
      expect(
        traced.recommendations.map((item) => item.food.id),
        conservative.recommendations.map((item) => item.food.id),
      );
      final scores = traced.mechanisticCandidateScores!;
      expect(scores, hasLength(candidates.length));
      final milk = scores.singleWhere(
        (score) => score.candidateFoodId == 'food_ref_usda_171267',
      );
      expect(
        milk.explanation,
        contains(
          'Modeled amount: one source-reported portion of about 244 g; '
          'per-100 g source values were scaled to it.',
        ),
      );
      for (final score in scores) {
        expect(findBannedSubstrings(score.explanation.join(' ')), isEmpty);
      }
    },
  );
}

class _EmptyProjectionService extends CdssCatalogProjectionService {
  _EmptyProjectionService() : super(database: const _StubDb());

  @override
  Future<List<FoodItem>> projectFoods() async => const [];

  @override
  Future<CdssFoodProjectionResult> projectFoodsWithAudit() async =>
      CdssFoodProjectionResult(
        foods: const [],
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
