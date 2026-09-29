import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/protein_trend_point.dart';
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
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: _days - 1));
    bool inRange(DateTime t) => !t.toLocal().isBefore(start);

    final events = state.timeline.where((e) => inRange(e.time)).toList();
    final protein = state.proteinTrend.where((p) => inRange(p.time)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    int count(TimelineEventType type) =>
        events.where((e) => e.type == type).length;
    final avgProtein = protein.isEmpty
        ? null
        : protein.fold<double>(0, (sum, p) => sum + p.protein) / protein.length;

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
                  onSelectionChanged: (value) =>
                      setState(() => _days = value.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PaperReveal(
            order: 1,
            storageId: 'insights-1',
            child: _KpiStrip(
              cells: [
                (
                  Icons.restaurant_outlined,
                  '${count(TimelineEventType.meal)}',
                  i18n.tr('insights.meals'),
                ),
                (
                  Icons.medication_outlined,
                  '${count(TimelineEventType.medication)}',
                  i18n.tr('insights.intakes'),
                ),
                (
                  Icons.monitor_heart_outlined,
                  '${count(TimelineEventType.observation)}',
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
                        days: _days,
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
                      _ProteinChart(points: protein, average: avgProtein),
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
      final t = event.time.toLocal();
      final index = DateTime(t.year, t.month, t.day).difference(start).inDays;
      if (index >= 0 && index < days) {
        perDay[index][event.type] = perDay[index][event.type]! + 1;
      }
    }
    final totals = [
      for (final day in perDay) day.values.fold(0, (a, b) => a + b),
    ];
    final peak = math.max(1, totals.fold(0, math.max));
    final labelEvery = days <= 7 ? 1 : 5;
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
  const _ProteinChart({required this.points, required this.average});

  final List<ProteinTrendPoint> points;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    if (points.isEmpty) return _Empty(text: i18n.tr('insights.empty'));
    final shown = points.length > 14
        ? points.sublist(points.length - 14)
        : points;
    final peak = math.max(
      1.0,
      shown.fold<double>(0, (m, p) => math.max(m, p.protein)),
    );
    return Semantics(
      label: shown.map((p) => '${p.protein.toStringAsFixed(1)} g').join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: 150,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const labelSpace = 20.0;
            final barArea = constraints.maxHeight - labelSpace;
            final avg = average;
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in shown)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: barArea,
                                child: PaperGrowBar(
                                  factor: math.max(
                                    2 / barArea,
                                    point.protein / peak,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Paper.clay.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: labelSpace,
                                child: Center(
                                  child: Text(
                                    point.protein.toStringAsFixed(0),
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
    final h = t.toLocal().hour;
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
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Paper.inkMuted),
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
