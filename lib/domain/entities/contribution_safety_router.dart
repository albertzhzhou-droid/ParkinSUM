/// P11 — ContributionSafetyRouter entities.
///
/// Educational/research prototype only. A deterministic **repository-governance**
/// helper that classifies pull-request / diff risk from changed file paths,
/// source references, and safety-sensitive keywords, then emits a structured
/// risk report, suggested labels, and a recommended reviewer checklist.
///
/// It is **NOT** an AI code reviewer, **NOT** a medical reviewer, **NOT** a
/// legal/compliance tool, and does **NOT** replace human review or judge
/// clinical correctness. Synthetic/demo data only; no PHI / patient / subject /
/// encounter semantics.
library;

class ContributionRiskSeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

class ContributionRiskLevel {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String blocker = 'blocker';

  /// Ordering for aggregation (lower index = lower risk).
  static const List<String> order = [low, medium, high, blocker];

  static int rank(String l) {
    final i = order.indexOf(l);
    return i < 0 ? 0 : i;
  }

  static String higher(String a, String b) => rank(a) >= rank(b) ? a : b;
}

class ContributionRiskCategory {
  static const String docsOnly = 'docs_only';
  static const String testOnly = 'test_only';
  static const String sourceMetadata = 'source_metadata';
  static const String replayScenario = 'replay_scenario';
  static const String ruleExplanation = 'rule_explanation';
  static const String mechanisticModel = 'mechanistic_model';
  static const String importer = 'importer';
  static const String firebaseRules = 'firebase_rules';
  static const String securitySensitive = 'security_sensitive';
  static const String localizationCopy = 'localization_copy';
  static const String evidenceArtifact = 'evidence_artifact';
  static const String medicalClaimRisk = 'medical_claim_risk';
  static const String clinicalAdviceRisk = 'clinical_advice_risk';
  static const String secretRisk = 'secret_risk';
  static const String phiRisk = 'phi_risk';
  static const String sourceAccessRisk = 'source_access_risk';
  static const String releaseGovernance = 'release_governance';
  static const String generatedOutput = 'generated_output';
  static const String unknown = 'unknown';
}

/// One changed file in a diff (supplied by the CLI collector or tests).
class ContributionChange {
  final String path;

  /// `added` / `modified` / `deleted` / `renamed`.
  final String changeType;
  final int addedLines;
  final int removedLines;

  /// Concatenated added-line text, used for keyword scanning (may be empty).
  final String addedContent;

  /// Keywords pre-matched by a collector (optional; router also scans content).
  final List<String> matchedKeywords;
  final List<String> sourceRefs;
  final bool isGenerated;
  final bool isDocs;
  final bool isTest;

  /// When true, keyword risk findings on this change are downgraded (it is a
  /// detector-definition / scanner / its own test file that legitimately
  /// contains the patterns it defines).
  final bool allowlisted;

  const ContributionChange({
    required this.path,
    this.changeType = 'modified',
    this.addedLines = 0,
    this.removedLines = 0,
    this.addedContent = '',
    this.matchedKeywords = const [],
    this.sourceRefs = const [],
    this.isGenerated = false,
    this.isDocs = false,
    this.isTest = false,
    this.allowlisted = false,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'change_type': changeType,
        'added_lines': addedLines,
        'removed_lines': removedLines,
        'matched_keywords': matchedKeywords,
        'source_refs': sourceRefs,
        'is_generated': isGenerated,
        'is_docs': isDocs,
        'is_test': isTest,
        'allowlisted': allowlisted,
      };
}

class ContributionRiskFinding {
  final String severity;
  final String category;
  final String path;
  final int line;
  final String message;
  final String matchedText;
  final String suggestedReview;
  final String requiredCommand;
  final String safetyBoundary;

  const ContributionRiskFinding({
    required this.severity,
    required this.category,
    required this.path,
    this.line = 0,
    required this.message,
    this.matchedText = '',
    this.suggestedReview = '',
    this.requiredCommand = '',
    this.safetyBoundary = '',
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'category': category,
        'path': path,
        'line': line,
        'message': message,
        'matched_text': matchedText,
        'suggested_review': suggestedReview,
        'required_command': requiredCommand,
        'safety_boundary': safetyBoundary,
      };
}

class ContributionReviewChecklistItem {
  final String id;
  final String category;
  final bool required;
  final String text;
  final bool blockingIfMissing;
  final List<String> relatedCommands;

  const ContributionReviewChecklistItem({
    required this.id,
    required this.category,
    required this.required,
    required this.text,
    this.blockingIfMissing = false,
    this.relatedCommands = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'required': required,
        'text': text,
        'blocking_if_missing': blockingIfMissing,
        'related_commands': relatedCommands,
      };
}

class ContributionSafetyReport {
  static const String kReportType = 'contribution_safety_router';

  final String generatedAt;
  final int changeCount;
  final List<String> categories;
  final String riskLevel;
  final Map<String, int> counts; // info / warn / blocker
  final List<ContributionRiskFinding> findings;
  final List<ContributionReviewChecklistItem> checklist;
  final List<String> suggestedLabels;
  final List<String> requiredCommands;
  final bool pass;
  final String safetyBoundary;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const ContributionSafetyReport({
    required this.generatedAt,
    required this.changeCount,
    required this.categories,
    required this.riskLevel,
    required this.counts,
    required this.findings,
    required this.checklist,
    required this.suggestedLabels,
    required this.requiredCommands,
    required this.pass,
    required this.safetyBoundary,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount => counts['blocker'] ?? 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'not_ai_code_review': true,
        'does_not_replace_human_review': true,
        'generated_at': generatedAt,
        'change_count': changeCount,
        'risk_level': riskLevel,
        'categories': categories,
        'counts': counts,
        'pass': pass,
        'suggested_labels': suggestedLabels,
        'required_commands': requiredCommands,
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'checklist': checklist.map((c) => c.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
      };
}

/// Optional configuration.
class ContributionSafetyRouterConfig {
  final String deterministicTimestamp;

  /// When true, WARN findings are escalated to BLOCKER.
  final bool strictMode;

  const ContributionSafetyRouterConfig({
    this.deterministicTimestamp = 'synthetic-demo',
    this.strictMode = false,
  });
}
