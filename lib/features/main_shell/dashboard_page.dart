import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/next_meal_plan.dart';
import '../../domain/entities/personal_observation.dart';
import '../../domain/entities/protein_trend_point.dart';
import '../../domain/entities/timeline_event.dart';
import '../entry/entry_page.dart';
import '../next_meal/next_meal_planner_widgets.dart';
import '../timeline/timeline_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _formatDateTime(DateTime value) {
    value = value.toLocal();
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _localizedTimelineDescription(AppI18n i18n, TimelineEvent event) {
    if (event.type == TimelineEventType.meal) {
      final countMatch = RegExp(r'(\d+)').firstMatch(event.description);
      final count = countMatch?.group(1) ?? '?';
      return i18n.tr('dashboard.items', {'count': count});
    }
    return event.description
        .replaceFirst('Medication · ', '${i18n.tr('medications.title')} · ')
        .replaceFirst('No dosage note', '-');
  }

  String _localizedTimelineTitle(AppI18n i18n, TimelineEvent event) {
    if (event.type == TimelineEventType.observation) {
      return i18n.languageFamily == 'zh' ? '个人观察' : 'Personal observation';
    }
    if (event.type == TimelineEventType.medication && event.entityId != null) {
      return i18n.medicationName(event.entityId!, event.title);
    }
    return event.title;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final timeline = state.timeline.take(8).toList();
    final observationsById = {
      for (final item in state.observations) item.id: item,
    };
    final trend = state.proteinTrend;
    final navigate = PaperShellScope.maybeOf(context)?.navigate;

    final nextMealPlate = _buildPlannerPlate(context, state, i18n, navigate);
    final proteinCard = _buildProteinCard(context, state, i18n, trend);
    final timelineCard = _buildTimelineCard(
      context,
      i18n,
      timeline,
      observationsById,
      navigate,
    );

    return Scaffold(
      appBar: PaperAppBar(
        chapterTabs: PaperShellScope.showsChapters(context),
        title: Text(i18n.tr('nav.today')),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = paperPageInsets(
            constraints.maxWidth,
            maxWidth: 1240,
            top: 4,
          );
          final contentWidth = constraints.maxWidth - insets.horizontal;
          const gap = SizedBox(height: 16);
          Widget column(List<Widget> cards) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) gap,
                cards[i],
              ],
            ],
          );
          // Today is a hub: log, glance, and step into a chapter. Details
          // (editing meals, the full rule output) live in their chapters.
          final grid = contentWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: timelineCard),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: column([nextMealPlate, proteinCard]),
                    ),
                  ],
                )
              : column([nextMealPlate, timelineCard, proteinCard]);
          return ListView(
            padding: insets,
            // Sections settle in top to bottom the first time Today opens.
            children: [
              PaperReveal(
                storageId: 'today-header',
                child: _buildHeader(context, i18n),
              ),
              const SizedBox(height: 18),
              PaperReveal(
                order: 1,
                storageId: 'today-composer',
                child: _buildComposer(context, i18n, wide: contentWidth >= 640),
              ),
              const SizedBox(height: 16),
              PaperReveal(
                order: 2,
                storageId: 'today-kpi',
                child: _buildKpiStrip(context, state, i18n),
              ),
              const SizedBox(height: 16),
              PaperReveal(order: 3, storageId: 'today-grid', child: grid),
            ],
          );
        },
      ),
    );
  }

  /// Running head (date), serif greeting and a raised-initial lede.
  Widget _buildHeader(BuildContext context, AppI18n i18n) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final greetingKey = now.hour < 12
        ? 'dashboard.greeting_morning'
        : now.hour < 18
        ? 'dashboard.greeting_afternoon'
        : 'dashboard.greeting_evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MaterialLocalizations.of(context).formatFullDate(now).toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: Paper.accentInk,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(i18n.tr(greetingKey), style: text.headlineLarge),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: PaperInitialParagraph(
            i18n.tr('dashboard.subtitle'),
            style: text.bodyMedium?.copyWith(color: Paper.inkSecondary),
          ),
        ),
      ],
    );
  }

  /// The one place on Today to start an entry: three choices on a plate.
  Widget _buildComposer(
    BuildContext context,
    AppI18n i18n, {
    required bool wide,
  }) {
    final choices = [
      _LogChoice(
        key: const ValueKey('today-log-meal'),
        icon: Icons.restaurant_outlined,
        tone: PaperTone.accent,
        label: i18n.tr('dashboard.add_meal'),
        hint: i18n.tr('dashboard.log_meal_hint'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EntryPage()),
        ),
      ),
      _LogChoice(
        key: const ValueKey('today-log-intake'),
        icon: Icons.medication_outlined,
        tone: PaperTone.info,
        label: i18n.tr('timeline.add_intake'),
        hint: i18n.tr('dashboard.log_intake_hint'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IntakeEditorPage()),
        ),
      ),
      _LogChoice(
        key: const ValueKey('today-log-observation'),
        icon: Icons.monitor_heart_outlined,
        tone: PaperTone.success,
        label: i18n.tr('shell.action.observation'),
        hint: i18n.tr('dashboard.log_observation_hint'),
        onTap: () => openObservationEditor(context),
      ),
    ];
    return PaperPlate(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('dashboard.log_prompt'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < choices.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: choices[i]),
                  ],
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  choices[i],
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// Four figures in one ruled strip instead of four tall cards.
  Widget _buildKpiStrip(BuildContext context, AppState state, AppI18n i18n) {
    final cells = [
      _KpiCell(
        key: const ValueKey('dashboard-stat-meals'),
        value: '${state.meals.length}',
        label: i18n.tr('dashboard.stat_meals'),
        icon: Icons.restaurant_outlined,
      ),
      _KpiCell(
        key: const ValueKey('dashboard-stat-drugs'),
        value: '${state.activeDrugs.length}',
        label: i18n.tr('dashboard.stat_drugs'),
        icon: Icons.medication_outlined,
      ),
      _KpiCell(
        key: const ValueKey('dashboard-stat-intakes'),
        value: '${state.intakes.length}',
        label: i18n.tr('dashboard.stat_intakes'),
        icon: Icons.schedule_outlined,
      ),
      _KpiCell(
        key: const ValueKey('dashboard-stat-protein'),
        value: state.averageKnownProtein == null
            ? '—'
            : '${state.averageKnownProtein!.toStringAsFixed(1)} g',
        label: i18n.tr('dashboard.stat_protein'),
        icon: Icons.egg_alt_outlined,
      ),
    ];
    return PaperSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = constraints.maxWidth >= 620
              ? 4
              : constraints.maxWidth >= 300
              ? 2
              : 1;
          final rows = <Widget>[];
          for (var start = 0; start < cells.length; start += perRow) {
            final slice = cells.skip(start).take(perRow).toList();
            if (start > 0) rows.add(const Divider(height: 1));
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < slice.length; i++) ...[
                      if (i > 0) const VerticalDivider(width: 1),
                      Expanded(child: slice[i]),
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

  /// Entry to the Next-meal planner. The legacy ranker no longer orders
  /// anything on Today: foods the user logged before are listed by name, as
  /// in the planner's neutral default order.
  Widget _buildPlannerPlate(
    BuildContext context,
    AppState state,
    AppI18n i18n,
    ValueChanged<String>? navigate,
  ) {
    final text = Theme.of(context).textTheme;
    final familiar = state.nextMealPlanner
        .arrange(
          state.familiarNextMealCandidates,
          filter: const NextMealFilter(),
          sort: NextMealSortKey.name,
          descending: false,
          textureMode: state.userProfile.swallowingTextureMode,
          nameOf: (c) => i18n.foodName(c.food.id, c.food.name),
        )
        .take(3)
        .toList();
    return PaperPlate(
      key: const ValueKey('today-planner-card'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperSectionHeader(
            eyebrow: i18n.tr('planner.today_card_eyebrow'),
            title: i18n.tr('dashboard.recommendations'),
          ),
          const SizedBox(height: 8),
          Text(i18n.tr('planner.today_card_intro'), style: text.bodySmall),
          const SizedBox(height: 12),
          if (familiar.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EmptyLine(
                icon: Icons.inbox_outlined,
                text: i18n.tr('dashboard.no_recommendations'),
              ),
            )
          else ...[
            Text(
              i18n.tr('planner.today_card_familiar'),
              style: text.labelMedium?.copyWith(color: Paper.inkMuted),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < familiar.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.foodName(familiar[i].food.id, familiar[i].food.name),
                      style: text.titleSmall,
                    ),
                    Text(
                      '${plannerServingText(i18n, familiar[i])} · '
                      '${plannerProteinText(i18n, familiar[i].proteinG)}',
                      style: text.bodySmall?.copyWith(color: Paper.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (navigate != null) ...[
            const SizedBox(height: 4),
            _ChapterLink(
              key: const ValueKey('today-open-next-meal'),
              label: i18n.tr('dashboard.open_next_meal'),
              onTap: () => navigate('next-meal'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProteinCard(
    BuildContext context,
    AppState state,
    AppI18n i18n,
    List<ProteinTrendPoint> trend,
  ) {
    final points = trend.take(7).toList().reversed.toList();
    final maxProtein = points.fold<double>(
      0,
      (max, point) => point.protein > max ? point.protein : max,
    );
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperSectionHeader(
            title: i18n.tr('dashboard.protein_trend'),
            subtitle: i18n.tr('dashboard.average_protein', {
              'value':
                  state.averageKnownProtein?.toStringAsFixed(1) ??
                  (i18n.languageFamily == 'zh' ? '未知' : 'Unknown'),
            }),
          ),
          const SizedBox(height: 14),
          if (points.isEmpty)
            _EmptyLine(
              icon: Icons.bar_chart_rounded,
              text: i18n.tr('dashboard.no_trend'),
            )
          else
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: Semantics(
                        label:
                            '${_formatDateTime(point.time)} · '
                            '${point.protein.toStringAsFixed(1)} g',
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                point.protein.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontFamily: Paper.mono,
                                  fontSize: 11,
                                  color: Paper.inkMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: PaperGrowBar(
                                  factor: maxProtein <= 0
                                      ? 0.04
                                      : (point.protein / maxProtein).clamp(
                                          0.04,
                                          1.0,
                                        ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: point == points.last
                                          ? Paper.accent
                                          : Paper.clay.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(
                                        Paper.radiusXs,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDateTime(point.time).split(' ').first,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontFamily: Paper.mono,
                                  fontSize: 10.5,
                                  color: Paper.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
    BuildContext context,
    AppI18n i18n,
    List<TimelineEvent> timeline,
    Map<String, PersonalObservation> observationsById,
    ValueChanged<String>? navigate,
  ) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperSectionHeader(
            title: i18n.tr('dashboard.today'),
            trailing: navigate == null
                ? null
                : _ChapterLink(
                    key: const ValueKey('today-open-timeline'),
                    label: i18n.tr('dashboard.open_timeline'),
                    onTap: () => navigate('timeline'),
                  ),
          ),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EmptyLine(
                icon: Icons.timeline_rounded,
                text: i18n.tr('dashboard.no_timeline'),
              ),
            ),
          for (var i = 0; i < timeline.length; i++)
            Builder(
              builder: (context) {
                final event = timeline[i];
                final tone = _timelineTone(event.type);
                final isLast = i == timeline.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Column(
                          children: [
                            _ToneTile(
                              icon: _timelineIcon(event.type),
                              foreground: tone.foreground,
                              background: tone.background,
                              size: 28,
                            ),
                            if (!isLast)
                              const Expanded(
                                child: VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: Paper.border,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 4,
                            bottom: isLast ? 6 : 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _localizedTimelineTitle(i18n, event),
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${_formatDateTime(event.time.toLocal())} · ${event.type == TimelineEventType.observation ? observationsById[event.recordId]?.summary(chinese: i18n.languageFamily == 'zh') ?? '' : _localizedTimelineDescription(i18n, event)}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  PaperTone _timelineTone(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return PaperTone.accent;
      case TimelineEventType.medication:
        return PaperTone.info;
      case TimelineEventType.observation:
        return PaperTone.success;
    }
  }

  IconData _timelineIcon(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Icons.restaurant_outlined;
      case TimelineEventType.medication:
        return Icons.medication_outlined;
      case TimelineEventType.observation:
        return Icons.monitor_heart_outlined;
    }
  }
}

/// "Open …" link into another chapter, set in rubric small type.
class _ChapterLink extends StatelessWidget {
  const _ChapterLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 16),
        ],
      ),
    );
  }
}

/// One choice in the Today composer.
class _LogChoice extends StatelessWidget {
  const _LogChoice({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final PaperTone tone;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Paper.radiusMd);
    return Material(
      color: Paper.surfaceSunken,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: Paper.hover,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ToneTile(
                icon: icon,
                foreground: tone.foreground,
                background: tone.background,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(hint, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One figure in the KPI strip.
class _KpiCell extends StatelessWidget {
  const _KpiCell({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Paper.gilt),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: Paper.serif,
                      fontSize: 26,
                      height: 1.1,
                      color: Paper.ink,
                    ),
                  ),
                  Text(
                    label,
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
    );
  }
}

class _ToneTile extends StatelessWidget {
  const _ToneTile({
    required this.icon,
    required this.foreground,
    required this.background,
    this.size = 38,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Paper.radiusSm + 1),
      ),
      child: Icon(icon, size: size * 0.52, color: foreground),
    );
  }
}

/// Quiet empty-state line.
class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Paper.inkFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: Paper.serif,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: Paper.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
