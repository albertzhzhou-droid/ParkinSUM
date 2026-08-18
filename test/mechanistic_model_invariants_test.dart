import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

void main() {
  final normalizer = MealCompositionNormalizer();
  final model = GastricEmptyingModel();

  FoodComponent component({
    required String id,
    required MealPhysicalForm form,
    required double? portionGrams,
    double? proteinGrams = 8,
    double? fatGrams = 4,
    double? fiberGrams = 3,
    double? carbohydrateGrams = 30,
    double? calories = 190,
  }) {
    return FoodComponent(
      id: id,
      name: id,
      physicalForm: form,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
      carbohydrateGrams: carbohydrateGrams,
      calories: calories,
      portionGrams: portionGrams,
      sourceDocId: 'synthetic:model-invariant-gate',
    );
  }

  GastricEmptyingProfile profileFor(List<FoodComponent> components) {
    final composition = normalizer.normalize(
      mealId: 'invariant-meal',
      components: components,
    );
    return model.build(
      mealId: 'invariant-meal',
      mealStartMinute: 0,
      composition: composition,
    );
  }

  test('component weights are finite, bounded, and conserve meal mass', () {
    final profile = profileFor([
      component(
        id: 'positive-mass',
        form: MealPhysicalForm.solid,
        portionGrams: 180,
      ),
      component(
        id: 'zero-mass',
        form: MealPhysicalForm.liquid,
        portionGrams: 0,
      ),
      component(
        id: 'missing-mass',
        form: MealPhysicalForm.mixed,
        portionGrams: null,
      ),
    ]);

    final fractions = profile.componentProfiles
        .map((component) => component.fractionOfMeal)
        .toList(growable: false);
    expect(fractions.every((value) => value.isFinite), isTrue);
    expect(fractions.every((value) => value >= 0 && value <= 1), isTrue);
    expect(fractions.reduce((a, b) => a + b), closeTo(1, 1e-12));
    expect(fractions, [0.5, 0.0, 0.5]);
    expect(profile.missingInputs, contains('portion_grams'));
    expect(
      profile.assumptions,
      anyElement(startsWith('ge.component_portion.partial_mean_imputation')),
    );
  });

  test('normalizer exposes partial portion missingness without false mass', () {
    final composition = normalizer.normalize(
      mealId: 'partial-portion',
      components: [
        component(
          id: 'known-liquid',
          form: MealPhysicalForm.liquid,
          portionGrams: 180,
        ),
        component(
          id: 'unknown-solid',
          form: MealPhysicalForm.solid,
          portionGrams: null,
        ),
      ],
    );

    expect(composition.liquidFraction, isNull);
    expect(composition.mealPhysicalForm, MealPhysicalForm.mixed);
    expect(composition.missingFields, contains('portion_grams'));
    expect(composition.missingFields, contains('liquid_fraction'));
    expect(composition.compositionCompleteness, closeTo(6 / 8, 1e-12));
  });

  test('partial nutrient observations never become precise meal totals', () {
    final composition = normalizer.normalize(
      mealId: 'partial-nutrients',
      components: [
        component(
          id: 'known',
          form: MealPhysicalForm.solid,
          portionGrams: 100,
          proteinGrams: 10,
          fatGrams: 5,
          calories: 200,
        ),
        component(
          id: 'unknown',
          form: MealPhysicalForm.solid,
          portionGrams: 100,
          proteinGrams: null,
          fatGrams: null,
          calories: null,
        ),
      ],
    );

    expect(composition.proteinGrams, isNull);
    expect(composition.fatGrams, isNull);
    expect(composition.totalCalories, isNull);
    expect(
      composition.missingFields,
      containsAll(['protein_grams', 'fat_grams', 'total_calories']),
    );
    expect(composition.proteinAmountBand, AmountBand.unknown);
    expect(composition.fatAmountBand, AmountBand.unknown);
    expect(composition.calorieBand, AmountBand.unknown);
  });

  test('published nutrient aggregates are finite and nonnegative', () {
    final invalid = normalizer.normalize(
      mealId: 'invalid-nutrients',
      components: [
        component(
          id: 'invalid',
          form: MealPhysicalForm.solid,
          portionGrams: 100,
          proteinGrams: double.nan,
          fatGrams: double.infinity,
          fiberGrams: -1,
          carbohydrateGrams: double.negativeInfinity,
          calories: -10,
        ),
      ],
    );
    expect([
      invalid.proteinGrams,
      invalid.fatGrams,
      invalid.fiberGrams,
      invalid.carbohydrateGrams,
      invalid.totalCalories,
    ], everyElement(isNull));

    final zeros = normalizer.normalize(
      mealId: 'known-zero-nutrients',
      components: [
        component(
          id: 'zeros',
          form: MealPhysicalForm.solid,
          portionGrams: 0,
          proteinGrams: 0,
          fatGrams: 0,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 0,
        ),
      ],
    );
    final published = [
      zeros.proteinGrams,
      zeros.fatGrams,
      zeros.fiberGrams,
      zeros.carbohydrateGrams,
      zeros.totalCalories,
    ].whereType<double>();
    expect(published, everyElement(0.0));
    expect(published.every((value) => value.isFinite && value >= 0), isTrue);
  });

  test(
    'unknown physical form is missing unless a known declaration covers it',
    () {
      final unknown = normalizer.normalize(
        mealId: 'unknown-form',
        components: [
          component(
            id: 'unknown',
            form: MealPhysicalForm.unknown,
            portionGrams: 100,
          ),
        ],
      );
      expect(unknown.mealPhysicalForm, MealPhysicalForm.unknown);
      expect(unknown.liquidFraction, isNull);
      expect(
        unknown.missingFields,
        containsAll(['meal_physical_form', 'liquid_fraction']),
      );
      expect(unknown.compositionCompleteness, closeTo(6 / 8, 1e-12));

      final declared = normalizer.normalize(
        mealId: 'declared-form',
        components: unknown.foodComponents,
        declaredPhysicalForm: MealPhysicalForm.solid,
      );
      expect(declared.mealPhysicalForm, MealPhysicalForm.solid);
      expect(declared.missingFields, isNot(contains('meal_physical_form')));
    },
  );

  test(
    'empty composition and gastric trace preserve physical-form missingness',
    () {
      final composition = normalizer.normalize(
        mealId: 'empty-form',
        components: const [],
      );
      expect(composition.missingFields, contains('meal_physical_form'));

      final profile = model.build(
        mealId: composition.id,
        mealStartMinute: 0,
        composition: composition,
      );
      expect(profile.missingInputs, containsAll(composition.missingFields));
    },
  );

  test('all-known component masses retain their exact proportions', () {
    final profile = profileFor([
      component(id: 'one', form: MealPhysicalForm.solid, portionGrams: 120),
      component(id: 'two', form: MealPhysicalForm.liquid, portionGrams: 240),
    ]);

    final fractions = profile.componentProfiles
        .map((component) => component.fractionOfMeal)
        .toList(growable: false);
    expect(fractions[0], closeTo(1 / 3, 1e-12));
    expect(fractions[1], closeTo(2 / 3, 1e-12));
    expect(fractions.reduce((a, b) => a + b), closeTo(1, 1e-12));
    expect(profile.missingInputs, isNot(contains('portion_grams')));
  });

  test('partial unknown mass uses the mean of known positive portions', () {
    final profile = profileFor([
      component(id: 'small', form: MealPhysicalForm.solid, portionGrams: 100),
      component(id: 'large', form: MealPhysicalForm.liquid, portionGrams: 300),
      component(
        id: 'unknown',
        form: MealPhysicalForm.mixed,
        portionGrams: null,
      ),
    ]);

    final fractions = profile.componentProfiles
        .map((component) => component.fractionOfMeal)
        .toList(growable: false);
    // Mean-imputed mass is 200 g, so the normalized weights are 1:3:2.
    expect(fractions[0], closeTo(1 / 6, 1e-12));
    expect(fractions[1], closeTo(3 / 6, 1e-12));
    expect(fractions[2], closeTo(2 / 6, 1e-12));
    expect(fractions.reduce((a, b) => a + b), closeTo(1, 1e-12));
  });

  test(
    'all-unknown component masses use a normalized equal-weight fallback',
    () {
      final profile = profileFor([
        component(
          id: 'unknown-a',
          form: MealPhysicalForm.solid,
          portionGrams: null,
        ),
        component(
          id: 'unknown-b',
          form: MealPhysicalForm.liquid,
          portionGrams: null,
        ),
      ]);

      final fractions = profile.componentProfiles
          .map((component) => component.fractionOfMeal)
          .toList(growable: false);
      expect(fractions, [0.5, 0.5]);
      expect(fractions.reduce((a, b) => a + b), closeTo(1, 1e-12));
      expect(profile.missingInputs, contains('portion_grams'));
      expect(
        profile.assumptions,
        anyElement(startsWith('ge.component_portion.all_unknown_equal_weight')),
      );
    },
  );

  test('unusable component masses retain a finite normalized fallback', () {
    final profile = profileFor([
      component(id: 'zero', form: MealPhysicalForm.solid, portionGrams: 0),
      component(
        id: 'negative',
        form: MealPhysicalForm.liquid,
        portionGrams: -10,
      ),
      component(
        id: 'not-a-number',
        form: MealPhysicalForm.mixed,
        portionGrams: double.nan,
      ),
      component(
        id: 'infinite',
        form: MealPhysicalForm.unknown,
        portionGrams: double.infinity,
      ),
    ]);

    final fractions = profile.componentProfiles
        .map((component) => component.fractionOfMeal)
        .toList(growable: false);
    expect(fractions, [0.25, 0.25, 0.25, 0.25]);
    expect(fractions.every((value) => value.isFinite), isTrue);
    expect(fractions.every((value) => value >= 0 && value <= 1), isTrue);
    expect(fractions.reduce((a, b) => a + b), closeTo(1, 1e-12));
    expect(
      profile.assumptions,
      anyElement(
        startsWith('ge.component_portion.no_usable_mass_equal_weight'),
      ),
    );
  });

  test('residence curve is finite, bounded, monotone, and complementary', () {
    final profile = profileFor([
      component(id: 'solid', form: MealPhysicalForm.solid, portionGrams: 120),
      component(id: 'liquid', form: MealPhysicalForm.liquid, portionGrams: 240),
    ]);

    var previousRemaining = 1.0;
    for (var minute = 0; minute <= 720; minute++) {
      final remaining = profile.remainingFractionAt(minute);
      final emptied = profile.emptiedFractionAt(minute);
      expect(remaining.isFinite, isTrue, reason: 'minute=$minute');
      expect(emptied.isFinite, isTrue, reason: 'minute=$minute');
      expect(remaining, inInclusiveRange(0.0, 1.0), reason: 'minute=$minute');
      expect(emptied, inInclusiveRange(0.0, 1.0), reason: 'minute=$minute');
      expect(
        remaining,
        lessThanOrEqualTo(previousRemaining + 1e-12),
        reason: 'minute=$minute',
      );
      expect(remaining + emptied, closeTo(1.0, 1e-12));
      previousRemaining = remaining;
    }
  });

  test('sensitivity envelope remains ordered around the central curve', () {
    final profile = profileFor([
      component(id: 'solid', form: MealPhysicalForm.solid, portionGrams: 120),
      component(id: 'liquid', form: MealPhysicalForm.liquid, portionGrams: 240),
    ]);

    for (var minute = 0; minute <= 720; minute += 5) {
      final central = profile.remainingFractionAt(minute);
      final envelope = profile.sensitivityEnvelopeAt(minute);
      expect(
        envelope.fasterRemaining,
        lessThanOrEqualTo(central + 1e-12),
        reason: 'minute=$minute',
      );
      expect(
        envelope.slowerRemaining,
        greaterThanOrEqualTo(central - 1e-12),
        reason: 'minute=$minute',
      );
    }
  });

  test(
    'discrete intestinal-arrival rate conserves cumulative emptied mass',
    () {
      final profile = profileFor([
        component(id: 'solid', form: MealPhysicalForm.solid, portionGrams: 120),
        component(
          id: 'liquid',
          form: MealPhysicalForm.liquid,
          portionGrams: 240,
        ),
      ]);

      var integratedArrival = 0.0;
      for (var minute = 0; minute <= 1440; minute++) {
        final rate = profile.intestinalArrivalRateAt(minute);
        expect(rate.isFinite, isTrue, reason: 'minute=$minute');
        expect(rate, inInclusiveRange(0.0, 1.0), reason: 'minute=$minute');
        integratedArrival += rate;
      }
      expect(integratedArrival, closeTo(profile.emptiedFractionAt(1440), 0.01));
    },
  );

  test('component order does not change aggregate gastric outputs', () {
    final components = [
      component(id: 'solid', form: MealPhysicalForm.solid, portionGrams: 120),
      component(id: 'liquid', form: MealPhysicalForm.liquid, portionGrams: 240),
      component(
        id: 'unknown',
        form: MealPhysicalForm.solid,
        portionGrams: null,
      ),
      component(id: 'zero', form: MealPhysicalForm.mixed, portionGrams: 0),
    ];
    final forward = profileFor(components);
    final reverse = profileFor(components.reversed.toList(growable: false));

    expect(
      forward.aggregateLagMinutes,
      closeTo(reverse.aggregateLagMinutes, 1e-12),
    );
    for (var minute = 0; minute <= 720; minute += 5) {
      expect(
        forward.remainingFractionAt(minute),
        closeTo(reverse.remainingFractionAt(minute), 1e-12),
        reason: 'minute=$minute',
      );
      expect(
        forward.intestinalArrivalRateAt(minute),
        closeTo(reverse.intestinalArrivalRateAt(minute), 1e-12),
        reason: 'minute=$minute',
      );
    }
  });
}
