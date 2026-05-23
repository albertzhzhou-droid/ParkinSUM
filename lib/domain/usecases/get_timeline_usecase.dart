import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../entities/timeline_event.dart';

class GetTimelineUseCase {
  List<TimelineEvent> call({
    required List<Meal> meals,
    required List<Intake> intakes,
    required List<DrugDefinition> medications,
  }) {
    final labelById = {
      for (final medication in medications)
        medication.id: medication.displayName,
    };

    final events = <TimelineEvent>[
      ...meals.map(TimelineEvent.fromMeal),
      ...intakes.map(
        (intake) => TimelineEvent.fromIntake(
          intake: intake,
          label: labelById[intake.drugId] ?? intake.drugId,
        ),
      ),
    ];

    events.sort((a, b) => b.time.compareTo(a.time));
    return events;
  }
}
