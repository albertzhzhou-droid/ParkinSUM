import 'personal_log_view.dart';
import 'personal_observation.dart';

/// Display filters for the meal-protein count. A filter chooses which logged
/// meals are counted; none of them is a target or a limit.
const diaryProteinFilterOptionsG = [10, 15, 20, 30];
const diaryDefaultProteinFilterG = 15;

/// One logged medication intake placed on a 24-hour axis. The dose is the
/// text as entered (or the explicit amount and unit); it is never parsed,
/// converted or completed. Null means no dose was recorded or it was omitted.
final class DiaryDoseMark {
  const DiaryDoseMark({
    required this.recordId,
    required this.time,
    required this.minuteOfDay,
    required this.medicationName,
    required this.doseText,
  });
  final String recordId;
  final DateTime time;
  final int minuteOfDay;
  final String medicationName;
  final String? doseText;
}

/// One logged meal. Protein keeps the Insights status: unknown or invalid
/// meals carry no number and are never shown as zero.
final class DiaryMealMark {
  const DiaryMealMark({
    required this.recordId,
    required this.time,
    required this.minuteOfDay,
    required this.title,
    required this.proteinStatus,
    required this.proteinG,
  });
  final String recordId;
  final DateTime time;
  final int minuteOfDay;
  final String title;
  final LoggedProteinStatus proteinStatus;
  final double? proteinG;
  bool get hasKnownProtein =>
      proteinStatus == LoggedProteinStatus.known && proteinG != null;
}

/// One self-reported motor-state entry. It is a point in time; nothing is
/// assumed about the state before or after it.
final class DiaryMotorMark {
  const DiaryMotorMark({
    required this.recordId,
    required this.time,
    required this.minuteOfDay,
    required this.state,
  });
  final String recordId;
  final DateTime time;
  final int minuteOfDay;
  final SelfReportedMotorState state;
}

/// One civil day in the declared zone with its three lanes in time order.
final class DiaryDay {
  DiaryDay({
    required this.date,
    required List<DiaryDoseMark> doses,
    required List<DiaryMealMark> meals,
    required List<DiaryMotorMark> motor,
    required this.motorWithoutState,
  }) : doses = List.unmodifiable(doses),
       meals = List.unmodifiable(meals),
       motor = List.unmodifiable(motor);
  final LogCivilDate date;
  final List<DiaryDoseMark> doses;
  final List<DiaryMealMark> meals;
  final List<DiaryMotorMark> motor;

  /// Motor-state entries saved as unknown or not measured; not drawn.
  final int motorWithoutState;
  bool get isEmpty =>
      doses.isEmpty && meals.isEmpty && motor.isEmpty && motorWithoutState == 0;
  int motorCount(SelfReportedMotorState state) =>
      motor.where((mark) => mark.state == state).length;
}

/// Counts of one motor state across the shown days. [afterFilteredMeal]
/// entries had a meal with known protein at or above the display filter in
/// the lookback before them; [unclassified] had none, but a meal with unknown
/// or invalid protein in that lookback, so they cannot be counted either way.
final class DiaryMotorCount {
  const DiaryMotorCount({
    required this.state,
    required this.total,
    required this.afterFilteredMeal,
    required this.unclassified,
  });
  final SelfReportedMotorState state;
  final int total;
  final int afterFilteredMeal;
  final int unclassified;
}

/// Display-only projection of stored records. It is not serialized, not a
/// recommendation input and makes no causal, predictive or clinical claim.
final class DiaryStripProjection {
  DiaryStripProjection({
    required this.zoneId,
    required List<DiaryDay> days,
    required this.proteinFilterG,
    required this.lookbackHours,
    required List<DiaryMotorCount> counts,
    required this.futureRecordCount,
  }) : days = List.unmodifiable(days),
       counts = List.unmodifiable(counts) {
    if (days.isEmpty) throw ArgumentError('A diary needs at least one day.');
  }
  final String zoneId;

  /// Ascending by date.
  final List<DiaryDay> days;
  final int proteinFilterG;
  final int lookbackHours;

  /// OFF, ON, uncertain — in that order.
  final List<DiaryMotorCount> counts;

  /// Records dated after the projection time; excluded from every lane.
  final int futureRecordCount;
  LogCivilDate get start => days.first.date;
  LogCivilDate get end => days.last.date;
  DiaryMotorCount count(SelfReportedMotorState state) =>
      counts.firstWhere((count) => count.state == state);
}
