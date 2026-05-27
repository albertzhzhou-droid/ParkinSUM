import '../entities/medication_entry_validation.dart';
import '../entities/time_axis_events.dart';

/// Pure builder for `TimeAxisConflictContext`. Deterministic, no I/O. The
/// engine never invents missing timestamps — events without a timestamp are
/// omitted and recorded in `missingFields`.
class TimeAxisBuilder {
  TimeAxisConflictContext build({
    required DateTime now,
    required List<MedicationTimelineInput> medicationInputs,
    required List<MealTimelineInput> mealInputs,
    UserDefinedMealWindow? userDefinedWindow,
  }) {
    final missingFields = <String>{};
    final medEvents = <MedicationTimelineEvent>[];
    final mealEvents = <MealTimelineEvent>[];
    final foodCompEvents = <FoodComponentTimelineEvent>[];

    for (final input in medicationInputs) {
      if (input.takenAt == null) {
        missingFields.add('medication.taken_at(${input.id})');
        continue;
      }
      if (!input.medicationContext.eligibleForRuleEvaluation) {
        missingFields.add('medication.invalid_context(${input.id})');
        continue;
      }
      medEvents.add(MedicationTimelineEvent(
        id: input.id,
        minute: dateTimeToMinute(input.takenAt!),
        context: input.medicationContext.normalized!,
      ));
    }

    for (final input in mealInputs) {
      if (input.startedAt == null) {
        missingFields.add('meal.started_at(${input.id})');
        continue;
      }
      mealEvents.add(MealTimelineEvent(
        id: input.id,
        minute: dateTimeToMinute(input.startedAt!),
        compositionId: input.compositionId,
        durationMinutes: input.durationMinutes,
        physicalForm: input.physicalForm,
      ));
      for (final c in input.componentEvents) {
        foodCompEvents.add(c);
      }
    }

    return TimeAxisConflictContext(
      referenceMinute: dateTimeToMinute(now),
      medicationEvents: medEvents,
      mealEvents: mealEvents,
      foodComponentEvents: foodCompEvents,
      userDefinedWindow: userDefinedWindow,
      missingFields: missingFields,
    );
  }
}

/// Input shape for medication events; carries the *validation result* so
/// invalid contexts surface as `missing_fields` rather than poisoned data.
class MedicationTimelineInput {
  final String id;
  final DateTime? takenAt;
  final MedicationContextValidationResult medicationContext;

  const MedicationTimelineInput({
    required this.id,
    required this.takenAt,
    required this.medicationContext,
  });
}

/// Input shape for meal events. `compositionId` references a separately
/// normalized `MealComposition` so the time-axis layer stays composition-free.
class MealTimelineInput {
  final String id;
  final DateTime? startedAt;
  final String compositionId;
  final int durationMinutes;
  final MealPhysicalForm physicalForm;
  final List<FoodComponentTimelineEvent> componentEvents;

  const MealTimelineInput({
    required this.id,
    required this.startedAt,
    required this.compositionId,
    this.durationMinutes = 15,
    this.physicalForm = MealPhysicalForm.unknown,
    this.componentEvents = const [],
  });
}
