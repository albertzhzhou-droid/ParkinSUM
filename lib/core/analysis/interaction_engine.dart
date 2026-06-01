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
    // Rule-finding/summary copy sourced through the compiler-validated registry;
    // the localized i18n string is the locale-strict fallback (non-en users keep
    // their translation). en output is byte-identical to app_i18n.
    const copy = ExplanationCopyService();
    final locale = i18n.languageFamily;
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
              title: copy.resolveForLocale(
                'legacy_high_protein_strong',
                locale: locale,
                fallback: i18n.tr('legacy.high_protein_strong'),
              ),
              detail: () {
                final bindings = {
                  'protein': totals.totalProteinG.toStringAsFixed(1),
                  'drug': localizedDrugName,
                };
                return copy.resolveForLocale(
                  'legacy_high_protein_strong_detail',
                  locale: locale,
                  bindings: bindings,
                  fallback:
                      i18n.tr('legacy.high_protein_strong_detail', bindings),
                );
              }(),
              relatedDrugId: d.id,
            ),
          );
        } else if (totals.totalProteinG >=
            NutritionRules.proteinInterferenceThresholdG) {
          score += _proteinTimingPenalty;
          issues.add(
            InteractionIssue(
              severity: InteractionSeverity.moderate,
              title: copy.resolveForLocale(
                'legacy_high_protein',
                locale: locale,
                fallback: i18n.tr('legacy.high_protein'),
              ),
              detail: () {
                final bindings = {
                  'protein': totals.totalProteinG.toStringAsFixed(1),
                  'drug': localizedDrugName,
                };
                return copy.resolveForLocale(
                  'legacy_high_protein_detail',
                  locale: locale,
                  bindings: bindings,
                  fallback: i18n.tr('legacy.high_protein_detail', bindings),
                );
              }(),
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
              title: copy.resolveForLocale(
                'legacy_tyramine',
                locale: locale,
                fallback: i18n.tr('legacy.tyramine'),
              ),
              detail: () {
                final bindings = {'drug': localizedDrugName};
                return copy.resolveForLocale(
                  'legacy_tyramine_detail',
                  locale: locale,
                  bindings: bindings,
                  fallback: i18n.tr('legacy.tyramine_detail', bindings),
                );
              }(),
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
              title: copy.resolveForLocale(
                'legacy_mineral',
                locale: locale,
                fallback: i18n.tr('legacy.mineral'),
              ),
              detail: copy.resolveForLocale(
                'legacy_mineral_detail',
                locale: locale,
                fallback: i18n.tr('legacy.mineral_detail'),
              ),
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
        message: copy.resolveForLocale(
          'legacy_no_conflict',
          locale: locale,
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
      summary: () {
        final bindings = {
          'score': '$boundedScore',
          'severity': severityLabel,
          'count': '${issues.length}',
        };
        return copy.resolveForLocale(
          'legacy_summary',
          locale: locale,
          bindings: bindings,
          fallback: i18n.tr('legacy.summary', bindings),
        );
      }(),
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
    // Boundary/result-framing copy sourced through the compiler-validated
    // registry; the localized i18n string is the locale-strict fallback.
    const copy = ExplanationCopyService();
    final locale = i18n.languageFamily;
    final analysisBindings = {
      'drugCount': '${drugs.length}',
      'score': '$score',
    };
    final proteinBindings = {
      'protein': totals.totalProteinG.toStringAsFixed(1),
    };
    final segments = <String>[
      copy.resolveForLocale(
        'legacy_analysis',
        locale: locale,
        bindings: analysisBindings,
        fallback: i18n.tr('legacy.analysis', analysisBindings),
      ),
      copy.resolveForLocale(
        'legacy_analysis_protein',
        locale: locale,
        bindings: proteinBindings,
        fallback: i18n.tr('legacy.analysis_protein', proteinBindings),
      ),
    ];

    if (meal.items.any((it) => it.foodTags.contains('high_tyramine'))) {
      segments.add(copy.resolveForLocale(
        'legacy_analysis_tyramine',
        locale: locale,
        fallback: i18n.tr('legacy.analysis_tyramine'),
      ));
    }
    segments.add(copy.resolveForLocale(
      'legacy_analysis_followup',
      locale: locale,
      fallback: i18n.tr('legacy.analysis_followup'),
    ));
    return segments.join(' ');
  }
}
