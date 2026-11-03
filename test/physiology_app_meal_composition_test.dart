import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/reference_food_catalog.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/physiology_composition_defaults_copy.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_plan.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_planner.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_nutrition_outputs.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_model.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_trace_provider.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_planner_widgets.dart';

// Synthetic foods and the public reference catalog only.
FoodComponent _food({
  String name = 'food',
  MealPhysicalForm form = MealPhysicalForm.solid,
  double? protein = 20,
  double? carbohydrate,
  double? fat,
  double? kcal = 300,
  double? portion = 150,
  String? source = 'USDA_FDC',
  ProteinSourceType? catalogSource,
}) => FoodComponent(
  id: name,
  name: name,
  physicalForm: form,
  proteinGrams: protein,
  fatGrams: fat,
  fiberGrams: null,
  carbohydrateGrams: carbohydrate,
  calories: kcal,
  portionGrams: portion,
  sourceDocId: source,
  catalogProteinSource: catalogSource,
);

FoodItem _curated(int fdcId) => buildReferenceFoodCatalog().singleWhere(
  (food) => food.sourceFoodCode == '$fdcId',
);

const int _beef = 173407;
const int _tofu = 172475;
const int _egg = 171287;
const int _rice = 169753;
const int _ricotta = 171248;
const int _humanMilk = 171279;
const int _cod = 171955;
const int _lentils = 172420;
const int _wheyPowder = 173180;

