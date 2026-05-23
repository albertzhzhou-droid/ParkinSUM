import 'dart:convert';

import '../entities/cdss_runtime.dart';
import '../entities/rule_registry_models.dart';
import '../entities/runtime_context.dart';

/// Candidate produced after a declarative PDRL-like rule matches the runtime context.
class RuleEvaluationCandidate {
  final RuleRegistryEntry rule;
  final String explanation;
  final Map<String, dynamic> evidence;

  const RuleEvaluationCandidate({
    required this.rule,
    required this.explanation,
    required this.evidence,
  });
}

/// Runtime evaluator for patient-level drug/meal/conflict rules.
///
/// 当前状态说明：
/// - 已支持 all / any / not / cmp / in / exists / between / dose_band。
/// - 已支持基于 jurisdiction chain 的规则筛选和优先级排序。
/// - 数据库 rule_registry 的 schema validate / compile、rule trace artifact、
///   same-band escalation 由 ClinicalDecisionSupportService + RuntimeRuleSupport 负责。
class RuntimeRuleEngine {
  static const Map<RuntimeDecisionType, int> _strictnessOrder = {
    RuntimeDecisionType.block: 7,
    RuntimeDecisionType.requireReview: 6,
    RuntimeDecisionType.discourage: 5,
    RuntimeDecisionType.warn: 4,
    RuntimeDecisionType.info: 3,
    RuntimeDecisionType.allow: 2,
    RuntimeDecisionType.defer: 1,
  };

  List<String> resolveJurisdictionChain(
    UnifiedRuntimeContext context, {
    List<Map<String, Object?>> regionJurisdictionRows =
        const <Map<String, Object?>>[],
  }) {
    final chain = <String>[];

    void addAll(List<String> values) {
      for (final value in values) {
        final normalized = value.trim().toUpperCase();
        if (normalized.isEmpty || chain.contains(normalized)) continue;
        chain.add(normalized);
      }
    }

    addAll(context.userProfile.contentJurisdictionOverride);
    // registration_region 和 display_locale 必须分开处理。
    // 前者主要驱动数据/规则辖区，后者只提供可能的地区回退线索。
    addAll(
      _regionToJurisdictionChain(
        context.userProfile.registrationRegion,
        rows: regionJurisdictionRows,
      ),
    );

    final localeRegion = _regionFromBcp47(context.userProfile.displayLocale);
    if (localeRegion != null) {
      addAll(
        _regionToJurisdictionChain(
          localeRegion,
          rows: regionJurisdictionRows,
        ),
      );
    }

    addAll(['GLOBAL']);
    return chain;
  }

