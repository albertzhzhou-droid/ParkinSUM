import 'dart:collection';
import 'dart:convert';

import '../entities/rule_set_diff.dart';

/// Compares complete declarative-rule JSON, without compiling or activating it.
/// Object key order is ignored; all arrays, including the rule array, retain
/// order. Scalars retain the current runtime's JSON representation. The VM can
/// distinguish 1 from 1.0; JavaScript may already have collapsed that distinction.
/// This is not a cross-runtime lexical JSON comparison.
final class RuleSetDiffService {
  const RuleSetDiffService();

  RuleSetDiffReport compare({
    required List<Map<String, Object?>> beforeRules,
    required List<Map<String, Object?>> afterRules,
    RuleSetDiffLimits limits = const RuleSetDiffLimits(),
  }) {
    final budget = _JsonBudget(limits);
    final before = budget.rules(beforeRules);
    final after = budget.rules(afterRules);
    final beforeById = {
      for (final rule in before) rule['rule_id']! as String: rule,
    };
    final afterById = {
      for (final rule in after) rule['rule_id']! as String: rule,
    };
    final ids = {...beforeById.keys, ...afterById.keys}.toList()..sort();
    final changes = <RuleSetChange>[];
    final warnings = <RuleSetDiffWarning>[];
    final unchanged = <String>[];
    var fieldCount = 0;

    for (final id in ids) {
      final left = beforeById[id];
      final right = afterById[id];
      final fields = <RuleFieldChange>[];

      void record(
        String path,
        bool leftPresent,
        Object? leftValue,
        bool rightPresent,
        Object? rightValue,
      ) {
        if (++fieldCount > limits.maxFieldChanges) {
          throw const FormatException('rule_set_diff_field_change_limit');
        }
        fields.add(
          RuleFieldChange(
            path: path,
            beforePresent: leftPresent,
            afterPresent: rightPresent,
            beforeValue: leftValue,
            afterValue: rightValue,
          ),
        );
      }

      void walk(String path, Object? a, Object? b) {
        if (a is Map<String, Object?> && b is Map<String, Object?>) {
          final keys = {...a.keys, ...b.keys}.toList()..sort();
          for (final key in keys) {
            final child = '$path/${_pointerToken(key)}';
            if (!a.containsKey(key) || !b.containsKey(key)) {
              record(
                child,
                a.containsKey(key),
                a[key],
                b.containsKey(key),
                b[key],
              );
            } else {
              walk(child, a[key], b[key]);
            }
          }
        } else if (a is List<Object?> && b is List<Object?>) {
          final length = a.length > b.length ? a.length : b.length;
          for (var index = 0; index < length; index++) {
            final child = '$path/$index';
            if (index >= a.length || index >= b.length) {
              record(
                child,
                index < a.length,
                index < a.length ? a[index] : null,
                index < b.length,
                index < b.length ? b[index] : null,
              );
            } else {
              walk(child, a[index], b[index]);
            }
          }
        } else if (!_equalScalar(a, b)) {
          record(path, true, a, true, b);
        }
      }

      if (left == null || right == null) {
        record('', left != null, left, right != null, right);
      } else {
        walk('', left, right);
      }
      if (fields.isEmpty) {
        unchanged.add(id);
        continue;
      }
      final change = RuleSetChange(
        ruleId: id,
        kind: left == null
            ? RuleSetChangeKind.added
            : right == null
            ? RuleSetChangeKind.removed
            : RuleSetChangeKind.changed,
        beforeRule: left,
        afterRule: right,
        fields: fields,
      );
      changes.add(change);
      if (change.sameVersionDifferentContent) {
        warnings.add(
          RuleSetDiffWarning(
            ruleId: id,
            code: 'same_version_different_content',
            message:
                'Rule content changed without changing its explicit version.',
          ),
        );
      } else if (change.kind == RuleSetChangeKind.changed &&
          (change.beforeVersion == null || change.afterVersion == null)) {
        warnings.add(
          RuleSetDiffWarning(
            ruleId: id,
            code: 'changed_rule_without_comparable_version',
            message:
                'Changed rule has a missing or invalid explicit version; '
                'version continuity cannot be established.',
          ),
        );
      }
    }

    final beforeOrder = beforeById.keys.toList();
    final afterOrder = afterById.keys.toList();
    return RuleSetDiffReport(
      beforeRuleOrder: beforeOrder,
      afterRuleOrder: afterOrder,
      ruleOrderChanged: jsonEncode(beforeOrder) != jsonEncode(afterOrder),
      unchangedRuleIds: unchanged,
      changes: changes,
      warnings: warnings,
    );
  }

