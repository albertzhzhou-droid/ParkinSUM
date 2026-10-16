import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../entities/personal_observation.dart';
import '../entities/personal_log_view.dart';
import '../entities/timeline_event.dart';
import 'get_timeline_usecase.dart';
import 'personal_log_date_window_resolver.dart';

/// Immutable, nonserialized descriptive projection. Original rows are neither
/// changed nor supplemented, and these outputs are not recommendation inputs.
final class PersonalLogInsightsProjection {
  PersonalLogInsightsProjection({
    required this.window,
    required List<TimelineEvent> historical,
    required List<TimelineEvent> future,
    required List<LoggedProteinSample> protein,
    required this.knownMeanG,
  }) : historical = List.unmodifiable(historical),
       future = List.unmodifiable(future),
       protein = List.unmodifiable(protein);
  final ResolvedLogWindow window;
  final List<TimelineEvent> historical;
  final List<TimelineEvent> future;
  final List<LoggedProteinSample> protein;
  final double? knownMeanG;
  List<LoggedProteinSample> get knownProtein => protein
      .where((p) => p.status == LoggedProteinStatus.known)
      .toList(growable: false);
  int get unknownCount =>
      protein.where((p) => p.status == LoggedProteinStatus.unknown).length;
  int get invalidCount =>
      protein.where((p) => p.status == LoggedProteinStatus.invalid).length;
  int get reportedZeroCount => protein.where((p) => p.isReportedZero).length;
  int count(TimelineEventType type) =>
      historical.where((e) => e.type == type).length;
}

final class PersonalLogViewProjector {
  const PersonalLogViewProjector();

  PersonalLogInsightsProjection insights({
    required ResolvedLogWindow window,
    required List<Meal> meals,
    required List<Intake> intakes,
    required List<PersonalObservation> observations,
    required List<FoodItem> foods,
    required List<DrugDefinition> medications,
  }) {
    final events = GetTimelineUseCase()(
      meals: meals,
      intakes: intakes,
      observations: observations,
      medications: medications,
    );
    final selected = events.where((e) => window.contains(e.time));
    final historical = selected.where((e) => !window.isFuture(e.time)).toList();
    final future = selected.where((e) => window.isFuture(e.time)).toList();
    final catalog = {for (final food in foods) food.id: food};
    final samples = <LoggedProteinSample>[];
    for (final meal in meals) {
      if (!window.contains(meal.effectiveOccurredAt) ||
          window.isFuture(meal.effectiveOccurredAt)) {
        continue;
      }
      String? reason;
      var status = LoggedProteinStatus.known;
      if (meal.items.isEmpty ||
          meal.items.any(
            (item) =>
                item.isNutrientMissing('proteinG') ||
                catalog[item.foodId]?.isNutrientMissing('proteinG') == true,
          )) {
        status = LoggedProteinStatus.unknown;
        reason = meal.items.isEmpty ? 'empty_meal' : 'protein_source_missing';
      } else if (meal.items.any(
        (item) =>
            !item.proteinPer100g.isFinite ||
            item.proteinPer100g < 0 ||
            !item.quantityFactor.isFinite ||
            item.quantityFactor <= 0,
      )) {
        status = LoggedProteinStatus.invalid;
        reason = 'invalid_protein_or_quantity';
      }
      // Preserve the existing complete-meal arithmetic. Restrict the catalogue
      // to referenced IDs to avoid rebuilding an entire catalogue per meal.
      final referenced = {for (final item in meal.items) item.foodId};
      final value = status == LoggedProteinStatus.known
          ? meal.knownNutrientTotal(
              'proteinG',
              catalog: [
                for (final id in referenced)
                  if (catalog[id] != null) catalog[id]!,
              ],
            )
          : null;
      if (status == LoggedProteinStatus.known && value == null) {
        status = LoggedProteinStatus.invalid;
        reason = 'invalid_protein_total';
      }
      samples.add(
        LoggedProteinSample(
          record: TypedLogRecordRef(TimelineEventType.meal, meal.id),
          time: meal.effectiveOccurredAt,
          status: status,
          valueG: value,
          reason: reason,
        ),
      );
    }
    samples.sort((a, b) {
      final time = a.time.compareTo(b.time);
      return time != 0 ? time : a.record.recordId.compareTo(b.record.recordId);
    });
    final known = samples
        .where((p) => p.status == LoggedProteinStatus.known)
        .toList();
    double? mean;
    if (known.isNotEmpty) {
      final sum = known.fold<double>(0, (sum, p) => sum + p.valueG!);
      mean = sum.isFinite
          ? sum / known.length
          : known.fold<double>(0, (sum, p) => sum + p.valueG! / known.length);
    }
    return PersonalLogInsightsProjection(
      window: window,
      historical: historical,
      future: future,
      protein: samples,
      knownMeanG: mean,
    );
  }

