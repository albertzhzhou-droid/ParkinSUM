import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/response_copy_service.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/models/meal.dart';
import '../../core/state/app_state.dart';
import '../../domain/entities/food_recommendation.dart';
import '../../domain/entities/timeline_event.dart';
import '../entry/entry_page.dart';
import '../shared/interaction_result_view.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _showMealCheckDialog(BuildContext context, Meal meal) async {
    final result = await context.read<AppState>().checkMeal(meal);
    if (!context.mounted) return;
    final i18n = context.appI18n;
    final copy = ResponseCopyService(i18n: i18n);
    final state = context.read<AppState>();
    final templateSummary = _currentRecommendationTemplateSummary(state, i18n);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.tr('dashboard.meal_check', {'title': meal.title})),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i18n.tr('dashboard.recommendation_path')}: '
                  '${copy.recommendationPath(state.recommendationDecisionPath)}',
                  style: const TextStyle(color: Colors.black54),
                ),
                if (templateSummary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    templateSummary,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                InteractionSummaryCard(result: result),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(i18n.tr('common.close')),
          ),
        ],
      ),
    );
  }

  String? _currentRecommendationTemplateSummary(AppState state, AppI18n i18n) {
    final region = state.recommendationTemplateCountryCode;
    final mealSlot = state.recommendationTemplateMealSlot;
    final texture = state.recommendationTemplateTextureLevel;
    if (region == null || mealSlot == null || texture == null) {
      return null;
    }
    return i18n.tr(
      'dashboard.recommendation_template',
      {
        'region': i18n.regionLabel(region),
        'mealSlot': i18n.mealSlotLabel(mealSlot),
        'texture': i18n.textureClassLabel(texture),
      },
    );
  }

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
    if (event.type == TimelineEventType.medication && event.entityId != null) {
      return i18n.medicationName(event.entityId!, event.title);
    }
    return event.title;
  }

  String? _localizedMealContextSummary(AppI18n i18n, Meal meal) {
    final parts = <String>[];
    if (meal.coeventSubstanceTags.contains('iron_salt')) {
      parts.add(i18n.tr('dashboard.meal_context_iron_supplement'));
    }
    if (meal.coeventSubstanceTags.contains('multivitamin_with_iron')) {
      parts.add(i18n.tr('dashboard.meal_context_iron_multivitamin'));
    }
    if (meal.thickenerType == 'starch_based') {
      parts.add(i18n.tr('dashboard.meal_context_starch_thickener'));
    } else if (meal.thickenerType == 'xanthan_based') {
      parts.add(i18n.tr('dashboard.meal_context_xanthan_thickener'));
    }
    if (meal.enteralFeedMode == 'continuous') {
      parts.add(i18n.tr(
        'dashboard.meal_context_enteral_feed_continuous',
        {
          'protein': meal.enteralFeedProteinGPerDay?.toStringAsFixed(0) ??
              'unspecified',
        },
      ));
    } else if (meal.enteralFeedMode == 'bolus') {
      parts.add(i18n.tr('dashboard.meal_context_enteral_feed_bolus'));
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
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
    return i18n.tr(
      'dashboard.recommendation_score_line',
      {
        'safety': safety.toStringAsFixed(2),
        'schedule': schedule.toStringAsFixed(2),
        'facts': facts.toStringAsFixed(2),
        'context': contextPenalty.toStringAsFixed(1),
        'timing': timingPenalty.toStringAsFixed(1),
        'swallowing': swallowingPenalty.toStringAsFixed(1),
        'template': templateAffinity.toStringAsFixed(2),
      },
    );
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
    final meals = state.meals.take(5).toList();
    final timeline = state.timeline.take(10).toList();
    final recommendations = state.recommendations.take(3).toList();
    final trend = state.proteinTrend;
    final copy = ResponseCopyService(i18n: i18n);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.tr('dashboard.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('dashboard.status'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(i18n.tr('dashboard.logged_meals',
                      {'count': '${state.meals.length}'})),
                  Text(i18n.tr('dashboard.active_drugs',
                      {'count': '${state.activeDrugs.length}'})),
                  Text(i18n.tr('dashboard.logged_intakes',
                      {'count': '${state.intakes.length}'})),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('dashboard.recommendations'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (recommendations.isEmpty)
                    Text(i18n.tr('dashboard.no_recommendations')),
                  Text(
                    '${i18n.tr('dashboard.recommendation_path')}: '
                    '${copy.recommendationPath(state.recommendationDecisionPath)}',
                  ),
                  if (state.recommendationTemplateCountryCode != null &&
                      state.recommendationTemplateMealSlot != null &&
                      state.recommendationTemplateTextureLevel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      i18n.tr(
                        'dashboard.recommendation_template',
                        {
                          'region': i18n.regionLabel(
                            state.recommendationTemplateCountryCode!,
                          ),
                          'mealSlot': i18n.mealSlotLabel(
                            state.recommendationTemplateMealSlot!,
                          ),
                          'texture': i18n.textureClassLabel(
                            state.recommendationTemplateTextureLevel!,
                          ),
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    state.recommendationAiUsed
                        ? i18n.tr('dashboard.ai_used')
                        : i18n.tr('dashboard.ai_not_used'),
                  ),
                  if (state.recommendationExplanations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('dashboard.recommendation_why'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    for (final line in state.recommendationExplanations.take(2))
                      Text('• ${copy.recommendationMessage(line)}'),
                  ],
                  if (state.recommendationGateReasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('dashboard.recommendation_gate'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    for (final reason
                        in state.recommendationGateReasons.take(4))
                      Text('• ${copy.recommendationMessage(reason)}'),
                  ],
                  const SizedBox(height: 8),
                  for (final recommendation in recommendations)
                    Builder(
                      builder: (context) {
                        final textureSummary = _localizedFoodTextureSummary(
                          i18n,
                          recommendation,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i18n.foodName(
                                  recommendation.food.id,
                                  recommendation.food.name,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${i18n.decisionLabel(recommendation.decision)} · ${recommendation.jurisdiction} · ${recommendation.food.sourceSystem}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                i18n.tr(
                                  'dashboard.recommendation_macro_line',
                                  {
                                    'protein': recommendation.food.proteinG
                                        .toStringAsFixed(1),
                                    'carbs': recommendation.food.carbsG
                                        .toStringAsFixed(1),
                                    'fat': recommendation.food.fatG
                                        .toStringAsFixed(1),
                                  },
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _localizedRecommendationBreakdown(
                                  i18n,
                                  recommendation,
                                ),
                                style: const TextStyle(color: Colors.black54),
                              ),
                              if (textureSummary != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  textureSummary,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                              if (recommendation.reasons.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                for (final reason
                                    in recommendation.reasons.take(3))
                                  Text(
                                      '• ${copy.recommendationMessage(reason)}'),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('dashboard.recent_meals'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (meals.isEmpty) Text(i18n.tr('dashboard.no_meals')),
                  for (final meal in meals)
                    Builder(
                      builder: (context) {
                        final result =
                            context.read<AppState>().cachedMealCheck(meal);
                        final mealContextSummary =
                            _localizedMealContextSummary(i18n, meal);
                        final accent =
                            interactionSeverityColor(result.overallSeverity);
                        return ListTile(
                          title: Text(meal.title),
                          subtitle: Text(
                            [
                              '${_formatDateTime(meal.eatenAt)} · ${i18n.tr('dashboard.items', {
                                    'count': '${meal.items.length}'
                                  })} · ${i18n.tr('interaction.score', {
                                    'value': '${result.score}'
                                  })}',
                              if (mealContextSummary != null)
                                mealContextSummary,
                            ].join('\n'),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: accent.withValues(alpha: 0.12),
                            foregroundColor: accent,
                            child: const Icon(Icons.restaurant_menu),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: i18n.tr('dashboard.edit'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EntryPage(initialMeal: meal),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: i18n.tr('dashboard.delete'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => context
                                    .read<AppState>()
                                    .deleteMeal(meal.id),
                              ),
                            ],
                          ),
                          onTap: () => _showMealCheckDialog(context, meal),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('dashboard.protein_trend'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(i18n.tr('dashboard.average_protein',
                      {'value': state.averageProtein.toStringAsFixed(1)})),
                  const SizedBox(height: 8),
                  if (trend.isEmpty) Text(i18n.tr('dashboard.no_trend')),
                  for (final point in trend.take(5).toList().reversed)
                    Text(
                      '${_formatDateTime(point.time)} · ${point.protein.toStringAsFixed(1)} g',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('dashboard.timeline'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (timeline.isEmpty) Text(i18n.tr('dashboard.no_timeline')),
                  for (final event in timeline.take(10))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            _timelineColor(event.type).withValues(alpha: 0.12),
                        foregroundColor: _timelineColor(event.type),
                        child: Icon(_timelineIcon(event.type)),
                      ),
                      title: Text(_localizedTimelineTitle(i18n, event)),
                      subtitle: Text(
                          '${_formatDateTime(event.time)} · ${_localizedTimelineDescription(i18n, event)}'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(i18n.tr('dashboard.add_meal')),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EntryPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _timelineColor(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Colors.teal;
      case TimelineEventType.medication:
        return Colors.indigo;
    }
  }

  IconData _timelineIcon(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Icons.restaurant_outlined;
      case TimelineEventType.medication:
        return Icons.medication_outlined;
    }
  }
}
