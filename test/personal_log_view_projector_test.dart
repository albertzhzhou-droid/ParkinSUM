import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/domain/usecases/get_timeline_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_date_window_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_view_projector.dart';
import 'package:parkinsum_companion/features/timeline/timeline_lookup_index.dart';

FoodItem food(
  String id, {
  double protein = 20,
  Set<String> missing = const {},
  String source = 'Foundation',
}) => FoodItem(
  id: id,
  name: id,
  category: FoodCategory.other,
  sourceSystem: source,
  proteinG: protein,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
  missingNutrientFields: missing,
);

Meal meal(
  String id,
  DateTime time, {
  double protein = 20,
  Set<String> missing = const {},
  double quantity = 1,
  String foodId = 'known',
}) => Meal(
  id: id,
  title: id,
  eatenAt: time,
  items: [
    MealItem.fromFood(
      food: food(foodId, protein: protein, missing: missing),
      quantityFactor: quantity,
    ),
  ],
);

ResolvedLogWindow selected(
  int year,
  int month,
  int day, {
  DateTime? asOf,
  String zone = 'America/Toronto',
}) => PersonalLogDateWindowResolver().resolve(
  PersonalLogDateWindow(
    start: LogCivilDate(year, month, day),
    endInclusive: LogCivilDate(year, month, day),
    zoneId: zone,
  ),
  asOf: asOf ?? DateTime.utc(2030),
);

