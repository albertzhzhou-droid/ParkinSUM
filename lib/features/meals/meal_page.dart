import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/meal.dart';
import '../../core/state/app_state.dart';
import '../entry/entry_page.dart';
import '../shared/interaction_result_view.dart';

class MealPage extends StatelessWidget {
  const MealPage({super.key});

  Future<void> _showMealCheckDialog(BuildContext context, Meal meal) async {
    final result = await context.read<AppState>().checkMeal(meal);
    if (!context.mounted) return;
    final i18n = context.appI18n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.tr('meal.check_title', {'title': meal.title})),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: InteractionSummaryCard(result: result),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.tr('meal.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EntryPage()),
            ),
          ),
        ],
      ),
      body: state.meals.isEmpty
          ? Center(child: Text(i18n.tr('meal.empty')))
          : ListView.separated(
              itemCount: state.meals.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final meal = state.meals[i];
                final totals = meal.computeTotals();
                final result = context.read<AppState>().cachedMealCheck(meal);
                final accent = interactionSeverityColor(result.overallSeverity);

                return ListTile(
                  title: Text(meal.title),
                  subtitle: Text(
                    'P=${totals.totalProteinG.toStringAsFixed(1)}g '
                    'C=${totals.totalCarbsG.toStringAsFixed(1)}g '
                    'F=${totals.totalFatG.toStringAsFixed(1)}g '
                    '· ${i18n.tr('interaction.score', {
                          'value': '${result.score}'
                        })}',
                  ),
                  leading: CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.12),
                    foregroundColor: accent,
                    child: const Icon(Icons.restaurant_outlined),
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
                            builder: (_) => EntryPage(initialMeal: meal),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: i18n.tr('dashboard.delete'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            context.read<AppState>().deleteMeal(meal.id),
                      ),
                    ],
                  ),
                  onTap: () => _showMealCheckDialog(context, meal),
                );
              },
            ),
    );
  }
}
