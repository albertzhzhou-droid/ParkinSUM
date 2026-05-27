import '../../domain/entities/mechanistic_conflict_result.dart';
import '../../domain/entities/meal_composition.dart';
import '../../domain/entities/time_axis_events.dart';
import '../../domain/usecases/medication_entry_validator.dart';
import '../../domain/usecases/mechanistic_next_meal_scorer.dart';

/// Expected output type for replay assertions.
enum ScenarioExpectedOutputType {
  educationalInfo,
  educationalCaution,
  insufficientContext,
  noModeledInteraction,
}

/// One synthetic scenario for replay. All inputs are synthetic; no real
/// patient data.
class MechanisticReplayScenario {
  final String scenarioId;
  final String title;
  final ScenarioExpectedOutputType expectedOutputType;
  final SeverityBand? expectedSeverityFloor;
  final SeverityBand? expectedSeverityCeiling;
  final ConfidenceBand? expectedConfidenceCeiling;
  final bool expectInsufficientContext;
  final bool expectNonEmptyRecommendations;
  final List<RawMedicationEntry> medicationEntries;
  final List<MinutesOffset> medicationMinutesOffsets;
  final List<ScenarioMeal> meals;
  final UserDefinedMealWindow? userDefinedWindow;
  final List<CandidateFood> candidateFoods;
  final String notes;

  const MechanisticReplayScenario({
    required this.scenarioId,
    required this.title,
    required this.expectedOutputType,
    this.expectedSeverityFloor,
    this.expectedSeverityCeiling,
    this.expectedConfidenceCeiling,
    this.expectInsufficientContext = false,
    this.expectNonEmptyRecommendations = false,
    required this.medicationEntries,
    required this.medicationMinutesOffsets,
    required this.meals,
    this.userDefinedWindow,
    this.candidateFoods = const [],
    this.notes = '',
  });
}

/// Offset (in minutes) from the scenario reference time at which a
/// medication or meal occurs.
class MinutesOffset {
  final int minutes;
  const MinutesOffset(this.minutes);
}

class ScenarioMeal {
  final String id;
  final MinutesOffset offset;
  final MealPhysicalForm physicalForm;
  final List<FoodComponent> components;

  const ScenarioMeal({
    required this.id,
    required this.offset,
    required this.physicalForm,
    required this.components,
  });
}

/// Reusable synthetic medication entries.
const _carbidopaLevodopaIr = RawMedicationEntry(
  activeIngredients: ['carbidopa', 'levodopa'],
  drugProductVariant: 'synthetic:carbidopa-levodopa-25-100-ir-tablet',
  strength: 100,
  unit: 'mg',
  form: 'tablet',
  route: 'oral',
  releaseType: 'immediate',
  jurisdiction: 'US',
  sourceDocId: 'synthetic:demo_label_carbidopa_levodopa',
  labelSection: 'dosage_and_administration',
  extractionConfidence: 0.95,
);

const _bareNumeric = RawMedicationEntry(freeText: '100');
const _levodopa100NoUnit = RawMedicationEntry(freeText: 'levodopa 100');
const _slashedNoUnit = RawMedicationEntry(freeText: '25/100');

const FoodComponent _oatmealSolidSmall = FoodComponent(
  id: 'food.oatmeal.synth',
  name: 'oatmeal (synthetic demo)',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 5,
  fatGrams: 3,
  fiberGrams: 4,
  carbohydrateGrams: 27,
  calories: 158,
  portionGrams: 200,
  sourceDocId: 'synthetic:demo_food',
);

const FoodComponent _chickenSteakProtein = FoodComponent(
  id: 'food.chicken.synth',
  name: 'chicken breast (synthetic demo)',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 35,
  fatGrams: 8,
  fiberGrams: 0,
  carbohydrateGrams: 0,
  calories: 220,
  portionGrams: 150,
  sourceDocId: 'synthetic:demo_food',
);

const FoodComponent _avocadoFatComponent = FoodComponent(
  id: 'food.avocado.synth',
  name: 'avocado (synthetic demo)',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 2,
  fatGrams: 22,
  fiberGrams: 7,
  carbohydrateGrams: 12,
  calories: 240,
  portionGrams: 150,
  sourceDocId: 'synthetic:demo_food',
);

