import '../entities/personal_observation.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../entities/timeline_event.dart';

class GetTimelineUseCase {
  List<TimelineEvent> call({
    required List<Meal> meals,
    required List<Intake> intakes,
    required List<DrugDefinition> medications,
    List<PersonalObservation> observations = const [],
  }) {
    final labelById = {
      for (final medication in medications)
        medication.id: medication.displayName,
    };

    final events = <TimelineEvent>[
      ...observations.map(TimelineEvent.fromObservation),
      ...meals.map(TimelineEvent.fromMeal),
      ...intakes.map(
        (intake) => TimelineEvent.fromIntake(
          intake: intake,
          label: labelById[intake.drugId] ?? intake.drugId,
        ),
      ),
    ];

    events.sort((a, b) {
      final date = b.time.compareTo(a.time);
      if (date != 0) return date;
      final type = a.type.index.compareTo(b.type.index);
      return type == 0 ? a.recordId.compareTo(b.recordId) : type;
    });
    return events;
  }
}
