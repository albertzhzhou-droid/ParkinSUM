import '../../domain/entities/amino_acid_profile.dart';
import '../../domain/entities/mechanistic_conflict_result.dart';
import '../../domain/entities/meal_composition.dart';
import '../../domain/entities/medication_source_metadata.dart';
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

// --- CDSS→mechanistic-context bridge demo metadata (synthetic) -------------
// Section-backed carbidopa/levodopa product provenance bridged into the
// mechanistic context. Provenance only — never a dose. Per-component strength
// is left null for the combination (single product strength only).
const _carbidopaLevodopaComponents = [
  MedicationComponent(
    ingredientName: 'carbidopa',
    role: 'decarboxylase_inhibitor',
    sourceRefs: ['src.dailymed.sinemet.label'],
  ),
  MedicationComponent(
    ingredientName: 'levodopa',
    role: 'active',
    sourceRefs: ['src.dailymed.sinemet.label'],
  ),
];

const _splIrMetadata = MechanisticMedicationMetadata(
  sourceSystem: 'DailyMed',
  sourceDocId: 'synthetic:spl:carbidopa-levodopa-ir',
  sourceDocVersion: 'spl_demo_v1',
  effectiveDate: '2025-01-01',
  jurisdiction: 'US',
  language: 'en',
  drugProductVariantId: 'synthetic:cl-ir',
  doseForm: 'tablet',
  route: 'oral',
  releaseType: 'immediate',
  releaseTypeSource: 'structured_variant_metadata',
  components: _carbidopaLevodopaComponents,
  labelSectionRefs: [
    LabelSectionRef(
      sourceSystem: 'DailyMed',
      sourceDocId: 'synthetic:spl:carbidopa-levodopa-ir',
      sourceDocVersion: 'spl_demo_v1',
      jurisdiction: 'US',
      language: 'en',
      sectionId: 'sec-dosage',
      sectionKey: 'dosage_and_administration',
      sectionTitle: 'Dosage and Administration',
      effectiveDate: '2025-01-01',
      parserName: 'cdss_drug_label_section_record',
      sourceRefs: ['src.dailymed.sinemet.label'],
    ),
  ],
  sourceRefs: ['src.dailymed.sinemet.label'],
  limitationText: 'Synthetic SPL-style demo metadata. Educational only.',
  metadataCompleteness: 'complete',
);

const _splErMetadata = MechanisticMedicationMetadata(
  sourceSystem: 'DailyMed',
  sourceDocId: 'synthetic:spl:carbidopa-levodopa-er',
  sourceDocVersion: 'spl_demo_v1',
  effectiveDate: '2025-01-01',
  jurisdiction: 'US',
  language: 'en',
  drugProductVariantId: 'synthetic:cl-er',
  doseForm: 'extended-release tablet',
  route: 'oral',
  releaseType: 'extended',
  releaseTypeSource: 'structured_variant_metadata',
  components: _carbidopaLevodopaComponents,
  labelSectionRefs: [
    LabelSectionRef(
      sourceSystem: 'DailyMed',
      sourceDocId: 'synthetic:spl:carbidopa-levodopa-er',
      sourceDocVersion: 'spl_demo_v1',
      jurisdiction: 'US',
      language: 'en',
      sectionId: 'sec-dosage-er',
      sectionKey: 'dosage_and_administration',
      sectionTitle: 'Dosage and Administration (Extended Release)',
      effectiveDate: '2025-01-01',
      parserName: 'cdss_drug_label_section_record',
      sourceRefs: ['src.dailymed.sinemet.extended.label'],
    ),
  ],
  sourceRefs: ['src.dailymed.sinemet.extended.label'],
  limitationText: 'Synthetic SPL-style demo metadata. Educational only.',
  metadataCompleteness: 'complete',
);

/// IR carbidopa/levodopa with structured product metadata + section refs.
/// User-entered dose (strength+unit) stays the only dose source.
const _carbidopaLevodopaIrWithMetadata = RawMedicationEntry(
  activeIngredients: ['carbidopa', 'levodopa'],
  drugProductVariant: 'synthetic:carbidopa-levodopa-25-100-ir-tablet',
  strength: 100,
  unit: 'mg',
  form: 'tablet',
  route: 'oral',
  releaseType: 'immediate',
  jurisdiction: 'US',
  sourceDocId: 'synthetic:spl:carbidopa-levodopa-ir',
  labelSection: 'dosage_and_administration',
  extractionConfidence: 0.95,
  medicationMetadata: _splIrMetadata,
);

