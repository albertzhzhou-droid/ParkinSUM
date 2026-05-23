import '../entities/rule_registry_models.dart';
import '../entities/runtime_context.dart';
import 'runtime_rule_engine.dart';

/// 运行时规则辅助模块：
/// - 把“哪些字段缺失会影响哪些规则”从 service 主流程里拆出来；
/// - 保持规则引擎本身仍然只负责 declarative condition evaluation；
/// - 避免随着规则增多，ClinicalDecisionSupportService 继续膨胀成单文件判断器。
class RuntimeRuleSupport {
  const RuntimeRuleSupport();

  /// 只对当前 bucket 相关规则提取缺失字段，避免无关字段把整个结果误升级。
  Set<String> collectRelevantMissingFields({
    required UnifiedRuntimeContext context,
    required List<RuleRegistryEntry> rules,
  }) {
    final missing = <String>{};
    for (final rule in rules) {
      missing.addAll(missingFieldsForRule(context: context, rule: rule));
    }
    return missing;
  }

  Set<String> missingFieldsForRule({
    required UnifiedRuntimeContext context,
    required RuleRegistryEntry rule,
  }) {
    final missing = <String>{};
    for (final path in collectReferencedPaths(rule.conditions)) {
      final field = _fieldCodeFromPath(path);
      if (field == null) continue;
      if (_isFieldMissing(context, field)) {
        missing.add(field);
      }
    }
    return missing;
  }

  /// 检测是否存在“同一 target、同优先带、不同决策”的硬冲突。
  bool hasSameBandDecisionConflict(List<RuleEvaluationCandidate> bucket) {
    if (bucket.length < 2) return false;
    final winner = bucket.first;
    return bucket.skip(1).any(
          (candidate) =>
              candidate.rule.priorityBand == winner.rule.priorityBand &&
              candidate.rule.thenClause.decision !=
                  winner.rule.thenClause.decision,
        );
  }

  SameBandEscalation evaluateSameBandEscalation(
    List<RuleEvaluationCandidate> bucket,
  ) {
    if (bucket.length < 2) {
      return const SameBandEscalation(
        requiresReview: false,
        reason: 'single_candidate',
        suppressedRuleIds: <String>[],
      );
    }
    final winner = bucket.first;
    final sameBand = bucket
        .skip(1)
        .where((candidate) =>
            candidate.rule.priorityBand == winner.rule.priorityBand)
        .toList(growable: false);
    if (sameBand.isEmpty) {
      return const SameBandEscalation(
        requiresReview: false,
        reason: 'different_priority_band',
        suppressedRuleIds: <String>[],
      );
    }
    final decisionConflict = sameBand.any(
      (candidate) =>
          candidate.rule.thenClause.decision != winner.rule.thenClause.decision,
    );
    final sameDecisionLowerProvenance = sameBand.any(
      (candidate) =>
          candidate.rule.thenClause.decision ==
              winner.rule.thenClause.decision &&
          candidate.rule.sourceAuthority < winner.rule.sourceAuthority,
    );
    if (decisionConflict) {
      final matrixReason = _sameBandMatrixReason([
        winner.rule,
        ...sameBand.map((candidate) => candidate.rule),
      ]);
      return SameBandEscalation(
        requiresReview: true,
        reason: matrixReason,
        suppressedRuleIds:
            sameBand.map((candidate) => candidate.rule.ruleId).toList(),
      );
    }
    return SameBandEscalation(
      requiresReview: false,
      reason: sameDecisionLowerProvenance
          ? 'same_decision_provenance_tiebreak'
          : 'same_band_consistent',
      suppressedRuleIds:
          sameBand.map((candidate) => candidate.rule.ruleId).toList(),
    );
  }

