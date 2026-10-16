import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/lnaa_protein_fraction_calibration_table.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/reference_food_catalog.dart';
import 'package:parkinsum_companion/core/constants/reference_food_composition_table.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/food_composition_interdependency_model.dart'
    show referenceRowsByFdcId;
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
      .validate(
        const RawMedicationEntry(
          activeIngredients: ['carbidopa', 'levodopa'],
          drugProductVariant: 'synthetic:demo',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      )
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
      mealId: 'meat',
      mealStartMinute: 0,
      composition: meatComp,
    );
    final legumeProfile = emptying.build(
      mealId: 'legume',
      mealStartMinute: 0,
      composition: legumeComp,
    );
    final med = MedicationTimelineEvent(
      id: 'm',
      minute: 15,
      context: levodopa(),
    );
    final meatWindow = absorption.build(
      medication: med,
      overlappingMealProfile: meatProfile,
    );
    final legumeWindow = absorption.build(
      medication: med,
      overlappingMealProfile: legumeProfile,
    );
    final meatC = competition.build(
      mealComposition: meatComp,
      mealEmptyingProfile: meatProfile,
      absorptionWindow: meatWindow,
      mealStartMinute: 0,
    );
    final legumeC = competition.build(
      mealComposition: legumeComp,
      mealEmptyingProfile: legumeProfile,
      absorptionWindow: legumeWindow,
      mealStartMinute: 0,
    );
    expect(meatC.peakPressure, greaterThan(legumeC.peakPressure));
    expect(meatC.lnaaSummary, isNotNull);
    expect(legumeC.lnaaSummary, isNotNull);
    expect(
      meatC.lnaaSummary!.effectiveLoadFactor,
      greaterThan(legumeC.lnaaSummary!.effectiveLoadFactor),
    );
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
    final knownProfile = emptying.build(
      mealId: 'k',
      mealStartMinute: 0,
      composition: knownComp,
    );
    final unknownProfile = emptying.build(
      mealId: 'u',
      mealStartMinute: 0,
      composition: unknownComp,
    );
    final med = MedicationTimelineEvent(
      id: 'm',
      minute: 15,
      context: levodopa(),
    );
    final wK = absorption.build(
      medication: med,
      overlappingMealProfile: knownProfile,
    );
    final wU = absorption.build(
      medication: med,
      overlappingMealProfile: unknownProfile,
    );
    final cK = competition.build(
      mealComposition: knownComp,
      mealEmptyingProfile: knownProfile,
      absorptionWindow: wK,
      mealStartMinute: 0,
    );
    final cU = competition.build(
      mealComposition: unknownComp,
      mealEmptyingProfile: unknownProfile,
      absorptionWindow: wU,
      mealStartMinute: 0,
    );
    const order = [
      UncertaintyBand.narrow,
      UncertaintyBand.moderate,
      UncertaintyBand.wide,
      UncertaintyBand.veryWide,
    ];
    expect(
      order.indexOf(cU.uncertaintyBand),
      greaterThanOrEqualTo(order.indexOf(cK.uncertaintyBand)),
    );
    expect(cU.lnaaSummary!.uncertaintyWidened, isTrue);
  });

  test('inferProteinSourceFromNameAndCategory maps common synthetic foods', () {
    expect(
      inferProteinSourceFromNameAndCategory(name: 'silken tofu'),
      ProteinSourceType.soy,
    );
    expect(
      inferProteinSourceFromNameAndCategory(name: 'beef brisket'),
      ProteinSourceType.meat,
    );
    expect(
      inferProteinSourceFromNameAndCategory(name: 'rolled oats'),
      ProteinSourceType.grain,
    );
    expect(
      inferProteinSourceFromNameAndCategory(name: 'cheddar cheese'),
      ProteinSourceType.dairy,
    );
    expect(
      inferProteinSourceFromNameAndCategory(name: 'mystery food'),
      ProteinSourceType.unknown,
    );
  });

  ProteinSourceType infer(String name) =>
      inferProteinSourceFromNameAndCategory(name: name);

  test('whole-word English matching avoids substring false matches', () {
    expect(infer('Eggplant (cooked)'), ProteinSourceType.unknown);
    expect(infer('Cauliflower, raw'), ProteinSourceType.unknown);
    expect(infer('Goat cheese'), ProteinSourceType.dairy);
    expect(infer('Licorice candy'), ProteinSourceType.unknown);
    expect(infer('Green peas'), ProteinSourceType.legume);
    expect(infer('Peanut butter'), ProteinSourceType.legume);
    expect(infer('Shrimp (cooked)'), ProteinSourceType.fish);
    expect(infer('Crab meat'), ProteinSourceType.fish);
    expect(infer('Hummus'), ProteinSourceType.legume);
    expect(infer('Couscous (cooked)'), ProteinSourceType.grain);
    expect(infer('Coffee beans, roasted'), ProteinSourceType.unknown);
    expect(
      infer('Japchae (glass noodles stir-fry)'),
      ProteinSourceType.unknown,
    );
  });

  test('plant drinks are not dairy', () {
    expect(infer('Oat milk'), ProteinSourceType.grain);
    expect(infer('Soy milk (unsweetened)'), ProteinSourceType.soy);
    expect(infer('Almond milk (unsweetened)'), ProteinSourceType.unknown);
    expect(infer('Coconut milk, canned'), ProteinSourceType.unknown);
    expect(infer('Whole milk'), ProteinSourceType.dairy);
    expect(infer('Vanilla ice cream'), ProteinSourceType.dairy);
  });

  test('two named sources are mixed; grain yields to the other', () {
    expect(infer('Chicken and egg fried rice'), ProteinSourceType.mixed);
    expect(infer('Chicken biryani'), ProteinSourceType.meat);
    expect(infer('Soybean paste'), ProteinSourceType.soy);
    expect(infer('Cheese pizza (slice)'), ProteinSourceType.dairy);
  });

  test('Chinese names are matched on specific food words', () {
    expect(infer('原味豆腐'), ProteinSourceType.soy);
    expect(infer('牛肉（瘦，煎）'), ProteinSourceType.meat);
    expect(infer('鸡蛋（水煮）'), ProteinSourceType.egg);
    expect(infer('三文鱼（养殖，烤）'), ProteinSourceType.fish);
    expect(infer('半脱脂牛奶'), ProteinSourceType.dairy);
    expect(infer('燕麦片'), ProteinSourceType.grain);
    expect(infer('鲜蚕豆'), ProteinSourceType.legume);
    // Words that contain a keyword without naming the food.
    expect(infer('土豆（水煮）'), ProteinSourceType.unknown);
    expect(infer('牛油果（生）'), ProteinSourceType.unknown);
    expect(infer('奶油南瓜（生）'), ProteinSourceType.unknown);
    expect(infer('红薯（带皮烤，果肉）'), ProteinSourceType.unknown);
    expect(infer('鱼香肉丝'), ProteinSourceType.meat);
    expect(infer('乳清蛋白粉'), ProteinSourceType.dairy);
    expect(infer('大豆蛋白粉'), ProteinSourceType.soy);
    expect(infer('椰奶'), ProteinSourceType.unknown);
    expect(infer('燕麦奶'), ProteinSourceType.grain);
    expect(infer('蛋糕'), ProteinSourceType.unknown);
  });

  test('aliases decide when the display name names no source', () {
    expect(
      inferProteinSourceFromNameAndCategory(
        name: '某种菜',
        aliases: const ['chicken breast, cooked'],
      ),
      ProteinSourceType.meat,
    );
    for (final food in buildP0FoodCatalog()) {
      final source = proteinSourceForFoodItem(food);
      if (food.aliases.any((alias) => alias.contains('beef'))) {
        expect(source, ProteinSourceType.meat, reason: food.name);
      }
      if (food.aliases.any((alias) => alias.contains('tofu'))) {
        expect(source, ProteinSourceType.soy, reason: food.name);
      }
    }
  });

  test('text inference agrees with the curated reference groups', () {
    // The 224 curated reference foods are a labelled set in two languages:
    // the Chinese display name, the English name and the official
    // description must each infer the curated group's protein source.
    // Accepted disagreements are botanical or carry no protein to speak of.
    const accepted = {
      170419, // green peas: a legume, curated as a vegetable
      170420,
      169998, // sweet corn: a cereal, curated as a vegetable
      169717, // tapioca pearls: cassava starch, curated as a grain
      171403, // mayonnaise-type dressing (蛋黄酱): egg yolk, a condiment
      171410, // peanut oil
      171411, // soybean oil
    };
    final disagreements = <int>{};
    for (final row in referenceFoodCompositionRows) {
      final expected = proteinSourceForReferenceGroup(
        row.group,
        row.sourceDescription,
      );
      for (final text in [row.nameZh, row.nameEn, row.sourceDescription]) {
        if (infer(text) != expected) disagreements.add(row.fdcId);
      }
    }
    expect(disagreements, accepted);
    expect(referenceFoodCompositionRows, hasLength(224));
  });

  test('catalog foods use their curated group, as the calibration does', () {
    for (final food in lnaaCalibrationFoods) {
      final row = referenceRowsByFdcId[food.fdcId]!;
      final source = proteinSourceForReferenceGroup(
        row.group,
        row.sourceDescription,
      );
      expect(
        food.proteinSource ?? ProteinSourceType.unknown,
        source,
        reason: '${food.fdcId}',
      );
    }
    final catalog = {
      for (final food in buildReferenceFoodCatalog()) food.sourceFoodCode: food,
    };
    // Display names are Chinese; the curated group still decides.
    final chicken = catalog['171477']!;
    expect(chicken.name, contains('鸡胸肉'));
    expect(proteinSourceForFoodItem(chicken), ProteinSourceType.meat);
    expect(
      foodItemToCandidateFood(chicken).components.single.proteinSource,
      ProteinSourceType.meat,
    );
    expect(proteinSourceForFoodItem(catalog['172475']!), ProteinSourceType.soy);
    expect(
      proteinSourceForFoodItem(catalog['172420']!),
      ProteinSourceType.legume,
    );
    // Eggplant is a vegetable; the proxy names no type for it.
    expect(
      proteinSourceForFoodItem(catalog['169228']!),
      ProteinSourceType.unknown,
    );
  });
}