  String regionJurisdictionMapSource(
    UnifiedRuntimeContext context, {
    List<Map<String, Object?>> regionJurisdictionRows =
        const <Map<String, Object?>>[],
  }) {
    final regions = <String>{
      context.userProfile.registrationRegion.toUpperCase(),
      if (_regionFromBcp47(context.userProfile.displayLocale) != null)
        _regionFromBcp47(context.userProfile.displayLocale)!.toUpperCase(),
    }..removeWhere((value) => value.trim().isEmpty);
    if (regions.isEmpty) return 'runtime_static_map';
    final dbRegions = regionJurisdictionRows
        .map((row) => '${row['region_code'] ?? ''}'.toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    return regions.every(dbRegions.contains)
        ? 'database_region_jurisdiction_map'
        : 'runtime_static_map';
  }

  List<RuleEvaluationCandidate> evaluateCandidates({
    required UnifiedRuntimeContext context,
    required List<RuleRegistryEntry> rules,
    List<Map<String, Object?>> regionJurisdictionRows =
        const <Map<String, Object?>>[],
  }) {
    final candidates = <RuleEvaluationCandidate>[];
    final contextJson = context.toJson();
    final jurisdictionChain = resolveJurisdictionChain(
      context,
      regionJurisdictionRows: regionJurisdictionRows,
    );

    for (final rule in rules) {
      // 先按辖区过滤，避免把不适用辖区的规则误用于当前用户。
      if (!jurisdictionMatches(rule.jurisdictions, jurisdictionChain)) {
        continue;
      }
      final matched = _evaluateNode(rule.conditions, contextJson);
      if (matched) {
        candidates.add(
          RuleEvaluationCandidate(
            rule: rule,
            explanation: 'Rule ${rule.ruleId} matched target ${rule.target}.',
            evidence: {
              'jurisdiction_chain': jurisdictionChain,
              'source_refs': rule.provenance.sourceRefs,
            },
          ),
        );
      }
    }

    return candidates;
  }

  List<RuleEvaluationCandidate> resolveByPriority(
    List<RuleEvaluationCandidate> candidates, {
    required List<String> jurisdictionChain,
  }) {
    // 这里按词典序比较后再 reverse，是为了让“更强”的规则排在前面，后续 bucket.first 即 winner。
    final sorted = [...candidates]
      ..sort((a, b) => _compareRulePriority(a.rule, b.rule, jurisdictionChain));
    return sorted.reversed.toList(growable: false);
  }

  int _compareRulePriority(
    RuleRegistryEntry left,
    RuleRegistryEntry right,
    List<String> jurisdictionChain,
  ) {
    // 优先级顺序：
    // manual override > strictness > jurisdiction > specificity > authority > recency > rule id。
    // 最后一项 rule id 只作为稳定排序兜底；解释性 provenance score 在 service trace 中输出。
    final leftJurisdictionRank =
        _bestJurisdictionRank(left.jurisdictions, jurisdictionChain);
    final rightJurisdictionRank =
        _bestJurisdictionRank(right.jurisdictions, jurisdictionChain);

    return _compareTuple(
      [
        left.manualOverride ? 1 : 0,
        _strictnessOrder[left.thenClause.decision] ?? 0,
        left.priorityBand,
        -leftJurisdictionRank,
        left.specificityBand,
        left.sourceAuthority,
        left.provenance.effectiveFrom?.millisecondsSinceEpoch ?? 0,
        left.ruleId,
      ],
      [
        right.manualOverride ? 1 : 0,
        _strictnessOrder[right.thenClause.decision] ?? 0,
        right.priorityBand,
        -rightJurisdictionRank,
        right.specificityBand,
        right.sourceAuthority,
        right.provenance.effectiveFrom?.millisecondsSinceEpoch ?? 0,
        right.ruleId,
      ],
    );
  }

  int _compareTuple(List<Object> left, List<Object> right) {
    for (var i = 0; i < left.length; i++) {
      final l = left[i];
      final r = right[i];
      int comparison;
      if (l is num && r is num) {
        comparison = l.compareTo(r);
      } else {
        comparison = l.toString().compareTo(r.toString());
      }
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  bool _evaluateNode(Map<String, dynamic> node, Map<String, dynamic> context) {
    // 这里保持纯声明式求值，避免把规则重新写回硬编码 if/else。
    if (node.containsKey('all')) {
      final items = (node['all'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(growable: false);
      return items.every((child) => _evaluateNode(child, context));
    }
    if (node.containsKey('any')) {
      final items = (node['any'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(growable: false);
      return items.any((child) => _evaluateNode(child, context));
    }
    if (node.containsKey('not')) {
      return !_evaluateNode(
        Map<String, dynamic>.from(node['not'] as Map),
        context,
      );
    }
    if (node.containsKey('cmp')) {
      final cmp = Map<String, dynamic>.from(node['cmp'] as Map);
      final value = _lookup(context, cmp['path'] as String);
      final rhs = cmp['value'];
      final op = cmp['op'] as String;
      return _compare(value, rhs, op);
    }
    if (node.containsKey('in')) {
      final config = Map<String, dynamic>.from(node['in'] as Map);
      final value = _lookup(context, config['path'] as String);
      final options = (config['values'] as List<dynamic>).toList();
      if (value is List<dynamic>) {
        return value.any((entry) => options.contains(entry));
      }
      return options.contains(value);
    }
    if (node.containsKey('exists')) {
      final config = Map<String, dynamic>.from(node['exists'] as Map);
      final value = _lookup(context, config['path'] as String);
      return value != null;
    }
    if (node.containsKey('between')) {
      final config = Map<String, dynamic>.from(node['between'] as Map);
      final left = _lookup(context, config['left_path'] as String);
      final right = _lookup(context, config['right_path'] as String);
      final leftTime = _asDateTime(left);
      final rightTime = _asDateTime(right);
      // 时间窗比较要求上游已经把字段标准化成 ISO 字符串或 DateTime。
      // 若时间缺失，这里返回 false，后续由 service 层统一升级为 REQUIRE_REVIEW。
      if (leftTime == null || rightTime == null) return false;
      final unit = (config['unit'] as String?) ?? 'minutes';
      final delta = unit == 'hours'
          ? leftTime.difference(rightTime).inMinutes / 60.0
          : leftTime.difference(rightTime).inMinutes.toDouble();
      final low = (config['low'] as num).toDouble();
      final high = (config['high'] as num).toDouble();
      return delta >= low && delta <= high;
    }
    if (node.containsKey('dose_band')) {
      final config = Map<String, dynamic>.from(node['dose_band'] as Map);
      final value = _lookup(context, config['path'] as String);
      final normalizedValue = _normalizeDoseToMg(value, config);
      if (normalizedValue == null) return false;
      final low = (config['low'] as num?)?.toDouble();
      final high = (config['high'] as num?)?.toDouble();
      if (low != null || high != null) {
        return (low == null || normalizedValue >= low) &&
            (high == null || normalizedValue <= high);
      }
      final threshold = _normalizeDoseToMg(config['threshold'], config);
      final op = config['op'] as String;
      return threshold == null
          ? false
          : _compare(normalizedValue, threshold, op);
    }
    return false;
  }

  bool _compare(dynamic left, dynamic right, String op) {
    final l = _comparableValue(left, op);
    final r = _comparableValue(right, op);
    switch (op) {
      case 'eq':
        return l == r;
      case 'ne':
        return l != r;
      case 'gt':
        return l is num && r is num && l > r;
      case 'gte':
        return l is num && r is num && l >= r;
      case 'lt':
        return l is num && r is num && l < r;
      case 'lte':
        return l is num && r is num && l <= r;
      default:
        return false;
    }
  }

  dynamic _comparableValue(dynamic value, String op) {
    if (value is Map) {
      final qualifier = value['qualifier_kind']?.toString();
      if (qualifier == 'trace') return 0.0;
      final exact = value['value_num'] ?? value['value'];
      if (exact is num) return exact;
      if ((op == 'lt' || op == 'lte') && value['high'] is num) {
        return value['high'];
      }
      if ((op == 'gt' || op == 'gte') && value['low'] is num) {
        return value['low'];
      }
      if (value['low'] is num && value['high'] is num) {
        return ((value['low'] as num) + (value['high'] as num)) / 2.0;
      }
    }
    if (value is String && value.trim().toLowerCase() == 'trace') {
      return 0.0;
    }
    return value;
  }

  dynamic _lookup(Map<String, dynamic> map, String path) {
    dynamic value = map;
    for (final segment in path.split('.')) {
      if (value is Map<String, dynamic>) {
        value = value[segment];
      } else {
        return null;
      }
    }
    return value;
  }

  DateTime? _asDateTime(dynamic input) {
    if (input is DateTime) return input;
    if (input is String) return DateTime.tryParse(input);
    return null;
  }

  double? _normalizeDoseToMg(dynamic value, Map<String, dynamic> config) {
    if (value == null) return null;
    if (value is num) {
      final unit = (config['unit'] ?? config['value_unit'] ?? 'mg').toString();
      return _convertDoseToMg(value.toDouble(), unit);
    }
    if (value is String) {
      final match =
          RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Zµμ]+)?').firstMatch(value);
      if (match == null) return null;
      final amount = double.tryParse(match.group(1) ?? '');
      if (amount == null) return null;
      return _convertDoseToMg(amount, match.group(2) ?? 'mg');
    }
    if (value is Map) {
      final amount = value['value'] ?? value['amount'] ?? value['dose'];
      final unit = value['unit'] ?? config['unit'] ?? 'mg';
      if (amount is! num) return null;
      return _convertDoseToMg(amount.toDouble(), '$unit');
    }
    return null;
  }

  double? _convertDoseToMg(double amount, String unit) {
    final normalized = unit.trim().toLowerCase().split('/').first;
    switch (normalized) {
      case 'mg':
      case 'milligram':
      case 'milligrams':
        return amount;
      case 'g':
      case 'gram':
      case 'grams':
        return amount * 1000;
      case 'mcg':
      case 'ug':
      case 'µg':
      case 'μg':
      case 'microgram':
      case 'micrograms':
        return amount / 1000;
      default:
        return null;
    }
  }

  /// 对外公开给 service/support 层复用，避免重复实现辖区匹配。
  bool jurisdictionMatches(List<String> ruleJurisdictions, List<String> chain) {
    if (ruleJurisdictions.contains('*')) return true;
    return ruleJurisdictions
        .any((value) => chain.contains(value.toUpperCase()));
  }

  int _bestJurisdictionRank(
      List<String> ruleJurisdictions, List<String> chain) {
    if (ruleJurisdictions.contains('*')) return chain.length + 1;
    var best = -1;
    for (final jurisdiction in ruleJurisdictions) {
      final index = chain.indexOf(jurisdiction.toUpperCase());
      if (index == -1) continue;
      if (best == -1 || index < best) {
        best = index;
      }
    }
    return best == -1 ? 999 : best;
  }

  String? _regionFromBcp47(String localeTag) {
    final parts = localeTag.split('-');
    if (parts.length < 2) return null;
    return parts[1].toUpperCase();
  }

  List<String> _regionToJurisdictionChain(
    String region, {
    List<Map<String, Object?>> rows = const <Map<String, Object?>>[],
  }) {
    final dbChain = _regionChainFromRows(region, rows);
    if (dbChain.isNotEmpty) return dbChain;
    // 当前保留内置默认链作为数据库未初始化时的生产候选降级路径。
    switch (region.toUpperCase()) {
      case 'US':
        return const ['US', 'NA', 'GLOBAL'];
      case 'CA':
        return const ['CA', 'NA', 'GLOBAL'];
      case 'FR':
        return const ['FR', 'EU', 'GLOBAL'];
      case 'JP':
        return const ['JP', 'APAC', 'GLOBAL'];
      default:
        return const ['GLOBAL'];
    }
  }

  List<String> _regionChainFromRows(
    String region,
    List<Map<String, Object?>> rows,
  ) {
    final normalized = region.toUpperCase();
    for (final row in rows) {
      if ('${row['region_code'] ?? ''}'.toUpperCase() != normalized) continue;
      try {
        final decoded = jsonDecode('${row['jurisdiction_chain_json'] ?? '[]'}');
        if (decoded is! List) return const <String>[];
        return decoded
            .map((value) => value.toString().trim().toUpperCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
      } catch (_) {
        return const <String>[];
      }
    }
    return const <String>[];
  }
}

String toJsonLine(Map<String, dynamic> json) => '${jsonEncode(json)}\n';
