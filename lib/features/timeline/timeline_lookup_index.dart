import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../domain/entities/timeline_event.dart';

/// Per-build lookup tables for the timeline.
///
/// [events] is already reverse-chronological (the contract of
/// `GetTimelineUseCase`). A two-pointer sweep therefore resolves both sets of
/// cross-type nearest neighbours in O(events + meals + intakes), without a
/// full-list scan for every rendered row. Equal-distance ties prefer the
/// earlier record, which is deterministic and conservative for context shown
/// around a later event.
class TimelineLookupIndex {
  TimelineLookupIndex({
    required List<TimelineEvent> events,
    required List<Meal> meals,
    required List<Intake> intakes,
  }) : _mealById = <String, Meal>{for (final meal in meals) meal.id: meal},
       _intakeById = <String, Intake>{
         for (final intake in intakes) intake.id: intake,
       } {
    final orderedMeals = <Meal>[];
    final orderedIntakes = <Intake>[];
    final seenMealIds = <String>{};
    final seenIntakeIds = <String>{};
    for (final event in events) {
      switch (event.type) {
        case TimelineEventType.meal:
          final meal = _mealById[event.recordId];
          if (meal != null && seenMealIds.add(meal.id)) {
            orderedMeals.add(meal);
          }
        case TimelineEventType.medication:
          final intake = _intakeById[event.recordId];
          if (intake != null && seenIntakeIds.add(intake.id)) {
            orderedIntakes.add(intake);
          }
      }
    }

    _nearestIntakeByMealId = _nearestByTime<Meal, Intake>(
      left: orderedMeals,
      right: orderedIntakes,
      leftId: (meal) => meal.id,
      leftTime: (meal) => meal.effectiveOccurredAt,
      rightTime: (intake) => intake.takenAt,
    );
    _nearestMealByIntakeId = _nearestByTime<Intake, Meal>(
      left: orderedIntakes,
      right: orderedMeals,
      leftId: (intake) => intake.id,
      leftTime: (intake) => intake.takenAt,
      rightTime: (meal) => meal.effectiveOccurredAt,
    );
  }

  final Map<String, Meal> _mealById;
  final Map<String, Intake> _intakeById;
  late final Map<String, Intake> _nearestIntakeByMealId;
  late final Map<String, Meal> _nearestMealByIntakeId;

  Meal? mealForEvent(TimelineEvent event) => _mealById[event.recordId];

  Intake? intakeForEvent(TimelineEvent event) => _intakeById[event.recordId];

  Intake? nearestIntakeForMeal(Meal meal) => _nearestIntakeByMealId[meal.id];

  Meal? nearestMealForIntake(Intake intake) =>
      _nearestMealByIntakeId[intake.id];

  static Map<String, R> _nearestByTime<L, R>({
    required List<L> left,
    required List<R> right,
    required String Function(L value) leftId,
    required DateTime Function(L value) leftTime,
    required DateTime Function(R value) rightTime,
  }) {
    if (right.isEmpty) return <String, R>{};
    final nearest = <String, R>{};
    var rightIndex = 0;
    for (final value in left) {
      final time = leftTime(value);
      while (rightIndex + 1 < right.length) {
        final currentDistance = rightTime(
          right[rightIndex],
        ).difference(time).abs();
        final nextDistance = rightTime(
          right[rightIndex + 1],
        ).difference(time).abs();
        if (nextDistance > currentDistance) break;
        rightIndex += 1;
      }
      nearest[leftId(value)] = right[rightIndex];
    }
    return nearest;
  }
}
