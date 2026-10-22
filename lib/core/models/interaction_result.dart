import '../../domain/entities/decision_support_followup.dart';

/// 交互检查总体状态
enum InteractionStatus { ok, warning, unassessed }

/// 严重程度（用于 UI 标色/排序）
enum InteractionSeverity { low, moderate, high }

/// 单条证据引用，用于在冲突结果页显示标题 / PMID / 链接。
class InteractionEvidence {
  final String sourceRef;
  final String title;
  final String? pmid;
  final String? doi;
  final String? sourceUrl;
  final String? publication;
  final String? evidenceKind;
  final String? sourceFamily;

  const InteractionEvidence({
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
    'sourceRef': sourceRef,
    'title': title,
    'pmid': pmid,
    'doi': doi,
    'sourceUrl': sourceUrl,
    'publication': publication,
    'evidenceKind': evidenceKind,
    'sourceFamily': sourceFamily,
  };

  static InteractionEvidence fromJson(Map<String, dynamic> json) {
    return InteractionEvidence(
      sourceRef: (json['sourceRef'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      pmid: json['pmid'] as String?,
      doi: json['doi'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      publication: json['publication'] as String?,
      evidenceKind: json['evidenceKind'] as String?,
      sourceFamily: json['sourceFamily'] as String?,
    );
  }
}

/// 一条具体提示
class InteractionIssue {
  final InteractionSeverity severity;
  final String title;
  final String detail;
  final String? relatedDrugId;
  final List<InteractionEvidence> evidence;

  InteractionIssue({
    required this.severity,
    required this.title,
    required this.detail,
    required this.relatedDrugId,
    this.evidence = const <InteractionEvidence>[],
  });

  InteractionIssue copyWith({
    InteractionSeverity? severity,
    String? title,
    String? detail,
    String? relatedDrugId,
    List<InteractionEvidence>? evidence,
  }) {
    return InteractionIssue(
      severity: severity ?? this.severity,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      relatedDrugId: relatedDrugId ?? this.relatedDrugId,
      evidence: evidence ?? this.evidence,
    );
  }

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'title': title,
    'detail': detail,
    'relatedDrugId': relatedDrugId,
    'evidence': evidence.map((item) => item.toJson()).toList(),
  };

  static InteractionIssue fromJson(Map<String, dynamic> json) {
    final sevName =
        (json['severity'] as String?) ?? InteractionSeverity.low.name;
    final sev = InteractionSeverity.values.firstWhere(
      (s) => s.name == sevName,
      orElse: () => InteractionSeverity.low,
    );

    return InteractionIssue(
      severity: sev,
      title: (json['title'] as String?) ?? '',
      detail: (json['detail'] as String?) ?? '',
      relatedDrugId: json['relatedDrugId'] as String?,
      evidence: (json['evidence'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                InteractionEvidence.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// One weighted component of the final 0-100 interaction score.
class InteractionScoreFactor {
  final String code;
  final String label;
  final int points;

  const InteractionScoreFactor({
    required this.code,
    required this.label,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'points': points,
  };

  static InteractionScoreFactor fromJson(Map<String, dynamic> json) {
    return InteractionScoreFactor(
      code: (json['code'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 交互结果：可序列化落盘
class InteractionResult {
  final String mealId;

  /// Immutable prompts captured by the deterministic runtime, before AI copy.
  final List<DecisionSupportPrompt> followupPrompts;
  final InteractionStatus status;
  final String summary;

  /// 分析结论文本：
  /// - 用于在总摘要下方补充“本次引擎是如何得出当前判断”的人类可读说明；
  /// - 为空时 UI 不展示，保持兼容旧结果。
  final String analysisText;
  final List<String> keyFindings;
  final List<String> nextActions;
  final List<String> dataNotes;
  final List<InteractionIssue> issues;
  final DateTime generatedAt;

  /// Null means the supplied context cannot be assessed. It is never zero risk.
  final int? score;
  final List<InteractionScoreFactor> scoreFactors;
  final List<String> assessmentReasons;
  final List<String> unresolvedDrugIds;

  /// Deterministic mechanistic time-axis simulation trace, when one was
  /// computed for this run. Stored as a JSON map (rather than the typed
  /// `MechanisticConflictResult`) so the existing `toJson` / `fromJson`
  /// serialization continues to work for callers that haven't migrated to
  /// the typed shape. Educational simulation only; not medical advice.
  final Map<String, dynamic>? mechanisticTraceJson;

  InteractionResult({
    required this.mealId,
    this.followupPrompts = const [],
    required this.status,
    required this.summary,
    this.analysisText = '',
    this.keyFindings = const <String>[],
    this.nextActions = const <String>[],
    this.dataNotes = const <String>[],
    required this.issues,
    required this.generatedAt,
    required this.score,
    this.scoreFactors = const <InteractionScoreFactor>[],
    this.assessmentReasons = const [],
    this.unresolvedDrugIds = const [],
    this.mechanisticTraceJson,
  }) {
    if (status == InteractionStatus.unassessed) {
      if (score != null ||
          scoreFactors.isNotEmpty ||
          mechanisticTraceJson != null) {
        throw ArgumentError(
          'An unassessed result cannot carry a score or trace.',
        );
      }
    } else if (score == null) {
      throw ArgumentError('An assessed result requires an explicit score.');
    }
  }

  bool get hasAssessment => status != InteractionStatus.unassessed;

  InteractionResult copyWith({
    String? mealId,
    List<DecisionSupportPrompt>? followupPrompts,
    InteractionStatus? status,
    String? summary,
    String? analysisText,
    List<String>? keyFindings,
    List<String>? nextActions,
    List<String>? dataNotes,
    List<InteractionIssue>? issues,
    DateTime? generatedAt,
    int? score,
    List<InteractionScoreFactor>? scoreFactors,
    List<String>? assessmentReasons,
    List<String>? unresolvedDrugIds,
    Map<String, dynamic>? mechanisticTraceJson,
  }) {
    return InteractionResult(
      mealId: mealId ?? this.mealId,
      followupPrompts: followupPrompts ?? this.followupPrompts,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      analysisText: analysisText ?? this.analysisText,
      keyFindings: keyFindings ?? this.keyFindings,
      nextActions: nextActions ?? this.nextActions,
      dataNotes: dataNotes ?? this.dataNotes,
      issues: issues ?? this.issues,
      generatedAt: generatedAt ?? this.generatedAt,
      score: score ?? this.score,
      scoreFactors: scoreFactors ?? this.scoreFactors,
      assessmentReasons: assessmentReasons ?? this.assessmentReasons,
      unresolvedDrugIds: unresolvedDrugIds ?? this.unresolvedDrugIds,
      mechanisticTraceJson: mechanisticTraceJson ?? this.mechanisticTraceJson,
    );
  }

  factory InteractionResult.ok({
    required String mealId,
    required String message,
  }) {
    return InteractionResult(
      mealId: mealId,
      status: InteractionStatus.ok,
      summary: message,
      analysisText: '',
      keyFindings: const <String>[],
      nextActions: const <String>[],
      dataNotes: const <String>[],
      issues: const [],
      generatedAt: DateTime.now(),
      score: 0,
      scoreFactors: const <InteractionScoreFactor>[],
    );
  }

  /// The headline severity follows the rule decisions: the most severe issue
  /// wins. Rule points are a heuristic sum (protein, timing, context factors)
  /// and are shown separately; they never raise the headline above what the
  /// rules decided. Score bands remain only for results without issues.
  InteractionSeverity? get overallSeverity {
    final assessedScore = score;
    if (!hasAssessment || assessedScore == null) return null;
    if (issues.isNotEmpty) {
      return issues
          .map((issue) => issue.severity)
          .reduce((a, b) => a.index >= b.index ? a : b);
    }
    if (assessedScore >= 70) return InteractionSeverity.high;
    if (assessedScore >= 30) return InteractionSeverity.moderate;
    return InteractionSeverity.low;
  }

  Map<String, dynamic> toJson() => {
    'mealId': mealId,
    'status': status.name,
    'summary': summary,
    'analysisText': analysisText,
    'keyFindings': keyFindings,
    'nextActions': nextActions,
    'dataNotes': dataNotes,
    'issues': issues.map((e) => e.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
    'score': score,
    'scoreFactors': scoreFactors.map((item) => item.toJson()).toList(),
    if (assessmentReasons.isNotEmpty) 'assessmentReasons': assessmentReasons,
    if (unresolvedDrugIds.isNotEmpty) 'unresolvedDrugIds': unresolvedDrugIds,
    if (mechanisticTraceJson != null) 'mechanisticTrace': mechanisticTraceJson,
  };

  static InteractionResult fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final status = InteractionStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => throw FormatException('Unknown interaction status.'),
    );

    return InteractionResult(
      mealId: json['mealId'] as String,
      status: status,
      summary: (json['summary'] as String?) ?? '',
      analysisText: (json['analysisText'] as String?) ?? '',
      keyFindings: (json['keyFindings'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      nextActions: (json['nextActions'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      dataNotes: (json['dataNotes'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      issues: (json['issues'] as List<dynamic>? ?? const [])
          .map((e) => InteractionIssue.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      score: (json['score'] as num?)?.toInt(),
      scoreFactors: (json['scoreFactors'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                InteractionScoreFactor.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      assessmentReasons:
          (json['assessmentReasons'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
      unresolvedDrugIds:
          (json['unresolvedDrugIds'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
      mechanisticTraceJson: json['mechanisticTrace'] is Map
          ? Map<String, dynamic>.from(json['mechanisticTrace'] as Map)
          : null,
    );
  }
}
