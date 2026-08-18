import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/domain/usecases/get_timeline_usecase.dart';
import 'package:parkinsum_companion/features/timeline/timeline_lookup_index.dart';

void main() {
  test('resolves records and both nearest-neighbour directions', () {
    final meals = <Meal>[_meal('meal_12', 12), _meal('meal_20', 20)];
    final intakes = <Intake>[
      _intake('intake_13', 13),
      _intake('intake_21', 21),
      _intake('intake_11', 11),
      _intake('intake_19', 19),
    ];
    final events = GetTimelineUseCase()(
      meals: meals,
      intakes: intakes,
      medications: const [],
    );
    final lookup = TimelineLookupIndex(
      events: events,
      meals: meals,
      intakes: intakes,
    );

    final mealEvent = events.firstWhere((event) => event.recordId == 'meal_12');
    final intakeEvent = events.firstWhere(
      (event) => event.recordId == 'intake_19',
    );
    expect(lookup.mealForEvent(mealEvent)?.id, 'meal_12');
    expect(lookup.intakeForEvent(intakeEvent)?.id, 'intake_19');

    // 11:00 and 13:00 are equidistant from noon; the documented tie-break
    // prefers the earlier record.
    expect(lookup.nearestIntakeForMeal(meals[0])?.id, 'intake_11');
    expect(lookup.nearestIntakeForMeal(meals[1])?.id, 'intake_19');
    expect(lookup.nearestMealForIntake(intakes[0])?.id, 'meal_12');
    expect(lookup.nearestMealForIntake(intakes[1])?.id, 'meal_20');
  });

  test('matches brute-force nearest results across a large timeline', () {
    final meals = <Meal>[
      for (var index = 0; index < 120; index++) _meal('meal_$index', index * 4),
    ];
    final intakes = <Intake>[
      for (var index = 0; index < 140; index++)
        _intake('intake_$index', index * 4 + 1),
    ];
    final events = GetTimelineUseCase()(
      meals: meals,
      intakes: intakes,
      medications: const [],
    );
    final lookup = TimelineLookupIndex(
      events: events,
      meals: meals.reversed.toList(),
      intakes: intakes.reversed.toList(),
    );

    for (final meal in meals) {
      expect(
        lookup.nearestIntakeForMeal(meal)?.id,
        _bruteNearestIntake(meal, intakes).id,
      );
    }
    for (final intake in intakes) {
      expect(
        lookup.nearestMealForIntake(intake)?.id,
        _bruteNearestMeal(intake, meals).id,
      );
    }
  });

  test('returns null when the opposite event type is absent', () {
    final meal = _meal('only_meal', 12);
    final event = TimelineEvent.fromMeal(meal);
    final lookup = TimelineLookupIndex(
      events: <TimelineEvent>[event],
      meals: <Meal>[meal],
      intakes: const <Intake>[],
    );

    expect(lookup.mealForEvent(event), same(meal));
    expect(lookup.nearestIntakeForMeal(meal), isNull);
  });
}

Meal _meal(String id, int hourOffset) {
  return Meal(
    id: id,
    eatenAt: DateTime.utc(2026, 1, 1).add(Duration(hours: hourOffset)),
    title: id,
    items: const [],
  );
}

Intake _intake(String id, int hourOffset) {
  return Intake(
    id: id,
    drugId: 'drug',
    takenAt: DateTime.utc(2026, 1, 1).add(Duration(hours: hourOffset)),
    dosageNote: '',
  );
}

Intake _bruteNearestIntake(Meal meal, List<Intake> intakes) {
  return intakes.reduce((best, candidate) {
    final bestDistance = best.takenAt
        .difference(meal.effectiveOccurredAt)
        .abs();
    final candidateDistance = candidate.takenAt
        .difference(meal.effectiveOccurredAt)
        .abs();
    return candidateDistance < bestDistance ? candidate : best;
  });
}

Meal _bruteNearestMeal(Intake intake, List<Meal> meals) {
  return meals.reduce((best, candidate) {
    final bestDistance = best.effectiveOccurredAt
        .difference(intake.takenAt)
        .abs();
    final candidateDistance = candidate.effectiveOccurredAt
        .difference(intake.takenAt)
        .abs();
    return candidateDistance < bestDistance ? candidate : best;
  });
}
