import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/food_recommendation.dart';
import '../../domain/entities/personal_observation.dart';
import '../../domain/entities/protein_trend_point.dart';
import '../../domain/entities/timeline_event.dart';
import '../entry/entry_page.dart';
import '../next_meal/candidate_set_snapshot_card.dart';
import '../timeline/timeline_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _formatDateTime(DateTime value) {
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

  String _localizedRecommendationBreakdown(
    AppI18n i18n,
    FoodRecommendation recommendation,
  ) {
    final safety = (recommendation.scoreBreakdown['safety_score'] as num?) ?? 0;
    final schedule =
        (recommendation.scoreBreakdown['medication_schedule_fit'] as num?) ?? 0;
    final facts =
        (recommendation.scoreBreakdown['database_fact_coverage'] as num?) ?? 0;
    final contextPenalty =
        (recommendation.scoreBreakdown['context_penalty_points'] as num?) ?? 0;
    final timingPenalty =
        (recommendation.scoreBreakdown['levodopa_window_penalty'] as num?) ?? 0;
    final swallowingPenalty =
        (recommendation.scoreBreakdown['swallowing_texture_penalty'] as num?) ??
        0;
    final templateAffinity =
        (recommendation.scoreBreakdown['template_texture_affinity'] as num?) ??
        0;
    return i18n.tr('dashboard.recommendation_score_line', {
      'safety': safety.toStringAsFixed(2),
      'schedule': schedule.toStringAsFixed(2),
      'facts': facts.toStringAsFixed(2),
      'context': contextPenalty.toStringAsFixed(1),
      'timing': timingPenalty.toStringAsFixed(1),
      'swallowing': swallowingPenalty.toStringAsFixed(1),
      'template': templateAffinity.toStringAsFixed(2),
    });
  }

  String? _localizedFoodTextureSummary(
    AppI18n i18n,
    FoodRecommendation recommendation,
  ) {
    final food = recommendation.food;
    if (food.textureClass == null && food.iddsiLevel == null) {
      return null;
    }
    return i18n.foodTextureSummary(
      textureClass: food.textureClass,
      iddsiLevel: food.iddsiLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final timeline = state.timeline.take(8).toList();
    final observationsById = {
      for (final item in state.observations) item.id: item,
    };
    final rankPresentationWithheld =
        state.recommendationRankPresentationWithheld;
    final recommendations = rankPresentationWithheld
        ? const <FoodRecommendation>[]
        : state.recommendations.take(3).toList();
    final trend = state.proteinTrend;
    final copy = ResponseCopyService(i18n: i18n);
    final navigate = PaperShellScope.maybeOf(context)?.navigate;

    final nextMealPlate = _buildRecommendationPlate(
      context,
      state,
      i18n,
      copy,
      recommendations,
      navigate,
      rankPresentationWithheld,
    );
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
        value: '${state.averageProtein.toStringAsFixed(1)} g',
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

  Widget _buildRecommendationPlate(
    BuildContext context,
    AppState state,
    AppI18n i18n,
    ResponseCopyService copy,
    List<FoodRecommendation> recommendations,
    ValueChanged<String>? navigate,
    bool rankPresentationWithheld,
  ) {
    final text = Theme.of(context).textTheme;
    final hasTemplate =
        state.recommendationTemplateCountryCode != null &&
        state.recommendationTemplateMealSlot != null &&
        state.recommendationTemplateTextureLevel != null;
    return PaperPlate(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperSectionHeader(
            eyebrow: i18n.tr('dashboard.recommendation_path'),
            title: i18n.tr('dashboard.recommendations'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PaperPill(
                label: copy.recommendationPath(
                  state.recommendationDecisionPath,
                ),
                tone: PaperTone.accent,
                icon: Icons.alt_route_rounded,
              ),
              PaperPill(
                label: state.recommendationAiUsed
                    ? i18n.tr('dashboard.ai_used')
                    : i18n.tr('dashboard.ai_not_used'),
                icon: state.recommendationAiUsed
                    ? Icons.auto_awesome_outlined
                    : Icons.rule_rounded,
              ),
            ],
          ),
          if (hasTemplate) ...[
            const SizedBox(height: 8),
            Text(
              i18n.tr('dashboard.recommendation_template', {
                'region': i18n.regionLabel(
                  state.recommendationTemplateCountryCode!,
                ),
                'mealSlot': i18n.mealSlotLabel(
                  state.recommendationTemplateMealSlot!,
                ),
                'texture': i18n.textureClassLabel(
                  state.recommendationTemplateTextureLevel!,
                ),
              }),
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (rankPresentationWithheld)
            const RankedFoodPresentationWithheldNotice()
          else if (recommendations.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EmptyLine(
                icon: Icons.inbox_outlined,
                text: i18n.tr('dashboard.no_recommendations'),
              ),
            ),
          for (var i = 0; i < recommendations.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _RecommendationRow(
              name: i18n.foodName(
                recommendations[i].food.id,
                recommendations[i].food.name,
              ),
              decision: i18n.decisionLabel(recommendations[i].decision),
              macros: i18n.tr('dashboard.recommendation_macro_line', {
                'protein': recommendations[i].food.proteinG.toStringAsFixed(1),
                'carbs': recommendations[i].food.carbsG.toStringAsFixed(1),
                'fat': recommendations[i].food.fatG.toStringAsFixed(1),
              }),
              provenance:
                  '${recommendations[i].jurisdiction} · ${recommendations[i].food.sourceSystem}',
              breakdown: _localizedRecommendationBreakdown(
                i18n,
                recommendations[i],
              ),
              texture: _localizedFoodTextureSummary(i18n, recommendations[i]),
              reasons: [
                for (final reason in recommendations[i].reasons.take(3))
                  copy.recommendationMessage(reason),
              ],
              showLabel: i18n.tr('dashboard.show_details'),
              hideLabel: i18n.tr('dashboard.hide_details'),
            ),
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
              'value': state.averageProtein.toStringAsFixed(1),
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

/// A recommendation as one compact row; the score breakdown, texture note
/// and reasons fold out on demand instead of always filling the page.
class _RecommendationRow extends StatefulWidget {
  const _RecommendationRow({
    required this.name,
    required this.decision,
    required this.macros,
    required this.provenance,
    required this.breakdown,
    required this.texture,
    required this.reasons,
    required this.showLabel,
    required this.hideLabel,
  });

  final String name;
  final String decision;
  final String macros;
  final String provenance;
  final String breakdown;
  final String? texture;
  final List<String> reasons;
  final String showLabel;
  final String hideLabel;

  @override
  State<_RecommendationRow> createState() => _RecommendationRowState();
}

class _RecommendationRowState extends State<_RecommendationRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          hint: _expanded ? widget.hideLabel : widget.showLabel,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(Paper.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          widget.macros,
                          style: const TextStyle(
                            fontFamily: Paper.mono,
                            fontSize: 11.5,
                            color: Paper.inkSecondary,
                          ),
                        ),
                        Text(
                          widget.provenance,
                          style: const TextStyle(
                            fontFamily: Paper.mono,
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                            color: Paper.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PaperPill(label: widget.decision),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: Paper.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Paper.surfaceSunken,
                      borderRadius: BorderRadius.circular(Paper.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.breakdown,
                          style: const TextStyle(
                            fontFamily: Paper.mono,
                            fontSize: 11.5,
                            height: 1.5,
                            color: Paper.inkSecondary,
                          ),
                        ),
                        if (widget.texture != null) ...[
                          const SizedBox(height: 4),
                          Text(widget.texture!, style: text.bodySmall),
                        ],
                        if (widget.reasons.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          for (final reason in widget.reasons) _Bullet(reason),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Rounded icon tile used as a list leading mark.
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

/// A bullet line with a small gilt lozenge.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: 5, height: 5, color: Paper.gilt),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Paper.inkSecondary),
            ),
          ),
        ],
      ),
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
