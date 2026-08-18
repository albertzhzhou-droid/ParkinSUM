import '../entities/algorithm_component_identity_witness.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/time_axis_events.dart';

/// Pure builder for `TimeAxisConflictContext`. Deterministic, no I/O. The
/// engine never invents missing timestamps — events without a timestamp are
/// omitted and recorded in `missingFields`.
class TimeAxisBuilder with RegisteredAlgorithmComponentIdentity {
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

    String canonicalEventId(String id) => id.trim();
    Map<String, int> idCounts(Iterable<String> ids) {
      final counts = <String, int>{};
      for (final id in ids.map(canonicalEventId).where((id) => id.isNotEmpty)) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    }

    final medicationIdCounts = idCounts(
      medicationInputs.map((input) => input.id),
    );
    final mealIdCounts = idCounts(mealInputs.map((input) => input.id));
    final crossTypeCollisions = medicationIdCounts.keys
        .where(mealIdCounts.containsKey)
        .toSet();

    for (var index = 0; index < medicationInputs.length; index += 1) {
      final input = medicationInputs[index];
      final eventId = canonicalEventId(input.id);
      if (eventId.isEmpty) {
        missingFields.add('medication.event_id_empty(index=$index)');
        continue;
      }
      if ((medicationIdCounts[eventId] ?? 0) > 1) {
        missingFields.add('medication.event_id_duplicate($eventId)');
        continue;
      }
      if (crossTypeCollisions.contains(eventId)) {
        missingFields.add('timeline.event_id_collision($eventId)');
        continue;
      }
      if (input.takenAt == null) {
        missingFields.add('medication.taken_at($eventId)');
        continue;
      }
      if (!input.medicationContext.eligibleForRuleEvaluation) {
        missingFields.add('medication.invalid_context($eventId)');
        continue;
      }
      medEvents.add(
        MedicationTimelineEvent(
          id: eventId,
          minute: dateTimeToMinute(input.takenAt!),
          context: input.medicationContext.normalized!,
        ),
      );
    }

    for (var index = 0; index < mealInputs.length; index += 1) {
      final input = mealInputs[index];
      final eventId = canonicalEventId(input.id);
      if (eventId.isEmpty) {
        missingFields.add('meal.event_id_empty(index=$index)');
        continue;
      }
      if ((mealIdCounts[eventId] ?? 0) > 1) {
        missingFields.add('meal.event_id_duplicate($eventId)');
        continue;
      }
      if (crossTypeCollisions.contains(eventId)) {
        missingFields.add('timeline.event_id_collision($eventId)');
        continue;
      }
      if (input.startedAt == null) {
        missingFields.add('meal.started_at($eventId)');
        continue;
      }
      mealEvents.add(
        MealTimelineEvent(
          id: eventId,
          minute: dateTimeToMinute(input.startedAt!),
          compositionId: input.compositionId,
          durationMinutes: input.durationMinutes,
          physicalForm: input.physicalForm,
        ),
      );
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
