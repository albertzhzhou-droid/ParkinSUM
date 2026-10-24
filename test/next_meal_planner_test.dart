import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_plan.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/food_serving_reference_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_planner.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_trace_provider.dart';

// Synthetic foods, medicines and intakes only.
FoodItem _food(
  String id, {
  String name = 'Food',
  FoodCategory category = FoodCategory.protein,
  String? texture,
  double protein = 10,
  double carbs = 5,
  double fat = 3,
  double? energy = 100,
  Set<String> missing = const {},
  String jurisdiction = 'US',
  String sourceSystem = 'LOCAL_SEED',
  String? code,
}) => FoodItem(
  id: id,
  name: name,
  category: category,
  textureClass: texture,
  proteinG: protein,
  carbsG: carbs,
  fatG: fat,
  fiberG: 0,
  sodiumMg: 0,
  energyKcal: energy,
  missingNutrientFields: missing,
  jurisdiction: jurisdiction,
  sourceSystem: sourceSystem,
  sourceFoodCode: code,
);

final _levodopa = DrugDefinition(
  id: 'drug_synthetic_levodopa',
  genericName: 'carbidopa/levodopa',
  brandNames: const [],
  tags: const [DrugTag.levodopaLike],
  notes: '',
  route: 'oral',
  dosageForm: 'tablet',
  releaseType: 'immediate',
);

final _profile = UserProfile.defaults();
final _doseAt = DateTime.utc(2026, 1, 1, 8);

Intake _confirmed({DateTime? at, String releaseType = 'immediate'}) {
  final takenAt = at ?? _doseAt;
  return AdministrationDoseConfirmationCoordinator()
      .prepare(
        draft: Intake(
          id: 'intake_${takenAt.millisecondsSinceEpoch}',
          drugId: _levodopa.id,
          takenAt: takenAt,
          dosageNote: '100 mg',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: releaseType,
        ),
        current: null,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        ownerScope: _profile.patientId,
        operationId: 'planner_test_${takenAt.millisecondsSinceEpoch}',
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'test.explicit_confirmation',
        uiContractVersion: 'test-dose-confirmation:1',
        confirmedAt: takenAt.add(const Duration(minutes: 1)),
      )
      .intake!;
}