const FoodComponent _waterLiquid = FoodComponent(
  id: 'food.water.synth',
  name: 'water (synthetic demo)',
  physicalForm: MealPhysicalForm.liquid,
  proteinGrams: 0,
  fatGrams: 0,
  fiberGrams: 0,
  carbohydrateGrams: 0,
  calories: 0,
  portionGrams: 250,
  sourceDocId: 'synthetic:demo_food',
);

const FoodComponent _smoothieLiquidProtein = FoodComponent(
  id: 'food.smoothie.synth',
  name: 'protein smoothie (synthetic demo)',
  physicalForm: MealPhysicalForm.liquid,
  proteinGrams: 18,
  fatGrams: 3,
  fiberGrams: 2,
  carbohydrateGrams: 30,
  calories: 230,
  portionGrams: 300,
  sourceDocId: 'synthetic:demo_food',
);

/// Synthetic candidate foods for the next-meal scoring scenarios.
const _candidateBanana = CandidateFood(
  id: 'cand.banana',
  name: 'banana (synthetic demo)',
  regionalFoodLibraryRef: 'synthetic:demo_food_library',
  declaredPhysicalForm: MealPhysicalForm.solid,
  components: [
    FoodComponent(
      id: 'food.banana.synth',
      name: 'banana',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 1,
      fatGrams: 0,
      fiberGrams: 3,
      carbohydrateGrams: 27,
      calories: 105,
      portionGrams: 120,
      sourceDocId: 'synthetic:demo_food',
    ),
  ],
);

const _candidateProteinShake = CandidateFood(
  id: 'cand.protein_shake',
  name: 'protein shake (synthetic demo)',
  regionalFoodLibraryRef: 'synthetic:demo_food_library',
  declaredPhysicalForm: MealPhysicalForm.liquid,
  components: [_smoothieLiquidProtein],
);

const _candidateRiceCake = CandidateFood(
  id: 'cand.rice_cake',
  name: 'rice cake (synthetic demo)',
  regionalFoodLibraryRef: 'synthetic:demo_food_library',
  declaredPhysicalForm: MealPhysicalForm.solid,
  components: [
    FoodComponent(
      id: 'food.rice_cake.synth',
      name: 'rice cake',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 1,
      fatGrams: 0,
      fiberGrams: 0,
      carbohydrateGrams: 9,
      calories: 35,
      portionGrams: 12,
      sourceDocId: 'synthetic:demo_food',
    ),
  ],
);

const _candidateMissingNutrients = CandidateFood(
  id: 'cand.unknown_nutrients',
  name: 'unknown nutrient candidate (synthetic demo)',
  regionalFoodLibraryRef: 'synthetic:demo_food_library',
  declaredPhysicalForm: MealPhysicalForm.unknown,
  components: [
    FoodComponent(
      id: 'food.unknown.synth',
      name: 'unknown',
      physicalForm: MealPhysicalForm.unknown,
      proteinGrams: null,
      fatGrams: null,
      fiberGrams: null,
      carbohydrateGrams: null,
      calories: null,
      portionGrams: null,
      sourceDocId: 'synthetic:demo_food',
    ),
  ],
);