  TimelineViewProjection timeline({
    required List<TimelineEvent> fullEvents,
    required List<Meal> meals,
    required List<Intake> intakes,
    required List<PersonalObservation> observations,
    required List<FoodItem> foods,
    required List<DrugDefinition> medications,
    required TimelineViewQuery query,
    TypedLogRecordRef? focus,
  }) {
    final mealById = {for (final m in meals) m.id: m};
    final intakeById = {for (final i in intakes) i.id: i};
    final observationById = {for (final o in observations) o.id: o};
    final foodById = {for (final f in foods) f.id: f};
    final medicationById = {for (final m in medications) m.id: m};
    final facets = <String, TimelineSourceFacet>{};
    final sourcesByRecord = <TypedLogRecordRef, Set<String>>{};
    final unconfirmed = <TypedLogRecordRef>{};
    final filtered = <TimelineEvent>[];
    final needle = query.name.trim().toLowerCase();
    for (final event in fullEvents) {
      final ref = TypedLogRecordRef.fromEvent(event);
      final sources = <String>{};
      final names = <String>[event.title];
      void catalogSource(String? source) {
        if (source == null || source.trim().isEmpty) {
          sources.add('unconfirmed');
          unconfirmed.add(ref);
          return;
        }
        final id = 'catalog:$source';
        facets[id] = TimelineSourceFacet(
          id: id,
          value: source,
          isCurrentCatalog: true,
          isUnconfirmed: false,
        );
        sources.add(id);
      }

      switch (event.type) {
        case TimelineEventType.meal:
          final meal = mealById[event.recordId];
          if (meal == null || meal.items.isEmpty) catalogSource(null);
          for (final item in meal?.items ?? <MealItem>[]) {
            names.add(item.foodName);
            catalogSource(foodById[item.foodId]?.sourceSystem);
          }
        case TimelineEventType.medication:
          final drug = medicationById[intakeById[event.recordId]?.drugId];
          names.addAll(drug?.brandNames ?? <String>[]);
          catalogSource(drug?.sourceSystem);
        case TimelineEventType.observation:
          final observation = observationById[event.recordId];
          if (observation == null) {
            sources.add('unconfirmed');
            unconfirmed.add(ref);
          } else {
            final id = 'observation:${observation.source.name}';
            facets[id] = TimelineSourceFacet(
              id: id,
              value: observation.source.name,
              isCurrentCatalog: false,
              isUnconfirmed: false,
            );
            sources.add(id);
          }
      }
      sourcesByRecord[ref] = Set.unmodifiable(sources);
      if (query.window != null && !query.window!.contains(event.time)) continue;
      if (query.types.isNotEmpty && !query.types.contains(event.type)) continue;
      if (needle.isNotEmpty &&
          !names.any((name) => name.toLowerCase().contains(needle))) {
        continue;
      }
      if (query.sources.isNotEmpty && !sources.any(query.sources.contains)) {
        continue;
      }
      filtered.add(event);
    }
    if (unconfirmed.isNotEmpty) {
      facets['unconfirmed'] = const TimelineSourceFacet(
        id: 'unconfirmed',
        value: 'unconfirmed',
        isCurrentCatalog: false,
        isUnconfirmed: true,
      );
    }
    final matching = focus == null
        ? <TimelineEvent>[]
        : fullEvents
              .where((e) => TypedLogRecordRef.fromEvent(e) == focus)
              .toList();
    final focusStatus = focus == null
        ? TimelineFocusStatus.none
        : matching.isEmpty
        ? TimelineFocusStatus.unavailable
        : matching.length > 1
        ? TimelineFocusStatus.ambiguous
        : !filtered.any((e) => TypedLogRecordRef.fromEvent(e) == focus)
        ? TimelineFocusStatus.hiddenByFilters
        : TimelineFocusStatus.found;
    return TimelineViewProjection(
      filtered: filtered,
      visible: focus == null
          ? filtered
          : focusStatus == TimelineFocusStatus.found
          ? matching
          : const [],
      sources: facets.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
      sourcesByRecord: sourcesByRecord,
      unconfirmed: unconfirmed,
      focusStatus: focusStatus,
    );
  }
}

final class TimelineViewProjection {
  TimelineViewProjection({
    required List<TimelineEvent> filtered,
    required List<TimelineEvent> visible,
    required List<TimelineSourceFacet> sources,
    required Map<TypedLogRecordRef, Set<String>> sourcesByRecord,
    required Set<TypedLogRecordRef> unconfirmed,
    required this.focusStatus,
  }) : filtered = List.unmodifiable(filtered),
       visible = List.unmodifiable(visible),
       sources = List.unmodifiable(sources),
       sourcesByRecord = Map.unmodifiable(sourcesByRecord),
       unconfirmed = Set.unmodifiable(unconfirmed);
  final List<TimelineEvent> filtered;
  final List<TimelineEvent> visible;
  final List<TimelineSourceFacet> sources;
  final Map<TypedLogRecordRef, Set<String>> sourcesByRecord;
  final Set<TypedLogRecordRef> unconfirmed;
  final TimelineFocusStatus focusStatus;
}

/// Useful for both day buckets and time-of-day summaries: device local time
/// never enters a declared-zone calendar projection.
DateTime logDisplayTime(DateTime time, String zoneId) =>
    PersonalLogDateWindowResolver().displayTime(time, zoneId);