const _carbidopaLevodopaErWithMetadata = RawMedicationEntry(
  activeIngredients: ['carbidopa', 'levodopa'],
  drugProductVariant: 'synthetic:carbidopa-levodopa-50-200-er-tablet',
  strength: 200,
  unit: 'mg',
  form: 'extended-release tablet',
  route: 'oral',
  releaseType: 'extended',
  jurisdiction: 'US',
  sourceDocId: 'synthetic:spl:carbidopa-levodopa-er',
  labelSection: 'dosage_and_administration',
  extractionConfidence: 0.95,
  medicationMetadata: _splErMetadata,
);

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

/// Candidate carrying actual amino-acid fields (FDC-style), so the LNAA
/// layer uses `actualAminoAcidFields` mode rather than the protein-source
/// proxy.
const _candidateAminoAcidFood = CandidateFood(
  id: 'cand.amino_acid_food',
  name: 'amino-acid-profiled food (synthetic demo)',
  regionalFoodLibraryRef: 'synthetic:usda_fdc_demo',
  declaredPhysicalForm: MealPhysicalForm.solid,
  components: [
    FoodComponent(
      id: 'food.aa.synth',
      name: 'high-protein food with amino-acid fields',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 26,
      fatGrams: 5,
      fiberGrams: 0,
      carbohydrateGrams: 0,
      calories: 200,
      portionGrams: 150,
      sourceDocId: 'synthetic:usda_fdc_demo',
      aminoAcidProfile: AminoAcidProfile(
        leucine: 2.1,
        isoleucine: 1.2,
        valine: 1.3,
        phenylalanine: 1.0,
        tyrosine: 0.9,
        tryptophan: 0.3,
        // Verified FDC nutrient numbers, in field order:
        // 504 leucine, 503 isoleucine, 510 valine, 508 phenylalanine,
        // 509 tyrosine, 501 tryptophan.
        nutrientIds: ['504', '503', '510', '508', '509', '501'],
        sourceRefs: ['src.fdc.api.amino_acid_fields'],
      ),
    ),
  ],
);

/// Candidate carrying a PARTIAL amino-acid profile (only some of the six
/// competing LNAA present). The LNAA layer must mark it partial and widen
/// uncertainty rather than treating it as fully narrow.
const _candidatePartialAminoAcidFood = CandidateFood(
  id: 'cand.partial_amino_acid_food',
  name: 'partial amino-acid food (synthetic demo)',
  regionalFoodLibraryRef: 'synthetic:usda_fdc_demo',
  declaredPhysicalForm: MealPhysicalForm.solid,
  components: [
    FoodComponent(
      id: 'food.partial_aa.synth',
      name: 'food with partial amino-acid fields',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 24,
      fatGrams: 4,
      fiberGrams: 0,
      carbohydrateGrams: 0,
      calories: 190,
      portionGrams: 150,
      sourceDocId: 'synthetic:usda_fdc_demo',
      aminoAcidProfile: AminoAcidProfile(
        // Only 3 of the 6 competing LNAA present → partial.
        leucine: 2.0,
        valine: 1.2,
        tryptophan: 0.3,
        nutrientIds: ['504', '510', '501'],
        sourceRefs: ['src.fdc.api.amino_acid_fields'],
      ),
    ),
  ],
);

/// High-calorie, high-fat solid meal component for the gastric-uncertainty
/// scenario (≥ 1.5× the reference meal calories → high-calorie widening).
const _bigHighCalorieMeal = FoodComponent(
  id: 'food.big_meal.synth',
  name: 'large mixed plate (synthetic demo)',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 30,
  fatGrams: 35,
  fiberGrams: 4,
  carbohydrateGrams: 90,
  calories: 800,
  portionGrams: 600,
  sourceDocId: 'synthetic:demo_food',
);

