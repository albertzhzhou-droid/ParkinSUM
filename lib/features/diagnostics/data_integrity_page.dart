import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/usecases/data_integrity_report.dart';

/// Read-only view of whether user events and catalog inputs are computable.
///
/// Counts and ratios describe data availability only. They are not a clinical
/// score and do not claim that the underlying evidence coverage is adequate.
class DataIntegrityPage extends StatelessWidget {
  const DataIntegrityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final state = context.watch<AppState>();
    final report = DataIntegrityReport.assess(
      intakes: state.intakes,
      meals: state.meals,
      foods: state.foodRepo.allFoods,
      medications: state.medRepo.allDrugs,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text(i18n.tr('runtime.validation_source'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ReviewCard(report: report),
          const SizedBox(height: 12),
          _IntegritySection(
            title: i18n.tr('timeline.title'),
            icon: Icons.timeline_outlined,
            coverage: [
              _CoverageDatum(
                label: i18n.tr('missing.dose'),
                value: report.doseCoverage,
                count: report.intakesWithComputableDose,
                total: report.intakeCount,
              ),
              _CoverageDatum(
                label: i18n.tr('missing.formulation'),
                value: report.formulationSnapshotCoverage,
                count: report.intakesWithFormulationSnapshot,
                total: report.intakeCount,
              ),
              _CoverageDatum(
                label: i18n.tr('missing.meal_time'),
                value: report.mealTimeCoverage,
                count: report.mealsWithExplicitTime,
                total: report.mealCount,
              ),
              _CoverageDatum(
                label: i18n.tr('catalog.foods'),
                value: report.mealItemResolutionCoverage,
                count: report.resolvedMealItemCount,
                total: report.mealItemCount,
              ),
            ],
            issues: [
              _IssueDatum(
                label: i18n.tr('timeline.medication'),
                count: report.orphanedIntakeCount,
              ),
              _IssueDatum(
                label: i18n.tr('catalog.foods'),
                count: report.unresolvedMealItemCount,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _IntegritySection(
            title: i18n.tr('detail.source_label'),
            icon: Icons.source_outlined,
            coverage: [
              _CoverageDatum(
                label: i18n.tr('catalog.foods'),
                value: report.foodTraceabilityCoverage,
                count: report.traceableFoodCount,
                total: report.foodCount,
              ),
              _CoverageDatum(
                label: i18n.tr('timeline.medication'),
                value: report.medicationTraceabilityCoverage,
                count: report.traceableMedicationCount,
                total: report.medicationCount,
              ),
            ],
            issues: [
              _IssueDatum(
                label: i18n.tr('interaction.missing_input'),
                count: report.foodsWithMissingCoreNutrients,
              ),
              _IssueDatum(
                label: i18n.tr('missing.formulation'),
                count: report.medicationsWithIncompleteFormulation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.report});

  final DataIntegrityReport report;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final requiresReview = report.requiresReview;
    final color = requiresReview
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            requiresReview ? Icons.rule_outlined : Icons.verified_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n.tr(
                requiresReview ? 'decision.require_review' : 'common.done',
              ),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegritySection extends StatelessWidget {
  const _IntegritySection({
    required this.title,
    required this.icon,
    required this.coverage,
    required this.issues,
  });

  final String title;
  final IconData icon;
  final List<_CoverageDatum> coverage;
  final List<_IssueDatum> issues;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final datum in coverage) ...[
            Row(
              children: [
                Expanded(child: Text(datum.label)),
                Text(
                  datum.value == null
                      ? i18n.tr('common.not_available')
                      : '${datum.count}/${datum.total} '
                            '${(datum.value! * 100).round()}%',
                  style: const TextStyle(
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: datum.value ?? 0,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: LiquidGlass.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 14),
          ],
          const Divider(),
          for (final issue in issues)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                issue.count == 0
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: issue.count == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary,
              ),
              title: Text(issue.label),
              trailing: Text('${issue.count}'),
            ),
        ],
      ),
    );
  }
}

class _CoverageDatum {
  const _CoverageDatum({
    required this.label,
    required this.value,
    required this.count,
    required this.total,
  });

  final String label;
  final double? value;
  final int count;
  final int total;
}

class _IssueDatum {
  const _IssueDatum({required this.label, required this.count});

  final String label;
  final int count;
}
