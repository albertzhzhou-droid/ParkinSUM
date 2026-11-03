import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/constants/dish_catalog.dart';
import 'package:parkinsum_companion/core/constants/profile_options.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n_advanced_dishes_translations.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/state/dish_plate_handoff.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/dish_recipe.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/dish_nutrition_view.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';

/// Synthetic foods only. Values are per 100 g.
FoodItem _food(
  String id, {
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  double fiber = 0,
  double? energy,
  Set<String> missing = const {},
  AminoAcidProfile? aminoAcids,
  String? basisType,
}) => FoodItem(
  id: id,
  name: id,
  category: FoodCategory.other,
  sourceSystem: 'SYNTHETIC',
  sourceFoodCode: id,
  proteinG: protein,
  carbsG: carbs,
  fatG: fat,
  fiberG: fiber,
  sodiumMg: 0,
  energyKcal: energy,
  missingNutrientFields: missing,
  aminoAcidProfile: aminoAcids,
  basisType: basisType,
);

AminoAcidProfile _lnaa({double each = 1, bool partial = false}) =>
    AminoAcidProfile(
      leucine: each,
      isoleucine: each,
      valine: each,
      phenylalanine: each,
      tyrosine: each,
      tryptophan: partial ? null : each,
      unit: 'g',
      basis: 'per_100g',
    );

DishRecipe _dish(List<DishIngredient> ingredients) => DishRecipe(
  id: 'dish_test',
  name: const DishText(en: 'Test dish', zh: '测试菜'),
  regions: const ['US'],
  servings: 1,
  prepMinutes: 1,
  cookMinutes: 1,
  equipment: const [DishEquipment.bowl],
  ingredients: ingredients,
  steps: const [
    DishText(en: 'One.', zh: '一。'),
    DishText(en: 'Two.', zh: '二。'),
    DishText(en: 'Three.', zh: '三。'),
  ],
  texture: DishTexture.regular,
);

DishIngredient _ing(String? id, double grams) => DishIngredient(
  foodId: id,
  name: DishText(en: id ?? 'missing', zh: id ?? '缺失'),
  gramsPerServing: grams,
);