void main() {
  const projector = PersonalLogViewProjector();

  test(
    'Toronto spring and autumn civil days are independently 23 and 25 hours',
    () {
      final spring = selected(2026, 3, 8);
      expect(spring.startUtc, DateTime.utc(2026, 3, 8, 5));
      expect(spring.endUtcExclusive, DateTime.utc(2026, 3, 9, 4));
      expect(spring.endUtcExclusive.difference(spring.startUtc).inHours, 23);
      final autumn = selected(2026, 11, 1);
      expect(autumn.startUtc, DateTime.utc(2026, 11, 1, 4));
      expect(autumn.endUtcExclusive, DateTime.utc(2026, 11, 2, 5));
      expect(autumn.endUtcExclusive.difference(autumn.startUtc).inHours, 25);
    },
  );

  test(
    'both date boundaries, future asOf, and occurrence precedence are explicit',
    () {
      final window = selected(2026, 9, 30, asOf: DateTime.utc(2026, 9, 30, 12));
      final meals = [
        meal('before', DateTime.utc(2026, 9, 30, 3, 59)),
        meal('start', DateTime.utc(2026, 9, 30, 4), protein: 0),
        meal('asOf', DateTime.utc(2026, 9, 30, 12)),
        meal('future', DateTime.utc(2026, 9, 30, 12, 1)),
        meal('end', DateTime.utc(2026, 10, 1, 4)),
        meal(
          'moved',
          DateTime.utc(2026, 10, 1, 6),
        ).copyWith(occurredAt: DateTime.utc(2026, 9, 30, 10)),
      ];
      final result = projector.insights(
        window: window,
        meals: meals,
        intakes: [],
        observations: [],
        foods: [food('known')],
        medications: [],
      );
      expect(result.historical.map((e) => e.recordId), [
        'asOf',
        'moved',
        'start',
      ]);
      expect(result.future.map((e) => e.recordId), ['future']);
      expect(result.knownProtein.map((p) => p.record.recordId), [
        'start',
        'moved',
        'asOf',
      ]);
      expect(result.knownMeanG, closeTo(40 / 3, 1e-12));
      expect(result.reportedZeroCount, 1);
    },
  );

  test(
    'unknown numeric placeholders and invalid rows never enter the denominator',
    () {
      final time = DateTime.utc(2026, 9, 30, 10);
      final rows = [
        meal('zero', time, protein: 0),
        meal('known', time),
        meal('captured-missing', time, protein: 999, missing: {'proteinG'}),
        meal('catalog-missing', time, protein: 999, foodId: 'catalog-missing'),
        meal('negative', time, protein: -1),
        meal('nan', time, protein: double.nan),
        meal('infinity', time, protein: double.infinity),
        meal('zero-quantity', time, quantity: 0),
        meal('overflow', time, protein: double.maxFinite, quantity: 2),
        Meal(id: 'empty', title: 'empty', eatenAt: time, items: []),
      ];
      final result = projector.insights(
        window: selected(2026, 9, 30),
        meals: rows,
        intakes: [],
        observations: [],
        foods: [
          food('known'),
          food('catalog-missing', missing: {'proteinG'}),
        ],
        medications: [],
      );
      expect(result.knownMeanG, 10);
      expect(result.knownProtein.map((p) => p.record.recordId), [
        'known',
        'zero',
      ]);
      expect(result.unknownCount, 3);
      expect(result.invalidCount, 5);
      expect(
        result.protein
            .singleWhere((p) => p.record.recordId == 'captured-missing')
            .valueG,
        isNull,
      );
      expect(result.reportedZeroCount, 1);
    },
  );

  test('all unknown and future-only ranges have no numeric mean', () {
    final result = projector.insights(
      window: selected(2026, 9, 30, asOf: DateTime.utc(2026, 9, 30, 12)),
      meals: [
        meal('unknown', DateTime.utc(2026, 9, 30, 10), missing: {'proteinG'}),
        meal('future', DateTime.utc(2026, 9, 30, 18)),
      ],
      intakes: [],
      observations: [],
      foods: [],
      medications: [],
    );
    expect(result.knownMeanG, isNull);
    expect(result.knownProtein, isEmpty);
    expect(result.unknownCount, 1);
    expect(result.future, hasLength(1));
    expect(result.count(TimelineEventType.meal), 1);
  });

  test(
    'typed IDs do not collide across meal and intake, including 10k records',
    () {
      final rows = [
        for (var i = 0; i < 10000; i++)
          meal('record-$i', DateTime.utc(2026, 1, 1).add(Duration(minutes: i))),
      ];
      final intake = Intake(
        id: 'record-9999',
        drugId: 'unknown',
        takenAt: DateTime.utc(2026, 1, 9),
        dosageNote: '',
      );
      final events = GetTimelineUseCase()(
        meals: rows,
        intakes: [intake],
        medications: [],
      );
      final result = projector.timeline(
        fullEvents: events,
        meals: rows,
        intakes: [intake],
        observations: [],
        foods: [],
        medications: [],
        query: TimelineViewQuery(),
        focus: const TypedLogRecordRef(TimelineEventType.meal, 'record-9999'),
      );
      expect(result.filtered, hasLength(10001));
      expect(result.visible.single.type, TimelineEventType.meal);
      expect(result.visible.single.time, DateTime.utc(2026, 1, 7, 22, 39));
      expect(result.focusStatus, TimelineFocusStatus.found);
      expect(
        result.unconfirmed,
        contains(
          const TypedLogRecordRef(TimelineEventType.meal, 'record-9999'),
        ),
      );
    },
  );

  test(
    'view filters intersect dates, type, captured names and current catalogue source',
    () {
      final rows = [
        meal('breakfast', DateTime.utc(2026, 9, 30, 10), foodId: 'fruit'),
        meal('dinner', DateTime.utc(2026, 9, 30, 22), foodId: 'other'),
      ];
      final intake = Intake(
        id: 'med',
        drugId: 'drug',
        takenAt: DateTime.utc(2026, 9, 30, 11),
        dosageNote: '',
      );
      final events = GetTimelineUseCase()(
        meals: rows,
        intakes: [intake],
        medications: [],
      );
      final result = projector.timeline(
        fullEvents: events,
        meals: rows,
        intakes: [intake],
        observations: [],
        foods: [
          food('fruit', source: 'Ciqual'),
          food('other'),
        ],
        medications: [],
        query: TimelineViewQuery(
          window: selected(2026, 9, 30),
          types: {TimelineEventType.meal},
          name: 'FRUIT',
          sources: {'catalog:Ciqual'},
        ),
      );
      expect(result.visible.map((e) => e.recordId), ['breakfast']);
      expect(events, hasLength(3));
      expect(rows.first.items.single.foodName, 'fruit');
      expect(
        result.sources.any((s) => s.isCurrentCatalog && s.value == 'Ciqual'),
        isTrue,
      );
    },
  );

  test(
    'focus reports hidden, deleted and ambiguous identities without choosing a neighbour',
    () {
      final row = meal('target', DateTime.utc(2026, 9, 30, 10));
      TimelineViewProjection view(
        List<TimelineEvent> events,
        TimelineViewQuery query,
      ) => projector.timeline(
        fullEvents: events,
        meals: [row],
        intakes: [],
        observations: [],
        foods: [],
        medications: [],
        query: query,
        focus: const TypedLogRecordRef(TimelineEventType.meal, 'target'),
      );
      expect(
        view([
          TimelineEvent.fromMeal(row),
        ], TimelineViewQuery(name: 'absent')).focusStatus,
        TimelineFocusStatus.hiddenByFilters,
      );
      expect(
        view([], TimelineViewQuery()).focusStatus,
        TimelineFocusStatus.unavailable,
      );
      final duplicate = TimelineEvent.fromMeal(row);
      expect(
        view([duplicate, duplicate], TimelineViewQuery()).focusStatus,
        TimelineFocusStatus.ambiguous,
      );
      expect(
        view([duplicate, duplicate], TimelineViewQuery()).visible,
        isEmpty,
      );
    },
  );

  test(
    'nearest-context answers still use the full timeline after type filtering',
    () {
      final row = meal('meal', DateTime.utc(2026, 9, 30, 12));
      final intakes = [
        Intake(
          id: 'near',
          drugId: 'drug',
          takenAt: DateTime.utc(2026, 9, 30, 11),
          dosageNote: '',
        ),
        Intake(
          id: 'far',
          drugId: 'drug',
          takenAt: DateTime.utc(2026, 9, 30, 16),
          dosageNote: '',
        ),
      ];
      final full = GetTimelineUseCase()(
        meals: [row],
        intakes: intakes,
        medications: [],
      );
      final view = projector.timeline(
        fullEvents: full,
        meals: [row],
        intakes: intakes,
        observations: [],
        foods: [],
        medications: [],
        query: TimelineViewQuery(types: {TimelineEventType.meal}),
      );
      final lookup = TimelineLookupIndex(
        events: full,
        meals: [row],
        intakes: intakes,
      );
      expect(view.visible, hasLength(1));
      expect(lookup.nearestIntakeForMeal(row)?.id, 'near');
    },
  );

  test(
    'recorded observation sources remain distinct from unconfirmed catalogue sources',
    () {
      final row = meal('missing-catalog', DateTime.utc(2026, 9, 30, 10));
      final observation = PersonalObservation.create(
        id: 'observation',
        kind: PersonalObservationKind.symptom,
        occurredAt: DateTime.utc(2026, 9, 30, 11),
        recordedAt: DateTime.utc(2026, 9, 30, 11),
        originalTimezone: 'UTC',
        source: PersonalObservationSource.caregiverReported,
        recorderId: 'synthetic-owner',
        status: PersonalObservationStatus.unknown,
        symptomLabel: 'Unknown symptom',
      );
      final full = GetTimelineUseCase()(
        meals: [row],
        intakes: [],
        medications: [],
        observations: [observation],
      );
      final observed = projector.timeline(
        fullEvents: full,
        meals: [row],
        intakes: [],
        observations: [observation],
        foods: [],
        medications: [],
        query: TimelineViewQuery(sources: {'observation:caregiverReported'}),
      );
      expect(observed.visible.single.type, TimelineEventType.observation);
      expect(
        observed.sources
            .singleWhere((s) => s.id == 'observation:caregiverReported')
            .isCurrentCatalog,
        isFalse,
      );
      final absent = projector.timeline(
        fullEvents: full,
        meals: [row],
        intakes: [],
        observations: [observation],
        foods: [],
        medications: [],
        query: TimelineViewQuery(sources: {'unconfirmed'}),
      );
      expect(absent.visible.single.recordId, 'missing-catalog');
      expect(observation.status, PersonalObservationStatus.unknown);
    },
  );

  test(
    'unknown zones and nonexistent civil dates fail closed instead of device fallback',
    () {
      expect(
        () => selected(2026, 9, 30, zone: 'Unknown/Zone'),
        throwsFormatException,
      );
      expect(() => LogCivilDate(2026, 2, 30), throwsFormatException);
      expect(
        () => selected(2011, 12, 30, zone: 'Pacific/Apia'),
        throwsFormatException,
      );
      expect(
        () => PersonalLogDateWindow(
          start: LogCivilDate(2026, 10, 1),
          endInclusive: LogCivilDate(2026, 9, 30),
          zoneId: 'UTC',
        ),
        throwsFormatException,
      );
    },
  );
}
