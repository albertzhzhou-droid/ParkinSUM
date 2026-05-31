import '../../domain/usecases/explanation_copy_service.dart';
import '../i18n/app_i18n.dart';
import '../models/drug_definition.dart';
import '../models/interaction_result.dart';
import '../models/meal.dart';
import 'nutrition_rules.dart';

/// InteractionEngine：
/// 将“饮食特征”与“药物规则”做匹配，输出可解释的 InteractionResult。
class InteractionEngine {
  static const int _proteinTimingPenalty = 45;
  static const int _proteinTimingStrongPenalty = 65;
  static const int _tyraminePenalty = 90;
  static const int _mineralTimingPenalty = 25;

  /// 评估：某一餐 + 多个药物
  InteractionResult evaluateMealWithDrugs({
    required Meal meal,
    required List<DrugDefinition> drugs,
    String localeTag = 'en-US',
  }) {
    final i18n = AppI18n.fromLocaleTag(localeTag);
    final issues = <InteractionIssue>[];
    var score = 0;

    // 计算餐的宏量营养合计（非常简化：按条目 sum）
    final totals = meal.computeTotals();

    for (final d in drugs) {
      final localizedDrugName = i18n.medicationName(d.id, d.displayName);
      // 规则 1：Levodopa/Carbidopa 类（示例）——蛋白影响吸收
      if (d.tags.contains(DrugTag.levodopaLike)) {
        if (totals.totalProteinG >=
            NutritionRules.proteinInterferenceThresholdG + 15) {
          score += _proteinTimingStrongPenalty;
          issues.add(
            InteractionIssue(
              severity: InteractionSeverity.high,
              title: i18n.tr('legacy.high_protein_strong'),
              detail: i18n.tr(
                'legacy.high_protein_strong_detail',
                {
                  'protein': totals.totalProteinG.toStringAsFixed(1),
                  'drug': localizedDrugName,
                },
              ),
              relatedDrugId: d.id,
            ),
          );
        } else if (totals.totalProteinG >=
            NutritionRules.proteinInterferenceThresholdG) {
          score += _proteinTimingPenalty;
          issues.add(
            InteractionIssue(
              severity: InteractionSeverity.moderate,
              title: i18n.tr('legacy.high_protein'),
              detail: i18n.tr(
                'legacy.high_protein_detail',
                {
                  'protein': totals.totalProteinG.toStringAsFixed(1),
                  'drug': localizedDrugName,
                },
              ),
              relatedDrugId: d.id,
            ),
          );
        }
      }

      // 规则 2：MAOI（示例）——高酪胺风险（这里只做占位规则）
      if (d.tags.contains(DrugTag.maoi)) {
        final hasHighTyramine =
            meal.items.any((it) => it.foodTags.contains('high_tyramine'));
        if (hasHighTyramine) {
          score += _tyraminePenalty;
          issues.add(
            InteractionIssue(
              severity: InteractionSeverity.high,
              title: i18n.tr('legacy.tyramine'),
              detail: i18n.tr(
                'legacy.tyramine_detail',
                {'drug': localizedDrugName},
              ),
              relatedDrugId: d.id,
            ),
          );
        }
      }

      // 规则 3：铁/钙补充剂（示例）——与部分药物存在螯合/吸收影响（占位）
      if (d.tags.contains(DrugTag.mineralSupplement)) {
        final calciumLikelyHigh = totals.totalProteinG > 0 &&
            meal.items.any((it) => it.foodCategoryName == 'dairy');
        if (calciumLikelyHigh) {
          score += _mineralTimingPenalty;
          issues.add(
            InteractionIssue(
              severity: InteractionSeverity.low,
              title: i18n.tr('legacy.mineral'),
              detail: i18n.tr('legacy.mineral_detail'),
              relatedDrugId: d.id,
            ),
          );
        }
      }
    }

    // 如果没有任何问题，给一个“通过”提示
    if (issues.isEmpty) {
      return InteractionResult.ok(
        // Boundary copy sourced through the compiler-validated registry; the
        // localized i18n string is the fallback (locale-strict — non-en users
        // keep their translation).
        message: const ExplanationCopyService().resolveForLocale(
          'legacy_no_conflict',
          locale: i18n.languageFamily,
          fallback: i18n.tr('legacy.no_conflict'),
        ),
        mealId: meal.id,
      );
    }

    final boundedScore = score.clamp(0, 100).toInt();
    final severityLabel = boundedScore >= 70
        ? i18n.tr('legacy.severity.high')
        : boundedScore >= 30
            ? i18n.tr('legacy.severity.moderate')
            : i18n.tr('legacy.severity.low');

    // 否则返回带问题的结果
    return InteractionResult(
      mealId: meal.id,
      status: InteractionStatus.warning,
      summary: i18n.tr(
        'legacy.summary',
        {
          'score': '$boundedScore',
          'severity': severityLabel,
          'count': '${issues.length}',
        },
      ),
      analysisText: _buildLegacyAnalysisText(
        i18n: i18n,
        meal: meal,
        drugs: drugs,
        score: boundedScore,
        totals: totals,
      ),
      issues: issues,
      generatedAt: DateTime.now(),
      score: boundedScore,
    );
  }

  /// 旧规则引擎的分析说明：
  /// - 明确告诉用户这是 built-in heuristic 路径；
  /// - 让“分析完之后”的文本不再缺失。
  String _buildLegacyAnalysisText({
    required AppI18n i18n,
    required Meal meal,
    required List<DrugDefinition> drugs,
    required int score,
    required MealTotals totals,
  }) {
    final segments = <String>[
      i18n.tr(
        'legacy.analysis',
        {
          'drugCount': '${drugs.length}',
          'score': '$score',
        },
      ),
      i18n.tr(
        'legacy.analysis_protein',
        {'protein': totals.totalProteinG.toStringAsFixed(1)},
      ),
    ];

    if (meal.items.any((it) => it.foodTags.contains('high_tyramine'))) {
      segments.add(i18n.tr('legacy.analysis_tyramine'));
    }
    segments.add(i18n.tr('legacy.analysis_followup'));
    return segments.join(' ');
  }
}
