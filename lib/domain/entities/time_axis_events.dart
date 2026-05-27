/// Minute-resolution time-axis primitives used by the mechanistic conflict
/// engine.
///
/// All times are integer minutes-since-epoch (UTC). The engine never invents
/// times; if the upstream input is missing a timestamp, the corresponding
/// event is omitted and the resulting context widens its uncertainty.
library;

import 'medication_entry_validation.dart';

/// Kind of timeline event.
enum TimelineEventKind { medication, meal, foodComponent }

/// Physical form of a meal or food component.
enum MealPhysicalForm { solid, liquid, mixed, unknown }

/// Half-open window of minutes-since-epoch.
class TimelineWindow {
  final int startMinute;
  final int endMinute;

  const TimelineWindow({required this.startMinute, required this.endMinute})
      : assert(endMinute >= startMinute);

  int get durationMinutes => endMinute - startMinute;

  bool contains(int minute) => minute >= startMinute && minute < endMinute;

  bool overlaps(TimelineWindow other) =>
      startMinute < other.endMinute && other.startMinute < endMinute;

  Map<String, dynamic> toJson() => {
        'start_minute': startMinute,
        'end_minute': endMinute,
      };
}

/// A user-defined window inside which next-meal candidates may be scored.
/// The engine *never* picks the meal time; it only scores candidates against
/// what the user already provided.
class UserDefinedMealWindow {
  final TimelineWindow window;
  final String source; // e.g. "user_input", "synthetic_demo_fixture"

  const UserDefinedMealWindow({required this.window, required this.source});

  int get midpointMinute => (window.startMinute + window.endMinute) ~/ 2;

  Map<String, dynamic> toJson() => {
        'window': window.toJson(),
        'source': source,
      };
}

/// Base class for events placed on the model timeline.
abstract class TimelineEvent {
  final String id;
  final int minute;
  final TimelineEventKind kind;
  const TimelineEvent({
    required this.id,
    required this.minute,
    required this.kind,
  });

  Map<String, dynamic> toJson();
}

/// Medication event placed on the timeline. Only created from a validated
/// `NormalizedMedicationContext` — never from free-text input.
class MedicationTimelineEvent extends TimelineEvent {
  final NormalizedMedicationContext context;

  const MedicationTimelineEvent({
    required super.id,
    required super.minute,
    required this.context,
  }) : super(kind: TimelineEventKind.medication);

  String get releaseType => context.releaseType;
  String get route => context.route;
  bool get isLevodopaContext =>
      context.activeIngredients.any((i) => i.toLowerCase() == 'levodopa');

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'minute': minute,
        'kind': kind.name,
        'context': context.toJson(),
      };
}

/// Meal event placed on the timeline. Composition is normalized separately
/// (see `MealComposition`) and referenced by id.
class MealTimelineEvent extends TimelineEvent {
  final String compositionId;
  final int durationMinutes;
  final MealPhysicalForm physicalForm;

  const MealTimelineEvent({
    required super.id,
    required super.minute,
    required this.compositionId,
    this.durationMinutes = 15,
    this.physicalForm = MealPhysicalForm.unknown,
  }) : super(kind: TimelineEventKind.meal);

  TimelineWindow get span =>
      TimelineWindow(startMinute: minute, endMinute: minute + durationMinutes);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'minute': minute,
        'kind': kind.name,
        'composition_id': compositionId,
        'duration_minutes': durationMinutes,
        'physical_form': physicalForm.name,
      };
}

/// A single food component inside a mixed meal, when caller wants to model
/// per-component contributions (e.g. liquid coffee + solid toast).
class FoodComponentTimelineEvent extends TimelineEvent {
  final String parentMealId;
  final String foodComponentId;
  final MealPhysicalForm physicalForm;

  const FoodComponentTimelineEvent({
    required super.id,
    required super.minute,
    required this.parentMealId,
    required this.foodComponentId,
    required this.physicalForm,
  }) : super(kind: TimelineEventKind.foodComponent);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'minute': minute,
        'kind': kind.name,
        'parent_meal_id': parentMealId,
        'food_component_id': foodComponentId,
        'physical_form': physicalForm.name,
      };
}

/// Full context handed to the mechanistic conflict engine.
class TimeAxisConflictContext {
  final int referenceMinute;
  final List<MedicationTimelineEvent> medicationEvents;
  final List<MealTimelineEvent> mealEvents;
  final List<FoodComponentTimelineEvent> foodComponentEvents;
  final UserDefinedMealWindow? userDefinedWindow;
  final Set<String> missingFields;

  TimeAxisConflictContext({
    required this.referenceMinute,
    required List<MedicationTimelineEvent> medicationEvents,
    required List<MealTimelineEvent> mealEvents,
    List<FoodComponentTimelineEvent> foodComponentEvents = const [],
    this.userDefinedWindow,
    Set<String> missingFields = const {},
  })  : medicationEvents = List.unmodifiable([...medicationEvents]
          ..sort((a, b) => a.minute.compareTo(b.minute))),
        mealEvents = List.unmodifiable(
            [...mealEvents]..sort((a, b) => a.minute.compareTo(b.minute))),
        foodComponentEvents = List.unmodifiable([...foodComponentEvents]
          ..sort((a, b) => a.minute.compareTo(b.minute))),
        missingFields = Set.unmodifiable(missingFields);

  Map<String, dynamic> toJson() => {
        'reference_minute': referenceMinute,
        'medication_events':
            medicationEvents.map((e) => e.toJson()).toList(growable: false),
        'meal_events':
            mealEvents.map((e) => e.toJson()).toList(growable: false),
        'food_component_events':
            foodComponentEvents.map((e) => e.toJson()).toList(growable: false),
        'user_defined_window': userDefinedWindow?.toJson(),
        'missing_fields': missingFields.toList(growable: false),
      };
}

/// Convert a `DateTime` to canonical minute resolution. Always UTC-stable.
int dateTimeToMinute(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 60000;

/// Convert minute back to UTC DateTime.
DateTime minuteToDateTime(int minute) =>
    DateTime.fromMillisecondsSinceEpoch(minute * 60000, isUtc: true);
