import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/mechanistic_candidate_score.dart';
import '../../domain/entities/next_meal_plan.dart';
import '../../domain/entities/next_meal_recommendation_models.dart';
import '../../domain/entities/personal_diary_strip.dart';
import '../../domain/usecases/next_meal_planner.dart';
import '../../domain/usecases/personal_diary_strip_projector.dart';
import '../../domain/usecases/personal_log_date_window_resolver.dart';
import '../entry/entry_page.dart';
import '../shared/mechanistic_trace_view.dart';
import 'next_meal_plate_chart.dart';
import 'next_meal_planner_widgets.dart';

/// Exact, one-to-one projection of model traces onto an id order. Missing,
/// duplicate, or extra ids are withheld rather than guessed into a position.
/// The planner's audit section uses it with foods sorted by name.
class MechanisticCandidateTraceAlignment {
  final List<MechanisticCandidateScore> alignedScores;
  final List<String> missingRecommendationIds;
  final List<String> withheldCandidateIds;

  MechanisticCandidateTraceAlignment({
    required List<MechanisticCandidateScore> alignedScores,
    required List<String> missingRecommendationIds,
    required List<String> withheldCandidateIds,
  }) : alignedScores = List.unmodifiable(alignedScores),
       missingRecommendationIds = List.unmodifiable(missingRecommendationIds),
       withheldCandidateIds = List.unmodifiable(withheldCandidateIds);

  bool get complete =>
      missingRecommendationIds.isEmpty && withheldCandidateIds.isEmpty;
}

MechanisticCandidateTraceAlignment alignMechanisticCandidateTraces({
  required List<String> recommendationFoodIds,
  required List<MechanisticCandidateScore> candidateScores,
}) {
  final recommendationCounts = <String, int>{};
  for (final id in recommendationFoodIds) {
    recommendationCounts[id] = (recommendationCounts[id] ?? 0) + 1;
  }
  final scoreBuckets = <String, List<MechanisticCandidateScore>>{};
  for (final score in candidateScores) {
    scoreBuckets.putIfAbsent(score.candidateFoodId, () => []).add(score);
  }

  final aligned = <MechanisticCandidateScore>[];
  final missing = <String>{};
  final matchedIds = <String>{};
  for (final id in recommendationFoodIds) {
    final matches = scoreBuckets[id] ?? const <MechanisticCandidateScore>[];
    if (recommendationCounts[id] == 1 && matches.length == 1) {
      aligned.add(matches.single);
      matchedIds.add(id);
    } else {
      missing.add(id);
    }
  }
  final withheld = <String>{
    for (final score in candidateScores)
      if (!matchedIds.contains(score.candidateFoodId)) score.candidateFoodId,
  };
  return MechanisticCandidateTraceAlignment(
    alignedScores: aligned,
    missingRecommendationIds: missing.toList(growable: false),
    withheldCandidateIds: withheld.toList(growable: false),
  );
}

/// Next-meal planner: pick a time, browse foods at a reference serving as
/// cards, build a plate and compare it with "no meal" in the physiology
/// reference model. The order of the food list is always the user's sort
/// choice (neutral by default), and nothing is called best or recommended.
/// Educational prototype; synthetic data in demos.
class NextMealPage extends StatefulWidget {
  const NextMealPage({super.key, this.clock, this.initialPlannedAt});

  /// Current time; injectable for tests and captures.
  final DateTime Function()? clock;

  /// Starting planned time; defaults to the current time (no suggested time).
  final DateTime? initialPlannedAt;

  @override
  State<NextMealPage> createState() => _NextMealPageState();
}

sealed class _Pinned {
  const _Pinned();
}

final class _PinnedFood extends _Pinned {
  const _PinnedFood(this.foodId);
  final String foodId;
}

final class _PinnedPlate extends _Pinned {
  const _PinnedPlate(this.number, this.items);
  final int number;
  final List<NextMealPlateItem> items;
}

