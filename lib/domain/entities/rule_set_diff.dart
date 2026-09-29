const ruleSetDiffReportSchemaVersion = 1;

/// Structural comparison only. It does not approve rules or assess their
/// clinical meaning, provenance authenticity, or runtime behavior.
enum RuleSetChangeKind { added, removed, changed }

/// A JSON Pointer relative to one complete rule. The empty path identifies the
/// whole rule. Presence flags distinguish a missing value from JSON null.
final class RuleFieldChange {
  const RuleFieldChange({
    required this.path,
    required this.beforePresent,
    required this.afterPresent,
    required this.beforeValue,
    required this.afterValue,
  });

  final String path;
  final bool beforePresent;
  final bool afterPresent;
  // The service supplies deeply immutable, validated JSON snapshots.
  final Object? beforeValue;
  final Object? afterValue;

  Map<String, Object?> toJson() => {
    'path': path,
    'beforePresent': beforePresent,
    'afterPresent': afterPresent,
    'beforeValue': beforeValue,
    'afterValue': afterValue,
  };
}

final class RuleSetChange {
  RuleSetChange({
    required this.ruleId,
    required this.kind,
    required this.beforeRule,
    required this.afterRule,
    required Iterable<RuleFieldChange> fields,
  }) : fields = List.unmodifiable(fields);

  final String ruleId;
  final RuleSetChangeKind kind;
  final Map<String, Object?>? beforeRule;
  final Map<String, Object?>? afterRule;
  final List<RuleFieldChange> fields;

  String? get beforeVersion => _version(beforeRule);
  String? get afterVersion => _version(afterRule);
  bool get sameVersionDifferentContent =>
      kind == RuleSetChangeKind.changed &&
      beforeVersion != null &&
      beforeVersion == afterVersion;

  static String? _version(Map<String, Object?>? rule) {
    final value = rule?['version'];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  Map<String, Object?> toJson() => {
    'ruleId': ruleId,
    'kind': kind.name,
    'beforeRule': beforeRule,
    'afterRule': afterRule,
    'fields': fields.map((field) => field.toJson()).toList(),
    'sameVersionDifferentContent': sameVersionDifferentContent,
  };
}

final class RuleSetDiffWarning {
  const RuleSetDiffWarning({
    required this.ruleId,
    required this.code,
    required this.message,
  });

  final String ruleId;
  final String code;
  final String message;

  Map<String, Object?> toJson() => {
    'ruleId': ruleId,
    'code': code,
    'message': message,
  };
}

final class RuleSetDiffReport {
  RuleSetDiffReport({
    required Iterable<String> beforeRuleOrder,
    required Iterable<String> afterRuleOrder,
    required this.ruleOrderChanged,
    required Iterable<String> unchangedRuleIds,
    required Iterable<RuleSetChange> changes,
    required Iterable<RuleSetDiffWarning> warnings,
  }) : beforeRuleOrder = List.unmodifiable(beforeRuleOrder),
       afterRuleOrder = List.unmodifiable(afterRuleOrder),
       unchangedRuleIds = List.unmodifiable(unchangedRuleIds),
       changes = List.unmodifiable(changes),
       warnings = List.unmodifiable(warnings);

  final List<String> beforeRuleOrder;
  final List<String> afterRuleOrder;

  /// Includes changes in the complete rule-array order, not just rule content.
  final bool ruleOrderChanged;
  final List<String> unchangedRuleIds;
  final List<RuleSetChange> changes;
  final List<RuleSetDiffWarning> warnings;

  bool get hasChanges => ruleOrderChanged || changes.isNotEmpty;
  List<String> get addedRuleIds => _ids(RuleSetChangeKind.added);
  List<String> get removedRuleIds => _ids(RuleSetChangeKind.removed);
  List<String> get changedRuleIds => _ids(RuleSetChangeKind.changed);

  List<String> _ids(RuleSetChangeKind kind) => List.unmodifiable(
    changes
        .where((change) => change.kind == kind)
        .map((change) => change.ruleId),
  );

  Map<String, Object?> toJson() => {
    'schema_version': ruleSetDiffReportSchemaVersion,
    'beforeRuleOrder': beforeRuleOrder,
    'afterRuleOrder': afterRuleOrder,
    'ruleOrderChanged': ruleOrderChanged,
    'addedRuleIds': addedRuleIds,
    'removedRuleIds': removedRuleIds,
    'changedRuleIds': changedRuleIds,
    'unchangedRuleIds': unchangedRuleIds,
    'changes': changes.map((change) => change.toJson()).toList(),
    'warnings': warnings.map((warning) => warning.toJson()).toList(),
  };
}

/// Budgets cover both complete input arrays together, except maxRules which is
/// per array. Exceeding any budget rejects the entire comparison.
final class RuleSetDiffLimits {
  const RuleSetDiffLimits({
    this.maxRules = 2048,
    this.maxDepth = 32,
    this.maxNodes = 100000,
    this.maxPayloadBytes = 8 * 1024 * 1024,
    this.maxStringLength = 65536,
    this.maxFieldChanges = 10000,
  });

  final int maxRules;
  final int maxDepth;
  final int maxNodes;
  final int maxPayloadBytes;
  final int maxStringLength;
  final int maxFieldChanges;
}
