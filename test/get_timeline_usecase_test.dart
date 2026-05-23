import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/domain/usecases/get_timeline_usecase.dart';

void main() {
  test('combines meals and intakes in reverse chronological order', () {
    final useCase = GetTimelineUseCase();
    final meal = Meal(
      id: 'meal_1',
      eatenAt: DateTime.utc(2026, 4, 16, 12),
      title: 'Lunch',
      items: [
        MealItem(
          foodId: 'rice',
          foodName: 'Rice',
          foodCategory: FoodCategory.carbs,
          quantityFactor: 1,
          foodTags: const [],
          proteinPer100g: 2.7,
          carbsPer100g: 28,
          fatPer100g: 0.3,
          fiberPer100g: 0.4,
          sodiumPer100g: 1,
        ),
      ],
    );
    final intake = Intake(
      id: 'intake_1',
      drugId: 'drug_levodopa',
      takenAt: DateTime.utc(2026, 4, 16, 13),
      dosageNote: '25/100 mg',
    );

    final events = useCase(
      meals: [meal],
      intakes: [intake],
      medications: [
        DrugDefinition(
          id: 'drug_levodopa',
          genericName: 'Levodopa/carbidopa',
          brandNames: const [],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
    );

    expect(events, hasLength(2));
    expect(events.first.type, TimelineEventType.medication);
    expect(events.first.recordId, 'intake_1');
    expect(events.first.entityId, 'drug_levodopa');
    expect(events.first.title, 'Levodopa/carbidopa');
    expect(events.last.type, TimelineEventType.meal);
    expect(events.last.recordId, 'meal_1');
  });

  test('uses meal effective occurred time for ordering', () {
    final useCase = GetTimelineUseCase();
    final meal = Meal(
      id: 'meal_interval',
      eatenAt: DateTime.utc(2026, 4, 16, 18),
      occurredRangeStart: DateTime.utc(2026, 4, 16, 10),
      occurredRangeEnd: DateTime.utc(2026, 4, 16, 10, 30),
      timePrecision: 'interval',
      title: 'Approx meal',
      items: const [],
    );
    final intake = Intake(
      id: 'intake_early',
      drugId: 'drug_unknown',
      takenAt: DateTime.utc(2026, 4, 16, 11),
      dosageNote: '',
    );

    final events = useCase(
      meals: [meal],
      intakes: [intake],
      medications: const [],
    );

    expect(events.first.recordId, 'intake_early');
    expect(events.last.recordId, 'meal_interval');
  });
}
