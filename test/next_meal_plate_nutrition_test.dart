import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/reference_food_catalog.dart';
import 'package:parkinsum_companion/core/constants/reference_food_composition_table.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n_next_meal_planner_translations.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/utils/texture_support.dart';
import 'package:parkinsum_companion/data/datasources/remote/regional_seed_catalog_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/seed_catalog_importer.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_plan.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_planner.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_nutrition_outputs.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_model.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_trace_provider.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_planner_widgets.dart';

final _catalog = buildReferenceFoodCatalog();

FoodItem _named(String nameEn) {
  final row = referenceFoodCompositionRows.singleWhere(
    (r) => r.nameEn == nameEn,
  );
  return _catalog.singleWhere((f) => f.sourceFoodCode == '${row.fdcId}');
}

// A small population keeps the bands cheap; the agreement fixture checks the
// full one.
final _planner = NextMealPlanner(
  nutrition: PhysiologyNutritionProvider(draws: 12),
);

NextMealPlateItem _item(String nameEn, [double servings = 1]) =>
    NextMealPlateItem(_planner.candidateFor(_named(nameEn)), servings);

void main() {
  group('curated form as eaten', () {
    test('states a form for 206 of the 224 reference foods', () {
      final forms = referenceFoodCompositionRows.map((r) => r.physicalForm);
      expect(forms.where((f) => f == 'solid'), hasLength(183));
      expect(forms.where((f) => f == 'liquid'), hasLength(23));
      expect(forms.where((f) => f == null), hasLength(18));
    });

    test('stays unstated where preparation decides the form', () {
      for (final name in [
        'olive oil',
        'butter, salted',
        'egg, whole, raw',
        'protein powder, whey based',
        'honey',
        'wheat flour, white, all-purpose, enriched',
      ]) {
        expect(
          curatedPhysicalFormForFoodItem(_named(name)),
          isNull,
          reason: name,
        );
      }
    });

    test('is read only for curated reference records', () {
      final other = FoodItem(
        id: 'food_other',
        name: 'Apple, raw',
        category: FoodCategory.fruit,
        proteinG: 0.3,
        carbsG: 14,
        fatG: 0.2,
        fiberG: 2,
        sodiumMg: 1,
        energyKcal: 52,
        sourceSystem: 'LOCAL_SEED',
        sourceFoodCode: '171688',
      );
      expect(curatedPhysicalFormForFoodItem(other), isNull);
    });

    test('never sets a texture, an IDDSI level or the stored form', () {
      for (final row in referenceFoodCompositionRows) {
        final food = _catalog.singleWhere(
          (f) => f.sourceFoodCode == '${row.fdcId}',
        );
        expect(food.textureClass, row.textureClass);
        expect(
          food.iddsiLevel,
          inferIddsiLevelFromTextureClass(row.textureClass),
        );
        final component = foodItemToCandidateFood(food).components.single;
        expect(
          component.physicalForm,
          textureClassToPhysicalForm(row.textureClass),
        );
      }
    });

    test('is not serialized, so replay capsules do not change', () {
      final component = foodItemToCandidateFood(
        _named('apple, raw, with skin'),
      ).components.single;
      expect(component.catalogPhysicalForm, MealPhysicalForm.solid);
      expect(component.toJson().toString(), isNot(contains('catalog')));
    });
  });

  group('form across the built-in catalogs', () {
    ({int stated, int bracketed, int noComposition}) coverage(
      List<FoodItem> foods,
    ) {
      var stated = 0, bracketed = 0, noComposition = 0;
      for (final food in foods) {
        final component = foodItemToCandidateFood(food).components.single;
        if (physiologyNutritionComponentFromFood(component) != null) {
          stated++;
        } else if (physiologyNutritionComponentFromFood(
              component,
              assumedForm: MealPhysicalForm.solid,
            ) !=
            null) {
          bracketed++;
        } else {
          noComposition++;
        }
      }
      return (
        stated: stated,
        bracketed: bracketed,
        noComposition: noComposition,
      );
    }

    test('the default catalog states 224 of 244', () {
      expect(coverage(buildP0FoodCatalog()), (
        stated: 18,
        bracketed: 2,
        noComposition: 0,
      ));
      expect(coverage(_catalog), (
        stated: 206,
        bracketed: 18,
        noComposition: 0,
      ));
    });

    test('every seed food with a composition states a form', () {
      expect(
        coverage(
          const SeedCatalogImporter().importSeedCatalog().projectedFoods,
        ),
        (stated: 87, bracketed: 0, noComposition: 4),
      );
      expect(
        coverage(
          const RegionalSeedCatalogImporter()
              .importRegionalSeedCatalog()
              .projectedFoods,
        ),
        (stated: 55, bracketed: 0, noComposition: 40),
      );
    });

    test('oats and olive oil stay unstated', () {
      for (final id in ['food_oats', 'food_olive_oil']) {
        final food = buildP0FoodCatalog().singleWhere((f) => f.id == id);
        expect(curatedPhysicalFormForFoodItem(food), isNull, reason: id);
      }
    });

    test('never changes the timing converter or the stored form', () {
      for (final food in [
        ...buildP0FoodCatalog(),
        ...const SeedCatalogImporter().importSeedCatalog().projectedFoods,
        ...const RegionalSeedCatalogImporter()
            .importRegionalSeedCatalog()
            .projectedFoods,
      ]) {
        final component = foodItemToCandidateFood(food).components.single;
        if (component.catalogPhysicalForm == null) continue;
        expect(
          component.physicalForm,
          MealPhysicalForm.unknown,
          reason: food.id,
        );
        expect(physiologyComponentFromFood(component), isNull, reason: food.id);
      }
    });

    test('a food from another source with the same id gets no form', () {
      final imported = FoodItem(
        id: 'food_banana',
        name: 'Banana',
        category: FoodCategory.fruit,
        proteinG: 1,
        carbsG: 20,
        fatG: 0,
        fiberG: 2,
        sodiumMg: 0,
        sourceSystem: 'OFF',
      );
      expect(curatedPhysicalFormForFoodItem(imported), isNull);
    });
  });

  group('nutrition converter', () {
    test('uses the curated form; the timing converter does not', () {
      final component = foodItemToCandidateFood(
        _named('apple, raw, with skin'),
      ).components.single;
      expect(component.physicalForm, MealPhysicalForm.unknown);
      expect(physiologyComponentFromFood(component), isNull);
      expect(
        physiologyNutritionComponentFromFood(component)!.form,
        PhysiologyComponentForm.solid,
      );
    });

    test('a logged meal stays unmodeled by the meal check', () {
      // The meal check converts through physiologyComponentFromFood only.
      final component = foodItemToCandidateFood(
        _named('banana, raw'),
      ).components.single;
      expect(physiologyComponentFromFood(component), isNull);
    });

    test('a stored form wins over the curated one', () {
      final component = foodItemToCandidateFood(
        _named('oatmeal, cooked with water'),
      ).components.single;
      expect(component.physicalForm, MealPhysicalForm.solid);
      expect(
        physiologyNutritionComponentFromFood(component)!.form,
        PhysiologyComponentForm.solid,
      );
    });
  });

  group('plate nutrition', () {
    test('models a plate with no medicine or dose in scope', () {
      final result = _planner.plateNutrition([
        _item('white rice, long-grain, cooked, enriched, salted'),
        _item('chicken breast, meat only, roasted'),
      ]);
      expect(result.modeled, isTrue);
      expect(result.foodsWithoutForm, 0);
      expect(result.digestibleMmol, greaterThan(0));
      expect(result.peakRiseUmolPerL!.high, greaterThan(0));
      expect(result.halfAppearedMin, isNotNull);
      expect(result.draws, 12);
    });

    test('a known form gives one scenario, an unknown form two', () {
      final known = [_item('chicken breast, meat only, roasted')];
      final bracketed = [...known, _item('olive oil')];
      expect(_planner.plateNutrition(known).foodsWithoutForm, 0);
      expect(_planner.plateNutrition(bracketed).foodsWithoutForm, 1);
    });

    test('form changes the timing of the load, not its size', () {
      final solid = _planner.plateNutrition([_item('apple, raw, with skin')]);
      final liquid = _planner.plateNutrition([_item('orange juice, raw')]);
      expect(solid.modeled && liquid.modeled, isTrue);
      final chicken = _planner.plateNutrition([
        _item('chicken breast, meat only, roasted'),
      ]);
      final chickenAndOil = _planner.plateNutrition([
        _item('chicken breast, meat only, roasted'),
        _item('olive oil'),
      ]);
      expect(
        chickenAndOil.digestibleMmol,
        closeTo(chicken.digestibleMmol!, 1e-9),
      );
    });

    test('shares sum to the plate, largest first, and follow servings', () {
      final result = _planner.plateNutrition([
        _item('white rice, long-grain, cooked, enriched, salted'),
        _item('chicken breast, meat only, roasted'),
      ]);
      expect(result.shares, hasLength(2));
      expect(
        result.shares.first.candidate.food.id,
        _named('chicken breast, meat only, roasted').id,
      );
      expect(
        result.shares.fold<double>(0, (sum, s) => sum + s.fraction),
        closeTo(1, 1e-9),
      );
      expect(
        result.shares.fold<double>(0, (sum, s) => sum + s.mmol),
        closeTo(result.digestibleMmol!, 1e-9),
      );

      final one = _planner.plateNutrition([
        _item('chicken breast, meat only, roasted'),
      ]);
      final two = _planner.plateNutrition([
        _item('chicken breast, meat only, roasted', 2),
      ]);
      expect(two.digestibleMmol, closeTo(one.digestibleMmol! * 2, 1e-9));
    });

    test('a plate without amino acids shows no absorption time', () {
      final result = _planner.plateNutrition([_item('sugar, granulated')]);
      expect(result.modeled, isTrue);
      expect(result.digestibleMmol, 0);
      expect(result.halfAppearedMin, isNull);
    });

    test('states why a plate is not modeled', () {
      expect(_planner.plateNutrition(const []).reasons, [
        NextMealUnavailableReason.emptyPlate,
      ]);
      final noEnergy = _planner.candidateFor(
        FoodItem(
          id: 'food_no_energy',
          name: 'Synthetic food',
          category: FoodCategory.protein,
          proteinG: 10,
          carbsG: 5,
          fatG: 3,
          fiberG: 0,
          sodiumMg: 0,
          missingNutrientFields: const {'energyKcal', 'carbsG', 'fatG'},
        ),
      );
      expect(
        _planner.plateNutrition([NextMealPlateItem(noEnergy, 1)]).reasons,
        [NextMealUnavailableReason.missingEnergy],
      );
    });
  });

  group('panel', () {
    Future<void> pump(WidgetTester tester, NextMealPlateNutrition nutrition) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlannerPlateNutritionPanel(
                  i18n: AppI18n.fromLocaleTag('en'),
                  nutrition: nutrition,
                  nameOf: (c) => c.food.name,
                ),
              ),
            ),
          ),
        );

    testWidgets('shows the load, ranges, foods and the boundary', (
      tester,
    ) async {
      await pump(
        tester,
        _planner.plateNutrition([
          _item('white rice, long-grain, cooked, enriched, salted'),
          _item('chicken breast, meat only, roasted'),
        ]),
      );
      expect(find.text('Amino acids on this plate'), findsOneWidget);
      expect(find.textContaining('Not a prediction for you'), findsOneWidget);
      expect(find.textContaining('mmol'), findsWidgets);
      expect(find.textContaining('µmol/L'), findsOneWidget);
      expect(find.text('By food'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.textContaining('12 simulated adults'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('next-meal-nutrition-no-form')),
        findsNothing,
      );
    });

    testWidgets('fits a narrow phone at a large text size', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        _planner.plateNutrition([
          _item('white rice, long-grain, cooked, enriched, salted'),
          _item('chicken breast, meat only, roasted'),
          _item('olive oil'),
        ]),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('says when foods were modeled both ways', (tester) async {
      await pump(
        tester,
        _planner.plateNutrition([
          _item('chicken breast, meat only, roasted'),
          _item('olive oil'),
        ]),
      );
      expect(
        find.textContaining('1 of 2 foods have no stated form'),
        findsOneWidget,
      );
    });

    testWidgets('says when the peak can fall after the window', (tester) async {
      NextMealPlateNutrition plate(double highMin) =>
          NextMealPlateNutrition.modeled(
            digestibleMmol: 10,
            peakRiseUmolPerL: const NextMealRange(100, 200),
            peakTimeMin: NextMealRange(170, highMin),
            windowMin: 240,
            halfAppearedMin: const NextMealRange(120, 150),
            shares: const [],
            foods: 1,
            foodsWithoutForm: 0,
            compositionDefaults: _planner.plateNutrition([
              _item('chicken breast, meat only, roasted'),
            ]).compositionDefaults!,
            draws: 12,
            seed: 1,
          );
      await pump(tester, plate(240));
      expect(find.text('170 min or later'), findsOneWidget);
      await pump(tester, plate(235));
      expect(find.text('170 min or later'), findsNothing);
      expect(find.text('170–235 min'), findsOneWidget);
    });

    testWidgets('gives the reason when a plate is not modeled', (tester) async {
      await pump(
        tester,
        const NextMealPlateNutrition.unavailable([
          NextMealUnavailableReason.missingEnergy,
        ]),
      );
      expect(find.textContaining('Not modeled:'), findsOneWidget);
    });

    test('copy names no medicine or dose and gives no instruction', () {
      final forbidden = RegExp(
        r'levodopa|dose|medic|recommend|should|best|左旋多巴|剂量|药|建议你|应该',
        caseSensitive: false,
      );
      for (final locale in kNextMealPlannerTranslations.values) {
        final copy = locale.entries
            .where((e) => e.key.startsWith('planner.nutrition_'))
            .where((e) => e.key != 'planner.nutrition_boundary');
        expect(copy, hasLength(14));
        for (final entry in copy) {
          expect(entry.value, isNot(matches(forbidden)), reason: entry.key);
        }
      }
    });
  });
}