class _NextMealPageState extends State<NextMealPage> {
  static const int _pageSize = 24;
  static const int _maxPinned = 3;

  final _resolver = PersonalLogDateWindowResolver();
  final _search = TextEditingController();
  late DateTime _plannedAt;
  NextMealSortKey _sort = NextMealSortKey.familiarThenName;
  bool _descending = false;
  NextMealFilter _filter = const NextMealFilter();
  bool _showFilters = false;
  int _visible = _pageSize;
  final List<NextMealPlateItem> _plate = [];
  final List<_Pinned> _pinned = [];
  int _plateNumber = 0;

  NextMealRecommendationResult? _legacy;
  bool _legacyRunning = false;
  String? _legacyError;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final now = _now();
    _plannedAt =
        widget.initialPlannedAt ??
        now.subtract(
          Duration(
            minutes: now.minute % 5,
            seconds: now.second,
            milliseconds: now.millisecond,
            microseconds: now.microsecond,
          ),
        );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Time in the profile's zone (the diary convention); local time when the
  // zone is unavailable.
  // ---------------------------------------------------------------------------

  DateTime _show(DateTime instant, String zone) {
    try {
      return _resolver.displayTime(instant, zone);
    } on FormatException {
      return instant.toLocal();
    }
  }

  DateTime _atClock(String zone, int hour, int minute) {
    final day = _show(_plannedAt, zone);
    try {
      return tz.TZDateTime(
        _resolver.location(zone),
        day.year,
        day.month,
        day.day,
        hour,
        minute,
      );
    } on FormatException {
      return DateTime(day.year, day.month, day.day, hour, minute);
    }
  }

  String _plannedText(String zone) {
    final planned = _show(_plannedAt, zone);
    final now = _show(_now(), zone);
    final clock = plannerClockText(planned);
    final sameDay =
        planned.year == now.year &&
        planned.month == now.month &&
        planned.day == now.day;
    if (sameDay) return clock;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${planned.year}-${two(planned.month)}-${two(planned.day)} $clock';
  }

  void _setPlanned(DateTime value) {
    debugPrint('[NextMeal] planned:set');
    setState(() => _plannedAt = value);
  }

  // ---------------------------------------------------------------------------
  // Plate and compare.
  // ---------------------------------------------------------------------------

  int _plateIndex(String id) => _plate.indexWhere((i) => i.candidate.id == id);

  void _togglePlate(NextMealCandidate c) {
    setState(() {
      final index = _plateIndex(c.id);
      if (index >= 0) {
        _plate.removeAt(index);
      } else {
        _plate.add(NextMealPlateItem(c, 1));
      }
    });
  }

  void _stepServings(String id, double delta) {
    setState(() {
      final index = _plateIndex(id);
      if (index < 0) return;
      final next = (_plate[index].servings + delta).clamp(
        NextMealPlanner.minServings,
        NextMealPlanner.maxServings,
      );
      _plate[index] = _plate[index].withServings(next.toDouble());
    });
  }

  bool _isPinnedFood(String id) =>
      _pinned.any((p) => p is _PinnedFood && p.foodId == id);