/// Meal component carrying actual amino-acid fields, for the dose-relative
/// LNAA scenario (meal history path, not a candidate).
const _aminoAcidMealComponent = FoodComponent(
  id: 'food.aa_meal.synth',
  name: 'amino-acid-profiled meal (synthetic demo)',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 26,
  fatGrams: 5,
  fiberGrams: 0,
  carbohydrateGrams: 0,
  calories: 200,
  portionGrams: 150,
  sourceDocId: 'synthetic:usda_fdc_demo',
  aminoAcidProfile: AminoAcidProfile(
    leucine: 2.1,
    isoleucine: 1.2,
    valine: 1.3,
    phenylalanine: 1.0,
    tyrosine: 0.9,
    tryptophan: 0.3,
    basis: 'per_serving',
    nutrientIds: ['504', '503', '510', '508', '509', '501'],
    sourceRefs: ['src.fdc.api.amino_acid_fields'],
    // FDC Foundation-food provenance (analytical) — surfaces the confidence
    // tier in the replay report without widening uncertainty (B1).
    fdcDataType: 'Foundation',
    derivations: {
      'leucine': NutrientDerivation(
          derivationCode: 'A',
          derivationDescription: 'Analytical',
          dataPoints: 12),
      'valine': NutrientDerivation(
          derivationCode: 'A',
          derivationDescription: 'Analytical',
          dataPoints: 12),
    },
  ),
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
    scenarioId: 's04b_multidose_ir',
    title: 'Two IR levodopa doses; the dose overlapping the high-protein meal '
        'drives the score (max-overlap, not averaged)',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    expectedSeverityFloor: SeverityBand.moderate,
    // First dose lands on the high-protein meal (high overlap); second dose is
    // hours later with no nearby meal (low overlap). Max-overlap aggregation
    // must keep severity driven by the first dose.
    medicationEntries: [_carbidopaLevodopaIr, _carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30), MinutesOffset(360)],
    meals: [
      ScenarioMeal(
        id: 'meal_chicken_md',
        offset: MinutesOffset(0),
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
  // --- Protein-redistribution + multi-source coverage (s16–s21) ---------
  MechanisticReplayScenario(
    scenarioId: 's16_daytime_high_overlap_high_protein',
    title: 'Daytime high-overlap window + high-protein candidate → overlap '
        'penalty (NOT a "protein is bad" penalty)',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(0)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 0, endMinute: 90),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateProteinShake, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's17_evening_low_overlap_high_protein',
    title: 'Evening low-overlap window + high-protein candidate → not globally '
        'penalized',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-300)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 240, endMinute: 360),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateProteinShake, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's18_zero_vs_moderate_protein_low_overlap',
    title: 'Zero-protein vs moderate-protein in a low-overlap window → '
        'zero-protein does not automatically win',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-300)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 240, endMinute: 360),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateRiceCake, _candidateProteinShake],
  ),
  MechanisticReplayScenario(
    scenarioId: 's19_missing_protein_unknown_competition',
    title: 'Candidate missing protein → unknown amino-acid competition',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-240)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 60, endMinute: 120),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateMissingNutrients, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's20_invalid_medication_no_window_scoring',
    title:
        'Invalid medication context → candidate scoring returns insufficient '
        'context (no pretended optimization)',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_bareNumeric],
    medicationMinutesOffsets: [MinutesOffset(-30)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 60, endMinute: 120),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateBanana, _candidateProteinShake],
  ),
  MechanisticReplayScenario(
    scenarioId: 's21_no_user_window_mechanistic_primary_unavailable',
    title:
        'No user-defined window → mechanistic-primary unavailable; candidates '
        'return insufficient context with a visible reason',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-30)],
    meals: [],
    candidateFoods: [_candidateBanana, _candidateProteinShake],
  ),
  // --- s22–s26: external-adapter + amino-acid + fallback coverage --------
  MechanisticReplayScenario(
    scenarioId: 's22_amino_acid_actual_fields_mode',
    title: 'Candidate with actual amino-acid fields → LNAA uses actual-fields '
        'mode (preferred over protein-source proxy)',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-300)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 240, endMinute: 360),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateAminoAcidFood, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's23_amino_acid_proxy_mode',
    title: 'Candidate without amino-acid fields → LNAA falls back to '
        'protein-source proxy mode',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-300)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 240, endMinute: 360),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateProteinShake, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's24_levodopa_no_unit_invalid',
    title:
        '"levodopa 100" without unit → invalid medication context, candidates '
        'insufficient',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_levodopa100NoUnit],
    medicationMinutesOffsets: [MinutesOffset(-30)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 60, endMinute: 120),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's25_slashed_no_unit_invalid',
    title: '"25/100" without catalog normalization → invalid context',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    medicationEntries: [_slashedNoUnit],
    medicationMinutesOffsets: [MinutesOffset(-30)],
    meals: [],
  ),
  MechanisticReplayScenario(
    scenarioId: 's26_eligible_overwrites_legacy_order',
    title: 'Mechanistic-primary eligible (window + scored candidates) → '
        'mechanistic ordering, not legacy heuristic',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-300)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 240, endMinute: 360),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [
      _candidateProteinShake,
      _candidateBanana,
      _candidateRiceCake
    ],
  ),
  // --- s27–s31: production-readiness guardrail coverage ------------------
  MechanisticReplayScenario(
    scenarioId: 's27_amino_acid_food_far_window_actual_mode',
    title: 'Amino-acid-profiled candidate in a far low-overlap window → actual '
        'amino-acid mode, redistribution-compatible',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-360)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 300, endMinute: 420),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateAminoAcidFood, _candidateRiceCake],
  ),
  MechanisticReplayScenario(
    scenarioId: 's28_mixed_aa_and_proxy_candidates',
    title:
        'Mixed candidate set (amino-acid-profiled + proxy + missing nutrients) '
        '→ each scored with its own data mode',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-360)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 300, endMinute: 420),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [
      _candidateAminoAcidFood,
      _candidateProteinShake,
      _candidateMissingNutrients,
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's29_bare_numeric_invalid_with_window',
    title: 'Bare numeric "100" with a window → invalid medication context, '
        'candidates insufficient (no pretended optimization)',
    expectedOutputType: ScenarioExpectedOutputType.insufficientContext,
    expectInsufficientContext: true,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_bareNumeric],
    medicationMinutesOffsets: [MinutesOffset(-30)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 300, endMinute: 420),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateAminoAcidFood],
  ),
  MechanisticReplayScenario(
    scenarioId: 's30_no_window_fallback_visible',
    title:
        'No user-defined window with amino-acid candidate → mechanistic-primary '
        'unavailable, fallback reason visible',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-30)],
    meals: [],
    candidateFoods: [_candidateAminoAcidFood, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's31_daytime_overlap_amino_acid_food',
    title:
        'Daytime high-overlap window + amino-acid-profiled candidate → overlap '
        'penalty (not a protein-is-bad penalty)',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(0)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 0, endMinute: 90),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidateAminoAcidFood, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's32_partial_amino_acid_profile',
    title: 'Candidate with a PARTIAL amino-acid profile → partial data flag + '
        'widened uncertainty (not treated as fully narrow)',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    expectNonEmptyRecommendations: true,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(-300)],
    meals: [],
    userDefinedWindow: UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 240, endMinute: 360),
      source: 'synthetic_demo_fixture',
    ),
    candidateFoods: [_candidatePartialAminoAcidFood, _candidateBanana],
  ),
  MechanisticReplayScenario(
    scenarioId: 's33_high_calorie_high_fat_meal',
    title: 'Large high-calorie/high-fat meal close to a dose → gastric '
        'uncertainty widened (educational simulation; magnitudes heuristic)',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_big_plate',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_bigHighCalorieMeal],
      ),
    ],
  ),
  MechanisticReplayScenario(
    scenarioId: 's34_explicit_dose_dose_relative_lnaa',
    title:
        'Explicit user-entered dose + actual amino-acid meal → dose-relative '
        'LNAA proxy available in the trace (never an invented dose)',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_aa_dose_relative',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_aminoAcidMealComponent],
      ),
    ],
  ),

  // --- D2: missingness stress suite (missing ≠ zero) ---------------------
  MechanisticReplayScenario(
    scenarioId: 's35_missing_calories_and_portion',
    title: 'Protein present but calories + portion missing → lower composition '
        'completeness + capped confidence (missing ≠ zero)',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    expectedConfidenceCeiling: ConfidenceBand.medium,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_missing_cal_portion',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [
          FoodComponent(
            id: 'food.missing_cal_portion',
            name: 'high-protein item, calories+portion unknown (synthetic)',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 30,
            fatGrams: 6,
            fiberGrams: 0,
            carbohydrateGrams: 0,
            calories: null, // missing — never treated as 0
            portionGrams: null, // missing — never treated as 0
            sourceDocId: 'synthetic:demo_food',
          ),
        ],
      ),
    ],
    notes: 'Asserts missing calories/portion lower completeness + cap '
        'confidence rather than fabricating 0.',
  ),
  MechanisticReplayScenario(
    scenarioId: 's36_missing_all_macros_unknown_competition',
    title:
        'All macronutrients missing → unknown competition + insufficient/low '
        'confidence (never fabricated)',
    expectedOutputType: ScenarioExpectedOutputType.educationalInfo,
    expectedConfidenceCeiling: ConfidenceBand.low,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_all_missing',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.unknown,
        components: [
          FoodComponent(
            id: 'food.all_missing',
            name: 'unknown food, no macros (synthetic)',
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
      ),
    ],
    notes: 'Proves missing macros stay missing (unknown competition, lowered '
        'confidence), never silently 0.',
  ),

  // --- C1: enteral feeding educational scenarios (non-prescriptive) ------
  MechanisticReplayScenario(
    scenarioId: 's37_enteral_continuous_low_protein',
    title: 'Continuous enteral-style feed (low-protein liquid, sustained) — '
        'educational context only, no schedule or timing advice',
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_enteral_continuous',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.liquid,
        components: [
          FoodComponent(
            id: 'food.enteral_continuous.synth',
            name: 'continuous enteral feed, low protein (synthetic demo)',
            physicalForm: MealPhysicalForm.liquid,
            proteinGrams: 2,
            fatGrams: 2,
            fiberGrams: 0,
            carbohydrateGrams: 12,
            calories: 80,
            portionGrams: 250,
            sourceDocId: 'synthetic:demo_food',
          ),
        ],
      ),
    ],
    notes: 'Enteral feeding changes protein delivery + gastric context. '
        'Educational simulation only; not a feeding schedule or timing '
        'recommendation. Review with a qualified professional.',
  ),
  MechanisticReplayScenario(
    scenarioId: 's38_enteral_bolus_protein',
    title: 'Bolus enteral-style feed (protein-containing liquid) near a dose — '
        'educational context only, no schedule or timing advice',
    // A liquid bolus empties quickly, so in this configuration the model finds
    // no modeled interaction by the time the absorption window opens.
    expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
    medicationEntries: [_carbidopaLevodopaIr],
    medicationMinutesOffsets: [MinutesOffset(20)],
    meals: [
      ScenarioMeal(
        id: 'meal_enteral_bolus',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.liquid,
        components: [_smoothieLiquidProtein],
      ),
    ],
    notes: 'Bolus enteral feed modeled as a protein-containing liquid meal. '
        'Educational simulation only; not a feeding schedule or timing '
        'recommendation. Review with a qualified professional.',
  ),

  // --- A1/A2: CDSS→mechanistic medication section-provenance bridge -------
  MechanisticReplayScenario(
    scenarioId: 's39_spl_ir_section_provenance',
    title: 'SPL-style IR carbidopa/levodopa with section provenance + 2 '
        'components bridged into the mechanistic context (educational)',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    expectedSeverityFloor: SeverityBand.moderate,
    medicationEntries: [_carbidopaLevodopaIrWithMetadata],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_chicken_spl_ir',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_chickenSteakProtein],
      ),
    ],
    notes: 'Label section refs + combination components + release-type source '
        'reach the per-event trace + report. Dose still from user/variant '
        'strength; product metadata never fabricates a dose.',
  ),
  MechanisticReplayScenario(
    scenarioId: 's40_spl_er_section_provenance',
    title: 'SPL-style ER carbidopa/levodopa with section provenance → wider '
        'absorption window from source-backed release type (educational)',
    expectedOutputType: ScenarioExpectedOutputType.educationalCaution,
    medicationEntries: [_carbidopaLevodopaErWithMetadata],
    medicationMinutesOffsets: [MinutesOffset(30)],
    meals: [
      ScenarioMeal(
        id: 'meal_chicken_spl_er',
        offset: MinutesOffset(0),
        physicalForm: MealPhysicalForm.solid,
        components: [_chickenSteakProtein],
      ),
    ],
    notes: 'Extended-release product metadata widens the modeled absorption '
        'window; release-type source recorded as structured_variant_metadata.',
  ),
];