void main() {
  group('protein type comes from catalog data, never a name', () {
    String typeOf(FoodItem food) =>
        physiologyProteinType(foodItemToCandidateFood(food).components.single);

    test('curated records map to the types the model has tables for', () {
      expect(typeOf(_curated(_beef)), 'meat');
      expect(typeOf(_curated(_egg)), 'egg');
      expect(typeOf(_curated(_rice)), 'cereal');
      expect(typeOf(_curated(_tofu)), 'soy');
    });

    test('a group that does not establish a type stays on the default', () {
      // The dairy group holds whey-rich foods, so it does not mean casein.
      for (final id in [_ricotta, _humanMilk, _cod, _lentils, _wheyPowder]) {
        expect(typeOf(_curated(id)), 'mixed', reason: '$id');
      }
    });

    test('the whole reference catalog maps as pinned', () {
      final counts = <String, int>{};
      for (final food in buildReferenceFoodCatalog()) {
        counts.update(typeOf(food), (n) => n + 1, ifAbsent: () => 1);
      }
      expect(counts, {
        'meat': 14,
        'egg': 6,
        'cereal': 33,
        'soy': 14,
        'mixed': 157,
      });
    });

    test('a food named after a protein source gets no type from its name', () {
      for (final food in buildP0FoodCatalog()) {
        expect(typeOf(food), 'mixed', reason: food.name);
      }
      final named = FoodItem(
        id: 'synthetic_beef',
        name: 'Beef steak',
        category: FoodCategory.protein,
        aliases: const ['beef', 'whey', 'tofu'],
        proteinG: 25,
        carbsG: 0,
        fatG: 10,
        fiberG: 0,
        sodiumMg: 0,
        sourceSystem: 'USDA_FDC',
        sourceFoodCode: '999999999',
      );
      expect(proteinSourceForFoodItem(named), ProteinSourceType.meat);
      expect(typeOf(named), 'mixed');
    });

    test('the curated record decides even under a different display name', () {
      final beef = _curated(_beef);
      final renamed = FoodItem(
        id: beef.id,
        name: 'Apple',
        category: FoodCategory.fruit,
        proteinG: beef.proteinG,
        carbsG: beef.carbsG,
        fatG: beef.fatG,
        fiberG: beef.fiberG,
        sodiumMg: beef.sodiumMg,
        sourceSystem: beef.sourceSystem,
        sourceFoodCode: beef.sourceFoodCode,
      );
      expect(typeOf(renamed), 'meat');
    });

    test('logged meals read the matched record; no match has no type', () {
      MealItem item(String name, String foodId) => MealItem(
        foodId: foodId,
        foodName: name,
        foodCategory: FoodCategory.protein,
        quantityFactor: 1.5,
        foodTags: const [],
        proteinPer100g: 20,
        carbsPer100g: 2,
        fatPer100g: 8,
        fiberPer100g: 0,
        sodiumPer100g: 70,
      );
      final matched = mealItemToFoodComponent(
        item('Whatever I called it', 'food_ref_usda_$_beef'),
        componentId: 'a',
        catalogMatch: _curated(_beef),
      );
      expect(physiologyProteinType(matched), 'meat');
      final unmatched = mealItemToFoodComponent(
        item('Beef steak', 'typed_by_hand'),
        componentId: 'b',
      );
      expect(unmatched.proteinSource, ProteinSourceType.meat);
      expect(physiologyProteinType(unmatched), 'mixed');
    });

    test('the type survives normalization and stays out of replay JSON', () {
      final component = foodItemToCandidateFood(
        _curated(_beef),
      ).components.single;
      final composition = MealCompositionNormalizer().normalize(
        mealId: 'm',
        components: [component],
      );
      expect(physiologyProteinType(composition.foodComponents.single), 'meat');
      expect(
        component.toJson().keys,
        isNot(contains('catalog_protein_source')),
      );
    });
  });

  group('full, partial and missing composition', () {
    test('full composition passes every stated value', () {
      final c = physiologyComponentFromFood(
        _food(carbohydrate: 30, fat: 5, catalogSource: ProteinSourceType.meat),
      )!;
      expect(c.carbohydrateG, 30);
      expect(c.fatG, 5);
      expect(c.proteinType, 'meat');
      expect(c.carbohydrateBasis, PhysiologyCarbohydrateBasis.stated);
      final defaults = physiologyCompositionDefaults([c]);
      expect(defaults.carbohydrate, 0);
      expect(defaults.proteinType, 0);
      expect(defaults.aminoAcids, 1, reason: 'no measured profile');
    });

    test('fat without carbohydrate uses the energy remainder, not 0', () {
      final c = physiologyComponentFromFood(_food(fat: 10))!;
      expect(c.carbohydrateG, isNull);
      expect(c.carbohydrateBasis, PhysiologyCarbohydrateBasis.energyRemainder);
      // (300 kcal - 4 x 20 - 9 x 10) / 4
      expect(c.carbohydrateGrams(0.55), closeTo(32.5, 1e-9));
      expect(physiologyCompositionDefaults([c]).carbohydrate, 1);
    });

    test('carbohydrate without fat is used as stated', () {
      final c = physiologyComponentFromFood(_food(carbohydrate: 12))!;
      expect(c.fatG, isNull);
      expect(c.carbohydrateGrams(0.55), 12);
      expect(physiologyCompositionDefaults([c]).carbohydrate, 0);
    });

    test('missing composition uses the stated share, never 0', () {
      final c = physiologyComponentFromFood(_food())!;
      expect(c.carbohydrateBasis, PhysiologyCarbohydrateBasis.defaultShare);
      expect(c.proteinType, 'mixed');
      expect(c.profileBasis, PhysiologyProfileBasis.mixedDefault);
      expect(c.carbohydrateGrams(0.55), closeTo(0.55 * 220 / 4, 1e-9));
      final defaults = physiologyCompositionDefaults([c]);
      expect(defaults.carbohydrate, 1);
      expect(defaults.proteinType, 1);
      expect(defaults.aminoAcids, 1);
    });

    test('a true zero is stated, unlike a missing value', () {
      final c = physiologyComponentFromFood(_food(carbohydrate: 0, fat: 0))!;
      expect(c.carbohydrateG, 0);
      expect(c.carbohydrateBasis, PhysiologyCarbohydrateBasis.stated);
    });

    test('an impossible amount is missing, not a negative intake', () {
      for (final bad in [-3.0, double.nan, double.infinity]) {
        final c = physiologyComponentFromFood(
          _food(carbohydrate: bad, fat: bad),
        )!;
        expect(c.carbohydrateG, isNull);
        expect(c.fatG, isNull);
      }
    });

    test('an unverified carbohydrate convention is not read as available', () {
      final c = physiologyComponentFromFood(
        _food(carbohydrate: 30, fat: 5, source: 'CHINA_CDC_FOOD_PLATFORM'),
      )!;
      expect(c.carbohydrateG, isNull);
      expect(c.carbohydrateBasis, PhysiologyCarbohydrateBasis.energyRemainder);
    });

    test('catalog foods missing carbohydrate stay missing', () {
      final missing = [
        for (final food in buildReferenceFoodCatalog())
          if (food.isNutrientMissing('carbsG')) food,
      ];
      expect(missing, hasLength(3));
      for (final food in missing) {
        final component = foodItemToCandidateFood(food).components.single;
        expect(component.carbohydrateGrams, isNull, reason: food.name);
        expect(
          physiologyComponentFromFood(
            component,
            assumedForm: MealPhysicalForm.solid,
          )!.carbohydrateG,
          isNull,
          reason: food.name,
        );
      }
    });

    test('a food without protein has no protein type to default', () {
      final defaults = physiologyCompositionDefaults([
        physiologyComponentFromFood(
          _food(protein: 0, carbohydrate: 25, fat: 0, kcal: 100),
        )!,
        const PhysiologyComponent(
          'water',
          PhysiologyComponentForm.water,
          waterMl: 250,
        ),
      ]);
      expect(defaults.foods, 1);
      expect(defaults.anyUsed, isFalse);
    });
  });

  group('real composition reaches the nutrition outputs', () {
    final provider = PhysiologyNutritionProvider(draws: 20);
    final known = physiologyComponentFromFood(
      _food(
        form: MealPhysicalForm.liquid,
        protein: 25,
        carbohydrate: 3,
        fat: 1,
        kcal: 120,
        portion: 300,
        catalogSource: ProteinSourceType.soy,
      ),
    )!;
    final unknown = physiologyComponentFromFood(
      _food(
        form: MealPhysicalForm.liquid,
        protein: 25,
        kcal: 120,
        portion: 300,
      ),
    )!;

    test('known carbohydrate and type differ from the defaults', () {
      final a = provider.summarize([known]);
      final b = provider.summarize([unknown]);
      expect(
        a.load.components.single.profileBasis,
        PhysiologyProfileBasis.proteinTypeTable,
      );
      expect(
        b.load.components.single.profileBasis,
        PhysiologyProfileBasis.mixedDefault,
      );
      expect(a.load.digestibleUmol, isNot(b.load.digestibleUmol));
      for (final key in const [
        'lnaa6_peak_rise_umol_per_l',
        'lnaa6_rise_area_umol_min_per_l',
        'appearance_umol',
      ]) {
        expect(
          a.central[key],
          isNot(closeTo(b.central[key], 1e-6)),
          reason: key,
        );
      }
      // Soy digests faster than the mixed default.
      expect(
        a.central.appearanceHalfTimeMin,
        lessThan(b.central.appearanceHalfTimeMin),
      );
    });

    test('carbohydrate alone changes the insulin-lowered LNAA response', () {
      final low = physiologyComponentFromFood(_food(carbohydrate: 5, fat: 0))!;
      final high = physiologyComponentFromFood(
        _food(carbohydrate: 55, fat: 0),
      )!;
      expect(
        provider.summarize([high]).central.lnaa6RiseAreaUmolMinPerL,
        lessThan(provider.summarize([low]).central.lnaa6RiseAreaUmolMinPerL),
      );
    });

    test('levodopa curves are bit-identical; only brain entry moves', () {
      final trace = PhysiologyReferenceTraceProvider(draws: 20);
      for (final offset in const [-60.0, 0.0, 60.0]) {
        final a = simulatePhysiology(
          physiologyTimingScenario([known], offset),
          PhysiologyParameterValues.central(),
        );
        final b = simulatePhysiology(
          physiologyTimingScenario([unknown], offset),
          PhysiologyParameterValues.central(),
        );
        for (final key in const [
          'levodopa_mg_per_l',
          'stomach_kcal',
          'energy_out_kcal_per_min',
          'water_ml',
        ]) {
          expect(a[key], b[key], reason: '$key at $offset');
        }
        expect(a['brain_entry_index'], isNot(b['brain_entry_index']));
        final x = trace.mealTimingComparison([known], offset)!;
        final y = trace.mealTimingComparison([unknown], offset)!;
        expect(x.plasmaCentral, y.plasmaCentral);
        expect(x.plasmaBand.toList(), y.plasmaBand.toList());
      }
    });

    test('meals that differ only in composition do not share a memo', () {
      final trace = PhysiologyReferenceTraceProvider(draws: 20);
      expect(physiologyMealKey([known]), isNot(physiologyMealKey([unknown])));
      final a = trace.mealTimingEffect([known], -30)!;
      final b = trace.mealTimingEffect([unknown], -30)!;
      expect(a.central, isNot(b.central));
    });
  });

  group('planner', () {
    final planner = NextMealPlanner(
      physiology: PhysiologyReferenceTraceProvider(draws: 20),
    );

    test('the estimated LNAA chip uses the type table when it has one', () {
      FoodItem noProfile(String system, String code) => FoodItem(
        id: 'synthetic_$code',
        name: 'Synthetic',
        category: FoodCategory.protein,
        proteinG: 20,
        carbsG: 0,
        fatG: 5,
        fiberG: 0,
        sodiumMg: 0,
        energyKcal: 125,
        sourceSystem: system,
        sourceFoodCode: code,
      );
      final typed = planner.candidateFor(noProfile('USDA_FDC', '$_beef'));
      final untyped = planner.candidateFor(noProfile('LOCAL_SEED', '1'));
      expect(typed.lnaaBasis, NextMealLnaaBasis.estimatedFromProtein);
      expect(untyped.lnaaBasis, NextMealLnaaBasis.estimatedFromProtein);
      expect(typed.lnaaG, isNot(untyped.lnaaG));
    });
  });

  group('the user sees when a default was used', () {
    final i18n = AppI18n.fromLocaleTag('en-US');

    test('names only the inputs that used a default, with counts', () {
      final text = physiologyCompositionDefaultsText(
        i18n,
        const PhysiologyCompositionDefaults(
          foods: 3,
          carbohydrate: 1,
          proteinType: 2,
          aminoAcids: 0,
        ),
      )!;
      expect(text, contains('carbohydrate (1 of 3 foods)'));
      expect(text, contains('protein type (2 of 3 foods)'));
      expect(text, isNot(contains('amino-acid')));
      expect(text, contains('not counted as 0'));
    });

    test('says nothing when every input was stated', () {
      expect(
        physiologyCompositionDefaultsText(
          i18n,
          const PhysiologyCompositionDefaults(
            foods: 2,
            carbohydrate: 0,
            proteinType: 0,
            aminoAcids: 0,
          ),
        ),
        isNull,
      );
    });

    test('every language has the disclosure and keeps its placeholders', () {
      for (final code in const ['en', 'zh', 'fr', 'ja']) {
        final text = physiologyCompositionDefaultsText(
          AppI18n.fromLocaleTag(code),
          const PhysiologyCompositionDefaults(
            foods: 4,
            carbohydrate: 2,
            proteinType: 3,
            aminoAcids: 1,
          ),
        )!;
        expect(text, isNot(contains('{')), reason: code);
        expect(text, isNot(contains('mealcheck.')), reason: code);
        expect(text, contains('4'), reason: code);
      }
    });

    NextMealModeledEffect effect(PhysiologyCompositionDefaults? defaults) =>
        NextMealModeledEffect.modeled(
          bracketed: false,
          offsetMinutes: 30,
          centralLow: 0.8,
          centralHigh: 0.8,
          compositionDefaults: defaults,
        );

    Future<void> pump(WidgetTester tester, NextMealModeledEffect e) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlannerEffectLine(i18n: i18n, effect: e),
            ),
          ),
        );

    testWidgets('the effect line shows the disclosure under the value', (
      tester,
    ) async {
      await pump(
        tester,
        effect(
          const PhysiologyCompositionDefaults(
            foods: 1,
            carbohydrate: 1,
            proteinType: 0,
            aminoAcids: 0,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('next-meal-composition-defaults')),
        findsOneWidget,
      );
      expect(
        find.textContaining('carbohydrate (1 of 1 foods)'),
        findsOneWidget,
      );
    });

    testWidgets('the effect line stays as it was with nothing to disclose', (
      tester,
    ) async {
      await pump(
        tester,
        effect(
          const PhysiologyCompositionDefaults(
            foods: 1,
            carbohydrate: 0,
            proteinType: 0,
            aminoAcids: 0,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('next-meal-composition-defaults')),
        findsNothing,
      );
    });
  });
}