void main() {
  // Twenty draws keep the suite fast; the seed is fixed either way.
  final provider = PhysiologyReferenceTraceProvider(draws: 20);
  NextMealPlanner planner() => NextMealPlanner(physiology: provider);

  NextMealDoseContext context(
    NextMealPlanner p, {
    Duration mealAfterDose = const Duration(minutes: 30),
    List<DrugDefinition>? drugs,
    List<Intake>? intakes,
  }) => p.doseContext(
    plannedAt: _doseAt.add(mealAfterDose),
    drugs: drugs ?? [_levodopa],
    intakes: intakes ?? [_confirmed()],
    ownerScope: _profile.patientId,
    observedAt: _doseAt.add(const Duration(hours: 2)),
  );

  group('candidate set', () {
    test('keeps one entry per id and per source record, per serving', () {
      final foods = [
        _food('a', name: 'Apple', sourceSystem: 'USDA_FDC', code: '1'),
        _food('a', name: 'Apple again'),
        _food('b', name: 'Apple copy', sourceSystem: 'usda_fdc', code: '1'),
        _food('c', name: 'Cheese'),
      ];
      final candidates = planner().buildCandidates(
        foods: foods,
        history: const [],
      );
      expect(candidates.map((c) => c.id), ['a', 'c']);
      final apple = candidates.first;
      final serving = foodServingReferenceFor(apple.food);
      expect(apple.proteinG, closeTo(10 * serving.evaluatedGrams / 100, 1e-9));
    });

    test('missing values stay unknown and lower completeness', () {
      final c = planner().candidateFor(
        _food('m', missing: {'proteinG', 'energyKcal'}, energy: null),
      );
      expect(c.proteinG, isNull);
      expect(c.energyKcal, isNull);
      expect(c.lnaaBasis, NextMealLnaaBasis.unknown);
      expect(
        c.missingFields,
        containsAll([
          NextMealDataFields.protein,
          NextMealDataFields.energy,
          NextMealDataFields.texture,
        ]),
      );
      expect(c.completeData, isFalse);
    });

    test('energy is derived 4/4/9 when the source has none', () {
      final c = planner().candidateFor(_food('d', energy: null));
      expect(c.energyDerived, isTrue);
      final scale = foodServingReferenceFor(c.food).evaluatedGrams / 100;
      expect(c.energyKcal, closeTo((4 * 10 + 4 * 5 + 9 * 3) * scale, 1e-9));
      expect(c.lnaaBasis, NextMealLnaaBasis.estimatedFromProtein);
      expect(c.lnaaG, greaterThan(0));
    });

    test('familiarity counts the user\'s own logged meals', () {
      final at = DateTime.utc(2026, 1, 1, 12);
      final meal = Meal(
        id: 'm1',
        eatenAt: at,
        title: 'Lunch',
        items: [
          MealItem.fromFood(food: _food('c'), quantityFactor: 1),
          MealItem.fromFood(food: _food('c'), quantityFactor: 1),
        ],
      );
      final candidates = planner().buildCandidates(
        foods: [_food('a'), _food('c')],
        history: [meal],
      );
      expect(candidates[0].familiar, isFalse);
      expect(candidates[1].timesLogged, 1);
      expect(candidates[1].lastLoggedAt, at);
    });
  });

  group('dose context', () {
    test('applies to a confirmed oral immediate-release dose', () {
      final ctx = context(planner());
      expect(ctx.applicable, isTrue);
      expect(ctx.offsetMinutes, 30);
    });

    test('names each reason it cannot apply', () {
      final p = planner();
      expect(context(p, drugs: const []).reasons, [
        NextMealUnavailableReason.noLevodopaMedication,
      ]);
      expect(context(p, intakes: const []).reasons, [
        NextMealUnavailableReason.noLoggedDose,
      ]);
      final unconfirmed = Intake(
        id: 'plain',
        drugId: _levodopa.id,
        takenAt: _doseAt,
        dosageNote: '100 mg',
      );
      expect(context(p, intakes: [unconfirmed]).reasons, [
        NextMealUnavailableReason.doseNotConfirmed,
      ]);
      expect(
        context(p, intakes: [_confirmed(releaseType: 'extended')]).reasons,
        [NextMealUnavailableReason.notOralImmediateRelease],
      );
      expect(context(p, mealAfterDose: const Duration(hours: 5)).reasons, [
        NextMealUnavailableReason.outsideModeledRange,
      ]);
    });

    test('compares with the logged dose nearest to the planned time', () {
      final p = planner();
      final ctx = context(
        p,
        mealAfterDose: const Duration(hours: 3, minutes: 50),
        intakes: [
          _confirmed(),
          _confirmed(at: _doseAt.add(const Duration(hours: 4))),
        ],
      );
      expect(ctx.offsetMinutes, -10);
      final anchors = p.anchors(
        now: _doseAt.add(const Duration(hours: 1)),
        drugs: [_levodopa],
        intakes: [
          _confirmed(),
          _confirmed(at: _doseAt.add(const Duration(hours: 4))),
        ],
      );
      expect(anchors.lastDoseAt, _doseAt);
      expect(anchors.nextDoseAt, _doseAt.add(const Duration(hours: 4)));
    });
  });

  group('modeled effect states', () {
    test('available when form, protein and energy are recorded', () {
      final p = planner();
      final c = p.candidateFor(_food('tofu', texture: 'soft', protein: 15));
      final central = p.candidateEffect(c, context(p));
      expect(central.availability, NextMealModelAvailability.available);
      expect(central.band, isNull);
      expect(central.centralLow, central.centralHigh);
      expect(central.centralLow, lessThan(1.0));
      final banded = p.candidateEffect(c, context(p), withBand: true);
      expect(banded.centralLow, central.centralLow);
      expect(banded.band!.p05, lessThanOrEqualTo(banded.band!.p95));
      expect(banded.plasmaLow, isNotNull);
    });

    test('bracketed between solid and liquid when the form is unknown', () {
      final p = planner();
      final c = p.candidateFor(_food('x', protein: 20, energy: 250));
      final effect = p.candidateEffect(c, context(p), withBand: true);
      expect(effect.availability, NextMealModelAvailability.bracketed);
      expect(effect.centralLow, lessThan(effect.centralHigh!));
      expect(effect.band!.p05, lessThanOrEqualTo(effect.centralLow!));
    });

    test('unavailable with reasons for missing inputs and context', () {
      final p = planner();
      final noProtein = p.candidateFor(
        _food('np', texture: 'soft', missing: {'proteinG'}),
      );
      final noEnergy = p.candidateFor(
        _food(
          'ne',
          texture: 'soft',
          energy: null,
          missing: {'fatG', 'energyKcal'},
        ),
      );
      expect(p.candidateEffect(noProtein, context(p)).reasons, [
        NextMealUnavailableReason.missingProtein,
      ]);
      expect(p.candidateEffect(noEnergy, context(p)).reasons, [
        NextMealUnavailableReason.missingEnergy,
      ]);
      expect(p.plateEffect(const [], context(p)).reasons, [
        NextMealUnavailableReason.emptyPlate,
      ]);
      final good = p.candidateFor(_food('g', texture: 'soft'));
      expect(p.candidateEffect(good, context(p, drugs: const [])).reasons, [
        NextMealUnavailableReason.noLevodopaMedication,
      ]);
    });

    test('sees direction: a meal before the dose differs from one after', () {
      final p = planner();
      final c = p.candidateFor(
        _food('t', texture: 'soft', protein: 25, energy: 300),
      );
      final before = p.candidateEffect(
        c,
        context(p, mealAfterDose: const Duration(minutes: -30)),
      );
      final after = p.candidateEffect(c, context(p));
      expect(before.centralLow, isNot(closeTo(after.centralLow!, 1e-6)));
    });

    test('is deterministic across planner instances', () {
      final food = _food('det', texture: 'liquid', protein: 12, energy: 160);
      List<double> run() {
        final p = NextMealPlanner(
          physiology: PhysiologyReferenceTraceProvider(draws: 20),
        );
        final e = p.candidateEffect(
          p.candidateFor(food),
          context(p),
          withBand: true,
        );
        return [e.centralLow!, ...e.band!.toList(), e.plasmaLow!];
      }

      expect(run(), run());
    });
  });

  group('plate', () {
    test('totals are additive in servings and count unknown parts', () {
      final p = planner();
      final a = p.candidateFor(_food('a', texture: 'soft', protein: 10));
      final b = p.candidateFor(_food('b', texture: 'soft', protein: 4));
      final u = p.candidateFor(_food('u', missing: {'proteinG'}));
      final one = p.plateTotals([NextMealPlateItem(a, 1)]);
      final two = p.plateTotals([NextMealPlateItem(a, 2)]);
      expect(two.protein.known, closeTo(2 * one.protein.known, 1e-9));
      final plate = p.plateTotals([
        NextMealPlateItem(a, 1),
        NextMealPlateItem(b, 1.5),
        NextMealPlateItem(u, 1),
      ]);
      expect(
        plate.protein.known,
        closeTo(a.proteinG! + 1.5 * b.proteinG!, 1e-9),
      );
      expect(plate.protein.unknownItemCount, 1);
      expect(
        plate.energy.known,
        closeTo(a.energyKcal! + 1.5 * b.energyKcal! + u.energyKcal!, 1e-9),
      );
    });

    test('doubling the servings lowers modeled brain entry further', () {
      final p = planner();
      final c = p.candidateFor(
        _food('h', texture: 'soft', protein: 18, energy: 220),
      );
      final whole = p.plateEffect(
        [NextMealPlateItem(c, 1)],
        context(p),
        withBand: false,
      );
      final doubled = p.plateEffect(
        [NextMealPlateItem(c, 2)],
        context(p),
        withBand: false,
      );
      expect(doubled.centralLow, lessThan(whole.centralLow!));
    });

    test('curves cover the dose window with bands and match the summary', () {
      final p = planner();
      final c = p.candidateFor(
        _food('cv', texture: 'soft', protein: 20, energy: 260),
      );
      final items = [NextMealPlateItem(c, 1)];
      final curves = p.plateCurves(items, context(p));
      expect(curves.scenarios, hasLength(1));
      final s = curves.scenarios.single;
      expect(s.timesMin.first, lessThanOrEqualTo(-30));
      expect(s.timesMin.last, 240);
      for (var j = 0; j < s.timesMin.length; j++) {
        expect(
          s.levodopaMeal.p05[j],
          lessThanOrEqualTo(s.levodopaMeal.p95[j] + 1e-12),
        );
        if (s.timesMin[j] < 0) {
          expect(s.brainEntryNoMeal.central[j], closeTo(1.0, 1e-9));
        }
      }
      final effect = p.plateEffect(items, context(p));
      expect(curves.effect.centralLow, effect.centralLow);
      expect(curves.effect.band!.toList(), effect.band!.toList());
    });
  });

  group('user-chosen order and filters', () {
    final foods = [
      _food(
        'z',
        name: 'Zucchini',
        category: FoodCategory.vegetable,
        protein: 1,
      ),
      _food(
        'b',
        name: 'Beans',
        texture: 'soft',
        protein: 8,
        jurisdiction: 'FR',
      ),
      _food(
        'm',
        name: 'Milk',
        category: FoodCategory.dairy,
        texture: 'liquid',
        protein: 3,
      ),
      _food(
        'q',
        name: 'Quark',
        category: FoodCategory.dairy,
        missing: {'proteinG'},
      ),
      _food('s', name: 'Steak', texture: 'regular', protein: 26),
    ];
    final meal = Meal(
      id: 'm',
      eatenAt: DateTime.utc(2026, 1, 1),
      title: 'x',
      items: [MealItem.fromFood(food: foods.first, quantityFactor: 1)],
    );

    List<String> ids(
      NextMealPlanner p, {
      NextMealFilter filter = const NextMealFilter(),
      NextMealSortKey sort = NextMealSortKey.familiarThenName,
      bool descending = false,
      String textureMode = 'unrestricted',
    }) => p
        .arrange(
          p.buildCandidates(foods: foods, history: [meal]),
          filter: filter,
          sort: sort,
          descending: descending,
          textureMode: textureMode,
          nameOf: (c) => c.food.name,
        )
        .map((c) => c.id)
        .toList();

    test('default order is familiar first, then by name', () {
      expect(ids(planner()), ['z', 'b', 'm', 'q', 's']);
      expect(ids(planner(), sort: NextMealSortKey.name), [
        'b',
        'm',
        'q',
        's',
        'z',
      ]);
    });

    test('value sorts put unknown values last in both directions', () {
      final p = planner();
      expect(ids(p, sort: NextMealSortKey.proteinPerServing).last, 'q');
      expect(
        ids(p, sort: NextMealSortKey.proteinPerServing, descending: true),
        ['s', 'b', 'm', 'z', 'q'],
      );
    });

    test('filters by group, texture, region, profile and completeness', () {
      final p = planner();
      expect(
        ids(p, filter: const NextMealFilter(groups: {FoodCategory.dairy})),
        ['m', 'q'],
      );
      expect(
        ids(
          p,
          filter: const NextMealFilter(
            textures: {NextMealTextureFilter.unknown},
          ),
        ),
        ['z', 'q'],
      );
      expect(ids(p, filter: const NextMealFilter(regions: {'FR'})), ['b']);
      expect(
        ids(
          p,
          filter: const NextMealFilter(matchTextureProfile: true),
          textureMode: 'soft_or_liquid',
        ),
        ['z', 'b', 'm', 'q'],
      );
      expect(
        ids(p, filter: const NextMealFilter(completeDataOnly: true)),
        isEmpty,
      );
      expect(ids(p, filter: const NextMealFilter(query: 'mil')), ['m']);
    });

    test('modeled-effect sort uses the effect the caller supplies', () {
      final p = planner();
      final ctx = context(p);
      final sorted = p.arrange(
        p.buildCandidates(foods: foods, history: const []),
        filter: const NextMealFilter(),
        sort: NextMealSortKey.modeledBrainEntry,
        descending: false,
        textureMode: 'unrestricted',
        nameOf: (c) => c.food.name,
        effectOf: (c) => p.candidateEffect(c, ctx),
      );
      expect(sorted.last.id, 'q');
      final values = [
        for (final c in sorted.take(4)) p.candidateEffect(c, ctx).sortValue!,
      ];
      expect(values, orderedEquals([...values]..sort()));
    });
  });

  group('alternatives (nutrition only)', () {
    String nameOf(NextMealCandidate c) => c.food.name;
    final p = planner();
    NextMealCandidate c(
      String id, {
      FoodCategory category = FoodCategory.protein,
      double protein = 10,
      double energy = 150,
      String? texture = 'soft',
      String jurisdiction = 'US',
      Set<String> missing = const {},
    }) => p.candidateFor(
      _food(
        id,
        name: id,
        category: category,
        protein: protein,
        energy: energy,
        texture: texture,
        jurisdiction: jurisdiction,
        missing: missing,
      ),
    );

    test(
      'same group, protein and energy within tolerance, texture allowed',
      () {
        final original = c('orig');
        final scale = original.proteinG! / 10;
        final pool = [
          original,
          c('close', protein: 10.5),
          c('far_protein', protein: 10 + 3.5 / scale * 2),
          c('other_group', category: FoodCategory.dairy),
          c('solid', texture: 'regular'),
          c('unknown', missing: {'proteinG'}),
        ];
        final alts = p.alternativesFor(
          original,
          pool,
          textureMode: 'soft_or_liquid',
          regions: const {'US'},
          nameOf: nameOf,
        );
        expect(alts.map((a) => a.candidate.id), ['close']);
        expect(alts.single.proteinDeltaG, closeTo(0.5 * scale, 1e-9));
        expect(alts.single.sameTexture, isTrue);
      },
    );

    test('closeness follows the documented formula and orders the deck', () {
      final original = c('orig');
      final a = c('a_near', protein: 10.2);
      final b = c('b_further', protein: 11.0, energy: 170);
      final closeness = NextMealPlanner.alternativeCloseness(original, b);
      final p0 = original.proteinG!;
      final e0 = original.energyKcal!;
      final expected =
          1 -
          0.5 *
              (b.proteinG! - p0).abs() /
              NextMealPlanner.proteinTolerance(p0) -
          0.3 *
              (b.energyKcal! - e0).abs() /
              NextMealPlanner.energyTolerance(e0) -
          0.2 *
              ((b.lnaaG! - original.lnaaG!).abs() /
                      NextMealPlanner.lnaaTolerance(original.lnaaG!))
                  .clamp(0.0, 1.0);
      expect(closeness, closeTo(expected, 1e-12));
      final alts = p.alternativesFor(
        original,
        [b, a, original],
        textureMode: 'unrestricted',
        regions: const {'US'},
        nameOf: nameOf,
      );
      expect(alts.map((x) => x.candidate.id), ['a_near', 'b_further']);
      // Deterministic across calls.
      expect(
        p
            .alternativesFor(
              original,
              [a, original, b],
              textureMode: 'unrestricted',
              regions: const {'US'},
              nameOf: nameOf,
            )
            .map((x) => x.closeness),
        alts.map((x) => x.closeness),
      );
    });

    test('regional evidence comes before closeness', () {
      final original = c('orig');
      final alts = p.alternativesFor(
        original,
        [
          c('fr_near', protein: 10.1, jurisdiction: 'FR'),
          c('us_far', protein: 11.5),
        ],
        textureMode: 'unrestricted',
        regions: const {'US'},
        nameOf: nameOf,
      );
      expect(alts.map((x) => x.candidate.id), ['us_far', 'fr_near']);
      expect(alts.last.regionalEvidence, isFalse);
    });

    test('no position without known protein and energy', () {
      expect(
        p.alternativesFor(
          c('orig', missing: {'proteinG'}),
          [c('x')],
          textureMode: 'unrestricted',
          regions: const {'US'},
          nameOf: nameOf,
        ),
        isEmpty,
      );
    });
  });

  group('region, availability and variety', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    Meal meal(String id, String foodId, DateTime at) => Meal(
      id: id,
      eatenAt: at,
      title: id,
      items: [
        MealItem.fromFood(food: _food(foodId, name: foodId), quantityFactor: 1),
      ],
    );
    final foods = [
      _food('us_a', name: 'Apple', jurisdiction: 'US'),
      _food('us_b', name: 'Bean', jurisdiction: 'US'),
      _food('fr_c', name: 'Cheese', jurisdiction: 'FR'),
      _food('fr_d', name: 'Dates', jurisdiction: 'FR'),
    ];

    List<String> ids(
      List<Meal> history, {
      NextMealFilter filter = const NextMealFilter(),
      int rotate = 0,
      NextMealSortKey sort = NextMealSortKey.familiarThenName,
    }) {
      final p = planner();
      return p
          .arrange(
            p.buildCandidates(foods: foods, history: history),
            filter: filter,
            sort: sort,
            descending: false,
            textureMode: 'unrestricted',
            nameOf: (c) => c.food.name,
            regions: const {'US'},
            now: now,
            rotateUsedWithinDays: rotate,
          )
          .map((c) => c.id)
          .toList();
    }

    test('user regions: override, else registration and diet region', () {
      final profile = UserProfile.defaults().copyWith(
        registrationRegion: 'CA',
        dietProfileRegion: 'FR',
      );
      expect(NextMealPlanner.userRegions(profile), {'CA', 'FR'});
      expect(
        NextMealPlanner.userRegions(
          profile.copyWith(contentJurisdictionOverride: ['cn', ' ']),
        ),
        {'CN'},
      );
    });

    test('foods without regional evidence wait behind a toggle', () {
      final history = [
        meal('m1', 'fr_d', now.subtract(const Duration(days: 5))),
      ];
      // Seen in the user's own meals counts as regional evidence.
      expect(ids(history), ['fr_d', 'us_a', 'us_b']);
      expect(
        ids(history, filter: const NextMealFilter(includeOtherRegions: true)),
        ['fr_d', 'us_a', 'us_b', 'fr_c'],
      );
      expect(
        ids(history, filter: const NextMealFilter(seenInMyMealsOnly: true)),
        ['fr_d'],
      );
    });

    test('variety rotation moves recent foods back until the days pass', () {
      final eatenApple = [
        meal('m1', 'us_a', now.subtract(const Duration(days: 1))),
      ];
      expect(ids(eatenApple, sort: NextMealSortKey.name), ['us_a', 'us_b']);
      expect(ids(eatenApple, sort: NextMealSortKey.name, rotate: 3), [
        'us_b',
        'us_a',
      ]);
      expect(
        ids(eatenApple, filter: const NextMealFilter(hideUsedWithinDays: 3)),
        ['us_b'],
      );
      // After the window the food is back in its place ...
      final older = [meal('m1', 'us_a', now.subtract(const Duration(days: 4)))];
      expect(ids(older, sort: NextMealSortKey.name, rotate: 3), [
        'us_a',
        'us_b',
      ]);
      // ... and reusing it starts its cycle again.
      final reused = [
        ...older,
        meal('m2', 'us_a', now.subtract(const Duration(hours: 2))),
      ];
      expect(ids(reused, sort: NextMealSortKey.name, rotate: 3), [
        'us_b',
        'us_a',
      ]);
      final candidate = planner()
          .buildCandidates(foods: foods, history: reused)
          .firstWhere((c) => c.id == 'us_a');
      expect(NextMealPlanner.daysSinceLastEaten(candidate, now), 0);
      expect(candidate.timesLogged, 2);
    });
  });
}
