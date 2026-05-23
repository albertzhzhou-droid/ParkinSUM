enum FactConflictType {
  variation,
  coexistVariant,
  contradiction,
  override,
  incompleteInput,
  parsingUncertainty,
  jurisdictionSplit,
}

enum RuntimeDecisionType {
  block('BLOCK'),
  requireReview('REQUIRE_REVIEW'),
  discourage('DISCOURAGE'),
  warn('WARN'),
  info('INFO'),
  allow('ALLOW'),
  defer('DEFER');

  final String wireValue;
  const RuntimeDecisionType(this.wireValue);
}

enum RuleType {
  hardConstraint,
  softRule,
  temporalRule,
  doseDependentRule,
  jurisdictionOverride,
  sourceResolutionRule,
  escalationRule,
}

/// 结构化证据引用：
/// - 只承载 provenance 元数据，不进入主营养/药物事实表；
/// - 供审计、解释展开项和前台证据卡片复用。
class EvidenceReferenceDetail {
  final String sourceRef;
  final String title;
  final String? pmid;
  final String? doi;
  final String? sourceUrl;
  final String? publication;
  final String? evidenceKind;
  final String? sourceFamily;

  const EvidenceReferenceDetail({
    required this.sourceRef,
    required this.title,
    this.pmid,
    this.doi,
    this.sourceUrl,
    this.publication,
    this.evidenceKind,
    this.sourceFamily,
  });

  Map<String, dynamic> toJson() => {
        'source_ref': sourceRef,
        'title': title,
        'pmid': pmid,
        'doi': doi,
        'source_url': sourceUrl,
        'publication': publication,
        'evidence_kind': evidenceKind,
        'source_family': sourceFamily,
      };
}

class RuntimeAlert {
  final String target;
  final RuntimeDecisionType decision;
  final String severity;
  final String explanation;
  final List<Map<String, dynamic>> actions;
  final List<String> evidenceSources;
  final List<String> evidenceDetails;
  final List<EvidenceReferenceDetail> evidenceRecords;
  final List<String> ruleIds;

  const RuntimeAlert({
    required this.target,
    required this.decision,
    required this.severity,
    required this.explanation,
    required this.actions,
    required this.evidenceSources,
    required this.evidenceDetails,
    required this.evidenceRecords,
    required this.ruleIds,
  });

  Map<String, dynamic> toJson() => {
        'target': target,
        'decision': decision.wireValue,
        'severity': severity,
        'explanation': explanation,
        'actions': actions,
        'evidence_sources': evidenceSources,
        'evidence_details': evidenceDetails,
        'evidence_records':
            evidenceRecords.map((item) => item.toJson()).toList(),
        'rule_ids': ruleIds,
      };
}

class RuntimeAuditEntry {
  final String target;
  final RuntimeDecisionType decision;
  final List<String> winningRuleIds;
  final List<String> suppressedRuleIds;
  final List<String> sourceDocRefs;
  final List<String> evidenceDetails;
  final List<EvidenceReferenceDetail> evidenceRecords;
  final String inputHash;
  final String decisionReason;
  final List<Map<String, dynamic>> machineActions;
  final String humanMessage;
  final bool needsHumanReview;

  const RuntimeAuditEntry({
    required this.target,
    required this.decision,
    required this.winningRuleIds,
    required this.suppressedRuleIds,
    required this.sourceDocRefs,
    required this.evidenceDetails,
    required this.evidenceRecords,
    required this.inputHash,
    required this.decisionReason,
    required this.machineActions,
    required this.humanMessage,
    required this.needsHumanReview,
  });

  Map<String, dynamic> toJson() => {
        'target': target,
        'decision': decision.wireValue,
        'winning_rule_ids': winningRuleIds,
        'suppressed_rule_ids': suppressedRuleIds,
        'source_doc_refs': sourceDocRefs,
        'evidence_details': evidenceDetails,
        'evidence_records':
            evidenceRecords.map((item) => item.toJson()).toList(),
        'input_hash': inputHash,
        'decision_reason': decisionReason,
        'machine_actions': machineActions,
        'human_message': humanMessage,
        'needs_human_review': needsHumanReview,
      };
}

class EngineRunOutput {
  final Map<String, dynamic> alertsJson;
  final String humanReadableMarkdown;
  final String auditLogJsonl;
  final List<RuntimeAlert> alerts;
  final List<RuntimeAuditEntry> auditEntries;

  const EngineRunOutput({
    required this.alertsJson,
    required this.humanReadableMarkdown,
    required this.auditLogJsonl,
    required this.alerts,
    required this.auditEntries,
  });
}