/// The default replay scenario suite (covers all 14 acceptance scenarios).
const List<MechanisticReplayScenario> mechanisticReplayScenarios = [
  MechanisticReplayScenario(
    scenarioId: 's01_low_protein_far',
    title:
        'Valid catalog-backed levodopa context + small low-protein meal far from medication',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectedSeverityCeiling: SeverityBand.low,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(240)],
    meals: [
      ScenarioMeal(
        id: 'meal_oats',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_oatmealSolidSmall],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's02_high_protein_close',
    title:
        'Valid catalog-backed levodopa context + high-protein solid meal close to medication',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    expectedSeverityFloor: SeverityBand.moderate,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_chicken',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_chickenSteakProtein],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's03_high_fat_before',
    title:
        'Valid catalog-backed levodopa context + high-fat mixed meal before medication',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(45)],
    meals: [
      ScenarioMeal(
        id: 'meal_avocado_toast',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.mixed,
        components: [_avocadoFatComponent, _oatmealSolidSmall],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's04_overlapping_meals',
    title: 'Valid catalog-backed levodopa context + overlapping meals',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(75)],
    meals: [
      ScenarioMeal(
        id: 'meal_early',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_oatmealSolidSmall],
      ),
      ScenarioMeal(
        id: 'meal_overlap',
        offset: MinutesOffset(45),
        physicalForm: MealPhysicalForm.solid,
        components: [_chickenSteakProtein],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's05_liquid_meal',
    title: 'Liquid-only meal scenario',
    // Pure water (no protein, no fat) yields no modeled interaction —
    // educational simulation correctly reports "nothing to flag".
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(15)],
    meals: [
      ScenarioMeal(
        id: 'meal_water',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.liquid,
        components: [_waterLiquid],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's06_missing_protein',
    title: 'Missing meal protein data',
    expectedOutputType: ScenarioExpectedOutputType.educationalInfo,
    expectedConfidenceCeiling: ConfidenceBand.low,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_partial',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [
          FoodComponent(
            id: 'food.unknown_protein',
            name: 'partial meal (synthetic demo)',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: null,
            fatGrams: 5,
            fiberGrams: 2,
            carbohydrateGrams: 30,
            calories: 200,
            portionGrams: 200,
            sourceDocId: 'synthetic:demo_food',
          ),
        ],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's07_missing_meal_time',
    title: 'Missing meal start time',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(60)],
    meals: [], // empty — simulates meal-time missing
    notes: 'Time-axis layer omits the meal because no start minute was given.',
  ),
  MechanisticReplayScenario(
    scenarioId: 's08_bare_numeric',
    title: 'Invalid unitless medication entry "100"',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    medicationEntries: [_bareNumeric],
    medicationMinutesOffsets: [MinutesOffset(0)],
    meals: [],
  ),
  MechanisticReplayScenario(
    scenarioId: 's09_levodopa_no_unit',
    title: '"levodopa 100" without unit',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    medicationEntries: [_levodopa100NoUnit],
    medicationMinutesOffsets: [MinutesOffset(0)],
    meals: [],
  ),
  MechanisticReplayScenario(
    scenarioId: 's10_slashed_no_unit',
    title: '"25/100" without catalog normalization',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    medicationEntries: [_slashedNoUnit],
    medicationMinutesOffsets: [MinutesOffset(0)],
    meals: [],
  ),
  MechanisticReplayScenario(
    scenarioId: 's11_mixed_solid_liquid',
    title: 'Mixed meal with liquid + solid components',
    expectedOutputType: ScenarioExpectedOutputType.educationalInfo,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(20)],
    meals: [
      ScenarioMeal(
        id: 'meal_mixed',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.mixed,
        components: [_oatmealSolidSmall, _waterLiquid],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's12_high_fat_plus_protein',
    title: 'High-fat component + protein component in the same meal',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_fat_protein',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.mixed,
        components: [_avocadoFatComponent, _chickenSteakProtein],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's13_user_window_candidates',
    title: 'User-defined next-meal window with several candidates',
    // Medication and earlier meal are far in the past so the BASE state is
    // clean; the recommender's job is to rank candidates inside the user
    // window.
    expectedOutputType: ScenarioExpectedOutputType.educationalInfo,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-240)],
    meals: [
      ScenarioMeal(
        id: 'meal_breakfast',
        offset: MinutesOffset(-300),
        physicalForm: MealPhysicalForm.solid,
        components: [_oatmealSolidSmall],
      ),
    ],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 60, endMinute: 120),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [
      _candidateBanana,
      _candidateProteinShake,
      _candidateRiceCake,
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's14_user_window_missing_nutrients',
    title:
        'Next-meal recommendation with missing nutrient values and high uncertainty',
    expectedOutputType: ScenarioExpectedOutputType.educationalInfo,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-240)],
    meals: [
      ScenarioMeal(
        id: 'meal_breakfast',
        offset: MinutesOffset(-300),
        physicalForm: MealPhysicalForm.solid,
        components: [_oatmealSolidSmall],
      ),
    ],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 60, endMinute: 120),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [
      _candidateBanana,
      _candidateMissingNutrients,
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's15_multi_point_window_variation',
    title:
        'User-defined window that straddles the levodopa absorption window — '
        'multi-point sampling should produce varying overlap across the window',
    // Base context has no prior meal, so the engine reports
    // `noModeledInteraction`; the multi-point sampling happens against the
    // candidates' hypothetical meal events placed inside the user window.
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-15)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: -10, endMinute: 110),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [
      _candidateBanana,
      _candidateProteinShake,
      _candidateRiceCake,
    ],
  ),
];
