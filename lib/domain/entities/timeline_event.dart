import '../../core/models/intake.dart';
import '../../core/models/meal.dart';

enum TimelineEventType { meal, medication }

class TimelineEvent {
  final DateTime time;
  final TimelineEventType type;
  final String recordId;
  final String? entityId;
  final String title;
  final String description;

  const TimelineEvent({
    required this.time,
    required this.type,
    required this.recordId,
    this.entityId,
    required this.title,
    required this.description,
  });

  factory TimelineEvent.fromMeal(Meal meal) {
    return TimelineEvent(
      // 时间轴应优先展示“实际发生时间”，而不是旧的兼容字段名。
      time: meal.effectiveOccurredAt,
      type: TimelineEventType.meal,
      recordId: meal.id,
      entityId: meal.id,
      title: meal.title,
      description: 'Meal · ${meal.items.length} items',
    );
  }

  factory TimelineEvent.fromIntake({
    required Intake intake,
    required String label,
  }) {
    return TimelineEvent(
      time: intake.takenAt,
      type: TimelineEventType.medication,
      recordId: intake.id,
      entityId: intake.drugId,
      title: label,
      description:
          'Medication · ${intake.dosageNote.isEmpty ? 'No dosage note' : intake.dosageNote}',
    );
  }
}