  String _sameBandMatrixReason(List<RuleRegistryEntry> rules) {
    final decisions =
        rules.map((rule) => rule.thenClause.decision.wireValue).toSet();
    if (decisions.contains('BLOCK')) {
      return 'same_band_block_conflict';
    }
    if (decisions.contains('REQUIRE_REVIEW')) {
      return 'same_band_review_conflict';
    }
    if (decisions.contains('DISCOURAGE') &&
        (decisions.contains('ALLOW') || decisions.contains('INFO'))) {
      return 'same_band_discourage_permissive_conflict';
    }
    if (decisions.contains('WARN') &&
        (decisions.contains('ALLOW') || decisions.contains('INFO'))) {
      return 'same_band_warn_permissive_conflict';
    }
    return 'same_band_decision_conflict';
  }

  Set<String> collectReferencedPaths(Map<String, dynamic> node) {
    final paths = <String>{};
    if (node.containsKey('all')) {
      for (final child in (node['all'] as List<dynamic>)) {
        paths.addAll(
            collectReferencedPaths(Map<String, dynamic>.from(child as Map)));
      }
    }
    if (node.containsKey('any')) {
      for (final child in (node['any'] as List<dynamic>)) {
        paths.addAll(
            collectReferencedPaths(Map<String, dynamic>.from(child as Map)));
      }
    }
    if (node.containsKey('not')) {
      paths.addAll(
        collectReferencedPaths(Map<String, dynamic>.from(node['not'] as Map)),
      );
    }
    if (node.containsKey('cmp')) {
      final cmp = Map<String, dynamic>.from(node['cmp'] as Map);
      paths.add('${cmp['path']}');
    }
    if (node.containsKey('in')) {
      final config = Map<String, dynamic>.from(node['in'] as Map);
      paths.add('${config['path']}');
    }
    if (node.containsKey('exists')) {
      final config = Map<String, dynamic>.from(node['exists'] as Map);
      paths.add('${config['path']}');
    }
    if (node.containsKey('between')) {
      final config = Map<String, dynamic>.from(node['between'] as Map);
      paths.add('${config['left_path']}');
      paths.add('${config['right_path']}');
    }
    if (node.containsKey('dose_band')) {
      final config = Map<String, dynamic>.from(node['dose_band'] as Map);
      paths.add('${config['path']}');
    }
    return paths;
  }

  String? _fieldCodeFromPath(String path) {
    switch (path) {
      case 'drug.daily_dose_mg':
        return 'dose';
      case 'drug.formulation':
      case 'drug.dosage_form':
      case 'drug.release_type':
        return 'formulation';
      case 'drug.start_at':
      case 'timestamps.drug_time':
        return 'time';
      case 'meal.start_at':
      case 'timestamps.meal_time':
        return 'meal_time';
      case 'coevent.start_at':
      case 'timestamps.coevent_time':
        return 'coevent_time';
      case 'coevent.thickener_type':
        return 'thickener_type';
      case 'enteral_feed.protein_g_per_day':
        return 'enteral_feed_protein';
      default:
        return null;
    }
  }

  bool _isFieldMissing(UnifiedRuntimeContext context, String field) {
    switch (field) {
      case 'dose':
        return context.drug.dailyDoseMg == null;
      case 'formulation':
        return context.drug.formulation.isEmpty ||
            context.drug.dosageForm.isEmpty ||
            context.drug.releaseType.isEmpty;
      case 'time':
        return context.timestamps.drugTime == null;
      case 'meal_time':
        return context.meal != null && context.timestamps.mealTime == null;
      case 'coevent_time':
        return context.coevent != null &&
            context.timestamps.coeventTime == null;
      case 'thickener_type':
        return context.coevent != null &&
            context.coevent!.thickenerType == null;
      case 'enteral_feed_protein':
        return context.enteralFeed != null &&
            context.enteralFeed!.proteinGPerDay == null;
      default:
        return false;
    }
  }
}

class SameBandEscalation {
  final bool requiresReview;
  final String reason;
  final List<String> suppressedRuleIds;

  const SameBandEscalation({
    required this.requiresReview,
    required this.reason,
    required this.suppressedRuleIds,
  });
}
