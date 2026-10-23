import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../entities/personal_diary_strip.dart';
import '../entities/personal_log_view.dart';
import '../entities/personal_observation.dart';
import 'personal_log_date_window_resolver.dart';
import 'personal_log_view_projector.dart';

/// Lays stored intakes, meals and self-reported motor states on a 24-hour axis
/// per civil day in the declared zone, and counts motor-state entries that
/// were recorded after a meal. Descriptive only: no record is changed or
/// supplemented, no missing protein becomes zero, and nothing here is a cause,
/// prediction, target or clinical assessment.
final class PersonalDiaryStripProjector {
  const PersonalDiaryStripProjector();

  static const proteinFilterOptionsG = diaryProteinFilterOptionsG;
  static const defaultProteinFilterG = diaryDefaultProteinFilterG;
  static const lookbackHours = 3;
  static const maxDays = 31;

  DiaryStripProjection project({
    required LogCivilDate endDay,
    required int dayCount,
    required String zoneId,
    required DateTime asOf,
    required List<Meal> meals,
    required List<Intake> intakes,
    required List<PersonalObservation> observations,
    required List<FoodItem> foods,
    required List<DrugDefinition> medications,
    int proteinFilterG = defaultProteinFilterG,
    PersonalLogDateWindowResolver? resolver,
  }) {
    if (dayCount < 1 || dayCount > maxDays) {
      throw ArgumentError('Diary day count is out of range.');
    }
    if (!proteinFilterOptionsG.contains(proteinFilterG)) {
      throw ArgumentError('Unsupported protein display filter.');
    }
    final calendar = resolver ?? PersonalLogDateWindowResolver();
    final start = endDay.addDays(-dayCount + 1);
    final window = calendar.resolve(
      PersonalLogDateWindow(start: start, endInclusive: endDay, zoneId: zoneId),
      asOf: asOf,
    );
    // One extra day so a motor entry just after midnight still sees the
    // previous evening's meals in its lookback.
    final lookbackWindow = calendar.resolve(
      PersonalLogDateWindow(
        start: start.addDays(-1),
        endInclusive: endDay,
        zoneId: zoneId,
      ),
      asOf: asOf,
    );
    final protein = const PersonalLogViewProjector().insights(
      window: lookbackWindow,
      meals: meals,
      intakes: const [],
      observations: const [],
      foods: foods,
      medications: const [],
    );
    final proteinByMeal = {
      for (final sample in protein.protein) sample.record.recordId: sample,
    };
    final names = {for (final drug in medications) drug.id: drug.displayName};

    var future = 0;
    bool shown(DateTime time) {
      if (!window.contains(time)) return false;
      if (window.isFuture(time)) {
        future++;
        return false;
      }
      return true;
    }

    final local = <String, _DayLanes>{};
    _DayLanes lanesAt(DateTime time) {
      final day = calendar.dateAt(time, zoneId);
      return local.putIfAbsent('$day', () => _DayLanes());
    }

    int minuteOfDay(DateTime time) {
      final value = calendar.displayTime(time, zoneId);
      return value.hour * 60 + value.minute;
    }

    for (final intake in intakes) {
      if (!shown(intake.takenAt)) continue;
      final dose = intake.doseDisplayText.trim();
      lanesAt(intake.takenAt).doses.add(
        DiaryDoseMark(
          recordId: intake.id,
          time: intake.takenAt.toUtc(),
          minuteOfDay: minuteOfDay(intake.takenAt),
          medicationName: names[intake.drugId] ?? intake.drugId,
          doseText: dose.isEmpty ? null : dose,
        ),
      );
    }
    for (final meal in meals) {
      final time = meal.effectiveOccurredAt;
      if (!shown(time)) continue;
      final sample = proteinByMeal[meal.id];
      lanesAt(time).meals.add(
        DiaryMealMark(
          recordId: meal.id,
          time: time.toUtc(),
          minuteOfDay: minuteOfDay(time),
          title: meal.title,
          proteinStatus: sample?.status ?? LoggedProteinStatus.unknown,
          proteinG: sample?.status == LoggedProteinStatus.known
              ? sample?.valueG
              : null,
        ),
      );
    }
    for (final observation in observations) {
      if (observation.kind != PersonalObservationKind.selfReportedMotorState ||
          !shown(observation.occurredAt)) {
        continue;
      }
      final lanes = lanesAt(observation.occurredAt);
      final state = observation.motorState;
      if (observation.status != PersonalObservationStatus.recorded ||
          state == null) {
        lanes.motorWithoutState++;
        continue;
      }
      lanes.motor.add(
        DiaryMotorMark(
          recordId: observation.id,
          time: observation.occurredAt.toUtc(),
          minuteOfDay: minuteOfDay(observation.occurredAt),
          state: state,
        ),
      );
    }

    int byTime(DateTime a, String aId, DateTime b, String bId) {
      final order = a.compareTo(b);
      return order != 0 ? order : aId.compareTo(bId);
    }

    final days = <DiaryDay>[];
    for (var offset = 0; offset < dayCount; offset++) {
      final date = start.addDays(offset);
      final lanes = local['$date'] ?? _DayLanes();
      days.add(
        DiaryDay(
          date: date,
          doses: lanes.doses
            ..sort((a, b) => byTime(a.time, a.recordId, b.time, b.recordId)),
          meals: lanes.meals
            ..sort((a, b) => byTime(a.time, a.recordId, b.time, b.recordId)),
          motor: lanes.motor
            ..sort((a, b) => byTime(a.time, a.recordId, b.time, b.recordId)),
          motorWithoutState: lanes.motorWithoutState,
        ),
      );
    }

    // Historical meals of the lookback window, with their protein status.
    final mealTimes = protein.protein;
    const lookback = Duration(hours: lookbackHours);
    final counts = <DiaryMotorCount>[];
    for (final state in const [
      SelfReportedMotorState.off,
      SelfReportedMotorState.on,
      SelfReportedMotorState.uncertain,
    ]) {
      var total = 0;
      var after = 0;
      var unclassified = 0;
      for (final day in days) {
        for (final mark in day.motor.where((mark) => mark.state == state)) {
          total++;
          final before = mealTimes.where((meal) {
            final gap = mark.time.difference(meal.time.toUtc());
            return gap > Duration.zero && gap <= lookback;
          });
          if (before.any(
            (meal) =>
                meal.status == LoggedProteinStatus.known &&
                meal.valueG != null &&
                meal.valueG! >= proteinFilterG,
          )) {
            after++;
          } else if (before.any(
            (meal) => meal.status != LoggedProteinStatus.known,
          )) {
            unclassified++;
          }
        }
      }
      counts.add(
        DiaryMotorCount(
          state: state,
          total: total,
          afterFilteredMeal: after,
          unclassified: unclassified,
        ),
      );
    }
    return DiaryStripProjection(
      zoneId: zoneId,
      days: days,
      proteinFilterG: proteinFilterG,
      lookbackHours: lookbackHours,
      counts: counts,
      futureRecordCount: future,
    );
  }
}

final class _DayLanes {
  final doses = <DiaryDoseMark>[];
  final meals = <DiaryMealMark>[];
  final motor = <DiaryMotorMark>[];
  var motorWithoutState = 0;
}