  void _pin(_Pinned entry) {
    if (_pinned.length >= _maxPinned) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.appI18n.tr('planner.pin_full'))),
        );
      return;
    }
    setState(() => _pinned.add(entry));
  }

  void _togglePinFood(NextMealCandidate c) {
    if (_isPinnedFood(c.id)) {
      setState(
        () => _pinned.removeWhere((p) => p is _PinnedFood && p.foodId == c.id),
      );
    } else {
      _pin(_PinnedFood(c.id));
    }
  }

  void _pinPlate() {
    if (_plate.isEmpty) return;
    _pin(_PinnedPlate(++_plateNumber, List.unmodifiable(_plate)));
  }

  Future<void> _saveDraft(AppState state) async {
    final i18n = context.appI18n;
    debugPrint('[NextMeal] draft:open items=${_plate.length}');
    final meal = Meal(
      id: 'planner_${_plannedAt.millisecondsSinceEpoch}',
      eatenAt: _plannedAt,
      occurredAt: _plannedAt,
      timeSource: 'user_exact',
      title: i18n.tr('planner.draft_title'),
      items: [
        for (final item in _plate)
          MealItem.fromFood(
            food: item.candidate.food,
            quantityFactor:
                item.candidate.serving.evaluatedGrams * item.servings / 100,
          ).copyWith(
            foodName: i18n.foodName(
              item.candidate.food.id,
              item.candidate.food.name,
            ),
          ),
      ],
    );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => EntryPage(reuseMeal: meal)));
  }

  Future<void> _runLegacy(AppState state) async {
    setState(() {
      _legacyRunning = true;
      _legacyError = null;
    });
    try {
      final result = await state.requestNextMealRecommendation(
        nextMealAt: _plannedAt,
        useLocalAi: false,
        windowDuration: const Duration(minutes: 60),
      );
      if (!mounted) return;
      setState(() => _legacy = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _legacyError = '$error');
    } finally {
      if (mounted) setState(() => _legacyRunning = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build.
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final planner = state.nextMealPlanner;
    final zone = state.userProfile.timezone;
    final candidates = state.nextMealCandidates;
    final byId = {for (final c in candidates) c.id: c};
    // Plate items follow catalog updates by id.
    for (var i = _plate.length - 1; i >= 0; i--) {
      final fresh = byId[_plate[i].candidate.id];
      if (fresh == null) {
        _plate.removeAt(i);
      } else if (!identical(fresh, _plate[i].candidate)) {
        _plate[i] = NextMealPlateItem(fresh, _plate[i].servings);
      }
    }
    final doseContext = state.nextMealDoseContext(_plannedAt);
    String nameOf(NextMealCandidate c) => i18n.foodName(c.food.id, c.food.name);
    final arranged = planner.arrange(
      candidates,
      filter: _filter,
      sort: _sort,
      descending: _descending,
      textureMode: state.userProfile.swallowingTextureMode,
      nameOf: nameOf,
      effectOf: _sort == NextMealSortKey.modeledBrainEntry
          ? (c) => planner.candidateEffect(c, doseContext)
          : null,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PaperAppBar(
        chapterTabs: PaperShellScope.showsChapters(context),
        title: Text(i18n.tr('next_meal.title')),
      ),
      body: SafeArea(
        bottom: false,
        child: PaperSplit(
          secondaryKey: const ValueKey('next-meal-browser-scroll'),
          primaryWidth: 420,
          primary: [
            Text(
              i18n.tr('planner.subtitle'),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: PlannerPalette.of(context).muted,
              ),
            ),
            const SizedBox(height: 12),
            _dayStrip(state, i18n, zone),
            const SizedBox(height: 12),
            PlannerTimeCard(
              i18n: i18n,
              plannedText: _plannedText(zone),
              onStep: (minutes) =>
                  _setPlanned(_plannedAt.add(Duration(minutes: minutes))),
              onTyped: (hour, minute) {
                _setPlanned(_atClock(zone, hour, minute));
                return true;
              },
              anchors: state.nextMealTimeAnchors(_now()),
              onAnchor: (anchor, plus) =>
                  _setPlanned(anchor.add(Duration(minutes: plus))),
              contextLine: _doseContextLine(i18n, doseContext, zone),
            ),
            const SizedBox(height: 12),
            _plateCard(state, i18n, planner, doseContext, nameOf),
          ],
          secondary: [
            if (_pinned.isNotEmpty) ...[
              _compareCard(i18n, planner, doseContext, byId, nameOf),
              const SizedBox(height: 12),
            ],
            _browserControls(state, i18n, candidates, arranged.length),
            const SizedBox(height: 10),
            if (arranged.isEmpty)
              PlannerCard(
                child: Text(
                  i18n.tr('planner.no_results'),
                  key: const ValueKey('next-meal-no-results'),
                ),
              ),
            for (final c in arranged.take(_visible))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PlannerFoodCard(
                  i18n: i18n,
                  candidate: c,
                  name: nameOf(c),
                  effect: planner.candidateEffect(
                    c,
                    doseContext,
                    withBand: true,
                  ),
                  onPlate: _plateIndex(c.id) >= 0,
                  pinned: _isPinnedFood(c.id),
                  onTogglePlate: () => _togglePlate(c),
                  onTogglePin: () => _togglePinFood(c),
                ),
              ),
            if (arranged.length > _visible)
              Center(
                child: OutlinedButton(
                  key: const ValueKey('next-meal-show-more'),
                  onPressed: () => setState(() => _visible += _pageSize),
                  child: Text(
                    i18n.tr('planner.show_more', {
                      'count':
                          '${(arranged.length - _visible).clamp(0, _pageSize)}',
                    }),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              i18n.tr('planner.boundary'),
              key: const ValueKey('next-meal-result-boundary'),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: PlannerPalette.of(context).muted,
              ),
            ),
            const SizedBox(height: 8),
            _auditSection(state, i18n, nameOf),
          ],
        ),
      ),
    );
  }

  Widget _dayStrip(AppState state, AppI18n i18n, String zone) {
    final now = _now();
    DiaryDay? day;
    var nowMinute = now.hour * 60 + now.minute;
    int? plannedMinute;
    try {
      final today = _resolver.dateAt(now, zone);
      day = const PersonalDiaryStripProjector()
          .project(
            endDay: today,
            dayCount: 1,
            zoneId: zone,
            asOf: now,
            meals: state.meals,
            intakes: state.intakes,
            observations: const [],
            foods: state.foodRepo.allFoods,
            medications: state.medRepo.allDrugs,
            resolver: _resolver,
          )
          .days
          .single;
      final shownNow = _resolver.displayTime(now, zone);
      nowMinute = shownNow.hour * 60 + shownNow.minute;
      if (_resolver.dateAt(_plannedAt, zone).compareTo(today) == 0) {
        final planned = _resolver.displayTime(_plannedAt, zone);
        plannedMinute = planned.hour * 60 + planned.minute;
      }
    } on FormatException {
      day = null;
    } on ArgumentError {
      day = null;
    }
    return PlannerDayStrip(
      i18n: i18n,
      day: day,
      nowMinute: nowMinute,
      plannedMinute: plannedMinute,
    );
  }

  Widget _doseContextLine(
    AppI18n i18n,
    NextMealDoseContext doseContext,
    String zone,
  ) {
    final intake = doseContext.intake;
    final drug = doseContext.drug;
    return Column(
      key: const ValueKey('next-meal-dose-context'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (intake != null && drug != null)
          Text(
            i18n.tr('planner.dose_context', {
              'drug': i18n.medicationName(drug.id, drug.displayName),
              'time': plannerClockText(_show(intake.takenAt, zone)),
              'offset': plannerOffsetText(i18n, doseContext.offsetMinutes!),
            }),
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        if (!doseContext.applicable) ...[
          const SizedBox(height: 4),
          PlannerChip(
            label: plannerCantModelText(i18n, doseContext.reasons),
            tone: PlannerChipTone.warn,
            icon: Icons.block_outlined,
          ),
        ],
      ],
    );
  }

  Widget _plateCard(
    AppState state,
    AppI18n i18n,
    NextMealPlanner planner,
    NextMealDoseContext doseContext,
    String Function(NextMealCandidate) nameOf,
  ) {
    final totals = planner.plateTotals(_plate);
    final curves = _plate.isEmpty
        ? null
        : planner.plateCurves(_plate, doseContext);
    return PlannerCard(
      key: const ValueKey('next-meal-plate'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              i18n.tr('planner.plate_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          if (_plate.isEmpty)
            Text(
              i18n.tr('planner.plate_empty'),
              key: const ValueKey('next-meal-plate-empty'),
              style: TextStyle(
                fontSize: 13,
                color: PlannerPalette.of(context).muted,
              ),
            ),
          for (final item in _plate)
            PlannerPlateItemRow(
              i18n: i18n,
              item: item,
              name: nameOf(item.candidate),
              onLess: item.servings > NextMealPlanner.minServings
                  ? () => _stepServings(
                      item.candidate.id,
                      -NextMealPlanner.servingStep,
                    )
                  : null,
              onMore: item.servings < NextMealPlanner.maxServings
                  ? () => _stepServings(
                      item.candidate.id,
                      NextMealPlanner.servingStep,
                    )
                  : null,
              onRemove: () => _togglePlate(item.candidate),
            ),
          if (_plate.isNotEmpty) ...[
            const SizedBox(height: 8),
            PlannerTotals(i18n: i18n, totals: totals),
            const SizedBox(height: 12),
            if (curves != null && curves.effect.modeled)
              NextMealPlateChart(
                curves: curves,
                i18n: i18n,
                draws: planner.physiology.draws,
                seed: planner.physiology.seed,
              )
            else if (curves != null)
              KeyedSubtree(
                key: const ValueKey('next-meal-plate-not-modeled'),
                child: PlannerEffectLine(i18n: i18n, effect: curves.effect),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('next-meal-pin-plate'),
                  onPressed: _pinPlate,
                  icon: const Icon(Icons.push_pin_outlined),
                  label: Text(i18n.tr('planner.pin_plate')),
                ),
                FilledButton.icon(
                  key: const ValueKey('next-meal-save-draft'),
                  onPressed: () => _saveDraft(state),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(i18n.tr('planner.save_draft')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              i18n.tr('planner.save_draft_note'),
              style: TextStyle(
                fontSize: 12,
                color: PlannerPalette.of(context).muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compareCard(
    AppI18n i18n,
    NextMealPlanner planner,
    NextMealDoseContext doseContext,
    Map<String, NextMealCandidate> byId,
    String Function(NextMealCandidate) nameOf,
  ) {
    final columns = <Widget>[];
    for (final entry in List.of(_pinned)) {
      switch (entry) {
        case _PinnedFood(:final foodId):
          final c = byId[foodId];
          if (c == null) continue;
          final items = [NextMealPlateItem(c, 1)];
          columns.add(
            PlannerCompareColumn(
              key: ValueKey('next-meal-compare-food-$foodId'),
              i18n: i18n,
              title: nameOf(c),
              subtitle: plannerServingText(i18n, c),
              totals: planner.plateTotals(items),
              effect: planner.plateEffect(items, doseContext),
              dataText: i18n.tr('planner.completeness', {
                'present': '${c.presentFieldCount}',
                'total': '${NextMealDataFields.all.length}',
              }),
              onUnpin: () => setState(() => _pinned.remove(entry)),
            ),
          );
        case _PinnedPlate(:final number, :final items):
          final present = items.fold<int>(
            0,
            (sum, i) => sum + i.candidate.presentFieldCount,
          );
          columns.add(
            PlannerCompareColumn(
              key: ValueKey('next-meal-compare-plate-$number'),
              i18n: i18n,
              title: i18n.tr('planner.plate_label', {'n': '$number'}),
              subtitle: items.map((i) => nameOf(i.candidate)).join(', '),
              totals: planner.plateTotals(items),
              effect: planner.plateEffect(items, doseContext),
              dataText: i18n.tr('planner.completeness', {
                'present': '$present',
                'total': '${NextMealDataFields.all.length * items.length}',
              }),
              onUnpin: () => setState(() => _pinned.remove(entry)),
            ),
          );
      }
    }
    return PlannerCard(
      key: const ValueKey('next-meal-compare'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              i18n.tr('planner.compare_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.tr('planner.compare_hint'),
            style: TextStyle(
              fontSize: 12,
              color: PlannerPalette.of(context).muted,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Side by side when there is room, stacked on a phone.
              final wide = constraints.maxWidth >= 560;
              if (!wide) {
                return Column(
                  children: [
                    for (final column in columns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(width: double.infinity, child: column),
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: columns[i]),
                  ],
                  for (var i = columns.length; i < _maxPinned; i++) ...[
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox()),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _sortLabel(AppI18n i18n, NextMealSortKey key) => i18n.tr(switch (key) {
    NextMealSortKey.familiarThenName => 'planner.sort.familiar_then_name',
    NextMealSortKey.name => 'planner.sort.name',
    NextMealSortKey.proteinPerServing => 'planner.sort.protein',
    NextMealSortKey.modeledBrainEntry => 'planner.sort.modeled',
    NextMealSortKey.energy => 'planner.sort.energy',
  });

  String _directionLabel(AppI18n i18n) {
    final byName =
        _sort == NextMealSortKey.name ||
        _sort == NextMealSortKey.familiarThenName;
    return i18n.tr(
      byName
          ? (_descending ? 'planner.sort_z_a' : 'planner.sort_a_z')
          : (_descending
                ? 'planner.sort_descending'
                : 'planner.sort_ascending'),
    );
  }

  Widget _browserControls(
    AppState state,
    AppI18n i18n,
    List<NextMealCandidate> candidates,
    int shownCount,
  ) {
    final palette = PlannerPalette.of(context);
    final regions = {
      for (final c in candidates) c.food.jurisdiction.toUpperCase(),
    }.toList()..sort();
    final textureMode = state.userProfile.swallowingTextureMode;
    void update(NextMealFilter next) => setState(() {
      _filter = next;
      _visible = _pageSize;
    });
    Set<T> toggled<T>(Set<T> set, T value) =>
        set.contains(value) ? ({...set}..remove(value)) : {...set, value};
    final activeFilters =
        _filter.groups.length +
        _filter.textures.length +
        _filter.regions.length +
        (_filter.completeDataOnly ? 1 : 0) +
        (_filter.matchTextureProfile ? 1 : 0);

    Widget section(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: palette.muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );

    return PlannerCard(
      key: const ValueKey('next-meal-browser-controls'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              i18n.tr('planner.browser_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('next-meal-search'),
            controller: _search,
            decoration: InputDecoration(
              labelText: i18n.tr('planner.search'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (value) => update(_filter.copyWith(query: value)),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
                child: DropdownButtonFormField<NextMealSortKey>(
                  key: const ValueKey('next-meal-sort'),
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: i18n.tr('planner.sort_label'),
                  ),
                  items: [
                    for (final key in NextMealSortKey.values)
                      DropdownMenuItem(
                        value: key,
                        child: Text(_sortLabel(i18n, key)),
                      ),
                  ],
                  onChanged: (key) => setState(() {
                    if (key == null) return;
                    _sort = key;
                    _descending =
                        key == NextMealSortKey.proteinPerServing ||
                        key == NextMealSortKey.energy;
                  }),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('next-meal-sort-reverse'),
                onPressed: () => setState(() => _descending = !_descending),
                icon: const Icon(Icons.swap_vert_rounded),
                label: Text(_directionLabel(i18n)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            i18n.tr('planner.sort_note'),
            style: TextStyle(fontSize: 12, color: palette.muted, height: 1.35),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: const ValueKey('next-meal-filters'),
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: Icon(
                  _showFilters
                      ? Icons.expand_less_rounded
                      : Icons.filter_list_rounded,
                ),
                label: Text(
                  activeFilters == 0
                      ? i18n.tr('planner.filters')
                      : '${i18n.tr('planner.filters')} ($activeFilters)',
                ),
              ),
              if (_filter.active)
                TextButton(
                  key: const ValueKey('next-meal-filters-clear'),
                  onPressed: () {
                    _search.clear();
                    update(const NextMealFilter());
                  },
                  child: Text(i18n.tr('planner.filter_clear')),
                ),
            ],
          ),
          if (_showFilters) ...[
            section(i18n.tr('planner.filter_group'), [
              for (final group in FoodCategory.values)
                FilterChip(
                  key: ValueKey('next-meal-filter-group-${group.name}'),
                  label: Text(i18n.tr('planner.group.${group.name}')),
                  selected: _filter.groups.contains(group),
                  onSelected: (_) => update(
                    _filter.copyWith(groups: toggled(_filter.groups, group)),
                  ),
                ),
            ]),
            section(i18n.tr('planner.filter_texture'), [
              for (final (value, key) in const [
                (NextMealTextureFilter.liquid, 'planner.texture_liquid'),
                (NextMealTextureFilter.soft, 'planner.texture_soft'),
                (NextMealTextureFilter.regular, 'planner.texture_regular'),
                (NextMealTextureFilter.unknown, 'planner.texture_unknown'),
              ])
                FilterChip(
                  key: ValueKey('next-meal-filter-texture-$value'),
                  label: Text(i18n.tr(key)),
                  selected: _filter.textures.contains(value),
                  onSelected: (_) => update(
                    _filter.copyWith(
                      textures: toggled(_filter.textures, value),
                    ),
                  ),
                ),
            ]),
            section(i18n.tr('planner.filter_region'), [
              for (final region in regions)
                FilterChip(
                  key: ValueKey('next-meal-filter-region-$region'),
                  label: Text(i18n.regionLabel(region)),
                  selected: _filter.regions.contains(region),
                  onSelected: (_) => update(
                    _filter.copyWith(regions: toggled(_filter.regions, region)),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const ValueKey('next-meal-filter-complete'),
              contentPadding: EdgeInsets.zero,
              title: Text(i18n.tr('planner.filter_complete')),
              value: _filter.completeDataOnly,
              onChanged: (value) =>
                  update(_filter.copyWith(completeDataOnly: value)),
            ),
            if (textureMode != 'unrestricted')
              SwitchListTile(
                key: const ValueKey('next-meal-filter-profile'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  i18n.tr('planner.filter_profile', {
                    'mode': i18n.textureModeLabel(textureMode),
                  }),
                ),
                value: _filter.matchTextureProfile,
                onChanged: (value) =>
                    update(_filter.copyWith(matchTextureProfile: value)),
              ),
          ],
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              i18n.tr('planner.result_count', {
                'shown': '${shownCount < _visible ? shownCount : _visible}',
                'total': '$shownCount',
              }),
              key: const ValueKey('next-meal-result-count'),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditSection(
    AppState state,
    AppI18n i18n,
    String Function(NextMealCandidate) nameOf,
  ) {
    final legacy = _legacy;
    final scores = [...?legacy?.mechanisticCandidateScores]
      ..sort((a, b) => a.candidateName.compareTo(b.candidateName));
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('next-meal-audit'),
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(
          i18n.tr('planner.audit_title'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          Text(
            i18n.tr('planner.audit_body'),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const ValueKey('next-meal-audit-run'),
              onPressed: _legacyRunning ? null : () => _runLegacy(state),
              child: Text(
                _legacyRunning
                    ? i18n.tr('planner.audit_running')
                    : i18n.tr('planner.audit_run'),
              ),
            ),
          ),
          if (_legacyError != null) ...[
            const SizedBox(height: 6),
            Text(_legacyError!, style: const TextStyle(fontSize: 12)),
          ],
          if (legacy?.mechanisticTrace != null) ...[
            const SizedBox(height: 10),
            MechanisticConflictTraceCard(typedResult: legacy!.mechanisticTrace),
          ],
          if (scores.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              i18n.tr('planner.audit_candidates'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final score in scores)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MechanisticCandidateScoreLine(score: score),
              ),
          ],
        ],
      ),
    );
  }
}
