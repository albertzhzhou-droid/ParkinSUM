import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/personal_log_view.dart';
import '../../domain/usecases/personal_log_date_window_resolver.dart';
import '../../domain/usecases/personal_log_view_projector.dart';
import '../shared/personal_log_view_controls.dart';
import '../timeline/timeline_page.dart';
import '../../domain/entities/timeline_event.dart';

/// Insights — descriptive summaries of the user's own entries.
///
/// This page used to mix localization status, local-AI endpoint fields, a raw
/// replay benchmark and an import shortcut. Those were operator tools, not
/// insights: the local-AI connection now lives in Settings → Advanced, the
/// benchmark in Engineering diagnostics, and the rest already had homes.
/// What remains is what a reader wants from their notebook: how often they
/// logged, how protein was spread across meals, and when entries happen.
/// Every figure is a count or sum of logged entries — no clinical inference.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, this.clock, this.initialWindow});

  final DateTime Function()? clock;
  final PersonalLogDateWindow? initialWindow;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _days = 7;
  PersonalLogDateWindow? _customSelection;
  String? _scopeOwner;
  int? _scopeEpoch;

  @override
  void initState() {
    super.initState();
    _customSelection = widget.initialWindow;
  }

  Future<void> _openRecord(
    AppState state,
    TypedLogRecordRef record,
    PersonalLogDateWindow selection,
    String? owner,
    int epoch,
  ) async {
    if (owner == null ||
        state.currentUserId != owner ||
        state.mealDraftSessionEpoch != epoch ||
        !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: state,
          child: TimelinePage(
            focus: record,
            initialWindow: selection,
            expectedOwner: owner,
            expectedSessionEpoch: epoch,
          ),
        ),
      ),
    );
  }

  Future<void> _showRecords(
    AppState state,
    PersonalLogInsightsProjection projection, {
    bool future = false,
  }) async {
    final owner = state.currentUserId;
    final epoch = state.mealDraftSessionEpoch;
    final i18n = context.appI18n;
    var expired = false;
    StateSetter? rebuild;
    bool current() =>
        !expired &&
        state.currentUserId == owner &&
        state.mealDraftSessionEpoch == epoch &&
        state.userProfile.timezone == projection.window.selection.zoneId;
    void observe() {
      if (!current()) expired = true;
      rebuild?.call(() {});
    }

    state.addListener(observe);
    try {
      final selected = await showDialog<TypedLogRecordRef>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final fresh = current()
                ? const PersonalLogViewProjector().insights(
                    window: projection.window,
                    meals: state.meals,
                    intakes: state.intakes,
                    observations: state.observations,
                    foods: state.foodRepo.allFoods,
                    medications: state.medRepo.allDrugs,
                  )
                : null;
            final records = future
                ? fresh?.future ?? <TimelineEvent>[]
                : fresh?.historical ?? <TimelineEvent>[];
            final protein = {
              for (final point in fresh?.protein ?? <LoggedProteinSample>[])
                point.record: point,
            };
            return AlertDialog(
              title: Text(logViewText(i18n, 'log_view.records')),
              content: SizedBox(
                width: 560,
                height: 400,
                child: !current()
                    ? Text(logViewText(i18n, 'log_view.selection_changed'))
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (_, index) {
                          final event = records[index];
                          final ref = TypedLogRecordRef.fromEvent(event);
                          final sample = protein[ref];
                          final time = logDisplayTime(
                            event.time,
                            projection.window.selection.zoneId,
                          );
                          final value = future
                              ? logViewText(i18n, 'log_view.future')
                              : sample == null
                              ? ''
                              : switch (sample.status) {
                                  LoggedProteinStatus.known =>
                                    '${sample.valueG!.toStringAsFixed(1)} g',
                                  LoggedProteinStatus.unknown => logViewText(
                                    i18n,
                                    'log_view.unknown',
                                  ),
                                  LoggedProteinStatus.invalid => logViewText(
                                    i18n,
                                    'log_view.invalid',
                                  ),
                                };
                          return ListTile(
                            key: ValueKey('insights-record-${ref.viewKey}'),
                            title: Text(event.title),
                            subtitle: Text(
                              '${LogCivilDate.fromDateTime(time)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · $value',
                            ),
                            onTap: () => Navigator.of(dialogContext).pop(ref),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(i18n.tr('common.close')),
                ),
              ],
            );
          },
        ),
      );
      // The dialog is gone before the pushed record route can mutate state.
      // Detach its rebuild callback and listener before awaiting that route.
      rebuild = null;
      state.removeListener(observe);
      if (current() && selected != null && mounted) {
        await _openRecord(
          state,
          selected,
          projection.window.selection,
          owner,
          epoch,
        );
      }
    } finally {
      state.removeListener(observe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final now = (widget.clock?.call() ?? DateTime.now()).toUtc();
    if (_scopeEpoch != null &&
        (_scopeOwner != state.currentUserId ||
            _scopeEpoch != state.mealDraftSessionEpoch)) {
      _customSelection = null;
    }
    _scopeOwner = state.currentUserId;
    _scopeEpoch = state.mealDraftSessionEpoch;
    final selectionOwner = state.currentUserId;
    final selectionEpoch = state.mealDraftSessionEpoch;
    final resolver = PersonalLogDateWindowResolver();
    final zone = state.userProfile.timezone;
    late final ResolvedLogWindow window;
    try {
      final today = resolver.dateAt(now, zone);
      final selection = _customSelection == null
          ? PersonalLogDateWindow(
              start: today.addDays(-_days + 1),
              endInclusive: today,
              zoneId: zone,
            )
          : PersonalLogDateWindow(
              start: _customSelection!.start,
              endInclusive: _customSelection!.endInclusive,
              zoneId: zone,
            );
      window = resolver.resolve(selection, asOf: now);
    } on FormatException {
      return Scaffold(
        appBar: PaperAppBar(title: Text(i18n.tr('insights.title'))),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            logViewText(i18n, 'log_view.zone_hold'),
            key: const ValueKey('insights-zone-hold'),
          ),
        ),
      );
    }
    final projection = const PersonalLogViewProjector().insights(
      window: window,
      meals: state.meals,
      intakes: state.intakes,
      observations: state.observations,
      foods: state.foodRepo.allFoods,
      medications: state.medRepo.allDrugs,
    );
    final events = projection.historical
        .map(
          (event) => TimelineEvent(
            time: resolver.displayTime(event.time, zone),
            type: event.type,
            recordId: event.recordId,
            entityId: event.entityId,
            title: event.title,
            description: event.description,
          ),
        )
        .toList();
    final protein = projection.knownProtein;
    final excludedProteinMeals =
        projection.unknownCount + projection.invalidCount;
    final proteinCoverage = logViewText(i18n, 'insights.protein_coverage', {
      'start': '${window.selection.start}',
      'end': '${window.selection.endInclusive}',
      'zone': zone,
      'included': '${protein.length}',
      'excluded': '$excludedProteinMeals',
      'unknown': '${projection.unknownCount}',
      'invalid': '${projection.invalidCount}',
      'zero': '${projection.reportedZeroCount}',
    });
    final avgProtein = projection.knownMeanG;
    final start = window.selection.start.calendarValue;
    final calendarDays = window.selection.calendarDays;

    return Scaffold(
      appBar: PaperAppBar(
        chapterTabs: PaperShellScope.showsChapters(context),
        title: Text(i18n.tr('insights.title')),
      ),
      body: PaperScrollPage(
        maxWidth: 1180,
        top: 4,
        children: [
          PaperReveal(
            order: 0,
            storageId: 'insights-0',
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: PaperInitialParagraph(
                    i18n.tr('insights.subtitle'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Paper.inkSecondary),
                  ),
                ),
                SegmentedButton<int>(
                  key: const ValueKey('insights-range'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 7,
                      label: Text(i18n.tr('insights.range_7')),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text(i18n.tr('insights.range_30')),
                    ),
                  ],
                  selected: {_days},
                  onSelectionChanged: (value) => setState(() {
                    _days = value.first;
                    _customSelection = null;
                  }),
                ),
                PersonalLogDateButton(
                  key: const ValueKey('insights-custom-dates'),
                  zoneId: zone,
                  selection: window.selection,
                  maxDays: 366,
                  onChanged: (selection) {
                    if (state.currentUserId == selectionOwner &&
                        state.mealDraftSessionEpoch == selectionEpoch) {
                      setState(() => _customSelection = selection);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(logViewText(i18n, 'log_view.date_basis', {'zone': zone})),
          Text(
            logViewText(i18n, 'insights.future_count', {
              'count': '${projection.future.length}',
            }),
            key: const ValueKey('insights-future-count'),
          ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const ValueKey('insights-records'),
                onPressed: () => _showRecords(state, projection),
                child: Text(logViewText(i18n, 'log_view.records')),
              ),
              if (projection.future.isNotEmpty)
                OutlinedButton(
                  key: const ValueKey('insights-future-records'),
                  onPressed: () =>
                      _showRecords(state, projection, future: true),
                  child: Text(logViewText(i18n, 'log_view.future')),
                ),
            ],
          ),
          const SizedBox(height: 18),
          PaperReveal(
            order: 1,
            storageId: 'insights-1',
            child: _KpiStrip(
              cells: [
                (
                  Icons.restaurant_outlined,
                  '${projection.count(TimelineEventType.meal)}',
                  i18n.tr('insights.meals'),
                ),
                (
                  Icons.medication_outlined,
                  '${projection.count(TimelineEventType.medication)}',
                  i18n.tr('insights.intakes'),
                ),
                (
                  Icons.monitor_heart_outlined,
                  '${projection.count(TimelineEventType.observation)}',
                  i18n.tr('insights.observations'),
                ),
                (
                  Icons.egg_alt_outlined,
                  avgProtein == null
                      ? '—'
                      : '${avgProtein.toStringAsFixed(1)} g',
                  i18n.tr('insights.avg_protein'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PaperReveal(
            order: 2,
            storageId: 'insights-2',
            child: PaperColumns(
              minColumnWidth: 400,
              maxColumns: 2,
              children: [
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PaperSectionHeader(
                        title: i18n.tr('insights.rhythm_title'),
                        subtitle: i18n.tr('insights.rhythm_subtitle'),
                      ),
                      const SizedBox(height: 16),
                      _RhythmChart(
                        start: start,
                        days: calendarDays,
                        events: events,
                        localeTag: Localizations.localeOf(context).toString(),
                      ),
                      const SizedBox(height: 12),
                      _Legend(
                        items: [
                          (Paper.accent, i18n.tr('insights.meals')),
                          (Paper.info, i18n.tr('insights.intakes')),
                          (Paper.success, i18n.tr('insights.observations')),
                        ],
                      ),
                    ],
                  ),
                ),
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PaperSectionHeader(
                        title: i18n.tr('insights.protein_title'),
                        subtitle: i18n.tr('insights.protein_subtitle'),
                      ),
                      const SizedBox(height: 16),
                      _ProteinChart(
                        points: protein,
                        average: avgProtein,
                        onSelect: (point) => _openRecord(
                          state,
                          point.record,
                          window.selection,
                          state.currentUserId,
                          state.mealDraftSessionEpoch,
                        ),
                      ),
                      Text(
                        logViewText(i18n, 'insights.chart_scope', {
                          'shown': '${math.min(14, protein.length)}',
                          'total': '${protein.length}',
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        proteinCoverage,
                        key: const ValueKey('insights-protein-coverage'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PaperSectionHeader(
                        title: i18n.tr('insights.daypart_title'),
                        subtitle: i18n.tr('insights.daypart_subtitle'),
                      ),
                      const SizedBox(height: 14),
                      _DaypartTable(events: events),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PaperReveal(
            order: 3,
            storageId: 'insights-3',
            child: PaperNote(
              icon: Icons.school_outlined,
              child: Text(i18n.tr('insights.boundary')),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.cells});

  final List<(IconData, String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return PaperSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = constraints.maxWidth >= 620 ? 4 : 2;
          final rows = <Widget>[];
          for (var start = 0; start < cells.length; start += perRow) {
            if (start > 0) rows.add(const Divider(height: 1));
            final slice = cells.skip(start).take(perRow).toList();
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < slice.length; i++) ...[
                      if (i > 0) const VerticalDivider(width: 1),
                      Expanded(
                        child: Semantics(
                          container: true,
                          label: '${slice[i].$3}: ${slice[i].$2}',
                          excludeSemantics: true,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                            child: Row(
                              children: [
                                Icon(slice[i].$1, size: 18, color: Paper.gilt),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slice[i].$2,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontFamily: Paper.serif,
                                          fontSize: 26,
                                          height: 1.1,
                                          color: Paper.ink,
                                        ),
                                      ),
                                      Text(
                                        slice[i].$3,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Paper.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Column(children: rows);
        },
      ),
    );
  }
}

/// Entries per day, stacked by kind.
class _RhythmChart extends StatelessWidget {
  const _RhythmChart({
    required this.start,
    required this.days,
    required this.events,
    required this.localeTag,
  });

  final DateTime start;
  final int days;
  final List<TimelineEvent> events;
  final String localeTag;

  static const _order = [
    TimelineEventType.meal,
    TimelineEventType.medication,
    TimelineEventType.observation,
  ];

  static Color _color(TimelineEventType type) => switch (type) {
    TimelineEventType.meal => Paper.accent,
    TimelineEventType.medication => Paper.info,
    TimelineEventType.observation => Paper.success,
  };

  @override
  Widget build(BuildContext context) {
    final perDay = List.generate(
      days,
      (_) => {for (final type in _order) type: 0},
    );
    for (final event in events) {
      final t = event.time;
      final index = DateTime.utc(
        t.year,
        t.month,
        t.day,
      ).difference(start).inDays;
      if (index >= 0 && index < days) {
        perDay[index][event.type] = perDay[index][event.type]! + 1;
      }
    }
    final totals = [
      for (final day in perDay) day.values.fold(0, (a, b) => a + b),
    ];
    final peak = math.max(1, totals.fold(0, math.max));
    final labelEvery = days <= 7 ? 1 : math.max(5, (days / 6).ceil());
    final localizations = MaterialLocalizations.of(context);
    return Semantics(
      label: [
        for (var i = 0; i < days; i++)
          '${localizations.formatShortMonthDay(start.add(Duration(days: i)))}: ${totals[i]}',
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: days <= 7 ? 6 : 1.5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (days <= 7)
                        Text(
                          totals[i] == 0 ? '' : '${totals[i]}',
                          style: const TextStyle(
                            fontFamily: Paper.mono,
                            fontSize: 11,
                            color: Paper.inkMuted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: PaperGrowBar(
                          factor: totals[i] == 0 ? 0.02 : totals[i] / peak,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Column(
                              children: [
                                for (final type in _order.reversed)
                                  if (perDay[i][type]! > 0)
                                    Expanded(
                                      flex: perDay[i][type]!,
                                      child: Container(color: _color(type)),
                                    ),
                                if (totals[i] == 0)
                                  Expanded(
                                    child: Container(color: Paper.border),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 14,
                        child: i % labelEvery == 0 || i == days - 1
                            ? Text(
                                days <= 7
                                    ? localizations
                                          .formatShortMonthDay(
                                            start.add(Duration(days: i)),
                                          )
                                          .split(' ')
                                          .last
                                    : '${start.add(Duration(days: i)).day}',
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: const TextStyle(
                                  fontFamily: Paper.mono,
                                  fontSize: 10.5,
                                  color: Paper.inkMuted,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Protein per logged meal, oldest to newest, with the period average.
class _ProteinChart extends StatelessWidget {
  const _ProteinChart({
    required this.points,
    required this.average,
    required this.onSelect,
  });

  final List<LoggedProteinSample> points;
  final ValueChanged<LoggedProteinSample> onSelect;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    if (points.isEmpty) {
      return _Empty(text: logViewText(i18n, 'insights.no_known_protein'));
    }
    final shown = points.length > 14
        ? points.sublist(points.length - 14)
        : points;
    final peak = math.max(
      1.0,
      math.max(
        average ?? 0,
        shown.fold<double>(0, (m, p) => math.max(m, p.valueG!)),
      ),
    );
    return Semantics(
      label: shown.map((p) => '${p.valueG!.toStringAsFixed(1)} g').join(', '),
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const labelSpace = 20.0;
            final barArea = constraints.maxHeight - labelSpace;
            final avg = average;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(constraints.maxWidth, shown.length * 48.0),
                height: constraints.maxHeight,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final point in shown)
                          Expanded(
                            child: InkWell(
                              key: ValueKey(
                                'insights-point-${point.record.viewKey}',
                              ),
                              onTap: () => onSelect(point),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: barArea,
                                      child: PaperGrowBar(
                                        factor: point.isReportedZero
                                            ? 0
                                            : math.max(
                                                2 / barArea,
                                                point.valueG! / peak,
                                              ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Paper.clay.withValues(
                                              alpha: 0.55,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: labelSpace,
                                      child: Center(
                                        child: Text(
                                          point.valueG!.toStringAsFixed(0),
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontFamily: Paper.mono,
                                            fontSize: 10,
                                            color: Paper.inkMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (avg != null)
                      AnimatedPositioned(
                        duration: Paper.motion(context, Paper.motionMedium * 2),
                        curve: Paper.motionCurve,
                        left: 0,
                        right: 0,
                        top: barArea - barArea * avg / peak,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(height: 1, color: Paper.accent),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '⌀ ${avg.toStringAsFixed(1)} g',
                              style: const TextStyle(
                                fontFamily: Paper.mono,
                                fontSize: 10.5,
                                color: Paper.accentInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Meals and intakes by part of day.
class _DaypartTable extends StatelessWidget {
  const _DaypartTable({required this.events});

  final List<TimelineEvent> events;

  static int _bucket(DateTime t) {
    final h = t.hour;
    if (h >= 5 && h < 11) return 0;
    if (h >= 11 && h < 16) return 1;
    if (h >= 16 && h < 22) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final labels = [
      i18n.tr('insights.morning'),
      i18n.tr('insights.midday'),
      i18n.tr('insights.evening'),
      i18n.tr('insights.night'),
    ];
    final meals = List.filled(4, 0);
    final intakes = List.filled(4, 0);
    for (final event in events) {
      if (event.type == TimelineEventType.meal) meals[_bucket(event.time)]++;
      if (event.type == TimelineEventType.medication) {
        intakes[_bucket(event.time)]++;
      }
    }
    final peak = math.max(1, [...meals, ...intakes].fold(0, math.max));
    if (meals.every((c) => c == 0) && intakes.every((c) => c == 0)) {
      return _Empty(text: i18n.tr('insights.empty'));
    }
    Widget bar(int value, Color color) => Row(
      children: [
        Expanded(
          child: PaperGrowBar(
            axis: Axis.horizontal,
            factor: value == 0 ? 0.01 : value / peak,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontFamily: Paper.mono,
              fontSize: 11,
              color: Paper.inkMuted,
            ),
          ),
        ),
      ],
    );
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      fontFamily: Paper.serif,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: Paper.inkSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      bar(meals[i], Paper.accent),
                      const SizedBox(height: 4),
                      bar(intakes[i], Paper.info),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        _Legend(
          items: [
            (Paper.accent, i18n.tr('insights.meals')),
            (Paper.info, i18n.tr('insights.intakes')),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: Paper.serif,
            fontStyle: FontStyle.italic,
            fontSize: 14,
            color: Paper.inkMuted,
          ),
        ),
      ),
    );
  }
}