  static String _pointerToken(String value) =>
      value.replaceAll('~', '~0').replaceAll('/', '~1');

  static bool _equalScalar(Object? a, Object? b) {
    if (a is Map || a is List || b is Map || b is List) return false;
    return jsonEncode(a) == jsonEncode(b);
  }
}

final class _JsonBudget {
  _JsonBudget(this.limits) {
    if (limits.maxRules < 1 ||
        limits.maxDepth < 1 ||
        limits.maxDepth > 64 ||
        limits.maxNodes < 1 ||
        limits.maxPayloadBytes < 1 ||
        limits.maxStringLength < 1 ||
        limits.maxFieldChanges < 1) {
      throw const FormatException('rule_set_diff_invalid_limits');
    }
  }

  final RuleSetDiffLimits limits;
  final _ancestors = HashSet<Object>.identity();
  var _nodes = 0;
  var _bytes = 0;

  List<Map<String, Object?>> rules(List<Map<String, Object?>> input) {
    if (input.length > limits.maxRules) {
      throw const FormatException('rule_set_diff_rule_count_limit');
    }
    final result = (_freeze(input, 0) as List<Object?>)
        .cast<Map<String, Object?>>();
    final ids = <String>{};
    for (final rule in result) {
      final id = rule['rule_id'];
      if (id is! String ||
          id.trim().isEmpty ||
          id.length > 512 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(id) ||
          !ids.add(id)) {
        throw const FormatException(
          'rule_set_diff_invalid_or_duplicate_rule_id',
        );
      }
    }
    return List.unmodifiable(result);
  }

  Object? _freeze(Object? value, int depth) {
    if (depth > limits.maxDepth) {
      throw const FormatException('rule_set_diff_depth_limit');
    }
    if (++_nodes > limits.maxNodes) {
      throw const FormatException('rule_set_diff_node_limit');
    }
    if (value == null || value is bool || value is int || value is double) {
      if (value is double && !value.isFinite) {
        throw const FormatException('rule_set_diff_non_json_number');
      }
      _addBytes(jsonEncode(value).length);
      return value;
    }
    if (value is String) {
      _stringBytes(value);
      return value;
    }
    if (value is! Map && value is! List) {
      throw const FormatException('rule_set_diff_non_json_value');
    }
    if (!_ancestors.add(value)) {
      throw const FormatException('rule_set_diff_cyclic_json');
    }
    try {
      if (value is Map) {
        _checkChildCount(value.length);
        if (value.keys.any((key) => key is! String)) {
          throw const FormatException('rule_set_diff_non_string_key');
        }
        final keys = value.keys.cast<String>().toList()..sort();
        _addBytes(2 + (keys.isEmpty ? 0 : keys.length - 1) + keys.length);
        final frozen = <String, Object?>{};
        for (final key in keys) {
          _stringBytes(key);
          frozen[key] = _freeze(value[key], depth + 1);
        }
        return Map<String, Object?>.unmodifiable(frozen);
      }
      final items = value as List;
      _checkChildCount(items.length);
      _addBytes(2 + (items.isEmpty ? 0 : items.length - 1));
      return List<Object?>.unmodifiable(
        items.map((item) => _freeze(item, depth + 1)),
      );
    } finally {
      _ancestors.remove(value);
    }
  }

  void _stringBytes(String value) {
    if (value.length > limits.maxStringLength ||
        value.length > limits.maxPayloadBytes - _bytes) {
      throw const FormatException('rule_set_diff_string_or_payload_limit');
    }
    _addBytes(utf8.encode(jsonEncode(value)).length);
  }

  void _checkChildCount(int count) {
    if (count > limits.maxNodes - _nodes) {
      throw const FormatException('rule_set_diff_node_limit');
    }
  }

  void _addBytes(int amount) {
    _bytes += amount;
    if (_bytes > limits.maxPayloadBytes) {
      throw const FormatException('rule_set_diff_payload_limit');
    }
  }
}
