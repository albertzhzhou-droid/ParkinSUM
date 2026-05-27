import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

void main() {
  final normalizer = MealCompositionNormalizer();
  final emptying = GastricEmptyingModel();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final competition = AminoAcidCompetitionModel();
  final validator = MedicationEntryValidator();

  NormalizedMedicationContext levodopa() => validator
      .validate(const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:demo',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ))
      .normalized!;

  test('same total protein, meat vs legume produces different LNAA load', () {
    final meatComp = normalizer.normalize(
      mealId: 'meat',
      components: const [
        FoodComponent(
          id: 'meat',
          name: 'meat',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 25,
          fatGrams: 8,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 150,
          sourceDocId: 'synthetic',
          proteinSource: ProteinSourceType.meat,
        ),
      ],
      declaredPhysicalForm: MealPhysicalForm.solid,
    );
    final legumeComp = normalizer.normalize(
      mealId: 'legume',
      components: const [
        FoodComponent(
          id: 'legume',
          name: 'legume',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 25,
          fatGrams: 8,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 150,
          sourceDocId: 'synthetic',
          proteinSource: ProteinSourceType.legume,
        ),
      ],
      declaredPhysicalForm: MealPhysicalForm.solid,
    );
    final meatProfile = emptying.build(
        mealId: 'meat', mealStartMinute: 0, composition: meatComp);
    final legumeProfile = emptying.build(
        mealId: 'legume', mealStartMinute: 0, composition: legumeComp);
    final med =
        MedicationTimelineEvent(id: 'm', minute: 15, context: levodopa());
    final meatWindow =
        absorption.build(medication: med, overlappingMealProfile: meatProfile);
    final legumeWindow = absorption.build(
        medication: med, overlappingMealProfile: legumeProfile);
    final meatC = competition.build(
        mealComposition: meatComp,
        mealEmptyingProfile: meatProfile,
        absorptionWindow: meatWindow,
        mealStartMinute: 0);
    final legumeC = competition.build(
        mealComposition: legumeComp,
        mealEmptyingProfile: legumeProfile,
        absorptionWindow: legumeWindow,
        mealStartMinute: 0);
    expect(meatC.peakPressure, greaterThan(legumeC.peakPressure));
    expect(meatC.lnaaSummary, isNotNull);
    expect(legumeC.lnaaSummary, isNotNull);
    expect(meatC.lnaaSummary!.effectiveLoadFactor,
        greaterThan(legumeC.lnaaSummary!.effectiveLoadFactor));
  });

  test('unknown protein source widens uncertainty vs known source', () {
    final knownComp = normalizer.normalize(
      mealId: 'known',
      components: const [
        FoodComponent(
          id: 'known',
          name: 'fish',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 25,
          fatGrams: 8,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 150,
          sourceDocId: 'synthetic',
          proteinSource: ProteinSourceType.fish,
        ),
      ],
      declaredPhysicalForm: MealPhysicalForm.solid,
    );
    final unknownComp = normalizer.normalize(
      mealId: 'unknown',
      components: const [
        FoodComponent(
          id: 'unknown',
          name: 'mystery protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 25,
          fatGrams: 8,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 150,
          sourceDocId: 'synthetic',
          proteinSource: ProteinSourceType.unknown,
        ),
      ],
      declaredPhysicalForm: MealPhysicalForm.solid,
    );
    final knownProfile =
        emptying.build(mealId: 'k', mealStartMinute: 0, composition: knownComp);
    final unknownProfile = emptying.build(
        mealId: 'u', mealStartMinute: 0, composition: unknownComp);
    final med =
        MedicationTimelineEvent(id: 'm', minute: 15, context: levodopa());
    final wK =
        absorption.build(medication: med, overlappingMealProfile: knownProfile);
    final wU = absorption.build(
        medication: med, overlappingMealProfile: unknownProfile);
    final cK = competition.build(
        mealComposition: knownComp,
        mealEmptyingProfile: knownProfile,
        absorptionWindow: wK,
        mealStartMinute: 0);
    final cU = competition.build(
        mealComposition: unknownComp,
        mealEmptyingProfile: unknownProfile,
        absorptionWindow: wU,
        mealStartMinute: 0);
    const order = [
      UncertaintyBand.narrow,
      UncertaintyBand.moderate,
      UncertaintyBand.wide,
      UncertaintyBand.veryWide,
    ];
    expect(order.indexOf(cU.uncertaintyBand),
        greaterThanOrEqualTo(order.indexOf(cK.uncertaintyBand)));
    expect(cU.lnaaSummary!.uncertaintyWidened, isTrue);
  });

  test('inferProteinSourceFromNameAndCategory maps common synthetic foods', () {
    expect(inferProteinSourceFromNameAndCategory(name: 'silken tofu'),
        ProteinSourceType.soy);
    expect(inferProteinSourceFromNameAndCategory(name: 'beef brisket'),
        ProteinSourceType.meat);
    expect(inferProteinSourceFromNameAndCategory(name: 'rolled oats'),
        ProteinSourceType.grain);
    expect(inferProteinSourceFromNameAndCategory(name: 'cheddar cheese'),
        ProteinSourceType.dairy);
    expect(inferProteinSourceFromNameAndCategory(name: 'mystery food'),
        ProteinSourceType.unknown);
  });
}