void main() {
  const view = DishNutritionView();

  group('DishNutritionView', () {
    test('scales per-100 g catalog values by grams and adds them', () {
      final foods = {
        'a': _food(
          'a',
          protein: 10,
          carbs: 20,
          fat: 5,
          fiber: 2,
          energy: 150,
          aminoAcids: _lnaa(each: 1),
        ),
        'b': _food(
          'b',
          protein: 4,
          carbs: 0,
          fat: 1,
          fiber: 0,
          energy: 40,
          aminoAcids: _lnaa(each: 0.5),
        ),
      };
      final result = view.compute(
        _dish([_ing('a', 150), _ing('b', 50)]),
        (id) => foods[id],
      );
      expect(result.complete, isTrue);
      expect(result.total(DishNutrient.protein).value, closeTo(17, 1e-9));
      expect(result.total(DishNutrient.carbohydrate).value, closeTo(30, 1e-9));
      expect(result.total(DishNutrient.fat).value, closeTo(8, 1e-9));
      expect(result.total(DishNutrient.fiber).value, closeTo(3, 1e-9));
      expect(result.total(DishNutrient.energy).value, closeTo(245, 1e-9));
      // 6 × 1 g × 1.5 + 6 × 0.5 g × 0.5.
      expect(
        result.total(DishNutrient.competingLnaa).value,
        closeTo(10.5, 1e-9),
      );
      expect(result.resolvedCount, 2);
      expect(result.resolvedGramsPerServing, 200);
    });

    test('missing fields stay unknown and are counted, never zero', () {
      final foods = {
        'known': _food('known', protein: 10, energy: 100, aminoAcids: _lnaa()),
        'noProtein': _food(
          'noProtein',
          protein: 999,
          energy: 50,
          missing: {'proteinG', 'fiberG'},
        ),
      };
      final result = view.compute(
        _dish([_ing('known', 100), _ing('noProtein', 100)]),
        (id) => foods[id],
      );
      final protein = result.total(DishNutrient.protein);
      expect(protein.complete, isFalse);
      expect(protein.value, isNull);
      expect(protein.knownSum, closeTo(10, 1e-9));
      expect((protein.knownCount, protein.unknownCount), (1, 1));
      expect(result.ingredients[1].valueOf(DishNutrient.protein), isNull);
      expect(result.ingredients[1].valueOf(DishNutrient.fiber), isNull);
      // Energy is known for both.
      expect(result.total(DishNutrient.energy).value, closeTo(150, 1e-9));
      // Unknown protein (not zero) gives unknown LNAA, not the zero bound.
      expect(result.ingredients[1].lnaaBasis, DishLnaaBasis.unknown);
      expect(result.complete, isFalse);
    });

    test('ingredients outside the catalog are unknown, not zero', () {
      final foods = {'a': _food('a', protein: 10, energy: 100)};
      final result = view.compute(
        _dish([_ing('a', 100), _ing(null, 120), _ing('ghost', 30)]),
        (id) => foods[id],
      );
      expect(result.ingredients[1].status, DishIngredientStatus.notInCatalog);
      expect(
        result.ingredients[2].status,
        DishIngredientStatus.catalogIdUnresolved,
      );
      for (final row in result.ingredients.skip(1)) {
        for (final nutrient in DishNutrient.values) {
          expect(row.valueOf(nutrient), isNull);
        }
      }
      final protein = result.total(DishNutrient.protein);
      expect((protein.knownCount, protein.ingredientCount), (1, 3));
      expect(protein.value, isNull);
      expect(result.resolvedCount, 1);
      expect(result.gramsPerServing, 250);
      expect(result.resolvedGramsPerServing, 100);
    });

    test('a food without an edible-mass basis is not scaled', () {
      final foods = {
        'liquid': _food(
          'liquid',
          protein: 3,
          energy: 60,
          basisType: 'per_100ml_product',
        ),
      };
      final result = view.compute(
        _dish([_ing('liquid', 200)]),
        (id) => foods[id],
      );
      expect(
        result.ingredients.single.status,
        DishIngredientStatus.noMassBasis,
      );
      expect(result.total(DishNutrient.protein).anyKnown, isFalse);
    });

    test('LNAA: complete profile, reported zero protein, or unknown', () {
      final foods = {
        'oil': _food('oil', protein: 0, fat: 100, energy: 884),
        'partial': _food(
          'partial',
          protein: 8,
          aminoAcids: _lnaa(partial: true),
        ),
        'none': _food('none', protein: 5),
        'full': _food('full', protein: 20, aminoAcids: _lnaa(each: 2)),
      };
      final result = view.compute(
        _dish([
          _ing('oil', 10),
          _ing('partial', 100),
          _ing('none', 100),
          _ing('full', 50),
        ]),
        (id) => foods[id],
      );
      final rows = result.ingredients;
      expect(rows[0].lnaaBasis, DishLnaaBasis.zeroProtein);
      expect(rows[0].valueOf(DishNutrient.competingLnaa), 0);
      expect(rows[1].lnaaBasis, DishLnaaBasis.unknown);
      expect(rows[1].valueOf(DishNutrient.competingLnaa), isNull);
      expect(rows[2].lnaaBasis, DishLnaaBasis.unknown);
      expect(rows[3].lnaaBasis, DishLnaaBasis.measuredProfile);
      expect(rows[3].valueOf(DishNutrient.competingLnaa), closeTo(6, 1e-9));
      final lnaa = result.total(DishNutrient.competingLnaa);
      expect((lnaa.knownCount, lnaa.ingredientCount), (2, 4));
      expect(lnaa.knownSum, closeTo(6, 1e-9));
    });

    test('plate request carries only resolved catalog foods', () {
      final foods = {'a': _food('a', protein: 10)};
      final result = view.compute(
        _dish([_ing('a', 80), _ing(null, 5)]),
        (id) => foods[id],
      );
      final request = DishPlateRequest.fromNutrition(
        result,
        catalogVersion: kDishCatalogVersion,
        servings: 2,
      );
      expect(request.items, [const DishPlateItem(foodId: 'a', grams: 160)]);
      expect(request.skippedIngredientNames.single.en, 'missing');
      expect(request.catalogVersion, kDishCatalogVersion);

      final handoff = DishPlateHandoff();
      var notified = 0;
      handoff.addListener(() => notified++);
      handoff.offer(request);
      expect(handoff.pending, same(request));
      expect(handoff.take(), same(request));
      expect(handoff.take(), isNull);
      expect(notified, 2);
    });
  });

  group('dish catalog', () {
    final repo = FoodRepository.createDefault();

    test('a versioned set of about 30–40 dishes with stable, unique ids', () {
      expect(kDishCatalogVersion, startsWith('dish_catalog_v'));
      expect(kDishCatalog.length, inInclusiveRange(30, 42));
      final ids = kDishCatalog.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(id, matches(RegExp(r'^dish_[a-z]{2}_[a-z0-9_]+$')));
      }
      expect(dishById('dish_cn_tomato_egg')?.name.zh, '番茄炒蛋');
      expect(dishById('nope'), isNull);
    });

    test('covers CN, US, FR/EU and other regions', () {
      int count(String region) =>
          kDishCatalog.where((d) => d.regions.contains(region)).length;
      expect(count('CN'), greaterThanOrEqualTo(8));
      expect(count('US'), greaterThanOrEqualTo(5));
      expect(count('FR') + count('ES'), greaterThanOrEqualTo(5));
      for (final region in ['JP', 'KR', 'IN', 'MX', 'SA']) {
        expect(count(region), greaterThan(0), reason: region);
      }
      for (final dish in kDishCatalog) {
        expect(dish.regions, isNotEmpty);
        for (final region in dish.regions) {
          expect(kSupportedRegistrationRegions, contains(region));
        }
      }
      for (final id in [
        'dish_cn_tomato_egg',
        'dish_cn_plain_congee',
        'dish_cn_steamed_fish',
        'dish_cn_tofu_shiitake',
      ]) {
        expect(dishById(id), isNotNull, reason: id);
      }
    });

    test('every dish is complete data', () {
      for (final dish in kDishCatalog) {
        final reason = dish.id;
        expect(dish.name.en.trim(), isNotEmpty, reason: reason);
        expect(dish.name.zh.trim(), isNotEmpty, reason: reason);
        expect(dish.steps.length, inInclusiveRange(3, 6), reason: reason);
        for (final step in dish.steps) {
          expect(step.en.trim(), isNotEmpty, reason: reason);
          expect(step.zh.trim(), isNotEmpty, reason: reason);
          expect(step.en.length, lessThan(160), reason: '$reason: ${step.en}');
        }
        expect(dish.servings, greaterThan(0), reason: reason);
        expect(dish.totalMinutes, greaterThan(0), reason: reason);
        expect(dish.equipment, isNotEmpty, reason: reason);
        expect(dish.ingredients, isNotEmpty, reason: reason);
        for (final ingredient in dish.ingredients) {
          expect(ingredient.gramsPerServing, greaterThan(0), reason: reason);
          expect(ingredient.name.en.trim(), isNotEmpty, reason: reason);
          expect(ingredient.name.zh.trim(), isNotEmpty, reason: reason);
        }
        final option = dish.textureOption;
        if (option != null) {
          expect(option.texture, isNot(dish.texture), reason: reason);
          expect(option.note.en.trim(), isNotEmpty, reason: reason);
          expect(option.note.zh.trim(), isNotEmpty, reason: reason);
        }
      }
    });

    test('every catalog id resolves in the built-in catalog', () {
      for (final dish in kDishCatalog) {
        for (final ingredient in dish.ingredients) {
          final id = ingredient.foodId;
          if (id == null) continue;
          final food = repo.getById(id);
          expect(food, isNotNull, reason: '${dish.id}: $id');
          expect(food!.supportsEdibleMassPoint, isTrue, reason: id);
        }
      }
    });

    test('nutrition is computed from the catalog for every dish', () {
      var complete = 0;
      for (final dish in kDishCatalog) {
        final result = view.compute(dish, repo.getById);
        final protein = result.total(DishNutrient.protein);
        expect(protein.anyKnown, isTrue, reason: dish.id);
        if (result.complete) complete++;
        // Not-in-catalog ingredients are the only unresolved ones here.
        for (final row in result.ingredients) {
          expect(
            row.resolved,
            row.ingredient.inCatalog,
            reason: '${dish.id}: ${row.ingredient.name.en}',
          );
        }
      }
      expect(complete, greaterThan(0));
      expect(complete, lessThan(kDishCatalog.length));
    });

    test('tomato and egg stir-fry matches the catalog arithmetic', () {
      final dish = dishById('dish_cn_tomato_egg')!;
      final result = view.compute(dish, repo.getById);
      var expected = 0.0;
      for (final ingredient in dish.ingredients) {
        final food = ingredient.foodId == null
            ? null
            : repo.getById(ingredient.foodId!);
        if (food == null) continue;
        expected += food.proteinG * ingredient.gramsPerServing / 100;
      }
      final protein = result.total(DishNutrient.protein);
      expect(protein.knownSum, closeTo(expected, 1e-9));
      // Scallion is not in the catalog.
      expect(protein.complete, isFalse);
      expect(protein.unknownCount, 1);
      expect(protein.knownSum, greaterThan(5));
    });
  });

  group('copy', () {
    final ui = kAdvancedDishesUiTranslations;
    final catalog = advancedDishCatalogTranslations();

    test('en and zh keys and placeholders match; others fall back', () {
      final placeholder = RegExp(r'\{([a-zA-Z]+)\}');
      Set<String> names(String text) =>
          placeholder.allMatches(text).map((m) => m[1]!).toSet();
      for (final map in [ui, catalog]) {
        final en = map['en']!;
        final zh = map['zh']!;
        expect(zh.keys.toSet(), en.keys.toSet());
        for (final key in en.keys) {
          expect(names(zh[key]!), names(en[key]!), reason: key);
        }
      }
      for (final tag in ['fr-FR', 'ja-JP', 'es-ES', 'ar-SA']) {
        final i18n = AppI18n.fromLocaleTag(tag);
        expect(i18n.tr('dishes.title'), ui['en']!['dishes.title']);
        expect(
          i18n.tr('dishes.catalog.dish_cn_tomato_egg.name'),
          'Tomato and egg stir-fry',
        );
      }
      expect(
        AppI18n.fromLocaleTag('zh-CN').tr('dishes.title'),
        ui['zh']!['dishes.title'],
      );
    });

    test('no banned, prescriptive or medical-claim wording', () {
      final prescriptive = RegExp(
        r'\bshould\b|\bmust\b|recommend|\bsafe\b|\bhealthy\b|\btreat|\bcure|'
        r'\bprevent|\bbest\b|应该|必须|推荐|安全|健康|治疗(?!师)|预防|最佳',
        caseSensitive: false,
      );
      for (final map in [ui, catalog]) {
        for (final entry in map.entries) {
          for (final MapEntry(key: key, value: text) in entry.value.entries) {
            expect(findBannedSubstrings(text), isEmpty, reason: text);
            for (final family in LocalizationSafetyLint.bannedFamilies.values) {
              for (final pattern in family) {
                expect(
                  text.toLowerCase().contains(pattern.toLowerCase()),
                  isFalse,
                  reason: '$key contains $pattern',
                );
              }
            }
            for (final pattern
                in LocalizationSafetyLint.overconfidencePatterns) {
              expect(text.toLowerCase().contains(pattern), isFalse);
            }
            expect(prescriptive.hasMatch(text), isFalse, reason: '$key: $text');
          }
        }
      }
    });

    test('framing names the boundary and the clinician review', () {
      final en = ui['en']!;
      expect(en['dishes.framing'], contains('simple preparation examples'));
      expect(en['dishes.framing'], contains('not dietary advice'));
      expect(
        en['dishes.framing'],
        contains('qualified clinician or dietitian'),
      );
      expect(en['dishes.texture_boundary'], contains('not swallowing advice'));
      expect(ui['zh']!['dishes.framing'], contains('不是饮食建议'));
      expect(ui['zh']!['dishes.texture_boundary'], contains('不是吞咽建议'));
      expect(en['dishes.incomplete_note'], contains('never counted as zero'));
    });
  });
}
